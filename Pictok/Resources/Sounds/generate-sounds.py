#!/usr/bin/env python3
"""
Generate the three Pictok sound effects as 16-bit PCM mono WAVs at 44.1 kHz.

Usage:
    cd /Users/rehatchugh/emoji-decode/Pictok/Resources/Sounds
    python3 generate-sounds.py

Outputs (overwrites if present):
    correct.wav  — rising two-tone "ding"  (~160 ms)
    wrong.wav    — soft low descending thunk (~220 ms)
    win.wav      — three-note ascending arpeggio (~520 ms)

Uses only Python stdlib (wave, struct, math). No pip installs.
"""

import wave
import struct
import math
import os

SAMPLE_RATE = 44100
AMPLITUDE = 0.55  # 0.0 to 1.0; keep some headroom to avoid clipping


def env_attack_release(n_samples, attack_frac=0.05, release_frac=0.40):
    """Envelope with quick attack and longer release, both as fractions of total length."""
    attack = max(1, int(n_samples * attack_frac))
    release = max(1, int(n_samples * release_frac))
    sustain = max(0, n_samples - attack - release)
    env = []
    # Attack: ramp up linearly
    for i in range(attack):
        env.append(i / attack)
    # Sustain: flat
    for _ in range(sustain):
        env.append(1.0)
    # Release: ramp down (cosine for smoothness)
    for i in range(release):
        t = i / release
        env.append(0.5 * (1.0 + math.cos(math.pi * t)))
    return env


def tone(freq, duration_s, amp=AMPLITUDE, attack=0.05, release=0.40):
    """Generate a pure sine tone with attack/release envelope."""
    n = int(duration_s * SAMPLE_RATE)
    env = env_attack_release(n, attack, release)
    samples = []
    for i in range(n):
        v = math.sin(2 * math.pi * freq * i / SAMPLE_RATE)
        samples.append(v * amp * env[i])
    return samples


def two_oscillator_tone(freq, duration_s, amp=AMPLITUDE, attack=0.05, release=0.40):
    """A slightly richer tone: fundamental + 2nd harmonic at lower amp, with envelope."""
    n = int(duration_s * SAMPLE_RATE)
    env = env_attack_release(n, attack, release)
    samples = []
    for i in range(n):
        v = (
            math.sin(2 * math.pi * freq * i / SAMPLE_RATE)
            + 0.25 * math.sin(2 * math.pi * freq * 2 * i / SAMPLE_RATE)
        )
        v *= 0.8  # compensate for the added harmonic
        samples.append(v * amp * env[i])
    return samples


def descending_thunk(start_freq, end_freq, duration_s, amp=AMPLITUDE):
    """A low tone whose pitch drops slightly — feels like 'oops' without being harsh."""
    n = int(duration_s * SAMPLE_RATE)
    env = env_attack_release(n, attack_frac=0.05, release_frac=0.55)
    samples = []
    phase = 0.0
    for i in range(n):
        # Linear pitch drop
        f = start_freq + (end_freq - start_freq) * (i / n)
        phase += 2 * math.pi * f / SAMPLE_RATE
        v = math.sin(phase)
        samples.append(v * amp * env[i])
    return samples


def concat(*chunks, gap_s=0.0):
    """Concatenate chunks with optional silent gap between them."""
    gap = [0.0] * int(gap_s * SAMPLE_RATE)
    out = []
    for i, c in enumerate(chunks):
        if i > 0 and gap:
            out.extend(gap)
        out.extend(c)
    return out


def write_wav(path, samples):
    """Write a list of floats in [-1.0, 1.0] as a 16-bit PCM mono WAV."""
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)  # 16-bit
        w.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for s in samples:
            # Clamp + scale
            v = max(-1.0, min(1.0, s))
            frames.extend(struct.pack("<h", int(v * 32767)))
        w.writeframes(bytes(frames))


def build_correct():
    """A pleasant rising two-tone 'ding' — A5 → E6."""
    a5 = two_oscillator_tone(880.0, 0.06, amp=0.55, attack=0.05, release=0.50)
    e6 = two_oscillator_tone(1318.5, 0.10, amp=0.55, attack=0.05, release=0.60)
    return concat(a5, e6, gap_s=0.005)


def build_wrong():
    """A soft, warm low thunk that drops pitch — A3 → F3."""
    return descending_thunk(220.0, 175.0, 0.22, amp=0.55)


def build_win():
    """A three-note ascending major triad: C5 - E5 - G5."""
    c5 = two_oscillator_tone(523.25, 0.13, amp=0.55, attack=0.05, release=0.50)
    e5 = two_oscillator_tone(659.25, 0.13, amp=0.55, attack=0.05, release=0.50)
    g5 = two_oscillator_tone(783.99, 0.20, amp=0.55, attack=0.05, release=0.65)
    return concat(c5, e5, g5, gap_s=0.01)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    plan = [
        ("correct.wav", build_correct()),
        ("wrong.wav",   build_wrong()),
        ("win.wav",     build_win()),
    ]
    for name, samples in plan:
        path = os.path.join(here, name)
        write_wav(path, samples)
        size = os.path.getsize(path)
        duration_ms = int(1000 * len(samples) / SAMPLE_RATE)
        print(f"  {name:<14} {duration_ms:>4} ms   {size:>6} bytes")


if __name__ == "__main__":
    print("Generating Pictok sound effects (16-bit PCM mono 44.1kHz)...")
    main()
    print("Done.")
