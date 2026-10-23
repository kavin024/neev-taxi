import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/captain_state.dart';

class CaptainTripScreen extends StatefulWidget {
  const CaptainTripScreen({
    super.key,
    required this.state,
    required this.initialRide,
  });
  final CaptainState state;
  final Ride initialRide;

  @override
  State<CaptainTripScreen> createState() => _CaptainTripScreenState();
}

class _CaptainTripScreenState extends State<CaptainTripScreen> {
  late Ride _ride = widget.initialRide;
  final _pin = TextEditingController();
  Timer? _refreshTimer;
  Timer? _simTimer;
  LatLng? _lastPoint;
  bool _busy = false;
  bool _simulating = false;
  double _progress = 0;
  String? _error;
  String? _info;

  String? get _tripId => _ride.trip?.id;
  String get _stage => _ride.trip?.state ?? _ride.status;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_ride.isLive) _refresh();
    });
    _refresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _simTimer?.cancel();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final latest = await widget.state.latest(_ride.id);
    if (latest == null || !mounted) return;
    setState(() => _ride = latest);
    if (!latest.isLive) {
      _stopSimulation(silent: true);
    }
  }

  Future<void> _arrive() async {
    final tripId = _tripId;
    if (tripId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ride = await widget.state.api.arrived(tripId);
      if (mounted) setState(() => _ride = ride);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    final tripId = _tripId;
    if (tripId == null) return;
    if (_pin.text.trim().length != 4) {
      setState(() => _error = 'Enter the 4-digit PIN shown on the passenger app.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ride = await widget.state.api.startTrip(tripId, _pin.text.trim());
      if (mounted) {
        setState(() {
          _ride = ride;
          _error = null;
          _info =
              'Trip started. The passenger can see your live location updates.';
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final tripId = _tripId;
    if (tripId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete this trip?'),
        content: Text(
          'Confirm that you have reached the drop-off. The passenger fare is ${money(_ride.trip?.finalFarePaise ?? _ride.quotedFarePaise)}.\n\n'
          'The server checks the completion point against the booked drop; a large mismatch is flagged for support review.',
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete trip'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _stopSimulation(silent: true);
    try {
      final ride = await widget.state.api.completeTrip(
        tripId,
        _ride.drop.lat,
        _ride.drop.lng,
      );
      if (!mounted) return;
      setState(() {
        _ride = ride;
        _info = 'Trip completed. Payout entries are recorded server-side.';
      });
      await widget.state.refreshDashboard();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<LatLng> get _path {
    if (_ride.routePoints.length > 1) return _ride.routePoints;
    return [_ride.pickup, _ride.drop];
  }

  LatLng _pointAt(double t) {
    final path = _path;
    if (path.length < 2) return path.first;
    final clamped = t.clamp(0.0, 1.0);
    final scaled = clamped * (path.length - 1);
    final index = scaled.floor().clamp(0, path.length - 2);
    final local = scaled - index;
    final a = path[index];
    final b = path[index + 1];
    return LatLng(
      a.lat + (b.lat - a.lat) * local,
      a.lng + (b.lng - a.lng) * local,
    );
  }

  Future<void> _sendPoint(LatLng point, {String source = 'simulated'}) async {
    final tripId = _tripId;
    if (tripId == null) return;
    try {
      await widget.state.api.postLocation(
        tripId: tripId,
        lat: point.lat,
        lng: point.lng,
        recordedAt: DateTime.now(),
        source: source,
      );
      if (mounted) setState(() => _lastPoint = point);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
        _stopSimulation(silent: true);
      }
    }
  }

  Future<void> _toggleSimulation() async {
    if (_simulating) {
      _stopSimulation();
      return;
    }
    if (!widget.state.gpsSimulation) {
      setState(() => _error =
          'GPS simulation is disabled by the server. Configure a device-location adapter for this build.');
      return;
    }
    setState(() {
      _simulating = true;
      _error = null;
      _info =
          'Simulating GPS along the route every 3 seconds. These updates are labelled "simulated" in the database.';
    });
    await _sendPoint(_pointAt(_progress));
    _simTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      _progress = (_progress + 0.07).clamp(0.0, 1.0);
      await _sendPoint(_pointAt(_progress));
      if (_progress >= 1.0) {
        _stopSimulation(silent: true);
        if (mounted) {
          setState(() {
            _info = 'Simulation reached the drop-off point.';
          });
        }
      }
    });
  }

  void _stopSimulation({bool silent = false}) {
    _simTimer?.cancel();
    _simTimer = null;
    if (_simulating && mounted) {
      setState(() {
        _simulating = false;
        if (!silent) _info = 'Location simulation stopped.';
      });
    } else {
      _simulating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trip · ${humanize(_ride.category)}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final map = NeevMap(
            height: double.infinity,
            route: _ride.routePoints,
            pickup: _ride.pickup,
            drop: _ride.drop,
            captain: _lastPoint,
            providerLabel: widget.state.config?.demoDataset == true
                ? 'Demo map · live coordinates'
                : 'Development map',
          );
          final panel = _panel(context);
          if (wide) {
            return Row(
              children: [
                SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 36),
                    child: panel,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 24, 24),
                    child: map,
                  ),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 230, child: map),
                const SizedBox(height: 16),
                panel,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _panel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageHeader(stage: _stage),
        const SizedBox(height: 14),
        if (_error != null) ...[
          ErrorBanner(message: _error!),
          const SizedBox(height: 12),
        ],
        if (_info != null) ...[
          NeevCard(
            color: NeevColors.greenSoft,
            child: Text(_info!, style: const TextStyle(fontSize: 12.5)),
          ),
          const SizedBox(height: 12),
        ],
        switch (_stage) {
          'captain_arriving' => _arrivingPanel(context),
          'arrived' => _arrivedPanel(context),
          'in_progress' => _progressPanel(context),
          'completed' => _completedPanel(context),
          _ => _closedPanel(context),
        },
        const SizedBox(height: 14),
        if (_stage == 'captain_arriving' || _stage == 'in_progress')
          _simulationCard(context),
        const SizedBox(height: 14),
        if (_stage != 'completed')
          NeevButton(
            label: 'Contact support',
            tone: NeevButtonTone.outline,
            icon: Icons.support_agent_outlined,
            onPressed: () => _showSupport(context),
          ),
      ],
    );
  }

  Widget _arrivingPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeevCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Head to the pickup',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                _ride.pickupAddress,
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Passenger',
                      value: _ride.captain == null
                          ? 'Neev rider'
                          : 'Neev rider',
                      icon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      label: 'Fare',
                      value: _ride.quotedFareDisplay,
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              NeevButton(
                label: 'I have arrived',
                icon: Icons.location_on_outlined,
                loading: _busy,
                onPressed: _arrive,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tapping "arrived" notifies the passenger to share their 4-digit start PIN.',
                style: TextStyle(fontSize: 11, color: NeevColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _arrivedPanel(BuildContext context) {
    return NeevCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Waiting for the passenger',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Ask the passenger for the 4-digit start PIN. The server verifies it; never start without it.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: NeevColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 28,
              letterSpacing: 12,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: '••••',
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          NeevButton(
            label: 'Verify PIN and start trip',
            loading: _busy,
            onPressed: _start,
            icon: Icons.play_arrow_rounded,
          ),
          const SizedBox(height: 8),
          const Text(
            'Repeated wrong PINs lock the trip temporarily. Contact support if the passenger cannot provide the PIN.',
            style: TextStyle(fontSize: 11, color: NeevColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _progressPanel(BuildContext context) {
    final trip = _ride.trip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeevCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Trip in progress',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  const StatusPill(status: 'in_progress'),
                ],
              ),
              const SizedBox(height: 10),
              _AddressLine(
                icon: Icons.trip_origin,
                color: NeevColors.amber,
                text: _ride.pickupAddress,
              ),
              const SizedBox(height: 6),
              _AddressLine(
                icon: Icons.place,
                color: NeevColors.green,
                text: _ride.dropAddress,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Distance',
                      value: distanceLabel(_ride.distanceM),
                      icon: Icons.route_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      label: 'Fare',
                      value: money(trip?.finalFarePaise ?? _ride.quotedFarePaise),
                      icon: Icons.currency_rupee,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      label: 'Started',
                      value: timeLabel(trip?.startedAt),
                      icon: Icons.schedule,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              NeevButton(
                label: 'Complete trip at drop-off',
                loading: _busy,
                onPressed: _complete,
                icon: Icons.flag_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _completedPanel(BuildContext context) {
    final trip = _ride.trip;
    return NeevCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: NeevColors.greenSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: NeevColors.green, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trip completed',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      '${dateTimeLabel(trip?.completedAt)} · ${durationLabel(trip?.durationS ?? _ride.durationS)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: NeevColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                money(trip?.finalFarePaise ?? _ride.quotedFarePaise),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Payment',
                  value: humanize(trip?.paymentStatus),
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Drop check',
                  value: trip?.dropVerified == null
                      ? 'Not checked'
                      : trip!.dropVerified!
                          ? 'Within 200 m'
                          : 'Flagged',
                  icon: Icons.my_location,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            trip?.paymentStatus == 'captured'
                ? 'Payment is captured. Your earnings ledger is updated net of commission.'
                : 'If this was a cash trip, the passenger confirms handover in their app. Payout availability follows the ledger entry.',
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: NeevColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          NeevButton(
            label: 'Back to offers',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _closedPanel(BuildContext context) {
    return NeevCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trip closed', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Current state: ${humanize(_stage)}. If you believe this is wrong, open a support ticket so an admin can review the ride record.',
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 12),
          NeevButton(
            label: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _simulationCard(BuildContext context) {
    return NeevCard(
      color: NeevColors.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined,
                  size: 17, color: NeevColors.muted),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'DEVELOPMENT GPS SIMULATION',
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: NeevColors.muted,
                  ),
                ),
              ),
              if (_simulating)
                const Text(
                  'RUNNING',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: NeevColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.state.gpsSimulation
                ? 'Walk a marker along the booked route and post real location rows with source "simulated". The passenger sees these updates on their map.'
                : 'GPS simulation is disabled by the server, and no device GPS adapter is configured in this build.',
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: NeevColors.inkSoft,
            ),
          ),
          const SizedBox(height: 10),
          NeevButton(
            label: _simulating ? 'Stop simulation' : 'Start route simulation',
            tone: _simulating
                ? NeevButtonTone.outline
                : NeevButtonTone.primary,
            onPressed: widget.state.gpsSimulation ? _toggleSimulation : null,
            icon: _simulating ? Icons.stop : Icons.play_arrow,
          ),
        ],
      ),
    );
  }

  void _showSupport(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trip support',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Ticket-based support is available from the Profile tab. For an emergency, call 112. This build does not include a live captain safety desk.',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 14),
              NeevButton(
                label: 'Close',
                tone: NeevButtonTone.outline,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.stage});
  final String stage;

  @override
  Widget build(BuildContext context) {
    final steps = ['captain_arriving', 'arrived', 'in_progress', 'completed'];
    final index = steps.indexOf(stage).clamp(0, 3);
    return Row(
      children: List.generate(steps.length, (i) {
        final active = i <= index;
        return Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 4,
                margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                decoration: BoxDecoration(
                  color: active ? NeevColors.green : NeevColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                humanize(steps[i]).replaceAll('Captain ', ''),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: active ? NeevColors.greenDeep : NeevColors.muted,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4)),
        ),
      ],
    );
  }
}
