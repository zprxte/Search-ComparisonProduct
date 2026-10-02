import 'package:flutter/material.dart';

import '../language/app_language.dart';

// โครงของแผ่นตัวกรองที่เด้งขึ้นจากข้างล่าง — รายการเลื่อนได้ + แถบปุ่มล่างติดที่
//
// ใช้ร่วมกันระหว่างแผ่นตัวกรองสินค้า (`filter_sheet.dart`) กับแผ่นคัดกรองของ
// ตารางเปรียบเทียบ (`compare_filter_sheet.dart`) ซึ่งเดิมเขียนโครงเดียวกันคนละชุด
// (สัดส่วนความสูง 0.75/0.4/0.95, ระยะขอบ, แถบปุ่ม "ล้าง | ดูผลลัพธ์") ทำให้เวลา
// ปรับอย่างหนึ่งต้องไล่แก้ให้เหมือนกันสองที่
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.children,
    required this.clearLabel,
    required this.onClear,
    required this.onApply,
  });

  // เนื้อในของแผ่น — วางในรายการที่เลื่อนได้ (ตัวเลื่อนของแผ่นจัดการให้เอง)
  final List<Widget> children;

  // ข้อความของปุ่มล้าง — สองแผ่นใช้คำต่างกัน (ล้างตัวกรอง / ล้างการกรอง)
  final String clearLabel;
  final VoidCallback onClear;

  // กด "ดูผลลัพธ์" — ผู้เรียกเป็นคนสั่ง Navigator.pop พร้อมค่าที่ต้องการคืน
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: children,
            ),
          ),
          // แถบปุ่มล่างติดอยู่กับที่ ไม่เลื่อนหนีไปกับรายการ
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  TextButton(onPressed: onClear, child: Text(clearLabel)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: onApply,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(langs('showResults')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
