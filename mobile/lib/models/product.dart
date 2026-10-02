class Product {
  final String productId;
  final String productName;
  final String? productImage;
  final num productPrice;
  final String? slug;

  // มีโมเดลให้เลือกไหม — ปุ่มเปรียบเทียบบนการ์ดใช้ตัดสินว่าต้องถามโมเดลก่อน
  // หรือเพิ่มเข้าตารางได้เลย (backend ส่งมาให้ทั้ง /products และ /search)
  final bool hasModels;

  // รหัสโมเดลทั้งหมดของสินค้าตัวนี้ — ใช้บอกว่าเลือกครบทุกโมเดลแล้วหรือยัง
  // ว่าง = สินค้าไม่มีโมเดล (ทั้ง /products และ /search ส่งช่องนี้มาแล้ว
  // ตั้งแต่ 23 ก.ย. 2026 — ใช้ `utils/productShape.js` ร่วมกัน)
  final List<String> modelIds;

  const Product({
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.productPrice,
    required this.slug,
    this.hasModels = false,
    this.modelIds = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productId: json['product_id'],
      productName: json['product_name'],
      productImage: json['product_image'],
      productPrice: (json['product_price'] as num?) ?? 0,
      slug: json['slug'],
      hasModels: json['has_models'] == true,
      modelIds: ((json['model_ids'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
