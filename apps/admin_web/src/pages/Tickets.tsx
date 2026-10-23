import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { CheckCircle2, CornerDownLeft, LifeBuoy, Send } from 'lucide-react';
import { api, errorMessage } from '../lib/api';
import { useApi } from '../lib/hooks';
import { useToast } from '../components/toast';
import {
  Button,
  Card,
  ErrorNote,
  Field,
  LoadingBlock,
  Modal,
  PageHeader,
  StatusBadge,
  Tabs,
} from '../components/ui';
import type { Paginated, SupportTicket } from '../lib/types';
import { dateLabel, dateTime, relativeTime, titleCase } from '../lib/format';

const statusTabs = [
  { id: '', label: 'All' },
  { id: 'open', label: 'Open' },
  { id: 'pending', label: 'Awaiting passenger' },
  { id: 'resolved', label: 'Resolved' },
  { id: 'closed', label: 'Closed' },
];

export function TicketsPage() {
  const [params, setParams] = useSearchParams();
  const toast = useToast();
  const status = params.get('status') ?? '';
  const ticketParam = params.get('ticket') ?? '';
  const { data, loading, error, reload } = useApi<Paginated<SupportTicket>>('/admin/tickets', {
    status: status || undefined,
    page_size: 50,
  });
  const selectedId = ticketParam || data?.items[0]?.id || '';
  const detail = useApi<SupportTicket>(
    selectedId ? `/admin/tickets/${selectedId}` : null,
  );
  const ticket = detail.data ?? data?.items.find((item) => item.id === selectedId) ?? null;
  const [reply, setReply] = useState('');
  const [sending, setSending] = useState(false);
  const [resolveOpen, setResolveOpen] = useState(false);
  const [resolution, setResolution] = useState('');
  const [resolveStatus, setResolveStatus] = useState<'resolved' | 'closed' | 'pending'>('resolved');
  const [busy, setBusy] = useState(false);
  const threadEnd = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    threadEnd.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
  }, [ticket?.messages.length, selectedId]);

  const sorted = useMemo(
    () =>
      (data?.items ?? []).slice().sort((a, b) => (a.updated_at < b.updated_at ? 1 : -1)),
    [data],
  );

  function selectTicket(id: string) {
    setParams((current) => {
      const next = new URLSearchParams(current);
      next.set('ticket', id);
      return next;
    });
  }

  async function sendReply() {
    if (!ticket || reply.trim().length === 0) return;
    setSending(true);
    try {
      await api.post(`/admin/tickets/${ticket.id}/reply`, { body: reply.trim() });
      toast.success('Reply sent to the passenger app.');
      setReply('');
      reload();
      detail.reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setSending(false);
    }
  }

  async function resolveTicket() {
    if (!ticket) return;
    setBusy(true);
    try {
      await api.post(`/admin/tickets/${ticket.id}/resolve`, {
        resolution_notes: resolution.trim(),
        status: resolveStatus,
      });
      toast.success('Ticket updated and the passenger notified.');
      setResolveOpen(false);
      setResolution('');
      reload();
      detail.reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <PageHeader
        title="Ticket desk"
        subtitle="Passenger and captain conversations, threaded against the account and ride."
        actions={
          <Button onClick={() => { reload(); detail.reload(); }} loading={loading}>
            Refresh desk
          </Button>
        }
      />

      <Card>
        <Tabs
          value={status}
          onChange={(value) =>
            setParams((current) => {
              const next = new URLSearchParams(current);
              if (value) next.set('status', value);
              else next.delete('status');
              next.delete('ticket');
              return next;
            })
          }
          tabs={statusTabs}
        />

        {error ? (
          <div style={{ padding: 18 }}>
            <ErrorNote error={error} onRetry={reload} />
          </div>
        ) : loading && !data ? (
          <LoadingBlock />
        ) : data?.items.length === 0 ? (
          <div className="empty" style={{ padding: 64 }}>
            <div className="empty-icon">
              <LifeBuoy size={20} />
            </div>
            <strong>No tickets in this queue</strong>
            <p>When a passenger or captain raises an issue it lands here in real time.</p>
          </div>
        ) : (
          <div className="ticket-layout" style={{ padding: 14 }}>
            <Card className="ticket-list" style={{ boxShadow: 'none' }}>
              {sorted.map((item) => (
                <button
                  key={item.id}
                  type="button"
                  className={`ticket-item ${item.id === selectedId ? 'active' : ''}`}
                  onClick={() => selectTicket(item.id)}
                  style={{ width: '100%', textAlign: 'left', background: 'transparent' }}
                >
                  <div className="row-between" style={{ marginBottom: 3 }}>
                    <span className="tag">{titleCase(item.category)}</span>
                    <span className="tiny muted">{relativeTime(item.updated_at)}</span>
                  </div>
                  <div className="subject">{item.subject}</div>
                  <div className="meta">
                    <StatusBadge status={item.status} />
                    <span>{item.user_phone ?? 'Account'}</span>
                    {item.priority !== 'normal' && (
                      <span className="badge badge-danger">{item.priority}</span>
                    )}
                  </div>
                </button>
              ))}
            </Card>

            <Card className="ticket-thread">
              {detail.loading && !ticket ? (
                <LoadingBlock />
              ) : ticket ? (
                <>
                  <div className="thread-head">
                    <div className="row-between" style={{ alignItems: 'flex-start' }}>
                      <div style={{ minWidth: 0 }}>
                        <div className="row wrap" style={{ gap: 8, marginBottom: 5 }}>
                          <StatusBadge status={ticket.status} />
                          <span className="tag">{titleCase(ticket.category)}</span>
                          {ticket.priority !== 'normal' && (
                            <span className="badge badge-danger">{ticket.priority}</span>
                          )}
                        </div>
                        <div className="detail-name" style={{ fontSize: 17 }}>
                          {ticket.subject}
                        </div>
                        <div className="detail-meta">
                          <span>{ticket.user_phone ?? ticket.user_id.slice(0, 12)}</span>
                          <span>·</span>
                          <span>{titleCase(ticket.user_role ?? 'user')}</span>
                          <span>·</span>
                          <span>Opened {dateTime(ticket.created_at)}</span>
                          {ticket.ride_request_id && (
                            <>
                              <span>·</span>
                              <Link
                                to={`/rides/${ticket.ride_request_id}`}
                                className="mono"
                                style={{ color: 'var(--green)' }}
                              >
                                Ride {ticket.ride_request_id.slice(0, 8)}…
                              </Link>
                            </>
                          )}
                        </div>
                      </div>
                      <Button onClick={() => {
                        setResolution(ticket.resolution_notes ?? '');
                        setResolveOpen(true);
                      }}>
                        <CheckCircle2 size={13} /> Resolve
                      </Button>
                    </div>
                  </div>

                  <div className="thread-body">
                    <div className="bubble user">
                      <div className="bubble-meta">Request · {dateTime(ticket.created_at)}</div>
                      {ticket.description}
                    </div>
                    {ticket.messages.map((message) => (
                      <div
                        key={message.id}
                        className={`bubble ${message.sender_type === 'admin' ? 'admin' : 'user'}`}
                      >
                        <div className="bubble-meta">
                          {titleCase(message.sender_type)} · {dateTime(message.created_at)}
                        </div>
                        {message.body}
                      </div>
                    ))}
                    {ticket.resolution_notes && (
                      <div className="note-box" style={{ alignSelf: 'stretch' }}>
                        <strong>Resolution note</strong>
                        {ticket.resolution_notes}
                        <div className="tiny muted" style={{ marginTop: 4 }}>
                          {ticket.resolved_at ? dateTime(ticket.resolved_at) : ''}
                        </div>
                      </div>
                    )}
                    <div ref={threadEnd} />
                  </div>

                  <div className="thread-compose">
                    <textarea
                      value={reply}
                      onChange={(event) => setReply(event.target.value)}
                      placeholder="Reply to the passenger… (Ctrl+Enter to send)"
                      onKeyDown={(event) => {
                        if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
                          event.preventDefault();
                          sendReply();
                        }
                      }}
                    />
                    <Button
                      variant="primary"
                      loading={sending}
                      disabled={reply.trim().length === 0}
                      onClick={sendReply}
                    >
                      <Send size={14} /> Send
                    </Button>
                  </div>
                </>
              ) : (
                <div className="empty">
                  <div className="empty-icon">
                    <CornerDownLeft size={18} />
                  </div>
                  <strong>Select a ticket</strong>
                  <p>Pick a conversation from the queue to read the full thread.</p>
                </div>
              )}
            </Card>
          </div>
        )}
      </Card>

      <p className="tiny muted" style={{ marginTop: 12 }}>
        Showing the 50 most recent tickets. Replies set the ticket to <strong>pending</strong> until
        the passenger responds.
      </p>

      <Modal
        open={resolveOpen}
        onClose={() => setResolveOpen(false)}
        title="Close out ticket"
        subtitle={`${ticket?.subject ?? ''} · ${ticket ? dateLabel(ticket.created_at) : ''}`}
        footer={
          <>
            <Button onClick={() => setResolveOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant="primary"
              loading={busy}
              disabled={resolution.trim().length < 3}
              onClick={resolveTicket}
            >
              Save resolution
            </Button>
          </>
        }
      >
        <Field label="Resolution status">
          <select
            value={resolveStatus}
            onChange={(event) =>
              setResolveStatus(event.target.value as 'resolved' | 'closed' | 'pending')
            }
          >
            <option value="resolved">Resolved</option>
            <option value="pending">Keep pending</option>
            <option value="closed">Closed without resolution</option>
          </select>
        </Field>
        <Field label="Resolution notes" hint="Shared with the user. At least 3 characters.">
          <textarea
            value={resolution}
            onChange={(event) => setResolution(event.target.value)}
            placeholder="e.g. Fare difference refunded; passenger confirmed receipt."
          />
        </Field>
      </Modal>
    </>
  );
}
