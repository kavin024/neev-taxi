import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/captain_state.dart';
import 'trip_screen.dart';

class CaptainTripsScreen extends StatefulWidget {
  const CaptainTripsScreen({super.key, required this.state});
  final CaptainState state;

  @override
  State<CaptainTripsScreen> createState() => _CaptainTripsScreenState();
}

class _CaptainTripsScreenState extends State<CaptainTripsScreen> {
  List<Ride> _rides = const [];
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
      final rides = await widget.state.api.captainTrips();
      if (mounted) setState(() => _rides = rides);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
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
                    Text('Trips',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 3),
                    const Text(
                      'Every accepted trip, including cancellations and live work.',
                      style: TextStyle(fontSize: 12.5, color: NeevColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading && _rides.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 70),
              child: LoadingState(label: 'Loading trips…'),
            )
          else if (_error != null)
            ErrorBanner(message: _error!, onRetry: _load)
          else if (_rides.isEmpty)
            const EmptyState(
              icon: Icons.route_outlined,
              title: 'No trips yet',
              message: 'Accepted rides appear here with their final state.',
            )
          else
            ..._rides.map(
              (ride) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NeevCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CaptainTripScreen(
                          state: widget.state,
                          initialRide: ride,
                        ),
                      ),
                    );
                    _load();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${humanize(ride.category)} · ${dateLabel(ride.createdAt)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            money(ride.trip?.finalFarePaise ??
                                ride.quotedFarePaise),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${ride.pickupAddress.split(',').first} → ${ride.dropAddress.split(',').first}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: NeevColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StatusPill(
                            status: ride.trip?.state ?? ride.status,
                          ),
                          const Spacer(),
                          Text(
                            '${distanceLabel(ride.distanceM)} · ${durationLabel(ride.durationS)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: NeevColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
