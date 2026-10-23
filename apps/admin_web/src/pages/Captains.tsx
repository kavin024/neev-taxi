import { useEffect, useState, type ReactNode } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import {
  BadgeCheck,
  Ban,
  Check,
  Eye,
  FileText,
  Search,
  ShieldCheck,
  Star,
  X,
} from 'lucide-react';
import { api, absoluteApiUrl, errorMessage } from '../lib/api';
import { useApi, useDebounced } from '../lib/hooks';
import { useAuth } from '../lib/auth';
import { useToast } from '../components/toast';
import {
  Avatar,
  Button,
  Card,
  ConfirmDialog,
  ErrorNote,
  Field,
  LoadingBlock,
  Modal,
  PageHeader,
  Pagination,
  StatusBadge,
  Tag,
} from '../components/ui';
import type {
  CaptainDetail,
  CaptainDocument,
  CaptainRow,
  Paginated,
} from '../lib/types';
import { categoryLabel, dateLabel, dateTime, money, number, titleCase } from '../lib/format';

export function CaptainsPage() {
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const term = params.get('q') ?? '';
  const status = params.get('status') ?? '';
  const online = params.get('is_online') ?? '';
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

  const { data, error, loading, reload } = useApi<Paginated<CaptainRow>>('/admin/captains', {
    search: term || undefined,
    verification_status: status || undefined,
    is_online: online === '' ? undefined : online === 'true',
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

  return (
    <>
      <PageHeader
        title="Captains"
        subtitle="Verification queue, documents and account standing for every Neev captain."
        actions={
          <Button variant="secondary" onClick={reload} loading={loading}>
            Refresh queue
          </Button>
        }
      />

      <Card>
        <div className="filters">
          <div className="search">
            <Search size={14} />
            <input
              placeholder="Search by name or phone…"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              aria-label="Search captains"
            />
          </div>
          <select
            value={status}
            onChange={(event) => update('status', event.target.value)}
            aria-label="Verification status"
          >
            <option value="">All verification states</option>
            <option value="pending">Pending review</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
            <option value="suspended">Suspended</option>
          </select>
          <select
            value={online}
            onChange={(event) => update('is_online', event.target.value)}
            aria-label="Presence"
          >
            <option value="">Any presence</option>
            <option value="true">Online now</option>
            <option value="false">Offline</option>
          </select>
          <div className="grow" />
          {data && (
            <span className="tiny muted">
              {number(data.total)} captain{data.total === 1 ? '' : 's'}
            </span>
          )}
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
                    <th>Captain</th>
                    <th>Vehicle</th>
                    <th>Verification</th>
                    <th>Presence</th>
                    <th>Rating</th>
                    <th>Docs</th>
                    <th>Joined</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {data?.items.length === 0 && (
                    <tr>
                      <td colSpan={8}>
                        <div className="table-empty">
                          <strong>No captains match these filters</strong>
                          Try clearing the search or verification state.
                        </div>
                      </td>
                    </tr>
                  )}
                  {data?.items.map((captain) => (
                    <tr
                      key={captain.id}
                      className="clickable"
                      onClick={() => navigate(`/captains/${captain.id}`)}
                    >
                      <td>
                        <div className="row">
                          <Avatar name={captain.name} />
                          <div>
                            <div className="cell-main row" style={{ gap: 6 }}>
                              {captain.name}
                              {captain.is_demo && <Tag tone="demo">Demo</Tag>}
                            </div>
                            <div className="cell-sub mono">{captain.phone}</div>
                          </div>
                        </div>
                      </td>
                      <td>
                        <div className="cell-main">{categoryLabel(captain.category)}</div>
                        <div className="cell-sub mono">{captain.vehicle ?? 'No vehicle'}</div>
                      </td>
                      <td>
                        <StatusBadge status={captain.verification_status} />
                      </td>
                      <td>
                        <span className={`badge badge-${captain.is_online ? 'success' : 'neutral'}`}>
                          <span className="dot" />
                          {captain.is_online ? 'Online' : 'Offline'}
                        </span>
                      </td>
                      <td>
                        <div className="row" style={{ gap: 4 }}>
                          <Star size={12} fill="#F2B544" stroke="#F2B544" />
                          <span className="mono">{captain.rating.toFixed(2)}</span>
                          <span className="tiny muted">/ {captain.total_trips} trips</span>
                        </div>
                      </td>
                      <td>
                        {captain.pending_documents > 0 ? (
                          <span className="badge badge-warn">{captain.pending_documents} pending</span>
                        ) : (
                          <span className="tiny muted">—</span>
                        )}
                      </td>
                      <td className="tiny muted">{dateLabel(captain.created_at)}</td>
                      <td className="num">
                        <span className="tiny muted">View →</span>
                      </td>
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

export function CaptainDetailPage() {
  const { id = '' } = useParams();
  const { admin } = useAuth();
  const toast = useToast();
  const { data, loading, error, reload } = useApi<CaptainDetail>(id ? `/admin/captains/${id}` : null);
  const [approving, setApproving] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [suspendOpen, setSuspendOpen] = useState(false);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [docReject, setDocReject] = useState<CaptainDocument | null>(null);
  const [docReason, setDocReason] = useState('');
  const [docBusy, setDocBusy] = useState(false);

  const canWrite = admin?.role === 'admin' || admin?.role === 'super_admin';

  if (loading && !data) return <LoadingBlock label="Loading captain file…" />;
  if (error && !data) return <ErrorNote error={error} onRetry={reload} />;
  if (!data) return null;

  const required: Record<string, string> = {
    driving_license: 'Driving licence',
    vehicle_rc: 'Vehicle RC',
    insurance: 'Insurance',
    profile_photo: 'Profile photo',
  };
  const present = new Set(
    data.documents.filter((doc) => doc.status !== 'rejected').map((doc) => doc.doc_type),
  );
  const missing = Object.keys(required).filter((key) => !present.has(key));
  if (data.vehicles.length === 0) missing.push('vehicle');

  async function decide(approved: boolean) {
    setBusy(true);
    try {
      await api.post(`/admin/captains/${id}/decision`, {
        approved,
        reason: approved ? undefined : reason.trim(),
      });
      toast.success(approved ? 'Captain approved and notified.' : 'Captain rejected. Reason sent to the app.');
      setRejectOpen(false);
      setReason('');
      reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function setSuspended(suspended: boolean) {
    setBusy(true);
    try {
      await api.post(`/admin/captains/${id}/status`, {
        suspended,
        reason: reason.trim() || (suspended ? 'Suspended by operations' : 'Reinstated by operations'),
      });
      toast.success(suspended ? 'Captain suspended and sessions invalidated.' : 'Captain reinstated.');
      setSuspendOpen(false);
      setReason('');
      reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function viewDocument(doc: CaptainDocument) {
    try {
      const link = await api.get<{ url: string; expires_at: string }>(
        `/admin/documents/${doc.id}/link`,
      );
      window.open(absoluteApiUrl(link.url), '_blank', 'noopener,noreferrer');
    } catch (err) {
      toast.error(errorMessage(err));
    }
  }

  async function reviewDocument(doc: CaptainDocument, approved: boolean, why?: string) {
    setDocBusy(true);
    try {
      await api.post(`/admin/captains/${id}/documents/${doc.id}/review`, {
        approved,
        reason: why,
      });
      toast.success(approved ? 'Document approved.' : 'Document rejected and captain notified.');
      setDocReject(null);
      setDocReason('');
      reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setDocBusy(false);
    }
  }

  return (
    <>
      <PageHeader
        title={data.name}
        back={{ to: '/captains', label: 'All captains' }}
        subtitle={
          <span className="row wrap" style={{ gap: 8 }}>
            <StatusBadge status={data.verification_status} />
            <span className={`badge badge-${data.is_online ? 'success' : 'neutral'}`}>
              {data.is_online ? 'Online' : 'Offline'}
            </span>
            {data.is_demo && <Tag tone="demo">Demo account</Tag>}
            <span className="mono">{data.phone}</span>
          </span>
        }
        actions={
          canWrite ? (
            <>
              {data.status === 'suspended' ? (
                <Button
                  onClick={() => {
                    setReason('');
                    setSuspendOpen(true);
                  }}
                >
                  <ShieldCheck size={14} /> Reinstate
                </Button>
              ) : (
                <Button
                  variant="secondary"
                  onClick={() => {
                    setReason('');
                    setSuspendOpen(true);
                  }}
                >
                  <Ban size={14} /> Suspend
                </Button>
              )}
              {data.verification_status !== 'approved' && (
                <Button variant="primary" onClick={() => setApproving(true)}>
                  <BadgeCheck size={14} /> Approve captain
                </Button>
              )}
              <Button
                variant="danger"
                onClick={() => {
                  setReason('');
                  setRejectOpen(true);
                }}
              >
                <X size={14} /> Reject
              </Button>
            </>
          ) : (
            <span className="tag">Read-only access</span>
          )
        }
      />

      {missing.length > 0 && data.verification_status !== 'approved' && (
        <div className="note-box warn" style={{ marginBottom: 16 }}>
          <strong>Approval blocked</strong>
          Missing {missing.map((key) => required[key] ?? 'vehicle').join(', ')}. The server will
          refuse approval until every required document and one vehicle are on file.
        </div>
      )}

      {data.rejection_reason && data.verification_status === 'rejected' && (
        <div className="note-box danger" style={{ marginBottom: 16 }}>
          <strong>Rejection reason on record</strong>
          {data.rejection_reason}
        </div>
      )}

      <Card style={{ marginBottom: 18 }}>
        <div className="detail-header">
          <Avatar name={data.name} size="lg" />
          <div className="grow">
            <div className="detail-name">{data.name}</div>
            <div className="detail-meta">
              <span>
                <Star size={12} fill="#F2B544" stroke="#F2B544" /> {data.rating.toFixed(2)}
              </span>
              <span>·</span>
              <span>{number(data.total_trips)} lifetime trips</span>
              <span>·</span>
              <span>Joined {dateLabel(data.created_at)}</span>
              {data.approved_at && (
                <>
                  <span>·</span>
                  <span>Approved {dateLabel(data.approved_at)}</span>
                </>
              )}
            </div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div className="kpi-label">Lifetime earnings</div>
            <div className="mono" style={{ fontSize: 22, fontWeight: 800, letterSpacing: '-0.5px' }}>
              {data.lifetime_earnings_display}
            </div>
          </div>
        </div>
        <div className="metric-strip">
          <div className="metric">
            <div className="label">Account</div>
            <div className="value" style={{ textTransform: 'capitalize', fontSize: 15 }}>
              {data.status}
            </div>
          </div>
          <div className="metric">
            <div className="label">Vehicles</div>
            <div className="value">{data.vehicles.length}</div>
          </div>
          <div className="metric">
            <div className="label">Documents</div>
            <div className="value">{data.documents.length}</div>
          </div>
        </div>
      </Card>

      <div className="detail-grid">
        <div className="stack">
          <Card>
            <div className="card-head">
              <div>
                <div className="card-title">Documents</div>
                <div className="card-sub">
                  Files are streamed through short-lived, signed links. Review before approval.
                </div>
              </div>
            </div>
            {data.documents.length === 0 ? (
              <div className="table-empty">
                <strong>No documents uploaded</strong>
                The captain must upload licence, RC, insurance and a profile photo.
              </div>
            ) : (
              <div className="doc-list">
                {data.documents.map((doc) => (
                  <div className="doc-row" key={doc.id}>
                    <div className="doc-icon">
                      <FileText size={15} />
                    </div>
                    <div className="grow">
                      <div className="doc-name">
                        {required[doc.doc_type] ?? titleCase(doc.doc_type)}
                      </div>
                      <div className="doc-sub">
                        {doc.original_filename} · {(doc.size_bytes / 1024).toFixed(0)} KB ·{' '}
                        {dateLabel(doc.created_at)}
                      </div>
                      {doc.rejection_reason && (
                        <div className="doc-sub" style={{ color: 'var(--danger)' }}>
                          {doc.rejection_reason}
                        </div>
                      )}
                    </div>
                    <StatusBadge status={doc.status} />
                    <div className="doc-actions">
                      <Button size="sm" onClick={() => viewDocument(doc)}>
                        <Eye size={12} /> View
                      </Button>
                      {canWrite && doc.status !== 'approved' && (
                        <Button
                          size="sm"
                          variant="primary"
                          onClick={() => reviewDocument(doc, true)}
                          disabled={docBusy}
                        >
                          <Check size={12} /> Approve
                        </Button>
                      )}
                      {canWrite && doc.status !== 'rejected' && (
                        <Button
                          size="sm"
                          variant="danger"
                          onClick={() => {
                            setDocReason('');
                            setDocReject(doc);
                          }}
                        >
                          <X size={12} />
                        </Button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </Card>

          <Card>
            <div className="card-head">
              <div>
                <div className="card-title">Recent trips</div>
                <div className="card-sub">Last 50 trips assigned to this captain</div>
              </div>
            </div>
            <div className="table-wrap">
              <table className="data">
                <thead>
                  <tr>
                    <th>Trip</th>
                    <th>State</th>
                    <th>Payment</th>
                    <th className="num">Fare</th>
                    <th>Completed</th>
                  </tr>
                </thead>
                <tbody>
                  {data.trips.length === 0 && (
                    <tr>
                      <td colSpan={5}>
                        <div className="table-empty">
                          <strong>No trips yet</strong>
                          This captain has not completed a Neev trip.
                        </div>
                      </td>
                    </tr>
                  )}
                  {data.trips.map((trip) => (
                    <tr key={trip.id}>
                      <td>
                        <Link
                          to={`/rides/${trip.ride_id}`}
                          className="cell-main"
                          style={{ color: 'var(--green)' }}
                        >
                          {trip.ride_id.slice(0, 10)}…
                        </Link>
                      </td>
                      <td>
                        <StatusBadge status={trip.state} />
                      </td>
                      <td className="tiny muted">{trip.payment_status ?? '—'}</td>
                      <td className="num mono">{money(trip.final_fare_paise)}</td>
                      <td className="tiny muted">
                        {trip.completed_at ? dateTime(trip.completed_at) : '—'}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </div>

        <div className="stack">
          <Card>
            <div className="card-head">
              <div className="card-title">Identity</div>
            </div>
            <div className="card-pad">
              <div className="info-grid">
                <Info label="Phone" value={<span className="mono">{data.phone}</span>} />
                <Info label="Email" value={data.email ?? '—'} />
                <Info label="Driving licence" value={data.dl_masked ?? 'Not provided'} />
                <Info label="PAN" value={data.pan_masked ?? 'Not provided'} />
              </div>
              <div style={{ marginTop: 10 }}>
                <div className="kv">
                  <span className="k">Aadhaar</span>
                  <span className="v">{data.aadhaar_masked ?? 'Not provided'}</span>
                </div>
                <div className="kv">
                  <span className="k">Account state</span>
                  <span className="v" style={{ textTransform: 'capitalize' }}>
                    {data.status}
                  </span>
                </div>
                <div className="kv">
                  <span className="k">Verification</span>
                  <span className="v" style={{ textTransform: 'capitalize' }}>
                    {data.verification_status}
                  </span>
                </div>
              </div>
            </div>
          </Card>

          <Card>
            <div className="card-head">
              <div className="card-title">Vehicles</div>
              <span className="card-actions tag">{data.vehicles.length}</span>
            </div>
            <div className="card-pad" style={{ display: 'grid', gap: 8 }}>
              {data.vehicles.length === 0 && (
                <div className="muted small">No vehicle registered. Approval is blocked.</div>
              )}
              {data.vehicles.map((vehicle) => (
                <div
                  key={vehicle.id}
                  style={{
                    border: '1px solid var(--line)',
                    borderRadius: 11,
                    padding: '10px 12px',
                    opacity: vehicle.is_active ? 1 : 0.55,
                  }}
                >
                  <div className="row-between">
                    <strong style={{ fontSize: 12.5 }}>{vehicle.reg_number}</strong>
                    <StatusBadge status={vehicle.is_active ? 'active' : 'inactive'} />
                  </div>
                  <div className="tiny muted" style={{ marginTop: 2 }}>
                    {categoryLabel(vehicle.category)} · {vehicle.make_model} · {vehicle.color}
                    {vehicle.year ? ` · ${vehicle.year}` : ''}
                  </div>
                </div>
              ))}
            </div>
          </Card>

          <Card className="card-pad">
            <div className="card-title" style={{ marginBottom: 6 }}>
              Operator notes
            </div>
            <p className="small muted" style={{ lineHeight: 1.6 }}>
              Approval notifies the captain over the realtime channel. Suspension increments their
              token version, which invalidates existing sessions immediately.
            </p>
          </Card>
        </div>
      </div>

      <ConfirmDialog
        open={approving}
        title={`Approve ${data.name}?`}
        message={
          missing.length > 0 ? (
            <div className="note-box danger">
              Required records are missing: {missing.join(', ')}. The server will reject this
              approval.
            </div>
          ) : (
            <>
              This marks the captain verified, approves any pending documents, and lets them go
              online to receive offers.
            </>
          )
        }
        confirmLabel="Approve captain"
        busy={busy}
        onConfirm={() => decide(true)}
        onClose={() => setApproving(false)}
      />

      <Modal
        open={rejectOpen}
        onClose={() => setRejectOpen(false)}
        title="Reject captain application"
        subtitle="The reason is shown to the captain in the Neev Captain app."
        footer={
          <>
            <Button onClick={() => setRejectOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant="danger"
              loading={busy}
              disabled={reason.trim().length < 5}
              onClick={() => decide(false)}
            >
              Reject application
            </Button>
          </>
        }
      >
        <Field label="Reason" hint="At least 5 characters. Be specific and actionable.">
          <textarea
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            placeholder="e.g. Insurance certificate expired on 12 Aug 2026."
          />
        </Field>
      </Modal>

      <Modal
        open={suspendOpen}
        onClose={() => setSuspendOpen(false)}
        title={data.status === 'suspended' ? 'Reinstate captain' : 'Suspend captain'}
        subtitle={
          data.status === 'suspended'
            ? 'Restores account access and marks verification approved.'
            : 'Immediately signs the captain out, forces them offline and blocks new offers.'
        }
        footer={
          <>
            <Button onClick={() => setSuspendOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant={data.status === 'suspended' ? 'primary' : 'danger'}
              loading={busy}
              onClick={() => setSuspended(data.status !== 'suspended')}
            >
              {data.status === 'suspended' ? 'Reinstate' : 'Suspend account'}
            </Button>
          </>
        }
      >
        <Field label="Reason" hint="Recorded in the audit log.">
          <textarea
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            placeholder={
              data.status === 'suspended'
                ? 'e.g. Review complete, documents re-verified.'
                : 'e.g. Repeated route deviation reports under investigation.'
            }
          />
        </Field>
      </Modal>

      <Modal
        open={docReject !== null}
        onClose={() => setDocReject(null)}
        title="Reject document"
        subtitle="The captain sees this reason and can upload a replacement."
        footer={
          <>
            <Button onClick={() => setDocReject(null)} disabled={docBusy}>
              Cancel
            </Button>
            <Button
              variant="danger"
              loading={docBusy}
              disabled={docReason.trim().length < 5}
              onClick={() => docReject && reviewDocument(docReject, false, docReason.trim())}
            >
              Reject document
            </Button>
          </>
        }
      >
        <Field label="Reason" hint="At least 5 characters.">
          <textarea
            value={docReason}
            onChange={(event) => setDocReason(event.target.value)}
            placeholder="e.g. Photo is blurred; registration number is unreadable."
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
