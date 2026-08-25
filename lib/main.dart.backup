import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'منصة الأستاذ',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('منصة الأستاذ', textDirection: TextDirection.rtl),
          backgroundColor: Colors.blue.shade700,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 80, color: Colors.blue),
              SizedBox(height: 20),
              Text(
                'مرحباً بك!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'التطبيق يعمل بنجاح',
                style: TextStyle(fontSize: 18, color: Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
