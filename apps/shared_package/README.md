# neev_shared

Shared Dart SDK for the Neev passenger and captain apps. It is the single place where
API contracts, realtime behaviour, session storage, design tokens and common widgets
live, so the two clients cannot drift apart.

## Modules

| File | Contents |
| --- | --- |
| `src/api_client.dart` | Typed HTTP client, bearer auth, automatic token refresh, uniform `NeevApiException` with server error codes |
| `src/models.dart` | Ride, trip, offer, quote, captain, passenger, payment, ticket, safety and notification models |
| `src/session.dart` | `SessionStore` backed by `shared_preferences`; persists token pair and user |
| `src/realtime.dart` | Authenticated WebSocket client with heartbeat, reconnect/backoff and event decoding |
| `src/theme.dart` | Neev colour palette, typography and component themes |
| `src/widgets.dart` | Shared logo, buttons, cards, sheets, status chips and empty states |
| `src/format.dart` | Paise → rupee formatting, distance/duration and timestamp helpers |
| `src/ids.dart` | Idempotency key generation |

## Use

Add the path dependency (already present in both apps):

```yaml
dependencies:
  neev_shared:
    path: ../shared_package
```

```dart
import 'package:neev_shared/neev_shared.dart';

final api = ApiClient(baseUrl: const String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
));
```

Money is represented as integer paise in models and converted only for display. The
REST API is authoritative; realtime events are hints and should be followed by a
fetch after reconnect.

## Checks

```bash
flutter pub get
flutter analyze
flutter test
```
