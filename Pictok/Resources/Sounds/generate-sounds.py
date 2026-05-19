#!/usr/bin/env python3
"""
Generate the four Pictok sound effects as 16-bit PCM mono WAVs at 44.1 kHz.

This is round-2 synthesis: FM-derived bell tones with layered harmonics,
noise-burst attack transients, soft saturation, and a tiny echo tail.
The outputs are noticeably less "calculator beep" than pure-sine v1.

Usage:
    cd /Users/rehatchugh/emoji-decode/Pictok/Resources/Sounds
    python3 generate-sounds.py

Outputs (overwrites if present):
    correct.wav   — bright bell-pluck "ding" with attack transient (~180 ms)
    wrong.wav     — soft warm low thud, single muffled hit (~240 ms)
    fail.wav      — three-note descending "sad bell" sequence (~700 ms)
    win.wav       — bright bell arpeggio with chord finish + sparkle (~900 ms)

Uses only Python stdlib (wave, struct, math, random). No pip installs.
"""

import wave
import struct
import math
import random
import os

SAMPLE_RATE = 44100
HEADROOM = 0.85  # final master gain, leaves room before clipping

random.seed(7)  # deterministic output across regenerations


# ----------------------------- envelopes ------------------------------------

def env_exp(n_samples: int, attack_s: float, decay_s: float) -> list[float]:
    """Linear attack into exponential decay. Returns a list of floats in [0, 1]."""
    attack = max(1, int(attack_s * SAMPLE_RATE))
    decay = max(1, int(decay_s * SAMPLE_RATE))
    total = attack + decay
    env = [0.0] * total
    for i in range(attack):
        env[i] = i / attack
    # Exponential decay with -60 dB target at end of decay window
    k = math.log(1000.0) / decay  # so e^(-k * decay) = 0.001
    for i in range(decay):
        env[attack + i] = math.exp(-k * i)
    # Pad/trim to n_samples
    if total < n_samples:
        env.extend([0.0] * (n_samples - total))
    return env[:n_samples]


def env_ar(n_samples: int, attack_frac: float = 0.04, release_frac: float = 0.50) -> list[float]:
    """Attack/sustain/release envelope, smoothed cosine release."""
    attack = max(1, int(n_samples * attack_frac))
    release = max(1, int(n_samples * release_frac))
    sustain = max(0, n_samples - attack - release)
    env = []
    for i in range(attack):
        env.append(i / attack)
    env.extend([1.0] * sustain)
    for i in range(release):
        t = i / release
        env.append(0.5 * (1.0 + math.cos(math.pi * t)))
    return env[:n_samples]


# ----------------------------- oscillators ----------------------------------

def fm_bell(freq: float, duration_s: float, *,
            mod_ratio: float = 1.41,
            mod_index_start: float = 4.0,
            mod_index_decay_s: float = 0.18,
            attack_s: float = 0.004,
            decay_s: float = None,
            amp: float = 0.6) -> list[float]:
    """FM synthesis producing a bell/pluck timbre.

    Carrier frequency = freq. Modulator frequency = freq * mod_ratio.
    Modulation index decays exponentially → harmonics fade, leaving the
    fundamental. Classic Chowning-bell technique. Non-integer ratios give
    inharmonic (bell-like) overtones; integer ratios give harmonic (mallet-like).
    """
    if decay_s is None:
        decay_s = duration_s - attack_s
    n = int(duration_s * SAMPLE_RATE)
    env = env_exp(n, attack_s, decay_s)
    mod_k = math.log(1000.0) / (mod_index_decay_s * SAMPLE_RATE)
    out = [0.0] * n
    two_pi = 2.0 * math.pi
    fm_freq = freq * mod_ratio
    for i in range(n):
        idx = mod_index_start * math.exp(-mod_k * i)
        mod = math.sin(two_pi * fm_freq * i / SAMPLE_RATE)
        carrier_phase = two_pi * freq * i / SAMPLE_RATE + idx * mod
        out[i] = math.sin(carrier_phase) * env[i] * amp
    return out


def detuned_pair(freq: float, duration_s: float, *,
                 detune_cents: float = 8.0,
                 amp: float = 0.5,
                 attack_s: float = 0.01,
                 decay_s: float = 0.18) -> list[float]:
    """Two slightly-detuned sines = chorus-like warmth (good for warm thuds)."""
    n = int(duration_s * SAMPLE_RATE)
    env = env_exp(n, attack_s, decay_s)
    ratio = 2.0 ** (detune_cents / 1200.0)
    out = [0.0] * n
    two_pi = 2.0 * math.pi
    for i in range(n):
        a = math.sin(two_pi * freq * i / SAMPLE_RATE)
        b = math.sin(two_pi * (freq * ratio) * i / SAMPLE_RATE)
        out[i] = 0.5 * (a + b) * env[i] * amp
    return out


def pitch_drop(start_freq: float, end_freq: float, duration_s: float, *,
               amp: float = 0.55,
               attack_s: float = 0.01,
               decay_s: float = 0.20) -> list[float]:
    """Sine whose frequency glides start → end over the duration."""
    n = int(duration_s * SAMPLE_RATE)
    env = env_exp(n, attack_s, decay_s)
    out = [0.0] * n
    phase = 0.0
    two_pi = 2.0 * math.pi
    for i in range(n):
        t = i / n if n > 0 else 0
        f = start_freq + (end_freq - start_freq) * t
        phase += two_pi * f / SAMPLE_RATE
        out[i] = math.sin(phase) * env[i] * amp
    return out


def noise_burst(duration_s: float, *,
                amp: float = 0.35,
                attack_s: float = 0.001,
                decay_s: float = 0.020,
                lowpass_alpha: float = 0.3) -> list[float]:
    """Filtered white-noise burst → adds attack "click" or "thud" character.

    `lowpass_alpha` 0..1: lower = more bass-heavy (good for thuds), higher = brighter.
    Implemented as a 1-pole IIR: y[n] = a*x[n] + (1-a)*y[n-1].
    """
    n = int(duration_s * SAMPLE_RATE)
    env = env_exp(n, attack_s, decay_s)
    out = [0.0] * n
    prev = 0.0
    for i in range(n):
        x = random.uniform(-1.0, 1.0)
        y = lowpass_alpha * x + (1.0 - lowpass_alpha) * prev
        prev = y
        out[i] = y * env[i] * amp
    return out


# ----------------------------- effects --------------------------------------

def soft_saturate(samples: list[float], gain: float = 1.5) -> list[float]:
    """tanh-based soft clipping. Adds gentle harmonics, prevents harsh clipping."""
    return [math.tanh(s * gain) for s in samples]


def echo(samples: list[float], delay_s: float, feedback: float = 0.25,
         mix: float = 0.35) -> list[float]:
    """Single-tap echo. Returns a list possibly longer than the input."""
    delay = int(delay_s * SAMPLE_RATE)
    tail = int(delay * 3)  # leave room for ~3 echo iterations to decay
    n_out = len(samples) + tail
    out = list(samples) + [0.0] * tail
    delay_buf = [0.0] * delay
    write_pos = 0
    for i in range(n_out):
        dry = out[i] if i < len(out) else 0.0
        wet = delay_buf[write_pos]
        out[i] = dry + wet * mix
        delay_buf[write_pos] = dry + wet * feedback
        write_pos = (write_pos + 1) % delay
    return out


def mix_signals(*chunks: list[float]) -> list[float]:
    """Sum-mix chunks of varying lengths; output length = max(len)."""
    n = max(len(c) for c in chunks)
    out = [0.0] * n
    for c in chunks:
        for i in range(len(c)):
            out[i] += c[i]
    return out


def concat(*chunks: list[float], gap_s: float = 0.0) -> list[float]:
    """Concatenate chunks with optional silent gap between them."""
    gap = [0.0] * int(gap_s * SAMPLE_RATE)
    out: list[float] = []
    for i, c in enumerate(chunks):
        if i > 0 and gap:
            out.extend(gap)
        out.extend(c)
    return out


def overlay_at(base: list[float], chunk: list[float], offset_s: float) -> list[float]:
    """Overlay `chunk` onto `base` starting at offset_s seconds. Extends base if needed."""
    offset = int(offset_s * SAMPLE_RATE)
    needed = offset + len(chunk)
    if needed > len(base):
        base = base + [0.0] * (needed - len(base))
    for i, s in enumerate(chunk):
        base[offset + i] += s
    return base


# ----------------------------- WAV writer -----------------------------------

def write_wav(path: str, samples: list[float]) -> None:
    """Write floats in [-1, 1] as 16-bit PCM mono. Master gain applied here."""
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s * HEADROOM))
            frames.extend(struct.pack("<h", int(v * 32767)))
        w.writeframes(bytes(frames))


# ----------------------------- sound builders -------------------------------

def build_correct() -> list[float]:
    """Bright bell-pluck. Bell at E6 (~1318 Hz) + tick transient + a hint of echo."""
    body = fm_bell(freq=1318.5, duration_s=0.18,
                   mod_ratio=1.4, mod_index_start=3.5,
                   mod_index_decay_s=0.10,
                   attack_s=0.003, decay_s=0.17, amp=0.55)
    tick = noise_burst(0.012, amp=0.35, lowpass_alpha=0.6)
    body = overlay_at(body, tick, offset_s=0.0)
    body = soft_saturate(body, gain=1.05)
    return echo(body, delay_s=0.08, feedback=0.0, mix=0.18)


def build_wrong() -> list[float]:
    """Soft warm thud. Low detuned body + bass thump transient, drops slightly."""
    thump = noise_burst(0.030, amp=0.45, lowpass_alpha=0.10)
    body = pitch_drop(start_freq=190.0, end_freq=140.0,
                      duration_s=0.22, amp=0.55,
                      attack_s=0.008, decay_s=0.21)
    warm = detuned_pair(160.0, duration_s=0.22,
                        detune_cents=12.0, amp=0.35,
                        attack_s=0.008, decay_s=0.21)
    combined = mix_signals(body, warm)
    combined = overlay_at(combined, thump, offset_s=0.0)
    return soft_saturate(combined, gain=1.10)


def build_fail() -> list[float]:
    """Three-note descending sad bell: E5 → B4 → G4. Bigger and slower than wrong."""
    e5 = fm_bell(freq=659.25, duration_s=0.22,
                 mod_ratio=1.41, mod_index_start=3.0,
                 mod_index_decay_s=0.15,
                 attack_s=0.004, decay_s=0.21, amp=0.55)
    b4 = fm_bell(freq=493.88, duration_s=0.22,
                 mod_ratio=1.41, mod_index_start=2.8,
                 mod_index_decay_s=0.15,
                 attack_s=0.004, decay_s=0.21, amp=0.55)
    g4 = fm_bell(freq=392.00, duration_s=0.32,
                 mod_ratio=1.41, mod_index_start=2.6,
                 mod_index_decay_s=0.18,
                 attack_s=0.004, decay_s=0.31, amp=0.60)
    sequence = concat(e5, b4, g4, gap_s=0.025)
    sequence = soft_saturate(sequence, gain=1.05)
    return echo(sequence, delay_s=0.12, feedback=0.10, mix=0.20)


def build_win() -> list[float]:
    """Bright bell arpeggio C5-E5-G5 + chord ring + sparkle."""
    c5 = fm_bell(freq=523.25, duration_s=0.18,
                 mod_ratio=1.4, mod_index_start=3.0,
                 mod_index_decay_s=0.12,
                 attack_s=0.003, decay_s=0.17, amp=0.50)
    e5 = fm_bell(freq=659.25, duration_s=0.18,
                 mod_ratio=1.4, mod_index_start=3.0,
                 mod_index_decay_s=0.12,
                 attack_s=0.003, decay_s=0.17, amp=0.50)
    g5 = fm_bell(freq=783.99, duration_s=0.22,
                 mod_ratio=1.4, mod_index_start=3.2,
                 mod_index_decay_s=0.14,
                 attack_s=0.003, decay_s=0.21, amp=0.52)

    # Final ringing chord (all three notes at once, longer tail)
    chord = mix_signals(
        fm_bell(freq=523.25, duration_s=0.34,
                mod_ratio=1.4, mod_index_start=2.6,
                mod_index_decay_s=0.20,
                attack_s=0.003, decay_s=0.33, amp=0.32),
        fm_bell(freq=659.25, duration_s=0.34,
                mod_ratio=1.4, mod_index_start=2.6,
                mod_index_decay_s=0.20,
                attack_s=0.003, decay_s=0.33, amp=0.32),
        fm_bell(freq=783.99, duration_s=0.34,
                mod_ratio=1.4, mod_index_start=2.6,
                mod_index_decay_s=0.20,
                attack_s=0.003, decay_s=0.33, amp=0.32),
    )

    # Brief high sparkle (noise burst, brighter filter)
    sparkle = noise_burst(0.06, amp=0.18, lowpass_alpha=0.85)

    arpeggio = concat(c5, e5, g5, gap_s=0.01)
    arpeggio = overlay_at(arpeggio, chord, offset_s=0.40)
    arpeggio = overlay_at(arpeggio, sparkle, offset_s=0.42)
    arpeggio = soft_saturate(arpeggio, gain=1.08)
    return echo(arpeggio, delay_s=0.10, feedback=0.15, mix=0.22)


# ----------------------------- main -----------------------------------------

def main() -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    plan = [
        ("correct.wav", build_correct()),
        ("wrong.wav",   build_wrong()),
        ("fail.wav",    build_fail()),
        ("win.wav",     build_win()),
    ]
    for name, samples in plan:
        path = os.path.join(here, name)
        write_wav(path, samples)
        size = os.path.getsize(path)
        duration_ms = int(1000 * len(samples) / SAMPLE_RATE)
        print(f"  {name:<14} {duration_ms:>4} ms   {size:>7,} bytes")


if __name__ == "__main__":
    print("Generating Pictok sound effects v2 (16-bit PCM mono 44.1kHz)...")
    main()
    print("Done.")
