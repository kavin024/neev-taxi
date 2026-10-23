import { useEffect, useState, type ReactNode } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { Ban, Search, ShieldCheck, Star } from 'lucide-react';
import { api, errorMessage } from '../lib/api';
import { useApi, useDebounced } from '../lib/hooks';
import { useAuth } from '../lib/auth';
import { useToast } from '../components/toast';
import {
  Avatar,
  Button,
  Card,
  ErrorNote,
  Field,
  LoadingBlock,
  Modal,
  PageHeader,
  Pagination,
  StatusBadge,
  Tag,
} from '../components/ui';
import type { Paginated, PassengerDetail, PassengerRow } from '../lib/types';
import { categoryLabel, dateLabel, dateTime, number } from '../lib/format';

export function PassengersPage() {
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const term = params.get('q') ?? '';
  const status = params.get('status') ?? '';
  const page = Math.max(1, Number(params.get('page') ?? '1') || 1);
  const [search, setSearch] = useState(term);
  const debounced = useDebounced(search);

  useEffect(() => {
    if (debounced === term) return;
    setParams((current) => {
      const next = new URLSearchParams(current);
      if (debounced) next.set('q', debounced);
      else next.delete('q');
      next.delete('page');
      return next;
    });
  }, [debounced, term, setParams]);

  const { data, loading, error, reload } = useApi<Paginated<PassengerRow>>('/admin/passengers', {
    search: term || undefined,
    status: status || undefined,
    page,
    page_size: 25,
  });

  return (
    <>
      <PageHeader
        title="Passengers"
        subtitle="Accounts, activity and standing. Phone numbers are masked in list views by the API."
        actions={
          <Button onClick={reload} loading={loading}>
            Refresh
          </Button>
        }
      />

      <Card>
        <div className="filters">
          <div className="search">
            <Search size={14} />
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search by phone or passenger ID…"
              aria-label="Search passengers"
            />
          </div>
          <select
            value={status}
            onChange={(event) =>
              setParams((current) => {
                const next = new URLSearchParams(current);
                if (event.target.value) next.set('status', event.target.value);
                else next.delete('status');
                next.delete('page');
                return next;
              })
            }
            aria-label="Account status"
          >
            <option value="">All account states</option>
            <option value="active">Active</option>
            <option value="suspended">Suspended</option>
          </select>
          <div className="grow" />
          {data && <span className="tiny muted">{number(data.total)} accounts</span>}
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
                    <th>Passenger</th>
                    <th>Status</th>
                    <th>Rides</th>
                    <th>Rating</th>
                    <th>Joined</th>
                    <th>Last login</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {data?.items.length === 0 && (
                    <tr>
                      <td colSpan={7}>
                        <div className="table-empty">
                          <strong>No passengers found</strong>
                          Try a different search.
                        </div>
                      </td>
                    </tr>
                  )}
                  {data?.items.map((row) => (
                    <tr
                      key={row.id}
                      className="clickable"
                      onClick={() => navigate(`/passengers/${row.id}`)}
                    >
                      <td>
                        <div className="row">
                          <Avatar name={row.name ?? row.masked_phone} amber />
                          <div>
                            <div className="cell-main row" style={{ gap: 6 }}>
                              {row.name || 'Unnamed passenger'}
                              {row.is_demo && <Tag tone="demo">Demo</Tag>}
                            </div>
                            <div className="cell-sub mono">{row.masked_phone}</div>
                          </div>
                        </div>
                      </td>
                      <td>
                        <StatusBadge status={row.status} />
                      </td>
                      <td className="mono">{number(row.total_rides)}</td>
                      <td>
                        {row.rating === null ? (
                          <span className="tiny muted">No ratings</span>
                        ) : (
                          <span className="row" style={{ gap: 4 }}>
                            <Star size={12} fill="#F2B544" stroke="#F2B544" />
                            <span className="mono">{row.rating.toFixed(2)}</span>
                          </span>
                        )}
                      </td>
                      <td className="tiny muted">{dateLabel(row.created_at)}</td>
                      <td className="tiny muted">
                        {row.last_login_at ? dateTime(row.last_login_at) : 'Never'}
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

export function PassengerDetailPage() {
  const { id = '' } = useParams();
  const { admin } = useAuth();
  const toast = useToast();
  const { data, loading, error, reload } = useApi<PassengerDetail>(
    id ? `/admin/passengers/${id}` : null,
  );
  const [suspendOpen, setSuspendOpen] = useState(false);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);

  const canWrite = admin?.role === 'admin' || admin?.role === 'super_admin';

  if (loading && !data) return <LoadingBlock label="Loading passenger…" />;
  if (error && !data) return <ErrorNote error={error} onRetry={reload} />;
  if (!data) return null;

  const profile = data.passenger;

  async function toggleStatus(suspended: boolean) {
    setBusy(true);
    try {
      await api.post(`/admin/passengers/${id}/status`, {
        suspended,
        reason: reason.trim() || (suspended ? 'Suspended by operations' : 'Reinstated by operations'),
      });
      toast.success(suspended ? 'Passenger suspended.' : 'Passenger reinstated.');
      setSuspendOpen(false);
      setReason('');
      reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <PageHeader
        title={data.name || 'Passenger'}
        back={{ to: '/passengers', label: 'All passengers' }}
        subtitle={
          <span className="row wrap" style={{ gap: 8 }}>
            <StatusBadge status={data.status} />
            {data.is_demo && <Tag tone="demo">Demo account</Tag>}
            <span className="mono">{data.phone}</span>
            <span className="tiny muted">ID {data.id.slice(0, 12)}…</span>
          </span>
        }
        actions={
          canWrite ? (
            <Button
              variant={data.status === 'suspended' ? 'primary' : 'danger'}
              onClick={() => {
                setReason('');
                setSuspendOpen(true);
              }}
            >
              {data.status === 'suspended' ? <ShieldCheck size={14} /> : <Ban size={14} />}
              {data.status === 'suspended' ? 'Reinstate account' : 'Suspend account'}
            </Button>
          ) : (
            <span className="tag">Read-only access</span>
          )
        }
      />

      <Card style={{ marginBottom: 18 }}>
        <div className="detail-header">
          <Avatar name={data.name ?? data.phone} src={profile?.photo_url} size="lg" amber />
          <div className="grow">
            <div className="detail-name">{data.name || 'Unnamed passenger'}</div>
            <div className="detail-meta">
              <span>{profile?.email || 'No email on file'}</span>
              <span>·</span>
              <span>Joined {dateLabel(data.created_at)}</span>
              <span>·</span>
              <span>{data.phone_verified ? 'Phone verified' : 'Phone unverified'}</span>
            </div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div className="kpi-label">Lifetime rides</div>
            <div className="mono" style={{ fontSize: 24, fontWeight: 800 }}>
              {number(profile?.total_rides ?? 0)}
            </div>
          </div>
        </div>
        <div className="metric-strip">
          <div className="metric">
            <div className="label">Rating</div>
            <div className="value">
              {profile?.rating !== null && profile?.rating !== undefined ? (
                <span className="row" style={{ gap: 4 }}>
                  <Star size={13} fill="#F2B544" stroke="#F2B544" />
                  {profile.rating.toFixed(2)}
                </span>
              ) : (
                '—'
              )}
            </div>
          </div>
          <div className="metric">
            <div className="label">Home area</div>
            <div className="value" style={{ fontSize: 14 }}>
              {profile?.home_area ?? 'Not set'}
            </div>
          </div>
          <div className="metric">
            <div className="label">Support tickets</div>
            <div className="value">{data.tickets.length}</div>
          </div>
        </div>
      </Card>

      <div className="detail-grid">
        <Card>
          <div className="card-head">
            <div>
              <div className="card-title">Ride history</div>
              <div className="card-sub">Most recent 50 requests</div>
            </div>
          </div>
          <div className="table-wrap">
            <table className="data">
              <thead>
                <tr>
                  <th>Ride</th>
                  <th>Route</th>
                  <th>State</th>
                  <th className="num">Fare</th>
                  <th>Requested</th>
                </tr>
              </thead>
              <tbody>
                {data.rides.length === 0 && (
                  <tr>
                    <td colSpan={5}>
                      <div className="table-empty">
                        <strong>No rides yet</strong>
                        This passenger has not requested a trip.
                      </div>
                    </td>
                  </tr>
                )}
                {data.rides.map((ride) => (
                  <tr key={ride.id}>
                    <td>
                      <Link
                        to={`/rides/${ride.id}`}
                        className="cell-main"
                        style={{ color: 'var(--green)' }}
                      >
                        {categoryLabel(ride.category)}
                      </Link>
                      <div className="cell-sub mono">{ride.id.slice(0, 9)}…</div>
                    </td>
                    <td style={{ maxWidth: 300 }}>
                      <div className="cell-main truncate" style={{ maxWidth: 280 }}>
                        {ride.drop.address}
                      </div>
                      <div className="cell-sub truncate" style={{ maxWidth: 280 }}>
                        from {ride.pickup.address}
                      </div>
                    </td>
                    <td>
                      <StatusBadge status={ride.trip?.state ?? ride.status} />
                    </td>
                    <td className="num mono">{ride.quoted_fare_display}</td>
                    <td className="tiny muted">{dateTime(ride.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>

        <div className="stack">
          <Card>
            <div className="card-head">
              <div className="card-title">Identity</div>
            </div>
            <div className="card-pad">
              <div className="info-grid">
                <Info label="Phone" value={<span className="mono">{data.phone}</span>} />
                <Info label="Role" value="Passenger" />
                <Info label="Email" value={profile?.email ?? '—'} />
                <Info label="Status" value={data.status} />
              </div>
              <div className="note-box" style={{ marginTop: 12 }}>
                Wallet balance and payments belong to the account ledger. Use the payments desk for
                transaction-level questions.
              </div>
            </div>
          </Card>

          <Card>
            <div className="card-head">
              <div className="card-title">Support tickets</div>
            </div>
            <div className="card-pad" style={{ display: 'grid', gap: 8 }}>
              {data.tickets.length === 0 && (
                <div className="muted small">No support tickets raised.</div>
              )}
              {data.tickets.map((ticket) => (
                <Link
                  key={ticket.id}
                  to={`/tickets?ticket=${ticket.id}`}
                  className="row-between"
                  style={{
                    border: '1px solid var(--line)',
                    borderRadius: 10,
                    padding: '9px 11px',
                  }}
                >
                  <div style={{ minWidth: 0 }}>
                    <div className="truncate" style={{ fontSize: 12, fontWeight: 700 }}>
                      {ticket.subject}
                    </div>
                    <div className="tiny muted">{dateLabel(ticket.created_at)}</div>
                  </div>
                  <StatusBadge status={ticket.status} />
                </Link>
              ))}
            </div>
          </Card>
        </div>
      </div>

      <Modal
        open={suspendOpen}
        onClose={() => setSuspendOpen(false)}
        title={data.status === 'suspended' ? 'Reinstate passenger' : 'Suspend passenger'}
        subtitle={
          data.status === 'suspended'
            ? 'Restores access to Neev Ride.'
            : 'Signs the passenger out everywhere and blocks new ride requests.'
        }
        footer={
          <>
            <Button onClick={() => setSuspendOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant={data.status === 'suspended' ? 'primary' : 'danger'}
              loading={busy}
              onClick={() => toggleStatus(data.status !== 'suspended')}
            >
              {data.status === 'suspended' ? 'Reinstate' : 'Suspend account'}
            </Button>
          </>
        }
      >
        <Field label="Reason" hint="Recorded in the audit trail.">
          <textarea
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            placeholder={
              data.status === 'suspended'
                ? 'e.g. Appeal reviewed and accepted.'
                : 'e.g. Chargeback investigation, repeated abusive behaviour.'
            }
          />
        </Field>
      </Modal>
    </>
  );
}

function Info({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="info-item">
      <div className="label">{label}</div>
      <div className="value">{value}</div>
    </div>
  );
}
