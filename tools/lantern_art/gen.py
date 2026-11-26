import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
OUT = os.path.join(ROOT, 'supabase', 'gen_part2', 'ports', 'lanterns_v1.png')
FONT = '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc'
W, H, S = 24, 26, 8

SHAPES = [('round', '둥근 등', art.ROUND), ('cho', '청사초롱', art.CHO),
          ('lotus', '연꽃 등', art.LOTUS), ('fish', '물고기 등', art.FISH)]

def rows(s):
    out = []
    for l in s.strip('\n').split('\n'):
        out.append(l + l[::-1] if len(l) == 11 else l)
    w = max(len(x) for x in out)
    return [x.ljust(w, '.') for x in out]

def outline(r):
    h, w = len(r), len(r[0])
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

def compose(src):
    spr = outline(rows(src))
    grid = [['.'] * W for _ in range(H)]
    wl = H - len(art.WATER)
    top = wl + 2 - len(spr)
    left = (W - len(spr[0])) // 2
    for y, line in enumerate(spr):
        for x, ch in enumerate(line):
            yy, xx = top + y, left + x
            if ch != '.' and 0 <= yy < H and 0 <= xx < W:
                grid[yy][xx] = ch
    for y, line in enumerate(art.WATER):
        line = line.center(W, '.')
        for x, ch in enumerate(line[:W]):
            if ch != '.' and grid[wl + y][x] == '.':
                grid[wl + y][x] = ch
    return grid

def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

def render(grid, pal):
    im = Image.new('RGBA', (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch == '.':
                continue
            c = pal.get(ch) or art.FIXED.get(ch)
            if c is None:
                raise SystemExit('no color ' + ch)
            d.rectangle([x * S, y * S, x * S + S - 1, y * S + S - 1], fill=hexrgb(c))
    return im

def main():
    lab, pad = 150, 24
    cw, ch = W * S + pad, H * S + pad
    head = 50
    sheet = Image.new('RGB', (lab + cw * 4 + pad, head + ch * len(SHAPES) + pad), (14, 22, 38))
    dr = ImageDraw.Draw(sheet)
    f = ImageFont.truetype(FONT, 24)
    keys = list(art.COLORS)
    for i, k in enumerate(keys):
        dr.text((lab + pad + i * cw + 60, 14), art.COLORS[k]['name'], fill=(220, 214, 196), font=f)
    for j, (key, name, src) in enumerate(SHAPES):
        grid = compose(src)
        y0 = head + j * ch
        dr.text((16, y0 + ch // 2 - 14), name, fill=(220, 214, 196), font=f)
        for i, k in enumerate(keys):
            x0 = lab + pad + i * cw
            dr.rectangle([x0 - 4, y0 - 4, x0 + W * S + 3, y0 + H * S + 3], fill=(20, 32, 54))
            wl = (H - len(art.WATER)) * S + S + S // 2
            dr.rectangle([x0 - 4, y0 + wl, x0 + W * S + 3, y0 + H * S + 3], fill=(16, 38, 66))
            im = render(grid, art.COLORS[k])
            sheet.paste(im, (x0, y0), im)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print(OUT)

main()
