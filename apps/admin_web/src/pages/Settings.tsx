import { useEffect, useState } from 'react';
import { Plus, Save, Settings2 } from 'lucide-react';
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
  Tag,
} from '../components/ui';
import type { AppSetting } from '../lib/types';
import { dateTime } from '../lib/format';

export function SettingsPage() {
  const { admin } = useAuth();
  const toast = useToast();
  const { data, loading, error, reload } = useApi<AppSetting[]>('/admin/settings');
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [savingKey, setSavingKey] = useState<string | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [newKey, setNewKey] = useState('');
  const [newValue, setNewValue] = useState('{\n  \n}');
  const [newDescription, setNewDescription] = useState('');
  const [busy, setBusy] = useState(false);
  const canWrite = admin?.role === 'admin' || admin?.role === 'super_admin';

  useEffect(() => {
    if (!data) return;
    const next: Record<string, string> = {};
    for (const setting of data) next[setting.key] = JSON.stringify(setting.value, null, 2);
    setDrafts(next);
  }, [data]);

  async function saveSetting(key: string) {
    const raw = drafts[key] ?? '{}';
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(raw) as Record<string, unknown>;
    } catch {
      toast.error('That value is not valid JSON. Fix the syntax before saving.');
      return;
    }
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      toast.error('Settings must be a JSON object.');
      return;
    }
    setSavingKey(key);
    try {
      await api.put(`/admin/settings/${encodeURIComponent(key)}`, {
        value: parsed,
        description: data?.find((item) => item.key === key)?.description ?? undefined,
      });
      toast.success(`Setting “${key}” saved.`);
      reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setSavingKey(null);
    }
  }

  async function createSetting() {
    const key = newKey.trim();
    if (!/^[a-z0-9_.-]{2,80}$/i.test(key)) {
      toast.error('Use 2–80 letters, numbers, dots, dashes or underscores.');
      return;
    }
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(newValue) as Record<string, unknown>;
    } catch {
      toast.error('Value must be valid JSON.');
      return;
    }
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      toast.error('Value must be a JSON object.');
      return;
    }
    setBusy(true);
    try {
      await api.put(`/admin/settings/${encodeURIComponent(key)}`, {
        value: parsed,
        description: newDescription.trim() || undefined,
      });
      toast.success('Setting created.');
      setCreateOpen(false);
      setNewKey('');
      setNewValue('{\n  \n}');
      setNewDescription('');
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
        title="Settings"
        subtitle="Operational values read by the apps. These are database settings, not infrastructure secrets."
        actions={
          canWrite ? (
            <Button variant="primary" onClick={() => setCreateOpen(true)}>
              <Plus size={14} /> Add setting
            </Button>
          ) : (
            <span className="tag">Read-only access</span>
          )
        }
      />

      <div className="note-box warn" style={{ marginBottom: 18 }}>
        <strong>Scope of these settings</strong>
        Runtime configuration such as OTP adapters, payment provider keys and map provider comes
        from environment variables. Values here are app-facing content (support details, demo
        markers, display flags). The dispatch entry is a read-only snapshot and does not reconfigure
        the search radius.
      </div>

      {error ? (
        <ErrorNote error={error} onRetry={reload} />
      ) : loading && !data ? (
        <LoadingBlock />
      ) : (
        <div className="stack">
          {data?.length === 0 && (
            <Card className="card-pad">
              <div className="muted small">No app settings stored yet.</div>
            </Card>
          )}
          {data?.map((setting) => {
            const dirty = drafts[setting.key] !== JSON.stringify(setting.value, null, 2);
            return (
              <Card key={setting.key}>
                <div className="card-head">
                  <div className="row" style={{ gap: 10 }}>
                    <span className="kpi-icon">
                      <Settings2 size={16} />
                    </span>
                    <div>
                      <div className="card-title mono">{setting.key}</div>
                      <div className="card-sub">{setting.description ?? 'No description'}</div>
                    </div>
                  </div>
                  <div className="card-actions">
                    {setting.key === 'demo_data' && <Tag tone="demo">Demo marker</Tag>}
                    <span className="tiny muted">Updated {dateTime(setting.updated_at)}</span>
                    {canWrite && (
                      <Button
                        size="sm"
                        variant="primary"
                        loading={savingKey === setting.key}
                        disabled={!dirty}
                        onClick={() => saveSetting(setting.key)}
                      >
                        <Save size={12} /> Save
                      </Button>
                    )}
                  </div>
                </div>
                <div className="card-pad">
                  <textarea
                    value={drafts[setting.key] ?? ''}
                    onChange={(event) =>
                      setDrafts({ ...drafts, [setting.key]: event.target.value })
                    }
                    spellCheck={false}
                    disabled={!canWrite}
                    style={{
                      width: '100%',
                      minHeight: 130,
                      fontFamily:
                        "ui-monospace, 'SFMono-Regular', Menlo, Consolas, monospace",
                      fontSize: 12,
                      lineHeight: 1.55,
                    }}
                  />
                  {dirty && canWrite && (
                    <div className="tiny" style={{ color: '#8a5a00', marginTop: 6 }}>
                      Unsaved changes
                    </div>
                  )}
                </div>
              </Card>
            );
          })}
        </div>
      )}

      <Modal
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        title="Add app setting"
        subtitle="Stored as a JSON object and readable by the mobile apps."
        footer={
          <>
            <Button onClick={() => setCreateOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button variant="primary" loading={busy} onClick={createSetting}>
              Create setting
            </Button>
          </>
        }
      >
        <div className="form-grid">
          <Field label="Key" span2 hint="Letters, numbers, dots, dashes and underscores.">
            <input
              value={newKey}
              onChange={(event) => setNewKey(event.target.value)}
              placeholder="support_holiday"
            />
          </Field>
          <Field label="Description" span2>
            <input
              value={newDescription}
              onChange={(event) => setNewDescription(event.target.value)}
              placeholder="Shown to operators in this console"
            />
          </Field>
        </div>
        <Field label="JSON value">
          <textarea
            value={newValue}
            onChange={(event) => setNewValue(event.target.value)}
            spellCheck={false}
            style={{
              fontFamily: "ui-monospace, 'SFMono-Regular', Menlo, Consolas, monospace",
              fontSize: 12,
            }}
          />
        </Field>
      </Modal>
    </>
  );
}
