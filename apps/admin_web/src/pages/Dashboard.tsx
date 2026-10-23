import { useState, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import {
  ArrowUpRight,
  CarFront,
  CheckCircle2,
  IdCard,
  IndianRupee,
  LifeBuoy,
  Percent,
  Radio,
  RefreshCw,
  ShieldAlert,
  Users,
} from 'lucide-react';
import { useApi } from '../lib/hooks';
import type { DashboardData, RefundRow, SafetyIncident } from '../lib/types';
import { categoryLabel, compactMoney, money, number, relativeTime } from '../lib/format';
import { RideChart } from '../components/Charts';
import {
  Card,
  ErrorNote,
  LoadingBlock,
  PageHeader,
  StatusBadge,
  Button,
} from '../components/ui';

export function DashboardPage() {
  const [days, setDays] = useState(7);
  const [metric, setMetric] = useState<'rides' | 'gmv'>('rides');
  const { data, error, loading, reload } = useApi<DashboardData>('/admin/dashboard', { days });
  const { data: refunds } = useApi<RefundRow[]>('/admin/refunds', { status: 'requested' });
  const { data: incidents } = useApi<SafetyIncident[]>('/admin/safety-incidents');

  if (loading && !data) return <LoadingBlock label="Loading command centre…" />;
  if (error && !data) return <ErrorNote error={error} onRetry={reload} />;
  if (!data) return null;

  const k = data.kpis;
  const maxCategory = Math.max(...data.category_breakdown.map((row) => row.rides), 1);
  const unresolvedIncidents = (incidents ?? []).filter(
    (incident) => !['resolved', 'cancelled'].includes(incident.status),
  ).length;
  const pendingRefunds = refunds?.length ?? 0;

  return (
    <>
      <PageHeader
        title="Command centre"
        subtitle={
          <>
            Live operational picture across dispatch, verification, money and support.{' '}
            <span className="muted">Generated {relativeTime(data.generated_at)}.</span>
          </>
        }
        actions={
          <>
            <div className="segmented" aria-label="Dashboard window">
              {[7, 14, 30].map((value) => (
                <button
                  key={value}
                  type="button"
                  className={days === value ? 'active' : ''}
                  onClick={() => setDays(value)}
                >
                  {value}d
                </button>
              ))}
            </div>
            <Button onClick={reload} loading={loading}>
              <RefreshCw size={14} /> Refresh
            </Button>
          </>
        }
      />

      {data.demo_data_present && (
        <div className="note-box warn" style={{ marginBottom: 18 }}>
          <strong>Demo dataset in use</strong>
          This database contains seeded demo accounts and trips. Figures below are real aggregates of
          those records, not production traffic.
        </div>
      )}

      <div className="kpi-grid">
        <Kpi
          label="Rides requested today"
          value={number(k.rides_today)}
          icon={<CarFront size={17} />}
          foot={
            <>
              <CheckCircle2 size={12} /> {number(k.completed_today)} completed today
            </>
          }
          to="/rides"
        />
        <Kpi
          label="Active rides"
          value={number(k.active_rides)}
          icon={<Radio size={17} />}
          tone="info"
          foot="Arriving, arrived or in progress"
          to="/rides?status=assigned"
        />
        <Kpi
          label="Captains online"
          value={number(k.online_captains)}
          icon={<Users size={17} />}
          foot={`${number(k.pending_captain_approvals)} awaiting verification`}
          to="/captains?is_online=true"
        />
        <Kpi
          label="Payments captured today"
          value={k.captured_payments_today_display}
          small
          icon={<IndianRupee size={17} />}
          tone="amber"
          foot={`${k.platform_commission_today_display} platform commission`}
          to="/payments"
        />
        <Kpi
          label="Pending approvals"
          value={number(k.pending_captain_approvals)}
          icon={<IdCard size={17} />}
          tone={k.pending_captain_approvals > 0 ? 'amber' : 'default'}
          foot="Captain documents to review"
          to="/captains?status=pending"
        />
        <Kpi
          label="Open tickets"
          value={number(k.open_tickets)}
          icon={<LifeBuoy size={17} />}
          tone={k.open_tickets > 0 ? 'danger' : 'default'}
          foot="Open or awaiting passenger"
          to="/tickets?status=open"
        />
        <Kpi
          label="Refunds to decide"
          value={number(pendingRefunds)}
          icon={<Percent size={17} />}
          foot="Requested, not yet processed"
          to="/payments?tab=refunds&status=requested"
        />
        <Kpi
          label="Safety incidents"
          value={number(unresolvedIncidents)}
          icon={<ShieldAlert size={17} />}
          tone={unresolvedIncidents > 0 ? 'danger' : 'default'}
          foot="Unresolved SOS records"
          to="/safety"
        />
      </div>

      <div className="grid dashboard-split">
        <Card>
          <div className="chart-card">
            <div className="chart-head">
              <div className="grow">
                <div className="card-title">Ride demand</div>
                <div className="card-sub">
                  {days}-day request volume and gross booking value from live ride records.
                </div>
              </div>
              <div className="segmented">
                <button
                  type="button"
                  className={metric === 'rides' ? 'active' : ''}
                  onClick={() => setMetric('rides')}
                >
                  Rides
                </button>
                <button
                  type="button"
                  className={metric === 'gmv' ? 'active' : ''}
                  onClick={() => setMetric('gmv')}
                >
                  GMV
                </button>
              </div>
            </div>
            <RideChart series={data.ride_series} metric={metric} />
            <div className="row-between" style={{ padding: '6px 2px 10px', flexWrap: 'wrap' }}>
              <div className="chart-legend">
                <span>
                  <span className="legend-dot" style={{ background: 'var(--green)' }} />
                  {metric === 'rides' ? 'Requests per day' : 'Quoted GMV per day'}
                </span>
                <span>
                  <span className="legend-dot" style={{ background: 'var(--amber)' }} />
                  Hover for detail
                </span>
              </div>
              <span className="tiny muted">{data.sources}</span>
            </div>
          </div>
        </Card>

        <div className="stack">
          <Card>
            <div className="card-head">
              <div>
                <div className="card-title">Category mix</div>
                <div className="card-sub">Share of requests in this window</div>
              </div>
            </div>
            <div className="card-pad" style={{ paddingTop: 12 }}>
              {data.category_breakdown.length === 0 && (
                <div className="muted small">No rides requested yet.</div>
              )}
              {data.category_breakdown.map((row) => (
                <div className="breakdown-row" key={row.category}>
                  <span className="breakdown-label">{categoryLabel(row.category)}</span>
                  <span className="breakdown-track">
                    <span
                      className="breakdown-fill"
                      style={{ width: `${Math.max(4, (row.rides / maxCategory) * 100)}%` }}
                    />
                  </span>
                  <span className="breakdown-value">{row.rides}</span>
                </div>
              ))}
            </div>
          </Card>

          <Card>
            <div className="card-head">
              <div>
                <div className="card-title">Needs attention</div>
                <div className="card-sub">Queues that block a good ride</div>
              </div>
            </div>
            <div className="card-pad" style={{ paddingTop: 8, display: 'grid', gap: 2 }}>
              <AttentionRow
                label="Captain approvals"
                value={k.pending_captain_approvals}
                to="/captains?status=pending"
              />
              <AttentionRow label="Support tickets" value={k.open_tickets} to="/tickets?status=open" />
              <AttentionRow
                label="Refund requests"
                value={pendingRefunds}
                to="/payments?tab=refunds&status=requested"
              />
              <AttentionRow label="Safety incidents" value={unresolvedIncidents} to="/safety" />
            </div>
          </Card>
        </div>
      </div>

      <div className="grid grid-3" style={{ marginTop: 18 }}>
        <Card className="card-pad">
          <div className="row-between" style={{ marginBottom: 10 }}>
            <div className="card-title">Ride integrity</div>
            <StatusBadge status="active" label="Enforced" />
          </div>
          <p className="small muted" style={{ lineHeight: 1.6 }}>
            Acceptance is a single conditional write. A ride can be claimed exactly once, offers
            expire automatically, and every state change is persisted to the ride event log.
          </p>
          <Link to="/rides" className="back-link" style={{ marginTop: 12, marginBottom: 0 }}>
            Inspect the ride ledger <ArrowUpRight size={13} />
          </Link>
        </Card>
        <Card className="card-pad">
          <div className="row-between" style={{ marginBottom: 10 }}>
            <div className="card-title">Money trail</div>
            <StatusBadge status="captured" label="Ledger" />
          </div>
          <p className="small muted" style={{ lineHeight: 1.6 }}>
            Cash, sandbox and provider payments post to a double-entry ledger. Payout holds are
            reversed when a request is rejected or fails.
          </p>
          <Link
            to="/payments"
            className="back-link"
            style={{ marginTop: 12, marginBottom: 0 }}
          >
            Open payments <ArrowUpRight size={13} />
          </Link>
        </Card>
        <Card className="card-pad">
          <div className="row-between" style={{ marginBottom: 10 }}>
            <div className="card-title">Today at a glance</div>
            <span className="tiny muted mono">{money(k.captured_payments_today_paise)}</span>
          </div>
          <div className="stack" style={{ gap: 4 }}>
            <div className="row-between small">
              <span className="muted">Commission</span>
              <strong className="mono">{k.platform_commission_today_display}</strong>
            </div>
            <div className="row-between small">
              <span className="muted">Completed trips</span>
              <strong className="mono">{number(k.completed_today)}</strong>
            </div>
            <div className="row-between small">
              <span className="muted">GMV (7d)</span>
              <strong className="mono">
                {compactMoney(data.ride_series.reduce((sum, row) => sum + row.gmv_paise, 0))}
              </strong>
            </div>
          </div>
        </Card>
      </div>
    </>
  );
}

function Kpi({
  label,
  value,
  icon,
  foot,
  tone = 'default',
  small,
  to,
}: {
  label: string;
  value: string;
  icon: ReactNode;
  foot: ReactNode;
  tone?: 'default' | 'amber' | 'danger' | 'info';
  small?: boolean;
  to?: string;
}) {
  const content = (
    <div className="kpi">
      <div className="kpi-top">
        <span className="kpi-label">{label}</span>
        <span className={`kpi-icon ${tone === 'default' ? '' : tone}`}>{icon}</span>
      </div>
      <div className={`kpi-value ${small ? 'small-value' : ''}`}>{value}</div>
      <div className="kpi-foot">{foot}</div>
    </div>
  );
  return to ? (
    <Link to={to} style={{ display: 'block' }}>
      {content}
    </Link>
  ) : (
    content
  );
}

function AttentionRow({ label, value, to }: { label: string; value: number; to: string }) {
  return (
    <Link
      to={to}
      className="row-between"
      style={{
        padding: '10px 2px',
        borderBottom: '1px solid #f0eee6',
        fontSize: 12.5,
        fontWeight: 700,
      }}
    >
      <span>{label}</span>
      <span className="row" style={{ gap: 8 }}>
        <span className={`badge ${value > 0 ? 'badge-warn' : 'badge-success'}`}>{value}</span>
        <ArrowUpRight size={13} style={{ color: 'var(--muted)' }} />
      </span>
    </Link>
  );
}
