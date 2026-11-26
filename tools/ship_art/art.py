PAL = {
    'k': '#1a120e',
    'a': '#ebb676', 'b': '#c4884e', 'c': '#9c6438', 'd': '#704228', 'e': '#4a2a1a', 'f': '#1a120e',
    'm': '#c4884e', 'M': '#704228',
    's': '#fff6dc', 't': '#f1dca4', 'T': '#d8b672', 'S': '#a88650', 'x': '#4a2a1a',
    'w': '#fbfaf3', 'W': '#e6e4da', 'X': '#c3c0b4', 'Z': '#918d82',
    'r': '#8a6a4a',
    'g': '#7f8aa6', 'h': '#565d78', 'H': '#383d52',
    'R': '#e0483a', 'Q': '#a32a22', 'P': '#ffb84a',
    'y': '#ffe27a', 'Y': '#ffb84a',
    'j': '#3f9a8c', 'J': '#2a6a66', 'i': '#ffe27a',
    'u': '#2c5b86', 'U': '#4a86b6', 'v': '#cfeaf6', 'V': '#4a86b6', 'n': '#383d52',
}

NO_OUTLINE = set('uUvVnr')

ANIM = {'water': True, 'phase': 0, 'puff': 0, 'flag': 0, 'lit': 0, 'wargs': None}


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [['.'] * w for _ in range(h)]

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c:
            self.g[y][x] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.g[y][x]
        return '.'

    def line(self, x0, y0, x1, y1, c, only_empty=False):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            if not only_empty or self.get(x0, y0) == '.':
                self.put(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def rows(self):
        return [''.join(r) for r in self.g]


def hull(cv, x0, x1, yd, depth, sheer=3, bow_rake=6, stern_rake=4, band=None, ports=None, trim=None):
    xm = (x0 + x1) / 2
    half = (x1 - x0) / 2
    tops, bots = {}, {}
    yb = yd + depth
    for x in range(x0, x1 + 1):
        f = (x - xm) / half
        lift = sheer * (abs(f) ** 2.2) * (1.35 if f > 0 else 1.0)
        top = yd - round(lift)
        if x > x1 - bow_rake:
            bot = yb - round((x - (x1 - bow_rake)) * depth * 0.7 / bow_rake)
        elif x < x0 + stern_rake:
            bot = yb - round(((x0 + stern_rake) - x) * depth * 0.55 / stern_rake)
        else:
            bot = yb
        tops[x], bots[x] = top, bot
    darker = {'a': 'b', 'b': 'c', 'c': 'd', 'd': 'e', 'e': 'f', 'f': 'f'}
    lighter = {'b': 'a', 'c': 'b', 'd': 'c', 'e': 'd', 'a': 'a', 'f': 'e'}
    nb = max(2, round(depth / 2.3))
    shade_of = ['b', 'b', 'c', 'c', 'd', 'd', 'd']
    bands = {}
    for x in range(x0, x1 + 1):
        top, bot = tops[x], bots[x]
        full = yb - top - 1
        prev = None
        for y in range(top, bot + 1):
            r = y - top
            if r == 0:
                c = 'e'
            elif r == 1:
                c = 'a'
            else:
                u = (r - 2) / max(1, full)
                bi = min(nb - 1, int(u * nb))
                base = 'b' if u < 0.28 else ('c' if u < 0.58 else 'd')
                first = prev is None or bi != prev
                after = bi > 0 and (not first) and bands.get((x, y - 1)) == bi and bands.get((x, y - 2), -1) != bi
                if first and prev is not None:
                    c = darker[base]
                elif after:
                    c = lighter[base]
                else:
                    c = base
                    if (x * 3 + bi * 11) % 19 == 0:
                        c = darker[base]
                bands[(x, y)] = bi
                prev = bi
            if y >= bot and r > 2:
                c = 'f'
            if x >= x1 - 1 and r > 0:
                c = darker[c]
            if x <= x0 + 1 and r > 1:
                c = lighter[c]
            cv.put(x, y, c)
    cv.put(x1, tops[x1] - 1, 'e')
    cv.put(x1, tops[x1] - 2, 'd')
    cv.put(x0, tops[x0] - 1, 'd')
    if band:
        bi_want, cols = band
        for (x, y), bi in bands.items():
            if bi == bi_want and x0 + 2 < x < x1 - 2 and y < bots[x] - 1:
                above = bands.get((x, y - 1))
                c = cols[0] if above == bi else 'i'
                if c == cols[0] and bands.get((x, y + 1)) != bi:
                    c = cols[1]
                cv.put(x, y, c)
    if ports:
        py, step, start, end = ports
        for x in range(x0 + start, x1 - end, step):
            t = tops[x]
            cv.put(x, t + py, 'H')
            cv.put(x + 1, t + py, 'H')
            cv.put(x, t + py + 1, 'f')
            cv.put(x + 1, t + py + 1, 'H')
            cv.put(x, t + py - 1, 'a')
    if trim:
        for x in range(x0, x1 + 1):
            cv.put(x, tops[x], trim)
    return tops, bots


def mast(cv, x, top, bot, w=2):
    for y in range(top, bot + 1):
        cv.put(x, y, 'm')
        if w > 1:
            cv.put(x + 1, y, 'M')
    cv.put(x, top - 1, 'M')


SAILC = set('stTSxwWXZ')


def sail(cv, xl, xr, yt, yb, cloth='y', step=4, rake=2, curve=True):
    if cloth == 'y':
        hi, mid, lo, sh, bat = 's', 't', 'T', 'S', 'x'
    else:
        hi, mid, lo, sh, bat = 'w', 'W', 'X', 'Z', 'x'
    H = yb - yt
    spans = {}
    for y in range(yt, yb + 1):
        k = (y - yt) / max(1, H)
        left = xl + round(rake * (1 - k) ** 1.5)
        belly = 1 if curve and 0.3 < k < 0.8 else 0
        if ANIM['puff'] > 0 and 0.4 < k < 0.72:
            belly += 1
        elif ANIM['puff'] < 0 and 0.3 < k < 0.8:
            belly -= 1
        right = xr + belly
        spans[y] = (left, right)
    for y, (left, right) in spans.items():
        for x in (left - 1, right + 1):
            if cv.get(x, y) in SAILC:
                cv.put(x, y, 'k')
    for x in range(spans[yt][0], spans[yt][1] + 1):
        if cv.get(x, yt - 1) in SAILC:
            cv.put(x, yt - 1, 'k')
    for y, (left, right) in spans.items():
        p = (y - yt) % step
        for x in range(left, right + 1):
            fx = (x - left) / max(1, right - left)
            if p == 0:
                c = bat
            else:
                if p == 1:
                    c = lo
                elif p == step - 1:
                    c = mid
                else:
                    c = hi if fx < 0.5 else mid
                if fx > 0.78:
                    c = {hi: mid, mid: lo, lo: sh, sh: sh}[c]
                if x == left:
                    c = hi if p != 1 else mid
                if x == right:
                    c = sh
                if p >= 2 and (x - left) % 6 == 4 and c in (hi, mid):
                    c = {hi: mid, mid: lo}[c]
            cv.put(x, y, c)
        if p == 0:
            cv.put(left - 1, y, bat)
            cv.put(right + 1, y, bat)
    return xl, xr, yt, yb


def flag(cv, x, y, c1='R', c2='Q', ln=5):
    for i in range(ln):
        wave = 1 if ((i + ANIM['flag']) % 4) in (2,) else 0
        cv.put(x + i, y + wave, c1)
        cv.put(x + i, y + 1 + wave, c2 if i > 0 else c1)
    cv.put(x + ln, y + 1 + (1 if ANIM['flag'] % 4 == 3 else 0), c2)


def lantern(cv, x, y):
    cv.put(x, y - 1, 'f')
    cv.put(x, y, 'Q')
    cv.put(x + 1, y, 'Q')
    cv.put(x, y + 1, 'P' if (x + ANIM['lit']) % 3 else 'R')
    cv.put(x + 1, y + 1, 'R')
    cv.put(x, y + 2, 'R')
    cv.put(x + 1, y + 2, 'Q')
    cv.put(x, y + 3, 'i')


def roof(cv, xl, xr, y, rows=3, flare=2):
    for i in range(rows):
        yy = y + i
        ext = flare - (rows - 1 - i) * 0 if i == rows - 1 else max(0, flare - 1 - (rows - 1 - i))
        a, b = xl - ext + (rows - 1 - i), xr + ext - (rows - 1 - i)
        for x in range(a, b + 1):
            c = 'g' if i == 0 else ('h' if (x + i) % 3 else 'H')
            if i == rows - 1:
                c = 'H'
            cv.put(x, yy, c)
    yb = y + rows - 1
    cv.put(xl - flare - 1, yb - 1, 'H')
    cv.put(xr + flare + 1, yb - 1, 'H')


def wall(cv, xl, xr, yt, yb, windows=(), lit=True):
    for y in range(yt, yb + 1):
        for x in range(xl, xr + 1):
            c = 'b' if (y - yt) % 3 else 'c'
            if x == xl:
                c = 'a'
            if x == xr:
                c = 'd'
            if (x - xl) % 5 == 0 and xl < x < xr:
                c = 'd'
            cv.put(x, y, c)
    for (wx, wy) in windows:
        for dx in range(2):
            for dy in range(2):
                on = (wx * 7 + wy * 3 + ANIM['lit']) % 5 != 0
                cv.put(wx + dx, wy + dy, ('y' if (dx + dy) == 0 and on else 'Y') if lit else 'H')
        cv.put(wx, wy + 2, 'e')
        cv.put(wx + 1, wy + 2, 'e')


def rail(cv, xl, xr, y, c='R', c2='Q'):
    for x in range(xl, xr + 1):
        cv.put(x, y, c)
        if (x - xl) % 3 == 0:
            cv.put(x, y + 1, c2)


def water(cv, x0, x1, yw, tops_bots, rows=5):
    if not ANIM['water']:
        ANIM['wargs'] = (x0, x1, yw, tops_bots, rows)
        return
    bots = tops_bots[1]
    ph = ANIM['phase']
    for i in range(rows):
        y = yw + i
        shrink = i * 2
        a, b = x0 - 5 + shrink, x1 + 5 - shrink
        for x in range(a, b + 1):
            under = x in bots and bots[x] >= y
            q = x + ph * (1 if i % 2 == 0 else 2)
            if under:
                if i == 0:
                    c = 'v' if q % 3 else 'V'
                else:
                    r = x - ph
                    c = 'n' if (r + i * 2) % 5 else 'u'
                    if i >= 2 and (r + i) % 7 == 0:
                        c = 'U'
            else:
                if i == 0:
                    c = 'V' if (q // 2) % 3 else 'v'
                elif i == 1:
                    c = 'U' if (q + 1) % 6 else 'V'
                else:
                    c = 'u' if (q + i * 3) % 8 else 'U'
            edge = x in (a, b)
            if edge and i > 0:
                c = 'U' if i < 3 else 'u'
            cv.put(x, y, c)
        if i == 0:
            cv.put(a - 1, y, 'V')
            cv.put(b + 1, y, 'V')
    for x in range(x0 - 8, x1 + 9, 1):
        if (x + ph) % 11 == 0:
            cv.put(x, yw + rows, 'u')
            cv.put(x + 1, yw + rows, 'u')


def ship1():
    cv = Canvas(46, 22)
    rails = None
    hb = hull(cv, 4, 41, 13, 5, sheer=3, bow_rake=6, stern_rake=4)
    for x in range(14, 21):
        for y in range(9, 12):
            c = 'b' if y > 9 else 'a'
            if x == 20:
                c = 'd'
            if y == 11:
                c = 'c'
            cv.put(x, y, c)
    for x in range(14, 21):
        cv.put(x, 10, 'R' if x in (14, 15, 16, 17, 18, 19) and False else cv.get(x, 10))
    cv.put(17, 9, 'e')
    cv.put(17, 10, 'e')
    cv.put(17, 11, 'e')
    for x in range(23, 27):
        cv.put(x, 10, 't')
        cv.put(x, 11, 'T')
    cv.put(24, 10, 's')
    cv.put(26, 11, 'S')
    cv.put(27, 11, 'S')
    for x in range(24, 27):
        cv.put(x, 9, 'T' if x != 25 else 'x')
    cv.line(32, 2, 35, 12, 'm')
    cv.line(33, 2, 36, 12, 'M')
    water(cv, 4, 41, 17, hb, rows=4)
    return cv


def ship2():
    cv = Canvas(58, 38)
    hb = hull(cv, 4, 53, 27, 6, sheer=4, bow_rake=8, stern_rake=5)
    cv.line(27, 6, 9, 25, 'r')
    cv.line(28, 6, 50, 24, 'r')
    sail(cv, 18, 36, 7, 23, cloth='y', step=4, rake=2)
    mast(cv, 26, 4, 25)
    cv.put(26, 3, 'R')
    cv.put(27, 3, 'R')
    cv.put(28, 3, 'Q')
    cv.put(28, 4, 'R')
    for x in range(40, 45):
        for y in range(23, 26):
            cv.put(x, y, 'b' if y > 23 else 'a')
        cv.put(44, y, 'd')
    for x in range(40, 45):
        cv.put(x, 25, 'c')
    for x in range(41, 44):
        cv.put(x, 24, 'b')
    cv.put(47, 23, 'h')
    cv.put(48, 23, 'h')
    cv.put(46, 24, 'g')
    cv.put(47, 24, 'h')
    cv.put(48, 24, 'h')
    cv.put(49, 24, 'H')
    cv.put(47, 22, 'H')
    cv.line(7, 20, 9, 26, 'm')
    water(cv, 4, 53, 32, hb, rows=5)
    return cv


def ship3():
    cv = Canvas(72, 52)
    hb = hull(cv, 4, 67, 38, 7, sheer=5, bow_rake=9, stern_rake=5)
    cv.line(34, 5, 8, 36, 'r')
    cv.line(35, 5, 64, 35, 'r')
    cv.line(35, 5, 58, 36, 'r')
    sail(cv, 22, 48, 7, 33, cloth='y', step=4, rake=3)
    mast(cv, 33, 3, 36)
    flag(cv, 35, 2, 'R', 'Q', 5)
    roof(cv, 8, 18, 27, rows=3, flare=2)
    wall(cv, 8, 18, 30, 35, windows=[(10, 31), (15, 31)])
    rail(cv, 50, 62, 34, 'c', 'd')
    lantern(cv, 6, 30)
    water(cv, 4, 67, 44, hb, rows=6)
    return cv


def deckhouse(cv, tops, xa, xb, ytop, ports_step=6, lit=False):
    for x in range(xa, xb + 1):
        t = tops[x]
        for y in range(ytop, t):
            c = 'b' if (y - ytop) % 3 else 'c'
            if (x - xa) % ports_step == 0:
                c = 'd'
            if x == xa:
                c = 'a'
            if x == xb:
                c = 'e'
            cv.put(x, y, c)
    for x in range(xa + 2, xb - 2, ports_step):
        y = ytop + 3
        if lit:
            cv.put(x + 1, y, 'y' if (x * 7 + ANIM['lit']) % 5 else 'Y')
            cv.put(x + 2, y, 'Y')
            cv.put(x + 1, y + 1, 'Y')
            cv.put(x + 2, y + 1, 'Y')
        else:
            cv.put(x + 1, y, 'H')
            cv.put(x + 2, y, 'H')
            cv.put(x + 1, y + 1, 'f')
            cv.put(x + 2, y + 1, 'H')
    for x in range(xa - 1, xb + 2):
        cv.put(x, ytop - 1, 'Q')
        cv.put(x, ytop - 2, 'R')
        if (x - xa) % 3 == 0:
            cv.put(x, ytop - 3, 'Q')
            cv.put(x, ytop - 4, 'R')
    for x in range(xa - 1, xb + 2):
        if cv.get(x, ytop - 4) == 'R' or (x - xa) % 3 == 0:
            pass
    for x in range(xa - 1, xb + 2):
        cv.put(x, ytop - 5, 'R' if (x - xa) % 3 else 'Q')


def pavilion(cv, xa, xb, ybase, h=5):
    roof(cv, xa, xb, ybase - h - 3, rows=3, flare=2)
    for y in range(ybase - h, ybase):
        for x in range(xa, xb + 1):
            c = 'H' if y < ybase - 2 else 'e'
            if x in (xa, xb, (xa + xb) // 2):
                c = 'R' if x != xb else 'Q'
            cv.put(x, y, c)
    for x in range(xa, xb + 1):
        cv.put(x, ybase - 2, 'R' if x % 2 else 'Q')


def ship4():
    cv = Canvas(90, 66)
    hb = hull(cv, 4, 83, 50, 9, sheer=5, bow_rake=11, stern_rake=6,
              band=(0, ['j', 'J']), ports=(7, 5, 10, 13))
    tops = hb[0]
    cv.line(23, 6, 8, 38, 'r')
    cv.line(61, 9, 82, 44, 'r')
    cv.line(24, 6, 60, 10, 'r')
    sail(cv, 50, 72, 12, 33, cloth='w', step=4, rake=2)
    sail(cv, 10, 36, 8, 33, cloth='w', step=4, rake=3)
    mast(cv, 22, 4, 40)
    mast(cv, 60, 8, 40)
    deckhouse(cv, tops, 11, 76, 41, ports_step=6)
    flag(cv, 24, 3, 'R', 'Q', 6)
    flag(cv, 62, 7, 'i', 'Y', 4)
    pavilion(cv, 39, 47, 36, h=5)
    lantern(cv, 37, 29)
    lantern(cv, 48, 29)
    water(cv, 4, 83, 58, hb, rows=7)
    return cv


def ship5():
    cv = Canvas(106, 82)
    hb = hull(cv, 4, 99, 63, 11, sheer=6, bow_rake=13, stern_rake=6,
              band=(0, ['j', 'J']))
    tops = hb[0]
    cv.line(43, 4, 10, 30, 'r')
    cv.line(44, 4, 70, 9, 'r')
    cv.line(71, 9, 90, 16, 'r')
    cv.line(91, 16, 102, 56, 'r')
    sail(cv, 79, 96, 19, 45, cloth='w', step=4, rake=2)
    sail(cv, 58, 82, 11, 45, cloth='w', step=4, rake=2)
    sail(cv, 28, 58, 7, 45, cloth='w', step=4, rake=3)
    mast(cv, 42, 4, 53)
    mast(cv, 70, 8, 53)
    mast(cv, 90, 15, 53)
    deckhouse(cv, tops, 30, 86, 54, ports_step=5, lit=True)
    flag(cv, 44, 1, 'R', 'Q', 8)
    flag(cv, 72, 5, 'i', 'Y', 6)
    flag(cv, 92, 12, 'j', 'J', 5)
    roof(cv, 12, 22, 33, rows=3, flare=2)
    wall(cv, 12, 22, 36, 40, windows=[(14, 37), (19, 37)])
    rail(cv, 8, 26, 41, 'R', 'Q')
    roof(cv, 7, 27, 42, rows=3, flare=3)
    wall(cv, 7, 27, 45, tops[8] - 1, windows=[(9, 47), (14, 47), (19, 47), (24, 47), (9, 52), (14, 52), (19, 52), (24, 52)])
    rail(cv, 5, 29, 57, 'R', 'Q')
    lantern(cv, 3, 45)
    lantern(cv, 30, 45)
    lantern(cv, 100, 52)
    water(cv, 4, 99, 73, hb, rows=8)
    return cv


SHIPS = [
    ('나룻배', ship1),
    ('거룻배', ship2),
    ('돛배', ship3),
    ('판옥배', ship4),
    ('대양함선', ship5),
]
