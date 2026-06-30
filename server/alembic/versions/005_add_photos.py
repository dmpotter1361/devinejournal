"""add photos table

Revision ID: 005
Revises: 004
Create Date: 2026-06-30
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '005'
down_revision = '004'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'photos',
        sa.Column('id',         postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('entry_id',   postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('user_id',    postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('data',       sa.Text(),   nullable=False),
        sa.Column('width_pct',  sa.String(), nullable=True, server_default='100'),
        sa.Column('align',      sa.String(), nullable=True, server_default='center'),
        sa.Column('caption',    sa.String(), nullable=True, server_default=''),
        sa.Column('sort_order', sa.String(), nullable=True, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['entry_id'], ['entries.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'],  ['users.id'],   ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_photos_entry_id', 'photos', ['entry_id'], unique=False)
    op.create_index('ix_photos_user_id',  'photos', ['user_id'],  unique=False)


def downgrade():
    op.drop_index('ix_photos_user_id',  table_name='photos')
    op.drop_index('ix_photos_entry_id', table_name='photos')
    op.drop_table('photos')
