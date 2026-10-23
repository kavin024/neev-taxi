/// Indian currency, distance, duration and date formatting shared by both apps.
/// Money is always handled as integer paise in the API and only formatted here.
String money(int paise, {bool withDecimals = false}) {
  final negative = paise < 0;
  final value = paise.abs();
  final rupees = value ~/ 100;
  final remainder = value % 100;

  final digits = rupees.toString();
  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }

  final decimals = withDecimals || remainder != 0
      ? '.${remainder.toString().padLeft(2, '0')}'
      : '';
  return '${negative ? '-' : ''}₹$grouped$decimals';
}

String distanceLabel(num meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

String durationLabel(num seconds) {
  if (seconds < 60) return '${seconds.round()} s';
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String dateLabel(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

String dateTimeLabel(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
          ? local.hour - 12
          : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'pm' : 'am';
  return '${dateLabel(local)}, $hour:$minute $suffix';
}

String timeLabel(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
          ? local.hour - 12
          : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour >= 12 ? 'pm' : 'am'}';
}

String relativeTime(DateTime? value) {
  if (value == null) return '';
  final diff = DateTime.now().difference(value.toLocal());
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return dateLabel(value);
}

/// Converts machine codes such as `in_progress` or `power_pass` into
/// human-readable labels, while leaving already-formatted text untouched.
String humanize(String? value) {
  if (value == null || value.isEmpty) return '—';
  final words = value
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'));
  return words
      .map((word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return 'N';
  final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return letters;
}

String maskPhone(String phone) {
  if (phone.length < 4) return phone;
  return '••••${phone.substring(phone.length - 4)}';
}
