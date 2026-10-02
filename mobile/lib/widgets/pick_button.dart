import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/app_colors.dart';
import 'pill_style.dart';

// ปุ่มท้ายแถวในรายการเลือกสินค้า
// ยังไม่ได้เพิ่ม = เม็ดยาโปร่งขอบเทา ("เลือก") · เพิ่มแล้ว = เม็ดยาทึบสีแบรนด์ + ติ๊กถูก ("เลือกแล้ว")
// (ผู้ใช้ขอให้ของที่เพิ่มแล้วค้างอยู่ในรายการแบบนี้ แทนที่จะหายไป 23 ก.ย. 2026)
class PickButton extends StatelessWidget {
  const PickButton({
    super.key,
    required this.picked,
    required this.label,
    required this.onTap,
  });

  final bool picked;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // อยู่ใน trailing ของ ListTile ซึ่งกว้างเท่าที่ลูกต้องการ จึงต้องบีบพื้นที่
    // แตะส่วนเกินออก ไม่งั้นปุ่มจะกินความกว้างเกินตัวอักษรไปมาก
    final style = pillButtonStyle(
      foreground: picked ? AppColors.white : AppColors.navy900,
      background: picked ? AppColors.brand600 : AppColors.white,
      borderColor: picked ? AppColors.brand600 : AppColors.border,
      shrinkTapTarget: true,
    );

    return TextButton.icon(
      onPressed: onTap,
      style: style,
      icon: Icon(picked ? LucideIcons.check : LucideIcons.plus, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
