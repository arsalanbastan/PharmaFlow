package com.example.pharmaflow

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val UPDATE_CHANNEL =
            "pharmaflow/app_update"

        private const val ACTION_INSTALL_STATUS =
            "com.example.pharmaflow.APP_UPDATE_INSTALL_STATUS"

        private const val FOREGROUND_NOTIFICATION_CHANNEL =
            "pharmaflow/foreground_notification"

        private const val ORDER_NOTIFICATION_CHANNEL_ID =
            "pharmaflow_orders"

        private const val SILENT_NOTIFICATION_CHANNEL_ID =
            "pharmaflow_silent"

        private const val ACTION_OPEN_ORDER =
            "com.example.pharmaflow.OPEN_ORDER"

        private const val EXTRA_ORDER_ID =
            "pharmaflow_order_id"

        private const val EXTRA_PUSH_TYPE =
            "pharmaflow_push_type"

        private const val EXTRA_PUSH_DELIVERY_ID =
            "pharmaflow_push_delivery_id"

        private const val NOTIFICATION_COUNTER_PREFERENCES =
            "pharmaflow_notification_counters"
    }

    private var foregroundNotificationChannel: MethodChannel? = null
    private var pendingForegroundOrderId: String? = null
    private var pendingForegroundPushType: String? = null
    private var pendingForegroundPushDeliveryId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleInstallStatusIntent(intent)
        handleForegroundOrderIntent(intent, deliverToFlutter = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleInstallStatusIntent(intent)
        handleForegroundOrderIntent(intent, deliverToFlutter = true)
    }

    override fun onResume() {
        super.onResume()
        clearDisplayedPushNotifications()
    }

    private fun clearDisplayedPushNotifications() {
        val notificationManager =
            getSystemService(
                Context.NOTIFICATION_SERVICE,
            ) as NotificationManager

        notificationManager.cancelAll()

        resetNotificationCount("ORDER_CREATED")
        resetNotificationCount("CHEQUE_CREATED")
        resetNotificationCount("CASH_PAYMENT_CREATED")
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine,
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPDATE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersion" -> {
                    try {
                        result.success(readAppVersion())
                    } catch (error: Exception) {
                        result.error(
                            "VERSION_READ_FAILED",
                            error.message,
                            null,
                        )
                    }
                }

                "canRequestPackageInstalls" -> {
                    try {
                        result.success(
                            canRequestPackageInstalls(),
                        )
                    } catch (error: Exception) {
                        result.error(
                            "INSTALL_PERMISSION_CHECK_FAILED",
                            error.message,
                            null,
                        )
                    }
                }

                "openInstallPermissionSettings" -> {
                    try {
                        openInstallPermissionSettings()
                        result.success(null)
                    } catch (error: Exception) {
                        result.error(
                            "INSTALL_PERMISSION_SETTINGS_FAILED",
                            error.message,
                            null,
                        )
                    }
                }

                "installApk" -> {
                    val filePath =
                        call.argument<String>("filePath")
                            ?.trim()

                    if (filePath.isNullOrEmpty()) {
                        result.error(
                            "APK_PATH_MISSING",
                            "APK file path is required.",
                            null,
                        )

                        return@setMethodCallHandler
                    }

                    try {
                        installApk(filePath)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error(
                            "APK_INSTALL_FAILED",
                            error.message,
                            null,
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
        configureForegroundNotificationChannel(flutterEngine)
    }

    private fun configureForegroundNotificationChannel(
        flutterEngine: FlutterEngine,
    ) {
        ensureNotificationChannels(
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager,
        )

        foregroundNotificationChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                FOREGROUND_NOTIFICATION_CHANNEL,
            ).also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "showOrderNotification" -> {
                            val title =
                                call.argument<String>("title")
                                    ?.trim()
                            val body =
                                call.argument<String>("body")
                                    ?.trim()
                            val orderId =
                                call.argument<String>("orderId")
                                    ?.trim()
                            val type =
                                call.argument<String>("type")
                                    ?.trim()
                                    ?.uppercase()
                                    ?: "ORDER_CREATED"
                            val silent =
                                call.argument<Boolean>("silent") ?: false
                            val count =
                                (call.argument<Int>("count") ?: 1)
                                    .coerceAtLeast(1)
                            val deliveryId =
                                call.argument<String>("deliveryId")
                                    ?.trim()
                                    ?.takeIf { it.isNotEmpty() }

                            if (
                                title.isNullOrEmpty() ||
                                body.isNullOrEmpty() ||
                                orderId.isNullOrEmpty()
                            ) {
                                result.error(
                                    "ORDER_NOTIFICATION_ARGUMENTS_INVALID",
                                    "title, body and orderId are required.",
                                    null,
                                )

                                return@setMethodCallHandler
                            }

                            try {
                                showOrderNotification(
                                    title = title,
                                    body = body,
                                    orderId = orderId,
                                    type = type,
                                    silent = silent,
                                    count = count,
                                    deliveryId = deliveryId,
                                )
                                result.success(null)
                            } catch (error: Exception) {
                                result.error(
                                    "ORDER_NOTIFICATION_SHOW_FAILED",
                                    error.message,
                                    null,
                                )
                            }
                        }

                        "consumePendingOrderId" -> {
                            val orderId = pendingForegroundOrderId
                            val type = pendingForegroundPushType
                            val deliveryId =
                                pendingForegroundPushDeliveryId

                            pendingForegroundOrderId = null
                            pendingForegroundPushType = null
                            pendingForegroundPushDeliveryId = null

                            if (orderId == null) {
                                result.success(null)
                            } else {
                                val target =
                                    mutableMapOf<String, Any>(
                                        "type" to
                                            (type ?: "ORDER_CREATED"),
                                        "id" to orderId,
                                    )

                                if (deliveryId != null) {
                                    target["deliveryId"] = deliveryId
                                }

                                result.success(target)
                            }
                        }

                        else -> result.notImplemented()
                    }
                }
            }
    }

    private fun ensureNotificationChannels(
        notificationManager: NotificationManager,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val audibleChannel =
            NotificationChannel(
                ORDER_NOTIFICATION_CHANNEL_ID,
                "PharmaFlow Orders",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "PharmaFlow audible notifications"
                enableVibration(true)
                setShowBadge(true)
            }

        val silentChannel =
            NotificationChannel(
                SILENT_NOTIFICATION_CHANNEL_ID,
                "PharmaFlow Silent",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "PharmaFlow silent notifications"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(true)
            }

        notificationManager.createNotificationChannel(audibleChannel)
        notificationManager.createNotificationChannel(silentChannel)
    }
    private fun showOrderNotification(
        title: String,
        body: String,
        orderId: String,
        type: String,
        silent: Boolean,
        count: Int,
        deliveryId: String?,
    ) {
        val notificationManager =
            getSystemService(
                Context.NOTIFICATION_SERVICE,
            ) as NotificationManager

        ensureNotificationChannels(notificationManager)

        val notificationChannelId =
            if (silent) {
                SILENT_NOTIFICATION_CHANNEL_ID
            } else {
                ORDER_NOTIFICATION_CHANNEL_ID
            }

        val openOrderIntent =
            Intent(
                this,
                MainActivity::class.java,
            ).apply {
                action = ACTION_OPEN_ORDER
                putExtra(EXTRA_ORDER_ID, orderId)
                putExtra(EXTRA_PUSH_TYPE, type)

                if (deliveryId != null) {
                    putExtra(EXTRA_PUSH_DELIVERY_ID, deliveryId)
                }

                addFlags(
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP,
                )
            }

        var pendingIntentFlags =
            PendingIntent.FLAG_UPDATE_CURRENT

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pendingIntentFlags =
                pendingIntentFlags or PendingIntent.FLAG_IMMUTABLE
        }
        val requestCode =
            notificationIdForType(type)

        val notificationCount =
            count.coerceAtLeast(1)

        val notificationBody =
            aggregatedNotificationBody(
                type = type,
                count = notificationCount,
                fallbackBody = body,
            )

        val openOrderPendingIntent =
            PendingIntent.getActivity(
                this,
                requestCode,
                openOrderIntent,
                pendingIntentFlags,
            )

        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(
                    this,
                    notificationChannelId,
                )
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }

        @Suppress("DEPRECATION")
        val notification =
            builder
                .setSmallIcon(applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(notificationBody)
                .setNumber(notificationCount)
                .setAutoCancel(true)
                .setContentIntent(openOrderPendingIntent)
                .setCategory(Notification.CATEGORY_MESSAGE)
                .setPriority(Notification.PRIORITY_HIGH)
                .apply {
                    if (silent) {
                        setDefaults(0)
                        setSound(null)
                    } else {
                        setDefaults(Notification.DEFAULT_ALL)
                    }
                }
                .build()

        notificationManager.notify(
            requestCode,
            notification,
        )
    }

    private fun notificationIdForType(type: String): Int {
        val normalizedType = type.trim().uppercase()

        return "pharmaflow:$normalizedType".hashCode() and Int.MAX_VALUE
    }

    private fun notificationCountKey(type: String): String {
        return "count_${type.trim().uppercase()}"
    }

    private fun nextNotificationCount(
        notificationManager: NotificationManager,
        type: String,
    ): Int {
        val notificationId = notificationIdForType(type)

        val preferences =
            getSharedPreferences(
                NOTIFICATION_COUNTER_PREFERENCES,
                Context.MODE_PRIVATE,
            )

        val hasActiveNotification =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                notificationManager.activeNotifications.any {
                    it.id == notificationId
                }
            } else {
                preferences.getInt(
                    notificationCountKey(type),
                    0,
                ) > 0
            }

        val previousCount =
            if (hasActiveNotification) {
                preferences.getInt(
                    notificationCountKey(type),
                    0,
                )
            } else {
                0
            }

        val nextCount = previousCount + 1

        preferences
            .edit()
            .putInt(
                notificationCountKey(type),
                nextCount,
            )
            .apply()

        return nextCount
    }

    private fun resetNotificationCount(type: String) {
        getSharedPreferences(
            NOTIFICATION_COUNTER_PREFERENCES,
            Context.MODE_PRIVATE,
        )
            .edit()
            .remove(notificationCountKey(type))
            .apply()
    }

    private fun aggregatedNotificationBody(
        type: String,
        count: Int,
        fallbackBody: String,
    ): String {
        return when (type.trim().uppercase()) {
            "ORDER_CREATED" ->
                "شما $count سفارش جدید دارید"

            "CHEQUE_CREATED" ->
                "شما $count چک جدید دارید"

            "CASH_PAYMENT_CREATED" ->
                "شما $count واریزی جدید دارید"

            else -> fallbackBody
        }
    }
    private fun handleForegroundOrderIntent(
        source: Intent?,
        deliverToFlutter: Boolean,
    ) {
        if (source?.action != ACTION_OPEN_ORDER) {
            return
        }

        val orderId =
            source.getStringExtra(EXTRA_ORDER_ID)
                ?.trim()

        if (orderId.isNullOrEmpty()) {
            return
        }

        val type =
            source.getStringExtra(EXTRA_PUSH_TYPE)
                ?.trim()
                ?.uppercase()
                ?: "ORDER_CREATED"

        val deliveryId =
            source.getStringExtra(EXTRA_PUSH_DELIVERY_ID)
                ?.trim()
                ?.takeIf { it.isNotEmpty() }

        source.removeExtra(EXTRA_ORDER_ID)
        source.removeExtra(EXTRA_PUSH_TYPE)
        source.removeExtra(EXTRA_PUSH_DELIVERY_ID)

        pendingForegroundOrderId = orderId
        pendingForegroundPushType = type
        pendingForegroundPushDeliveryId = deliveryId

        if (!deliverToFlutter) {
            return
        }

        val channel = foregroundNotificationChannel

        if (channel != null) {
            val target =
                mutableMapOf<String, Any>(
                    "type" to type,
                    "id" to orderId,
                )

            if (deliveryId != null) {
                target["deliveryId"] = deliveryId
            }

            channel.invokeMethod(
                "orderNotificationTapped",
                target,
            )

            pendingForegroundOrderId = null
            pendingForegroundPushType = null
            pendingForegroundPushDeliveryId = null
        }
    }
    private fun readAppVersion(): Map<String, Any> {
        val packageInfo =
            if (
                Build.VERSION.SDK_INT >=
                    Build.VERSION_CODES.TIRAMISU
            ) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(
                    packageName,
                    0,
                )
            }

        val versionCode =
            if (
                Build.VERSION.SDK_INT >=
                    Build.VERSION_CODES.P
            ) {
                packageInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                packageInfo.versionCode.toLong()
            }

        return mapOf(
            "versionName" to
                (packageInfo.versionName ?: ""),
            "versionCode" to versionCode,
        )
    }

    private fun canRequestPackageInstalls(): Boolean {
        if (
            Build.VERSION.SDK_INT <
                Build.VERSION_CODES.O
        ) {
            return true
        }

        return packageManager.canRequestPackageInstalls()
    }

    private fun openInstallPermissionSettings() {
        if (
            Build.VERSION.SDK_INT <
                Build.VERSION_CODES.O
        ) {
            return
        }

        val appSettingsIntent =
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )

        if (
            appSettingsIntent.resolveActivity(
                packageManager,
            ) != null
        ) {
            startActivity(appSettingsIntent)
            return
        }

        val fallbackIntent =
            Intent(Settings.ACTION_SECURITY_SETTINGS)

        if (
            fallbackIntent.resolveActivity(
                packageManager,
            ) != null
        ) {
            startActivity(fallbackIntent)
            return
        }

        throw IllegalStateException(
            "Android installation settings are unavailable.",
        )
    }

    private fun installApk(apkPath: String) {
        val apkFile = File(apkPath)

        require(apkFile.isFile) {
            "Verified APK file does not exist."
        }

        require(apkFile.length() > 0L) {
            "Verified APK file is empty."
        }

        if (!canRequestPackageInstalls()) {
            throw SecurityException(
                "Install unknown apps permission is not granted.",
            )
        }

        @Suppress("DEPRECATION")
        val archiveInfo =
            packageManager.getPackageArchiveInfo(
                apkFile.absolutePath,
                0,
            )

        require(archiveInfo != null) {
            "Android could not read the APK package."
        }

        require(archiveInfo.packageName == packageName) {
            "APK package name does not match PharmaFlow."
        }

        val candidateVersionCode =
            if (
                Build.VERSION.SDK_INT >=
                    Build.VERSION_CODES.P
            ) {
                archiveInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                archiveInfo.versionCode.toLong()
            }

        val currentPackageInfo =
            if (
                Build.VERSION.SDK_INT >=
                    Build.VERSION_CODES.TIRAMISU
            ) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(
                    packageName,
                    0,
                )
            }

        val currentVersionCode =
            if (
                Build.VERSION.SDK_INT >=
                    Build.VERSION_CODES.P
            ) {
                currentPackageInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                currentPackageInfo.versionCode.toLong()
            }

        require(candidateVersionCode > currentVersionCode) {
            "APK version is not newer than the installed version."
        }

        val params =
            PackageInstaller.SessionParams(
                PackageInstaller.SessionParams.MODE_FULL_INSTALL,
            ).apply {
                setAppPackageName(packageName)
                setSize(apkFile.length())

                if (
                    Build.VERSION.SDK_INT >=
                        Build.VERSION_CODES.S
                ) {
                    setRequireUserAction(
                        PackageInstaller.SessionParams
                            .USER_ACTION_REQUIRED,
                    )
                }
            }

        val installer =
            packageManager.packageInstaller

        val sessionId =
            installer.createSession(params)

        var committed = false

        try {
            installer.openSession(sessionId).use { session ->
                FileInputStream(apkFile).use { input ->
                    session.openWrite(
                        "base.apk",
                        0L,
                        apkFile.length(),
                    ).use { output ->
                        input.copyTo(output)
                        session.fsync(output)
                    }
                }

                val statusIntent =
                    Intent(
                        this,
                        MainActivity::class.java,
                    ).apply {
                        action = ACTION_INSTALL_STATUS

                        putExtra(
                            PackageInstaller.EXTRA_SESSION_ID,
                            sessionId,
                        )

                        addFlags(
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP,
                        )
                    }

                var pendingIntentFlags =
                    PendingIntent.FLAG_UPDATE_CURRENT

                if (
                    Build.VERSION.SDK_INT >=
                        Build.VERSION_CODES.S
                ) {
                    pendingIntentFlags =
                        pendingIntentFlags or
                            PendingIntent.FLAG_MUTABLE
                }

                val statusPendingIntent =
                    PendingIntent.getActivity(
                        this,
                        sessionId,
                        statusIntent,
                        pendingIntentFlags,
                    )

                session.commit(
                    statusPendingIntent.intentSender,
                )

                committed = true
            }
        } catch (error: Exception) {
            if (!committed) {
                try {
                    installer.abandonSession(sessionId)
                } catch (_: Exception) {
                    // Best-effort cleanup only.
                }
            }

            throw error
        }
    }

    private fun handleInstallStatusIntent(
        statusIntent: Intent?,
    ) {
        if (
            statusIntent?.action !=
                ACTION_INSTALL_STATUS
        ) {
            return
        }

        val status =
            statusIntent.getIntExtra(
                PackageInstaller.EXTRA_STATUS,
                PackageInstaller.STATUS_FAILURE,
            )

        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirmationIntent =
                    readConfirmationIntent(statusIntent)

                if (confirmationIntent != null) {
                    startActivity(confirmationIntent)
                } else {
                    Toast.makeText(
                        this,
                        "Android installation confirmation is unavailable.",
                        Toast.LENGTH_LONG,
                    ).show()
                }
            }

            PackageInstaller.STATUS_SUCCESS -> {
                Toast.makeText(
                    this,
                    "PharmaFlow update installed successfully.",
                    Toast.LENGTH_LONG,
                ).show()
            }

            else -> {
                val message =
                    statusIntent.getStringExtra(
                        PackageInstaller.EXTRA_STATUS_MESSAGE,
                    ) ?: "Android package installation failed."

                Toast.makeText(
                    this,
                    message,
                    Toast.LENGTH_LONG,
                ).show()
            }
        }
    }

    private fun readConfirmationIntent(
        source: Intent,
    ): Intent? {
        return if (
            Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.TIRAMISU
        ) {
            source.getParcelableExtra(
                Intent.EXTRA_INTENT,
                Intent::class.java,
            )
        } else {
            @Suppress("DEPRECATION")
            source.getParcelableExtra(
                Intent.EXTRA_INTENT,
            )
        }
    }
}