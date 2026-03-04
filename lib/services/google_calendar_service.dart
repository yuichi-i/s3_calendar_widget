import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Google カレンダー連携サービス
/// サインイン・サインアウト・イベント取得・カレンダーアプリ起動を担う
class GoogleCalendarService {
  static final GoogleCalendarService _instance = GoogleCalendarService._internal();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._internal();

  /// 月ごとのイベントキャッシュ（キー: "yyyy-M"）
  final Map<String, Map<String, List<Color>>> _eventCache = {};

  /// Google Sign-In インスタンス（Calendar の読み取りスコープを要求）
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [gcal.CalendarApi.calendarReadonlyScope],
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
    await _googleSignIn.signOut();
    _eventCache.clear();
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

  /// 指定月のイベントを取得する（キャッシュあり）
  /// 戻り値: 日付文字列（yyyy-MM-dd）→ イベント色リスト のマップ（最大3件/日）
  /// 誕生日カレンダー（#contacts@group.v.calendar.google.com 等）は除外する
  Future<Map<String, List<Color>>> fetchEventsForMonth(int year, int month) async {
    if (!isSignedIn) return {};

    final cacheKey = '$year-$month';
    if (_eventCache.containsKey(cacheKey)) {
      return _eventCache[cacheKey]!;
    }

    try {
      final headers = await currentUser!.authHeaders;
      final client = _AuthClient(http.Client(), headers);
      final calendarApi = gcal.CalendarApi(client);

      // 除外するカレンダーIDのセットを取得
      final excludedCalendarIds = await _getBirthdayCalendarIds(calendarApi);

      // 取得範囲: 月の初日 〜 月の末日
      final timeMin = DateTime(year, month, 1).toUtc();
      final timeMax = DateTime(year, month + 1, 0, 23, 59, 59).toUtc();

      final events = await calendarApi.events.list(
        'primary', // プライマリカレンダー（ユーザーが登録した予定）
        timeMin: timeMin,
        timeMax: timeMax,
        singleEvents: true, // 繰り返しイベントも展開
        orderBy: 'startTime',
        maxResults: 250,
      );

      client.close();

      final result = <String, List<Color>>{};

      for (final event in (events.items ?? [])) {
        // 誕生日・記念日イベントを除外（eventType で判定）
        // eventType: 'birthday' または organizer が contacts グループの場合はスキップ
        if (_isBirthdayEvent(event, excludedCalendarIds)) continue;

        // 開始日付を取得（終日イベントは date、時刻指定は dateTime）
        final startDate = event.start?.date ?? event.start?.dateTime?.toLocal();
        if (startDate == null) continue;

        final key =
            '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

        final list = result.putIfAbsent(key, () => []);
        // 1日あたり最大3件まで、件数順に固定色を割り当て
        if (list.length < 3) {
          list.add(_eventDotColor(list.length));
        }
      }

      // 結果をキャッシュに保存
      _eventCache[cacheKey] = result;
      return result;
    } catch (e) {
      debugPrint('カレンダーイベント取得エラー: $e');
      return {};
    }
  }

  /// 複数月のイベントをまとめて取得する（未キャッシュ月のみAPIを呼ぶ）
  /// 戻り値: "yyyy-M" → イベントマップ
  Future<Map<String, Map<String, List<Color>>>> fetchEventsForMonths(
      List<DateTime> months) async {
    if (!isSignedIn) return {};

    // 未キャッシュの月だけAPIで取得（最大5並行）
    final uncachedMonths =
        months.where((m) => !_eventCache.containsKey('${m.year}-${m.month}')).toList();

    if (uncachedMonths.isNotEmpty) {
      const batchSize = 5;
      for (int i = 0; i < uncachedMonths.length; i += batchSize) {
        final batch = uncachedMonths.skip(i).take(batchSize).toList();
        await Future.wait(
          batch.map((m) => fetchEventsForMonth(m.year, m.month)),
        );
      }
    }

    // キャッシュから結果を返す
    final result = <String, Map<String, List<Color>>>{};
    for (final m in months) {
      final key = '${m.year}-${m.month}';
      result[key] = _eventCache[key] ?? {};
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
          .where((cal) =>
              cal.id?.contains('#contacts@group') == true ||
              cal.id?.contains('birthday') == true ||
              cal.summary?.toLowerCase().contains('birthday') == true ||
              cal.summary?.contains('誕生日') == true)
          .map((cal) => cal.id ?? '')
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// イベントが誕生日・記念日かどうかを判定する
  bool _isBirthdayEvent(gcal.Event event, Set<String> excludedCalendarIds) {
    // eventType が 'birthday' の場合は除外
    if (event.eventType == 'birthday') return true;
    // Google コンタクトの誕生日は organizer のメールが contacts グループ
    final organizerEmail = event.organizer?.email ?? '';
    if (organizerEmail.contains('#contacts@group')) return true;
    if (organizerEmail.contains('calendar.google.com') &&
        organizerEmail.contains('birthday')) {
      return true;
    }
    // カレンダーID で除外
    // （primary カレンダーのイベントだが念のため）
    return false;
  }

  /// 件数順（0始まり）に●の色を返す
  /// 1件目: Google ブルー、2件目: グリーン、3件目: オレンジ
  Color _eventDotColor(int index) {
    switch (index) {
      case 0: return const Color(0xFF4285F4); // Google ブルー
      case 1: return const Color(0xFF34A853); // Google グリーン
      case 2: return const Color(0xFFFF6D00); // オレンジ
      default: return const Color(0xFF4285F4);
    }
  }

  /// 指定日付を Google カレンダーアプリで開く
  /// アプリが入っていれば起動、なければブラウザで開く
  Future<void> openCalendarOnDate(DateTime date) async {
    // Google カレンダーアプリ用の URI
    // content://com.android.calendar/time/<epoch_ms> でアプリを起動
    final epochMs = date.millisecondsSinceEpoch;
    final appUri = Uri.parse('content://com.android.calendar/time/$epochMs');
    final webUri = Uri.parse(
      'https://calendar.google.com/calendar/r/day/${date.year}/${date.month}/${date.day}',
    );

    // まずカレンダーアプリを試みる
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(webUri)) {
      // フォールバック: ブラウザで Google カレンダー Web を開く
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

