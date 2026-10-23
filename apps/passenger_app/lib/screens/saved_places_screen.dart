import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/passenger_state.dart';
import 'place_picker.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key, required this.state});
  final PassengerState state;

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
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
      final items = await widget.state.api.savedAddresses();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final place = await showPlacePicker(
      context,
      state: widget.state,
      title: 'Save a place',
    );
    if (place == null || !mounted) return;
    final labelController = TextEditingController(text: place.name);
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this place'),
        content: TextField(
          controller: labelController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Home, Work, Gym…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, labelController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    labelController.dispose();
    if (label == null || label.isEmpty) return;
    try {
      await widget.state.api.addSavedAddress(
        label: label,
        address: place.address,
        lat: place.lat,
        lng: place.lng,
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

  Future<void> _delete(String id) async {
    try {
      await widget.state.api.deleteSavedAddress(id);
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
        title: const Text('Saved places'),
        actions: [
          IconButton(
            tooltip: 'Add place',
            onPressed: _add,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const LoadingState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
              children: [
                if (_error != null) ErrorBanner(message: _error!, onRetry: _load),
                if (_items.isEmpty && _error == null)
                  const EmptyState(
                    icon: Icons.bookmark_border,
                    title: 'No saved places',
                    message:
                        'Save home, work or a frequent pickup to book faster.',
                  )
                else
                  ..._items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: NeevCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.bookmark_outline,
                                color: NeevColors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (item['label'] ?? 'Saved').toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    (item['address'] ?? '').toString(),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: NeevColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove',
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
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add place'),
      ),
    );
  }
}
