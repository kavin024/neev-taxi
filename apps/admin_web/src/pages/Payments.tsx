import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { Check, RefreshCw, RotateCcw, X } from 'lucide-react';
import { api, errorMessage } from '../lib/api';
import { useApi } from '../lib/hooks';
import { useAuth } from '../lib/auth';
import { useToast } from '../components/toast';
import {
  Button,
  Card,
  ErrorNote,
  Field,
  LoadingBlock,
  Modal,
  PageHeader,
  Pagination,
  StatusBadge,
  Tabs,
  Tag,
} from '../components/ui';
import type { Paginated, PaymentRow, RefundRow } from '../lib/types';
import { dateTime, number, relativeTime, titleCase } from '../lib/format';

export function PaymentsPage() {
  const [params, setParams] = useSearchParams();
  const { admin } = useAuth();
  const toast = useToast();
  const tab = params.get('tab') === 'refunds' ? 'refunds' : 'payments';
  const status = params.get('status') ?? '';
  const page = Math.max(1, Number(params.get('page') ?? '1') || 1);

  const payments = useApi<Paginated<PaymentRow>>('/admin/payments', {
    status: status || undefined,
    page,
    page_size: 25,
  });
  const refunds = useApi<RefundRow[]>('/admin/refunds', {
    status: tab === 'refunds' ? status || undefined : undefined,
  });

  const [decision, setDecision] = useState<{ refund: RefundRow; approve: boolean } | null>(null);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);

  const canWrite = admin?.role === 'admin' || admin?.role === 'super_admin';

  function setTab(next: string) {
    setParams((current) => {
      const params = new URLSearchParams(current);
      if (next === 'refunds') params.set('tab', 'refunds');
      else params.delete('tab');
      params.delete('status');
      params.delete('page');
      return params;
    });
  }

  function setStatus(next: string) {
    setParams((current) => {
      const params = new URLSearchParams(current);
      if (next) params.set('status', next);
      else params.delete('status');
      params.delete('page');
      return params;
    });
  }

  async function decideRefund() {
    if (!decision) return;
    setBusy(true);
    try {
      await api.post(`/admin/refunds/${decision.refund.id}/decision`, {
        decision: decision.approve ? 'approve' : 'reject',
        note: note.trim(),
      });
      toast.success(
        decision.approve
          ? 'Refund approved and sent to the payment provider.'
          : 'Refund request rejected.',
      );
      setDecision(null);
      setNote('');
      refunds.reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <PageHeader
        title="Payments & refunds"
        subtitle="Provider transactions, verification state and refund decisions. Sandbox entries are labelled."
        actions={
          <Button
            onClick={() => {
              payments.reload();
              refunds.reload();
            }}
            loading={payments.loading || refunds.loading}
          >
            <RefreshCw size={14} /> Refresh
          </Button>
        }
      />

      <Card>
        <Tabs
          value={tab}
          onChange={setTab}
          tabs={[
            { id: 'payments', label: 'Transactions', count: payments.data?.total },
            { id: 'refunds', label: 'Refund requests', count: refunds.data?.length },
          ]}
        />

        {tab === 'payments' ? (
          <>
            <div className="filters">
              <select value={status} onChange={(event) => setStatus(event.target.value)} aria-label="Payment status">
                <option value="">All payment states</option>
                <option value="created">Created</option>
                <option value="captured">Captured</option>
                <option value="pending">Pending</option>
                <option value="failed">Failed</option>
                <option value="refunded">Refunded</option>
              </select>
              <div className="grow" />
              {payments.data && (
                <span className="tiny muted">{number(payments.data.total)} transactions</span>
              )}
            </div>

            {payments.error ? (
              <div style={{ padding: 18 }}>
                <ErrorNote error={payments.error} onRetry={payments.reload} />
              </div>
            ) : payments.loading && !payments.data ? (
              <LoadingBlock />
            ) : (
              <>
                <div className="table-wrap">
                  <table className="data">
                    <thead>
                      <tr>
                        <th>Transaction</th>
                        <th>Purpose</th>
                        <th className="num">Amount</th>
                        <th>Method</th>
                        <th>Status</th>
                        <th>Sandbox</th>
                        <th>Created</th>
                      </tr>
                    </thead>
                    <tbody>
                      {payments.data?.items.length === 0 && (
                        <tr>
                          <td colSpan={7}>
                            <div className="table-empty">
                              <strong>No payments match this filter</strong>
                              Try another state.
                            </div>
                          </td>
                        </tr>
                      )}
                      {payments.data?.items.map((payment) => (
                        <tr key={payment.id}>
                          <td>
                            <div className="cell-main mono">{payment.id.slice(0, 12)}…</div>
                            <div className="cell-sub mono">user {payment.user_id.slice(0, 8)}…</div>
                          </td>
                          <td>
                            <div className="cell-main">{titleCase(payment.purpose)}</div>
                            {payment.ride_request_id && (
                              <Link
                                to={`/rides/${payment.ride_request_id}`}
                                className="cell-sub"
                                style={{ color: 'var(--green)' }}
                              >
                                ride {payment.ride_request_id.slice(0, 8)}…
                              </Link>
                            )}
                          </td>
                          <td className="num mono">{payment.amount_display}</td>
                          <td>
                            <div className="cell-main">{titleCase(payment.method)}</div>
                            <div className="cell-sub">{payment.provider}</div>
                          </td>
                          <td>
                            <StatusBadge status={payment.status} />
                          </td>
                          <td>
                            {payment.sandbox ? (
                              <Tag tone="demo">Sandbox</Tag>
                            ) : (
                              <span className="tiny muted">Live</span>
                            )}
                          </td>
                          <td className="tiny muted">{dateTime(payment.created_at)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {payments.data && (
                  <Pagination
                    page={payments.data.page}
                    pageSize={payments.data.page_size}
                    total={payments.data.total}
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
          </>
        ) : (
          <>
            <div className="filters">
              <select value={status} onChange={(event) => setStatus(event.target.value)} aria-label="Refund status">
                <option value="">All refund states</option>
                <option value="requested">Requested</option>
                <option value="approved">Approved</option>
                <option value="processed">Processed</option>
                <option value="rejected">Rejected</option>
              </select>
              <div className="grow" />
              {refunds.data && <span className="tiny muted">{refunds.data.length} requests</span>}
            </div>

            {refunds.error ? (
              <div style={{ padding: 18 }}>
                <ErrorNote error={refunds.error} onRetry={refunds.reload} />
              </div>
            ) : refunds.loading && !refunds.data ? (
              <LoadingBlock />
            ) : (
              <div className="table-wrap">
                <table className="data">
                  <thead>
                    <tr>
                      <th>Refund</th>
                      <th>Reason</th>
                      <th className="num">Amount</th>
                      <th>Status</th>
                      <th>Requested</th>
                      <th>Admin note</th>
                      <th />
                    </tr>
                  </thead>
                  <tbody>
                    {refunds.data?.length === 0 && (
                      <tr>
                        <td colSpan={7}>
                          <div className="table-empty">
                            <strong>No refunds in this state</strong>
                            Refund requests raised by passengers or support appear here.
                          </div>
                        </td>
                      </tr>
                    )}
                    {refunds.data?.map((refund) => (
                      <tr key={refund.id}>
                        <td>
                          <div className="cell-main mono">{refund.id.slice(0, 11)}…</div>
                          {refund.ride_request_id && (
                            <Link
                              to={`/rides/${refund.ride_request_id}`}
                              className="cell-sub"
                              style={{ color: 'var(--green)' }}
                            >
                              ride {refund.ride_request_id.slice(0, 8)}…
                            </Link>
                          )}
                        </td>
                        <td style={{ maxWidth: 280 }}>
                          <div className="small">{refund.reason}</div>
                        </td>
                        <td className="num mono">{refund.amount_display}</td>
                        <td>
                          <StatusBadge status={refund.status} />
                        </td>
                        <td className="tiny muted">
                          {relativeTime(refund.created_at)}
                          <div className="cell-sub">{dateTime(refund.created_at)}</div>
                        </td>
                        <td className="tiny muted" style={{ maxWidth: 220 }}>
                          {refund.admin_note ?? '—'}
                        </td>
                        <td className="num">
                          {refund.status === 'requested' && canWrite && (
                            <div className="cell-actions">
                              <Button
                                size="sm"
                                variant="primary"
                                onClick={() => {
                                  setNote('');
                                  setDecision({ refund, approve: true });
                                }}
                              >
                                <Check size={12} /> Approve
                              </Button>
                              <Button
                                size="sm"
                                variant="danger"
                                onClick={() => {
                                  setNote('');
                                  setDecision({ refund, approve: false });
                                }}
                              >
                                <X size={12} /> Reject
                              </Button>
                            </div>
                          )}
                          {refund.status === 'requested' && !canWrite && (
                            <span className="tiny muted">Read-only</span>
                          )}
                          {refund.provider_refund_id && (
                            <div className="tiny muted mono" style={{ marginTop: 3 }}>
                              {refund.provider_refund_id}
                            </div>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </>
        )}
      </Card>

      <div className="note-box" style={{ marginTop: 16 }}>
        <strong>Provider behaviour is honest</strong>
        Sandbox payments settle locally through a signed sandbox flow. If Razorpay is selected but
        not configured, refund decisions fail with an explicit provider error instead of pretending
        to succeed.
      </div>

      <Modal
        open={decision !== null}
        onClose={() => setDecision(null)}
        title={decision?.approve ? 'Approve refund' : 'Reject refund'}
        subtitle={
          decision
            ? `${decision.refund.amount_display} · ${decision.refund.reason}`
            : undefined
        }
        footer={
          <>
            <Button onClick={() => setDecision(null)} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant={decision?.approve ? 'primary' : 'danger'}
              loading={busy}
              disabled={note.trim().length < 3}
              onClick={decideRefund}
            >
              <RotateCcw size={13} /> {decision?.approve ? 'Approve refund' : 'Reject refund'}
            </Button>
          </>
        }
      >
        <Field
          label="Decision note"
          hint="Visible in the audit trail. At least 3 characters; the passenger is notified."
        >
          <textarea
            value={note}
            onChange={(event) => setNote(event.target.value)}
            placeholder={
              decision?.approve
                ? 'e.g. Captain cancelled after arrival; full refund approved.'
                : 'e.g. Trip completed and drop verified; refund not applicable.'
            }
          />
        </Field>
        {decision?.approve && (
          <div className="note-box warn">
            Approving sends the refund through the configured provider. In sandbox mode this settles
            locally and is labelled as sandbox in the customer record.
          </div>
        )}
      </Modal>
    </>
  );
}
