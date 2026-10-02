// สินค้าหนึ่งตัวแบบเต็ม (จาก GET /products/:id) — ใช้ในหน้ารายละเอียดสินค้า
class ProductDetail {
  final String productId;
  final String productName;
  final String? categoryName;
  final num productPrice;
  final String? description;
  final String? warrantyText;
  final String? shippingText;
  final List<String> gallery; // path รูป เรียงตาม sort_order
  final List<ProductModelOption> models;
  final List<ProductAddon> options;
  final List<ProductSpec> specs;
  final Map<String, String> storeLinks; // ชื่อร้าน → ลิงก์

  const ProductDetail({
    required this.productId,
    required this.productName,
    required this.categoryName,
    required this.productPrice,
    required this.description,
    required this.warrantyText,
    required this.shippingText,
    required this.gallery,
    required this.models,
    required this.options,
    required this.specs,
    required this.storeLinks,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final gallery = ((json['product_gallery'] as List?) ?? [])
        .map((e) => (e as Map<String, dynamic>)['product_image']?.toString())
        .whereType<String>()
        .toList();

    // สินค้าที่ไม่มีแกลเลอรี ใช้รูปหลักแทน จะได้ไม่เป็นช่องว่างเปล่า
    if (gallery.isEmpty && json['product_image'] != null) {
      gallery.add(json['product_image'].toString());
    }

    final links = <String, String>{};
    void addLink(String label, Object? value) {
      final url = value?.toString();
      if (url != null && url.isNotEmpty) links[label] = url;
    }

    addLink('Shopee', json['shopee_link']);
    addLink('Lazada', json['lazada_link']);
    addLink('TikTok', json['tiktok_link']);
    addLink('LINE', json['line_link']);

    return ProductDetail(
      productId: json['product_id'].toString(),
      productName: json['product_name']?.toString() ?? '',
      categoryName: json['category']?['category_name']?.toString(),
      productPrice: (json['product_price'] as num?) ?? 0,
      description: json['description']?.toString(),
      warrantyText: json['warranty_text']?.toString(),
      shippingText: json['shipping_text']?.toString(),
      gallery: gallery,
      models: ((json['product_model'] as List?) ?? [])
          .map((e) => ProductModelOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      options: ((json['product_option'] as List?) ?? [])
          .map((e) => ProductAddon.fromJson(e as Map<String, dynamic>))
          .toList(),
      specs: ((json['product_attribute_value'] as List?) ?? [])
          .map((e) => ProductSpec.fromJson(e as Map<String, dynamic>))
          .toList(),
      storeLinks: links,
    );
  }
}

// โมเดลของสินค้า — เลือกแล้วราคาเปลี่ยน และสเปคบางข้อถูก override
class ProductModelOption {
  final String modelId;
  final String modelName;
  final num productPrice;
  final List<ProductSpec> specs; // เฉพาะข้อที่โมเดลนี้เขียนทับ

  const ProductModelOption({
    required this.modelId,
    required this.modelName,
    required this.productPrice,
    required this.specs,
  });

  factory ProductModelOption.fromJson(Map<String, dynamic> json) =>
      ProductModelOption(
        modelId: json['model_id'].toString(),
        modelName: json['model_name']?.toString() ?? '',
        productPrice: (json['product_price'] as num?) ?? 0,
        specs: ((json['product_attribute_value'] as List?) ?? [])
            .map((e) => ProductSpec.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// อุปกรณ์เสริม เช่น SD Card — ติ๊กแล้วบวกราคาเพิ่ม
class ProductAddon {
  final String optionId;
  final String optionName;
  final num addonPrice;

  const ProductAddon({
    required this.optionId,
    required this.optionName,
    required this.addonPrice,
  });

  factory ProductAddon.fromJson(Map<String, dynamic> json) => ProductAddon(
    optionId: json['option_id'].toString(),
    optionName: json['option_name']?.toString() ?? '',
    addonPrice: (json['addon_price'] as num?) ?? 0,
  );
}

// สเปค 1 ข้อ (หัวข้อ + ค่า)
class ProductSpec {
  final String name;
  final String value;

  const ProductSpec({required this.name, required this.value});

  factory ProductSpec.fromJson(Map<String, dynamic> json) => ProductSpec(
    name: json['attribute']?['attribute_name']?.toString() ?? '',
    value: json['value']?.toString() ?? '',
  );
}
