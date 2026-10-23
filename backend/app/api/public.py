from __future__ import annotations

import html
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import api_error
from app.core.config import settings
from app.core.database import get_db, utcnow
from app.core.rate_limit import rate_limit
from app.models import (
    CaptainProfile,
    LocationUpdate,
    RideRequest,
    Trip,
    TripShare,
    User,
    Vehicle,
)
from app.services.security_utils import hash_share_token, masked_phone

router = APIRouter(tags=["public"])
# Mounted at the application root so shared links are short: /share/<token>
root_router = APIRouter(tags=["public"])


def _share_context(db: Session, token: str) -> dict:
    share = db.scalar(
        select(TripShare).where(TripShare.token_hash == hash_share_token(token))
    )
    if not share or share.revoked_at is not None or share.expires_at <= utcnow():
        raise api_error(404, "share_not_found", "This trip link is invalid or has expired.")
    trip = db.get(Trip, share.trip_id)
    if not trip:
        raise api_error(404, "trip_not_found", "Trip not found.")
    ride = db.get(RideRequest, trip.ride_request_id)
    captain_user = db.get(User, trip.captain_id)
    profile = db.get(CaptainProfile, trip.captain_id)
    vehicle = db.scalar(
        select(Vehicle).where(Vehicle.captain_id == trip.captain_id, Vehicle.is_active.is_(True))
    )
    latest = db.scalars(
        select(LocationUpdate)
        .where(LocationUpdate.trip_id == trip.id)
        .order_by(LocationUpdate.recorded_at.desc())
        .limit(1)
    ).first()
    live = trip.state in {"captain_arriving", "arrived", "in_progress"}
    return {
        "trip": trip,
        "share": share,
        "ride": ride,
        "captain": profile,
        "captain_phone_masked": masked_phone(captain_user.phone) if captain_user else None,
        "vehicle": vehicle,
        "latest": latest,
        "live": live,
    }


@router.get("/public/trips/share/{token}", dependencies=[Depends(rate_limit("share_view", 60, 60))])
def get_shared_trip(token: str, db: Session = Depends(get_db)):
    ctx = _share_context(db, token)
    trip, ride, captain, vehicle, latest, live = (
        ctx["trip"], ctx["ride"], ctx["captain"], ctx["vehicle"], ctx["latest"], ctx["live"],
    )
    return {
        "live": live,
        "trip_state": trip.state,
        "category": ride.category,
        "pickup_area": ride.pickup_address.split(",")[0],
        "drop_area": ride.drop_address.split(",")[0],
        "captain": {
            "name": captain.name if captain else "Not assigned",
            "rating": captain.rating if captain else None,
        },
        "vehicle": {
            "reg_number": vehicle.reg_number,
            "make_model": vehicle.make_model,
        }
        if vehicle
        else None,
        "last_location": {
            "lat": latest.lat,
            "lng": latest.lng,
            "recorded_at": latest.recorded_at,
            "simulated": latest.source == "simulated",
        }
        if latest and live
        else None,
        "started_at": trip.started_at,
        "completed_at": trip.completed_at,
        "expires_at": ctx["share"].expires_at,
        "disclaimer": "Limited live-trip view from Neev. No personal phone numbers are shown.",
    }


@root_router.get("/share/{token}", response_class=HTMLResponse, include_in_schema=False)
def shared_trip_page(token: str):
    safe_token = html.escape(token)
    return HTMLResponse(
        f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Live trip · Neev</title>
<style>
  :root {{ color-scheme: light; --ink:#10201d; --green:#0e4f45; --cream:#f7f5ef; --amber:#f2b544; }}
  * {{ box-sizing: border-box; }}
  body {{ margin:0; font-family:system-ui,-apple-system,'Segoe UI',sans-serif; background:var(--cream); color:var(--ink); }}
  main {{ max-width:480px; margin:0 auto; padding:32px 20px 64px; }}
  .brand {{ font-weight:800; letter-spacing:-0.03em; font-size:22px; }}
  .brand span {{ color:var(--green); }}
  .card {{ background:#fff; border-radius:22px; padding:24px; margin-top:24px; box-shadow:0 12px 36px rgba(16,32,29,.08); }}
  .state {{ display:inline-block; background:#e5f4ee; color:var(--green); padding:6px 12px; border-radius:999px; font-size:13px; font-weight:700; }}
  h1 {{ font-size:26px; line-height:1.2; letter-spacing:-0.02em; margin:16px 0 4px; }}
  .muted {{ color:#61716d; font-size:14px; }}
  .row {{ display:flex; justify-content:space-between; gap:16px; padding:12px 0; border-top:1px solid #edf0ec; font-size:14px; }}
  .row strong {{ text-align:right; }}
  .warn {{ background:#fff6df; border:1px solid #f0d692; border-radius:14px; padding:14px; font-size:13px; margin-top:20px; }}
  .map {{ margin-top:20px; height:180px; border-radius:18px; background:linear-gradient(135deg,#dcece5,#eef4ef); display:flex; align-items:center; justify-content:center; font-size:14px; color:#40534e; text-align:center; padding:20px; }}
</style>
</head>
<body>
<main>
  <div class="brand">neev<span>.</span></div>
  <div class="card" id="card">
    <span class="state" id="state">Loading</span>
    <h1 id="headline">Fetching live trip…</h1>
    <p class="muted" id="sub">This is a limited, read-only trip view.</p>
    <div class="row"><span>Captain</span><strong id="captain">—</strong></div>
    <div class="row"><span>Vehicle</span><strong id="vehicle">—</strong></div>
    <div class="row"><span>Route</span><strong id="route">—</strong></div>
    <div class="row"><span>Updated</span><strong id="updated">—</strong></div>
    <div class="map" id="map">Location appears here while the trip is live.</div>
    <div class="warn">Neev does not contact emergency services from this page. If someone is in danger, call 112.</div>
  </div>
</main>
<script>
const token = {safe_token!r};
const el = (id) => document.getElementById(id);
function render(d) {{
  el('state').textContent = d.live ? 'Live' : (d.trip_state || 'Closed');
  el('headline').textContent = d.live ? 'Trip in progress' : 'Trip ' + (d.trip_state || '');
  el('sub').textContent = d.live ? 'This page refreshes every 10 seconds.' : 'This shared view is no longer live.';
  el('captain').textContent = (d.captain?.name || '—') + (d.captain?.rating ? ' · ' + d.captain.rating + '★' : '');
  el('vehicle').textContent = d.vehicle ? d.vehicle.reg_number + ' · ' + d.vehicle.make_model : '—';
  el('route').textContent = (d.pickup_area || '') + ' → ' + (d.drop_area || '');
  if (d.last_location) {{
    el('map').textContent = (d.last_location.simulated ? 'Simulated GPS · ' : 'GPS · ') + d.last_location.lat.toFixed(5) + ', ' + d.last_location.lng.toFixed(5);
    el('updated').textContent = new Date(d.last_location.recorded_at).toLocaleTimeString();
  }} else {{
    el('updated').textContent = d.expires_at ? 'Link expires ' + new Date(d.expires_at).toLocaleTimeString() : '—';
  }}
}}
async function load() {{
  try {{
    const res = await fetch('/api/v1/public/trips/share/' + encodeURIComponent(token));
    if (!res.ok) throw new Error('unavailable');
    render(await res.json());
  }} catch (e) {{
    el('state').textContent = 'Unavailable';
    el('headline').textContent = 'This link is invalid or has expired';
    el('sub').textContent = 'Ask the rider for a new live-trip link.';
  }}
}}
load();
setInterval(load, 10000);
</script>
</body>
</html>"""
    )
