"""Makes assets/textures/waterfall.png: soft vertical white streaks on transparency, tiling top to bottom.
Used by the waterfall Beams (tools/build_map.luau). Run: python tools/make_water_texture.py"""
import os
import random

import numpy as np
from PIL import Image

W, H = 128, 256
rng = random.Random(5)
alpha = np.zeros((H, W), dtype=float)
for _ in range(26):
    x = rng.uniform(0, W)
    width = rng.uniform(2, 7)
    phase, strength = rng.uniform(0, 1), rng.uniform(0.35, 0.9)
    cols = np.arange(W)
    dx = np.minimum(abs(cols - x), W - abs(cols - x))  # wraps left to right
    profile = np.clip(1 - dx / width, 0, 1) ** 1.5
    rows = np.arange(H)
    wave = 0.6 + 0.4 * np.sin(2 * np.pi * (rows / H * rng.choice((1, 2, 3)) + phase))  # tiles top to bottom
    alpha = np.maximum(alpha, np.outer(wave, profile) * strength)
alpha = np.clip(alpha + 0.18, 0, 1)
rgb = np.stack([np.full((H, W), 235), np.full((H, W), 248), np.full((H, W), 255)], axis=-1)
image = np.dstack([rgb, (alpha * 255)]).astype(np.uint8)
os.makedirs("assets/textures", exist_ok=True)
Image.fromarray(image, "RGBA").save("assets/textures/waterfall.png")
print("saved assets/textures/waterfall.png")
