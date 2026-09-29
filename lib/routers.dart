// lib/routes.dart
import 'package:flutter/material.dart';
import 'core/main_screen.dart';

class AppRoutes {
  // Đặt màn hình mặc định khởi động ứng dụng
  static const String root = '/';
  static Map<String, WidgetBuilder> get routes => {
    AppRoutes.root: (context) => const MainScreen(),
  };
}