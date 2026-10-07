import 'package:firebase_core/firebase_core.dart'; // khoi tao firebase
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'routers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trọ 123',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: AppRoutes.root,
      routes: AppRoutes.routes,
    );
  }
}

