#!/usr/bin/env python3
"""Genera las pistas de música: menu.wav (canción del menú), day.wav (día) y
tension.wav (votación). NO toca ambient.wav (la música del lobby/noche).
Todo se calcula de forma circular para que el bucle empalme sin cortes.
Requiere numpy. Uso: python3 tool/gen_tracks.py
"""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


class Track:
    def __init__(self, dur, seed):
        self.dur = dur
        self.N = int(SR * dur)
        self.t = np.arange(self.N) / SR
        self.rng = np.random.default_rng(seed)

    def fr(self, f):
        """Frecuencia con ciclos enteros en el bucle (sin clic en el empalme)."""
        return max(1, round(f * self.dur)) / self.dur

    def circ_env(self, center, attack, release):
        d = (self.t - center + self.dur / 2) % self.dur - self.dur / 2
        return np.where(d < 0, np.exp(-(d / attack) ** 2), np.exp(-(d / release) ** 2))

    def lowpass(self, x, cutoff):
        X = np.fft.rfft(x)
        f = np.fft.rfftfreq(len(x), 1 / SR)
        return np.fft.irfft(X / (1 + (f / cutoff) ** 2), n=len(x))

    def pad_voice(self, f, seed):
        out = np.zeros(self.N)
        for k, det in enumerate((-0.0035, 0.0, 0.0035)):
            ff = f * (1 + det)
            ph = (seed + k) * 1.7
            out += np.sin(2 * np.pi * ff * self.t + ph)
            out += 0.28 * np.sin(2 * np.pi * 2 * ff * self.t + ph * 1.3)
            out += 0.10 * np.sin(2 * np.pi * 3 * ff * self.t + ph * 0.7)
        return out / 3

    def pluck(self, start, f, amp, decay=2.0, bright=0.4):
        d = (self.t - start) % self.dur
        env = np.exp(-d * decay) * np.minimum(1, d / 0.008)
        tone = (np.sin(2 * np.pi * f * d) + bright * np.sin(2 * np.pi * 2 * f * d) * np.exp(-d * 3)
                + 0.12 * np.sin(2 * np.pi * 4.02 * f * d) * np.exp(-d * 9))
        return tone * env * amp

    def echo(self, x, taps):
        y = x.copy()
        for delay, g in taps:
            y = y + g * np.roll(x, int(delay * SR))
        return y

    def reverb(self, x, secs=2.6, tau=0.9, mix=0.75):
        n = int(secs * SR)
        ir = self.rng.standard_normal(n) * np.exp(-np.arange(n) / (tau * SR))
        ir = self.lowpass(np.pad(ir, (0, self.N - n)), 3000)[:n]
        ir /= np.sqrt((ir ** 2).sum())
        wet = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir, n=self.N), n=self.N)
        return 0.55 * x + mix * wet

    def finish(self, x, name, cutoff=3800, peak=0.55, edge_fade_ms=0):
        x = self.lowpass(x, cutoff)
        x = x - x.mean()
        x = x / np.max(np.abs(x)) * peak
        if edge_fade_ms:                      # micro-fundido: garantiza empalme sin chasquido
            n = int(SR * edge_fade_ms / 1000)
            ramp = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, n))
            x[:n] *= ramp
            x[-n:] *= ramp[::-1]
        pcm = (x * 32767).astype('<i2').tobytes()
        with wave.open(os.path.join(OUT, name), 'wb') as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm)
        step = float(np.abs(np.diff(x)).mean())
        jump = abs(float(x[0] - x[-1]))
        print(f'{name}: {self.dur:.1f}s, pico {np.max(np.abs(x)):.2f}, empalme {jump:.4f} (paso típico {step:.4f})')


# ------------------------------------------------------------------ MENÚ
def menu():
    bpm = 72
    beat = 60 / bpm
    T = Track(64 * beat, seed=11)
    phrase = 8 * beat
    pads = [[57, 60, 64, 67], [53, 57, 60, 64], [55, 60, 64, 67], [55, 59, 62, 69],
            [57, 60, 64, 67], [53, 57, 60, 64], [53, 57, 62, 65], [52, 56, 59, 64]]
    roots = [45, 41, 48, 43, 45, 41, 38, 40]
    # melodía: (midi, inicio en pulsos dentro de la frase, duración)
    mel = [
        [(76, 0, 1.5), (72, 1.5, .5), (74, 2, 1), (72, 3, 1), (71, 4, 1.5), (69, 5.5, .5), (72, 6, 2)],
        [(77, 0, 1.5), (74, 1.5, .5), (72, 2, 1), (69, 3, 1), (72, 4, 1.5), (74, 5.5, .5), (77, 6, 2)],
        [(79, 0, 1.5), (76, 1.5, .5), (74, 2, 1), (72, 3, 1), (76, 4, 2), (74, 6, 1), (72, 7, 1)],
        [(74, 0, 1.5), (71, 1.5, .5), (67, 2, 1), (71, 3, 1), (74, 4, 2), (79, 6, 2)],
        [(81, 0, 1.5), (79, 1.5, .5), (76, 2, 1), (72, 3, 1), (76, 4, 1.5), (72, 5.5, .5), (69, 6, 2)],
        [(77, 0, 1), (76, 1, 1), (74, 2, 1), (72, 3, 1), (69, 4, 1.5), (72, 5.5, .5), (74, 6, 2)],
        [(74, 0, 1.5), (77, 1.5, .5), (81, 2, 1), (77, 3, 1), (76, 4, 1.5), (74, 5.5, .5), (72, 6, 2)],
        [(76, 0, 1.5), (71, 1.5, .5), (68, 2, 1), (71, 3, 1), (76, 4, 4)],
    ]
    music = np.zeros(T.N)
    for i, chord in enumerate(pads):
        env = T.circ_env(phrase * (i + 0.5), phrase * 0.26, phrase * 0.28)
        for j, m in enumerate(chord):
            lfo = 0.88 + 0.12 * np.sin(2 * np.pi * (0.06 + 0.015 * j) * T.t + j)
            music += T.pad_voice(midi(m), i * 5 + j) * env * lfo * 0.30
        # bajo en los pulsos 1 y 5 de la frase
        for b in (0, 4):
            music += T.pluck(phrase * i + b * beat, midi(roots[i]), 0.55, decay=1.1, bright=0.15)
    lead = np.zeros(T.N)
    for i, notes in enumerate(mel):
        for m, s, d in notes:
            lead += T.pluck(phrase * i + s * beat, midi(m), 0.20, decay=1.6 + 0.4 / max(d, .5))
    lead = T.echo(lead, [(0.75 * beat, 0.34), (1.5 * beat, 0.16)])
    mix = T.reverb(music + lead, secs=2.4, mix=0.7)
    T.finish(mix, 'menu.wav')


# ------------------------------------------------------------------- DÍA
def day():
    bpm = 66
    beat = 60 / bpm
    T = Track(64 * beat, seed=22)
    seg = 16 * beat
    chords = [[60, 64, 67, 71], [55, 59, 62, 66], [57, 60, 64, 67], [53, 57, 60, 64]]  # C G Am F
    roots = [48, 43, 45, 41]
    music = np.zeros(T.N)
    for i, chord in enumerate(chords):
        env = T.circ_env(seg * (i + 0.5), seg * 0.27, seg * 0.29)
        for j, m in enumerate(chord):
            lfo = 0.9 + 0.1 * np.sin(2 * np.pi * (0.05 + 0.02 * j) * T.t + j)
            music += T.pad_voice(midi(m), i * 3 + j) * env * lfo * 0.28
        music += T.pluck(seg * i, midi(roots[i]), 0.5, decay=0.55, bright=0.1)
        music += T.pluck(seg * i + 8 * beat, midi(roots[i]), 0.4, decay=0.7, bright=0.1)
    arp = np.zeros(T.N)
    for i, chord in enumerate(chords):
        tones = [m + 12 for m in chord] + [chord[1] + 24, chord[2] + 12]
        order = [0, 1, 2, 3, 2, 1, 4, 2]
        for k in range(32):                                  # corcheas
            if T.rng.random() < 0.18:
                continue                                      # huecos: no suena mecánico
            m = tones[order[k % len(order)]]
            arp += T.pluck(seg * i + k * 0.5 * beat, midi(m), 0.075, decay=2.6, bright=0.5)
    arp = T.echo(arp, [(0.75 * beat, 0.30)])
    mix = T.reverb(music + arp, secs=2.0, mix=0.6)
    T.finish(mix, 'day.wav', cutoff=4200)


# --------------------------------------------------------------- TENSIÓN
def tension():
    T = Track(30.0, seed=33)
    drone = np.zeros(T.N)
    for f, a in ((73.42, 0.55), (110.0, 0.30), (77.78, 0.32)):         # D2, A2, Eb2 (segunda menor)
        drone += a * np.sin(2 * np.pi * T.fr(f) * T.t)
    drone *= 0.75 + 0.25 * np.sin(2 * np.pi * 2 * T.t / T.dur)         # respiración lenta
    # Cuerdas agudas en cluster, con oleadas
    strings = np.zeros(T.N)
    for k, (f, a) in enumerate(((587.33, 0.10), (622.25, 0.09), (880.0, 0.06), (932.33, 0.05))):
        sw = 0.5 + 0.5 * np.sin(2 * np.pi * (k + 1) * T.t / T.dur + k)
        trem = 0.8 + 0.2 * np.sin(2 * np.pi * T.fr(5.5) * T.t + k)
        strings += a * np.sin(2 * np.pi * T.fr(f) * T.t) * sw * trem
    # Latido: "lub-dub" cada segundo, que se acelera suavemente (dos tempos por ciclo)
    heart = np.zeros(T.N)
    for beat_t in np.arange(0, T.dur, 1.0):
        for off, amp in ((0.0, 1.0), (0.30, 0.65)):
            d = (T.t - (beat_t + off)) % T.dur
            sweep = 85 - 40 * np.minimum(d, 0.25) / 0.25
            heart += amp * np.sin(2 * np.pi * sweep * d) * np.exp(-d * 14) * np.minimum(1, d / 0.004)
    # Tics agudos y escasos
    ticks = np.zeros(T.N)
    for k in range(9):
        s = T.rng.uniform(0, T.dur)
        d = (T.t - s) % T.dur
        ticks += 0.04 * np.sin(2 * np.pi * 1760 * d) * np.exp(-d * 30)
    mix = T.reverb(drone * 0.8 + strings + ticks, secs=2.2, mix=0.65) + 0.55 * heart
    T.finish(mix, 'tension.wav', cutoff=3000, peak=0.40, edge_fade_ms=8)


if __name__ == '__main__':
    menu(); day(); tension()
