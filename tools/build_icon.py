#!/usr/bin/env python3
"""Convert icon/icon_zst.pcx into the GEOS 1 VisMoniker bitmap resources."""
from pathlib import Path
import struct
import sys

PC_PALETTE = [
    (0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170),
    (170, 0, 0), (170, 0, 170), (170, 85, 0), (170, 170, 170),
    (85, 85, 85), (85, 85, 255), (85, 255, 85), (85, 255, 255),
    (255, 85, 85), (255, 85, 255), (255, 255, 85), (255, 255, 255),
]
TRANSPARENT = 0
SIZES = {
    5: (64, 40, 0x46, True),
    6: (64, 40, 0x41, False),
    7: (48, 30, 0x46, True),
    8: (48, 30, 0x41, False),
    9: (64, 18, 0x61, False),
    10: (48, 14, 0x61, False),
}


def read_pcx(path):
    data = path.read_bytes()
    if len(data) < 897 or data[0] != 10 or data[2] != 1 or data[3] != 8 or data[65] != 1:
        raise SystemExit("Icon muss ein 8-Bit-Indextabelle-PCX mit einer Ebene sein")
    xmin, ymin, xmax, ymax = struct.unpack_from("<4H", data, 4)
    w, h = xmax - xmin + 1, ymax - ymin + 1
    stride = struct.unpack_from("<H", data, 66)[0]
    if data[-769] != 12 or stride < w:
        raise SystemExit("PCX-Daten oder Farbtabelle sind unvollständig")
    raw = bytearray()
    i, end = 128, len(data) - 769
    while i < end and len(raw) < stride * h:
        b = data[i]
        i += 1
        if b >= 0xC0:
            n, b = b & 0x3F, data[i]
            i += 1
            raw.extend([b] * n)
        else:
            raw.append(b)
    if len(raw) < stride * h:
        raise SystemExit("PCX-Bilddaten sind abgeschnitten")
    pal = [tuple(data[-768 + 3 * j:-765 + 3 * j]) for j in range(256)]
    image = [list(raw[y * stride:y * stride + w]) for y in range(h)]
    return image, pal


def nearest(rgb):
    return min(range(16), key=lambda n: sum((rgb[k] - PC_PALETTE[n][k]) ** 2 for k in range(3)))


def resize_fit(src, width, height):
    sh, sw = len(src), len(src[0])
    scale = min(width / sw, height / sh)
    nw, nh = max(1, round(sw * scale)), max(1, round(sh * scale))
    ox, oy = (width - nw) // 2, (height - nh) // 2
    out = [[TRANSPARENT] * width for _ in range(height)]
    for y in range(nh):
        sy = min(sh - 1, int(y * sh / nh))
        for x in range(nw):
            sx = min(sw - 1, int(x * sw / nw))
            out[oy + y][ox + x] = src[sy][sx]
    return out


def packbits(row):
    out, i = bytearray(), 0
    while i < len(row):
        j = i
        while j + 1 < len(row) and row[j + 1] == row[i] and j - i < 127:
            j += 1
        if j - i + 1 >= 3:
            out.extend((257 - (j - i + 1), row[i]))
            i = j + 1
            continue
        literal = bytearray()
        while i < len(row) and len(literal) < 128:
            if i + 2 < len(row) and row[i] == row[i + 1] == row[i + 2]:
                break
            literal.append(row[i])
            i += 1
        out.append(len(literal) - 1)
        out.extend(literal)
    return out


def make_moniker(image, palette, width, height, vmtype, color):
    img = resize_fit(image, width, height)
    bitmap = bytearray()
    for row in img:
        if color:
            mask = bytearray((width + 7) // 8)
            pixels = bytearray((width + 1) // 2)
            for x, idx in enumerate(row):
                opaque = idx != TRANSPARENT
                if opaque:
                    mask[x // 8] |= 0x80 >> (x % 8)
                col = nearest(palette[idx]) if opaque else 15
                pixels[x // 2] |= col << 4 if x % 2 == 0 else col
            packed_row = mask + pixels
        else:
            packed_row = bytearray((width + 7) // 8)
            for x, idx in enumerate(row):
                if idx != TRANSPARENT and sum(palette[idx]) < 3 * 128:
                    packed_row[x // 8] |= 0x80 >> (x % 8)
        bitmap.extend(packbits(packed_row))
    btype = 0x11 if color else 0x00
    bmp = struct.pack("<HHBB", width, height, 1, btype) + bitmap
    return struct.pack("<BHH", vmtype, width, height) + b"\x1a" + struct.pack("<H", len(bmp)) + bmp + b"\0"


def main():
    source = Path(sys.argv[1])
    outdir = Path(sys.argv[2])
    outdir.mkdir(parents=True, exist_ok=True)
    image, palette = read_pcx(source)
    for resid, (w, h, kind, color) in SIZES.items():
        target = outdir / f"mon_{resid}.bin"
        target.write_bytes(make_moniker(image, palette, w, h, kind, color))
        print(f"{target}: {w}x{h}")


if __name__ == "__main__":
    main()

