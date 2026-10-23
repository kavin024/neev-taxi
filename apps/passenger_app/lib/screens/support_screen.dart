import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/passenger_state.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.state, this.rideId});
  final PassengerState state;
  final String? rideId;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  List<Map<String, dynamic>> _tickets = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await widget.state.api.tickets();
      if (mounted) setState(() => _tickets = items);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final subject = TextEditingController();
    final description = TextEditingController();
    String category = 'app';
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New support ticket'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'payment', child: Text('Payment')),
                    DropdownMenuItem(
                        value: 'cancellation', child: Text('Cancellation')),
                    DropdownMenuItem(value: 'safety', child: Text('Safety')),
                    DropdownMenuItem(value: 'driver', child: Text('Captain')),
                    DropdownMenuItem(value: 'app', child: Text('App issue')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => category = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'What happened?',
                    alignLabelWithHint: true,
                  ),
                ),
                if (category == 'safety') ...[
                  const SizedBox(height: 10),
                  const Text(
                    'For an emergency, call 112 now. In-app tickets are reviewed by staff but are not a live emergency channel.',
                    style:
                        TextStyle(fontSize: 11.5, color: NeevColors.danger),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (created == true) {
      try {
        await widget.state.api.createTicket(
          category: category,
          subject: subject.text.trim(),
          description: description.text.trim(),
          rideId: widget.rideId,
        );
        await _load();
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        }
      }
    }
    subject.dispose();
    description.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        actions: [
          IconButton(onPressed: _create, icon: const Icon(Icons.add)),
        ],
      ),
      body: _loading
          ? const LoadingState()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                children: [
                  const NeevCard(
                    color: NeevColors.amberSoft,
                    borderColor: NeevColors.amber,
                    child: Text(
                      'Neev support in this build is ticket-based. There is no 24×7 phone desk. For emergencies in India, call 112.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_error != null)
                    ErrorBanner(message: _error!, onRetry: _load)
                  else if (_tickets.isEmpty)
                    EmptyState(
                      icon: Icons.support_agent_outlined,
                      title: 'No tickets yet',
                      message:
                          'Open a ticket for a fare, trip or app issue. A human reviews it in the admin console.',
                      action: NeevButton(
                        label: 'Open a ticket',
                        expand: false,
                        onPressed: _create,
                      ),
                    )
                  else
                    ..._tickets.map(
                      (ticket) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: NeevCard(
                          padding: const EdgeInsets.all(14),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TicketDetailScreen(
                                  state: widget.state,
                                  ticketId: (ticket['id'] ?? '').toString(),
                                ),
                              ),
                            );
                            _load();
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.confirmation_number_outlined,
                                  color: NeevColors.green),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (ticket['subject'] ?? '').toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    Text(
                                      '${humanize((ticket['category'] ?? '').toString())} · ${relativeTime(DateTime.tryParse((ticket['created_at'] ?? '').toString()))}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: NeevColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusPill(
                                status: (ticket['status'] ?? 'open').toString(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: NeevColors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New ticket'),
      ),
    );
  }
}

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({
    super.key,
    required this.state,
    required this.ticketId,
  });
  final PassengerState state;
  final String ticketId;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  Map<String, dynamic>? _ticket;
  final _reply = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ticket =
          await widget.state.api.ticketDetail(widget.ticketId);
      if (mounted) setState(() => _ticket = ticket);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.state.api.replyTicket(widget.ticketId, body);
      _reply.clear();
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages =
        (_ticket?['messages'] as List? ?? []).cast<Map<String, dynamic>>();
    final closed = _ticket?['status'] == 'resolved' ||
        _ticket?['status'] == 'closed';
    return Scaffold(
      appBar: AppBar(title: Text(_ticket?['subject']?.toString() ?? 'Ticket')),
      body: _loading
          ? const LoadingState()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                    children: [
                      if (_error != null) ...[
                        ErrorBanner(message: _error!, onRetry: _load),
                        const SizedBox(height: 10),
                      ],
                      NeevCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (_ticket?['subject'] ?? '').toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                StatusPill(
                                  status:
                                      (_ticket?['status'] ?? 'open').toString(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${humanize((_ticket?['category'] ?? '').toString())} · ${dateTimeLabel(DateTime.tryParse((_ticket?['created_at'] ?? '').toString()))}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: NeevColors.muted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              (_ticket?['description'] ?? '').toString(),
                              style: const TextStyle(fontSize: 13, height: 1.5),
                            ),
                            if ((_ticket?['resolution_notes'] ?? '')
                                .toString()
                                .isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: NeevColors.greenSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Resolution: ${_ticket!['resolution_notes']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...messages.map(
                        (message) {
                          final fromUser = message['sender_type'] == 'user';
                          return Align(
                            alignment: fromUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 420),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: fromUser
                                    ? NeevColors.green
                                    : NeevColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: fromUser
                                    ? null
                                    : Border.all(color: NeevColors.line),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fromUser ? 'You' : 'Neev support',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: fromUser
                                          ? Colors.white70
                                          : NeevColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    (message['body'] ?? '').toString(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: fromUser
                                          ? Colors.white
                                          : NeevColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (!closed)
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      decoration: const BoxDecoration(
                        color: NeevColors.surface,
                        border: Border(top: BorderSide(color: NeevColors.line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _reply,
                              minLines: 1,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Write a reply…',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _sending ? null : _send,
                            icon: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'This ticket is closed. Open a new ticket if you need more help.',
                        style: TextStyle(
                          fontSize: 12,
                          color: NeevColors.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
