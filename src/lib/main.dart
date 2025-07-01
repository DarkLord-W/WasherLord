// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:washer/config_screen.dart';
import 'package:washer/login_screen.dart';
import 'package:washer/storage.dart';
import 'package:washer/user.dart';
import 'package:washer/washer_monitor.dart';
import 'package:washer/washer_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final User? cachedUser = await UserStorage.getCurrentUser();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WasherProvider()),
      ],
      child: MyApp(initialUser: cachedUser),
    ),
  );
}

class MyApp extends StatelessWidget {
  final User? initialUser;

  const MyApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Washer App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      // initialRoute: initialUser != null ? '/home' : '/login',
      initialRoute: '/login',// 强制所有启动进入登录页面
      routes: {
        '/login': (context) => LoginScreen(),
        '/home': (context) => WasherMonitorScreen(),
        '/config': (context) => ConfigScreen(),
      },

      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          return PageRouteBuilder(
            pageBuilder: (_, __, ___) => WasherMonitorScreen(),
            transitionsBuilder: (_, a, __, c) =>
                FadeTransition(opacity: a, child: c),
            transitionDuration: Duration(milliseconds: 300),
          );
        }
        return null;
      },
      onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }
}
