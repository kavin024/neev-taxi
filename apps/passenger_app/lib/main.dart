import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import 'screens/login_screen.dart';
import 'screens/root_shell.dart';
import 'state/passenger_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = PassengerState();
  runApp(NeevPassengerApp(state: state));
  state.bootstrap();
}

class NeevPassengerApp extends StatefulWidget {
  const NeevPassengerApp({super.key, required this.state});
  final PassengerState state;

  @override
  State<NeevPassengerApp> createState() => _NeevPassengerAppState();
}

class _NeevPassengerAppState extends State<NeevPassengerApp> {
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
    return MaterialApp(
      title: 'Neev Ride',
      debugShowCheckedModeBanner: false,
      theme: NeevTheme.build(),
      home: !widget.state.ready
          ? const _SplashScreen()
          : widget.state.signedIn
              ? RootShell(state: widget.state)
              : LoginScreen(state: widget.state),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeevColors.greenDeep,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NeevLogo(size: 60, light: true, subtitle: 'RIDE'),
            const SizedBox(height: 28),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Opening Neev…',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
