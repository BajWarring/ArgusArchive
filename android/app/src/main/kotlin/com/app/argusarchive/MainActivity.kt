package com.app.argusarchive

import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Icon
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    private val APK_CHANNEL = "com.app.argusarchive/apk_icon"
    private val SHORTCUT_CHANNEL = "com.app.argusarchive/shortcuts"
    private val MEDIA_CHANNEL = "com.app.argusarchive/media_utils" // NEW THUMBNAIL CHANNEL
    private var flutterChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupDynamicShortcuts()
    }

    private fun setupDynamicShortcuts() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            val shortcutManager = getSystemService(ShortcutManager::class.java)
            if (shortcutManager != null) {
                val shortcutIntent = Intent(this, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    putExtra("route", "/video_library")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                }
                val dynamicShortcut = ShortcutInfo.Builder(this, "video_library_dynamic")
                    .setShortLabel("Video Player")
                    .setLongLabel("Open Video Player")
                    .setIcon(Icon.createWithResource(this, R.drawable.ic_launcher_video))
                    .setIntent(shortcutIntent)
                    .build()
                shortcutManager.dynamicShortcuts = listOf(dynamicShortcut)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHORTCUT_CHANNEL)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.app.argusarchive/video_player",
            VideoPlayerViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APK_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getApkIcon") {
                val path = call.argument<String>("path")
                if (path != null) {
                    result.success(getApkIconBytes(path))
                } else {
                    result.error("INVALID_ARGUMENT", "Path cannot be null.", null)
                }
            } else {
                result.notImplemented()
            }
        }

        flutterChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "createVideoPlayerShortcut" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val shortcutManager = context.getSystemService(ShortcutManager::class.java)
                        if (shortcutManager != null && shortcutManager.isRequestPinShortcutSupported) {
                            val shortcutIntent = Intent(context, MainActivity::class.java).apply {
                                action = Intent.ACTION_VIEW
                                putExtra("route", "/video_library")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                            }
                            val pinShortcutInfo = ShortcutInfo.Builder(context, "video_library_pinned")
                                .setShortLabel("Video Player")
                                .setIcon(Icon.createWithResource(context, R.drawable.ic_launcher_video))
                                .setIntent(shortcutIntent)
                                .build()
                            shortcutManager.requestPinShortcut(pinShortcutInfo, null)
                            result.success(true)
                        } else { result.success(false) }
                    } else { result.success(false) }
                }
                "getInitialRoute" -> {
                    result.success(intent?.getStringExtra("route"))
                }
                else -> result.notImplemented()
            }
        }

        // ==========================================
        // FAST NATIVE VIDEO THUMBNAILS
        // ==========================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getVideoThumbnail") {
                val path = call.argument<String>("path")
                if (path != null) {
                    Thread {
                        try {
                            val retriever = MediaMetadataRetriever()
                            retriever.setDataSource(path)
                            // Pulls a frame 2 seconds in to avoid black starting frames
                            val bitmap = retriever.getFrameAtTime(2000000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                                ?: retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                            retriever.release()
                            
                            if (bitmap != null) {
                                val ratio = bitmap.width.toFloat() / bitmap.height.toFloat()
                                val width = 400 // Slightly higher resolution for library grids
                                val height = (width / ratio).toInt()
                                val scaled = Bitmap.createScaledBitmap(bitmap, width, height, true)
                                
                                val stream = ByteArrayOutputStream()
                                scaled.compress(Bitmap.CompressFormat.JPEG, 70, stream)
                                val bytes = stream.toByteArray()
                                Handler(Looper.getMainLooper()).post { result.success(bytes) }
                            } else {
                                Handler(Looper.getMainLooper()).post { result.success(null) }
                            }
                        } catch (e: Exception) {
                            Handler(Looper.getMainLooper()).post { result.success(null) }
                        }
                    }.start()
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        this.intent = intent 
        val route = intent.getStringExtra("route")
        if (route != null) {
            flutterChannel?.invokeMethod("onRouteChanged", route)
        }
    }

    private fun getApkIconBytes(apkPath: String): ByteArray? {
        return try {
            val pm: PackageManager = context.packageManager
            val packageInfo = pm.getPackageArchiveInfo(apkPath, 0)
            val appInfo = packageInfo?.applicationInfo
            appInfo?.sourceDir = apkPath
            appInfo?.publicSourceDir = apkPath
            
            val icon = appInfo?.loadIcon(pm)
            if (icon != null) {
                val bitmap = if (icon is BitmapDrawable) {
                    icon.bitmap
                } else {
                    val bit = Bitmap.createBitmap(icon.intrinsicWidth.coerceAtLeast(1), icon.intrinsicHeight.coerceAtLeast(1), Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bit)
                    icon.setBounds(0, 0, canvas.width, canvas.height)
                    icon.draw(canvas)
                    bit
                }
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                stream.toByteArray()
            } else { null }
        } catch (e: Exception) { null }
    }
}
