import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/api_config.dart';
import '../config/app_colors.dart';

// รูปจากเซิร์ฟเวอร์ พร้อมภาพแทนตอนไม่มีรูป/โหลดไม่ขึ้น
//
// เดิมโค้ดชุดนี้ (ต่อ URL → Image.network → errorBuilder เป็นไอคอน) ถูกเขียนซ้ำ
// 7 ที่ใน 5 ไฟล์ และเขียนไม่เหมือนกันเสียทีเดียว — บางที่ครอบ Center บางที่ไม่ครอบ
// บางที่กำหนดขนาดไอคอน บางที่ปล่อยตามค่าเริ่มต้น เวลาจะเปลี่ยนพฤติกรรมร่วม
// (เช่นใส่ placeholder ระหว่างโหลด) จึงต้องไล่แก้ทีละจุดและมักตกหล่น
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.path,
    this.fit = BoxFit.contain,
    this.iconSize,
    this.width,
    this.placeholderIcon = LucideIcons.image,
    this.errorIcon = LucideIcons.imageOff,
    this.keepSpaceWhileLoading = false,
  });

  // path จากฐานข้อมูล เช่น `/uploads/products/...` (null = ยังไม่มีรูป)
  final String? path;
  final BoxFit fit;
  final double? iconSize;
  final double? width;

  // ไอคอนตอน "ไม่มีรูปในฐานข้อมูล" กับตอน "มีรูปแต่โหลดไม่ขึ้น" — แยกกันเพราะ
  // เป็นคนละเรื่อง ผู้ดูแลข้อมูลควรแยกออกว่าลืมใส่รูป หรือไฟล์หาย
  final IconData placeholderIcon;
  final IconData errorIcon;

  // จองที่ว่างไว้ระหว่างโหลดแทนการปล่อยให้ Image วาดทีละส่วน — ใช้กับการ์ดสินค้า
  // ที่เรียงเป็นกริด ไม่งั้นรูปทยอยขึ้นแล้วหน้าจอกระตุก
  final bool keepSpaceWhileLoading;

  Widget _icon(IconData icon) => Center(
    child: Icon(icon, size: iconSize, color: AppColors.muted),
  );

  @override
  Widget build(BuildContext context) {
    if (path == null) return _icon(placeholderIcon);
    return Image.network(
      ApiConfig.imageUrl(path),
      fit: fit,
      width: width,
      loadingBuilder: keepSpaceWhileLoading
          ? (context, child, progress) =>
                progress == null ? child : const SizedBox.shrink()
          : null,
      errorBuilder: (context, error, stack) => _icon(errorIcon),
    );
  }
}
