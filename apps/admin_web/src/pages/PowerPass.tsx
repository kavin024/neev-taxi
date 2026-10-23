import { useState } from 'react';
import { Pencil, Zap } from 'lucide-react';
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
import type { PowerPassPlan } from '../lib/types';
import { money } from '../lib/format';

interface PlanForm {
  name: string;
  description: string;
  price: string;
  discountPct: string;
  maxDiscount: string;
  rideLimit: string;
  validityDays: string;
  active: boolean;
}

export function PowerPassPage() {
  const { admin } = useAuth();
  const toast = useToast();
  const { data, loading, error, reload } = useApi<PowerPassPlan[]>('/admin/power-pass');
  const [editing, setEditing] = useState<PowerPassPlan | null>(null);
  const [form, setForm] = useState<PlanForm | null>(null);
  const [busy, setBusy] = useState(false);
  const canWrite = admin?.role === 'admin' || admin?.role === 'super_admin';

  function open(plan: PowerPassPlan) {
    setEditing(plan);
    setForm({
      name: plan.name,
      description: plan.description ?? '',
      price: String(plan.price_paise / 100),
      discountPct: String(plan.discount_pct),
      maxDiscount: String(plan.max_discount_paise / 100),
      rideLimit: String(plan.ride_limit),
      validityDays: String(plan.validity_days),
      active: plan.is_active,
    });
  }

  async function save() {
    if (!editing || !form) return;
    setBusy(true);
    try {
      await api.patch(`/admin/power-pass/${editing.id}`, {
        name: form.name,
        description: form.description,
        price_paise: Math.round(Number(form.price) * 100),
        discount_pct: Number(form.discountPct),
        max_discount_paise: Math.round(Number(form.maxDiscount) * 100),
        ride_limit: Number(form.rideLimit),
        validity_days: Number(form.validityDays),
        is_active: form.active,
      });
      toast.success('Power Pass plan updated.');
      setEditing(null);
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
        title="Power Pass"
        subtitle="Prepaid ride passes. Purchases run through the configured payment provider and are labelled sandbox in development."
        actions={
          canWrite ? undefined : <span className="tag">Read-only access</span>
        }
      />

      {error ? (
        <ErrorNote error={error} onRetry={reload} />
      ) : loading && !data ? (
        <LoadingBlock />
      ) : (
        <div className="grid grid-3">
          {data?.map((plan) => (
            <Card key={plan.id} className="card-pad">
              <div className="row-between" style={{ marginBottom: 14 }}>
                <div className="row" style={{ gap: 10 }}>
                  <span className="kpi-icon amber">
                    <Zap size={17} />
                  </span>
                  <div>
                    <div className="card-title">{plan.name}</div>
                    <div className="tiny muted mono">{plan.code}</div>
                  </div>
                </div>
                <StatusBadge status={plan.is_active ? 'active' : 'inactive'} />
              </div>

              <div className="row" style={{ alignItems: 'flex-end', gap: 8 }}>
                <span style={{ fontSize: 30, fontWeight: 800, letterSpacing: '-1.2px' }}>
                  {plan.price_display}
                </span>
                <span className="tiny muted" style={{ paddingBottom: 6 }}>
                  / {plan.validity_days} days
                </span>
              </div>
              <p className="small muted" style={{ marginTop: 6, minHeight: 40 }}>
                {plan.description ?? 'No description.'}
              </p>

              <div className="divider" />
              <div className="kv">
                <span className="k">Discount</span>
                <span className="v">{plan.discount_pct}% off eligible rides</span>
              </div>
              <div className="kv">
                <span className="k">Per-ride cap</span>
                <span className="v">{money(plan.max_discount_paise)}</span>
              </div>
              <div className="kv">
                <span className="k">Ride limit</span>
                <span className="v">{plan.ride_limit} rides</span>
              </div>
              <div className="kv">
                <span className="k">Validity</span>
                <span className="v">{plan.validity_days} days</span>
              </div>

              {canWrite && (
                <Button className="btn-block" style={{ marginTop: 14 }} onClick={() => open(plan)}>
                  <Pencil size={13} /> Edit plan
                </Button>
              )}
            </Card>
          ))}
          {data?.length === 0 && (
            <Card className="card-pad">
              <div className="muted small">No Power Pass plans configured.</div>
            </Card>
          )}
        </div>
      )}

      <Modal
        open={editing !== null && form !== null}
        onClose={() => setEditing(null)}
        title={`Edit ${editing?.name ?? 'plan'}`}
        subtitle="Changes apply to new purchases; existing passes keep their snapshot terms."
        footer={
          <>
            <Button onClick={() => setEditing(null)} disabled={busy}>
              Cancel
            </Button>
            <Button variant="primary" loading={busy} onClick={save}>
              Save plan
            </Button>
          </>
        }
      >
        {form && (
          <>
            <div className="form-grid">
              <Field label="Plan name">
                <input
                  value={form.name}
                  onChange={(event) => setForm({ ...form, name: event.target.value })}
                />
              </Field>
              <Field label="Price (₹)">
                <input
                  type="number"
                  min="0"
                  value={form.price}
                  onChange={(event) => setForm({ ...form, price: event.target.value })}
                />
              </Field>
              <Field label="Description" span2>
                <textarea
                  value={form.description}
                  onChange={(event) => setForm({ ...form, description: event.target.value })}
                />
              </Field>
              <Field label="Discount (%)">
                <input
                  type="number"
                  min="0"
                  max="100"
                  value={form.discountPct}
                  onChange={(event) => setForm({ ...form, discountPct: event.target.value })}
                />
              </Field>
              <Field label="Max discount per ride (₹)">
                <input
                  type="number"
                  min="0"
                  value={form.maxDiscount}
                  onChange={(event) => setForm({ ...form, maxDiscount: event.target.value })}
                />
              </Field>
              <Field label="Ride limit">
                <input
                  type="number"
                  min="1"
                  max="100"
                  value={form.rideLimit}
                  onChange={(event) => setForm({ ...form, rideLimit: event.target.value })}
                />
              </Field>
              <Field label="Validity (days)">
                <input
                  type="number"
                  min="1"
                  max="365"
                  value={form.validityDays}
                  onChange={(event) => setForm({ ...form, validityDays: event.target.value })}
                />
              </Field>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={form.active}
                onChange={(event) => setForm({ ...form, active: event.target.checked })}
              />
              <span className="switch-track" />
              Available for purchase
            </label>
          </>
        )}
      </Modal>
    </>
  );
}
