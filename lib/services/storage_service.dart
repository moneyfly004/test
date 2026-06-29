import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refresh_token', token);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }

  // ── Auto-login with saved password ──────────────────────

  Future<void> saveCredentials(String account, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_account', account);
    await prefs.setString('saved_password', password);
    await prefs.setBool('save_password', true);
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_account');
    await prefs.remove('saved_password');
    await prefs.setBool('save_password', false);
  }

  Future<Map<String, String?>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savePassword = prefs.getBool('save_password') ?? false;
    if (!savePassword) return null;
    final account = prefs.getString('saved_account');
    final password = prefs.getString('saved_password');
    if (account == null || password == null) return null;
    return {'account': account, 'password': password};
  }

  Future<bool> shouldAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('save_password') ?? false;
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('saved_account');
    await prefs.remove('saved_password');
    await prefs.remove('save_password');
    await prefs.remove('device_id');
  }

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = await _generateDeviceId();
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }

  Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String identifier;

    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      identifier = '${info.id}_${info.model}_${info.device}';
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      identifier = info.identifierForVendor ?? DateTime.now().toString();
    } else if (Platform.isMacOS) {
      final info = await deviceInfo.macOsInfo;
      identifier = '${info.systemGUID}_${info.model}';
    } else if (Platform.isWindows) {
      final info = await deviceInfo.windowsInfo;
      identifier = '${info.deviceId}_${info.computerName}';
    } else {
      identifier = DateTime.now().millisecondsSinceEpoch.toString();
    }

    return sha256.convert(utf8.encode(identifier)).toString();
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
