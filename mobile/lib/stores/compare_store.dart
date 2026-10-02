import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';

// หนึ่งช่องในตารางเปรียบเทียบ = (สินค้า, โมเดล)
//
// เก็บระดับโมเดลเหมือนฝั่งเว็บ เพราะสินค้าตัวเดียวกันคนละโมเดลมีราคาและสเปค
// ต่างกัน ถ้าเก็บแค่ระดับสินค้าจะเทียบ "รุ่น 4 ช่อง vs รุ่น 8 ช่อง" ไม่ได้เลย
// [modelId] เป็น null เฉพาะสินค้าที่ไม่มีโมเดลให้เลือก
@immutable
class CompareItem {
  final String productId;
  final String productName;
  final String? productImage;
  final num productPrice; // ราคาของโมเดลที่เลือก ไม่ใช่ราคาเริ่มต้นของสินค้า
  final String? modelId;
  final String? modelName;

  const CompareItem({
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.productPrice,
    this.modelId,
    this.modelName,
  });

  // รหัสประจำช่อง — สินค้าเดียวกันคนละโมเดลต้องได้คนละค่า
  String get key => modelId == null ? productId : '$productId::$modelId';

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'product_image': productImage,
    'product_price': productPrice,
    'model_id': modelId,
    'model_name': modelName,
  };

  factory CompareItem.fromJson(Map<String, dynamic> json) => CompareItem(
    productId: json['product_id'] as String,
    productName: json['product_name'] as String? ?? '',
    productImage: json['product_image'] as String?,
    productPrice: json['product_price'] as num? ?? 0,
    modelId: json['model_id'] as String?,
    modelName: json['model_name'] as String?,
  );

  factory CompareItem.fromProduct(Product product) => CompareItem(
    productId: product.productId,
    productName: product.productName,
    productImage: product.productImage,
    productPrice: product.productPrice,
  );
}

// ตะกร้าเปรียบเทียบของทั้งแอป — มีตัวเดียวใช้ร่วมกันทุกหน้า (singleton)
//
// ใช้ [ValueNotifier] เพื่อให้หน้าไหนก็ตามที่ครอบด้วย ValueListenableBuilder
// วาดใหม่เองทันทีที่รายการเปลี่ยน โดยไม่ต้องส่งค่าผ่าน constructor ไปทีละชั้น
//
// จำข้ามการเปิดแอปเหมือนเว็บที่เก็บลง localStorage — ทุกครั้งที่รายการเปลี่ยน
// จะบันทึกลง shared_preferences ให้เอง ([load] เรียกครั้งเดียวตอนเปิดแอป)
class CompareStore {
  CompareStore._() {
    // ดักที่ตัว notifier จุดเดียว ทุกเมธอดที่แก้รายการจึงบันทึกครบโดยไม่ต้องจำไปเรียกเอง
    items.addListener(_persist);
  }
  static final CompareStore instance = CompareStore._();

  static const String _storageKey = 'compare_items';

  // เพดานของ "แอปมือถือ" โดยเฉพาะ: เทียบได้ทีละ 2 ช่อง
  // จุดประสงค์ (มองเทียบกันทีเดียว) — ข้อความทุกจุดอ่านเลขจากตัวนี้ ไม่ hardcode
  static const int maxItems = 2;

  final ValueNotifier<List<CompareItem>> items =
      ValueNotifier<List<CompareItem>>([]);

  // อ่านรายการที่เคยเลือกไว้ — ข้อมูลเสีย/อ่านไม่ได้ก็เริ่มจากตะกร้าว่าง
  // ไม่ควรทำให้แอปเปิดไม่ขึ้น (เหมือน loadPersisted() ของเว็บ)
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => CompareItem.fromJson(e as Map<String, dynamic>))
          .toList();
      // เพดานอาจลดลงในรุ่นหลัง — ตัดท้ายให้เหลือไม่เกินเพดานปัจจุบัน
      items.value = list.take(maxItems).toList();
    } catch (e) {
      debugPrint('โหลดตะกร้าเปรียบเทียบไม่ได้: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(items.value.map((item) => item.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('บันทึกตะกร้าเปรียบเทียบไม่ได้: $e');
    }
  }

  // สินค้าตัวนี้อยู่ในตาราง "อย่างน้อยหนึ่งโมเดล" หรือยัง
  // (ปุ่มบนการ์ดสินค้าใช้ค่านี้ตัดสินว่าจะขึ้นว่า "อยู่ในตารางแล้ว" ไหม)
  bool contains(String productId) =>
      items.value.any((item) => item.productId == productId);

  // โมเดลนี้ของสินค้าตัวนี้อยู่ในตารางหรือยัง (ป็อปอัปเลือกโมเดลใช้)
  // ช่องรหัสนี้ยังอยู่ในตารางไหม — ป็อปอัป "เปลี่ยนสินค้า" ใช้เช็กว่าช่องที่
  // กำลังจะเปลี่ยนถูกเอาออกไปแล้วหรือยัง (ถ้าไม่มีแล้วก็ไม่เหลืออะไรให้แทนที่)
  bool containsKey(String key) => items.value.any((item) => item.key == key);

  bool containsExact(String productId, String? modelId) => items.value.any(
    (item) => item.productId == productId && item.modelId == modelId,
  );

  bool get isFull => items.value.length >= maxItems;

  // เพิ่มหนึ่งช่อง — คืน false เมื่อเต็มแล้ว (หน้าจอเอาไปขึ้นข้อความเตือน)
  // ช่องที่มีอยู่แล้วถือว่าสำเร็จ ไม่เพิ่มซ้ำ
  bool add(CompareItem item) {
    if (containsExact(item.productId, item.modelId)) return true;
    if (isFull) return false;
    // ต้องสร้าง list ใหม่เสมอ ถ้าแก้ list เดิมแล้วใส่กลับ ValueNotifier
    // จะมองว่าเป็นค่าเดิม (identical) แล้วไม่แจ้งให้หน้าจอวาดใหม่
    items.value = [...items.value, item];
    return true;
  }

  // เพิ่มถ้ายังไม่มี / เอาออกถ้ามีอยู่แล้ว (เทียบทั้งสินค้าและโมเดล)
  bool toggle(CompareItem item) {
    if (containsExact(item.productId, item.modelId)) {
      removeExact(item.productId, item.modelId);
      return true;
    }
    return add(item);
  }

  // เอาออกทุกโมเดลของสินค้าตัวนี้ — ใช้กับปุ่มบนการ์ดสินค้าที่รู้แค่ตัวสินค้า
  void remove(String productId) {
    items.value = items.value
        .where((item) => item.productId != productId)
        .toList();
  }

  void removeExact(String productId, String? modelId) {
    items.value = items.value
        .where(
          (item) => !(item.productId == productId && item.modelId == modelId),
        )
        .toList();
  }

  // แทนที่ช่องเดิมด้วยของใหม่ โดยอยู่ตำแหน่งเดิม
  // (ปุ่ม "เปลี่ยนสินค้า" และ dropdown เลือกโมเดลบนหัวคอลัมน์)
  //
  // ต้องแทนที่ในตำแหน่งเดิม ไม่ใช่ลบแล้วต่อท้าย ไม่งั้นคอลัมน์จะสลับที่
  // ทั้งที่ผู้ใช้แค่เปลี่ยนของในช่องเดียว
  //
  // ถ้าของใหม่ไปตรงกับช่องอื่นที่มีอยู่แล้ว = **สลับที่กันสองช่อง**
  // (ช่องนั้นรับของเดิมของช่องนี้ไป) ไม่ใช่ปฏิเสธ — ผู้ใช้ที่เลือกโมเดลซึ่ง
  // อีกช่องถืออยู่ ตั้งใจจะย้ายมันมาไว้ฝั่งนี้ การขึ้นข้อความว่าซ้ำแล้วไม่ทำ
  // อะไรให้เลยทำให้ต้องไปไล่เปลี่ยนอีกช่องเองก่อน ซึ่งวกวนโดยไม่จำเป็น
  //
  // คืน false เฉพาะตอนหาช่องที่จะแทนที่ไม่เจอ (ถูกเอาออกไปก่อนแล้ว)
  bool replace(String key, CompareItem item) {
    final list = [...items.value];
    final index = list.indexWhere((old) => old.key == key);
    if (index < 0) return false;

    final other = list.indexWhere(
      (old) => old.key == item.key && old.key != key,
    );
    if (other >= 0) list[other] = list[index]; // ของเดิมย้ายไปอยู่ช่องนั้นแทน

    list[index] = item;
    items.value = list;
    return true;
  }

  // เอาออกด้วยรหัสประจำช่อง — ปุ่ม ✕ บนหัวคอลัมน์ในตารางใช้
  void removeKey(String key) {
    items.value = items.value.where((item) => item.key != key).toList();
  }

  void clear() => items.value = [];
}
