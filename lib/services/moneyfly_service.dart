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

  static Future<Profile?> syncSubscription(WidgetRef ref) {
    return _syncSubscription(ref);
  }

  static Future<Profile?> syncSubscriptionFromContainer(
    ProviderContainer container,
  ) {
    return _syncSubscription(container);
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

  static Future<Profile?> _syncSubscription(dynamic container) async {
    final subscriptionUrl = await ApiService().getSubscriptionUrl();
    if (subscriptionUrl == null || subscriptionUrl.isEmpty) return null;

    final profiles = List<Profile>.from(container.read(profilesProvider));
    final existingProfile = profiles.where(_isMoneyFlyProfile).firstOrNull;
    final sourceProfile = existingProfile ??
        Profile.normal(label: profileLabel, url: subscriptionUrl);
    final profile = await sourceProfile
        .copyWith(label: profileLabel, url: subscriptionUrl)
        .update();
    container.read(profilesProvider.notifier).put(profile);
    container.read(currentProfileIdProvider.notifier).value = profile.id;
    container.read(setupActionProvider.notifier).applyProfileDebounce(
          force: true,
          silence: true,
        );
    return profile;
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
}
