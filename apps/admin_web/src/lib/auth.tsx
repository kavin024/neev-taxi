import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { api, getToken, setToken, UNAUTHORIZED_EVENT } from './api';
import type { AdminUser } from './types';

const ADMIN_KEY = 'neev_admin_profile';

interface AuthState {
  admin: AdminUser | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthState | null>(null);

export function readStoredAdmin(): AdminUser | null {
  try {
    const raw = localStorage.getItem(ADMIN_KEY);
    return raw ? (JSON.parse(raw) as AdminUser) : null;
  } catch {
    return null;
  }
}

function storeAdmin(admin: AdminUser | null): void {
  if (admin) localStorage.setItem(ADMIN_KEY, JSON.stringify(admin));
  else localStorage.removeItem(ADMIN_KEY);
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [admin, setAdmin] = useState<AdminUser | null>(() =>
    getToken() ? readStoredAdmin() : null,
  );
  const [loading, setLoading] = useState(Boolean(getToken()));

  const logout = useCallback(() => {
    setToken(null);
    storeAdmin(null);
    setAdmin(null);
  }, []);

  useEffect(() => {
    const onUnauthorized = () => {
      storeAdmin(null);
      setAdmin(null);
    };
    window.addEventListener(UNAUTHORIZED_EVENT, onUnauthorized);
    return () => window.removeEventListener(UNAUTHORIZED_EVENT, onUnauthorized);
  }, []);

  useEffect(() => {
    if (!getToken()) {
      setLoading(false);
      return;
    }
    let cancelled = false;
    api
      .get<AdminUser>('/admin/auth/me')
      .then((profile) => {
        if (cancelled) return;
        setAdmin(profile);
        storeAdmin(profile);
      })
      .catch(() => {
        if (!cancelled) setAdmin(null);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const response = await api.post<{
      access_token: string;
      token_type: string;
      expires_in: number;
      admin: AdminUser;
    }>('/admin/auth/login', { email, password });
    setToken(response.access_token);
    storeAdmin(response.admin);
    setAdmin(response.admin);
  }, []);

  const value = useMemo(
    () => ({ admin, loading, login, logout }),
    [admin, loading, login, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}
