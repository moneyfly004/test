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

  Future<void> _auth() async {
    final token = await StorageService().getToken();
    if (token != null) _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // ── Auth ──────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final resp = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return _data(resp);
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String verificationCode,
    String? inviteCode,
  }) async {
    final resp = await _dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
      'verification_code': verificationCode,
      if (inviteCode != null && inviteCode.isNotEmpty) 'invite_code': inviteCode,
    });
    return _data(resp);
  }

  Future<void> sendVerificationCode(String email) async {
    await _dio.post('/auth/verification/send', data: {'email': email, 'type': 'email'});
  }

  Future<void> sendForgotPasswordCode(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    final resp = await _dio.post('/auth/reset-password', data: {
      'email': email,
      'verification_code': code,
      'new_password': newPassword,
    });
    return _data(resp);
  }

  Future<void> logout() async {
    await _auth();
    try { await _dio.post('/auth/logout'); } catch (_) {}
  }

  // ── User ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getMe() async {
    await _auth();
    final resp = await _dio.get('/users/me');
    return _data(resp);
  }

  Future<Map<String, dynamic>> getDashboard() async {
    await _auth();
    final resp = await _dio.get('/users/dashboard-info');
    return _data(resp);
  }

  // ── Subscription ─────────────────────────────────────

  /// Returns the clash subscription URL for this user.
  Future<String?> getSubscriptionUrl() async {
    await _auth();
    try {
      final resp = await _dio.get('/subscriptions/user-subscription');
      final data = _data(resp);
      // clash_url is the full URL; subscription_url is the token part
      return data['clash_url'] as String? ?? data['subscription_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Devices ───────────────────────────────────────────

  Future<List<dynamic>> getDevices() async {
    await _auth();
    final resp = await _dio.get('/devices');
    final data = _data(resp);
    return data['devices'] as List? ?? data['list'] as List? ?? (resp.data is List ? resp.data : []);
  }

  Future<void> deleteDevice(String deviceId) async {
    await _auth();
    await _dio.delete('/devices/$deviceId');
  }

  Future<void> remarkDevice(String deviceId, String remark) async {
    await _auth();
    await _dio.put('/subscriptions/devices/$deviceId/remark', data: {'remark': remark});
  }

  // ── Packages ─────────────────────────────────────────

  Future<List<dynamic>> getPackages() async {
    final resp = await _dio.get('/packages');
    final data = _data(resp);
    return data['packages'] as List? ?? data['list'] as List? ?? (resp.data is List ? resp.data : []);
  }

  // ── Payment methods ───────────────────────────────────

  Future<List<dynamic>> getPaymentMethods() async {
    final resp = await _dio.get('/payment-methods/active');
    final data = _data(resp);
    return data['methods'] as List? ?? data['payment_methods'] as List? ?? (resp.data is List ? resp.data : []);
  }

  // ── Orders ────────────────────────────────────────────

  Future<Map<String, dynamic>> createOrder(String packageId, String paymentMethod) async {
    await _auth();
    final resp = await _dio.post('/orders', data: {
      'package_id': int.tryParse(packageId) ?? packageId,
      'payment_method': paymentMethod,
    });
    return _data(resp);
  }

  Future<Map<String, dynamic>> getOrderStatus(String orderNo) async {
    await _auth();
    final resp = await _dio.get('/orders/$orderNo/status');
    return _data(resp);
  }

  // ── Helpers ───────────────────────────────────────────

  Map<String, dynamic> _data(Response resp) {
    final body = resp.data;
    if (body is Map<String, dynamic>) {
      // Standard: { success: true, data: {...} } or { data: {...} }
      if (body.containsKey('data') && body['data'] is Map) {
        return body['data'] as Map<String, dynamic>;
      }
      if (body.containsKey('data') && body['data'] is List) {
        return body as Map<String, dynamic>;
      }
      return body;
    }
    return {};
  }
}
