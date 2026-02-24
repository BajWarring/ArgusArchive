package com.app.argusarchive

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
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
    context: Context,
    viewId: Int,
    creationParams: Map<String?, Any?>?,
    messenger: BinaryMessenger
) : PlatformView, MethodChannel.MethodCallHandler {

    private val playerView: PlayerView = PlayerView(context)
    private val exoPlayer: ExoPlayer
    private val trackSelector = DefaultTrackSelector(context)
    
    private val methodChannel: MethodChannel
    private val eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())

    init {
        // High-performance hardware acceleration & FFmpeg hook
        val renderersFactory = DefaultRenderersFactory(context)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)

        // Tuned for fast instant-seeking
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(15000, 50000, 1500, 2000)
            .build()

        exoPlayer = ExoPlayer.Builder(context, renderersFactory)
            .setTrackSelector(trackSelector)
            .setLoadControl(loadControl)
            .build()

        exoPlayer.setSeekParameters(SeekParameters.CLOSEST_SYNC)
        
        playerView.player = exoPlayer
        playerView.useController = false // We handle UI in Flutter

        methodChannel = MethodChannel(messenger, "com.app.argusarchive/video_player_$viewId")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(messenger, "com.app.argusarchive/video_events_$viewId")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                startProgressTimer()
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        // Listen for buffering and state changes
        exoPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                eventSink?.success(mapOf("event" to "state", "state" to playbackState))
            }
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                eventSink?.success(mapOf("event" to "isPlaying", "isPlaying" to isPlaying))
            }
        })

        // Load Initial Path
        val path = creationParams?.get("path") as? String
        if (path != null) {
            val mediaItem = MediaItem.fromUri(path)
            exoPlayer.setMediaItem(mediaItem)
            exoPlayer.prepare()
            exoPlayer.playWhenReady = true
        }
    }

    override fun getView(): View = playerView

    override fun dispose() {
        handler.removeCallbacksAndMessages(null)
        exoPlayer.release()
    }

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> { exoPlayer.play(); result.success(null) }
            "pause" -> { exoPlayer.pause(); result.success(null) }
            "seekTo" -> {
                val position = call.argument<Number>("position")?.toLong() ?: 0L
                exoPlayer.seekTo(position)
                result.success(null)
            }
            "setSpeed" -> {
                val speed = call.argument<Number>("speed")?.toFloat() ?: 1.0f
                exoPlayer.setPlaybackSpeed(speed)
                result.success(null)
            }
            else -> result.notImplemented()
        }
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
                    handler.postDelayed(this, 500) // 500ms updates
                }
            }
        })
    }
}
