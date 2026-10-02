// ตัวเลือกหนึ่งอันในตัวกรอง (หมวดหมู่ หรือ แท็ก) จาก GET /products/filters
class FilterOption {
  final String value; // category_id หรือชื่อแท็ก
  final String label; // ข้อความที่แสดง
  final int count; // มีสินค้ากี่ชิ้น

  const FilterOption({
    required this.value,
    required this.label,
    required this.count,
  });

  factory FilterOption.fromCategory(Map<String, dynamic> json) => FilterOption(
    value: json['category_id'].toString(),
    label: json['category_name']?.toString() ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
  );

  factory FilterOption.fromTag(Map<String, dynamic> json) => FilterOption(
    value: json['tag'].toString(),
    label: json['label']?.toString() ?? json['tag'].toString(),
    count: (json['count'] as num?)?.toInt() ?? 0,
  );
}

// ตัวเลือกทั้งหมดที่หน้าสินค้าเอาไปทำตัวกรอง
class FilterOptions {
  final List<FilterOption> categories;
  final List<FilterOption> tags;

  const FilterOptions({required this.categories, required this.tags});
}

// ค่าที่ผู้ใช้เลือกอยู่ตอนนี้
class ProductFilters {
  final Set<String> categoryIds;
  final Set<String> tags;
  final String sort; // newest / popular / price_asc / price_desc / name

  const ProductFilters({
    this.categoryIds = const {},
    this.tags = const {},
    this.sort = 'newest',
  });

  int get activeCount => categoryIds.length + tags.length;

  // ค่าเริ่มต้นของแต่ละหน้า: ผลการค้นหาเรียงตามความตรงกับคำค้น
  // ส่วนหน้าสินค้าทั้งหมดเรียงใหม่ล่าสุด (เหมือนเว็บ)
  static ProductFilters initial({required bool isSearch}) =>
      ProductFilters(sort: isSearch ? 'relevance' : 'newest');

  ProductFilters copyWith({
    Set<String>? categoryIds,
    Set<String>? tags,
    String? sort,
  }) => ProductFilters(
    categoryIds: categoryIds ?? this.categoryIds,
    tags: tags ?? this.tags,
    sort: sort ?? this.sort,
  );
}

// ค่าเรียงลำดับที่ backend รับ → คีย์ข้อความในโมดูลภาษา (ส่งเข้า langs())
// เก็บเป็นคีย์ ไม่ใช่ข้อความตรงๆ เพราะป้ายต้องเปลี่ยนตามภาษาที่เลือก
// 'relevance' ใช้ได้เฉพาะตอนค้นหา (ไม่มีคำค้นก็ไม่มีอะไรให้วัดความตรง)
const sortLabels = {
  'relevance': 'sortRelevance',
  'newest': 'sortNewest',
  'popular': 'sortPopular',
  'price_asc': 'sortPriceAsc',
  'price_desc': 'sortPriceDesc',
  'name': 'sortName',
};
