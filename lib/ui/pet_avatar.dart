import 'package:flutter/material.dart';

import '../contracts/contracts.dart';

class PetAvatar extends StatelessWidget {
  const PetAvatar({
    super.key,
    required this.formId,
    required this.paletteId,
    this.size = 120,
    this.stage = PetStage.baby,
  });
  final String formId;
  final String paletteId;
  final double size;
  final PetStage stage;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Финни, ${formId.split('.').last}, ${paletteId.split('.').last}, ${switch (stage) {
          PetStage.baby => 'малыш',
          PetStage.junior => 'подросший',
          PetStage.grown => 'взрослый',
        }}',
    image: true,
    child: ClipRect(
      child: CustomPaint(
        size: Size(size, size),
        painter: _PetPainter(formId, paletteId, stage),
      ),
    ),
  );
}

class _PetPainter extends CustomPainter {
  _PetPainter(this.form, this.palette, this.stage);
  final PetStage stage;
  final String form;
  final String palette;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 160, size.height / 160);
    // Every stage keeps the same 160 x 160 canvas and ground line.
    final scaleX = stage == PetStage.baby
        ? .78
        : stage == PetStage.junior
        ? .9
        : 1.0;
    final scaleY = stage == PetStage.baby
        ? .76
        : stage == PetStage.junior
        ? .9
        : 1.04;
    canvas.translate(80 * (1 - scaleX), 140 * (1 - scaleY));
    canvas.scale(scaleX, scaleY);
    final color = palette.endsWith('02')
        ? const Color(0xfff4bf87)
        : palette.endsWith('03')
        ? const Color(0xffc5b3ed)
        : const Color(0xff9ed8bb);
    final fill = Paint()..color = color;
    final ink = Paint()..color = const Color(0xff284b40);
    final outline = Paint()
      ..color = ink.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final body = Path()
      ..moveTo(30, 90)
      ..cubicTo(25, 30, 135, 30, 130, 90)
      ..lineTo(137, 118)
      ..quadraticBezierTo(125, 132, 111, 122)
      ..quadraticBezierTo(80, 146, 48, 122)
      ..quadraticBezierTo(25, 132, 23, 117)
      ..close();
    if (form.endsWith('02')) {
      final ears = Path()
        ..moveTo(43, 74)
        ..lineTo(35, 36)
        ..lineTo(67, 63)
        ..moveTo(94, 63)
        ..lineTo(126, 36)
        ..lineTo(117, 76);
      canvas.drawPath(ears, fill);
      canvas.drawPath(ears, outline);
    } else if (form.endsWith('03')) {
      final tuft = Path()
        ..moveTo(62, 45)
        ..lineTo(70, 17)
        ..lineTo(82, 38)
        ..lineTo(96, 23)
        ..lineTo(101, 49)
        ..close();
      canvas.drawPath(tuft, fill);
      canvas.drawPath(tuft, outline);
    }
    canvas.drawPath(body, fill);
    canvas.drawPath(body, outline);
    if (stage != PetStage.baby) {
      final scarf = Paint()..color = const Color(0xffd65b42);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(44, 96, 72, 9),
          const Radius.circular(4),
        ),
        scarf,
      );
      canvas.drawPath(
        Path()
          ..moveTo(105, 102)
          ..lineTo(119, 115)
          ..lineTo(108, 118)
          ..close(),
        scarf,
      );
    }
    if (stage == PetStage.grown) {
      canvas.drawCircle(
        const Offset(54, 101),
        7,
        Paint()..color = const Color(0xffffcc46),
      );
      canvas.drawCircle(const Offset(54, 101), 7, outline);
      canvas.drawLine(const Offset(54, 97), const Offset(54, 105), outline);
    }
    canvas.drawCircle(const Offset(61, 78), 4, ink);
    canvas.drawCircle(const Offset(99, 78), 4, ink);
    canvas.drawPath(
      Path()
        ..moveTo(71, 91)
        ..quadraticBezierTo(80, 99, 89, 91),
      outline,
    );
    if (palette.endsWith('02')) {
      canvas.drawLine(const Offset(59, 111), const Offset(101, 111), outline);
      canvas.drawLine(const Offset(66, 120), const Offset(94, 120), outline);
    } else if (palette.endsWith('03')) {
      canvas.drawPath(
        Path()
          ..moveTo(80, 106)
          ..lineTo(84, 113)
          ..lineTo(93, 114)
          ..lineTo(87, 120)
          ..lineTo(89, 128)
          ..lineTo(80, 124)
          ..lineTo(72, 128)
          ..lineTo(73, 120)
          ..lineTo(67, 114)
          ..lineTo(76, 113)
          ..close(),
        ink,
      );
    } else {
      for (final point in [
        const Offset(64, 113),
        const Offset(80, 122),
        const Offset(96, 113),
      ]) {
        canvas.drawCircle(point, 3, ink);
      }
    }
  }

  @override
  bool shouldRepaint(_PetPainter oldDelegate) =>
      oldDelegate.form != form ||
      oldDelegate.palette != palette ||
      oldDelegate.stage != stage;
}
