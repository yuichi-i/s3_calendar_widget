# S3カレンダーウィジェット

Android ホーム画面に月間カレンダーを表示するウィジェットアプリです。  
Flutter で作成されており、日本の祝日を自動取得して色分け表示します。  
Google カレンダーとの連携により、予定を日付上にインジケーター表示できます。

---

## 機能要件

### カレンダー表示
- 月間カレンダーをカード形式で表示（2列グリッド）
- 月の週数に応じて5行または6行表示
- 過去・未来の月を無限スクロールで追加読み込み
- 起動時は自動的に当月へスクロール

### ホーム画面ウィジェット
- Android ホーム画面に今月のカレンダーウィジェットを配置可能（横3×縦2セル）
- アプリ起動・設定変更時に自動でウィジェットデータを更新
- **日付が変わった際（深夜0時）に自動でウィジェットを更新**（端末再起動後も維持）
- **本日の日付を半透明グレーの丸でハイライト表示**（土曜=青、日曜・祝日=赤、平日=黒文字）

### 祝日対応
- [holidays-jp.github.io](https://holidays-jp.github.io/api/v1/) から日本の祝日データを自動取得
- 取得データは SharedPreferences に 24 時間キャッシュ
- オフライン時はキャッシュがフォールバックとして使用される

### Googleカレンダー連携
- Google アカウントでサインインし、Googleカレンダーの「予定」をアプリ画面のカレンダーに表示
- 予定が登録されている日付の下に色付きの●（インジケーター）を表示（最大3件）
- 前月・次月の埋め部分にも薄色で●を表示
- 日付をタップすると Google カレンダーアプリが起動し、該当日付付近を表示
- 連携は設定画面からサインイン/サインアウトで管理
- ウィジェット画面への予定表示には非対応（表示スペースの都合による）

### 日付の色分け
| 日付種別 | 色 |
|---|---|
| 平日 | 白 |
| 土曜日 | 青（`#4488FF`、変更可） |
| 日曜日・祝日 | 赤（`#FF4444`、変更可） |

### カスタマイズ設定
- **週の始まり**: 日曜始まり（デフォルト） / 月曜始まり
- **ウィジェット背景色**: カラーピッカーで自由に選択
- **ウィジェット背景透過率**: スライダーで透過率を調整（デフォルト: やや透過）
- **土曜日の文字色**: カラーピッカーで変更可能（デフォルト: 青 `#4488FF`）
- **日曜日・祝日の文字色**: カラーピッカーで変更可能（デフォルト: 赤 `#FF4444`）
- **Googleカレンダー連携**: サインイン/サインアウト
- **Googleカレンダーイベント●の色**: 10色から選択可能

### デザイン
- ダークテーマ固定（背景色: 黒）
- セリフ体イタリックフォント（Android 標準 serif）

---

## 動作要件

| 項目 | 要件 |
|---|---|
| OS | Android 13 以上（API Level 33+） |
| Flutter | 3.38.9 以上 |
| Dart | 3.10.8 以上 |

---

## 使用ライブラリ

| パッケージ | 用途 |
|---|---|
| `home_widget` | ホーム画面ウィジェットの更新・データ連携 |
| `provider` | 状態管理 |
| `shared_preferences` | 設定・祝日キャッシュの永続化 |
| `http` | 祝日 API の取得 |
| `flutter_colorpicker` | ウィジェット背景色の選択 UI |
| `google_sign_in` | Googleアカウント認証 |
| `googleapis` | Google Calendar API アクセス |
| `google_fonts` | フォント（Rajdhani等） |
| `url_launcher` | Googleカレンダーアプリの起動 |

---

## ビルド方法

### 前提条件

- Flutter SDK がインストール済みであること
- Android Studio または VS Code がセットアップ済みであること
- Android 開発環境（Android SDK）が設定済みであること
- Googleカレンダー連携を使う場合は、Firebase プロジェクトと Google Cloud の OAuth クライアントの設定が必要（後述）

### セットアップ

```bash
# リポジトリのクローン
git clone git@github.com:yuichi-i/s3_calendar_widget.git
cd s3_calendar_widget

# 依存パッケージの取得
flutter pub get
```

### Googleカレンダー連携のセットアップ（オプション）

1. [Firebase Console](https://console.firebase.google.com/) でプロジェクトを作成し、Android アプリを追加
2. `google-services.json` をダウンロードして `android/app/` に配置
3. [Google Cloud Console](https://console.cloud.google.com/) で Google Calendar API を有効化
4. OAuth 2.0 クライアント ID（Android 用）を作成し、アプリの SHA-1 フィンガープリントを登録

> **Note:** `google-services.json` にはプロジェクト固有の認証情報が含まれます。  
> このファイルは `.gitignore` に含まれているため、クローン後に各自で取得・配置してください。

### デバッグ実行

```bash
# 接続済みデバイスまたはエミュレーターで実行
flutter run
```

### リリースビルド（APK）

```bash
flutter build apk --release
```

ビルド成果物: `build/app/outputs/flutter-apk/app-release.apk`

### リリースビルド（App Bundle）

```bash
flutter build appbundle --release
```

---

## 使用方法

### アプリ画面

1. アプリを起動するとカレンダー一覧画面が表示される
2. 上下スクロールで過去・未来の月を閲覧できる
3. 右上の設定アイコン（⚙️）から設定画面を開く
4. Googleカレンダー連携を有効にすると、予定のある日に●インジケーターが表示される
5. 日付をタップすると Google カレンダーアプリが起動する

### 設定画面

- **週の始まり**: 日曜始まり / 月曜始まり を切り替え
- **ウィジェット背景色**: カラーピッカーで任意の色を選択
- **ウィジェット背景透過率**: スライダーで透過率を調整
- **土曜日の文字色**: カラーピッカーで任意の色を選択（デフォルト: 青）
- **日曜日・祝日の文字色**: カラーピッカーで任意の色を選択（デフォルト: 赤）
- **Googleカレンダー連携**: Googleアカウントでサインインして予定を表示
- 設定変更後、ホーム画面ウィジェットが自動的に更新される

### ホーム画面ウィジェットの追加（Android）

1. ホーム画面を長押し → **ウィジェット** を選択
2. 一覧から **S3 Calendar Widget** を探して配置
3. アプリを起動するたびにウィジェットのカレンダーデータが最新化される

---

## プロジェクト構成

```
android/
└── app/src/main/kotlin/.../
    ├── CalendarWidgetProvider.kt  # ホーム画面ウィジェット描画
    ├── DateChangedReceiver.kt     # 日付変更時の自動更新・アラーム管理
    └── MainActivity.kt            # アプリエントリー
lib/
├── main.dart                   # アプリエントリーポイント
├── models/
│   ├── app_settings.dart       # 設定モデル（永続化）
│   ├── calendar_cell.dart      # カレンダーセルデータ
│   └── holiday.dart            # 祝日モデル
├── providers/
│   └── settings_provider.dart  # 設定の状態管理
├── screens/
│   ├── calendar_list_screen.dart  # カレンダー一覧画面
│   └── settings_screen.dart       # 設定画面
├── services/
│   ├── calendar_service.dart      # カレンダーセル生成ロジック
│   ├── google_calendar_service.dart # Googleカレンダー連携
│   ├── holiday_service.dart       # 祝日取得・キャッシュ
│   └── widget_update_service.dart # ホーム画面ウィジェット更新
└── widgets/
    ├── day_cell_widget.dart        # 日付セル UI
    └── month_calendar_card.dart    # 月カレンダーカード UI
```
