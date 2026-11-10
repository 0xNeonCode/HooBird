package dev.hoobird.spike.hoobird

import kotlin.math.PI
import kotlin.math.sin
import kotlin.math.sqrt

/** RMS of 16-bit PCM, scaled to 0..1 against full scale. Empty input is 0. */
fun pcmRms(samples: ShortArray): Double {
    var sum = 0.0
    for (sample in samples) {
        val value = sample.toDouble()
        sum += value * value
    }
    return rmsFromSum(sum, samples.size.toLong())
}

fun rmsFromSum(sumSquares: Double, count: Long): Double {
    if (count <= 0L) return 0.0
    return sqrt(sumSquares / count) / 32768.0
}

/**
 * Running loudness of little-endian 16-bit PCM. [chunkMax] is only the last
 * buffer, so a level meter can move. [maxAbs] and [rms] cover the whole take.
 */
class PcmAccumulator {
    var sumSquares = 0.0
        private set
    var count = 0L
        private set
    var maxAbs = 0
        private set
    var chunkMax = 0
        private set

    fun addPcm16le(bytes: ByteArray, length: Int) {
        chunkMax = 0
        val end = length - (length % 2)
        var index = 0
        while (index < end) {
            val lo = bytes[index].toInt() and 0xff
            val hi = bytes[index + 1].toInt() and 0xff
            val sample = (lo or (hi shl 8)).toShort().toInt()
            val abs = if (sample < 0) -sample else sample
            if (abs > maxAbs) maxAbs = abs
            if (abs > chunkMax) chunkMax = abs
            val value = sample.toDouble()
            sumSquares += value * value
            count += 1
            index += 2
        }
    }

    fun rms(): Double = rmsFromSum(sumSquares, count)

    fun chunkAmplitude(): Double = (chunkMax / 32768.0).coerceIn(0.0, 1.0)
}

/**
 * Numbers the send gate sees. A missing decode, or a zero peak on either the
 * captured PCM or the decoded file, becomes "not decoded / peak 0" so the take
 * cannot be sent.
 */
fun failClosedLoudness(
    fileDecoded: Boolean,
    pcmMax: Int,
    pcmRms: Double,
    fileMax: Int,
    fileRms: Double,
): Triple<Boolean, Int, Double> {
    if (!fileDecoded || pcmMax <= 0 || fileMax <= 0) {
        return Triple(false, 0, 0.0)
    }
    return Triple(true, minOf(pcmMax, fileMax), minOf(pcmRms, fileRms))
}

/**
 * Fail closed. A take is sent only when the file decoded and both the captured
 * PCM and the decoded file have a non-zero peak and an RMS at or above [threshold].
 */
fun voiceSendAllowed(decoded: Boolean, maxAbs: Int, rms: Double, threshold: Double = 0.01): Boolean {
    if (!decoded) return false
    if (maxAbs <= 0) return false
    if (rms < threshold) return false
    return true
}

/** A probe that is not actually recording, is silenced, or is all zeros is abandoned. */
fun probeShouldRetry(recording: Boolean, silenced: Boolean, maxAbs: Int): Boolean {
    return !recording || silenced || maxAbs <= 0
}

/** A sine at [hz] for [seconds]. Used to prove a tone is not treated as silence. */
fun tonePcm(sampleRate: Int, hz: Double, seconds: Double, amplitude: Int): ShortArray {
    val count = (sampleRate * seconds).toInt().coerceAtLeast(0)
    val samples = ShortArray(count)
    for (index in 0 until count) {
        val sample = sin(2.0 * PI * hz * index / sampleRate) * amplitude
        samples[index] = sample.toInt().toShort()
    }
    return samples
}
