import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/support_provider.dart';
import '../../services/websocket_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int ticketId;
  const ChatScreen({super.key, required this.ticketId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  SupportConversation? _chat;
  bool _isLoading = true;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadChat();
    WebSocketService().listenToChannel('chat.${widget.ticketId}', 'message.sent', _onNewMessage);
  }

  void _onNewMessage(dynamic data) {
    if (!mounted) return;
    try {
      final payload = data != null && data is Map ? (data['message'] ?? data) : null;
      if (payload != null && payload is Map) {
        final newMsg = SupportMessage.fromJson(Map<String, dynamic>.from(payload));
        setState(() {
          if (_chat != null) {
            final currentMsgs = _chat!.messages ?? [];
            final exists = currentMsgs.any((m) => m.id == newMsg.id);
            if (!exists) {
              _chat = SupportConversation(
                id: _chat!.id,
                subject: _chat!.subject,
                status: _chat!.status,
                updatedAt: _chat!.updatedAt,
                messagesCount: _chat!.messagesCount + 1,
                messages: [...currentMsgs, newMsg],
              );
            }
          } else {
            _chat = SupportConversation(
              id: widget.ticketId,
              subject: 'Support',
              status: 'open',
              updatedAt: DateTime.now().toIso8601String(),
              messagesCount: 1,
              messages: [newMsg],
            );
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error parsing live message: $e');
    }
  }

  @override
  void dispose() {
    WebSocketService().leaveChannel('chat.${widget.ticketId}');
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChat() async {
    try {
      final chat = await ref.read(supportProvider.notifier).loadChat(widget.ticketId);
      setState(() {
        _chat = chat;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    final msg = _messageController.text;
    _messageController.clear();
    
    try {
      await ref.read(supportProvider.notifier).replyToTicket(widget.ticketId, msg);
      await _loadChat();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send message')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_chat == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Failed to load chat')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_chat!.subject),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadChat)
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _chat!.messages?.length ?? 0,
              itemBuilder: (context, index) {
                final msg = _chat!.messages![index];
                final isMe = !msg.isAdmin; // In the app, admin is the "other" person
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Colors.grey[800],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                        bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isMe) Text(msg.userName, style: const TextStyle(fontSize: 10, color: Colors.blueAccent)),
                        Text(msg.message, style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_chat!.status == 'open')
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                      ),
                    )
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[900],
              child: const Text('This ticket is closed.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            )
        ],
      ),
    );
  }
}
