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
}
