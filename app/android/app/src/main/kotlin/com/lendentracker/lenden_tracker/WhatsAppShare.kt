package com.lendentracker.lenden_tracker

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

internal class WhatsAppShare(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val packages = listOf("com.whatsapp", "com.whatsapp.w4b")

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "availability" -> result.success(availability())
            "shareImage" -> {
                val image = call.argument<ByteArray>("image")
                val text = call.argument<String>("text")
                if (image == null || image.isEmpty() || text == null) {
                    result.error("invalid_args", "Reminder image and caption are required", null)
                    return
                }
                val target = packages.firstOrNull { handlesImage(it) }
                if (target == null) {
                    result.success(false)
                    return
                }
                try {
                    val directory = File(activity.cacheDir, "share_plus").apply { mkdirs() }
                    val file = File(directory, "whatsapp_reminder_${System.nanoTime()}.png")
                    file.writeBytes(image)
                    val uri = FileProvider.getUriForFile(
                        activity, "${activity.packageName}.flutter.share_provider", file
                    )
                    val intent = imageIntent(uri, text).apply {
                        setPackage(target)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    activity.startActivity(intent)
                    result.success(true)
                } catch (_: ActivityNotFoundException) {
                    result.success(false)
                } catch (error: Exception) {
                    result.error("share_failed", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun imageIntent(uri: Uri? = null, text: String? = null) = Intent(Intent.ACTION_SEND).apply {
        type = "image/png"
        if (uri != null) putExtra(Intent.EXTRA_STREAM, uri)
        if (text != null) putExtra(Intent.EXTRA_TEXT, text)
    }

    private fun installed(packageName: String): Boolean = try {
        if (Build.VERSION.SDK_INT >= 33) {
            activity.packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            activity.packageManager.getPackageInfo(packageName, 0)
        }
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    private fun handlesImage(packageName: String): Boolean {
        if (!installed(packageName)) return false
        val intent = imageIntent().apply { setPackage(packageName) }
        return activity.packageManager.queryIntentActivities(intent, 0).isNotEmpty()
    }

    private fun availability(): String = when {
        packages.any { handlesImage(it) } -> "available"
        packages.any { installed(it) } -> "noHandler"
        else -> "missing"
    }
}
