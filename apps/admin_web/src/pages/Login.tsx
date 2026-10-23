import { useState, type FormEvent } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
import { ArrowRight, Eye, EyeOff, LockKeyhole, Mail, ShieldCheck } from 'lucide-react';
import { useAuth } from '../lib/auth';
import { errorMessage } from '../lib/api';
import { Button, NeevMark } from '../components/ui';

export function LoginPage() {
  const { admin, login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (admin) return <Navigate to="/" replace />;

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await login(email.trim(), password);
      navigate('/', { replace: true });
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-screen">
      <section className="login-art">
        <div className="login-brand">
          <NeevMark size={42} />
          <div>
            <div className="brand-name">
              neev<span>.</span>
            </div>
            <div className="brand-sub">Mobility operations</div>
          </div>
        </div>

        <h1>
          Every ride,
          <br />
          <em>accounted for.</em>
        </h1>
        <p className="lede">
          Dispatch, captain verification, pricing, payments and passenger support in one
          operator-facing console. Every action is written to an immutable audit trail.
        </p>

        <div className="login-stats">
          <div className="login-stat">
            <strong>Dispatch</strong>
            <span>Live ride state</span>
          </div>
          <div className="login-stat">
            <strong>Verification</strong>
            <span>Document review</span>
          </div>
          <div className="login-stat">
            <strong>Money</strong>
            <span>Ledger-backed</span>
          </div>
          <div className="login-stat">
            <strong>Support</strong>
            <span>Human handoff</span>
          </div>
        </div>
      </section>

      <section className="login-panel">
        <div className="login-card">
          <div className="env-pill" style={{ marginBottom: 18 }}>
            <ShieldCheck size={12} /> Restricted access
          </div>
          <h2>Sign in to operations</h2>
          <p className="sub">
            Use your Neev staff account. Access is role-based and every session is audited.
          </p>

          {error && (
            <div className="error-note login-error" role="alert">
              {error}
            </div>
          )}

          <form onSubmit={onSubmit} className="stack" style={{ gap: 15 }}>
            <div className="field">
              <label htmlFor="email">Work email</label>
              <div style={{ position: 'relative' }}>
                <Mail
                  size={15}
                  style={{
                    position: 'absolute',
                    left: 12,
                    top: '50%',
                    transform: 'translateY(-50%)',
                    color: 'var(--muted)',
                  }}
                />
                <input
                  id="email"
                  type="email"
                  autoComplete="username"
                  required
                  placeholder="you@neev.local"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  style={{ paddingLeft: 36, width: '100%' }}
                />
              </div>
            </div>

            <div className="field">
              <label htmlFor="password">Password</label>
              <div style={{ position: 'relative' }}>
                <LockKeyhole
                  size={15}
                  style={{
                    position: 'absolute',
                    left: 12,
                    top: '50%',
                    transform: 'translateY(-50%)',
                    color: 'var(--muted)',
                  }}
                />
                <input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  autoComplete="current-password"
                  required
                  placeholder="Enter your password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  style={{ paddingLeft: 36, paddingRight: 42, width: '100%' }}
                />
                <button
                  type="button"
                  className="icon-btn"
                  onClick={() => setShowPassword((v) => !v)}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                  style={{
                    position: 'absolute',
                    right: 4,
                    top: '50%',
                    transform: 'translateY(-50%)',
                    color: 'var(--muted)',
                  }}
                >
                  {showPassword ? <EyeOff size={15} /> : <Eye size={15} />}
                </button>
              </div>
            </div>

            <Button type="submit" variant="primary" loading={busy} className="btn-block" style={{ marginTop: 4 }}>
              Continue to console <ArrowRight size={15} />
            </Button>
          </form>

          <div className="demo-note">
            <strong>Local demo credentials</strong>
            Seeded development database only — not valid in production.
            <br />
            <code>admin@neev.local</code> · <code>NeevAdmin!2026</code>
            <br />
            Support-role demo: <code>support@neev.local</code> · <code>NeevSupport!2026</code>
          </div>

          <p className="login-foot">
            Neev is an independent ride-booking platform built for this workspace. It is not
            affiliated with, endorsed by, or connected to any other ride-hailing brand.
          </p>
        </div>
      </section>
    </div>
  );
}
