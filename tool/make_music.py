#!/usr/bin/env python3
"""Generates a cheerful, seamlessly looping chiptune track for the game.

Pure standard library (wave + math). Produces assets/music.wav.
"""
import math
import struct
import wave

SR = 22050  # sample rate
BPM = 132
BEAT = 60.0 / BPM
BARS = 16
BEATS = BARS * 4

# Note frequencies (equal temperament), name -> Hz
A4 = 440.0
def note(n):
    # n is semitones from A4
    return A4 * (2 ** (n / 12.0))

# helper by name+octave
NAMES = {'C':-9,'C#':-8,'D':-7,'D#':-6,'E':-5,'F':-4,'F#':-3,'G':-2,'G#':-1,
         'A':0,'A#':1,'B':2}
def nf(name, octave):
    return note(NAMES[name] + (octave - 4) * 12)

def R():
    return 0.0

# Chord progression (I - V - vi - IV) in C major, 4 bars repeated
# Each entry is a bar of 4 beats for the lead melody (freq or 0 for rest)
lead_pattern = [
    # Bar 1 (C)
    nf('E',5), nf('G',5), nf('C',6), nf('G',5),
    # Bar 2 (G)
    nf('D',5), nf('G',5), nf('B',5), nf('D',6),
    # Bar 3 (Am)
    nf('C',5), nf('E',5), nf('A',5), nf('E',5),
    # Bar 4 (F)
    nf('C',5), nf('F',5), nf('A',5), nf('C',6),
    # Bar 5 (C)
    nf('G',5), nf('E',5), nf('C',6), nf('E',6),
    # Bar 6 (G)
    nf('B',5), nf('D',6), nf('G',5), nf('B',5),
    # Bar 7 (Am)
    nf('A',5), nf('C',6), nf('E',6), nf('C',6),
    # Bar 8 (F -> G)
    nf('F',5), nf('A',5), nf('C',6), nf('D',6),
]
# repeat 8-bar phrase twice for 16 bars, second time an octave sparkle
lead = lead_pattern + lead_pattern

# Bass: root note per bar (2 hits per bar)
bass_roots = [
    nf('C',3), nf('G',2), nf('A',2), nf('F',2),
    nf('C',3), nf('G',2), nf('A',2), nf('G',2),
] * 2

def adsr(t, dur, a=0.01, d=0.06, s=0.7, r=0.06):
    if t < a:
        return t / a
    if t < a + d:
        return 1 - (1 - s) * ((t - a) / d)
    if t < dur - r:
        return s
    if t < dur:
        return s * (1 - (t - (dur - r)) / r)
    return 0.0

def square(phase, duty=0.5):
    return 1.0 if (phase % 1.0) < duty else -1.0

def triangle(phase):
    p = phase % 1.0
    return 4 * abs(p - 0.5) - 1

total_samples = int(SR * BEAT * BEATS)
buf = [0.0] * total_samples

# Render lead (one note per beat)
for i, freq in enumerate(lead):
    if freq <= 0:
        continue
    start = int(i * BEAT * SR)
    dur = BEAT * 0.9
    n = int(dur * SR)
    for k in range(n):
        idx = start + k
        if idx >= total_samples:
            break
        t = k / SR
        env = adsr(t, dur)
        phase = freq * t
        # soft square lead
        val = 0.5 * square(phase, 0.5) * env
        buf[idx] += val * 0.28

# Render bass (two hits per bar => every 2 beats)
for bar in range(BARS):
    freq = bass_roots[bar]
    for hit in range(2):
        start = int((bar * 4 + hit * 2) * BEAT * SR)
        dur = BEAT * 1.6
        n = int(dur * SR)
        for k in range(n):
            idx = start + k
            if idx >= total_samples:
                break
            t = k / SR
            env = adsr(t, dur, a=0.005, d=0.1, s=0.6, r=0.1)
            val = triangle(freq * t) * env
            buf[idx] += val * 0.32

# Simple hi-hat/percussion on off-beats using short noise bursts
import random
random.seed(7)
for beat in range(BEATS):
    start = int((beat + 0.5) * BEAT * SR)
    dur = 0.04
    n = int(dur * SR)
    for k in range(n):
        idx = start + k
        if idx >= total_samples:
            break
        t = k / SR
        env = max(0.0, 1 - t / dur)
        buf[idx] += (random.uniform(-1, 1)) * env * 0.05

# Normalize and add gentle crossfade at the loop boundary for seamlessness
fade = int(0.02 * SR)
for k in range(fade):
    g = k / fade
    buf[k] *= g
    buf[total_samples - 1 - k] *= g

peak = max(1e-6, max(abs(v) for v in buf))
scale = 0.9 / peak

with wave.open('assets/music.wav', 'w') as wf:
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(SR)
    frames = bytearray()
    for v in buf:
        s = int(max(-1.0, min(1.0, v * scale)) * 32767)
        frames += struct.pack('<h', s)
    wf.writeframes(bytes(frames))

print('wrote assets/music.wav', total_samples, 'samples', round(total_samples / SR, 1), 's')
