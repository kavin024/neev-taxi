import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/captain_state.dart';

class CaptainLoginScreen extends StatefulWidget {
  const CaptainLoginScreen({super.key, required this.state});
  final CaptainState state;

  @override
  State<CaptainLoginScreen> createState() => _CaptainLoginScreenState();
}

class _CaptainLoginScreenState extends State<CaptainLoginScreen> {
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

  String get _phoneValue {
    final raw = _phone.text.replaceAll(RegExp(r'[^0-9+]'), '');
    if (raw.startsWith('+')) return raw;
    if (raw.length == 10) return '+91$raw';
    return raw;
  }

  Future<void> _request() async {
    if (_phoneValue.length < 10) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      final challenge = await widget.state.api.requestOtp(_phoneValue, 'captain');
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
      setState(() => _error = 'Enter the code from your messages.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final result = await widget.state.api.verifyOtp(
        _challenge?.phone ?? _phoneValue,
        _code.text.trim(),
        'captain',
      );
      await widget.state.adoptSignIn(result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _demo({bool onboarded = true}) {
    setState(() {
      _phone.text = onboarded ? '+919000000011' : '+919000000099';
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
          final form = _form(context);
          if (!wide) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NeevLogo(size: 42, subtitle: 'CAPTAIN'),
                    const SizedBox(height: 30),
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
                            const NeevLogo(size: 46, subtitle: 'CAPTAIN'),
                            const SizedBox(height: 38),
                            form,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(flex: 6, child: _CaptainPanel(onDemo: _demo)),
            ],
          );
        },
      ),
    );
  }

  Widget _form(BuildContext context) {
    final otp = _challenge != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          otp ? 'Captain verification' : 'Drive with Neev.',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 10),
        Text(
          otp
              ? 'Enter the 6-digit code sent to ${_challenge!.phone}.'
              : 'Sign in to manage your availability, offers and earnings. New captains complete verification before going online.',
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.5,
            color: NeevColors.muted,
          ),
        ),
        const SizedBox(height: 26),
        if (!otp) ...[
          NeevField(
            label: 'Captain phone number',
            controller: _phone,
            hint: '+91 90000 00011',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            onSubmitted: (_) => _request(),
          ),
          const SizedBox(height: 16),
          NeevButton(
            label: 'Send code',
            loading: _requesting,
            icon: Icons.arrow_forward,
            onPressed: _request,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => _demo(),
                icon: const Icon(Icons.science_outlined, size: 16),
                label: const Text('Approved demo captain'),
              ),
              TextButton.icon(
                onPressed: () => _demo(onboarded: false),
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: const Text('New captain'),
              ),
            ],
          ),
        ] else ...[
          if (_challenge!.devOtp != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: NeevColors.amberSoft,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: NeevColors.amber.withValues(alpha: 0.6)),
              ),
              child: Text(
                'Development OTP delivery is active. The local API returned ${_challenge!.devOtp} instead of sending an SMS. This is refused in production.',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF7A5400),
                ),
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
          const SizedBox(height: 16),
          NeevButton(
            label: 'Sign in',
            loading: _verifying,
            icon: Icons.login,
            onPressed: _verify,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _challenge = null;
                  _code.clear();
                  _error = null;
                }),
                child: const Text('Change number'),
              ),
              const Spacer(),
              TextButton(
                onPressed: _requesting ? null : _request,
                child: const Text('Resend'),
              ),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          ErrorBanner(message: _error!),
        ],
        const SizedBox(height: 24),
        const Row(
          children: [
            Icon(Icons.verified_user_outlined,
                size: 15, color: NeevColors.green),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Admin-reviewed documents · server-verified trip PIN · transparent earnings',
                style: TextStyle(fontSize: 11.5, color: NeevColors.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CaptainPanel extends StatelessWidget {
  const _CaptainPanel({required this.onDemo});
  final void Function({bool onboarded}) onDemo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NeevColors.ink,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -80,
            top: -60,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: NeevColors.amber.withValues(alpha: 0.18),
                  width: 2,
                ),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: 60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NeevColors.amber.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: NeevColors.amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: NeevColors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'CAPTAIN HUB',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w800,
                      color: NeevColors.amber,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your city.\nYour schedule.',
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
                    'Go online when you want, accept one ride at a time, and see every fare and payout entry. No hidden acceptance games.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HOW VERIFICATION WORKS',
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w800,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Add your profile and vehicle\n'
                        '2. Upload licence, RC, insurance and photo\n'
                        '3. An admin reviews each document\n'
                        '4. Go online only after approval',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.6,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => onDemo(onboarded: false),
                        style: TextButton.styleFrom(
                          foregroundColor: NeevColors.amber,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Preview the new-captain flow'),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  'Independent Neev build · no affiliation with any other ride-hailing company.',
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
