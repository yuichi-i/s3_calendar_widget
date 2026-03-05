import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/google_calendar_service.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = const AppSettings();
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();

  AppSettings get settings => _settings;
  Color get backgroundColor => _settings.backgroundColor;
  bool get startOnMonday => _settings.startOnMonday;
  double get backgroundOpacity => _settings.backgroundOpacity;
  /// 土曜日の文字色
  Color get saturdayColor => _settings.saturdayColor;
  /// 日曜・祝日の文字色
  Color get sundayHolidayColor => _settings.sundayHolidayColor;

  /// Googleカレンダー連携が有効かどうか
  bool get googleCalendarEnabled => _googleCalendarService.isSignedIn;
  /// 連携中のアカウントメールアドレス
  String? get googleAccountEmail => _googleCalendarService.currentUser?.email;

  /// Googleカレンダー表示の●色（1件目）
  Color get firstEventDotColor => _settings.firstEventDotColor;
  /// Googleカレンダー表示の●色（2件目）
  Color get secondEventDotColor => _settings.secondEventDotColor;
  /// Googleカレンダー表示の●色（3件目）
  Color get thirdEventDotColor => _settings.thirdEventDotColor;

  Future<void> init() async {
    _settings = await AppSettings.load();
    // アプリ起動時にサインイン状態を復元
    await _googleCalendarService.restoreSignIn();
    notifyListeners();
  }

  Future<void> setBackgroundColor(Color color) async {
    _settings = _settings.copyWith(backgroundColor: color);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setBackgroundOpacity(double opacity) async {
    _settings = _settings.copyWith(backgroundOpacity: opacity);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setStartOnMonday(bool value) async {
    _settings = _settings.copyWith(startOnMonday: value);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setSaturdayColor(Color color) async {
    _settings = _settings.copyWith(saturdayColor: color);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setSundayHolidayColor(Color color) async {
    _settings = _settings.copyWith(sundayHolidayColor: color);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setFirstEventDotColor(Color color) async {
    _settings = _settings.copyWith(firstEventDotColor: color);
    await _settings.save();
    // 色変更時はキャッシュを捨てて次回取得で新色を反映する
    _googleCalendarService.clearCache();
    notifyListeners();
  }

  Future<void> setSecondEventDotColor(Color color) async {
    _settings = _settings.copyWith(secondEventDotColor: color);
    await _settings.save();
    // 色変更時はキャッシュを捨てて次回取得で新色を反映する
    _googleCalendarService.clearCache();
    notifyListeners();
  }

  Future<void> setThirdEventDotColor(Color color) async {
    _settings = _settings.copyWith(thirdEventDotColor: color);
    await _settings.save();
    // 色変更時はキャッシュを捨てて次回取得で新色を反映する
    _googleCalendarService.clearCache();
    notifyListeners();
  }

  /// Googleカレンダーにサインインする
  Future<bool> signInGoogle() async {
    final account = await _googleCalendarService.signIn();
    // サインイン直後は前回のインメモリキャッシュを使わない
    _googleCalendarService.clearCache();
    notifyListeners();
    return account != null;
  }

  /// Googleカレンダーからサインアウトする
  Future<void> signOutGoogle() async {
    await _googleCalendarService.signOut();
    notifyListeners();
  }
}
