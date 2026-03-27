"""add deleted fields to blog comments

Revision ID: a4b5c6d7e8f1
Revises: f2b6c7d8e9f0
Create Date: 2026-03-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'a4b5c6d7e8f1'
down_revision = 'f2b6c7d8e9f0'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('blog_comments', schema=None) as batch_op:
        batch_op.add_column(sa.Column('deleted', sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column('deleted_at', sa.DateTime(), nullable=True))


def downgrade():
    with op.batch_alter_table('blog_comments', schema=None) as batch_op:
        batch_op.drop_column('deleted_at')
        batch_op.drop_column('deleted')