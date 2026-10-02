import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/app_colors.dart';
import '../language/app_language.dart';
import '../utils/snap_scroll_physics.dart';
import '../models/product.dart';
import 'product_card.dart';

class ProductRail extends StatefulWidget {
  const ProductRail({
    super.key,
    required this.products,
    this.height = 300,
    this.visibleCards = 2,
    this.gutter = 28, // ระยะจากขอบจอถึงการ์ด (เผื่อที่ให้ปุ่มลูกศร)
    this.gap = 12, // ช่องว่างระหว่างการ์ด
  });

  final List<Product> products;
  final double height;
  final double visibleCards;
  final double gutter;
  final double gap;

  @override
  State<ProductRail> createState() => _ProductRailState();
}

class _ProductRailState extends State<ProductRail> {
  static const double _arrowSize = 32;

  final ScrollController _controller = ScrollController();

  int _index = 0; // ตอนนี้การ์ดใบไหนอยู่ซ้ายสุด
  int _animating = 0; // จำนวนการเลื่อนที่สั่งไปแล้วยังไม่จบ
  double? _lastExtent; // ขนาดการ์ด + ช่องว่าง ของเฟรมก่อนหน้า

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateTo(double offset, double itemExtent) async {
    _animating++;
    try {
      await _controller.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _animating--;
      // จบการเลื่อนแล้วยึดตำแหน่งจริงเป็นหลักเสมอ — เป้าหมายที่สั่งไปอาจถูก
      // clamp ด้วยขอบรางจนไม่ตรงกับเลขใบที่ตั้งใจ ถ้าไม่ปรับกลับ ครั้งต่อไป
      // จะนับต่อจากเลขที่ไม่มีอยู่จริงแล้วกดหนึ่งครั้งไม่ขยับ
      if (mounted && _controller.hasClients) {
        _index = (_controller.position.pixels / itemExtent).round();
      }
    }
  }

  // ใบซ้ายสุดที่เลื่อนไปได้ไกลสุด — คิดจาก "จำนวนสินค้า ลบ จำนวนที่เห็นพร้อมกัน"
  //
  // ห้ามคิดจาก `maxScrollExtent` เพราะ `ListView` สร้างลูกแบบ lazy ค่าที่ได้ก่อน
  // เลื่อนไปถึงท้ายรางเป็นแค่ **ค่าประมาณ** (เจอจริง: ประมาณ 1511 ทั้งที่จริง 1384
  // = เกินไป 1 ใบ) พอเอาไปหารก็ได้เลขใบสุดท้ายเกินจริง แล้วการกดวนกลับจะไป
  // ยืนที่เลขที่ไม่มีอยู่ ทำให้ต้องกดเปล่าอีกหนึ่งครั้งก่อนรางจะขยับ
  int get _lastIndex {
    final steps = widget.products.length - widget.visibleCards;
    return steps <= 0 ? 0 : steps.floor();
  }

  void _step(int direction, double itemExtent) {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final lastIndex = _lastIndex;

    var next = _index + direction;
    if (next > lastIndex) {
      // เลยใบสุดท้าย → วนกลับใบแรก: ไปยืนห่างใบแรก 1 ใบแบบไม่มีภาพก่อน
      // แล้วค่อยเลื่อนเข้าที่ ตาจึงเห็นเป็นการก้าว 1 ใบเหมือนกดครั้งอื่น
      _controller.jumpTo(itemExtent.clamp(0.0, max));
      next = 0;
    } else if (next < 0) {
      _controller.jumpTo(((lastIndex - 1) * itemExtent).clamp(0.0, max));
      next = lastIndex;
    }

    _index = next;
    _animateTo((next * itemExtent).clamp(0.0, max), itemExtent);
  }

  // ปุ่มกลมขาว วางคร่อมขอบการ์ดพอดี (กว้าง 32 = 2 เท่าของขอบหน้า 16)
  Widget _arrow(IconData icon, String label, VoidCallback onPressed) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: const Color(0x33081C30),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: _arrowSize,
            height: _arrowSize,
            child: Center(
              child: Icon(icon, size: 20, color: AppColors.navy900),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      // วัดความกว้างจริงที่ได้รับ ไม่ใช้ขนาดจอ จะได้ไม่เพี้ยนถ้าเอาไปวางที่อื่น
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth =
              (constraints.maxWidth -
                  widget.gutter * 2 -
                  widget.gap * (widget.visibleCards - 1)) /
              widget.visibleCards;
          final itemExtent = cardWidth + widget.gap;

          // ขนาดการ์ดเปลี่ยน (หมุนจอ / แก้ visibleCards แล้ว hot reload)
          // ตำแหน่งที่ค้างอยู่จะไม่ตรงขอบใบไหนอีกต่อไป จัดกลับมาให้ตรงใบเดิม
          if (_lastExtent != itemExtent) {
            _lastExtent = itemExtent;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_controller.hasClients) return;
              final max = _controller.position.maxScrollExtent;
              _controller.jumpTo((_index * itemExtent).clamp(0.0, max));
            });
          }

          return Stack(
            children: [
              // ปัดนิ้วเองแล้วต้องอัปเดตเลขใบ ไม่งั้นกดปุ่มครั้งต่อไปจะนับจากใบเก่า
              // เช็ก _animating เพื่อไม่ให้การเลื่อนของปุ่มเองมาแก้เลขกลางทาง
              NotificationListener<ScrollEndNotification>(
                onNotification: (n) {
                  if (_animating == 0) {
                    _index = (n.metrics.pixels / itemExtent).round();
                  }
                  return false;
                },
                // รางกินพื้นที่แค่ช่วงกลาง แถบ gutter ริมจอจึงเป็นที่ว่างจริง
                // ไม่ใช่ที่ที่การ์ดใบข้างๆ เลื่อนเข้ามาโผล่ (ตัวเลื่อนตัดขอบให้เอง)
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.gutter),
                  child: ListView.separated(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    physics: SnapScrollPhysics(itemExtent: itemExtent),
                    padding: EdgeInsets.zero,
                    itemCount: widget.products.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(width: widget.gap),
                    itemBuilder: (context, index) => SizedBox(
                      width: cardWidth,
                      child: ProductCard(product: widget.products[index]),
                    ),
                  ),
                ),
              ),

              if (widget.products.length > 1) ...[
                Positioned(
                  // กึ่งกลางวงกลมตรงขอบการ์ดพอดี ครึ่งวงบนการ์ด ครึ่งวงนอกการ์ด
                  left: widget.gutter - _arrowSize / 2,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _arrow(
                      LucideIcons.chevronLeft,
                      langs('scrollLeft'),
                      () => _step(-1, itemExtent),
                    ),
                  ),
                ),
                Positioned(
                  right: widget.gutter - _arrowSize / 2,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _arrow(
                      LucideIcons.chevronRight,
                      langs('scrollRight'),
                      () => _step(1, itemExtent),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
