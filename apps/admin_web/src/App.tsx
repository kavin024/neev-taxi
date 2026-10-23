import type { ReactNode } from 'react';
import { Navigate, Outlet, Route, Routes, useLocation } from 'react-router-dom';
import { ShieldX } from 'lucide-react';
import { AuthProvider, useAuth } from './lib/auth';
import { ToastProvider } from './components/toast';
import { Layout } from './components/Layout';
import { Card, NeevMark, PageHeader } from './components/ui';
import { LoginPage } from './pages/Login';
import { DashboardPage } from './pages/Dashboard';
import { CaptainsPage, CaptainDetailPage } from './pages/Captains';
import { PassengersPage, PassengerDetailPage } from './pages/Passengers';
import { RidesPage, RideDetailPage } from './pages/Rides';
import { PricingPage } from './pages/Pricing';
import { CouponsPage } from './pages/Coupons';
import { PowerPassPage } from './pages/PowerPass';
import { TicketsPage } from './pages/Tickets';
import { PaymentsPage } from './pages/Payments';
import { PayoutsPage } from './pages/Payouts';
import { ServiceAreasPage } from './pages/ServiceAreas';
import { SettingsPage } from './pages/Settings';
import { AuditPage } from './pages/Audit';
import { SafetyPage } from './pages/Safety';
import { AdminsPage } from './pages/Admins';

export function App() {
  return (
    <AuthProvider>
      <ToastProvider>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route element={<Protected />}>
            <Route element={<Layout />}>
              <Route index element={<DashboardPage />} />
              <Route path="rides" element={<RidesPage />} />
              <Route path="rides/:id" element={<RideDetailPage />} />
              <Route path="captains" element={<CaptainsPage />} />
              <Route path="captains/:id" element={<CaptainDetailPage />} />
              <Route path="passengers" element={<PassengersPage />} />
              <Route path="passengers/:id" element={<PassengerDetailPage />} />
              <Route path="safety" element={<SafetyPage />} />
              <Route path="pricing" element={<PricingPage />} />
              <Route path="coupons" element={<CouponsPage />} />
              <Route path="power-pass" element={<PowerPassPage />} />
              <Route path="service-areas" element={<ServiceAreasPage />} />
              <Route path="payments" element={<PaymentsPage />} />
              <Route path="payouts" element={<PayoutsPage />} />
              <Route path="tickets" element={<TicketsPage />} />
              <Route path="settings" element={<SettingsPage />} />
              <Route
                path="audit"
                element={
                  <SuperOnly>
                    <AuditPage />
                  </SuperOnly>
                }
              />
              <Route
                path="admins"
                element={
                  <SuperOnly>
                    <AdminsPage />
                  </SuperOnly>
                }
              />
              <Route path="*" element={<NotFound />} />
            </Route>
          </Route>
        </Routes>
      </ToastProvider>
    </AuthProvider>
  );
}

function Protected() {
  const { admin, loading } = useAuth();
  const location = useLocation();

  if (loading) {
    return (
      <div
        style={{
          minHeight: '100vh',
          display: 'grid',
          placeItems: 'center',
          gap: 14,
          background: 'var(--cream)',
        }}
      >
        <div style={{ display: 'grid', justifyItems: 'center', gap: 14 }}>
          <NeevMark size={46} />
          <div className="row" style={{ color: 'var(--muted)', fontSize: 12, fontWeight: 700 }}>
            <span className="spinner" /> Verifying operator session…
          </div>
        </div>
      </div>
    );
  }

  if (!admin) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }

  return <Outlet />;
}

function SuperOnly({ children }: { children: ReactNode }) {
  const { admin } = useAuth();
  if (admin?.role !== 'super_admin') {
    return (
      <div className="forbidden">
        <div className="empty-icon">
          <ShieldX size={22} />
        </div>
        <h2 style={{ fontSize: 20, marginBottom: 6 }}>Super-admin access required</h2>
        <p className="small muted">
          Your role is <strong>{admin?.role.replace('_', ' ')}</strong>. Audit logs and team access
          are restricted to super admins by the API.
        </p>
      </div>
    );
  }
  return <>{children}</>;
}

function NotFound() {
  return (
    <>
      <PageHeader title="Page not found" subtitle="That route does not exist in the operations console." />
      <Card className="card-pad">
        <div className="empty">
          <div className="empty-icon">
            <ShieldX size={20} />
          </div>
          <strong>Nothing here</strong>
          <p>Use the navigation to return to a live operational view.</p>
        </div>
      </Card>
    </>
  );
}
