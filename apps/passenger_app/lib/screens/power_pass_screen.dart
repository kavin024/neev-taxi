import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/passenger_state.dart';

class PowerPassScreen extends StatefulWidget {
  const PowerPassScreen({super.key, required this.state});
  final PassengerState state;

  @override
  State<PowerPassScreen> createState() => _PowerPassScreenState();
}

class _PowerPassScreenState extends State<PowerPassScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.state.api.powerPass();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy(Map<String, dynamic> plan) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.state.api.purchasePowerPass(
        (plan['id'] ?? '').toString(),
        newRequestKey('pass'),
      );
      final paymentId = (result['payment_id'] ?? '').toString();
      final status = (result['status'] ?? '').toString();
      if (status == 'created' && result['sandbox'] == true) {
        if (!mounted) return;
        final outcome = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sandbox Power Pass payment'),
            content: Text(
              'This activates the pass through the sandbox payment adapter only. No real money moves.\n\n'
              'Amount: ${result['amount_display'] ?? money((plan['price_paise'] as num?)?.toInt() ?? 0)}',
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'failed'),
                child: const Text('Simulate failure'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, 'succeeded'),
                child: const Text('Simulate success'),
              ),
            ],
          ),
        );
        if (outcome == null) return;
        await widget.state.api.confirmSandbox(
          paymentId,
          outcome,
          newRequestKey('confirm'),
        );
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Power Pass status refreshed.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _data?['active'] as Map<String, dynamic>?;
    final plans =
        (_data?['plans'] as List? ?? []).cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(title: const Text('Neev Power Pass')),
      body: _loading
          ? const LoadingState()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
                children: [
                  if (_error != null) ...[
                    ErrorBanner(message: _error!, onRetry: _load),
                    const SizedBox(height: 14),
                  ],
                  if (active != null)
                    NeevCard(
                      color: NeevColors.greenDeep,
                      borderColor: NeevColors.greenDeep,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded,
                                  color: NeevColors.amber, size: 26),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'POWER PASS ACTIVE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              Text(
                                '${active['rides_remaining']} rides left',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Expires ${dateLabel(DateTime.tryParse((active['expires_at'] ?? '').toString()))}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Eligible rides automatically apply the pass discount at quote time.',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const NeevCard(
                      child: Text(
                        'No active pass. A Power Pass applies a capped discount to eligible rides until its ride limit or expiry.',
                        style: TextStyle(fontSize: 13, height: 1.45),
                      ),
                    ),
                  const SizedBox(height: 22),
                  Text('Available plans',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  ...plans.map(
                    (plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: NeevCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (plan['name'] ?? 'Power Pass').toString(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  money(
                                      (plan['price_paise'] as num?)?.toInt() ??
                                          0),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (plan['description'] ?? '').toString(),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: NeevColors.muted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _Stat(
                                  icon: Icons.percent,
                                  label:
                                      '${plan['discount_pct']}% off up to ${money((plan['max_discount_paise'] as num?)?.toInt() ?? 0)}',
                                ),
                                _Stat(
                                  icon: Icons.confirmation_number_outlined,
                                  label: '${plan['ride_limit']} rides',
                                ),
                                _Stat(
                                  icon: Icons.event_available_outlined,
                                  label: '${plan['validity_days']} days',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            NeevButton(
                              label: 'Buy with sandbox payment',
                              tone: NeevButtonTone.outline,
                              loading: _busy,
                              onPressed: active != null ? null : () => _buy(plan),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Power Pass purchases in this build use the sandbox payment adapter. Production activation requires a configured payment provider.',
                    style: TextStyle(fontSize: 11, color: NeevColors.muted),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: NeevColors.cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NeevColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: NeevColors.green),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
