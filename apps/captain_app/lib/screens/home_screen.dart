import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/captain_state.dart';
import 'trip_screen.dart';

class CaptainHomeScreen extends StatelessWidget {
  const CaptainHomeScreen({super.key, required this.state});
  final CaptainState state;

  Future<void> _toggleOnline(BuildContext context, bool online) async {
    if (!state.gpsSimulation) {
      // No device-location plugin is configured in this build. Rather than
      // claiming a GPS fix we refuse to go online.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location is unavailable in this build. A production map/GPS adapter must be configured before a captain can go online.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(online ? 'Go online?' : 'Go offline?'),
        content: Text(
          online
              ? 'This development build has no device GPS adapter. Neev will use the labelled demo location 12.9719, 77.6412 (Indiranagar) so dispatch can be tested. Real deployment requires a GPS provider.'
              : 'You will stop receiving new ride offers. Any active trip must be completed first.',
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(online ? 'Go online' : 'Go offline'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.setOnline(online);
    }
  }

  Future<void> _accept(BuildContext context, Offer offer) async {
    final ride = await state.accept(offer);
    if (ride != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CaptainTripScreen(state: state, initialRide: ride),
        ),
      );
      await state.refreshDashboard();
      await state.refreshOffers();
    } else if (context.mounted && state.actionError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.actionError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final dashboard = state.dashboard;
        final active = state.activeRide ?? dashboard?.activeRide;
        return RefreshIndicator(
          onRefresh: () async {
            await state.refreshDashboard();
            await state.refreshOffers();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${state.name.split(' ').first}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          state.isOnline
                              ? 'You are online and receiving offers.'
                              : 'You are offline. Go online to receive rides.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: NeevColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  NeevAvatar(name: state.name, size: 44),
                ],
              ),
              const SizedBox(height: 16),
              _OnlineCard(
                online: state.isOnline,
                busy: state.busy,
                onChanged: (value) => _toggleOnline(context, value),
                gpsSimulation: state.gpsSimulation,
                onlineSince: dashboard?.isOnline == true
                    ? DateTime.now()
                    : null,
              ),
              if (state.actionError != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(
                  message: state.actionError!,
                  onRetry: () async {
                    await state.refreshDashboard();
                    await state.refreshOffers();
                  },
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Available balance',
                      value: dashboard?.earningsDisplay ?? money(0),
                      icon: Icons.account_balance_wallet_outlined,
                      tone: NeevColors.surface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      label: 'Total trips',
                      value: '${dashboard?.totalTrips ?? 0}',
                      icon: Icons.route_outlined,
                      tone: NeevColors.surface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      label: 'Rating',
                      value: dashboard?.rating?.toStringAsFixed(1) ?? '—',
                      icon: Icons.star_rounded,
                      tone: NeevColors.surface,
                    ),
                  ),
                ],
              ),
              if (active != null) ...[
                const SizedBox(height: 18),
                _ActiveTripCard(
                  ride: active,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CaptainTripScreen(
                          state: state,
                          initialRide: active,
                        ),
                      ),
                    );
                    await state.refreshDashboard();
                  },
                ),
              ],
              const SizedBox(height: 24),
              SectionHeading(
                title: 'Ride offers',
                subtitle: state.isOnline
                    ? 'Offers are reserved for you until they expire. Accept exactly once.'
                    : 'Go online to start receiving offers.',
                action: IconButton(
                  tooltip: 'Refresh offers',
                  onPressed: state.refreshOffers,
                  icon: const Icon(Icons.refresh, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              if (!state.isOnline)
                const EmptyState(
                  icon: Icons.power_settings_new,
                  title: 'You are offline',
                  message:
                      'Offers only arrive while you are online with an approved vehicle.',
                )
              else if (state.offers.isEmpty)
                const EmptyState(
                  icon: Icons.radar,
                  title: 'Waiting for a ride',
                  message:
                      'The dispatch engine will offer nearby requests. Keep this screen open while testing.',
                )
              else
                ...state.offers.map(
                  (offer) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OfferCard(
                      offer: offer,
                      busy: state.busy,
                      onAccept: () => _accept(context, offer),
                      onReject: () => state.reject(offer),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'Dispatch sends offers to eligible online captains. Acceptance is a single atomic update: if another captain wins, this offer fails safely.',
                style: TextStyle(fontSize: 10.5, color: NeevColors.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OnlineCard extends StatelessWidget {
  const _OnlineCard({
    required this.online,
    required this.busy,
    required this.onChanged,
    required this.gpsSimulation,
    required this.onlineSince,
  });
  final bool online;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final bool gpsSimulation;
  final DateTime? onlineSince;

  @override
  Widget build(BuildContext context) {
    return NeevCard(
      color: online ? NeevColors.greenDeep : NeevColors.surface,
      borderColor: online ? NeevColors.greenDeep : NeevColors.line,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: online
                  ? Colors.white.withValues(alpha: 0.12)
                  : NeevColors.cream,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.power_settings_new,
              color: online ? NeevColors.amber : NeevColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w900,
                    color: online ? Colors.white70 : NeevColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  online ? 'Ready for offers' : 'Not receiving offers',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: online ? Colors.white : NeevColors.ink,
                  ),
                ),
                Text(
                  gpsSimulation
                      ? 'Simulated GPS · demo location'
                      : 'GPS provider unavailable',
                  style: TextStyle(
                    fontSize: 10.5,
                    color:
                        online ? Colors.white54 : NeevColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: online,
              onChanged: onChanged,
              activeThumbColor: NeevColors.amber,
            ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });
  final Offer offer;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final expiresIn = offer.expiresAt?.difference(DateTime.now()).inSeconds;
    return NeevCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: NeevColors.amberSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.notifications_active_outlined,
                    size: 21, color: Color(0xFF7A5400)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${humanize(offer.category)} ride · ${offer.passengerName.split(' ').first}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${distanceLabel(offer.distanceM)} · ${durationLabel(offer.durationS)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: NeevColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                offer.fareDisplay,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.trip_origin,
                  size: 12, color: NeevColors.amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  offer.pickupAddress,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place, size: 13, color: NeevColors.green),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  offer.dropAddress,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.near_me_outlined,
                  size: 13, color: NeevColors.muted),
              const SizedBox(width: 4),
              Text(
                '${distanceLabel(offer.distanceToPickupM)} to pickup',
                style: const TextStyle(
                  fontSize: 11,
                  color: NeevColors.muted,
                ),
              ),
              const Spacer(),
              if (expiresIn != null)
                Text(
                  expiresIn <= 0
                      ? 'Expired'
                      : 'Expires in ${expiresIn}s',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: expiresIn <= 15
                        ? NeevColors.danger
                        : NeevColors.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NeevButton(
                  label: 'Decline',
                  tone: NeevButtonTone.outline,
                  onPressed: busy ? null : onReject,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: NeevButton(
                  label: 'Accept ride',
                  loading: busy,
                  onPressed: onAccept,
                  icon: Icons.arrow_forward,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard({required this.ride, required this.onTap});
  final Ride ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = ride.trip?.state ?? ride.status;
    return NeevCard(
      color: NeevColors.amberSoft,
      borderColor: NeevColors.amber,
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.navigation_outlined, color: Color(0xFF7A5400)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACTIVE TRIP',
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7A5400),
                  ),
                ),
                Text(
                  '${humanize(state)} · ${ride.dropAddress}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 19),
        ],
      ),
    );
  }
}
