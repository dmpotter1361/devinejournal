"""add voice_memos table

Revision ID: 007
Revises: 006
Create Date: 2026-06-30
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '007'
down_revision = '006'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'voice_memos',
        sa.Column('id',          postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('entry_id',    postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('user_id',     postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('data',        sa.Text(),   nullable=False),
        sa.Column('duration_ms', sa.String(), nullable=True, server_default='0'),
        sa.Column('transcript',  sa.Text(),   nullable=True, server_default=''),
        sa.Column('sort_order',  sa.String(), nullable=True, server_default='0'),
        sa.Column('created_at',  sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['entry_id'], ['entries.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'],  ['users.id'],   ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_voice_memos_entry_id', 'voice_memos', ['entry_id'], unique=False)
    op.create_index('ix_voice_memos_user_id',  'voice_memos', ['user_id'],  unique=False)


def downgrade():
    op.drop_index('ix_voice_memos_user_id',  table_name='voice_memos')
    op.drop_index('ix_voice_memos_entry_id', table_name='voice_memos')
    op.drop_table('voice_memos')
