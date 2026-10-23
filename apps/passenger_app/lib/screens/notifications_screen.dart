import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/passenger_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.state});
  final PassengerState state;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = const [];
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
      final items = await widget.state.api.notifications();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAll() async {
    try {
      await widget.state.api.markNotificationsRead();
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _items.any((n) => n.unread) ? _markAll : null,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: _loading
          ? const LoadingState()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                children: [
                  if (_error != null)
                    ErrorBanner(message: _error!, onRetry: _load)
                  else if (_items.isEmpty)
                    const EmptyState(
                      icon: Icons.notifications_none,
                      title: 'Nothing new',
                      message:
                          'Trip and payment updates will appear here.',
                    )
                  else
                    ..._items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: NeevCard(
                          color: item.unread
                              ? NeevColors.greenSoft
                              : NeevColors.surface,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _icon(item.type),
                                size: 20,
                                color: NeevColors.green,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.body,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: NeevColors.inkSoft,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      relativeTime(item.createdAt),
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: NeevColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (item.unread)
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsets.only(top: 5),
                                  decoration: const BoxDecoration(
                                    color: NeevColors.green,
                                    shape: BoxShape.circle,
                                  ),
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

  IconData _icon(String type) {
    if (type.contains('payment')) return Icons.receipt_long_outlined;
    if (type.contains('trip')) return Icons.route_outlined;
    if (type.contains('safety')) return Icons.shield_outlined;
    if (type.contains('support')) return Icons.support_agent_outlined;
    return Icons.notifications_none;
  }
}
