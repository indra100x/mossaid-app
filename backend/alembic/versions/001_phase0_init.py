"""phase0 init: users, craftsman_profiles, bookings + postgis

Revision ID: 001
Revises:
Create Date: 2026-09-23
"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # PostGIS for geo search (system-architecture.md:56) — ignore if not available (e.g. sqlite)
    try:
        op.execute("CREATE EXTENSION IF NOT EXISTS postgis")
    except Exception:
        pass

    op.create_table(
        "users",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("phone", sa.String(length=20), nullable=False),
        sa.Column("role", sa.String(length=20), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=True),
        sa.Column("language_pref", sa.String(length=10), nullable=False),
        sa.Column("is_verified", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_users_phone"), "users", ["phone"], unique=True)

    op.create_table(
        "craftsman_profiles",
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("trades", sa.JSON(), nullable=False),
        sa.Column("bio", sa.Text(), nullable=True),
        sa.Column("service_radius_km", sa.Integer(), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("hourly_rate", sa.Float(), nullable=True),
        sa.Column("rating_avg", sa.Float(), nullable=False),
        sa.Column("verification_status", sa.String(length=20), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id"),
    )

    op.create_table(
        "bookings",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("client_id", sa.UUID(), nullable=False),
        sa.Column("craftsman_id", sa.UUID(), nullable=False),
        sa.Column("trade", sa.String(length=50), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("address", sa.Text(), nullable=False),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("price_agreed", sa.Float(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["client_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["craftsman_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_bookings_client_id"), "bookings", ["client_id"], unique=False)
    op.create_index(op.f("ix_bookings_craftsman_id"), "bookings", ["craftsman_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_bookings_craftsman_id"), table_name="bookings")
    op.drop_index(op.f("ix_bookings_client_id"), table_name="bookings")
    op.drop_table("bookings")
    op.drop_table("craftsman_profiles")
    op.drop_index(op.f("ix_users_phone"), table_name="users")
    op.drop_table("users")
