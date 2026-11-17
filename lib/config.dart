/// Web project settings. Change the address when the domain changes.
class AppConfig {
  static const String apiBase = 'https://connecttofriends.com/api/web/v1/';
  static const String appName = 'Connect to Friends';

  /// Google "Web client ID" (ends with .apps.googleusercontent.com). Leave empty to hide the Google button.
  /// It must also be listed in the server's socialLogin -> googleClientIds.
  static const String googleClientId = '559111651319-gjc71odm8dvecf3mhljkl47kat6e461o.apps.googleusercontent.com';

  /// chat server (Socket.IO)
  static const socketUrl = 'https://connecttofriends.com:4000/';
  static const chatVersion = 1;
  static const enableEncryption = 1;
  // same key the Android app uses for chat messages (it can be read from the app too, so it is not a real secret)
  static const chatKey = 'bbC2H19lkVbQDfakxcrtNMQdd0FloLyw';
}
