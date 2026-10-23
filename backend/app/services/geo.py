from __future__ import annotations

import math
from dataclasses import dataclass

from app.models import ServiceArea

EARTH_RADIUS_M = 6_371_000
CATEGORY_SPEED_KMH = {"bike": 23.0, "auto": 19.0, "cab": 25.0}


def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> int:
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = (
        math.sin(dphi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    )
    return int(2 * EARTH_RADIUS_M * math.asin(math.sqrt(a)))


def road_distance_m(lat1: float, lng1: float, lat2: float, lng2: float) -> int:
    """Fallback road estimate when a routing provider is unavailable.

    Clearly approximate: straight-line distance with a 1.28 road-network factor.
    """
    return max(1, int(haversine_m(lat1, lng1, lat2, lng2) * 1.28))


def estimate_duration_s(distance_m: int, category: str, multiplier: float = 1.0) -> int:
    speed = CATEGORY_SPEED_KMH.get(category, 20.0) * multiplier
    seconds = (distance_m / 1000.0) / speed * 3600
    return max(60, int(seconds + 180))


def point_in_service_area(lat: float, lng: float, area: ServiceArea) -> bool:
    return haversine_m(lat, lng, area.center_lat, area.center_lng) <= area.radius_km * 1000


@dataclass
class RouteResult:
    distance_m: int
    duration_s: int
    points: list[tuple[float, float]]
    provider: str
    approximate: bool


def approximate_route(
    lat1: float, lng1: float, lat2: float, lng2: float, category: str
) -> RouteResult:
    """A deterministic curved line used only when no routing provider is configured."""
    distance = road_distance_m(lat1, lng1, lat2, lng2)
    mid_lat = (lat1 + lat2) / 2
    mid_lng = (lng1 + lng2) / 2
    dlat, dlng = lat2 - lat1, lng2 - lng1
    # Perpendicular bend gives the demo map a route-like shape.
    bend = 0.10
    points = [(lat1, lng1)]
    for i in range(1, 6):
        t = i / 6
        curve = math.sin(t * math.pi) * bend
        points.append((lat1 + dlat * t - dlng * curve, lng1 + dlng * t + dlat * curve))
    points.append((lat2, lng2))
    return RouteResult(
        distance_m=distance,
        duration_s=estimate_duration_s(distance, category),
        points=points,
        provider="demo",
        approximate=True,
    )
