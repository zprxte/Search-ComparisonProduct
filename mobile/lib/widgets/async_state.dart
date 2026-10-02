import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../language/app_language.dart';

// กำลังโหลด — ทุกหน้าที่รอ API ใช้ตัวนี้ตัวเดียว
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

// โหลดไม่สำเร็จ — ข้อความอธิบาย + ปุ่มลองใหม่ (ถ้าหน้านั้นโหลดซ้ำได้)
//
// เดิมแต่ละหน้าประกอบเองคนละแบบ บางหน้าโชว์ `'Error: $e'` ดิบๆ เป็นภาษาอังกฤษ
// ทั้งที่ส่วนอื่นของแอปแปลครบ 3 ภาษา — รวมมาที่เดียวแล้วทุกหน้าได้ข้อความเดียวกัน
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.title, this.onRetry});

  // ตัวข้อผิดพลาดจริง (แสดงเป็นบรรทัดเล็กไว้ให้แจ้งปัญหาได้)
  final Object? error;

  // หัวข้อเฉพาะหน้า เช่น "โหลดข้อมูลเปรียบเทียบไม่สำเร็จ"
  final String? title;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title ?? langs('loadFailed', {'error': ''}).trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.navy900),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: Text(langs('retry'))),
            ],
          ],
        ),
      ),
    );
  }
}
