import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont
import art

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
OUT = os.path.join(ROOT, 'supabase', 'gen_part2', 'ports', 'feast_v1.png')
FONT = '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc'
BG = {'A': '#2b2030', 'a': '#3a2a36', 'W': '#1f2c40', 'V': '#34465e', 'T': '#5a4a3a',
      'P': '#4a3424', 'O': '#38261a', 'F': '#2e2018', 'S': '#241812', 'q': '#f4d27a', 'Q': '#fff2b8', 'y': '#e8c34a'}
PAL = dict(art.PAL)
for k, v in BG.items():
    PAL.setdefault(k, v)
SW, SH = 88, 54
TX0, TX1 = 8, 79
TY0, TY1 = 18, 35
INSET = 3


def rows(s):
    return [l for l in s.strip('\n').split('\n')]


def outline(r):
    h, w = len(r), max(len(x) for x in r)
    r = [x.ljust(w, '.') for x in r]
    g = [['.'] * (w + 2) for _ in range(h + 2)]
    for y, line in enumerate(r):
        for x, ch in enumerate(line):
            g[y + 1][x + 1] = ch
    out = [row[:] for row in g]
    for y in range(h + 2):
        for x in range(w + 2):
            if g[y][x] != '.':
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w + 2 and 0 <= yy < h + 2 and g[yy][xx] not in '.k':
                    out[y][x] = 'k'
                    break
    return [''.join(r) for r in out]


def grid(w, h, ch='.'):
    return [[ch] * w for _ in range(h)]


def put(dst, spr, ox, oy):
    for y, line in enumerate(spr):
        for x, ch in enumerate(line):
            if ch != '.' and 0 <= oy + y < len(dst) and 0 <= ox + x < len(dst[0]):
                dst[oy + y][ox + x] = ch


def span(y):
    t = (y - TY0) / (TY1 - TY0)
    ins = round(INSET * (1 - t))
    return TX0 + ins, TX1 - ins


def table():
    g = grid(SW, SH)
    for y in range(TY0, TY1 + 1):
        a, b = span(y)
        for x in range(a, b + 1):
            c = 'r'
            if y == TY0:
                c = 'L'
            elif y == TY0 + 1 and x < (a + b) // 2:
                c = 'L'
            elif x == a:
                c = 'L'
            elif x == b:
                c = 'R'
            elif y == TY1:
                c = 'R'
            g[y][x] = c
    for y in range(TY1 + 1, TY1 + 4):
        for x in range(TX0, TX1 + 1):
            g[y][x] = 'R' if y < TY1 + 3 else 'D'
        g[y][TX0] = 'r'
    for x in range(TX0 + 2, TX1 - 1):
        g[TY1 + 2][x] = 'Z' if (x - TX0) % 6 else 'y'
    legs = [(TX0 + 2, True), (TX1 - 4, False)]
    for lx, left in legs:
        for i, y in enumerate(range(TY1 + 4, TY1 + 14)):
            off = 0
            if i >= 7:
                off = (-1 if left else 1) * (i - 6)
            w = 3 if i < 8 else 2
            for j in range(w):
                x = lx + off + j + (0 if left or i < 8 else 1)
                g[y][x] = 'r' if j == 0 else ('D' if j == w - 1 else 'R')
    for lx in (TX0 + 9, TX1 - 11):
        for y in range(TY1 + 4, TY1 + 8):
            g[y][lx] = 'D'
            g[y][lx + 1] = 'D'
    return outline([''.join(r) for r in g])[1:-1]


def seats():
    out = []
    for row, sy in ((0, TY0 + 5), (1, TY0 + 14)):
        a, b = span(sy)
        sp = (b - a) / 6
        for i in range(6):
            out.append((round(a + sp * i + sp / 2), sy))
    return out


ORDER = [2, 9, 4, 7, 0, 11, 5, 6, 1, 10, 3, 8]
DSPR = {k: outline(rows(v)) for k, v in art.DISH.items()}


def bg(lit):
    g = grid(SW, SH, 'A')
    for y in range(0, 6):
        for x in range(SW):
            if (x * 7 + y * 13) % 41 == 0:
                g[y][x] = 'a'
    for y in range(12, 17):
        for x in range(SW):
            g[y][x] = 'W'
            if (x + y * 5) % 9 == 0 and y > 12:
                g[y][x] = 'V'
    for x in range(SW):
        g[11][x] = 'T'
    if lit:
        for y in range(13, 17):
            for x in range(SW):
                if (x * 3 + y * 7) % 11 == 0:
                    g[y][x] = 'q'
    for y in range(17, SH):
        for x in range(SW):
            band = (y - 17) // 4
            g[y][x] = 'P' if band % 2 == 0 else 'O'
            if (y - 17) % 4 == 3:
                g[y][x] = 'F'
            if (x + band * 11) % 23 == 0 and (y - 17) % 4 != 3:
                g[y][x] = 'F'
    for y in range(TY1 + 13, TY1 + 16):
        for x in range(TX0 - 2, TX1 + 4):
            if y < SH:
                g[y][x] = 'S'
    return g


LANT_OFF = """
.k.
kRk
RDR
DDD
.R.
"""
LANT_ON = """
.y.
LqL
qQq
rqr
.y.
"""


def garland(g, lit):
    xs = list(range(4, SW - 2, 8))
    for x in range(SW):
        y = 3 + round(1.6 * abs(((x % 8) - 4) / 4) * -1 + 1.6)
        g[y][x] = 'e'
    l = outline(rows(LANT_ON if lit else LANT_OFF))
    for x in xs:
        put(g, l, x - 2, 4)
        if lit:
            for dx, dy in ((-3, 6), (3, 6), (0, 9)):
                xx, yy = x + dx, 4 + dy
                if 0 <= xx < SW and g[yy][xx] in 'Aa':
                    g[yy][xx] = 'a'


def sparkle(g, x, y, big):
    pts = [(0, 0)] + ([(1, 0), (-1, 0), (0, 1), (0, -1)] if big else [])
    for dx, dy in pts:
        xx, yy = x + dx, y + dy
        if 0 <= xx < SW and 0 <= yy < SH:
            g[yy][xx] = 'Q' if (dx, dy) == (0, 0) else 'q'


PLAQUE = """
ZyyyyyyyZ
y{a}{a}{a}{a}{a}{a}{a}y
y{b}{a}{a}{a}{a}{a}{b}y
ZyyyyyyyZ
"""


def scene(dishes, kind=None):
    full = len(dishes) >= 12
    g = bg(full)
    garland(g, full)
    put(g, table(), 0, 0)
    st = seats()
    placed = {ORDER[i]: d for i, d in enumerate(dishes)}
    for idx in sorted(range(12)):
        sx, sy = st[idx]
        if idx not in placed:
            for dx in (-3, 3):
                g[sy][sx + dx] = 'R'
            for dx in range(-2, 3):
                g[sy - 1][sx + dx] = 'R'
                g[sy + 1][sx + dx] = 'R'
            g[sy + 1][sx - 1] = 'L'
            g[sy + 1][sx] = 'L'
            continue
    for idx in range(12):
        if idx not in placed:
            continue
        d = placed[idx]
        spr = DSPR[d]
        w, h = len(spr[0]), len(spr)
        ox, oy = st[idx][0] - w // 2, st[idx][1] + 2 - h
        put(g, spr, ox, oy)
        if d in art.STEAMY:
            put(g, art.STEAM, ox + w // 2 - 2 + (idx % 2), oy - 4)
    if kind:
        k = art.KINDS[kind]
        p = PLAQUE.replace('{a}', k['tag']).replace('{b}', k['tag2'])
        p = rows(p)
        put(g, outline(p), (TX0 + TX1) // 2 - 5, TY1 + 1)
    if full:
        for (x, y, b) in [(4, 22, True), (83, 20, True), (6, 33, False), (82, 31, False), (20, 10, False),
                          (68, 9, False), (44, 9, True), (2, 40, False), (85, 41, True), (30, 12, False), (58, 12, True)]:
            sparkle(g, x, y, b)
    return g


def render(g, sc):
    h, w = len(g), len(g[0])
    im = Image.new('RGBA', (w * sc, h * sc), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for y in range(h):
        for x in range(w):
            ch = g[y][x]
            if ch == '.':
                continue
            d.rectangle([x * sc, y * sc, x * sc + sc - 1, y * sc + sc - 1], fill=PAL[ch])
    return im


def main():
    S = 6
    font = ImageFont.truetype(FONT, 22)
    small = ImageFont.truetype(FONT, 18)
    sw, sh = SW * S, SH * S
    gap = 24
    cols = 3
    top = 250
    W = cols * sw + (cols + 1) * gap
    scenes = [('빈 상', []), ('4그릇', ['meat', 'namul', 'fish', 'soup']),
              ('8그릇', ['meat', 'namul', 'fish', 'soup', 'rice', 'tteok', 'meat', 'rice']),
              ('12그릇 · 고기상', art.KINDS['meat']['dishes']),
              ('12그릇 · 소반', art.KINDS['soban']['dishes']),
              ('12그릇 · 바다상', art.KINDS['sea']['dishes'])]
    kinds = [None, None, None, 'meat', 'soban', 'sea']
    H = top + 2 * (sh + 40) + 3 * gap
    im = Image.new('RGB', (W, H), '#1c1418')
    d = ImageDraw.Draw(im)
    d.text((gap, 12), '나눔 잔칫상 시안 v1 · 그릇 여섯 (칸 8배)', font=font, fill='#f4d27a')
    x = gap
    for k in ['meat', 'fish', 'namul', 'rice', 'tteok', 'soup']:
        spr = [list(r) for r in DSPR[k]]
        top_pad = 5
        g = [['.'] * len(spr[0]) for _ in range(top_pad)] + spr
        if k in art.STEAMY:
            put(g, art.STEAM, len(spr[0]) // 2 - 2, 0)
        b = render(g, 10)
        im.paste(b, (x, 185 - b.height), b)
        d.text((x, 192), art.NAMES[k], font=small, fill='#e8dcc8')
        x += b.width + 60
    for i, ((name, dishes), kind) in enumerate(zip(scenes, kinds)):
        c, r = i % cols, i // cols
        px = gap + c * (sw + gap)
        py = top + r * (sh + 40 + gap)
        sim = render(scene(dishes, kind), S)
        im.paste(sim, (px, py + 34), sim)
        d.text((px, py + 4), name, font=font, fill='#f4d27a')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    im.save(OUT)
    print(OUT, im.size)


main()
