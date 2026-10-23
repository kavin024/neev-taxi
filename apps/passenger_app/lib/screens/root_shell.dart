import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/passenger_state.dart';
import 'account_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key, required this.state});
  final PassengerState state;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(state: widget.state, onSeeActivity: () => _select(1)),
      HistoryScreen(state: widget.state),
      AccountScreen(state: widget.state),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
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
                          child: NeevLogo(size: 38, subtitle: 'RIDE'),
                        ),
                        _SideDestination(
                          icon: Icons.explore_outlined,
                          selectedIcon: Icons.explore,
                          label: 'Ride',
                          selected: _index == 0,
                          onTap: () => _select(0),
                        ),
                        _SideDestination(
                          icon: Icons.receipt_long_outlined,
                          selectedIcon: Icons.receipt_long,
                          label: 'Activity',
                          selected: _index == 1,
                          onTap: () => _select(1),
                        ),
                        _SideDestination(
                          icon: Icons.person_outline,
                          selectedIcon: Icons.person,
                          label: 'Account',
                          selected: _index == 2,
                          onTap: () => _select(2),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: NeevColors.cream,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: NeevColors.line),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DEVELOPMENT BUILD',
                                      style: TextStyle(
                                        fontSize: 9,
                                        letterSpacing: 1.1,
                                        fontWeight: FontWeight.w800,
                                        color: NeevColors.muted,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Demo maps · sandbox payments',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: NeevColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'neev · v0.1.0',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: NeevColors.muted,
                                ),
                              ),
                            ],
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
                  ['Neev', 'Your rides', 'Account'][_index],
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(state: widget.state),
                  ),
                ),
                icon: const Icon(Icons.notifications_none),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => _select(2),
                  child: NeevAvatar(
                    name: widget.state.user?.name ?? 'Neev rider',
                    size: 32,
                  ),
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
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Ride',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Activity',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Account',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SideDestination extends StatelessWidget {
  const _SideDestination({
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
