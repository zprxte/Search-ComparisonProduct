import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/app_colors.dart';
import '../language/app_language.dart';
import 'sheet_scaffold.dart';

// ไม่ได้เรียงตามอะไร
const String compareSortNone = '';

// เรียงตามราคา — ราคาอยู่ในหัวคอลัมน์ ไม่ใช่แถวสเปค จึงต้องมีคีย์พิเศษของตัวเอง
// (ใช้ชื่อที่ชนกับชื่อหัวข้อสเปคจริงไม่ได้ เลยครอบด้วยขีดล่างสองตัวแบบฝั่งเว็บ)
const String compareSortPrice = '__price__';

// ค่าตัวกรองของตารางเปรียบเทียบทั้งชุด — ส่งเข้า/ออกจากแผ่นตัวกรองเป็นก้อนเดียว
// เหมือนฝั่งเว็บ (`ComparePage.vue`): ติ๊กคุณสมบัติ = จัดอันดับคอลัมน์
// ไม่ใช่ซ่อนสินค้าออกจากตาราง — สินค้าที่ไม่มีคุณสมบัตินั้นยังอยู่ แค่ถูกดันไปขวา
@immutable
class CompareFilter {
  const CompareFilter({
    this.features = const <String>{},
    this.sortField = compareSortNone,
    this.sortAscending = false,
    this.onlyDifferences = false,
    this.onlySelected = false,
  });

  // คุณสมบัติที่ผู้ใช้ติ๊กว่าต้องการ (ใช้นับคะแนนความตรงของแต่ละคอลัมน์)
  final Set<String> features;

  // หัวข้อที่ใช้เรียงคอลัมน์ — ชื่อสเปค, [compareSortPrice] หรือ [compareSortNone]
  final String sortField;
  final bool sortAscending;

  // ซ่อนแถวที่ทุกคอลัมน์มีค่าเท่ากัน
  final bool onlyDifferences;

  // แสดงเฉพาะแถวของคุณสมบัติที่ติ๊กไว้ — ของเพิ่มเฉพาะแอป
  // (จอมือถือเห็นทีละไม่กี่แถว สเปค 30 หัวข้อทำให้ต้องเลื่อนหาหัวข้อที่สนใจนาน)
  final bool onlySelected;

  bool get isActive =>
      features.isNotEmpty ||
      sortField != compareSortNone ||
      onlyDifferences ||
      onlySelected;

  // ตัวเลขบนปุ่มตัวกรอง — นับเฉพาะสิ่งที่ผู้ใช้ตั้งเอง
  // (การเรียงตามสเปคมาพร้อมการติ๊กคุณสมบัติอยู่แล้ว ไม่นับซ้ำ)
  int get badgeCount =>
      features.length +
      (sortField == compareSortPrice ? 1 : 0) +
      (onlyDifferences ? 1 : 0) +
      (onlySelected ? 1 : 0);

  CompareFilter copyWith({
    Set<String>? features,
    String? sortField,
    bool? sortAscending,
    bool? onlyDifferences,
    bool? onlySelected,
  }) {
    return CompareFilter(
      features: features ?? this.features,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      onlyDifferences: onlyDifferences ?? this.onlyDifferences,
      onlySelected: onlySelected ?? this.onlySelected,
    );
  }
}

// แผ่นตัวกรองของหน้าเปรียบเทียบ — คืนค่าที่ตั้งใหม่เมื่อกด "ดูผลลัพธ์"
// คืน null ถ้าผู้ใช้ปัดปิดทิ้ง (ของเดิมไม่ถูกแตะ)
Future<CompareFilter?> showCompareFilterSheet(
  BuildContext context, {
  required List<String> attributeNames,
  required Set<String> computableNames,
  required Set<String> sameNames,
  required CompareFilter current,
}) {
  return showModalBottomSheet<CompareFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _CompareFilterSheet(
      attributeNames: attributeNames,
      computableNames: computableNames,
      sameNames: sameNames,
      current: current,
    ),
  );
}

class _CompareFilterSheet extends StatefulWidget {
  const _CompareFilterSheet({
    required this.attributeNames,
    required this.computableNames,
    required this.sameNames,
    required this.current,
  });

  final List<String> attributeNames;

  // หัวข้อที่อ่านเป็นตัวเลขได้อย่างน้อย 2 คอลัมน์ — มีเฉพาะพวกนี้ที่เรียงลำดับได้จริง
  final Set<String> computableNames;

  // หัวข้อที่ทุกคอลัมน์มีค่าเท่ากัน (ใช้ซ่อนตามสวิตช์ "เฉพาะที่ต่างกัน")
  final Set<String> sameNames;

  final CompareFilter current;

  @override
  State<_CompareFilterSheet> createState() => _CompareFilterSheetState();
}

class _CompareFilterSheetState extends State<_CompareFilterSheet> {
  late Set<String> _features = {...widget.current.features};
  late String _sortField = widget.current.sortField;
  late bool _sortAscending = widget.current.sortAscending;
  late bool _onlyDifferences = widget.current.onlyDifferences;
  late bool _onlySelected = widget.current.onlySelected;

  // ติ๊กคุณสมบัติที่เรียงลำดับได้ = ตั้งให้เป็นตัวเรียงอัตโนมัติ (มาก→น้อยก่อน)
  // เหมือนเว็บ — ผู้ใช้ที่สนใจ "ความละเอียด" ย่อมอยากเห็นตัวที่สูงสุดก่อน
  void _toggleFeature(String name) {
    setState(() {
      if (_features.remove(name)) {
        if (_sortField == name) _sortField = compareSortNone;
        return;
      }
      _features.add(name);
      if (widget.computableNames.contains(name)) {
        _sortField = name;
        _sortAscending = false;
      }
    });
  }

  void _selectSort(String field, String? value) {
    setState(() {
      if (value == null || value.isEmpty) {
        if (_sortField == field) _sortField = compareSortNone;
        return;
      }
      _sortField = field;
      _sortAscending = value == 'asc';
      // เรียงตามหัวข้อไหน ก็ต้องนับหัวข้อนั้นเป็นคุณสมบัติที่ต้องการด้วย
      // ไม่งั้นตัวเลข "ตรงกับที่เลือก" จะไม่ตรงกับสิ่งที่เห็นว่าเรียงอยู่
      if (field != compareSortPrice) _features.add(field);
    });
  }

  String? _sortValueFor(String field) {
    if (_sortField != field) return '';
    return _sortAscending ? 'asc' : 'desc';
  }

  void _clearAll() {
    setState(() {
      _features = {};
      _sortField = compareSortNone;
      _sortAscending = false;
      _onlyDifferences = false;
      _onlySelected = false;
    });
  }

  // เปิด "เฉพาะที่ต่างกัน" แล้วหัวข้อที่ทุกตัวเท่ากันก็ไม่ช่วยจัดอันดับอะไร
  // ซ่อนออกจากรายการด้วย — ยกเว้นหัวข้อที่ติ๊กค้างไว้ ต้องเห็นเสมอ
  // ไม่งั้นตัวกรองที่ทำงานอยู่จะหายไปจากสายตาแต่ยังนับอยู่ในคะแนน
  List<String> get _visibleNames => widget.attributeNames
      .where(
        (name) =>
            !_onlyDifferences ||
            !widget.sameNames.contains(name) ||
            _features.contains(name),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final names = _visibleNames;

    return SheetScaffold(
      clearLabel: langs('compareFilterClear'),
      onClear: _clearAll,
      onApply: () => Navigator.pop(
        context,
        CompareFilter(
          features: _features,
          sortField: _sortField,
          sortAscending: _sortAscending,
          onlyDifferences: _onlyDifferences,
          // ไม่มีอะไรติ๊กไว้ = เปิดโหมดนี้ค้างไม่ได้ ตารางจะว่างเปล่า
          onlySelected: _features.isEmpty ? false : _onlySelected,
        ),
      ),
      children: [
        Text(
          langs('compareFilterTitle'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.navy900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          langs('compareFilterHint'),
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _onlyDifferences,
          onChanged: (value) => setState(() => _onlyDifferences = value),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            langs('compareOnlyDiff'),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        SwitchListTile(
          value: _onlySelected,
          // ไม่ได้ติ๊กอะไรไว้เลย เปิดแล้วตารางจะว่าง ปิดไว้ก่อน
          onChanged: _features.isEmpty
              ? null
              : (value) => setState(() => _onlySelected = value),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            langs('compareOnlySelected'),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        _heading(langs('comparePriceHeading')),
        _SortRow(
          label: langs('compareSortByPrice'),
          value: _sortValueFor(compareSortPrice),
          onChanged: (value) => _selectSort(compareSortPrice, value),
        ),
        _heading(langs('compareFeatureHeading')),
        if (names.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              langs('compareNoFeatures'),
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ...names.map(
          (name) => _FeatureRow(
            name: name,
            selected: _features.contains(name),
            onToggle: () => _toggleFeature(name),
            sortValue: widget.computableNames.contains(name)
                ? _sortValueFor(name)
                : null,
            onSortChanged: (value) => _selectSort(name, value),
          ),
        ),
      ],
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.navy900,
      ),
    ),
  );
}

// แถวคุณสมบัติหนึ่งข้อ: ติ๊กเลือก + ตัวเลือกการเรียง (เฉพาะข้อที่เป็นตัวเลข)
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.name,
    required this.selected,
    required this.onToggle,
    required this.sortValue,
    required this.onSortChanged,
  });

  final String name;
  final bool selected;
  final VoidCallback onToggle;

  // null = หัวข้อนี้เรียงลำดับไม่ได้ (เป็นข้อความล้วน) จึงไม่มี dropdown
  final String? sortValue;
  final ValueChanged<String?> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: (_) => onToggle(),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.navy900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (sortValue != null)
          _SortDropdown(value: sortValue!, onChanged: onSortChanged),
      ],
    );
  }
}

// แถวเรียงลำดับที่ไม่มี checkbox (ใช้กับราคา ซึ่งไม่ใช่หัวข้อสเปค)
class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13.5, color: AppColors.navy900),
          ),
        ),
        _SortDropdown(value: value ?? '', onChanged: onChanged),
      ],
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.circle,
        borderRadius: BorderRadius.circular(999),
      ),
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(12),
        icon: const Icon(LucideIcons.chevronDown, size: 16),
        style: const TextStyle(fontSize: 11.5, color: AppColors.navy900),
        items: [
          DropdownMenuItem(value: '', child: Text(langs('compareSortNone'))),
          DropdownMenuItem(value: 'asc', child: Text(langs('compareSortAsc'))),
          DropdownMenuItem(
            value: 'desc',
            child: Text(langs('compareSortDesc')),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
