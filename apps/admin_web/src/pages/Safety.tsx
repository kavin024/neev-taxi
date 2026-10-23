import { useState } from 'react';
import { Link } from 'react-router-dom';
import { AlertTriangle, CheckCircle2, MapPin, ShieldAlert } from 'lucide-react';
import { api, errorMessage } from '../lib/api';
import { useApi } from '../lib/hooks';
import { useToast } from '../components/toast';
import {
  Button,
  Card,
  ErrorNote,
  Field,
  LoadingBlock,
  Modal,
  PageHeader,
  StatusBadge,
} from '../components/ui';
import type { SafetyIncident } from '../lib/types';
import { dateTime, number, relativeTime } from '../lib/format';

export function SafetyPage() {
  const toast = useToast();
  const [status, setStatus] = useState('');
  const { data, loading, error, reload } = useApi<SafetyIncident[]>('/admin/safety-incidents', {
    status: status || undefined,
  });
  const [resolving, setResolving] = useState<SafetyIncident | null>(null);
  const [resolution, setResolution] = useState('');
  const [busy, setBusy] = useState(false);

  async function resolve() {
    if (!resolving) return;
    setBusy(true);
    try {
      await api.post(`/admin/safety-incidents/${resolving.id}/resolve`, {
        resolution: resolution.trim(),
      });
      toast.success('Incident resolved and the passenger notified.');
      setResolving(null);
      setResolution('');
      reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  const openCount = (data ?? []).filter((row) => row.status === 'active').length;

  return (
    <>
      <PageHeader
        title="Safety incidents"
        subtitle="SOS records raised from the passenger app. These are human-reviewed; the platform does not call emergency services automatically."
        actions={
          <Button onClick={reload} loading={loading}>
            Refresh incidents
          </Button>
        }
      />

      <div className="grid grid-3" style={{ marginBottom: 18 }}>
        <Card className="card-pad">
          <div className="row" style={{ gap: 10 }}>
            <span className="kpi-icon danger">
              <ShieldAlert size={17} />
            </span>
            <div>
              <div className="kpi-label">Active now</div>
              <div className="kpi-value small-value" style={{ marginTop: 4 }}>
                {openCount}
              </div>
            </div>
          </div>
        </Card>
        <Card className="card-pad">
          <div className="kpi-label">Contacts notified</div>
          <div className="kpi-value small-value" style={{ marginTop: 8 }}>
            {number((data ?? []).reduce((sum, row) => sum + row.contacts_notified, 0))}
          </div>
          <div className="kpi-foot">SMS dispatches through the configured provider</div>
        </Card>
        <Card className="card-pad">
          <div className="kpi-label">Incidents in view</div>
          <div className="kpi-value small-value" style={{ marginTop: 8 }}>
            {number(data?.length ?? 0)}
          </div>
          <div className="kpi-foot">Latest 100 matching records</div>
        </Card>
      </div>

      <Card>
        <div className="filters">
          <select value={status} onChange={(event) => setStatus(event.target.value)} aria-label="Incident status">
            <option value="">All incidents</option>
            <option value="active">Active</option>
            <option value="resolved">Resolved</option>
            <option value="cancelled">Cancelled</option>
          </select>
          <div className="grow" />
          <span className="tiny muted">Active incidents need a human response.</span>
        </div>

        {error ? (
          <div style={{ padding: 18 }}>
            <ErrorNote error={error} onRetry={reload} />
          </div>
        ) : loading && !data ? (
          <LoadingBlock />
        ) : data?.length === 0 ? (
          <div className="empty" style={{ padding: 64 }}>
            <div className="empty-icon">
              {status === 'active' ? <CheckCircle2 size={20} /> : <AlertTriangle size={20} />}
            </div>
            <strong>No incidents in this view</strong>
            <p>Nothing needs attention right now. New SOS records appear here immediately.</p>
          </div>
        ) : (
          <div className="table-wrap">
            <table className="data">
              <thead>
                <tr>
                  <th>Incident</th>
                  <th>Account</th>
                  <th>Location</th>
                  <th>Notifications</th>
                  <th>Status</th>
                  <th>Raised</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {data?.map((incident) => (
                  <tr key={incident.id}>
                    <td>
                      <div className="cell-main mono">{incident.id.slice(0, 11)}…</div>
                      {incident.ride_request_id && (
                        <Link
                          to={`/rides/${incident.ride_request_id}`}
                          className="cell-sub"
                          style={{ color: 'var(--green)' }}
                        >
                          ride {incident.ride_request_id.slice(0, 8)}…
                        </Link>
                      )}
                    </td>
                    <td className="mono tiny">{incident.user_id.slice(0, 12)}…</td>
                    <td>
                      {incident.lat !== null && incident.lng !== null ? (
                        <a
                          href={`https://www.openstreetmap.org/?mlat=${incident.lat}&mlon=${incident.lng}#map=16/${incident.lat}/${incident.lng}`}
                          target="_blank"
                          rel="noreferrer"
                          className="row"
                          style={{ gap: 4, fontSize: 11.5, color: 'var(--green)' }}
                        >
                          <MapPin size={12} />
                          <span className="mono">
                            {incident.lat.toFixed(5)}, {incident.lng.toFixed(5)}
                          </span>
                        </a>
                      ) : (
                        <span className="tiny muted">No coordinates</span>
                      )}
                    </td>
                    <td>
                      <div className="cell-main">{incident.contacts_notified} contacts</div>
                      <div className="cell-sub">
                        {incident.emergency_services_contacted
                          ? 'Emergency services contacted'
                          : 'Emergency services not contacted'}
                      </div>
                    </td>
                    <td>
                      <StatusBadge status={incident.status} />
                    </td>
                    <td className="tiny muted">
                      {relativeTime(incident.created_at)}
                      <div className="cell-sub">{dateTime(incident.created_at)}</div>
                    </td>
                    <td className="num">
                      {incident.status === 'active' ? (
                        <Button
                          size="sm"
                          variant="primary"
                          onClick={() => {
                            setResolution('');
                            setResolving(incident);
                          }}
                        >
                          Resolve
                        </Button>
                      ) : incident.resolution ? (
                        <span className="tiny muted" style={{ maxWidth: 180, display: 'inline-block' }}>
                          {incident.resolution}
                        </span>
                      ) : (
                        <span className="tiny muted">—</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <div className="note-box danger" style={{ marginTop: 16 }}>
        <strong>Safety escalation is manual</strong>
        Neev notifies the passenger&apos;s trusted contacts when an SOS is raised and records the
        incident here. It does not silently dial emergency services. In a real emergency, call local
        emergency services (112 in India).
      </div>

      <Modal
        open={resolving !== null}
        onClose={() => setResolving(null)}
        title="Resolve safety incident"
        subtitle={
          resolving
            ? `Raised ${dateTime(resolving.created_at)} · ${resolving.contacts_notified} contacts notified`
            : undefined
        }
        footer={
          <>
            <Button onClick={() => setResolving(null)} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant="primary"
              loading={busy}
              disabled={resolution.trim().length < 3}
              onClick={resolve}
            >
              Mark resolved
            </Button>
          </>
        }
      >
        <div className="note-box">
          Record what the operator actually did. Do not claim emergency services were contacted unless
          that happened.
        </div>
        <Field label="Resolution note" hint="Shared with the passenger. At least 3 characters.">
          <textarea
            value={resolution}
            onChange={(event) => setResolution(event.target.value)}
            placeholder="e.g. Called passenger, confirmed safe, ride completed. No emergency services required."
          />
        </Field>
      </Modal>
    </>
  );
}
