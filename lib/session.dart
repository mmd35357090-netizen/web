import 'api.dart';
import 'models.dart';

/// the logged in user (loaded once after login)
class Session {
  static AppUser? me;

  static Future<AppUser?> load() async {
    if (me != null) return me;
    final r = await Api.get('users/profile');
    if (r.ok && r.data is Map && r.data['user'] != null) {
      me = AppUser.fromJson(r.data['user']);
    }
    return me;
  }

  static void clear() => me = null;
}
