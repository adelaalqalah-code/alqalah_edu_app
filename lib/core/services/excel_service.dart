import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// نموذج صف درجة مستورد
class GradeImportRow {
  final String? confirmationId;
  final String? fullName;
  final double? score;
  final String? gradeType;
  final String? notes;
  final bool isValid;
  final String? error;

  GradeImportRow({
    this.confirmationId,
    this.fullName,
    this.score,
    this.gradeType,
    this.notes,
    this.isValid = true,
    this.error,
  });
}

class ExcelService {
  static final _client = Supabase.instance.client;

  /// استيراد الدرجات من Excel
  static Future<List<GradeImportRow>> pickAndParseGradesExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      throw Exception('لم يتم اختيار ملف');
    }

    final bytes = result.files.first.bytes;
    if (bytes == null) throw Exception('تعذر قراءة الملف');

    return _parseGradesFromBytes(bytes);
  }

  static List<GradeImportRow> _parseGradesFromBytes(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.keys.first;
    final rows = excel.tables[sheet]!.rows;

    if (rows.length < 2) {
      throw Exception('الملف فارغ أو لا يحتوي على بيانات كافية');
    }

    final headers = rows.first.map((cell) => cell?.value?.toString().trim() ?? '').toList();

    final idIndex = _findColumnIndex(headers, ['رقم التأكيد', 'confirmation_id', 'الرقم', 'ID']);
    final nameIndex = _findColumnIndex(headers, ['الاسم', 'full_name', 'اسم الطالب', 'الطالب']);
    final scoreIndex = _findColumnIndex(headers, ['الدرجة', 'score', 'العلامة', 'النقاط']);
    final typeIndex = _findColumnIndex(headers, ['النوع', 'type', 'نوع الدرجة', 'التصنيف']);
    final notesIndex = _findColumnIndex(headers, ['ملاحظات', 'notes', 'تعليق']);

    if (idIndex == -1 && nameIndex == -1) {
      throw Exception('لم يتم العثور على عمود رقم التأكيد أو الاسم في الملف');
    }

    final List<GradeImportRow> parsedRows = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((c) => c?.value == null)) continue;

      final confirmationId = idIndex != -1 ? row[idIndex]?.value?.toString().trim() : null;
      final fullName = nameIndex != -1 ? row[nameIndex]?.value?.toString().trim() : null;
      final scoreStr = scoreIndex != -1 ? row[scoreIndex]?.value?.toString().trim() : null;
      final gradeType = typeIndex != -1 ? row[typeIndex]?.value?.toString().trim() : null;
      final notes = notesIndex != -1 ? row[notesIndex]?.value?.toString().trim() : null;

      double? score;
      String? error;

      if (scoreStr != null && scoreStr.isNotEmpty) {
        score = double.tryParse(scoreStr.replaceAll('/', '.'));
        if (score == null) {
          final parts = scoreStr.split('/');
          if (parts.length == 2) {
            final numerator = double.tryParse(parts[0].trim());
            if (numerator != null) score = numerator;
          }
        }
      }

      if ((confirmationId == null || confirmationId.isEmpty) &&
          (fullName == null || fullName.isEmpty)) {
        error = 'رقم التأكيد والاسم فارغان';
      } else if (score == null && scoreStr != null && scoreStr.isNotEmpty) {
        error = 'الدرجة غير صالحة: $scoreStr';
      }

      parsedRows.add(GradeImportRow(
        confirmationId: confirmationId,
        fullName: fullName,
        score: score,
        gradeType: gradeType ?? 'تكليف',
        notes: notes,
        isValid: error == null,
        error: error,
      ));
    }

    return parsedRows;
  }

  static int _findColumnIndex(List<String> headers, List<String> possibleNames) {
    for (final name in possibleNames) {
      final index = headers.indexWhere((h) => h.contains(name) || h.toLowerCase().contains(name.toLowerCase()));
      if (index != -1) return index;
    }
    return -1;
  }

  /// حفظ الدرجات المستوردة في Supabase
  static Future<Map<String, dynamic>> saveImportedGrades({
    required List<GradeImportRow> rows,
    required String gradeTypeId,
    required String courseId,
    required String professorName,
  }) async {
    int successCount = 0;
    int failCount = 0;
    List<String> errors = [];

    for (final row in rows) {
      if (!row.isValid || row.confirmationId == null || row.score == null) {
        failCount++;
        continue;
      }

      try {
        final studentResponse = await _client
            .from('students')
            .select('id')
            .eq('confirmation_id', row.confirmationId!)
            .maybeSingle();

        if (studentResponse == null) {
          failCount++;
          errors.add('الطالب ${row.confirmationId} غير موجود');
          continue;
        }

        final studentId = studentResponse['id'];

        final existing = await _client
            .from('grades')
            .select('id, is_locked')
            .eq('student_id', studentId)
            .eq('grade_type_id', gradeTypeId)
            .maybeSingle();

        if (existing != null && existing['is_locked'] == true) {
          failCount++;
          errors.add('درجة ${row.confirmationId} مثبتة ولا يمكن التعديل');
          continue;
        }

        if (existing != null) {
          await _client.from('grades').update({
            'score': row.score,
            'notes': row.notes,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', existing['id']);
        } else {
          await _client.from('grades').insert({
            'student_id': studentId,
            'grade_type_id': gradeTypeId,
            'score': row.score,
            'notes': row.notes,
            'max_score': 100,
          });
        }

        successCount++;
      } catch (e) {
        failCount++;
        errors.add('خطأ في ${row.confirmationId}: $e');
      }
    }

    return {'success': successCount, 'failed': failCount, 'errors': errors};
  }

  /// تصدير الدرجات إلى Excel
  static Future<void> exportGradesToExcel({
    required String fileName,
    required String gradeTypeName,
    required List<Map<String, dynamic>> gradesData,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['الدرجات'];

    final headers = ['رقم التأكيد', 'اسم الطالب', 'القسم', 'الدرجة', 'من', 'النسبة %', 'الحالة', 'ملاحظات'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#1A1A1A',
      fontColorHex: '#FFFFFF',
      horizontalAlign: HorizontalAlign.Center,
    );
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).style = headerStyle;
    }

    for (final data in gradesData) {
      final score = (data['score'] as num?)?.toDouble() ?? 0;
      final maxScore = (data['max_score'] as num?)?.toDouble() ?? 100;
      final percentage = maxScore > 0 ? (score / maxScore * 100).toStringAsFixed(1) : '0';
      final isLocked = data['is_locked'] == true;

      sheet.appendRow([
        TextCellValue(data['confirmation_id']?.toString() ?? ''),
        TextCellValue(data['full_name']?.toString() ?? ''),
        TextCellValue(data['department_name']?.toString() ?? ''),
        DoubleCellValue(score),
        DoubleCellValue(maxScore),
        TextCellValue('$percentage%'),
        TextCellValue(isLocked ? 'مثبتة' : 'قابلة للتعديل'),
        TextCellValue(data['notes']?.toString() ?? ''),
      ]);
    }

    sheet.setColumnWidth(0, 18);
    sheet.setColumnWidth(1, 25);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 10);
    sheet.setColumnWidth(4, 8);
    sheet.setColumnWidth(5, 12);
    sheet.setColumnWidth(6, 18);
    sheet.setColumnWidth(7, 25);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('فشل في إنشاء الملف');

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName.xlsx';
    final file = File(path);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(path)], subject: 'تصدير درجات - $gradeTypeName');
  }

  /// قالب Excel فارغ للتحميل
  static Future<void> downloadTemplate() async {
    final excel = Excel.createExcel();
    final sheet = excel['درجات الطلاب'];

    sheet.appendRow([
      TextCellValue('رقم التأكيد'),
      TextCellValue('اسم الطالب'),
      TextCellValue('الدرجة'),
      TextCellValue('النوع (تكليف/مشاركة/واجب)'),
      TextCellValue('ملاحظات'),
    ]);

    sheet.appendRow([
      TextCellValue('CS-2026-0001'),
      TextCellValue('أحمد محمد الصبري'),
      TextCellValue('85'),
      TextCellValue('تكليف'),
      TextCellValue(''),
    ]);
    sheet.appendRow([
      TextCellValue('CS-2026-0002'),
      TextCellValue('سارة عبدالله'),
      TextCellValue('92'),
      TextCellValue('مشاركة'),
      TextCellValue('ممتاز'),
    ]);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('فشل في إنشاء القالب');

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/grade_template.xlsx';
    final file = File(path);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(path)], subject: 'قالب استيراد الدرجات');
  }
}
