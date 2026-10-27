// lib/features/contact/screens/contact_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/contact_models.dart';
import '../services/interaction_service.dart';
import '../widgets/interaction_ui.dart';
import 'booking_screen.dart';

const String _quickReply = 'Tôi muốn đặt lịch xem phòng';

/// Màn nhắn tin giữa người thuê và chủ trọ về một phòng.
///
/// - Người thuê mở từ nút "Liên hệ" ở trang chi tiết phòng: truyền [roomId]
///   (chưa nhắn lần nào thì cuộc trò chuyện chỉ được tạo khi gửi tin đầu tiên).
/// - Chủ trọ (hoặc người thuê) mở từ danh sách tin nhắn: truyền [contactId].
///
/// Tin nhắn lưu trong bộ nhớ, chưa có thời gian thực.
class ContactChatScreen extends StatefulWidget {
  final String? roomId;
  final String? contactId;

  const ContactChatScreen({super.key, this.roomId, this.contactId})
    : assert(roomId != null || contactId != null, 'Cần roomId hoặc contactId');

  @override
  State<ContactChatScreen> createState() => _ContactChatScreenState();
}

class _ContactChatScreenState extends State<ContactChatScreen> {
  final InteractionService _service = InteractionService.instance;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  Contact? get _contact {
    final id = widget.contactId;
    if (id != null) return _service.contacts.findById(id);
    return _service.findContact(
      roomId: widget.roomId!,
      tenantId: _service.currentUser.id,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contact = _contact;
      if (contact != null) _service.markContactRead(contact.id);
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final contact = _contact;
    final roomId = widget.roomId;
    if (contact == null && roomId == null) return;

    final ok = runAction(context, () {
      if (contact == null) {
        _service.sendToOwner(roomId: roomId!, text: text);
      } else {
        _service.sendMessage(contact.id, text);
      }
    });
    if (ok) {
      _input.clear();
      _scrollToEnd();
    }
  }

  void _useQuickReply() {
    _input.text = _quickReply;
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, child) {
        final isTenant = _service.role == UserRole.tenant;
        final contact = _contact;
        final roomId = contact?.roomId ?? widget.roomId;
        final room = roomId == null ? null : _service.rooms[roomId];
        final peerId = isTenant
            ? (roomId == null ? null : _service.ownerOf(roomId))
            : contact?.tenantId;
        final peer = _service.userById(peerId);
        final messages = contact?.messages ?? const <ContactMessage>[];
        final now = _service.now();

        return Scaffold(
          backgroundColor: IStyle.background,
          appBar: AppBar(
            title: Text(isTenant ? 'Liên hệ chủ trọ' : 'Tin nhắn'),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
          ),
          body: Column(
            children: [
              _PeerHeader(
                peer: peer,
                peerIsOwner: isTenant,
                roomTitle: room?.title,
              ),
              Expanded(
                child: messages.isEmpty
                    ? const EmptyState(
                        icon: Icons.chat_bubble_outline,
                        message: 'Chưa có tin nhắn nào.\nHãy nhắn tin đầu tiên để hỏi về phòng này.',
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return _Bubble(
                            message: message,
                            mine: message.senderId == _service.currentUser.id,
                            now: now,
                          );
                        },
                      ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isTenant)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ActionChip(
                            label: const Text(_quickReply),
                            labelStyle: const TextStyle(
                              color: IStyle.primary,
                              fontSize: 13,
                            ),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: IStyle.primary),
                            onPressed: _useQuickReply,
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              minLines: 1,
                              maxLines: 3,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: InputDecoration(
                                hintText: 'Nhập tin nhắn...',
                                filled: true,
                                fillColor: IStyle.background,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _send,
                            icon: const Icon(Icons.send_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: IStyle.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      if (isTenant && roomId != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (ctx) => BookingScreen(roomId: roomId),
                              ),
                            ),
                            icon: const Icon(Icons.event_available),
                            label: const Text('Đặt lịch xem phòng'),
                            style: FilledButton.styleFrom(
                              backgroundColor: IStyle.primary,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dải thông tin người đang trò chuyện cùng (chủ trọ hoặc người thuê).
class _PeerHeader extends StatelessWidget {
  final DemoUser? peer;
  final bool peerIsOwner;
  final String? roomTitle;

  const _PeerHeader({
    required this.peer,
    required this.peerIsOwner,
    required this.roomTitle,
  });

  @override
  Widget build(BuildContext context) {
    final user = peer;
    final name = user?.name ?? 'Người dùng';
    final phone = user?.phone ?? '';
    final subtitle = [
      if (phone.isNotEmpty) phone,
      peerIsOwner ? 'Chủ trọ' : 'Người thuê',
    ].join(' · ');
    final title = roomTitle;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: name, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (peerIsOwner)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.verified_outlined,
                              size: 16,
                              color: IStyle.primary,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: IStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (phone.isNotEmpty)
                IconButton(
                  tooltip: 'Sao chép số điện thoại',
                  icon: const Icon(Icons.copy_outlined, color: IStyle.primary),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã sao chép số điện thoại'),
                      ),
                    );
                  },
                ),
            ],
          ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Về phòng: $title',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: IStyle.muted),
              ),
            ),
        ],
      ),
    );
  }
}

String _stamp(DateTime? time, DateTime now) {
  if (time == null) return '';
  final sameDay =
      time.year == now.year && time.month == now.month && time.day == now.day;
  return sameDay
      ? 'Hôm nay, ${fmtTime(time)}'
      : '${fmtDateShort(time)}, ${fmtTime(time)}';
}

class _Bubble extends StatelessWidget {
  final ContactMessage message;
  final bool mine;
  final DateTime now;

  const _Bubble({required this.message, required this.mine, required this.now});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.75;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mine ? IStyle.primary : Colors.white,
              border: mine ? null : Border.all(color: IStyle.border),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: mine ? Colors.white : Colors.black87,
                height: 1.35,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, bottom: 10),
            child: Text(
              _stamp(message.createdAt, now),
              style: const TextStyle(fontSize: 11, color: IStyle.muted),
            ),
          ),
        ],
      ),
    );
  }
}
