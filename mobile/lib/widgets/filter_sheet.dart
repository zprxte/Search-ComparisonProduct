import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../language/app_language.dart';
import '../models/filter_option.dart';
import 'sheet_scaffold.dart';

// แผ่นตัวกรองที่เด้งขึ้นจากข้างล่าง
// คืนค่าที่เลือกเมื่อกด "ดูผลลัพธ์" · คืน null ถ้าผู้ใช้ปิดทิ้ง
//
// เลือกเสร็จค่อยยิง API ทีเดียว ไม่ยิงทุกครั้งที่ติ๊ก
// (ติ๊กทีละอันแล้วโหลดใหม่ รายการจะกระพริบและเปลืองเน็ต)
Future<ProductFilters?> showFilterSheet(
  BuildContext context, {
  required FilterOptions options,
  required ProductFilters current,
  bool isSearch = false,
}) {
  return showModalBottomSheet<ProductFilters>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) =>
        _FilterSheet(options: options, current: current, isSearch: isSearch),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.options,
    required this.current,
    required this.isSearch,
  });

  final FilterOptions options;
  final ProductFilters current;
  final bool isSearch;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _categoryIds = {...widget.current.categoryIds};
  late Set<String> _tags = {...widget.current.tags};
  late String _sort = widget.current.sort;

  void _toggle(Set<String> target, String value) {
    setState(() {
      if (!target.remove(value)) target.add(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      clearLabel: langs('filterclearAll'),
      onClear: () => setState(() {
        _categoryIds = {};
        _tags = {};
        _sort = widget.isSearch ? 'relevance' : 'newest';
      }),
      onApply: () => Navigator.pop(
        context,
        ProductFilters(categoryIds: _categoryIds, tags: _tags, sort: _sort),
      ),
      children: [
        _title(langs('sortHeading')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sortLabels.entries
              // ไม่มีคำค้น ก็ไม่มีอะไรให้วัดว่า "ตรงที่สุด"
              .where((e) => widget.isSearch || e.key != 'relevance')
              .map(
                (e) => ChoiceChip(
                  label: Text(langs(e.value)),
                  selected: _sort == e.key,
                  onSelected: (_) => setState(() => _sort = e.key),
                ),
              )
              .toList(),
        ),
        if (widget.options.categories.isNotEmpty) ...[
          _title(langs('categoryHeading')),
          _chips(widget.options.categories, _categoryIds),
        ],
        if (widget.options.tags.isNotEmpty) ...[
          _title(langs('tagHeading')),
          _chips(widget.options.tags, _tags),
        ],
      ],
    );
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.navy900,
      ),
    ),
  );

  // จำนวนสินค้าต่อท้ายตัวเลือก ทำให้ผู้ใช้รู้ล่วงหน้าว่าติ๊กแล้วเจออะไรบ้าง
  // ไม่ต้องลองผิดลองถูก — backend ส่งตัวเลขนี้มาให้อยู่แล้ว
  Widget _chips(List<FilterOption> options, Set<String> selected) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options
        .map(
          (o) => FilterChip(
            label: Text('${o.label} (${o.count})'),
            selected: selected.contains(o.value),
            onSelected: (_) => _toggle(selected, o.value),
          ),
        )
        .toList(),
  );
}
