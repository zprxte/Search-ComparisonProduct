import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/material.dart';

// ทำให้ตัวเลื่อน "หยุดตรงขอบช่อง" ตั้งแต่ตอนคำนวณแรงเฉื่อย
// แทนการปล่อยให้หยุดมั่วแล้วค่อยดีดตามทีหลัง (วิธีเดิมที่สั่งเลื่อนชนกันเอง)
class SnapScrollPhysics extends ScrollPhysics {
  const SnapScrollPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  @override
  SnapScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      SnapScrollPhysics(itemExtent: itemExtent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // ดึงเลยขอบตัวเลื่อน ปล่อยให้ physics ปกติดีดกลับตามเดิม
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    // เผื่อแรงสะบัดนิ้วเล็กน้อย ปัดแรงจึงไปได้ไกลกว่า 1 ช่อง
    final raw = position.pixels + velocity * 0.15;
    final target = (raw / itemExtent).round() * itemExtent;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if ((clamped - position.pixels).abs() < precisionErrorTolerance) {
      return null; // อยู่ตรงขอบพอดีแล้ว
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      clamped,
      velocity,
      tolerance: toleranceFor(position),
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}
