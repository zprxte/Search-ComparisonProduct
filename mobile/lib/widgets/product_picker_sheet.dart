import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/app_colors.dart';
import '../language/app_language.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../stores/compare_store.dart';
import '../utils/format.dart';
import '../utils/compare_actions.dart';
import '../utils/product_filter.dart';
import 'compare_model_dialog.dart';
import 'async_state.dart';
import 'pick_button.dart';
import 'remote_image.dart';

// ป็อปอัปเลือกสินค้าเข้าตารางเปรียบเทียบ (เทียบเท่าป็อปอัป "เพิ่มสินค้า" บนเว็บ)
//
// เปิดจากช่องว่างกรอบประในหน้าเปรียบเทียบ — ค้นหาได้ และกดเพิ่มได้ทีละชิ้น
// โดยไม่ต้องออกจากหน้าเปรียบเทียบ (เว็บก็ทำแบบนี้ เพราะผู้ใช้กำลังเทียบอยู่
// การเด้งไปหน้ารายการสินค้าแล้วกลับมาทำให้เสียบริบทที่ดูค้างไว้)
// [replaceKey] มีค่า = โหมด "เปลี่ยนสินค้า" ของช่องนั้น แทนการเพิ่มช่องใหม่
Future<void> showProductPickerSheet(
  BuildContext context, {
  VoidCallback? onBrowseAll,
  String? replaceKey,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // ต้องใส่ ไม่งั้นแผ่นสูงได้แค่ครึ่งจอ
    showDragHandle: true,
    builder: (context) =>
        _ProductPickerSheet(onBrowseAll: onBrowseAll, replaceKey: replaceKey),
  );
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({this.onBrowseAll, this.replaceKey});

  final VoidCallback? onBrowseAll;

  // ช่องที่กำลังจะถูกแทนที่ (null = โหมดเพิ่มช่องใหม่)
  final String? replaceKey;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _api = ApiService();

  // แคตตาล็อกทั้งชุด โหลดครั้งเดียวตอนเปิดแผ่น แล้วกรองในเครื่องทุกครั้งที่พิมพ์
  //
  // เดิมยิง `/search` ใหม่ทุก 300ms ระหว่างพิมพ์ ซึ่งเป็นตัวค้นหาฉบับเต็มฝั่ง
  // public (ตัดคำไทย + AND + จัดอันดับ) — เข้มเกินสำหรับการ "เลือกจากรายการ"
  // พิมพ์ชื่อไม่ครบคำหรือพิมพ์ตกหล่นแล้วรายการว่างเปล่าบ่อย และยังต้องรอเน็ต
  // ทุกครั้ง · แคตตาล็อกมีแค่หลักสิบชิ้น โหลดทีเดียวแล้วกรองเองเร็วกว่ามาก
  // (ฝั่งเว็บ `ComparePage.vue` ก็ทำแบบนี้ — `productAPI.list({ limit: 100 })`
  //  ครั้งเดียวแล้ว `filteredPickerProducts` กรองในเครื่อง)
  List<Product> _all = [];
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // เรียงตามยอดนิยม = ยังไม่พิมพ์อะไรก็เจอตัวที่คนเทียบกันบ่อยอยู่บนสุด
      // limit 100 คือเพดานของ `/products` ฝั่ง public (แคตตาล็อกจริง 43 ชิ้น)
      final result = await _api.fetchProducts(limit: 100, sort: 'popular');
      if (!mounted) return;
      setState(() {
        _all = result.products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // กรองในเครื่องจึงไม่ต้องหน่วง — พิมพ์แล้วรายการขยับทันทีทุกตัวอักษร
  void _onChanged(String value) => setState(() => _query = value);

  // ตารางเต็มแล้วก็ไม่มีอะไรให้เลือกต่อ ปิดแผ่นให้เองเพื่อให้เห็นผลทันที
  // เรียกหลังจากป็อปอัปเลือกโมเดล (ถ้ามี) ปิดไปแล้วเสมอ — ถ้าเรียกตอนป็อปอัป
  // นั้นยังเปิดอยู่ Navigator จะปิดป็อปอัปนั้นแทนที่จะปิดแผ่นนี้
  void _closeIfFull() {
    if (mounted && CompareStore.instance.isFull) Navigator.pop(context);
  }

  // รายการช่องในตะกร้าตอนนี้ ไว้เทียบว่าหลังเปิดป็อปอัปเลือกโมเดลแล้ว
  // ผู้ใช้ได้เพิ่ม/เปลี่ยนอะไรจริงหรือเปล่า
  List<String> get _cartKeys =>
      CompareStore.instance.items.value.map((item) => item.key).toList();

  bool get _isReplacing => widget.replaceKey != null;

  // กติกาเดียวกับปุ่มบนการ์ดสินค้า: มีหลายโมเดลต้องเลือกก่อน
  //
  // ขั้นตอนหาโมเดลและข้อความแจ้งผลใช้ร่วมกับการ์ดสินค้า/หน้ารายละเอียด
  // ที่ utils/compare_actions.dart — เหลือเฉพาะกติกาการปิดแผ่นไว้ที่นี่
  Future<void> _add(Product product) async {
    final before = _cartKeys;
    final resolved = await resolveCompareItem(product);
    if (!mounted || resolved.failed) return;

    if (resolved.product != null) {
      final done = await showCompareModelDialog(
        context,
        product: resolved.product!,
        replaceKey: widget.replaceKey,
      );
      if (!mounted) return;
      // ป็อปอัปเลือกโมเดลปิดไปแล้ว แผ่นนี้เป็นตัวบนสุดแล้ว จึงปิดได้ถูกตัว
      if (_isReplacing && done == true) {
        Navigator.pop(context);
      } else if (_isReplacing &&
          !CompareStore.instance.containsKey(widget.replaceKey!)) {
        // ผู้ใช้กดยกเลิกช่องที่กำลังจะเปลี่ยนจากในป็อปอัปโมเดล — ไม่มีช่องให้
        // แทนที่แล้ว อยู่ต่อก็เลือกอะไรไม่ได้
        Navigator.pop(context);
      } else if (!listEquals(before, _cartKeys)) {
        // ปิดแผ่นนี้ตามเฉพาะตอนที่ผู้ใช้ "เลือกอะไรไปจริงๆ" แล้วตารางเต็มพอดี
        // ปัดป็อปอัปโมเดลทิ้งเฉยๆ ต้องได้แผ่นนี้คืนมาเหมือนเดิม ไม่ใช่ปิดตามไป
        _closeIfFull();
      }
      return;
    }

    final ok = addCompareItem(resolved.item!, replaceKey: widget.replaceKey);
    // เปลี่ยนสินค้า = เลือกเสร็จก็จบงาน ปิดแผ่นทันที
    if (_isReplacing && ok) {
      Navigator.pop(context);
    } else {
      _closeIfFull();
    }
  }

  // ยกเลิกสินค้าที่เพิ่มไปแล้วจากในแผ่นนี้เลย (คำขอผู้ใช้ 23 ก.ย. 2026)
  // ใช้กับสินค้าที่มีโมเดลเดียวหรือไม่มีโมเดลเท่านั้น — หลายโมเดลต้องไป
  // ยกเลิกในป็อปอัปเลือกโมเดล เพราะต้องรู้ว่ากำลังเอาโมเดลไหนออก
  void _cancel(Product product) {
    removeCompareProduct(product.productId);
    // ยกเลิก "ช่องที่กำลังจะเปลี่ยน" เสียเอง = ไม่เหลือช่องให้แทนที่ ปิดแผ่นไปเลย
    if (_isReplacing &&
        !CompareStore.instance.containsKey(widget.replaceKey!)) {
      Navigator.pop(context);
    }
  }

  // สินค้าตัวนี้ต้องผ่านป็อปอัปเลือกโมเดลไหม
  // (`modelIds` ว่างทั้งที่ `hasModels` = ข้อมูลไม่ครบ ให้ถือว่าต้องเลือกก่อน
  // แล้วไปเจอความจริงในป็อปอัป ซึ่งรู้ข้อมูลครบจาก `/products/compare`)
  bool _needsModelPick(Product product) =>
      product.hasModels &&
      (product.modelIds.isEmpty || product.modelIds.length > 1);

  @override
  Widget build(BuildContext context) {
    // แผ่นสูง 85% ของจอ และดันขึ้นเหนือแป้นพิมพ์ตอนพิมพ์ค้นหา
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                langs(_isReplacing ? 'swapProductTitle' : 'pickerTitle'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: langs('pickerSearchHint'),
                  prefixIcon: const Icon(LucideIcons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildList()),
            if (widget.onBrowseAll != null)
              SafeArea(
                top: false,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onBrowseAll!();
                  },
                  child: Text(langs('seeAllProducts')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const LoadingView();
    if (_error != null) {
      return ErrorView(error: _error, onRetry: _load);
    }
    // กรองด้วยชื่อสินค้าแบบเดียวกับช่องค้นหาหน้า "สินค้าของฉัน" ฝั่งแอดมิน
    final results = filterProductsByName(_all, _query);
    if (results.isEmpty) {
      return Center(
        child: Text(
          langs('noProducts'),
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }

    // ฟังตะกร้าอยู่ กดเพิ่มแล้วปุ่มของแถวนั้นเปลี่ยนทันทีโดยไม่ต้องปิดแผ่น
    return ValueListenableBuilder<List<CompareItem>>(
      valueListenable: CompareStore.instance.items,
      builder: (context, items, _) {
        // สินค้าที่เพิ่มไปแล้ว "ค้างอยู่ในรายการ" พร้อมปุ่ม "✓ เลือกแล้ว"
        // (คำขอผู้ใช้ 23 ก.ย. 2026 — เดิมหายไปเลย) เพื่อให้กดยกเลิกได้จากที่นี่
        // โดยไม่ต้องปิดแผ่นไปกดปุ่ม ✕ บนหัวคอลัมน์ และยังเห็นว่าเพิ่มอะไรไปแล้ว
        final visible = results;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: visible.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, indent: 76),
          itemBuilder: (context, index) {
            final product = visible[index];
            // สินค้าหลายโมเดลที่เพิ่งเพิ่มไปบางโมเดลยังอยู่ในรายการ (เพราะยัง
            // เลือกโมเดลที่เหลือได้) ต้องมีเครื่องหมายบอกว่าแตะไปแล้วบางส่วน
            // ไม่งั้นดูไม่ออกว่าอันไหนเคยเพิ่มไปแล้ว
            final pickedCount = items
                .where((item) => item.productId == product.productId)
                .length;
            final picked = pickedCount > 0;

            // เพิ่มไปแล้ว = ต้องกดที่ปุ่มเท่านั้นถึงจะยกเลิก ทุกโหมด
            // (ปล่อยให้แตะทั้งแถวแล้วหลุดออกจากตาราง เป็นการทำลายของที่เลือกไว้
            // ด้วยการแตะพลาดครั้งเดียว ซึ่งไม่คุ้มกับความสะดวกที่ได้)
            final lockRowTap = picked;
            return ListTile(
              onTap: lockRowTap ? null : () => _add(product),
              leading: SizedBox(
                width: 48,
                height: 48,
                child: RemoteImage(path: product.productImage),
              ),
              title: Text(
                product.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Row(
                children: [
                  Text(
                    formatPrice(product.productPrice),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.brand700,
                    ),
                  ),
                  // มีหลายโมเดลเท่านั้นที่ต้องบอกจำนวน — โมเดลเดียวมีปุ่ม
                  // "เพิ่มแล้ว" บอกอยู่แล้ว เขียนซ้ำอีกที่ก็ไม่ได้ข้อมูลเพิ่ม
                  // (ผลจาก /search ไม่ส่ง model_ids มา จึงไม่รู้จำนวน ไม่ต้องบอก)
                  if (pickedCount > 0 && product.modelIds.length > 1) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        langs('pickedModels', {
                          'picked': pickedCount,
                          'total': product.modelIds.length,
                        }),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: PickButton(
                picked: picked,
                label: picked ? langs('pickedAlready') : langs('pickerPick'),
                // เพิ่มแล้วแต่ยังมีโมเดลอื่นให้เลือก = กดแล้วเปิดรายการโมเดล
                // ให้จัดการทีละโมเดลในนั้น (ยกเลิกทั้งสินค้าจากตรงนี้จะเหวี่ยง
                // เกินไป ผู้ใช้อาจตั้งใจเอาออกแค่โมเดลเดียวจากสองโมเดล)
                onTap: !lockRowTap
                    ? () => _add(product)
                    : _needsModelPick(product)
                    ? () => _add(product)
                    : () => _cancel(product),
              ),
            );
          },
        );
      },
    );
  }
}
