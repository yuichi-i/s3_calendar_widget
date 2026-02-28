import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          '設定',
          style: GoogleFonts.rajdhani(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 週の始まり設定
              _SectionHeader(title: '週の始まり'),
              Card(
                color: Colors.grey[900],
                child: RadioGroup<bool>(
                  groupValue: provider.startOnMonday,
                  onChanged: (v) {
                    if (v != null) provider.setStartOnMonday(v);
                  },
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        title: Text(
                          '日曜始まり（デフォルト）',
                          style: GoogleFonts.rajdhani(color: Colors.white),
                        ),
                        value: false,
                        activeColor: Colors.white,
                      ),
                      RadioListTile<bool>(
                        title: Text(
                          '月曜始まり',
                          style: GoogleFonts.rajdhani(color: Colors.white),
                        ),
                        value: true,
                        activeColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 背景色設定
              _SectionHeader(title: 'ウィジェット背景色'),
              Card(
                color: Colors.grey[900],
                child: ListTile(
                  title: Text(
                    '背景色を選択',
                    style: GoogleFonts.rajdhani(color: Colors.white),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: provider.backgroundColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white38),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.white54),
                    ],
                  ),
                  onTap: () => _showColorPicker(context, provider),
                ),
              ),
              const SizedBox(height: 12),
              // 透過率設定
              _SectionHeader(title: 'ウィジェット背景の透過率'),
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // 透過率プレビュー
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Stack(
                                children: [
                                  // 市松模様（透過を視覚化）
                                  CustomPaint(
                                    size: const Size(32, 32),
                                    painter: _CheckerPainter(),
                                  ),
                                  Container(
                                    color: provider.backgroundColor.withValues(
                                      alpha: provider.backgroundOpacity,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Slider(
                              value: provider.backgroundOpacity,
                              min: 0.0,
                              max: 1.0,
                              divisions: 20,
                              activeColor: Colors.white70,
                              inactiveColor: Colors.white24,
                              onChanged: (v) => provider.setBackgroundOpacity(v),
                            ),
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${(provider.backgroundOpacity * 100).round()}%',
                              style: GoogleFonts.rajdhani(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('完全透明',
                              style: GoogleFonts.rajdhani(
                                  color: Colors.white38, fontSize: 11)),
                          Text('不透明',
                              style: GoogleFonts.rajdhani(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 色の凡例
              _SectionHeader(title: '色の凡例'),
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _ColorLegendRow(
                          color: const Color(0xFFFF4444), label: '日曜日・祝日'),
                      const SizedBox(height: 8),
                      _ColorLegendRow(
                          color: const Color(0xFF4488FF), label: '土曜日'),
                      const SizedBox(height: 8),
                      _ColorLegendRow(color: Colors.white, label: '平日'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 祝日について
              _SectionHeader(title: '祝日データ'),
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '日本の祝日データは holidays-jp.github.io から自動取得します。\n'
                    'データは24時間キャッシュされ、期限切れ後に自動更新されます。',
                    style: GoogleFonts.rajdhani(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showColorPicker(BuildContext context, SettingsProvider provider) {
    Color pickedColor = provider.backgroundColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          '背景色を選択',
          style: GoogleFonts.rajdhani(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickedColor,
            onColorChanged: (c) => pickedColor = c,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: GoogleFonts.rajdhani(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white24,
            ),
            onPressed: () async {
              await provider.setBackgroundColor(pickedColor);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('決定',
                style: GoogleFonts.rajdhani(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.rajdhani(
          fontSize: 12,
          color: Colors.white54,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ColorLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  const _ColorLegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.rajdhani(color: Colors.white),
        ),
      ],
    );
  }
}

/// 透過プレビュー用の市松模様を描画するPainter
class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 8.0;
    final light = Paint()..color = const Color(0xFFCCCCCC);
    final dark = Paint()..color = const Color(0xFF888888);
    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final isLight = ((x / cellSize).floor() + (y / cellSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isLight ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) => false;
}
