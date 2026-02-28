package com.example.s3_calendar_widget

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

@SuppressLint("NewApi")
class CalendarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            try { updateWidget(context, appWidgetManager, appWidgetId) }
            catch (e: Exception) { Log.e(TAG, "onUpdate failed", e) }
        }
    }

    override fun onEnabled(context: Context) { super.onEnabled(context); Log.d(TAG, "onEnabled") }

    companion object {
        private const val TAG = "CalendarWidget"
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val KEY_CALENDAR_DATA   = "calendar_widget_data"
        private const val KEY_BG_COLOR        = "widget_bg_color"
        private const val KEY_START_ON_MONDAY = "widget_start_on_monday"
        private const val KEY_DOW_HEADERS     = "widget_dow_headers"
        private const val KEY_HOLIDAY_DATES   = "widget_holiday_dates"

        // 5 rows x 7 cols = 35 cells
        private val DAY_ID_MAP: Array<IntArray> by lazy { arrayOf(
            intArrayOf(R.id.day_0_0, R.id.day_0_1, R.id.day_0_2, R.id.day_0_3, R.id.day_0_4, R.id.day_0_5, R.id.day_0_6),
            intArrayOf(R.id.day_1_0, R.id.day_1_1, R.id.day_1_2, R.id.day_1_3, R.id.day_1_4, R.id.day_1_5, R.id.day_1_6),
            intArrayOf(R.id.day_2_0, R.id.day_2_1, R.id.day_2_2, R.id.day_2_3, R.id.day_2_4, R.id.day_2_5, R.id.day_2_6),
            intArrayOf(R.id.day_3_0, R.id.day_3_1, R.id.day_3_2, R.id.day_3_3, R.id.day_3_4, R.id.day_3_5, R.id.day_3_6),
            intArrayOf(R.id.day_4_0, R.id.day_4_1, R.id.day_4_2, R.id.day_4_3, R.id.day_4_4, R.id.day_4_5, R.id.day_4_6),
        )}

        // Background circle ImageView ids
        private val BG_ID_MAP: Array<IntArray> by lazy { arrayOf(
            intArrayOf(R.id.bg_0_0, R.id.bg_0_1, R.id.bg_0_2, R.id.bg_0_3, R.id.bg_0_4, R.id.bg_0_5, R.id.bg_0_6),
            intArrayOf(R.id.bg_1_0, R.id.bg_1_1, R.id.bg_1_2, R.id.bg_1_3, R.id.bg_1_4, R.id.bg_1_5, R.id.bg_1_6),
            intArrayOf(R.id.bg_2_0, R.id.bg_2_1, R.id.bg_2_2, R.id.bg_2_3, R.id.bg_2_4, R.id.bg_2_5, R.id.bg_2_6),
            intArrayOf(R.id.bg_3_0, R.id.bg_3_1, R.id.bg_3_2, R.id.bg_3_3, R.id.bg_3_4, R.id.bg_3_5, R.id.bg_3_6),
            intArrayOf(R.id.bg_4_0, R.id.bg_4_1, R.id.bg_4_2, R.id.bg_4_3, R.id.bg_4_4, R.id.bg_4_5, R.id.bg_4_6),
        )}

        private val DOW_ID_MAP: IntArray by lazy { intArrayOf(
            R.id.tv_dow0, R.id.tv_dow1, R.id.tv_dow2, R.id.tv_dow3, R.id.tv_dow4, R.id.tv_dow5, R.id.tv_dow6
        )}

        private val COLOR_RED       = Color.parseColor("#FFFF4444")
        private val COLOR_BLUE      = Color.parseColor("#FF4488FF")
        private val COLOR_DIM_RED   = Color.parseColor("#66FF4444")
        private val COLOR_DIM_BLUE  = Color.parseColor("#664488FF")
        private val COLOR_DIM_WHITE = Color.parseColor("#66FFFFFF")

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            Log.d(TAG, "updateWidget id=$appWidgetId")
            val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val bgColorInt = try {
                when (val raw = prefs.all[KEY_BG_COLOR]) {
                    is Int  -> raw
                    is Long -> raw.toInt()
                    else    -> Color.BLACK
                }
            } catch (_: Exception) { Color.BLACK }

            val startOnMonday    = prefs.getBoolean(KEY_START_ON_MONDAY, false)
            val calendarDataJson = prefs.getString(KEY_CALENDAR_DATA, null)
            val dowHeadersJson   = prefs.getString(KEY_DOW_HEADERS, null)
            val holidayDatesJson = prefs.getString(KEY_HOLIDAY_DATES, null)

            // Estimate cell height from actual widget height
            val opts = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val widgetHeightDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
                .takeIf { it > 0 }
                ?: opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 120)
            val density = context.resources.displayMetrics.density
            val widgetHeightPx = (widgetHeightDp * density).toInt()
            // Subtract estimated header area (~40dp) then divide by 5 rows
            val headerPx = (40 * density).toInt()
            val cellHeightPx = ((widgetHeightPx - headerPx) / 5).coerceAtLeast((16 * density).toInt())
            val circleSizePx = (cellHeightPx * 0.92f).toInt() // ~92% of cell height, leaving small margin

            val circleBitmap = createCircleBitmap(circleSizePx)

            val views = RemoteViews(context.packageName, R.layout.calendar_widget)
            views.setColorInt(R.id.widget_root, "setBackgroundColor", bgColorInt, bgColorInt)

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = "CALENDAR_WIDGET_CLICK"
                flags  = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            views.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(
                context, appWidgetId, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))

            val holidaySet = parseHolidayDates(holidayDatesJson)
            if (calendarDataJson != null) {
                try { renderFromJson(context, views, calendarDataJson, dowHeadersJson, startOnMonday, holidaySet, circleBitmap) }
                catch (e: Exception) { Log.w(TAG, "renderFromJson failed", e); renderCurrentMonth(context, views, startOnMonday, holidaySet, circleBitmap) }
            } else {
                renderCurrentMonth(context, views, startOnMonday, holidaySet, circleBitmap)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        /**
         * Create a perfect circle bitmap at the given pixel size.
         */
        private fun createCircleBitmap(sizePx: Int): Bitmap {
            val bmp = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#80FFFFFF")
                style = Paint.Style.FILL
            }
            val r = sizePx / 2f
            canvas.drawCircle(r, r, r, paint)
            return bmp
        }

        /**
         * Today mark: show/hide the background ImageView.
         * The ImageView is match_parent×match_parent; the bitmap is sized to
         * exactly fill the cell so no scaling is needed.
         */
        private fun setTodayMark(views: RemoteViews, bgViewId: Int, isToday: Boolean, circleBitmap: Bitmap) {
            if (isToday) {
                views.setViewVisibility(bgViewId, View.VISIBLE)
                views.setImageViewBitmap(bgViewId, circleBitmap)
            } else {
                views.setViewVisibility(bgViewId, View.GONE)
            }
        }

        private fun renderFromJson(
            context: Context, views: RemoteViews, calendarDataJson: String, dowHeadersJson: String?,
            startOnMonday: Boolean, holidaySet: Set<String>, circleBitmap: Bitmap
        ) {
            val dataArray = JSONArray(calendarDataJson)
            views.setTextViewText(R.id.tv_month_year, extractMonthYear(dataArray))

            val headers = if (dowHeadersJson != null) {
                val arr = JSONArray(dowHeadersJson); Array(7) { i -> if (i < arr.length()) arr.getString(i) else "" }
            } else defaultDowHeaders(startOnMonday)
            val dowColors = buildDowColors(startOnMonday)
            for (i in 0..6) { views.setTextViewText(DOW_ID_MAP[i], headers[i]); views.setTextColor(DOW_ID_MAP[i], dowColors[i]) }

            val todayCal = Calendar.getInstance()
            val todayKey = formatDateKey(todayCal.get(Calendar.YEAR), todayCal.get(Calendar.MONTH) + 1, todayCal.get(Calendar.DAY_OF_MONTH))

            for (cellIndex in 0 until 35) {
                val row = cellIndex / 7; val col = cellIndex % 7
                val viewId = DAY_ID_MAP[row][col]
                val bgViewId = BG_ID_MAP[row][col]
                if (cellIndex < dataArray.length()) {
                    val cell = dataArray.getJSONObject(cellIndex)
                    val day        = cell.optInt("day", 0)
                    val colorType  = cell.optString("colorType", "weekday")
                    val isAdjacent = cell.optBoolean("isAdjacentMonth", false)
                    val dateStr    = cell.optString("date", "")
                    val dayText    = if (day > 0) day.toString() else ""

                    val effectiveColorType = if (colorType != "holiday" && !isAdjacent && dateStr.isNotEmpty()) {
                        if (holidaySet.contains(dateStr.take(10))) "holiday" else colorType
                    } else colorType

                    val isToday = !isAdjacent && dateStr.take(10) == todayKey
                    val todayTextColor = when (effectiveColorType) {
                        "sunday", "holiday" -> COLOR_RED
                        "saturday"          -> COLOR_BLUE
                        else                -> Color.BLACK
                    }
                    views.setTextViewText(viewId, dayText)
                    views.setTextColor(viewId, if (isToday) todayTextColor else resolveColor(effectiveColorType, isAdjacent))
                    setTodayMark(views, bgViewId, isToday, circleBitmap)
                } else {
                    views.setTextViewText(viewId, "")
                    setTodayMark(views, bgViewId, false, circleBitmap)
                }
            }
        }

        private fun renderCurrentMonth(context: Context, views: RemoteViews, startOnMonday: Boolean, holidaySet: Set<String>, circleBitmap: Bitmap) {
            val cal     = Calendar.getInstance()
            val year    = cal.get(Calendar.YEAR)
            val month   = cal.get(Calendar.MONTH)
            val todayDay = cal.get(Calendar.DAY_OF_MONTH)
            views.setTextViewText(R.id.tv_month_year, "${year}\u5E74 ${month + 1}\u6708")

            val headers   = defaultDowHeaders(startOnMonday)
            val dowColors = buildDowColors(startOnMonday)
            for (i in 0..6) { views.setTextViewText(DOW_ID_MAP[i], headers[i]); views.setTextColor(DOW_ID_MAP[i], dowColors[i]) }

            cal.set(year, month, 1)
            val firstDayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
            val daysInMonth    = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
            val offset = if (startOnMonday) (if (firstDayOfWeek == Calendar.SUNDAY) 6 else firstDayOfWeek - 2) else firstDayOfWeek - 1
            val prevCal = (cal.clone() as Calendar).apply { add(Calendar.MONTH, -1) }
            val prevDaysInMonth = prevCal.getActualMaximum(Calendar.DAY_OF_MONTH)
            var currentDay = 1; var nextDay = 1

            for (cellIndex in 0 until 35) {
                val row = cellIndex / 7; val col = cellIndex % 7
                val viewId = DAY_ID_MAP[row][col]
                val bgViewId = BG_ID_MAP[row][col]
                when {
                    cellIndex < offset -> {
                        val prevDay = prevDaysInMonth - (offset - 1 - cellIndex)
                        val dow = getDayOfWeek(prevCal.get(Calendar.YEAR), prevCal.get(Calendar.MONTH), prevDay)
                        views.setTextViewText(viewId, prevDay.toString())
                        views.setTextColor(viewId, dimColorForDow(dow))
                        setTodayMark(views, bgViewId, false, circleBitmap)
                    }
                    currentDay <= daysInMonth -> {
                        val dow      = getDayOfWeek(year, month, currentDay)
                        val dateKey  = formatDateKey(year, month + 1, currentDay)
                        val isHoliday = holidaySet.contains(dateKey)
                        val isToday  = currentDay == todayDay
                        val normalColor = if (isHoliday) COLOR_RED else brightColorForDow(dow)
                        val todayTextColor = when {
                            isHoliday                -> COLOR_RED
                            dow == Calendar.SUNDAY   -> COLOR_RED
                            dow == Calendar.SATURDAY -> COLOR_BLUE
                            else                     -> Color.BLACK
                        }
                        views.setTextViewText(viewId, currentDay.toString())
                        views.setTextColor(viewId, if (isToday) todayTextColor else normalColor)
                        setTodayMark(views, bgViewId, isToday, circleBitmap)
                        currentDay++
                    }
                    else -> {
                        val dow = getDayOfWeek(year, month + 1, nextDay)
                        views.setTextViewText(viewId, nextDay.toString())
                        views.setTextColor(viewId, dimColorForDow(dow))
                        setTodayMark(views, bgViewId, false, circleBitmap)
                        nextDay++
                    }
                }
            }
        }

        // helpers
        private fun getDayOfWeek(year: Int, month: Int, day: Int): Int =
            Calendar.getInstance().apply { set(year, month, day) }.get(Calendar.DAY_OF_WEEK)
        private fun brightColorForDow(dow: Int) = when (dow) { Calendar.SUNDAY -> COLOR_RED; Calendar.SATURDAY -> COLOR_BLUE; else -> Color.WHITE }
        private fun dimColorForDow(dow: Int) = when (dow) { Calendar.SUNDAY -> COLOR_DIM_RED; Calendar.SATURDAY -> COLOR_DIM_BLUE; else -> COLOR_DIM_WHITE }
        private fun resolveColor(colorType: String, isAdjacent: Boolean): Int = if (isAdjacent) {
            when (colorType) { "sunday", "holiday" -> COLOR_DIM_RED; "saturday" -> COLOR_DIM_BLUE; else -> COLOR_DIM_WHITE }
        } else {
            when (colorType) { "sunday", "holiday" -> COLOR_RED; "saturday" -> COLOR_BLUE; else -> Color.WHITE }
        }
        private fun defaultDowHeaders(startOnMonday: Boolean) =
            if (startOnMonday) arrayOf("\u6708","\u706B","\u6C34","\u6728","\u91D1","\u571F","\u65E5") else arrayOf("\u65E5","\u6708","\u706B","\u6C34","\u6728","\u91D1","\u571F")
        private fun buildDowColors(startOnMonday: Boolean): IntArray =
            if (startOnMonday) intArrayOf(Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, COLOR_BLUE, COLOR_RED)
            else intArrayOf(COLOR_RED, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, COLOR_BLUE)
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
        private fun formatMonthYear(dateStr: String): String = try {
            val cal = Calendar.getInstance().apply { time = SimpleDateFormat("yyyy-MM-dd", Locale.JAPAN).parse(dateStr)!! }
            "${cal.get(Calendar.YEAR)}\u5E74 ${cal.get(Calendar.MONTH) + 1}\u6708"
        } catch (_: Exception) { dateStr }
        private fun parseHolidayDates(json: String?): Set<String> {
            if (json == null) return emptySet()
            return try { val arr = JSONArray(json); (0 until arr.length()).map { arr.getString(it) }.toSet() }
            catch (_: Exception) { emptySet() }
        }
        private fun formatDateKey(year: Int, month: Int, day: Int): String = "%04d-%02d-%02d".format(year, month, day)
    }
}
