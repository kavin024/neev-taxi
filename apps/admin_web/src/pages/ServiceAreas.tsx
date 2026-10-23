import { useState } from 'react';
import { MapPinned, Pencil, Plus } from 'lucide-react';
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
import type { ServiceArea } from '../lib/types';

interface AreaForm {
  name: string;
  city: string;
  lat: string;
  lng: string;
  radius: string;
  active: boolean;
}

const emptyForm: AreaForm = {
  name: '',
  city: 'Bengaluru',
  lat: '12.9716',
  lng: '77.5946',
  radius: '25',
  active: true,
};

export function ServiceAreasPage() {
  const { admin } = useAuth();
  const toast = useToast();
  const { data, loading, error, reload } = useApi<ServiceArea[]>('/admin/service-areas');
  const [editing, setEditing] = useState<ServiceArea | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [form, setForm] = useState<AreaForm>(emptyForm);
  const [busy, setBusy] = useState(false);
  const canWrite = admin?.role === 'admin' || admin?.role === 'super_admin';

  function openEdit(area: ServiceArea) {
    setForm({
      name: area.name,
      city: area.city,
      lat: String(area.center_lat),
      lng: String(area.center_lng),
      radius: String(area.radius_km),
      active: area.is_active,
    });
    setEditing(area);
  }

  async function create() {
    setBusy(true);
    try {
      await api.post('/admin/service-areas', {
        name: form.name.trim(),
        city: form.city.trim(),
        center_lat: Number(form.lat),
        center_lng: Number(form.lng),
        radius_km: Number(form.radius),
        is_active: form.active,
      });
      toast.success('Service area created.');
      setCreateOpen(false);
      reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function save() {
    if (!editing) return;
    setBusy(true);
    try {
      await api.patch(`/admin/service-areas/${editing.id}`, {
        name: form.name.trim(),
        city: form.city.trim(),
        center_lat: Number(form.lat),
        center_lng: Number(form.lng),
        radius_km: Number(form.radius),
        is_active: form.active,
      });
      toast.success('Service area updated.');
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
        title="Service areas"
        subtitle="Geofences used for serviceability and area-specific pricing. Coordinates are stored as numeric latitude and longitude."
        actions={
          canWrite ? (
            <Button
              variant="primary"
              onClick={() => {
                setForm(emptyForm);
                setCreateOpen(true);
              }}
            >
              <Plus size={14} /> New service area
            </Button>
          ) : (
            <span className="tag">Read-only access</span>
          )
        }
      />

      {error ? (
        <ErrorNote error={error} onRetry={reload} />
      ) : loading && !data ? (
        <LoadingBlock />
      ) : (
        <div className="grid grid-3">
          {data?.map((area) => (
            <Card key={area.id} className="card-pad">
              <div className="row-between" style={{ marginBottom: 12 }}>
                <div className="row" style={{ gap: 10 }}>
                  <span className="kpi-icon">
                    <MapPinned size={17} />
                  </span>
                  <div>
                    <div className="card-title">{area.name}</div>
                    <div className="tiny muted">{area.city}</div>
                  </div>
                </div>
                <StatusBadge status={area.is_active ? 'active' : 'inactive'} />
              </div>
              <div className="kv">
                <span className="k">Centre</span>
                <span className="v mono">
                  {area.center_lat.toFixed(4)}, {area.center_lng.toFixed(4)}
                </span>
              </div>
              <div className="kv">
                <span className="k">Radius</span>
                <span className="v">{area.radius_km} km</span>
              </div>
              <div className="kv">
                <span className="k">Area ID</span>
                <span className="v mono tiny">{area.id.slice(0, 10)}…</span>
              </div>
              {canWrite && (
                <Button
                  className="btn-block"
                  style={{ marginTop: 12 }}
                  onClick={() => openEdit(area)}
                >
                  <Pencil size={13} /> Edit area
                </Button>
              )}
            </Card>
          ))}
          {data?.length === 0 && (
            <Card className="card-pad">
              <div className="muted small">
                No service areas configured. Requests outside every active area are rejected by the
                fare service.
              </div>
            </Card>
          )}
        </div>
      )}

      <Modal
        open={createOpen || editing !== null}
        onClose={() => {
          setCreateOpen(false);
          setEditing(null);
        }}
        title={editing ? `Edit ${editing.name}` : 'New service area'}
        subtitle="Circle-based geofence. Lat/lng are the centre of the operating radius."
        footer={
          <>
            <Button
              onClick={() => {
                setCreateOpen(false);
                setEditing(null);
              }}
              disabled={busy}
            >
              Cancel
            </Button>
            <Button
              variant="primary"
              loading={busy}
              disabled={form.name.trim().length < 2 || form.city.trim().length < 2}
              onClick={editing ? save : create}
            >
              {editing ? 'Save area' : 'Create area'}
            </Button>
          </>
        }
      >
        <div className="form-grid">
          <Field label="Area name">
            <input
              value={form.name}
              onChange={(event) => setForm({ ...form, name: event.target.value })}
              placeholder="Central Bengaluru"
            />
          </Field>
          <Field label="City">
            <input
              value={form.city}
              onChange={(event) => setForm({ ...form, city: event.target.value })}
              placeholder="Bengaluru"
            />
          </Field>
          <Field label="Centre latitude">
            <input
              type="number"
              step="0.000001"
              min={-90}
              max={90}
              value={form.lat}
              onChange={(event) => setForm({ ...form, lat: event.target.value })}
            />
          </Field>
          <Field label="Centre longitude">
            <input
              type="number"
              step="0.000001"
              min={-180}
              max={180}
              value={form.lng}
              onChange={(event) => setForm({ ...form, lng: event.target.value })}
            />
          </Field>
          <Field label="Radius (km)">
            <input
              type="number"
              min="1"
              max="200"
              value={form.radius}
              onChange={(event) => setForm({ ...form, radius: event.target.value })}
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
          Accepting ride requests in this area
        </label>
        <div className="note-box">
          The demo map adapter uses a local fixture and this radius for serviceability. Switching to
          the OSM adapter uses the same database fence; no public map service is used at runtime in
          production without configuration.
        </div>
      </Modal>
    </>
  );
}
