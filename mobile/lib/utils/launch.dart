import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../language/app_language.dart';

// เปิดลิงก์ภายนอก (ร้านค้า / โทรออก) พร้อมบอกผู้ใช้เมื่อเปิดไม่ได้
//
// ใช้ [LaunchMode.externalApplication] เพื่อให้เด้งไปแอปร้านค้าที่ติดตั้งไว้
// (Shopee/Lazada/TikTok/LINE) ถ้าไม่มีแอปค่อยตกไปเป็นเบราว์เซอร์
// — โหมดในแอปจะติดหน้าล็อกอินของร้านค้าและกดกลับยาก
Future<void> openExternalLink(
  BuildContext context,
  String url, {
  String? label,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(url.trim());

  // ลิงก์ในฐานข้อมูลบางแถวกรอกไว้ไม่ครบ (ไม่มี https://) เปิดไม่ได้จริง
  if (uri == null ||
      !uri.hasScheme ||
      uri.host.isEmpty && !uri.isScheme('tel')) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(langs('linkInvalid', {'url': url}))),
      );
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(langs('linkFailed', {'label': label ?? langs('link')})),
        ),
      );
  }
}
