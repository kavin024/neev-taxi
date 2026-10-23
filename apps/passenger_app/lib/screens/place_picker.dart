import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/passenger_state.dart';

/// Search sheet backed by the configured map provider. Results are always
/// labelled by the provider so users know when a demo fixture is in use.
Future<Place?> showPlacePicker(
  BuildContext context, {
  required PassengerState state,
  required String title,
  List<Map<String, dynamic>> saved = const [],
}) {
  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    backgroundColor: NeevColors.cream,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.86,
      child: _PlacePickerSheet(
        state: state,
        title: title,
        saved: saved,
      ),
    ),
  );
}

class _PlacePickerSheet extends StatefulWidget {
  const _PlacePickerSheet({
    required this.state,
    required this.title,
    required this.saved,
  });

  final PassengerState state;
  final String title;
  final List<Map<String, dynamic>> saved;

  @override
  State<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<_PlacePickerSheet> {
  final _controller = TextEditingController(text: 'Bengaluru');
  Timer? _debounce;
  List<Place> _results = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('Bengaluru');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (value.trim().isNotEmpty) _search(value.trim());
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.state.api.searchPlaces(query);
      if (!mounted) return;
      setState(() => _results = results);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: NeevColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _controller,
              autofocus: false,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Search for an area or landmark',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          if (widget.saved.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.saved.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = widget.saved[index];
                    return ActionChip(
                      avatar: const Icon(Icons.bookmark_outline, size: 15),
                      label: Text(
                        (item['label'] ?? item['name'] ?? 'Saved').toString(),
                      ),
                      onPressed: () => Navigator.pop(
                        context,
                        Place(
                          id: (item['id'] ?? '').toString(),
                          name: (item['label'] ?? item['name'] ?? 'Saved place')
                              .toString(),
                          address: (item['address'] ?? '').toString(),
                          lat: (item['lat'] as num?)?.toDouble() ?? 0,
                          lng: (item['lng'] as num?)?.toDouble() ?? 0,
                          label: 'Saved place',
                          provider: 'saved',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          const Divider(),
          Expanded(
            child: _loading
                ? const LoadingState(label: 'Searching the demo place index…')
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: ErrorBanner(
                          message: _error!,
                          onRetry: () => _search(_controller.text.trim()),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            const Divider(indent: 64, endIndent: 20),
                        itemBuilder: (context, index) {
                          final place = _results[index];
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: NeevColors.greenSoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.place_outlined,
                                  size: 19, color: NeevColors.green),
                            ),
                            title: Text(
                              place.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                            subtitle: Text(
                              place.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: NeevColors.muted,
                              ),
                            ),
                            trailing: DemoBadge(label: place.label),
                            onTap: () => Navigator.pop(context, place),
                          );
                        },
                      ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            color: NeevColors.surface,
            child: Text(
              widget.state.isDemoMap
                  ? 'Demo place index with real Bengaluru coordinates. Configure a production map provider before launch.'
                  : 'Places are provided by the configured development map provider.',
              style: const TextStyle(fontSize: 11, color: NeevColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
