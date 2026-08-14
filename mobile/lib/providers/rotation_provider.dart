import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../models/proxy_entry.dart';
import '../models/rotation_config.dart';
import 'settings_provider.dart';

/// Select next proxy based on current mode, pool filtering, failure skipping, and cooldown.
/// Direct port of rotationEngine.ts `pickNext()` (lines 23-87).
ProxyEntry? pickNext(AppSettings settings) {
  final proxies = settings.proxies;
  final activeProxyId = settings.activeProxyId;
  final rotation = settings.rotation;
  final autoDetect = settings.autoDetect;

  if (proxies.isEmpty) return null;

  // 1. Filter out flagged/failed proxies if autoSkipFlagged or skipFailed is enabled
  var pool = proxies.where((p) {
    if (!autoDetect.autoSkipFlagged) return true;
    final status = p.testResult?.status;
    if (status == null || status == ProxyTestStatus.untested || status == ProxyTestStatus.ok) {
      return true;
    }
    if (status == ProxyTestStatus.dead || status == ProxyTestStatus.blocked) {
      return false;
    }
    return !rotation.skipFailed;
  }).toList();

  // 2. Cooldown filter: exclude proxies used within cooldownMinutes
  if (rotation.cooldownMinutes > 0) {
    final cutoff = DateTime.now().millisecondsSinceEpoch - (rotation.cooldownMinutes * 60000);
    final cooled = pool.where((p) => p.lastUsed == null || p.lastUsed! < cutoff).toList();
    // Only apply cooldown if there are other candidates besides current active
    if (cooled.any((p) => p.id != activeProxyId)) {
      pool = cooled;
    }
  }

  // Fallback to full list if pool became empty
  if (pool.isEmpty) pool = List.from(proxies);

  final currentIndex = pool.indexWhere((p) => p.id == activeProxyId);

  // 3. Selection mode decision
  switch (rotation.mode) {
    case RotationMode.roundRobin:
      return pool[(currentIndex + 1) % pool.length];

    case RotationMode.random:
      final candidates = pool.where((p) => p.id != activeProxyId).toList();
      final src = candidates.isNotEmpty ? candidates : pool;
      return src[Random().nextInt(src.length)];

    case RotationMode.weighted:
      final totalWeight = pool.fold<int>(0, (sum, p) => sum + (p.weight ?? 1));
      if (totalWeight <= 0) return pool.first;
      var r = Random().nextDouble() * totalWeight;
      for (final p in pool) {
        r -= (p.weight ?? 1);
        if (r <= 0) return p;
      }
      return pool.first;

    case RotationMode.sticky:
      final currentProxy = proxies.where((p) => p.id == activeProxyId).firstOrNull;
      if (currentProxy?.lastUsed != null) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - currentProxy!.lastUsed!;
        if (elapsed < rotation.stickySessionMinutes * 60000) {
          return currentProxy;
        }
      }
      return pool[(currentIndex + 1) % pool.length];
  }
}

final rotationProvider = NotifierProvider<RotationNotifier, void>(() {
  return RotationNotifier();
});

class RotationNotifier extends Notifier<void> {
  Timer? _timer;

  @override
  void build() {
    ref.listen<AppSettings>(settingsProvider, (prev, next) {
      if (next.enabled && next.rotation.trigger == RotationTrigger.time) {
        scheduleRotation(next.rotation.intervalMinutes);
      } else {
        cancelRotation();
      }
    });

    ref.onDispose(() {
      _timer?.cancel();
    });
  }

  void scheduleRotation(int intervalMinutes) {
    _timer?.cancel();
    if (intervalMinutes <= 0) return;
    _timer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => rotateNow(),
    );
  }

  void cancelRotation() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> rotateNow() async {
    final settings = ref.read(settingsProvider);
    if (!settings.enabled || settings.proxies.isEmpty) return;

    final next = pickNext(settings);
    if (next == null || next.id == settings.activeProxyId) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Stamp lastUsed on the current proxy being rotated away from
    final updatedProxies = settings.proxies.map((p) {
      if (p.id == settings.activeProxyId) {
        return p.copyWith(lastUsed: now);
      }
      return p;
    }).toList();

    await ref.read(settingsProvider.notifier).update(
          activeProxyId: next.id,
          proxies: updatedProxies,
        );
  }
}
