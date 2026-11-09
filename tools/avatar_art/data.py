import math

W, H = 28, 34
CX = W / 2
HEAD_CY, HEAD_RX, HEAD_RY = 12.2, 12.6, 10.4
FACE_CY, FACE_RX, FACE_RY = 16.6, 8.4, 6.2
TOP, BOT = 22, 30


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
    return ((x + .5 - CX) / HEAD_RX) ** 2 + ((y + .5 - HEAD_CY) / HEAD_RY) ** 2 <= 1


def in_face(x, y):
    return y >= 12 and ((x + .5 - CX) / FACE_RX) ** 2 + ((y + .5 - FACE_CY) / FACE_RY) ** 2 <= 1


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
    g.ell(CX, FACE_CY, FACE_RX, FACE_RY, 's', lambda x, y: y >= 12)
    g.rect(13, 22, 14, 23, 'S')
    g.sym(8, 27, 's')
    g.sym(8, 28, 's')
    lift = 1 if frame == 'walk' else 0
    g.rect(11, 30, 12, 31 - lift, 's')
    g.rect(15, 30, 16, 31, 's')
    return g


FRINGES = {
    'jag': [12, 14, 13, 12, 14, 13, 12, 15, 16, 13, 12, 14, 13, 12, 14, 13],
    'flat': [14, 13, 13, 13, 14, 13, 13, 14, 14, 13, 13, 14, 13, 13, 13, 14],
    'side': [15, 15, 15, 14, 14, 14, 13, 13, 13, 12, 12, 12, 11, 11, 11, 11],
    'part': [14, 14, 13, 13, 12, 12, 11, 10, 10, 11, 12, 12, 13, 13, 14, 14],
    'soft': [13, 14, 13, 12, 13, 14, 13, 12, 12, 13, 14, 13, 12, 13, 14, 13],
    'curl': [13, 14, 14, 13, 12, 13, 14, 14, 13, 12, 13, 14, 14, 13, 12, 13],
}
EYE_COLS = set(range(6, 11)) | set(range(17, 22))
SPIKES = [(1, 7), (0, 10), (1, 14), (2, 18), (26, 7), (27, 10), (26, 14), (25, 18), (4, 4), (23, 4), (3, 5), (24, 5)]


def wave(y):
    return (0, 1, 1, 0, -1, -1)[(y // 2) % 6]


def hair_front(fringe, locks, kind=''):
    g = Grid()
    pat = FRINGES[fringe]
    for x in range(W):
        for y in range(H):
            if in_head(x, y) and y < 12:
                g.set(x, y, 'h')
    for i, x in enumerate(range(6, 22)):
        tip = pat[i]
        if x in EYE_COLS:
            tip = min(tip, 13)
        for y in range(10, tip + 1):
            g.set(x, y, 'h')
        g.set(x, tip, 'H')
    end = int(12 + 10 * locks)
    for y in range(12, end + 1):
        o = wave(y) if kind == 'wavy' and y > 15 else 0
        for x in (4, 5, 6):
            g.sym(x - o, y, 'h' if x < 6 or y < 18 else 'H')
    g.sym(4, end + 1, 'H')
    if kind == 'curly':
        for x0 in (7, 14, 20):
            for y in range(5, 12):
                x = x0 + (0, 1, 1, 0, -1, -1)[(y - 5) % 6]
                if g.p.get((x, y)) == 'h':
                    g.set(x, y, 'k')
    if kind == 'wavy':
        for y in range(16, end + 1, 4):
            g.sym(5 - wave(y), y, 'i')
    for pts in ([(7, 6), (6, 7), (6, 8), (5, 9), (5, 10)], [(11, 5), (11, 6), (10, 7), (10, 8), (9, 9)], [(13, 6), (13, 7), (13, 8), (13, 9)]):
        for x, y in pts:
            if g.p.get((x, y)) == 'h':
                g.sym(x, y, 'k')
    for x, y in ((7, 4), (8, 3), (9, 3), (10, 3), (11, 4)):
        g.sym(x, y, 'i')
    g.sym(9, 3, 'j')
    return g


def hair_back(kind):
    g = Grid()
    g.ell(CX, HEAD_CY, HEAD_RX, HEAD_RY, 'k', lambda x, y: not (y >= 18 and 7 <= x <= 20))
    if kind in ('short', 'spiky'):
        for x, y in SPIKES:
            g.set(x, y, 'k')
        g.rect(13, 0, 15, 0, 'H'); g.set(12, 1, 'H'); g.rect(15, 1, 16, 1, 'H')
    if kind == 'bob':
        g.srect(1, 12, 4, 23, 'k')
        g.srect(2, 24, 4, 24, 'H')
    elif kind == 'long':
        g.srect(2, 12, 6, 31, 'k')
        g.srect(3, 32, 6, 32, 'H')
        for y in range(15, 31, 4):
            g.sym(4, y, 'H')
    elif kind == 'pony':
        for y in range(5, 27):
            w = 1 if y < 8 or y > 24 else 2
            g.rect(25, y, 25 + w, y, 'k')
        g.rect(25, 5, 26, 6, 'H')
        g.rect(25, 26, 26, 26, 'H')
    elif kind == 'buns':
        for cx in (4.5, 23.5):
            g.ell(cx, 3.4, 3.6, 3.3, 'h')
            g.set(int(cx) - 1, 1, 'i'); g.set(int(cx), 1, 'i')
    elif kind == 'knot':
        g.ell(CX, 1.6, 3.4, 2.2, 'h')
        g.rect(11, 3, 16, 3, 'H')
        g.set(13, 0, 'i')
    elif kind == 'braid':
        g.srect(2, 12, 4, 19, 'k')
        for y in range(18, 32):
            x = 22 + (y % 2)
            g.rect(x, y, x + 1, y, 'h' if y % 3 else 'H')
        g.rect(22, 32, 23, 32, 'H')
    elif kind == 'curly':
        for a in range(0, 360, 30):
            t = math.radians(a)
            x = CX + (HEAD_RX + 0.2) * math.cos(t)
            y = HEAD_CY + (HEAD_RY + 0.2) * math.sin(t)
            if y < 20:
                g.ell(x, y, 1.4, 1.4, 'k')
        for y in range(12, 21):
            o = (0, 1, 1, 0, -1, -1)[y % 6]
            g.srect(1 - o, y, 4 - o, y, 'k')
        g.srect(0, 20, 3, 21, 'k')
        g.sym(0, 19, 'k')
        g.srect(0, 21, 2, 21, 'H')
    elif kind == 'wavy':
        for y in range(12, 32):
            o = wave(y)
            g.srect(2 - o, y, 6 - o, y, 'k')
            g.sym(3 - o, y, 'H' if (y // 2) % 3 == 0 else 'k')
        for y in (32, 33):
            g.srect(3 - wave(y), y, 6 - wave(y), y, 'H' if y == 33 else 'k')
    elif kind == 'spiky':
        for bx, by, dx, dy in ((6, 3, -1, -1), (10, 1, -1, -1), (14, 0, 0, -1), (19, 1, 1, -1), (22, 3, 1, -1), (1, 9, -1, 0), (26, 9, 1, 0)):
            for t in range(2):
                g.set(bx + dx * t, by + dy * t, 'k')
    return g


HAIRS = {
    'short': ('짧은 머리', 'short', 'jag', 1.0),
    'bob': ('단발', 'bob', 'flat', 1.0),
    'long': ('긴 생머리', 'long', 'flat', 1.1),
    'pony': ('한 갈래 묶음', 'pony', 'side', 0.9),
    'buns': ('쌍 쪽머리', 'buns', 'soft', 0.8),
    'knot': ('상투', 'knot', 'part', 0.6),
    'braid': ('땋은 머리', 'braid', 'part', 0.9),
    'spiky': ('뻗친 머리', 'spiky', 'jag', 0.7),
    'curly': ('물결 짧은 머리', 'curly', 'curl', 0.7),
    'wavy': ('물결 긴 머리', 'wavy', 'part', 1.1),
}

EX, EY = 6, 14

EYE_SHAPES = {
    'round': ['lllll', '.wEEE', '.EeeE', '.eeee', '..ff.'],
    'droopy': ['..lll', '.lwEE', 'lEeeE', '.eeef', '..ff.'],
    'sparkle': ['.llll', 'lwEwE', 'lEeeE', '.feew', '..ff.'],
    'cat': ['l....', '.llll', '.wEEE', '.eeeE', '..ff.'],
    'sleepy': ['.....', 'lllll', '.wEEE', '.feee', '.....'],
    'sharp': ['l....', '.llll', '..EEE', '..lll', '.....'],
    'teary': ['.llll', 'lwEEE', 'lEeeE', '.feee', '.vvv.'],
    'dot': ['.....', '..wE.', '..EE.', '.....', '.....'],
    'smile': ['.....', '.lll.', 'l...l', '.....', '.....'],
    'wink': None,
}
CLOSED = ['.....', '.....', 'l...l', '.lll.', '.....']


def eye(kind, closed):
    g = Grid()
    left = right = EYE_SHAPES['round'] if kind == 'wink' else EYE_SHAPES[kind]
    if kind == 'wink':
        right = EYE_SHAPES['smile']
    if closed and kind != 'smile':
        left, right = CLOSED, (EYE_SHAPES['smile'] if kind == 'wink' else CLOSED)
    for dy, r in enumerate(left):
        for dx, ch in enumerate(r):
            if ch != '.':
                g.set(EX + dx, EY + dy, ch)
    rx = W - EX - 5
    for dy, r in enumerate(right):
        m = list(r[::-1])
        for c in range(5):
            if m[c] == 'w':
                m[c] = r[c] if r[c] != 'w' else 'E'
        for c in range(5):
            if r[c] == 'w':
                m[c] = 'w'
        for dx, ch in enumerate(m):
            if ch != '.':
                g.set(rx + dx, EY + dy, ch)
    for x in (8, 9):
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
        g.sym(12, MY, 'm'); g.rect(13, MY + 1, 14, MY + 1, 'm')
    elif kind == 'open':
        g.rect(13, MY, 14, MY, 'n'); g.rect(13, MY + 1, 14, MY + 1, 'm')
    elif kind == 'cat':
        g.sym(11, MY, 'm'); g.sym(12, MY + 1, 'm'); g.rect(13, MY, 14, MY, 'm')
    elif kind == 'grin':
        g.sym(12, MY, 'm'); g.rect(13, MY, 14, MY, 'w'); g.rect(13, MY + 1, 14, MY + 1, 'm')
    elif kind == 'pout':
        g.sym(12, MY + 1, 'm'); g.sym(13, MY, 'm')
    return g


MOUTHS = {
    'small': '작은 입', 'smile': '웃는 입', 'open': '벌린 입',
    'cat': 'w 입', 'grin': '이 보이는 입', 'pout': '삐죽 입',
}


def half(y, flare):
    if y == TOP + 1:
        return 4
    return 5 + (max(0, y - 27) // flare if flare else 0)


def coat(g, length=29, flare=0, collar=True, belt=None):
    for y in range(TOP + 1, length + 1):
        hw = half(y, flare)
        g.srect(14 - hw, y, 13, y, 'a')
        g.sym(14 - hw, y, 'b')
    for y in range(TOP + 2, 27):
        g.sym(8, y, 'b')
    g.sym(7, 24, 'b')
    if collar:
        g.rect(12, TOP + 1, 15, TOP + 1, 'c')
        g.rect(13, TOP + 2, 14, TOP + 2, 'c')
    g.rect(13, TOP, 14, TOP, 'c' if collar else 'a')
    if belt:
        hw = half(belt, flare)
        g.srect(14 - hw, belt, 13, belt, 'd')


def pants(g, frame, shoe='z'):
    lift = 1 if frame == 'walk' else 0
    for y in range(28, 31):
        g.srect(10, y, 13, y, 'a')
    g.sym(10, 30, 'b')
    g.rect(11, 31 - lift, 12, 31 - lift, 'a')
    g.rect(15, 31, 16, 31, 'a')
    g.rect(10, 32 - lift, 12, 32 - lift, shoe)
    g.rect(15, 32, 17, 32, shoe)


def skirt(g, frame, shoe='z'):
    lift = 1 if frame == 'walk' else 0
    for y in range(26, 32):
        hw = 5 + (y - 26) // 2
        g.srect(14 - hw, y, 13, y, 'a')
        g.sym(14 - hw, y, 'b')
    for y in range(27, 32, 2):
        g.sym(11, y, 'b')
    g.rect(10, 32 - lift, 12, 32 - lift, shoe)
    g.rect(15, 32, 17, 32, shoe)


def top_guard():
    g = Grid()
    coat(g, belt=27, collar=False)
    for y in range(TOP + 2, 30, 2):
        for x in range(10, 14):
            if (x + y) % 2 == 0:
                g.sym(x, y, 'b')
    g.srect(7, TOP + 1, 9, TOP + 2, 'd')
    return g, {'a': '#5c6470', 'b': '#8a94a0', 'd': '#c9a24a'}


def top_scout():
    g = Grid()
    coat(g, belt=27)
    return g, {'a': '#4f7a4a', 'b': '#3e6239', 'c': '#efe7d2', 'd': '#7a5432'}


def top_exorcist():
    g = Grid()
    coat(g, length=31, flare=2)
    g.rect(13, TOP + 3, 14, 31, 'c')
    g.srect(9, 26, 13, 26, 'd')
    return g, {'a': '#eceae4', 'b': '#cfcbc0', 'c': '#55624f', 'd': '#a8452c'}


def top_medic():
    g = Grid()
    coat(g, length=31, flare=3)
    g.rect(11, TOP + 3, 16, 31, 'd')
    g.rect(13, TOP + 4, 14, TOP + 6, 'e')
    g.rect(12, TOP + 5, 15, TOP + 5, 'e')
    return g, {'a': '#cfdcd8', 'b': '#a9bcb6', 'c': '#f4efe2', 'd': '#8fa676', 'e': '#f4efe2'}


def top_seal():
    g = Grid()
    coat(g, belt=27)
    for y in range(TOP + 1, 30):
        g.sym(12 - (y - TOP) // 4, y, 'd')
    return g, {'a': '#4a3a6a', 'b': '#3a2c56', 'c': '#d9c48a', 'd': '#c9a24a'}


def top_shadow():
    g = Grid()
    coat(g)
    g.rect(13, TOP, 14, TOP, 'e')
    g.rect(13, TOP + 2, 13, TOP + 2, 'e'); g.rect(13, TOP + 4, 13, TOP + 4, 'e')
    for y in range(TOP + 3, 31):
        g.set(18, y, 'd')
    g.set(19, 30, 'd')
    return g, {'a': '#2e2a36', 'b': '#3e3848', 'c': '#e8e2dc', 'd': '#9a2a36', 'e': '#d6aa52'}


def top_jeogori():
    g = Grid()
    for y in range(TOP + 1, 27):
        hw = half(y, 0)
        g.srect(14 - hw, y, 13, y, 'a')
    for y in range(TOP + 2, 27):
        g.sym(8, y, 'b')
    g.sym(7, 24, 'b')
    g.sym(8, 26, 'c')
    g.rect(12, TOP + 1, 15, TOP + 1, 'c')
    g.rect(13, TOP, 14, TOP, 'c')
    g.rect(14, TOP + 2, 15, TOP + 6, 'd')
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

FIXED = {'v': '#f6f1ea', 'w': '#ffffff', 'l': '#2a1c22', 'p': '#f8c4bc', 'm': '#c8645e', 'n': '#7a2a2a'}
