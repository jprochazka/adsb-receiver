"""add blog comments

Revision ID: e7a1c4d5b6f7
Revises: 9f18123aa632
Create Date: 2026-03-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'e7a1c4d5b6f7'
down_revision = '9f18123aa632'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'blog_comments',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('blog_post_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('parent_comment_id', sa.Integer(), nullable=True),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['blog_post_id'], ['blog_posts.id']),
        sa.ForeignKeyConstraint(['parent_comment_id'], ['blog_comments.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id')
    )

    with op.batch_alter_table('blog_comments', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_blog_comments_blog_post_id'), ['blog_post_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_blog_comments_created_at'), ['created_at'], unique=False)
        batch_op.create_index(batch_op.f('ix_blog_comments_parent_comment_id'), ['parent_comment_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_blog_comments_user_id'), ['user_id'], unique=False)


def downgrade():
    with op.batch_alter_table('blog_comments', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_blog_comments_user_id'))
        batch_op.drop_index(batch_op.f('ix_blog_comments_parent_comment_id'))
        batch_op.drop_index(batch_op.f('ix_blog_comments_created_at'))
        batch_op.drop_index(batch_op.f('ix_blog_comments_blog_post_id'))

    op.drop_table('blog_comments')