import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neev_passenger/main.dart';
import 'package:neev_passenger/state/passenger_state.dart';
import 'package:neev_shared/neev_shared.dart';

void main() {
  testWidgets('shows the branded splash before bootstrap completes',
      (tester) async {
    final state = PassengerState();
    await tester.pumpWidget(NeevPassengerApp(state: state));
    expect(find.text('Opening Neev…'), findsOneWidget);
  });

  testWidgets('shows phone sign-in when signed out', (tester) async {
    final state = PassengerState()..ready = true;
    await tester.pumpWidget(NeevPassengerApp(state: state));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your city'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    expect(find.text('Use the seeded demo passenger'), findsOneWidget);
  });

  testWidgets('renders the vector map with pickup and drop markers',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NeevTheme.build(),
        home: const Scaffold(
          body: NeevMap(
            pickup: LatLng(12.9719, 77.6412),
            drop: LatLng(12.9352, 77.6245),
            route: [
              LatLng(12.9719, 77.6412),
              LatLng(12.9352, 77.6245),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(NeevMap), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Drop'), findsOneWidget);
  });
}
