"""add edited fields to blog comments

Revision ID: f2b6c7d8e9f0
Revises: e7a1c4d5b6f7
Create Date: 2026-03-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'f2b6c7d8e9f0'
down_revision = 'e7a1c4d5b6f7'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('blog_comments', schema=None) as batch_op:
        batch_op.add_column(sa.Column('edited', sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column('edited_at', sa.DateTime(), nullable=True))


def downgrade():
    with op.batch_alter_table('blog_comments', schema=None) as batch_op:
        batch_op.drop_column('edited_at')
        batch_op.drop_column('edited')