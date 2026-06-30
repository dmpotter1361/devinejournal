"""initial schema

Revision ID: 001
Revises:
Create Date: 2026-06-30
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = '001'
down_revision = None
branch_labels = None
depends_on = None

def upgrade():
    op.create_table(
        'users',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column('google_id', sa.String(), unique=True, nullable=False),
        sa.Column('email', sa.String(), unique=True, nullable=False),
        sa.Column('name', sa.String(), server_default=''),
        sa.Column('picture', sa.String(), server_default=''),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_users_google_id', 'users', ['google_id'])

    op.create_table(
        'entries',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('title', sa.String(), server_default=''),
        sa.Column('body', sa.Text(), server_default=''),
        sa.Column('mood', sa.String(), server_default=''),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_entries_user_id', 'entries', ['user_id'])

def downgrade():
    op.drop_table('entries')
    op.drop_table('users')
