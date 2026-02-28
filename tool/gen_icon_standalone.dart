import 'dart:io';
import 'package:image/image.dart' as img;

/// アプリアイコンをプログラム生成するスクリプト
/// Usage: dart run tool/gen_icon_standalone.dart
void main() async {
  final sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };

  // まず 1024px のマスターを生成
  final master = _generateIcon(1024);

  // assetsフォルダに高解像度版を保存（flutter_launcher_iconsが使用）
  Directory('assets').createSync(recursive: true);
  File('assets/icon.png').writeAsBytesSync(img.encodePng(master));
  print('Generated: assets/icon.png (1024x1024)');

  // 各解像度にリサイズしてmipmap-*に保存
  for (final entry in sizes.entries) {
    final size = entry.value;
    final resized = img.copyResize(master, width: size, height: size,
        interpolation: img.Interpolation.cubic);
    final path = 'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png';
    File(path).writeAsBytesSync(img.encodePng(resized));
    print('Generated: $path (${size}x$size)');
  }
  print('All icons generated!');
}

img.Image _generateIcon(int size) {
  final s = size;
  final image = img.Image(width: s, height: s);

  // 背景: 深いダークネイビー
  final bgColor = img.ColorRgba8(20, 20, 46, 255); // #14142E
  img.fill(image, color: bgColor);

  // 角丸マスク
  final radius = (s * 0.18).round();
  _drawRoundedRectMask(image, 0, 0, s, s, radius);

  // ヘッダー部分（赤帯）
  final headerH = (s * 0.28).round();
  final headerColor = img.ColorRgba8(200, 50, 50, 255); // #C83232
  for (int y = 0; y < headerH; y++) {
    for (int x = 0; x < s; x++) {
      // 角丸の外はスキップ
      if (image.getPixel(x, y).a == 0) continue;
      image.setPixel(x, y, headerColor);
    }
  }

  // ヘッダーとボディの境界線
  final dividerColor = img.ColorRgba8(180, 40, 40, 255);
  for (int x = 0; x < s; x++) {
    image.setPixel(x, headerH, dividerColor);
    image.setPixel(x, headerH + 1, dividerColor);
  }

  // リングタブ（白い丸）
  final ringR = (s * 0.05).round();
  final ringY = (s * 0.05).round();
  _drawCircle(image, (s * 0.30).round(), ringY, ringR,
      img.ColorRgba8(255, 255, 255, 255));
  _drawCircle(image, (s * 0.70).round(), ringY, ringR,
      img.ColorRgba8(255, 255, 255, 255));
  // タブの穴
  final holeR = (ringR * 0.45).round();
  _drawCircle(image, (s * 0.30).round(), ringY, holeR, bgColor);
  _drawCircle(image, (s * 0.70).round(), ringY, holeR, bgColor);

  // "2月" テキスト代わりに数字グリッドを描く
  // グリッドエリア
  final gridL = (s * 0.08).toInt();
  final gridR = (s * 0.92).toInt();
  final gridT = (s * 0.33).toInt();
  final gridB = (s * 0.94).toInt();
  final cols = 7;
  final rows = 5;
  final cellW = (gridR - gridL) ~/ cols;
  final cellH = (gridB - gridT) ~/ rows;

  // 曜日ドット行（小さな色付きドット）
  final dowColors = [
    img.ColorRgba8(255, 80, 80, 200),   // 日: 赤
    img.ColorRgba8(200, 200, 200, 200), // 月
    img.ColorRgba8(200, 200, 200, 200), // 火
    img.ColorRgba8(200, 200, 200, 200), // 水
    img.ColorRgba8(200, 200, 200, 200), // 木
    img.ColorRgba8(200, 200, 200, 200), // 金
    img.ColorRgba8(80, 136, 255, 200),  // 土: 青
  ];

  for (int c = 0; c < cols; c++) {
    final cx = gridL + cellW * c + cellW ~/ 2;
    final cy = gridT + cellH ~/ 4;
    _drawCircle(image, cx, cy, (s * 0.018).round(), dowColors[c]);
  }

  // 日付グリッド（小さな四角ドット）
  // 2026/2/1 = 日曜始まり: 1列目から始まる
  // 簡易的に配置: 1-28日
  int day = 1;
  final dayColors = [
    img.ColorRgba8(255, 80, 80, 230),   // col0 日
    img.ColorRgba8(230, 230, 230, 230), // col1-5 平日
    img.ColorRgba8(230, 230, 230, 230),
    img.ColorRgba8(230, 230, 230, 230),
    img.ColorRgba8(230, 230, 230, 230),
    img.ColorRgba8(230, 230, 230, 230),
    img.ColorRgba8(80, 136, 255, 230),  // col6 土
  ];

  for (int row = 1; row < rows; row++) {
    for (int col = 0; col < cols; col++) {
      if (day > 28) break;
      final cx = gridL + cellW * col + cellW ~/ 2;
      final cy = gridT + cellH * row + cellH ~/ 2;
      final dotR = (s * 0.028).round();

      // 今日ハイライト（10日）
      if (day == 10) {
        _drawCircle(image, cx, cy, (dotR * 1.6).round(),
            img.ColorRgba8(255, 255, 255, 60));
      }

      // 数字を小さな四角で表現
      _drawRoundedRect(image, cx - dotR, cy - dotR,
          cx + dotR, cy + dotR, (dotR * 0.3).round(), dayColors[col]);
      day++;
    }
  }

  return image;
}

void _drawRoundedRectMask(
    img.Image image, int x1, int y1, int x2, int y2, int radius) {
  // 角丸の外側を透明にする
  for (int y = y1; y < y2; y++) {
    for (int x = x1; x < x2; x++) {
      bool inside = true;
      if (x < x1 + radius && y < y1 + radius) {
        final dx = x - (x1 + radius);
        final dy = y - (y1 + radius);
        inside = dx * dx + dy * dy <= radius * radius;
      } else if (x >= x2 - radius && y < y1 + radius) {
        final dx = x - (x2 - radius);
        final dy = y - (y1 + radius);
        inside = dx * dx + dy * dy <= radius * radius;
      } else if (x < x1 + radius && y >= y2 - radius) {
        final dx = x - (x1 + radius);
        final dy = y - (y2 - radius);
        inside = dx * dx + dy * dy <= radius * radius;
      } else if (x >= x2 - radius && y >= y2 - radius) {
        final dx = x - (x2 - radius);
        final dy = y - (y2 - radius);
        inside = dx * dx + dy * dy <= radius * radius;
      }
      if (!inside) {
        image.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
      }
    }
  }
}

void _drawCircle(img.Image image, int cx, int cy, int radius, img.Color color) {
  for (int y = cy - radius; y <= cy + radius; y++) {
    for (int x = cx - radius; x <= cx + radius; x++) {
      if (x < 0 || y < 0 || x >= image.width || y >= image.height) continue;
      final dx = x - cx;
      final dy = y - cy;
      if (dx * dx + dy * dy <= radius * radius) {
        image.setPixel(x, y, color);
      }
    }
  }
}

void _drawRoundedRect(img.Image image, int x1, int y1, int x2, int y2,
    int radius, img.Color color) {
  for (int y = y1; y <= y2; y++) {
    for (int x = x1; x <= x2; x++) {
      if (x < 0 || y < 0 || x >= image.width || y >= image.height) continue;
      bool inside = true;
      if (x < x1 + radius && y < y1 + radius) {
        final dx = x - (x1 + radius);
        final dy = y - (y1 + radius);
        inside = dx * dx + dy * dy <= radius * radius;
      } else if (x >= x2 - radius && y < y1 + radius) {
        final dx = x - (x2 - radius);
        final dy = y - (y1 + radius);
        inside = dx * dx + dy * dy <= radius * radius;
      } else if (x < x1 + radius && y >= y2 - radius) {
        final dx = x - (x1 + radius);
        final dy = y - (y2 - radius);
        inside = dx * dx + dy * dy <= radius * radius;
      } else if (x >= x2 - radius && y >= y2 - radius) {
        final dx = x - (x2 - radius);
        final dy = y - (y2 - radius);
        inside = dx * dx + dy * dy <= radius * radius;
      }
      if (inside) image.setPixel(x, y, color);
    }
  }
}

