package com.example.task_management_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class HabitReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (
            intent?.action == Intent.ACTION_BOOT_COMPLETED ||
            intent?.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent?.action == Intent.ACTION_TIME_CHANGED ||
            intent?.action == Intent.ACTION_TIMEZONE_CHANGED
        ) {
            HabitReminderScheduler.scheduleNext(context)
        }
    }
}
