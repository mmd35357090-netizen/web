import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class ApiResult {
  final bool ok;
  final int status;
  final dynamic data;
  final String message;
  ApiResult(this.ok, this.status, this.data, this.message);
}

class Api {
  static String? token;

  /// called when the server says the login is not valid any more
  static void Function()? onUnauthorized;

  static Future<void> loadToken() async {
    try {
      final p = await SharedPreferences.getInstance();
      token = p.getString('auth_key');
    } catch (_) {}
  }

  static Future<void> saveToken(String? t) async {
    token = t;
    try {
      final p = await SharedPreferences.getInstance();
      if (t == null) {
        await p.remove('auth_key');
      } else {
        await p.setString('auth_key', t);
      }
    } catch (_) {}
  }

  static Map<String, String> _headers({bool json = false}) {
    final h = <String, String>{};
    if (token != null) h['Authorization'] = 'Bearer $token';
    if (json) h['Content-Type'] = 'application/json';
    return h;
  }

  static String _firstError(dynamic errors) {
    try {
      if (errors is Map) {
        final m = errors['message'];
        if (m is List && m.isNotEmpty) return m.first.toString();
        for (final v in errors.values) {
          if (v is List && v.isNotEmpty) return v.first.toString();
        }
      }
    } catch (_) {}
    return '';
  }

  static ApiResult _parse(http.Response r) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      int status = r.statusCode;
      String msg = '';
      dynamic data;
      if (j is Map) {
        if (j['status'] is int) status = j['status'] as int;
        if (j['message'] is String) msg = j['message'] as String;
        data = j['data'];
      }
      if (status != 200 && msg.isEmpty && data is Map) {
        msg = _firstError(data['errors']);
      }
      if (status == 401 && token != null && onUnauthorized != null) {
        onUnauthorized!();
      }
      return ApiResult(status == 200, status, data, msg);
    } catch (_) {
      return ApiResult(false, r.statusCode, null, 'Unexpected response from server');
    }
  }

  static Uri _uri(String path) => Uri.parse('${AppConfig.apiBase}$path');

  static Future<ApiResult> get(String path) async {
    try {
      final r = await http.get(_uri(path), headers: _headers());
      return _parse(r);
    } catch (_) {
      return ApiResult(false, 0, null, 'Network error. Please check your connection.');
    }
  }

  static Future<ApiResult> post(String path, Map<String, dynamic> body) async {
    try {
      final r = await http.post(_uri(path), headers: _headers(json: true), body: jsonEncode(body));
      return _parse(r);
    } catch (_) {
      return ApiResult(false, 0, null, 'Network error. Please check your connection.');
    }
  }

  /// login uses a normal form body, like the mobile app
  static Future<ApiResult> login(String email, String password) async {
    try {
      final r = await http.post(_uri('users/login'), body: {
        'email': email,
        'password': password,
        'device_type': '3',
        'device_token': '',
        'device_model': 'web',
        'device_os_version': 'web',
        'device_app_release_version': '1.0.0',
        'login_ip': '',
        'login_location': '',
      });
      return _parse(r);
    } catch (_) {
      return ApiResult(false, 0, null, 'Network error. Please check your connection.');
    }
  }

  /// uploads one file (type 7 = post media) and returns {file, fileUrl} or an error message
  static Future<ApiResult> upload(String name, Uint8List bytes, String mime, {String type = '7'}) async {
    try {
      final req = http.MultipartRequest('POST', _uri('file-uploads/upload-file'));
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.fields['type'] = type;
      req.files.add(http.MultipartFile.fromBytes('mediaFile', bytes,
          filename: name, contentType: MediaType.parse(mime)));
      final streamed = await req.send();
      final r = await http.Response.fromStream(streamed);
      return _parse(r);
    } catch (_) {
      return ApiResult(false, 0, null, 'Upload failed. Please check your connection.');
    }
  }

  static Future<ApiResult> delete(String path) async {
    try {
      final r = await http.delete(_uri(path), headers: _headers(json: true));
      return _parse(r);
    } catch (_) {
      return ApiResult(false, 0, null, 'Network error. Please check your connection.');
    }
  }

  /// profile photo (field name imageFile)
  static Future<ApiResult> uploadProfileImage(String name, Uint8List bytes, String mime) async {
    try {
      final req = http.MultipartRequest('POST', _uri('users/update-profile-image'));
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.files.add(http.MultipartFile.fromBytes('imageFile', bytes,
          filename: name, contentType: MediaType.parse(mime)));
      final streamed = await req.send();
      return _parse(await http.Response.fromStream(streamed));
    } catch (_) {
      return ApiResult(false, 0, null, 'Upload failed. Please check your connection.');
    }
  }
}
