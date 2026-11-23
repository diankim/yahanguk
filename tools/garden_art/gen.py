import os, json, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'js', 'housing', 'garden_art.js')

def rows(s):
    return [l for l in s.strip('\n').split('\n')]

def outline(r):
    h, w = len(r), max(len(x) for x in r)
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

spr = {k: outline(rows(v)) for k, v in art.CROPS.items()}
spr['sprout1'] = outline(rows(art.SPROUT1))
spr['sprout2'] = outline(rows(art.SPROUT2))
spr['rot'] = outline(rows(art.ROT))
spr['scarecrow'] = outline(rows(art.SCARECROW))
spr['crow'] = outline(rows(art.CROW))
with open(OUT, 'w') as f:
    f.write('export const GPAL = ' + json.dumps(art.PAL, ensure_ascii=False) + ';\n')
    f.write('export const GSPR = ' + json.dumps(spr, ensure_ascii=False, separators=(',', ':')) + ';\n')
print(OUT)
