# Neev Ride (passenger)

Flutter passenger client for the Neev mobility platform. It talks to the FastAPI
backend through `neev_shared` and implements the full rider journey: OTP login,
place picking, category selection and quotes, booking, live trip tracking, PIN
handoff, payment, ratings, Power Pass, safety and support.

## Run

```bash
flutter pub get
flutter run -d chrome
# or against another API:
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

The backend must be running (see the root README). Development OTP is `123456` and
seeded passengers are `+919000000001` and `+919000000002`.

## Screens

`lib/screens/` contains the login, home, place picker, ride, history, Power Pass,
account, saved places, notifications, trusted contacts and support screens.
`lib/state/passenger_state.dart` owns session state and API orchestration using the
shared `ApiClient` and `RealtimeClient`. Polling/WebSocket resynchronisation is
handled through the shared package, with the REST API as the source of truth.

## Checks

```bash
flutter analyze
flutter test
```

`API_BASE_URL` defaults to `http://127.0.0.1:8000`. Builds are plain Flutter; no
secrets are embedded client-side.
