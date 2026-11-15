import 'package:flutter/material.dart';
import '../api.dart';
import '../config.dart';
import 'feed_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'reels_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _items = <_Nav>[
    _Nav('Home', Icons.home_outlined, Icons.home_rounded),
    _Nav('Reels', Icons.play_circle_outline_rounded, Icons.play_circle_rounded),
    _Nav('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  Widget _page(int i) {
    switch (i) {
      case 0:
        return const FeedScreen();
      case 1:
        return _index == 1 ? const ReelsScreen() : const SizedBox.shrink();
      default:
        return const ProfileScreen();
    }
  }

  Future<void> _logout() async {
    await Api.post('users/logout', {});
    await Api.saveToken(null);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final body = IndexedStack(
      index: _index,
      children: [for (int i = 0; i < _items.length; i++) _page(i)],
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: Colors.white,
              selectedIndex: _index,
              extended: MediaQuery.of(context).size.width >= 1200,
              onDestinationSelected: (i) => setState(() => _index = i),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(AppConfig.appName,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary)),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: IconButton(
                        tooltip: 'Log out', onPressed: _logout, icon: const Icon(Icons.logout_rounded)),
                  ),
                ),
              ),
              destinations: [
                for (final n in _items)
                  NavigationRailDestination(
                      icon: Icon(n.icon), selectedIcon: Icon(n.activeIcon), label: Text(n.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final n in _items)
            NavigationDestination(icon: Icon(n.icon), selectedIcon: Icon(n.activeIcon), label: n.label),
        ],
      ),
    );
  }
}

class _Nav {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _Nav(this.label, this.icon, this.activeIcon);
}
