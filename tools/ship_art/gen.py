import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont
import art

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
OUT = os.path.join(ROOT, 'supabase', 'gen_part2', 'ports', 'ships_v2.png')
FONT = '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc'
S = 6
BG = (27, 24, 32)


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def outline(rows):
    h, w = len(rows), max(len(r) for r in rows)
    g = [list(r.ljust(w, '.')) for r in rows]
    out = [r[:] for r in g]
    for y in range(h):
        for x in range(w):
            if g[y][x] != '.':
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and g[yy][xx] not in '.k' and g[yy][xx] not in art.NO_OUTLINE:
                    out[y][x] = 'k'
                    break
    return [''.join(r) for r in out]


def trim(rows):
    ys = [y for y, r in enumerate(rows) if r.strip('.')]
    xs = [x for r in rows for x, c in enumerate(r) if c != '.']
    x0, x1 = min(xs), max(xs)
    return [r[x0:x1 + 1] for r in rows[ys[0]:ys[-1] + 1]]


def bake(rows):
    h, w = len(rows), len(rows[0])
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != '.':
                px[x, y] = rgb(art.PAL[c]) + (255,)
    return im


def main():
    sprites = []
    for name, fn in art.SHIPS:
        rows = trim(outline(fn().rows()))
        used = sorted(set(''.join(rows)) - {'.'})
        print(name, len(rows[0]), 'x', len(rows), 'colors', len({art.PAL[c] for c in used}))
        sprites.append((name, bake(rows)))
    gap = 14
    W = sum(im.width for _, im in sprites) * S + gap * S * (len(sprites) + 1)
    Hs = max(im.height for _, im in sprites) * S
    H = Hs + 24 * S
    sheet = Image.new('RGBA', (W, H), BG + (255,))
    d = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(FONT, 7 * S)
    x = gap * S
    for i, (name, im) in enumerate(sprites):
        big = im.resize((im.width * S, im.height * S), Image.NEAREST)
        y = Hs - big.height + 6 * S
        sheet.alpha_composite(big, (x, y))
        label = f'{i + 1}. {name}'
        tw = d.textlength(label, font=font)
        d.text((x + big.width / 2 - tw / 2, Hs + 9 * S), label, font=font, fill=(232, 224, 206))
        x += big.width + gap * S
    sheet.convert('RGB').save(OUT)
    print(OUT)


if __name__ == '__main__':
    main()
