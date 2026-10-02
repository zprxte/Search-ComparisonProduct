import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translations.dart';

// ภาษาที่เลือกอยู่ของทั้งแอป — มีตัวเดียวใช้ร่วมกันทุกหน้า (singleton)
//
// ขอบเขตเท่าฝั่งเว็บ: แปลเฉพาะข้อความ UI ไม่แปลข้อมูลสินค้าในฐานข้อมูล
// (ชื่อสินค้า/สเปคมีภาษาเดียวใน DB การแปลต้องเพิ่มคอลัมน์ ดู CLAUDE.md 3.3)
class LanguageStore {
  LanguageStore._();
  static final LanguageStore instance = LanguageStore._();

  static const String _storageKey = 'app_lang';

  // เริ่มที่ไทยเสมอ แล้วค่อยแทนที่ด้วยค่าที่เคยเลือกไว้เมื่อโหลดเสร็จ
  // (อ่าน shared_preferences เป็น async จะรอก่อนวาดหน้าแรกไม่ได้)
  final ValueNotifier<String> code = ValueNotifier<String>('th');

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved != null && dict.containsKey(saved)) code.value = saved;
    } catch (e) {
      // อ่านค่าที่เคยเลือกไม่ได้ก็ใช้ภาษาไทยไปก่อน ไม่ควรทำให้แอปเปิดไม่ขึ้น
      debugPrint('โหลดภาษาที่เลือกไว้ไม่ได้: $e');
    }
  }

  Future<void> setLang(String next) async {
    if (!dict.containsKey(next)) {
      // เคยพลาดมาแล้ว 2 รอบ: รหัสใน appLanguages ไม่ตรงกับคีย์ของ dict
      // แล้วกดเลือกภาษาก็ไม่มีอะไรเกิดขึ้นโดยไม่มี error ให้เห็น
      // คราวนี้ให้ฟ้องใน console แทนการเงียบหายไปเฉยๆ
      debugPrint('ไม่รู้จักรหัสภาษา "$next" — ต้องตรงกับคีย์ใน dict');
      assert(false, 'ไม่รู้จักรหัสภาษา "$next"');
      return;
    }
    code.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, next);
    } catch (e) {
      debugPrint('บันทึกภาษาที่เลือกไม่ได้: $e');
    }
  }
}

// ข้อความตามภาษาที่เลือกอยู่ — ใช้แทนข้อความ hardcode ทุกจุดในหน้าจอ
//
// [vars] แทนที่ตัวยึด `{ชื่อ}` ในข้อความ เช่น langs('pageOf', {'page': 1})
// คีย์ที่ยังไม่ได้แปลจะตกไปใช้ภาษาไทย แล้วจึงเป็นตัวคีย์เอง (เห็นทันทีว่าลืม)
String langs(String key, [Map<String, Object>? vars]) {
  final lang = LanguageStore.instance.code.value;
  var text = dict[lang]?[key] ?? dict['th']?[key] ?? key;
  if (vars != null) {
    vars.forEach((name, value) {
      text = text.replaceAll('{$name}', '$value');
    });
  }
  return text;
}
