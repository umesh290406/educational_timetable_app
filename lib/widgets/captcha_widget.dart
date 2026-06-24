import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A self-contained CAPTCHA widget that renders distorted text using CustomPainter.
/// No external packages needed.
class CaptchaWidget extends StatefulWidget {
  /// Called whenever the CAPTCHA is refreshed with the new expected text.
  final ValueChanged<String> onRefreshed;

  const CaptchaWidget({super.key, required this.onRefreshed});

  @override
  State<CaptchaWidget> createState() => _CaptchaWidgetState();
}

class _CaptchaWidgetState extends State<CaptchaWidget> {
  late String _captchaText;
  final _random = Random();

  // Varied character set — uppercase, lowercase, digits (avoids ambiguous chars)
  static const _chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    _captchaText = List.generate(6, (_) => _chars[_random.nextInt(_chars.length)]).join();
    widget.onRefreshed(_captchaText);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security Verification',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              // CAPTCHA canvas
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: CustomPaint(
                    painter: _CaptchaPainter(text: _captchaText, seed: _captchaText.hashCode),
                    size: const Size(double.infinity, 64),
                  ),
                ),
              ),
              // Refresh button
              Container(
                width: 52,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  border: Border(left: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                ),
                child: IconButton(
                  icon: Icon(Icons.refresh_rounded, color: Colors.teal.shade700, size: 26),
                  tooltip: 'Refresh CAPTCHA',
                  onPressed: _generate,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Paints the CAPTCHA image: distorted characters + noise lines + dots.
class _CaptchaPainter extends CustomPainter {
  final String text;
  final int seed;

  _CaptchaPainter({required this.text, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);

    // ── Background gradient ───────────────────────────────────────────────────
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.grey.shade100, Colors.white, Colors.grey.shade50],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // ── Noise dots ────────────────────────────────────────────────────────────
    for (int i = 0; i < 60; i++) {
      final dotPaint = Paint()
        ..color = _randomColor(rnd).withOpacity(0.25)
        ..strokeWidth = rnd.nextDouble() * 2 + 0.5
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * 2 + 0.5,
        dotPaint,
      );
    }

    // ── Noise lines (behind text) ─────────────────────────────────────────────
    for (int i = 0; i < 5; i++) {
      final linePaint = Paint()
        ..color = _randomColor(rnd).withOpacity(0.28)
        ..strokeWidth = rnd.nextDouble() * 2 + 0.8
        ..style = PaintingStyle.stroke;
      final path = Path();
      path.moveTo(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      path.cubicTo(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      canvas.drawPath(path, linePaint);
    }

    // ── Characters ────────────────────────────────────────────────────────────
    final charWidth = size.width / text.length;
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final fontSize = 22.0 + rnd.nextDouble() * 10; // 22–32
      final rotation = (rnd.nextDouble() - 0.5) * 0.55; // ~±16°
      final x = charWidth * i + charWidth / 2;
      final y = size.height / 2 + (rnd.nextDouble() - 0.5) * 12;

      final textPainter = TextPainter(
        text: TextSpan(
          text: char,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.values[rnd.nextInt(FontWeight.values.length)],
            color: _randomColor(rnd).withOpacity(0.9),
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // ── Foreground noise lines (on top of text) ───────────────────────────────
    for (int i = 0; i < 3; i++) {
      final linePaint = Paint()
        ..color = _randomColor(rnd).withOpacity(0.15)
        ..strokeWidth = rnd.nextDouble() * 1.5 + 0.5;
      canvas.drawLine(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        linePaint,
      );
    }
  }

  Color _randomColor(Random rnd) {
    // Mostly dark, readable colors — avoid near-white which blends with bg
    final colors = [
      Colors.teal.shade700,
      Colors.indigo.shade600,
      Colors.purple.shade700,
      Colors.red.shade700,
      Colors.orange.shade800,
      Colors.blue.shade800,
      Colors.green.shade800,
      Colors.brown.shade600,
      Colors.pink.shade700,
      Colors.cyan.shade800,
    ];
    return colors[rnd.nextInt(colors.length)];
  }

  @override
  bool shouldRepaint(_CaptchaPainter old) => old.text != text || old.seed != seed;
}
