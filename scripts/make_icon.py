#!/usr/bin/env python3
"""Renders the Color Gate Rush app icon (1024x1024, opaque) with Pillow.

Usage: python3 scripts/make_icon.py ColorGateRush/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
The artwork is fully procedural: three neon gates in perspective and an orb with a speed trail.
"""
import math
import sys
from PIL import Image, ImageDraw, ImageFilter

S = 1024
SS = 2  # supersampling factor for smooth edges
W = S * SS

CRIMSON = (255, 61, 97)
AMBER = (255, 189, 36)
LIME = (92, 237, 107)
AZURE = (46, 163, 255)
VIOLET = (189, 102, 255)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background():
    img = Image.new("RGB", (W, W))
    px = ImageDraw.Draw(img)
    top, bottom = (10, 8, 34), (52, 22, 112)
    for y in range(W):
        px.line([(0, y), (W, y)], fill=lerp(top, bottom, y / W))
    # Horizon glow.
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.ellipse([W * 0.05, W * 0.18, W * 0.95, W * 0.52], fill=(140, 90, 255, 150))
    glow = glow.filter(ImageFilter.GaussianBlur(W * 0.06))
    img.paste(glow, (0, 0), glow)
    return img


def neon_layer(draw_fn, blur):
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    return layer.filter(ImageFilter.GaussianBlur(blur)), layer


def composite(base, draw_fn, blur):
    glow, sharp = neon_layer(draw_fn, blur)
    base.alpha_composite(glow)
    base.alpha_composite(glow)
    base.alpha_composite(sharp)


def gate(draw, cx, cy, w, h, color, width):
    r = int(h * 0.18)
    draw.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], radius=r, outline=color + (255,), width=width)


def main(out):
    img = background().convert("RGBA")
    horizon = (W / 2, W * 0.34)

    # Track rails converging on the horizon.
    def rails(d):
        for lx, col, wd in [(-0.62, (150, 130, 255), 14), (0.62, (150, 130, 255), 14), (-0.2, (180, 170, 255), 5), (0.2, (180, 170, 255), 5)]:
            d.line([(W / 2 + lx * W * 1.05, W * 1.02), horizon], fill=col + (200,), width=wd * SS // 2 * 2)
    composite(img, rails, 10)

    # Three gates receding: far violet, middle lime, near amber; plus the target gate (azure) the orb flies into.
    gates = [
        (0.45, VIOLET, 0.22),
        (0.58, AMBER, 0.38),
        (0.76, AZURE, 0.62),
    ]
    for t, color, scale in gates:
        cy = horizon[1] + (W * 0.98 - horizon[1]) * (t - 0.34) / 0.66
        w = W * scale * 0.95
        h = w * 0.62

        def draw_gate(d, cy=cy, w=w, h=h, color=color, scale=scale):
            gate(d, W / 2, cy, w, h, color, int(34 * scale * SS))
        composite(img, draw_gate, 22 * scale * SS)

    # Orb with trail.
    ox, oy, r = W / 2, W * 0.70, W * 0.105

    def trail(d):
        steps = 26
        for i in range(steps):
            t = i / steps
            rr = r * (1 - t) * 0.9
            yy = oy + r * 0.6 + t * W * 0.32
            a = int(220 * (1 - t))
            col = lerp(AZURE, (255, 255, 255), 0.2)
            d.ellipse([ox - rr, yy - rr * 0.6, ox + rr, yy + rr * 0.6], fill=col + (a,))
    composite(img, trail, 18 * SS)

    def orb(d):
        d.ellipse([ox - r, oy - r, ox + r, oy + r], fill=AZURE + (255,))
    composite(img, orb, 40 * SS)

    # Diamond symbol on the orb (azure's shape) and a specular highlight.
    d = ImageDraw.Draw(img)
    s = r * 0.48
    d.polygon([(ox, oy - s), (ox + s * 0.78, oy), (ox, oy + s), (ox - s * 0.78, oy)], fill=(255, 255, 255, 255))
    d.ellipse([ox - r * 0.55, oy - r * 0.78, ox - r * 0.05, oy - r * 0.48], fill=(255, 255, 255, 140))

    # Corner sparkle accents in the other gate colors.
    for (x, y, col) in [(0.16, 0.16, CRIMSON), (0.86, 0.22, LIME)]:
        def sparkle(dd, x=x, y=y, col=col):
            cx, cy, rr = W * x, W * y, W * 0.022
            dd.polygon([(cx, cy - rr * 2), (cx + rr * 0.5, cy), (cx, cy + rr * 2), (cx - rr * 0.5, cy)], fill=col + (255,))
            dd.polygon([(cx - rr * 2, cy), (cx, cy + rr * 0.5), (cx + rr * 2, cy), (cx, cy - rr * 0.5)], fill=col + (255,))
        composite(img, sparkle, 8 * SS)

    final = img.convert("RGB").resize((S, S), Image.LANCZOS)
    final.save(out, "PNG")
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png")
