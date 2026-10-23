import { useState } from 'react';
import { Check, Pencil, Plus } from 'lucide-react';
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
  Tabs,
} from '../components/ui';
import type { PricingRule, ServiceCategory } from '../lib/types';
import { categoryLabel, dateLabel, percent } from '../lib/format';

interface RuleForm {
  base: string;
  minimum: string;
  perKm: string;
  perMinute: string;
  waiting: string;
  cancellation: string;
  platform: string;
  commission: string;
  night: string;
  active: boolean;
}

const emptyRuleForm: RuleForm = {
  base: '25',
  minimum: '40',
  perKm: '11',
  perMinute: '1.50',
  waiting: '2',
  cancellation: '20',
  platform: '5',
  commission: '18',
  night: '1.15',
  active: true,
};

function formFromRule(rule: PricingRule): RuleForm {
  return {
    base: String(rule.base_fare_paise / 100),
    minimum: String(rule.minimum_fare_paise / 100),
    perKm: String(rule.per_km_paise / 100),
    perMinute: String(rule.per_minute_paise / 100),
    waiting: String(rule.waiting_per_minute_paise / 100),
    cancellation: String(rule.cancellation_fee_paise / 100),
    platform: String(rule.platform_fee_paise / 100),
    commission: String(rule.commission_pct),
    night: String(rule.night_multiplier),
    active: rule.is_active,
  };
}

function toPaise(value: string): number {
  return Math.round(Number(value) * 100);
}

export function PricingPage() {
  const { admin } = useAuth();
  const toast = useToast();
  const [tab, setTab] = useState<'pricing' | 'categories'>('pricing');
  const pricing = useApi<PricingRule[]>('/admin/pricing');
  const categories = useApi<ServiceCategory[]>('/admin/categories');
  const [editRule, setEditRule] = useState<PricingRule | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [category, setCategory] = useState<'bike' | 'auto' | 'cab'>('bike');
  const [form, setForm] = useState<RuleForm>(emptyRuleForm);
  const [categoryEdit, setCategoryEdit] = useState<ServiceCategory | null>(null);
  const [busy, setBusy] = useState(false);

  const canWrite = admin?.role === 'admin' || admin?.role === 'super_admin';

  function openEdit(rule: PricingRule) {
    setForm(formFromRule(rule));
    setEditRule(rule);
  }

  async function saveRule() {
    if (!editRule) return;
    setBusy(true);
    try {
      await api.patch(`/admin/pricing/${editRule.id}`, {
        base_fare_paise: toPaise(form.base),
        minimum_fare_paise: toPaise(form.minimum),
        per_km_paise: toPaise(form.perKm),
        per_minute_paise: toPaise(form.perMinute),
        waiting_per_minute_paise: toPaise(form.waiting),
        cancellation_fee_paise: toPaise(form.cancellation),
        platform_fee_paise: toPaise(form.platform),
        commission_pct: Number(form.commission),
        night_multiplier: Number(form.night),
        is_active: form.active,
      });
      toast.success('Pricing rule updated. New quotes use this version immediately.');
      setEditRule(null);
      pricing.reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function createRule() {
    setBusy(true);
    try {
      await api.post('/admin/pricing', {
        category,
        base_fare_paise: toPaise(form.base),
        minimum_fare_paise: toPaise(form.minimum),
        per_km_paise: toPaise(form.perKm),
        per_minute_paise: toPaise(form.perMinute),
        waiting_per_minute_paise: toPaise(form.waiting),
        cancellation_fee_paise: toPaise(form.cancellation),
        platform_fee_paise: toPaise(form.platform),
        commission_pct: Number(form.commission),
        night_multiplier: Number(form.night),
        is_active: form.active,
      });
      toast.success(`${categoryLabel(category)} pricing rule created.`);
      setCreateOpen(false);
      pricing.reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function saveCategory() {
    if (!categoryEdit) return;
    setBusy(true);
    try {
      await api.patch(`/admin/categories/${categoryEdit.id}`, {
        display_name: categoryEdit.display_name,
        description: categoryEdit.description,
        capacity: categoryEdit.capacity,
        is_active: categoryEdit.is_active,
        sort_order: categoryEdit.sort_order,
      });
      toast.success('Service category updated.');
      setCategoryEdit(null);
      categories.reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <PageHeader
        title="Pricing & categories"
        subtitle="Fare rules are versioned. Every edit creates a new version used by subsequent quotes."
        actions={
          canWrite ? (
            <Button
              variant="primary"
              onClick={() => {
                setForm(emptyRuleForm);
                setCreateOpen(true);
              }}
            >
              <Plus size={14} /> New pricing rule
            </Button>
          ) : (
            <span className="tag">Read-only access</span>
          )
        }
      />

      <Card>
        <Tabs
          value={tab}
          onChange={(value) => setTab(value as 'pricing' | 'categories')}
          tabs={[
            { id: 'pricing', label: 'Fare rules', count: pricing.data?.length },
            { id: 'categories', label: 'Service categories', count: categories.data?.length },
          ]}
        />

        {tab === 'pricing' ? (
          <>
            {pricing.error ? (
              <div style={{ padding: 18 }}>
                <ErrorNote error={pricing.error} onRetry={pricing.reload} />
              </div>
            ) : pricing.loading && !pricing.data ? (
              <LoadingBlock />
            ) : (
              <div className="table-wrap">
                <table className="data">
                  <thead>
                    <tr>
                      <th>Category</th>
                      <th className="num">Base</th>
                      <th className="num">Minimum</th>
                      <th className="num">Per km</th>
                      <th className="num">Per min</th>
                      <th className="num">Platform fee</th>
                      <th className="num">Commission</th>
                      <th className="num">Night ×</th>
                      <th>Status</th>
                      <th>Effective</th>
                      <th />
                    </tr>
                  </thead>
                  <tbody>
                    {pricing.data?.length === 0 && (
                      <tr>
                        <td colSpan={11}>
                          <div className="table-empty">
                            <strong>No pricing rules configured</strong>
                            Create one to enable quotes for a category.
                          </div>
                        </td>
                      </tr>
                    )}
                    {pricing.data?.map((rule) => (
                      <tr key={rule.id}>
                        <td>
                          <div className="cell-main">{categoryLabel(rule.category)}</div>
                          <div className="cell-sub">
                            v{rule.version}
                            {rule.service_area_id ? ' · area-specific' : ' · global'}
                          </div>
                        </td>
                        <td className="num mono">₹{(rule.base_fare_paise / 100).toFixed(0)}</td>
                        <td className="num mono">₹{(rule.minimum_fare_paise / 100).toFixed(0)}</td>
                        <td className="num mono">₹{(rule.per_km_paise / 100).toFixed(2)}</td>
                        <td className="num mono">₹{(rule.per_minute_paise / 100).toFixed(2)}</td>
                        <td className="num mono">₹{(rule.platform_fee_paise / 100).toFixed(0)}</td>
                        <td className="num mono">{percent(rule.commission_pct, 0)}</td>
                        <td className="num mono">{rule.night_multiplier.toFixed(2)}×</td>
                        <td>
                          <StatusBadge status={rule.is_active ? 'active' : 'inactive'} />
                        </td>
                        <td className="tiny muted">{dateLabel(rule.effective_from)}</td>
                        <td className="num">
                          {canWrite && (
                            <Button size="sm" onClick={() => openEdit(rule)}>
                              <Pencil size={12} /> Edit
                            </Button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <div className="card-pad muted tiny" style={{ borderTop: '1px solid var(--line)' }}>
              Fare = base + distance + time + platform fee, with a minimum-fare floor. Night
              multiplier applies between 22:00 and 06:00 IST. Waiting and cancellation fees are
              stored for trip settlement.
            </div>
          </>
        ) : categories.error ? (
          <div style={{ padding: 18 }}>
            <ErrorNote error={categories.error} onRetry={categories.reload} />
          </div>
        ) : categories.loading && !categories.data ? (
          <LoadingBlock />
        ) : (
          <div className="table-wrap">
            <table className="data">
              <thead>
                <tr>
                  <th>Code</th>
                  <th>Display name</th>
                  <th>Description</th>
                  <th className="num">Capacity</th>
                  <th className="num">Order</th>
                  <th>Status</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {categories.data?.map((item) => (
                  <tr key={item.id}>
                    <td className="cell-main mono">{item.code}</td>
                    <td className="cell-main">{item.display_name}</td>
                    <td className="tiny muted" style={{ maxWidth: 320 }}>
                      {item.description ?? '—'}
                    </td>
                    <td className="num mono">{item.capacity}</td>
                    <td className="num mono">{item.sort_order}</td>
                    <td>
                      <StatusBadge status={item.is_active ? 'active' : 'inactive'} />
                    </td>
                    <td className="num">
                      {canWrite && (
                        <Button size="sm" onClick={() => setCategoryEdit({ ...item })}>
                          <Pencil size={12} /> Edit
                        </Button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <Modal
        open={editRule !== null}
        onClose={() => setEditRule(null)}
        title={`Edit ${categoryLabel(editRule?.category)} pricing`}
        subtitle="Values are in rupees. Saving increments the rule version."
        wide
        footer={
          <>
            <Button onClick={() => setEditRule(null)} disabled={busy}>
              Cancel
            </Button>
            <Button variant="primary" loading={busy} onClick={saveRule}>
              <Check size={14} /> Save new version
            </Button>
          </>
        }
      >
        <RuleFields form={form} setForm={setForm} />
      </Modal>

      <Modal
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        title="New pricing rule"
        subtitle="Global rule. Newer rules supersede older versions for quoting."
        wide
        footer={
          <>
            <Button onClick={() => setCreateOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button variant="primary" loading={busy} onClick={createRule}>
              <Plus size={14} /> Create rule
            </Button>
          </>
        }
      >
        <Field label="Service category">
          <select value={category} onChange={(event) => setCategory(event.target.value as typeof category)}>
            <option value="bike">Bike</option>
            <option value="auto">Auto</option>
            <option value="cab">Cab</option>
          </select>
        </Field>
        <RuleFields form={form} setForm={setForm} />
      </Modal>

      <Modal
        open={categoryEdit !== null}
        onClose={() => setCategoryEdit(null)}
        title={`Edit ${categoryEdit?.display_name ?? 'category'}`}
        footer={
          <>
            <Button onClick={() => setCategoryEdit(null)} disabled={busy}>
              Cancel
            </Button>
            <Button variant="primary" loading={busy} onClick={saveCategory}>
              Save category
            </Button>
          </>
        }
      >
        {categoryEdit && (
          <>
            <div className="form-grid">
              <Field label="Display name">
                <input
                  value={categoryEdit.display_name}
                  onChange={(event) =>
                    setCategoryEdit({ ...categoryEdit, display_name: event.target.value })
                  }
                />
              </Field>
              <Field label="Capacity">
                <input
                  type="number"
                  min={1}
                  max={10}
                  value={categoryEdit.capacity}
                  onChange={(event) =>
                    setCategoryEdit({ ...categoryEdit, capacity: Number(event.target.value) })
                  }
                />
              </Field>
              <Field label="Description" span2>
                <textarea
                  value={categoryEdit.description ?? ''}
                  onChange={(event) =>
                    setCategoryEdit({ ...categoryEdit, description: event.target.value })
                  }
                />
              </Field>
              <Field label="Sort order">
                <input
                  type="number"
                  value={categoryEdit.sort_order}
                  onChange={(event) =>
                    setCategoryEdit({ ...categoryEdit, sort_order: Number(event.target.value) })
                  }
                />
              </Field>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={categoryEdit.is_active}
                onChange={(event) =>
                  setCategoryEdit({ ...categoryEdit, is_active: event.target.checked })
                }
              />
              <span className="switch-track" />
              Visible to passengers
            </label>
          </>
        )}
      </Modal>
    </>
  );
}

function RuleFields({ form, setForm }: { form: RuleForm; setForm: (form: RuleForm) => void }) {
  const set = (key: keyof RuleForm, value: string | boolean) => setForm({ ...form, [key]: value });
  return (
    <>
      <div className="form-grid">
        <Field label="Base fare (₹)">
          <input type="number" min="0" step="0.01" value={form.base} onChange={(e) => set('base', e.target.value)} />
        </Field>
        <Field label="Minimum fare (₹)">
          <input type="number" min="0" step="0.01" value={form.minimum} onChange={(e) => set('minimum', e.target.value)} />
        </Field>
        <Field label="Per km (₹)">
          <input type="number" min="0" step="0.01" value={form.perKm} onChange={(e) => set('perKm', e.target.value)} />
        </Field>
        <Field label="Per minute (₹)">
          <input type="number" min="0" step="0.01" value={form.perMinute} onChange={(e) => set('perMinute', e.target.value)} />
        </Field>
        <Field label="Waiting / min (₹)">
          <input type="number" min="0" step="0.01" value={form.waiting} onChange={(e) => set('waiting', e.target.value)} />
        </Field>
        <Field label="Cancellation fee (₹)">
          <input type="number" min="0" step="0.01" value={form.cancellation} onChange={(e) => set('cancellation', e.target.value)} />
        </Field>
        <Field label="Platform fee (₹)">
          <input type="number" min="0" step="0.01" value={form.platform} onChange={(e) => set('platform', e.target.value)} />
        </Field>
        <Field label="Commission (%)">
          <input type="number" min="0" max="100" step="0.1" value={form.commission} onChange={(e) => set('commission', e.target.value)} />
        </Field>
        <Field label="Night multiplier" hint="Applied 22:00–06:00 IST.">
          <input type="number" min="0.5" max="5" step="0.01" value={form.night} onChange={(e) => set('night', e.target.value)} />
        </Field>
      </div>
      <label className="switch">
        <input type="checkbox" checked={form.active} onChange={(e) => set('active', e.target.checked)} />
        <span className="switch-track" />
        Rule active for quoting
      </label>
      <div className="note-box">
        Distance and time charges are calculated on the route estimate. The minimum fare floor and
        coupons are applied after those lines.
      </div>
    </>
  );
}
