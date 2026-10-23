import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/passenger_state.dart';
import 'notifications_screen.dart';
import 'power_pass_screen.dart';
import 'saved_places_screen.dart';
import 'support_screen.dart';
import 'trusted_contacts_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.state});
  final PassengerState state;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _wallet;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await widget.state.api.passengerProfile();
      final wallet = await widget.state.api.wallet();
      if (mounted) {
        setState(() {
          _profile = profile;
          _wallet = wallet;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editProfile() async {
    final passenger = _profile?['passenger'] as Map<String, dynamic>? ?? {};
    final name = TextEditingController(
      text: (_profile?['name'] ?? passenger['name'] ?? '').toString(),
    );
    final email =
        TextEditingController(text: (passenger['email'] ?? '').toString());
    final area =
        TextEditingController(text: (passenger['home_area'] ?? '').toString());
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: area,
                decoration: const InputDecoration(
                  labelText: 'Home area',
                  hintText: 'Indiranagar, Bengaluru',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      try {
        await widget.state.api.updatePassengerProfile({
          'name': name.text.trim(),
          if (email.text.trim().isNotEmpty) 'email': email.text.trim(),
          if (area.text.trim().isNotEmpty) 'home_area': area.text.trim(),
        });
        final me = await widget.state.api.me();
        widget.state.user = me;
        await _load();
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        }
      }
    }
    name.dispose();
    email.dispose();
    area.dispose();
  }

  Future<void> _topUp() async {
    const amount = 20000;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Top up wallet'),
        content: Text(
          'Add ${money(amount)} to your Neev wallet using the sandbox payment adapter? No real money moves in this build.',
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Top up'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final payment = await widget.state.api.walletTopup(
        amount,
        newRequestKey('topup'),
      );
      final paymentId = (payment['id'] ?? '').toString();
      await widget.state.api.confirmSandbox(
        paymentId,
        'succeeded',
        newRequestKey('confirm'),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sandbox wallet top-up captured.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'This revokes all refresh tokens for your account on the server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.state.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.state.user;
    final passenger = _profile?['passenger'] as Map<String, dynamic>? ?? {};
    final walletBalance =
        (_wallet?['balance_paise'] as num?)?.toInt() ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
        children: [
          Text('Account', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          NeevCard(
            child: Row(
              children: [
                NeevAvatar(name: user?.name ?? 'Neev rider', size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Neev rider',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        maskPhone(user?.phone ?? ''),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: NeevColors.muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: NeevColors.amber),
                          const SizedBox(width: 2),
                          Text(
                            passenger['rating'] == null
                                ? 'New rider'
                                : '${passenger['rating']} · ${passenger['total_rides'] ?? 0} rides',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: NeevColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: _editProfile,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          NeevCard(
            color: NeevColors.greenDeep,
            borderColor: NeevColors.greenDeep,
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined,
                      color: Colors.white),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEEV WALLET',
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w800,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _loading ? '…' : money(walletBalance),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Sandbox top-ups only',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _topUp,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text('Top up'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(message: _error!, onRetry: _load),
          ],
          const SizedBox(height: 20),
          const _GroupLabel('RIDING'),
          const SizedBox(height: 8),
          NeevCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.bolt_outlined,
                  title: 'Power Pass',
                  subtitle: 'Ride bundles and discounts',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PowerPassScreen(state: widget.state),
                    ),
                  ),
                ),
                const Divider(indent: 54),
                _MenuTile(
                  icon: Icons.bookmark_border,
                  title: 'Saved places',
                  subtitle: 'Home, work and frequent stops',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SavedPlacesScreen(state: widget.state),
                    ),
                  ),
                ),
                const Divider(indent: 54),
                _MenuTile(
                  icon: Icons.people_outline,
                  title: 'Trusted contacts',
                  subtitle: 'People notified on SOS',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrustedContactsScreen(state: widget.state),
                    ),
                  ),
                ),
                const Divider(indent: 54),
                _MenuTile(
                  icon: Icons.notifications_none,
                  title: 'Notifications',
                  subtitle: 'Trip, payment and safety updates',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          NotificationsScreen(state: widget.state),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _GroupLabel('HELP & TRUST'),
          const SizedBox(height: 8),
          NeevCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.support_agent_outlined,
                  title: 'Support tickets',
                  subtitle: 'Talk to the team, review replies',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupportScreen(state: widget.state),
                    ),
                  ),
                ),
                const Divider(indent: 54),
                _MenuTile(
                  icon: Icons.shield_outlined,
                  title: 'Safety in this build',
                  subtitle: 'What SOS does and does not do',
                  onTap: () => _showSafety(context),
                ),
                const Divider(indent: 54),
                const _MenuTile(
                  icon: Icons.info_outline,
                  title: 'About Neev',
                  subtitle: 'Independent build · v0.1.0',
                  onTap: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          NeevButton(
            label: 'Sign out',
            tone: NeevButtonTone.outline,
            icon: Icons.logout,
            onPressed: _signOut,
          ),
          const SizedBox(height: 14),
          const Text(
            'Neev is an original, independent implementation for a ride-booking pilot. It is not affiliated with any other ride-hailing company.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: NeevColors.muted),
          ),
        ],
      ),
    );
  }

  void _showSafety(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Safety features'),
        content: const SingleChildScrollView(
          child: Text(
            '• 4-digit trip PIN verified on the server before the trip starts.\n'
            '• Live location visible only to the passenger and assigned captain.\n'
            '• Expiring, unlisted share links for someone you trust.\n'
            '• Hold-to-activate SOS creates an incident and queues SMS to trusted contacts.\n\n'
            'Not included: emergency-service dispatch, a staffed 24×7 safety desk, and in-ride insurance. In a real emergency call 112.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: NeevColors.cream,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: NeevColors.green),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: NeevColors.muted),
      ),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right, size: 19, color: NeevColors.muted),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w800,
        color: NeevColors.muted,
      ),
    );
  }
}
