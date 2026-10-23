import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { CheckCircle2, Info, X, XCircle } from 'lucide-react';

type ToastKind = 'success' | 'error' | 'info';

interface ToastItem {
  id: number;
  kind: ToastKind;
  message: string;
}

interface ToastState {
  push: (message: string, kind?: ToastKind) => void;
  success: (message: string) => void;
  error: (message: string) => void;
}

const ToastContext = createContext<ToastState | null>(null);

let nextId = 1;

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([]);

  const remove = useCallback((id: number) => {
    setItems((current) => current.filter((item) => item.id !== id));
  }, []);

  const push = useCallback(
    (message: string, kind: ToastKind = 'info') => {
      const id = nextId++;
      setItems((current) => [...current.slice(-3), { id, kind, message }]);
      window.setTimeout(() => remove(id), 5200);
    },
    [remove],
  );

  const value = useMemo<ToastState>(
    () => ({
      push,
      success: (message: string) => push(message, 'success'),
      error: (message: string) => push(message, 'error'),
    }),
    [push],
  );

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div className="toasts" role="status" aria-live="polite">
        {items.map((item) => (
          <div key={item.id} className={`toast ${item.kind}`}>
            {item.kind === 'success' ? (
              <CheckCircle2 size={16} style={{ flex: 'none', marginTop: 1 }} />
            ) : item.kind === 'error' ? (
              <XCircle size={16} style={{ flex: 'none', marginTop: 1 }} />
            ) : (
              <Info size={16} style={{ flex: 'none', marginTop: 1 }} />
            )}
            <span>{item.message}</span>
            <button type="button" onClick={() => remove(item.id)} aria-label="Dismiss">
              <X size={13} />
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastState {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToast must be used inside ToastProvider');
  return ctx;
}
