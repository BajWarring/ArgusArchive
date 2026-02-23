package com.app.argusarchive

import android.content.pm.PackageInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.concurrent.thread

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.app.argusarchive/apk_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getApkIcon") {
                val path = call.argument<String>("path")
                if (path != null) {
                    // Run on background thread to prevent UI freezing
                    thread {
                        val icon = extractApkIcon(path)
                        // Return result to Flutter on the main thread
                        Handler(Looper.getMainLooper()).post {
                            if (icon != null) {
                                result.success(icon)
                            } else {
                                result.error("UNAVAILABLE", "Icon not available.", null)
                            }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "Path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun extractApkIcon(path: String): ByteArray? {
        try {
            val pm = context.packageManager
            val pi: PackageInfo? = pm.getPackageArchiveInfo(path, 0)
            if (pi != null) {
                // Point the package info to the actual file on storage
                pi.applicationInfo.sourceDir = path
                pi.applicationInfo.publicSourceDir = path
                
                val icon: Drawable = pi.applicationInfo.loadIcon(pm)
                return drawableToByteArray(icon)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            val bmp = Bitmap.createBitmap(
                if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 1,
                if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 1,
                Bitmap.Config.ARGB_8888
            )
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }
        val stream = ByteArrayOutputStream()
        // Compress as PNG and send bytes to Flutter
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }
}
