import 'package:dio/dio.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/services/storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    connectTimeout: apiTimeout,
    receiveTimeout: apiTimeout,
    headers: {'Content-Type': 'application/json'},
  ));

  Future<void> _addAuthHeader() async {
    final token = await StorageService().getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      _dio.options.headers['X-App-Device-Id'] = await StorageService().getDeviceId();
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
      'device_id': await StorageService().getDeviceId(),
    });
    return response.data;
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String verificationCode,
    String? inviteCode,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
      'email_verification_code': verificationCode,
      'invite_code': inviteCode,
      'device_id': await StorageService().getDeviceId(),
    });
    return response.data;
  }

  Future<void> sendVerificationCode(String email) async {
    await _dio.post('/auth/send-code', data: {'email': email});
  }

  Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    final response = await _dio.post('/auth/reset-password', data: {
      'email': email,
      'verification_code': code,
      'new_password': newPassword,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getProfile() async {
    await _addAuthHeader();
    final response = await _dio.get('/user/profile');
    return response.data;
  }

  Future<String> getSubscriptionUrl() async {
    await _addAuthHeader();
    final response = await _dio.get('/user/subscription-url');
    return response.data['subscription_url'];
  }

  Future<List<dynamic>> getDevices() async {
    await _addAuthHeader();
    final response = await _dio.get('/devices');
    return response.data['devices'];
  }

  Future<void> deleteDevice(String deviceId) async {
    await _addAuthHeader();
    await _dio.delete('/devices/$deviceId');
  }

  Future<List<dynamic>> getPackages() async {
    await _addAuthHeader();
    final response = await _dio.get('/packages');
    return response.data['packages'];
  }

  Future<Map<String, dynamic>> createOrder(String packageId) async {
    await _addAuthHeader();
    final response = await _dio.post('/orders', data: {'package_id': packageId});
    return response.data;
  }

  Future<Map<String, dynamic>> getOrderStatus(String orderId) async {
    await _addAuthHeader();
    final response = await _dio.get('/orders/$orderId');
    return response.data;
  }

  Future<void> logout() async {
    await _addAuthHeader();
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
  }
}
