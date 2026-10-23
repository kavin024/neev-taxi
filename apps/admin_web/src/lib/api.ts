export class ApiError extends Error {
  status: number;
  code: string;
  details: unknown;
  requestId: string | null;

  constructor(
    status: number,
    code: string,
    message: string,
    details?: unknown,
    requestId?: string | null,
  ) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.details = details;
    this.requestId = requestId ?? null;
  }
}

const TOKEN_KEY = 'neev_admin_token';
export const UNAUTHORIZED_EVENT = 'neev:unauthorized';

export const apiBase = (import.meta.env.VITE_API_BASE_URL ?? '').replace(/\/$/, '');

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string | null): void {
  if (token) localStorage.setItem(TOKEN_KEY, token);
  else localStorage.removeItem(TOKEN_KEY);
}

type QueryValue = string | number | boolean | null | undefined;

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  body?: unknown;
  query?: Record<string, QueryValue>;
  signal?: AbortSignal;
}

function buildPath(path: string, query?: Record<string, QueryValue>): string {
  const base = `${apiBase}/api/v1${path}`;
  if (!query) return base;
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value === undefined || value === null || value === '') continue;
    params.set(key, String(value));
  }
  const qs = params.toString();
  return qs ? `${base}?${qs}` : base;
}

export async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const headers: Record<string, string> = { Accept: 'application/json' };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  let body: BodyInit | undefined;
  if (options.body !== undefined) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(options.body);
  }
  let response: Response;
  try {
    response = await fetch(buildPath(path, options.query), {
      method: options.method ?? 'GET',
      headers,
      body,
      signal: options.signal,
    });
  } catch (error) {
    if ((error as Error).name === 'AbortError') throw error;
    throw new ApiError(
      0,
      'network_error',
      'Cannot reach the Neev API. Check that the backend is running and try again.',
    );
  }

  if (response.status === 204) return undefined as T;

  const text = await response.text();
  let payload: unknown = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = text;
    }
  }

  if (!response.ok) {
    if (response.status === 401) {
      setToken(null);
      window.dispatchEvent(new CustomEvent(UNAUTHORIZED_EVENT));
    }
    const err = (payload as { error?: { code?: string; message?: string; details?: unknown } } | null)
      ?.error;
    const requestId = (payload as { request_id?: string } | null)?.request_id ?? null;
    throw new ApiError(
      response.status,
      err?.code ?? 'http_error',
      err?.message ?? `Request failed with status ${response.status}.`,
      err?.details,
      requestId,
    );
  }
  return payload as T;
}

export const api = {
  get: <T>(path: string, query?: Record<string, QueryValue>, signal?: AbortSignal) =>
    request<T>(path, { method: 'GET', query, signal }),
  post: <T>(path: string, body?: unknown) => request<T>(path, { method: 'POST', body }),
  put: <T>(path: string, body?: unknown) => request<T>(path, { method: 'PUT', body }),
  patch: <T>(path: string, body?: unknown) => request<T>(path, { method: 'PATCH', body }),
  delete: <T>(path: string) => request<T>(path, { method: 'DELETE' }),
};

export function absoluteApiUrl(path: string): string {
  if (/^https?:\/\//i.test(path)) return path;
  return `${apiBase}${path}`;
}

export function errorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    const details = error.details;
    if (Array.isArray(details) && details.length > 0) {
      const first = details[0] as { field?: string; message?: string; missing?: string[] };
      if (Array.isArray(first?.missing) && first.missing.length) {
        return `${error.message} Missing: ${first.missing.join(', ')}.`;
      }
      if (first?.field) return `${error.message} (${first.field})`;
    }
    return error.message;
  }
  if (error instanceof Error) return error.message;
  return 'Something went wrong. Please try again.';
}
