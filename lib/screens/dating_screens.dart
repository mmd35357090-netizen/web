import 'package:flutter/material.dart';
import '../app_only.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'paged_list.dart';
import 'profile_screen.dart';
import 'dating_plans_screen.dart';

int? _age(String dob) {
  final d = DateTime.tryParse(dob);
  if (d == null) return null;
  final now = DateTime.now();
  var a = now.year - d.year;
  if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
  return a < 0 || a > 120 ? null : a;
}

class DatingScreen extends StatelessWidget {
  const DatingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dating'),
          actions: [
            IconButton(
              tooltip: 'My dating settings',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const DatingSettingsScreen())),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Discover'), Tab(text: 'Matches'), Tab(text: 'Likes you')]),
        ),
        body: const TabBarView(children: [
          _Discover(),
          _SimpleList(path: 'datings/profile-matching', listKey: 'userMatch', nested: true, empty: 'No matches yet'),
          _SimpleList(
              path: 'datings/profile-like-by-other-users',
              listKey: 'profileLikeByOtherUsers',
              nested: false,
              empty: 'Nobody has liked you yet'),
        ]),
      ),
    );
  }
}

class _Discover extends StatefulWidget {
  const _Discover();

  @override
  State<_Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<_Discover> {
  List<Map> _profiles = [];
  bool _loading = true;
  bool _busy = false;
  String _error = '';
  Map _status = {};
  final Map<int, List<String>> _photos = {};
  int _photoIdx = 0;
  int _lastSkipped = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _paused => _status['paused'] == true;
  int get _superLeft => int.tryParse('${_status['super_likes_left'] ?? 0}') ?? 0;

  Future<void> _loadStatus() async {
    final r = await Api.get('datings/dating-status');
    if (!mounted) return;
    if (r.ok && r.data is Map) setState(() => _status = Map.from(r.data as Map));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    _loadStatus();
    final r = await Api.get('datings/preference-profile-match');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _photoIdx = 0;
      final l = r.data is Map ? r.data['preferenceMatchProfile'] : null;
      _profiles = l is List ? l.whereType<Map>().toList() : [];
      if (!r.ok) _error = r.message;
    });
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    if (_profiles.isEmpty) return;
    final id = int.tryParse('${_profiles.first['id']}') ?? 0;
    if (id == 0 || _photos.containsKey(id)) return;
    final r = await Api.get('datings/profile-photos?user_id=$id');
    if (!mounted) return;
    final l = r.ok && r.data is Map ? r.data['photos'] : null;
    setState(() => _photos[id] = l is List ? l.map((e) => '$e').where((e) => e.isNotEmpty && e != 'null').toList() : []);
  }

  void _next() {
    setState(() {
      _profiles.removeAt(0);
      _photoIdx = 0;
    });
    if (_profiles.isEmpty) {
      _load();
    } else {
      _loadPhotos();
    }
  }

  Future<void> _act(bool like, {bool superLike = false}) async {
    if (_profiles.isEmpty || _busy) return;
    final p = _profiles.first;
    setState(() => _busy = true);
    final r = await Api.post(like ? 'datings/profile-action-like' : 'datings/profile-action-skip',
        {'profile_user_id': '${p['id']}', if (superLike) 'super_like': '1'});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      final isMatch = r.data is Map && (r.data['is_match'] == true || '${r.data['is_match']}' == '1');
      if (!like) _lastSkipped = int.tryParse('${p['id']}') ?? 0;
      if (like) {
        if (r.data is Map && r.data['super_likes_left'] != null) {
          _status['super_likes_left'] = r.data['super_likes_left'];
        }
        toast(context, superLike ? 'Super liked ${str(p['name'])}' : 'Liked ${str(p['name'])}');
      }
      _next();
      if (isMatch) _matchDialog(p);
    } else {
      toast(context, r.message.isEmpty ? 'Something went wrong' : r.message);
    }
  }

  void _matchDialog(Map p) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.favorite_rounded, color: Colors.pink, size: 40),
        title: const Text("It's a match!", textAlign: TextAlign.center),
        content: Text('You and ${str(p['name'])} liked each other.', textAlign: TextAlign.center),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Keep swiping'))],
      ),
    );
  }

  Future<void> _rewind() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await Api.post('datings/profile-action-rewind', _lastSkipped > 0 ? {'profile_user_id': '$_lastSkipped'} : {});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      toast(context, 'Last skip undone');
      _lastSkipped = 0;
      _load();
    } else {
      toast(context, r.message.isEmpty ? 'Nothing to rewind' : r.message);
    }
  }

  Future<void> _boost() async {
    final r = await Api.post('datings/boost', {});
    if (!mounted) return;
    toast(context, r.ok ? 'Boost on for 30 minutes' : (r.message.isEmpty ? 'Boost not available' : r.message));
    _loadStatus();
  }

  Future<void> _unpause() async {
    final r = await Api.post('datings/pause', {'paused': '0'});
    if (!mounted) return;
    if (r.ok) {
      toast(context, 'Your profile is visible again');
      _loadStatus();
    } else {
      toast(context, r.message.isEmpty ? 'Failed' : r.message);
    }
  }

  Widget _round(IconData icon, Color color, VoidCallback? onTap, {double size = 28, String? tip, String? badge}) {
    final b = FloatingActionButton(
      heroTag: null,
      mini: size < 26,
      backgroundColor: Colors.white,
      tooltip: tip,
      onPressed: onTap,
      child: Icon(icon, color: color, size: size),
    );
    if (badge == null) return b;
    return Badge(label: Text(badge), child: b);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final banner = _paused
        ? MaterialBanner(
            content: const Text('Your dating profile is paused, so nobody can see you.'),
            leading: const Icon(Icons.pause_circle_outline),
            actions: [TextButton(onPressed: _unpause, child: const Text('Show me'))],
          )
        : null;
    if (_profiles.isEmpty) {
      return Column(children: [
        if (banner != null) banner,
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.favorite_border_rounded, size: 48),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error.isNotEmpty
                      ? _error
                      : 'No profiles to show right now.\nCheck your dating settings (gender, age) with the ⚙ button.',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: _load, child: const Text('Refresh')),
                if (_lastSkipped > 0) OutlinedButton(onPressed: _rewind, child: const Text('Undo last skip')),
                OutlinedButton(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const DatingPlansScreen())),
                    child: const Text('Get more profiles')),
              ]),
            ]),
          ),
        ),
      ]);
    }
    final p = _profiles.first;
    final id = int.tryParse('${p['id']}') ?? 0;
    final pic = str(p['picture']);
    final gallery = <String>[
      if (_photos[id] != null && _photos[id]!.isNotEmpty) ..._photos[id]! else if (pic.isNotEmpty && pic != 'null') pic
    ];
    final shown = gallery.isEmpty ? '' : gallery[_photoIdx.clamp(0, gallery.length - 1)];
    final age = _age(str(p['dob']));
    final remaining = _status['remaining'];
    final boostActive = _status['boost_active'] == true;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(children: [
          if (banner != null) banner,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Card(
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                child: Stack(fit: StackFit.expand, children: [
                  shown.isEmpty
                      ? const ColoredBox(color: Colors.black12, child: Icon(Icons.person, size: 90))
                      : netImage(shown, width: double.infinity, height: double.infinity),
                  if (gallery.length > 1) ...[
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Row(children: [
                        for (var i = 0; i < gallery.length; i++)
                          Expanded(
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: i == _photoIdx ? Colors.white : Colors.white38,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    Positioned.fill(
                      child: Row(children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => setState(() => _photoIdx = (_photoIdx - 1).clamp(0, gallery.length - 1)),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => setState(() => _photoIdx = (_photoIdx + 1).clamp(0, gallery.length - 1)),
                          ),
                        ),
                      ]),
                    ),
                  ],
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(age == null ? str(p['name']) : '${str(p['name'])}, $age',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                          if (str(p['bio']).isNotEmpty && str(p['bio']) != 'null')
                            Text(str(p['bio']), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _round(Icons.replay_rounded, Colors.amber.shade800, _busy ? null : _rewind, size: 22, tip: 'Undo last skip'),
            _round(Icons.close_rounded, Colors.red, _busy ? null : () => _act(false), size: 32, tip: 'Skip'),
            _round(Icons.star_rounded, Colors.blue, _busy || _superLeft <= 0 ? null : () => _act(true, superLike: true),
                size: 26, tip: 'Super like', badge: '$_superLeft'),
            _round(Icons.favorite_rounded, Colors.pink, _busy ? null : () => _act(true), size: 30, tip: 'Like'),
            _round(Icons.bolt_rounded, boostActive ? Colors.grey : Colors.purple, boostActive ? null : _boost,
                size: 22, tip: boostActive ? 'Boost is on' : 'Boost my profile'),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(remaining == null ? '' : '$remaining profiles left today',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ]),
      ),
    );
  }
}

class _SimpleList extends StatefulWidget {
  final String path;
  final String listKey;
  final bool nested; // response is {key: {items: []}}
  final String empty;
  const _SimpleList({required this.path, required this.listKey, required this.nested, required this.empty});

  @override
  State<_SimpleList> createState() => _SimpleListState();
}

class _SimpleListState extends State<_SimpleList> {
  List<Map> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Api.get(widget.path).then((r) {
      if (!mounted) return;
      dynamic l = r.data is Map ? r.data[widget.listKey] : null;
      if (widget.nested && l is Map) l = l['items'];
      setState(() {
        _loading = false;
        _items = l is List ? l.whereType<Map>().toList() : [];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return Center(child: Text(widget.empty));
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: _items.length,
          itemBuilder: (c, i) {
            final u = AppUser.fromJson(_items[i]);
            final age = _age(str(_items[i]['dob']));
            return Card(
              elevation: 0,
              child: ListTile(
                leading: Avatar(u),
                title: Text(age == null ? u.displayName : '${u.displayName}, $age'),
                subtitle: Text('@${u.username}'),
                onTap: () => Navigator.of(c)
                    .push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: u.id))),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// My own dating details (birthday, gender) and who I want to see (gender, age range).
class DatingSettingsScreen extends StatefulWidget {
  const DatingSettingsScreen({super.key});

  @override
  State<DatingSettingsScreen> createState() => _DatingSettingsScreenState();
}

class _DatingSettingsScreenState extends State<DatingSettingsScreen> {
  bool _loading = true;
  bool _busy = false;
  int _myGender = 1; // 1 male, 2 female, 3 other
  DateTime? _dob;
  int _wantGender = 2;
  RangeValues _age = const RangeValues(18, 40);
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await Api.get('users/profile');
    final pref = await Api.get('datings/preference-profile?expand=preferenceInterest,preferenceLanguage');
    final st = await Api.get('datings/dating-status');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (st.data is Map) _paused = st.data['paused'] == true;
      if (me.data is Map && me.data['user'] is Map) {
        final u = me.data['user'] as Map;
        _myGender = int.tryParse('${u['sex']}') ?? 1;
        if (_myGender < 1 || _myGender > 3) _myGender = 1;
        _dob = DateTime.tryParse('${u['dob']}');
      }
      if (pref.data is Map && pref.data['preferenceSetting'] is Map) {
        final p = pref.data['preferenceSetting'] as Map;
        final g = int.tryParse('${p['gander']}');
        if (g != null && g >= 1 && g <= 3) _wantGender = g;
        final a = double.tryParse('${p['age_from']}');
        final b = double.tryParse('${p['age_to']}');
        if (a != null && b != null && a >= 18 && b <= 80 && a <= b) _age = RangeValues(a, b);
      }
    });
  }

  Future<void> _save() async {
    if (_dob == null) {
      toast(context, 'Choose your date of birth');
      return;
    }
    setState(() => _busy = true);
    final r1 = await Api.post('users/profile-update', {
      'dob': DateFormat('yyyy-MM-dd').format(_dob!),
      'sex': '$_myGender',
    });
    final r2 = await Api.post('datings/add-user-preference', {
      'gander': '$_wantGender',
      'age_from': '${_age.start.round()}',
      'age_to': '${_age.end.round()}',
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r1.ok && r2.ok) {
      toast(context, 'Saved');
      Navigator.pop(context);
    } else {
      toast(context, (!r1.ok ? r1.message : r2.message).isEmpty ? 'Could not save' : (!r1.ok ? r1.message : r2.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget genderPick(int value, ValueChanged<int> set) => SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('Male')),
            ButtonSegment(value: 2, label: Text('Female')),
            ButtonSegment(value: 3, label: Text('Other')),
          ],
          selected: {value},
          onSelectionChanged: (s) => setState(() => set(s.first)),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Dating settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  const Text('About me', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 10),
                  genderPick(_myGender, (v) => _myGender = v),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cake_outlined),
                    title: Text(_dob == null ? 'Date of birth' : DateFormat('d MMM yyyy').format(_dob!)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _dob ?? DateTime(now.year - 25),
                        firstDate: DateTime(now.year - 100),
                        lastDate: DateTime(now.year - 18, now.month, now.day),
                      );
                      if (d != null) setState(() => _dob = d);
                    },
                  ),
                  const Divider(height: 32),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pause my dating profile'),
                    subtitle: const Text('Hide me from everyone until you turn it back on'),
                    value: _paused,
                    onChanged: (v) async {
                      setState(() => _paused = v);
                      final r = await Api.post('datings/pause', {'paused': v ? '1' : '0'});
                      if (!mounted) return;
                      if (!r.ok) {
                        setState(() => _paused = !v);
                        toast(context, r.message.isEmpty ? 'Failed' : r.message);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: const Text('Dating plans'),
                    subtitle: const Text('See more profiles every day'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const DatingPlansScreen())),
                  ),
                  const Divider(height: 32),
                  const Text('I want to meet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 10),
                  genderPick(_wantGender, (v) => _wantGender = v),
                  const SizedBox(height: 16),
                  Text('Age: ${_age.start.round()} - ${_age.end.round()}'),
                  RangeSlider(
                    values: _age,
                    min: 18,
                    max: 80,
                    divisions: 62,
                    labels: RangeLabels('${_age.start.round()}', '${_age.end.round()}'),
                    onChanged: (v) => setState(() => _age = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'Save')),
                  const SizedBox(height: 8),
                  const AppOnlyNote('More filters (interests, languages, height) are in the mobile app.'),
                ]),
              ),
            ),
    );
  }
}
