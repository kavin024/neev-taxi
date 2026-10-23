import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { Eye, ScrollText } from 'lucide-react';
import { useApi } from '../lib/hooks';
import {
  Button,
  Card,
  ErrorNote,
  JsonView,
  LoadingBlock,
  Modal,
  PageHeader,
  Pagination,
} from '../components/ui';
import type { AuditLog, Paginated } from '../lib/types';
import { dateTime, number, titleCase } from '../lib/format';

export function AuditPage() {
  const [params, setParams] = useSearchParams();
  const entityType = params.get('entity_type') ?? '';
  const action = params.get('action') ?? '';
  const page = Math.max(1, Number(params.get('page') ?? '1') || 1);
  const { data, loading, error, reload } = useApi<Paginated<AuditLog>>('/admin/audit-logs', {
    entity_type: entityType || undefined,
    action: action || undefined,
    page,
    page_size: 50,
  });
  const [selected, setSelected] = useState<AuditLog | null>(null);

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
        title="Audit trail"
        subtitle="Append-only operator actions. Includes before and after snapshots, request ID and source address."
        actions={
          <Button onClick={reload} loading={loading}>
            Refresh trail
          </Button>
        }
      />

      <Card>
        <div className="filters">
          <select
            value={entityType}
            onChange={(event) => update('entity_type', event.target.value)}
            aria-label="Entity type"
          >
            <option value="">All entity types</option>
            <option value="captain_profile">Captain profile</option>
            <option value="captain_document">Captain document</option>
            <option value="pricing_rule">Pricing rule</option>
            <option value="service_category">Service category</option>
            <option value="coupon">Coupon</option>
            <option value="power_pass_plan">Power Pass plan</option>
            <option value="support_ticket">Support ticket</option>
            <option value="refund">Refund</option>
            <option value="payout_request">Payout request</option>
            <option value="service_area">Service area</option>
            <option value="app_setting">App setting</option>
            <option value="user">User</option>
            <option value="safety_incident">Safety incident</option>
            <option value="admin_user">Admin user</option>
          </select>
          <input
            value={action}
            onChange={(event) => update('action', event.target.value)}
            placeholder="Exact action, e.g. captain.approve"
            aria-label="Action"
            style={{ minWidth: 240 }}
          />
          <div className="grow" />
          {data && <span className="tiny muted">{number(data.total)} entries</span>}
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
                    <th>#</th>
                    <th>When</th>
                    <th>Actor</th>
                    <th>Action</th>
                    <th>Entity</th>
                    <th>Source</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {data?.items.length === 0 && (
                    <tr>
                      <td colSpan={7}>
                        <div className="table-empty">
                          <div className="empty-icon" style={{ margin: '0 auto 10px' }}>
                            <ScrollText size={20} />
                          </div>
                          <strong>No audit entries match</strong>
                          Clear the action filter or try another entity type.
                        </div>
                      </td>
                    </tr>
                  )}
                  {data?.items.map((entry) => (
                    <tr key={entry.id}>
                      <td className="mono tiny muted">{entry.id}</td>
                      <td className="tiny">{dateTime(entry.created_at)}</td>
                      <td>
                        <div className="cell-main" style={{ textTransform: 'capitalize' }}>
                          {entry.actor_type}
                        </div>
                        <div className="cell-sub mono">{entry.actor_id.slice(0, 10)}…</div>
                      </td>
                      <td>
                        <span className="tag">{entry.action}</span>
                      </td>
                      <td>
                        <div className="cell-main">{titleCase(entry.entity_type)}</div>
                        <div className="cell-sub mono">
                          {entry.entity_id ? `${entry.entity_id.slice(0, 12)}…` : '—'}
                        </div>
                      </td>
                      <td className="tiny muted mono">{entry.ip_address ?? '—'}</td>
                      <td className="num">
                        <Button size="sm" onClick={() => setSelected(entry)}>
                          <Eye size={12} /> Inspect
                        </Button>
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

      <Modal
        open={selected !== null}
        onClose={() => setSelected(null)}
        title={selected?.action ?? 'Audit entry'}
        subtitle={
          selected
            ? `${titleCase(selected.entity_type)} · ${selected.entity_id ?? 'no entity id'}`
            : undefined
        }
        wide
        footer={<Button onClick={() => setSelected(null)}>Close</Button>}
      >
        {selected && (
          <>
            <div className="info-grid">
              <div className="info-item">
                <div className="label">Actor</div>
                <div className="value">
                  {selected.actor_type} · {selected.actor_id}
                </div>
              </div>
              <div className="info-item">
                <div className="label">When</div>
                <div className="value">{dateTime(selected.created_at)}</div>
              </div>
              <div className="info-item">
                <div className="label">Request ID</div>
                <div className="value mono tiny">{selected.request_id ?? '—'}</div>
              </div>
              <div className="info-item">
                <div className="label">Source IP</div>
                <div className="value mono tiny">{selected.ip_address ?? '—'}</div>
              </div>
            </div>
            <div>
              <div className="section-title">Before</div>
              <JsonView value={selected.before} />
            </div>
            <div>
              <div className="section-title">After</div>
              <JsonView value={selected.after} />
            </div>
          </>
        )}
      </Modal>
    </>
  );
}
