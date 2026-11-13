#!/usr/bin/env python3
"""Genera la música ambiental (assets/audio/ambient.wav): pad armónico lento con
reverberación y campanas espaciadas, en un bucle SIN cortes (todo se calcula de
forma circular). Requiere numpy. Uso: python3 tool/gen_music.py
"""
import os, wave
import numpy as np

SR = 22050
DUR = 48.0                      # 4 acordes x 12 s
N = int(SR * DUR)
t = np.arange(N) / SR
rng = np.random.default_rng(42)


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# Progresión oscura y calmada: Am9 - Fmaj7 - Dm9 - Em(add9)
chords = [
    [45, 52, 59, 60, 64],   # A2 E3 B3 C4 E4
    [41, 48, 52, 57, 60],   # F2 C3 E3 A3 C4
    [38, 45, 53, 57, 60],   # D2 A2 F3 A3 C4
    [40, 47, 55, 59, 62],   # E2 B2 G3 B3 D4
]
SEG = DUR / len(chords)


def circ_env(center, attack, release, length=N):
    """Envolvente circular suave (campana asimétrica) para que el bucle empalme."""
    d = (t - center + DUR / 2) % DUR - DUR / 2        # distancia circular con signo
    env = np.where(d < 0, np.exp(-(d / attack) ** 2), np.exp(-(d / release) ** 2))
    return env


def lowpass(x, cutoff):
    # filtro de un polo, aplicado en frecuencia (circular => sin clic en el empalme)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / (1 + (f / cutoff) ** 2), n=len(x))


def pad_voice(freq, phase_seed):
    """Tres osciladores ligeramente desafinados con armónicos suaves."""
    out = np.zeros(N)
    for k, det in enumerate((-0.0035, 0.0, 0.0035)):
        f = freq * (1 + det)
        ph = (phase_seed + k) * 1.7
        out += np.sin(2 * np.pi * f * t + ph)
        out += 0.28 * np.sin(2 * np.pi * 2 * f * t + ph * 1.3)
        out += 0.10 * np.sin(2 * np.pi * 3 * f * t + ph * 0.7)
    return out / 3


music = np.zeros(N)
for i, chord in enumerate(chords):
    center = SEG * (i + 0.5)
    env = circ_env(center, attack=SEG * 0.28, release=SEG * 0.30)
    for j, m in enumerate(chord):
        v = pad_voice(midi(m), i * 7 + j)
        lfo = 0.85 + 0.15 * np.sin(2 * np.pi * (0.07 + 0.02 * j) * t + j)   # respiración lenta
        gain = 0.55 if m < 48 else 0.30
        music += v * env * lfo * gain
    # Sub grave suave en la fundamental
    music += 0.35 * np.sin(2 * np.pi * midi(chord[0] - 12) * t) * env

music = lowpass(music, 1800)

# Campanas espaciadas (pentatónica menor de La) con eco
bells = np.zeros(N)
scale = [69, 72, 74, 76, 79, 81]            # A4 C5 D5 E5 G5 A5
for k in range(14):
    start = (k * (DUR / 14) + rng.uniform(0.0, 1.2)) % DUR
    m = int(rng.choice(scale))
    f = midi(m)
    d = (t - start) % DUR
    amp = np.exp(-d * 1.1) * np.minimum(1, d / 0.01)
    tone = np.sin(2 * np.pi * f * d) + 0.35 * np.sin(2 * np.pi * f * 2.76 * d) * np.exp(-d * 2.0)
    bells += tone * amp * 0.07
for delay, g in ((0.45, 0.45), (0.9, 0.22)):  # eco circular
    bells = bells + g * np.roll(bells, int(delay * SR))
bells = lowpass(bells, 4500)

mix = music + bells

# Reverberación: convolución circular con una respuesta de ruido que decae (2.6 s)
ir_len = int(2.6 * SR)
ir = rng.standard_normal(ir_len) * np.exp(-np.arange(ir_len) / (0.9 * SR))
ir = lowpass(np.pad(ir, (0, N - ir_len)), 3000)[:ir_len]
ir /= np.sqrt((ir ** 2).sum())
wet = np.fft.irfft(np.fft.rfft(mix) * np.fft.rfft(ir, n=N), n=N)
out = 0.55 * mix + 0.75 * wet

out = lowpass(out, 3800)                      # quita aspereza
out -= out.mean()
out = out / np.max(np.abs(out)) * 0.55        # volumen contenido

pcm = (out * 32767).astype('<i2').tobytes()
path = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio', 'ambient.wav')
with wave.open(path, 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm)

# Comprobación de empalme del bucle: salto entre última y primera muestra.
jump = abs(float(out[0] - out[-1]))
print(f'ok {DUR:.0f}s, pico {np.max(np.abs(out)):.2f}, salto de empalme {jump:.4f}')
