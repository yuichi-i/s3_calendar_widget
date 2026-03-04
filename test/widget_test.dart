import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s3_calendar_widget/models/app_settings.dart';

void main() {
  test('AppSettingsのデフォルト値が正しい', () {
    const settings = AppSettings();

    expect(settings.backgroundColor, Colors.black);
    expect(settings.startOnMonday, false);
    expect(settings.backgroundOpacity, 0.85);
    expect(settings.saturdayColor, const Color(0xFF4488FF));
    expect(settings.sundayHolidayColor, const Color(0xFFFF4444));
  });

  test('copyWithで指定項目だけ更新できる', () {
    const base = AppSettings();
    final updated = base.copyWith(
      startOnMonday: true,
      backgroundOpacity: 0.5,
    );

    expect(updated.startOnMonday, true);
    expect(updated.backgroundOpacity, 0.5);
    expect(updated.backgroundColor, base.backgroundColor);
    expect(updated.saturdayColor, base.saturdayColor);
    expect(updated.sundayHolidayColor, base.sundayHolidayColor);
  });
}
