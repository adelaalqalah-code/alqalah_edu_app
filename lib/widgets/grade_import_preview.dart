import 'package:flutter/material.dart';
import '../../core/services/excel_service.dart';

class GradeImportPreview extends StatelessWidget {
  final List<GradeImportRow> rows;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const GradeImportPreview({
    super.key,
    required this.rows,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final validRows = rows.where((r) => r.isValid).length;
    final invalidRows = rows.where((r) => !r.isValid).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ═══ ملخص المعاينة ═══
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('معاينة البيانات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${rows.length} صف',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatChip('صالحة', validRows, Colors.green),
                  const SizedBox(width: 8),
                  if (invalidRows > 0)
                    _buildStatChip('غير صالحة', invalidRows, Colors.red),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ═══ جدول المعاينة ═══
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              // رأس الجدول
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _headerText('رقم التأكيد')),
                    Expanded(flex: 2, child: _headerText('الاسم')),
                    Expanded(child: _headerText('الدرجة')),
                    Expanded(child: _headerText('النوع')),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              // الصفوف
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rows.length > 50 ? 50 : rows.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: !row.isValid ? Colors.red.shade50 : null,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            row.confirmationId ?? '-',
                            style: TextStyle(
                              fontSize: 13,
                              color: !row.isValid ? Colors.red.shade700 : Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            row.fullName ?? '-',
                            style: TextStyle(
                              fontSize: 13,
                              color: !row.isValid ? Colors.red.shade700 : Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.score?.toString() ?? '-',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: !row.isValid ? Colors.red.shade700 : Colors.black,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.gradeType ?? 'تكليف',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: !row.isValid
                              ? Tooltip(
                                  message: row.error ?? 'خطأ غير معروف',
                                  child: Icon(Icons.error_outline, size: 18, color: Colors.red.shade600),
                                )
                              : const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (rows.length > 50)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '... و ${rows.length - 50} صفوف أخرى',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ═══ أزرار التأكيد ═══
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: validRows > 0 ? onSave : null,
                icon: const Icon(Icons.save, size: 18),
                label: Text('حفظ $validRows درجة'),
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
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('إلغاء'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerText(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color.shade700),
      ),
    );
  }
}
