import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/passenger_state.dart';
import 'ride_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.state});
  final PassengerState state;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Ride> _rides = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rides = await widget.state.api.rides(limit: 40);
      if (mounted) setState(() => _rides = rides);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Ride> get _filtered {
    switch (_filter) {
      case 'completed':
        return _rides.where((r) => r.isComplete).toList();
      case 'cancelled':
        return _rides.where((r) => r.isCancelled).toList();
      case 'live':
        return _rides.where((r) => r.isLive).toList();
      default:
        return _rides;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your rides',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 3),
                    const Text(
                      'Every trip is stored server-side with its fare and status.',
                      style: TextStyle(fontSize: 12.5, color: NeevColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in const [
                  ('all', 'All'),
                  ('live', 'Live'),
                  ('completed', 'Completed'),
                  ('cancelled', 'Cancelled'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.$2),
                      selected: _filter == entry.$1,
                      onSelected: (_) => setState(() => _filter = entry.$1),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading && _rides.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: LoadingState(label: 'Loading your rides…'),
            )
          else if (_error != null)
            ErrorBanner(message: _error!, onRetry: _load)
          else if (_filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: EmptyState(
                icon: Icons.route_outlined,
                title: 'No rides here yet',
                message: 'Book your first Neev ride from the Ride tab.',
              ),
            )
          else
            ..._filtered.map(
              (ride) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RideHistoryTile(
                  ride: ride,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RideScreen(
                          state: widget.state,
                          initialRide: ride,
                        ),
                      ),
                    );
                    _load();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RideHistoryTile extends StatelessWidget {
  const _RideHistoryTile({required this.ride, required this.onTap});
  final Ride ride;
  final VoidCallback onTap;

  IconData get _icon => switch (ride.category) {
        'bike' => Icons.two_wheeler,
        'auto' => Icons.electric_rickshaw,
        _ => Icons.local_taxi,
      };

  @override
  Widget build(BuildContext context) {
    final displayFare = ride.trip?.finalFarePaise ?? ride.quotedFarePaise;
    final settled = ride.payment?.status == 'captured' ||
        ride.payment?.status == 'paid' ||
        ride.trip?.paymentStatus == 'captured';
    return NeevCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: NeevColors.cream,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(_icon, size: 21, color: NeevColors.greenDeep),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${humanize(ride.category)} · ${dateLabel(ride.createdAt)}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      ride.dropAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: NeevColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(displayFare),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  StatusPill(
                    status: ride.isComplete && !settled
                        ? 'pending'
                        : ride.status,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.trip_origin,
                  size: 12, color: NeevColors.amber),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  ride.pickupAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: NeevColors.muted,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward,
                  size: 12, color: NeevColors.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  ride.dropAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: NeevColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
