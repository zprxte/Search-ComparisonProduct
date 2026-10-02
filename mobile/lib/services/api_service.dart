import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/category.dart';
import '../models/compare_product.dart';
import '../models/filter_option.dart';
import '../models/product_detail.dart';
import '../models/product.dart';
import '../models/shop.dart';

class ProductPage {
  final List<Product> products;
  final int page;
  final int totalPages;
  final int total; // จำนวนรายการทั้งหมด (ทุกหน้ารวมกัน)
  const ProductPage({
    required this.products,
    required this.page,
    required this.totalPages,
    this.total = 0,
  });
}

// คำแนะนำ 1 รายการ — ใช้ได้ทั้ง autocomplete และ "คุณหมายถึง…?"
// มี productId เพื่อให้กดแล้วเข้าหน้าสินค้าได้เลย ไม่ต้องพิมพ์ค้นใหม่
class SearchSuggestion {
  final String productId;
  final String productName;
  final String? slug;

  const SearchSuggestion({
    required this.productId,
    required this.productName,
    required this.slug,
  });

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) =>
      SearchSuggestion(
        productId: json['product_id'].toString(),
        productName: json['product_name']?.toString() ?? '',
        slug: json['slug']?.toString(),
      );
}

class SearchResult {
  final List<Product> products;
  final int page;
  final int totalPages;
  final int total;

  // คำที่ระบบใช้ค้นจริงเมื่อกู้คำที่พิมพ์ผิดแป้นให้ (null = ใช้คำที่ผู้ใช้พิมพ์)
  final String? searchedAs;

  // มีค่าเฉพาะตอนค้นไม่เจอ — เอาไปทำ "คุณหมายถึง…?"
  final List<SearchSuggestion> suggestions;

  const SearchResult({
    required this.products,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.searchedAs,
    required this.suggestions,
  });
}

class CategoryPage {
  final List<Category> categories;
  final int page;
  final int totalPages;
  const CategoryPage({
    required this.categories,
    required this.page,
    required this.totalPages,
  });
}

class ShopPage {
  final List<Shop> shops;
  final int page;
  final int totalPages;
  const ShopPage({
    required this.shops,
    required this.page,
    required this.totalPages,
  });
}

class ApiService {
  // ตัวกลางเรียก GET ทุกเส้นทาง — รวมการเช็ค status code ไว้ที่เดียว
  // จะได้ไม่ต้องเขียนซ้ำทุกเมธอด
  Future<dynamic> _getJson(String path) async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}$path'));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} จาก $path');
    }
    // ต้องอ่านเป็น bodyBytes แล้ว decode เป็น UTF-8 เอง — response.body ใช้
    // latin1 เมื่อ header ไม่ได้ระบุ charset ทำให้ชื่อสินค้าภาษาไทยเพี้ยน
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // ข้อมูลเต็มของสินค้าที่เลือกไว้ในตะกร้าเปรียบเทียบ (สเปคครบทุกหัวข้อ)
  // ใช้ /products/compare ไม่ใช่ /products/:id เพราะตัวนั้นนับยอดเข้าชมสินค้า
  Future<List<CompareProduct>> fetchCompare(List<String> productIds) async {
    if (productIds.isEmpty) return [];
    final ids = productIds.map(Uri.encodeComponent).join(',');
    final json = await _getJson('/products/compare?ids=$ids');
    final list = (json['products'] as List?) ?? const [];
    return list
        .map((row) => CompareProduct.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ค้นหาสินค้า — ฝั่ง backend จัดการ fuzzy / พิมพ์ผิดแป้น / Caps Lock ให้หมด
  // แอปแค่ส่งคำที่ผู้ใช้พิมพ์ไปตรงๆ ไม่ต้องแปลงอะไรก่อน
  Future<SearchResult> searchProducts(
    String searchword, {
    int page = 1,
    int limit = 10,
    Set<String> categoryIds = const {},
    Set<String> tags = const {},
    String? sort,
  }) async {
    final q = Uri.encodeComponent(searchword);
    final query = StringBuffer('?searchword=$q&page=$page&limit=$limit');
    // /search รับตัวกรองชุดเดียวกับ /products — กรองผลการค้นหาได้เหมือนเว็บ
    if (categoryIds.isNotEmpty) {
      final ids = categoryIds.map(Uri.encodeComponent).join(',');
      query.write('&category_ids=$ids');
    }
    if (tags.isNotEmpty) {
      final list = tags.map(Uri.encodeComponent).join(',');
      query.write('&tags=$list');
    }
    if (sort != null) query.write('&sort=$sort');
    final body = await _getJson('/search$query') as Map<String, dynamic>;
    return SearchResult(
      products: ((body['products'] as List?) ?? [])
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: (body['page'] as num?)?.toInt() ?? 1,
      totalPages: (body['total_pages'] as num?)?.toInt() ?? 1,
      total: (body['total'] as num?)?.toInt() ?? 0,
      searchedAs: body['searched_as']?.toString(),
      suggestions: ((body['suggestions'] as List?) ?? [])
          .map((e) => SearchSuggestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // คำแนะนำระหว่างพิมพ์ (ต้อง 2 ตัวอักษรขึ้นไป ไม่งั้น backend ตอบว่าง)
  Future<List<SearchSuggestion>> fetchAutocomplete(String searchword) async {
    if (searchword.trim().length < 2) return [];
    final q = Uri.encodeComponent(searchword.trim());
    final body = await _getJson(
      '/search/autocomplete?searchword=$q',
    ) as Map<String, dynamic>;
    return ((body['suggestions'] as List?) ?? [])
        .map((e) => SearchSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // รายการตัวกรองที่มีจริงในฐานข้อมูล — backend คำนวณให้ทุกครั้ง
  // ไม่ได้ hardcode ฝั่งแอป เพิ่มสินค้า/แท็กใหม่แล้วตัวเลือกโผล่เอง
  Future<FilterOptions> fetchFilters() async {
    final json = await _getJson('/products/filters') as Map<String, dynamic>;
    return FilterOptions(
      categories: ((json['categories'] as List?) ?? [])
          .map((e) => FilterOption.fromCategory(e as Map<String, dynamic>))
          .toList(),
      tags: ((json['tags'] as List?) ?? [])
          .map((e) => FilterOption.fromTag(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<ProductPage> fetchProducts({
    int page = 1,
    int limit = 10,
    String? categoryId,
    Set<String> categoryIds = const {},
    Set<String> tags = const {},
    String? sort,
  }) async {
    final query = StringBuffer('?page=$page&limit=$limit');
    if (categoryId != null) query.write('&category_id=$categoryId');
    // ติ๊กได้หลายหมวด/หลายแท็ก backend รับเป็นรหัสคอมม่าคั่น
    if (categoryIds.isNotEmpty) {
      final ids = categoryIds.map(Uri.encodeComponent).join(',');
      query.write('&category_ids=$ids');
    }
    if (tags.isNotEmpty) {
      final list = tags.map(Uri.encodeComponent).join(',');
      query.write('&tags=$list');
    }
    if (sort != null) query.write('&sort=$sort');

    final body = await _getJson('/products$query') as Map<String, dynamic>;
    final data = body['products'] as List<dynamic>;
    return ProductPage(
      products: data
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: body['page'] as int,
      totalPages: body['total_pages'] as int,
      total: (body['total'] as num?)?.toInt() ?? 0,
    );
  }

  // ข้อมูลเต็มของสินค้า 1 ตัว — endpoint นี้นับยอดเข้าชมให้ด้วย
  // จึงเรียกเฉพาะตอนเปิดหน้ารายละเอียดจริงๆ เท่านั้น
  Future<ProductDetail> fetchProductDetail(String productId) async {
    final json = await _getJson(
      '/products/${Uri.encodeComponent(productId)}',
    ) as Map<String, dynamic>;
    return ProductDetail.fromJson(json);
  }

  Future<List<Category>> fetchCategories() async {
    final data = await _getJson('/categories') as List<dynamic>;
    return data
        .map((item) => Category.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Shop>> fetchShops() async {
    final data = await _getJson('/shops') as List<dynamic>;
    return data
        .map((item) => Shop.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
