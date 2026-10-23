import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/captain_state.dart';
import 'onboarding_screen.dart';
import 'support_screen.dart';

class CaptainProfileScreen extends StatelessWidget {
  const CaptainProfileScreen({super.key, required this.state});
  final CaptainState state;

  Future<void> _edit(BuildContext context) async {
    final name = TextEditingController(text: state.name);
    final email = TextEditingController();
    final payout = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit captain profile'),
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
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: payout,
                decoration: const InputDecoration(
                  labelText: 'Payout UPI ID',
                  hintText: 'captain@bank',
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
    if (ok == true) {
      try {
        await state.api.updateCaptainProfile({
          if (name.text.trim().isNotEmpty) 'name': name.text.trim(),
          if (email.text.trim().isNotEmpty) 'email': email.text.trim(),
          if (payout.text.trim().isNotEmpty) 'payout_upi': payout.text.trim(),
        });
        await state.refreshProfile();
      } on ApiException catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        }
      }
    }
    name.dispose();
    email.dispose();
    payout.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final profile = state.profile;
        final docs = profile?.documents ?? const [];
        final vehicles = profile?.vehicles ?? const [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
          children: [
            Text('Captain profile',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 14),
            NeevCard(
              child: Row(
                children: [
                  NeevAvatar(name: state.name, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          maskPhone(state.user?.phone ?? ''),
                          style: const TextStyle(
                            fontSize: 12,
                            color: NeevColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            StatusPill(
                              status: profile?.verificationStatus ?? 'draft',
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.star_rounded,
                                size: 14, color: NeevColors.amber),
                            Text(
                              profile?.rating?.toStringAsFixed(1) ?? '—',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              ' · ${profile?.totalTrips ?? 0} trips',
                              style: const TextStyle(
                                fontSize: 11,
                                color: NeevColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.edit_outlined, size: 19),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            NeevCard(
              color: NeevColors.cream,
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined,
                      color: NeevColors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.approved
                              ? 'Approved captain'
                              : 'Verification ${humanize(profile?.verificationStatus ?? 'draft')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          state.approved
                              ? 'Document review is complete. Keep documents current.'
                              : (profile?.rejectionReason?.isNotEmpty == true
                                  ? 'Rejected: ${profile!.rejectionReason}'
                                  : 'An admin reviews every document before offers are enabled.'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: NeevColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OnboardingScreen(state: state),
                      ),
                    ),
                    child: const Text('Manage'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _Label('VEHICLES'),
            const SizedBox(height: 8),
            if (vehicles.isEmpty)
              const NeevCard(
                child: Text('No vehicle on file.',
                    style: TextStyle(fontSize: 12.5)),
              )
            else
              ...vehicles.map(
                (vehicle) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NeevCard(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        const Icon(Icons.two_wheeler,
                            color: NeevColors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (vehicle['reg_number'] ?? '').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${humanize((vehicle['category'] ?? '').toString())} · ${vehicle['make_model']}${vehicle['color'] == null ? '' : ' · ${vehicle['color']}'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: NeevColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusPill(
                          status: vehicle['is_active'] == true
                              ? 'active'
                              : 'inactive',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            const _Label('DOCUMENTS'),
            const SizedBox(height: 8),
            if (docs.isEmpty)
              const NeevCard(
                child: Text('No documents uploaded.',
                    style: TextStyle(fontSize: 12.5)),
              )
            else
              ...docs.map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NeevCard(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        Icon(
                          doc['status'] == 'approved'
                              ? Icons.check_circle_outline
                              : doc['status'] == 'rejected'
                                  ? Icons.error_outline
                                  : Icons.description_outlined,
                          size: 19,
                          color: doc['status'] == 'approved'
                              ? NeevColors.green
                              : doc['status'] == 'rejected'
                                  ? NeevColors.danger
                                  : NeevColors.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                humanize((doc['doc_type'] ?? '').toString()),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              Text(
                                '${(doc['original_filename'] ?? '').toString()} · ${((doc['size_bytes'] as num?)?.toInt() ?? 0) ~/ 1024} KB',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: NeevColors.muted,
                                ),
                              ),
                              if ((doc['rejection_reason'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text(
                                  (doc['rejection_reason'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: NeevColors.danger,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        StatusPill(
                          status: (doc['status'] ?? 'pending').toString(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            const _Label('ACCOUNT & HELP'),
            const SizedBox(height: 8),
            NeevCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.support_agent_outlined,
                        color: NeevColors.green),
                    title: const Text('Support tickets'),
                    subtitle: const Text(
                      'Payouts, trips and account review',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CaptainSupportScreen(state: state),
                      ),
                    ),
                  ),
                  const Divider(indent: 54),
                  ListTile(
                    leading: const Icon(Icons.science_outlined,
                        color: NeevColors.green),
                    title: const Text('Development settings'),
                    subtitle: Text(
                      'GPS simulation: ${state.gpsSimulation ? 'enabled' : 'disabled'} · map: ${state.config?.mapProvider ?? '—'} · payments: ${state.config?.sandboxPayments == true ? 'sandbox' : 'provider'}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const Divider(indent: 54),
                  const ListTile(
                    leading: Icon(Icons.info_outline, color: NeevColors.green),
                    title: Text('Neev Captain'),
                    subtitle: Text('v0.1.0 · independent build',
                        style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            NeevButton(
              label: 'Sign out',
              tone: NeevButtonTone.outline,
              icon: Icons.logout,
              onPressed: state.signOut,
            ),
            const SizedBox(height: 14),
            const Text(
              'Neev is an original, independent implementation. It is not affiliated with any other ride-hailing company.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: NeevColors.muted),
            ),
          ],
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9.5,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w800,
        color: NeevColors.muted,
      ),
    );
  }
}
