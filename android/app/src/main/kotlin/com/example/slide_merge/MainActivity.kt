package com.example.slide_merge

import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val players = mutableSetOf<MediaPlayer>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "slide_merge/audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val asset = call.argument<String>("asset")
                    val volume = call.argument<Double>("volume")?.toFloat() ?: 0.7f
                    if (asset != null) playSound(asset, volume)
                    result.success(null)
                }
                "disposeAudio" -> {
                    disposeAudio()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        disposeAudio()
        super.onDestroy()
    }

    private fun playSound(asset: String, volume: Float) {
        // Bound the number of overlapping effects.
        if (players.size >= MAX_PLAYERS) return
        runCatching {
            val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
            val descriptor = assets.openFd("flutter_assets/$key")
            val player = MediaPlayer()
            try {
                player.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .build(),
                )
                player.setDataSource(
                    descriptor.fileDescriptor,
                    descriptor.startOffset,
                    descriptor.length,
                )
                player.prepare()
                player.setVolume(volume, volume)
                player.setOnCompletionListener {
                    players.remove(it)
                    it.release()
                }
                players.add(player)
                player.start()
            } catch (error: Throwable) {
                players.remove(player)
                player.release()
                throw error
            } finally {
                descriptor.close()
            }
        }
    }

    private fun disposeAudio() {
        players.toList().forEach { it.release() }
        players.clear()
    }

    private companion object {
        const val MAX_PLAYERS = 8
    }
}
