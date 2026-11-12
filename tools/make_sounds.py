#!/usr/bin/env python3
"""Синтез всех звуков игры: python3 tools/make_sounds.py → папка sfx/.
Никаких чужих сэмплов: всё собирается из синусов, шума и щипковой струны."""
import numpy as np, wave, os
from scipy.signal import butter, lfilter

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "sfx")
rng = np.random.default_rng(2026)

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, d=0.1, curve=4.0):
    x = np.arange(n) / SR
    att = np.clip(x / max(a, 1e-4), 0, 1)
    return att * np.exp(-curve * np.maximum(x - a, 0) / max(d, 1e-4))
def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), hi / (SR / 2)], "band"); return lfilter(b, a, x)
def lp(x, f, order=2):
    b, a = butter(order, f / (SR / 2), "low"); return lfilter(b, a, x)
def hp(x, f, order=2):
    b, a = butter(order, f / (SR / 2), "high"); return lfilter(b, a, x)
def noise(n): return rng.uniform(-1, 1, n)
def norm(x, peak=0.8):
    m = np.max(np.abs(x)); return x * (peak / m) if m > 0 else x
def fade(x, ms=6):
    k = min(len(x) // 2, int(SR * ms / 1000)); x = x.copy()
    x[:k] *= np.linspace(0, 1, k); x[-k:] *= np.linspace(1, 0, k); return x
def save(name, x, peak=0.8, edges=True):
    x = norm(x, peak)
    if edges: x = fade(x)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())

def pluck(freq, dur, bright=0.5, decay=0.996):
    """Щипковая струна (Карплус — Стронг): звучит как балалайка/домра."""
    n = int(SR * dur); p = max(2, int(SR / freq))
    buf = lp(noise(p), 1500 + bright * 6000) if p > 12 else noise(p)
    out = np.zeros(n); b = buf.copy()
    for i in range(n):
        j = i % p
        out[i] = b[j]
        b[j] = decay * 0.5 * (b[j] + b[(j + 1) % p])
    return out * env(n, 0.002, dur * 0.6, 2.5)

def bell(freq, dur, partials=((1, 1), (2.76, 0.4), (5.4, 0.2))):
    x = t(dur); y = sum(a * np.sin(2 * np.pi * freq * m * x) * np.exp(-x * (3 + m * 2)) for m, a in partials)
    return y * env(len(x), 0.002, dur, 1.0)

# ── Интерфейс ──
save("click", np.sin(2 * np.pi * 950 * t(0.07)) * env(int(SR * 0.07), 0.001, 0.025, 1) + 0.3 * bp(noise(int(SR * 0.07)), 2000, 5000) * env(int(SR * 0.07), 0.001, 0.01, 1), 0.6)
x = t(0.12); save("beep", np.sin(2 * np.pi * 880 * x) * env(len(x), 0.003, 0.12, 2), 0.5)
x = t(0.35); save("go", (np.sin(2 * np.pi * 1320 * x) + 0.3 * np.sin(2 * np.pi * 1980 * x)) * env(len(x), 0.003, 0.3, 2), 0.55)

# ── Пчела ──
x = t(0.06); f = np.linspace(700, 1400, len(x)); save("pop", np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(x), 0.002, 0.05, 2), 0.45)
save("chime", bell(1046, 0.8) + 0.6 * np.concatenate([np.zeros(int(SR * 0.08)), bell(1318, 0.72)]), 0.6)
big = np.zeros(int(SR * 1.3))
for i, f in enumerate([523, 659, 784, 1046, 1318]):
    s = int(SR * 0.09 * i); b = bell(f, 0.9); big[s:s + len(b)] += b[:len(big) - s]
save("big_chime", big, 0.65)
x = t(0.22); save("thud", (np.sin(2 * np.pi * np.cumsum(np.linspace(180, 60, len(x))) / SR) + 0.5 * lp(noise(len(x)), 600)) * env(len(x), 0.002, 0.08, 1.5), 0.75)
n = int(SR * 0.3); f = np.linspace(400, 2400, n); w = noise(n)
save("whoosh", bp(w, 300, 3000) * np.sin(np.linspace(0, np.pi, n)) ** 2, 0.5)
n = int(SR * 0.12); save("flap", bp(noise(n), 400, 1800) * np.sin(np.linspace(0, np.pi, n)), 0.4)
save("ring", bell(1568, 0.6, ((1, 1), (2.0, 0.5), (3.0, 0.25))), 0.55)
# Оса отжала: «хоп» вниз
x = t(0.25); save("steal", np.sign(np.sin(2 * np.pi * np.cumsum(np.linspace(500, 180, len(x))) / SR)) * 0.4 * env(len(x), 0.005, 0.2, 2), 0.45)
# Липко: хлюп
x = t(0.35); save("jam", lp(np.sin(2 * np.pi * np.cumsum(220 + 160 * np.sin(np.linspace(0, 9, len(x)))) / SR), 900) * env(len(x), 0.01, 0.3, 2), 0.55)

# ── Дачник ──
n = int(SR * 0.14); save("slap", (hp(noise(n), 900) * env(n, 0.0005, 0.03, 1) + 0.4 * np.sin(2 * np.pi * 160 * t(0.14)) * env(n, 0.001, 0.05, 1)), 0.85)
n = int(SR * 0.1); save("sting", (bp(noise(n), 3000, 8000) * env(n, 0.001, 0.03, 1) + 0.5 * np.sin(2 * np.pi * 2100 * t(0.1)) * env(n, 0.001, 0.06, 1)), 0.6)
n = int(SR * 0.6); save("puff", lp(noise(n), 700) * env(n, 0.03, 0.5, 2), 0.6)
save("jar", bell(2600, 0.35, ((1, 1), (1.32, 0.6), (2.1, 0.3))), 0.5)
# Мотор: чих-пых, разгоняется
n = int(SR * 1.6); x = t(1.6); rate = np.linspace(9, 22, n); ph = np.cumsum(rate) / SR
pulse = (np.sin(2 * np.pi * ph) > 0.6).astype(float)
eng = lp(pulse * (0.6 + 0.4 * noise(n)), 500) + 0.3 * np.sin(2 * np.pi * np.cumsum(np.linspace(45, 90, n)) / SR)
save("car", eng * np.minimum(1, x * 3), 0.7)

# ── Итоги ──
win = np.zeros(int(SR * 1.4))
for i, f in enumerate([392, 523, 659, 784, 1046]):
    s = int(SR * 0.11 * i); p = pluck(f, 0.9, 0.8); win[s:s + len(p)] += p[:len(win) - s]
save("win", win, 0.7)
lose = np.zeros(int(SR * 1.6))
for i, f in enumerate([392, 370, 349, 294]):
    x = t(0.5 if i < 3 else 0.9); vib = 1 + 0.012 * np.sin(2 * np.pi * 5.5 * x)
    saw = lp(2 * ((np.cumsum(f * vib) / SR) % 1) - 1, 1400)
    s = int(SR * 0.36 * i); seg = saw * env(len(x), 0.03, 0.4 if i < 3 else 0.8, 1.2)
    lose[s:s + len(seg)] += seg[:len(lose) - s]
save("lose", lose, 0.6)

# ── Жужжание (петли — целое число периодов, чтобы не щёлкало) ──
def buzz(f0, dur, fm=6.0, depth=4.0, bright=2600):
    x = t(dur); f = f0 + depth * np.sin(2 * np.pi * fm * x)
    saw = 2 * ((np.cumsum(f) / SR) % 1) - 1
    y = lp(saw, bright) + 0.15 * lp(noise(len(x)), 3000)
    return y
save("buzz", buzz(220, 1.0), 0.5, edges=False)
sw = sum(buzz(f, 2.0, fm, d, 1800) for f, fm, d in [(180, 5, 5), (205, 6, 4), (232, 7, 6), (251, 4, 3)])
save("swarm", sw, 0.5, edges=False)

# ── Голос деда: слоги «бу-бу-бу» из формант ──
VOWELS = {"а": (700, 1220), "о": (500, 900), "у": (320, 800), "э": (520, 1700), "ы": (360, 1500), "е": (450, 1900)}
def syllable(vowel, pitch, dur=0.13, consonant="b"):
    x = t(dur); f = pitch * (1 + 0.04 * np.sin(2 * np.pi * 7 * x)) * np.linspace(1.04, 0.96, len(x))
    glott = 2 * ((np.cumsum(f) / SR) % 1) - 1
    glott = glott ** 3
    f1, f2 = VOWELS[vowel]
    y = bp(glott, f1 * 0.75, f1 * 1.3) + 0.6 * bp(glott, f2 * 0.8, f2 * 1.2)
    e = env(len(x), 0.015, dur * 0.7, 1.6)
    y = y * e
    if consonant == "b":
        y[: int(SR * 0.012)] *= np.linspace(0, 1, int(SR * 0.012)) ** 2
    elif consonant == "m":
        y += 0.4 * lp(glott, 400) * env(len(x), 0.005, 0.04, 1)
    elif consonant == "h":
        k = int(SR * 0.03); y[:k] += 0.3 * bp(noise(k), 1000, 4000)
    return y
for i, (v, c) in enumerate([("у", "b"), ("а", "m"), ("о", "b"), ("э", "h"), ("ы", "m"), ("а", "b"), ("е", "m"), ("о", "h")]):
    save("ded%d" % i, syllable(v, 118 + (i % 3) * 9, 0.12 + (i % 2) * 0.03, c), 0.7)

# ── Музыка ──
def song(bpm, bars, chords, melody, mel_oct=2.0, bass_vol=0.55, swing=0.0):
    beat = 60 / bpm; total = int(SR * beat * 4 * bars); out = np.zeros(total + SR * 2)
    def put(sig, at, vol):
        s = int(SR * at); out[s:s + len(sig)] += sig * vol
    notes = {"A": 220.0, "B": 246.94, "C": 261.63, "D": 293.66, "E": 329.63, "F": 349.23, "G": 392.0}
    for bar in range(bars):
        root, kind = chords[bar % len(chords)]
        r = notes[root] / 2
        third = r * (2 ** (3 / 12) if kind == "m" else 2 ** (4 / 12)); fifth = r * 1.5
        for b4 in range(4):
            at = (bar * 4 + b4) * beat
            if b4 % 2 == 0:
                put(pluck(r / 2 if b4 == 0 else fifth / 2, beat * 1.8, 0.2, 0.995), at, bass_vol)
            else:
                for k, f in enumerate([r * 2, third * 2, fifth * 2]):
                    put(pluck(f, beat * 0.9, 0.5, 0.993), at + k * 0.012, 0.22)
            # Тремоло-«дрожь» как у балалайки на сильных долях
    pos = 0.0
    for (deg, length) in melody:
        if deg is not None:
            f = notes["A"] * mel_oct * 2 ** (deg / 12)
            n_strokes = max(1, int(length * 4)) if length >= 1 else 1
            for k in range(n_strokes):
                put(pluck(f, min(length * beat, 1.2), 0.85, 0.994), (pos + k * 0.25) * beat, 0.3 if k == 0 else 0.16)
        pos += length
    # Шейкер
    for i in range(bars * 8):
        put(hp(noise(int(SR * 0.04)), 5000) * env(int(SR * 0.04), 0.001, 0.02, 1), i * beat / 2 + (swing * beat / 2 if i % 2 else 0), 0.05 if i % 2 else 0.08)
    loop = out[:total].copy()
    tail = out[total:total + SR]
    loop[:len(tail)] += tail  # хвост нот переходит в начало — петля без шва
    return loop

# Пасека: неспешный дачный вальс-полечка, ля минор / до мажор
menu_mel = [(0, 1), (3, 1), (7, 1), (5, 1), (3, 2), (0, 2), (2, 1), (3, 1), (5, 1), (7, 1), (5, 4),
            (7, 1), (8, 1), (10, 1), (8, 1), (7, 2), (3, 2), (5, 1), (3, 1), (2, 1), (-2, 1), (0, 4)]
save("music_menu", song(96, 8, [("A", "m"), ("D", "m"), ("G", ""), ("C", ""), ("F", ""), ("D", "m"), ("E", ""), ("A", "m")], menu_mel, 2.0, swing=0.15), 0.55, edges=False)
# Игра: бодрая плясовая
act_mel = [(7, 0.5), (7, 0.5), (8, 0.5), (10, 0.5), (12, 1), (10, 1), (8, 0.5), (7, 0.5), (5, 0.5), (3, 0.5), (5, 2),
           (3, 0.5), (5, 0.5), (7, 0.5), (8, 0.5), (10, 1), (8, 1), (7, 0.5), (5, 0.5), (3, 0.5), (2, 0.5), (0, 2),
           (7, 0.5), (7, 0.5), (8, 0.5), (10, 0.5), (12, 1), (15, 1), (14, 0.5), (12, 0.5), (10, 0.5), (8, 0.5), (7, 2),
           (5, 0.5), (7, 0.5), (8, 0.5), (7, 0.5), (5, 1), (3, 1), (2, 0.5), (3, 0.5), (2, 0.5), (-2, 0.5), (0, 2)]
save("music_game", song(138, 8, [("A", "m"), ("A", "m"), ("D", "m"), ("E", ""), ("A", "m"), ("G", ""), ("E", ""), ("A", "m")], act_mel, 2.0, 0.6), 0.55, edges=False)
print("готово:", sorted(os.listdir(OUT)))
