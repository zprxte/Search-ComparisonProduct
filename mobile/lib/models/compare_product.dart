// สินค้าหนึ่งตัวจาก GET /products/compare
// เก็บเฉพาะที่ตารางใช้จริง: หัวคอลัมน์ + ค่าสเปค + โมเดลพร้อมค่าที่เขียนทับ
class CompareProduct {
  final String productId;
  final String productName;
  final String? productImage;
  final num productPrice;

  // ชื่อหัวข้อสเปค → ค่าที่ใช้ร่วมทุกโมเดล เช่น {'ความละเอียด': '1080p'}
  final Map<String, String> attributes;

  // โมเดลของสินค้าตัวนี้ (ว่าง = ไม่มีโมเดลให้เลือก)
  final List<CompareModel> models;

  const CompareProduct({
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.productPrice,
    required this.attributes,
    required this.models,
  });

  // ค่าสเปคที่ต้องแสดงจริงของช่องหนึ่งช่อง
  // = ค่าร่วมของสินค้า แล้วให้ค่าเฉพาะโมเดลเขียนทับข้อที่ซ้ำกัน
  Map<String, String> attributesFor(String? modelId) {
    if (modelId == null) return attributes;
    final model = modelById(modelId);
    if (model == null) return attributes;
    return {...attributes, ...model.attributes};
  }

  CompareModel? modelById(String? modelId) {
    for (final model in models) {
      if (model.modelId == modelId) return model;
    }
    return null;
  }

  factory CompareProduct.fromJson(Map<String, dynamic> json) {
    return CompareProduct(
      productId: json['product_id'].toString(),
      productName: json['product_name']?.toString() ?? '',
      productImage: json['product_image']?.toString(),
      productPrice: (json['product_price'] as num?) ?? 0,
      attributes: parseAttributes(json['product_attribute_value']),
      models: ((json['product_model'] as List?) ?? const [])
          .map((row) => CompareModel.fromJson(row as Map<String, dynamic>))
          .toList(),
    );
  }
}

// โมเดลหนึ่งตัว — ราคาของตัวเอง และสเปคเฉพาะข้อที่เขียนทับของสินค้า
class CompareModel {
  final String modelId;
  final String modelName;
  final num productPrice;
  final Map<String, String> attributes;

  const CompareModel({
    required this.modelId,
    required this.modelName,
    required this.productPrice,
    required this.attributes,
  });

  factory CompareModel.fromJson(Map<String, dynamic> json) => CompareModel(
    modelId: json['model_id'].toString(),
    modelName: json['model_name']?.toString() ?? '',
    productPrice: (json['product_price'] as num?) ?? 0,
    attributes: parseAttributes(json['product_attribute_value']),
  );
}

// แปลงลิสต์ product_attribute_value ให้เป็น map ชื่อหัวข้อ → ค่า
// (backend ส่งรูปแบบเดียวกันทั้งของสินค้าและของโมเดล)
Map<String, String> parseAttributes(Object? raw) {
  final values = (raw as List?) ?? const [];
  final attributes = <String, String>{};
  for (final row in values) {
    final map = row as Map<String, dynamic>;
    final name = map['attribute']?['attribute_name']?.toString();
    final value = map['value']?.toString().trim();
    if (name == null || value == null || value.isEmpty) continue;
    // หัวข้อเดียวกันซ้ำหลายแถว เอาแถวแรกที่มีค่าเป็นหลัก
    attributes.putIfAbsent(name, () => value);
  }
  return attributes;
}
