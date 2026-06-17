// lib/pages/chat_page.dart
//
// Écran de chat --- Ma Billetterie Sereine

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String ticketTitle;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.ticketTitle,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _otherUserName = 'Vendeur';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOtherUserName();
    _markAsRead();
  }

  Future<void> _loadOtherUserName() async {
    final name = await _chatService.getUserDisplayName(widget.otherUserId);
    if (mounted) {
      setState(() {
        _otherUserName = name;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead() async {
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (currentUserId != null) {
      await _chatService.markAsRead(
        conversationId: widget.conversationId,
        currentUserId: currentUserId,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (currentUserId == null) return;

    _messageController.clear();

    await _chatService.sendMessage(
      conversationId: widget.conversationId,
      senderId: currentUserId,
      text: text,
    );

    // Scroll vers le bas
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatMessageTime(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is! Timestamp) return '';

    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthProvider>(context).user?.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.premiumBlack,
        foregroundColor: AppTheme.goldSoft,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isLoading ? 'Chargement...' : _otherUserName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              widget.ticketTitle,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Liste des messages ────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.getMessages(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 60,
                          color: AppTheme.primaryGold.withOpacity(0.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Commencez la conversation',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Posez vos questions sur ce billet',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['senderId'] == currentUserId;
                    final text = msg['text']?.toString() ?? '';
                    final time = _formatMessageTime(msg['createdAt']);

                    return _MessageBubble(
                      text: text,
                      isMe: isMe,
                      time: time,
                    );
                  },
                );
              },
            ),
          ),

          // ── Barre de saisie ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Votre message...',
                        filled: true,
                        fillColor: AppTheme.ivoryBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bulle de message ───────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryGold : AppTheme.ivoryBackground,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 11,
                color: isMe ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}