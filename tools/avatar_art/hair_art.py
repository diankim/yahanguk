import math
from data import Grid, W, in_face, form, EY, EYE_COLS


def strand(g, x0, y0, x1, y1, w, c='h'):
    n = max(1, int(round(max(abs(x1 - x0), abs(y1 - y0)))))
    vert = abs(y1 - y0) >= abs(x1 - x0)
    for t in range(n + 1):
        f = t / n
        x = x0 + (x1 - x0) * f
        y = y0 + (y1 - y0) * f
        ww = max(1.0, w * (1 - f * 0.85))
        if vert:
            for xx in range(int(round(x - ww / 2 + .01)), int(round(x + ww / 2 - .01)) + 1):
                g.set(xx, int(round(y)), c)
        else:
            for yy in range(int(round(y - ww / 2 + .01)), int(round(y + ww / 2 - .01)) + 1):
                g.set(int(round(x)), yy, c)
    g.set(int(round(x1)), int(round(y1)), 'H')


def dome(g, top=1, mid=7, side=10, rx=11.8):
    cy = top + 10
    for y in range(top, side + 1):
        for x in range(W):
            if ((x + .5 - 14) / rx) ** 2 + ((y + .5 - cy) / 10) ** 2 <= 1 and (y <= mid or x < 6 or x > 21):
                g.set(x, y, 'h')


def fringe(g, tips, root=5, w=4.6):
    for x, y in tips:
        strand(g, x + (0.6 if x < 14 else -0.6), root, x, y, w)
    for (x0, y0), (x1, y1) in zip(tips, tips[1:]):
        mx = (x0 + x1) / 2
        end = min(y0, y1) - 1
        for y in range(root + 2, end + 1):
            xx = int(round(mx + (y - end) * 0.15 * (1 if mx < 14 else -1)))
            if (xx, y) in g.p:
                g.p[(xx, y)] = 'H'


def shade_front(g):
    tips = {}
    for (x, y), c in g.p.items():
        if 6 <= x <= 21 and 8 <= y <= 16:
            tips[x] = max(tips.get(x, -1), y)
    form(g, 'h', 'g', 'k')
    for (x, y), c in list(g.p.items()):
        if c == 'h' and y <= 4:
            g.p[(x, y)] = 'g'
        elif c == 'h' and y >= 15:
            g.p[(x, y)] = 'k'
    for a in range(200, 341, 5):
        r = math.radians(a)
        x, y = int(14 + math.cos(r) * 8.0), int(7.6 + math.sin(r) * 4.4)
        for xx in (x, x + 1):
            if g.p.get((xx, y)) in ('h', 'g', 'k'):
                g.p[(xx, y)] = 'i'
    for x, y in ((9, 3), (10, 3)):
        if g.p.get((x, y)) == 'i':
            g.p[(x, y)] = 'j'
    for x, y in tips.items():
        if in_face(x, y + 1) and (y + 1 < EY or x not in EYE_COLS) and (x, y + 1) not in g.p:
            g.set(x, y + 1, 'S')
    return g


def lines(g, pts):
    for x, y in pts:
        if g.p.get((x, y)) in ('h', 'g', 'k'):
            g.p[(x, y)] = 'H'


def layered():
    f, b = Grid(), Grid()
    dome(f)
    fringe(f, ((6, 12), (9, 13), (12, 11), (15, 14), (18, 12), (21, 13)))
    for s in ((4, 8, 3, 17, 4), (23, 8, 24, 17, 4), (4, 13, 1, 17, 2), (23, 13, 26, 17, 2), (9, 3, 7, 0, 2), (16, 3, 18, 0, 2), (2, 7, 0, 10, 2), (25, 7, 27, 10, 2)):
        strand(f, *s)
    lines(f, [(9, 4), (9, 5), (13, 3), (13, 4), (17, 4), (17, 5)])
    return shade_front(f), b


def swept():
    f, b = Grid(), Grid()
    dome(f)
    for s in ((9, 5, 22, 13, 6), (10, 6, 17, 13, 5), (12, 7, 15, 14, 3), (8, 6, 6, 12, 3), (4, 8, 4, 18, 4), (23, 8, 23, 18, 4),
              (23, 13, 26, 18, 2), (4, 13, 2, 17, 2), (18, 2, 22, 0, 2), (21, 3, 25, 2, 2)):
        strand(f, *s)
    for y in range(2, 7):
        f.set(9, y, 'H')
    lines(f, [(13, 8), (15, 9), (17, 10), (13, 4), (15, 5), (17, 6)])
    return shade_front(f), b


def center():
    f, b = Grid(), Grid()
    dome(f)
    for s in ((12, 5, 6, 13, 5), (11, 5, 8, 13, 4), (15, 5, 21, 13, 5), (16, 5, 19, 13, 4), (5, 8, 5, 20, 4), (22, 8, 22, 20, 4),
              (5, 17, 7, 21, 2), (22, 17, 20, 21, 2)):
        strand(f, *s)
    for y in range(2, 7):
        f.set(13, y, 'H')
    lines(f, [(10, 4), (9, 6), (17, 4), (18, 6)])
    return shade_front(f), b


def long():
    f, b = Grid(), Grid()
    dome(f)
    fringe(f, ((6, 13), (9, 12), (12, 13), (15, 14), (18, 12), (21, 13)))
    for s in ((5, 9, 5, 25, 4), (22, 9, 22, 25, 4), (5, 20, 3, 26, 2), (22, 20, 24, 26, 2)):
        strand(f, *s)
    lines(f, [(9, 4), (9, 5), (13, 3), (13, 4), (17, 4), (17, 5)])
    dome(b, 1, 18, 18, 12.4)
    for s in ((4, 10, 2, 31, 6), (23, 10, 25, 31, 6), (6, 14, 7, 30, 3), (21, 14, 20, 30, 3)):
        strand(b, *s, c='k')
    form(b, 'k', 'h', 'q')
    return shade_front(f), b


def twintail():
    f, b = Grid(), Grid()
    dome(f)
    fringe(f, ((6, 12), (9, 13), (12, 12), (15, 14), (18, 13), (21, 12)))
    for s in ((4, 9, 4, 16, 3), (23, 9, 23, 16, 3)):
        strand(f, *s)
    for x, y in ((3, 7), (4, 7), (23, 7), (24, 7)):
        f.set(x, y, 'H')
    lines(f, [(9, 4), (12, 3), (16, 3), (19, 4)])
    for s in ((2, 7, 0, 29, 6), (25, 7, 27, 29, 6), (2, 7, 3, 24, 3), (25, 7, 24, 24, 3)):
        strand(b, *s, c='k')
    form(b, 'k', 'h', 'q')
    return shade_front(f), b


def wolf():
    f, b = Grid(), Grid()
    dome(f, 1)
    fringe(f, ((5, 13), (8, 12), (11, 13), (13, 15), (16, 12), (19, 13), (22, 12)))
    for s in ((4, 8, 4, 16, 4), (23, 8, 23, 16, 4), (12, 2, 10, -1, 2), (15, 2, 17, -1, 2), (6, 4, 2, 2, 2), (21, 4, 25, 2, 2), (2, 9, 0, 12, 2), (25, 9, 27, 12, 2)):
        strand(f, *s)
    for s in ((5, 12, 2, 22, 4), (22, 12, 25, 22, 4), (6, 16, 5, 23, 2), (21, 16, 22, 23, 2)):
        strand(b, *s, c='k')
    lines(f, [(9, 4), (9, 5), (13, 3), (13, 4), (18, 4), (18, 5)])
    form(b, 'k', 'h', 'q')
    return shade_front(f), b


ART = {
    'layered': ('부스스 짧은 머리', layered),
    'swept': ('쓸어 넘긴 앞머리', swept),
    'center': ('가르마 내린 머리', center),
    'longstr': ('가닥 긴 생머리', long),
    'twintail': ('양갈래', twintail),
    'wolf': ('뻗친 늑대머리', wolf),
}
