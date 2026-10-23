import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/passenger_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});
  final PassengerState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  OtpChallenge? _challenge;
  bool _requesting = false;
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _normalizedPhone {
    final raw = _phone.text.replaceAll(RegExp(r'[^0-9+]'), '');
    if (raw.startsWith('+')) return raw;
    if (raw.length == 10) return '+91$raw';
    return raw;
  }

  Future<void> _requestOtp() async {
    final phone = _normalizedPhone;
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      final challenge = await widget.state.api.requestOtp(phone, 'passenger');
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        if (challenge.devOtp != null) _code.text = challenge.devOtp!;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.trim().length < 4) {
      setState(() => _error = 'Enter the code sent to your phone.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final result = await widget.state.api.verifyOtp(
        _challenge?.phone ?? _normalizedPhone,
        _code.text.trim(),
        'passenger',
      );
      await widget.state.adoptSignIn(result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _useDemoAccount() {
    setState(() {
      _phone.text = '+919000000001';
      _challenge = null;
      _code.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final form = _buildForm(context);
          if (!wide) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NeevLogo(size: 42, subtitle: 'RIDE'),
                    const SizedBox(height: 34),
                    form,
                  ],
                ),
              ),
            );
          }
          return Row(
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  color: NeevColors.cream,
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 410),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const NeevLogo(size: 46, subtitle: 'RIDE'),
                            const SizedBox(height: 38),
                            form,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: _BrandPanel(state: widget.state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final otpStep = _challenge != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          otpStep ? 'Check your messages' : 'Your city, one tap away.',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 10),
        Text(
          otpStep
              ? 'We sent a 6-digit code to ${_challenge!.phone}. It expires in ${_challenge!.expiresIn ~/ 60} minutes.'
              : 'Sign in with your phone number. New riders get an account automatically.',
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.5,
            color: NeevColors.muted,
          ),
        ),
        const SizedBox(height: 28),
        if (!otpStep) ...[
          NeevField(
            label: 'Phone number',
            controller: _phone,
            hint: '+91 90000 00001',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            onSubmitted: (_) => _requestOtp(),
          ),
          const SizedBox(height: 18),
          NeevButton(
            label: 'Send code',
            loading: _requesting,
            onPressed: _requestOtp,
            icon: Icons.arrow_forward,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _useDemoAccount,
            icon: const Icon(Icons.science_outlined, size: 16),
            label: const Text('Use the seeded demo passenger'),
          ),
        ] else ...[
          if (_challenge!.devOtp != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: NeevColors.amberSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: NeevColors.amber.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.science_outlined,
                      size: 17, color: Color(0xFF7A5400)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Development OTP delivery is active. The code ${_challenge!.devOtp} was returned by the local API instead of an SMS. This is disabled in production.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Color(0xFF7A5400),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          NeevField(
            label: '6-digit code',
            controller: _code,
            hint: '123456',
            keyboardType: TextInputType.number,
            maxLength: 6,
            prefixIcon: Icons.password_outlined,
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 18),
          NeevButton(
            label: 'Continue',
            loading: _verifying,
            onPressed: _verify,
            icon: Icons.login,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: _requesting
                    ? null
                    : () => setState(() {
                          _challenge = null;
                          _code.clear();
                          _error = null;
                        }),
                child: const Text('Change number'),
              ),
              const Spacer(),
              TextButton(
                onPressed: _requesting ? null : _requestOtp,
                child: Text(_requesting ? 'Sending…' : 'Resend code'),
              ),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          ErrorBanner(message: _error!),
        ],
        const SizedBox(height: 26),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: const [
            _TrustChip(icon: Icons.shield_outlined, label: 'Server-verified PIN'),
            _TrustChip(icon: Icons.visibility_outlined, label: 'Live trip sharing'),
            _TrustChip(icon: Icons.receipt_long_outlined, label: 'Cash or sandbox pay'),
          ],
        ),
      ],
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: NeevColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NeevColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: NeevColors.green),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: NeevColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.state});
  final PassengerState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NeevColors.greenDeep,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _PanelPatternPainter()),
          Padding(
            padding: const EdgeInsets.all(52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'INDEPENDENT • BENGALURU PILOT',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'City rides,\nwithout the noise.',
                  style: TextStyle(
                    fontSize: 44,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.8,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 390,
                  child: Text(
                    'Bike, auto and cab in one calm app. Watch your captain approach, start with a PIN, and share the live trip with someone you trust.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    height: 210,
                    color: const Color(0xFFEDEBE2),
                    child: NeevMap(
                      height: 210,
                      borderRadius: 0,
                      providerLabel: state.isDemoMap
                          ? 'Demo map · real coordinates'
                          : 'Development map',
                      route: const [
                        LatLng(12.9719, 77.6412),
                        LatLng(12.9698, 77.6350),
                        LatLng(12.9650, 77.6320),
                        LatLng(12.9600, 77.6355),
                        LatLng(12.9552, 77.6410),
                      ],
                      pickup: const LatLng(12.9719, 77.6412),
                      drop: const LatLng(12.9552, 77.6410),
                      captain: const LatLng(12.9600, 77.6355),
                      showLegend: false,
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Neev is an original, independent build. It is not affiliated with any other ride-hailing company.',
                  style: TextStyle(fontSize: 11.5, color: Colors.white38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var i = 0; i < 9; i++) {
      final radius = size.width * (0.12 + i * 0.09);
      canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.08), radius, paint);
    }
    final accent = Paint()
      ..color = NeevColors.amber.withValues(alpha: 0.35)
      ..strokeWidth = 2;
    final path = Path()
      ..moveTo(size.width * 0.06, size.height * 0.82)
      ..cubicTo(size.width * 0.25, size.height * 0.7, size.width * 0.1,
          size.height * 0.5, size.width * 0.35, size.height * 0.42);
    canvas.drawPath(path, accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
