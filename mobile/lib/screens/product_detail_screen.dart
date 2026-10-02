import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/app_colors.dart';
import '../language/app_language.dart';
import '../models/product_detail.dart';
import '../services/api_service.dart';
import '../stores/compare_store.dart';
import '../utils/format.dart';
import '../utils/launch.dart';
import '../utils/compare_actions.dart';
import '../widgets/async_state.dart';
import '../widgets/remote_image.dart';

// หน้ารายละเอียดสินค้า — ตาม wireframe จอ Detail:
// แถบบน (ย้อนกลับ — ไม่มีปุ่มแชร์ตามคำขอผู้ใช้ 25 ก.ย. 2026) → แกลเลอรีรูป → หมวดหมู่/ชื่อ/ราคารวม →
// เลือกโมเดล → ตัวเลือกเสริม → แท็บ สเปค/รายละเอียด/ประกัน-จัดส่ง →
// แถบปุ่มล่าง (+ เปรียบเทียบ | สั่งซื้อ)
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<ProductDetail> _future;

  int _galleryIndex = 0;
  String? _modelId; // โมเดลที่เลือกอยู่ (null = สินค้าไม่มีโมเดล)
  final Set<String> _optionIds = {}; // ตัวเลือกเสริมที่ติ๊กไว้
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _future = ApiService().fetchProductDetail(widget.productId);
  }

  // ราคารวม = ราคาโมเดลที่เลือก + ตัวเลือกเสริมที่ติ๊ก
  // สินค้าราคา 0 ("ติดต่อสอบถาม") ติ๊กตัวเลือกแล้วยังเป็นติดต่อสอบถาม
  // เหมือนฝั่งเว็บ — ไม่ใช่ราคาของตัวเลือกล้วนๆ ซึ่งจะทำให้เข้าใจผิด
  // โมเดลที่เลือกอยู่ (null = สินค้าไม่มีโมเดล)
  ProductModelOption? _model(ProductDetail product) =>
      product.models.where((m) => m.modelId == _modelId).firstOrNull;

  num _total(ProductDetail product) {
    final base = _model(product)?.productPrice ?? product.productPrice;
    if (base == 0) return 0;

    var total = base;
    for (final option in product.options) {
      if (_optionIds.contains(option.optionId)) total += option.addonPrice;
    }
    return total;
  }

  // สเปคที่แสดง = สเปคของสินค้า ทับด้วยสเปคเฉพาะโมเดลที่เลือก
  List<ProductSpec> _specs(ProductDetail product) {
    final merged = <String, String>{};
    for (final spec in product.specs) {
      merged[spec.name] = spec.value;
    }
    for (final spec in _model(product)?.specs ?? const <ProductSpec>[]) {
      merged[spec.name] = spec.value;
    }
    return merged.entries
        .map((e) => ProductSpec(name: e.key, value: e.value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: FutureBuilder<ProductDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return SafeArea(
              child: Column(
                children: [
                  _header(null),
                  Expanded(child: ErrorView(error: snapshot.error)),
                ],
              ),
            );
          }

          final product = snapshot.data!;
          // ครั้งแรกที่ข้อมูลมาถึง ให้เลือกโมเดลแรกไว้ก่อน
          _modelId ??= product.models.isEmpty
              ? null
              : product.models.first.modelId;

          return SafeArea(
            child: Column(
              children: [
                _header(product),
                Expanded(child: _body(product)),
                _bottomBar(product),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(ProductDetail? product) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: langs('back'),
            icon: const Icon(LucideIcons.chevronLeft),
          ),
        ],
      ),
    );
  }

  Widget _body(ProductDetail product) {
    final specs = _specs(product);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _gallery(product),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.categoryName != null)
                Text(
                  product.categoryName!,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              const SizedBox(height: 4),
              Text(
                product.productName,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatPrice(_total(product)),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand700,
                ),
              ),

              if (product.models.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionLabel(langs('modelHeading')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: product.models
                      .map(
                        (model) => ChoiceChip(
                          label: Text(model.modelName),
                          selected: _modelId == model.modelId,
                          onSelected: (_) =>
                              setState(() => _modelId = model.modelId),
                        ),
                      )
                      .toList(),
                ),
              ],

              if (product.options.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionLabel(langs('optionsHeading')),
                ...product.options.map(
                  (option) => CheckboxListTile(
                    value: _optionIds.contains(option.optionId),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _optionIds.add(option.optionId);
                      } else {
                        _optionIds.remove(option.optionId);
                      }
                    }),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      option.optionName,
                      style: const TextStyle(fontSize: 13),
                    ),
                    secondary: Text(
                      '+${formatPrice(option.addonPrice)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              _tabs(),
              const SizedBox(height: 12),
              _tabContent(product, specs),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gallery(ProductDetail product) {
    if (product.gallery.isEmpty) {
      return Container(
        height: 280,
        color: AppColors.surface,
        child: const Center(
          child: Icon(LucideIcons.image, size: 40, color: AppColors.muted),
        ),
      );
    }

    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          // ปัดซ้าย/ขวาดูรูปถัดไป ตาม wireframe
          PageView.builder(
            itemCount: product.gallery.length,
            onPageChanged: (index) => setState(() => _galleryIndex = index),
            // พื้นขาวให้กลืนกับพื้นขาวที่ติดมาในไฟล์รูป (ดู product_card.dart)
            itemBuilder: (context, index) => Container(
              color: AppColors.white,
              padding: const EdgeInsets.all(16),
              child: RemoteImage(path: product.gallery[index]),
            ),
          ),
          if (product.gallery.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  product.gallery.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _galleryIndex ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: index == _galleryIndex
                          ? AppColors.navy900
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.navy900,
      ),
    ),
  );

  Widget _tabs() {
    final labels = [
      langs('tabSpecs'),
      langs('tabDetail'),
      langs('tabWarranty'),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = _tab == index;
          return InkWell(
            onTap: () => setState(() => _tab = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 2,
                    color: selected ? AppColors.navy900 : Colors.transparent,
                  ),
                ),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.navy900 : AppColors.muted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _tabContent(ProductDetail product, List<ProductSpec> specs) {
    if (_tab == 0) {
      if (specs.isEmpty) return _placeholder(langs('noSpecs'));
      return Column(
        children: specs
            .map(
              (spec) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        spec.name,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        spec.value,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.navy900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
    }

    if (_tab == 1) {
      final text = product.description?.trim() ?? '';
      if (text.isEmpty) return _placeholder(langs('noDetail'));
      return Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.5,
          color: AppColors.navy900,
        ),
      );
    }

    final warranty = product.warrantyText?.trim() ?? '';
    final shipping = product.shippingText?.trim() ?? '';
    if (warranty.isEmpty && shipping.isEmpty) {
      return _placeholder(langs('noWarranty'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (warranty.isNotEmpty) ...[
          _sectionLabel(langs('warranty')),
          Text(warranty, style: const TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 12),
        ],
        if (shipping.isNotEmpty) ...[
          _sectionLabel(langs('shipping')),
          Text(shipping, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ],
    );
  }

  Widget _placeholder(String text) =>
      Text(text, style: const TextStyle(fontSize: 13, color: AppColors.muted));

  Widget _bottomBar(ProductDetail product) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<List<CompareItem>>(
              valueListenable: CompareStore.instance.items,
              builder: (context, items, _) {
                // ดูถึงระดับโมเดล: สินค้าตัวเดียวกันคนละโมเดลเป็นคนละช่อง
                // เลือกโมเดลอื่นแล้วปุ่มต้องกลับเป็น "เปรียบเทียบ" ให้เพิ่มได้อีก
                final inCompare = items.any(
                  (item) =>
                      item.productId == product.productId &&
                      item.modelId == _modelId,
                );
                return OutlinedButton.icon(
                  onPressed: () => _toggleCompare(product, inCompare),
                  icon: Icon(
                    inCompare ? LucideIcons.check : LucideIcons.gitCompare,
                    size: 18,
                  ),
                  label: Text(
                    inCompare ? langs('inCompare') : langs('compare'),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: inCompare
                        ? AppColors.brand700
                        : AppColors.navy900,
                    side: BorderSide(
                      color: inCompare ? AppColors.brand700 : AppColors.navy900,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: product.storeLinks.isEmpty
                  ? null
                  : () => _showStores(product),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.navy900,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(langs('buy')),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleCompare(ProductDetail product, bool inCompare) {
    // เพิ่มเป็นช่องของ "โมเดลที่กำลังดูอยู่" เทียบข้ามโมเดลของสินค้าเดียวกันได้
    // ราคาใช้ราคาโมเดลล้วนๆ ไม่รวมตัวเลือกเสริมที่ติ๊กไว้ เพราะตัวเลือกเสริม
    // ไม่ได้เข้าตารางเปรียบเทียบ (คำขอผู้ใช้ 9 ก.ย. 2026 ฝั่งเว็บ)
    final model = _model(product);
    if (inCompare) {
      removeCompareModel(product.productId, model?.modelId);
      return;
    }
    addCompareItem(
      CompareItem(
        productId: product.productId,
        productName: product.productName,
        productImage: product.gallery.isEmpty ? null : product.gallery.first,
        productPrice: model?.productPrice ?? product.productPrice,
        modelId: model?.modelId,
        modelName: model?.modelName,
      ),
    );
  }

  // ปุ่มสั่งซื้อ = เลือกแพลตฟอร์ม (ระบบไม่มีตะกร้าของตัวเอง ส่งต่อร้านค้า)
  void _showStores(ProductDetail product) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: product.storeLinks.entries
              .map(
                (entry) => ListTile(
                  title: Text(entry.key),
                  subtitle: Text(
                    entry.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(LucideIcons.externalLink, size: 18),
                  onTap: () {
                    Navigator.pop(context);
                    // ระบบไม่มีตะกร้าของตัวเอง ส่งต่อไปแอป/เว็บของร้านค้า
                    openExternalLink(context, entry.value, label: entry.key);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
