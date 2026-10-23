import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'models.dart';
import 'session.dart';

const defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

class ApiException implements Exception {
  ApiException(this.statusCode, this.code, this.message, [this.details]);
  final int statusCode;
  final String code;
  final String message;
  final Object? details;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl, required this.session})
      : baseUrl = (baseUrl ?? defaultApiBaseUrl).replaceAll(RegExp(r'/$'), '');

  final String baseUrl;
  final SessionStore session;
  final http.Client _http = http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (session.accessToken != null)
          'Authorization': 'Bearer ${session.accessToken}',
      };

  Uri _uri(String path, [Map<String, String?>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized').replace(
      queryParameters: query
          ?.map((k, v) => MapEntry(k, v ?? ''))
          .map((k, v) => MapEntry(k, v.isEmpty ? null : v)),
    );
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String?>? query,
    bool retry = true,
  }) async {
    final uri = _uri(path, query);
    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _http.get(uri, headers: _headers);
        case 'POST':
          response = await _http.post(uri,
              headers: _headers, body: body == null ? null : jsonEncode(body));
        case 'PATCH':
          response = await _http.patch(uri,
              headers: _headers, body: body == null ? null : jsonEncode(body));
        case 'PUT':
          response = await _http.put(uri,
              headers: _headers, body: body == null ? null : jsonEncode(body));
        case 'DELETE':
          response = await _http.delete(uri, headers: _headers);
        default:
          throw ApiException(0, 'bad_method', 'Unsupported request.');
      }
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException(
        0,
        'network_error',
        'Cannot reach the Neev API at $baseUrl. Check that the backend is running.',
      );
    }

    if (response.statusCode == 401 &&
        retry &&
        session.refreshToken != null &&
        !path.contains('/auth/refresh') &&
        !path.contains('/admin/')) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _request(method, path, body: body, query: query, retry: false);
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String code = 'request_failed';
    String message = 'Request failed (${response.statusCode}).';
    Object? details;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        code = (error['code'] ?? code).toString();
        message = (error['message'] ?? message).toString();
        details = error['details'];
      }
    } catch (_) {
      // Keep the generic message when the body is not our error envelope.
    }
    if (response.statusCode == 422 && details is List && details.isNotEmpty) {
      final first = details.first;
      if (first is Map && first['message'] != null) {
        message = first['message'].toString();
      }
    }
    throw ApiException(response.statusCode, code, message, details);
  }

  Future<bool> _tryRefresh() async {
    try {
      final response = await _http.post(
        _uri('/api/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': session.refreshToken}),
      );
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await session.updateTokens(
        data['access_token'].toString(),
        data['refresh_token'].toString(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------- auth
  Future<OtpChallenge> requestOtp(String phone, String role) async {
    final data = await _request(
      'POST',
      '/api/v1/auth/otp/request',
      body: {'phone': phone, 'role': role},
    ) as Map<String, dynamic>;
    return OtpChallenge.fromJson(data);
  }

  Future<AuthResult> verifyOtp(
      String phone, String code, String role, {String? deviceId}) async {
    final data = await _request(
      'POST',
      '/api/v1/auth/otp/verify',
      body: {
        'phone': phone,
        'code': code,
        'role': role,
        'device_id': deviceId ?? 'neev-flutter-web',
      },
    ) as Map<String, dynamic>;
    final result = AuthResult.fromJson(data);
    await session.save(result);
    return result;
  }

  Future<UserSession> me() async {
    final data =
        await _request('GET', '/api/v1/auth/me') as Map<String, dynamic>;
    final user = UserSession.fromJson(data);
    await session.updateUser(user);
    return user;
  }

  Future<void> logoutAll() async {
    await _request('POST', '/api/v1/auth/logout-all', body: {});
    await session.clear();
  }

  // ------------------------------------------------------------- catalog
  Future<AppConfig> config() async =>
      AppConfig.fromJson(await _request('GET', '/api/v1/catalog/config')
          as Map<String, dynamic>);

  Future<List<CategoryOption>> categories() async {
    final data = await _request('GET', '/api/v1/catalog/categories') as List;
    return data
        .map((e) => CategoryOption.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Place>> searchPlaces(String query) async {
    final data = await _request(
      'GET',
      '/api/v1/locations/search',
      query: {'q': query},
    ) as Map<String, dynamic>;
    return (data['results'] as List? ?? [])
        .map((e) => Place.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Place> reversePlace(double lat, double lng) async {
    final data = await _request(
      'GET',
      '/api/v1/locations/reverse',
      query: {'lat': '$lat', 'lng': '$lng'},
    ) as Map<String, dynamic>;
    return Place.fromJson((data['place'] as Map).cast<String, dynamic>());
  }

  Future<Quote> quote({
    required String category,
    required Place pickup,
    required Place drop,
    bool usePowerPass = true,
    String? couponCode,
  }) async {
    final data = await _request(
      'POST',
      '/api/v1/fares/quote',
      body: {
        'category': category,
        'pickup': {
          'address': pickup.address,
          'lat': pickup.lat,
          'lng': pickup.lng,
        },
        'drop': {
          'address': drop.address,
          'lat': drop.lat,
          'lng': drop.lng,
        },
        'use_power_pass': usePowerPass,
        if (couponCode != null && couponCode.trim().isNotEmpty)
          'coupon_code': couponCode.trim().toUpperCase(),
      },
    ) as Map<String, dynamic>;
    return Quote.fromJson(data);
  }

  // --------------------------------------------------------------- rides
  Future<Ride> requestRide({
    required String category,
    required Place pickup,
    required Place drop,
    required String idempotencyKey,
    String paymentMethod = 'cash',
    bool usePowerPass = true,
    String? couponCode,
  }) async {
    final data = await _request(
      'POST',
      '/api/v1/rides/request',
      body: {
        'category': category,
        'pickup': {
          'address': pickup.address,
          'lat': pickup.lat,
          'lng': pickup.lng,
        },
        'drop': {
          'address': drop.address,
          'lat': drop.lat,
          'lng': drop.lng,
        },
        'idempotency_key': idempotencyKey,
        'payment_method': paymentMethod,
        'use_power_pass': usePowerPass,
        if (couponCode != null && couponCode.trim().isNotEmpty)
          'coupon_code': couponCode.trim().toUpperCase(),
      },
    ) as Map<String, dynamic>;
    return Ride.fromJson(data);
  }

  Future<Ride> ride(String rideId) async =>
      Ride.fromJson(await _request('GET', '/api/v1/rides/$rideId')
          as Map<String, dynamic>);

  Future<List<Ride>> rides({int limit = 30}) async {
    final data = await _request(
      'GET',
      '/api/v1/rides',
      query: {'limit': '$limit'},
    ) as Map<String, dynamic>;
    return (data['items'] as List? ?? [])
        .map((e) => Ride.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Ride> cancelRide(String rideId, String reason) async {
    final data = await _request(
      'POST',
      '/api/v1/rides/$rideId/cancel',
      body: {'reason': reason, 'accept_cancellation_fee': true},
    ) as Map<String, dynamic>;
    return Ride.fromJson(data);
  }

  Future<Map<String, dynamic>> rateRide(
    String rideId,
    int stars, {
    String? comment,
    List<String> tags = const [],
  }) async {
    return await _request(
      'POST',
      '/api/v1/rides/$rideId/rate',
      body: {'stars': stars, 'comment': comment, 'tags': tags},
    ) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> rideLocations(String rideId) async {
    final data = await _request('GET', '/api/v1/rides/$rideId/locations')
        as Map<String, dynamic>;
    return (data['items'] as List? ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> shareRide(String rideId,
      {int durationMinutes = 240}) async {
    return await _request(
      'POST',
      '/api/v1/rides/$rideId/share',
      body: {'duration_minutes': durationMinutes},
    ) as Map<String, dynamic>;
  }

  Future<Ride?> activeRide() async {
    final items = await rides(limit: 5);
    for (final ride in items) {
      if (ride.isLive) return ride;
    }
    return null;
  }

  // ------------------------------------------------------------- captain
  Future<CaptainProfileSnapshot> captainProfile() async =>
      CaptainProfileSnapshot.fromJson(
          await _request('GET', '/api/v1/captain/profile')
              as Map<String, dynamic>);

  Future<Map<String, dynamic>> captainOnboarding({
    required String name,
    required String dlNumber,
    String? email,
    String? panNumber,
    String? aadhaarLast4,
    String? serviceAreaId,
  }) async {
    return await _request(
      'POST',
      '/api/v1/captain/onboarding',
      body: {
        'name': name,
        'dl_number': dlNumber,
        if (email != null) 'email': email,
        if (panNumber != null) 'pan_number': panNumber,
        if (aadhaarLast4 != null) 'aadhaar_last4': aadhaarLast4,
        if (serviceAreaId != null) 'service_area_id': serviceAreaId,
      },
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCaptainProfile(
      Map<String, dynamic> patch) async {
    return await _request('PUT', '/api/v1/captain/profile', body: patch)
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addVehicle({
    required String category,
    required String regNumber,
    required String makeModel,
    String? color,
    int? year,
  }) async {
    return await _request(
      'POST',
      '/api/v1/captain/vehicles',
      body: {
        'category': category,
        'reg_number': regNumber,
        'make_model': makeModel,
        if (color != null) 'color': color,
        if (year != null) 'year': year,
      },
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadDocument({
    required String docType,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/v1/captain/documents'),
    );
    request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    request.fields['doc_type'] = docType;
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: _mediaType(mimeType),
    ));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(
      response.statusCode,
      'upload_failed',
      'Document upload failed (${response.statusCode}).',
    );
  }

  Future<Map<String, dynamic>> setAvailability({
    required bool online,
    double? lat,
    double? lng,
  }) async {
    return await _request(
      'POST',
      '/api/v1/captain/availability',
      body: {
        'is_online': online,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    ) as Map<String, dynamic>;
  }

  Future<void> postIdleLocation(double lat, double lng,
      {String source = 'simulated'}) async {
    await _request(
      'POST',
      '/api/v1/captain/location',
      body: {'lat': lat, 'lng': lng, 'source': source},
    );
  }

  Future<CaptainDashboard> captainDashboard() async =>
      CaptainDashboard.fromJson(await _request('GET', '/api/v1/captain/dashboard')
          as Map<String, dynamic>);

  Future<List<Offer>> captainOffers() async {
    final data = await _request('GET', '/api/v1/captain/offers')
        as Map<String, dynamic>;
    return (data['items'] as List? ?? [])
        .map((e) => Offer.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Ride> acceptOffer(String rideId) async =>
      Ride.fromJson(await _request(
        'POST',
        '/api/v1/captain/offers/$rideId/accept',
      ) as Map<String, dynamic>);

  Future<void> rejectOffer(String rideId) async {
    await _request('POST', '/api/v1/captain/offers/$rideId/reject');
  }

  Future<Ride> arrived(String tripId) async =>
      Ride.fromJson(await _request(
        'POST',
        '/api/v1/captain/trips/$tripId/arrived',
      ) as Map<String, dynamic>);

  Future<Ride> startTrip(String tripId, String pin) async =>
      Ride.fromJson(await _request(
        'POST',
        '/api/v1/captain/trips/$tripId/start',
        body: {'pin': pin},
      ) as Map<String, dynamic>);

  Future<Map<String, dynamic>> postLocation({
    required String tripId,
    required double lat,
    required double lng,
    required DateTime recordedAt,
    String source = 'simulated',
    double? speedMps,
    double? heading,
  }) async {
    return await _request(
      'POST',
      '/api/v1/captain/trips/$tripId/location',
      body: {
        'lat': lat,
        'lng': lng,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'source': source,
        if (speedMps != null) 'speed_mps': speedMps,
        if (heading != null) 'heading': heading,
      },
    ) as Map<String, dynamic>;
  }

  Future<Ride> completeTrip(String tripId, double lat, double lng) async =>
      Ride.fromJson(await _request(
        'POST',
        '/api/v1/captain/trips/$tripId/complete',
        body: {'lat': lat, 'lng': lng},
      ) as Map<String, dynamic>);

  Future<List<Ride>> captainTrips() async {
    final data = await _request('GET', '/api/v1/captain/trips')
        as Map<String, dynamic>;
    return (data['items'] as List? ?? [])
        .map((e) => Ride.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Map<String, dynamic>> captainEarnings() async =>
      await _request('GET', '/api/v1/captain/earnings') as Map<String, dynamic>;

  Future<Map<String, dynamic>> requestPayout({
    required int amountPaise,
    required String destination,
    String method = 'upi',
  }) async {
    return await _request(
      'POST',
      '/api/v1/captain/payouts',
      body: {
        'amount_paise': amountPaise,
        'destination': destination,
        'method': method,
      },
    ) as Map<String, dynamic>;
  }

  // ------------------------------------------------------------ payments
  Future<List<PaymentMethod>> paymentMethods() async {
    final data =
        await _request('GET', '/api/v1/payments/methods') as Map<String, dynamic>;
    return (data['methods'] as List? ?? [])
        .map((e) => PaymentMethod.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Map<String, dynamic>> createRidePayment(
    String rideId,
    String method,
    String idempotencyKey,
  ) async {
    return await _request(
      'POST',
      '/api/v1/payments/rides/$rideId',
      body: {'method': method, 'idempotency_key': idempotencyKey},
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> confirmCash(String rideId) async =>
      await _request('POST', '/api/v1/payments/rides/$rideId/cash-confirm')
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> confirmSandbox(
    String paymentId,
    String outcome,
    String idempotencyKey,
  ) async {
    return await _request(
      'POST',
      '/api/v1/payments/$paymentId/sandbox-confirm',
      body: {'outcome': outcome, 'idempotency_key': idempotencyKey},
    ) as Map<String, dynamic>;
  }

  Future<List<PaymentRecord>> paymentHistory() async {
    final data =
        await _request('GET', '/api/v1/payments/history') as Map<String, dynamic>;
    return (data['payments'] as List? ?? [])
        .map((e) => PaymentRecord.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Map<String, dynamic>> wallet() async =>
      await _request('GET', '/api/v1/passenger/wallet') as Map<String, dynamic>;

  Future<Map<String, dynamic>> walletTopup(
          int amountPaise, String idempotencyKey) async =>
      await _request(
        'POST',
        '/api/v1/payments/wallet/topup',
        body: {
          'amount_paise': amountPaise,
          'method': 'mock_upi',
          'idempotency_key': idempotencyKey,
        },
      ) as Map<String, dynamic>;

  Future<Map<String, dynamic>> refund(String paymentId, String reason) async =>
      await _request(
        'POST',
        '/api/v1/payments/$paymentId/refund',
        body: {'reason': reason},
      ) as Map<String, dynamic>;

  // ---------------------------------------------------------- power pass
  Future<Map<String, dynamic>> powerPass() async =>
      await _request('GET', '/api/v1/passenger/power-pass') as Map<String, dynamic>;

  Future<Map<String, dynamic>> purchasePowerPass(
          String planId, String idempotencyKey) async =>
      await _request(
        'POST',
        '/api/v1/passenger/power-pass/purchase',
        body: {
          'plan_id': planId,
          'method': 'mock_upi',
          'idempotency_key': idempotencyKey,
        },
      ) as Map<String, dynamic>;

  // -------------------------------------------------------------- safety
  Future<Map<String, dynamic>> safetyFeatures() async =>
      await _request('GET', '/api/v1/safety/features') as Map<String, dynamic>;

  Future<Map<String, dynamic>> triggerSos({
    String? rideId,
    double? lat,
    double? lng,
    String? note,
  }) async {
    return await _request(
      'POST',
      '/api/v1/safety/sos',
      body: {
        if (rideId != null) 'ride_request_id': rideId,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'press_hold_ms': 3500,
        if (note != null) 'note': note,
      },
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelSos(String incidentId) async =>
      await _request('POST', '/api/v1/safety/sos/$incidentId/cancel')
          as Map<String, dynamic>;

  Future<Map<String, dynamic>?> activeSos() async {
    final data =
        await _request('GET', '/api/v1/safety/sos/active') as Map<String, dynamic>;
    return (data['active'] as Map?)?.cast<String, dynamic>();
  }

  // ------------------------------------------------------------- support
  Future<List<Map<String, dynamic>>> tickets() async {
    final data = await _request('GET', '/api/v1/support/tickets') as List;
    return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> createTicket({
    required String category,
    required String subject,
    required String description,
    String? rideId,
  }) async {
    return await _request(
      'POST',
      '/api/v1/support/tickets',
      body: {
        'category': category,
        'subject': subject,
        'description': description,
        if (rideId != null) 'ride_request_id': rideId,
      },
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> ticketDetail(String ticketId) async =>
      await _request('GET', '/api/v1/support/tickets/$ticketId')
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> replyTicket(
          String ticketId, String body) async =>
      await _request(
        'POST',
        '/api/v1/support/tickets/$ticketId/messages',
        body: {'body': body},
      ) as Map<String, dynamic>;

  // ------------------------------------------------------- notifications
  Future<List<AppNotification>> notifications() async {
    final data = await _request('GET', '/api/v1/notifications')
        as Map<String, dynamic>;
    return (data['items'] as List? ?? [])
        .map((e) => AppNotification.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<int> markNotificationsRead({List<String> ids = const []}) async {
    final data = await _request(
      'POST',
      '/api/v1/notifications/read',
      body: {'notification_ids': ids},
    ) as Map<String, dynamic>;
    return (data['updated'] as num?)?.toInt() ?? 0;
  }

  // ------------------------------------------------------------ profile
  Future<Map<String, dynamic>> passengerProfile() async =>
      await _request('GET', '/api/v1/passenger/profile') as Map<String, dynamic>;

  Future<Map<String, dynamic>> updatePassengerProfile(
      Map<String, dynamic> patch) async {
    return await _request('PUT', '/api/v1/passenger/profile', body: patch)
        as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> savedAddresses() async {
    final data = await _request('GET', '/api/v1/passenger/saved-addresses') as List;
    return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> addSavedAddress({
    required String label,
    required String address,
    required double lat,
    required double lng,
  }) async {
    return await _request(
      'POST',
      '/api/v1/passenger/saved-addresses',
      body: {'label': label, 'address': address, 'lat': lat, 'lng': lng},
    ) as Map<String, dynamic>;
  }

  Future<void> deleteSavedAddress(String addressId) async {
    await _request('DELETE', '/api/v1/passenger/saved-addresses/$addressId');
  }

  Future<List<Map<String, dynamic>>> trustedContacts() async {
    final data = await _request('GET', '/api/v1/passenger/trusted-contacts') as List;
    return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> addTrustedContact({
    required String name,
    required String phone,
    String? relationship,
  }) async {
    return await _request(
      'POST',
      '/api/v1/passenger/trusted-contacts',
      body: {
        'name': name,
        'phone': phone,
        if (relationship != null) 'relationship': relationship,
      },
    ) as Map<String, dynamic>;
  }

  Future<void> deleteTrustedContact(String contactId) async {
    await _request('DELETE', '/api/v1/passenger/trusted-contacts/$contactId');
  }

  void dispose() => _http.close();
}

MediaType _mediaType(String mimeType) {
  try {
    return MediaType.parse(mimeType);
  } catch (_) {
    return MediaType('application', 'octet-stream');
  }
}
