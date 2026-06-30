"""add tags to entries

Revision ID: 002
Revises: 001
Create Date: 2026-06-30
"""
from alembic import op
import sqlalchemy as sa

revision = '002'
down_revision = '001'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('entries', sa.Column('tags', sa.Text(), nullable=True, server_default=''))

def downgrade():
    op.drop_column('entries', 'tags')
