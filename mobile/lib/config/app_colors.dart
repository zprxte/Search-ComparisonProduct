import 'package:flutter/material.dart';

// สีชุดเดียวกับฝั่งเว็บ — คัดมาจาก frontend/tailwind.config.js
// brand = ฟ้า DTC, navy = สีตัวอักษรเข้ม
class AppColors {
  static const brand50 = Color(0xFFE6F7FD);
  static const brand100 = Color(0xFFC2ECF9);
  static const brand300 = Color(0xFF4FCBEE);
  static const brand500 = Color(0xFF00AEEF);
  static const brand600 = Color(0xFF0093D3);
  static const brand700 = Color(0xFF0077AB);
  static const navy900 = Color(0xFF081C30);

  // สีกลางที่เว็บใช้จาก tailwind ปกติ
  static const border = Color(0xFFE5E7EB); // gray-200
  static const muted = Color(0xFF6B7280); // gray-500
  static const button = Color(0xFF9CA3AF); // gray400
  static const circle = Color(0xFFF3F4F6); // gray-100
  static const surface = Color(0xFFF9FAFB); // gray-50
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const skeleton = Color(0xFFE5E7EB);
}
