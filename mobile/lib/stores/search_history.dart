import 'package:shared_preferences/shared_preferences.dart';

// ประวัติการค้นหา — เก็บในเครื่องผู้ใช้เท่านั้น ไม่ได้ส่งขึ้น server
// (เทียบเท่า localStorage ของฝั่งเว็บ) จึงไม่ต้องมีระบบล็อกอิน
class SearchHistory {
  SearchHistory._();
  static final SearchHistory instance = SearchHistory._();

  static const _key = 'search_history';
  static const maxItems = 10;

  List<String> _items = [];
  List<String> get items => List.unmodifiable(_items);

  // อ่านจากเครื่องครั้งแรกที่เปิดหน้าค้นหา
  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    _items = prefs.getStringList(_key) ?? [];
    return items;
  }

  // บันทึกคำค้น — คำซ้ำถูกดันขึ้นบนสุดแทนที่จะเพิ่มซ้ำ
  Future<List<String>> add(String word) async {
    final q = word.trim();
    if (q.isEmpty) return items;

    _items = [q, ..._items.where((w) => w.toLowerCase() != q.toLowerCase())];
    if (_items.length > maxItems) _items = _items.sublist(0, maxItems);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _items);
    return items;
  }

  Future<List<String>> remove(String word) async {
    _items = _items.where((w) => w != word).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _items);
    return items;
  }

  Future<void> clear() async {
    _items = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
