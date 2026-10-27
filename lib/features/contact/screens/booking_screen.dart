// lib/features/contact/screens/booking_screen.dart
import 'package:flutter/material.dart';

import '../models/contact_models.dart';
import '../services/interaction_service.dart';
import '../widgets/interaction_ui.dart';
import '../widgets/room_summary_card.dart';
import 'booking_success_screen.dart';

/// Màn "Đặt lịch xem phòng" (người thuê).
class BookingScreen extends StatefulWidget {
  final String roomId;

  const BookingScreen({super.key, required this.roomId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final InteractionService _service = InteractionService.instance;
  late DateTime _date;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 30);
  late final TextEditingController _phone;
  final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = _service.now();
    _date = DateTime(now.year, now.month, now.day + 1);
    _phone = TextEditingController(text: _service.currentUser.phone);
  }

  @override
  void dispose() {
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = _service.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  void _submit() {
    final time = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    Appointment? created;
    final ok = runAction(context, () {
      created = _service.book(
        roomId: widget.roomId,
        time: time,
        phone: _phone.text,
        note: _note.text,
      );
    });
    final appointment = created;
    if (ok && appointment != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (ctx) => BookingSuccessScreen(appointmentId: appointment.id),
        ),
      );
    }
  }

  InputDecoration _decoration({IconData? icon, String? hint}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _service.rooms[widget.roomId];
    return Scaffold(
      backgroundColor: IStyle.background,
      appBar: AppBar(
        title: const Text('Đặt lịch xem phòng'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (room != null) RoomSummaryCard(room: room),
                  const SizedBox(height: 16),
                  _Field(
                    label: 'Ngày xem phòng',
                    child: _PickerTile(
                      icon: Icons.calendar_today_outlined,
                      text: fmtDate(_date),
                      onTap: _pickDate,
                    ),
                  ),
                  _Field(
                    label: 'Thời gian',
                    child: _PickerTile(
                      icon: Icons.access_time,
                      text: fmtHm(_time.hour, _time.minute),
                      onTap: _pickTime,
                    ),
                  ),
                  _Field(
                    label: 'Số điện thoại',
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: _decoration(icon: Icons.phone_outlined),
                    ),
                  ),
                  _Field(
                    label: 'Ghi chú',
                    child: TextField(
                      controller: _note,
                      maxLines: 3,
                      decoration: _decoration(
                        hint: 'Nhập lời nhắn cho chủ trọ...',
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.schedule, color: IStyle.warning),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trạng thái dự kiến',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: IStyle.muted,
                                ),
                              ),
                              Text(
                                'Chờ chủ trọ phản hồi',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Chờ xác nhận',
                          style: TextStyle(
                            color: IStyle.warning,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: IStyle.primary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Thông tin của bạn chỉ được chia sẻ với chủ trọ để xác nhận lịch hẹn.',
                          style: TextStyle(fontSize: 12, color: IStyle.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SafeArea(
              top: false,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.event_available),
                label: const Text('Xác nhận đặt lịch'),
                style: FilledButton.styleFrom(
                  backgroundColor: IStyle.primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;

  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IStyle.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: IStyle.muted),
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
