from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from typing import Protocol

import httpx

from app.core.config import settings
from app.services.geo import RouteResult, approximate_route, road_distance_m, estimate_duration_s

logger = logging.getLogger("neev.maps")


@dataclass
class Place:
    id: str
    name: str
    address: str
    lat: float
    lng: float
    label: str = "Demo location"


# Real coordinates for recognisable Bengaluru landmarks. The *dataset* is a
# development fixture, not a live place index; every response is labelled.
DEMO_PLACES: list[Place] = [
    Place("demo-mg-road", "MG Road Metro", "MG Road, Bengaluru 560001", 12.9757, 77.6068),
    Place("demo-koramangala", "Koramangala 5th Block", "5th Block, Koramangala, Bengaluru 560095", 12.9352, 77.6245),
    Place("demo-indiranagar", "Indiranagar 100ft Road", "100 Feet Road, Indiranagar, Bengaluru 560038", 12.9719, 77.6412),
    Place("demo-hsr", "HSR Layout Sector 2", "Sector 2, HSR Layout, Bengaluru 560102", 12.9116, 77.6389),
    Place("demo-whitefield", "Whitefield ITPL", "ITPL Main Road, Whitefield, Bengaluru 560066", 12.9698, 77.7499),
    Place("demo-electronic-city", "Electronic City Phase 1", "Electronic City, Bengaluru 560100", 12.8452, 77.6602),
    Place("demo-jayanagar", "Jayanagar 4th Block", "4th Block, Jayanagar, Bengaluru 560011", 12.9250, 77.5938),
    Place("demo-hebbal", "Hebbal Flyover", "Hebbal, Bengaluru 560024", 13.0358, 77.5970),
    Place("demo-majestic", "Majestic Bus Station", "Kempegowda Bus Station, Bengaluru 560009", 12.9776, 77.5713),
    Place("demo-cubbon", "Cubbon Park", "Kasturba Road, Bengaluru 560001", 12.9763, 77.5929),
    Place("demo-lalbagh", "Lalbagh West Gate", "Lalbagh, Bengaluru 560004", 12.9507, 77.5848),
    Place("demo-marathahalli", "Marathahalli Bridge", "Marathahalli, Bengaluru 560037", 12.9591, 77.6974),
    Place("demo-yelahanka", "Yelahanka New Town", "Yelahanka, Bengaluru 560064", 13.1007, 77.5963),
    Place("demo-domlur", "Domlur", "Domlur, Bengaluru 560071", 12.9609, 77.6387),
    Place("demo-airport", "Kempegowda Airport", "Kempegowda International Airport, Bengaluru 560300", 13.1986, 77.7066),
]


class MapProvider(Protocol):
    name: str

    def search(self, query: str, limit: int = 6) -> list[Place]: ...

    def reverse(self, lat: float, lng: float) -> Place: ...

    def route(
        self, lat1: float, lng1: float, lat2: float, lng2: float, category: str
    ) -> RouteResult: ...


class DemoMapProvider:
    name = "demo"

    def search(self, query: str, limit: int = 6) -> list[Place]:
        q = query.strip().lower()
        if not q:
            return DEMO_PLACES[:limit]
        matches = [
            p
            for p in DEMO_PLACES
            if q in p.name.lower() or q in p.address.lower()
        ]
        return matches[:limit]

    def reverse(self, lat: float, lng: float) -> Place:
        nearest = min(
            DEMO_PLACES, key=lambda p: (p.lat - lat) ** 2 + (p.lng - lng) ** 2
        )
        return Place(
            id=f"demo-reverse-{nearest.id}",
            name=f"Near {nearest.name}",
            address=f"{nearest.address} (demo reverse geocode)",
            lat=lat,
            lng=lng,
            label="Demo reverse geocode",
        )

    def route(
        self, lat1: float, lng1: float, lat2: float, lng2: float, category: str
    ) -> RouteResult:
        return approximate_route(lat1, lng1, lat2, lng2, category)


class OsmMapProvider:
    """OSM/Nominatim/OSRM adapter for controlled development.

    Public instances are rate-limited and not suitable for production traffic.
    Configure self-hosted endpoints or a commercial provider for production.
    """

    name = "osm"
    _cache: dict[str, tuple[float, list[Place]]] = {}

    def search(self, query: str, limit: int = 6) -> list[Place]:
        key = f"{query.lower()}:{limit}"
        cached = self._cache.get(key)
        if cached and time.time() - cached[0] < 300:
            return cached[1]
        try:
            response = httpx.get(
                f"{settings.osm_nominatim_url}/search",
                params={
                    "q": query,
                    "format": "jsonv2",
                    "limit": limit,
                    "countrycodes": "in",
                    "addressdetails": 1,
                },
                headers={"User-Agent": settings.geocoder_user_agent},
                timeout=6.0,
            )
            response.raise_for_status()
            places = []
            for item in response.json():
                places.append(
                    Place(
                        id=f"osm-{item.get('place_id')}",
                        name=item.get("name") or item.get("display_name", "").split(",")[0],
                        address=item.get("display_name", ""),
                        lat=float(item["lat"]),
                        lng=float(item["lon"]),
                        label="OpenStreetMap",
                    )
                )
            self._cache[key] = (time.time(), places)
            return places
        except Exception:
            logger.warning("maps.search_failed", exc_info=True)
            return []

    def reverse(self, lat: float, lng: float) -> Place:
        try:
            response = httpx.get(
                f"{settings.osm_nominatim_url}/reverse",
                params={"lat": lat, "lon": lng, "format": "jsonv2"},
                headers={"User-Agent": settings.geocoder_user_agent},
                timeout=6.0,
            )
            response.raise_for_status()
            item = response.json()
            return Place(
                id=f"osm-{item.get('place_id', 'reverse')}",
                name=item.get("name") or item.get("display_name", "").split(",")[0],
                address=item.get("display_name", f"{lat:.5f}, {lng:.5f}"),
                lat=lat,
                lng=lng,
                label="OpenStreetMap",
            )
        except Exception:
            logger.warning("maps.reverse_failed", exc_info=True)
            return Place(
                id="reverse-fallback",
                name="Pinned location",
                address=f"{lat:.5f}, {lng:.5f}",
                lat=lat,
                lng=lng,
                label="Approximate coordinates",
            )

    def route(
        self, lat1: float, lng1: float, lat2: float, lng2: float, category: str
    ) -> RouteResult:
        try:
            response = httpx.get(
                f"{settings.osm_osrm_url}/route/v1/driving/{lng1},{lat1};{lng2},{lat2}",
                params={"overview": "full", "geometries": "geojson"},
                headers={"User-Agent": settings.geocoder_user_agent},
                timeout=8.0,
            )
            response.raise_for_status()
            data = response.json()
            route = data["routes"][0]
            coords = [(p[1], p[0]) for p in route["geometry"]["coordinates"]]
            return RouteResult(
                distance_m=int(route["distance"]),
                duration_s=int(route["duration"]),
                points=coords,
                provider="osm-osrm",
                approximate=False,
            )
        except Exception:
            logger.warning("maps.route_failed", exc_info=True)
            route = approximate_route(lat1, lng1, lat2, lng2, category)
            route.provider = "osm-fallback"
            route.approximate = True
            return route


def get_map_provider() -> MapProvider:
    if settings.map_provider == "osm":
        return OsmMapProvider()
    return DemoMapProvider()


def route_between(
    lat1: float, lng1: float, lat2: float, lng2: float, category: str
) -> RouteResult:
    return get_map_provider().route(lat1, lng1, lat2, lng2, category)
