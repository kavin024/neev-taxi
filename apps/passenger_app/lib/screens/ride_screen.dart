import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/passenger_state.dart';

class RideScreen extends StatefulWidget {
  const RideScreen({
    super.key,
    required this.state,
    required this.initialRide,
  });

  final PassengerState state;
  final Ride initialRide;

  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  late Ride _ride = widget.initialRide;
  Timer? _timer;
  LatLng? _captainAt;
  bool _busy = false;
  bool _rated = false;
  String? _actionError;
  String _payMethod = 'cash';
  int _stars = 0;
  final _ratingComment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _payMethod = _ride.paymentMethod;
    widget.state.addListener(_syncFromState);
    _refresh(quiet: true);
    _loadTrack();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_ride.isLive) {
        _refresh(quiet: true);
        _loadTrack();
      }
    });
  }

  @override
  void dispose() {
    widget.state.removeListener(_syncFromState);
    _timer?.cancel();
    _ratingComment.dispose();
    super.dispose();
  }

  void _syncFromState() {
    final active = widget.state.activeRide;
    if (active != null && active.id == _ride.id && mounted) {
      setState(() => _ride = active);
    }
  }

  Future<void> _refresh({bool quiet = true}) async {
    final latest = await widget.state.latestRide(_ride.id);
    if (latest == null || !mounted) return;
    setState(() => _ride = latest);
    if (widget.state.activeRide?.id == latest.id) {
      widget.state.activeRide = latest;
    }
  }

  Future<void> _loadTrack() async {
    if (_ride.status != 'assigned' && _ride.status != 'in_progress') return;
    final rows = await widget.state.captainTrack(_ride.id);
    if (!mounted || rows.isEmpty) return;
    final last = rows.last;
    setState(() {
      _captainAt = LatLng(
        (last['lat'] as num).toDouble(),
        (last['lng'] as num).toDouble(),
      );
    });
  }

  String get _stage {
    if (_ride.status == 'searching') return 'searching';
    if (_ride.status == 'cancelled' || _ride.status == 'expired') return 'cancelled';
    if (_ride.status == 'completed') return 'completed';
    final tripState = _ride.trip?.state;
    if (tripState == 'in_progress') return 'in_progress';
    if (tripState == 'arrived') return 'arrived';
    return 'arriving';
  }

  bool get _paymentSettled {
    final status = _ride.payment?.status;
    return status == 'captured' || status == 'paid' || status == 'refunded';
  }

  Future<void> _cancel() async {
    final reasons = <String>[
      'Plans changed',
      'Captain is taking too long',
      'Booked by mistake',
      'Wrong pickup or drop',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cancel this ride?',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              const Text(
                'A cancellation fee may apply once a captain has accepted. The server calculates the final amount.',
                style: TextStyle(fontSize: 12.5, color: NeevColors.muted),
              ),
              const SizedBox(height: 12),
              ...reasons.map(
                (reason) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(reason),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => Navigator.pop(context, reason),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (reason == null) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final ride = await widget.state.api.cancelRide(_ride.id, reason);
      widget.state.setActiveRide(null);
      if (!mounted) return;
      setState(() => _ride = ride);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareTrip() async {
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final data = await widget.state.api.shareRide(_ride.id);
      if (!mounted) return;
      final url = (data['url'] ?? '').toString();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Live trip link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Anyone with this unlisted link can see limited live trip details until it expires. It never includes your phone number.',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NeevColors.greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  url,
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Expires ${dateTimeLabel(DateTime.tryParse((data['expires_at'] ?? '').toString()))}',
                style: const TextStyle(fontSize: 11, color: NeevColors.muted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard.')),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 17),
              label: const Text('Copy link'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sos() async {
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final incident = await widget.state.api.triggerSos(
        rideId: _ride.id,
        lat: _ride.pickup.lat,
        lng: _ride.pickup.lng,
        note: 'Triggered from the active Neev trip screen.',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('SOS recorded'),
          content: Text(
            'A safety incident was recorded at ${dateTimeLabel(DateTime.tryParse((incident['created_at'] ?? '').toString()))}. '
            'SMS notifications were queued to your trusted contacts through the configured adapter.\n\n'
            'This build does not contact police, ambulances, or a staffed safety desk. If you are in danger, call 112 directly.',
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.call, size: 17),
              label: const Text('Emergency 112'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      if (_payMethod == 'cash') {
        await widget.state.api.confirmCash(_ride.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash payment confirmed.')),
        );
        await _refresh();
        return;
      }

      final created = await widget.state.api.createRidePayment(
        _ride.id,
        _payMethod,
        newRequestKey('pay'),
      );
      final paymentId = (created['id'] ?? '').toString();
      if ((created['status'] ?? '') == 'captured') {
        await _refresh();
        return;
      }
      if (created['sandbox'] != true &&
          created['provider'] != 'sandbox' &&
          _payMethod != 'mock_upi') {
        throw ApiException(
          503,
          'provider_unconfigured',
          'That payment provider is not configured in this build. Pay by cash or use the labelled sandbox method.',
        );
      }
      if (!mounted) return;
      final outcome = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sandbox checkout'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This is a sandbox payment. No real money will move and no card details are collected. Choose the outcome to send to the payment provider adapter.',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: NeevColors.amberSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Payment ${paymentId.substring(0, paymentId.length.clamp(0, 8))}… · ${money(_ride.trip?.finalFarePaise ?? _ride.quotedFarePaise)}',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'failed'),
              child: const Text('Simulate failure'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'succeeded'),
              child: const Text('Simulate success'),
            ),
          ],
        ),
      );
      if (outcome == null) return;
      final result = await widget.state.api.confirmSandbox(
        paymentId,
        outcome,
        newRequestKey('confirm'),
      );
      if (!mounted) return;
      if ((result['status'] ?? '') != 'captured') {
        setState(() => _actionError =
            'Sandbox payment ended in status ${result['status']}.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sandbox payment captured.')),
        );
      }
      await _refresh();
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitRating() async {
    if (_stars == 0) return;
    setState(() => _busy = true);
    try {
      await widget.state.api.rateRide(
        _ride.id,
        _stars,
        comment: _ratingComment.text.trim().isEmpty
            ? null
            : _ratingComment.text.trim(),
        tags: const [],
      );
      if (!mounted) return;
      setState(() => _rated = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for rating your captain.')),
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _actionError = error.message;
          if (error.code == 'already_rated') _rated = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const NeevLogo(size: 30, showWordmark: false),
                const SizedBox(width: 10),
                Text('Ride · ${humanize(_ride.category)}'),
              ],
            ),
            actions: [
              if (_ride.isLive)
                IconButton(
                  tooltip: 'Refresh ride',
                  onPressed: (_busy || _ride.id.isEmpty) ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              const SizedBox(width: 6),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final map = _buildMap();
              final panel = _buildPanel(context);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 440,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
                        child: panel,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 24, 24),
                        child: map,
                      ),
                    ),
                  ],
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
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
      },
    );
  }

  Widget _buildMap() {
    final showCaptain = _captainAt != null && _ride.isLive;
    return NeevMap(
      height: double.infinity,
      route: _ride.routePoints,
      pickup: _ride.pickup,
      drop: _ride.drop,
      captain: showCaptain ? _captainAt : null,
      providerLabel: widget.state.isDemoMap
          ? 'Demo map · live coordinates'
          : 'Development map',
    );
  }

  Widget _buildPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TripProgress(stage: _stage),
        const SizedBox(height: 16),
        ...switch (_stage) {
          'searching' => [_searchingCard(context)],
          'cancelled' => [_cancelledCard(context)],
          'completed' => [_completedCard(context)],
          _ => [_captainCard(context), const SizedBox(height: 12), _tripCard(context)],
        },
        if (_actionError != null) ...[
          const SizedBox(height: 12),
          ErrorBanner(message: _actionError!),
        ],
        const SizedBox(height: 16),
        if (_ride.isLive) _safetyActions(context),
        if (_ride.isLive) ...[
          const SizedBox(height: 14),
          NeevButton(
            label: _stage == 'searching'
                ? 'Cancel request'
                : 'Cancel ride',
            tone: NeevButtonTone.outline,
            loading: _busy,
            onPressed: _cancel,
          ),
        ],
      ],
    );
  }

  Widget _searchingCard(BuildContext context) {
    return NeevCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Radar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Finding your captain',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    const Text(
                      'Matching your request with approved captains nearby. Offers are sent automatically.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: NeevColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Offers sent',
                  value: '${_ride.offersSent}',
                  icon: Icons.outbox_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Captains nearby',
                  value: '${_ride.captainsAvailable}',
                  icon: Icons.radar,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Request expires ${timeLabel(_ride.createdAt?.add(const Duration(minutes: 3)))}. Cancelling now is free.',
            style: const TextStyle(fontSize: 11, color: NeevColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _captainCard(BuildContext context) {
    final captain = _ride.captain;
    final vehicle = _ride.vehicle;
    final pin = _ride.trip?.startPin;
    final arriving = _stage == 'arriving';
    return NeevCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arriving ? 'Captain is on the way' : 'Captain has arrived',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      arriving
                          ? 'Share your PIN only when you are ready to start.'
                          : 'Confirm the PIN before the trip starts.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: NeevColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(status: _stage == 'arriving' ? 'arriving' : 'arrived'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              NeevAvatar(name: captain?.name ?? 'Neev captain', size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      captain?.name ?? 'Captain assigned',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: NeevColors.amber),
                        const SizedBox(width: 2),
                        Text(
                          captain?.rating?.toStringAsFixed(1) ?? '—',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          ' · ${captain?.totalTrips ?? 0} trips',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: NeevColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (vehicle != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      vehicle.regNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      '${vehicle.makeModel}${vehicle.color == null ? '' : ' · ${vehicle.color}'}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: NeevColors.muted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (pin != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: NeevColors.amberSoft,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: NeevColors.amber.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRIP START PIN',
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7A5400),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Give this to your captain in person.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF7A5400),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    pin,
                    style: const TextStyle(
                      fontSize: 30,
                      letterSpacing: 6,
                      fontWeight: FontWeight.w900,
                      color: NeevColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tripCard(BuildContext context) {
    final inProgress = _stage == 'in_progress';
    return NeevCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  inProgress ? 'You are on your way' : 'Trip details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatusPill(
                status: inProgress ? 'in_progress' : _ride.status,
                label: inProgress ? 'In trip' : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RouteLine(
            pickup: _ride.pickupAddress,
            drop: _ride.dropAddress,
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
                  label: 'Typical time',
                  value: durationLabel(_ride.durationS),
                  icon: Icons.schedule,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Quoted fare',
                  value: _ride.quotedFareDisplay,
                  icon: Icons.receipt_long_outlined,
                ),
              ),
            ],
          ),
          if (_captainAt == null && inProgress) ...[
            const SizedBox(height: 12),
            const Text(
              'Waiting for the next captain location update. Tracking is server-authorised and limited to this trip.',
              style: TextStyle(fontSize: 11, color: NeevColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _completedCard(BuildContext context) {
    final trip = _ride.trip;
    final fare = trip?.finalFarePaise ?? _ride.quotedFarePaise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeevCard(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(fare),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      StatusPill(
                        status: _paymentSettled ? 'paid' : 'pending',
                        label: _paymentSettled ? 'Paid' : 'Payment due',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _RouteLine(
                pickup: _ride.pickupAddress,
                drop: _ride.dropAddress,
              ),
              if (trip?.dropVerified == false) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: NeevColors.amberSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'The captain completed this trip away from the booked drop. A support ticket was opened automatically for review.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF7A5400)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!_paymentSettled) _paymentCard(context) else _ratedCard(context),
      ],
    );
  }

  Widget _paymentCard(BuildContext context) {
    final methods = widget.state.paymentMethods.isEmpty
        ? const [
            PaymentMethod(
              code: 'cash',
              label: 'Cash',
              enabled: true,
              provider: 'cash',
            ),
          ]
        : widget.state.paymentMethods;
    final current = methods.where((m) => m.enabled).toList();
    if (!current.any((m) => m.code == _payMethod)) {
      _payMethod = current.isEmpty ? 'cash' : current.first.code;
    }
    return NeevCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pay for this trip',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Cash is confirmed by you after handing it to the captain. Sandbox payments are explicitly labelled and move no real money.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: NeevColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: current.map((method) {
              return ChoiceChip(
                selected: _payMethod == method.code,
                onSelected: (_) => setState(() => _payMethod = method.code),
                label: Text(method.label),
                avatar: Icon(
                  method.methodIcon,
                  size: 15,
                  color: _payMethod == method.code
                      ? NeevColors.greenDeep
                      : NeevColors.muted,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          NeevButton(
            label: _payMethod == 'cash'
                ? 'Confirm cash paid · ${money(_ride.trip?.finalFarePaise ?? _ride.quotedFarePaise)}'
                : 'Open ${_payMethod == 'mock_upi' ? 'sandbox' : ''} payment',
            loading: _busy,
            onPressed: _pay,
            icon: _payMethod == 'cash'
                ? Icons.payments_outlined
                : Icons.lock_outline,
          ),
          if (_payMethod == 'mock_upi') ...[
            const SizedBox(height: 8),
            const Text(
              'Sandbox adapter: no funds move. You choose success or failure at checkout.',
              style: TextStyle(fontSize: 11, color: NeevColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ratedCard(BuildContext context) {
    if (_rated) {
      return NeevCard(
        child: Row(
          children: [
            const Icon(Icons.favorite_rounded, color: NeevColors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Payment settled. Thanks for riding with Neev.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      );
    }
    return NeevCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate your captain',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            _ride.captain?.name ?? 'Your captain',
            style: const TextStyle(fontSize: 12.5, color: NeevColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () => setState(() => _stars = index + 1),
                icon: Icon(
                  index < _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: NeevColors.amber,
                  size: 32,
                ),
              );
            }),
          ),
          TextField(
            controller: _ratingComment,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Optional comment about the trip',
            ),
          ),
          const SizedBox(height: 12),
          NeevButton(
            label: 'Submit rating',
            loading: _busy,
            onPressed: _stars == 0 ? null : _submitRating,
          ),
        ],
      ),
    );
  }

  Widget _cancelledCard(BuildContext context) {
    final cancelled = _ride.status == 'expired'
        ? 'This request expired before a captain accepted.'
        : 'This ride was cancelled.';
    return NeevCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ride closed', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(cancelled, style: const TextStyle(fontSize: 13)),
          if (_ride.cancellationReason != null) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: ${_ride.cancellationReason}',
              style: const TextStyle(fontSize: 12.5, color: NeevColors.muted),
            ),
          ],
          const SizedBox(height: 14),
          NeevButton(
            label: 'Book another ride',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _safetyActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: NeevButton(
                label: 'Share live trip',
                tone: NeevButtonTone.outline,
                icon: Icons.ios_share,
                loading: _busy,
                onPressed: _shareTrip,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        HoldToActivate(
          label: 'Hold 3s for SOS',
          onActivated: _sos,
        ),
        const SizedBox(height: 8),
        const Text(
          'SOS records an incident and queues SMS to trusted contacts. This build does not contact emergency services. Call 112 if you are in danger.',
          style: TextStyle(
            fontSize: 10.5,
            height: 1.4,
            color: NeevColors.muted,
          ),
        ),
      ],
    );
  }
}

extension on PaymentMethod {
  IconData get methodIcon => switch (code) {
        'cash' => Icons.payments_outlined,
        'mock_upi' => Icons.science_outlined,
        'card' => Icons.credit_card,
        'upi' => Icons.qr_code_2,
        'wallet' => Icons.account_balance_wallet_outlined,
        _ => Icons.payments_outlined,
      };
}

class _TripProgress extends StatelessWidget {
  const _TripProgress({required this.stage});
  final String stage;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('searching', 'Finding'),
      ('assigned', 'Assigned'),
      ('arrived', 'Arrived'),
      ('in_progress', 'In trip'),
      ('completed', 'Done'),
    ];
    final normalized = switch (stage) {
      'searching' => 0,
      'arriving' => 1,
      'arrived' => 2,
      'in_progress' => 3,
      'completed' => 4,
      _ => 0,
    };
    return Row(
      children: List.generate(steps.length, (index) {
        final done = index <= normalized;
        final active = index == normalized;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: done ? NeevColors.green : NeevColors.line,
                  shape: BoxShape.circle,
                  border: active
                      ? Border.all(color: NeevColors.greenDeep, width: 3)
                      : null,
                ),
                child: done
                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                    : null,
              ),
              if (index < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: index < normalized
                        ? NeevColors.green
                        : NeevColors.line,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.pickup, required this.drop});
  final String pickup;
  final String drop;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Icon(Icons.trip_origin, size: 13, color: NeevColors.amber),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pickup,
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(left: 5),
          child: SizedBox(
            height: 14,
            child: VerticalDivider(width: 3, thickness: 1),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.place, size: 14, color: NeevColors.green),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                drop,
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Radar extends StatefulWidget {
  const _Radar();

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 62,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 18 + (44 * ((_controller.value + i / 3) % 1)),
                  height: 18 + (44 * ((_controller.value + i / 3) % 1)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: NeevColors.green.withValues(
                        alpha: 0.30 * (1 - ((_controller.value + i / 3) % 1)),
                      ),
                    ),
                  ),
                ),
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: NeevColors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.two_wheeler,
                    size: 13, color: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }
}
