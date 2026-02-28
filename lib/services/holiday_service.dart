import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/holiday.dart';

class HolidayService {
  static const String _baseUrl =
      'https://holidays-jp.github.io/api/v1';
  static const String _cacheKeyPrefix = 'holidays_cache_';
  static const String _cacheDateKeyPrefix = 'holidays_cache_date_';
  static const Duration _cacheExpiry = Duration(hours: 24);

  // キャッシュ込みで指定年の祝日を返す
  Future<List<Holiday>> getHolidays(int year) async {
    final cached = await _loadFromCache(year);
    if (cached != null) return cached;

    return await _fetchAndCache(year);
  }

  // 指定月の祝日セットを返す（日付文字列 → Holidayマップ）
  Future<Map<String, Holiday>> getHolidayMapForMonth(
      int year, int month) async {
    final all = await getHolidays(year);
    final Map<String, Holiday> map = {};
    for (final h in all) {
      if (h.date.year == year && h.date.month == month) {
        final key = _dateKey(h.date);
        map[key] = h;
      }
    }
    return map;
  }

  // 指定日が祝日かチェック
  Future<Holiday?> getHoliday(DateTime date) async {
    final holidays = await getHolidays(date.year);
    try {
      return holidays.firstWhere(
        (h) => h.date.year == date.year &&
            h.date.month == date.month &&
            h.date.day == date.day,
      );
    } catch (_) {
      return null;
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<List<Holiday>?> _loadFromCache(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheDateStr = prefs.getString('$_cacheDateKeyPrefix$year');
    if (cacheDateStr == null) return null;

    final cacheDate = DateTime.parse(cacheDateStr);
    if (DateTime.now().difference(cacheDate) > _cacheExpiry) {
      return null; // キャッシュ期限切れ（fetchAndCacheで再取得させる）
    }

    final cacheJson = prefs.getString('$_cacheKeyPrefix$year');
    if (cacheJson == null) return null;

    return _parseHolidays(jsonDecode(cacheJson) as Map<String, dynamic>);
  }

  /// 期限切れでも構わずキャッシュを返す（ネットワーク失敗時のフォールバック用）
  Future<List<Holiday>?> _loadFromCacheAnyAge(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString('$_cacheKeyPrefix$year');
    if (cacheJson == null) return null;
    return _parseHolidays(jsonDecode(cacheJson) as Map<String, dynamic>);
  }

  Future<List<Holiday>> _fetchAndCache(int year) async {
    try {
      final url = Uri.parse('$_baseUrl/$year/date.json');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final holidays = _parseHolidays(data);

        // キャッシュに保存
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_cacheKeyPrefix$year', response.body);
        await prefs.setString(
            '$_cacheDateKeyPrefix$year', DateTime.now().toIso8601String());

        debugPrint('[HolidayService] fetched ${holidays.length} holidays for $year');
        return holidays;
      } else {
        debugPrint('[HolidayService] HTTP ${response.statusCode} for $year');
      }
    } catch (e) {
      debugPrint('[HolidayService] fetch error for $year: $e');
    }

    // ネットワーク失敗時：期限切れキャッシュでもフォールバック
    final stale = await _loadFromCacheAnyAge(year);
    if (stale != null) {
      debugPrint('[HolidayService] using stale cache for $year (${stale.length} holidays)');
      return stale;
    }

    debugPrint('[HolidayService] no cache available for $year, returning empty');
    return [];
  }

  List<Holiday> _parseHolidays(Map<String, dynamic> data) {
    final List<Holiday> holidays = [];
    data.forEach((dateStr, name) {
      try {
        holidays.add(Holiday.fromEntry(dateStr, name as String));
      } catch (_) {}
    });
    return holidays;
  }
}

