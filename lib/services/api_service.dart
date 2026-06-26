import 'package:dio/dio.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/services/storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: apiTimeout,
      receiveTimeout: apiTimeout,
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService().getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }
          options.headers['X-App-Client'] = appName;
          options.headers['X-App-Device-Id'] =
              await StorageService().getDeviceId();
          handler.next(options);
        },
        onError: (error, handler) {
          handler.reject(_friendlyError(error));
        },
      ),
    );

  Future<void> _auth() async {
    final token = await StorageService().getToken();
    if (token != null) _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // ── Auth ──────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String account, String password) async {
    final normalizedAccount = account.trim();
    final isEmail = normalizedAccount.contains('@');
    final resp = await _dio.post(
      isEmail ? '/auth/login' : '/auth/login-json',
      data: {
        if (isEmail)
          'email': normalizedAccount
        else
          'username': normalizedAccount,
        'password': password,
      },
    );
    return _data(resp);
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String verificationCode,
    String? inviteCode,
  }) async {
    final resp = await _dio.post(
      '/auth/register',
      data: {
        'username': username,
        'email': email,
        'password': password,
        'verification_code': verificationCode,
        if (inviteCode != null && inviteCode.isNotEmpty)
          'invite_code': inviteCode,
      },
    );
    return _data(resp);
  }

  Future<void> sendVerificationCode(String email) async {
    await _dio.post(
      '/auth/verification/send',
      data: {'email': email, 'type': 'email'},
    );
  }

  Future<void> sendForgotPasswordCode(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    final resp = await _dio.post(
      '/auth/reset-password',
      data: {
        'email': email,
        'verification_code': code,
        'new_password': newPassword,
      },
    );
    return _data(resp);
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
  }

  // ── User ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getMe() async {
    final resp = await _dio.get('/users/me');
    return _data(resp);
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final result = <String, dynamic>{};

    // 1. Get expiry/subscription info from known-working endpoint
    try {
      final resp = await _dio.get('/subscriptions/user-subscription');
      final data = _data(resp);
      // Try common expiry field names
      final expiry = data['expire_at'] ?? data['expiry'] ?? data['expired_at'] ??
          data['expire_time'] ?? data['end_at'] ?? data['end_time'] ??
          data['expires_at'] ?? data['valid_until'];
      if (expiry != null) result['expiry'] = expiry;
      // Device limit
      final limit = data['device_limit'] ?? data['devices_limit'] ?? data['max_devices'];
      if (limit != null) result['device_limit'] = limit;
    } catch (_) {}

    // Also try /subscriptions list as fallback
    if (!result.containsKey('expiry')) {
      try {
        final resp = await _dio.get('/subscriptions');
        final data = _data(resp);
        final list = data['subscriptions'] as List? ??
            data['list'] as List? ??
            (resp.data is List ? resp.data as List : null);
        final first = list?.isNotEmpty == true ? list!.first as Map? : null;
        if (first != null) {
          final expiry = first['expire_at'] ?? first['expiry'] ?? first['expired_at'] ??
              first['end_at'] ?? first['expires_at'] ?? first['valid_until'];
          if (expiry != null) result['expiry'] = expiry;
          final limit = first['device_limit'] ?? first['devices_limit'] ?? first['max_devices'];
          if (limit != null) result['device_limit'] = limit;
        }
      } catch (_) {}
    }

    // 2. Get device count from devices endpoint
    try {
      final resp = await _dio.get('/subscriptions/devices');
      final data = _data(resp);
      final devices = data['devices'] as List? ??
          data['list'] as List? ??
          (resp.data is List ? resp.data as List : null);
      if (devices != null) {
        result['device_used'] = devices.length;
        // If we don't have limit yet, try from this response
        if (!result.containsKey('device_limit')) {
          final limit = data['limit'] ?? data['max'] ?? data['device_limit'];
          if (limit != null) result['device_limit'] = limit;
        }
      }
    } catch (_) {}

    // 3. Try /users/me for any remaining fields
    if (result.isEmpty) {
      try {
        final resp = await _dio.get('/users/me');
        result.addAll(_data(resp));
      } catch (_) {}
    }

    return result;
  }

  // ── Subscription ─────────────────────────────────────

  /// Returns the clash subscription URL for this user.
  Future<String?> getSubscriptionUrl() async {
    try {
      final resp = await _dio.get('/subscriptions/user-subscription');
      final data = _data(resp);
      // clash_url is the full URL; subscription_url is the token part
      final url = _subscriptionUrlFromMap(data);
      if (url != null) return url;
    } catch (_) {
      // Fall through to the subscriptions list endpoint for older deployments.
    }
    final resp = await _dio.get('/subscriptions');
    final data = _data(resp);
    final subscriptions = data['subscriptions'] as List? ??
        data['list'] as List? ??
        (resp.data is List ? resp.data as List : null);
    if (subscriptions == null || subscriptions.isEmpty) return null;
    final first = subscriptions.first;
    if (first is Map) return _subscriptionUrlFromMap(first);
    return null;
  }

  // ── Devices ───────────────────────────────────────────

  Future<List<dynamic>> getDevices() async {
    final resp = await _dio.get('/subscriptions/devices');
    final data = _data(resp);
    return data['devices'] as List? ??
        data['list'] as List? ??
        (resp.data is List ? resp.data : []);
  }

  Future<void> deleteDevice(String deviceId) async {
    await _dio.delete('/devices/$deviceId');
  }

  Future<void> remarkDevice(String deviceId, String remark) async {
    await _dio.put(
      '/subscriptions/devices/$deviceId/remark',
      data: {'remark': remark},
    );
  }

  // ── Packages ─────────────────────────────────────────

  Future<List<dynamic>> getPackages() async {
    final resp = await _dio.get('/packages');
    final data = _data(resp);
    return _listFromData(resp.data, data, [
      'packages',
      'plans',
      'products',
      'items',
      'list',
      'data',
    ]);
  }

  // ── Payment methods ───────────────────────────────────

  Future<List<dynamic>> getPaymentMethods() async {
    final resp = await _dio.get('/payment-methods/active');
    final data = _data(resp);
    return _listFromData(resp.data, data, [
      'methods',
      'payment_methods',
      'items',
      'list',
      'data',
    ]);
  }

  // ── Orders ────────────────────────────────────────────

  Future<Map<String, dynamic>> createOrder(
    String packageId,
    String paymentMethod,
  ) async {
    final resp = await _dio.post(
      '/orders',
      data: {
        'package_id': int.tryParse(packageId) ?? packageId,
        'payment_method': paymentMethod,
      },
    );
    return _data(resp);
  }

  Future<Map<String, dynamic>> getOrderStatus(String orderNo) async {
    final resp = await _dio.get('/orders/$orderNo/status');
    return _data(resp);
  }

  // ── Helpers ───────────────────────────────────────────

  List<dynamic> _listFromData(
    Object? raw,
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) return value;
    }
    if (raw is List) return raw;
    if (raw is Map) {
      for (final key in keys) {
        final value = raw[key];
        if (value is List) return value;
      }
    }
    return [];
  }

  Map<String, dynamic> _data(Response resp) {
    final body = resp.data;
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data') && body['data'] is Map) {
        return body['data'] as Map<String, dynamic>;
      }
      if (body.containsKey('data') && body['data'] is List) {
        return body;
      }
      return body;
    }
    return {};
  }

  DioException _friendlyError(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    final message = _messageFromBody(response?.data) ??
        _messageFromStatusCode(statusCode) ??
        error.message ??
        '网络请求失败，请检查网络后重试';
    return error.copyWith(message: message);
  }

  String? _messageFromStatusCode(int? statusCode) {
    if (statusCode == null) return null;
    if (statusCode >= 500 && statusCode < 600) {
      return '服务器暂时不可用，请稍后再试';
    }
    return switch (statusCode) {
      400 => '请求参数不正确，请检查后重试',
      401 => '登录已失效或账号密码错误，请重新登录',
      403 => '当前账号无权执行此操作',
      404 => '请求的资源不存在',
      429 => '操作过于频繁，请稍后再试',
      _ => null,
    };
  }

  String? _messageFromBody(Object? body) {
    if (body is Map) {
      for (final key in ['message', 'msg', 'error']) {
        final value = body[key];
        if (value is String && value.trim().isNotEmpty) return value;
      }
      final data = body['data'];
      if (data is Map) return _messageFromBody(data);
    }
    return null;
  }

  String? _subscriptionUrlFromMap(Map data) {
    final clashUrl = data['clash_url'];
    if (clashUrl is String && clashUrl.isNotEmpty) return clashUrl;
    final token = data['subscription_url'];
    if (token is String && token.isNotEmpty) {
      if (token.startsWith('http')) return token;
      return '$apiBaseUrl/subscriptions/clash/$token';
    }
    return null;
  }
}
