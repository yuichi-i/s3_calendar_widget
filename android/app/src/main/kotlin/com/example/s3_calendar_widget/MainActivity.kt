package com.example.s3_calendar_widget

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val tag = "MainActivity"
    // Flutter と通信するチャンネル名
    private val channelName = "com.example.s3_calendar_widget/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    // 現在バッテリー最適化が除外されているか確認
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    val ignoring = pm.isIgnoringBatteryOptimizations(packageName)
                    Log.d(tag, "バッテリー最適化除外状態: $ignoring")
                    result.success(ignoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    // バッテリー最適化除外の設定画面を開く
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(tag, "バッテリー最適化設定画面を開けない", e)
                        // フォールバック: バッテリー最適化の一覧画面を開く
                        try {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            result.success(true)
                        } catch (e2: Exception) {
                            Log.e(tag, "バッテリー設定画面のフォールバックも失敗", e2)
                            result.error("UNAVAILABLE", "設定画面を開けませんでした", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
