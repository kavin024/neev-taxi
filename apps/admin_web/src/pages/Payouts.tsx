import { useState } from 'react';
import { Check, RefreshCw, Send, X } from 'lucide-react';
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
  StatusBadge,
} from '../components/ui';
import type { PayoutRow } from '../lib/types';
import { dateTime, money, relativeTime, titleCase } from '../lib/format';

type Decision = 'approve' | 'reject' | 'complete' | 'fail';

export function PayoutsPage() {
  const { admin } = useAuth();
  const toast = useToast();
  const [status, setStatus] = useState('');
  const { data, loading, error, reload } = useApi<PayoutRow[]>('/admin/payouts', {
    status: status || undefined,
  });
  const [action, setAction] = useState<{ payout: PayoutRow; decision: Decision } | null>(null);
  const [note, setNote] = useState('');
  const [reference, setReference] = useState('');
  const [busy, setBusy] = useState(false);
  const canWrite = admin?.role === 'admin' || admin?.role === 'super_admin';

  async function submit() {
    if (!action) return;
    setBusy(true);
    try {
      await api.post(`/admin/payouts/${action.payout.id}/decision`, {
        decision: action.decision,
        note: note.trim() || undefined,
        provider_reference: action.decision === 'complete' ? reference.trim() || undefined : undefined,
      });
      toast.success(`Payout ${action.decision === 'complete' ? 'marked paid' : action.decision + 'd'}.`);
      setAction(null);
      setNote('');
      setReference('');
      reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  const pendingTotal = (data ?? [])
    .filter((row) => ['requested', 'approved', 'processing'].includes(row.status))
    .reduce((sum, row) => sum + row.amount_paise, 0);

  return (
    <>
      <PageHeader
        title="Captain payouts"
        subtitle="Withdrawal requests backed by captain earnings. Approving does not move money; completing records the external transfer."
        actions={
          <Button onClick={reload} loading={loading}>
            <RefreshCw size={14} /> Refresh
          </Button>
        }
      />

      <div className="grid grid-3" style={{ marginBottom: 18 }}>
        <Card className="card-pad">
          <div className="kpi-label">Open payout value</div>
          <div className="kpi-value small-value" style={{ marginTop: 8 }}>
            {money(pendingTotal)}
          </div>
          <div className="kpi-foot">Requested, approved or processing</div>
        </Card>
        <Card className="card-pad">
          <div className="kpi-label">Requests shown</div>
          <div className="kpi-value small-value" style={{ marginTop: 8 }}>
            {data?.length ?? 0}
          </div>
          <div className="kpi-foot">Latest 100 matching requests</div>
        </Card>
        <Card className="card-pad">
          <div className="kpi-label">Settlement mode</div>
          <div className="kpi-value small-value" style={{ marginTop: 8, fontSize: 18 }}>
            Manual approval
          </div>
          <div className="kpi-foot">Provider reference recorded by the operator</div>
        </Card>
      </div>

      <Card>
        <div className="filters">
          <select value={status} onChange={(event) => setStatus(event.target.value)} aria-label="Payout status">
            <option value="">All payout states</option>
            <option value="requested">Requested</option>
            <option value="approved">Approved</option>
            <option value="processing">Processing</option>
            <option value="completed">Completed</option>
            <option value="rejected">Rejected</option>
            <option value="failed">Failed</option>
          </select>
          <div className="grow" />
          <span className="tiny muted">Holds are reversed automatically on rejection or failure.</span>
        </div>

        {error ? (
          <div style={{ padding: 18 }}>
            <ErrorNote error={error} onRetry={reload} />
          </div>
        ) : loading && !data ? (
          <LoadingBlock />
        ) : (
          <div className="table-wrap">
            <table className="data">
              <thead>
                <tr>
                  <th>Payout</th>
                  <th>Captain</th>
                  <th className="num">Amount</th>
                  <th>Destination</th>
                  <th>Status</th>
                  <th>Requested</th>
                  <th>Processed</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {data?.length === 0 && (
                  <tr>
                    <td colSpan={8}>
                      <div className="table-empty">
                        <strong>No payout requests in this state</strong>
                        Captain withdrawal requests appear here for review.
                      </div>
                    </td>
                  </tr>
                )}
                {data?.map((payout) => (
                  <tr key={payout.id}>
                    <td>
                      <div className="cell-main mono">{payout.id.slice(0, 10)}…</div>
                      <div className="cell-sub">{titleCase(payout.method)}</div>
                    </td>
                    <td className="mono tiny">{payout.captain_id.slice(0, 10)}…</td>
                    <td className="num mono">{payout.amount_display}</td>
                    <td className="tiny mono">{payout.destination_masked}</td>
                    <td>
                      <StatusBadge status={payout.status} />
                    </td>
                    <td className="tiny muted">
                      {relativeTime(payout.requested_at)}
                      <div className="cell-sub">{dateTime(payout.requested_at)}</div>
                    </td>
                    <td className="tiny muted">
                      {payout.processed_at ? dateTime(payout.processed_at) : '—'}
                      {payout.admin_note && (
                        <div className="cell-sub" style={{ maxWidth: 180 }}>
                          {payout.admin_note}
                        </div>
                      )}
                    </td>
                    <td className="num">
                      {canWrite && ['requested', 'approved', 'processing'].includes(payout.status) && (
                        <div className="cell-actions">
                          {payout.status === 'requested' && (
                            <Button
                              size="sm"
                              onClick={() => {
                                setNote('');
                                setAction({ payout, decision: 'approve' });
                              }}
                            >
                              <Check size={12} /> Approve
                            </Button>
                          )}
                          <Button
                            size="sm"
                            variant="primary"
                            onClick={() => {
                              setNote('');
                              setReference('');
                              setAction({ payout, decision: 'complete' });
                            }}
                          >
                            <Send size={12} /> Mark paid
                          </Button>
                          <Button
                            size="sm"
                            variant="danger"
                            onClick={() => {
                              setNote('');
                              setAction({ payout, decision: 'reject' });
                            }}
                          >
                            <X size={12} />
                          </Button>
                        </div>
                      )}
                      {!canWrite && <span className="tiny muted">Read-only</span>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <div className="note-box" style={{ marginTop: 16 }}>
        <strong>No automatic bank transfer</strong>
        Neev records the decision and an operator-supplied provider reference. It does not claim a
        bank transfer occurred unless a payments provider integration is configured and confirms it.
      </div>

      <Modal
        open={action !== null}
        onClose={() => setAction(null)}
        title={
          action?.decision === 'approve'
            ? 'Approve payout request'
            : action?.decision === 'complete'
              ? 'Mark payout as paid'
              : action?.decision === 'fail'
                ? 'Mark payout failed'
                : 'Reject payout request'
        }
        subtitle={
          action
            ? `${action.payout.amount_display} to ${action.payout.destination_masked}`
            : undefined
        }
        footer={
          <>
            <Button onClick={() => setAction(null)} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant={action?.decision === 'reject' || action?.decision === 'fail' ? 'danger' : 'primary'}
              loading={busy}
              onClick={submit}
            >
              Confirm
            </Button>
          </>
        }
      >
        {action?.decision === 'complete' && (
          <Field
            label="Provider reference"
            hint="UTR, bank reference or payout provider ID. Optional in manual mode."
          >
            <input
              value={reference}
              onChange={(event) => setReference(event.target.value)}
              placeholder="e.g. HDFC-UTR-88231902"
            />
          </Field>
        )}
        <Field
          label="Operator note"
          hint="Stored on the payout and written to the audit trail."
        >
          <textarea
            value={note}
            onChange={(event) => setNote(event.target.value)}
            placeholder={
              action?.decision === 'complete'
                ? 'e.g. Transferred via manual bank run; reference attached.'
                : 'e.g. Bank details failed verification; captain asked to re-submit.'
            }
          />
        </Field>
        {action?.decision === 'reject' && (
          <div className="note-box danger">
            Rejecting reverses the earnings hold so the captain can request again with corrected
            details.
          </div>
        )}
      </Modal>
    </>
  );
}
