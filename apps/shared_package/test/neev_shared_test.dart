import 'package:flutter_test/flutter_test.dart';
import 'package:neev_shared/neev_shared.dart';

void main() {
  group('money', () {
    test('formats paise using Indian grouping', () {
      expect(money(0), '₹0');
      expect(money(5000), '₹50');
      expect(money(123456), '₹1,234.56');
      expect(money(123456789), '₹12,34,567.89');
      expect(money(-5000), '-₹50');
    });
  });

  group('distance and duration labels', () {
    test('uses metres under one kilometre', () {
      expect(distanceLabel(850), '850 m');
      expect(distanceLabel(1200), '1.2 km');
      expect(durationLabel(45), '45 s');
      expect(durationLabel(600), '10 min');
      expect(durationLabel(3900), '1h 5m');
    });
  });

  group('models', () {
    test('parses a ride envelope', () {
      final ride = Ride.fromJson({
        'id': 'ride-1',
        'category': 'bike',
        'status': 'assigned',
        'payment_method': 'cash',
        'pickup': {'lat': 12.97, 'lng': 77.60, 'address': 'Indiranagar'},
        'drop': {'lat': 12.93, 'lng': 77.62, 'address': 'Koramangala'},
        'distance_m': 4200,
        'duration_s': 900,
        'quoted_fare_paise': 8900,
        'quoted_fare_display': '₹89',
        'trip': {
          'id': 'trip-1',
          'state': 'arriving',
          'payment_status': 'pending',
          'payment_method': 'cash',
        },
        'route_points': [
          [12.97, 77.60],
          [12.93, 77.62],
        ],
      });
      expect(ride.id, 'ride-1');
      expect(ride.isLive, isTrue);
      expect(ride.trip?.state, 'arriving');
      expect(ride.routePoints, hasLength(2));
      expect(ride.pickupAddress, 'Indiranagar');
    });

    test('parses an OTP challenge with a dev code', () {
      final challenge = OtpChallenge.fromJson({
        'challenge_id': 'abc',
        'phone': '+919000000001',
        'expires_in': 300,
        'delivery': 'development',
        'dev_otp': '123456',
      });
      expect(challenge.devOtp, '123456');
      expect(challenge.expiresIn, 300);
    });

    test('parses realtime envelopes', () {
      final event = RealtimeEvent.fromJson({
        'type': 'ride.assigned',
        'entity_id': 'ride-1',
        'event_id': 7,
        'payload': {'status': 'assigned'},
      });
      expect(event.type, 'ride.assigned');
      expect(event.eventId, 7);
      expect(event.payload['status'], 'assigned');
    });
  });

  test('humanize converts machine codes', () {
    expect(humanize('in_progress'), 'In Progress');
    expect(humanize('power_pass'), 'Power Pass');
  });
}
