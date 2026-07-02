#!/usr/bin/env bash
# Nightly backup for DevineJournal.
#
# Runs pg_dump INSIDE the db container using the container's own
# POSTGRES_USER / POSTGRES_DB env vars, so no database credentials are ever
# read or handled on the host. This is a COMPLETE backup: entries, photos,
# and voice memos all live in Postgres (stored as base64 in Text columns).
#
# Install (on the VM):
#   cp ops/backup-devinejournal.sh /home/dmpotter1361/stacks/devinejournal/backup.sh
#   chmod +x /home/dmpotter1361/stacks/devinejournal/backup.sh
#   ( crontab -l 2>/dev/null; echo '30 2 * * * /home/dmpotter1361/stacks/devinejournal/backup.sh >> /home/dmpotter1361/backups/devinejournal/backup.log 2>&1' ) | crontab -
set -euo pipefail

CONTAINER="${DJ_DB_CONTAINER:-devinejournal-db}"
BACKUP_DIR="${DJ_BACKUP_DIR:-/home/dmpotter1361/backups/devinejournal}"
KEEP="${DJ_KEEP:-14}"          # how many dumps to retain

mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
TMP="${BACKUP_DIR}/.inprogress-$$.sql.gz"
OUT="${BACKUP_DIR}/devinejournal-${STAMP}.sql.gz"
trap 'rm -f "$TMP"' EXIT

# --clean --if-exists makes the dump safe to restore over an existing DB.
docker exec "$CONTAINER" sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists' \
  | gzip -9 > "$TMP"

# Validate before we let it count as a good backup.
if ! gzip -t "$TMP" 2>/dev/null; then
  echo "$(date -Is) BACKUP FAILED: corrupt gzip" >&2
  exit 1
fi
SIZE="$(stat -c%s "$TMP")"
if [ "$SIZE" -lt 1000 ]; then
  echo "$(date -Is) BACKUP FAILED: dump only ${SIZE} bytes (schema-only or broken)" >&2
  exit 1
fi

mv "$TMP" "$OUT"
trap - EXIT
echo "$(date -Is) backup ok: ${OUT} (${SIZE} bytes)"

# Rotate: keep the newest $KEEP dumps, delete the rest.
ls -1t "${BACKUP_DIR}"/devinejournal-*.sql.gz 2>/dev/null \
  | tail -n +"$((KEEP + 1))" \
  | xargs -r rm -f
