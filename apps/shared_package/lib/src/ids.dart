import 'dart:math';

final _random = Random.secure();

/// Client-generated idempotency key. The backend uses this to guarantee that a
/// retried booking or payment never creates a duplicate.
String newRequestKey(String prefix) {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final entropy = List.generate(4, (_) => _random.nextInt(1 << 32))
      .map((n) => n.toRadixString(36))
      .join();
  return '$prefix-$time-$entropy';
}
