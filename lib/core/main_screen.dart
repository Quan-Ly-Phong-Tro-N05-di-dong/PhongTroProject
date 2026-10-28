// lib/core/main_screen.dart
import 'package:flutter/material.dart';

import '../features/home_catalog/counter_screen.dart';
import '../features/auth/screens/account_screen.dart';
import '../features/contact/screens/interaction_home_screen.dart';
import '../features/auth/widgets/role_guard.dart';
import '../features/manage-posts/manage_posts_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    CounterScreen(title: 'Phòng Trọ'),
    RoleGuard(child: ManagePostsPage(embedded: true)),
    RoleGuard(child: InteractionHomeScreen()),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.post_add), label: 'Bài đăng'),
          BottomNavigationBarItem(
            icon: Icon(Icons.contact_support),
            label: 'Liên hệ',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
    );
  }
}
