import math
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy import String, and_, cast, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.models.craftsman_profile import CraftsmanProfile
from app.models.user import User
from app.modules.discovery.schemas import CraftsmanSearchOut, SearchResponse

router = APIRouter(prefix="/discovery", tags=["discovery"])


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlng / 2) ** 2
    c = 2 * math.asin(math.sqrt(a))
    return 6371 * c


def haversine_sql(lat_col: object, lng_col: object, lat: float, lng: float) -> object:
    return 6371 * func.acos(
        func.cos(func.radians(lat))
        * func.cos(func.radians(lat_col))
        * func.cos(func.radians(lng_col) - func.radians(lng))
        + func.sin(func.radians(lat)) * func.sin(func.radians(lat_col))
    )


@router.get("/search", response_model=SearchResponse)
async def search_craftsmen(
    session: Annotated[AsyncSession, Depends(get_session)],
    trade: str | None = Query(None),
    lat: float | None = Query(None, ge=-90, le=90),
    lng: float | None = Query(None, ge=-180, le=180),
    radius_km: float | None = Query(None, ge=0.1, le=200),
    min_rating: float | None = Query(None, ge=0, le=5),
    min_price: float | None = Query(None, ge=0),
    max_price: float | None = Query(None, ge=0),
    q: str | None = Query(None, max_length=100),
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
) -> SearchResponse:
    base_filters = [User.role == "craftsman"]
    stmt = select(CraftsmanProfile, User).join(User, CraftsmanProfile.user_id == User.id).where(and_(*base_filters))
    count_stmt = select(func.count()).select_from(CraftsmanProfile).join(User, CraftsmanProfile.user_id == User.id).where(
        and_(*base_filters)
    )

    # Trade filter - free-form, case-insensitive, JSON cast
    if trade:
        trades_norm = trade.strip().lower()
        stmt = stmt.where(cast(CraftsmanProfile.trades, String).ilike(f"%{trades_norm}%"))
        count_stmt = count_stmt.where(cast(CraftsmanProfile.trades, String).ilike(f"%{trades_norm}%"))

    if min_rating is not None:
        stmt = stmt.where(CraftsmanProfile.rating_avg >= min_rating)
        count_stmt = count_stmt.where(CraftsmanProfile.rating_avg >= min_rating)

    if min_price is not None:
        stmt = stmt.where(CraftsmanProfile.hourly_rate >= min_price)
        count_stmt = count_stmt.where(CraftsmanProfile.hourly_rate >= min_price)
    if max_price is not None:
        stmt = stmt.where(CraftsmanProfile.hourly_rate <= max_price)
        count_stmt = count_stmt.where(CraftsmanProfile.hourly_rate <= max_price)

    if q:
        q_ilike = f"%{q.strip().lower()}%"
        stmt = stmt.where(
            (func.lower(func.coalesce(User.name, "")).like(q_ilike))
            | (func.lower(func.coalesce(CraftsmanProfile.bio, "")).like(q_ilike))
            | (cast(CraftsmanProfile.trades, String).ilike(q_ilike))
        )
        count_stmt = count_stmt.where(
            (func.lower(func.coalesce(User.name, "")).like(q_ilike))
            | (func.lower(func.coalesce(CraftsmanProfile.bio, "")).like(q_ilike))
            | (cast(CraftsmanProfile.trades, String).ilike(q_ilike))
        )

    is_sqlite = session.bind is not None and session.bind.dialect.name == "sqlite"
    use_sql_distance = lat is not None and lng is not None and radius_km is not None and not is_sqlite

    distance_expr = None
    if lat is not None and lng is not None and radius_km is not None:
        stmt = stmt.where(CraftsmanProfile.latitude.is_not(None), CraftsmanProfile.longitude.is_not(None))
        count_stmt = count_stmt.where(
            CraftsmanProfile.latitude.is_not(None), CraftsmanProfile.longitude.is_not(None)
        )
        if use_sql_distance:
            distance_expr = haversine_sql(CraftsmanProfile.latitude, CraftsmanProfile.longitude, lat, lng)
            stmt = stmt.where(distance_expr <= radius_km)  # type: ignore[operator,arg-type]
            count_stmt = count_stmt.where(distance_expr <= radius_km)  # type: ignore[operator,arg-type]
            stmt = stmt.order_by(distance_expr, CraftsmanProfile.rating_avg.desc())  # type: ignore[arg-type]
        else:
            # SQLite: order by rating, filter distance in python
            stmt = stmt.order_by(CraftsmanProfile.rating_avg.desc())
    else:
        stmt = stmt.order_by(CraftsmanProfile.rating_avg.desc())

    # For SQLite distance filtering, we need to fetch all then filter, so not use DB count accurately
    # Instead handle pagination after python filtering for SQLite case
    if is_sqlite and lat is not None and lng is not None and radius_km is not None:
        result = await session.execute(stmt)
        rows = result.all()
        # python distance filtering
        filtered: list[tuple[CraftsmanProfile, User]] = []
        for prof, user in rows:
            if prof.latitude is None or prof.longitude is None:
                continue
            dist = haversine_km(lat, lng, prof.latitude, prof.longitude)
            if dist <= radius_km:
                filtered.append((prof, user))
        total = len(filtered)
        paginated = filtered[offset : offset + limit]
        items: list[CraftsmanSearchOut] = []
        for prof, user in paginated:
            dist = haversine_km(lat, lng, prof.latitude, prof.longitude)  # type: ignore[arg-type]
            items.append(
                CraftsmanSearchOut(
                    user_id=user.id,
                    name=user.name,
                    phone=user.phone,
                    trades=prof.trades,
                    bio=prof.bio,
                    hourly_rate=prof.hourly_rate,
                    rating_avg=prof.rating_avg,
                    latitude=prof.latitude,
                    longitude=prof.longitude,
                    service_radius_km=prof.service_radius_km,
                    distance_km=round(dist, 2),
                )
            )
        return SearchResponse(items=items, total=total, limit=limit, offset=offset)

    total_res = await session.execute(count_stmt)
    total = total_res.scalar_one()

    stmt = stmt.limit(limit).offset(offset)
    result = await session.execute(stmt)
    rows = result.all()

    items: list[CraftsmanSearchOut] = []  # type: ignore[no-redef]
    for prof, user in rows:
        dist: float | None = None  # type: ignore[no-redef]
        if lat is not None and lng is not None and prof.latitude and prof.longitude:
            dist = haversine_km(lat, lng, prof.latitude, prof.longitude)

        items.append(
            CraftsmanSearchOut(
                user_id=user.id,
                name=user.name,
                phone=user.phone,
                trades=prof.trades,
                bio=prof.bio,
                hourly_rate=prof.hourly_rate,
                rating_avg=prof.rating_avg,
                latitude=prof.latitude,
                longitude=prof.longitude,
                service_radius_km=prof.service_radius_km,
                distance_km=round(dist, 2) if dist is not None and radius_km is not None else None,
            )
        )

    return SearchResponse(items=items, total=total, limit=limit, offset=offset)


@router.get("/")
async def discovery_placeholder() -> dict[str, str]:
    """discovery — search & filter craftsmen."""
    return {"module": "discovery", "status": "not_implemented"}
