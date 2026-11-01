# 롤백 뒤 더하는 꼬마 동무 6종(사용자 요청, 2026-10-31): 누렁 줄고양이(치즈)·잿빛 장모 고양이·까치 고양이(턱시도), 똥개, 부리너구리(오리너구리), 산토끼
# ── 고양이 셋: 같은 몸틀에 빛깔만 다르다(o 줄무늬 · c 흰 털) ──
CAT_B = dict(
    idle='''
.....a...a..
....aaa.aaa.
....aoaoaoa.
o...aieaiea.
o...aeeaeea.
.o..pacncap.
.aaoaoacccc.
.aoaoaacccc.
.aa.a..c.cc.''',
    step_tail='''
..aa.a.c.cc.''',
    sleep='''
......a...a.
.....aaa.aaa
.....aoaoaoa
.aaaaakkakka
aoaoapacncap
accccccccaa.''')
CAT_A = dict(
    idle='''
........a...a..
.......aaa.aaa.
.......aoaoaoa.
.o.....aieaiea.
o......aeeaeea.
o......pacncap.
.o......accca..
..oaaaaaaccccc.
..aoaoaoacccca.
..aaoaoaaaaaaa.
..aa.aa...cc.c.
..aa.aa...cc.c.''',
    step_tail='''
...aa.aa..cc.c.
..aa...aa.c..c.''',
    sleep='''
.........a...a.
........aaa.aaa
........aoaoaoa
.aaaaaaaakkakka
aaoaoaoapacncap
aaaoaoaaacccaaa
.oooooooooooo..''')
def cat_form(base, pal, sub=()):
    f = {k: v for k, v in base.items()}
    for a, b in sub:
        f = {k: v.replace(a, b) for k, v in f.items()}
    return dict(pal=pal, **f)

CHEESE = {'a': '#f0a24e', 'o': '#c96f28', 'c': '#fbf1df', 'n': '#e07a86', 'e': E, 'i': I, 'p': PK}
pet(id='cheese_cat', name='누렁 줄고양이', grade=1, kind='shadow', likes='treat_fish',
    desc='노란 털에 주황 줄무늬가 진 고양이입니다. 장터 사람들은 「호박이」라고 부릅니다. 밥그릇 소리만 나면 어디서든 달려옵니다.',
    baby=cat_form(CAT_B, CHEESE), adult=cat_form(CAT_A, CHEESE))

# 잿빛 장모 고양이: 솜뭉치처럼 둥근 몸, 앞머리에 반쯤 가린 눈, 작은 코, 부숭한 꼬리(사용자 그림 참고)
LONG = {'a': '#cfd2d8', 's': '#9ea2ad', 'w': '#eef0f4', 'p': '#eaa6a6', 'e': '#3a3440', 'n': '#e58f98'}
LONG_B = dict(idle='''
..........a..a..
.........apaapa.
.......aaaaaaaa.
.....aaaaaaaaaaa
....aaasasasasaa
...aaaaseasaseaa
..aaaaaaaaanaaaa
s.aaawaaaaaaaaa.
ssaaaaaaaaaaaaa.
sssaaaaaaaaaaa..
sss.aaaaaaaaaa..
.s..asaasaasa...''', step_tail='''
.s..aasaasaasa..''', sleep='''
..........a..a..
.........apaapa.
......aaaaaaaaa.
....aaasasasasaa
ss.aaaaskkaskkaa
sssaaaaaaaanaaa.
.ssaaaaaaaaaaa..
....asaasaasa...''')
LONG_A = dict(idle='''
..............a...a...
.............apa.apa..
...........aaaaaaaaaa.
.........aaaaaaaaaaaaa
........aaasasasasasaa
.......aaaasasasasasaa
......aaaaaaseasaseaaa
.....aaaaaaaaaaanaaaaa
....aaaaaawaaaaaaaaaa.
s..aaawaaaaaaaaaaaaaa.
sssaaaaaaaaaaaaaaaaaa.
ssssaaaaaaaaaaaaaaaa..
sssssaaaaaaaaaaaaaaa..
.ss...asaaasaaasaa....''', step_tail='''
.ss...aasaaasaaasa....''', sleep='''
..............a...a...
.............apa.apa..
........aaaaaaaaaaaaa.
......aaaaasasasasasaa
ss..aaaaaaaskkaaskkaaa
sss.aaaaaaaaaaaanaaaaa
ssssaaaaaaaaaaaaaaaaa.
.sssaaaaaaaaaaaaaaaa..
..ss..asaaasaaasaa....''')
for f in (LONG_B, LONG_A): f['blink'] = f['idle'].replace('e', 's')
pet(id='gray_longhair', name='잿빛 장모 고양이', grade=1, kind='shadow', likes='treat_fish',
    desc='잿빛 털이 솜뭉치처럼 부푼 고양이입니다. 앞머리에 눈이 반쯤 가려도 밥그릇만큼은 용케 찾아갑니다.',
    baby=dict(pal=LONG, **LONG_B), adult=dict(pal=LONG, **LONG_A))

# 턱시도: 줄무늬 없이 검고, 주둥이·가슴·네 발이 희다
TUX = {'a': '#4a4553', 'c': '#f6f3ec', 'n': '#e48a96', 'e': '#c9b23a', 'i': '#fff4b0', 'p': '#d98a96'}
pet(id='tuxedo_cat', name='까치 고양이', grade=1, kind='shadow', likes='treat_fish',
    desc='까치처럼 검은 등에 흰 앞섶을 받쳐 입은 고양이입니다. 늘 차려입은 얼굴로 손님을 맞습니다.',
    baby=dict(pal=TUX, idle='''
.....a...a..
....aaa.aaa.
....aaaaaaa.
a...aieaiea.
a...aeeaeea.
.a..pacncap.
.aaaaaacccc.
.aaaaaacccc.
.cc.c..c.cc.''', step_tail='''
..cc.c.c.cc.''', sleep='''
......a...a.
.....aaa.aaa
.....aaaaaaa
.aaaaakkakka
aaaaapacncap
accccccccaa.'''),
    adult=dict(pal=TUX, idle='''
........a...a..
.......aaa.aaa.
.......aaaaaaa.
.a.....aieaiea.
a......aeeaeea.
a......pacncap.
.a......accca..
..aaaaaaaccccc.
..aaaaaaacccca.
..aaaaaaaaaaaa.
..aa.aa...aa.a.
..cc.cc...cc.c.''', step_tail='''
...aa.aa..aa.a.
..cc...cc.c..c.''', sleep='''
.........a...a.
........aaa.aaa
........aaaaaaa
.aaaaaaaakkakka
aaaaaaaapacncap
aaaaaaaaacccaaa
.cccccaaaaccc..'''))

# ── 똥개: 머리에 진짜 똥을 얹고 다니는 동네 개 ──
DDONG = {'a': '#ead6ab', 'b': '#4a3222', 'g': '#d8b47c', 'm': '#5c3f2a', 'c': '#fbf3e2', 'n': '#1a0f0a', 'q': '#4e2c12', 'r': '#7e4a20', 'd': '#c0392b', 'e': E, 'i': I, 'p': PK}
pet(id='ddonggae', name='똥개', grade=1, kind='ward', likes='treat_meat',
    desc='주둥이·귀·발이 까무잡잡한 동네 개입니다. 어디서 얹었는지 늘 머리에 똥 한 덩이를 이고 다닙니다. 본인은 모자인 줄 알고 아주 뿌듯해합니다.',
    baby=dict(pal=DDONG, idle='''
.......q....
......qrq...
.....qqrqq..
.....aaaaa..
...baaaaaaab
...baieaieab
b..bbeeaeebb
b...pamnmap.
.baaaaaccca.
.aggaaaaaaaa
.aaaaggaaaaa
.mm.m...m.mm''', step_tail='''
..mm.m.mm.m.''', sleep='''
.......q....
......qrq...
.....qqrqq..
.....aaaaa..
...baaaaaaab
...bakkakkab
baabpamnmapb
.aggaaaaaaaa
.aaaaaggaaa.'''),
    adult=dict(pal=DDONG, idle='''
..........q....
.........qrq...
........qqrqq..
........aaaaa..
......baaaaaaab
......baieaieab
......bbeeaeebb
b......pamnmap.
.b......accca..
.b.....ddddddd.
.aaaaaaaacccaa.
.aggaaaaggaaaa.
.aa.aa....aa.aa
.mm.mm....mm.mm''', step_tail='''
.aa..aa..aa.aa.
mm....mm.mm..mm''', sleep='''
..........q....
.........qrq...
........qqrqq..
........aaaaa..
......baaaaaaab
......bakkakkab
baaaaabpamnmapb
.aaaaaaaddddddd
aaggaaaaggaaaaa
.aaaaaaaaaaaaa.'''))

# ── 오리너구리: 오리 부리·납작 꼬리·물갈퀴 ──
PLATY = {'a': '#8a5a36', 't': '#5c3a22', 'b': '#3e3b38', 'w': '#4a3a30', 'e': E, 'i': I}
pet(id='platypus', name='부리너구리', grade=2, kind='water', likes='treat_fish',
    desc='오리 부리에 너구리 몸, 납작한 꼬리를 단 먼 바다 건너의 동무입니다. 뱃사람들이 구등대 군도에서 데려왔다고 합니다. 물가에서는 누구보다 날쌥니다.',
    baby=dict(pal=PLATY, idle='''
....aaaaa...
...aaaaaaa..
...aaieaabbb
tt.aaeeaabbb
ttaaaaaaabb.
ttaaaaaaaa..
.aaaaaaaaa..
..ww....ww..''', step_tail='''
...ww..ww...''', sleep='''
....aaaaa...
...aakkaabbb
ttaaaaaaabbb
ttaaaaaaaa..
.aaaaaaaaa..'''),
    adult=dict(pal=PLATY, idle='''
.......aaaaa....
.....aaaaaaaa...
.....aaaieaaabbb
ttt..aaaeeaaabbb
tttaaaaaaaaaabb.
tttaaaaaaaaaaa..
.ttaaaaaaaaaaa..
..aaaaaaaaaaa...
..ww.ww...ww.ww.''', step_tail='''
...ww.ww.ww.ww..''', sleep='''
.......aaaaa....
.....aaakkaaabbb
tttaaaaaaaaaabbb
tttaaaaaaaaaaab.
.aaaaaaaaaaaaa..'''))

# ── 산토끼: 흰 토끼 몸틀에 갈색 털·검은 귀 끝 ──
HARE = {'a': '#a37a50', 'x': '#3a2a1e', 'c': '#efe4cf', 'p': '#d9a08a', 'n': '#6a4030', 'e': E, 'i': I}
pet(id='hare', name='산토끼', grade=1, kind='wood', likes='treat_herb',
    desc='산기슭에서 내려온 갈색 토끼입니다. 귀 끝이 까맣고, 놀라면 한달음에 언덕 너머까지 뛰어갑니다.',
    baby=dict(pal=HARE, idle='''
.....xx.xx..
.....pa.pa..
.....pa.pa..
....aaaaaaa.
....aieaiea.
....aeeaeea.
.cc.paanaap.
ccaaaaaaaaa.
.caaaaaaaaa.
.aaa...a.aa.''', step_tail='''
..caaaaaaaa.
aaa.....aa..''', sleep='''
..xaaa......
...appaaaaa.
....akkakka.
.cc.paanaap.
ccaaaaaaaaaa
.caaaaaaaaa.'''),
    adult=dict(pal=HARE, idle='''
.......xx..xx.
.......pa.pa..
.......pa.pa..
.......pa.pa..
......aaaaaaa.
......aieaiea.
......aeeaeea.
.cc...paanaap.
cccaaaaaaaaa..
.caaaaaaaaaaa.
..aaaaaaaaaaa.
.aaaa....aa.a.''', step_tail='''
..caaaaaaaaa..
aaaa......aa..''', sleep='''
...xaaaa......
....apppaaaaa.
......akkakka.
.cc...paanaap.
cccaaaaaaaaaaa
.caaaaaaaaaaa.
..aaaaaaaaaaa.'''))
