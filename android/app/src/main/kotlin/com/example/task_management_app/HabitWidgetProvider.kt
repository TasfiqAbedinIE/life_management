package com.example.task_management_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class HabitWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.habit_widget)
            bindHeader(context, views, widgetData)
            bindEmptyState(views, widgetData)
            bindRow(
                context = context,
                views = views,
                widgetData = widgetData,
                index = 0,
                rowLayoutId = R.id.habit_row_0,
                accentId = R.id.habit_row_0_accent,
                nameId = R.id.habit_row_0_name,
                progressId = R.id.habit_row_0_progress,
                countId = R.id.habit_row_0_count,
                minusId = R.id.habit_row_0_minus,
                plusId = R.id.habit_row_0_plus,
            )
            bindRow(
                context = context,
                views = views,
                widgetData = widgetData,
                index = 1,
                rowLayoutId = R.id.habit_row_1,
                accentId = R.id.habit_row_1_accent,
                nameId = R.id.habit_row_1_name,
                progressId = R.id.habit_row_1_progress,
                countId = R.id.habit_row_1_count,
                minusId = R.id.habit_row_1_minus,
                plusId = R.id.habit_row_1_plus,
            )
            bindRow(
                context = context,
                views = views,
                widgetData = widgetData,
                index = 2,
                rowLayoutId = R.id.habit_row_2,
                accentId = R.id.habit_row_2_accent,
                nameId = R.id.habit_row_2_name,
                progressId = R.id.habit_row_2_progress,
                countId = R.id.habit_row_2_count,
                minusId = R.id.habit_row_2_minus,
                plusId = R.id.habit_row_2_plus,
            )
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun bindHeader(
        context: Context,
        views: RemoteViews,
        widgetData: SharedPreferences
    ) {
        val summary = widgetData.getString("habit_widget_summary", "No habits yet") ?: "No habits yet"
        views.setTextViewText(R.id.widget_summary, summary)

        val launchIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("wrapco://open-habits?homeWidget=1")
        )
        views.setOnClickPendingIntent(R.id.widget_root, launchIntent)
        views.setOnClickPendingIntent(R.id.widget_open_button, launchIntent)
    }

    private fun bindEmptyState(
        views: RemoteViews,
        widgetData: SharedPreferences
    ) {
        val count = widgetData.getInt("habit_widget_total", 0)
        val emptyMessage = widgetData.getString(
            "habit_widget_empty_message",
            "Create a habit to start your streak."
        ) ?: "Create a habit to start your streak."

        val isEmpty = count == 0
        views.setViewVisibility(R.id.widget_empty_state, if (isEmpty) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.widget_rows, if (isEmpty) View.GONE else View.VISIBLE)
        views.setTextViewText(R.id.widget_empty_message, emptyMessage)
    }

    private fun bindRow(
        context: Context,
        views: RemoteViews,
        widgetData: SharedPreferences,
        index: Int,
        rowLayoutId: Int,
        accentId: Int,
        nameId: Int,
        progressId: Int,
        countId: Int,
        minusId: Int,
        plusId: Int,
    ) {
        val id = widgetData.getString("habit_row_${index}_id", "") ?: ""
        val name = widgetData.getString("habit_row_${index}_name", "") ?: ""
        val done = widgetData.getInt("habit_row_${index}_done", 0)
        val target = widgetData.getInt("habit_row_${index}_target", 0)
        val enabled = widgetData.getBoolean("habit_row_${index}_enabled", true)
        val color = widgetData.getString("habit_row_${index}_color", "#6D7CFF") ?: "#6D7CFF"
        val visible = id.isNotEmpty() && target > 0

        views.setViewVisibility(rowLayoutId, if (visible) View.VISIBLE else View.GONE)
        if (!visible) return

        views.setTextViewText(nameId, name)
        views.setTextViewText(countId, "$done/$target")
        views.setProgressBar(progressId, target, done.coerceAtMost(target), false)
        views.setInt(accentId, "setBackgroundColor", parseColor(color))
        views.setBoolean(minusId, "setEnabled", enabled)
        views.setBoolean(plusId, "setEnabled", enabled)
        views.setFloat(minusId, "setAlpha", if (enabled) 1f else 0.35f)
        views.setFloat(plusId, "setAlpha", if (enabled) 1f else 0.35f)

        if (!enabled) {
            views.setOnClickPendingIntent(minusId, null)
            views.setOnClickPendingIntent(plusId, null)
            return
        }

        val decrementIntent = HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse("wrapco://habit-widget-action?action=decrement&habitId=$id")
        )
        val incrementIntent = HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse("wrapco://habit-widget-action?action=increment&habitId=$id")
        )

        views.setOnClickPendingIntent(minusId, decrementIntent)
        views.setOnClickPendingIntent(plusId, incrementIntent)
    }

    private fun parseColor(color: String): Int {
        return try {
            Color.parseColor(color)
        } catch (_: IllegalArgumentException) {
            Color.parseColor("#6D7CFF")
        }
    }
}
