package dev.hoobird.spike.hoobird

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioRecordingConfiguration
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.os.Build
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.nio.ByteOrder
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * PCM capture with [AudioRecord], encoded to AAC in an m4a container.
 *
 * MediaRecorder on HyperOS can write a valid AAC file whose samples are
 * digital zeros while AudioService still reports the mic as not silenced.
 * Reading PCM makes that visible: the first 400 ms are inspected, and an
 * all-zero or client-silenced source is closed and the next source is tried.
 */
class VoiceCapture(
    private val context: Context,
    private val log: (Int, String) -> Unit,
    private val emit: (Map<String, Any>) -> Unit,
) {
    data class Stats(
        val elapsedMs: Long = 0,
        val bytes: Long = 0,
        val rms: Double = 0.0,
        val maxAbs: Int = 0,
        val decoded: Boolean = false,
        val source: String = "",
        val sampleRate: Int = 0,
        val samples: Long = 0,
        val pcmMaxAbs: Int = 0,
        val pcmRms: Double = 0.0,
        val fileMaxAbs: Int = 0,
        val fileRms: Double = 0.0,
        val fileDecoded: Boolean = false,
        val container: String = "",
        val mime: String = "",
        val path: String = "",
    )

    private val running = AtomicBoolean(false)
    private val audio = context.getSystemService(AudioManager::class.java)
    private var worker: Thread? = null
    private var finished: CountDownLatch? = null
    private var focusRequest: AudioFocusRequest? = null
    private var startedAt = 0L

    @Volatile
    var active: Boolean = false
        private set

    @Volatile
    var last: Stats = Stats()
        private set

    fun start(path: String, inForeground: Boolean): String? {
        if (!inForeground) {
            log(Log.WARN, "start refused activity not resumed")
            return "Die Aufnahme startet nur, solange HooBird sichtbar ist."
        }
        val free = freeBytes(path)
        if (!storageAllowsRecording(free)) {
            log(Log.WARN, "storage low free=$free")
            return "Zu wenig Speicher für eine Aufnahme."
        }
        requestStop()
        joinWorker()
        abandonFocus()
        requestFocus()
        val latch = CountDownLatch(1)
        startedAt = SystemClock.elapsedRealtime()
        running.set(true)
        active = true
        finished = latch
        last = Stats()
        val thread =
            Thread(
                {
                    try {
                        last = capture(path)
                    } catch (exc: Exception) {
                        log(Log.WARN, "capture crashed ${exc.javaClass.simpleName} ${exc.message}")
                        last =
                            Stats(
                                elapsedMs = SystemClock.elapsedRealtime() - startedAt,
                                decoded = false,
                            )
                    } finally {
                        running.set(false)
                        latch.countDown()
                    }
                },
                "HooBirdVoice",
            )
        worker = thread
        thread.start()
        log(Log.INFO, "start thread path=$path")
        return null
    }

    fun requestStop() {
        running.set(false)
    }

    fun stop(): Stats {
        requestStop()
        joinWorker()
        abandonFocus()
        active = false
        val stats = last
        val allowed = voiceSendAllowed(stats.decoded, stats.maxAbs, stats.rms)
        log(
            if (allowed) Log.INFO else Log.WARN,
            "decision source=${stats.source} rate=${stats.sampleRate} samples=${stats.samples} " +
                "pcmMax=${stats.pcmMaxAbs} pcmRms=${stats.pcmRms} fileDecoded=${stats.fileDecoded} " +
                "fileMax=${stats.fileMaxAbs} fileRms=${stats.fileRms} container=${stats.container} " +
                "elapsed=${stats.elapsedMs} bytes=${stats.bytes} send=$allowed",
        )
        return stats
    }

    private fun joinWorker() {
        val thread = worker
        worker = null
        if (thread != null && thread !== Thread.currentThread()) {
            try {
                thread.join(5000)
            } catch (_: InterruptedException) {
            }
        }
        try {
            finished?.await(500, TimeUnit.MILLISECONDS)
        } catch (_: InterruptedException) {
        }
    }

    private fun capture(path: String): Stats {
        val file = File(path)
        file.parentFile?.mkdirs()
        if (file.exists()) file.delete()
        val sources =
            listOf(
                MediaRecorder.AudioSource.VOICE_RECOGNITION to "VOICE_RECOGNITION",
                MediaRecorder.AudioSource.MIC to "MIC",
                MediaRecorder.AudioSource.DEFAULT to "DEFAULT",
                MediaRecorder.AudioSource.CAMCORDER to "CAMCORDER",
            )
        val formats = supportedCaptureFormats { rate, channels -> minBuffer(rate, channels) }
        log(
            Log.INFO,
            "probe order ${sources.joinToString(",") { it.second }} formats " +
                formats.joinToString(",") { "${it.rate}/${it.channels}" },
        )
        var chosen: AudioRecord? = null
        var chosenName = ""
        var chosenRate = 0
        var chosenChannels = 1
        var primed = ByteArray(0)
        var fallbackSource = -1
        var fallbackRate = 0
        var fallbackChannels = 1
        var fallbackName = ""
        var prepared: RunningEncoder? = null
        val pcm = PcmAccumulator()
        for ((source, name) in sources) {
            if (!running.get()) break
            var opened: AudioRecord? = null
            var rateUsed = 0
            var channelsUsed = 1
            var preparedForSource: RunningEncoder? = null
            for (format in formats) {
                if (!running.get()) break
                // Build the encoder before the microphone opens, so the read
                // loop is not paused for codec setup. A paused AudioRecord
                // overflows and the rest of the take comes back as zeros.
                // A null encoder is the WAV fallback and is still usable.
                val encoder = prepareEncoder(format.rate)
                val candidate = openRecord(source, name, format.rate, format.channels)
                if (candidate == null) {
                    encoder?.let { releaseCodec(it.codec) }
                    continue
                }
                opened = candidate
                rateUsed = format.rate
                channelsUsed = format.channels
                preparedForSource = encoder
                break
            }
            val record = opened ?: continue
            val probe = readProbe(record, name, rateUsed, channelsUsed)
            val recording = record.recordingState == AudioRecord.RECORDSTATE_RECORDING
            val silenced = clientSilenced(record)
            log(
                if (probe.maxAbs == 0 || silenced) Log.WARN else Log.INFO,
                "probe source=$name rate=$rateUsed channels=$channelsUsed max=${probe.maxAbs} rms=${probe.rms} " +
                    "silenced=$silenced state=${record.recordingState} bytes=${probe.pcm.size}",
            )
            if (running.get() && recording && !silenced && fallbackSource < 0) {
                fallbackSource = source
                fallbackRate = rateUsed
                fallbackChannels = channelsUsed
                fallbackName = name
            }
            if (!running.get() || probeShouldRetry(recording, silenced, probe.maxAbs)) {
                releaseRecord(record)
                preparedForSource?.let { releaseCodec(it.codec) }
                continue
            }
            chosen = record
            chosenName = name
            chosenRate = rateUsed
            chosenChannels = channelsUsed
            prepared = preparedForSource
            primed = probe.pcm
            pcm.addPcm16le(primed, primed.size)
            log(Log.INFO, "source kept $name rate=$rateUsed channels=$channelsUsed pcmMax=${pcm.maxAbs}")
            break
        }
        if (chosen == null && fallbackSource >= 0 && running.get()) {
            // Every probe was zeros. Keep one live source anyway: some HALs
            // stay at zero for the first few hundred milliseconds and then
            // deliver real samples. An all-zero take is still rejected later.
            log(Log.WARN, "all probes were zero, continuing on $fallbackName rate=$fallbackRate")
            val encoder = prepareEncoder(fallbackRate)
            val reopened = openRecord(fallbackSource, fallbackName, fallbackRate, fallbackChannels)
            if (reopened != null) {
                chosen = reopened
                chosenName = fallbackName
                chosenRate = fallbackRate
                chosenChannels = fallbackChannels
                prepared = encoder
                primed = ByteArray(0)
            } else {
                encoder?.let { releaseCodec(it.codec) }
            }
        }
        val record = chosen
        if (record == null) {
            log(Log.WARN, "every source was silent or closed")
            while (running.get()) {
                emitTick("", 0, pcm)
                try {
                    Thread.sleep(200)
                } catch (_: InterruptedException) {
                    break
                }
            }
            return finishStats(file, "", 0, pcm)
        }
        var muxerStarted = false
        var codec: MediaCodec? = null
        var muxer: MediaMuxer? = null
        // The microphone is read on its own thread. Encoding on the same thread
        // stalls AudioRecord, the small HAL buffer overruns, and everything
        // after the probe comes back as digital zeros.
        val chunks = ArrayBlockingQueue<ByteArray>(96)
        val readerDone = AtomicBoolean(false)
        val reader =
            Thread(
                {
                    val readBuffer = ByteArray(readChunkBytes(record, chosenChannels))
                    var lastTick = 0L
                    var dropped = 0
                    try {
                        while (running.get()) {
                            if (shouldStopForLength(SystemClock.elapsedRealtime() - startedAt)) {
                                log(Log.WARN, "max duration")
                                running.set(false)
                                break
                            }
                            // Blocking read. stop() from the encoder thread unblocks it.
                            // A non-blocking read that sleeps falls behind the HAL, and
                            // ranchu then inserts silence for the rest of the take.
                            val count = record.read(readBuffer, 0, readBuffer.size)
                            if (count < 0) {
                                if (running.get()) log(Log.WARN, "read failed code=$count source=$chosenName")
                                break
                            }
                            if (count == 0) continue
                            val mono = downmixToMono16le(readBuffer, count, chosenChannels)
                            if (mono.isEmpty()) continue
                            pcm.addPcm16le(mono, mono.size)
                            if (!chunks.offer(mono)) {
                                chunks.poll()
                                chunks.offer(mono)
                                dropped += 1
                                if (dropped <= 3 || dropped % 25 == 0) {
                                    log(Log.WARN, "capture queue full dropped=$dropped")
                                }
                            }
                            val now = SystemClock.elapsedRealtime()
                            if (now - lastTick >= 200) {
                                lastTick = now
                                emitTick(chosenName, chosenRate, pcm)
                            }
                        }
                    } finally {
                        readerDone.set(true)
                    }
                },
                "HooBirdVoiceRead",
            )
        reader.start()
        val containerName = prepared?.container ?: "wav"
        val outFile = outputFile(path, containerName)
        var wroteWav = false
        try {
            val runningEncoder = prepared
            if (runningEncoder == null) {
                wroteWav = writeWav(outFile, chosenRate, primed, chunks, readerDone, record)
            } else {
            val encoder = runningEncoder.codec
            codec = encoder
            val muxerFormat =
                if (containerName == "webm") {
                    MediaMuxer.OutputFormat.MUXER_OUTPUT_WEBM
                } else {
                    MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
                }
            val container = MediaMuxer(outFile.absolutePath, muxerFormat)
            muxer = container
            var track = -1
            val info = MediaCodec.BufferInfo()
            var pts = 0L
            var lastPts = -1L
            fun drain(waitForEnd: Boolean) {
                val deadline = SystemClock.elapsedRealtime() + if (waitForEnd) 2000 else 0
                while (true) {
                    if (waitForEnd && SystemClock.elapsedRealtime() > deadline) {
                        log(Log.WARN, "encoder drain timed out")
                        return
                    }
                    val index = encoder.dequeueOutputBuffer(info, if (waitForEnd) 10_000 else 0)
                    if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        if (!muxerStarted) {
                            track = container.addTrack(encoder.outputFormat)
                            container.start()
                            muxerStarted = true
                            log(Log.INFO, "muxer started track=$track")
                        }
                        continue
                    }
                    if (index < 0) return
                    val encoded = encoder.getOutputBuffer(index)
                    val config = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                    if (encoded != null && info.size > 0 && !config && muxerStarted && track >= 0) {
                        encoded.position(info.offset)
                        encoded.limit(info.offset + info.size)
                        if (info.presentationTimeUs <= lastPts) info.presentationTimeUs = lastPts + 1
                        lastPts = info.presentationTimeUs
                        container.writeSampleData(track, encoded, info)
                    }
                    val end = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    encoder.releaseOutputBuffer(index, false)
                    if (end) return
                    if (!waitForEnd && info.size == 0) return
                }
            }
            fun queue(bytes: ByteArray, length: Int) {
                var offset = 0
                var spins = 0
                while (offset < length && spins < 40) {
                    val index = encoder.dequeueInputBuffer(10_000)
                    if (index < 0) {
                        drain(false)
                        spins += 1
                        continue
                    }
                    val input = encoder.getInputBuffer(index) ?: break
                    input.clear()
                    val count = minOf(input.remaining(), length - offset)
                    if (count <= 0) break
                    input.put(bytes, offset, count)
                    val frames = count / 2
                    encoder.queueInputBuffer(index, 0, count, pts, 0)
                    pts += frames * 1_000_000L / chosenRate
                    offset += count
                    spins = 0
                    drain(false)
                }
            }
            queue(primed, primed.size)
            var stoppedRecord = false
            while (true) {
                val chunk = chunks.poll(40, TimeUnit.MILLISECONDS)
                if (chunk != null) queue(chunk, chunk.size)
                if (!running.get() && !stoppedRecord) {
                    stoppedRecord = true
                    try {
                        record.stop()
                    } catch (exc: Exception) {
                        log(Log.WARN, "record stop ${exc.message}")
                    }
                }
                if (stoppedRecord && readerDone.get() && chunks.isEmpty()) break
            }
            val eos = encoder.dequeueInputBuffer(20_000)
            if (eos >= 0) {
                encoder.queueInputBuffer(eos, 0, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            }
            drain(true)
            }
        } catch (exc: Exception) {
            log(Log.WARN, "encode failed ${exc.javaClass.simpleName} ${exc.message}")
        } finally {
            running.set(false)
            try {
                reader.join(1500)
            } catch (_: InterruptedException) {
            }
            releaseRecord(record)
            try {
                codec?.stop()
            } catch (_: Exception) {
            }
            try {
                codec?.release()
            } catch (_: Exception) {
            }
            try {
                if (muxerStarted) muxer?.stop()
            } catch (exc: Exception) {
                log(Log.WARN, "muxer stop ${exc.message}")
            }
            try {
                muxer?.release()
            } catch (_: Exception) {
            }
            if (!muxerStarted && !wroteWav && outFile.exists()) outFile.delete()
        }
        return finishStats(outFile, chosenName, chosenRate, pcm, containerName)
    }

    private fun finishStats(
        file: File,
        source: String,
        rate: Int,
        pcm: PcmAccumulator,
        container: String = "",
    ): Stats {
        val bytes = if (file.isFile) file.length() else 0L
        val decoded =
            if (bytes > 0L) {
                decodeFile(file.absolutePath, container)
            } else {
                Decoded(false, 0, 0.0)
            }
        val closed = failClosedLoudness(decoded.ok, pcm.maxAbs, pcm.rms(), decoded.maxAbs, decoded.rms)
        return Stats(
            elapsedMs = SystemClock.elapsedRealtime() - startedAt,
            bytes = bytes,
            rms = closed.third,
            maxAbs = closed.second,
            decoded = closed.first,
            source = source,
            sampleRate = rate,
            samples = pcm.count,
            pcmMaxAbs = pcm.maxAbs,
            pcmRms = pcm.rms(),
            fileMaxAbs = decoded.maxAbs,
            fileRms = decoded.rms,
            fileDecoded = decoded.ok,
            container = container,
            mime = if (container.isEmpty()) "" else mimeForContainer(container),
            path = if (file.isFile) file.absolutePath else "",
        )
    }

    private data class Probe(val pcm: ByteArray, val maxAbs: Int, val rms: Double)

    private fun readProbe(record: AudioRecord, name: String, rate: Int, channels: Int): Probe {
        val stats = PcmAccumulator()
        val collected = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(readChunkBytes(record, channels))
        val deadline = SystemClock.elapsedRealtime() + 400
        var lastTick = 0L
        while (running.get() && SystemClock.elapsedRealtime() < deadline) {
            val count = record.read(buffer, 0, buffer.size)
            if (count < 0) {
                log(Log.WARN, "probe read failed code=$count source=$name")
                break
            }
            if (count > 0) {
                val mono = downmixToMono16le(buffer, count, channels)
                if (mono.isEmpty()) continue
                stats.addPcm16le(mono, mono.size)
                collected.write(mono)
                val now = SystemClock.elapsedRealtime()
                if (now - lastTick >= 200) {
                    lastTick = now
                    emitTick(name, rate, stats)
                }
            }
        }
        return Probe(collected.toByteArray(), stats.maxAbs, stats.rms())
    }

    private fun emitTick(source: String, rate: Int, pcm: PcmAccumulator) {
        val elapsed = SystemClock.elapsedRealtime() - startedAt
        val amplitude = pcm.chunkAmplitude()
        log(
            Log.INFO,
            "tick amp=$amplitude source=$source rate=$rate max=${pcm.maxAbs} rms=${pcm.rms()} elapsed=$elapsed samples=${pcm.count}",
        )
        emit(
            mapOf(
                "kind" to "recording",
                "elapsedMs" to elapsed,
                "amplitude" to amplitude,
                "source" to source,
                "sampleRate" to rate,
                "maxAbs" to pcm.maxAbs,
                "rms" to pcm.rms(),
            ),
        )
    }

    private fun openRecord(source: Int, name: String, rate: Int, channels: Int): AudioRecord? {
        val mask = if (channels == 1) AudioFormat.CHANNEL_IN_MONO else AudioFormat.CHANNEL_IN_STEREO
        val min = minBuffer(rate, channels)
        if (min <= 0) {
            log(Log.WARN, "no buffer source=$name rate=$rate channels=$channels code=$min")
            return null
        }
        // One second of 16-bit PCM. The platform minimum is only a few dozen
        // milliseconds; a short stall then overruns and later reads are zeros.
        val buffer = recordBufferBytes(min, rate, channels)
        return try {
            val format =
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(rate)
                    .setChannelMask(mask)
                    .build()
            val builder =
                AudioRecord.Builder()
                    .setAudioSource(source)
                    .setAudioFormat(format)
                    .setBufferSizeInBytes(buffer)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                builder.setContext(context)
            }
            val record = builder.build()
            if (record.state != AudioRecord.STATE_INITIALIZED) {
                log(Log.WARN, "not initialized source=$name rate=$rate")
                record.release()
                return null
            }
            record.startRecording()
            if (record.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                log(Log.WARN, "not recording source=$name rate=$rate state=${record.recordingState}")
                releaseRecord(record)
                return null
            }
            log(
                Log.INFO,
                "opened source=$name rate=$rate channels=$channels session=${record.audioSessionId} bytes=$buffer",
            )
            record
        } catch (exc: Exception) {
            log(Log.WARN, "open failed source=$name rate=$rate ${exc.javaClass.simpleName} ${exc.message}")
            null
        }
    }

    private fun clientSilenced(record: AudioRecord): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || audio == null) return false
        val session = record.audioSessionId
        val configs: List<AudioRecordingConfiguration> =
            try {
                audio.activeRecordingConfigurations
            } catch (exc: Exception) {
                log(Log.WARN, "recording configs failed ${exc.message}")
                return false
            }
        val mine = configs.filter { it.clientAudioSessionId == session }
        if (mine.isEmpty()) {
            log(Log.INFO, "no recording config yet session=$session configs=${configs.size}")
            return false
        }
        val silenced = mine.any { it.isClientSilenced }
        if (silenced) log(Log.WARN, "client silenced session=$session")
        return silenced
    }

    private fun readChunkBytes(record: AudioRecord, channels: Int): Int {
        val frames = record.bufferSizeInFrames.coerceAtLeast(1)
        val bytes = frames * 2 * channels.coerceAtLeast(1)
        return minOf(bytes, 3840 * channels.coerceAtLeast(1)).coerceAtLeast(2 * channels.coerceAtLeast(1))
    }

    private class RunningEncoder(
        val codec: MediaCodec,
        val container: String,
    )

    private fun minBuffer(rate: Int, channels: Int): Int {
        val mask = if (channels == 1) AudioFormat.CHANNEL_IN_MONO else AudioFormat.CHANNEL_IN_STEREO
        return AudioRecord.getMinBufferSize(rate, mask, AudioFormat.ENCODING_PCM_16BIT)
    }

    private fun prepareEncoder(rate: Int): RunningEncoder? {
        val attempts = encoderAttempts(listEncoders(rate))
        log(Log.INFO, "encoder attempts=${attempts.size} rate=$rate")
        var failures = 0
        for (attempt in attempts) {
            try {
                val codec = startOne(attempt, rate)
                log(
                    Log.INFO,
                    "encoder chosen name=${attempt.name} mime=${attempt.mime} profile=${attempt.profile} container=${attempt.container}",
                )
                return RunningEncoder(codec, attempt.container)
            } catch (exc: Exception) {
                failures += 1
                log(
                    Log.WARN,
                    "encoder failed name=${attempt.name} profile=${attempt.profile} ${exc.message} " +
                        "next=${containerAfterFailures(attempts, failures)}",
                )
            }
        }
        log(Log.WARN, "encoder none, wav pcm")
        return null
    }

    private fun listEncoders(rate: Int): List<ListedEncoder> {
        val found = ArrayList<ListedEncoder>()
        val infos =
            try {
                MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos
            } catch (exc: Exception) {
                log(Log.WARN, "codec list failed ${exc.message}")
                return found
            }
        for (info in infos) {
            if (!info.isEncoder) continue
            for (mime in info.supportedTypes) {
                if (mime != mimeAac && mime != mimeOpus) continue
                try {
                    val caps = info.getCapabilitiesForType(mime)
                    val audio = caps.audioCapabilities
                    val supportsRate = audio?.isSampleRateSupported(rate) == true
                    val supportsChannels = (audio?.maxInputChannelCount ?: 0) >= 1
                    val profiles = HashSet<String>()
                    if (mime == mimeAac) {
                        for (level in caps.profileLevels) {
                            when (level.profile) {
                                MediaCodecInfo.CodecProfileLevel.AACObjectLC -> profiles.add("lc")
                                MediaCodecInfo.CodecProfileLevel.AACObjectHE,
                                MediaCodecInfo.CodecProfileLevel.AACObjectHE_PS,
                                -> profiles.add("he")
                                else -> profiles.add("other")
                            }
                        }
                    }
                    found.add(ListedEncoder(info.name, mime, profiles, supportsRate, supportsChannels))
                } catch (exc: Exception) {
                    log(Log.WARN, "codec caps ${info.name} ${exc.message}")
                }
            }
        }
        return found
    }

    private fun startOne(attempt: EncoderAttempt, rate: Int): MediaCodec {
        val format =
            MediaFormat.createAudioFormat(attempt.mime, rate, 1).apply {
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16_384)
                setInteger(MediaFormat.KEY_CHANNEL_MASK, AudioFormat.CHANNEL_IN_MONO)
                if (attempt.mime == mimeAac) {
                    setInteger(MediaFormat.KEY_BIT_RATE, 64_000)
                    if (attempt.profile == "lc") {
                        setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                    } else if (attempt.profile == "he") {
                        setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectHE)
                    }
                } else {
                    setInteger(MediaFormat.KEY_BIT_RATE, 24_000)
                }
            }
        val codec = MediaCodec.createByCodecName(attempt.name)
        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
        } catch (exc: Exception) {
            try {
                codec.release()
            } catch (_: Exception) {
            }
            throw exc
        }
        return codec
    }

    private data class Decoded(val ok: Boolean, val maxAbs: Int, val rms: Double)

    private fun decodeFile(path: String, container: String): Decoded {
        if (container == "wav") {
            return try {
                val read = wavLoudness(File(path).readBytes())
                log(Log.INFO, "wav decoded ok=${read.ok} max=${read.maxAbs} rms=${read.rms} rate=${read.rate}")
                if (!read.ok) Decoded(false, 0, 0.0) else Decoded(true, read.maxAbs, read.rms)
            } catch (exc: Exception) {
                log(Log.WARN, "wav header bad ${exc.message}")
                Decoded(false, 0, 0.0)
            }
        }
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
                log(Log.WARN, "decode no audio track")
                return Decoded(false, 0, 0.0)
            }
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return Decoded(false, 0, 0.0)
            extractor.selectTrack(track)
            val decoder = MediaCodec.createDecoderByType(mime)
            codec = decoder
            decoder.configure(format, null, null, 0)
            decoder.start()
            val info = MediaCodec.BufferInfo()
            var sum = 0.0
            var count = 0L
            var maxAbs = 0
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
                            decoder.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
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
                            val sample = out.short.toInt()
                            val abs = if (sample < 0) -sample else sample
                            if (abs > maxAbs) maxAbs = abs
                            val value = sample.toDouble()
                            sum += value * value
                            count += 1
                        }
                    }
                    decoder.releaseOutputBuffer(outIndex, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                }
            }
            val rms = rmsFromSum(sum, count)
            log(Log.INFO, "decode samples=$count max=$maxAbs rms=$rms")
            if (count == 0L) return Decoded(false, 0, 0.0)
            return Decoded(true, maxAbs, rms)
        } catch (exc: Exception) {
            log(Log.WARN, "decode failed ${exc.javaClass.simpleName} ${exc.message}")
            return Decoded(false, 0, 0.0)
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

    private val focusListener =
        AudioManager.OnAudioFocusChangeListener { change ->
            log(Log.INFO, "audio focus change $change")
            if (shouldStopOnFocusChange(change)) {
                log(Log.WARN, "focus lost, stopping")
                requestStop()
            }
        }
    private var legacyFocus = false

    private fun requestFocus() {
        val manager = audio ?: return
        // Media usage, not voice-communication. On HyperOS a communication
        // focus can move the mic onto a path that captures digital zeros
        // while AudioService still reports the client as not silenced.
        try {
            manager.mode = AudioManager.MODE_NORMAL
        } catch (exc: Exception) {
            log(Log.WARN, "audio mode ${exc.message}")
        }
        log(Log.INFO, "route sco=${manager.isBluetoothScoOn} a2dp=${manager.isBluetoothA2dpOn}")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request =
                AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build(),
                    )
                    .setOnAudioFocusChangeListener(focusListener)
                    .build()
            focusRequest = request
            legacyFocus = false
            val granted = manager.requestAudioFocus(request)
            log(Log.INFO, "audio focus result=$granted")
        } else {
            @Suppress("DEPRECATION")
            val granted =
                manager.requestAudioFocus(
                    focusListener,
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE,
                )
            legacyFocus = true
            log(Log.INFO, "audio focus result=$granted")
        }
    }

    private fun abandonFocus() {
        val manager = audio
        val request = focusRequest
        if (request != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager?.abandonAudioFocusRequest(request)
        } else if (legacyFocus && manager != null) {
            @Suppress("DEPRECATION")
            manager.abandonAudioFocus(focusListener)
        }
        focusRequest = null
        legacyFocus = false
        log(Log.INFO, "audio focus released")
    }

    private fun freeBytes(path: String): Long {
        return try {
            val dir = File(path).parentFile ?: return Long.MAX_VALUE
            if (!dir.exists()) dir.mkdirs()
            android.os.StatFs(dir.absolutePath).availableBytes
        } catch (exc: Exception) {
            log(Log.WARN, "storage check ${exc.message}")
            Long.MAX_VALUE
        }
    }

    private fun outputFile(requested: String, container: String): File {
        val ext =
            when (container) {
                "wav" -> "wav"
                "webm" -> "webm"
                else -> "m4a"
            }
        val file = File(requested)
        return File(file.parentFile, file.nameWithoutExtension + ".$ext")
    }

    private fun writeWav(
        file: File,
        rate: Int,
        primed: ByteArray,
        chunks: ArrayBlockingQueue<ByteArray>,
        readerDone: AtomicBoolean,
        record: AudioRecord,
    ): Boolean {
        var stream: java.io.FileOutputStream? = null
        return try {
            file.parentFile?.mkdirs()
            stream = java.io.FileOutputStream(file)
            stream.write(ByteArray(44))
            var dataBytes = 0
            fun append(bytes: ByteArray) {
                if (bytes.isEmpty()) return
                stream?.write(bytes)
                dataBytes += bytes.size
            }
            append(primed)
            var stoppedRecord = false
            while (true) {
                val chunk = chunks.poll(40, TimeUnit.MILLISECONDS)
                if (chunk != null) append(chunk)
                if (!running.get() && !stoppedRecord) {
                    stoppedRecord = true
                    try {
                        record.stop()
                    } catch (exc: Exception) {
                        log(Log.WARN, "record stop ${exc.message}")
                    }
                }
                if (stoppedRecord && readerDone.get() && chunks.isEmpty()) break
            }
            stream.flush()
            stream.close()
            stream = null
            java.io.RandomAccessFile(file, "rw").use { raf ->
                raf.seek(0)
                raf.write(wavHeader(dataBytes, rate, 1))
            }
            log(Log.INFO, "wav wrote bytes=$dataBytes rate=$rate")
            true
        } catch (exc: Exception) {
            log(Log.WARN, "wav write failed ${exc.message}")
            false
        } finally {
            try {
                stream?.close()
            } catch (_: Exception) {
            }
        }
    }

    private fun releaseCodec(codec: MediaCodec) {
        try {
            codec.stop()
        } catch (_: Exception) {
        }
        try {
            codec.release()
        } catch (_: Exception) {
        }
    }

    private fun releaseRecord(record: AudioRecord) {
        try {
            if (record.recordingState == AudioRecord.RECORDSTATE_RECORDING) record.stop()
        } catch (exc: Exception) {
            log(Log.WARN, "record stop ${exc.message}")
        }
        try {
            record.release()
        } catch (_: Exception) {
        }
    }
}
