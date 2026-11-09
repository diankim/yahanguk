import math

W, H = 28, 34
HEAD_CY, HEAD_RX, HEAD_RY = 11.5, 12.5, 11.0
FACE_CY, FACE_RX, FACE_RY = 13.92, 9.25, 7.0
TOP, BOT = 22, 28


class Grid:
    def __init__(self):
        self.p = {}

    def set(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.p[(x, y)] = c

    def sym(self, x, y, c):
        self.set(x, y, c)
        self.set(W - 1 - x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def srect(self, x0, y0, x1, y1, c):
        self.rect(x0, y0, x1, y1, c)
        self.rect(W - 1 - x1, y0, W - 1 - x0, y1, c)

    def ell(self, cx, cy, rx, ry, c, cond=None):
        for y in range(H):
            for x in range(W):
                if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1 and (cond is None or cond(x, y)):
                    self.set(x, y, c)

    def rows(self):
        if not self.p:
            return dict(x=0, y=0, rows=['.'])
        xs = [x for x, _ in self.p]
        ys = [y for _, y in self.p]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        out = []
        for y in range(y0, y1 + 1):
            out.append(''.join(self.p.get((x, y), '.') for x in range(x0, x1 + 1)))
        return dict(x=x0, y=y0, rows=out)


def in_head(x, y):
    return ((x + .5 - W / 2) / HEAD_RX) ** 2 + ((y + .5 - HEAD_CY) / HEAD_RY) ** 2 <= 1


def in_face(x, y):
    return ((x + .5 - W / 2) / FACE_RX) ** 2 + ((y + .5 - FACE_CY) / FACE_RY) ** 2 <= 1


SKINS = {
    'fair': ('맑은 살결', '#fbe6d6'),
    'warm': ('따뜻한 살결', '#f9dfc6'),
    'tan': ('볕에 그은 살결', '#e8bf98'),
    'deep': ('짙은 살결', '#c9946b'),
}
HAIR_COLORS = {
    'black': ('먹빛', '#2c2422'),
    'brown': ('고동빛', '#4a3428'),
    'chestnut': ('밤빛', '#7a4a2c'),
    'gold': ('금빛', '#d9b45a'),
    'silver': ('은빛', '#b8bcc4'),
    'red': ('단풍빛', '#a8452c'),
    'indigo': ('쪽빛', '#3a4f7a'),
    'peach': ('복숭아빛', '#e3a6b4'),
}
EYE_COLORS = {
    'dark': ('먹빛 눈', '#4a2a22'),
    'brown': ('고동빛 눈', '#6a3a2a'),
    'amber': ('호박빛 눈', '#b0742a'),
    'blue': ('쪽빛 눈', '#3a5a9a'),
    'jade': ('비취빛 눈', '#3f8a6a'),
    'crimson': ('붉은 눈', '#9a2a2a'),
}


def body(frame):
    g = Grid()
    g.ell(W / 2, FACE_CY, FACE_RX, FACE_RY, 's')
    for y in range(H):
        xs = [x for x in range(W) if g.p.get((x, y)) == 's']
        if xs and y > FACE_CY:
            g.set(xs[0], y, 'S')
            g.set(xs[-1], y, 'S')
    for x in range(W):
        ys = [y for y in range(H) if g.p.get((x, y)) in ('s', 'S')]
        if ys:
            g.set(x, ys[-1], 'S')
    g.rect(13, 20, 14, 22, 'S')
    g.srect(10, TOP, 13, BOT, 's')
    g.srect(8, BOT - 1, 9, BOT, 's')
    lift = 1 if frame == 'walk' else 0
    g.rect(11, 29 - 0, 12, 30 - lift, 's')
    g.rect(15, 29, 16, 30, 's')
    return g


FRINGES = {
    'jag': [1, 2, 2, 1, 0, 1, 2, 3, 2, 1, 1, 2, 3, 2, 1, 0, 1, 2, 2, 1],
    'flat': [2] * 20,
    'side': [3, 3, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0, -1, -1, -1],
    'part': [3, 3, 2, 2, 1, 1, 0, -1, -2, -3, -3, -2, -1, 0, 1, 1, 2, 2, 3, 3],
    'soft': [2, 2, 1, 1, 2, 2, 1, 1, 2, 2, 2, 1, 1, 2, 2, 1, 1, 2, 2, 2],
}


def hair_front(fringe, locks):
    g = Grid()
    pat = FRINGES[fringe]
    fy = FACE_CY - FACE_RY * 0.72
    x0, x1 = int(W / 2 - FACE_RX - 1), int(W / 2 + FACE_RX + 1)
    for i, x in enumerate(range(x0, x1 + 1)):
        d = pat[i % len(pat)]
        lim = int(fy + d * 0.6)
        for y in range(0, lim):
            if in_head(x, y):
                g.set(x, y, 'h')
        if d >= 3 and fringe in ('jag', 'side'):
            g.set(x, lim, 'H')
    for x in range(0, W):
        for y in range(0, int(fy)):
            if in_head(x, y) and not in_face(x, y):
                g.set(x, y, 'h')
    for x in range(x0, x1 + 1):
        for y in range(0, H):
            if (x, y) in g.p and (x, y + 1) not in g.p and in_face(x, y + 1) and g.p[(x, y)] in ('h', 'H'):
                g.set(x, y, 'H')
                g.set(x, y + 1, 'S')
                break
    for side in (-1, 1):
        sx = int(W / 2 + side * (FACE_RX - 0.5)) - (1 if side > 0 else 0)
        for y in range(int(FACE_CY - 2), int(FACE_CY + FACE_RY * locks)):
            g.set(sx, y, 'h')
            g.set(sx + (1 if side > 0 else -1), y, 'h')
        g.set(sx, int(FACE_CY + FACE_RY * locks), 'H')
    for k in (-2, -1, 1, 2):
        xs = int(W / 2 + k * HEAD_RX / 3.2)
        for y in range(int(fy - 3), int(fy)):
            if g.p.get((xs, y)) == 'h':
                g.set(xs, y, 'H')
    for a in range(200, 341, 6):
        r = math.radians(a)
        x = int(W / 2 + math.cos(r) * HEAD_RX * 0.55)
        y = int(HEAD_CY - HEAD_RY * 0.25 + math.sin(r) * HEAD_RY * 0.55)
        if g.p.get((x, y)) in ('h', 'H'):
            g.set(x, y, 'i')
            g.set(x + 1, y, 'i')
    return g


def hair_back(kind):
    g = Grid()
    g.ell(W / 2, HEAD_CY, HEAD_RX, HEAD_RY, 'k')
    if kind == 'short':
        for x in (12, 13, 15):
            g.set(x, 0, 'h')
    elif kind == 'bob':
        g.srect(2, 12, 5, 21, 'h')
        g.srect(3, 21, 5, 22, 'H')
    elif kind == 'long':
        g.srect(3, 12, 7, 30, 'h')
        g.srect(3, 30, 6, 31, 'H')
        for y in range(14, 30, 4):
            g.sym(5, y, 'H')
    elif kind == 'pony':
        for y in range(5, 24):
            w = 1 if y < 8 or y > 21 else 2
            g.rect(25, y, 25 + w, y, 'h')
        g.rect(25, 5, 26, 6, 'H')
        g.rect(25, 23, 26, 23, 'H')
    elif kind == 'buns':
        for cx in (4.5, 23.5):
            g.ell(cx, 3.5, 3.4, 3.2, 'h')
            g.set(int(cx), 2, 'i')
    elif kind == 'knot':
        g.ell(14, 1.6, 3.2, 2.2, 'h')
        g.rect(12, 3, 15, 3, 'H')
    elif kind == 'braid':
        g.srect(3, 12, 5, 18, 'h')
        for y in range(18, 31):
            x = 21 + (y % 2)
            g.rect(x, y, x + 1, y, 'h' if y % 3 else 'H')
        g.rect(21, 31, 22, 31, 'H')
    elif kind == 'spiky':
        for bx, by, dx, dy in ((5, 3, -1, -1), (9, 0, -1, -1), (14, 0, 0, -1), (19, 0, 1, -1), (23, 3, 1, -1), (2, 8, -1, 0), (25, 8, 1, 0)):
            for t in range(3):
                g.set(bx + dx * t, by + dy * t, 'h')
                g.set(bx + dx * t + (1 if dx <= 0 else -1), by + dy * t, 'h')
    return g


HAIRS = {
    'short': ('짧은 머리', 'short', 'jag', 1.0),
    'bob': ('단발', 'bob', 'flat', 1.0),
    'long': ('긴 생머리', 'long', 'flat', 1.15),
    'pony': ('한 갈래 묶음', 'pony', 'side', 1.0),
    'buns': ('쌍 쪽머리', 'buns', 'soft', 0.9),
    'knot': ('상투', 'knot', 'part', 0.7),
    'braid': ('땋은 머리', 'braid', 'part', 1.0),
    'spiky': ('뻗친 머리', 'spiky', 'jag', 0.8),
}

EY, EX = 13, 8


EYE_SHAPES = {
    'round': ['.lll.', 'lwwEl', 'lweEl', '.eef.', '.fff.', '.....'],
    'droopy': ['..ll.', '.lEEl', 'lwEe.', 'leef.', '.ff..', '.....'],
    'sparkle': ['llll.', 'lwEEl', 'lEwel', '.eef.', '.fwf.', '..l..'],
    'cat': ['l....', '.llll', '.wEe.', '.eef.', '..ll.', '.....'],
    'sleepy': ['.....', '.....', 'lllll', '.wEe.', '.eef.', '.....'],
    'sharp': ['.....', 'lllll', 'vwEEv', '.lll.', '.....', '.....'],
    'teary': ['.lll.', 'lwwEl', 'lwEel', '.eef.', '.vfv.', '..v..'],
    'dot': ['.....', '..EE.', '..wE.', '..EE.', '.....', '.....'],
    'smile': ['.....', '.lll.', 'l...l', '.....', '.....', '.....'],
    'wink': None,
}
CLOSED = ['.....', '.....', '.....', 'l...l', '.lll.', '.....']


def eye(kind, closed):
    g = Grid()
    left = right = EYE_SHAPES['round'] if kind == 'wink' else EYE_SHAPES[kind]
    if kind == 'wink':
        right = EYE_SHAPES['smile']
    if closed and kind not in ('smile',):
        left = right = CLOSED if kind != 'wink' else None
        if kind == 'wink':
            left, right = CLOSED, EYE_SHAPES['smile']
    for rows, side in ((left, 0), (right, 1)):
        for dy, r in enumerate(rows):
            for dx, ch in enumerate(r):
                if ch != '.':
                    x = EX - 1 + dx
                    g.set(x if side == 0 else W - 1 - x, EY - 1 + dy, ch)
    for x in range(EX - 2, EX + 1):
        g.sym(x, EY + 5, 'p')
    return g


EYES = {
    'round': '동그란 눈', 'droopy': '순한 눈', 'sparkle': '반짝이는 눈', 'cat': '고양이 눈', 'sleepy': '졸린 눈',
    'sharp': '째진 눈', 'teary': '촉촉한 눈', 'dot': '콩알 눈', 'smile': '웃는 눈', 'wink': '윙크',
}

MY = 19


def mouth(kind):
    g = Grid()
    if kind == 'small':
        g.rect(13, MY, 14, MY, 'm')
    elif kind == 'smile':
        g.sym(12, MY, 'm'); g.sym(13, MY + 1, 'm')
    elif kind == 'open':
        g.rect(13, MY, 14, MY + 1, 'n'); g.rect(13, MY + 1, 14, MY + 1, 'm')
    elif kind == 'cat':
        g.sym(12, MY, 'm'); g.sym(13, MY + 1, 'm'); g.sym(11, MY - 1, 'm')
    elif kind == 'grin':
        g.sym(12, MY, 'm'); g.rect(13, MY, 14, MY, 'w'); g.rect(13, MY + 1, 14, MY + 1, 'm')
    elif kind == 'pout':
        g.sym(12, MY + 1, 'm'); g.sym(13, MY, 'm')
    return g


MOUTHS = {
    'small': '작은 입', 'smile': '웃는 입', 'open': '벌린 입',
    'cat': '고양이 입', 'grin': '이 보이는 입', 'pout': '삐죽 입',
}


def coat(g, length=BOT, flare=6, sleeve_to=BOT - 2, collar=True, belt=None):
    for y in range(TOP, length + 1):
        fl = (y - TOP) // flare
        g.srect(10 - fl, y, 13, y, 'a')
    for y in range(TOP + 1, length):
        g.sym(10, y, 'b')
    for y in range(TOP + 1, sleeve_to + 1):
        g.sym(8, y, 'a'); g.sym(9, y, 'b')
    if collar:
        g.rect(12, TOP, 15, TOP + 3, 'c')
        g.rect(13, TOP + 4, 14, length - 1, 'c')
    if belt:
        y = TOP + (length - TOP) // 2 if belt == 'mid' else belt
        fl = (y - TOP) // flare
        g.srect(10 - fl, y, 13, y, 'd')


def pants(g, frame, shoe='z'):
    lift = 1 if frame == 'walk' else 0
    for y in range(25, BOT + 1):
        g.srect(10 if y < 27 else 9, y, 13, y, 'a')
    g.rect(11, 29, 12, 30 - lift, 'a')
    g.rect(15, 29, 16, 30, 'a')
    g.rect(10, 31 - lift, 12, 31 - lift, shoe)
    g.rect(15, 31, 17, 31, shoe)


def skirt(g, frame, shoe='z'):
    lift = 1 if frame == 'walk' else 0
    for y in range(24, 31):
        fl = (y - 24) // 2
        g.srect(10 - fl, y, 13, y, 'a')
    for y in range(26, 31, 2):
        g.sym(11, y, 'b')
    g.rect(10, 31 - lift, 12, 31 - lift, shoe)
    g.rect(15, 31, 17, 31, shoe)


def top_guard():
    g = Grid()
    coat(g, belt='mid', collar=False)
    for y in range(TOP, BOT + 1, 2):
        for x in range(10 - (y - TOP) // 6, 14):
            if (x + y) % 2 == 0:
                g.sym(x, y, 'b')
    g.srect(7, TOP, 9, TOP + 1, 'b')
    return g, {'a': '#5c6470', 'b': '#8a94a0', 'd': '#c9a24a'}


def top_scout():
    g = Grid()
    coat(g, belt='mid')
    return g, {'a': '#4f7a4a', 'b': '#3e6239', 'c': '#efe7d2', 'd': '#7a5432'}


def top_exorcist():
    g = Grid()
    coat(g, length=30, flare=4)
    g.rect(12, TOP + 4, 15, TOP + 4, 'd')
    return g, {'a': '#eceae4', 'b': '#cfcbc0', 'c': '#55624f', 'd': '#a8452c'}


def top_medic():
    g = Grid()
    coat(g, length=29, flare=5)
    g.rect(11, TOP + 2, 16, BOT, 'd')
    g.rect(13, TOP + 3, 14, TOP + 5, 'e')
    g.rect(12, TOP + 4, 15, TOP + 4, 'e')
    return g, {'a': '#cfdcd8', 'b': '#a9bcb6', 'c': '#f4efe2', 'd': '#8fa676', 'e': '#f4efe2'}


def top_seal():
    g = Grid()
    coat(g, belt='mid')
    for y in range(TOP, BOT + 1):
        g.sym(11 - (y - TOP) // 6, y, 'd')
    return g, {'a': '#4a3a6a', 'b': '#3a2c56', 'c': '#d9c48a', 'd': '#c9a24a'}


def top_shadow():
    g = Grid()
    coat(g, belt='mid')
    g.rect(10, TOP, 17, TOP + 1, 'd')
    g.rect(16, TOP + 2, 17, TOP + 4, 'd')
    return g, {'a': '#2e2e36', 'b': '#202027', 'c': '#4a4a55', 'd': '#a8452c'}


def top_jeogori():
    g = Grid()
    for y in range(TOP, 26):
        g.srect(10, y, 13, y, 'a')
    for y in range(TOP + 1, 27):
        g.sym(8, y, 'a'); g.sym(9, y, 'b')
    g.rect(12, TOP, 15, TOP + 1, 'c')
    g.rect(13, TOP + 2, 14, TOP + 2, 'c')
    g.rect(14, TOP + 2, 15, TOP + 5, 'd')
    g.sym(8, 26, 'c')
    return g, {'a': '#f2b8c0', 'b': '#e09aa6', 'c': '#f8f2e6', 'd': '#b8324a'}


TOPS = {
    'guard': ('쇠미늘 갑옷', top_guard),
    'scout': ('무명 철릭', top_scout),
    'exorcist': ('삼베 도포', top_exorcist),
    'medic': ('쑥빛 앞치마 도포', top_medic),
    'seal': ('누비 전포', top_seal),
    'shadow': ('먹빛 누비 전포', top_shadow),
    'jeogori': ('연분홍 저고리', top_jeogori),
}


def bottom_def(kind, a, b, shoe):
    def make(frame):
        g = Grid()
        (skirt if kind == 'skirt' else pants)(g, frame)
        return g
    return make, {'a': a, 'b': b, 'z': shoe}


BOTTOMS = {
    'guard': ('검은 바지와 가죽 장화', 'pants', '#3a3030', '#2a2222', '#4a3020'),
    'scout': ('고동 바지와 미투리', 'pants', '#6a4a32', '#55392a', '#c8a46a'),
    'exorcist': ('쪽빛 바지', 'pants', '#363b48', '#2a2e38', '#2a2e40'),
    'medic': ('무명 바지', 'pants', '#e6dcc4', '#cbbfa4', '#6a4a32'),
    'seal': ('검은 바지', 'pants', '#2c2830', '#201c24', '#3a2c56'),
    'shadow': ('먹빛 바지와 짚신', 'pants', '#24242a', '#18181d', '#c8a46a'),
    'chima': ('남빛 치마', 'skirt', '#2f3f72', '#25325c', '#f8f2e6'),
}

JOB_DEFAULT = {
    'artificer': ('guard', 'guard'),
    'scout': ('scout', 'scout'),
    'exorcist': ('exorcist', 'exorcist'),
    'medic': ('medic', 'medic'),
    'sealmaster': ('seal', 'seal'),
    'analyst': ('shadow', 'shadow'),
}

FIXED = {'v': '#f6f1ea', 'w': '#ffffff', 'l': '#3a2620', 'p': '#f7aea4', 'm': '#c8645e', 'n': '#7a2a2a'}
