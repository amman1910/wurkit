import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_ui.dart';
import '../../jobs/screens/job_details_page.dart';
import '../services/chat_service.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _canSend = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chatService.markChatAsRead(widget.chatId);
    _messageController.addListener(() {
      final canSend = _messageController.text.trim().isNotEmpty;
      if (canSend != _canSend) {
        setState(() {
          _canSend = canSend;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (!_canSend || _isSending) {
      return;
    }

    final text = _messageController.text;
    setState(() {
      _isSending = true;
    });

    try {
      await _chatService.sendMessage(chatId: widget.chatId, text: text);
      _messageController.clear();
      HapticFeedback.lightImpact();
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not send message. Please try again.'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .snapshots(),
          builder: (context, chatSnapshot) {
            final chat = chatSnapshot.data?.data();

            if (chatSnapshot.hasError) {
              return const _ChatErrorView();
            }

            if (chatSnapshot.connectionState == ConnectionState.waiting &&
                chat == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.coralAccent),
              );
            }

            if (chat == null) {
              return const _ChatErrorView();
            }

            final isActive = chat['isActive'] as bool? ?? true;

            return Column(
              children: [
                _ChatHeader(chat: chat, chatService: _chatService),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _chatService.watchMessages(widget.chatId),
                    builder: (context, messageSnapshot) {
                      if (messageSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !messageSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.coralAccent,
                          ),
                        );
                      }

                      if (messageSnapshot.hasError) {
                        return const _MessagesLoadError();
                      }

                      final messages = messageSnapshot.data ?? [];
                      if (messages.isNotEmpty) {
                        _chatService.markChatAsRead(widget.chatId);
                      }
                      _scrollToBottom();

                      if (messages.isEmpty) {
                        return const _EmptyConversationView();
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 10 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: _MessageBubble(
                              message: messages[index],
                              showTopSpace: index > 0,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                _MessageInputBar(
                  controller: _messageController,
                  isActive: isActive,
                  canSend: _canSend,
                  isSending: _isSending,
                  onSend: _sendMessage,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.chat, required this.chatService});

  final Map<String, dynamic> chat;
  final ChatService chatService;

  @override
  Widget build(BuildContext context) {
    final otherName = chatService.getOtherParticipantName(chat);
    final otherImage = chatService.getOtherParticipantImage(chat);
    final jobTitle = chat['jobTitle'] as String? ?? 'Matched job';
    final jobId = chat['jobId'] as String?;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openJobDetails(context, jobId),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(8, 10, 18, 16),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            border: const Border(bottom: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: AppColors.white),
              ),
              _HeaderAvatar(imageUrl: otherImage, name: otherName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      otherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      jobTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.coralAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Matched conversation',
                      style: TextStyle(
                        color: AppColors.lightText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.lightText,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openJobDetails(BuildContext context, String? jobId) {
    if (jobId == null || jobId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job details are not available')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailsPage(jobId: jobId, openedFromChat: true),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.imageUrl, required this.name});

  final String imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'W' : name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.coralAccent.withValues(alpha: 0.18),
      backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
      child: imageUrl.isEmpty
          ? Text(
              initial,
              style: const TextStyle(
                color: AppColors.coralAccent,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.showTopSpace});

  final Map<String, dynamic> message;
  final bool showTopSpace;

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final senderId = message['senderId'] as String?;
    final isMine = senderId == currentUserId;
    final isDeleted = message['isDeleted'] as bool? ?? false;
    final text = isDeleted
        ? 'Message deleted'
        : (message['text'] as String? ?? '').trim();
    final createdAt = message['createdAt'];

    return Padding(
      padding: EdgeInsets.only(top: showTopSpace ? 10 : 0),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isMine ? AppColors.coralAccent : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 5),
                bottomRight: Radius.circular(isMine ? 5 : 18),
              ),
              border: isMine
                  ? null
                  : Border.all(color: AppColors.border.withValues(alpha: 0.8)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text.isEmpty ? ' ' : text,
                    style: TextStyle(
                      color: isMine ? AppColors.navyBg : AppColors.white,
                      fontSize: 15.5,
                      fontStyle: isDeleted
                          ? FontStyle.italic
                          : FontStyle.normal,
                      fontWeight: isMine ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatMessageTime(createdAt),
                    style: TextStyle(
                      color: isMine
                          ? AppColors.navyBg.withValues(alpha: 0.72)
                          : AppColors.lightText,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  const _MessageInputBar({
    required this.controller,
    required this.isActive,
    required this.canSend,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isActive;
  final bool canSend;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? 8 : 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.navyBg,
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.65)),
          ),
        ),
        child: isActive
            ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      style: AppTextStyles.input,
                      cursorColor: AppColors.coralAccent,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: AppTextStyles.hint,
                        filled: true,
                        fillColor: AppColors.surface.withValues(alpha: 0.9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: AppColors.coralAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: ElevatedButton(
                      onPressed: canSend && !isSending ? onSend : null,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                        backgroundColor: AppColors.coralAccent,
                        foregroundColor: AppColors.navyBg,
                        disabledBackgroundColor: AppColors.surface.withValues(
                          alpha: 0.9,
                        ),
                      ),
                      child: isSending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.navyBg,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 22),
                    ),
                  ),
                ],
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'This conversation is closed.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body,
                ),
              ),
      ),
    );
  }
}

class _EmptyConversationView extends StatelessWidget {
  const _EmptyConversationView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              color: AppColors.coralAccent,
              size: 52,
            ),
            SizedBox(height: 16),
            Text(
              'Start the conversation',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Send a message to coordinate the shift.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesLoadError extends StatelessWidget {
  const _MessagesLoadError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Could not load messages.', style: AppTextStyles.body),
    );
  }
}

class _ChatErrorView extends StatelessWidget {
  const _ChatErrorView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Could not load this conversation.',
              style: AppTextStyles.body,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatMessageTime(Object? value) {
  if (value is! Timestamp) {
    return '';
  }

  final date = value.toDate();
  return '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
