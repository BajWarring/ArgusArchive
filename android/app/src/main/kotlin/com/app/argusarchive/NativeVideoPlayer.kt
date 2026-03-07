package com.app.argusarchive

import android.app.Activity
import android.app.ActivityManager
import android.app.PictureInPictureParams
import android.content.Context
import android.content.ContextWrapper
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Rational
import android.view.View
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.SeekParameters
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

class NativeVideoPlayer(
    private val context: Context,
    viewId: Int,
    creationParams: Map<String?, Any?>?,
    messenger: BinaryMessenger
) : PlatformView, MethodChannel.MethodCallHandler {

    private val playerView: PlayerView = PlayerView(context)
    private val exoPlayer: ExoPlayer
    private val trackSelector: DefaultTrackSelector

    private val methodChannel: MethodChannel
    private val eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    // ── Device memory tier detection ──────────────────────────────────────────
    private val isLowEndDevice: Boolean by lazy {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memInfo)
        val totalRamMb = memInfo.totalMem / (1024 * 1024)
        totalRamMb < 3000 // Under 3GB RAM = low/mid range
    }

    init {
        trackSelector = DefaultTrackSelector(context).apply {
            // Adaptive resolution cap for low-end devices
            if (isLowEndDevice) {
                parameters = buildUponParameters()
                    .setMaxVideoSizeSd() // Cap at SD for smooth playback
                    .build()
            }
        }

        // Decoder priority: prefer hardware, fall back to software (FFmpeg) if needed
        val renderersFactory = DefaultRenderersFactory(context).apply {
            // PREFER mode tries hardware first, then FFmpeg extension, then software
            setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
        }

        // ── Adaptive buffering based on device tier ───────────────────────────
        val loadControl = if (isLowEndDevice) {
            // Low/mid range: smaller buffer to save RAM, faster start
            DefaultLoadControl.Builder()
                .setBufferDurationsMs(
                    /* minBufferMs   */ 8_000,
                    /* maxBufferMs   */ 25_000,
                    /* bufferForPlaybackMs             */ 1_500,
                    /* bufferForPlaybackAfterRebufferMs */ 3_000
                )
                .setTargetBufferBytes(8 * 1024 * 1024) // 8 MB cap
                .build()
        } else {
            // Higher-end: more aggressive pre-buffering for smooth experience
            DefaultLoadControl.Builder()
                .setBufferDurationsMs(15_000, 50_000, 2_500, 5_000)
                .setTargetBufferBytes(24 * 1024 * 1024) // 24 MB
                .build()
        }

        exoPlayer = ExoPlayer.Builder(context, renderersFactory)
            .setTrackSelector(trackSelector)
            .setLoadControl(loadControl)
            .build()

        // CLOSEST_SYNC = fast seek on low-end, EXACT can be slow
        exoPlayer.setSeekParameters(SeekParameters.CLOSEST_SYNC)

        playerView.player = exoPlayer
        playerView.useController = false
        playerView.keepScreenOn = true

        // ── Channels ─────────────────────────────────────────────────────────
        methodChannel = MethodChannel(messenger, "com.app.argusarchive/video_player_$viewId")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(messenger, "com.app.argusarchive/video_events_$viewId")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                startProgressTimer()
            }
            override fun onCancel(arguments: Any?) { eventSink = null }
        })

        setupPlayerListeners()

        // ── Auto-play on creation ─────────────────────────────────────────────
        val path = creationParams?.get("path") as? String
        if (path != null) {
            exoPlayer.setMediaItem(MediaItem.fromUri(path))
            exoPlayer.prepare()
            exoPlayer.playWhenReady = true
        }
    }

    // ── Player event listeners ────────────────────────────────────────────────
    private fun setupPlayerListeners() {
        exoPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                val s = when (state) {
                    Player.STATE_IDLE      -> "idle"
                    Player.STATE_BUFFERING -> "buffering"
                    Player.STATE_READY     -> "ready"
                    Player.STATE_ENDED     -> "ended"
                    else -> "unknown"
                }
                eventSink?.success(mapOf("event" to "state", "state" to s))
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                eventSink?.success(mapOf("event" to "isPlaying", "isPlaying" to isPlaying))
            }

            override fun onTracksChanged(tracks: androidx.media3.common.Tracks) {
                val audioTracks = mutableListOf<Map<String, Any>>()
                val subTracks   = mutableListOf<Map<String, Any>>()

                for (group in tracks.groups) {
                    for (i in 0 until group.length) {
                        val format     = group.getTrackFormat(i)
                        val isSelected = group.isTrackSelected(i)
                        val trackMap   = mapOf(
                            "id"         to "${group.mediaTrackGroup.hashCode()}_$i",
                            "language"   to (format.language ?: "Unknown"),
                            "label"      to (format.label ?: "Track ${i + 1}"),
                            "selected"   to isSelected,
                            "groupIndex" to tracks.groups.indexOf(group),
                            "trackIndex" to i
                        )
                        when (group.type) {
                            C.TRACK_TYPE_AUDIO -> audioTracks.add(trackMap)
                            C.TRACK_TYPE_TEXT  -> subTracks.add(trackMap)
                        }
                    }
                }
                eventSink?.success(mapOf(
                    "event" to "tracks",
                    "audio" to audioTracks,
                    "subs"  to subTracks
                ))
            }

            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                eventSink?.success(mapOf("event" to "error", "message" to (error.message ?: "Playback error")))
            }
        })
    }

    // ── Method call handler ───────────────────────────────────────────────────
    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play"  -> { exoPlayer.play(); result.success(null) }
            "pause" -> { exoPlayer.pause(); result.success(null) }

            "seekTo" -> {
                val pos = call.argument<Number>("position")?.toLong() ?: 0L
                exoPlayer.seekTo(pos)
                result.success(null)
            }

            "setSpeed" -> {
                val speed = call.argument<Number>("speed")?.toFloat()?.coerceIn(0.25f, 4.0f) ?: 1.0f
                exoPlayer.setPlaybackSpeed(speed)
                result.success(null)
            }

            "selectTrack" -> {
                val groupIndex = call.argument<Int>("groupIndex") ?: run { result.success(null); return }
                val trackIndex = call.argument<Int>("trackIndex") ?: run { result.success(null); return }
                val isAudio    = call.argument<Boolean>("isAudio") ?: true
                val type       = if (isAudio) C.TRACK_TYPE_AUDIO else C.TRACK_TYPE_TEXT

                try {
                    trackSelector.parameters = trackSelector.parameters.buildUpon()
                        .clearOverridesOfType(type)
                        .addOverride(
                            TrackSelectionOverride(
                                exoPlayer.currentTracks.groups[groupIndex].mediaTrackGroup,
                                trackIndex
                            )
                        )
                        .build()
                } catch (e: Exception) { /* group index may be stale, ignore */ }
                result.success(null)
            }

            "disableSubtitles" -> {
                trackSelector.parameters = trackSelector.parameters.buildUpon()
                    .setIgnoredTextSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                    .clearOverridesOfType(C.TRACK_TYPE_TEXT)
                    .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
                    .build()
                result.success(null)
            }

            "enterPiP" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    getActivity()?.let { activity ->
                        val params = PictureInPictureParams.Builder()
                            .setAspectRatio(Rational(16, 9))
                            .build()
                        activity.enterPictureInPictureMode(params)
                    }
                }
                result.success(null)
            }

            "setBrightness" -> {
                val brightness = call.argument<Double>("brightness")?.toFloat()?.coerceIn(0.01f, 1.0f) ?: 0.5f
                val window = getActivity()?.window
                val lp = window?.attributes
                lp?.screenBrightness = brightness
                window?.attributes = lp
                result.success(null)
            }

            "setVolume" -> {
                val vol = call.argument<Double>("volume")?.coerceIn(0.0, 1.0) ?: 0.5
                val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, (vol * max).toInt(), 0)
                result.success(null)
            }

            "setAspectRatio" -> {
                val mode = call.argument<Int>("mode") ?: 0
                playerView.resizeMode = when (mode) {
                    1    -> AspectRatioFrameLayout.RESIZE_MODE_FILL // Fill/Stretch
                    2    -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM // Crop
                    else -> AspectRatioFrameLayout.RESIZE_MODE_FIT  // Fit (default)
                }
                result.success(null)
            }

            "setSubtitleDelay" -> {
                // Placeholder: subtitle delay pipeline hook for future SRT parser
                // val delayMs = call.argument<Int>("delayMs") ?: 0
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    // ── Progress timer ────────────────────────────────────────────────────────
    // Refresh rate: 33ms on low-end (30fps), 16ms on high-end (60fps) for smoother slider
    private val progressIntervalMs: Long get() = if (isLowEndDevice) 33L else 16L

    private fun startProgressTimer() {
        handler.post(object : Runnable {
            override fun run() {
                if (eventSink != null) {
                    eventSink?.success(mapOf(
                        "event"    to "progress",
                        "position" to exoPlayer.currentPosition,
                        "duration" to exoPlayer.duration,
                        "buffered" to exoPlayer.bufferedPosition
                    ))
                    handler.postDelayed(this, progressIntervalMs)
                }
            }
        })
    }

    // ── Activity helper ───────────────────────────────────────────────────────
    private fun getActivity(): Activity? {
        var ctx = context
        while (ctx is ContextWrapper) {
            if (ctx is Activity) return ctx
            ctx = ctx.baseContext
        }
        return null
    }

    override fun getView(): View = playerView

    override fun dispose() {
        handler.removeCallbacksAndMessages(null)
        exoPlayer.release()
        playerView.player = null
    }
}
