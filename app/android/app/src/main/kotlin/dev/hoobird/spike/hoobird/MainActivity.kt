package dev.hoobird.spike.hoobird

import android.Manifest
import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.media.PlaybackParams
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import java.nio.ByteOrder
import androidx.core.content.FileProvider
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
    private var output: ParcelFileDescriptor? = null
    private var focusRequest: AudioFocusRequest? = null
    private var recordingPath: String? = null
    private var tickLogsLeft = 0
    private var lastStop: Map<String, Any> =
        mapOf("elapsedMs" to 0, "bytes" to 0, "rms" to 0.0, "decoded" to false)
    private val handler = Handler(Looper.getMainLooper())
    private val tick =
        object : Runnable {
            override fun run() {
                val recording = recorder
                val playing = player
                if (recording != null) {
                    val amplitude =
                        try {
                            (recording.maxAmplitude / 32767.0).coerceIn(0.0, 1.0)
                        } catch (exc: Exception) {
                            voiceLog("amplitude failed ${exc.message}")
                            0.0
                        }
                    val elapsed = System.currentTimeMillis() - startedAt
                    val sink = events
                    if (tickLogsLeft > 0) {
                        tickLogsLeft -= 1
                        voiceLog("tick amp=$amplitude elapsed=$elapsed sink=${sink != null}")
                    }
                    if (sink != null) {
                        try {
                            sink.success(
                                mapOf(
                                    "kind" to "recording",
                                    "elapsedMs" to elapsed,
                                    "amplitude" to amplitude,
                                ),
                            )
                        } catch (exc: Exception) {
                            voiceLog("tick send failed ${exc.message}")
                        }
                    }
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
    private fun micOpsAllowed(): Boolean {
        val appOps = getSystemService(AppOpsManager::class.java) ?: return true
        val mode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
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
        return mode != AppOpsManager.MODE_IGNORED && mode != AppOpsManager.MODE_ERRORED
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
        val debuggable =
            applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (!debuggable) return
        Log.i("HooBirdVoice", message)
    }

    private fun startRecording(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrEmpty()) {
            result.error("record_failed", "Der Aufnahmepfad fehlt.", null)
            return
        }
        stopPlayback()
        releaseRecorder()
        val file = java.io.File(path)
        file.parentFile?.mkdirs()
        recordingPath = path
        val sources =
            listOf(
                MediaRecorder.AudioSource.MIC to "MIC",
                MediaRecorder.AudioSource.VOICE_RECOGNITION to "VOICE_RECOGNITION",
                MediaRecorder.AudioSource.VOICE_COMMUNICATION to "VOICE_COMMUNICATION",
            )
        var last: Exception? = null
        for ((source, name) in sources) {
            var created: MediaRecorder? = null
            try {
                if (file.exists()) file.delete()
                created =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        MediaRecorder(this)
                    } else {
                        @Suppress("DEPRECATION")
                        MediaRecorder()
                    }
                created.setAudioSource(source)
                created.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                created.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                created.setAudioChannels(1)
                created.setAudioSamplingRate(44100)
                created.setAudioEncodingBitRate(64000)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    closeOutput()
                    val descriptor =
                        ParcelFileDescriptor.open(
                            file,
                            ParcelFileDescriptor.MODE_CREATE or
                                ParcelFileDescriptor.MODE_READ_WRITE or
                                ParcelFileDescriptor.MODE_TRUNCATE,
                        )
                    output = descriptor
                    created.setOutputFile(descriptor.fileDescriptor)
                } else {
                    created.setOutputFile(path)
                }
                created.prepare()
                created.start()
                requestMicFocus()
                recorder = created
                startedAt = System.currentTimeMillis()
                tickLogsLeft = 5
                handler.removeCallbacks(tick)
                handler.post(tick)
                voiceLog("start ok source=$name sink=${events != null}")
                result.success(null)
                return
            } catch (exc: Exception) {
                last = exc
                voiceLog("start failed source=$name ${exc.message}")
                recorder = null
                try {
                    created?.release()
                } catch (_: Exception) {
                }
                closeOutput()
                abandonMicFocus()
            }
        }
        result.error(
            "record_failed",
            micFailureMessage(last ?: IllegalStateException("Die Aufnahme konnte nicht starten.")),
            null,
        )
    }

    private fun micFailureMessage(exc: Exception): String {
        val raw = exc.message ?: ""
        if (exc is SecurityException || raw.contains("permission", ignoreCase = true) || !micOpsAllowed()) {
            return "Mikrofon blockiert. Nichts wurde gesendet."
        }
        return raw.ifBlank { "Die Aufnahme konnte nicht starten." }
    }

    private fun requestMicFocus() {
        val audio = getSystemService(AudioManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request =
                AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build(),
                    )
                    .build()
            focusRequest = request
            audio.requestAudioFocus(request)
        }
    }

    private fun abandonMicFocus() {
        val audio = getSystemService(AudioManager::class.java) ?: return
        val request = focusRequest
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && request != null) {
            audio.abandonAudioFocusRequest(request)
        }
        focusRequest = null
    }

    private fun stopRecording(result: MethodChannel.Result) {
        val current = recorder
        if (current == null) {
            voiceLog("stop ignored, no active recorder")
            result.success(lastStop)
            return
        }
        // Clear first so a second stop, from release-send and cancel together,
        // cannot call MediaRecorder.stop again (invalid state 32 after -1007).
        recorder = null
        handler.removeCallbacks(tick)
        val elapsed = System.currentTimeMillis() - startedAt
        var stopError: String? = null
        try {
            current.stop()
        } catch (exc: Exception) {
            stopError = exc.message
        }
        try {
            current.release()
        } catch (exc: Exception) {
            voiceLog("release failed ${exc.message}")
        }
        closeOutput()
        abandonMicFocus()
        val path = recordingPath
        val bytes = if (path == null) 0L else java.io.File(path).length()
        val decodedRms = if (path != null && bytes > 0L) fileRms(path) else false to 0.0
        val payload =
            mapOf(
                "elapsedMs" to elapsed,
                "bytes" to bytes,
                "rms" to decodedRms.second,
                "decoded" to decodedRms.first,
            )
        lastStop = payload
        voiceLog(
            "stop ${if (stopError == null) "ok" else "failed: $stopError"} elapsed=$elapsed bytes=$bytes rms=${decodedRms.second} decoded=${decodedRms.first}",
        )
        result.success(payload)
    }

    private fun fileRms(path: String): Pair<Boolean, Double> {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(path)
            var track = -1
            var format: MediaFormat? = null
            for (index in 0 until extractor.trackCount) {
                val candidate = extractor.getTrackFormat(index)
                val mime = candidate.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    track = index
                    format = candidate
                    break
                }
            }
            if (track < 0 || format == null) {
                voiceLog("decode no audio track")
                return false to 0.0
            }
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return false to 0.0
            extractor.selectTrack(track)
            val decoder = MediaCodec.createDecoderByType(mime)
            codec = decoder
            decoder.configure(format, null, null, 0)
            decoder.start()
            val info = MediaCodec.BufferInfo()
            var sum = 0.0
            var count = 0L
            var inputDone = false
            var outputDone = false
            val deadline = SystemClock.elapsedRealtime() + 4000
            while (!outputDone && SystemClock.elapsedRealtime() < deadline) {
                if (!inputDone) {
                    val inIndex = decoder.dequeueInputBuffer(10_000)
                    if (inIndex >= 0) {
                        val buffer = decoder.getInputBuffer(inIndex)
                        val size = if (buffer == null) -1 else extractor.readSampleData(buffer, 0)
                        if (size < 0) {
                            decoder.queueInputBuffer(
                                inIndex,
                                0,
                                0,
                                0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val outIndex = decoder.dequeueOutputBuffer(info, 10_000)
                if (outIndex >= 0) {
                    val out = decoder.getOutputBuffer(outIndex)
                    if (out != null && info.size > 1) {
                        out.order(ByteOrder.LITTLE_ENDIAN)
                        out.position(info.offset)
                        out.limit(info.offset + info.size)
                        while (out.remaining() >= 2) {
                            val sample = out.short.toDouble()
                            sum += sample * sample
                            count += 1
                        }
                    }
                    decoder.releaseOutputBuffer(outIndex, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                }
            }
            val rms = rmsFromSum(sum, count)
            voiceLog("decode samples=$count rms=$rms")
            if (count == 0L) return false to 0.0
            return true to rms
        } catch (exc: Exception) {
            voiceLog("decode failed ${exc.message}")
            return false to 0.0
        } finally {
            try {
                codec?.stop()
            } catch (_: Exception) {
            }
            try {
                codec?.release()
            } catch (_: Exception) {
            }
            extractor.release()
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
        val current = recorder
        recorder = null
        handler.removeCallbacks(tick)
        if (current != null) {
            try {
                current.stop()
            } catch (exc: Exception) {
                voiceLog("release stop failed ${exc.message}")
            }
            try {
                current.release()
            } catch (_: Exception) {
            }
        }
        closeOutput()
        abandonMicFocus()
    }

    private fun closeOutput() {
        try {
            output?.close()
        } catch (_: Exception) {
        }
        output = null
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
