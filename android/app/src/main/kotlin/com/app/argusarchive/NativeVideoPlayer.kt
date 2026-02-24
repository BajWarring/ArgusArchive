package com.app.argusarchive

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.Context
import android.content.ContextWrapper
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Rational
import android.view.View
import android.view.WindowManager
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.SeekParameters
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
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

    init {
        trackSelector = DefaultTrackSelector(context)
        
        // Premium Decoder Setup (Hardware + FFmpeg Extension Priority)
        val renderersFactory = DefaultRenderersFactory(context)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)

        // Aggressive buffering for instant seek
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(15000, 50000, 2500, 5000)
            .build()

        exoPlayer = ExoPlayer.Builder(context, renderersFactory)
            .setTrackSelector(trackSelector)
            .setLoadControl(loadControl)
            .build()

        exoPlayer.setSeekParameters(SeekParameters.CLOSEST_SYNC)
        playerView.player = exoPlayer
        playerView.useController = false

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

        val path = creationParams?.get("path") as? String
        if (path != null) {
            exoPlayer.setMediaItem(MediaItem.fromUri(path))
            exoPlayer.prepare()
            exoPlayer.playWhenReady = true
        }
    }

    private fun setupPlayerListeners() {
        exoPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                val stateStr = when (state) {
                    Player.STATE_IDLE -> "idle"
                    Player.STATE_BUFFERING -> "buffering"
                    Player.STATE_READY -> "ready"
                    Player.STATE_ENDED -> "ended"
                    else -> "unknown"
                }
                eventSink?.success(mapOf("event" to "state", "state" to stateStr))
            }
            
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                eventSink?.success(mapOf("event" to "isPlaying", "isPlaying" to isPlaying))
            }

            override fun onTracksChanged(tracks: androidx.media3.common.Tracks) {
                // Broadcast available tracks to Flutter
                val audioTracks = mutableListOf<Map<String, Any>>()
                val subTracks = mutableListOf<Map<String, Any>>()
                
                for (group in tracks.groups) {
                    for (i in 0 until group.length) {
                        val format = group.getTrackFormat(i)
                        val isSelected = group.isTrackSelected(i)
                        val trackMap = mapOf(
                            "id" to "${group.mediaTrackGroup.hashCode()}_$i",
                            "language" to (format.language ?: "Unknown"),
                            "label" to (format.label ?: "Track ${i+1}"),
                            "selected" to isSelected,
                            "groupIndex" to tracks.groups.indexOf(group),
                            "trackIndex" to i
                        )
                        if (group.type == C.TRACK_TYPE_AUDIO) audioTracks.add(trackMap)
                        if (group.type == C.TRACK_TYPE_TEXT) subTracks.add(trackMap)
                    }
                }
                eventSink?.success(mapOf("event" to "tracks", "audio" to audioTracks, "subs" to subTracks))
            }

            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                eventSink?.success(mapOf("event" to "error", "message" to error.message))
            }
        })
    }

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> { exoPlayer.play(); result.success(null) }
            "pause" -> { exoPlayer.pause(); result.success(null) }
            "seekTo" -> {
                val pos = call.argument<Number>("position")?.toLong() ?: 0L
                exoPlayer.seekTo(pos)
                result.success(null)
            }
            "setSpeed" -> {
                val speed = call.argument<Number>("speed")?.toFloat() ?: 1.0f
                exoPlayer.setPlaybackSpeed(speed)
                result.success(null)
            }
            "selectTrack" -> {
                val groupIndex = call.argument<Int>("groupIndex") ?: return
                val trackIndex = call.argument<Int>("trackIndex") ?: return
                val isAudio = call.argument<Boolean>("isAudio") ?: true
                
                val type = if (isAudio) C.TRACK_TYPE_AUDIO else C.TRACK_TYPE_TEXT
                trackSelector.parameters = trackSelector.parameters.buildUpon()
                    .clearOverridesOfType(type)
                    .addOverride(TrackSelectionOverride(exoPlayer.currentTracks.groups[groupIndex].mediaTrackGroup, trackIndex))
                    .build()
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
                    val activity = getActivity()
                    val params = PictureInPictureParams.Builder()
                        .setAspectRatio(Rational(16, 9))
                        .build()
                    activity?.enterPictureInPictureMode(params)
                }
                result.success(null)
            }
            "setBrightness" -> {
                val brightness = call.argument<Double>("brightness")?.toFloat() ?: 0.5f
                val window = getActivity()?.window
                val layoutParams = window?.attributes
                layoutParams?.screenBrightness = brightness
                window?.attributes = layoutParams
                result.success(null)
            }
            "setVolume" -> {
                val vol = call.argument<Double>("volume") ?: 0.5
                val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, (vol * max).toInt(), 0)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun getActivity(): Activity? {
        var ctx = context
        while (ctx is ContextWrapper) {
            if (ctx is Activity) return ctx
            ctx = ctx.baseContext
        }
        return null
    }

    private fun startProgressTimer() {
        handler.post(object : Runnable {
            override fun run() {
                if (eventSink != null) {
                    eventSink?.success(mapOf(
                        "event" to "progress",
                        "position" to exoPlayer.currentPosition,
                        "duration" to exoPlayer.duration,
                        "buffered" to exoPlayer.bufferedPosition
                    ))
                    handler.postDelayed(this, 250) // High refresh rate for smooth slider
                }
            }
        })
    }

    override fun getView(): View = playerView
    override fun dispose() {
        handler.removeCallbacksAndMessages(null)
        exoPlayer.release()
    }
}
