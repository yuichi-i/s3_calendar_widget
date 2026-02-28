import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// カレンダーアイコンをプログラムで生成してPNGとして保存するスクリプト
/// Usage: dart run tool/generate_icon.dart
Future<void> main() async {
  const sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };

  for (final entry in sizes.entries) {
    final size = entry.value.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    _drawCalendarIcon(canvas, size);

    final picture = recorder.endRecording();
    final img = await picture.toImage(entry.value, entry.value);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final path =
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png';
    final file = File(path);
    await file.writeAsBytes(bytes);
    print('Generated: $path (${entry.value}x${entry.value})');
  }
  print('Done!');
}

void _drawCalendarIcon(Canvas canvas, double size) {
  final s = size;
  final r = s * 0.12; // corner radius

  // 背景: 深いダークブルーグレー
  final bgPaint = Paint()..color = const Color(0xFF1A1A2E);
  final bgRRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, s, s),
    Radius.circular(r),
  );
  canvas.drawRRect(bgRRect, bgPaint);

  // ヘッダー部分（赤）
  final headerPaint = Paint()..color = const Color(0xFFCC3333);
  final headerRRect = RRect.fromRectAndCorners(
    Rect.fromLTWH(0, 0, s, s * 0.28),
    topLeft: Radius.circular(r),
    topRight: Radius.circular(r),
  );
  canvas.drawRRect(headerRRect, headerPaint);

  // リングの書き込み（上部タブ）
  final ringPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  final ringRadius = s * 0.055;
  final ringY = s * 0.04;
  // 左タブ
  canvas.drawCircle(Offset(s * 0.30, ringY), ringRadius, ringPaint);
  // 右タブ
  canvas.drawCircle(Offset(s * 0.70, ringY), ringRadius, ringPaint);

  // タブの穴（ダーク）
  final holePaint = Paint()..color = const Color(0xFF1A1A2E);
  canvas.drawCircle(Offset(s * 0.30, ringY), ringRadius * 0.5, holePaint);
  canvas.drawCircle(Offset(s * 0.70, ringY), ringRadius * 0.5, holePaint);

  // ヘッダーのテキスト（CAL）
  final headerTextPainter = TextPainter(
    text: TextSpan(
      text: 'CAL',
      style: TextStyle(
        color: Colors.white,
        fontSize: s * 0.11,
        fontWeight: FontWeight.bold,
        letterSpacing: s * 0.01,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  headerTextPainter.paint(
    canvas,
    Offset(
      (s - headerTextPainter.width) / 2,
      s * 0.28 / 2 - headerTextPainter.height / 2,
    ),
  );

  // グリッド（7列×4行）
  const cols = 7;
  const rows = 4;
  final gridLeft = s * 0.07;
  final gridRight = s - s * 0.07;
  final gridTop = s * 0.34;
  final gridBottom = s - s * 0.07;
  final cellW = (gridRight - gridLeft) / cols;
  final cellH = (gridBottom - gridTop) / rows;

  // 曜日ヘッダー行
  final dowColors = [
    const Color(0xFFFF4444), // 日
    Colors.white,
    Colors.white,
    Colors.white,
    Colors.white,
    Colors.white,
    const Color(0xFF4488FF), // 土
  ];
  final dowLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  for (int c = 0; c < cols; c++) {
    final cx = gridLeft + cellW * c + cellW / 2;
    final cy = gridTop + cellH * 0.3;
    final tp = TextPainter(
      text: TextSpan(
        text: dowLabels[c],
        style: TextStyle(
          color: dowColors[c].withAlpha(180),
          fontSize: s * 0.065,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  // 日付数字（サンプル: 2月カレンダー風）
  // 日曜始まり: 2026/2/1=日, 28日まで
  final dayData = [
    // row1
    [1, 2, 3, 4, 5, 6, 7],
    // row2
    [8, 9, 10, 11, 12, 13, 14],
    // row3
    [15, 16, 17, 18, 19, 20, 21],
  ];

  for (int row = 0; row < dayData.length; row++) {
    for (int col = 0; col < cols; col++) {
      final day = dayData[row][col];
      final cx = gridLeft + cellW * col + cellW / 2;
      final cy = gridTop + cellH * (row + 1.3);
      Color color;
      if (col == 0) {
        color = const Color(0xFFFF4444);
      } else if (col == 6) {
        color = const Color(0xFF4488FF);
      } else {
        color = Colors.white;
      }
      // 今日をハイライト（例: 10を丸で囲む）
      if (day == 10) {
        final highlightPaint = Paint()..color = const Color(0x44FFFFFF);
        canvas.drawCircle(
            Offset(cx, cy + s * 0.01), cellW * 0.4, highlightPaint);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: day.toString(),
          style: TextStyle(
            color: color,
            fontSize: s * 0.08,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }
}

