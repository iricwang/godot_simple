"""程序化生成 plinko 音效 — 5 个短 wav。
直接用 struct 写 PCM 16-bit mono，避免依赖 numpy/scipy。
"""
import struct
import math
import os

OUT_DIR = r"D:\AI_Temp\gf_test\modules\plinko_game\sfx"
SR = 44100  # sample rate


def write_wav(path: str, samples: list[float]) -> None:
    """写 16-bit PCM mono wav。samples 取值 -1..1。"""
    # 软裁剪
    pcm = bytearray()
    for s in samples:
        v = max(-1.0, min(1.0, s))
        pcm += struct.pack("<h", int(v * 32767))
    data_size = len(pcm)
    # RIFF 头
    with open(path, "wb") as f:
        f.write(b"RIFF")
        f.write(struct.pack("<I", 36 + data_size))
        f.write(b"WAVE")
        f.write(b"fmt ")
        f.write(struct.pack("<I", 16))            # fmt 块大小
        f.write(struct.pack("<H", 1))             # PCM
        f.write(struct.pack("<H", 1))             # mono
        f.write(struct.pack("<I", SR))
        f.write(struct.pack("<I", SR * 2))        # byte rate
        f.write(struct.pack("<H", 2))             # block align
        f.write(struct.pack("<H", 16))            # bits/sample
        f.write(b"data")
        f.write(struct.pack("<I", data_size))
        f.write(bytes(pcm))


def env(i: int, total: int, attack: float = 0.005, release: float = 0.05) -> float:
    """ADSR 简化版：起音 + 指数衰减。"""
    t = i / SR
    T = total / SR
    if t < attack:
        return t / attack
    # 指数衰减到末尾接近 0
    decay_t = (t - attack) / max(1e-6, T - attack)
    return math.exp(-decay_t * 4.0) * (1.0 - decay_t) ** 2 if decay_t < 1.0 else 0.0


def tone(freq: float, dur: float, type_: str = "sine", vol: float = 0.8,
         freq_end: float | None = None) -> list[float]:
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        # 频率滑音
        f = freq if freq_end is None else freq + (freq_end - freq) * (i / n)
        phase = 2.0 * math.pi * f * t
        if type_ == "sine":
            s = math.sin(phase)
        elif type_ == "square":
            s = 1.0 if math.sin(phase) >= 0 else -1.0
        elif type_ == "triangle":
            s = (2.0 / math.pi) * math.asin(math.sin(phase))
        elif type_ == "saw":
            s = 2.0 * ((f * t) - math.floor(0.5 + f * t))
        else:
            s = math.sin(phase)
        out.append(s * vol * env(i, n))
    return out


def noise(dur: float, vol: float = 0.4, lp: float = 0.5) -> list[float]:
    """白噪 + 简单一阶低通，得到柔和噪声。"""
    n = int(dur * SR)
    out = []
    prev = 0.0
    for i in range(n):
        s = (1.0 if (hash(str(i)) & 1) else -1.0)  # 伪随机
        # 一阶 IIR 低通
        prev = prev + lp * (s - prev)
        out.append(prev * vol * env(i, n, attack=0.002, release=0.05))
    return out


def mix(*tracks: list[float]) -> list[float]:
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    # 归一
    peak = max(1e-6, max(abs(v) for v in out))
    if peak > 0.95:
        out = [v * (0.95 / peak) for v in out]
    return out


# 1) drop — 短促"咚"，200Hz 衰减正弦 + 一点低频
drop = mix(
    tone(180, 0.12, "sine", vol=0.7, freq_end=80),
    tone(360, 0.08, "sine", vol=0.25, freq_end=200),
)

# 2) peg_hit — 金属短促 click，1200Hz square 衰减很快
peg_hit = mix(
    tone(1200, 0.05, "square", vol=0.4, freq_end=600),
    tone(800, 0.04, "sine", vol=0.3, freq_end=400),
    noise(0.02, vol=0.15, lp=0.4),
)

# 3) score — 金币叮：C5 → E5 → G5，短的 sine
score = mix(
    tone(523.25, 0.10, "sine", vol=0.45),       # C5
    tone(659.25, 0.10, "sine", vol=0.45)[int(0.05 * SR):],   # E5
    tone(783.99, 0.18, "sine", vol=0.50)[int(0.10 * SR):],   # G5
)

# 4) button — 短促咔哒，700Hz 极短 square
button = mix(
    tone(700, 0.04, "square", vol=0.35, freq_end=500),
    noise(0.02, vol=0.10, lp=0.6),
)

# 5) win — 上行琶音 C5 E5 G5 C6，每音 0.12s，最后 0.25s 拖
win = mix(
    tone(523.25, 0.16, "sine", vol=0.45),
    tone(659.25, 0.16, "sine", vol=0.45)[int(0.10 * SR):],
    tone(783.99, 0.16, "sine", vol=0.45)[int(0.20 * SR):],
    tone(1046.50, 0.40, "sine", vol=0.50)[int(0.30 * SR):],
)

# 6) game_over — 下行三连
game_over = mix(
    tone(659.25, 0.20, "sine", vol=0.45, freq_end=523.25),
    tone(523.25, 0.20, "sine", vol=0.45, freq_end=392.00)[int(0.18 * SR):],
    tone(392.00, 0.45, "sine", vol=0.50, freq_end=261.63)[int(0.36 * SR):],
)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    files = {
        "drop.wav": drop,
        "peg_hit.wav": peg_hit,
        "score.wav": score,
        "button.wav": button,
        "win.wav": win,
        "game_over.wav": game_over,
    }
    for name, samples in files.items():
        path = os.path.join(OUT_DIR, name)
        write_wav(path, samples)
        print(f"  wrote {name}  ({len(samples)/SR:.3f}s)")


if __name__ == "__main__":
    main()
