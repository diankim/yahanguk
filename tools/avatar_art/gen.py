import colorsys, json, pathlib
import data as D

ROOT = pathlib.Path(__file__).resolve().parents[2]


def hx(c):
    return tuple(int(c[i:i + 2], 16) for i in (1, 3, 5))


def shade(c, f):
    r, g, b = [v / 255 for v in hx(c)]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    l = max(0, min(1, l * f))
    s = min(1, s * (1.15 if f < 1 else 0.9))
    return '#%02x%02x%02x' % tuple(int(v * 255) for v in colorsys.hls_to_rgb(h, l, s))


def part(g):
    return g.rows()


out = dict(w=D.W, h=D.H, fixed=D.FIXED)
out['skins'] = {k: dict(name=n, s=c, S=shade(c, .93), T=shade(c, .8)) for k, (n, c) in D.SKINS.items()}
out['hairColors'] = {k: dict(name=n, h=c, H=shade(c, .72), i=shade(c, 1.22), j=shade(c, 1.5), k=shade(c, .84), g=shade(c, 1.1), q=shade(c, .62)) for k, (n, c) in D.HAIR_COLORS.items()}
out['eyeColors'] = {k: dict(name=n, e=c, E=shade(c, .55), f=shade(c, 1.45)) for k, (n, c) in D.EYE_COLORS.items()}
out['body'] = {f: part(D.body(f)) for f in ('stand', 'walk')}
out['hair'] = {k: dict(name=n, back=part(D.hair_back(b)), front=part(D.hair_front(fr, lk, b))) for k, (n, b, fr, lk) in D.HAIRS.items()}
import hair_art as A
for k, (n, fn) in A.ART.items():
    fr, bk = fn()
    out['hair'][k] = dict(name=n, back=part(bk), front=part(fr))
out['hair'] = {k: out['hair'][k] for k in A.ORDER}
out['eyes'] = {k: dict(name=n, open=part(D.eye(k, False)), closed=part(D.eye(k, True))) for k, n in D.EYES.items()}
out['mouth'] = {k: dict(name=n, part=part(D.mouth(k))) for k, n in D.MOUTHS.items()}
tops = {}
import tops_art as T
for k in T.TOPS:
    n, pal, g = T.top_grid(k)
    pal = dict(pal, x=shade(pal['a'], 1.14), y=shade(pal['a'], .74))
    tops[k] = dict(name=n, pal=pal, part=part(g))
out['top'] = tops
bots = {}
for k in T.BOTTOMS:
    n, pal, gs = T.bottom_grid(k, 'stand')
    _, _, gw = T.bottom_grid(k, 'walk')
    pal = dict(pal, x=shade(pal['a'], 1.14), y=shade(pal['a'], .74), u=shade(pal['z'], .7))
    bots[k] = dict(name=n, pal=pal, stand=part(gs), walk=part(gw))
out['bottom'] = bots

FABRIC = 'axyb'


def lum(c):
    r, g, b = [v / 255 for v in hx(c)]
    return colorsys.rgb_to_hls(r, g, b)[1]


def cells(part):
    return [(part['x'] + i, part['y'] + j, ch) for j, r in enumerate(part['rows']) for i, ch in enumerate(r) if ch in FABRIC]


def mask_of(part, pal, deco_set):
    used = set(''.join(part['rows']))
    return dict(n=len(cells(part)), bf=round(lum(pal['b']) / lum(pal['a']), 3), deco=[l for l in deco_set if l in used])


for k, t in tops.items():
    t['mask'] = mask_of(t['part'], t['pal'], 'cde')
for k, bt in bots.items():
    m = mask_of(bt['stand'], bt['pal'], 'dz')
    _, _, gs = T.bottom_grid(k, 'stand')
    _, _, gw = T.bottom_grid(k, 'walk')
    shape = T.BOTTOMS[k][1]
    moved = {}
    for (x, y), ch in sorted(gs.p.items(), key=lambda it: (it[0][1], it[0][0])):
        yy = y - 1 if shape != 'skirt' and x - T.OX < 8 and y >= 30 else y
        moved[(x, yy)] = (x, y)
    assert {pos: gs.p[src] for pos, src in moved.items()} == gw.p, k
    sidx = {(x, y): i for i, (x, y, _) in enumerate(cells(bt['stand']))}
    walk = []
    for x, y, ch in cells(bt['walk']):
        src = moved[(x, y)]
        assert gs.p[src] == ch, k
        walk.append(sidx[src])
    m['walk'] = walk
    bt['mask'] = m
out['acc'] = {}
for k in T.ACC:
    n, pal, gg = T.acc_grid(k)
    out['acc'][k] = dict(name=n, pal=pal, part=part(gg))
out['jobDefault'] = {j: dict(top=t, bottom=b) for j, (t, b) in D.JOB_DEFAULT.items()}
js = 'export const AV = ' + json.dumps(out, ensure_ascii=False, separators=(',', ':')) + ';\n'
(ROOT / 'assets/js/housing/avatar.js').write_text(js)
print(len(js))

FREE = ('skins', 'hair', 'hairColors', 'eyes', 'eyeColors', 'mouth')
parts = {k: sorted(out[k].keys()) for k in FREE}
outfits = {}
for k in T.TOPS:
    outfits['top:' + k] = dict(slot='top', name=T.TOPS[k][0], grade=1)
for k in T.BOTTOMS:
    outfits['bottom:' + k] = dict(slot='bottom', name=T.BOTTOMS[k][0], grade=1)
for k in T.ACC:
    outfits['acc:' + k] = dict(slot='acc', name=T.ACC[k][0], grade=1)
masks = {'top:' + k: dict(n=t['mask']['n'], deco=len(t['mask']['deco'])) for k, t in tops.items()}
masks.update({'bottom:' + k: dict(n=bt['mask']['n'], deco=len(bt['mask']['deco'])) for k, bt in bots.items()})
rules = dict(free=parts, outfits=outfits, job=out['jobDefault'], masks=masks)
(ROOT / 'supabase/gen_avatar').mkdir(exist_ok=True)
(ROOT / 'supabase/gen_avatar/parts.json').write_text(json.dumps(rules, ensure_ascii=False, separators=(',', ':')))
