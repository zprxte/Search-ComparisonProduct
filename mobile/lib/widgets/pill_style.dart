import 'package:flutter/material.dart';

// สไตล์ปุ่ม "เม็ดยา" (มุมโค้งเต็ม สูง 34) ที่ใช้ซ้ำทั่วแอป
//
// เดิมทุกจุดเขียน `RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))`
// พร้อมความสูง/ระยะขอบของตัวเองซ้ำกัน 8 แห่ง — ค่าที่ควรเท่ากันจึงค่อยๆ เพี้ยน
// ออกจากกัน (บางปุ่มสูง 34 บางปุ่มปล่อยตามค่าเริ่มต้น 40 ของ Material)
//
// ตั้งใจให้คุมแค่ "รูปทรง" ไม่คุมสี — แต่ละปุ่มยังเลือกสีของตัวเองได้ตามบทบาท
// (ปุ่มหลักสีแบรนด์ / ปุ่มรองพื้นเทา / ปุ่มขอบบาง) การบังคับสีร่วมกันจะทำให้
// ต้องไปแก้หน้าตาหลายหน้าพร้อมกันโดยไม่จำเป็น
ButtonStyle pillButtonStyle({
  required Color foreground,
  Color? background,
  Color? borderColor,
  double height = 34,
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 12),

  // ปุ่มที่อยู่ในช่องแคบ (เช่น trailing ของ ListTile) ต้องไม่กินพื้นที่แตะส่วนเกิน
  // ไม่งั้นความกว้างจะเลยตัวอักษรไปมาก
  bool shrinkTapTarget = false,

  // บังคับให้กว้างเต็มพื้นที่ที่ได้รับ (ปุ่มในแถวที่แบ่งครึ่ง)
  bool fillWidth = false,
}) {
  return TextButton.styleFrom(
    foregroundColor: foreground,
    backgroundColor: background,
    side: borderColor == null ? null : BorderSide(color: borderColor),
    padding: padding,
    minimumSize: fillWidth ? Size.fromHeight(height) : Size(0, height),
    tapTargetSize: shrinkTapTarget ? MaterialTapTargetSize.shrinkWrap : null,
    shape: const StadiumBorder(),
  );
}
