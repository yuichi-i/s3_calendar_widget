package com.example.s3_calendar_widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

/**
 * 日付変更時にウィジェットを自動更新するレシーバー。
 *
 * - BOOT_COMPLETED / ウィジェット追加時 → 翌日0時のアラームをスケジュール
 * - ACTION_MIDNIGHT_UPDATE (自前インテント) → ウィジェット更新 + 次のアラームを再スケジュール
 * - ACTION_TIME_CHANGED / ACTION_TIMEZONE_CHANGED → アラームを再スケジュール
 *
 * ColorOS等の独自省電力管理を持つ端末への対策:
 * - canScheduleExactAlarms() がfalseの場合は setWindow() にフォールバックする
 * - 正確なアラーム許可がない場合はユーザーへの案内が必要（Flutterアプリ側で実施）
 */
class DateChangedReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive: ${intent.action}")
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            AppWidgetManager.ACTION_APPWIDGET_ENABLED -> {
                // 端末再起動・ウィジェット追加時はアラームを（再）スケジュール
                scheduleNextMidnightAlarm(context)
            }
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                // 時刻・タイムゾーン変更時はアラームを再スケジュールし、ウィジェットも即時更新
                updateAllWidgets(context)
                scheduleNextMidnightAlarm(context)
            }
            ACTION_MIDNIGHT_UPDATE -> {
                // 日付変更アラーム受信: ウィジェット更新 → 次のアラームをスケジュール
                updateAllWidgets(context)
                scheduleNextMidnightAlarm(context)
            }
        }
    }

    companion object {
        private const val TAG = "DateChangedReceiver"
        const val ACTION_MIDNIGHT_UPDATE = "com.example.s3_calendar_widget.ACTION_MIDNIGHT_UPDATE"

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, CalendarWidgetProvider::class.java)
            )
            if (ids.isEmpty()) {
                Log.d(TAG, "ウィジェットなし、更新をスキップ")
                return
            }
            Log.d(TAG, "ウィジェット更新: ${ids.size}件")
            for (id in ids) {
                try {
                    CalendarWidgetProvider.updateWidget(context, manager, id)
                } catch (e: Exception) {
                    Log.e(TAG, "updateWidget 失敗 id=$id", e)
                }
            }
        }

        fun scheduleNextMidnightAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // 翌日0時0分1秒を計算
            val nextMidnight = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 1)
                set(Calendar.MILLISECOND, 0)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                Intent(context, DateChangedReceiver::class.java).apply {
                    action = ACTION_MIDNIGHT_UPDATE
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                    // Android 12以降で正確なアラームの許可がない場合:
                    // setWindow() を使用（最大15分の誤差があるが Doze 対応）
                    Log.w(TAG, "正確なアラームの許可なし → setWindow() にフォールバック")
                    alarmManager.setWindow(
                        AlarmManager.RTC_WAKEUP,
                        nextMidnight.timeInMillis,
                        15 * 60 * 1000L, // 15分の誤差ウィンドウ
                        pendingIntent
                    )
                } else {
                    // setExactAndAllowWhileIdle: Dozeモード中でも指定時刻に発火
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        nextMidnight.timeInMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "正確なアラームをセット: ${nextMidnight.time}")
                }
            } catch (e: SecurityException) {
                // 正確なアラームのパーミッションが実行時に拒否された場合
                Log.e(TAG, "正確なアラームのセキュリティ例外 → setWindow() にフォールバック", e)
                try {
                    alarmManager.setWindow(
                        AlarmManager.RTC_WAKEUP,
                        nextMidnight.timeInMillis,
                        15 * 60 * 1000L,
                        pendingIntent
                    )
                } catch (e2: Exception) {
                    Log.e(TAG, "setWindow() も失敗", e2)
                }
            } catch (e: Exception) {
                Log.e(TAG, "アラームセット失敗", e)
            }
        }
    }
}

