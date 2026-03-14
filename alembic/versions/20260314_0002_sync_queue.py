"""Add sync queue."""

from alembic import op
import sqlalchemy as sa


revision = "20260314_0002"
down_revision = "20260314_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "sync_queue",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("entity_type", sa.String(length=50), nullable=False),
        sa.Column("entity_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="pending"),
        sa.Column("payload_snapshot", sa.Text(), nullable=True),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.Column("retry_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_attempt_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_sync_queue_entity", "sync_queue", ["entity_type", "entity_id"], unique=False)
    op.create_index("ix_sync_queue_status", "sync_queue", ["status"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_sync_queue_status", table_name="sync_queue")
    op.drop_index("ix_sync_queue_entity", table_name="sync_queue")
    op.drop_table("sync_queue")
