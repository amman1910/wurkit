import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
// Import the welcome page
import 'features/auth/screens/welcome_page.dart';
import 'features/notifications/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.instance.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: PushNotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Wurkit',
      theme: ThemeData(
        // Setting the theme to dark to match your splash design
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFA8072),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // Set the initial page to WelcomePage
      home: const WelcomePage(),
    );
  }
}
