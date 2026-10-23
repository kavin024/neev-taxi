import { useState } from 'react';
import { Pencil, Plus, TicketPercent } from 'lucide-react';
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
import type { Coupon } from '../lib/types';
import { categoryLabel, dateLabel, money, number } from '../lib/format';

interface CouponForm {
  code: string;
  description: string;
  discountType: 'percent' | 'fixed';
  value: string;
  maxDiscount: string;
  minFare: string;
  maxUses: string;
  perUserLimit: string;
  categories: string[];
  validUntil: string;
  active: boolean;
}

const emptyForm: CouponForm = {
  code: '',
  description: '',
  discountType: 'percent',
  value: '20',
  maxDiscount: '100',
  minFare: '0',
  maxUses: '',
  perUserLimit: '1',
  categories: [],
  validUntil: defaultValidUntil(),
  active: true,
};

function defaultValidUntil(): string {
  const date = new Date();
  date.setDate(date.getDate() + 30);
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 16);
}

function formFromCoupon(coupon: Coupon): CouponForm {
  return {
    code: coupon.code,
    description: coupon.description,
    discountType: coupon.discount_type,
    value:
      coupon.discount_type === 'fixed'
        ? String(coupon.value / 100)
        : String(coupon.value),
    maxDiscount: coupon.max_discount_paise ? String(coupon.max_discount_paise / 100) : '',
    minFare: String(coupon.min_fare_paise / 100),
    maxUses: coupon.max_uses ? String(coupon.max_uses) : '',
    perUserLimit: String(coupon.per_user_limit),
    categories: coupon.categories ?? [],
    validUntil: toInputValue(coupon.valid_until),
    active: coupon.is_active,
  };
}

function toInputValue(iso: string): string {
  const date = new Date(iso);
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 16);
}

export function CouponsPage() {
  const { admin } = useAuth();
  const toast = useToast();
  const { data, loading, error, reload } = useApi<Coupon[]>('/admin/coupons');
  const [createOpen, setCreateOpen] = useState(false);
  const [editCoupon, setEditCoupon] = useState<Coupon | null>(null);
  const [form, setForm] = useState<CouponForm>(emptyForm);
  const [busy, setBusy] = useState(false);
  const [toggling, setToggling] = useState<string | null>(null);

  const canWrite = admin?.role === 'admin' || admin?.role === 'super_admin';

  function payload() {
    return {
      description: form.description.trim(),
      value: form.discountType === 'fixed' ? Math.round(Number(form.value) * 100) : Number(form.value),
      max_discount_paise:
        form.discountType === 'percent' && form.maxDiscount
          ? Math.round(Number(form.maxDiscount) * 100)
          : null,
      min_fare_paise: Math.round(Number(form.minFare || '0') * 100),
      max_uses: form.maxUses ? Number(form.maxUses) : null,
      per_user_limit: Number(form.perUserLimit || '1'),
      categories: form.categories.length > 0 ? form.categories : null,
      valid_until: new Date(form.validUntil).toISOString(),
      is_active: form.active,
    };
  }

  async function createCoupon() {
    setBusy(true);
    try {
      await api.post('/admin/coupons', {
        code: form.code.trim().toUpperCase(),
        discount_type: form.discountType,
        ...payload(),
      });
      toast.success(`Coupon ${form.code.toUpperCase()} created.`);
      setCreateOpen(false);
      reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function saveCoupon() {
    if (!editCoupon) return;
    setBusy(true);
    try {
      await api.patch(`/admin/coupons/${editCoupon.id}`, payload());
      toast.success('Coupon updated.');
      setEditCoupon(null);
      reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function toggle(coupon: Coupon) {
    setToggling(coupon.id);
    try {
      await api.patch(`/admin/coupons/${coupon.id}`, { is_active: !coupon.is_active });
      toast.success(coupon.is_active ? 'Coupon paused.' : 'Coupon activated.');
      reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setToggling(null);
    }
  }

  const activeCoupons = (data ?? []).filter((coupon) => coupon.is_active).length;
  const redemptions = (data ?? []).reduce((sum, coupon) => sum + coupon.used_count, 0);

  return (
    <>
      <PageHeader
        title="Coupons"
        subtitle="Percentage or fixed discounts with per-user caps, minimum fares and category scoping."
        actions={
          canWrite ? (
            <Button
              variant="primary"
              onClick={() => {
                setForm({ ...emptyForm, validUntil: defaultValidUntil() });
                setCreateOpen(true);
              }}
            >
              <Plus size={14} /> New coupon
            </Button>
          ) : (
            <span className="tag">Read-only access</span>
          )
        }
      />

      <div className="kpi-grid" style={{ gridTemplateColumns: 'repeat(3, minmax(0, 1fr))' }}>
        <div className="kpi">
          <div className="kpi-top">
            <span className="kpi-label">Total coupons</span>
            <span className="kpi-icon">
              <TicketPercent size={17} />
            </span>
          </div>
          <div className="kpi-value">{number(data?.length ?? 0)}</div>
          <div className="kpi-foot">{activeCoupons} currently active</div>
        </div>
        <div className="kpi">
          <div className="kpi-top">
            <span className="kpi-label">Redemptions</span>
            <span className="kpi-icon amber">
              <TicketPercent size={17} />
            </span>
          </div>
          <div className="kpi-value">{number(redemptions)}</div>
          <div className="kpi-foot">Across all coupon codes</div>
        </div>
        <div className="kpi">
          <div className="kpi-top">
            <span className="kpi-label">Expiring soon</span>
            <span className="kpi-icon info">
              <TicketPercent size={17} />
            </span>
          </div>
          <div className="kpi-value">
            {number(
              (data ?? []).filter((coupon) => {
                const days = (new Date(coupon.valid_until).getTime() - Date.now()) / 86_400_000;
                return coupon.is_active && days >= 0 && days <= 7;
              }).length,
            )}
          </div>
          <div className="kpi-foot">Active codes ending in 7 days</div>
        </div>
      </div>

      <Card>
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
                  <th>Code</th>
                  <th>Discount</th>
                  <th className="num">Min fare</th>
                  <th>Usage</th>
                  <th>Categories</th>
                  <th>Valid until</th>
                  <th>Status</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {data?.length === 0 && (
                  <tr>
                    <td colSpan={8}>
                      <div className="table-empty">
                        <strong>No coupons yet</strong>
                        Create a code to run a promotion.
                      </div>
                    </td>
                  </tr>
                )}
                {data?.map((coupon) => (
                  <tr key={coupon.id}>
                    <td>
                      <div className="cell-main mono" style={{ letterSpacing: 0.4 }}>
                        {coupon.code}
                      </div>
                      <div className="cell-sub" style={{ maxWidth: 260 }}>
                        {coupon.description}
                      </div>
                    </td>
                    <td>
                      <div className="cell-main">
                        {coupon.discount_type === 'percent'
                          ? `${coupon.value}% off`
                          : `${money(coupon.value)} off`}
                      </div>
                      {coupon.max_discount_paise ? (
                        <div className="cell-sub">up to {money(coupon.max_discount_paise)}</div>
                      ) : null}
                    </td>
                    <td className="num mono">{money(coupon.min_fare_paise)}</td>
                    <td>
                      <div className="cell-main mono">
                        {number(coupon.used_count)}
                        {coupon.max_uses ? ` / ${number(coupon.max_uses)}` : ' / ∞'}
                      </div>
                      <div className="cell-sub">{coupon.per_user_limit} per passenger</div>
                    </td>
                    <td className="tiny muted">
                      {coupon.categories?.length
                        ? coupon.categories.map(categoryLabel).join(', ')
                        : 'All categories'}
                    </td>
                    <td className="tiny muted">{dateLabel(coupon.valid_until)}</td>
                    <td>
                      <StatusBadge status={coupon.is_active ? 'active' : 'inactive'} />
                    </td>
                    <td className="num">
                      {canWrite && (
                        <div className="cell-actions">
                          <label className="switch" title="Toggle coupon">
                            <input
                              type="checkbox"
                              checked={coupon.is_active}
                              disabled={toggling === coupon.id}
                              onChange={() => toggle(coupon)}
                            />
                            <span className="switch-track" />
                          </label>
                          <Button
                            size="sm"
                            onClick={() => {
                              setForm(formFromCoupon(coupon));
                              setEditCoupon(coupon);
                            }}
                          >
                            <Pencil size={12} /> Edit
                          </Button>
                        </div>
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
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        title="Create coupon"
        subtitle="Codes are stored uppercase and checked at quote time."
        wide
        footer={
          <>
            <Button onClick={() => setCreateOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant="primary"
              loading={busy}
              disabled={form.code.trim().length < 3 || form.description.trim().length < 3}
              onClick={createCoupon}
            >
              Create coupon
            </Button>
          </>
        }
      >
        <div className="form-grid">
          <Field label="Code">
            <input
              value={form.code}
              onChange={(event) => setForm({ ...form, code: event.target.value.toUpperCase() })}
              placeholder="NEEV25"
              maxLength={30}
            />
          </Field>
          <Field label="Discount type">
            <select
              value={form.discountType}
              onChange={(event) =>
                setForm({ ...form, discountType: event.target.value as 'percent' | 'fixed' })
              }
            >
              <option value="percent">Percentage</option>
              <option value="fixed">Fixed amount</option>
            </select>
          </Field>
          <Field label="Description" span2>
            <input
              value={form.description}
              onChange={(event) => setForm({ ...form, description: event.target.value })}
              placeholder="25% off bike rides this week"
            />
          </Field>
          <Field label={form.discountType === 'percent' ? 'Percentage off' : 'Amount off (₹)'}>
            <input
              type="number"
              min="1"
              max={form.discountType === 'percent' ? 100 : undefined}
              value={form.value}
              onChange={(event) => setForm({ ...form, value: event.target.value })}
            />
          </Field>
          <Field label="Minimum fare (₹)">
            <input
              type="number"
              min="0"
              value={form.minFare}
              onChange={(event) => setForm({ ...form, minFare: event.target.value })}
            />
          </Field>
          {form.discountType === 'percent' && (
            <Field label="Maximum discount (₹)" hint="Leave blank for no cap.">
              <input
                type="number"
                min="0"
                value={form.maxDiscount}
                onChange={(event) => setForm({ ...form, maxDiscount: event.target.value })}
              />
            </Field>
          )}
          <Field label="Total uses" hint="Blank means unlimited.">
            <input
              type="number"
              min="1"
              value={form.maxUses}
              onChange={(event) => setForm({ ...form, maxUses: event.target.value })}
            />
          </Field>
          <Field label="Per passenger limit">
            <input
              type="number"
              min="1"
              value={form.perUserLimit}
              onChange={(event) => setForm({ ...form, perUserLimit: event.target.value })}
            />
          </Field>
          <Field label="Valid until">
            <input
              type="datetime-local"
              value={form.validUntil}
              onChange={(event) => setForm({ ...form, validUntil: event.target.value })}
            />
          </Field>
          <div className="field span-2">
            <label>Categories</label>
            <div className="row wrap" style={{ gap: 14, padding: '4px 0' }}>
              {['bike', 'auto', 'cab'].map((value) => (
                <label className="checkbox" key={value}>
                  <input
                    type="checkbox"
                    checked={form.categories.includes(value)}
                    onChange={(event) => {
                      const next = event.target.checked
                        ? [...form.categories, value]
                        : form.categories.filter((item) => item !== value);
                      setForm({ ...form, categories: next });
                    }}
                  />
                  {categoryLabel(value)}
                </label>
              ))}
              <span className="tiny muted">None selected = all categories</span>
            </div>
          </div>
        </div>
        <label className="switch">
          <input
            type="checkbox"
            checked={form.active}
            onChange={(event) => setForm({ ...form, active: event.target.checked })}
          />
          <span className="switch-track" />
          Active immediately
        </label>
      </Modal>

      <Modal
        open={editCoupon !== null}
        onClose={() => setEditCoupon(null)}
        title={`Edit ${editCoupon?.code ?? 'coupon'}`}
        subtitle="The code and discount type are immutable after creation."
        wide
        footer={
          <>
            <Button onClick={() => setEditCoupon(null)} disabled={busy}>
              Cancel
            </Button>
            <Button variant="primary" loading={busy} onClick={saveCoupon}>
              Save changes
            </Button>
          </>
        }
      >
        <div className="form-grid">
          <Field label="Code">
            <input value={form.code} disabled />
          </Field>
          <Field label="Discount type">
            <input value={form.discountType === 'percent' ? 'Percentage' : 'Fixed amount'} disabled />
          </Field>
          <Field label="Description" span2>
            <input
              value={form.description}
              onChange={(event) => setForm({ ...form, description: event.target.value })}
            />
          </Field>
          <Field label={form.discountType === 'percent' ? 'Percentage off' : 'Amount off (₹)'}>
            <input
              type="number"
              min="1"
              value={form.value}
              onChange={(event) => setForm({ ...form, value: event.target.value })}
            />
          </Field>
          <Field label="Minimum fare (₹)">
            <input
              type="number"
              min="0"
              value={form.minFare}
              onChange={(event) => setForm({ ...form, minFare: event.target.value })}
            />
          </Field>
          {form.discountType === 'percent' && (
            <Field label="Maximum discount (₹)">
              <input
                type="number"
                min="0"
                value={form.maxDiscount}
                onChange={(event) => setForm({ ...form, maxDiscount: event.target.value })}
              />
            </Field>
          )}
          <Field label="Total uses" hint="Blank means unlimited.">
            <input
              type="number"
              min="1"
              value={form.maxUses}
              onChange={(event) => setForm({ ...form, maxUses: event.target.value })}
            />
          </Field>
          <Field label="Per passenger limit">
            <input
              type="number"
              min="1"
              value={form.perUserLimit}
              onChange={(event) => setForm({ ...form, perUserLimit: event.target.value })}
            />
          </Field>
          <Field label="Valid until">
            <input
              type="datetime-local"
              value={form.validUntil}
              onChange={(event) => setForm({ ...form, validUntil: event.target.value })}
            />
          </Field>
          <div className="field span-2">
            <label>Categories</label>
            <div className="row wrap" style={{ gap: 14, padding: '4px 0' }}>
              {['bike', 'auto', 'cab'].map((value) => (
                <label className="checkbox" key={value}>
                  <input
                    type="checkbox"
                    checked={form.categories.includes(value)}
                    onChange={(event) => {
                      const next = event.target.checked
                        ? [...form.categories, value]
                        : form.categories.filter((item) => item !== value);
                      setForm({ ...form, categories: next });
                    }}
                  />
                  {categoryLabel(value)}
                </label>
              ))}
            </div>
          </div>
        </div>
        <label className="switch">
          <input
            type="checkbox"
            checked={form.active}
            onChange={(event) => setForm({ ...form, active: event.target.checked })}
          />
          <span className="switch-track" />
          Coupon active
        </label>
      </Modal>
    </>
  );
}
