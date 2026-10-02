import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/app_colors.dart';
import '../language/app_language.dart';
import '../models/compare_product.dart';
import '../services/api_service.dart';
import '../stores/compare_store.dart';
import '../utils/snap_scroll_physics.dart';
import '../utils/format.dart';
import '../utils/compare_actions.dart';
import '../widgets/compare_filter_sheet.dart';
import '../widgets/product_picker_sheet.dart';
import '../widgets/async_state.dart';
import '../widgets/pill_style.dart';
import '../widgets/remote_image.dart';

//หนัาเปรียบเทียบสินค้า
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key, this.onBrowse});

  //กดช่องว่าง "เพิ่มสินค้า" แล้วไปหน้าสินค้าทั้งหมด
  final VoidCallback? onBrowse;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final CompareStore _store = CompareStore.instance;

  Future<List<CompareProduct>>? _future;
  String _loadedIds = ''; // ชุดรหัสที่โหลดไปแล้ว กันยิง API ซ้ำโดยไม่จำเป็น

  //ตัวกรองของตาราง (คุณสมบัติที่ติ๊ก + การเรียง + สวิตช์ซ่อนแถว)
  CompareFilter _filter = const CompareFilter();

  //ดึงค่าตัวกรองมาจาก store
  @override
  void initState() {
    super.initState();
    _store.items.addListener(_reload);
    _reload();
  }

  //ลบค่าสินค้าออกจาก store
  @override
  void dispose() {
    _store.items.removeListener(_reload);
    super.dispose();
  }

  //โหลดสินค้า
  void _reload() {
    // สินค้าเดียวกันหลายโมเดลใช้ข้อมูลก้อนเดียว ยิง API ครั้งเดียวพอ
    final ids = <String>{for (final item in _store.items.value) item.productId}
        .toList();
    final key = ids.join(',');
    if (key == _loadedIds) return; // รายการเดิม ไม่ต้องโหลดใหม่
    setState(() {
      _loadedIds = key;
      _future = ids.isEmpty ? null : ApiService().fetchCompare(ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        shape: const Border(),
        title: Text(langs('compareTitle')),
        actions: [
          ValueListenableBuilder<List<CompareItem>>(
            valueListenable: _store.items,
            builder: (context, items, _) => items.isEmpty
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: _store.clear,
                    child: Text(langs('clearAll')),
                  ),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<CompareItem>>(
        valueListenable: _store.items,
        builder: (context, items, _) {
          if (items.isEmpty) return _EmptyState(onBrowse: widget.onBrowse);

          return FutureBuilder<List<CompareProduct>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              if (snapshot.hasError) {
                return ErrorView(
                  title: langs('compareLoadError'),
                  error: snapshot.error,
                  onRetry: () {
                    _loadedIds = ''; // บังคับให้โหลดใหม่
                    _reload();
                  },
                );
              }

              final products = snapshot.data ?? const <CompareProduct>[];
              if (products.isEmpty) {
                return _EmptyState(onBrowse: widget.onBrowse);
              }

              // หนึ่งคอลัมน์ = หนึ่งช่องในตะกร้า (สินค้า, โมเดล) ไม่ใช่หนึ่งสินค้า
              // ข้อมูลสเปคหยิบจากสินค้าที่โหลดมา แล้วให้ค่าเฉพาะโมเดลเขียนทับ
              final columns = <_CompareColumn>[];
              for (final item in items) {
                final product = products
                    .where((p) => p.productId == item.productId)
                    .firstOrNull;
                if (product == null) continue; // สินค้าถูกปิดการขายไปแล้ว
                columns.add(_CompareColumn(item: item, product: product));
              }
              if (columns.isEmpty) {
                return _EmptyState(onBrowse: widget.onBrowse);
              }

              return _CompareTable(
                columns: columns,
                filter: _filter,
                onFilterChanged: (value) => setState(() => _filter = value),
                onRemove: _store.removeKey,
                onBrowse: widget.onBrowse,
              );
            },
          );
        },
      ),
    );
  }
}

//หนึ่งคอลัมน์ในตาราง = ช่องในตะกร้า + ข้อมูลสินค้าที่โหลดมาแล้ว
class _CompareColumn {
  _CompareColumn({required this.item, required this.product});

  final CompareItem item;
  final CompareProduct product;

  String get key => item.key;
  String get name => item.productName;
  String? get modelName => item.modelName;
  String? get modelId => item.modelId;
  String? get image => product.productImage ?? item.productImage;
  num get price => item.productPrice;

  //สเปคของช่องนี้ = ค่าร่วมของสินค้า ทับด้วยค่าเฉพาะโมเดลที่เลือก
  late final Map<String, String> attributes = product.attributesFor(
    item.modelId,
  );
}

//ค่าที่ถือว่า "ไม่มีคุณสมบัตินี้" ตอนนับคะแนนความตรงกับที่ผู้ใช้ติ๊ก
const Set<String> _negativeFeatureValues = {
  '',
  '-',
  'ไม่มี',
  'ไม่',
  'no',
  'false',
  '0',
  'x',
  '✗',
};

bool _hasFeature(_CompareColumn column, String name) {
  final raw = column.attributes[name];
  if (raw == null) return false;
  return !_negativeFeatureValues.contains(raw.trim().toLowerCase());
}

//อ่านตัวเลขตัวแรกของข้อความหนึ่งท่อน — กติกาเดียวกับ `parseNumber()` ของเว็บ
//"2K" = 2000 และ "4K" = 4000 (ตัวเลขที่ตามด้วย K แปลว่าพัน) ต้องแปลงก่อนเสมอ
//ไม่งั้น "2K@30fps" จะถูกอ่านเป็นเลข 2 แล้วแพ้ "1080P@30fps" ทั้งที่ชัดกว่า
//ท้าย K ต้องไม่ใช่ตัวอักษร/ตัวเลขต่อ กันไปโดนรหัสรุ่นอย่าง "2K5" เข้า
double? _parseNumber(String raw) {
  final k = RegExp(r'(\d+(?:\.\d+)?)\s*[kK](?!\w)').firstMatch(raw);
  if (k != null) {
    final value = double.tryParse(k.group(1)!);
    if (value != null) return value * 1000;
  }
  final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(raw);
  return match == null ? null : double.tryParse(match.group(0)!);
}

// อ่านตัวเลขของค่าที่เป็นรายการหลายค่า เช่น
// "กล้องหน้า 2K, กล้องหลัง 1080P" → [2000, 1080]
//
// ตัดเป็นท่อนก่อนแล้วเอาตัวเลขตัวแรกของแต่ละท่อน (เหมือนเว็บ) ไม่ใช่กวาดทุกตัวเลข
// ในข้อความ ไม่งั้นหน่วยที่พ่วงมาอย่าง "@30fps" จะถูกนับเป็นค่าของสเปคด้วย
List<double> _parseAllNumbers(String? raw) {
  if (raw == null) return const [];
  final numbers = <double>[];
  for (final segment in raw.split(RegExp(r',|/|และ|\n'))) {
    final parsed = _parseNumber(segment);
    if (parsed != null) numbers.add(parsed);
  }
  return numbers;
}

class _CompareTable extends StatelessWidget {
  const _CompareTable({
    required this.columns,
    required this.filter,
    required this.onFilterChanged,
    required this.onRemove,
    this.onBrowse,
  });

  final List<_CompareColumn> columns;
  final CompareFilter filter;
  final ValueChanged<CompareFilter> onFilterChanged;
  final ValueChanged<String> onRemove;
  final VoidCallback? onBrowse;

  // ยังไม่เต็มเพดาน = ต่อช่องว่างอีกหนึ่งช่องท้ายตาราง (เหมือนเว็บ)
  // ต่อทีละช่องพอ ไม่ต่อจนเต็มเพดาน เพราะจอมือถือเห็นทีละ 2 คอลัมน์
  // ช่องว่างหลายช่องรวดจะดันสินค้าจริงหลุดจอไปโดยไม่ได้ประโยชน์
  bool get _hasAddSlot => columns.length < CompareStore.maxItems;
  int get _slotCount => columns.length + (_hasAddSlot ? 1 : 0);

  // รวมหัวข้อสเปคของทุกคอลัมน์ โดยคงลำดับที่เจอครั้งแรกไว้
  // (เรียงตามที่แอดมินตั้งไว้ ไม่ใช่เรียงตามตัวอักษร)
  List<String> get _attributeNames {
    final names = <String>[];
    for (final column in columns) {
      for (final name in column.attributes.keys) {
        if (!names.contains(name)) names.add(name);
      }
    }
    return names;
  }

  bool _isSame(String attribute) {
    final values = columns
        .map((c) => c.attributes[attribute] ?? 'ไม่มี')
        .toSet();
    return values.length == 1;
  }

  // หัวข้อที่เรียงลำดับได้จริง = อ่านเป็นตัวเลขได้อย่างน้อย 2 คอลัมน์
  // (มีคอลัมน์เดียวที่เป็นตัวเลข ก็ไม่มีอะไรให้เทียบกัน)
  Set<String> _computableNames(List<String> names) {
    return names.where((name) {
      final numeric = columns
          .where(
            (column) => _parseAllNumbers(column.attributes[name]).isNotEmpty,
          )
          .length;
      return numeric >= 2;
    }).toSet();
  }

  // เทียบคอลัมน์สองตัวตามหัวข้อที่เลือกเรียง — ตัวที่ไม่มีค่าตกไปท้ายเสมอ
  // ตัวเลขตัวมากสุดเป็นตัวตัดสินหลัก เท่ากันแล้วดูว่ามีค่าหลายตัวกว่ากัน
  // (เช่นมีกล้อง 2 ตัวย่อมดีกว่ากล้องตัวเดียวที่ความละเอียดเท่ากัน)
  int _compareBySortField(
    String field,
    bool ascending,
    _CompareColumn a,
    _CompareColumn b,
  ) {
    final sign = ascending ? 1 : -1;
    if (field == compareSortPrice) {
      // ราคา 0 = "ติดต่อสอบถาม" ถือว่าไม่มีราคา ตกไปท้ายเสมอทั้งสองทิศทาง
      final priceA = a.price == 0 ? null : a.price;
      final priceB = b.price == 0 ? null : b.price;
      if (priceA == null && priceB == null) return 0;
      if (priceA == null) return 1;
      if (priceB == null) return -1;
      return (priceA - priceB).sign.toInt() * sign;
    }
    final numbersA = _parseAllNumbers(a.attributes[field]);
    final numbersB = _parseAllNumbers(b.attributes[field]);
    if (numbersA.isEmpty && numbersB.isEmpty) return 0;
    if (numbersA.isEmpty) return 1;
    if (numbersB.isEmpty) return -1;
    final maxA = numbersA.reduce((x, y) => x > y ? x : y);
    final maxB = numbersB.reduce((x, y) => x > y ? x : y);
    if (maxA != maxB) return (maxA - maxB).sign.toInt() * sign;
    return (numbersA.length - numbersB.length).sign * sign;
  }

  @override
  Widget build(BuildContext context) {
    final names = _attributeNames;
    final computable = _computableNames(names);
    final sameNames = names.where(_isSame).toSet();

    // สินค้าที่มีคุณสมบัติที่ติ๊กไว้อาจถูกเอาออกจากตารางไปแล้ว — หัวข้อที่ไม่มี
    // อยู่จริงต้องไม่ถูกนับ ไม่งั้น "ตรงกับที่เลือก 1/3" จะอ้างถึงหัวข้อที่มองไม่เห็น
    final features = filter.features.where(names.contains).toSet();
    final sortField =
        filter.sortField == compareSortPrice ||
            computable.contains(filter.sortField)
        ? filter.sortField
        : compareSortNone;
    final effective = filter.copyWith(features: features, sortField: sortField);

    // นับว่าแต่ละคอลัมน์ตรงกับคุณสมบัติที่ติ๊กไว้กี่ข้อ
    final matchByKey = <String, int>{};
    if (features.isNotEmpty) {
      for (final column in columns) {
        matchByKey[column.key] = features
            .where((name) => _hasFeature(column, name))
            .length;
      }
    }

    // เรียงคอลัมน์: ตรงกับที่ติ๊กมากกว่ามาก่อน แล้วค่อยเรียงตามหัวข้อที่เลือก
    // เท่ากันหมดให้คงลำดับเดิมในตะกร้า (stable sort ด้วยดัชนีเดิม)
    final ordered = [
      for (var i = 0; i < columns.length; i++) (index: i, column: columns[i]),
    ];
    ordered.sort((a, b) {
      if (matchByKey.isNotEmpty) {
        final diff =
            (matchByKey[b.column.key] ?? 0) - (matchByKey[a.column.key] ?? 0);
        if (diff != 0) return diff;
      }
      if (sortField != compareSortNone) {
        final diff = _compareBySortField(
          sortField,
          effective.sortAscending,
          a.column,
          b.column,
        );
        if (diff != 0) return diff;
      }
      return a.index - b.index;
    });
    final sorted = [for (final entry in ordered) entry.column];

    // ติดป้าย "แนะนำ" เฉพาะตอนที่คอลัมน์แรกชนะคอลัมน์ถัดไปจริงๆ —
    // ตรงเท่ากันหมดและไม่มีสเปคตัวเลขให้ตัดสิน ก็ไม่มีตัวไหนดีกว่า
    var highlightIndex = -1;
    if (sorted.length >= 2) {
      final first = sorted[0];
      final second = sorted[1];
      final matchFirst = matchByKey[first.key] ?? 0;
      final matchSecond = matchByKey[second.key] ?? 0;
      if (matchByKey.isNotEmpty && matchFirst > matchSecond) {
        highlightIndex = 0;
      } else if (sortField != compareSortNone &&
          _compareBySortField(
                sortField,
                effective.sortAscending,
                first,
                second,
              ) <
              0) {
        highlightIndex = 0;
      }
    }

    // แถวที่จะแสดงจริงหลังกรอง
    var rows = names;
    if (effective.onlySelected && features.isNotEmpty) {
      rows = rows.where(features.contains).toList();
    }
    if (effective.onlyDifferences) {
      rows = rows.where((name) => !sameNames.contains(name)).toList();
    }

    Future<void> openFilter() async {
      final next = await showCompareFilterSheet(
        context,
        attributeNames: names,
        computableNames: computable,
        sameNames: sameNames,
        current: effective,
      );
      if (next != null) onFilterChanged(next);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // มือถือเห็นทีละ 2 คอลัมน์ ถ้าจอกว้างพอก็กางให้ครบทุกคอลัมน์
        final fitAll = constraints.maxWidth / _slotCount >= 180;
        final columnWidth = fitAll
            ? constraints.maxWidth / _slotCount
            : constraints.maxWidth / 2;
        final tableWidth = columnWidth * _slotCount;

        // หัวตาราง: การ์ดสินค้าแต่ละคอลัมน์
        final headerRow = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...sorted.indexed.map(
              (entry) => SizedBox(
                width: columnWidth,
                child: _ColumnHeader(
                  column: entry.$2,
                  recommended: entry.$1 == highlightIndex,
                  matchCount: matchByKey[entry.$2.key],
                  featureCount: features.length,
                  onRemove: () => onRemove(entry.$2.key),
                  onBrowse: onBrowse,
                ),
              ),
            ),
            if (_hasAddSlot)
              SizedBox(
                width: columnWidth,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AspectRatio(
                    // สูงเท่ารูปในหัวคอลัมน์ข้างๆ พอดี
                    aspectRatio: 1,
                    child: _AddSlot(
                      onTap: () => showProductPickerSheet(
                        context,
                        onBrowseAll: onBrowse,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );

        final cloneRow = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...sorted.map(
              (column) => SizedBox(
                width: columnWidth,
                child: _CloneHeaderCell(
                  column: column,
                  onRemove: () => onRemove(column.key),
                  onBrowse: onBrowse,
                ),
              ),
            ),
            // ช่องว่าง "เพิ่มสินค้า" ไม่มีอะไรให้ค้าง แต่ต้องกันที่ไว้ให้ตรงคอลัมน์
            if (_hasAddSlot) SizedBox(width: columnWidth),
          ],
        );

        final bodyRows = <Widget>[
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                names.isEmpty
                    ? langs('compareNoSpecs')
                    : effective.onlySelected
                    ? langs('compareNoFilteredRows')
                    : langs('compareAllSame'),
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ...rows.map(
            (name) => _AttributeRow(
              name: name,
              columns: sorted,
              columnWidth: columnWidth,
              isSame: sameNames.contains(name),
              hasAddSlot: _hasAddSlot,
            ),
          ),
          const SizedBox(height: 24),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterBar(
              filter: effective,
              onOpen: openFilter,
              onClear: () => onFilterChanged(const CompareFilter()),
            ),
            const Divider(height: 1),
            Expanded(
              child: _StickyTable(
                columnWidth: columnWidth,
                tableWidth: tableWidth,
                header: headerRow,
                clone: cloneRow,
                body: bodyRows,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ตารางที่ "หัวค้าง" ตอนเลื่อนดูสเปคยาวๆ
class _StickyTable extends StatefulWidget {
  const _StickyTable({
    required this.columnWidth,
    required this.tableWidth,
    required this.header,
    required this.clone,
    required this.body,
  });

  final double columnWidth;
  final double tableWidth;

  // หัวตารางจริง (การ์ดสินค้าเต็มใบ) อยู่ในสายการเลื่อนตามปกติ
  final Widget header;

  // หัวจำลองแบบย่อ โผล่มาทับเมื่อหัวจริงเลื่อนพ้นจอไปแล้ว
  final Widget clone;

  final List<Widget> body;

  @override
  State<_StickyTable> createState() => _StickyTableState();
}

class _StickyTableState extends State<_StickyTable> {
  final ScrollController _vertical = ScrollController();
  final ScrollController _bodyH = ScrollController();
  final ScrollController _cloneH = ScrollController();
  final GlobalKey _headerKey = GlobalKey();

  double _headerHeight = 0;
  bool _showClone = false;

  @override
  void initState() {
    super.initState();
    _vertical.addListener(_updateCloneVisibility);
    _bodyH.addListener(_syncClone);
  }

  @override
  void didUpdateWidget(_StickyTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // เพิ่ม/เปลี่ยนสินค้าแล้วความสูงของหัวตารางเปลี่ยนได้ ต้องวัดใหม่
    _scheduleMeasure();
  }

  @override
  void dispose() {
    _vertical.dispose();
    _bodyH.dispose();
    _cloneH.dispose();
    super.dispose();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
      final height = box?.size.height ?? 0;
      if (height != _headerHeight) {
        _headerHeight = height;
        _updateCloneVisibility();
      }
      _syncClone();
    });
  }

  // หัวจริงเลื่อนพ้นจอเมื่อไหร่ ก็สลับมาโชว์หัวจำลองแทน
  // เทียบค่าก่อน setState เสมอ ไม่งั้นจะวาดใหม่ทุกพิกเซลที่นิ้วลาก
  void _updateCloneVisibility() {
    if (_headerHeight <= 0 || !_vertical.hasClients) return;
    final show = _vertical.offset >= _headerHeight;
    if (show == _showClone) return;
    setState(() => _showClone = show);
    // หัวจำลองเพิ่งถูกสร้าง ตัวเลื่อนแนวนอนของมันยังอยู่ที่ 0
    // ต้องดันไปให้ตรงกับตารางจริงก่อนผู้ใช้ทันเห็นว่าคนละคอลัมน์กัน
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncClone());
  }

  void _syncClone() {
    if (!_cloneH.hasClients || !_bodyH.hasClients) return;
    final target = _bodyH.offset.clamp(0.0, _cloneH.position.maxScrollExtent);
    if ((_cloneH.offset - target).abs() > 0.5) _cloneH.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();

    return Stack(
      // ตัวเลื่อนต้องสูงเต็มพื้นที่เสมอ ไม่งั้นตอนสเปคสั้นกว่าจอ พื้นที่ว่างข้างล่าง
      // จะลากไม่ติด (Stack แบบ loose ย่อตัวลงเท่าลูกที่สูงสุด)
      fit: StackFit.expand,
      children: [
        SingleChildScrollView(
          controller: _vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _bodyH,
            // ปัดแล้วหยุดตรงขอบคอลัมน์เสมอ ไม่ค้างครึ่งคอลัมน์
            physics: SnapScrollPhysics(itemExtent: widget.columnWidth),
            child: SizedBox(
              width: widget.tableWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyedSubtree(key: _headerKey, child: widget.header),
                  ...widget.body,
                ],
              ),
            ),
          ),
        ),
        if (_showClone)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              elevation: 2,
              color: AppColors.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _cloneH,
                // ปัดที่หัวจำลองไม่ได้ ให้ปัดที่ตัวตารางแล้วหัวเลื่อนตามเอง
                // (ปัดได้สองที่ = สองตัวเลื่อนแย่งกันสั่ง jumpTo ใส่กันไปมา)
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(width: widget.tableWidth, child: widget.clone),
              ),
            ),
          ),
      ],
    );
  }
}

// หนึ่งคอลัมน์ของหัวค้าง — เลียนหัวตารางจำลองของเว็บ:
// บรรทัดบน รูปเล็ก + ชื่อสินค้า + ปุ่มเอาออก · บรรทัดล่าง ปุ่มเปลี่ยนสินค้า | เลือกโมเดล
class _CloneHeaderCell extends StatelessWidget {
  const _CloneHeaderCell({
    required this.column,
    required this.onRemove,
    this.onBrowse,
  });

  final _CompareColumn column;
  final VoidCallback onRemove;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: RemoteImage(path: column.image, iconSize: 16),
              ),
              const SizedBox(width: 6),
              // ชื่อบรรทัดเดียวแบบเว็บ — หัวค้างต้องเตี้ยที่สุดเท่าที่ยังอ่านออก
              // ไม่งั้นมันไปบังแถวสเปคที่กำลังอ่านอยู่เสียเอง
              Expanded(
                child: Text(
                  column.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy900,
                  ),
                ),
              ),
              InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: Icon(LucideIcons.x, size: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // ปุ่มชุดเดียวกับหัวจริง ใช้ได้เลยโดยไม่ต้องเลื่อนกลับขึ้นไปบนสุด
          Row(
            children: [
              Expanded(
                child: _HeaderButton(
                  icon: LucideIcons.arrowLeftRight,
                  label: langs('swapProduct'),
                  onTap: () => showProductPickerSheet(
                    context,
                    onBrowseAll: onBrowse,
                    replaceKey: column.key,
                  ),
                ),
              ),
              if (column.product.models.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(child: _ModelDropdown(column: column)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// แถบตัวกรองเหนือตาราง: ปุ่มเปิดแผ่นตัวกรอง (มีตัวเลขบอกจำนวนที่ตั้งไว้)
// กับปุ่มล้างการกรอง — แค่สองปุ่ม ไม่มีชิปรายหัวข้อ
//
// เดิมมีชิปของคุณสมบัติที่ติ๊กไว้เรียงอยู่ใต้ปุ่ม แต่เอาออกตามคำขอผู้ใช้
// (23 ก.ย. 2026): เว็บไม่มีชิปแบบนี้ สถานะที่ติ๊กไว้ดูได้ในแผ่นตัวกรองอยู่แล้ว
// และชิปกินพื้นที่แนวตั้งเหนือตารางซึ่งจอมือถือมีน้อย
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.onOpen,
    required this.onClear,
  });

  final CompareFilter filter;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
                  label: Text(
                    filter.badgeCount > 0
                        ? '${langs('compareFilterButton')} · ${filter.badgeCount}'
                        : langs('compareFilterButton'),
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: pillButtonStyle(
                    foreground: filter.isActive
                        ? AppColors.brand700
                        : AppColors.navy900,
                    background: filter.isActive
                        ? AppColors.brand50
                        : AppColors.white,
                    borderColor: filter.isActive
                        ? AppColors.brand300
                        : AppColors.border,
                  ),
                ),
                const Spacer(),
                if (filter.isActive)
                  TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(LucideIcons.x, size: 16),
                    label: Text(
                      langs('compareFilterClear'),
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.column,
    required this.onRemove,
    required this.recommended,
    required this.matchCount,
    required this.featureCount,
    this.onBrowse,
  });

  final _CompareColumn column;
  final VoidCallback onRemove;

  // คอลัมน์นี้ชนะตามตัวกรองที่ตั้งไว้ — ติดป้าย "แนะนำ" ทับมุมรูป
  final bool recommended;

  // ตรงกับคุณสมบัติที่ติ๊กไว้กี่ข้อ (null = ยังไม่ได้ติ๊กอะไร ไม่ต้องแสดง)
  final int? matchCount;
  final int featureCount;

  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RemoteImage(path: column.image),
                ),
              ),
              // ป้าย "แนะนำ" ทับมุมล่างซ้ายของรูป — มุมบนขวาเป็นปุ่มเอาออกแล้ว
              if (recommended)
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brand700,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      langs('compareRecommended'),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              // ปุ่มเอาออก ทับมุมรูปเหมือนหน้าเว็บ
              Positioned(
                top: 0,
                right: 0,
                child: Material(
                  color: AppColors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(LucideIcons.x, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            column.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: AppColors.navy900,
            ),
          ),
          // ชื่อโมเดลต้องอยู่ใต้ชื่อสินค้าเสมอ ไม่งั้นสินค้าตัวเดียวกันสองโมเดล
          // จะเป็นสองคอลัมน์ที่หน้าตาเหมือนกันเป๊ะ แยกไม่ออกว่าอันไหนรุ่นอะไร
          if (column.modelName != null) ...[
            const SizedBox(height: 2),
            Text(
              column.modelName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            formatPrice(column.price),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.brand700,
            ),
          ),
          // ตรงกับที่เลือกกี่ข้อ — ต้องบอกเป็นตัวเลข ไม่งั้นผู้ใช้เห็นแค่ลำดับ
          // ที่สลับไปมาโดยไม่รู้ว่าระบบตัดสินจากอะไร
          if (matchCount != null) ...[
            const SizedBox(height: 4),
            Text(
              '${langs('compareMatchLabel')} $matchCount/$featureCount',
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 8),
          // สองปุ่มแถวเดียวกันคนละครึ่งเหมือนเว็บ: เปลี่ยนทั้งสินค้า | เปลี่ยนแค่โมเดล
          // ทั้งคู่ "แทนที่ช่องเดิมในตำแหน่งเดิม" ไม่ใช่เอาออกแล้วเพิ่มใหม่
          // (ซึ่งจะทำให้คอลัมน์สลับที่ทั้งที่ผู้ใช้แค่เปลี่ยนของในช่องเดียว)
          Row(
            children: [
              Expanded(
                child: _HeaderButton(
                  icon: LucideIcons.arrowLeftRight,
                  label: langs('swapProduct'),
                  onTap: () => showProductPickerSheet(
                    context,
                    onBrowseAll: onBrowse,
                    replaceKey: column.key,
                  ),
                ),
              ),
              // มีโมเดลก็โชว์ช่องเลือกเสมอ แม้มีโมเดลเดียว (ตามฝั่งเว็บ 23 ก.ย. 2026)
              // ไม่งั้นผู้ใช้ไม่รู้ว่าค่าที่อ่านอยู่เป็นสเปคของโมเดลไหน
              if (column.product.models.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(child: _ModelDropdown(column: column)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ตัวเลือกโมเดลบนหัวคอลัมน์ — dropdown เหมือนเว็บ (ComparePage.vue ใช้ <select>)
// เลือกแล้วสลับโมเดลในช่องนั้นทันที ไม่ต้องเปิดป็อปอัปอีกชั้น
class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({required this.column});

  final _CompareColumn column;

  void _select(BuildContext context, String modelId) {
    final model = column.product.modelById(modelId);
    if (model == null) return;
    // เลือกโมเดลที่อีกช่องถืออยู่แล้ว = สลับที่กันสองช่อง (ดู CompareStore.replace)
    addCompareItem(
      CompareItem(
        productId: column.product.productId,
        productName: column.product.productName,
        productImage: column.product.productImage,
        productPrice: model.productPrice,
        modelId: model.modelId,
        modelName: model.modelName,
      ),
      replaceKey: column.key,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      // Container ที่กำหนดความสูงแต่ไม่บอก alignment จะวางลูกชิดบนซ้าย
      // ตัว dropdown เตี้ยกว่าเม็ดยา ถ้าไม่สั่งตรงนี้ข้อความจะลอยอยู่ข้างบน
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.circle,
        borderRadius: BorderRadius.circular(999),
      ),
      child: DropdownButton<String>(
        value: column.modelId,
        isExpanded: true, // ไม่ใส่แล้วชื่อโมเดลยาวๆ จะล้นออกนอกเม็ดยา
        isDense: true,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(12),
        icon: const Icon(LucideIcons.chevronDown, size: 16),
        style: const TextStyle(fontSize: 11.5, color: AppColors.navy900),
        // รายการที่กางออกมามีที่มากกว่าในเม็ดยา โชว์ราคาต่อท้ายได้ด้วย
        selectedItemBuilder: (context) => column.product.models
            .map(
              (model) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  model.modelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.navy900,
                  ),
                ),
              ),
            )
            .toList(),
        items: column.product.models
            .map(
              (model) => DropdownMenuItem<String>(
                value: model.modelId,
                child: Text(
                  '${model.modelName} · ${formatPrice(model.productPrice)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            )
            .toList(),
        onChanged: (modelId) {
          if (modelId != null) _select(context, modelId);
        },
      ),
    );
  }
}

// ปุ่มเม็ดยาเล็กๆ บนหัวคอลัมน์ — สองตัวหน้าตาเหมือนกัน ต่างแค่ไอคอน/ข้อความ
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5),
      ),
      style: pillButtonStyle(
        foreground: AppColors.navy900,
        background: AppColors.circle,
        // ไอคอนกับข้อความชิดกันหน่อย คอลัมน์แคบจะได้ไม่ตัดคำ
        padding: const EdgeInsets.symmetric(horizontal: 4),
        fillWidth: true,
      ).copyWith(iconAlignment: IconAlignment.start),
    );
  }
}

class _AttributeRow extends StatelessWidget {
  const _AttributeRow({
    required this.name,
    required this.columns,
    required this.columnWidth,
    required this.isSame,
    required this.hasAddSlot,
  });

  final String name;
  final List<_CompareColumn> columns;
  final double columnWidth;
  final bool isSame;

  // มีช่องว่าง "เพิ่มสินค้า" ต่อท้ายหรือไม่ — ต้องเว้นเซลล์เปล่าไว้ให้ตรงกัน
  final bool hasAddSlot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ชื่อหัวข้อ: แถบเต็มความกว้าง + ป้ายบอกว่าเหมือน/ต่าง
        // เทาเข้มกว่าพื้นหน้าหนึ่งระดับ — พื้นหน้าเป็น surface แล้ว ถ้าใช้ surface
        // ตรงนี้ด้วย แถบจะกลืนหายไปกับพื้น
        Container(
          width: double.infinity,
          color: AppColors.circle,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  // ป้าย "เหมือนกัน" พื้นขาว ไม่งั้นกลืนกับแถบหัวข้อที่เป็นสี circle
                  color: isSame ? AppColors.white : AppColors.brand50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isSame ? langs('compareSame') : langs('compareDifferent'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSame ? AppColors.muted : AppColors.brand700,
                  ),
                ),
              ),
            ],
          ),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...columns.map((column) {
                return Container(
                  width: columnWidth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: AppColors.border),
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Text(
                    column.attributes[name] ?? 'ไม่มี',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.navy900,
                    ),
                  ),
                );
              }),
              if (hasAddSlot)
                Container(
                  width: columnWidth,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// หน้าตอนยังไม่มีสินค้าในตาราง — ทำตามหน้าเว็บ: ไม่ใช่ข้อความเปล่าๆ
// แต่โชว์ "ช่องว่าง" ของตารางเป็นกรอบประเท่าจำนวนที่เพิ่มได้ ให้เห็นภาพว่า
// ตารางจะหน้าตาแบบไหนและเพิ่มได้อีกกี่ชิ้น · กดช่องไหนก็ไปหน้าสินค้าทั้งหมด
class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onBrowse});

  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Text(
          langs('compareEmptyTitle'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.navy900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          langs('compareEmptyBody', {'max': CompareStore.maxItems}),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 20),
        // ช่องว่างเรียง 2 คอลัมน์เท่าหน้ารายการสินค้า
        // (จำนวนช่องมาจาก CompareStore.maxItems ไม่ได้ fix ไว้)
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: List.generate(
            CompareStore.maxItems,
            (_) => _AddSlot(
              onTap: () =>
                  showProductPickerSheet(context, onBrowseAll: onBrowse),
            ),
          ),
        ),
      ],
    );
  }
}

// ช่องว่างหนึ่งช่องในตาราง (กรอบประ + เครื่องหมายบวก) เหมือนหัวคอลัมน์ว่างบนเว็บ
class _AddSlot extends StatelessWidget {
  const _AddSlot({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DottedBorderBox(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.plus, size: 26, color: AppColors.muted),
          const SizedBox(height: 6),
          Text(
            langs('addProduct'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// กรอบเส้นประแบบเดียวกับ border-dashed ของเว็บ
// Flutter ไม่มีเส้นประในตัว ต้องวาดเองด้วย CustomPaint
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );

    // เดินไปตามเส้นรอบกรอบแล้ววาดทีละช่วง เว้นช่วง ได้เป็นเส้นประ
    const dash = 6.0;
    const gap = 4.0;
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}
