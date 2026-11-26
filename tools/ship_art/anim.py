import os, sys, json, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont
import art
from gen import outline, rgb, FONT, BG

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
OUT_DIR = os.path.join(ROOT, 'supabase', 'gen_part2', 'ports')
N = 12
MS = 140
S = 6
PAD = 3
BOB = [0.0, 2.1, 4.0, 1.2, 3.1]
PUFF = [0, 1, 1, 1, 0, 0, -1, -1, 0, 0, 1, 0]
LIT = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 0, 1]


def frame_grid(fn, si, f):
    t = 2 * math.pi * f / N + BOB[si]
    dy = round(1.4 * math.sin(t))
    tilt = round(1.0 * math.sin(t + math.pi / 2))
    art.ANIM.update(water=False, phase=0, puff=PUFF[(f + si * 2) % N],
                    flag=(f + si) % 4, lit=LIT[(f + si * 3) % N])
    cv = fn()
    x0, x1, yw, tb, rows = art.ANIM['wargs']
    xm, half = (x0 + x1) / 2, (x1 - x0) / 2
    H = cv.h + PAD * 2
    out = art.Canvas(cv.w, H)

    bow = x1 - max(3, round(half * 0.1))

    def sh(x):
        if x >= bow:
            return dy - tilt
        return dy

    for y, row in enumerate(cv.g):
        for x, c in enumerate(row):
            if c != '.':
                out.put(x, y + PAD + sh(x), c)
    bots = {x: b + PAD + sh(x) for x, b in tb[1].items()}
    art.ANIM.update(water=True, phase=f)
    wcv = art.Canvas(cv.w, H)
    art.water(wcv, x0, x1, yw + PAD, (None, bots), rows)
    for y, row in enumerate(wcv.g):
        for x, c in enumerate(row):
            if c != '.':
                out.put(x, y, c)
    art.ANIM.update(water=True, phase=0, puff=0, flag=0, lit=0)
    return outline(out.rows()), yw + PAD + 1


def all_frames():
    ships = []
    for si, (name, fn) in enumerate(art.SHIPS):
        frames = []
        base = None
        for f in range(N):
            g, base = frame_grid(fn, si, f)
            frames.append(g)
        ships.append((name, frames, base))
    return ships


def bake(rows):
    im = Image.new('RGBA', (len(rows[0]), len(rows)), (0, 0, 0, 0))
    px = im.load()
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != '.':
                px[x, y] = rgb(art.PAL[c]) + (255,)
    return im


def layout(ships):
    gap = 12
    above = max(base for _, _, base in ships)
    below = max(len(fr[0]) - base for _, fr, base in ships)
    W = sum(len(fr[0][0]) for _, fr, _ in ships) + gap * (len(ships) + 1)
    pos, x = [], gap
    for _, fr, base in ships:
        pos.append((x, above - base))
        x += len(fr[0][0]) + gap
    return W, above + below, pos


def make_gif(ships):
    W, Hc, pos = layout(ships)
    font = ImageFont.truetype(FONT, 7 * S)
    frames = []
    for f in range(N):
        sheet = Image.new('RGBA', (W * S, (Hc + 16) * S), BG + (255,))
        d = ImageDraw.Draw(sheet)
        for i, ((name, fr, _), (px, py)) in enumerate(zip(ships, pos)):
            im = bake(fr[f]).resize((len(fr[f][0]) * S, len(fr[f]) * S), Image.NEAREST)
            sheet.alpha_composite(im, (px * S, py * S))
            label = f'{i + 1}. {name}'
            tw = d.textlength(label, font=font)
            d.text((px * S + im.width / 2 - tw / 2, (Hc + 4) * S), label, font=font, fill=(232, 224, 206))
        frames.append(sheet.convert('RGB'))
    out = os.path.join(OUT_DIR, 'ships_bob.gif')
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=MS, loop=0, disposal=1, optimize=False)
    return out


HTML = """<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>교역선 둥실</title>
<style>
html,body{margin:0;background:#1b1820;color:#e8e0ce;font-family:system-ui,sans-serif}
.wrap{padding:16px;box-sizing:border-box;width:100%}
canvas{display:block;width:100%;height:auto;image-rendering:pixelated;image-rendering:crisp-edges}
</style></head><body><div class="wrap"><canvas id="c"></canvas></div>
<script>
const D = __DATA__;
const cv = document.getElementById('c');
const ctx = cv.getContext('2d');
let S = 6, f = 0;
function size() {
  const w = cv.parentElement.clientWidth;
  S = Math.max(1, Math.floor(w * (window.devicePixelRatio || 1) / D.W));
  cv.width = D.W * S;
  cv.height = (D.H + 16) * S;
  draw();
}
function draw() {
  ctx.fillStyle = '#1b1820';
  ctx.fillRect(0, 0, cv.width, cv.height);
  D.ships.forEach((s, i) => {
    const g = s.frames[f];
    for (let y = 0; y < g.length; y++) {
      const r = g[y];
      for (let x = 0; x < r.length; x++) {
        const c = r[x];
        if (c === '.') continue;
        ctx.fillStyle = D.pal[c];
        ctx.fillRect((s.x + x) * S, (s.y + y) * S, S, S);
      }
    }
    ctx.fillStyle = '#e8e0ce';
    ctx.font = (7 * S) + 'px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText((i + 1) + '. ' + s.name, (s.x + g[0].length / 2) * S, (D.H + 11) * S);
  });
}
window.addEventListener('resize', size);
size();
setInterval(() => { f = (f + 1) % D.n; draw(); }, D.ms);
</script></body></html>
"""


def make_html(ships):
    W, Hc, pos = layout(ships)
    data = {'W': W, 'H': Hc, 'n': N, 'ms': MS, 'pal': art.PAL,
            'ships': [{'name': n, 'x': p[0], 'y': p[1], 'frames': fr} for (n, fr, _), p in zip(ships, pos)]}
    out = os.path.join(OUT_DIR, 'ships_bob.html')
    with open(out, 'w') as fh:
        fh.write(HTML.replace('__DATA__', json.dumps(data, ensure_ascii=False, separators=(',', ':'))))
    return out


if __name__ == '__main__':
    ships = all_frames()
    print(make_gif(ships))
    print(make_html(ships))
