# 꼬마 동무 안쪽 그림(테두리는 gen.py가 자동으로 두른다). 오른쪽을 본다.
# 공통 글자: e 눈동자 · i 눈 반짝임 · p 볼(분홍) · k 테두리색(안쪽 선)
E = '#2a1a14'; I = '#ffffff'; PK = '#f3a0a0'
PETS = []
import math
def _rows(s): return [l for l in s.strip('\n').split('\n')]
def grid(w, h): return [['.'] * w for _ in range(h)]
def stamp(cv, art, x=0, y=0, sep=True):
    H, W = len(cv), len(cv[0]); pts = {}
    for j, row in enumerate(_rows(art) if isinstance(art, str) else art):
        for i, ch in enumerate(row):
            if ch != '.': pts[(x + i, y + j)] = ch
    if sep:
        for (px, py) in pts:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (px + dx, py + dy)
                if q not in pts and 0 <= q[0] < W and 0 <= q[1] < H and cv[q[1]][q[0]] not in '.k':
                    cv[q[1]][q[0]] = 'k'
    for (px, py), ch in pts.items():
        if 0 <= px < W and 0 <= py < H: cv[py][px] = ch
def tail(cv, bx, by, ang, ln, rad, body, tip, tipfrac=.32, sep=True):
    a = math.radians(ang); tx, ty = bx + ln * math.cos(a), by - ln * math.sin(a)
    H, W = len(cv), len(cv[0]); pts = {}
    for y in range(H):
        for x in range(W):
            px, py = x + .5, y + .5; vx, vy = tx - bx, ty - by
            t = max(0, min(1, ((px - bx) * vx + (py - by) * vy) / (vx * vx + vy * vy)))
            d = math.hypot(px - (bx + t * vx), py - (by + t * vy))
            r = rad * (0.55 + 0.75 * math.sin(math.pi * min(1, t * 0.85 + 0.1)))
            if t >= 1 and d > rad * .45: continue
            if d <= r: pts[(x, y)] = tip if t > 1 - tipfrac else body
    rows = [['.'] * W for _ in range(H)]
    for (x, y), ch in pts.items(): rows[y][x] = ch
    stamp(cv, [''.join(r) for r in rows], sep=sep)
def show(cv): return '\n'.join(''.join(r) for r in cv)

def pet(**kw):
    PETS.append(kw)
exec(open(__file__.replace('data.py', 'art1.py')).read())
exec(open(__file__.replace('data.py', 'art2.py')).read())
exec(open(__file__.replace('data.py', 'art3.py')).read())

EFFECTS = {
    'heart': {'pal': {'r': '#e2475a', 'w': '#ff9aa6'}, 'rows': '''
.kk.kk.
krwkrrk
krrrrrk
.krrrk.
..krk..
...k...'''},
    'zz': {'pal': {'z': '#cfe3f2'}, 'rows': '''
zzzz
..z.
.z..
zzzz'''},
    'bowl': {'pal': {'w': '#f4f0e6', 'n': '#8a5a32', 'm': '#b07a46', 'f': '#e9c46a'}, 'rows': '''
.fwfwf.
kkkkkkk
knmmmnk
.knnnk.
..kkk..'''},
    'star': {'pal': {'g': '#f0d070', 'w': '#fff6c8'}, 'rows': '''
..g..
.gwg.
ggwgg
.gwg.
..g..'''},
    'note': {'pal': {'n': '#cfe3f2'}, 'rows': '''
..nnn
..n.n
..n..
nnn..
nnn..'''},
}
