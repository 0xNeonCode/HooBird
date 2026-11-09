package dev.hoobird.spike.hoobird

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.media.PlaybackParams
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var recorder: MediaRecorder? = null
    private var player: MediaPlayer? = null
    private var events: EventChannel.EventSink? = null
    private var permissionResult: MethodChannel.Result? = null
    private var startedAt: Long = 0
    private val handler = Handler(Looper.getMainLooper())
    private val tick =
        object : Runnable {
            override fun run() {
                val recording = recorder
                val playing = player
                if (recording != null) {
                    events?.success(
                        mapOf(
                            "kind" to "recording",
                            "elapsedMs" to (System.currentTimeMillis() - startedAt),
                        ),
                    )
                    handler.postDelayed(this, 200)
                } else if (playing != null && playing.isPlaying) {
                    events?.success(
                        mapOf(
                            "kind" to "playback",
                            "positionMs" to playing.currentPosition,
                            "durationMs" to playing.duration,
                            "completed" to false,
                        ),
                    )
                    handler.postDelayed(this, 200)
                }
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        EventChannel(messenger, "dev.hoobird.spike.hoobird/voice_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    events = sink
                }

                override fun onCancel(arguments: Any?) {
                    events = null
                }
            },
        )
        MethodChannel(messenger, "dev.hoobird.spike.hoobird/voice").setMethodCallHandler { call, result ->
            when (call.method) {
                "permission" -> requestMic(result)
                "openSettings" -> {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                    result.success(null)
                }
                "start" -> startRecording(call.argument<String>("path"), result)
                "stop" -> stopRecording(result)
                "play" -> play(call.argument<String>("path"), call.argument<Double>("speed") ?: 1.0, result)
                "pause" -> {
                    player?.pause()
                    handler.removeCallbacks(tick)
                    result.success(null)
                }
                "resume" -> {
                    player?.start()
                    handler.removeCallbacks(tick)
                    handler.post(tick)
                    result.success(null)
                }
                "speed" -> {
                    val speed = (call.argument<Double>("speed") ?: 1.0).toFloat()
                    val current = player
                    if (current != null) {
                        current.playbackParams = current.playbackParams.setSpeed(speed)
                    }
                    result.success(null)
                }
                "stopPlayback" -> {
                    stopPlayback()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestMic(result: MethodChannel.Result) {
        val granted = checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success("granted")
            return
        }
        if (permissionResult != null) {
            result.error("permission_busy", "Eine Berechtigungsfrage läuft schon.", null)
            return
        }
        permissionResult = result
        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 4101)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 4101) return
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        val askAgain = shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO)
        permissionResult?.success(if (granted) "granted" else if (askAgain) "denied" else "blocked")
        permissionResult = null
    }

    private fun startRecording(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrEmpty()) {
            result.error("record_failed", "Der Aufnahmepfad fehlt.", null)
            return
        }
        try {
            stopPlayback()
            releaseRecorder()
            val created =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    MediaRecorder(this)
                } else {
                    @Suppress("DEPRECATION")
                    MediaRecorder()
                }
            created.setAudioSource(MediaRecorder.AudioSource.MIC)
            created.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            created.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            created.setAudioChannels(1)
            created.setAudioSamplingRate(16000)
            created.setAudioEncodingBitRate(24000)
            created.setOutputFile(path)
            created.prepare()
            created.start()
            recorder = created
            startedAt = System.currentTimeMillis()
            handler.removeCallbacks(tick)
            handler.post(tick)
            result.success(null)
        } catch (exc: Exception) {
            releaseRecorder()
            result.error("record_failed", exc.message ?: "Die Aufnahme konnte nicht starten.", null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        val elapsed = System.currentTimeMillis() - startedAt
        val current = recorder
        if (current == null) {
            result.error("record_stop_failed", "Es läuft keine Aufnahme.", null)
            return
        }
        try {
            current.stop()
            current.release()
            recorder = null
            handler.removeCallbacks(tick)
            result.success(elapsed)
        } catch (exc: Exception) {
            releaseRecorder()
            result.error("record_stop_failed", exc.message ?: "Die Aufnahme konnte nicht beendet werden.", null)
        }
    }

    private fun play(path: String?, speed: Double, result: MethodChannel.Result) {
        if (path.isNullOrEmpty()) {
            result.error("play_failed", "Die Datei fehlt.", null)
            return
        }
        try {
            stopPlayback()
            val created = MediaPlayer()
            created.setDataSource(path)
            created.setOnCompletionListener { finished ->
                events?.success(
                    mapOf(
                        "kind" to "playback",
                        "positionMs" to finished.duration,
                        "durationMs" to finished.duration,
                        "completed" to true,
                    ),
                )
                handler.removeCallbacks(tick)
            }
            created.prepare()
            created.playbackParams = PlaybackParams().setSpeed(speed.toFloat())
            created.start()
            player = created
            handler.removeCallbacks(tick)
            handler.post(tick)
            result.success(created.duration)
        } catch (exc: Exception) {
            stopPlayback()
            result.error("play_failed", exc.message ?: "Die Wiedergabe ist fehlgeschlagen.", null)
        }
    }

    private fun stopPlayback() {
        handler.removeCallbacks(tick)
        val current = player ?: return
        player = null
        try {
            current.stop()
        } catch (_: Exception) {
        }
        current.release()
    }

    private fun releaseRecorder() {
        val current = recorder ?: return
        recorder = null
        try {
            current.stop()
        } catch (_: Exception) {
        }
        current.release()
    }

    override fun onDestroy() {
        releaseRecorder()
        stopPlayback()
        permissionResult?.error("permission_cancelled", "Die Aktivität wurde geschlossen.", null)
        permissionResult = null
        super.onDestroy()
    }
}
