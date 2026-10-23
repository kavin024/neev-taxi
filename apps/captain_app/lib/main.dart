import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state/captain_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = CaptainState();
  runApp(NeevCaptainApp(state: state));
  state.bootstrap();
}

class NeevCaptainApp extends StatefulWidget {
  const NeevCaptainApp({super.key, required this.state});
  final CaptainState state;

  @override
  State<NeevCaptainApp> createState() => _NeevCaptainAppState();
}

class _NeevCaptainAppState extends State<NeevCaptainApp> {
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.state.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final Widget home;
    if (!state.ready) {
      home = const _Splash();
    } else if (!state.signedIn) {
      home = CaptainLoginScreen(state: state);
    } else if (state.approved) {
      home = CaptainShell(state: state);
    } else {
      home = OnboardingScreen(state: state);
    }
    return MaterialApp(
      title: 'Neev Captain',
      debugShowCheckedModeBanner: false,
      theme: NeevTheme.build(),
      home: home,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeevColors.ink,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NeevLogo(size: 60, light: true, subtitle: 'CAPTAIN'),
            const SizedBox(height: 28),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: NeevColors.amber,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Starting Captain Hub…',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
