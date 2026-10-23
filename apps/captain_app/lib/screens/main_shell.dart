import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/captain_state.dart';
import 'earnings_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'trips_screen.dart';

class CaptainShell extends StatefulWidget {
  const CaptainShell({super.key, required this.state});
  final CaptainState state;

  @override
  State<CaptainShell> createState() => _CaptainShellState();
}

class _CaptainShellState extends State<CaptainShell> {
  int _index = 0;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final pages = [
      CaptainHomeScreen(state: widget.state),
      CaptainTripsScreen(state: widget.state),
      EarningsScreen(state: widget.state),
      CaptainProfileScreen(state: widget.state),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                Container(
                  width: 232,
                  decoration: const BoxDecoration(
                    color: NeevColors.surface,
                    border: Border(right: BorderSide(color: NeevColors.line)),
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(22, 24, 20, 26),
                          child: NeevLogo(size: 38, subtitle: 'CAPTAIN'),
                        ),
                        _Destination(
                          icon: Icons.space_dashboard_outlined,
                          selectedIcon: Icons.space_dashboard,
                          label: 'Home',
                          selected: _index == 0,
                          onTap: () => _select(0),
                        ),
                        _Destination(
                          icon: Icons.route_outlined,
                          selectedIcon: Icons.route,
                          label: 'Trips',
                          selected: _index == 1,
                          onTap: () => _select(1),
                        ),
                        _Destination(
                          icon: Icons.payments_outlined,
                          selectedIcon: Icons.payments,
                          label: 'Earnings',
                          selected: _index == 2,
                          onTap: () => _select(2),
                        ),
                        _Destination(
                          icon: Icons.person_outline,
                          selectedIcon: Icons.person,
                          label: 'Profile',
                          selected: _index == 3,
                          onTap: () => _select(3),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: NeevColors.ink,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CAPTAIN HUB',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: NeevColors.amber,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.state.isOnline
                                      ? 'Online · receiving offers'
                                      : 'Offline · no offers',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SafeArea(
                    child: IndexedStack(index: _index, children: pages),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const NeevLogo(size: 30, showWordmark: false),
                const SizedBox(width: 9),
                Text(
                  ['Captain', 'Trips', 'Earnings', 'Profile'][_index],
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () async {
                  await widget.state.refreshProfile();
                  await widget.state.refreshDashboard();
                  await widget.state.refreshOffers();
                },
                icon: const Icon(Icons.refresh),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => _select(3),
                  child: NeevAvatar(name: widget.state.name, size: 32),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: IndexedStack(index: _index, children: pages),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.route_outlined),
                selectedIcon: Icon(Icons.route),
                label: 'Trips',
              ),
              NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments),
                label: 'Earnings',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? NeevColors.greenSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 21,
                  color: selected ? NeevColors.green : NeevColors.muted,
                ),
                const SizedBox(width: 11),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? NeevColors.greenDeep : NeevColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
