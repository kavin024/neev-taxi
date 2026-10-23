import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/captain_state.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key, required this.state});
  final CaptainState state;

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _requesting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.state.api.captainEarnings();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _payout() async {
    final available = (_data?['available_paise'] as num?)?.toInt() ?? 0;
    if (available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available balance to withdraw.')),
      );
      return;
    }
    final amount = TextEditingController(
      text: (available / 100).toStringAsFixed(0),
    );
    final destination = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request payout'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available: ${money(available)}. Payouts are manually reviewed by an admin in this build; a request is not a completed transfer.',
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: destination,
                decoration: const InputDecoration(
                  labelText: 'UPI ID',
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
            child: const Text('Request'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _requesting = true);
      try {
        await widget.state.api.requestPayout(
          amountPaise:
              ((double.tryParse(amount.text.trim()) ?? 0) * 100).round(),
          destination: destination.text.trim(),
        );
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payout requested. An admin will review it.'),
            ),
          );
        }
      } on ApiException catch (error) {
        if (mounted) setState(() => _error = error.message);
      } finally {
        if (mounted) setState(() => _requesting = false);
      }
    }
    amount.dispose();
    destination.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trips =
        (_data?['trips'] as List? ?? []).cast<Map<String, dynamic>>();
    final payouts =
        (_data?['payouts'] as List? ?? []).cast<Map<String, dynamic>>();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Earnings',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 3),
                    const Text(
                      'Net of platform commission, recorded per completed trip.',
                      style: TextStyle(fontSize: 12.5, color: NeevColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading && _data == null)
            const Padding(
              padding: EdgeInsets.only(top: 70),
              child: LoadingState(label: 'Calculating earnings…'),
            )
          else ...[
            if (_error != null) ...[
              ErrorBanner(message: _error!, onRetry: _load),
              const SizedBox(height: 12),
            ],
            NeevCard(
              color: NeevColors.greenDeep,
              borderColor: NeevColors.greenDeep,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AVAILABLE FOR PAYOUT',
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (_data?['available_display'] ?? money(0)).toString(),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DarkMetric(
                          label: 'Today',
                          value: (_data?['today_display'] ?? money(0)).toString(),
                        ),
                      ),
                      Expanded(
                        child: _DarkMetric(
                          label: 'This week',
                          value: (_data?['week_display'] ?? money(0)).toString(),
                        ),
                      ),
                      Expanded(
                        child: _DarkMetric(
                          label: 'Lifetime',
                          value:
                              (_data?['lifetime_display'] ?? money(0)).toString(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: NeevColors.amber,
                        foregroundColor: NeevColors.ink,
                      ),
                      onPressed:
                          _requesting ? null : _payout,
                      icon: const Icon(Icons.account_balance_outlined, size: 18),
                      label: Text(
                        _requesting ? 'Requesting…' : 'Request payout',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionHeading(
              title: 'Recent trips',
              subtitle: '${trips.length} completed trips in this statement',
            ),
            const SizedBox(height: 8),
            if (trips.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No completed trips yet',
                message: 'Complete a trip to create a ledger entry.',
              )
            else
              ...trips.map(
                (trip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NeevCard(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 19, color: NeevColors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (trip['fare_display'] ?? '').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${dateTimeLabel(DateTime.tryParse((trip['completed_at'] ?? '').toString()))} · ${humanize((trip['payment_status'] ?? '').toString())}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: NeevColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusPill(
                          status: (trip['payment_status'] ?? '').toString(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            SectionHeading(
              title: 'Payout requests',
              subtitle: 'Admin-reviewed, never auto-approved',
            ),
            const SizedBox(height: 8),
            if (payouts.isEmpty)
              const NeevCard(
                child: Text(
                  'No payout requests yet.',
                  style: TextStyle(fontSize: 12.5, color: NeevColors.muted),
                ),
              )
            else
              ...payouts.map(
                (payout) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NeevCard(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_outlined,
                            size: 19, color: NeevColors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (payout['amount_display'] ?? '').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${(payout['destination_masked'] ?? '').toString()} · ${relativeTime(DateTime.tryParse((payout['requested_at'] ?? '').toString()))}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: NeevColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusPill(
                          status: (payout['status'] ?? 'pending').toString(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              (_data?['platform_commission_note'] ?? '').toString(),
              style: const TextStyle(fontSize: 10.5, color: NeevColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _DarkMetric extends StatelessWidget {
  const _DarkMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 8.5,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
            color: Colors.white38,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
