import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('منصة الأستاذ'),
        backgroundColor: Colors.indigo,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.indigo.shade50,
            child: const ListTile(
              leading: Icon(Icons.school, color: Colors.indigo, size: 40),
              title: Text('مرحباً بك', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('التطبيق يعمل بنجاح!'),
            ),
          ),
          const SizedBox(height: 20),
          _menuItem(Icons.table_chart, 'إدخال الدرجات', Colors.blue),
          _menuItem(Icons.import_export, 'استيراد Excel', Colors.green),
          _menuItem(Icons.people, 'قائمة الطلاب', Colors.orange),
          _menuItem(Icons.notifications, 'الإشعارات', Colors.red),
          _menuItem(Icons.fingerprint, 'القفل البيومتري', Colors.purple),
          _menuItem(Icons.settings, 'الإعدادات', Colors.grey),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {},
      ),
    );
  }
}