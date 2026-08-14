import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class SupportMessage {
  final int id;
  final String message;
  final String createdAt;
  final String userName;
  final bool isAdmin;

  SupportMessage({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.userName,
    required this.isAdmin,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return SupportMessage(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      message: json['message']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      userName: user != null && user is Map && user['name'] != null ? user['name'].toString() : 'Support',
      isAdmin: user != null && user is Map ? (user['is_admin'] == 1 || user['is_admin'] == true || user['is_admin'] == '1') : false,
    );
  }
}

class SupportConversation {
  final int id;
  final String subject;
  final String status;
  final String updatedAt;
  final int messagesCount;
  final List<SupportMessage>? messages;

  SupportConversation({
    required this.id,
    required this.subject,
    required this.status,
    required this.updatedAt,
    required this.messagesCount,
    this.messages,
  });

  factory SupportConversation.fromJson(Map<String, dynamic> json) {
    return SupportConversation(
      id: json['id'],
      subject: json['subject'],
      status: json['status'],
      updatedAt: json['updated_at'],
      messagesCount: json['messages_count'] ?? 0,
      messages: json['messages'] != null 
        ? (json['messages'] as List).map((m) => SupportMessage.fromJson(m)).toList() 
        : null,
    );
  }
}

final supportProvider = NotifierProvider<SupportNotifier, List<SupportConversation>>(() {
  return SupportNotifier();
});

class SupportNotifier extends Notifier<List<SupportConversation>> {
  final _apiService = ApiService();

  @override
  List<SupportConversation> build() {
    fetchTickets();
    return [];
  }

  Future<void> fetchTickets() async {
    try {
      final response = await _apiService.client.get('/support');
      final List<dynamic> data = response.data;
      state = data.map((item) => SupportConversation.fromJson(item)).toList();
    } catch (e) {
      print('Failed to fetch support tickets: $e');
    }
  }

  Future<void> createTicket(String subject, String message) async {
    try {
      await _apiService.client.post('/support', data: {'subject': subject, 'message': message});
      fetchTickets();
    } catch (e) {
      print('Failed to create ticket: $e');
      rethrow;
    }
  }

  Future<SupportConversation> loadChat(int id) async {
    final response = await _apiService.client.get('/support/$id');
    return SupportConversation.fromJson(response.data);
  }

  Future<void> replyToTicket(int id, String message) async {
    try {
      await _apiService.client.post('/support/$id/reply', data: {'message': message});
      // Optionally trigger a re-fetch of tickets so the "last updated" goes to top
      fetchTickets();
    } catch (e) {
      print('Failed to reply: $e');
      rethrow;
    }
  }

  Future<List<String>> fetchTopics() async {
    try {
      final response = await _apiService.client.get('/support-topics');
      final List<dynamic> data = response.data;
      return data.map((e) => e.toString()).toList();
    } catch (e) {
      return [
        'Proxy Connection Failing',
        'Slow Proxy Speed / High Latency',
        'IP Whitelist & Authentication Request',
        'Extension & App Integration Bug',
      ];
    }
  }
}
