import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../services/chat_service.dart';
import 'chat_detail_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, this.role});

  final String? role;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  int _streamVersion = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterChats(List<Map<String, dynamic>> chats) {
    if (_searchText.isEmpty) {
      return chats;
    }

    return chats.where((chat) {
      final otherName = _chatService.getOtherParticipantName(chat);
      final jobTitle = chat['jobTitle'] as String? ?? '';
      final lastMessage = chat['lastMessage'] as String? ?? '';
      final searchable = '$otherName $jobTitle $lastMessage'.toLowerCase();
      return searchable.contains(_searchText);
    }).toList();
  }

  void _retry() {
    setState(() {
      _streamVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.horizontal,
            vertical: AppSpacing.vertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _MessagesHeader(),
              const SizedBox(height: 18),
              _SearchField(controller: _searchController),
              const SizedBox(height: 18),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  key: ValueKey(_streamVersion),
                  stream: _chatService.watchUserChats(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.coralAccent,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return _MessagesErrorView(onRetry: _retry);
                    }

                    final chats = _filterChats(snapshot.data ?? []);
                    if (chats.isEmpty) {
                      return _MessagesEmptyView(
                        isSearching: _searchText.isNotEmpty,
                      );
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: chats.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 220 + index * 40),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 16 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: _ChatCard(
                            chat: chat,
                            chatService: _chatService,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatDetailPage(
                                    chatId: chat['chatId'] as String,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesHeader extends StatelessWidget {
  const _MessagesHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Messages',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Chat with your matched workers and businesses.',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: AppColors.coralAccent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.coralAccent.withValues(alpha: 0.35),
            ),
          ),
          child: const Icon(Icons.forum_outlined, color: AppColors.coralAccent),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppTextStyles.input,
      cursorColor: AppColors.coralAccent,
      decoration: InputDecoration(
        hintText: 'Search conversations',
        hintStyle: AppTextStyles.hint,
        prefixIcon: const Icon(Icons.search, color: AppColors.lightText),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close, color: AppColors.lightText),
              ),
        filled: true,
        fillColor: AppColors.surface.withValues(alpha: 0.82),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.coralAccent, width: 2),
        ),
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  const _ChatCard({
    required this.chat,
    required this.chatService,
    required this.onTap,
  });

  final Map<String, dynamic> chat;
  final ChatService chatService;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final otherName = chatService.getOtherParticipantName(chat);
    final otherImage = chatService.getOtherParticipantImage(chat);
    final unreadCount = chatService.getUnreadCount(chat);
    final hasUnread = unreadCount > 0;
    final jobTitle = chat['jobTitle'] as String? ?? 'Matched job';
    final lastMessage = chat['lastMessage'] as String? ?? '';
    final preview = lastMessage.trim().isEmpty
        ? 'No messages yet - start the conversation'
        : lastMessage.trim();
    final timestamp =
        chat['lastMessageAt'] ?? chat['updatedAt'] ?? chat['createdAt'];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: hasUnread
            ? AppColors.surface.withValues(alpha: 0.98)
            : AppColors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasUnread
              ? AppColors.coralAccent.withValues(alpha: 0.65)
              : AppColors.border,
          width: hasUnread ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: hasUnread ? 0.22 : 0.12),
            blurRadius: hasUnread ? 18 : 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: hasUnread ? 5 : 0,
                  decoration: const BoxDecoration(
                    color: AppColors.coralAccent,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(18),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        _Avatar(imageUrl: otherImage, name: otherName),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      otherName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.white,
                                        fontSize: 16,
                                        fontWeight: hasUnread
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatChatTime(timestamp),
                                    style: TextStyle(
                                      color: hasUnread
                                          ? AppColors.coralAccent
                                          : AppColors.lightText,
                                      fontSize: 12,
                                      fontWeight: hasUnread
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                jobTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.coralAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      preview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: hasUnread
                                            ? AppColors.white
                                            : AppColors.lightText,
                                        fontSize: 14,
                                        fontWeight: hasUnread
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (hasUnread) ...[
                                    const SizedBox(width: 10),
                                    _UnreadBadge(count: unreadCount),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.imageUrl, required this.name});

  final String imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'W' : name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: 26,
      backgroundColor: AppColors.coralAccent.withValues(alpha: 0.18),
      backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
      child: imageUrl.isEmpty
          ? Text(
              initial,
              style: const TextStyle(
                color: AppColors.coralAccent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.coralAccent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.navyBg,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MessagesEmptyView extends StatelessWidget {
  const _MessagesEmptyView({required this.isSearching});

  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.forum_outlined,
              color: AppColors.coralAccent,
              size: 52,
            ),
            const SizedBox(height: 18),
            Text(
              isSearching ? 'No conversations found' : 'No conversations yet',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isSearching
                  ? 'Try searching by name, job, or message.'
                  : 'When a match is created, your chat will appear here.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesErrorView extends StatelessWidget {
  const _MessagesErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.coralAccent,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load your messages.',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: AppButtonStyles.primary(foregroundColor: AppColors.navyBg),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatChatTime(Object? value) {
  if (value is! Timestamp) {
    return '';
  }

  final date = value.toDate();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(date.year, date.month, date.day);
  final yesterday = today.subtract(const Duration(days: 1));

  if (messageDay == today) {
    return '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
  }
  if (messageDay == yesterday) {
    return 'Yesterday';
  }

  return '${_twoDigits(date.day)}/${_twoDigits(date.month)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
