package com.app.argusarchive // IMPORTANT: Make sure this matches your exact package name!

import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    // This channel name must exactly match the channel name in your Dart ApkIconService
    private val CHANNEL = "com.app.argusarchive/apk_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getApkIcon") {
                val path = call.argument<String>("path")
                if (path != null) {
                    val iconBytes = getApkIconBytes(path)
                    if (iconBytes != null) {
                        result.success(iconBytes)
                    } else {
                        // Pass null back so Flutter knows it safely failed and can use the fallback icon
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

    private fun getApkIconBytes(apkPath: String): ByteArray? {
        return try {
            val pm: PackageManager = context.packageManager
            val packageInfo = pm.getPackageArchiveInfo(apkPath, 0)
            
            // Safely extract applicationInfo
            val appInfo = packageInfo?.applicationInfo
            
            // The FIX: Using '?.' to satisfy Kotlin's strict null safety
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
