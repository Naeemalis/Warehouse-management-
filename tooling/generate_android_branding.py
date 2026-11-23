#!/usr/bin/env python3
"""Generate the NaeemSoft WMS Android launcher icon using only Python stdlib."""
from pathlib import Path
import struct
import zlib
import xml.etree.ElementTree as ET

ROOT = Path("android/app/src/main")
ANDROID = "{http://schemas.android.com/apk/res/android}"

# 5x7 bitmap glyphs, deliberately simple for legibility at launcher size.
GLYPHS = {
    "N": ["10001", "11001", "11001", "10101", "10011", "10011", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
}

def png_chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xffffffff)

def make_icon(size):
    navy = (15, 35, 65, 255)
    panel = (23, 53, 91, 255)
    gold = (244, 190, 70, 255)
    white = (245, 248, 252, 255)
    img = [[navy for _ in range(size)] for _ in range(size)]

    def rect(x0, y0, x1, y1, color):
        x0, y0 = max(0, int(x0)), max(0, int(y0))
        x1, y1 = min(size, int(x1)), min(size, int(y1))
        for yy in range(y0, y1):
            for xx in range(x0, x1):
                img[yy][xx] = color

    # Rounded-square silhouette.
    radius = int(size * .19)
    for y in range(size):
        for x in range(size):
            cx = radius if x < radius else size-radius-1 if x >= size-radius else x
            cy = radius if y < radius else size-radius-1 if y >= size-radius else y
            if (x-cx)**2 + (y-cy)**2 > radius**2:
                img[y][x] = (0, 0, 0, 0)
    pad = int(size * .13)
    rect(pad, pad, size-pad, size-pad, panel)

    # Warehouse roof and shelving.
    t = max(2, int(size * .035))
    left, right = int(size*.25), int(size*.75)
    top, base = int(size*.25), int(size*.62)
    # Roof chevron
    for i in range(int(size*.17)):
        rect(left+i, top+i//2, left+i+t, top+i//2+t, gold)
        rect(right-i-t, top+i//2, right-i, top+i//2+t, gold)
    rect(left, int(size*.43), right, int(size*.43)+t, gold)
    rect(left, int(size*.60), right, int(size*.60)+t, gold)
    # Boxes on two shelves
    for bx in (int(size*.31), int(size*.49), int(size*.64)):
        rect(bx, int(size*.34), bx+int(size*.10), int(size*.42), white)
        rect(bx, int(size*.50), bx+int(size*.10), int(size*.58), white)
        rect(bx+int(size*.045), int(size*.34), bx+int(size*.055), int(size*.42), gold)

    # NS monogram centered in the lower field.
    cell = max(2, int(size*.018))
    glyph_w, glyph_h = 5*cell, 7*cell
    gap = cell*2
    start_x = (size - (glyph_w*2+gap))//2
    start_y = int(size*.70)
    for gi, letter in enumerate(("N", "S")):
        ox = start_x + gi*(glyph_w+gap)
        for row, bits in enumerate(GLYPHS[letter]):
            for col, bit in enumerate(bits):
                if bit == "1":
                    rect(ox+col*cell, start_y+row*cell,
                         ox+(col+1)*cell, start_y+(row+1)*cell, gold)

    raw = b"".join(b"\x00" + bytes(channel for pixel in row for channel in pixel) for row in img)
    return (b"\x89PNG\r\n\x1a\n"
            + png_chunk(b"IHDR", struct.pack(">2I5B", size, size, 8, 6, 0, 0, 0))
            + png_chunk(b"IDAT", zlib.compress(raw, 9))
            + png_chunk(b"IEND", b""))

def main():
    manifest = ROOT / "AndroidManifest.xml"
    tree = ET.parse(manifest)
    app = tree.getroot().find("application")
    if app is None:
        raise SystemExit("AndroidManifest.xml has no application element")
    app.set(ANDROID + "label", "NaeemSoft WMS")
    app.set(ANDROID + "icon", "@mipmap/ic_launcher")
    tree.write(manifest, encoding="utf-8", xml_declaration=True)

    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in densities.items():
        target = ROOT / "res" / folder
        target.mkdir(parents=True, exist_ok=True)
        (target / "ic_launcher.png").write_bytes(make_icon(size))
    print("Configured NaeemSoft WMS app label and generated launcher icons.")

if __name__ == "__main__":
    main()
