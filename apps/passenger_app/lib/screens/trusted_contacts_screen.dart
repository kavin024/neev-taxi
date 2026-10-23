import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/passenger_state.dart';

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key, required this.state});
  final PassengerState state;

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  List<Map<String, dynamic>> _items = const [];
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
      final items = await widget.state.api.trustedContacts();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final relationship = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a trusted contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+91…',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: relationship,
                decoration:
                    const InputDecoration(labelText: 'Relationship (optional)'),
              ),
              const SizedBox(height: 12),
              const Text(
                'SOS messages are queued through the configured SMS adapter when an incident is created. This build has no emergency-dispatch integration.',
                style: TextStyle(fontSize: 11.5, color: NeevColors.muted),
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
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (saved == true) {
      try {
        await widget.state.api.addTrustedContact(
          name: name.text.trim(),
          phone: phone.text.trim(),
          relationship: relationship.text.trim().isEmpty
              ? null
              : relationship.text.trim(),
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
    name.dispose();
    phone.dispose();
    relationship.dispose();
  }

  Future<void> _delete(String id) async {
    try {
      await widget.state.api.deleteTrustedContact(id);
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
        title: const Text('Trusted contacts'),
        actions: [
          IconButton(
            onPressed: _add,
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: _loading
          ? const LoadingState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
              children: [
                const NeevCard(
                  color: NeevColors.amberSoft,
                  borderColor: NeevColors.amber,
                  child: Text(
                    'Trusted contacts receive an SMS when you trigger SOS. The SMS adapter is unconfigured in this build, so messages are recorded as queued rather than delivered. Call 112 in a real emergency.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
                const SizedBox(height: 14),
                if (_error != null)
                  ErrorBanner(message: _error!, onRetry: _load)
                else if (_items.isEmpty)
                  const EmptyState(
                    icon: Icons.people_outline,
                    title: 'No trusted contacts',
                    message: 'Add up to five people for SOS notifications.',
                  )
                else
                  ..._items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: NeevCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            NeevAvatar(
                              name: (item['name'] ?? 'Contact').toString(),
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (item['name'] ?? '').toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    [
                                      maskPhone(
                                          (item['phone'] ?? '').toString()),
                                      if ((item['relationship'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        item['relationship'].toString(),
                                    ].join(' · '),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: NeevColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  _delete((item['id'] ?? '').toString()),
                              icon: const Icon(Icons.delete_outline, size: 19),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: NeevColors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add contact'),
      ),
    );
  }
}
