import os, sys
from freetype import *
sizes = [(40*64, "h1"), (32*64, "h2"), (32*48, "h3"), (24*36, "p")]
if __name__ == '__main__':
    face = Face('./JetBrainsMonoNL-Regular.ttf')
    for (size, name) in sizes:
        face.set_char_size(size)
        buf = []
        for c in range(0x20, 0x7F):
            face.load_glyph(face.get_char_index(c))
            slot = face.glyph
            bitmap = slot.bitmap
            data, rows, width = bitmap.buffer, bitmap.rows, bitmap.width
            buf += [width, rows, slot.bitmap_left, slot.bitmap_top] + bitmap.buffer
        f = open(f"rast/jb-{name}.txt", "wb")
        f.write(bytes(buf))

