import { useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { Download, RefreshCw } from 'lucide-react';
import { apiBase, getToken } from '../lib/api';
import { useApi } from '../lib/hooks';
import {
  Card,
  ErrorNote,
  JsonView,
  LoadingBlock,
  PageHeader,
  Pagination,
  StatusBadge,
  Button,
} from '../components/ui';
import type { Paginated, RideDetail, RideRow } from '../lib/types';
import {
  categoryLabel,
  dateTime,
  distanceLabel,
  durationLabel,
  money,
  number,
  relativeTime,
  timeLabel,
  titleCase,
} from '../lib/format';

const STATUS_OPTIONS = ['searching', 'assigned', 'cancelled', 'expired'];

export function RidesPage() {
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const [exporting, setExporting] = useState(false);
  const status = params.get('status') ?? '';
  const category = params.get('category') ?? '';
  const from = params.get('from') ?? '';
  const to = params.get('to') ?? '';
  const page = Math.max(1, Number(params.get('page') ?? '1') || 1);

  const { data, loading, error, reload } = useApi<Paginated<RideRow>>('/admin/rides', {
    status: status || undefined,
    category: category || undefined,
    from_date: from ? `${from}T00:00:00` : undefined,
    to_date: to ? `${to}T23:59:59` : undefined,
    page,
    page_size: 25,
  });

  function update(key: string, value: string) {
    setParams((current) => {
      const next = new URLSearchParams(current);
      if (value) next.set(key, value);
      else next.delete(key);
      next.delete('page');
      return next;
    });
  }

  async function exportCsv() {
    setExporting(true);
    try {
      const response = await fetch(`${apiBase}/api/v1/admin/exports/rides.csv`, {
        headers: { Authorization: `Bearer ${getToken() ?? ''}` },
      });
      if (!response.ok) throw new Error('Export failed');
      const blob = await response.blob();
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement('a');
      anchor.href = url;
      anchor.download = 'neev-rides.csv';
      document.body.appendChild(anchor);
      anchor.click();
      anchor.remove();
      URL.revokeObjectURL(url);
    } catch {
      window.alert('Could not export rides. Check that you are signed in with an operations role.');
    } finally {
      setExporting(false);
    }
  }

  return (
    <>
      <PageHeader
        title="Rides"
        subtitle="Every request with its dispatch state, assigned captain and quoted fare."
        actions={
          <>
            <Button onClick={exportCsv} loading={exporting}>
              <Download size={14} /> Export CSV
            </Button>
            <Button variant="primary" onClick={reload} loading={loading}>
              <RefreshCw size={14} /> Refresh
            </Button>
          </>
        }
      />

      <Card>
        <div className="filters">
          <select value={status} onChange={(event) => update('status', event.target.value)} aria-label="Ride state">
            <option value="">All ride states</option>
            {STATUS_OPTIONS.map((option) => (
              <option key={option} value={option}>
                {titleCase(option)}
              </option>
            ))}
          </select>
          <select
            value={category}
            onChange={(event) => update('category', event.target.value)}
            aria-label="Category"
          >
            <option value="">All categories</option>
            <option value="bike">Bike</option>
            <option value="auto">Auto</option>
            <option value="cab">Cab</option>
          </select>
          <input
            type="date"
            value={from}
            onChange={(event) => update('from', event.target.value)}
            aria-label="From date"
          />
          <span className="tiny muted">to</span>
          <input
            type="date"
            value={to}
            onChange={(event) => update('to', event.target.value)}
            aria-label="To date"
          />
          <div className="grow" />
          {data && <span className="tiny muted">{number(data.total)} rides</span>}
        </div>

        {error ? (
          <div style={{ padding: 18 }}>
            <ErrorNote error={error} onRetry={reload} />
          </div>
        ) : loading && !data ? (
          <LoadingBlock />
        ) : (
          <>
            <div className="table-wrap">
              <table className="data">
                <thead>
                  <tr>
                    <th>Ride</th>
                    <th>Route</th>
                    <th>Category</th>
                    <th>State</th>
                    <th className="num">Quoted fare</th>
                    <th>Passenger</th>
                    <th>Requested</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {data?.items.length === 0 && (
                    <tr>
                      <td colSpan={8}>
                        <div className="table-empty">
                          <strong>No rides match these filters</strong>
                          Adjust the state, category or date range.
                        </div>
                      </td>
                    </tr>
                  )}
                  {data?.items.map((ride) => (
                    <tr
                      key={ride.id}
                      className="clickable"
                      onClick={() => navigate(`/rides/${ride.id}`)}
                    >
                      <td>
                        <div className="cell-main mono">{ride.id.slice(0, 10)}…</div>
                        <div className="cell-sub">{ride.trip_state ? titleCase(ride.trip_state) : 'No trip yet'}</div>
                      </td>
                      <td style={{ maxWidth: 330 }}>
                        <div className="cell-main truncate" style={{ maxWidth: 310 }}>
                          {ride.drop}
                        </div>
                        <div className="cell-sub truncate" style={{ maxWidth: 310 }}>
                          from {ride.pickup}
                        </div>
                      </td>
                      <td>
                        <span className="tag">{categoryLabel(ride.category)}</span>
                      </td>
                      <td>
                        <StatusBadge status={ride.status} />
                      </td>
                      <td className="num mono">{ride.fare_display}</td>
                      <td className="mono tiny">{ride.passenger_id.slice(0, 9)}…</td>
                      <td className="tiny muted">
                        {relativeTime(ride.created_at)}
                        <div className="cell-sub">{dateTime(ride.created_at)}</div>
                      </td>
                      <td className="num tiny muted">View →</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {data && (
              <Pagination
                page={data.page}
                pageSize={data.page_size}
                total={data.total}
                onPage={(next) =>
                  setParams((current) => {
                    const params = new URLSearchParams(current);
                    params.set('page', String(next));
                    return params;
                  })
                }
              />
            )}
          </>
        )}
      </Card>
    </>
  );
}

export function RideDetailPage() {
  const { id = '' } = useParams();
  const { data, loading, error, reload } = useApi<RideDetail>(
    id ? `/admin/rides/${id}` : null,
  );

  if (loading && !data) return <LoadingBlock label="Loading ride record…" />;
  if (error && !data) return <ErrorNote error={error} onRetry={reload} />;
  if (!data) return null;

  const lines =
    (data.fare_breakdown as { lines?: { label: string; amount_paise: number }[] } | null)?.lines ?? [];
  const events = data.events ?? [];
  const points = normalizeRoute(data.route_points);

  const timeline: { label: string; at: string | null; note?: string; danger?: boolean }[] = [
    { label: 'Ride requested', at: data.created_at },
    { label: 'Captain assigned', at: data.assigned_at },
    { label: 'Offer accepted', at: data.trip?.accepted_at ?? null },
    { label: 'Captain arrived', at: data.trip?.arrived_at ?? null },
    { label: 'Trip started with PIN', at: data.trip?.started_at ?? null },
    { label: 'Trip completed', at: data.trip?.completed_at ?? null },
  ];
  if (data.cancelled_at) {
    timeline.push({
      label: `Ride cancelled${data.cancelled_by ? ` by ${data.cancelled_by}` : ''}`,
      at: data.cancelled_at,
      note: data.cancellation_reason ?? undefined,
      danger: true,
    });
  }

  return (
    <>
      <PageHeader
        title={`Ride ${data.id.slice(0, 10)}…`}
        back={{ to: '/rides', label: 'All rides' }}
        subtitle={
          <span className="row wrap" style={{ gap: 8 }}>
            <StatusBadge status={data.status} />
            {data.trip && <StatusBadge status={data.trip.state} />}
            <span className="tag">{categoryLabel(data.category)}</span>
            <span className="tag">{data.payment_method === 'cash' ? 'Cash trip' : 'Prepaid trip'}</span>
            <span className="tiny muted">Requested {dateTime(data.created_at)}</span>
          </span>
        }
        actions={
          <Button onClick={reload} loading={loading}>
            <RefreshCw size={14} /> Refresh record
          </Button>
        }
      />

      <div className="detail-grid">
        <div className="stack">
          <Card>
            <div className="card-head">
              <div>
                <div className="card-title">Route</div>
                <div className="card-sub">
                  {distanceLabel(data.distance_m)} · {durationLabel(data.duration_s)} estimated
                </div>
              </div>
              <div className="card-actions">
                <span className="mono" style={{ fontSize: 18, fontWeight: 800 }}>
                  {data.quoted_fare_display}
                </span>
              </div>
            </div>
            <div className="card-pad">
              <div className="route-box">
                <div className="route-point">
                  <div className="route-rail">
                    <span className="route-dot" />
                    <span className="route-line" />
                  </div>
                  <div className="route-text">
                    <div className="label">Pickup</div>
                    <div className="value">{data.pickup.address}</div>
                    <div className="tiny muted mono">
                      {data.pickup.lat.toFixed(5)}, {data.pickup.lng.toFixed(5)}
                    </div>
                  </div>
                </div>
                <div className="route-point">
                  <div className="route-rail">
                    <span className="route-dot end" />
                  </div>
                  <div className="route-text" style={{ paddingBottom: 0 }}>
                    <div className="label">Drop</div>
                    <div className="value">{data.drop.address}</div>
                    <div className="tiny muted mono">
                      {data.drop.lat.toFixed(5)}, {data.drop.lng.toFixed(5)}
                    </div>
                  </div>
                </div>
              </div>

              {points.length > 1 && <RouteSketch points={points} />}
            </div>
          </Card>

          <Card>
            <div className="card-head">
              <div>
                <div className="card-title">Fare composition</div>
                <div className="card-sub">Stored quote at request time; final fare may differ.</div>
              </div>
            </div>
            <div className="card-pad">
              {lines.length === 0 ? (
                <div className="muted small">No fare lines recorded.</div>
              ) : (
                <>
                  {lines.map((line, index) => (
                    <div className="kv" key={`${line.label}-${index}`}>
                      <span className="k">{line.label}</span>
                      <span className="v">{money(line.amount_paise)}</span>
                    </div>
                  ))}
                  <div className="kv">
                    <span className="k" style={{ fontWeight: 800, color: 'var(--ink)' }}>
                      Quoted total
                    </span>
                    <span className="v" style={{ fontSize: 15 }}>
                      {data.quoted_fare_display}
                    </span>
                  </div>
                  {data.trip?.final_fare_display && (
                    <div className="kv">
                      <span className="k" style={{ fontWeight: 800, color: 'var(--ink)' }}>
                        Final trip fare
                      </span>
                      <span className="v" style={{ fontSize: 15 }}>
                        {data.trip.final_fare_display}
                      </span>
                    </div>
                  )}
                </>
              )}
              {data.discount_paise > 0 && (
                <div className="note-box" style={{ marginTop: 10 }}>
                  Discount applied: {money(data.discount_paise)}
                </div>
              )}
            </div>
          </Card>

          <Card>
            <div className="card-head">
              <div>
                <div className="card-title">Event ledger</div>
                <div className="card-sub">
                  Persisted ride events ({events.length}). Payload is exactly what was written.
                </div>
              </div>
            </div>
            <div className="card-pad" style={{ paddingTop: 10 }}>
              {events.length === 0 ? (
                <div className="muted small">No events recorded for this ride.</div>
              ) : (
                <div className="stack" style={{ gap: 10 }}>
                  {events.map((event) => (
                    <details
                      key={event.event_id}
                      style={{
                        border: '1px solid var(--line)',
                        borderRadius: 10,
                        padding: '9px 11px',
                        background: '#fcfbf7',
                      }}
                    >
                      <summary
                        style={{
                          cursor: 'pointer',
                          fontSize: 12,
                          fontWeight: 700,
                          display: 'flex',
                          gap: 8,
                          alignItems: 'center',
                        }}
                      >
                        <span className="mono tiny muted">#{event.event_id}</span>
                        {titleCase(event.type)}
                        <span className="tiny muted" style={{ marginLeft: 'auto' }}>
                          {timeLabel(event.created_at)}
                        </span>
                      </summary>
                      <div style={{ marginTop: 8 }}>
                        <JsonView value={event.payload} />
                      </div>
                    </details>
                  ))}
                </div>
              )}
            </div>
          </Card>
        </div>

        <div className="stack">
          <Card>
            <div className="card-head">
              <div className="card-title">Trip timeline</div>
            </div>
            <div className="timeline">
              {timeline.map((item) => (
                <div
                  key={item.label}
                  className={`timeline-item ${item.at ? 'done' : ''} ${item.danger ? 'danger' : ''}`}
                >
                  <span className="timeline-dot" />
                  <div>
                    <div className="timeline-title">{item.label}</div>
                    <div className="timeline-time">
                      {item.at ? dateTime(item.at) : 'Not reached'}
                    </div>
                    {item.note && (
                      <div className="tiny" style={{ marginTop: 2, color: 'var(--danger)' }}>
                        {item.note}
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </Card>

          <Card>
            <div className="card-head">
              <div className="card-title">People</div>
            </div>
            <div className="card-pad stack" style={{ gap: 12 }}>
              <div>
                <div className="kpi-label" style={{ marginBottom: 4 }}>
                  Passenger
                </div>
                {data.passenger_id ? (
                  <Link
                    to={`/passengers/${data.passenger_id}`}
                    className="row"
                    style={{ gap: 10 }}
                  >
                    <span className="avatar amber">··</span>
                    <div className="grow">
                      <div style={{ fontSize: 12.5, fontWeight: 700 }}>Passenger record</div>
                      <div className="tiny muted mono">
                        {data.passenger_id.slice(0, 14)}…
                      </div>
                    </div>
                    <span className="tiny muted">Open →</span>
                  </Link>
                ) : (
                  <div className="small muted">Passenger identifier not exposed for this record.</div>
                )}
              </div>

              <div>
                <div className="kpi-label" style={{ marginBottom: 4 }}>
                  Captain
                </div>
                {data.captain ? (
                  <div className="row" style={{ gap: 10 }}>
                    <span className="avatar">{data.captain.name.slice(0, 2).toUpperCase()}</span>
                    <div className="grow">
                      <div style={{ fontSize: 12.5, fontWeight: 700 }}>{data.captain.name}</div>
                      <div className="tiny muted">
                        {data.captain.rating.toFixed(2)} ★ · {data.captain.total_trips} trips
                      </div>
                    </div>
                    <Link
                      to={`/captains/${data.captain.id}`}
                      className="btn btn-secondary btn-sm"
                    >
                      View
                    </Link>
                  </div>
                ) : (
                  <div className="small muted">No captain assigned.</div>
                )}
                {data.vehicle && (
                  <div className="note-box" style={{ marginTop: 8 }}>
                    {data.vehicle.make_model} · {data.vehicle.color} ·{' '}
                    <span className="mono">{data.vehicle.reg_number}</span>
                  </div>
                )}
              </div>
            </div>
          </Card>

          <Card>
            <div className="card-head">
              <div className="card-title">Payment</div>
            </div>
            <div className="card-pad">
              {data.payment ? (
                <>
                  <div className="kv">
                    <span className="k">Status</span>
                    <span className="v">
                      <StatusBadge status={data.payment.status} />
                    </span>
                  </div>
                  <div className="kv">
                    <span className="k">Method</span>
                    <span className="v">{data.payment.method_label}</span>
                  </div>
                  <div className="kv">
                    <span className="k">Amount</span>
                    <span className="v">{data.payment.amount_display}</span>
                  </div>
                  <div className="kv">
                    <span className="k">Provider</span>
                    <span className="v">
                      {data.payment.provider}
                      {data.payment.is_sandbox ? ' (sandbox)' : ''}
                    </span>
                  </div>
                  <div className="kv">
                    <span className="k">Signature</span>
                    <span className="v">{data.payment.signature_verified ? 'Verified' : 'Not verified'}</span>
                  </div>
                  <div className="kv">
                    <span className="k">Created</span>
                    <span className="v">{dateTime(data.payment.created_at)}</span>
                  </div>
                </>
              ) : (
                <div className="small muted">No payment recorded for this ride yet.</div>
              )}
              {data.trip && (
                <div className="note-box" style={{ marginTop: 10 }}>
                  Trip payment status: <strong>{data.trip.payment_status}</strong>
                  {data.trip.drop_verified ? ' · drop verified' : ''}
                </div>
              )}
            </div>
          </Card>

          <Card className="card-pad">
            <div className="card-kv">
              <div className="kpi-label">Ride ID</div>
              <div className="tiny mono" style={{ wordBreak: 'break-all', marginTop: 2 }}>
                {data.id}
              </div>
            </div>
            <div className="divider" />
            <div className="kv">
              <span className="k">Version</span>
              <span className="v mono">{data.version}</span>
            </div>
            <div className="kv">
              <span className="k">Expires</span>
              <span className="v">{data.expires_at ? dateTime(data.expires_at) : '—'}</span>
            </div>
            {data.cancellation_fee_paise > 0 && (
              <div className="kv">
                <span className="k">Cancellation fee</span>
                <span className="v">{data.cancellation_fee_display}</span>
              </div>
            )}
          </Card>
        </div>
      </div>
    </>
  );
}

function normalizeRoute(
  points: [number, number][] | { lat: number; lng: number }[],
): { lat: number; lng: number }[] {
  return points.map((point) =>
    Array.isArray(point) ? { lat: point[0], lng: point[1] } : point,
  );
}

function RouteSketch({ points }: { points: { lat: number; lng: number }[] }) {
  const lats = points.map((point) => point.lat);
  const lngs = points.map((point) => point.lng);
  const minLat = Math.min(...lats);
  const maxLat = Math.max(...lats);
  const minLng = Math.min(...lngs);
  const maxLng = Math.max(...lngs);
  const spanLat = maxLat - minLat || 0.001;
  const spanLng = maxLng - minLng || 0.001;
  const path = points
    .map((point, index) => {
      const x = 16 + ((point.lng - minLng) / spanLng) * 728;
      const y = 104 - ((point.lat - minLat) / spanLat) * 88;
      return `${index === 0 ? 'M' : 'L'} ${x.toFixed(1)} ${y.toFixed(1)}`;
    })
    .join(' ');
  const first = points[0];
  const last = points[points.length - 1];

  return (
    <div className="map-strip" style={{ marginTop: 14, height: 140 }}>
      <svg viewBox="0 0 760 140" preserveAspectRatio="none" aria-label="Recorded route geometry">
        <rect width="760" height="140" fill="#eaf0ea" />
        {[20, 50, 80, 110].map((y) => (
          <line key={y} x1="0" y1={y} x2="760" y2={y} stroke="#dce6df" strokeWidth="1" />
        ))}
        {[100, 220, 340, 460, 580, 700].map((x) => (
          <line key={x} x1={x} y1="0" x2={x} y2="140" stroke="#dce6df" strokeWidth="1" />
        ))}
        <path d={path} fill="none" stroke="#0E4F45" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" opacity="0.85" />
        <circle
          cx={16 + ((first.lng - minLng) / spanLng) * 728}
          cy={104 - ((first.lat - minLat) / spanLat) * 88}
          r="6"
          fill="#0E4F45"
          stroke="#fff"
          strokeWidth="2.5"
        />
        <circle
          cx={16 + ((last.lng - minLng) / spanLng) * 728}
          cy={104 - ((last.lat - minLat) / spanLat) * 88}
          r="6"
          fill="#F2B544"
          stroke="#fff"
          strokeWidth="2.5"
        />
      </svg>
      <span className="map-label">
        Recorded route geometry · {points.length} points
      </span>
    </div>
  );
}
