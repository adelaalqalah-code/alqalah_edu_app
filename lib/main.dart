import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ✅ تهيئة آمنة — إذا فشلت لا يتعطل التطبيق
  try {
    await Supabase.initialize(
      url: 'https://your-project.supabase.co',
      anonKey: 'your-anon-key',
    );
  } catch (e) {
    debugPrint('⚠️ Supabase offline: $e');
  }

  runApp(const ProviderScope(child: AlqalahEduApp()));
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
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const SafeSplashScreen(),
    );
  }
}

// ✅ شاشة افتتاحية آمنة — تنتقل تلقائياً بعد ثانيتين مهما حصل
class SafeSplashScreen extends StatefulWidget {
  const SafeSplashScreen({super.key});

  @override
  State<SafeSplashScreen> createState() => _SafeSplashScreenState();
}

class _SafeSplashScreenState extends State<SafeSplashScreen> {
  @override
  void initState() {
    super.initState();
    // ⏰ مؤقت صارم — لا يمكن أن يتوقف أبداً
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
            const Text(
              'منصة الأستاذ',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ الشاشة الرئيسية الكاملة — تعمل بدون إنترنت
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرئيسية'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(
            icon: Icons.table_chart,
            color: Colors.blue,
            title: 'إدخال الدرجات',
            subtitle: 'إضافة وتعديل درجات الطلاب',
            onTap: () => _showMsg(context, 'قسم الدرجات'),
          ),
          _buildCard(
            icon: Icons.import_export,
            color: Colors.green,
            title: 'استيراد / تصدير Excel',
            subtitle: 'رفع وتحميل ملفات Excel',
            onTap: () => _showMsg(context, 'قسم Excel'),
          ),
          _buildCard(
            icon: Icons.people,
            color: Colors.orange,
            title: 'قائمة الطلاب',
            subtitle: 'عرض وإدارة بيانات الطلاب',
            onTap: () => _showMsg(context, 'قائمة الطلاب'),
          ),
          _buildCard(
            icon: Icons.notifications_active,
            color: Colors.red,
            title: 'الإشعارات',
            subtitle: 'إرسال تنبيهات للطلاب',
            onTap: () => _showMsg(context, 'الإشعارات'),
          ),
          _buildCard(
            icon: Icons.fingerprint,
            color: Colors.purple,
            title: 'القفل البيومتري',
            subtitle: 'حماية التطبيق بالبصمة',
            onTap: () => _showMsg(context, 'القفل'),
          ),
          _buildCard(
            icon: Icons.settings,
            color: Colors.grey,
            title: 'الإعدادات',
            subtitle: 'تخصيص التطبيق',
            onTap: () => _showMsg(context, 'الإعدادات'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showMsg(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}