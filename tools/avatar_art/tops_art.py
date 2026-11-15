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
    'dallyeong': ('청사 단령', {'a': '#2e4a7a', 'b': '#22385e', 'c': '#efe7d2', 'd': '#c9a24a', 'e': '#8a2a2a'}, [
        "................",
        "....xccccab.....",
        "..bxaaccaaaaby..",
        "..bxaaaddddaby..",
        "..bxaaadeedaby..",
        "...dddddddddd...",
        "...xaaaaaaaab...",
        "..xaaaaaaaaaab..",
        "..xaaaaaaaaaab..",
        "..ybbbbbbbbbby..",
    ]),
    'furvest': ('설원 털배자', {'a': '#d8dde4', 'b': '#b4bcc8', 'c': '#f4f6f8', 'd': '#4a6a8a', 'e': '#8a6a4a'}, [
        "................",
        "...cccccccccc...",
        "..dxccaaaaccbd..",
        "..dxaaaaaaaabd..",
        "..dxaaaeaaaabd..",
        "...xaaaeaaaab...",
        "...cccccccccc...",
    ]),
    'saekdong': ('잔치 색동 저고리', {'a': '#f6efe0', 'b': '#ddd2bc', 'c': '#f8f2e6', 'd': '#c8382e', 'e': '#e8a53a', 'r': '#3f6fb5'}, [
        "................",
        "....xcccccb.....",
        "..ddacaaddaadd..",
        "..eeaacadaaaee..",
        "..rraaaadaaarr..",
        "...bbbbbdbbbb...",
        "........d.......",
        "........e.......",
    ]),
    'shadowrobe': ('봉연 그림자 도포', {'a': '#3a2c4a', 'b': '#2a1f38', 'c': '#d8c8ef', 'd': '#7a5ab0', 'e': '#b8a0e0'}, [
        "................",
        "....xacccab.....",
        "..bxaaaccaaaby..",
        "..bxaaaacaaaby..",
        "..bxaaaacaaaby..",
        "...dddddddddd...",
        "...xaaaacaaab...",
        "..xaaaaacaaaab..",
        "..xadaaacaadab..",
        "..ebebebebebeb..",
    ]),
    'fisher': ('어부 등거리', {'a': '#c8b48a', 'b': '#a8946a', 'c': '#efe7d2', 'd': '#6a8aa0', 'e': '#8a6a3a'}, [
        "................",
        "....xacccab.....",
        "..sxaaacaaaabs..",
        "..sxaaaacaaabs..",
        "..sxaaaacaaabs..",
        "...eeeeeeeeee...",
        "...xaaaacaaab...",
        "...ybbbbbbbby...",
    ]),
    'galot': ('갈옷 적삼', {'a': '#a0582e', 'b': '#7e4220', 'c': '#efe7d2', 'd': '#5a3020', 'e': '#c87a4a'}, [
        "................",
        "....xacaaaab....",
        "...xaaacaaaab...",
        "..bxaaaacaaaby..",
        "..bxaaaaadaaby..",
        "...ybbbbbdbby...",
    ]),
    'silkcheollik': ('비단 철릭', {'a': '#a02a3a', 'b': '#7e1e2c', 'c': '#f6e8c4', 'd': '#d6aa52', 'e': '#f2d06a'}, [
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
    'hoodie': ('쓰개 달린 겉옷', {'a': '#7a8290', 'b': '#5e6674', 'c': '#e4e6ea', 'd': '#687080', 'e': '#4a505c'}, [
        "................",
        "....baaaaab.....",
        "..bxaacaacaaby..",
        "..bxaacaacaaby..",
        "..bxaaaaaaaaby..",
        "...xaddddddab...",
        "...xaaaaaaaab...",
        "...ebbbbbbbbe...",
    ]),
    'knitvest': ('털실 조끼', {'a': '#6a8a5a', 'b': '#557046', 'c': '#f4efe2', 'd': '#c9a24a', 'e': '#e4dccb'}, [
        "................",
        "....xcccccb.....",
        "..cxacaaacaabc..",
        "..cxaadaadaabc..",
        "..cxadaadaadbc..",
        "...xaaaaaaaab...",
        "...ybbbbbbbby...",
    ]),
    'doroni': ('도롱이', {'a': '#b89a5a', 'b': '#957a40', 'c': '#d8c08a', 'd': '#6a5430', 'e': '#efe7d2'}, [
        "................",
        "....xeeeeeb.....",
        "..bacacacacacb..",
        "..bcacacacacab..",
        "..bacacacacacb..",
        "...cacacacaca...",
        "...acacacacac...",
        "..cacacacacaca..",
        "..dadadadadada..",
    ]),
    'durumagi': ('흰 두루마기', {'a': '#eceae2', 'b': '#cfcabc', 'c': '#f8f6f0', 'd': '#3a5a8a', 'e': '#b8b2a2'}, [
        "................",
        "....xacccab.....",
        "..bxaacacaaaby..",
        "..bxaaadddaaby..",
        "..bxaaaadaaaby..",
        "...xaaaadaaab...",
        "...xaaaacaaab...",
        "..xaaaaacaaaab..",
        "..xaaaaacaaaab..",
        "..ybbbbbcbbbby..",
    ]),
    'apron': ('앞치마 저고리', {'a': '#f4efe2', 'b': '#d8d0bc', 'c': '#f8f2e6', 'd': '#a0482e', 'e': '#7a3220'}, [
        "................",
        "....xcccccb.....",
        "..bxaaddddaaby..",
        "..bxaaddddaaby..",
        "..bxaaddddaaby..",
        "...eeeeeeeeee...",
        "....dddddddd....",
        "....dddddddd....",
        "....eeeeeeee....",
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
    'wide': [
        "...xaaaabaaab...",
        "..xaaaaabaaaab..",
        "..xaaaab.xaaab..",
        ".xaaaab..xaaaab.",
        "....zzu..zzu....",
    ],
    'wrap': [
        "...xaaaabaaab...",
        "...xaaaabaaab...",
        "....dad..dad....",
        "....ddd..ddd....",
        "....zzu..zzu....",
    ],
    'pleat': [
        "....xaaaaaab....",
        "...xabababaab...",
        "...xabababaab...",
        "..xaabababaabb..",
        "..xababababaab..",
        "..ybbbbbbbbbby..",
        "....zz....zz....",
    ],
    'stripe': [
        "...daaaabaaad...",
        "...daaaabaaad...",
        "....dab..xad....",
        "....dab..xad....",
        "....zzu..zzu....",
    ],
    'short': [
        "...xaaaabaaab...",
        "...xaaaabaaab...",
        ".....ss..ss.....",
        ".....ss..ss.....",
        "....zzu..zzu....",
    ],
    'bloom': [
        "....xaaaaaab....",
        "...xadaaadaab...",
        "...xaaabaaaab...",
        "..xaadaabaadab..",
        "..xaaaaaadaaab..",
        "..ybbbbbbbbbby..",
        "....zz....zz....",
    ],
}

SKIRTS = ('skirt', 'pleat', 'bloom')

BOTTOMS = {
    'guard': ('검은 바지와 가죽 장화', 'boots', '#3a3030', '#2a2222', '#4a3020', '#c9a24a'),
    'scout': ('고동 바지와 미투리', 'pants', '#6a4a32', '#55392a', '#c8a46a', '#c8a46a'),
    'exorcist': ('쪽빛 대님 바지', 'baggy', '#363b48', '#2a2e38', '#2a2e40', '#e8e2dc'),
    'medic': ('무명 대님 바지', 'baggy', '#e6dcc4', '#cbbfa4', '#6a4a32', '#8fa676'),
    'seal': ('검은 바지', 'pants', '#2c2830', '#201c24', '#3a2c56', '#c9a24a'),
    'shadow': ('먹빛 바지와 짚신', 'pants', '#24242a', '#18181d', '#c8a46a', '#9a2a36'),
    'tamer': ('각반 바지와 미투리', 'pants', '#5c5a3c', '#46442c', '#c8a46a', '#b8423a'),
    'chima': ('남빛 치마', 'skirt', '#2f3f72', '#25325c', '#f8f2e6', '#b8324a'),
    'redmoon': ('붉은 달 치마바지', 'wide', '#8a2030', '#6a1824', '#2a1c22', '#d8b25a'),
    'emberwrap': ('잔불 각반 바지', 'wrap', '#5a3a2a', '#46301f', '#c8a46a', '#e07a3a'),
    'inkpleat': ('먹빛 주름치마', 'pleat', '#2a2a30', '#1c1c22', '#efe7d2', '#9a2a36'),
    'haengjeon': ('행전 두른 바지', 'wrap', '#7a7460', '#5e5a48', '#6a4a32', '#efe7d2'),
    'jjokchima': ('쪽빛 홑치마', 'skirt', '#3a6a9a', '#2c5480', '#f8f2e6', '#efe7d2'),
    'leatherboots': ('가죽 장화 바지', 'boots', '#6a5446', '#54402f', '#3a2418', '#c9a24a'),
    'okchima': ('옥색 치마', 'skirt', '#9ad0c0', '#78b2a2', '#f8f2e6', '#3a7c6d'),
    'jeans': ('청바지와 운동화', 'pants', '#4a6a9a', '#3a5680', '#f4f4f4', '#c9a24a'),
    'jogger': ('줄무늬 운동 바지', 'stripe', '#2a2e3a', '#20232c', '#e8e8e8', '#efe7d2'),
    'shorts': ('무릎 반바지', 'short', '#c8a46a', '#a8844a', '#f4f4f4', '#efe7d2'),
    'flowerskirt': ('꽃무늬 치마', 'bloom', '#f2d06a', '#d8b04a', '#f8f2e6', '#e86a8a'),
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
            if frame == 'walk' and shape not in SKIRTS and x < 8 and yy >= 30:
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
    'mk_hairpin': ('먹 묻은 붓 비녀', {'a': '#8a5a32', 'b': '#2a2a2e', 'c': '#d8b25a', 'd': '#efebe0'}, 18, 0, [
        ".....bb",
        "....bbb",
        "...cb..",
        "..aa...",
        ".aa....",
        "aa.....",
    ]),
    'mk_nameplate': ('삐뚤빼뚤 이름패', {'a': '#efe2c4', 'b': '#8a5a32', 'c': '#2a2a2e', 'd': '#b8324a'}, 7, 23, [
        ".dd.",
        "bbbb",
        "baab",
        "bcab",
        "bacb",
        "bbbb",
    ]),
    'mk_lotus': ('연꽃 매듭 노리개', {'a': '#e89aa6', 'b': '#b8324a', 'c': '#d8b25a', 'd': '#6e2219'}, 17, 25, [
        ".c.",
        "a.a",
        "aba",
        ".c.",
        ".b.",
        "bdb",
        "b.b",
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
    'gat': ('흑립 갓', {'a': '#1e1a1c', 'b': '#4a4448', 'c': '#8a6a3a'}, 0, 1, [
        "..........abaaaaaa..........",
        "..........abaaaaaa..........",
        "..........abaaaaaa..........",
        "..........abaaaaaa..........",
        "..........cccccccc..........",
        "...aaaaaaaaaaaaaaaaaaaaaa...",
        "aaaabaaaaaaaaaaaaaaaaaabaaaa",
        ".......................c....",
        "........................c...",
        "........................c...",
    ]),
    'jokduri': ('혼례 족두리', {'a': '#2a2230', 'b': '#3f6fb5', 'c': '#d8b25a', 'd': '#c8382e'}, 10, 0, [
        "..c..c..",
        "..dccd..",
        ".aaaaaa.",
        "aabaacaa",
        "aaaaaaaa",
    ]),
    'lotushood': ('흑련 두건', {'a': '#26222c', 'b': '#3a3442', 'c': '#efe7d2', 'd': '#9a2a36'}, 3, 1, [
        ".......abbbbaa........",
        ".....aaabbaaaaaa......",
        "...aaaaaaaaaaaaaaaa...",
        "..aaaaaaaacdcaaaaaaa..",
        ".aaaaaaaaaacaaaaaaaaa.",
        "aaaaaaaaaaaaaaaaaaaaaa",
        "bbbbbbbbbbbbbbbbbbbbbb",
        "....................aa",
        ".....................a",
    ]),
    'satgat': ('삿갓', {'a': '#d8b46a', 'b': '#b08a46', 'c': '#8a6a3a'}, 0, 0, [
        ".............aa.............",
        "...........aabaaa...........",
        ".........aabaabaaba.........",
        ".......abaabaabaabaab.......",
        ".....aabaabaabaabaabaab.....",
        "...abaabaabaabaabaabaabaa...",
        ".aabaabaabaabaabaabaabaabaa.",
        "cccccccccccccccccccccccccccc",
    ]),
    'starpin': ('별빛 떨잠', {'b': '#a68a3c', 'c': '#e8d48a', 'd': '#fff4d0'}, 16, 2, [
        "..c..",
        ".cdc.",
        "ccdcc",
        ".c.c.",
        "..b..",
        "..c..",
    ]),
    'paeraengi': ('밀짚 패랭이', {'a': '#e2c27a', 'b': '#c4a050', 'c': '#b8324a'}, 3, 0, [
        "......aaaaaaaaaa......",
        "......abaaaaaaba......",
        "......abaaaaaaba......",
        "......cccccccccc......",
        "..aaaaaaaaaaaaaaaaaa..",
        "abbbbbbbbbbbbbbbbbbbba",
    ]),
    'horns': ('도깨비 뿔 머리띠', {'a': '#f2ead8', 'b': '#d0c4a8', 'c': '#9a2a36'}, 5, 0, [
        "..a............a..",
        "..aa..........aa..",
        "..ba..........ab..",
        "..bb..........bb..",
        "cccccccccccccccccc",
    ]),
    'nambawi': ('남바위', {'a': '#3a2c56', 'b': '#2a2040', 'c': '#7a5a3a', 'd': '#d8b25a'}, 3, 0, [
        "..........dd..........",
        ".......aaaaaaaa.......",
        ".....aaaaabbaaaaaa....",
        "...aaaaaaaaaaaaaaaaa..",
        "..aaaaaaaaaaaaaaaaaaa.",
        ".aaaaaaaaaaaaaaaaaaaa.",
        "cccccccccccccccccccccc",
        "ac..................ca",
        "ac..................ca",
        "ac..................ca",
        "cc..................cc",
        ".c..................c.",
    ]),
    'cap': ('챙 모자', {'a': '#3a5a9a', 'b': '#2a4478', 'c': '#f4efe2'}, 3, 1, [
        ".......aaaaaaaa.......",
        ".....aaaaaaaaaaaa.....",
        "...aaaaaaacaaaaaaaa...",
        "..aaaaaaaaaaaaaaaaaa..",
        ".aaaaaaaaaaaaaaaaaaaa.",
        "aaaaaaaaaaaaaaaaaaaaaa",
        "bbbbbbbbbbbbbbbbbbbbbb",
        "...bbbbbbbbbbbbbbbb...",
    ]),
    'headphone': ('소리 귀덮개', {'a': '#2a2a30', 'b': '#c8382e', 'c': '#efe7d2'}, 0, 0, None),
    'shades': ('검은 색안경', {'a': '#1a1a1e', 'b': '#2e2e38', 'c': '#8a8aa0'}, 5, 14, [
        "aaaaaaaaaaaaaaaaaa",
        "abbbbbba..abbbbbba",
        "abbcbbba..abbcbbba",
        ".abbbba....abbbba.",
        "..aaaa......aaaa..",
    ]),
    'flowercrown': ('꽃 화관', {'a': '#e86a8a', 'b': '#f2d06a', 'c': '#fff4d0', 'd': '#4f8a4a'}, 5, 4, [
        ".a...b...a...b...a",
        "aca.bcb.aca.bcb.ac",
        "dddddddddddddddddd",
    ]),
    'catears': ('고양이 귀 머리띠', {'a': '#3a3036', 'b': '#e8a0aa', 'c': '#3a3036'}, 5, 0, [
        "..a............a..",
        ".aba..........aba.",
        "abbba........abbba",
        "aaaaa........aaaaa",
        "cccccccccccccccccc",
    ]),
    'ribbon': ('붉은 머리끈', {'a': '#c8382e', 'b': '#e86a6a', 'c': '#8a1e1e'}, 18, 2, [
        "aa..aa",
        "abaaba",
        "aaccaa",
        "abaaba",
        "aa..aa",
        "..a.a.",
    ]),
}


def headphone_rows():
    W, cx, cy, rx, ry = 28, 13.5, 12.4, 13.6, 11.6
    rows = [['.'] * W for _ in range(18)]
    for y in range(0, 11):
        dy = (y + .5 - cy) / ry
        dx = rx * max(0, 1 - dy * dy) ** .5
        for x in (round(cx - dx), round(cx + dx)):
            if 0 <= x < W:
                rows[y][x] = 'a'
    for y in range(0, 2):
        dy = (y + .5 - cy) / ry
        dx = rx * max(0, 1 - dy * dy) ** .5
        for x in range(round(cx - dx), round(cx + dx) + 1):
            rows[y][x] = 'a'
    for y in range(11, 17):
        for x in (0, 1, 2, 25, 26, 27):
            rows[y][x] = 'b' if x in (1, 26) and 12 <= y <= 15 else 'a'
    rows[13][1] = rows[13][26] = 'c'
    return [''.join(r) for r in rows]


ACC['headphone'] = ACC['headphone'][:4] + (headphone_rows(),)


def acc_grid(key):
    name, pal, ox, oy, rows = ACC[key]
    g = Grid()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != '.':
                g.set(ox + x, oy + y, ch)
    return name, pal, g
