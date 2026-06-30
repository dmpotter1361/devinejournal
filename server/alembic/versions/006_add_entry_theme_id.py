"""add theme_id to entries

Revision ID: 006
Revises: 005
Create Date: 2026-06-30
"""
from alembic import op
import sqlalchemy as sa

revision = '006'
down_revision = '005'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('entries', sa.Column('theme_id', sa.String(), nullable=True))


def downgrade():
    op.drop_column('entries', 'theme_id')
