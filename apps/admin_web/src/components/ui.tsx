import {
  useEffect,
  useId,
  type ButtonHTMLAttributes,
  type CSSProperties,
  type ReactNode,
} from 'react';
import { createPortal } from 'react-dom';
import { Link } from 'react-router-dom';
import {
  ChevronLeft,
  ChevronRight,
  Copy,
  Inbox,
  RefreshCw,
  X,
  AlertTriangle,
} from 'lucide-react';
import { errorMessage } from '../lib/api';
import { initials, statusTone } from '../lib/format';
import { useToast } from './toast';

/* ---------------------------------- Brand --------------------------------- */

export function NeevMark({ size = 40 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden="true">
      <rect width="64" height="64" rx="16" fill="#0E4F45" />
      <path
        d="M18 45V21c0-2 1.6-3 3.2-1.6L43 40.4V21"
        fill="none"
        stroke="#F7F5EF"
        strokeWidth="5.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx="45.5" cy="45" r="4" fill="#F2B544" />
    </svg>
  );
}

/* --------------------------------- Buttons -------------------------------- */

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger' | 'amber';
  size?: 'md' | 'sm';
  loading?: boolean;
}

export function Button({
  variant = 'secondary',
  size = 'md',
  loading = false,
  className = '',
  children,
  disabled,
  ...rest
}: ButtonProps) {
  return (
    <button
      type="button"
      className={`btn btn-${variant} ${size === 'sm' ? 'btn-sm' : ''} ${className}`}
      disabled={disabled || loading}
      {...rest}
    >
      {loading && <span className="spinner" style={{ width: 13, height: 13, borderWidth: 2 }} />}
      {children}
    </button>
  );
}

/* --------------------------------- Badges --------------------------------- */

export function StatusBadge({
  status,
  label,
}: {
  status: string | null | undefined;
  label?: string;
}) {
  const tone = statusTone(status);
  return (
    <span className={`badge badge-${tone}`}>
      <span className="dot" />
      {label ?? (status ? status.replace(/_/g, ' ') : 'unknown')}
    </span>
  );
}

export function Tag({
  children,
  tone,
}: {
  children: ReactNode;
  tone?: 'demo' | 'default';
}) {
  return <span className={`tag ${tone === 'demo' ? 'demo-tag' : ''}`}>{children}</span>;
}

export function Avatar({
  name,
  src,
  size,
  amber,
}: {
  name?: string | null;
  src?: string | null;
  size?: 'lg';
  amber?: boolean;
}) {
  return (
    <span className={`avatar ${size === 'lg' ? 'lg' : ''} ${amber ? 'amber' : ''}`}>
      {src ? <img src={src} alt="" /> : initials(name)}
    </span>
  );
}

/* --------------------------------- Layout --------------------------------- */

export function Card({
  children,
  className = '',
  style,
}: {
  children: ReactNode;
  className?: string;
  style?: CSSProperties;
}) {
  return (
    <section className={`card ${className}`} style={style}>
      {children}
    </section>
  );
}

export function PageHeader({
  title,
  subtitle,
  actions,
  back,
}: {
  title: string;
  subtitle?: ReactNode;
  actions?: ReactNode;
  back?: { to: string; label: string };
}) {
  return (
    <>
      {back && (
        <Link to={back.to} className="back-link">
          <ChevronLeft size={14} />
          {back.label}
        </Link>
      )}
      <div className="page-head">
        <div style={{ minWidth: 0 }}>
          <h1 className="page-title">{title}</h1>
          {subtitle && <p className="page-sub">{subtitle}</p>}
        </div>
        {actions && <div className="page-actions">{actions}</div>}
      </div>
    </>
  );
}

export function Field({
  label,
  hint,
  children,
  span2,
}: {
  label: string;
  hint?: string;
  children: ReactNode;
  span2?: boolean;
}) {
  return (
    <div className={`field ${span2 ? 'span-2' : ''}`}>
      <label>{label}</label>
      {children}
      {hint && <span className="hint">{hint}</span>}
    </div>
  );
}

export function Tabs({
  tabs,
  value,
  onChange,
}: {
  tabs: { id: string; label: string; count?: number }[];
  value: string;
  onChange: (id: string) => void;
}) {
  return (
    <div className="tabs" role="tablist">
      {tabs.map((tab) => (
        <button
          key={tab.id}
          type="button"
          role="tab"
          aria-selected={value === tab.id}
          className={`tab ${value === tab.id ? 'active' : ''}`}
          onClick={() => onChange(tab.id)}
        >
          {tab.label}
          {tab.count !== undefined ? ` (${tab.count})` : ''}
        </button>
      ))}
    </div>
  );
}

/* ----------------------------- Loading / empty ---------------------------- */

export function LoadingBlock({ label = 'Loading live data…' }: { label?: string }) {
  return (
    <div className="loading-block">
      <span className="spinner" />
      {label}
    </div>
  );
}

export function EmptyState({
  title,
  description,
  icon,
  action,
}: {
  title: string;
  description?: string;
  icon?: ReactNode;
  action?: ReactNode;
}) {
  return (
    <div className="empty">
      <div className="empty-icon">{icon ?? <Inbox size={20} />}</div>
      <strong>{title}</strong>
      {description && <p>{description}</p>}
      {action && <div style={{ marginTop: 14 }}>{action}</div>}
    </div>
  );
}

export function ErrorNote({
  error,
  onRetry,
}: {
  error: unknown;
  onRetry?: () => void;
}) {
  return (
    <div className="error-note">
      <AlertTriangle size={15} style={{ flex: 'none', marginTop: 1 }} />
      <div className="grow">
        <div>{errorMessage(error)}</div>
        {onRetry && (
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            style={{ marginTop: 6, paddingLeft: 0 }}
            onClick={onRetry}
          >
            <RefreshCw size={12} /> Retry
          </button>
        )}
      </div>
    </div>
  );
}

/* -------------------------------- Pagination ------------------------------ */

export function Pagination({
  page,
  pageSize,
  total,
  onPage,
}: {
  page: number;
  pageSize: number;
  total: number;
  onPage: (page: number) => void;
}) {
  const pages = Math.max(1, Math.ceil(total / pageSize));
  const from = total === 0 ? 0 : (page - 1) * pageSize + 1;
  const to = Math.min(total, page * pageSize);
  return (
    <div className="pagination">
      <span>
        Showing <strong>{from}–{to}</strong> of <strong>{total}</strong>
      </span>
      <div className="pagination-buttons">
        <Button size="sm" onClick={() => onPage(page - 1)} disabled={page <= 1}>
          <ChevronLeft size={13} /> Prev
        </Button>
        <span className="mono" style={{ padding: '0 4px' }}>
          {page} / {pages}
        </span>
        <Button size="sm" onClick={() => onPage(page + 1)} disabled={page >= pages}>
          Next <ChevronRight size={13} />
        </Button>
      </div>
    </div>
  );
}

/* ---------------------------------- Modal --------------------------------- */

export function Modal({
  open,
  onClose,
  title,
  subtitle,
  children,
  footer,
  wide,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  subtitle?: string;
  children: ReactNode;
  footer?: ReactNode;
  wide?: boolean;
}) {
  const titleId = useId();

  useEffect(() => {
    if (!open) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', onKey);
    const previous = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = previous;
    };
  }, [open, onClose]);

  if (!open) return null;

  return createPortal(
    <div
      className="modal-overlay"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div className={`modal ${wide ? 'wide' : ''}`} role="dialog" aria-modal="true" aria-labelledby={titleId}>
        <div className="modal-head">
          <div className="grow">
            <div className="modal-title" id={titleId}>
              {title}
            </div>
            {subtitle && <div className="modal-sub">{subtitle}</div>}
          </div>
          <button type="button" className="icon-btn" onClick={onClose} aria-label="Close">
            <X size={16} />
          </button>
        </div>
        <div className="modal-body">{children}</div>
        {footer && <div className="modal-foot">{footer}</div>}
      </div>
    </div>,
    document.body,
  );
}

export function ConfirmDialog({
  open,
  title,
  message,
  confirmLabel = 'Confirm',
  tone = 'primary',
  busy = false,
  onConfirm,
  onClose,
}: {
  open: boolean;
  title: string;
  message: ReactNode;
  confirmLabel?: string;
  tone?: 'primary' | 'danger' | 'amber';
  busy?: boolean;
  onConfirm: () => void;
  onClose: () => void;
}) {
  return (
    <Modal
      open={open}
      onClose={onClose}
      title={title}
      footer={
        <>
          <Button onClick={onClose} disabled={busy}>
            Cancel
          </Button>
          <Button variant={tone} onClick={onConfirm} loading={busy}>
            {confirmLabel}
          </Button>
        </>
      }
    >
      <div style={{ fontSize: 13, lineHeight: 1.6, color: 'var(--ink-soft)' }}>{message}</div>
    </Modal>
  );
}

/* --------------------------------- Helpers -------------------------------- */

export function CopyButton({ text, label = 'Copy' }: { text: string; label?: string }) {
  const toast = useToast();
  return (
    <Button
      size="sm"
      onClick={async () => {
        try {
          await navigator.clipboard.writeText(text);
          toast.success('Copied to clipboard');
        } catch {
          toast.error('Clipboard is unavailable in this browser');
        }
      }}
    >
      <Copy size={12} /> {label}
    </Button>
  );
}

export function JsonView({ value }: { value: unknown }) {
  return <pre className="code-block">{JSON.stringify(value, null, 2)}</pre>;
}

export function KV({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="kv">
      <span className="k">{label}</span>
      <span className="v">{value}</span>
    </div>
  );
}
