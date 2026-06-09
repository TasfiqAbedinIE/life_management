package com.example.task_management_app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.toBitmap
import java.util.Calendar

object HabitReminderScheduler {
    const val DEFAULT_START_MINUTES = 11 * 60
    const val DEFAULT_INTERVAL_HOURS = 8

    private const val prefsName = "FlutterSharedPreferences"
    private const val enabledKey = "flutter.habit_notifications_enabled"
    private const val startMinutesKey = "flutter.habit_notifications_start_minutes"
    private const val intervalHoursKey = "flutter.habit_notifications_interval_hours"
    private const val nextTriggerAtKey = "habit_notifications_next_trigger_at"

    private const val channelId = "habit_record_reminders"
    private const val channelName = "Habit reminders"
    private const val channelDescription = "Offline reminders for recording today's habit progress."

    private const val notificationId = 4107
    private const val requestCode = 4107

    const val EXTRA_TRIGGER_AT = "trigger_at"
    const val EXTRA_DESTINATION = "destination"
    const val DESTINATION_HABITS = "habits"
    const val DESTINATION_COUPLED = "coupled"

    fun configure(context: Context, enabled: Boolean, startMinutes: Int, intervalHours: Int) {
        saveSettings(context, enabled, startMinutes, intervalHours)
        if (enabled) {
            scheduleNext(context)
        } else {
            cancel(context)
        }
    }

    fun scheduleNext(context: Context, fromTimeMillis: Long = System.currentTimeMillis()) {
        val settings = readSettings(context)
        if (!settings.enabled) {
            cancel(context)
            return
        }

        val nextTriggerAt = computeNextTriggerAt(
            nowMillis = fromTimeMillis,
            startMinutes = settings.startMinutes,
            intervalHours = settings.intervalHours
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = reminderPendingIntent(context, nextTriggerAt)

        alarmManager.cancel(pendingIntent)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                nextTriggerAt,
                pendingIntent
            )
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                nextTriggerAt,
                pendingIntent
            )
        }

        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .edit()
            .putLong(nextTriggerAtKey, nextTriggerAt)
            .apply()
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val existingTrigger = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .getLong(nextTriggerAtKey, 0L)

        alarmManager.cancel(reminderPendingIntent(context, existingTrigger))
        NotificationManagerCompat.from(context).cancel(notificationId)

        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .edit()
            .remove(nextTriggerAtKey)
            .apply()
    }

    fun showReminderNotification(context: Context) {
        val settings = readSettings(context)
        if (!settings.enabled) {
            cancel(context)
            return
        }

        createNotificationChannel(context)

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_DESTINATION, DESTINATION_HABITS)
        }

        val openPendingIntent = PendingIntent.getActivity(
            context,
            requestCode + 1,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val largeIcon = ContextCompat.getDrawable(context, R.mipmap.ic_launcher)?.toBitmap()

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setLargeIcon(largeIcon)
            .setColor(ContextCompat.getColor(context, android.R.color.holo_blue_light))
            .setContentTitle("Today's habit check-in")
            .setContentText("Keep the streak moving. Record today's habit progress now.")
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    "Keep the streak moving. Open Habits and record today's progress while it is still fresh."
                )
            )
            .setSubText("Habit reminder")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(openPendingIntent)
            .addAction(
                R.mipmap.ic_launcher,
                "Open habits",
                openPendingIntent
            )
            .build()

        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }

    private fun saveSettings(context: Context, enabled: Boolean, startMinutes: Int, intervalHours: Int) {
        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(enabledKey, enabled)
            .putInt(startMinutesKey, startMinutes)
            .putInt(intervalHoursKey, intervalHours.coerceIn(1, 24))
            .apply()
    }

    private fun readSettings(context: Context): ReminderSettings {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        return ReminderSettings(
            enabled = prefs.getBoolean(enabledKey, false),
            startMinutes = prefs.getInt(startMinutesKey, DEFAULT_START_MINUTES),
            intervalHours = prefs.getInt(intervalHoursKey, DEFAULT_INTERVAL_HOURS).coerceIn(1, 24)
        )
    }

    private fun reminderPendingIntent(context: Context, triggerAt: Long): PendingIntent {
        val reminderIntent = Intent(context, HabitReminderReceiver::class.java).apply {
            putExtra(EXTRA_TRIGGER_AT, triggerAt)
        }

        return PendingIntent.getBroadcast(
            context,
            requestCode,
            reminderIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun computeNextTriggerAt(
        nowMillis: Long,
        startMinutes: Int,
        intervalHours: Int
    ): Long {
        val intervalMillis = intervalHours.coerceIn(1, 24) * 60L * 60L * 1000L
        val calendar = Calendar.getInstance().apply {
            timeInMillis = nowMillis
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            set(Calendar.HOUR_OF_DAY, startMinutes / 60)
            set(Calendar.MINUTE, startMinutes % 60)
        }

        var candidate = calendar.timeInMillis
        while (candidate <= nowMillis) {
            candidate += intervalMillis
        }

        return candidate
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            channelId,
            channelName,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = channelDescription
            enableVibration(true)
            setShowBadge(true)
        }

        manager.createNotificationChannel(channel)
    }

    private data class ReminderSettings(
        val enabled: Boolean,
        val startMinutes: Int,
        val intervalHours: Int
    )
}
