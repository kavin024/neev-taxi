import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neev_captain/main.dart';
import 'package:neev_captain/state/captain_state.dart';
import 'package:neev_shared/neev_shared.dart';

void main() {
  testWidgets('shows the captain splash before bootstrap completes',
      (tester) async {
    final state = CaptainState();
    await tester.pumpWidget(NeevCaptainApp(state: state));
    expect(find.text('Starting Captain Hub…'), findsOneWidget);
  });

  testWidgets('shows captain phone sign-in when signed out', (tester) async {
    final state = CaptainState()..ready = true;
    await tester.pumpWidget(NeevCaptainApp(state: state));
    await tester.pumpAndSettle();
    expect(find.textContaining('Drive with Neev'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    expect(find.text('Approved demo captain'), findsOneWidget);
  });

  testWidgets('status pill renders human-readable states', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NeevTheme.build(),
        home: const Scaffold(
          body: Column(
            children: [
              StatusPill(status: 'captain_arriving'),
              StatusPill(status: 'approved'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Captain Arriving'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
  });
}
