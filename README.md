# S3 Calendar Widget

Android ホーム画面に月間カレンダーを表示するウィジェットアプリです。  
Flutter で作成されており、日本の祝日を自動取得して色分け表示します。

---

## 機能要件

### カレンダー表示
- 月間カレンダーをカード形式で表示（2列グリッド）
- 過去・未来の月を無限スクロールで追加読み込み
- 起動時は自動的に当月へスクロール

### ホーム画面ウィジェット
- Android ホーム画面に今月のカレンダーウィジェットを配置可能
- アプリ起動・設定変更時に自動でウィジェットデータを更新

### 祝日対応
- [holidays-jp.github.io](https://holidays-jp.github.io/api/v1/) から日本の祝日データを自動取得
- 取得データは SharedPreferences に 24 時間キャッシュ
- オフライン時はキャッシュがフォールバックとして使用される

### 日付の色分け
| 日付種別 | 色 |
|---|---|
| 平日 | 白 |
| 土曜日 | 青（`#4488FF`） |
| 日曜日・祝日 | 赤（`#FF4444`） |

### カスタマイズ設定
- **週の始まり**: 日曜始まり（デフォルト） / 月曜始まり
- **ウィジェット背景色**: カラーピッカーで自由に選択

### デザイン
- ダークテーマ固定（背景色: 黒）
- [Rajdhani](https://fonts.google.com/specimen/Rajdhani) フォント（Google Fonts）

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
| `google_fonts` | Rajdhani フォントの適用 |
| `http` | 祝日 API の取得 |
| `flutter_colorpicker` | ウィジェット背景色の選択 UI |

---

## ビルド方法

### 前提条件

- Flutter SDK がインストール済みであること
- Android Studio または VS Code がセットアップ済みであること
- Android 開発環境（Android SDK）が設定済みであること

### セットアップ

```bash
# リポジトリのクローン
git clone <repository-url>
cd s3_calendar_widget

# 依存パッケージの取得
flutter pub get
```

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

### 設定画面

- **週の始まり**: 日曜始まり / 月曜始まり を切り替え
- **ウィジェット背景色**: カラーピッカーで任意の色を選択
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
│   ├── holiday_service.dart       # 祝日取得・キャッシュ
│   └── widget_update_service.dart # ホーム画面ウィジェット更新
└── widgets/
    ├── day_cell_widget.dart        # 日付セル UI
    └── month_calendar_card.dart    # 月カレンダーカード UI
```
