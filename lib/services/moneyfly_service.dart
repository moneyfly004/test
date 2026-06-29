import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/services/api_service.dart';
import 'package:fl_clash/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MoneyFlyService {
  static const profileLabel = 'MoneyFly';

  static Future<MoneyFlyAccountState> refreshAccountState(WidgetRef ref) {
    return _refreshAccountState(ref);
  }

  static Future<MoneyFlyAccountState> refreshAccountStateFromContainer(
    ProviderContainer container,
  ) {
    return _refreshAccountState(container);
  }

  static Future<Profile?> syncSubscription(WidgetRef ref) async {
    return (await _refreshAccountState(ref)).profile;
  }

  static Future<Profile?> syncSubscriptionFromContainer(
    ProviderContainer container,
  ) async {
    return (await _refreshAccountState(container)).profile;
  }

  static Future<void> clearAccountData(WidgetRef ref) {
    return _clearAccountData(ref);
  }

  static Future<void> clearAccountDataFromContainer(
    ProviderContainer container,
  ) {
    return _clearAccountData(container);
  }

  static Future<void> logout(WidgetRef ref) async {
    await ApiService().logout();
    await _clearAccountData(ref);
    await StorageService().clearTokens();
  }

  // Fire-and-forget cleanup used after already navigating to login
  static Future<void> cleanupAfterLogout(WidgetRef ref) async {
    try {
      await ApiService().logout();
    } catch (_) {}
    try {
      await _clearAccountData(ref);
    } catch (_) {}
  }

  static Future<MoneyFlyAccountState> _refreshAccountState(
    dynamic container,
  ) async {
    Map<String, dynamic> dashboard = {};
    try {
      dashboard = await ApiService().getDashboard();
    } catch (e) {
      await _clearAccountData(container);
      return MoneyFlyAccountState.unavailable(
        message: '账户状态校验失败：$e',
        dashboard: dashboard,
      );
    }

    final statusMessage = _accountUnavailableMessage(dashboard);
    if (statusMessage != null) {
      await _clearAccountData(container);
      return MoneyFlyAccountState.unavailable(
        message: statusMessage,
        dashboard: dashboard,
      );
    }

    final String? subscriptionUrl;
    try {
      subscriptionUrl = await ApiService().getSubscriptionUrl();
    } catch (e) {
      await _clearAccountData(container);
      return MoneyFlyAccountState.unavailable(
        message: '订阅不可用：$e',
        dashboard: dashboard,
      );
    }
    if (subscriptionUrl == null || subscriptionUrl.isEmpty) {
      await _clearAccountData(container);
      return MoneyFlyAccountState.unavailable(
        message: '当前账号暂无可用订阅',
        dashboard: dashboard,
      );
    }

    final profiles = List<Profile>.from(container.read(profilesProvider));
    final existingProfile = profiles.where(_isMoneyFlyProfile).firstOrNull;
    final sourceProfile =
        existingProfile ??
        Profile.normal(label: profileLabel, url: subscriptionUrl);
    final Profile profile;
    try {
      profile = await sourceProfile
          .copyWith(label: profileLabel, url: subscriptionUrl)
          .update();
    } catch (e) {
      await _clearAccountData(container);
      return MoneyFlyAccountState.unavailable(
        message: '订阅配置更新失败：$e',
        dashboard: dashboard,
      );
    }
    container.read(profilesProvider.notifier).put(profile);
    container.read(currentProfileIdProvider.notifier).value = profile.id;
    container
        .read(setupActionProvider.notifier)
        .applyProfileDebounce(force: true, silence: true);
    return MoneyFlyAccountState.available(
      dashboard: dashboard,
      profile: profile,
    );
  }

  static Future<void> _clearAccountData(dynamic container) async {
    try {
      await container.read(setupActionProvider.notifier).updateStatus(false);
    } catch (_) {}
    await _deleteMoneyFlyProfiles(container);
  }

  static Future<void> _deleteMoneyFlyProfiles(dynamic container) async {
    final profiles = List<Profile>.from(container.read(profilesProvider));
    for (final profile in profiles) {
      if (_isMoneyFlyProfile(profile)) {
        await container
            .read(profilesActionProvider.notifier)
            .deleteProfile(profile.id);
      }
    }
  }

  static bool _isMoneyFlyProfile(Profile profile) {
    return profile.label == profileLabel ||
        profile.url.startsWith('$apiBaseUrl/subscriptions/clash/') ||
        profile.url.startsWith('$apiBaseUrl/subscriptions/universal/');
  }

  static String? _accountUnavailableMessage(Map<String, dynamic> data) {
    final maps = [
      data,
      if (data['user'] is Map) Map<String, dynamic>.from(data['user'] as Map),
      if (data['subscription'] is Map)
        Map<String, dynamic>.from(data['subscription'] as Map),
    ];

    for (final map in maps) {
      final status = _stringValue(map, [
        'status',
        'account_status',
        'subscription_status',
        'state',
      ])?.toLowerCase();
      if (status != null &&
          [
            'expired',
            'disabled',
            'disable',
            'banned',
            'blocked',
            'locked',
            'restricted',
            'suspended',
            'inactive',
            'limited',
          ].contains(status)) {
        return '当前账号状态不可用：$status';
      }
      final active = _boolValue(map, ['active', 'is_active', 'enabled']);
      if (active == false) return '当前账号已被限制或停用';
      final expired = _boolValue(map, ['expired', 'is_expired']);
      if (expired == true) return '当前套餐已到期';
    }

    final expireTime = _dateValue(data, [
      'expire_time',
      'expires_at',
      'expired_at',
      'end_time',
      'valid_until',
      'expiryDate',
    ]);
    if (expireTime != null && !expireTime.isAfter(DateTime.now())) {
      return '当前套餐已到期';
    }

    final deviceLimit = _intValue(data, ['device_limit', 'devices_limit']);
    final currentDevices = _intValue(data, [
      'current_devices',
      'device_used',
      'devices_used',
      'online_devices',
    ]);
    if (deviceLimit != null &&
        deviceLimit > 0 &&
        currentDevices != null &&
        currentDevices > deviceLimit) {
      return '设备数量已超过限制（$currentDevices/$deviceLimit）';
    }
    return null;
  }

  static String? _stringValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static bool? _boolValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.toLowerCase().trim();
        if (['true', '1', 'yes', 'active', 'enabled'].contains(normalized)) {
          return true;
        }
        if (['false', '0', 'no', 'inactive', 'disabled'].contains(normalized)) {
          return false;
        }
      }
    }
    return null;
  }

  static int? _intValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static DateTime? _dateValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is DateTime) return value;
      if (value is int) {
        final milliseconds = value > 100000000000 ? value : value * 1000;
        return DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
        final timestamp = int.tryParse(value);
        if (timestamp != null) {
          final milliseconds = timestamp > 100000000000
              ? timestamp
              : timestamp * 1000;
          return DateTime.fromMillisecondsSinceEpoch(milliseconds);
        }
      }
    }
    return null;
  }
}

class MoneyFlyAccountState {
  final bool available;
  final String? message;
  final Map<String, dynamic> dashboard;
  final Profile? profile;

  const MoneyFlyAccountState._({
    required this.available,
    required this.dashboard,
    this.message,
    this.profile,
  });

  factory MoneyFlyAccountState.available({
    required Map<String, dynamic> dashboard,
    required Profile profile,
  }) {
    return MoneyFlyAccountState._(
      available: true,
      dashboard: dashboard,
      profile: profile,
    );
  }

  factory MoneyFlyAccountState.unavailable({
    required String message,
    required Map<String, dynamic> dashboard,
  }) {
    return MoneyFlyAccountState._(
      available: false,
      message: message,
      dashboard: dashboard,
    );
  }
}
