package com.example.pharmaflow.staff

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "pharmaflow.staff/update"
        private const val METHOD_INSTALL_APK = "installApk"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != METHOD_INSTALL_APK) {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val apkPath = call.argument<String>("path")

            if (apkPath.isNullOrBlank()) {
                result.error(
                    "INVALID_APK_PATH",
                    "APK path is required.",
                    null,
                )
                return@setMethodCallHandler
            }

            try {
                val apkFile = File(apkPath)

                if (!apkFile.exists() || !apkFile.isFile) {
                    result.error(
                        "APK_NOT_FOUND",
                        "Downloaded APK file does not exist.",
                        null,
                    )
                    return@setMethodCallHandler
                }

                val apkUri = FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.update_files",
                    apkFile,
                )

                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(
                        apkUri,
                        "application/vnd.android.package-archive",
                    )
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }

                startActivity(intent)
                result.success(true)
            } catch (error: ActivityNotFoundException) {
                result.error(
                    "INSTALLER_NOT_FOUND",
                    "Android package installer is not available.",
                    error.message,
                )
            } catch (error: Exception) {
                result.error(
                    "INSTALL_FAILED",
                    "Unable to open Android package installer.",
                    error.message,
                )
            }
        }
    }
}