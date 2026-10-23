import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/passenger_state.dart';
import 'place_picker.dart';
import 'ride_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state, this.onSeeActivity});
  final PassengerState state;
  final VoidCallback? onSeeActivity;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _defaultPickup = Place(
    id: 'demo-indiranagar',
    name: 'Indiranagar 100ft Road',
    address: '100 Feet Road, Indiranagar, Bengaluru 560038',
    lat: 12.9719,
    lng: 77.6412,
    label: 'Demo location',
  );
  static const _defaultDrop = Place(
    id: 'demo-koramangala',
    name: 'Koramangala 5th Block',
    address: '5th Block, Koramangala, Bengaluru 560095',
    lat: 12.9352,
    lng: 77.6245,
    label: 'Demo location',
  );

  Place? _pickup = _defaultPickup;
  Place? _drop = _defaultDrop;
  final _coupon = TextEditingController();
  final Map<String, Quote> _quotes = {};
  String? _selectedCategory;
  String _paymentMethod = 'cash';
  bool _loadingQuotes = false;
  bool _booking = false;
  String? _quoteError;
  String? _bookError;
  List<Map<String, dynamic>> _saved = const [];
  bool _couponApplied = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuotes());
  }

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    try {
      final saved = await widget.state.api.savedAddresses();
      if (mounted) setState(() => _saved = saved);
    } catch (_) {}
  }

  Future<void> _loadQuotes() async {
    final pickup = _pickup;
    final drop = _drop;
    if (pickup == null || drop == null || widget.state.categories.isEmpty) {
      return;
    }
    setState(() {
      _loadingQuotes = true;
      _quoteError = null;
    });
    final results = <String, Quote>{};
    String? failure;
    await Future.wait(widget.state.categories.map((category) async {
      try {
        final quote = await widget.state.api.quote(
          category: category.code,
          pickup: pickup,
          drop: drop,
          couponCode: _couponApplied ? _coupon.text : null,
        );
        results[category.code] = quote;
      } on ApiException catch (error) {
        failure ??= error.message;
      }
    }));
    if (!mounted) return;
    setState(() {
      _quotes
        ..clear()
        ..addAll(results);
      _quoteError = results.isEmpty ? failure : null;
      _loadingQuotes = false;
      final codes = results.keys.toList();
      if (codes.isNotEmpty &&
          (_selectedCategory == null || !codes.contains(_selectedCategory))) {
        _selectedCategory = codes.contains('bike') ? 'bike' : codes.first;
      }
    });
  }

  Future<void> _choose(bool pickup) async {
    final place = await showPlacePicker(
      context,
      state: widget.state,
      title: pickup ? 'Pickup point' : 'Where to?',
      saved: _saved,
    );
    if (place == null) return;
    setState(() {
      if (pickup) {
        _pickup = place;
      } else {
        _drop = place;
      }
    });
    await _loadQuotes();
  }

  void _swap() {
    setState(() {
      final pickup = _pickup;
      _pickup = _drop;
      _drop = pickup;
    });
    _loadQuotes();
  }

  Future<void> _book() async {
    final pickup = _pickup;
    final drop = _drop;
    final category = _selectedCategory;
    if (pickup == null || drop == null || category == null) return;
    setState(() {
      _booking = true;
      _bookError = null;
    });
    try {
      final ride = await widget.state.book(
        category: category,
        pickup: pickup,
        drop: drop,
        paymentMethod: _paymentMethod,
        couponCode: _couponApplied ? _coupon.text : null,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RideScreen(state: widget.state, initialRide: ride),
        ),
      );
    } on ApiException catch (error) {
      setState(() => _bookError = error.message);
      if (error.code == 'active_ride' && error.details is Map) {
        final rideId = (error.details as Map)['ride_id']?.toString();
        if (rideId != null) {
          final latest = await widget.state.latestRide(rideId);
          if (latest != null) {
            widget.state.setActiveRide(latest);
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      RideScreen(state: widget.state, initialRide: latest),
                ),
              );
            }
          }
        }
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  Future<void> _openActiveRide() async {
    final ride = widget.state.activeRide;
    if (ride == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RideScreen(state: widget.state, initialRide: ride),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1020;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 460,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                      child: _buildBookingPanel(context),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 24, 28, 24),
                      child: _buildMapPanel(context),
                    ),
                  ),
                ],
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 240, child: _buildMapPanel(context)),
                  const SizedBox(height: 18),
                  _buildBookingPanel(context),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMapPanel(BuildContext context) {
    final selected = _selectedCategory == null
        ? null
        : _quotes[_selectedCategory];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: NeevMap(
            height: double.infinity,
            route: selected?.routePoints ?? const [],
            pickup: _pickup == null
                ? null
                : LatLng(_pickup!.lat, _pickup!.lng),
            drop: _drop == null ? null : LatLng(_drop!.lat, _drop!.lng),
            providerLabel: widget.state.isDemoMap
                ? 'Demo map · ${selected?.routeProvider ?? 'local fixture'}'
                : 'Development map',
          ),
        ),
        const SizedBox(height: 12),
        if (widget.state.activeRide != null)
          _ActiveRideBanner(
            ride: widget.state.activeRide!,
            onTap: _openActiveRide,
          ),
        if (widget.state.activeRide == null) ...[
          Row(
            children: [
              Expanded(
                child: _MiniFact(
                  icon: Icons.shield_outlined,
                  title: 'PIN-verified start',
                  body: 'The trip begins only when your captain enters your 4-digit PIN.',
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _MiniFact(
                  icon: Icons.ios_share,
                  title: 'Share live trip',
                  body: 'Send an expiring, read-only link to someone you trust.',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBookingPanel(BuildContext context) {
    final selected = _selectedCategory == null
        ? null
        : _quotes[_selectedCategory];
    final methods = widget.state.paymentMethods;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Where to, ${widget.state.firstName}?',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Fares are computed by the server from your route.',
                    style: TextStyle(fontSize: 12.5, color: NeevColors.muted),
                  ),
                ],
              ),
            ),
            if (widget.state.isDemoMap) const DemoBadge(),
          ],
        ),
        const SizedBox(height: 18),
        NeevCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: NeevColors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 52,
                    color: NeevColors.line,
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: NeevColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _PlaceRow(
                      label: 'PICKUP',
                      value: _pickup?.name ?? 'Choose pickup',
                      subtitle: _pickup?.address ?? '',
                      onTap: () => _choose(true),
                    ),
                    const Divider(height: 18),
                    _PlaceRow(
                      label: 'DROP',
                      value: _drop?.name ?? 'Choose destination',
                      subtitle: _drop?.address ?? '',
                      onTap: () => _choose(false),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Swap pickup and drop',
                onPressed: _swap,
                icon: const Icon(Icons.swap_vert, color: NeevColors.green),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _coupon,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Coupon code (try NEEV50)',
                  prefixIcon: const Icon(Icons.local_offer_outlined, size: 18),
                  suffixIcon: _couponApplied
                      ? IconButton(
                          tooltip: 'Remove coupon',
                          onPressed: () {
                            setState(() {
                              _couponApplied = false;
                              _coupon.clear();
                            });
                            _loadQuotes();
                          },
                          icon: const Icon(Icons.close, size: 18),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _loadingQuotes
                  ? null
                  : () {
                      setState(() => _couponApplied = true);
                      _loadQuotes();
                    },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(78, 48),
              ),
              child: Text(_couponApplied ? 'Applied' : 'Apply'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        SectionHeading(
          title: 'Choose your ride',
          subtitle: _loadingQuotes
              ? 'Pricing your route…'
              : 'Prices include the quoted fare for this route.',
          action: IconButton(
            tooltip: 'Refresh fares',
            onPressed: _loadingQuotes ? null : _loadQuotes,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ),
        const SizedBox(height: 10),
        if (_quoteError != null)
          ErrorBanner(message: _quoteError!, onRetry: _loadQuotes)
        else if (_loadingQuotes && _quotes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: LoadingState(label: 'Computing server-side fares…'),
          )
        else
          ...widget.state.categories.map((category) {
            final quote = _quotes[category.code];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CategoryCard(
                category: category,
                quote: quote,
                selected: category.code == _selectedCategory,
                onTap: quote == null
                    ? null
                    : () => setState(() => _selectedCategory = category.code),
              ),
            );
          }),
        const SizedBox(height: 14),
        Text('Payment', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: methods.map((method) {
            final enabled = method.enabled;
            final selected = _paymentMethod == method.code;
            return ChoiceChip(
              selected: selected,
              onSelected: enabled
                  ? (_) => setState(() => _paymentMethod = method.code)
                  : null,
              avatar: Icon(
                _paymentIcon(method.code),
                size: 16,
                color: selected ? NeevColors.greenDeep : NeevColors.muted,
              ),
              label: Text(
                enabled ? method.label : '${method.label} (not configured)',
              ),
            );
          }).toList(),
        ),
        if (_paymentMethod == 'mock_upi') ...[
          const SizedBox(height: 8),
          const Text(
            'Sandbox payment: no real money moves. You will explicitly confirm success or failure.',
            style: TextStyle(fontSize: 11.5, color: NeevColors.muted),
          ),
        ],
        if (_bookError != null) ...[
          const SizedBox(height: 12),
          ErrorBanner(message: _bookError!),
        ],
        const SizedBox(height: 18),
        NeevButton(
          label: selected == null
              ? 'Choose a ride'
              : 'Book ${humanize(selected.category)} · ${selected.totalDisplay}',
          icon: Icons.arrow_forward,
          loading: _booking,
          onPressed: selected == null || _booking ? null : _book,
        ),
        const SizedBox(height: 10),
        Text(
          widget.state.config?.paymentNote.isNotEmpty == true
              ? widget.state.config!.paymentNote
              : 'Pay by cash after the trip, or use the labelled sandbox adapter.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: NeevColors.muted),
        ),
      ],
    );
  }

  IconData _paymentIcon(String code) => switch (code) {
        'cash' => Icons.payments_outlined,
        'mock_upi' => Icons.science_outlined,
        'card' => Icons.credit_card,
        'upi' => Icons.qr_code_2,
        'wallet' => Icons.account_balance_wallet_outlined,
        _ => Icons.payments_outlined,
      };
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });
  final String label;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
                color: NeevColors.muted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: NeevColors.ink,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
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
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.quote,
    required this.selected,
    required this.onTap,
  });
  final CategoryOption category;
  final Quote? quote;
  final bool selected;
  final VoidCallback? onTap;

  IconData get _icon => switch (category.icon) {
        'bike' || 'two_wheeler' => Icons.two_wheeler,
        'auto' || 'rickshaw' => Icons.electric_rickshaw,
        'cab' || 'car' => Icons.local_taxi,
        'suv' => Icons.airport_shuttle,
        _ => Icons.directions_car,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? NeevColors.greenSoft : NeevColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? NeevColors.green : NeevColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : NeevColors.cream,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, size: 23, color: NeevColors.greenDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          category.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.people_alt_outlined,
                            size: 12, color: NeevColors.muted),
                        Text(
                          '${category.capacity}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: NeevColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quote == null
                          ? category.description
                          : '${quote!.durationLabel} · ${quote!.distanceLabel}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: NeevColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              quote == null
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          quote!.totalDisplay,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (quote!.discountPaise > 0)
                          Text(
                            'saved ${money(quote!.discountPaise)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: NeevColors.success,
                            ),
                          )
                        else if (quote!.surgeMultiplier > 1.01)
                          Text(
                            '${quote!.surgeMultiplier.toStringAsFixed(1)}× demand',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF7A5400),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner({required this.ride, required this.onTap});
  final Ride ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeevCard(
      color: NeevColors.greenDeep,
      borderColor: NeevColors.greenDeep,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.navigation_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOU HAVE A RIDE IN PROGRESS',
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${humanize(ride.category)} · ${ride.status == 'searching' ? 'Finding a captain' : ride.trip?.state == 'in_progress' ? 'On the way' : 'Captain assigned'}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  ride.dropAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Colors.white60),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
        ],
      ),
    );
  }
}

class _MiniFact extends StatelessWidget {
  const _MiniFact({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NeevColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NeevColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: NeevColors.green),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: const TextStyle(
              fontSize: 11,
              height: 1.35,
              color: NeevColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
