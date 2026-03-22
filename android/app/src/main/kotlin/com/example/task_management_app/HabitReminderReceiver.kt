package com.example.task_management_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class HabitReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        HabitReminderScheduler.showReminderNotification(context)
        HabitReminderScheduler.scheduleNext(context, System.currentTimeMillis() + 1000L)
    }
}
