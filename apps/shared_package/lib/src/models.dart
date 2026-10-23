import 'package:flutter/material.dart';

double _d(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _i(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

DateTime? _dt(dynamic value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

class LatLng {
  const LatLng(this.lat, this.lng);
  final double lat;
  final double lng;

  factory LatLng.fromJson(Map<String, dynamic> json) =>
      LatLng(_d(json['lat']), _d(json['lng']));

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.label = 'Demo location',
    this.provider = 'demo',
  });

  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String label;
  final String provider;

  LatLng get point => LatLng(lat, lng);

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Pinned location').toString(),
        address: (json['address'] ?? '').toString(),
        lat: _d(json['lat']),
        lng: _d(json['lng']),
        label: (json['label'] ?? 'Demo location').toString(),
        provider: (json['provider'] ?? 'demo').toString(),
      );
}

class FareLine {
  const FareLine({required this.label, required this.amountPaise});
  final String label;
  final int amountPaise;

  factory FareLine.fromJson(Map<String, dynamic> json) => FareLine(
        label: (json['label'] ?? '').toString(),
        amountPaise: _i(json['amount_paise']),
      );
}

class Quote {
  const Quote({
    required this.category,
    required this.distanceM,
    required this.durationS,
    required this.totalPaise,
    required this.totalDisplay,
    required this.lines,
    required this.surgeMultiplier,
    required this.discountPaise,
    required this.powerPassApplied,
    required this.couponCode,
    required this.routePoints,
    required this.routeProvider,
    required this.approximateRoute,
  });

  final String category;
  final int distanceM;
  final int durationS;
  final int totalPaise;
  final String totalDisplay;
  final List<FareLine> lines;
  final double surgeMultiplier;
  final int discountPaise;
  final bool powerPassApplied;
  final String? couponCode;
  final List<LatLng> routePoints;
  final String routeProvider;
  final bool approximateRoute;

  String get distanceLabel => distanceM >= 1000
      ? '${(distanceM / 1000).toStringAsFixed(1)} km'
      : '$distanceM m';
  String get durationLabel => '${(durationS / 60).round()} min';

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        category: (json['category'] ?? '').toString(),
        distanceM: _i(json['distance_m']),
        durationS: _i(json['duration_s']),
        totalPaise: _i(json['total_paise']),
        totalDisplay: (json['total_display'] ?? '').toString(),
        lines: (json['lines'] as List? ?? [])
            .map((e) => FareLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        surgeMultiplier: _d(json['surge_multiplier'], 1),
        discountPaise: _i(json['discount_paise']),
        powerPassApplied: json['power_pass_applied'] == true,
        couponCode: json['coupon_code']?.toString(),
        routePoints: (json['route_points'] as List? ?? [])
            .map((e) => LatLng(_d((e as List)[0]), _d(e[1])))
            .toList(),
        routeProvider: (json['route_provider'] ?? 'demo').toString(),
        approximateRoute: json['approximate_route'] == true,
      );
}

class CategoryOption {
  const CategoryOption({
    required this.code,
    required this.displayName,
    required this.description,
    required this.capacity,
    required this.icon,
    this.baseFarePaise,
  });

  final String code;
  final String displayName;
  final String description;
  final int capacity;
  final String icon;
  final int? baseFarePaise;

  factory CategoryOption.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'] as Map<String, dynamic>?;
    return CategoryOption(
      code: (json['code'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      capacity: _i(json['capacity'], 1),
      icon: (json['icon'] ?? 'bike').toString(),
      baseFarePaise: pricing == null ? null : _i(pricing['base_fare_paise']),
    );
  }
}

class ServiceArea {
  const ServiceArea({
    required this.id,
    required this.name,
    required this.city,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String name;
  final String city;
  final double lat;
  final double lng;

  factory ServiceArea.fromJson(Map<String, dynamic> json) => ServiceArea(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        city: (json['city'] ?? '').toString(),
        lat: _d(json['center_lat'] ?? (json['center'] as Map?)?['lat']),
        lng: _d(json['center_lng'] ?? (json['center'] as Map?)?['lng']),
      );
}

class AppConfig {
  const AppConfig({
    required this.brand,
    required this.mapProvider,
    required this.demoDataset,
    required this.sandboxPayments,
    required this.gpsSimulation,
    required this.serviceAreas,
    required this.dispatchRadiusKm,
    required this.paymentNote,
  });

  final String brand;
  final String mapProvider;
  final bool demoDataset;
  final bool sandboxPayments;
  final bool gpsSimulation;
  final List<ServiceArea> serviceAreas;
  final double dispatchRadiusKm;
  final String paymentNote;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final map = json['map'] as Map<String, dynamic>? ?? {};
    return AppConfig(
      brand: (json['brand'] ?? 'Neev').toString(),
      mapProvider: (map['provider'] ?? 'demo').toString(),
      demoDataset: map['demo_dataset'] == true,
      sandboxPayments: json['sandbox_payments'] == true,
      gpsSimulation: json['gps_simulation'] == true,
      serviceAreas: (json['service_areas'] as List? ?? [])
          .map((e) => ServiceArea.fromJson(e as Map<String, dynamic>))
          .toList(),
      dispatchRadiusKm: _d(json['dispatch_radius_km'], 5),
      paymentNote: (json['payments'] is Map
              ? (json['payments'] as Map)['note']
              : null)
          ?.toString() ??
          '',
    );
  }
}

class Offer {
  const Offer({
    required this.rideId,
    required this.category,
    required this.pickupAddress,
    required this.dropAddress,
    required this.pickup,
    required this.drop,
    required this.distanceM,
    required this.durationS,
    required this.farePaise,
    required this.fareDisplay,
    required this.distanceToPickupM,
    required this.expiresAt,
    required this.passengerName,
  });

  final String rideId;
  final String category;
  final String pickupAddress;
  final String dropAddress;
  final LatLng pickup;
  final LatLng drop;
  final int distanceM;
  final int durationS;
  final int farePaise;
  final String fareDisplay;
  final int distanceToPickupM;
  final DateTime? expiresAt;
  final String passengerName;

  factory Offer.fromJson(Map<String, dynamic> json) {
    final pickup = json['pickup'] as Map<String, dynamic>? ?? {};
    final drop = json['drop'] as Map<String, dynamic>? ?? {};
    return Offer(
      rideId: (json['ride_id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      pickupAddress: (pickup['address'] ?? '').toString(),
      dropAddress: (drop['address'] ?? '').toString(),
      pickup: LatLng(_d(pickup['lat']), _d(pickup['lng'])),
      drop: LatLng(_d(drop['lat']), _d(drop['lng'])),
      distanceM: _i(json['distance_m']),
      durationS: _i(json['duration_s']),
      farePaise: _i(json['fare_paise']),
      fareDisplay: (json['fare_display'] ?? '').toString(),
      distanceToPickupM: _i(json['distance_to_pickup_m']),
      expiresAt: _dt(json['expires_at']),
      passengerName: (json['passenger_name'] ?? 'Neev rider').toString(),
    );
  }
}

class RideCaptain {
  const RideCaptain({
    required this.id,
    required this.name,
    this.phone,
    this.rating,
    this.totalTrips,
  });

  final String id;
  final String name;
  final String? phone;
  final double? rating;
  final int? totalTrips;

  factory RideCaptain.fromJson(Map<String, dynamic> json) => RideCaptain(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Neev captain').toString(),
        phone: json['phone']?.toString(),
        rating: json['rating'] == null ? null : _d(json['rating']),
        totalTrips:
            json['total_trips'] == null ? null : _i(json['total_trips']),
      );
}

class RideVehicle {
  const RideVehicle({
    required this.regNumber,
    required this.makeModel,
    this.color,
    this.category,
  });

  final String regNumber;
  final String makeModel;
  final String? color;
  final String? category;

  factory RideVehicle.fromJson(Map<String, dynamic> json) => RideVehicle(
        regNumber: (json['reg_number'] ?? '').toString(),
        makeModel: (json['make_model'] ?? '').toString(),
        color: json['color']?.toString(),
        category: json['category']?.toString(),
      );
}

class RideTrip {
  const RideTrip({
    required this.id,
    required this.state,
    required this.paymentStatus,
    required this.paymentMethod,
    this.startPin,
    this.finalFarePaise,
    this.dropVerified,
    this.durationS,
    this.distanceM,
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final String state;
  final String paymentStatus;
  final String paymentMethod;
  final String? startPin;
  final int? finalFarePaise;
  final bool? dropVerified;
  final int? durationS;
  final int? distanceM;
  final DateTime? startedAt;
  final DateTime? completedAt;

  factory RideTrip.fromJson(Map<String, dynamic> json) => RideTrip(
        id: (json['id'] ?? '').toString(),
        state: (json['state'] ?? '').toString(),
        paymentStatus: (json['payment_status'] ?? 'pending').toString(),
        paymentMethod: (json['payment_method'] ?? 'cash').toString(),
        startPin: json['start_pin']?.toString(),
        finalFarePaise:
            json['final_fare_paise'] == null ? null : _i(json['final_fare_paise']),
        dropVerified: json['drop_verified'] as bool?,
        durationS: json['duration_s'] == null ? null : _i(json['duration_s']),
        distanceM: json['distance_m'] == null ? null : _i(json['distance_m']),
        startedAt: _dt(json['started_at']),
        completedAt: _dt(json['completed_at']),
      );
}

class RidePayment {
  const RidePayment({
    required this.id,
    required this.method,
    required this.methodLabel,
    required this.status,
    required this.amountPaise,
    required this.isSandbox,
  });

  final String id;
  final String method;
  final String methodLabel;
  final String status;
  final int amountPaise;
  final bool isSandbox;

  factory RidePayment.fromJson(Map<String, dynamic> json) => RidePayment(
        id: (json['id'] ?? '').toString(),
        method: (json['method'] ?? '').toString(),
        methodLabel: (json['method_label'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        amountPaise: _i(json['amount_paise']),
        isSandbox: json['is_sandbox'] == true,
      );
}

class RideEventItem {
  const RideEventItem({
    required this.id,
    required this.type,
    required this.payload,
    this.createdAt,
  });

  final int id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  factory RideEventItem.fromJson(Map<String, dynamic> json) => RideEventItem(
        id: _i(json['event_id']),
        type: (json['type'] ?? '').toString(),
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: _dt(json['created_at']),
      );
}

class Ride {
  const Ride({
    required this.id,
    required this.category,
    required this.status,
    required this.paymentMethod,
    required this.pickup,
    required this.pickupAddress,
    required this.drop,
    required this.dropAddress,
    required this.distanceM,
    required this.durationS,
    required this.quotedFarePaise,
    required this.quotedFareDisplay,
    this.trip,
    this.captain,
    this.vehicle,
    this.payment,
    this.events = const [],
    this.offersSent = 0,
    this.captainsAvailable = 0,
    this.routePoints = const [],
    this.couponCode,
    this.discountPaise = 0,
    this.cancellationReason,
    this.cancellationFeePaise = 0,
    this.createdAt,
  });

  final String id;
  final String category;
  final String status;
  final String paymentMethod;
  final LatLng pickup;
  final String pickupAddress;
  final LatLng drop;
  final String dropAddress;
  final int distanceM;
  final int durationS;
  final int quotedFarePaise;
  final String quotedFareDisplay;
  final RideTrip? trip;
  final RideCaptain? captain;
  final RideVehicle? vehicle;
  final RidePayment? payment;
  final List<RideEventItem> events;
  final int offersSent;
  final int captainsAvailable;
  final List<LatLng> routePoints;
  final String? couponCode;
  final int discountPaise;
  final String? cancellationReason;
  final int cancellationFeePaise;
  final DateTime? createdAt;

  bool get isLive =>
      status == 'searching' || status == 'assigned' || status == 'in_progress';
  bool get isComplete => status == 'completed';
  bool get isCancelled => status == 'cancelled' || status == 'expired';

  factory Ride.fromJson(Map<String, dynamic> json) {
    final pickup = json['pickup'] as Map<String, dynamic>? ?? {};
    final drop = json['drop'] as Map<String, dynamic>? ?? {};
    final trip = json['trip'] as Map<String, dynamic>?;
    final captain = json['captain'] as Map<String, dynamic>?;
    final vehicle = json['vehicle'] as Map<String, dynamic>?;
    final payment = json['payment'] as Map<String, dynamic>?;
    return Ride(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      paymentMethod: (json['payment_method'] ?? 'cash').toString(),
      pickup: LatLng(_d(pickup['lat']), _d(pickup['lng'])),
      pickupAddress: (pickup['address'] ?? '').toString(),
      drop: LatLng(_d(drop['lat']), _d(drop['lng'])),
      dropAddress: (drop['address'] ?? '').toString(),
      distanceM: _i(json['distance_m']),
      durationS: _i(json['duration_s']),
      quotedFarePaise: _i(json['quoted_fare_paise']),
      quotedFareDisplay: (json['quoted_fare_display'] ?? '').toString(),
      trip: trip == null ? null : RideTrip.fromJson(trip),
      captain: captain == null ? null : RideCaptain.fromJson(captain),
      vehicle: vehicle == null ? null : RideVehicle.fromJson(vehicle),
      payment: payment == null ? null : RidePayment.fromJson(payment),
      events: (json['events'] as List? ?? [])
          .map((e) => RideEventItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      offersSent: _i(json['offers_sent']),
      captainsAvailable: _i(json['captains_available']),
      routePoints: (json['route_points'] as List? ?? [])
          .map((e) => LatLng(_d((e as List)[0]), _d(e[1])))
          .toList(),
      couponCode: json['coupon_code']?.toString(),
      discountPaise: _i(json['discount_paise']),
      cancellationReason: json['cancellation_reason']?.toString(),
      cancellationFeePaise: _i(json['cancellation_fee_paise']),
      createdAt: _dt(json['created_at']),
    );
  }
}

class UserSession {
  const UserSession({
    required this.id,
    required this.phone,
    required this.role,
    required this.name,
    this.verificationStatus,
    this.isOnline = false,
  });

  final String id;
  final String phone;
  final String role;
  final String name;
  final String? verificationStatus;
  final bool isOnline;

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final captain = json['captain'] as Map<String, dynamic>?;
    return UserSession(
      id: (json['id'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      name: (json['name'] ?? 'Neev user').toString(),
      verificationStatus: captain?['verification_status']?.toString(),
      isOnline: captain?['is_online'] == true,
    );
  }
}

class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserSession user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        accessToken: (json['access_token'] ?? '').toString(),
        refreshToken: (json['refresh_token'] ?? '').toString(),
        user: UserSession.fromJson(
            (json['user'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}

class OtpChallenge {
  const OtpChallenge({
    required this.challengeId,
    required this.phone,
    required this.expiresIn,
    this.devOtp,
    required this.delivery,
  });

  final String challengeId;
  final String phone;
  final int expiresIn;
  final String? devOtp;
  final String delivery;

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
        challengeId: (json['challenge_id'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        expiresIn: _i(json['expires_in']),
        devOtp: json['dev_otp']?.toString(),
        delivery: (json['delivery'] ?? '').toString(),
      );
}

class PaymentMethod {
  const PaymentMethod({
    required this.code,
    required this.label,
    required this.enabled,
    this.warning,
    this.provider,
  });

  final String code;
  final String label;
  final bool enabled;
  final String? warning;
  final String? provider;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        code: (json['code'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        enabled: json['enabled'] == true,
        warning: json['warning']?.toString(),
        provider: json['provider']?.toString(),
      );
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.status,
    required this.method,
    required this.amountPaise,
    required this.provider,
    this.createdAt,
    this.sandbox = false,
  });

  final String id;
  final String status;
  final String method;
  final int amountPaise;
  final String provider;
  final DateTime? createdAt;
  final bool sandbox;

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: (json['id'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        method: (json['method'] ?? '').toString(),
        amountPaise: _i(json['amount_paise']),
        provider: (json['provider'] ?? '').toString(),
        createdAt: _dt(json['created_at']),
        sandbox: json['sandbox'] == true,
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get unread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        body: (json['body'] ?? '').toString(),
        readAt: _dt(json['read_at']),
        createdAt: _dt(json['created_at']),
      );
}

class EarningsSummary {
  const EarningsSummary({
    required this.availablePaise,
    required this.availableDisplay,
    required this.todayPaise,
    required this.weekPaise,
    required this.totalPaise,
    required this.tripCount,
  });

  final int availablePaise;
  final String availableDisplay;
  final int todayPaise;
  final int weekPaise;
  final int totalPaise;
  final int tripCount;

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    final available = json['available'] as Map<String, dynamic>? ??
        json['earnings'] as Map<String, dynamic>? ??
        {};
    final summary = json['summary'] as Map<String, dynamic>? ?? json;
    return EarningsSummary(
      availablePaise: _i(available['available_paise'] ?? summary['available_paise']),
      availableDisplay: (available['available_display'] ??
              summary['available_display'] ??
              '')
          .toString(),
      todayPaise: _i(summary['today_paise'] ?? summary['today']),
      weekPaise: _i(summary['week_paise'] ?? summary['week']),
      totalPaise: _i(summary['total_paise'] ?? summary['total']),
      tripCount: _i(summary['trip_count'] ?? summary['trips']),
    );
  }
}

class CaptainDashboard {
  const CaptainDashboard({
    required this.name,
    required this.verificationStatus,
    required this.isOnline,
    required this.offerCount,
    required this.earningsPaise,
    required this.earningsDisplay,
    required this.totalTrips,
    this.rating,
    this.activeRide,
    this.documentsPending = 0,
    this.documentsRejected = 0,
  });

  final String name;
  final String verificationStatus;
  final bool isOnline;
  final int offerCount;
  final int earningsPaise;
  final String earningsDisplay;
  final int totalTrips;
  final double? rating;
  final Ride? activeRide;
  final int documentsPending;
  final int documentsRejected;

  factory CaptainDashboard.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? {};
    final earnings = json['earnings'] as Map<String, dynamic>? ?? {};
    final active = json['active_ride'] as Map<String, dynamic>?;
    return CaptainDashboard(
      name: (profile['name'] ?? 'Neev captain').toString(),
      verificationStatus:
          (profile['verification_status'] ?? 'pending').toString(),
      isOnline: profile['is_online'] == true,
      offerCount: _i(json['offer_count']),
      earningsPaise: _i(earnings['available_paise']),
      earningsDisplay: (earnings['available_display'] ?? '').toString(),
      totalTrips: _i(profile['total_trips']),
      rating: profile['rating'] == null ? null : _d(profile['rating']),
      activeRide: active == null ? null : Ride.fromJson(active),
      documentsPending: _i(json['documents_pending']),
      documentsRejected: _i(json['documents_rejected']),
    );
  }
}

class CaptainProfileSnapshot {
  const CaptainProfileSnapshot({
    required this.onboardingRequired,
    required this.name,
    this.verificationStatus,
    this.rejectionReason,
    this.isOnline = false,
    this.rating,
    this.totalTrips = 0,
    this.documents = const [],
    this.vehicles = const [],
    this.activeRide,
  });

  final bool onboardingRequired;
  final String name;
  final String? verificationStatus;
  final String? rejectionReason;
  final bool isOnline;
  final double? rating;
  final int totalTrips;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> vehicles;
  final Ride? activeRide;

  factory CaptainProfileSnapshot.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    final active = json['active_ride'] as Map<String, dynamic>?;
    return CaptainProfileSnapshot(
      onboardingRequired: json['onboarding_required'] == true || profile == null,
      name: (json['name'] ?? 'Neev captain').toString(),
      verificationStatus: profile?['verification_status']?.toString(),
      rejectionReason: profile?['rejection_reason']?.toString(),
      isOnline: profile?['is_online'] == true,
      rating: profile?['rating'] == null ? null : _d(profile?['rating']),
      totalTrips: _i(profile?['total_trips']),
      documents: (json['documents'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
      vehicles: (json['vehicles'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
      activeRide: active == null ? null : Ride.fromJson(active),
    );
  }
}

class RealtimeEvent {
  const RealtimeEvent({
    required this.type,
    required this.entityId,
    required this.payload,
    this.eventId,
    this.timestamp,
  });

  final String type;
  final String entityId;
  final Map<String, dynamic> payload;
  final int? eventId;
  final DateTime? timestamp;

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) => RealtimeEvent(
        type: (json['type'] ?? '').toString(),
        entityId: (json['entity_id'] ?? '').toString(),
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        eventId: json['event_id'] == null ? null : _i(json['event_id']),
        timestamp: _dt(json['timestamp']),
      );
}

/// Parses `#RRGGBB` / `#AARRGGBB` strings, falling back to Neev green.
extension HexColor on String {
  Color get color {
    final cleaned = replaceFirst('#', '').trim();
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return const Color(0xFF0E4F45);
  }
}
