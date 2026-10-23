import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:neev_shared/neev_shared.dart';

/// Owns the signed-in passenger session, catalog cache, active ride and the
/// realtime connection. Screens listen to this single source of truth.
class PassengerState extends ChangeNotifier {
  PassengerState();

  final SessionStore session = SessionStore();
  late final ApiClient api = ApiClient(session: session);

  AppConfig? config;
  List<CategoryOption> categories = const [];
  List<PaymentMethod> paymentMethods = const [];
  UserSession? user;
  Ride? activeRide;

  bool ready = false;
  bool refreshingRide = false;
  String? bootError;

  NeevRealtime? _realtime;
  Timer? _pollTimer;
  bool _disposed = false;

  bool get signedIn => user != null && session.isSignedIn;
  bool get isDemoMap => config?.demoDataset ?? true;
  String get firstName =>
      (user?.name ?? 'Rider').trim().split(RegExp(r'\s+')).first;

  Future<void> bootstrap() async {
    await session.load();
    try {
      config = await api.config();
      categories = await api.categories();
      if (session.isSignedIn) {
        user = await api.me();
        try {
          paymentMethods = await api.paymentMethods();
        } catch (_) {
          paymentMethods = const [];
        }
        await _loadActiveRide();
        _connectRealtime();
        _startPolling();
      } else {
        // Catalog endpoints are public; payment methods need auth.
        paymentMethods = const [
          PaymentMethod(
            code: 'cash',
            label: 'Cash',
            enabled: true,
            provider: 'cash',
          ),
        ];
      }
    } on ApiException catch (error) {
      bootError = error.message;
    } catch (error) {
      bootError = 'Could not start Neev: $error';
    } finally {
      ready = true;
      _notify();
    }
  }

  Future<void> adoptSignIn(AuthResult result) async {
    user = result.user;
    try {
      config ??= await api.config();
      categories = await api.categories();
      paymentMethods = await api.paymentMethods();
    } catch (_) {
      // The login itself succeeded; catalog can retry on the next screen.
    }
    await _loadActiveRide();
    _connectRealtime();
    _startPolling();
    _notify();
  }

  Future<void> signOut() async {
    try {
      await api.logoutAll();
    } catch (_) {
      await session.clear();
    }
    _realtime?.dispose();
    _realtime = null;
    _pollTimer?.cancel();
    activeRide = null;
    user = null;
    _notify();
  }

  Future<void> reloadCatalog() async {
    try {
      config = await api.config();
      categories = await api.categories();
      paymentMethods = await api.paymentMethods();
      bootError = null;
    } on ApiException catch (error) {
      bootError = error.message;
    }
    _notify();
  }

  Future<void> _loadActiveRide() async {
    try {
      final rides = await api.rides(limit: 8);
      activeRide = null;
      for (final ride in rides) {
        if (ride.isLive) {
          activeRide = ride;
          break;
        }
      }
    } catch (_) {
      activeRide = null;
    }
  }

  Future<Ride?> refreshActiveRide({bool quiet = true}) async {
    final current = activeRide;
    if (current == null) return null;
    if (!quiet) {
      refreshingRide = true;
      _notify();
    }
    try {
      final latest = await api.ride(current.id);
      activeRide = latest;
      if (!latest.isLive) {
        _stopPolling();
      }
      _notify();
      return latest;
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        activeRide = null;
        _stopPolling();
        _notify();
      }
      return null;
    } finally {
      if (!quiet) {
        refreshingRide = false;
        _notify();
      }
    }
  }

  Future<Ride> book({
    required String category,
    required Place pickup,
    required Place drop,
    required String paymentMethod,
    String? couponCode,
  }) async {
    final ride = await api.requestRide(
      category: category,
      pickup: pickup,
      drop: drop,
      idempotencyKey: newRequestKey('ride'),
      paymentMethod: paymentMethod,
      couponCode: couponCode,
    );
    activeRide = ride;
    _connectRealtime();
    _realtime?.subscribe(ride.id);
    _startPolling();
    _notify();
    return ride;
  }

  void setActiveRide(Ride? ride) {
    activeRide = ride;
    if (ride == null || !ride.isLive) {
      _stopPolling();
    } else {
      _realtime?.subscribe(ride.id);
      _startPolling();
    }
    _notify();
  }

  Future<Ride?> latestRide(String rideId) async {
    try {
      return await api.ride(rideId);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> captainTrack(String rideId) async {
    try {
      return await api.rideLocations(rideId);
    } catch (_) {
      return const [];
    }
  }

  void _connectRealtime() {
    if (session.accessToken == null) return;
    final existing = _realtime;
    if (existing != null) {
      existing.subscribe(activeRide?.id ?? '');
      return;
    }
    _realtime = NeevRealtime(
      baseUrl: api.baseUrl,
      accessToken: session.accessToken!,
      onEvent: (event) {
        if (event.type == 'connection.ready') return;
        if (activeRide != null &&
            (event.entityId == activeRide!.id ||
                event.type.startsWith('ride.') ||
                event.type.startsWith('trip.') ||
                event.type.startsWith('payment.'))) {
          refreshActiveRide();
        }
        _notify();
      },
    )..connect();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (activeRide?.isLive == true) refreshActiveRide();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _realtime?.dispose();
    api.dispose();
    super.dispose();
  }
}
