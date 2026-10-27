// lib/features/contact/screens/conversations_tab.dart
import 'package:flutter/material.dart';

import '../models/contact_models.dart';
import '../services/interaction_service.dart';
import '../widgets/interaction_ui.dart';
import 'contact_chat_screen.dart';

/// Danh sách cuộc trò chuyện của người dùng hiện tại.
/// Chủ trọ thấy các tin nhận được (chấm xanh = chưa xem); người thuê thấy các chủ trọ mình đã nhắn.
class ConversationsTab extends StatelessWidget {
  const ConversationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, child) {
        final list = s.contactsForCurrentUser();
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.chat_bubble_outline,
            message: s.role == UserRole.tenant
                ? 'Bạn chưa nhắn tin cho chủ trọ nào.\nVào chi tiết phòng và bấm "Liên hệ".'
                : 'Chưa có tin nhắn nào.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              _ConversationTile(contact: list[index]),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Contact contact;

  const _ConversationTile({required this.contact});

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    final isOwner = s.role == UserRole.owner;
    final peer = s.userById(
      isOwner ? contact.tenantId : s.ownerOf(contact.roomId),
    );
    final room = s.rooms[contact.roomId];
    final last = contact.lastMessage;
    final unread = isOwner && contact.isUnreadForOwner;
    final now = s.now();
    final when = s.lastActivity(contact);
    final sameDay =
        when.year == now.year && when.month == now.month && when.day == now.day;
    final preview = last == null
        ? ''
        : (last.senderId == s.currentUser.id ? 'Bạn: ${last.text}' : last.text);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (ctx) => ContactChatScreen(contactId: contact.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: cardDecoration(),
        child: Row(
          children: [
            InitialsAvatar(name: peer?.name ?? '?'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          peer?.name ?? 'Người dùng',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        sameDay ? fmtTime(when) : fmtDateShort(when),
                        style: const TextStyle(
                          fontSize: 12,
                          color: IStyle.muted,
                        ),
                      ),
                    ],
                  ),
                  if (room != null)
                    Text(
                      room.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: IStyle.primary,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unread ? Colors.black87 : IStyle.muted,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: IStyle.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
