package cn.thebeike.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews

class UpcomingClassWidget : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "cn.thebeike.app.widget"
        private const val KEY_DATA = "upcoming_class_data"
        private const val REFRESH_INTERVAL_MS = 5 * 60 * 1000L
        private const val ACTION_AUTO_REFRESH = "cn.thebeike.app.AUTO_REFRESH"

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = buildRemoteViews(context)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, UpcomingClassWidget::class.java)
            )
            for (widgetId in widgetIds) {
                updateWidget(context, appWidgetManager, widgetId)
            }
        }

        fun saveData(context: Context, json: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_DATA, json).apply()
        }

        fun scheduleAutoRefresh(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, UpcomingClassWidget::class.java).apply {
                action = ACTION_AUTO_REFRESH
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)

            val triggerAt = SystemClock.elapsedRealtime() + REFRESH_INTERVAL_MS

            // setAlarmClock is exempt from Doze and does not require
            // SCHEDULE_EXACT_ALARM permission on Android 12+.
            val info = AlarmManager.AlarmClockInfo(triggerAt, pendingIntent)
            alarmManager.setAlarmClock(info, pendingIntent)
        }

        fun cancelAutoRefresh(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, UpcomingClassWidget::class.java).apply {
                action = ACTION_AUTO_REFRESH
            }
            val flags = PendingIntent.FLAG_NO_CREATE or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
        }

        private fun getNoClassMessage(): String {
            val calendar = java.util.Calendar.getInstance()
            val dayOfWeek = calendar.get(java.util.Calendar.DAY_OF_WEEK)
            return if (dayOfWeek == java.util.Calendar.SATURDAY || dayOfWeek == java.util.Calendar.SUNDAY) {
                "周末愉快～"
            } else {
                "今日课毕，宜休闲玩耍"
            }
        }

        private fun buildRemoteViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_upcoming_class)
            fillContent(context, views)
            return views
        }

        private fun fillContent(context: Context, views: RemoteViews) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY_DATA, null)

            views.setInt(R.id.label_text, "setVisibility", 0x00000008) // GONE

            if (json != null) {
                try {
                    val data = org.json.JSONObject(json)
                    if (data.optBoolean("hasClass", false)) {
                        views.setInt(R.id.time_text, "setVisibility", 0x00000000)   // VISIBLE
                        views.setInt(R.id.location_text, "setVisibility", 0x00000000)
                        views.setInt(R.id.teacher_text, "setVisibility", 0x00000000)
                        views.setTextViewText(R.id.class_name_text, data.optString("className", ""))
                        views.setTextViewText(R.id.time_text, data.optString("timeRange", ""))
                        views.setTextViewText(R.id.location_text, data.optString("location", ""))
                        views.setTextViewText(R.id.teacher_text, data.optString("teacher", ""))
                        attachClickIntent(context, views)
                        return
                    }
                } catch (_: Exception) { }
            }

            views.setInt(R.id.time_text, "setVisibility", 0x00000008)      // GONE
            views.setInt(R.id.location_text, "setVisibility", 0x00000008)
            views.setInt(R.id.teacher_text, "setVisibility", 0x00000008)
            views.setTextViewText(R.id.class_name_text, getNoClassMessage())
            attachClickIntent(context, views)
        }

        private fun attachClickIntent(context: Context, views: RemoteViews) {
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (intent != null) {
                val pi = PendingIntent.getActivity(
                    context, 0, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_container, pi)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_AUTO_REFRESH -> {
                updateAllWidgets(context)
                scheduleAutoRefresh(context)
            }
        }
    }

    override fun onEnabled(context: Context) {
        scheduleAutoRefresh(context)
    }

    override fun onDisabled(context: Context) {
        cancelAutoRefresh(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().clear().apply()
    }
}
