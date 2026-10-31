# ── 진품 ──
def fan(W, H, bx, by, a0, a1, R, n, body, notch=.22):
    cv = grid(W, H)
    for y in range(H):
        for x in range(W):
            dx, dy = x + .5 - bx, by - (y + .5)
            d = math.hypot(dx, dy); ang = math.degrees(math.atan2(dy, dx)) % 360
            if d > R or not (a0 <= ang <= a1): continue
            f = (ang - a0) / (a1 - a0) * n; k = min(n - 1, int(f)); fr = f - k
            if d > R - .9 and (fr < notch or fr > 1 - notch): continue
            cv[y][x] = ('oq'[k % 2] if d > R - 2.2 else 'ac'[k % 2])
    stamp(cv, body)
    return show(cv)
FOX = {'a': '#f8f0e0', 'c': '#d9bd90', 'o': '#f4a050', 'q': '#e07c34', 'r': '#d83a4a', 'n': '#3a2418', 'e': '#5a2410', 'i': '#b07050'}
FB = '''
.oo.oo.......
.aa.cc.o...o.
oaakcc.aa.aa.
oaakccaaaaaaa
ccakccaieaiea
.ccaccaeeaeea
..ccccraanaar
...aaaaaaaaa.
...aaaaaaaaa.
...oo.o..o.oo'''
FB_STEP = '''
oo.oo........
aa.cc..o...o.
aakcc..aa.aa.
oakccaaaaaaaa
cakccaaieaiea
.ccaccaeeaeea
..ccccraanaar
...aaaaaaaaa.
...aaaaaaaaa.
....oo.o.o.o.'''.replace('aaaaaaaa\n', 'aaaaaaa\n', 1)
FB_SLEEP = '''
.......o...o.
.......aa.aa.
......aaaaaaa
oo....akkakka
ccaaaaraanaar
oaccaaaaaaaaa
.oocccccccaa.'''
FA = '''
..........o...o.
..........aa.aa.
.........aaaaaaa
.........aieaiea
.........aeeaeea
.........raanaar
..........acca..
.....aaaaaaacca.
....aaaaaaaaaaa.
....aaaaaaaaaa..
....aa.aa...aa.a
....oo.oo...oo.o'''
FA_STEP = '\n'.join(FA.split('\n')[:-2]) + '\n.....aa.aa..aa.a\n....oo...oo.oo.o'
FA_SLEEP = '''
..........o...o.
..........aa.aa.
.........aaaaaaa
.........akkakka
.....aaaaraanaar
...aaaaaaaaaaaaa
...aaaaaaaaaaaa.'''
A9 = [70 + n * 13.5 for n in range(9)]
pet(id='baby_gumiho', name='새끼 구미호', grade=3, kind='mirror', likes='treat_meat',
    desc='꼬리가 아직 셋뿐인 어린 여우입니다. 천 년을 채우면 아홉 꼬리가 된다며 날마다 꼬리를 세어 봅니다.',
    baby=dict(pal=FOX, idle=FB, step=FB_STEP, sleep=FB_SLEEP),
    adult=dict(pal=FOX,
        idle=fan(16, 12, 6.0, 9.4, 78, 196, 9.2, 9, FA),
        step=fan(16, 12, 6.0, 9.4, 72, 190, 9.2, 9, FA_STEP),
        sleep=fan(16, 7, 5.6, 6.8, 112, 186, 6.6, 9, FA_SLEEP, .26)))

HAE = {'a': '#e8c46a', 'b': '#c89a3e', 'm': '#3f9a8c', 'n': '#7cd0bc', 'h': '#f4ecd2', 'y': '#f2d050', 'r': '#c0392b', 'q': '#3a2418', 'c': '#f6e6b8', 'e': E, 'i': I, 'p': PK}
pet(id='baby_haetae', name='아기 해태', grade=3, kind='ward', likes='treat_rice',
    desc='옳고 그름을 가린다는 해태의 새끼입니다. 불기운을 먹고 자라서 화로 곁을 떠나지 않습니다.',
    baby=dict(pal=HAE,
        idle='''
.......h....
....mnmhmnm.
...maaaaaaam
...maieaieam
.m.maeeaeeam
mnm.paaqaapm
.m..mmyymmm.
.mabaabaaaa.
..aaaaaaaaa.
..aa.a..a.aa''',
        step_tail='''
...aa.a.a.a.''',
        sleep='''
.......h....
....mnmhmnm.
...maaaaaaam
.m.makkakkam
mnm.paaqaapm
.mabmmyymmmm
.aaaaaaaaaaa'''),
    adult=dict(pal=HAE,
        idle='''
..........h.....
.......mnmhmnm..
......mnmhhhmnm.
.....mmaaaaaaamm
.....maaieaieaam
..m..maaeeaeeaam
.mnm.mnpaaqaapnm
.m.m..mmmyymmmm.
.mn..mabaabaabcm
..mmaabaabaabcc.
...abaabaabaacc.
...aaaaaaaaaaaa.
...aa.aa...aa.aa
...bb.bb...bb.bb''',
        step_tail='''
....aa.aa.aa.aa.
....bb.bb.bb.bb.''',
        sleep='''
..........h.....
.......mnmhmnm..
......mnmhhhmnm.
.....mmaaaaaaamm
..m..maakkakkaam
.mnm.mnpaaqaapnm
.m.m.mmmmyymmmmm
.mnaabaabaabaccm
.aaaaaaaaaaaaaa.'''))

IMU = {'a': '#3a9a8a', 'b': '#2a6e6a', 'c': '#ece2b4', 'f': '#7ad8c0', 'g': '#f6f4ff', 'h': '#b8c8f8', 'n': '#1e4a48', 'e': E, 'i': I, 'p': PK}
pet(id='bead_imugi', name='구슬 이무기', grade=3, kind='water', likes='treat_honey',
    desc='용이 되려고 여의주를 품고 사는 어린 이무기입니다. 구슬을 잃어버릴까 봐 잠도 감고 잡니다.',
    baby=dict(pal=IMU,
        idle='''
......aaaaa.
.....afaaafa
.....aieaiea
.....aeeaeea
.....pacccap
..bba.accagg
.babaa.aagjh
.aa.baaaa...
.bab.bbab...'''.replace('j', 'g'),
        step='''
......aaaaa.
.....afaaafa
.....aieaiea
.....aeeaeea
.....pacccap
.bba..accagg
babaa.aaaggh
.a..baaaa...
.ab..babab..''',
        sleep='''
......aaaaa.
.....afaaafa
.....akkakka
..bbapacccap
.babaabaaggg
bab.baaaaggh
.abababab...'''),
    adult=dict(pal=IMU,
        idle='''
.........f..f...
........aaaaaa..
.......afaaaafa.
.......aieaaiea.
.......aeeaaeea.
.......paccccap.
........acccca..
.bf......acca...
.ba.....aacb..gg
.bab...aaccb.ggh
..baabaacccb.ghh
..bacccccccb....
...bbbbbbbb.....''',
        step='''
.........f..f...
........aaaaaa..
.......afaaaafa.
.......aieaaiea.
.......aeeaaeea.
.......paccccap.
........acccca..
.........acca...
fb......aacb..gg
.bab...aaccb.ggh
..baabaacccb.ghh
..bacccccccb....
...bbbbbbbb.....''',
        sleep='''
.........f..f...
........aaaaaa..
.......afaaaafa.
.......akkaakka.
.bf....paccccap.
.bab...aacccab..
..baabaaccccb.gg
..bacccccccb.ggh
...bbbbbbbb...hh'''))

TIG = {'a': '#f0902a', 'd': '#2e1a10', 'c': '#fbf2e0', 'n': '#3a2418', 'e': E, 'i': I, 'p': PK}
pet(id='baby_sangun', name='아기 산군', grade=3, kind='breaker', likes='treat_meat',
    desc='산의 임금 범의 새끼입니다. 아직은 어흥 소리보다 하품 소리가 더 큽니다.',
    baby=dict(pal=TIG,
        idle='''
....aa...aa.
....aadadaa.
.d..aieaiea.
a...deeaeed.
d...pccnccp.
.adaadaacccc
.aadaadacca.
.aaaaaaaaaa.
.cc.c...c.cc''',
        step_tail='''
..cc.c.c.cc.''',
        sleep='''
....aa...aa.
....aadadaa.
....akkakka.
dad.pccnccp.
.adaadaadaaa
.aaaaaaaaaa.'''),
    adult=dict(pal=TIG,
        idle='''
.........aa...aa
.........aadadaa
.d.......aieaiea
a........deeaeed
d........pccnccp
.a.......acccca.
.d.aadaadaadccca
..aadaadaadaccca
..aaadaadaadaaaa
..aaaaaaaaaaaaa.
..aa.aa....aa.aa
..cc.cc....cc.cc''',
        step_tail='''
...aa.aa..aa.aa.
..cc...cc.cc..cc''',
        sleep='''
.........aa...aa
.........aadadaa
.........akkakka
.........deeaeed
dad......pccnccp
.adaadaadaadccca
.aaadaadaadaaaaa
..aaaaaaaaaaaaa.'''.replace('deeaeed', 'daaaaad')))

MOON = {'a': '#f4f0fa', 'c': '#cfc6e0', 'p': '#f2a8bc', 'y': '#f2d060', 'n': '#b07a42', 'r': '#fbf8ee', 'g': '#7ab060', 'e': '#2a2a4a', 'i': '#8a8ab0'}
pet(id='moon_rabbit', name='달토끼', grade=3, kind='sky', likes='treat_rice',
    desc='달에서 떡방아를 찧다 내려왔다는 토끼입니다. 이마에 초승달 무늬가 은은하게 빛납니다.',
    baby=dict(pal=MOON, lid='a',
        idle='''
.....aa.aa..
.....pa.pa..
.....pa.pa..
....aaayaaa.
....aieaiea.
....aeeaeea.
....paanaap.
.....caaarrg
..ccaaaaaa..
....aaa.aaa.''',
        step_tail='''
..ccaaaaaa..
...aaa...aa.''',
        sleep='''
....aaaa....
...apppaaa..
....aaayaaa.
....akkakka.
....paanaap.
..cccaaaarrg
.ccaaaaaaaa.'''),
    adult=dict(pal=MOON, lid='a',
        idle='''
.....aa.aa....
.....pa.pa..nn
.....pa.pa..nn
....aaaayaa.n.
....aieaiea.n.
....aeeaeea.n.
....paanaapn..
.....caaaan...
.cc..aaaaan...
.ccaaaaaaan...
...aaaaaa.n...
....aa.aa.n...
...aaa.aaann..''',
        step='''
.....aa.aa....
.....pa.pa....
.....pa.pa..nn
....aaaayaa.nn
....aieaiean..
....aeeaeean..
....paanaapn..
.....caaaan...
.cc..aaaaan...
.ccaaaaaaan...
...aaaaaa.n...
...aa...aan...
..aaa...aann..''',
        sleep='''
.....aaaa.....
....apppaaa...
....aaaayaa...
....akkakka...
....paanaap...
.cc.caaaaaa...
.ccaaaaaaaaa..
..aaaaaaaaaann'''))

DOLL = {'a': '#c8945a', 'b': '#94643a', 'c': '#e2b884', 'l': '#6ab04a', 'm': '#3e7a2e', 's': '#b8f4a8', 'e': '#3a2414', 'i': '#f6e6c8', 'p': '#e88a7a'}
pet(id='wooden_doll', name='목각 인형 정령', grade=3, kind='wood', likes='treat_honey',
    desc='오래된 느티나무 가지로 깎은 인형에 나무 정령이 깃들었습니다. 머리의 새싹이 기분 따라 흔들립니다.',
    baby=dict(pal=DOLL, noline='s',
        idle='''
....lml...
...acaaa..
..acaaaaa.
..aieaiea.
..aeeaeea.
..paabaap.
.s.aaaaa..
..accccca.
...bbbbb..
...cc.cc..''',
        step='''
...lml....
...acaaa..
..acaaaaa.
..aieaiea.
..aeeaeea.
..paabaap.
...aaaaa.s
..accccca.
...bbbbb..
..cc...cc.''',
        sleep='''
..........
....lml...
...acaaa..
..acaaaaa.
..akkakka.
..paabaap.
.acccccca.
.abbbbbbca'''),
    adult=dict(pal=DOLL, noline='s',
        idle='''
...l.lml.l..
....lmmml...
....aaaaa...
...acaaaaa..
..acaaaaaaa.
..aaieaieaa.
..aaeeaeeaa.
..apaabaapa.
s..abbbbba..
...aaaaaaa..
..aacccccaa.
.ab.cbcbc.ba
....bbbbb...
...ccc.ccc..''',
        step='''
..l.lml.l...
....lmmml...
....aaaaa...
...acaaaaa..
..acaaaaaaa.
..aaieaieaa.
..aaeeaeeaa.
..apaabaapa.
...abbbbba.s
...aaaaaaa..
..aacccccaa.
.ab.cbcbc.ba
....bbbbb...
..ccc...ccc.''',
        sleep='''
............
...l.lml.l..
....lmmml...
....aaaaa...
...acaaaaa..
..acaaaaaaa.
..aakkakkaa.
..apaabaapa.
.aaabbbbbaa.
abcbcbcbcbca
abbbbbbbbbbc'''))

# ── 명품 ──
BUL = {'a': '#7c8496', 'b': '#596070', 'c': '#aab2c0', 'n': '#dfe5ee', 'r': '#b0603a', 'e': E, 'i': I, 'p': PK}
pet(id='baby_bulgasari', name='아기 불가사리', grade=4, kind='giant', likes='treat_rice',
    desc='밥풀로 빚어졌다는 쇠 먹는 짐승의 새끼입니다. 바늘 같은 털이 아직 말랑해서 안아 줄 만합니다.',
    baby=dict(pal=BUL,
        idle='''
.n.n.n......
nnnnnb.....b
nbnbnaaaaaaa
.nbnbaieaiea
..bbbaeeaeea
.aaaapaacaap
.aaaaaaacaa.
.aaaaaa.cc..
.bb.bb..bb..''',
        step='''
n.n.n.......
nnnnnb.....b
nbnbnaaaaaaa
.nbnbaieaiea
..bbbaeeaeea
.aaaapaacaap
.aaaaaaaacc.
.aaaaaa.ac..
..bb.bb.bb..''',
        sleep='''
.n.n.n......
nnnnnb.....b
nbnbnaaaaaaa
.nbnbakkakka
.abbbpaacaap
.aaaaaaaacaa
.aaaaaaaaacc'''),
    adult=dict(pal=BUL,
        idle='''
..n.n.n.n.......
.nnnnnnnnb....b.
nnbnbnbnbaaaaaa.
nbnbnbnbaaaaaaaa
.nbnbnbnaieaaiea
..bbbbbnaeeaaeea
..aaaaaaapaccapa
..aaaaaaaaaccaa.
.aaaaaaaaaaacca.
.aacaaaaaaaa.cc.
.aacaaaaaaa...c.
.aaaaaaaaaa.....
.bbb.bb..bbb....
.bbb.bb..bbb....'''.replace('aieaaiea', 'aieaaiea'),
        step='''
.n.n.n.n........
.nnnnnnnnb....b.
nnbnbnbnbaaaaaa.
nbnbnbnbaaaaaaaa
.nbnbnbnaieaaiea
..bbbbbnaeeaaeea
..aaaaaaapaccapa
..aaaaaaaaaccaa.
.aaaaaaaaaaaacc.
.aacaaaaaaaa.cc.
.aacaaaaaaa..c..
.aaaaaaaaaa.....
..bbb.bb.bbb....
..bbb.bb.bbb....''',
        sleep='''
..n.n.n.n.......
.nnnnnnnnb....b.
nnbnbnbnbaaaaaa.
nbnbnbnbaaaaaaaa
.nbnbnbnakkaakka
.abbbbbnaaaaaaaa
.aaaaaaaapaccapa
aacaaaaaaaaccaa.
aacaaaaaaaaaacc.
.aaaaaaaaaaaaacc'''))

SUN = {'a': '#34364c', 'h': '#565a80', 'g': '#f2c440', 'y': '#e8a030', 'r': '#cf3a2c', 'o': '#f08a3a', 'e': '#f2c440', 'i': I, 'p': '#c88aa0'}
pet(id='samjogo_chick', name='삼족오 새끼', grade=4, kind='sky', likes='treat_honey',
    desc='해 속에 산다는 세 발 까마귀의 새끼입니다. 깃털 끝이 햇살처럼 금빛으로 반짝입니다.',
    baby=dict(pal=SUN, line='g',
        idle='''
......g..g..
.......gg...
......aaaa..
.....aaaaaa.
....aaaaiea.
....aaaaeeyy
ag..gaaaaap.
.aggggaaaaa.
..aahhaaaa..
....y.y.y...''',
        step_tail='''
..aahhaaaa..
...y..y..y..''',
        sleep='''
......g..g..
.......gg...
......aaaa..
.....aaaaaa.
....aaaagggy
ag..gaaaaap.
.aggggaaaaa.
..aaaaaaaa..'''),
    adult=dict(pal=SUN, line='g',
        idle='''
..rrrr..........
.rroorr....g..g.
rroooorr....gg..
rroooorr..aaaa..
rroooorr.aaaaaa.
.rroorr.aaaaaiea
..rrrr..aaaaaeey
......ggaaaaaap.
ag..ggahhaaaaa..
.agggaahhhaaaa..
..aaaaaaaaaaa...
.....aaaaaaa....
......y.y.y.....
.....yy.yy.yy...''',
        step_tail='''
.....y..y..y....
....yy..yy.yy...''',
        sleep='''
..rrrr..........
.rroorr....g..g.
rroooorr....gg..
rroooorr..aaaa..
rroooorr.aaaaaa.
.rroorr.aaaaaaaa
..rrrr..aaaaaggy
......ggaaaaaap.
ag..ggahhaaaaa..
.agggaahhhaaaa..
..aaaaaaaaaaa...
...aaaaaaaaaa...'''))

GIR = {'a': '#ecc462', 's': '#c8983a', 'm': '#4aa090', 'h': '#f6f0d8', 'c': '#f8ecc4', 'n': '#8a5a30', 'f': '#5a4030', 'e': E, 'i': I, 'p': PK}
pet(id='baby_girin', name='아기 기린', grade=4, kind='sky', likes='treat_herb',
    desc='사슴 몸에 외뿔과 비늘을 지닌 상서로운 기린의 새끼입니다. 풀 한 포기도 밟지 않으려 사뿐사뿐 걷습니다.',
    baby=dict(pal=GIR,
        idle='''
......a.h.a.
....maaaaaaa
...mmaieaiea
...mmaeeaeea
m.mm.pacncap
.mmasaaccc..
.aasasaaaa..
..asasaaas..
..a.a..a.a..
..f.f..f.f..''',
        step_tail='''
...a.a.a.a..
...f.f.f..f.''',
        sleep='''
......a.h.a.
....maaaaaaa
...mmakkakka
m.mm.pacncap
.mmasaacccc.
.aasasasaaaa
..ffaaaaaff.'''),
    adult=dict(pal=GIR,
        idle='''
...........h....
.........a.h.a..
.......maaaaaaa.
......mmaieaiea.
......mmaeeaeea.
.....mmmpacncap.
.......mmaacca..
m....mmmaaaccc..
mm.aaasasasaac..
.mmasasasasaaa..
...asasasasaas..
...aa.a....a.a..
...a..a....a..a.
...f..f....f..f.''',
        step_tail='''
...aa.a...a.a...
..a....a.a...a..
..f....f.f...f..''',
        sleep='''
...........h....
.........a.h.a..
.......maaaaaaa.
......mmakkakka.
.....mmmpacncap.
m....mmmaaacc...
mm.aaasasasaacc.
.mmasasasasasaaa
...afasasasaafa.
....ffffffffff..'''))

DRA = {'a': '#3a7ad8', 'b': '#2a58a8', 'c': '#f2e2a4', 'h': '#f0c850', 'f': '#7ad8e8', 'w': '#f2e2a4', 'e': E, 'i': I, 'p': PK, 'n': '#1e3a78'}
pet(id='little_cheongryong', name='꼬마 청룡', grade=4, kind='water', likes='treat_fish',
    desc='동쪽 하늘을 지킨다는 푸른 용의 새끼입니다. 재채기를 하면 작은 구름이 퐁 하고 나옵니다.',
    baby=dict(pal=DRA,
        idle='''
.....h.h.h.h
......haaah.
.....aaaaaaa
.....aieaiea
.f...aeeaeea
af..wpacncap
aaf.aaccccc.
.aafaacccca.
..aaaaacca..
....aa..aa..''',
        step_tail='''
..aaaaacca..
...aa..aa...''',
        sleep='''
.....h.h.h.h
......haaah.
.....aaaaaaa
.f...akkakka
af..wpacncap
aafaaaccccca
.aaaaaaacccc'''),
    adult=dict(pal=DRA,
        idle='''
.........h.h.h.h
..........haaah.
.........aaaaaaa
........faieaiea
.......ffaeeaeea
.......ffpacncap
......ffaaacccaw
..f..ffaaaccccw.
.faf.faaaccccc..
fabaffaabcccca..
fab..aabbccccaa.
fab..ab.aacca...
.fabba..aa..aa..
..bb...bbb..bbb.''',
        step_tail='''
.fabba.aa...aa..
..bb..bbb...bbb.''',
        sleep='''
.........h.h.h.h
..........haaah.
.........aaaaaaa
........fakkakka
.......ffpacncap
...f..ffaaacccaw
..faf.faaaccccw.
.fabaffaaacccccc
fab.aaabbbccccaa
.fabbaaaaaaaaaa.'''))

JANG = {'a': '#c89058', 'b': '#7a4a26', 'h': '#2a2630', 'g': '#4a4452', 'w': '#f6f0e0', 'e': E, 'i': I, 'p': '#e8705a', 'r': '#c83a2a'}
pet(id='little_jangseung', name='꼬마 장승', grade=4, kind='ward', likes='treat_herb',
    desc='마을 어귀를 지키던 천하대장군이 아기만 하게 줄어들었습니다. 눈을 부라려도 하나도 무섭지 않습니다.',
    baby=dict(pal=JANG,
        idle='''
..hhhhh..
.ghhhhhg.
hhhhhhhhh
.bbbabbb.
.aieaiea.
.aeeaeea.
.paabaap.
.awkwkwa.
.aabbbaa.
..b...b..''',
        step='''
..hhhhh..
.ghhhhhg.
hhhhhhhhh
.bbbabbb.
.aieaiea.
.aeeaeea.
.paabaap.
.awkwkwa.
.aabbbaa.
...b.b...''',
        sleep='''
..hhhhh..
.ghhhhhg.
hhhhhhhhh
.bbbabbb.
.akkakka.
.paabaap.
.abbbbba.
.aabbbaa.
aaaabaaaa'''),
    adult=dict(pal=JANG,
        idle='''
...hhhhh...
..ghhhhhg..
hhhhhhhhhhh
.abbbabbba.
.aaieaieaa.
.aaeeaeeaa.
.apaabaapa.
.aawkwkwaa.
.aabbbbbaa.
..abbbbba..
..aaaaaaa..
..aabbbaa..
..aaabaaa..
...b...b...''',
        step='''
...hhhhh...
..ghhhhhg..
hhhhhhhhhhh
.abbbabbba.
.aaieaieaa.
.aaeeaeeaa.
.apaabaapa.
.aawkwkwaa.
.aabbbbbaa.
..abbbbba..
..aaaaaaa..
..aabbbaa..
..aaabaaa..
....b.b....''',
        sleep='''
...hhhhh...
..ghhhhhg..
hhhhhhhhhhh
.abbbabbba.
.aakkakkaa.
.apaabaapa.
.aabbbbbaa.
.aabbbbbaa.
.aaaaaaaaa.
aaabbbbbaaa'''))

# ── 신품 ──
BAEK = {'a': '#f8f6f0', 'c': '#d8d4e8', 'h': '#e8c860', 'm': '#b8c8f4', 'g': '#e4f2ff', 'e': '#3a3a6e', 'i': '#8a8ac8', 'p': PK, 'n': '#8a8aa8'}
pet(id='baby_baektaek', name='아기 백택', grade=5, kind='ward', likes='treat_herb',
    desc='세상 모든 요괴의 이름을 안다는 백택의 새끼입니다. 몸 곳곳의 눈이 한꺼번에 깜빡이면 방 안이 환해집니다.',
    baby=dict(pal=BAEK, noline='g',
        idle='''
.g....h...h.
ggg...haiah.
.....aaaeaaa
.....aieaiea
.....aeeaeea
.....paanaap
.mcaieaaammg
mccaeeaaaam.
.ccaaaaaaaa.
.cc.cc..cc.c''',
        step_tail='''
..cc.c.cc.c.''',
        sleep='''
......h...h.
......haaah.
.....aaakaaa
.....akkakka
.mcaaaaanaap
mccakkaaammm
.ccaaaaaaaaa'''.replace('aaanaap', 'paanaap')),
    adult=dict(pal=BAEK, noline='g',
        idle='''
g..........h...h
..g.......hh.hh.
..........haiah.
.........aaaeaaa
.........aieaiea
.........aeeaeea
.........paanaap
m.......mmmmmm..
mm.aaaaaaaaammg.
m.aaieaaieaamm..
m.aaeeaaeeaaam..
.aaaaaaaaaaaaa..
.acaaaaaaaaaca..
.cc.cc...cc.cc..''',
        step_tail='''
.cc...cc.cc..cc.''',
        sleep='''
...........h...h
..........hh.hh.
..........haaah.
.........aaakaaa
.........akkakka
m........paanaap
mm.aaaaaaaammmm.
m.aakkaakkaamm..
m.aaaaaaaaaaam..
.aaaaaaaaaaaaaa.'''))

BUT = {'d': '#1a2a5a', 'b': '#2a5aa0', 't': '#3ac0c8', 'g': '#c8f8ff', 's': '#9fe8ff', 'a': '#20203a', 'c': '#d8d4f0', 'e': '#20203a', 'i': '#8a88b0', 'p': PK}
pet(id='gwiheo_butterfly', name='귀허 나비', grade=5, kind='ghost', likes='treat_honey',
    desc='귀허의 검푸른 바다 위를 날던 나비가 길을 잃고 따라왔습니다. 날갯짓마다 물빛 가루가 흩날립니다.',
    baby=dict(pal=BUT, noline='s', lid='c',
        idle='''
.ddd...a...a
dbbbd...a.a.
dbtgbd.cccc.
dbttbdciecie
.dbbbdceecee
..ddddapcccp
.dbtbdaa....
.dbgbd.a..s.
..ddd.......''',
        step='''
.dd....a...a
dbbd....a.a.
dbtgd..cccc.
dbttd.ciecie
dbbtd.ceecee
.dddd.apcccp
..dbdaa.....
..dgd..a....
...d......s.''',
        sleep='''
..ddd.......
.dbbbd......
.dbtbd.a..a.
.dbgtd..aa..
.dbttbdcccc.
..dbbdckkckk
..ddddacccp.'''),
    adult=dict(pal=BUT, noline='s', lid='c',
        idle='''
.dddd......a...a
dbbbbdd.....a.a.
dbttgbbd...cccc.
dbtgttbbd.ciecie
dbbttbbbd.ceecee
.dbbbbbbdaapcccp
..dddddddaa.....
..dbbtbbda......
.dbtgtbd.a......
.dbbtbd.....s...
..dbbd..........
...dd.....s.....''',
        step='''
.ddd.......a...a
dbbbd.......a.a.
dbtgbd.....cccc.
dbttgbd...ciecie
dbbttbd...ceecee
.dbbbbdddaapcccp
..ddddddaa......
...dbtbda.......
..dbtgbd.a......
..dbbbd.........
...dbd.....s....
....d...........''',
        sleep='''
...dd...........
..dbbd..........
..dbtbd.........
..dbgtbd...a...a
..dbttbd....a.a.
..dbbbbd...cccc.
...dbbbbd.ckkckk
...dddddd.acccp.
.........aa.....'''))
