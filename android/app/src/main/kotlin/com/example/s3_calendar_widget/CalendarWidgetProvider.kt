package com.example.s3_calendar_widget

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.util.Log
import android.widget.RemoteViews
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

@SuppressLint("NewApi")
class CalendarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                Log.e(TAG, "onUpdate failed", e)
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d(TAG, "onEnabled called")
    }

    companion object {
        private const val TAG = "CalendarWidget"
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val KEY_CALENDAR_DATA = "calendar_widget_data"
        private const val KEY_BG_COLOR = "widget_bg_color"
        private const val KEY_START_ON_MONDAY = "widget_start_on_monday"
        private const val KEY_DOW_HEADERS = "widget_dow_headers"
        private const val KEY_HOLIDAY_DATES = "widget_holiday_dates"

        // 5行×7列=35セル
        private val DAY_ID_MAP: Array<IntArray> by lazy {
            arrayOf(
                intArrayOf(R.id.day_0_0, R.id.day_0_1, R.id.day_0_2, R.id.day_0_3, R.id.day_0_4, R.id.day_0_5, R.id.day_0_6),
                intArrayOf(R.id.day_1_0, R.id.day_1_1, R.id.day_1_2, R.id.day_1_3, R.id.day_1_4, R.id.day_1_5, R.id.day_1_6),
                intArrayOf(R.id.day_2_0, R.id.day_2_1, R.id.day_2_2, R.id.day_2_3, R.id.day_2_4, R.id.day_2_5, R.id.day_2_6),
                intArrayOf(R.id.day_3_0, R.id.day_3_1, R.id.day_3_2, R.id.day_3_3, R.id.day_3_4, R.id.day_3_5, R.id.day_3_6),
                intArrayOf(R.id.day_4_0, R.id.day_4_1, R.id.day_4_2, R.id.day_4_3, R.id.day_4_4, R.id.day_4_5, R.id.day_4_6),
            )
        }

        private val DOW_ID_MAP: IntArray by lazy {
            intArrayOf(
                R.id.tv_dow0, R.id.tv_dow1, R.id.tv_dow2,
                R.id.tv_dow3, R.id.tv_dow4, R.id.tv_dow5, R.id.tv_dow6
            )
        }

        private val COLOR_RED   = Color.parseColor("#FFFF4444")
        private val COLOR_BLUE  = Color.parseColor("#FF4488FF")
        private val COLOR_DIM_RED   = Color.parseColor("#66FF4444")
        private val COLOR_DIM_BLUE  = Color.parseColor("#664488FF")
        private val COLOR_DIM_WHITE = Color.parseColor("#66FFFFFF")

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            Log.d(TAG, "updateWidget called for id=$appWidgetId")
            val prefs: SharedPreferences =
                context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val bgColorInt = try {
                // home_widget の保存型（Int/Long）を判別して正しく読み取る
                val raw = prefs.all[KEY_BG_COLOR]
                when (raw) {
                    is Int  -> raw
                    is Long -> raw.toInt()
                    else    -> Color.BLACK
                }
            } catch (_: Exception) {
                Color.BLACK
            }
            val startOnMonday = prefs.getBoolean(KEY_START_ON_MONDAY, false)
            val calendarDataJson = prefs.getString(KEY_CALENDAR_DATA, null)
            val dowHeadersJson = prefs.getString(KEY_DOW_HEADERS, null)
            val holidayDatesJson = prefs.getString(KEY_HOLIDAY_DATES, null)

            Log.d(TAG, "bgColor=$bgColorInt startOnMonday=$startOnMonday hasData=${calendarDataJson != null}")

            val views = RemoteViews(context.packageName, R.layout.calendar_widget)

            // 背景色設定（API 31+ の setColorInt を使用、minSdk=33 なので安全）
            Log.d(TAG, "applying bgColor=#${Integer.toHexString(bgColorInt)}")
            views.setColorInt(R.id.widget_root, "setBackgroundColor", bgColorInt, bgColorInt)

            // クリックでアプリを起動するインテント
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = "CALENDAR_WIDGET_CLICK"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, appWidgetId, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            // 祝日セットを構築
            val holidaySet = parseHolidayDates(holidayDatesJson)

            // Flutter側からデータがある場合はそれを使用、なければ自力で当月を描画
            if (calendarDataJson != null) {
                try {
                    renderFromJson(views, calendarDataJson, dowHeadersJson, startOnMonday, holidaySet)
                } catch (e: Exception) {
                    Log.w(TAG, "renderFromJson failed, fallback", e)
                    renderCurrentMonth(views, startOnMonday, holidaySet)
                }
            } else {
                renderCurrentMonth(views, startOnMonday, holidaySet)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "updateAppWidget done for id=$appWidgetId")
        }

        private fun renderFromJson(
            views: RemoteViews,
            calendarDataJson: String,
            dowHeadersJson: String?,
            startOnMonday: Boolean,
            holidaySet: Set<String> = emptySet()
        ) {
            val dataArray = JSONArray(calendarDataJson)

            // 月ヘッダー
            val monthYear = extractMonthYear(dataArray)
            views.setTextViewText(R.id.tv_month_year, monthYear)

            // 曜日ヘッダー
            val headers = if (dowHeadersJson != null) {
                val arr = JSONArray(dowHeadersJson)
                Array(7) { i -> if (i < arr.length()) arr.getString(i) else "" }
            } else {
                defaultDowHeaders(startOnMonday)
            }
            val dowColors = buildDowColors(startOnMonday)
            for (i in 0..6) {
                views.setTextViewText(DOW_ID_MAP[i], headers[i])
                views.setTextColor(DOW_ID_MAP[i], dowColors[i])
            }

            // 今日の日付キー
            val todayCal = Calendar.getInstance()
            val todayKey = formatDateKey(
                todayCal.get(Calendar.YEAR),
                todayCal.get(Calendar.MONTH) + 1,
                todayCal.get(Calendar.DAY_OF_MONTH)
            )

            // セルデータ（35セル固定）
            for (cellIndex in 0 until 35) {
                val row = cellIndex / 7
                val col = cellIndex % 7
                val viewId = DAY_ID_MAP[row][col]
                if (cellIndex < dataArray.length()) {
                    val cell = dataArray.getJSONObject(cellIndex)
                    val day = cell.optInt("day", 0)
                    val colorType = cell.optString("colorType", "weekday")
                    val isAdjacent = cell.optBoolean("isAdjacentMonth", false)
                    val dateStr = cell.optString("date", "")
                    val dayText = if (day > 0) day.toString() else ""

                    // colorType が holiday でなくても、holidaySet に含まれていれば祝日扱いにする
                    val effectiveColorType = if (colorType != "holiday" && !isAdjacent && dateStr.isNotEmpty()) {
                        val dateKey = dateStr.take(10)
                        if (holidaySet.contains(dateKey)) "holiday" else colorType
                    } else {
                        colorType
                    }

                    val isToday = !isAdjacent && dateStr.take(10) == todayKey
                    val textColor = resolveColor(effectiveColorType, isAdjacent)
                    val todayTextColor = when (effectiveColorType) {
                        "sunday", "holiday" -> COLOR_RED
                        "saturday"          -> COLOR_BLUE
                        else                -> Color.BLACK
                    }
                    views.setTextViewText(viewId, dayText)
                    if (isToday) {
                        views.setInt(viewId, "setBackgroundResource", R.drawable.today_circle)
                        views.setTextColor(viewId, todayTextColor)
                    } else {
                        views.setInt(viewId, "setBackgroundResource", 0)
                        views.setTextColor(viewId, textColor)
                    }
                } else {
                    views.setTextViewText(viewId, "")
                    views.setInt(viewId, "setBackgroundResource", 0)
                }
            }
        }

        private fun renderCurrentMonth(views: RemoteViews, startOnMonday: Boolean, holidaySet: Set<String> = emptySet()) {
            val cal = Calendar.getInstance()
            val year = cal.get(Calendar.YEAR)
            val month = cal.get(Calendar.MONTH)
            val todayDay = cal.get(Calendar.DAY_OF_MONTH)

            views.setTextViewText(R.id.tv_month_year, "${year}年 ${month + 1}月")

            val headers = defaultDowHeaders(startOnMonday)
            val dowColors = buildDowColors(startOnMonday)
            for (i in 0..6) {
                views.setTextViewText(DOW_ID_MAP[i], headers[i])
                views.setTextColor(DOW_ID_MAP[i], dowColors[i])
            }

            // 当月の月初曜日
            cal.set(year, month, 1)
            val firstDayOfWeek = cal.get(Calendar.DAY_OF_WEEK) // 1=日, 7=土
            val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
            val offset = if (startOnMonday) {
                if (firstDayOfWeek == Calendar.SUNDAY) 6 else firstDayOfWeek - 2
            } else {
                firstDayOfWeek - 1
            }

            // 前月末日
            val prevCal = (cal.clone() as Calendar).apply { add(Calendar.MONTH, -1) }
            val prevDaysInMonth = prevCal.getActualMaximum(Calendar.DAY_OF_MONTH)

            var currentDay = 1
            var nextDay = 1

            for (cellIndex in 0 until 35) {
                val row = cellIndex / 7
                val col = cellIndex % 7
                val viewId = DAY_ID_MAP[row][col]

                when {
                    cellIndex < offset -> {
                        val prevDay = prevDaysInMonth - (offset - 1 - cellIndex)
                        val dow = getDayOfWeek(prevCal.get(Calendar.YEAR), prevCal.get(Calendar.MONTH), prevDay)
                        views.setTextViewText(viewId, prevDay.toString())
                        views.setTextColor(viewId, dimColorForDow(dow))
                        views.setInt(viewId, "setBackgroundResource", 0)
                    }
                    currentDay <= daysInMonth -> {
                        val dow = getDayOfWeek(year, month, currentDay)
                        val dateKey = formatDateKey(year, month + 1, currentDay)
                        val isHoliday = holidaySet.contains(dateKey)
                        val isToday = currentDay == todayDay
                        val normalColor = if (isHoliday) COLOR_RED else brightColorForDow(dow)
                        val todayTextColor = when {
                            isHoliday                  -> COLOR_RED
                            dow == Calendar.SUNDAY     -> COLOR_RED
                            dow == Calendar.SATURDAY   -> COLOR_BLUE
                            else                       -> Color.BLACK
                        }
                        views.setTextViewText(viewId, currentDay.toString())
                        if (isToday) {
                            views.setInt(viewId, "setBackgroundResource", R.drawable.today_circle)
                            views.setTextColor(viewId, todayTextColor)
                        } else {
                            views.setInt(viewId, "setBackgroundResource", 0)
                            views.setTextColor(viewId, normalColor)
                        }
                        currentDay++
                    }
                    else -> {
                        val dow = getDayOfWeek(year, month + 1, nextDay)
                        views.setTextViewText(viewId, nextDay.toString())
                        views.setTextColor(viewId, dimColorForDow(dow))
                        views.setInt(viewId, "setBackgroundResource", 0)
                        nextDay++
                    }
                }
            }
        }

        // ---- ヘルパー ----

        private fun getDayOfWeek(year: Int, month: Int, day: Int): Int =
            Calendar.getInstance().apply { set(year, month, day) }.get(Calendar.DAY_OF_WEEK)

        private fun brightColorForDow(dow: Int) = when (dow) {
            Calendar.SUNDAY   -> COLOR_RED
            Calendar.SATURDAY -> COLOR_BLUE
            else -> Color.WHITE
        }

        private fun dimColorForDow(dow: Int) = when (dow) {
            Calendar.SUNDAY   -> COLOR_DIM_RED
            Calendar.SATURDAY -> COLOR_DIM_BLUE
            else -> COLOR_DIM_WHITE
        }

        private fun resolveColor(colorType: String, isAdjacent: Boolean): Int {
            return if (isAdjacent) {
                when (colorType) {
                    "sunday", "holiday" -> COLOR_DIM_RED
                    "saturday"          -> COLOR_DIM_BLUE
                    else                -> COLOR_DIM_WHITE
                }
            } else {
                when (colorType) {
                    "sunday", "holiday" -> COLOR_RED
                    "saturday"          -> COLOR_BLUE
                    else                -> Color.WHITE
                }
            }
        }

        private fun defaultDowHeaders(startOnMonday: Boolean) =
            if (startOnMonday) arrayOf("月","火","水","木","金","土","日")
            else               arrayOf("日","月","火","水","木","金","土")

        private fun buildDowColors(startOnMonday: Boolean): IntArray =
            if (startOnMonday) intArrayOf(Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, COLOR_BLUE, COLOR_RED)
            else               intArrayOf(COLOR_RED, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, COLOR_BLUE)

        private fun extractMonthYear(dataArray: JSONArray): String {
            for (i in 0 until dataArray.length()) {
                val cell = dataArray.getJSONObject(i)
                if (!cell.optBoolean("isAdjacentMonth", false)) {
                    val dateStr = cell.optString("date", "")
                    if (dateStr.isNotEmpty()) return formatMonthYear(dateStr)
                }
            }
            return ""
        }

        private fun formatMonthYear(dateStr: String): String {
            return try {
                val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.JAPAN)
                val date = sdf.parse(dateStr)!!
                val cal = Calendar.getInstance().apply { time = date }
                "${cal.get(Calendar.YEAR)}年 ${cal.get(Calendar.MONTH) + 1}月"
            } catch (_: Exception) {
                dateStr
            }
        }

        /** "yyyy-MM-dd" 形式の祝日日付セットを JSON 文字列から構築する */
        private fun parseHolidayDates(json: String?): Set<String> {
            if (json == null) return emptySet()
            return try {
                val arr = JSONArray(json)
                val set = mutableSetOf<String>()
                for (i in 0 until arr.length()) {
                    set.add(arr.getString(i))
                }
                set
            } catch (_: Exception) {
                emptySet()
            }
        }

        /** year/month/day を "yyyy-MM-dd" キーに変換（month は 1-origin） */
        private fun formatDateKey(year: Int, month: Int, day: Int): String =
            "%04d-%02d-%02d".format(year, month, day)
    }
}

