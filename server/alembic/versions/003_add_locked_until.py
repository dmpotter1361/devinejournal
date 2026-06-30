"""add locked_until to entries

Revision ID: 003
Revises: 002
Create Date: 2026-06-30
"""
from alembic import op
import sqlalchemy as sa

revision = '003'
down_revision = '002'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('entries', sa.Column('locked_until', sa.Text(), nullable=True, server_default=None))

def downgrade():
    op.drop_column('entries', 'locked_until')
