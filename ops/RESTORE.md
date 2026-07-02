# DevineJournal — Backup & Restore

## What's backed up
A nightly `pg_dump` of the Postgres database. Because entries, photos, and
voice memos are all stored **in the database** (photos/voice as base64 in
`Text` columns), a single dump is a complete, self-contained backup of the
whole journal.

- **Script:** `/home/dmpotter1361/stacks/devinejournal/backup.sh`
- **Backups:** `/home/dmpotter1361/backups/devinejournal/devinejournal-YYYYMMDD-HHMMSS.sql.gz`
- **Schedule:** nightly at 02:30 (VM crontab), keeps the 14 most recent dumps
- **Log:** `/home/dmpotter1361/backups/devinejournal/backup.log`

## Run a backup right now
```bash
/home/dmpotter1361/stacks/devinejournal/backup.sh
```

## Restore (disaster recovery, or roll back to a known-good state)
The dump uses `--clean --if-exists`, so it drops and recreates each object —
safe to run against the existing database.

```bash
# pick the dump you want
DUMP=/home/dmpotter1361/backups/devinejournal/devinejournal-YYYYMMDD-HHMMSS.sql.gz

gunzip -c "$DUMP" | docker exec -i devinejournal-db \
  sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'

# then restart the API so it reconnects cleanly
cd /home/dmpotter1361/stacks/devinejournal/server
docker compose restart devinejournal-api
```

### Restoring onto a brand-new/empty volume
If the volume was lost (`docker compose down -v` or disk failure) bring the DB
up first so the empty database exists, then run the restore above:
```bash
cd /home/dmpotter1361/stacks/devinejournal/server
docker compose up -d devinejournal-db
sleep 5
# ...then the gunzip | psql restore command above
```

## ⚠️ Still TODO: off-box copy
These dumps currently live on the **same VM/disk** as the database. That
protects against the common disasters — a bad migration, an accidental
`docker compose down -v`, container corruption, or a deleted entry — but NOT
against the physical disk dying. Next step is to replicate the newest dump to
a second location (the remote box, Google Drive, or the Windows machine).
