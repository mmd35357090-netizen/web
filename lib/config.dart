/// Web project settings. Change the address when the domain changes.
class AppConfig {
  static const String apiBase = 'https://facehub.sbehf.com/api/web/v1/';
  static const String appName = 'Facehub';

  /// chat server (Socket.IO)
  static const socketUrl = 'https://facehub.sbehf.com:4000/';
  static const chatVersion = 1;
  static const enableEncryption = 1;
  // same key the Android app uses for chat messages (it can be read from the app too, so it is not a real secret)
  static const chatKey = 'bbC2H19lkVbQDfakxcrtNMQdd0FloLyw';
}
