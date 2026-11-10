package dev.hoobird.spike.hoobird

import android.Manifest
import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentValues
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.PlaybackParams
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var player: MediaPlayer? = null
    private var events: EventChannel.EventSink? = null
    private var permissionResult: MethodChannel.Result? = null
    private var lastStop: Map<String, Any> = emptyStop()
    private val handler = Handler(Looper.getMainLooper())
    private val capture by lazy {
        VoiceCapture(
            this,
            log = { priority, message ->
                if (priority >= Log.WARN) Log.w("HooBirdVoice", message) else Log.i("HooBirdVoice", message)
            },
            emit = { payload ->
                handler.post {
                    val sink = events
                    if (sink == null) {
                        Log.w("HooBirdVoice", "tick dropped, sink null")
                        return@post
                    }
                    try {
                        sink.success(payload)
                    } catch (exc: Exception) {
                        Log.w("HooBirdVoice", "tick send failed ${exc.message}")
                    }
                }
            },
        )
    }
    private val tick =
        object : Runnable {
            override fun run() {
                val playing = player
                if (playing != null && playing.isPlaying) {
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
        val debug = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        Log.i("HooBirdVoice", "channel ready debug=$debug")
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        EventChannel(messenger, "dev.hoobird.spike.hoobird/voice_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    events = sink
                    voiceLog("onListen sink=true")
                }

                override fun onCancel(arguments: Any?) {
                    events = null
                    voiceLog("onCancel sink=false")
                }
            },
        )
        MethodChannel(messenger, "dev.hoobird.spike.hoobird/notify").setMethodCallHandler { call, result ->
            when (call.method) {
                "lockscreen" -> {
                    val hide = call.argument<Boolean>("hideContent") ?: true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val manager = getSystemService(NotificationManager::class.java)
                        val channel =
                            NotificationChannel(
                                "hoobird.messages",
                                "Nachrichten",
                                NotificationManager.IMPORTANCE_DEFAULT,
                            )
                        channel.lockscreenVisibility =
                            if (hide) Notification.VISIBILITY_SECRET else Notification.VISIBILITY_PRIVATE
                        channel.description =
                            "HooBird stellt in dieser Fassung keine Push-Nachricht zu. Die Sperrbildschirm-Sichtbarkeit ist nur vorgemerkt."
                        manager.createNotificationChannel(channel)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(messenger, "dev.hoobird.spike.hoobird/media").setMethodCallHandler { call, result ->
            when (call.method) {
                "saveJpeg" -> saveJpeg(call.argument<ByteArray>("bytes"), result)
                "shareJpeg" -> shareJpeg(call.argument<ByteArray>("bytes"), result)
                else -> result.notImplemented()
            }
        }
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
                "eventsReady" -> result.success(events != null)
                "log" -> {
                    voiceLog("ui ${call.argument<String>("message")}")
                    result.success(null)
                }
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

    /**
     * HyperOS reports [AppOpsManager.MODE_FOREGROUND] for a mic the user already
     * allowed, because this app records only while it is in front. That is not a
     * block. Only ignore and error are. Recording does not refuse on this reading:
     * a mic HyperOS actually muted shows up afterwards as an empty file or as
     * near-zero PCM after the file is decoded, and that is when the hint is shown.
     */
    private fun micOpsMode(): Int {
        val appOps = getSystemService(AppOpsManager::class.java) ?: return -1
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_RECORD_AUDIO,
                android.os.Process.myUid(),
                packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_RECORD_AUDIO,
                android.os.Process.myUid(),
                packageName,
            )
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
        val status =
            when {
                granted -> "granted"
                askAgain -> "denied"
                else -> "blocked"
            }
        permissionResult?.success(status)
        permissionResult = null
    }

    private fun voiceLog(message: String) {
        Log.i("HooBirdVoice", message)
    }

    private fun inForeground(): Boolean {
        return !isFinishing && lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)
    }

    private fun emptyStop(): Map<String, Any> {
        return mapOf(
            "elapsedMs" to 0,
            "bytes" to 0,
            "rms" to 0.0,
            "maxAbs" to 0,
            "decoded" to false,
            "source" to "",
            "sampleRate" to 0,
            "pcmMaxAbs" to 0,
            "pcmRms" to 0.0,
            "fileMaxAbs" to 0,
            "fileRms" to 0.0,
            "fileDecoded" to false,
            "container" to "",
            "mime" to "",
            "path" to "",
        )
    }

    private fun payload(stats: VoiceCapture.Stats): Map<String, Any> {
        return mapOf(
            "elapsedMs" to stats.elapsedMs,
            "bytes" to stats.bytes,
            "rms" to stats.rms,
            "maxAbs" to stats.maxAbs,
            "decoded" to stats.decoded,
            "source" to stats.source,
            "sampleRate" to stats.sampleRate,
            "pcmMaxAbs" to stats.pcmMaxAbs,
            "pcmRms" to stats.pcmRms,
            "fileMaxAbs" to stats.fileMaxAbs,
            "fileRms" to stats.fileRms,
            "fileDecoded" to stats.fileDecoded,
            "container" to stats.container,
            "mime" to stats.mime,
            "path" to stats.path,
        )
    }

    private fun startRecording(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrEmpty()) {
            Log.w("HooBirdVoice", "start refused, path missing")
            result.error("record_failed", "Der Aufnahmepfad fehlt.", null)
            return
        }
        voiceLog("start requested foreground=${inForeground()} ops=${micOpsMode()} sink=${events != null}")
        stopPlayback()
        val error = capture.start(path, inForeground())
        if (error != null) {
            result.error("record_failed", error, null)
            return
        }
        result.success(null)
    }

    private fun stopRecording(result: MethodChannel.Result) {
        if (!capture.active) {
            voiceLog("stop ignored, no active recorder")
            result.success(lastStop)
            return
        }
        val stats = capture.stop()
        lastStop = payload(stats)
        result.success(lastStop)
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
        if (capture.active) capture.stop()
    }

    override fun onResume() {
        super.onResume()
        Log.i("HooBirdVoice", "onResume")
    }

    override fun onPause() {
        Log.i("HooBirdVoice", "onPause")
        if (capture.active) {
            Log.w("HooBirdVoice", "pause while recording, releasing the mic")
            capture.requestStop()
        }
        super.onPause()
    }

    private fun saveJpeg(bytes: ByteArray?, result: MethodChannel.Result) {
        if (bytes == null || bytes.isEmpty()) {
            result.error("save_failed", "Das Bild ist leer.", null)
            return
        }
        try {
            val name = "hoobird-${System.currentTimeMillis()}.jpg"
            val values =
                ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, name)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/HooBird")
                        put(MediaStore.Images.Media.IS_PENDING, 1)
                    }
                }
            val uri =
                contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                    ?: throw IllegalStateException("Speichern wurde abgelehnt.")
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Speichern wurde abgelehnt.")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            }
            result.success(null)
        } catch (exc: Exception) {
            result.error("save_failed", exc.message ?: "Speichern ist fehlgeschlagen.", null)
        }
    }

    private fun shareJpeg(bytes: ByteArray?, result: MethodChannel.Result) {
        if (bytes == null || bytes.isEmpty()) {
            result.error("share_failed", "Das Bild ist leer.", null)
            return
        }
        try {
            val dir = java.io.File(cacheDir, "images")
            dir.mkdirs()
            val file = java.io.File(dir, "hoobird-share.jpg")
            file.writeBytes(bytes)
            val uri = FileProvider.getUriForFile(this, "$packageName.files", file)
            val send =
                Intent(Intent.ACTION_SEND).apply {
                    type = "image/jpeg"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            startActivity(Intent.createChooser(send, "Bild teilen"))
            result.success(null)
        } catch (exc: Exception) {
            result.error("share_failed", exc.message ?: "Teilen ist fehlgeschlagen.", null)
        }
    }

    override fun onDestroy() {
        releaseRecorder()
        stopPlayback()
        permissionResult?.error("permission_cancelled", "Die Aktivität wurde geschlossen.", null)
        permissionResult = null
        super.onDestroy()
    }
}
