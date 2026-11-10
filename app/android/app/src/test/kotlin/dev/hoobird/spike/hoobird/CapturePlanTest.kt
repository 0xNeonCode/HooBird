package dev.hoobird.spike.hoobird

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CapturePlanTest {
    @Test
    fun unsupportedRateAndChannelAreSkipped() {
        val formats =
            supportedCaptureFormats { rate, channels ->
                if (rate == 48000 || channels == 2) -1 else 2048
            }
        assertTrue(formats.none { it.rate == 48000 })
        assertTrue(formats.none { it.channels == 2 })
        assertEquals(listOf(44100, 16000), formats.map { it.rate })
    }

    @Test
    fun bufferCoversOneSecond() {
        assertEquals(96000, recordBufferBytes(minBuffer = 2048, rate = 48000, channels = 1))
        assertEquals(32000, recordBufferBytes(minBuffer = 4000, rate = 16000, channels = 1))
    }

    @Test
    fun encoderFailuresFallThroughToWav() {
        val aac = ListedEncoder("c2.android.aac.encoder", mimeAac, setOf("lc"), true, true)
        val opus = ListedEncoder("c2.android.opus.encoder", mimeOpus, emptySet(), true, true)
        val deaf = ListedEncoder("c2.android.aac.encoder", mimeAac, setOf("lc"), false, true)
        val attempts = encoderAttempts(listOf(opus, deaf, aac))
        assertEquals("lc", attempts[0].profile)
        assertEquals("m4a", attempts[0].container)
        assertEquals("c2.android.aac.encoder", attempts[0].name)
        assertTrue(attempts.any { it.profile == "he" && it.container == "m4a" })
        assertTrue(attempts.any { it.profile == "none" })
        assertEquals("webm", attempts.last().container)
        assertEquals("m4a", containerAfterFailures(attempts, 0))
        assertEquals("wav", containerAfterFailures(attempts, attempts.size))
        assertEquals("wav", containerAfterFailures(emptyList(), 0))
    }

    @Test
    fun zeroWavAndFailedDecodeAreRejected() {
        val silent = wavPcm16(ByteArray(3200), 16000, 1)
        val read = wavLoudness(silent)
        assertTrue(read.ok)
        assertEquals(0, read.maxAbs)
        assertEquals(0.0, read.rms, 0.0000001)
        assertFalse(voiceSendAllowed(read.ok, read.maxAbs, read.rms))

        val broken = wavLoudness(ByteArray(44))
        assertFalse(broken.ok)
        assertFalse(voiceSendAllowed(false, 0, 0.0))
    }

    @Test
    fun toneWavStaysAboveTheFloor() {
        val tone = tonePcm(sampleRate = 16000, hz = 440.0, seconds = 0.5, amplitude = 8000)
        val pcm = ByteArray(tone.size * 2)
        for (index in tone.indices) {
            val sample = tone[index].toInt()
            pcm[index * 2] = (sample and 0xff).toByte()
            pcm[index * 2 + 1] = ((sample shr 8) and 0xff).toByte()
        }
        val read = wavLoudness(wavPcm16(pcm, 16000, 1))
        assertTrue(read.ok)
        assertTrue(read.maxAbs > 0)
        assertTrue(voiceSendAllowed(read.ok, read.maxAbs, read.rms))
    }

    @Test
    fun stereoDownmixKeepsTheSignal() {
        val stereo = ByteArray(4)
        stereo[0] = 0
        stereo[1] = 0x10
        stereo[2] = 0
        stereo[3] = 0x20
        val mono = downmixToMono16le(stereo, stereo.size, 2)
        assertEquals(2, mono.size)
        val sample = (mono[0].toInt() and 0xff) or ((mono[1].toInt() and 0xff) shl 8)
        assertEquals(0x1800, sample)
    }

    @Test
    fun storageFocusAndLengthStopTheTake() {
        assertFalse(storageAllowsRecording(1024))
        assertTrue(storageAllowsRecording(voiceMinFreeBytes))
        assertFalse(shouldStopForLength(179_999))
        assertTrue(shouldStopForLength(voiceMaxMs))
        assertTrue(shouldStopOnFocusChange(-1))
        assertTrue(shouldStopOnFocusChange(-2))
        assertFalse(shouldStopOnFocusChange(-3))
    }
}
