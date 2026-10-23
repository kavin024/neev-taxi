import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/captain_state.dart';

class CaptainSupportScreen extends StatefulWidget {
  const CaptainSupportScreen({super.key, required this.state});
  final CaptainState state;

  @override
  State<CaptainSupportScreen> createState() => _CaptainSupportScreenState();
}

class _CaptainSupportScreenState extends State<CaptainSupportScreen> {
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
      final tickets = await widget.state.api.tickets();
      if (mounted) setState(() => _tickets = tickets);
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New captain ticket'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'payment', child: Text('Payout')),
                    DropdownMenuItem(value: 'driver', child: Text('Trip')),
                    DropdownMenuItem(value: 'safety', child: Text('Safety')),
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
                    labelText: 'Details',
                    alignLabelWithHint: true,
                  ),
                ),
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
    if (ok == true) {
      try {
        await widget.state.api.createTicket(
          category: category,
          subject: subject.text.trim(),
          description: description.text.trim(),
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

  Future<void> _open(Map<String, dynamic> ticket) async {
    final id = (ticket['id'] ?? '').toString();
    try {
      ticket = await widget.state.api.ticketDetail(id);
    } on ApiException {
      // Fall back to the list payload; the reply endpoint still works.
    }
    if (!mounted) return;
    final reply = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final messages =
              (ticket['messages'] as List? ?? []).cast<Map<String, dynamic>>();
          return AlertDialog(
            title: Text((ticket['subject'] ?? 'Ticket').toString()),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusPill(
                          status: (ticket['status'] ?? 'open').toString(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          humanize((ticket['category'] ?? '').toString()),
                          style: const TextStyle(
                            fontSize: 11,
                            color: NeevColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      (ticket['description'] ?? '').toString(),
                      style: const TextStyle(fontSize: 12.5, height: 1.45),
                    ),
                    if (messages.isNotEmpty) const Divider(height: 24),
                    ...messages.map(
                      (message) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['sender_type'] == 'user'
                                  ? 'You'
                                  : 'Neev support',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: NeevColors.muted,
                              ),
                            ),
                            Text(
                              (message['body'] ?? '').toString(),
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (ticket['status'] != 'resolved')
                      TextField(
                        controller: reply,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Add a reply…',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              if (ticket['status'] != 'resolved')
                FilledButton(
                  onPressed: () async {
                    if (reply.text.trim().isEmpty) return;
                    try {
                      await widget.state.api
                          .replyTicket(id, reply.text.trim());
                      if (context.mounted) {
                        Navigator.pop(context);
                        _load();
                      }
                    } on ApiException catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.message)),
                        );
                      }
                    }
                  },
                  child: const Text('Send'),
                ),
            ],
          );
        },
      ),
    );
    reply.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Captain support'),
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
                      'Ticket-based support only. There is no live captain safety desk in this build. For an emergency, call 112.',
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
                          'Raise a ticket for payouts, trip issues or account review.',
                      action: NeevButton(
                        label: 'New ticket',
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
                          onTap: () => _open(ticket),
                          child: Row(
                            children: [
                              const Icon(Icons.confirmation_number_outlined,
                                  color: NeevColors.green),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (ticket['subject'] ?? '').toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
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
                                status:
                                    (ticket['status'] ?? 'open').toString(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
