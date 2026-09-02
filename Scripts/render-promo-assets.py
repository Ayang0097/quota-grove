#!/usr/bin/env python3
"""Render demo data using the packaged app, without changing user preferences."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
app = root / "dist/Quota Grove.app/Contents/MacOS/QuotaGrove"
output = root / "promo/public/cards"
output.mkdir(parents=True, exist_ok=True)

def render(name, percent, *flags, style="quotaGrove"):
    subprocess.run([
        str(app), "-AppleLanguages", "(en)", "--render-preview", str(percent),
        str(output / f"{name}.png"), "--background-style", style, *flags,
    ], check=True)

for percent in [85, 55, 25, 5]:
    render(str(percent), percent)
render("expanded", 55, "--expanded")
render("stashed", 55, "--stashed")
for style in ["astralTerrarium", "cloudseaBeacon", "moonlitConservatory", "abyssalReverie"]:
    render(style, 85, style=style)
