import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:googleapis/tasks/v1.dart' as gtask;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_settings.dart';

/// Google カレンダー連携サービス
/// サインイン・サインアウト・イベント取得・カレンダーアプリ起動を担う
class GoogleCalendarService {
  static final GoogleCalendarService _instance =
      GoogleCalendarService._internal();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._internal();

  /// 月ごとのイベントキャッシュ（キー: "yyyy-M"）
  final Map<String, Map<String, List<Color>>> _eventCache = {};

  static const Color _taskDotColor = Color(0xFFAB47BC);

  /// Google Sign-In インスタンス（Calendar/Tasks 読み取りスコープを要求）
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      gcal.CalendarApi.calendarReadonlyScope,
      gtask.TasksApi.tasksReadonlyScope,
    ],
  );

  /// 現在サインイン中のアカウント（未サインインなら null）
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// サインイン済みかどうか
  bool get isSignedIn => currentUser != null;

  /// サインイン（アカウント選択ダイアログを表示）
  /// 成功すれば GoogleSignInAccount を返す、失敗・キャンセルなら null
  Future<GoogleSignInAccount?> signIn() async {
    try {
      // 前回のサインイン状態を復元
      final account = await _googleSignIn.signInSilently();
      if (account != null) return account;
      return await _googleSignIn.signIn();
    } catch (e) {
      debugPrint('GoogleSignIn エラー: $e');
      return null;
    }
  }

  /// サインアウト
  Future<void> signOut() async {
    final owner = _cacheOwnerKey(currentUser?.email);
    await _googleSignIn.signOut();
    _eventCache.clear();
    await _clearPersistedCacheForOwner(owner);
  }

  /// サインイン状態を復元（アプリ起動時に呼ぶ）
  Future<GoogleSignInAccount?> restoreSignIn() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('GoogleSignIn 状態復元エラー: $e');
      return null;
    }
  }

  /// 指定月のイベント/タスクを取得する（キャッシュあり）
  /// 戻り値: 日付文字列（yyyy-MM-dd）→ イベント色リスト のマップ（最大3件/日）
  Future<Map<String, List<Color>>> fetchEventsForMonth(
    int year,
    int month, {
    bool forceRefresh = false,
  }) async {
    if (!isSignedIn) return {};

    final cacheKey = '$year-$month';

    if (!forceRefresh) {
      if (_eventCache.containsKey(cacheKey)) {
        return _eventCache[cacheKey]!;
      }
      final persisted = await _loadMonthCacheFromDisk(cacheKey);
      if (persisted != null) {
        _eventCache[cacheKey] = persisted;
        return persisted;
      }
    }

    // 失敗時は既存キャッシュを優先して返す
    final fallback = _eventCache[cacheKey] ??
        await _loadMonthCacheFromDisk(cacheKey) ??
        <String, List<Color>>{};

    _AuthClient? client;
    try {
      final headers = await currentUser!.authHeaders;
      client = _AuthClient(http.Client(), headers);
      final calendarApi = gcal.CalendarApi(client);
      final tasksApi = gtask.TasksApi(client);

      // 取得範囲: 月の初日 〜 月末23:59:59
      final timeMin = DateTime(year, month, 1);
      final timeMax = DateTime(year, month + 1, 0, 23, 59, 59);

      final excludedCalendarIds = await _getBirthdayCalendarIds(calendarApi);

      // 予定取得は必須。ここが失敗したらフォールバックを返す
      final events = await calendarApi.events.list(
        'primary',
        timeMin: timeMin.toUtc(),
        timeMax: timeMax.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
        maxResults: 250,
      );

      // タスク取得は任意。失敗しても予定表示は継続する
      List<DateTime> taskDates = [];
      try {
        taskDates = await _fetchTasksForRange(tasksApi, timeMin, timeMax);
      } catch (e) {
        debugPrint('Googleタスク取得エラー（予定表示は継続）: $e');
      }

      final result = <String, List<Color>>{};

      for (final event in (events.items ?? [])) {
        if (_isBirthdayEvent(event, excludedCalendarIds)) continue;

        final startDate = event.start?.date ?? event.start?.dateTime?.toLocal();
        if (startDate == null) continue;

        final key = _dateKey(startDate);
        final list = result.putIfAbsent(key, () => []);
        if (list.length < 3) {
          list.add(_eventDotColor(list.length));
        }
      }

      for (final date in taskDates) {
        final key = _dateKey(date);
        final list = result.putIfAbsent(key, () => []);
        if (list.length < 3) {
          list.add(_taskDotColor);
        }
      }

      _eventCache[cacheKey] = result;
      await _saveMonthCacheToDisk(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('カレンダーイベント取得エラー: $e');
      return fallback;
    } finally {
      client?.close();
    }
  }

  /// 複数月のイベントをまとめて取得する
  /// forceRefresh=true の場合、指定月をすべて再取得する
  Future<Map<String, Map<String, List<Color>>>> fetchEventsForMonths(
    List<DateTime> months, {
    bool forceRefresh = false,
  }) async {
    if (!isSignedIn) return {};

    final targets = forceRefresh
        ? months
        : months.where((m) => !_eventCache.containsKey(_monthKey(m))).toList();

    if (targets.isNotEmpty) {
      const batchSize = 5;
      for (int i = 0; i < targets.length; i += batchSize) {
        final batch = targets.skip(i).take(batchSize).toList();
        await Future.wait(
          batch.map(
            (m) => fetchEventsForMonth(
              m.year,
              m.month,
              forceRefresh: forceRefresh,
            ),
          ),
        );
      }
    }

    final result = <String, Map<String, List<Color>>>{};
    for (final m in months) {
      final key = _monthKey(m);
      result[key] = _eventCache[key] ?? {};
    }
    return result;
  }

  /// 永続化キャッシュのみを先に読み込む（ネットワークアクセスなし）
  Future<Map<String, Map<String, List<Color>>>> getCachedEventsForMonths(
    List<DateTime> months,
  ) async {
    if (!isSignedIn) return {};

    final result = <String, Map<String, List<Color>>>{};
    for (final m in months) {
      final key = _monthKey(m);
      if (_eventCache.containsKey(key)) {
        result[key] = _eventCache[key]!;
        continue;
      }
      final persisted = await _loadMonthCacheFromDisk(key);
      if (persisted != null) {
        _eventCache[key] = persisted;
        result[key] = persisted;
      }
    }
    return result;
  }

  /// イベントキャッシュをクリアする（強制再取得したい場合に使用）
  void clearCache() {
    _eventCache.clear();
  }

  /// 誕生日・記念日系のカレンダーIDを取得する
  Future<Set<String>> _getBirthdayCalendarIds(gcal.CalendarApi api) async {
    try {
      final list = await api.calendarList.list();
      return (list.items ?? [])
          .where(
            (cal) =>
                cal.id?.contains('#contacts@group') == true ||
                cal.id?.contains('birthday') == true ||
                cal.summary?.toLowerCase().contains('birthday') == true ||
                cal.summary?.contains('誕生日') == true,
          )
          .map((cal) => cal.id ?? '')
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// 指定期間の未完了タスク期限日を取得する
  Future<List<DateTime>> _fetchTasksForRange(
    gtask.TasksApi tasksApi,
    DateTime timeMin,
    DateTime timeMax,
  ) async {
    final result = <DateTime>[];
    final taskLists = await tasksApi.tasklists.list(maxResults: 100);

    for (final taskList in (taskLists.items ?? [])) {
      final taskListId = taskList.id;
      if (taskListId == null || taskListId.isEmpty) continue;

      String? pageToken;
      do {
        final tasks = await tasksApi.tasks.list(
          taskListId,
          maxResults: 100,
          showCompleted: false,
          showDeleted: false,
          showHidden: false,
          pageToken: pageToken,
        );

        for (final task in (tasks.items ?? [])) {
          final due = task.due;
          if (due == null || due.isEmpty) continue;
          final parsed = DateTime.tryParse(due)?.toLocal();
          if (parsed == null) continue;

          if (!parsed.isBefore(timeMin) && !parsed.isAfter(timeMax)) {
            result.add(parsed);
          }
        }

        pageToken = tasks.nextPageToken;
      } while (pageToken != null && pageToken.isNotEmpty);
    }

    result.sort((a, b) => a.compareTo(b));
    return result;
  }

  /// イベントが誕生日・記念日かどうかを判定する
  bool _isBirthdayEvent(gcal.Event event, Set<String> excludedCalendarIds) {
    if (event.eventType == 'birthday') return true;

    final organizerEmail = event.organizer?.email ?? '';
    if (organizerEmail.contains('#contacts@group')) return true;
    if (organizerEmail.contains('calendar.google.com') &&
        organizerEmail.contains('birthday')) {
      return true;
    }

    final calendarId = event.organizer?.email ?? event.iCalUID ?? '';
    if (excludedCalendarIds.contains(calendarId)) return true;
    return false;
  }

  String _monthKey(DateTime date) => '${date.year}-${date.month}';

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _cacheOwnerKey(String? email) => (email ?? 'anonymous').toLowerCase();

  String _cacheDataKey(String ownerKey, String monthKey) =>
      '${AppSettings.googleEventCacheKeyPrefix}${ownerKey}_$monthKey';

  String _cacheDateKey(String ownerKey, String monthKey) =>
      '${AppSettings.googleEventCacheDateKeyPrefix}${ownerKey}_$monthKey';

  Future<void> _saveMonthCacheToDisk(
    String monthKey,
    Map<String, List<Color>> values,
  ) async {
    final owner = _cacheOwnerKey(currentUser?.email);
    final prefs = await SharedPreferences.getInstance();

    final encoded = <String, List<int>>{};
    values.forEach((dateKey, colorList) {
      encoded[dateKey] = colorList
          .map((c) => c.toARGB32().toSigned(32))
          .toList();
    });

    await prefs.setString(_cacheDataKey(owner, monthKey), jsonEncode(encoded));
    await prefs.setString(
      _cacheDateKey(owner, monthKey),
      DateTime.now().toIso8601String(),
    );
  }

  Future<Map<String, List<Color>>?> _loadMonthCacheFromDisk(
    String monthKey,
  ) async {
    final owner = _cacheOwnerKey(currentUser?.email);
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cacheDataKey(owner, monthKey));
    if (jsonString == null || jsonString.isEmpty) return null;

    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final result = <String, List<Color>>{};
      decoded.forEach((dateKey, rawList) {
        if (rawList is! List) return;
        result[dateKey] = rawList
            .whereType<num>()
            .map((v) => Color(v.toInt()))
            .toList(growable: false);
      });
      return result;
    } catch (e) {
      debugPrint('Googleイベントキャッシュ読み込みエラー: $e');
      return null;
    }
  }

  Future<void> _clearPersistedCacheForOwner(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    final dataPrefix = '${AppSettings.googleEventCacheKeyPrefix}${owner}_';
    final datePrefix = '${AppSettings.googleEventCacheDateKeyPrefix}${owner}_';

    final removeKeys = prefs
        .getKeys()
        .where((k) => k.startsWith(dataPrefix) || k.startsWith(datePrefix))
        .toList(growable: false);

    for (final key in removeKeys) {
      await prefs.remove(key);
    }
  }

  /// 件数順（0始まり）に●の色を返す
  /// 1件目: Google ブルー、2件目: グリーン、3件目: オレンジ
  Color _eventDotColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFF4285F4);
      case 1:
        return const Color(0xFF34A853);
      case 2:
        return const Color(0xFFFF6D00);
      default:
        return const Color(0xFF4285F4);
    }
  }

  /// 指定日付を Google カレンダーアプリで開く
  /// アプリが入っていれば起動、なければブラウザで開く
  Future<void> openCalendarOnDate(DateTime date) async {
    final epochMs = date.millisecondsSinceEpoch;
    final appUri = Uri.parse('content://com.android.calendar/time/$epochMs');
    final webUri = Uri.parse(
      'https://calendar.google.com/calendar/r/day/${date.year}/${date.month}/${date.day}',
    );

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Google カレンダーを開けませんでした');
    }
  }
}

/// Google Sign-In の認証ヘッダーを付与するHTTPクライアント
class _AuthClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _headers;

  _AuthClient(this._inner, this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
