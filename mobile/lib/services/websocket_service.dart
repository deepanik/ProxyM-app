import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/services/api_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  PusherChannelsClient? client;
  StreamSubscription? _connectionSub;
  final Map<String, PrivateChannel> _channels = {};
  final Map<String, StreamSubscription> _eventSubs = {};
  String? _token;

  Future<void> init(String token) async {
    if (client != null && _token == token) return;
    _token = token;

    try {
      final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
      final options = PusherChannelsOptions.fromHost(
        scheme: 'ws',
        host: host,
        port: 8080,
        key: 'reverb_key_local',
        shouldSupplyMetadataQueries: true,
      );

      client = PusherChannelsClient.websocket(
        options: options,
        connectionErrorHandler: (exception, trace, refresh) {
          print('[WS Error] $exception');
          refresh();
        },
      );

      _connectionSub?.cancel();
      _connectionSub = client?.onConnectionEstablished.listen((_) {
        print('[WS Connection Established]');
        _subscribeAllChannels();
      });

      client?.connect();
    } catch (e) {
      print('WebSocket Init Error: $e');
    }
  }

  void _subscribeAllChannels() {
    for (final channel in _channels.values) {
      try {
        print('[WS Subscribing] Channel: ${channel.name}');
        channel.subscribeIfNotUnsubscribed();
      } catch (e) {
        print('[WS Sub Error] $e');
      }
    }
  }

  Future<void> listenToChannel(String channelName, String eventName, Function(dynamic) callback) async {
    if (_token == null) {
      try {
        _token = await const FlutterSecureStorage().read(key: 'auth_token');
      } catch (_) {}
    }
    if (_token != null && client == null) {
      await init(_token!);
    }
    if (client == null) return;

    final fullChannel = channelName.startsWith('private-') ? channelName : 'private-$channelName';

    PrivateChannel? channel = _channels[fullChannel];
    if (channel == null) {
      channel = client!.privateChannel(
        fullChannel,
        authorizationDelegate: EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
          authorizationEndpoint: Uri.parse('${ApiService.baseUrl}/broadcasting/auth'),
          headers: {
            'Authorization': 'Bearer $_token',
            'Accept': 'application/json',
          },
        ),
      );
      _channels[fullChannel] = channel;
    }

    _subscribeAllChannels();

    final key = '$fullChannel:$eventName';
    _eventSubs[key]?.cancel();
    _eventSubs[key] = channel.bindToAll().listen((event) {
      final name = event.name;
      print('[Flutter WS Event Received] ${event.channelName} -> $name: ${event.data}');
      if (name == eventName || name == '.$eventName' || name.endsWith(eventName) || name.contains('MessageSent')) {
        dynamic data = event.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (_) {}
        }
        callback(data);
      }
    });
  }

  void leaveChannel(String channelName) {
    final fullChannel = channelName.startsWith('private-') ? channelName : 'private-$channelName';
    _channels[fullChannel]?.unsubscribe();
    _channels.remove(fullChannel);

    _eventSubs.removeWhere((key, sub) {
      if (key.startsWith('$fullChannel:')) {
        sub.cancel();
        return true;
      }
      return false;
    });
  }

  void disconnect() {
    _connectionSub?.cancel();
    for (final sub in _eventSubs.values) {
      sub.cancel();
    }
    _eventSubs.clear();
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    _channels.clear();
    client?.dispose();
    client = null;
    _token = null;
  }
}
