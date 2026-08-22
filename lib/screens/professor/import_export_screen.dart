import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/excel_service.dart';
import '../../widgets/grade_import_preview.dart';

enum ImportState { idle, parsing, preview, saving, done, error }

final importStateProvider = StateProvider<ImportState>((ref) => ImportState.idle);
final importRowsProvider = StateProvider<List<GradeImportRow>>((ref) => []);
final selectedGradeTypeProvider = StateProvider<String?>((ref) => null);
final selectedCourseProvider = StateProvider<String?>((ref) => null);
final importResultProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  bool _isExporting = false;
  List<Map<String, dynamic>> _gradeTypes = [];
  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    try {
      final types = await Supabase.instance.client
          .from('grade_types')
          .select('id, name, color')
          .eq('is_active', true)
          .order('sort_order');
      final courses = await Supabase.instance.client
          .from('courses')
          .select('id, name, department:departments(name)')
          .eq('is_active', true)
          .order('name');
      setState(() {
        _gradeTypes = List<Map<String, dynamic>>.from(types);
        _courses = List<Map<String, dynamic>>.from(courses);
      });
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _importExcel() async {
    final selectedType = ref.read(selectedGradeTypeProvider);
    final selectedCourse = ref.read(selectedCourseProvider);
    if (selectedType == null || selectedCourse == null) {
      _showSnackBar('يرجى اختيار نوع الدرجة والمساق أولاً', isError: true);
      return;
    }
    ref.read(importStateProvider.notifier).state = ImportState.parsing;
    try {
      final rows = await ExcelService.pickAndParseGradesExcel();
      ref.read(importRowsProvider.notifier).state = rows;
      ref.read(importStateProvider.notifier).state = ImportState.preview;
    } catch (e) {
      ref.read(importStateProvider.notifier).state = ImportState.error;
      _showSnackBar('خطأ: $e', isError: true);
    }
  }

  Future<void> _saveImportedGrades() async {
    final rows = ref.read(importRowsProvider);
    final selectedType = ref.read(selectedGradeTypeProvider);
    final selectedCourse = ref.read(selectedCourseProvider);
    if (selectedType == null || selectedCourse == null) return;
    ref.read(importStateProvider.notifier).state = ImportState.saving;
    try {
      final result = await ExcelService.saveImportedGrades(
        rows: rows,
        gradeTypeId: selectedType,
        courseId: selectedCourse,
        professorName: 'Adel AlQalah',
      );
      ref.read(importResultProvider.notifier).state = result;
      ref.read(importStateProvider.notifier).state = ImportState.done;
      _showSnackBar(
        'تم حفظ ${result['success']} درجة بنجاح، ${result['failed']} فشلت',
        isError: result['failed'] > 0,
      );
    } catch (e) {
      ref.read(importStateProvider.notifier).state = ImportState.error;
      _showSnackBar('خطأ في الحفظ: $e', isError: true);
    }
  }

  Future<void> _exportGrades() async {
    final selectedType = ref.read(selectedGradeTypeProvider);
    if (selectedType == null) {
      _showSnackBar('يرجى اختيار نوع الدرجة للتصدير', isError: true);
      return;
    }
    setState(() => _isExporting = true);
    try {
      final typeData = _gradeTypes.firstWhere((t) => t['id'] == selectedType);
      final typeName = typeData['name'] ?? 'درجات';
      final gradesData = await Supabase.instance.client
          .from('grades')
          .select('score, max_score, is_locked, notes, student:students(confirmation_id, full_name, department:departments(name))')
          .eq('grade_type_id', selectedType)
          .order('created_at', ascending: false);
      final formattedData = (gradesData as List).map((g) => {
        'confirmation_id': g['student']?['confirmation_id'] ?? '',
        'full_name': g['student']?['full_name'] ?? '',
        'department_name': g['student']?['department']?['name'] ?? '',
        'score': g['score'],
        'max_score': g['max_score'],
        'is_locked': g['is_locked'],
        'notes': g['notes'],
      }).toList();
      await ExcelService.exportGradesToExcel(
        fileName: 'grades_export_${DateTime.now().millisecondsSinceEpoch}',
        gradeTypeName: typeName,
        gradesData: formattedData,
      );
      _showSnackBar('تم تصدير الملف بنجاح');
    } catch (e) {
      _showSnackBar('خطأ في التصدير: $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      await ExcelService.downloadTemplate();
      _showSnackBar('تم تحميل القالب');
    } catch (e) {
      _showSnackBar('خطأ: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final importState = ref.watch(importStateProvider);
    final importRows = ref.watch(importRowsProvider);
    final importResult = ref.watch(importResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('استيراد وتصدير Excel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text('إدارة الدرجات دفعة واحدة', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w400)),
          ],
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('الإعدادات'),
            const SizedBox(height: 12),
            _buildDropdownCard(),
            const SizedBox(height: 24),
            _buildSectionTitle('الإجراءات'),
            const SizedBox(height: 12),
            _buildActionButtons(importState),
            const SizedBox(height: 24),
            if (importState == ImportState.parsing || importState == ImportState.saving)
              _buildProgressIndicator(importState),
            if (importState == ImportState.done && importResult != null)
              _buildResultCard(importResult),
            if (importState == ImportState.preview && importRows.isNotEmpty)
              GradeImportPreview(
                rows: importRows,
                onSave: _saveImportedGrades,
                onCancel: () {
                  ref.read(importStateProvider.notifier).state = ImportState.idle;
                  ref.read(importRowsProvider.notifier).state = [];
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87));
  }

  Widget _buildDropdownCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: ref.watch(selectedGradeTypeProvider),
              decoration: InputDecoration(
                labelText: 'نوع الدرجة',
                hintText: 'اختر نوع الدرجة',
                prefixIcon: Icon(Icons.category_outlined, color: Colors.grey.shade600),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _gradeTypes.map((type) {
                return DropdownMenuItem(
                  value: type['id'] as String,
                  child: Row(
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: Color(int.parse((type['color'] as String).replaceFirst('#', '0xFF'))),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(type['name'] as String),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => ref.read(selectedGradeTypeProvider.notifier).state = val,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: ref.watch(selectedCourseProvider),
              decoration: InputDecoration(
                labelText: 'المساق / المادة',
                hintText: 'اختر المساق',
                prefixIcon: Icon(Icons.menu_book_outlined, color: Colors.grey.shade600),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _courses.map((course) {
                return DropdownMenuItem(
                  value: course['id'] as String,
                  child: Text('${course['name']} (${course['department']?['name'] ?? ''})'),
                );
              }).toList(),
              onChanged: (val) => ref.read(selectedCourseProvider.notifier).state = val,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ImportState state) {
    final isBusy = state == ImportState.parsing || state == ImportState.saving;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : _importExcel,
                icon: const Icon(Icons.upload_file, size: 20),
                label: const Text('استيراد من Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy || _isExporting ? null : _exportGrades,
                icon: _isExporting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.download, size: 20),
                label: Text(_isExporting ? 'جاري التصدير...' : 'تصدير إلى Excel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: isBusy ? null : _downloadTemplate,
            icon: Icon(Icons.description_outlined, size: 18, color: Colors.grey.shade600),
            label: Text('تحميل قالب Excel فارغ', style: TextStyle(color: Colors.grey.shade700)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(ImportState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            backgroundColor: Colors.blue.shade100,
            valueColor: AlwaysStoppedAnimation(Colors.blue.shade700),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Text(
            state == ImportState.parsing ? 'جاري قراءة الملف...' : 'جاري حفظ الدرجات...',
            style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final success = result['success'] as int;
    final failed = result['failed'] as int;
    final errors = result['errors'] as List<String>;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: failed == 0 ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: failed == 0 ? Colors.green.shade200 : Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(failed == 0 ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: failed == 0 ? Colors.green.shade700 : Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(failed == 0 ? 'تم بنجاح!' : 'تم مع بعض الأخطاء',
                  style: TextStyle(fontWeight: FontWeight.w600,
                      color: failed == 0 ? Colors.green.shade800 : Colors.orange.shade800)),
            ],
          ),
          const SizedBox(height: 8),
          Text('✓ نجح: $success درجة', style: TextStyle(color: Colors.green.shade800)),
          if (failed > 0) Text('✗ فشل: $failed درجة', style: TextStyle(color: Colors.red.shade700)),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: errors.take(5).map((e) => Text('• $e', style: const TextStyle(fontSize: 12))).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
