// lib/core/main_screen.dart
import 'package:flutter/material.dart';

// Import màn hình của từng thành viên
import '../features/home_catalog/counter_screen.dart';
// Khi các bạn khác hoàn thành screen thật, chỉ việc thay thế import và widget tương ứng ở đây
// import '../features/auth/presentation/screens/auth_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Danh sách 4 màn hình tương ứng với 4 tab
  //Sau khi có giao diện thật, các bạn chỉ việc thay thế _PlaceholderTab bằng màn hình của mình (Ví dụ màn hình của Huy là CounterScreen)
  final List<Widget> _screens = const [
    CounterScreen(title: 'Phòng Trọ'), // Tab 0: Home Catalog 
    _PlaceholderTab(title: 'Bài Đăng'), // Tab 1: Manage Posts 
    _PlaceholderTab(title: 'Liên Hệ'),  // Tab 2: Contact 
    _PlaceholderTab(title: 'Tài Khoản'),// Tab 3: Auth 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed, // Cần thiết khi có từ 4 tabs trở lên
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.post_add),
            label: 'Bài đăng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contact_support),
            label: 'Liên hệ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}

// Giữ chỗ tạm thời cho các thành viên chưa nộp code
class _PlaceholderTab extends StatelessWidget {
  final String title;
  const _PlaceholderTab({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Module: $title\n(Đang hoàn thiện)',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }
}