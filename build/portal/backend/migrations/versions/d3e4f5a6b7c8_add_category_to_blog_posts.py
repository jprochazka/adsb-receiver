"""add_category_to_blog_posts

Revision ID: d3e4f5a6b7c8
Revises: c9d0e1f2a3b4
Create Date: 2026-03-27 21:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'd3e4f5a6b7c8'
down_revision = 'c9d0e1f2a3b4'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('blog_posts', schema=None) as batch_op:
        batch_op.add_column(sa.Column('category', sa.String(100), nullable=True, server_default=''))


def downgrade():
    with op.batch_alter_table('blog_posts', schema=None) as batch_op:
        batch_op.drop_column('category')
