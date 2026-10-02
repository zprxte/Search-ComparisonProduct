import 'package:flutter/material.dart';

import '../language/app_language.dart';
import '../models/compare_product.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../stores/compare_store.dart';

// กุญแจของ ScaffoldMessenger ระดับแอป — ทำให้แจ้งเตือนได้โดยไม่ต้องมี BuildContext
//
// จำเป็นเพราะการเพิ่มเข้าตารางเปรียบเทียบเกิดได้จากหลายที่ (การ์ดสินค้า,
// หน้ารายละเอียด, ป็อปอัปเลือกสินค้า, ป็อปอัปเลือกโมเดล) และบางที่สั่งปิดตัวเอง
// ทันทีหลังเพิ่ม ทำให้ context ของมันหลุดจากต้นไม้ไปก่อนข้อความจะถูกแสดง
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// แถบข้อความสั้นๆ ท้ายจอ — กดรัวๆ แล้วข้อความไม่ต่อคิวยาว
void showAppMessage(String message) {
  final messenger = appMessengerKey.currentState;
  if (messenger == null) return; // ยังไม่มีแอปให้แสดง (เช่นในเทสต์)
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(duration: const Duration(seconds: 2), content: Text(message)),
    );
}

// เพิ่มหนึ่งช่องเข้าตาราง หรือแทนที่ช่องเดิมเมื่อส่ง [replaceKey] มา
// แล้วแจ้งผลให้ผู้ใช้เอง — คืน true เมื่อตะกร้าเปลี่ยนจริง
//
// รวมมาไว้ที่เดียวเพราะเดิมการเลือกข้อความ (เพิ่มแล้ว / เต็มแล้ว / ซ้ำ)
// ถูกเขียนซ้ำที่ผู้เรียกทั้ง 4 ที่ แก้กติกาทีหนึ่งต้องไล่แก้ให้ครบทุกที่
// ซึ่งพลาดมาแล้วหลายรอบ (ฝั่งเว็บรวมไว้ใน compareStore.addItem() ตั้งแต่แรก)
bool addCompareItem(CompareItem item, {String? replaceKey, String? modelName}) {
  final store = CompareStore.instance;
  final ok = replaceKey == null
      ? store.add(item)
      : store.replace(replaceKey, item);
  showAppMessage(
    ok
        ? (modelName == null
              ? langs('compareAdded')
              : langs('compareAddedModel', {'model': modelName}))
        : replaceKey != null
        ? langs('swapDuplicate')
        : langs('compareFull', {'max': CompareStore.maxItems}),
  );
  return ok;
}

// เอาสินค้าตัวนี้ออกจากตารางทุกโมเดล (ใช้กับปุ่มที่รู้แค่ตัวสินค้า)
void removeCompareProduct(String productId) {
  CompareStore.instance.remove(productId);
  showAppMessage(langs('compareRemoved'));
}

// เอาออกเฉพาะโมเดลเดียว (ใช้ในป็อปอัปเลือกโมเดล ซึ่งรู้ว่ากำลังเอาตัวไหนออก)
void removeCompareModel(String productId, String? modelId) {
  CompareStore.instance.removeExact(productId, modelId);
  showAppMessage(langs('compareRemoved'));
}

// สินค้าจากการ์ด/ผลค้นหา (ซึ่งรู้แค่ว่า "มีโมเดลไหม") → ช่องที่พร้อมเข้าตาราง
//
// คืน null เมื่อต้องให้ผู้ใช้เลือกโมเดลก่อน — ผู้เรียกต้องไปเปิดป็อปอัปต่อ
// และคืน null เมื่อโหลดข้อมูลไม่สำเร็จ (แจ้งผู้ใช้ให้แล้ว)
//
// เดิมขั้นตอน "ยิง /products/compare → ดูจำนวนโมเดล → ประกอบ CompareItem"
// นี้ถูกเขียนซ้ำทั้งในการ์ดสินค้าและในป็อปอัปเลือกสินค้า
Future<CompareResolution> resolveCompareItem(Product product) async {
  if (!product.hasModels) {
    return CompareResolution.item(CompareItem.fromProduct(product));
  }
  try {
    final detail = (await ApiService().fetchCompare([product.productId]))
        .firstOrNull;
    final models = detail?.models ?? const <CompareModel>[];
    // หลายโมเดล = ราคาและสเปคคนละชุด ต้องให้ผู้ใช้เลือกเองก่อน
    if (detail != null && models.length > 1) {
      return CompareResolution.needsModel(detail);
    }
    final only = models.firstOrNull;
    return CompareResolution.item(
      CompareItem(
        productId: product.productId,
        productName: product.productName,
        productImage: product.productImage,
        productPrice: only?.productPrice ?? product.productPrice,
        modelId: only?.modelId,
        modelName: only?.modelName,
      ),
    );
  } catch (_) {
    showAppMessage(langs('compareModelError'));
    return const CompareResolution.failed();
  }
}

// ผลของ [resolveCompareItem] — ได้ช่องพร้อมใช้ / ต้องเลือกโมเดลก่อน / โหลดไม่สำเร็จ
class CompareResolution {
  const CompareResolution.item(CompareItem this.item)
    : product = null,
      failed = false;
  const CompareResolution.needsModel(CompareProduct this.product)
    : item = null,
      failed = false;
  const CompareResolution.failed() : item = null, product = null, failed = true;

  final CompareItem? item;
  final CompareProduct? product;
  final bool failed;
}
