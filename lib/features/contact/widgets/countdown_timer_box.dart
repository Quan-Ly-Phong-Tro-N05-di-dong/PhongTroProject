// lib/features/contact/widgets/countdown_timer_box.dart
import 'dart:async';

import 'package:flutter/material.dart';

/// Khung đồng hồ đếm ngược HH:MM:SS tới thời điểm [target]. Tự cập nhật mỗi giây.
class CountdownTimerBox extends StatefulWidget {
  final DateTime target;
  final String label;

  const CountdownTimerBox({
    super.key,
    required this.target,
    this.label = 'Còn lại đến giờ xem phòng',
  });

  @override
  State<CountdownTimerBox> createState() => _CountdownTimerBoxState();
}

class _CountdownTimerBoxState extends State<CountdownTimerBox> {
  Timer? _timer;
  late Duration _left;

  @override
  void initState() {
    super.initState();
    _left = _remaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _left = _remaining());
      if (_left == Duration.zero) timer.cancel();
    });
  }

  Duration _remaining() {
    final diff = widget.target.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final text =
        '${_two(_left.inHours)}:'
        '${_two(_left.inMinutes.remainder(60))}:'
        '${_two(_left.inSeconds.remainder(60))}';
    final label = _left == Duration.zero ? 'Đã đến giờ hẹn' : widget.label;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
