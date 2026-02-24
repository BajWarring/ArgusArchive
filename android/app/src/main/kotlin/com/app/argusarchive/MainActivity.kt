package com.app.argusarchive

import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    private val APK_CHANNEL = "com.app.argusarchive/apk_icon"
    private val SHORTCUT_CHANNEL = "com.app.argusarchive/shortcuts"
    private var flutterChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupDynamicShortcuts()
    }

    // Creates the shortcut that appears when you long-press the App Icon on the launcher
    private fun setupDynamicShortcuts() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            val shortcutManager = getSystemService(ShortcutManager::class.java)
            if (shortcutManager != null) {
                val shortcutIntent = Intent(this, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    putExtra("route", "/video_library") // Route to sub-app
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                }
                val dynamicShortcut = ShortcutInfo.Builder(this, "video_library_dynamic")
                    .setShortLabel("Video Player")
                    .setLongLabel("Open Video Player")
                    .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher)) // Uses app icon
                    .setIntent(shortcutIntent)
                    .build()
                shortcutManager.dynamicShortcuts = listOf(dynamicShortcut)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHORTCUT_CHANNEL)

        // 1. VIDEO PLAYER
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.app.argusarchive/video_player",
            VideoPlayerViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )
        
        // 2. APK ICON
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

        // 3. SHORTCUT CONTROLLER
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
                                .setIcon(Icon.createWithResource(context, R.mipmap.ic_launcher))
                                .setIntent(shortcutIntent)
                                .build()
                            shortcutManager.requestPinShortcut(pinShortcutInfo, null)
                            result.success(true)
                        } else { result.success(false) }
                    } else { result.success(false) }
                }
                "getInitialRoute" -> {
                    // Send the intent route that launched the app back to Flutter
                    result.success(intent?.getStringExtra("route"))
                }
                else -> result.notImplemented()
            }
        }
    }

    // Fires if the app is already running in the background and a shortcut is clicked
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
