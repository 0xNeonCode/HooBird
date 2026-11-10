package dev.hoobird.spike.hoobird

/** A voice note stops itself after three minutes so a WAV fallback cannot fill the disk. */
const val voiceMaxMs = 180_000L

/** Refuse to start when the cache directory has less than this free. */
const val voiceMinFreeBytes = 8L * 1024L * 1024L

const val mimeAac = "audio/mp4a-latm"
const val mimeOpus = "audio/opus"

data class CaptureFormat(val rate: Int, val channels: Int)

/**
 * Rates and channel counts the HAL will actually open. [minBuffer] is
 * `AudioRecord.getMinBufferSize`: a non-positive result means that pair is
 * not supported on this device.
 */
fun supportedCaptureFormats(
    rates: IntArray = intArrayOf(48000, 44100, 16000),
    channelCounts: IntArray = intArrayOf(1, 2),
    minBuffer: (rate: Int, channels: Int) -> Int,
): List<CaptureFormat> {
    val out = ArrayList<CaptureFormat>()
    for (rate in rates) {
        for (channels in channelCounts) {
            if (channels <= 0) continue
            val min = minBuffer(rate, channels)
            if (min > 0) out.add(CaptureFormat(rate, channels))
        }
    }
    return out
}

/** At least one second of PCM, and at least twice the HAL minimum. */
fun recordBufferBytes(minBuffer: Int, rate: Int, channels: Int): Int {
    val oneSecond = rate * 2 * channels.coerceAtLeast(1)
    return maxOf(minBuffer * 2, oneSecond)
}

data class ListedEncoder(
    val name: String,
    val mime: String,
    val profiles: Set<String>,
    val supportsRate: Boolean,
    val supportsChannels: Boolean,
)

data class EncoderAttempt(
    val name: String,
    val mime: String,
    val profile: String,
    val container: String,
)

/**
 * AAC-LC, then AAC-HE, then AAC with no profile, then Opus. An empty list
 * means the take is stored as PCM WAV.
 */
fun encoderAttempts(found: List<ListedEncoder>): List<EncoderAttempt> {
    val usable = found.filter { it.supportsRate && it.supportsChannels && it.name.isNotEmpty() }
    val out = ArrayList<EncoderAttempt>()
    for (encoder in usable.filter { it.mime == mimeAac }) {
        out.add(EncoderAttempt(encoder.name, mimeAac, "lc", "m4a"))
    }
    for (encoder in usable.filter { it.mime == mimeAac }) {
        out.add(EncoderAttempt(encoder.name, mimeAac, "he", "m4a"))
    }
    for (encoder in usable.filter { it.mime == mimeAac }) {
        out.add(EncoderAttempt(encoder.name, mimeAac, "none", "m4a"))
    }
    for (encoder in usable.filter { it.mime == mimeOpus }) {
        out.add(EncoderAttempt(encoder.name, mimeOpus, "na", "webm"))
    }
    return out
}

/** Container after [failures] configure/start errors. Past the end of the list, WAV. */
fun containerAfterFailures(attempts: List<EncoderAttempt>, failures: Int): String {
    if (failures < 0) return containerAfterFailures(attempts, 0)
    if (failures >= attempts.size) return "wav"
    return attempts[failures].container
}

fun mimeForContainer(container: String): String {
    return when (container) {
        "wav" -> "audio/wav"
        "webm" -> "audio/webm"
        else -> "audio/mp4"
    }
}

fun storageAllowsRecording(freeBytes: Long, minimum: Long = voiceMinFreeBytes): Boolean {
    return freeBytes >= minimum
}

fun shouldStopForLength(elapsedMs: Long, maxMs: Long = voiceMaxMs): Boolean {
    return elapsedMs >= maxMs
}

/** AUDIOFOCUS_LOSS and AUDIOFOCUS_LOSS_TRANSIENT. Ducking does not stop the take. */
fun shouldStopOnFocusChange(change: Int): Boolean {
    return change == -1 || change == -2
}

/** Stereo (or more) to mono, little-endian 16-bit. Mono is copied. */
fun downmixToMono16le(bytes: ByteArray, length: Int, channels: Int): ByteArray {
    val even = length - (length % 2)
    if (channels <= 1) return bytes.copyOf(even.coerceAtLeast(0))
    val frameBytes = 2 * channels
    if (frameBytes <= 0) return ByteArray(0)
    val frames = even / frameBytes
    val out = ByteArray(frames * 2)
    var inIndex = 0
    var outIndex = 0
    for (frame in 0 until frames) {
        var sum = 0
        for (channel in 0 until channels) {
            val lo = bytes[inIndex].toInt() and 0xff
            val hi = bytes[inIndex + 1].toInt() and 0xff
            sum += (lo or (hi shl 8)).toShort().toInt()
            inIndex += 2
        }
        val mixed = sum / channels
        out[outIndex] = (mixed and 0xff).toByte()
        out[outIndex + 1] = ((mixed shr 8) and 0xff).toByte()
        outIndex += 2
    }
    return out
}

fun wavHeader(dataBytes: Int, rate: Int, channels: Int): ByteArray {
    val header = ByteArray(44)
    fun le16(offset: Int, value: Int) {
        header[offset] = (value and 0xff).toByte()
        header[offset + 1] = ((value shr 8) and 0xff).toByte()
    }
    fun le32(offset: Int, value: Int) {
        header[offset] = (value and 0xff).toByte()
        header[offset + 1] = ((value shr 8) and 0xff).toByte()
        header[offset + 2] = ((value shr 16) and 0xff).toByte()
        header[offset + 3] = ((value shr 24) and 0xff).toByte()
    }
    header[0] = 'R'.code.toByte()
    header[1] = 'I'.code.toByte()
    header[2] = 'F'.code.toByte()
    header[3] = 'F'.code.toByte()
    le32(4, 36 + dataBytes)
    header[8] = 'W'.code.toByte()
    header[9] = 'A'.code.toByte()
    header[10] = 'V'.code.toByte()
    header[11] = 'E'.code.toByte()
    header[12] = 'f'.code.toByte()
    header[13] = 'm'.code.toByte()
    header[14] = 't'.code.toByte()
    header[15] = ' '.code.toByte()
    le32(16, 16)
    le16(20, 1)
    le16(22, channels)
    le32(24, rate)
    le32(28, rate * channels * 2)
    le16(32, channels * 2)
    le16(34, 16)
    header[36] = 'd'.code.toByte()
    header[37] = 'a'.code.toByte()
    header[38] = 't'.code.toByte()
    header[39] = 'a'.code.toByte()
    le32(40, dataBytes)
    return header
}

fun wavPcm16(pcm: ByteArray, rate: Int, channels: Int): ByteArray {
    val header = wavHeader(pcm.size, rate, channels)
    return header + pcm
}

data class WavRead(
    val ok: Boolean,
    val maxAbs: Int,
    val rms: Double,
    val rate: Int,
    val channels: Int,
)

/** Loudness of a PCM WAV we wrote. A bad header is not decoded. */
fun wavLoudness(bytes: ByteArray): WavRead {
    if (bytes.size < 44) return WavRead(false, 0, 0.0, 0, 0)
    if (bytes[0] != 'R'.code.toByte() || bytes[8] != 'W'.code.toByte()) return WavRead(false, 0, 0.0, 0, 0)
    fun u16(offset: Int): Int = (bytes[offset].toInt() and 0xff) or ((bytes[offset + 1].toInt() and 0xff) shl 8)
    fun u32(offset: Int): Int {
        var value = 0
        for (index in 0 until 4) value = value or ((bytes[offset + index].toInt() and 0xff) shl (8 * index))
        return value
    }
    if (u16(20) != 1 || u16(34) != 16) return WavRead(false, 0, 0.0, 0, 0)
    val channels = u16(22)
    val rate = u32(24)
    val dataBytes = u32(40)
    if (channels <= 0 || rate <= 0 || dataBytes < 0 || 44 + dataBytes > bytes.size) {
        return WavRead(false, 0, 0.0, 0, 0)
    }
    val pcm = bytes.copyOfRange(44, 44 + dataBytes - (dataBytes % 2))
    val stats = PcmAccumulator()
    stats.addPcm16le(pcm, pcm.size)
    if (stats.count == 0L) return WavRead(false, 0, 0.0, rate, channels)
    return WavRead(true, stats.maxAbs, stats.rms(), rate, channels)
}
