import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gbptnphvlbfudeilmdcu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdicHRucGh2bGJmdWRlaWxtZGN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzMzgxMTUsImV4cCI6MjA4OTkxNDExNX0.-RKt00oa30YEZRnHUEjw9TYRTXt45cR1rP2cIB1XOi0',
    );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'STEMSET',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(),
        );
  }
}
