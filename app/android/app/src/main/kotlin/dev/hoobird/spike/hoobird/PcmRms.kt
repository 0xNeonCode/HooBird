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
