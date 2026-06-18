#!/usr/bin/env python3
"""Generate Kairō's coastal app icon (1024×1024, no alpha — App Store safe).

The mark is Kairō's signature half-disc ◐ — read here as a sun setting into the
ocean (the *kairos* golden moment, recast coastal). Coral→peach lit half on a
deep-ocean gradient with a soft coral glow: the "Sunset" hero theme distilled.

Rendered at 4× then downscaled (LANCZOS) for smooth edges. Run:
    python3 scripts/make_appicon.py
Writes ios/Kairo/Assets.xcassets/AppIcon.appiconset/icon-1024.png
"""
from __future__ import annotations
import math
import os
from PIL import Image, ImageDraw, ImageChops

S = 1024            # final size
SS = 4              # supersample factor
R = S * SS          # render size

# --- coastal palette ----------------------------------------------------------
OCEAN_TOP    = (0x12, 0x3A, 0x3D)   # deep teal (top of bg)
OCEAN_BOTTOM = (0x05, 0x15, 0x18)   # near-black ocean (bottom of bg)
UNLIT        = (0x0A, 0x25, 0x28)   # unlit half of the disc
LIT_TOP      = (0xFF, 0xA8, 0x86)   # warm peach (top of sun)
LIT_BOTTOM   = (0xEC, 0x63, 0x42)   # coral (bottom of sun)
RING         = (0xFF, 0x8C, 0x6B)   # coral ring + glow
TERMINATOR   = (0xFF, 0xD8, 0xC2)   # bright edge where lit meets unlit


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vgrad(size, top, bottom):
    """Vertical gradient as a full RGB image."""
    col = Image.new("RGB", (1, size))
    for y in range(size):
        col.putpixel((0, y), lerp(top, bottom, y / (size - 1)))
    return col.resize((size, size))


def radial_alpha(size, cx, cy, radius, falloff=1.6):
    """Soft radial mask (L), 255 at center → 0 at `radius`."""
    G = 320
    g = Image.new("L", (G, G), 0)
    px = g.load()
    for y in range(G):
        for x in range(G):
            d = math.hypot(x - cx * G, y - cy * G) / (radius * G)
            px[x, y] = max(0, min(255, int(255 * (1 - d) ** falloff))) if d < 1 else 0
    return g.resize((size, size))


def main():
    # background: deep-ocean vertical gradient
    img = vgrad(R, OCEAN_TOP, OCEAN_BOTTOM)

    # soft coral sunset glow, low-centre (sun haze on the water)
    glow = radial_alpha(R, 0.5, 0.56, 0.62, falloff=1.9)
    glow = glow.point(lambda a: int(a * 0.30))
    coral = Image.new("RGB", (R, R), RING)
    img = Image.composite(coral, img, glow)

    # --- the half-disc -------------------------------------------------------
    r = int(R * 0.305)
    cx, cy = R // 2, int(R * 0.5)
    bbox = [cx - r, cy - r, cx + r, cy + r]

    circle = Image.new("L", (R, R), 0)
    ImageDraw.Draw(circle).ellipse(bbox, fill=255)

    left = Image.new("L", (R, R), 0)
    ImageDraw.Draw(left).rectangle([0, 0, cx, R], fill=255)
    right = ImageChops.invert(left)

    lit_mask = ImageChops.multiply(circle, left)
    unlit_mask = ImageChops.multiply(circle, right)

    img = Image.composite(Image.new("RGB", (R, R), UNLIT), img, unlit_mask)
    img = Image.composite(vgrad(R, LIT_TOP, LIT_BOTTOM), img, lit_mask)

    # bright terminator edge (subtle depth at the lit/unlit seam)
    seam = Image.new("L", (R, R), 0)
    sw = int(R * 0.010)
    ImageDraw.Draw(seam).rectangle([cx - sw, 0, cx + sw, R], fill=255)
    seam = ImageChops.multiply(seam, circle).point(lambda a: int(a * 0.55))
    img = Image.composite(Image.new("RGB", (R, R), TERMINATOR), img, seam)

    # coral ring around the whole disc
    ImageDraw.Draw(img).ellipse(bbox, outline=RING, width=int(R * 0.019))

    # soft top-left highlight on the lit half for dimensionality
    hl = radial_alpha(R, 0.40, 0.40, 0.18, falloff=2.2)
    hl = ImageChops.multiply(hl, lit_mask).point(lambda a: int(a * 0.22))
    img = Image.composite(Image.new("RGB", (R, R), (255, 240, 230)), img, hl)

    out = img.resize((S, S), Image.LANCZOS).convert("RGB")  # flatten alpha
    dest = os.path.join(
        os.path.dirname(__file__), "..",
        "ios/Kairo/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
    )
    out.save(os.path.abspath(dest), "PNG")
    print("wrote", os.path.abspath(dest))


if __name__ == "__main__":
    main()
