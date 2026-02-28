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
            onPressed: () {
              provider.setBackgroundColor(pickedColor);
              Navigator.pop(ctx);
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

