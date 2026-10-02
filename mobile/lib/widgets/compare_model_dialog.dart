import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../language/app_language.dart';
import '../models/compare_product.dart';
import '../stores/compare_store.dart';
import '../utils/format.dart';
import '../utils/compare_actions.dart';
import 'pick_button.dart';

// ป็อปอัปเลือกโมเดลก่อนเพิ่มเข้าตารางเปรียบเทียบ (เหมือน CompareModelDialog.vue)
// เปิดจากปุ่ม "เปรียบเทียบ" บนการ์ดสินค้า เฉพาะสินค้าที่มีมากกว่า 1 โมเดล
//
// กดโมเดลที่ยังไม่อยู่ในตาราง = เพิ่มเข้าตาราง แล้วเปิดค้างไว้ถ้ายังไม่เต็ม
// (เลือกโมเดลที่ 2 ของสินค้าตัวเดียวกันมาเทียบกันเองได้)
// โมเดลที่เพิ่มไปแล้วค้างอยู่ในรายการพร้อมปุ่ม "เลือกแล้ว" กดยกเลิกได้จากตรงนี้
// (คำขอผู้ใช้ 23 ก.ย. 2026 — เดิมหายไปจากรายการเลย)
// ปิดเองเมื่อตารางเต็ม เพราะไม่เหลือช่องให้เลือกต่อแล้ว
// [replaceKey] มีค่า = โหมด "เปลี่ยนสินค้า" — เลือกโมเดลแล้วไปแทนที่ช่องนั้น
// แทนการเพิ่มช่องใหม่ แล้วปิดทันที (คืนค่า true เมื่อเปลี่ยนสำเร็จ)
Future<bool?> showCompareModelDialog(
  BuildContext context, {
  required CompareProduct product,
  String? replaceKey,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ValueListenableBuilder<List<CompareItem>>(
        valueListenable: CompareStore.instance.items,
        builder: (context, items, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                langs('compareModelTitle'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                product.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
            const Divider(height: 1),
            // เลือกได้ทีละโมเดล เทียบสินค้าเดียวกันหลายโมเดลก็เปิดซ้ำได้
            Flexible(
              child: ListView(
                shrinkWrap: true,
                // โชว์ทุกโมเดลเสมอ ตัวที่เพิ่มไปแล้วขึ้นปุ่ม "เลือกแล้ว"
                // กดแล้วยกเลิกได้ตรงนั้น ไม่ต้องปิดป็อปอัปไปกดปุ่ม ✕ ในตาราง
                children: product.models.map((model) {
                  // อยู่ในตารางแล้วหรือยัง — ขึ้นป้าย "เลือกแล้ว" ทุกโหมด
                  final picked = items.any(
                    (item) =>
                        item.productId == product.productId &&
                        item.modelId == model.modelId,
                  );

                  // ปุ่ม "เลือกแล้ว" กดยกเลิกได้ทุกโหมด รวมถึงโหมดเปลี่ยนสินค้า
                  // (คำขอผู้ใช้ 23 ก.ย. 2026) · แลกมาด้วยการที่โหมดเปลี่ยนสินค้า
                  // เลือกโมเดลที่ช่องอื่นถืออยู่เพื่อ "สลับที่กัน" จากป็อปอัปนี้ไม่ได้
                  // แล้ว — ปุ่มนั้นกลายเป็นการยกเลิกแทน
                  final canCancel = picked;

                  void addModel() {
                    final store = CompareStore.instance;
                    final ok = addCompareItem(
                      CompareItem(
                        productId: product.productId,
                        productName: product.productName,
                        productImage: product.productImage,
                        productPrice: model.productPrice,
                        modelId: model.modelId,
                        modelName: model.modelName,
                      ),
                      replaceKey: replaceKey,
                      modelName: model.modelName,
                    );
                    // เปลี่ยนสินค้า = เลือกเสร็จก็จบงาน ปิดเลย
                    // ถ้ายังเหลือช่องต้องเปิดค้างไว้ ผู้ใช้จะได้กดโมเดลที่ 2
                    if (replaceKey != null || !ok || store.isFull) {
                      Navigator.pop(sheetContext, ok);
                    }
                  }

                  // ยกเลิกโมเดลที่เพิ่มไปแล้ว — ป็อปอัปไม่ปิด เพราะคนที่
                  // ยกเลิกมักจะกดเลือกอีกโมเดลแทนทันทีในหน้าเดียวกัน
                  void cancelModel() {
                    final store = CompareStore.instance;
                    removeCompareModel(product.productId, model.modelId);
                    // ยกเลิก "ช่องที่กำลังจะเปลี่ยน" เสียเอง = ไม่เหลือช่องให้แทนที่
                    // ปล่อยให้เลือกต่อไม่ได้ เพราะ replace() จะหาช่องไม่เจอแล้ว
                    final target = replaceKey;
                    if (target != null && !store.containsKey(target)) {
                      Navigator.pop(sheetContext, false);
                    }
                  }

                  return ListTile(
                    title: Text(model.modelName),
                    subtitle: Text(formatPrice(model.productPrice)),
                    trailing: PickButton(
                      picked: picked,
                      label: picked
                          ? langs('pickedAlready')
                          : langs('pickerPick'),
                      onTap: canCancel ? cancelModel : addModel,
                    ),
                    // เพิ่มไปแล้วต้องกดที่ปุ่มเท่านั้นถึงจะยกเลิก
                    // แตะทั้งแถวแล้วของหลุดออกจากตารางเป็นอุบัติเหตุที่แพง
                    // (โหมดเปลี่ยนสินค้าแตะได้ตามปกติ เพราะกดแล้วไม่มีอะไรหาย)
                    onTap: canCancel ? null : addModel,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
