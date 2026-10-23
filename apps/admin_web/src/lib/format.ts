const inr = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
});

const inrPrecise = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

export function money(paise: number | null | undefined, precise = false): string {
  if (paise === null || paise === undefined) return '—';
  const value = paise / 100;
  if (precise && value % 1 !== 0) return inrPrecise.format(value);
  return inr.format(value);
}

export function compactMoney(paise: number | null | undefined): string {
  if (paise === null || paise === undefined) return '—';
  const value = paise / 100;
  if (value >= 10_000_000) return `₹${(value / 10_000_000).toFixed(1)}Cr`;
  if (value >= 100_000) return `₹${(value / 100_000).toFixed(1)}L`;
  if (value >= 1_000) return `₹${(value / 1_000).toFixed(1)}k`;
  return inr.format(value);
}

export function number(value: number | null | undefined): string {
  if (value === null || value === undefined) return '—';
  return new Intl.NumberFormat('en-IN').format(value);
}

export function percent(value: number | null | undefined, digits = 0): string {
  if (value === null || value === undefined) return '—';
  return `${value.toFixed(digits)}%`;
}

export function dateLabel(value: string | null | undefined): string {
  if (!value) return '—';
  return new Date(value).toLocaleDateString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
}

export function dayLabel(value: string | null | undefined): string {
  if (!value) return '—';
  return new Date(value).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' });
}

export function timeLabel(value: string | null | undefined): string {
  if (!value) return '—';
  return new Date(value).toLocaleTimeString('en-IN', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
  });
}

export function dateTime(value: string | null | undefined): string {
  if (!value) return '—';
  return `${dateLabel(value)}, ${timeLabel(value)}`;
}

export function relativeTime(value: string | null | undefined): string {
  if (!value) return '—';
  const then = new Date(value).getTime();
  const diff = Date.now() - then;
  const minutes = Math.round(diff / 60_000);
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours} hr ago`;
  const days = Math.round(hours / 24);
  if (days < 7) return `${days} day${days === 1 ? '' : 's'} ago`;
  return dateLabel(value);
}

export function durationLabel(seconds: number | null | undefined): string {
  if (seconds === null || seconds === undefined) return '—';
  const mins = Math.round(seconds / 60);
  if (mins < 60) return `${mins} min`;
  return `${Math.floor(mins / 60)}h ${mins % 60}m`;
}

export function distanceLabel(metres: number | null | undefined): string {
  if (metres === null || metres === undefined) return '—';
  if (metres < 1000) return `${Math.round(metres)} m`;
  return `${(metres / 1000).toFixed(1)} km`;
}

export function initials(name: string | null | undefined): string {
  if (!name) return '··';
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? '')
    .join('');
}

export function titleCase(value: string | null | undefined): string {
  if (!value) return '—';
  return value
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

export function categoryLabel(value: string | null | undefined): string {
  const map: Record<string, string> = { bike: 'Bike', auto: 'Auto', cab: 'Cab' };
  return (value && map[value]) || titleCase(value);
}

export function truncate(value: string, max = 48): string {
  return value.length > max ? `${value.slice(0, max - 1)}…` : value;
}

export function toInputDate(value: Date): string {
  const local = new Date(value.getTime() - value.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
}

export function statusTone(status: string | null | undefined): string {
  const value = (status ?? '').toLowerCase();
  if (
    ['active', 'approved', 'completed', 'captured', 'resolved', 'closed', 'delivered', 'online'].includes(
      value,
    )
  )
    return 'success';
  if (
    ['pending', 'searching', 'requested', 'processing', 'open', 'arriving', 'in_progress', 'assigned'].includes(
      value,
    )
  )
    return 'warn';
  if (
    ['rejected', 'suspended', 'cancelled', 'failed', 'expired', 'offline', 'refunded'].includes(value)
  )
    return 'danger';
  if (['offered', 'accepted', 'captain_arriving', 'arrived', 'in_progress'].includes(value))
    return 'info';
  return 'neutral';
}
