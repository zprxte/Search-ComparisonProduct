import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/app_colors.dart';
import '../language/app_language.dart';
import '../models/product.dart';
import '../screens/product_detail_screen.dart';
import '../stores/compare_store.dart';
import 'compare_model_dialog.dart';
import 'remote_image.dart';
import '../utils/highlight.dart';
import '../utils/format.dart';
import '../utils/compare_actions.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({super.key, required this.product, this.onTap, this.query});

  final Product product;
  final VoidCallback? onTap;

  // คำค้นปัจจุบัน — ส่วนที่ตรงกันในชื่อสินค้าจะถูกไฮไลต์ให้ (เหมือนหน้าเว็บ)
  final String? query;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  // กำลังโหลดโมเดลของสินค้าตัวนี้อยู่ — กันกดรัวจนยิง API ซ้อนกัน
  bool _loadingModels = false;

  // เหมือนหน้าเว็บ (ProductCard.vue):
  // - สินค้าไม่มีโมเดล → เพิ่ม/เอาออกได้เลย
  // - มีหลายโมเดล → เปิดป็อปอัปให้เลือกก่อน เพราะแต่ละโมเดลราคา/สเปคคนละชุด
  // - มีโมเดลเดียว → เพิ่มโมเดลนั้นให้เลย ไม่ต้องถาม
  //
  // ขั้นตอนหาโมเดลและข้อความแจ้งผลอยู่ใน utils/compare_actions.dart
  // ใช้ร่วมกับป็อปอัปเลือกสินค้าและหน้ารายละเอียดสินค้า
  Future<void> _toggleCompare(bool inCompare) async {
    final product = widget.product;

    if (!product.hasModels) {
      if (inCompare) {
        removeCompareProduct(product.productId);
      } else {
        addCompareItem(CompareItem.fromProduct(product));
      }
      return;
    }

    if (_loadingModels) return;
    setState(() => _loadingModels = true);
    try {
      final resolved = await resolveCompareItem(product);
      if (!mounted || resolved.failed) return;

      if (resolved.product != null) {
        await showCompareModelDialog(context, product: resolved.product!);
        return;
      }
      // เหลือโมเดลเดียว (หรือไม่มีเลย) ปุ่มบนการ์ดจึงสลับเพิ่ม/เอาออกได้ทันที
      if (inCompare) {
        removeCompareProduct(product.productId);
      } else {
        addCompareItem(resolved.item!);
      }
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameHeight = MediaQuery.textScalerOf(context).scale(13.5) * 1.35 * 2;
    return DecoratedBox(
      // เงาอ่อนๆ ให้การ์ดลอยจากพื้นหลัง แทนการใช้เส้นขอบหนาๆ
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14081C30),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          // ไม่ได้ส่ง onTap มา = เข้าหน้ารายละเอียดสินค้าเป็นค่าเริ่มต้น
          // ทุกที่ที่ใช้การ์ดจึงกดเข้าดูสินค้าได้เหมือนกันหมด
          onTap:
              widget.onTap ??
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ProductDetailScreen(productId: widget.product.productId),
                ),
              ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // รูปสินค้า: จัตุรัส พื้นขาว มุมมนของตัวเอง — พื้นขาวเหมือน ProductCard.vue
                // เพราะรูปสินค้าส่วนใหญ่มีพื้นขาวติดมาในไฟล์ วางบนพื้นเทาจะเห็นกรอบซ้อนสองสี
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: AppColors.white,
                      padding: const EdgeInsets.all(10),
                      child: RemoteImage(
                        path: widget.product.productImage,
                        iconSize: 28,
                        keepSpaceWhileLoading: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: nameHeight,
                  child: Text.rich(
                    TextSpan(
                      children: highlightSegments(
                        widget.product.productName,
                        widget.query ?? '',
                        highlightStyle: const TextStyle(
                          backgroundColor: AppColors.brand50,
                          color: AppColors.brand700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy900,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  formatPrice(widget.product.productPrice),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand700,
                  ),
                ),
                const SizedBox(height: 8),
                // ปุ่มเปรียบเทียบ: พื้นฟ้าอ่อน ตัวอักษรฟ้าเข้ม (contrast ผ่าน) สูง 44 นิ้วกดง่าย
                // ปุ่ม 2 สถานะเหมือนหน้าเว็บ · ValueListenableBuilder ทำให้ปุ่ม
                // วาดใหม่เองทุกครั้งที่ตะกร้าเปลี่ยน ไม่ว่าจะเปลี่ยนจากหน้าไหน
                ValueListenableBuilder<List<CompareItem>>(
                  valueListenable: CompareStore.instance.items,
                  builder: (context, items, _) {
                    final inCompare = items.any(
                      (item) => item.productId == widget.product.productId,
                    );
                    return TextButton.icon(
                      onPressed: _loadingModels
                          ? null
                          : () => _toggleCompare(inCompare),
                      icon: Icon(
                        inCompare ? LucideIcons.check : LucideIcons.gitCompare,
                        size: 16,
                      ),
                      label: Text(
                        inCompare ? langs('inCompare') : langs('compare'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: inCompare
                            ? AppColors.white
                            : AppColors.brand700,
                        backgroundColor: inCompare
                            ? AppColors.brand700
                            : AppColors.brand50,
                        minimumSize: const Size.fromHeight(36),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        animationDuration: const Duration(milliseconds: 150),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
