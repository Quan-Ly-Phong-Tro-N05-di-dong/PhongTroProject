import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../firebase_options.dart';
import 'manage_posts_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase đã khởi tạo: ${Firebase.app().options.projectId}');
    runApp(const ManagePostsDemoApp());
  } catch (error, stack) {
    debugPrint('Không khởi tạo được Firebase: $error');
    debugPrintStack(stackTrace: stack);
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(title: const Text('Lỗi khởi tạo Firebase')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                '$error\n\nKiểm tra lib/firebase_options.dart của dự án chung.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ManagePostsDemoApp extends StatelessWidget {
  const ManagePostsDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quản lý bài đăng',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        appBarTheme: const AppBarThemeData(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      home: const ManagePostsPage(),
    );
  }
}
