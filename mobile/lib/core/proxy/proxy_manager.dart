import '../../models/proxy_entry.dart';
import '../../models/bypass_rule.dart';
import '../../services/vpn_proxy_engine.dart';
import 'circuit_breaker.dart';
import 'bypass_manager.dart';
import 'diagnostics_logger.dart';

class ProxyManager {
  static final ProxyManager instance = ProxyManager._internal();
  ProxyManager._internal();

  final Map<String, ProxyCircuitBreaker> _circuitBreakers = {};
  final DiagnosticsLogger _logger = DiagnosticsLogger.instance;

  ProxyEntry? _activeProxy;
  List<BypassRule> _bypassRules = [];
  bool _isEnabled = false;

  ProxyEntry? get activeProxy => _activeProxy;
  bool get isEnabled => _isEnabled;

  ProxyCircuitBreaker getCircuitBreaker(String proxyId) {
    return _circuitBreakers.putIfAbsent(proxyId, () => ProxyCircuitBreaker());
  }

  Future<void> updateConfig({
    required bool enabled,
    ProxyEntry? activeProxy,
    List<BypassRule>? bypassRules,
  }) async {
    _isEnabled = enabled;
    _activeProxy = activeProxy;
    if (bypassRules != null) {
      _bypassRules = bypassRules;
    }

    _logger.info('ProxyManager', 'Updating proxy configuration', {
      'enabled': enabled,
      'activeProxy': activeProxy?.raw,
      'bypassRulesCount': _bypassRules.length,
    });

    if (enabled && activeProxy != null) {
      final breaker = getCircuitBreaker(activeProxy.id);
      if (breaker.isAvailable) {
        final success = await VpnProxyEngine.startVpn(activeProxy);
        if (success) {
          _logger.info('ProxyManager', 'Tunnel started for ${activeProxy.host}:${activeProxy.port}');
        } else {
          _logger.error('ProxyManager', 'Failed to start tunnel for ${activeProxy.host}:${activeProxy.port}');
          breaker.onFailure();
        }
      } else {
        _logger.warn('ProxyManager', 'Circuit breaker open for ${activeProxy.id}, skipping activation');
      }
    } else {
      await VpnProxyEngine.stopVpn();
      _logger.info('ProxyManager', 'Tunnel stopped');
    }
  }

  void reportProxySuccess(String proxyId) {
    getCircuitBreaker(proxyId).onSuccess();
    _logger.info('ProxyManager', 'Proxy $proxyId marked healthy');
  }

  void reportProxyFailure(String proxyId, String reason) {
    final breaker = getCircuitBreaker(proxyId);
    breaker.onFailure();
    _logger.warn('ProxyManager', 'Proxy $proxyId failed: $reason', {
      'state': breaker.state.name,
    });
  }

  bool shouldBypass(String host) {
    final manager = BypassManager(_bypassRules);
    return manager.shouldBypass(host);
  }
}
