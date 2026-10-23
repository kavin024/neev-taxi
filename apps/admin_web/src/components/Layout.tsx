import { useEffect, useMemo, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import {
  CarFront,
  CreditCard,
  IdCard,
  Landmark,
  LayoutDashboard,
  LifeBuoy,
  LogOut,
  MapPinned,
  Menu,
  ReceiptText,
  ScrollText,
  Settings2,
  ShieldAlert,
  TicketPercent,
  UserCog,
  Users,
  Zap,
  type LucideIcon,
} from 'lucide-react';
import { useAuth } from '../lib/auth';
import { useApi } from '../lib/hooks';
import type { DashboardData } from '../lib/types';
import { Avatar, NeevMark } from './ui';

interface NavEntry {
  to: string;
  label: string;
  icon: LucideIcon;
  end?: boolean;
  badge?: 'captains' | 'tickets';
  superOnly?: boolean;
}

const groups: { label: string; items: NavEntry[] }[] = [
  {
    label: 'Overview',
    items: [{ to: '/', label: 'Command centre', icon: LayoutDashboard, end: true }],
  },
  {
    label: 'Operations',
    items: [
      { to: '/rides', label: 'Rides', icon: CarFront },
      { to: '/captains', label: 'Captains', icon: IdCard, badge: 'captains' },
      { to: '/passengers', label: 'Passengers', icon: Users },
      { to: '/safety', label: 'Safety incidents', icon: ShieldAlert },
    ],
  },
  {
    label: 'Growth',
    items: [
      { to: '/pricing', label: 'Pricing & categories', icon: ReceiptText },
      { to: '/coupons', label: 'Coupons', icon: TicketPercent },
      { to: '/power-pass', label: 'Power Pass', icon: Zap },
      { to: '/service-areas', label: 'Service areas', icon: MapPinned },
    ],
  },
  {
    label: 'Money',
    items: [
      { to: '/payments', label: 'Payments & refunds', icon: CreditCard },
      { to: '/payouts', label: 'Captain payouts', icon: Landmark },
    ],
  },
  {
    label: 'Support',
    items: [{ to: '/tickets', label: 'Ticket desk', icon: LifeBuoy, badge: 'tickets' }],
  },
  {
    label: 'System',
    items: [
      { to: '/settings', label: 'Settings', icon: Settings2 },
      { to: '/audit', label: 'Audit trail', icon: ScrollText, superOnly: true },
      { to: '/admins', label: 'Team access', icon: UserCog, superOnly: true },
    ],
  },
];

export function Layout() {
  const { admin, logout } = useAuth();
  const location = useLocation();
  const [open, setOpen] = useState(false);
  const [now, setNow] = useState(() => new Date());

  const { data: dashboard, reload } = useApi<DashboardData>(
    admin ? '/admin/dashboard' : null,
    { days: 7 },
    { enabled: Boolean(admin) },
  );

  useEffect(() => {
    setOpen(false);
    window.scrollTo({ top: 0 });
  }, [location.pathname]);

  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 30_000);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    const timer = window.setInterval(reload, 60_000);
    return () => window.clearInterval(timer);
  }, [reload]);

  const visibleGroups = useMemo(() => {
    return groups
      .map((group) => ({
        ...group,
        items: group.items.filter((item) => {
          if (item.superOnly && admin?.role !== 'super_admin') return false;
          return true;
        }),
      }))
      .filter((group) => group.items.length > 0);
  }, [admin?.role]);

  const currentSection =
    visibleGroups
      .flatMap((group) => group.items)
      .filter((item) => (item.end ? location.pathname === item.to : location.pathname.startsWith(item.to)))
      .sort((a, b) => b.to.length - a.to.length)[0]?.label ?? 'Command centre';

  const badgeCount = (badge: NavEntry['badge']): number | null => {
    if (!dashboard) return null;
    if (badge === 'captains') return dashboard.kpis.pending_captain_approvals || null;
    if (badge === 'tickets') return dashboard.kpis.open_tickets || null;
    return null;
  };

  return (
    <div className="app-shell">
      {open && <div className="mobile-scrim" onClick={() => setOpen(false)} />}
      <aside className={`sidebar ${open ? 'open' : ''}`}>
        <div className="brand">
          <NeevMark size={40} />
          <div>
            <div className="brand-name">
              neev<span>.</span>
            </div>
            <div className="brand-sub">Operations</div>
          </div>
        </div>

        <nav className="sidebar-nav">
          {visibleGroups.map((group) => (
            <div className="nav-group" key={group.label}>
              <div className="nav-label">{group.label}</div>
              {group.items.map((item) => {
                const Icon = item.icon;
                const count = badgeCount(item.badge);
                return (
                  <NavLink
                    key={item.to}
                    to={item.to}
                    end={item.end}
                    className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
                    onClick={() => setOpen(false)}
                  >
                    <Icon size={16} strokeWidth={2} />
                    <span>{item.label}</span>
                    {count ? <span className="nav-badge">{count > 99 ? '99+' : count}</span> : null}
                  </NavLink>
                );
              })}
            </div>
          ))}
        </nav>

        <div className="sidebar-foot">
          <div className="side-user">
            <Avatar name={admin?.name} />
            <div style={{ minWidth: 0 }}>
              <div className="side-user-name">{admin?.name ?? 'Operations'}</div>
              <div className="side-user-role">{admin?.role?.replace('_', ' ') ?? 'admin'}</div>
            </div>
            <button type="button" className="icon-btn" onClick={logout} title="Sign out" aria-label="Sign out">
              <LogOut size={15} />
            </button>
          </div>
        </div>
      </aside>

      <div className="main">
        <header className="topbar">
          <button
            type="button"
            className="icon-btn mobile-nav-toggle"
            aria-label="Open navigation"
            onClick={() => setOpen(true)}
          >
            <Menu size={19} />
          </button>
          <div className="topbar-context">
            Neev operations <span style={{ margin: '0 7px', opacity: 0.4 }}>/</span>{' '}
            <strong>{currentSection}</strong>
          </div>
          <div className="topbar-right">
            <span className="env-pill">
              <span className="env-dot" />
              Live data
            </span>
            <div className="topbar-divider" />
            <span className="topbar-clock">
              {now.toLocaleDateString('en-IN', { weekday: 'short', day: '2-digit', month: 'short' })}
              {' · '}
              {now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })}
            </span>
            <div className="topbar-divider" />
            <Avatar name={admin?.name} amber />
            <div style={{ lineHeight: 1.2 }}>
              <div style={{ fontSize: 12, fontWeight: 800 }}>{admin?.name}</div>
              <div style={{ fontSize: 10, color: 'var(--muted)', textTransform: 'capitalize' }}>
                {admin?.role?.replace('_', ' ')}
              </div>
            </div>
          </div>
        </header>
        <main className="page">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
