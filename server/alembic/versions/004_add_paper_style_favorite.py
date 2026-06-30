"""add paper_style and is_favorite to entries

Revision ID: 004
Revises: 003
Create Date: 2026-06-30
"""
from alembic import op
import sqlalchemy as sa

revision = '004'
down_revision = '003'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('entries', sa.Column('paper_style', sa.Text(), nullable=False, server_default='lined'))
    op.add_column('entries', sa.Column('is_favorite', sa.Boolean(), nullable=False, server_default='false'))

def downgrade():
    op.drop_column('entries', 'is_favorite')
    op.drop_column('entries', 'paper_style')
