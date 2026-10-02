import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/app_colors.dart';
import '../language/app_language.dart';
import '../language/translations.dart';

// ปุ่มสลับภาษา TH / EN / JP บนหัว AppBar (หน้าแรกและหน้าสินค้าทั้งหมด)
// เลือกแล้วบันทึกลงเครื่อง เปิดแอปครั้งหน้าได้ภาษาเดิม
// แปลเฉพาะข้อความ UI — ชื่อสินค้า/สเปคมาจากฐานข้อมูลซึ่งมีภาษาเดียว
class LanguageButton extends StatelessWidget {
  // จุดเรียกใช้ห้ามใส่ const เพราะข้อความบนปุ่มเปลี่ยนตามภาษาที่เลือก
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    // ฟังเองด้วย ไม่พึ่งให้หน้าแม่วาดใหม่ให้ — ตัวอักษรบนปุ่ม (TH/EN/JP)
    // ต้องเปลี่ยนทันทีที่เลือก แม้กิ่งอื่นจะยังไม่ถูกวาดใหม่
    return ValueListenableBuilder<String>(
      valueListenable: LanguageStore.instance.code,
      builder: (context, current, _) => _button(current),
    );
  }

  Widget _button(String current) {
    return PopupMenuButton<String>(
      tooltip: langs('languageLabel'),
      onSelected: LanguageStore.instance.setLang,
      padding: EdgeInsets.zero,
      offset: const Offset(0, 44),
      color: AppColors.white,
      elevation: 3,
      // เมนูกว้างเท่าที่เนื้อหาต้องการ ไม่ต้องกว้างเป็นบล็อกใหญ่กลางจอ
      constraints: const BoxConstraints(minWidth: 132, maxWidth: 190),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      itemBuilder: (context) => appLanguages
          .map(
            (lang) => PopupMenuItem<String>(
              value: lang.code,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _LanguageRow(
                badge: lang.badge,
                label: lang.label,
                selected: lang.code == current,
              ),
            ),
          )
          .toList(),
      // ตัวปุ่มบน AppBar: ทรงแคปซูลให้เห็นว่ากดได้ ไม่ใช่ตัวอักษรลอยๆ
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.fromLTRB(9, 5, 5, 5),
        decoration: BoxDecoration(
          color: AppColors.brand50,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.globe, size: 16, color: AppColors.brand700),
            const SizedBox(width: 5),
            Text(
              languageBadge(current),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.brand700,
              ),
            ),
            const Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: AppColors.brand700,
            ),
          ],
        ),
      ),
    );
  }
}

// หนึ่งบรรทัดในเมนูภาษา: ป้ายรหัสภาษา → ชื่อภาษาในภาษาของตัวเอง
//
// ไม่มีเครื่องหมายถูกแล้ว — ป้ายของภาษาที่เลือกอยู่เป็นพื้นฟ้าทึบตัวหนังสือขาว
// ส่วนที่เหลือเป็นเทาอ่อน ต่างกันชัดพอโดยไม่ต้องกันคอลัมน์ไว้ให้ไอคอน
// (ใช้ป้ายรหัสแทนธงชาติ เพราะธงต้องเพิ่มไฟล์รูป และภาษาไม่เท่ากับประเทศ)
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.badge,
    required this.label,
    required this.selected,
  });

  final String badge;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // ฟอนต์หลักของแอปเป็น Noto Sans Thai ซึ่งไม่มีตัวอักษรญี่ปุ่น ระบบจึงไป
    // หยิบฟอนต์สำรองของเครื่องมาใช้ หน้าตาเลยหลุดจากบรรทัดอื่น — บรรทัดนี้
    // จึงระบุ Noto Sans JP ให้ตรงๆ ตัวอักษรจะได้เป็นชุดเดียวกับที่ออกแบบไว้
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      color: selected ? AppColors.brand700 : AppColors.navy900,
    );

    return Row(
      children: [
        Container(
          width: 26,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.brand600 : AppColors.circle,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: selected ? AppColors.white : AppColors.muted,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: labelStyle,
          ),
        ),
      ],
    );
  }
}
