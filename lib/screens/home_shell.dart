import 'package:flutter/material.dart';
import '../api.dart';
import '../config.dart';
import 'create_post_screen.dart';
import 'feed_screen.dart';
import 'notifications_screen.dart';
import 'chat_list_screen.dart';
import '../chat/chat_service.dart';
import '../session.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'reels_screen.dart';
import 'explore_hub.dart';
import 'settings_screen.dart';
import 'hashtag_screen.dart';
import '../app_only.dart';
import '../install_hint.dart';
import '../links.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    ChatService.instance.connect();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppLinks.openPending(context);
    });
    Session.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  static const _items = <_Nav>[
    _Nav('Home', Icons.home_outlined, Icons.home_rounded),
    _Nav('Reels', Icons.play_circle_outline_rounded, Icons.play_circle_rounded),
    _Nav('Chat', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
    _Nav('Alerts', Icons.notifications_none_rounded, Icons.notifications_rounded),
    _Nav('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  Widget _page(int i) {
    switch (i) {
      case 0:
        return const FeedScreen();
      case 1:
        return _index == 1 ? const ReelsScreen() : const SizedBox.shrink();
      case 2:
        return _index == 2 ? const ChatListScreen() : const SizedBox.shrink();
      case 3:
        return _index == 3 ? const NotificationsScreen() : const SizedBox.shrink();
      default:
        return const ProfileScreen();
    }
  }

  void _create() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));
  }

  Widget? _fab() => (_index == 1 || _index == 2)
      ? null
      : FloatingActionButton(
          onPressed: _create,
          tooltip: 'New post',
          child: const Icon(Icons.add_rounded),
        );

  Future<void> _logout() async {
    await Api.post('users/logout', {});
    ChatService.instance.disconnect();
    Session.clear();
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
      final w = MediaQuery.of(context).size.width;
      final extended = w >= 1100;
      final showRight = w >= 1280;
      final maxW = _index == 1 ? 460.0 : (_index == 2 ? 940.0 : 680.0);
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              extended: extended,
              index: _index,
              items: _items,
              onSelect: (i) => setState(() => _index = i),
              onNewPost: _create,
              onLogout: _logout,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: body,
                ),
              ),
            ),
            if (showRight) const _RightRail(),
          ],
        ),
      );
    }

    return Scaffold(
      floatingActionButton: _fab(),
      body: SafeArea(bottom: false, child: Column(children: [const InstallHint(), Expanded(child: body)])),
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


class _Sidebar extends StatelessWidget {
  final bool extended;
  final int index;
  final List<_Nav> items;
  final ValueChanged<int> onSelect;
  final VoidCallback onNewPost;
  final VoidCallback onLogout;
  const _Sidebar({
    required this.extended,
    required this.index,
    required this.items,
    required this.onSelect,
    required this.onNewPost,
    required this.onLogout,
  });

  Widget _item(BuildContext context,
      {required IconData icon, required String label, required bool selected, required VoidCallback onTap}) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: extended ? '' : label,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 0),
            decoration: BoxDecoration(
              color: selected ? cs.primaryContainer.withValues(alpha: 0.6) : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 26),
                if (extended) ...[
                  const SizedBox(width: 14),
                  Text(label,
                      style: TextStyle(
                          fontSize: 16, color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: extended ? 260 : 84,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE6E8F0))),
      ),
      padding: EdgeInsets.symmetric(horizontal: extended ? 16 : 10, vertical: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 18, left: 4),
          child: Row(mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.diversity_3_rounded, color: Colors.white, size: 22),
            ),
            if (extended) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(AppConfig.appName,
                    maxLines: 2,
                    style: TextStyle(fontSize: 16, height: 1.15, fontWeight: FontWeight.w800, color: cs.primary)),
              ),
            ],
          ]),
        ),
        for (int i = 0; i < items.length; i++)
          _item(context,
              icon: i == index ? items[i].activeIcon : items[i].icon,
              label: items[i].label,
              selected: i == index,
              onTap: () => onSelect(i)),
        const Divider(height: 24),
        _item(context,
            icon: Icons.apps_rounded,
            label: 'Explore',
            selected: false,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreHub()))),
        _item(context,
            icon: Icons.settings_outlined,
            label: 'Settings',
            selected: false,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        const SizedBox(height: 14),
        extended
            ? FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: onNewPost,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New post'))
            : IconButton.filled(onPressed: onNewPost, tooltip: 'New post', icon: const Icon(Icons.add_rounded)),
        const Spacer(),
        if (extended && AppOnly.hasStoreLink)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Get the app', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              const Text('Calls, live, coins and more.', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: AppOnly.openStore, child: const Text('Download')),
            ]),
          ),
        _item(context, icon: Icons.logout_rounded, label: 'Log out', selected: false, onTap: onLogout),
      ]),
    );
  }
}

class _RightRail extends StatefulWidget {
  const _RightRail();

  @override
  State<_RightRail> createState() => _RightRailState();
}

class _RightRailState extends State<_RightRail> {
  List<Map> _tags = [];

  @override
  void initState() {
    super.initState();
    Api.get('posts/hash-counter-list?hashtag=&page=1').then((r) {
      if (!mounted) return;
      final d = r.data is Map ? r.data['results'] : null;
      final l = d is Map ? d['items'] : null;
      if (l is List) setState(() => _tags = l.whereType<Map>().take(8).toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(8, 18, 20, 18),
      child: ListView(children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Trending', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (_tags.isEmpty)
                const Text('Nothing trending yet', style: TextStyle(color: Colors.black45))
              else
                for (final t in _tags)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => HashtagScreen(tag: '${t['hashtag']}'))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        Expanded(
                            child: Text('#${t['hashtag']}',
                                style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary))),
                        Text('${t['counter']} posts', style: const TextStyle(color: Colors.black45, fontSize: 12)),
                      ]),
                    ),
                  ),
            ]),
          ),
        ),
        if (AppOnly.hasStoreLink)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.smartphone_rounded, color: cs.primary),
                  const SizedBox(width: 8),
                  const Text('Get the mobile app', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                const Text('Live streaming, voice and video calls, coins, nearby and push alerts work in the app.',
                    style: TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 10),
                FilledButton(onPressed: AppOnly.openStore, child: const Text('Download the app')),
              ]),
            ),
          ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('© Connect to Friends', style: TextStyle(color: Colors.black38, fontSize: 12)),
        ),
      ]),
    );
  }
}
