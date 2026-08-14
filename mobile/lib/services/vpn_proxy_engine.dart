import 'package:flutter/services.dart';
import '../models/proxy_entry.dart';

class VpnProxyEngine {
  static const MethodChannel _channel = MethodChannel('com.proxym/vpn');

  static Future<bool> startVpn(ProxyEntry proxy) async {
    try {
      final bool success = await _channel.invokeMethod('startVpn', {
        'host': proxy.host,
        'port': proxy.port,
        'protocol': proxy.protocol.name,
        'username': proxy.username,
        'password': proxy.password,
      });
      return success;
    } on PlatformException catch (e) {
      print('VPN Start Error: ${e.message}');
      return false;
    }
  }

  static Future<void> stopVpn() async {
    try {
      await _channel.invokeMethod('stopVpn');
    } on PlatformException catch (e) {
      print('VPN Stop Error: ${e.message}');
    }
  }

  static Future<bool> isPrepared() async {
    try {
      final bool res = await _channel.invokeMethod('isPrepared');
      return res;
    } catch (_) {
      return false;
    }
  }
}
