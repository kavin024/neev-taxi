import { useState } from 'react';
import { Plus, ShieldCheck, UserCog } from 'lucide-react';
import { api, errorMessage } from '../lib/api';
import { useApi } from '../lib/hooks';
import { useToast } from '../components/toast';
import {
  Avatar,
  Button,
  Card,
  ErrorNote,
  Field,
  LoadingBlock,
  Modal,
  PageHeader,
  StatusBadge,
} from '../components/ui';
import type { AdminUser } from '../lib/types';
import { dateTime } from '../lib/format';

export function AdminsPage() {
  const toast = useToast();
  const { data, loading, error, reload } = useApi<AdminUser[]>('/admin/admins');
  const [open, setOpen] = useState(false);
  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<'support' | 'admin' | 'super_admin'>('support');
  const [busy, setBusy] = useState(false);

  async function create() {
    setBusy(true);
    try {
      await api.post('/admin/admins', {
        email: email.trim(),
        name: name.trim(),
        password,
        role,
      });
      toast.success('Team member created. Share the password through a secure channel.');
      setOpen(false);
      setEmail('');
      setName('');
      setPassword('');
      setRole('support');
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
        title="Team access"
        subtitle="Staff accounts and their roles. Only super admins can view or create console users."
        actions={
          <Button variant="primary" onClick={() => setOpen(true)}>
            <Plus size={14} /> Add team member
          </Button>
        }
      />

      <div className="grid grid-3" style={{ marginBottom: 18 }}>
        <Card className="card-pad">
          <div className="row" style={{ gap: 10 }}>
            <span className="kpi-icon">
              <ShieldCheck size={17} />
            </span>
            <div>
              <div className="kpi-label">Super admins</div>
              <div className="kpi-value small-value" style={{ marginTop: 4 }}>
                {(data ?? []).filter((item) => item.role === 'super_admin').length}
              </div>
            </div>
          </div>
        </Card>
        <Card className="card-pad">
          <div className="row" style={{ gap: 10 }}>
            <span className="kpi-icon info">
              <UserCog size={17} />
            </span>
            <div>
              <div className="kpi-label">Operations admins</div>
              <div className="kpi-value small-value" style={{ marginTop: 4 }}>
                {(data ?? []).filter((item) => item.role === 'admin').length}
              </div>
            </div>
          </div>
        </Card>
        <Card className="card-pad">
          <div className="row" style={{ gap: 10 }}>
            <span className="kpi-icon amber">
              <UserCog size={17} />
            </span>
            <div>
              <div className="kpi-label">Support agents</div>
              <div className="kpi-value small-value" style={{ marginTop: 4 }}>
                {(data ?? []).filter((item) => item.role === 'support').length}
              </div>
            </div>
          </div>
        </Card>
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
                  <th>Team member</th>
                  <th>Email</th>
                  <th>Role</th>
                  <th>Status</th>
                  <th>Last login</th>
                </tr>
              </thead>
              <tbody>
                {data?.map((member) => (
                  <tr key={member.id}>
                    <td>
                      <div className="row">
                        <Avatar name={member.name} />
                        <div>
                          <div className="cell-main">{member.name}</div>
                          <div className="cell-sub mono">{member.id.slice(0, 12)}…</div>
                        </div>
                      </div>
                    </td>
                    <td className="mono tiny">{member.email}</td>
                    <td>
                      <span className={`badge ${member.role === 'super_admin' ? 'badge-danger' : member.role === 'admin' ? 'badge-info' : 'badge-neutral'}`}>
                        {member.role.replace('_', ' ')}
                      </span>
                    </td>
                    <td>
                      <StatusBadge status={member.is_active ? 'active' : 'inactive'} />
                    </td>
                    <td className="tiny muted">
                      {member.last_login_at ? dateTime(member.last_login_at) : 'Never'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <div className="note-box" style={{ marginTop: 16 }}>
        <strong>Least privilege</strong>
        Support agents can read operational data, reply to tickets and resolve incidents, but cannot
        approve captains, change pricing or move money. Admin and super-admin actions are written to
        the audit trail.
      </div>

      <Modal
        open={open}
        onClose={() => setOpen(false)}
        title="Add team member"
        subtitle="Passwords are hashed with Argon2. Minimum 12 characters."
        footer={
          <>
            <Button onClick={() => setOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant="primary"
              loading={busy}
              disabled={
                email.trim().length < 3 ||
                name.trim().length < 2 ||
                password.length < 12
              }
              onClick={create}
            >
              Create account
            </Button>
          </>
        }
      >
        <div className="form-grid">
          <Field label="Full name">
            <input value={name} onChange={(event) => setName(event.target.value)} placeholder="Asha Rao" />
          </Field>
          <Field label="Role">
            <select value={role} onChange={(event) => setRole(event.target.value as typeof role)}>
              <option value="support">Support agent</option>
              <option value="admin">Operations admin</option>
              <option value="super_admin">Super admin</option>
            </select>
          </Field>
          <Field label="Work email" span2>
            <input
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="asha@neev.local"
            />
          </Field>
          <Field label="Initial password" span2 hint="At least 12 characters.">
            <input
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              autoComplete="new-password"
            />
          </Field>
        </div>
        <div className="note-box">
          There is no password-reset endpoint in this build. Store the initial password in your
          password manager and share it over a secure channel.
        </div>
      </Modal>
    </>
  );
}
