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
