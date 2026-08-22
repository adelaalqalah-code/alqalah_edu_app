import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/excel_service.dart';

// Providers
final selectedDepartmentProvider = StateProvider<String?>((ref) => null);
final selectedCourseProvider = StateProvider<String?>((ref) => null);
final selectedGradeTypeProvider = StateProvider<String?>((ref) => null);
final gradeStudentsProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
final gradeScoresProvider = StateProvider<Map<String, double>>((ref) => {});
final gradeNotesProvider = StateProvider<Map<String, String>>((ref) => {});
final isLockedProvider = StateProvider<bool>((ref) => false);
final showImportProvider = StateProvider<bool>((ref) => false);
final savingProvider = StateProvider<bool>((ref) => false);

class GradeEntryScreen extends ConsumerStatefulWidget {
  const GradeEntryScreen({super.key});

  @override
  ConsumerState<GradeEntryScreen> createState() => _GradeEntryScreenState();
}

class _GradeEntryScreenState extends ConsumerState<GradeEntryScreen> {
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _gradeTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final depts = await Supabase.instance.client
          .from('departments').select('id, name, code').eq('is_active', true).order('sort_order');
      final courses = await Supabase.instance.client
          .from('courses').select('id, name, department_id').eq('is_active', true).order('name');
      final types = await Supabase.instance.client
          .from('grade_types').select('id, name, color, max_score').eq('is_active', true).order('sort_order');

      setState(() {
        _departments = List<Map<String, dynamic>>.from(depts);
        _courses = List<Map<String, dynamic>>.from(courses);
        _gradeTypes = List<Map<String, dynamic>>.from(types);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('خطأ في تحميل البيانات: $e', isError: true);
    }
  }

  Future<void> _loadStudents() async {
    final courseId = ref.read(selectedCourseProvider);
    final typeId = ref.read(selectedGradeTypeProvider);
    if (courseId == null || typeId == null) return;

    setState(() => _isLoading = true);

    try {
      final students = await Supabase.instance.client
          .from('students')
          .select('id, full_name, confirmation_id, department:departments(name)')
          .eq('course_id', courseId)
          .eq('is_active', true)
          .eq('is_approved', true)
          .order('full_name');

      final studentsList = List<Map<String, dynamic>>.from(students);
      final scores = <String, double>{};
      final notes = <String, String>{};
      bool anyLocked = false;

      for (final s in studentsList) {
        final sid = s['id'] as String;
        final gradeData = await Supabase.instance.client
            .from('grades')
            .select('score, max_score, is_locked, notes')
            .eq('student_id', sid)
            .eq('grade_type_id', typeId)
            .maybeSingle();

        if (gradeData != null) {
          scores[sid] = (gradeData['score'] as num).toDouble();
          notes[sid] = gradeData['notes']?.toString() ?? '';
          if (gradeData['is_locked'] == true) anyLocked = true;
        }
      }

      ref.read(gradeStudentsProvider.notifier).state = studentsList;
      ref.read(gradeScoresProvider.notifier).state = scores;
      ref.read(gradeNotesProvider.notifier).state = notes;
      ref.read(isLockedProvider.notifier).state = anyLocked;
    } catch (e) {
      _showSnack('خطأ: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveGrades() async {
    final students = ref.read(gradeStudentsProvider);
    final scores = ref.read(gradeScoresProvider);
    final notes = ref.read(gradeNotesProvider);
    final typeId = ref.read(selectedGradeTypeProvider);
    final isLocked = ref.read(isLockedProvider);

    if (typeId == null) {
      _showSnack('يرجى اختيار نوع الدرجة', isError: true);
      return;
    }

    if (isLocked) {
      _showSnack('الدرجات مثبتة ولا يمكن التعديل', isError: true);
      return;
    }

    ref.read(savingProvider.notifier).state = true;

    int saved = 0;
    try {
      for (final student in students) {
        final sid = student['id'] as String;
        final score = scores[sid];
        if (score == null) continue;

        final existing = await Supabase.instance.client
            .from('grades')
            .select('id, is_locked')
            .eq('student_id', sid)
            .eq('grade_type_id', typeId)
            .maybeSingle();

        if (existing != null && existing['is_locked'] == true) continue;

        if (existing != null) {
          await Supabase.instance.client.from('grades').update({
            'score': score,
            'notes': notes[sid],
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', existing['id']);
        } else {
          await Supabase.instance.client.from('grades').insert({
            'student_id': sid,
            'grade_type_id': typeId,
            'score': score,
            'notes': notes[sid],
            'max_score': 100,
          });
        }
        saved++;
      }

      _showSnack('تم حفظ $saved درجة بنجاح');
    } catch (e) {
      _showSnack('خطأ في الحفظ: $e', isError: true);
    } finally {
      ref.read(savingProvider.notifier).state = false;
    }
  }

  Future<void> _toggleLock() async {
    final typeId = ref.read(selectedGradeTypeProvider);
    if (typeId == null) return;

    final currentLock = ref.read(isLockedProvider);

    try {
      await Supabase.instance.client
          .from('grades')
          .update({
            'is_locked': !currentLock,
            'locked_at': !currentLock ? DateTime.now().toIso8601String() : null,
            'locked_by': !currentLock ? 'professor' : null,
          })
          .eq('grade_type_id', typeId);

      ref.read(isLockedProvider.notifier).state = !currentLock;
      _showSnack(currentLock ? 'تم فك التثبيت' : 'تم تثبيت الدرجات');
    } catch (e) {
      _showSnack('خطأ: $e', isError: true);
    }
  }

  Future<void> _importFromExcel() async {
    final typeId = ref.read(selectedGradeTypeProvider);
    if (typeId == null) {
      _showSnack('اختر نوع الدرجة أولاً', isError: true);
      return;
    }

    try {
      final rows = await ExcelService.pickAndParseGradesExcel();
      final students = ref.read(gradeStudentsProvider);
      final scores = Map<String, double>.from(ref.read(gradeScoresProvider));
      final notes = Map<String, String>.from(ref.read(gradeNotesProvider));

      int matched = 0;
      for (final row in rows) {
        if (!row.isValid || row.confirmationId == null || row.score == null) continue;

        final student = students.firstWhere(
          (s) => s['confirmation_id'] == row.confirmationId,
          orElse: () => {},
        );

        if (student.isNotEmpty) {
          scores[student['id']] = row.score!;
          if (row.notes != null) notes[student['id']] = row.notes!;
          matched++;
        }
      }

      ref.read(gradeScoresProvider.notifier).state = scores;
      ref.read(gradeNotesProvider.notifier).state = notes;
      ref.read(showImportProvider.notifier).state = false;

      _showSnack('تم استيراد $matched درجة من Excel');
    } catch (e) {
      _showSnack('خطأ في الاستيراد: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredCourses {
    final deptId = ref.watch(selectedDepartmentProvider);
    if (deptId == null) return _courses;
    return _courses.where((c) => c['department_id'] == deptId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDept = ref.watch(selectedDepartmentProvider);
    final selectedCourse = ref.watch(selectedCourseProvider);
    final selectedType = ref.watch(selectedGradeTypeProvider);
    final students = ref.watch(gradeStudentsProvider);
    final scores = ref.watch(gradeScoresProvider);
    final notes = ref.watch(gradeNotesProvider);
    final isLocked = ref.watch(isLockedProvider);
    final showImport = ref.watch(showImportProvider);
    final isSaving = ref.watch(savingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إدخال الدرجات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text('يدوي فردي وجماعي من Excel', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        centerTitle: false,
        actions: [
          if (selectedType != null)
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Chip(
                label: Text(isLocked ? 'مثبتة' : 'قابلة للتعديل'),
                backgroundColor: isLocked ? Colors.green.shade50 : Colors.orange.shade50,
                side: BorderSide(color: isLocked ? Colors.green.shade200 : Colors.orange.shade200),
                labelStyle: TextStyle(
                  color: isLocked ? Colors.green.shade800 : Colors.orange.shade800,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading && students.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilters(),
                  const SizedBox(height: 20),
                  if (selectedType != null && students.isNotEmpty)
                    _buildActionsBar(isLocked, isSaving),
                  if (selectedType != null && students.isNotEmpty)
                    const SizedBox(height: 16),
                  if (selectedType != null && !isLocked)
                    _buildImportToggle(showImport),
                  if (showImport && !isLocked)
                    _buildImportSection(),
                  const SizedBox(height: 16),
                  if (students.isEmpty && selectedType != null)
                    _buildEmptyState(),
                  if (students.isNotEmpty)
                    _buildStudentsList(students, scores, notes, isLocked),
                ],
              ),
            ),
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: ref.watch(selectedDepartmentProvider),
              decoration: InputDecoration(
                labelText: 'القسم',
                prefixIcon: Icon(Icons.apartment_outlined, color: Colors.grey.shade600),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('جميع الأقسام')),
                ..._departments.map((d) => DropdownMenuItem(
                  value: d['id'] as String,
                  child: Text('${d['code']} - ${d['name']}'),
                )),
              ],
              onChanged: (val) {
                ref.read(selectedDepartmentProvider.notifier).state = val;
                ref.read(selectedCourseProvider.notifier).state = null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: ref.watch(selectedCourseProvider),
              decoration: InputDecoration(
                labelText: 'المساق / المادة',
                prefixIcon: Icon(Icons.menu_book_outlined, color: Colors.grey.shade600),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('اختر المساق')),
                ..._filteredCourses.map((c) => DropdownMenuItem(
                  value: c['id'] as String,
                  child: Text(c['name'] as String),
                )),
              ],
              onChanged: (val) {
                ref.read(selectedCourseProvider.notifier).state = val;
                if (val != null && ref.read(selectedGradeTypeProvider) != null) {
                  _loadStudents();
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: ref.watch(selectedGradeTypeProvider),
              decoration: InputDecoration(
                labelText: 'نوع الدرجة',
                prefixIcon: Icon(Icons.category_outlined, color: Colors.grey.shade600),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('اختر نوع الدرجة')),
                ..._gradeTypes.map((t) => DropdownMenuItem(
                  value: t['id'] as String,
                  child: Row(
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: Color(int.parse((t['color'] as String).replaceFirst('#', '0xFF'))),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(t['name'] as String),
                    ],
                  ),
                )),
              ],
              onChanged: (val) {
                ref.read(selectedGradeTypeProvider.notifier).state = val;
                if (val != null && ref.read(selectedCourseProvider) != null) {
                  _loadStudents();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsBar(bool isLocked, bool isSaving) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isSaving ? null : _saveGrades,
            icon: isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 18),
            label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ الدرجات'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: _toggleLock,
          icon: Icon(isLocked ? Icons.lock_open : Icons.lock, size: 18),
          label: Text(isLocked ? 'فك التثبيت' : 'تثبيت'),
          style: OutlinedButton.styleFrom(
            foregroundColor: isLocked ? Colors.green.shade700 : Colors.orange.shade700,
            side: BorderSide(color: isLocked ? Colors.green.shade300 : Colors.orange.shade300),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildImportToggle(bool showImport) {
    return InkWell(
      onTap: () => ref.read(showImportProvider.notifier).state = !showImport,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(showImport ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              showImport ? 'إخفاء استيراد Excel' : 'استيراد من Excel (جماعي)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
            ),
            const Spacer(),
            Icon(Icons.upload_file, size: 18, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSection() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'استيراد جماعي من Excel',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue.shade900),
          ),
          const SizedBox(height: 4),
          Text(
            'الملف يجب أن يحتوي على: رقم التأكيد، الدرجة',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _importFromExcel,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('اختيار ملف Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await ExcelService.downloadTemplate();
                    _showSnack('تم تحميل القالب');
                  } catch (e) {
                    _showSnack('خطأ: $e', isError: true);
                  }
                },
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('قالب'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'لا يوجد طلاب مسجلين في هذا المساق',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            'أضف طلاباً أولاً من شاشة الطلاب',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList(
    List<Map<String, dynamic>> students,
    Map<String, double> scores,
    Map<String, String> notes,
    bool isLocked,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'قائمة الطلاب (${students.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (!isLocked)
              TextButton.icon(
                onPressed: () => _showBulkFillDialog(students),
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('تعبئة جماعية'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: students.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final student = students[index];
            final sid = student['id'] as String;
            final name = student['full_name'] as String;
            final confId = student['confirmation_id'] as String?;
            final deptName = student['department']?['name'] ?? '';
            final currentScore = scores[sid];
            final currentNote = notes[sid] ?? '';

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                '$confId · $deptName',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: currentScore?.toString() ?? '',
                            enabled: !isLocked,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'الدرجة',
                              hintText: '0-100',
                              prefixIcon: const Icon(Icons.grade_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (val) {
                              final score = double.tryParse(val);
                              final newScores = Map<String, double>.from(scores);
                              if (score != null) {
                                newScores[sid] = score;
                              } else {
                                newScores.remove(sid);
                              }
                              ref.read(gradeScoresProvider.notifier).state = newScores;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            initialValue: currentNote,
                            enabled: !isLocked,
                            decoration: InputDecoration(
                              labelText: 'ملاحظات',
                              hintText: 'اختياري',
                              prefixIcon: const Icon(Icons.notes_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (val) {
                              final newNotes = Map<String, String>.from(notes);
                              if (val.isNotEmpty) {
                                newNotes[sid] = val;
                              } else {
                                newNotes.remove(sid);
                              }
                              ref.read(gradeNotesProvider.notifier).state = newNotes;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showBulkFillDialog(List<Map<String, dynamic>> students) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تعبئة جماعية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('سيتم تعبئة نفس الدرجة لجميع الطلاب الذين ليس لديهم درجة.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الدرجة للجميع',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final score = double.tryParse(controller.text);
              if (score != null) {
                final newScores = Map<String, double>.from(ref.read(gradeScoresProvider));
                for (final s in students) {
                  final sid = s['id'] as String;
                  if (!newScores.containsKey(sid)) {
                    newScores[sid] = score;
                  }
                }
                ref.read(gradeScoresProvider.notifier).state = newScores;
                Navigator.pop(context);
                _showSnack('تم تعبئة ${students.length} طالب');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }
}
