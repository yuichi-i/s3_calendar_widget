import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'screens/calendar_list_screen.dart';

const String appGroupId = 'com.example.s3_calendar_widget';
const String iOSWidgetName = 'CalendarWidget';
const String androidWidgetName = 'CalendarWidgetProvider';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidget.setAppGroupId(appGroupId);
  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider()..init(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    HomeWidget.widgetClicked.listen(_handleWidgetClick);
  }

  void _handleWidgetClick(Uri? uri) {
    // ウィジェットクリック時の処理はナビゲーター経由で行う
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'カレンダーウィジェット',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const CalendarListScreen(),
      routes: {
        '/calendar': (context) => const CalendarListScreen(),
      },
    );
  }
}
