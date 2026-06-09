package com.example.task_management_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "task_management_app/habit_notifications"
    private val notificationPermissionRequestCode = 4108
    private var pendingLaunchDestination: String? = null
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        captureLaunchDestination()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "configureHabitNotifications" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val startMinutes = call.argument<Int>("startMinutes") ?: HabitReminderScheduler.DEFAULT_START_MINUTES
                    val intervalHours = call.argument<Int>("intervalHours") ?: HabitReminderScheduler.DEFAULT_INTERVAL_HOURS

                    HabitReminderScheduler.configure(
                        context = applicationContext,
                        enabled = enabled,
                        startMinutes = startMinutes,
                        intervalHours = intervalHours
                    )
                    result.success(null)
                }

                "showCouplePillNotification" -> {
                    val title = call.argument<String>("title") ?: "New love pill"
                    val message = call.argument<String>("message") ?: "Open Coupled to read it."
                    CouplePillNotifier.showNotification(
                        context = applicationContext,
                        title = title,
                        message = message
                    )
                    result.success(null)
                }

                "areNotificationsAllowed" -> {
                    result.success(areNotificationsAllowed())
                }

                "requestNotificationPermission" -> {
                    requestNotificationPermission(result)
                }

                "consumeLaunchDestination" -> {
                    result.success(pendingLaunchDestination)
                    pendingLaunchDestination = null
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureLaunchDestination()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != notificationPermissionRequestCode) {
            return
        }

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        permissionResult?.success(granted)
        permissionResult = null
    }

    private fun captureLaunchDestination() {
        val destination = intent?.getStringExtra(HabitReminderScheduler.EXTRA_DESTINATION)
        if (
            destination == HabitReminderScheduler.DESTINATION_HABITS ||
            destination == HabitReminderScheduler.DESTINATION_COUPLED
        ) {
            pendingLaunchDestination = destination
        }
    }

    private fun areNotificationsAllowed(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }

        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        if (areNotificationsAllowed()) {
            result.success(true)
            return
        }

        permissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequestCode
        )
    }
}
