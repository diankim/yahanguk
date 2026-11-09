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
        "...xbadbbdabb...",
        "...ebbdbbdbbe...",
    ]),
    'shadow': ('먹빛 누비 전포', {'a': '#2e2a36', 'b': '#3e3848', 'c': '#e8e2dc', 'd': '#9a2a36', 'e': '#d6aa52'}, [
        ".......ee.......",
        "....xbcccbb.....",
        "..bxaaaeaaabd...",
        "..bxaaaaaaadby..",
        "..bxaaaeaaadby..",
        "...xaaaaaaadb...",
        "...xaaaeaaadb...",
        "...xaaaaaaad....",
        "...ybbbbbbbdd...",
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
}


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
