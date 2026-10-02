import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/app_colors.dart';
import '../language/app_language.dart';
import '../screens/search_screen.dart';

// ช่องค้นหาทรงแคปซูลบนหัวหน้าแรกและหน้าสินค้าทั้งหมด (ตาม wireframe)
// กดแล้วเปิดหน้าค้นหา — ตัวมันเองไม่ใช่ช่องกรอกจริง เพื่อให้แป้นพิมพ์
// ขึ้นในหน้าค้นหาที่มีพื้นที่แสดงคำแนะนำเต็มจอ
class SearchBarButton extends StatelessWidget {
  const SearchBarButton({super.key, this.query, this.onSearch});

  // คำที่กำลังค้นอยู่ — มีค่าแล้วจะโชว์คำนั้นแทนข้อความชวนพิมพ์
  // และเปิดหน้าค้นหาพร้อมคำเดิมในช่อง แก้ต่อได้ไม่ต้องพิมพ์ใหม่
  final String? query;

  // ผู้ใช้ค้นเสร็จแล้วได้คำนี้มา — หน้าที่ใช้ปุ่มนี้เป็นคนตัดสินใจว่าจะทำอะไรต่อ
  // (ทั้งหน้าแรกและหน้าสินค้าส่งต่อขึ้นไปให้ MainScreen สลับไปแท็บสินค้า)
  final void Function(String query)? onSearch;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: langs('searchTitle'),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          final result = await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => SearchScreen(initialQuery: query),
            ),
          );
          // null = กดย้อนกลับเฉยๆ ไม่ได้ค้นอะไร
          if (result != null && result.trim().isNotEmpty) {
            onSearch?.call(result.trim());
          }
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.button),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.search, size: 18, color: AppColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  query ?? langs('searchHint'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: query == null ? AppColors.muted : AppColors.navy900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
