#!/usr/bin/env python3
"""Builds the retro filter's palette lookup table (presentation/look/retro_lut.png):
a 32x32x32 colour cube stored as 32 tiles side by side (1024 x 32). Every input
colour maps to the nearest colour of a curated palette made from the game's own
swatches (palette.json) at several shades, plus sky, water, snow, fire and
neutral greys. Rerun after changing palette.json:  python3 tools/gen_retro_lut.py"""
import json, os
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
pal = json.load(open(os.path.join(ROOT, "presentation/look/palette.json")))["rows"]

def hexrgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]

base = []
for row in pal.values():
    base += [hexrgb(h) for h in row]
extra = ["#B8C2C4", "#8FA3B0", "#5F7480", "#3E4E55", "#1E2628", "#E8EEF2", "#C9D2D8",
         "#FFE9B0", "#FFB347", "#E8622C", "#8A2A14", "#F4F1E6", "#0E100E", "#2B2E2A"]
base += [hexrgb(h) for h in extra]
# lit-terrain greens and dry grass the camera actually sees
base += [hexrgb(h) for h in ["#7E9455", "#94A866", "#A9B57A", "#5C7040", "#B5A46E", "#C8C09A", "#8C9D8F"]]
shades = [0.3, 0.45, 0.6, 0.75, 0.9, 1.05, 1.2, 1.4, 1.6]
colors = []
for c in base:
    for s in shades:
        colors.append([min(1.0, v * s) for v in c])
for g in np.linspace(0.04, 0.96, 10):
    colors.append([g, g, g])
P = np.unique(np.round(np.array(colors), 3), axis=0)

N = 32
axis = (np.arange(N) + 0.5) / N
r, g, b = np.meshgrid(axis, axis, axis, indexing="ij")
cube = np.stack([r, g, b], -1).reshape(-1, 3)
# perceptual-ish weighting (luma heavy) so shading survives the snap
w = np.array([0.30, 0.59, 0.11]) ** 0.5
d = (((cube[:, None, :] - P[None, :, :]) * w) ** 2).sum(-1)
nearest = P[d.argmin(1)].reshape(N, N, N, 3)  # [r][g][b]
img = np.zeros((N, N * N, 3))
for bi in range(N):
    # tile bi holds blue slice bi: x = red, y = green
    img[:, bi * N:(bi + 1) * N, :] = nearest[:, :, bi, :].transpose(1, 0, 2)
Image.fromarray((img * 255).round().astype(np.uint8)).save(os.path.join(ROOT, "presentation/look/retro_lut.png"))
print("palette colours:", len(P))
