import 'package:flutter/material.dart';

// ตัดชื่อสินค้าเป็นช่วงๆ ให้ช่วงที่ตรงกับคำค้นเป็นตัวหนาพื้นฟ้า
// (เทียบเท่า highlightSegments() ของฝั่งเว็บ)
//
// - ไม่สนตัวพิมพ์เล็ก/ใหญ่
// - คำค้นหลายคำ ไฮไลต์ให้ทุกคำ
// - คำค้นที่ไม่เจอในชื่อ ก็แค่ไม่ไฮไลต์ ไม่ทำให้ข้อความหาย
List<TextSpan> highlightSegments(
  String text,
  String query, {
  required TextStyle highlightStyle,
}) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return [TextSpan(text: text)];

  final lower = text.toLowerCase();
  // ทำเครื่องหมายทีละตัวอักษรว่าอยู่ในช่วงที่ตรงกับคำค้นหรือไม่
  // วิธีนี้รองรับกรณีคำค้นซ้อนทับกันเองโดยไม่ต้องจัดการเป็นกรณีพิเศษ
  final marks = List<bool>.filled(text.length, false);
  for (final word in words) {
    var from = 0;
    while (true) {
      final index = lower.indexOf(word, from);
      if (index < 0) break;
      for (var i = index; i < index + word.length; i++) {
        marks[i] = true;
      }
      from = index + word.length;
    }
  }

  final spans = <TextSpan>[];
  var start = 0;
  for (var i = 1; i <= text.length; i++) {
    final end = i == text.length || marks[i] != marks[start];
    if (!end) continue;
    spans.add(
      TextSpan(
        text: text.substring(start, i),
        style: marks[start] ? highlightStyle : null,
      ),
    );
    start = i;
  }
  return spans;
}
