import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const AlqalahEduApp());
}

class AlqalahEduApp extends StatelessWidget {
  const AlqalahEduApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'منصة الأستاذ',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 100, color: Colors.blue.shade700),
            const SizedBox(height: 24),
            const Text('منصة الأستاذ', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blue.shade700)),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الرئيسية'), backgroundColor: Colors.blue.shade700),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(Icons.table_chart, Colors.blue, 'إدخال الدرجات', 'إضافة وتعديل درجات الطلاب'),
          _buildCard(Icons.import_export, Colors.green, 'استيراد / تصدير Excel', 'رفع وتحميل ملفات Excel'),
          _buildCard(Icons.people, Colors.orange, 'قائمة الطلاب', 'عرض وإدارة بيانات الطلاب'),
          _buildCard(Icons.notifications_active, Colors.red, 'الإشعارات', 'إرسال تنبيهات للطلاب'),
          _buildCard(Icons.fingerprint, Colors.purple, 'القفل البيومتري', 'حماية التطبيق بالبصمة'),
          _buildCard(Icons.settings, Colors.grey, 'الإعدادات', 'تخصيص التطبيق'),
        ],
      ),
    );
  }
  Widget _buildCard(IconData icon, Color color, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الضغط على: ')));
        },
      ),
    );
  }
}