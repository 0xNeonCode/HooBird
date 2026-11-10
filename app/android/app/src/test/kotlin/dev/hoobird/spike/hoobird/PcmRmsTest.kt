package dev.hoobird.spike.hoobird

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PcmRmsTest {
    @Test
    fun silenceIsZero() {
        assertEquals(0.0, pcmRms(ShortArray(0)), 0.0)
        assertEquals(0.0, pcmRms(ShortArray(1600)), 0.0000001)
    }

    @Test
    fun injectedToneIsAboveTheSilenceFloor() {
        val tone = tonePcm(sampleRate = 44100, hz = 440.0, seconds = 1.0, amplitude = 8000)
        val rms = pcmRms(tone)
        assertTrue("rms=$rms", rms > 0.01)
        assertTrue(rms < 0.5)
    }

    @Test
    fun allZeroPcmAndAFailedDecodeAreRejected() {
        val zeros = ByteArray(3200)
        val silent = PcmAccumulator()
        silent.addPcm16le(zeros, zeros.size)
        assertEquals(0, silent.maxAbs)
        assertEquals(0.0, silent.rms(), 0.0000001)
        assertTrue(probeShouldRetry(recording = true, silenced = false, maxAbs = silent.maxAbs))
        assertTrue(probeShouldRetry(recording = true, silenced = true, maxAbs = 8000))
        assertTrue(probeShouldRetry(recording = false, silenced = false, maxAbs = 8000))

        val tone = tonePcm(sampleRate = 8000, hz = 440.0, seconds = 0.2, amplitude = 8000)
        val bytes = ByteArray(tone.size * 2)
        for (index in tone.indices) {
            val sample = tone[index].toInt()
            bytes[index * 2] = (sample and 0xff).toByte()
            bytes[index * 2 + 1] = ((sample shr 8) and 0xff).toByte()
        }
        val heard = PcmAccumulator()
        heard.addPcm16le(bytes, bytes.size)
        assertTrue(heard.maxAbs > 0)
        assertTrue(heard.rms() > 0.01)
        assertTrue(!probeShouldRetry(recording = true, silenced = false, maxAbs = heard.maxAbs))

        val closed = failClosedLoudness(false, heard.maxAbs, heard.rms(), heard.maxAbs, heard.rms())
        assertEquals(false, closed.first)
        assertEquals(false, voiceSendAllowed(closed.first, closed.second, closed.third))
        val zeroFile = failClosedLoudness(true, heard.maxAbs, heard.rms(), 0, 0.0)
        assertEquals(false, voiceSendAllowed(zeroFile.first, zeroFile.second, zeroFile.third))
        val quiet = failClosedLoudness(true, 30, 0.001, 30, 0.001)
        assertEquals(false, voiceSendAllowed(quiet.first, quiet.second, quiet.third))
        val ok = failClosedLoudness(true, heard.maxAbs, heard.rms(), heard.maxAbs, heard.rms())
        assertEquals(true, voiceSendAllowed(ok.first, ok.second, ok.third))
    }
}
