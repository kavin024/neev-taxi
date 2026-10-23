# Neev Captain

Flutter captain client for the Neev mobility platform. It covers onboarding and
document upload, verification status, going on duty, receiving and accepting offers,
arrival, PIN-verified trip start, live location streaming, completion, earnings,
payout requests, ratings and support.

## Run

```bash
flutter pub get
flutter run -d chrome
# or against another API:
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Seeded captains: `+919000000011` (bike), `+919000000012` (auto),
`+919000000013` (cab), OTP `123456`. Development builds auto-approve seeded
documents; the real review flow is exercised through the operations console.

## Structure

- `lib/state/captain_state.dart` — session, offers, active trip and location loop
- `lib/screens/onboarding_screen.dart` — profile, vehicle and document submission,
  including a clearly labelled placeholder-upload path for development
- `lib/screens/home_screen.dart` — duty toggle, offers and earnings summary
- `lib/screens/trip_screen.dart` — arrive, start with rider PIN, navigate, complete

The trip PIN is entered by the captain but verified only on the server; the captain
app never receives the expected PIN.

## Checks

```bash
flutter analyze
flutter test
```
