import 'dart:math';

import '../models/product.dart';

// กรองรายการสินค้าด้วย "ชื่อสินค้า" ในเครื่อง แบบเดียวกับช่องค้นหาในหน้า
// "สินค้าของฉัน" ฝั่งแอดมิน (`fuzzyFilterProducts()` ใน `routes/admin.js`)
//
// ต่างจาก `/api/search` (ตัวค้นหาหลักฝั่ง public) ตรงที่ **ไม่มีชั้นตัดคำไทย /
// คำพ้อง / IDF / กฎคำตรงตัวอักษร** — ตั้งใจให้เรียบง่ายเพราะผู้ใช้ที่เปิด
// ป็อปอัปนี้กำลังเลือกจากแคตตาล็อกที่ตัวเองเห็นอยู่ตรงหน้า ไม่ได้ "ค้นหา"
// ว่ามีสินค้าแบบไหนในระบบ กฎที่เข้มเกินจะคืนศูนย์ผลลัพธ์บ่อยกว่าจะช่วย
//
// ฝั่งเว็บ (`ComparePage.vue` → `filteredPickerProducts`) ก็กรองในเครื่อง
// ด้วยชื่อสินค้าเหมือนกัน ต่างแค่เว็บใช้ `includes()` ตรงๆ ไม่ทนคำพิมพ์ผิด
// ตรงนี้เติมชั้นทนพิมพ์ผิดให้เท่าฝั่งแอดมิน (fuse.js `threshold: 0.3`)
const double _fuzzyThreshold = 0.3;

class _Scored {
  const _Scored(this.product, this.score, this.index);
  final Product product;
  final double score;
  final int index;
}

List<Product> filterProductsByName(List<Product> products, String query) {
  // หลายคำ = ต้องเจอ "ทุกคำ" ที่ไหนก็ได้ในชื่อ ไม่จำเป็นต้องติดกันตามลำดับ
  // (fuse ฝั่งแอดมินเทียบทั้งประโยครวดเดียว พิมพ์ "hikvision 2k" จึงไม่เจอ
  //  เพราะสองคำนี้อยู่คนละท่อนของชื่อ — ตรงนี้จงใจทำให้ดีกว่า)
  final terms = query
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList();
  if (terms.isEmpty) return products;

  final scored = <_Scored>[];
  for (var i = 0; i < products.length; i++) {
    final name = products[i].productName.toLowerCase();
    var total = 0.0;
    var matchedAll = true;
    for (final term in terms) {
      final score = _termScore(name, term);
      if (score == null) {
        matchedAll = false;
        break;
      }
      total += score;
    }
    if (matchedAll) scored.add(_Scored(products[i], total / terms.length, i));
  }

  // คะแนนน้อย = ตรงกว่า · เท่ากันให้คงลำดับเดิม (ยอดนิยมมาก่อน) —
  // `sort` ของ Dart ไม่การันตีว่า stable จึงต้องตัดสินด้วยลำดับเดิมเอง
  scored.sort((a, b) {
    final byScore = a.score.compareTo(b.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });
  return scored.map((item) => item.product).toList();
}

// 0 = ตรงเป๊ะ (เป็นส่วนหนึ่งของชื่อ) · ยิ่งมากยิ่งเพี้ยน · null = ไม่นับว่าตรง
double? _termScore(String name, String term) {
  if (name.contains(term)) return 0;
  final score = _bestSubstringDistance(name, term) / term.length;
  return score <= _fuzzyThreshold ? score : null;
}

// ระยะแก้ไข (Levenshtein) ที่ "น้อยที่สุด" ระหว่างคำค้นกับท่อนใดท่อนหนึ่งของชื่อ
//
// ต่างจาก Levenshtein ปกติตรงแถวแรกเป็นศูนย์ทั้งแถว = เริ่มจับคู่ที่ตำแหน่งไหน
// ของชื่อก็ได้โดยไม่เสียคะแนน (เทียบเท่า `ignoreLocation: true` ของ fuse)
// ไม่งั้นคำค้นสั้นๆ จะแพ้ให้ชื่อยาวทันทีเพราะต้อง "ลบ" ส่วนที่เหลือทิ้งหมด
int _bestSubstringDistance(String name, String term) {
  var prev = List<int>.filled(name.length + 1, 0);
  final cur = List<int>.filled(name.length + 1, 0);
  for (var i = 1; i <= term.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= name.length; j++) {
      final cost = term[i - 1] == name[j - 1] ? 0 : 1;
      cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
    }
    prev = List<int>.from(cur);
  }
  return prev.reduce(min);
}
