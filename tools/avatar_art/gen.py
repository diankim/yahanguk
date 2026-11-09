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
out['skins'] = {k: dict(name=n, s=c, S=shade(c, .9)) for k, (n, c) in D.SKINS.items()}
out['hairColors'] = {k: dict(name=n, h=c, H=shade(c, .72), i=shade(c, 1.22), k=shade(c, .84)) for k, (n, c) in D.HAIR_COLORS.items()}
out['eyeColors'] = {k: dict(name=n, e=c, E=shade(c, .55), f=shade(c, 1.45)) for k, (n, c) in D.EYE_COLORS.items()}
out['body'] = {f: part(D.body(f)) for f in ('stand', 'walk')}
out['hair'] = {k: dict(name=n, back=part(D.hair_back(b)), front=part(D.hair_front(fr, lk))) for k, (n, b, fr, lk) in D.HAIRS.items()}
out['eyes'] = {k: dict(name=n, open=part(D.eye(k, False)), closed=part(D.eye(k, True))) for k, n in D.EYES.items()}
out['mouth'] = {k: dict(name=n, part=part(D.mouth(k))) for k, n in D.MOUTHS.items()}
tops = {}
for k, (n, fn) in D.TOPS.items():
    g, pal = fn()
    tops[k] = dict(name=n, pal=pal, part=part(g))
out['top'] = tops
bots = {}
for k, (n, kind, a, b, z) in D.BOTTOMS.items():
    make, pal = D.bottom_def(kind, a, b, z)
    bots[k] = dict(name=n, pal=pal, stand=part(make('stand')), walk=part(make('walk')))
out['bottom'] = bots
out['acc'] = {}
out['jobDefault'] = {j: dict(top=t, bottom=b) for j, (t, b) in D.JOB_DEFAULT.items()}
js = 'export const AV = ' + json.dumps(out, ensure_ascii=False, separators=(',', ':')) + ';\n'
(ROOT / 'assets/js/housing/avatar.js').write_text(js)
print(len(js))

FREE = ('skins', 'hair', 'hairColors', 'eyes', 'eyeColors', 'mouth')
parts = {k: sorted(out[k].keys()) for k in FREE}
outfits = {}
for k, (n, _) in D.TOPS.items():
    outfits['top:' + k] = dict(slot='top', name=n, grade=1)
for k, (n, *_r) in D.BOTTOMS.items():
    outfits['bottom:' + k] = dict(slot='bottom', name=n, grade=1)
rules = dict(free=parts, outfits=outfits, job=out['jobDefault'])
(ROOT / 'supabase/gen_avatar').mkdir(exist_ok=True)
(ROOT / 'supabase/gen_avatar/parts.json').write_text(json.dumps(rules, ensure_ascii=False, separators=(',', ':')))
