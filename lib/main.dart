import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:health/Screens/dashboard.dart';
import 'package:health/Screens/statistics.dart';
import 'screens/history.dart';




void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Monitoring App',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: Colors.grey.shade100,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const DashboardScreen(),
        '/history': (context) => const HistoryScreen(),
        '/stats': (context) => const StatisticsScreen(),
        
      },
    );
  }
}
