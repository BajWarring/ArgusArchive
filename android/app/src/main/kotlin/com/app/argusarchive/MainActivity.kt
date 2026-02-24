package com.app.argusarchive

import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    private val APK_CHANNEL = "com.app.argusarchive/apk_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // ==========================================
        // 1. VIDEO PLAYER: Register the Native ExoPlayer PlatformView
        // ==========================================
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.app.argusarchive/video_player",
            VideoPlayerViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )
        
        // ==========================================
        // 2. APK ICON: Set up the existing Method Channel
        // ==========================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APK_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getApkIcon") {
                val path = call.argument<String>("path")
                if (path != null) {
                    val iconBytes = getApkIconBytes(path)
                    if (iconBytes != null) {
                        result.success(iconBytes)
                    } else {
                        // Pass null back so Flutter knows it safely failed and uses the fallback icon
                        result.success(null) 
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Path cannot be null.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    // Safely extracts the APK icon using your previous null-safety fixes
    private fun getApkIconBytes(apkPath: String): ByteArray? {
        return try {
            val pm: PackageManager = context.packageManager
            val packageInfo = pm.getPackageArchiveInfo(apkPath, 0)
            
            // Safely extract applicationInfo
            val appInfo = packageInfo?.applicationInfo
            
            // Using '?.' to satisfy Kotlin's strict null safety
            appInfo?.sourceDir = apkPath
            appInfo?.publicSourceDir = apkPath
            
            val icon = appInfo?.loadIcon(pm)
            
            if (icon != null) {
                val bitmap = if (icon is BitmapDrawable) {
                    icon.bitmap
                } else {
                    val bit = Bitmap.createBitmap(
                        icon.intrinsicWidth.coerceAtLeast(1), 
                        icon.intrinsicHeight.coerceAtLeast(1), 
                        Bitmap.Config.ARGB_8888
                    )
                    val canvas = Canvas(bit)
                    icon.setBounds(0, 0, canvas.width, canvas.height)
                    icon.draw(canvas)
                    bit
                }
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                stream.toByteArray()
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }
}
