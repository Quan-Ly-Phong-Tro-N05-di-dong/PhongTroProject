// lib/features/contact/widgets/message_history_box.dart
import 'package:flutter/material.dart';

import '../models/contact_message.dart';

/// Khung "lịch sử trao đổi": thanh tiêu đề + các tin nhắn gần nhất.
class MessageHistoryBox extends StatelessWidget {
  final List<ContactMessage> messages;
  final String Function(String senderId) nameOf;
  final int maxItems;

  const MessageHistoryBox({
    super.key,
    required this.messages,
    required this.nameOf,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context) {
    final shown = messages.length > maxItems
        ? messages.sublist(messages.length - maxItems)
        : messages;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFE0E0E0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Trao đổi với chủ trọ',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Tin: ${messages.length}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chưa có tin nhắn nào.'),
            )
          else
            for (final m in shown)
              _MessageRow(
                name: nameOf(m.senderId),
                text: m.text,
                time: m.createdAt,
              ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final String name;
  final String text;
  final DateTime? time;

  const _MessageRow({
    required this.name,
    required this.text,
    required this.time,
  });

  String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final sentAt = time;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFD0D0D0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_circle, size: 36, color: Color(0xFF555555)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (sentAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                _hm(sentAt),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}
