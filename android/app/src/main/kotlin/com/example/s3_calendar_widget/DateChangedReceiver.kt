package com.example.s3_calendar_widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.Calendar

/**
 * 日付変更時にウィジェットを自動更新するレシーバー。
 *
 * - BOOT_COMPLETED / ウィジェット追加時 → 翌日0時のアラームをスケジュール
 * - ACTION_MIDNIGHT_UPDATE (自前インテント) → ウィジェット更新 + 次のアラームを再スケジュール
 */
class DateChangedReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            AppWidgetManager.ACTION_APPWIDGET_ENABLED,
            ACTION_MIDNIGHT_UPDATE -> {
                Log.d(TAG, "onReceive: ${intent.action}")
                if (intent.action == ACTION_MIDNIGHT_UPDATE) {
                    updateAllWidgets(context)
                }
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
            if (ids.isEmpty()) return
            for (id in ids) {
                try {
                    CalendarWidgetProvider.updateWidget(context, manager, id)
                } catch (e: Exception) {
                    Log.e(TAG, "updateWidget failed for id=$id", e)
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
                // setExactAndAllowWhileIdle: Dozeモードでも発火
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    nextMidnight.timeInMillis,
                    pendingIntent
                )
                Log.d(TAG, "Midnight alarm scheduled for ${nextMidnight.time}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule midnight alarm", e)
            }
        }
    }
}

