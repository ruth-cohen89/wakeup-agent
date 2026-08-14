#!/usr/bin/env python3
"""Generate throwaway alarm test tones for the Phase 0 AlarmKit spike.

These are NOT the final Sound Lab sounds. Their only job is to prove that
AlarmKit accepts a custom bundled sound file and that different sounds can be
attached to different alarms in an escalation chain. The real gentle / warning /
aggressive / rotating library comes later (Milestone 5), sourced from free CC0 packs.

Design notes:
  - 30 seconds each. On iOS 26.0 an alarm sound shorter than ~30s did not repeat
    (Apple Developer Forums thread 806697). 30s sidesteps that regression so the
    spike measures AlarmKit behaviour rather than a known bug.
  - 22.05 kHz mono 16-bit keeps each file ~1.3 MB, small enough to commit.
  - Standard library only (wave, math, struct). No pip installs, no paid packages.

Usage:
    python tools/generate_sounds.py
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 22050
DURATION_SECONDS = 30
AMPLITUDE = 0.72  # headroom to avoid clipping when partials sum

OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "ios", "WakeSpike", "Resources", "Sounds",
)


def _envelope_decay(t_in_event, event_length, decay=4.0):
    """Exponential decay envelope, 1.0 at event start falling toward 0."""
    if event_length <= 0:
        return 0.0
    return math.exp(-decay * (t_in_event / event_length))


def gentle_chime(t):
    """Soft decaying bell: a fundamental plus two quiet inharmonic partials.

    Rings every 3s so it is pleasant but still clearly an alarm.
    """
    period = 3.0
    t_in = t % period
    env = _envelope_decay(t_in, period, decay=3.2)
    fundamental = 587.33  # D5
    value = (
        1.00 * math.sin(2 * math.pi * fundamental * t)
        + 0.45 * math.sin(2 * math.pi * fundamental * 2.76 * t)
        + 0.22 * math.sin(2 * math.pi * fundamental * 5.40 * t)
    )
    return value * env * 0.42


def warning_pulse(t):
    """Firmer repeating two-tone. More insistent, still not unpleasant."""
    period = 1.2
    t_in = t % period
    if t_in > 0.75:
        return 0.0  # gap between pulses
    freq = 880.0 if t_in < 0.375 else 660.0
    env = _envelope_decay(t_in % 0.375, 0.375, decay=2.0)
    return math.sin(2 * math.pi * freq * t) * env * 0.60


def buzzer(t):
    """Harsh low buzz. Square-ish via odd harmonics, amplitude-modulated.

    Deliberately grating: this is the 08:10+ category.
    """
    period = 1.0
    t_in = t % period
    if t_in > 0.6:
        return 0.0
    base = 150.0
    value = 0.0
    for harmonic in (1, 3, 5, 7, 9):
        value += math.sin(2 * math.pi * base * harmonic * t) / harmonic
    tremolo = 0.5 + 0.5 * math.sin(2 * math.pi * 22.0 * t)
    return value * tremolo * 0.55


def siren(t):
    """Alternating frequency sweep between two poles.

    Phase is integrated rather than sampled so the sweep stays continuous and
    does not click at each cycle boundary.
    """
    sweep_period = 1.6
    phase = (t % sweep_period) / sweep_period
    low, high = 620.0, 1180.0
    inst_phase = 2 * math.pi * (
        low * t
        + (high - low) * (t / 2 - math.sin(2 * math.pi * phase) * sweep_period / (4 * math.pi))
    )
    return math.sin(inst_phase) * 0.58


SOUNDS = {
    "gentle_chime.wav": gentle_chime,
    "warning_pulse.wav": warning_pulse,
    "buzzer.wav": buzzer,
    "siren.wav": siren,
}


def write_wav(path, generator):
    total_frames = SAMPLE_RATE * DURATION_SECONDS
    frames = bytearray()
    peak = 0.0

    # First pass: render to floats so we can normalize without clipping.
    samples = []
    for n in range(total_frames):
        t = n / SAMPLE_RATE
        value = generator(t)
        peak = max(peak, abs(value))
        samples.append(value)

    scale = (AMPLITUDE / peak) if peak > 0 else 0.0

    for value in samples:
        sample = int(max(-1.0, min(1.0, value * scale)) * 32767)
        frames += struct.pack("<h", sample)

    with wave.open(path, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(bytes(frames))

    return len(frames) // 2


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("Generating Phase 0 spike test tones")
    print("  output: {}".format(OUTPUT_DIR))
    print("  format: {} Hz mono 16-bit, {}s each".format(SAMPLE_RATE, DURATION_SECONDS))
    print()

    for filename, generator in SOUNDS.items():
        path = os.path.join(OUTPUT_DIR, filename)
        frame_count = write_wav(path, generator)
        size_kb = os.path.getsize(path) / 1024
        print("  {:<20} {:>7} frames  {:>8.1f} KB".format(filename, frame_count, size_kb))

    print()
    print("Done. These are technical test tones only, not final alarm sounds.")
    print("If AlarmKit rejects WAV on device, convert on the Mac with:")
    print("  afconvert -f caff -d LEI16 input.wav output.caf")


if __name__ == "__main__":
    main()
