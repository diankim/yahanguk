from data import Grid

OX, OY = 6, 22

TOPS = {
    'guard': ('쇠미늘 갑옷', {'a': '#5c6470', 'b': '#3e4652', 'c': '#8a94a0', 'd': '#c9a24a', 'e': '#8a6a2a'}, [
        "................",
        ".dddcaaaaaacddd.",
        ".edddcbaabcddde.",
        "..bcacacacacab..",
        "..bacacacacacb..",
        "...cacacacaca...",
        "...dddddeddddd..",
        "...bcbcbcbcbcb..",
        "...cbcbcbcbcbc..",
    ]),
    'scout': ('무명 철릭', {'a': '#4f7a4a', 'b': '#3e6239', 'c': '#efe7d2', 'd': '#7a5432', 'e': '#c9a24a'}, [
        "................",
        "....xacccab.....",
        "..bxaaaccaaaby..",
        "..bxaaaabaaaby..",
        "..bxaaaabaaaby..",
        "...dddddeddddd..",
        "...xaaaabaaaay..",
        "..xaaaaabaaaay..",
        "..ybbaabbaabby..",
    ]),
    'exorcist': ('삼베 도포', {'a': '#eceae4', 'b': '#cfcbc0', 'c': '#55624f', 'd': '#a8452c', 'e': '#8a8676'}, [
        "................",
        "....xacccab.....",
        ".bxaaaaccaaaaby.",
        ".bxaaaacaaaaaby.",
        ".bbdddddddddbby.",
        "..bxaaacaaaab...",
        "...xaaacaaaab...",
        "..xaaaacaaaaab..",
        "..xaaaacaaaaab..",
        "..ebbbbcbbbbbe..",
    ]),
    'medic': ('쑥빛 앞치마 도포', {'a': '#cfdcd8', 'b': '#a9bcb6', 'c': '#f4efe2', 'd': '#8fa676', 'e': '#f4efe2'}, [
        "................",
        "....xacccab.....",
        "..bxaddddddaby..",
        "..bxaddeeddaby..",
        "..bxadeeeedaby..",
        "...xaddeeddab...",
        "...xaddddddab...",
        "..xaaddddddaab..",
        "..xaaddddddaab..",
        "..ybbddddddbby..",
    ]),
    'seal': ('누비 전포', {'a': '#4a3a6a', 'b': '#3a2c56', 'c': '#d9c48a', 'd': '#c9a24a', 'e': '#2a2040'}, [
        "................",
        "....dacccad.....",
        "..bxdbaccabdby..",
        "..bxadbaabdaby..",
        "..bxabdabdbaby..",
        "...dddddddddd...",
        "...xabdbbdbab...",
        "...ebadbbdabe...",
    ]),
    'shadow': ('먹빛 누비 전포', {'a': '#2e2a36', 'b': '#3e3848', 'c': '#e8e2dc', 'd': '#9a2a36', 'e': '#d6aa52'}, [
        ".......ee.......",
        "....xbcccbb.....",
        "..bxaaaeaaabd...",
        "..bxaaaaaaadby..",
        "..bxaaaeaaadby..",
        "...xaaaaaaadb...",
        "...xaaaeaaadb...",
        "...ybbbbbbbdd...",
    ]),
    'tamer': ('털깃 사냥 저고리', {'a': '#8a6a3a', 'b': '#6e5230', 'c': '#f0e6cc', 'd': '#4a3a2a', 'e': '#b8423a'}, [
        "................",
        "...cccccccccc...",
        "..bxcaaaaaacby..",
        "..bxaaaaabaaby..",
        "..bxaaaaabaaby..",
        "...dddddddeedd..",
        "...xaaaabaeey...",
        "..xaaaaabaaaay..",
        "..ybbaabbaabby..",
    ]),
    'jeogori': ('연분홍 저고리', {'a': '#f2b8c0', 'b': '#e09aa6', 'c': '#f8f2e6', 'd': '#b8324a', 'e': '#c7536a'}, [
        "................",
        "....xcccccb.....",
        "..cxacaaddaabc..",
        "..cxaacadaaabc..",
        "..cxaaaadaaabc..",
        "...bbbbbdbbbb...",
        "........d.......",
        "........e.......",
    ]),
    'vest': ('무명 조끼', {'a': '#8a6a4a', 'b': '#6a4e34', 'c': '#efe7d2', 'd': '#3a5a7a', 'e': '#cfc6ae'}, [
        "................",
        "....xacccab.....",
        "...xaaaccaaab...",
        "..exaaaccaaabe..",
        "..exaaaccaaabe..",
        "...dddddddddd...",
    ]),
    'magoja': ('짧은 마고자', {'a': '#7a2e3a', 'b': '#5a1e2a', 'c': '#e8d9b0', 'd': '#d6aa52', 'e': '#4a1420'}, [
        "................",
        "....xaccccab....",
        "...xaaaddaaab...",
        "..bxaaaaaaaaby..",
        "..bxaaaddaaaby..",
        "...ybbbbbbbby...",
    ]),
    'jeoksam': ('짧은 적삼', {'a': '#bcd4e6', 'b': '#94b0c6', 'c': '#f8f2e6', 'd': '#3a5a8a', 'e': '#7a96ac'}, [
        "................",
        "....xacaaaab....",
        "...xaaacaaaab...",
        "..bxaaaacaaaby..",
        "..bxaaaaadaaby..",
        "...ybbbbbdbby...",
    ]),
}


BOTTOM_SHAPES = {
    'pants': [
        "...xaaaabaaab...",
        "...xaaaabaaab...",
        "....xab..xab....",
        "....xab..xab....",
        "....zzu..zzu....",
    ],
    'baggy': [
        "...xaaaabaaab...",
        "..xaaaaabaaaab..",
        "..xaab....xaab..",
        "...dd......dd...",
        "....zzu..zzu....",
    ],
    'boots': [
        "...xaaaabaaab...",
        "...xaaaabaaab...",
        "....zzu..zzu....",
        "....zzu..zzu....",
        "...zzzu..zzzu...",
    ],
    'skirt': [
        "....xaaaaaab....",
        "...xaaaaaaaab...",
        "...xaabaaaaab...",
        "..xaaabaaaaabb..",
        "..xaabaaaabaab..",
        "..ybbbbbbbbbby..",
        "....zz....zz....",
    ],
}

BOTTOMS = {
    'guard': ('검은 바지와 가죽 장화', 'boots', '#3a3030', '#2a2222', '#4a3020', '#c9a24a'),
    'scout': ('고동 바지와 미투리', 'pants', '#6a4a32', '#55392a', '#c8a46a', '#c8a46a'),
    'exorcist': ('쪽빛 대님 바지', 'baggy', '#363b48', '#2a2e38', '#2a2e40', '#e8e2dc'),
    'medic': ('무명 대님 바지', 'baggy', '#e6dcc4', '#cbbfa4', '#6a4a32', '#8fa676'),
    'seal': ('검은 바지', 'pants', '#2c2830', '#201c24', '#3a2c56', '#c9a24a'),
    'shadow': ('먹빛 바지와 짚신', 'pants', '#24242a', '#18181d', '#c8a46a', '#9a2a36'),
    'tamer': ('각반 바지와 미투리', 'pants', '#5c5a3c', '#46442c', '#c8a46a', '#b8423a'),
    'chima': ('남빛 치마', 'skirt', '#2f3f72', '#25325c', '#f8f2e6', '#b8324a'),
}


def bottom_grid(key, frame):
    name, shape, a, b, z, d = BOTTOMS[key]
    rows = BOTTOM_SHAPES[shape]
    y0 = 32 - len(rows) + 1
    g = Grid()
    for y, r in enumerate(rows):
        assert len(r) == 16, (key, y, len(r))
        for x, ch in enumerate(r):
            if ch == '.':
                continue
            yy = y0 + y
            if frame == 'walk' and shape != 'skirt' and x < 8 and yy >= 30:
                yy -= 1
            g.set(OX + x, yy, ch)
    return name, {'a': a, 'b': b, 'z': z, 'd': d}, g


def top_grid(key):
    name, pal, rows = TOPS[key]
    g = Grid()
    for y, r in enumerate(rows):
        assert len(r) == 16, (key, y, len(r))
        for x, ch in enumerate(r):
            if ch != '.' and not (y in (5, 6) and x in (2, 13)) and not (y in (1, 2) and (x < 3 or x > 12)):
                g.set(OX + x, OY + y, ch)
    return name, pal, g


ACC = {
    'flowerpin': ('꽃 머리핀', {'a': '#e86a8a', 'b': '#b8405e', 'c': '#f6d36a'}, 19, 8, [
        ".a.",
        "aca",
        ".ab",
    ]),
    'glasses': ('둥근 안경', {'a': '#6a5446', 'b': '#c9d6e0'}, 4, 13, [
        ".aaaaaa......aaaaaa.",
        "a......a....a......a",
        "a......a....a......a",
        "a......aaaaaa......a",
        "a......a....a......a",
        "a......a....a......a",
        ".aaaaaa......aaaaaa.",
    ]),
    'earring': ('구슬 귀걸이', {'a': '#d6aa52', 'b': '#e86a6a', 'c': '#fff4d0'}, 3, 18, [
        "a....................a",
        "b....................b",
        "c....................c",
    ]),
    'scarf': ('목도리', {'a': '#b8324a', 'b': '#8a2236', 'c': '#e8a0aa'}, 9, 21, [
        ".aaaaaaaa.",
        "aacaacaaab",
        ".bbbbabbb.",
        "......ab..",
        "......ab..",
    ]),
    'norigae': ('노리개', {'a': '#d6aa52', 'b': '#3f8a6a', 'c': '#b8324a'}, 17, 27, [
        "a.",
        "b.",
        "cc",
        "cc",
    ]),
    'foxmask': ('여우 탈', {'a': '#f6f1ea', 'b': '#b8324a', 'c': '#3a3030', 'd': '#d8d0c4'}, 19, 2, [
        "a...a.",
        "aa.aa.",
        "aaaaad",
        "abaabd",
        "acaacd",
        ".aaad.",
        "..ad..",
    ]),
}


def acc_grid(key):
    name, pal, ox, oy, rows = ACC[key]
    g = Grid()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != '.':
                g.set(ox + x, oy + y, ch)
    return name, pal, g
