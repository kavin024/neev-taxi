import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:neev_shared/neev_shared.dart';

/// Session, onboarding state, live offers and the active trip for a captain.
class CaptainState extends ChangeNotifier {
  final SessionStore session = SessionStore();
  late final ApiClient api = ApiClient(session: session);

  AppConfig? config;
  List<CategoryOption> categories = const [];
  UserSession? user;
  CaptainProfileSnapshot? profile;
  CaptainDashboard? dashboard;
  List<Offer> offers = const [];
  Ride? activeRide;

  bool ready = false;
  bool busy = false;
  String? bootError;
  String? actionError;
  DateTime? lastSync;

  NeevRealtime? _realtime;
  Timer? _poll;
  bool _disposed = false;

  bool get signedIn => user != null && session.isSignedIn;
  bool get onboardingRequired => profile?.onboardingRequired ?? true;
  bool get approved => profile?.verificationStatus == 'approved';
  bool get isOnline => dashboard?.isOnline ?? profile?.isOnline ?? false;
  bool get gpsSimulation => config?.gpsSimulation ?? false;
  String get name => profile?.name ?? user?.name ?? 'Captain';

  Future<void> bootstrap() async {
    ready = false;
    bootError = null;
    _notify();
    await session.load();
    try {
      config = await api.config();
      categories = await api.categories();
      if (session.isSignedIn) {
        user = await api.me();
        await _loadProfile();
        if (approved) {
          await refreshDashboard();
          await refreshOffers();
        }
        _connectRealtime();
        _startPolling();
      }
    } on ApiException catch (error) {
      bootError = error.message;
    } catch (error) {
      bootError = 'Could not start Neev Captain: $error';
    } finally {
      ready = true;
      _notify();
    }
  }

  Future<void> adoptSignIn(AuthResult result) async {
    user = result.user;
    await _loadProfile();
    if (approved) {
      await refreshDashboard();
      await refreshOffers();
    }
    _connectRealtime();
    _startPolling();
    _notify();
  }

  Future<void> _loadProfile() async {
    try {
      profile = await api.captainProfile();
    } on ApiException {
      profile = null;
    }
  }

  Future<void> refreshProfile() async {
    await _loadProfile();
    if (approved) {
      await refreshDashboard();
      await refreshOffers();
    }
    _notify();
  }

  Future<void> refreshDashboard() async {
    if (!approved) return;
    try {
      dashboard = await api.captainDashboard();
      activeRide = dashboard?.activeRide;
    } on ApiException catch (error) {
      actionError = error.message;
    }
    lastSync = DateTime.now();
    _notify();
  }

  Future<void> refreshOffers() async {
    if (!approved || !isOnline) {
      offers = const [];
      _notify();
      return;
    }
    try {
      offers = await api.captainOffers();
    } on ApiException catch (error) {
      actionError = error.message;
      offers = const [];
    }
    _notify();
  }

  Future<void> setOnline(bool online, {double? lat, double? lng}) async {
    busy = true;
    actionError = null;
    _notify();
    try {
      await api.setAvailability(
        online: online,
        lat: online ? (lat ?? 12.9719) : null,
        lng: online ? (lng ?? 77.6412) : null,
      );
      await refreshDashboard();
      await refreshOffers();
    } on ApiException catch (error) {
      actionError = error.message;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<Ride?> accept(Offer offer) async {
    busy = true;
    actionError = null;
    _notify();
    try {
      final ride = await api.acceptOffer(offer.rideId);
      activeRide = ride;
      await refreshDashboard();
      await refreshOffers();
      return ride;
    } on ApiException catch (error) {
      actionError = error.message;
      await refreshOffers();
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> reject(Offer offer) async {
    try {
      await api.rejectOffer(offer.rideId);
      offers = offers.where((o) => o.rideId != offer.rideId).toList();
      _notify();
    } on ApiException catch (error) {
      actionError = error.message;
      _notify();
    }
  }

  Future<Ride?> latest(String rideId) async {
    try {
      final ride = await api.ride(rideId);
      if (activeRide?.id == rideId) activeRide = ride;
      _notify();
      return ride;
    } on ApiException {
      return null;
    }
  }

  void setActiveRide(Ride? ride) {
    activeRide = ride;
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
    _poll?.cancel();
    user = null;
    profile = null;
    dashboard = null;
    offers = const [];
    activeRide = null;
    _notify();
  }

  void _connectRealtime() {
    if (session.accessToken == null) return;
    if (_realtime != null) return;
    _realtime = NeevRealtime(
      baseUrl: api.baseUrl,
      accessToken: session.accessToken!,
      onEvent: (event) {
        _notify();
        if (event.type.startsWith('ride.') ||
            event.type.startsWith('trip.') ||
            event.type.startsWith('payment.') ||
            event.type == 'dispatch.offer') {
          refreshDashboard();
          refreshOffers();
        }
      },
    )..connect();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) {
      if (approved) {
        refreshDashboard();
        if (isOnline) refreshOffers();
      }
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _realtime?.dispose();
    api.dispose();
    super.dispose();
  }
}
