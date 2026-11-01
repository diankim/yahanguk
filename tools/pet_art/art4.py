# ── 1.0.0(롤백) 조사원 제보 동무 여덟 ──
# 제보 생김새를 그대로 따랐다. 기존 30종과 같은 틀(오른쪽을 보는 얼굴 · 눈 2×2 · idle/step/sleep, blink는 gen.py가 만든다).

# 1) 네눈박이 강아지(제보 박시현): 머리·등·꼬리 검정, 턱·가슴·배·다리 하양, 갈색 눈썹, 공놀이
NEUN = {'a': '#3a3640', 't': '#c8803e', 'w': '#f6f2ea', 'n': '#120c0a', 'l': '#9a94a2', 'd': '#3a6ac0', 'y': '#f2c94c', 'e': '#0c0806', 'i': I, 'p': PK}
pet(id='neun_puppy', name='네눈박이 강아지', grade=1, kind='ward', likes='treat_meat',
    desc='눈 위의 갈색 점이 눈이 넷인 것처럼 보이는 검둥이 강아지입니다. 공을 던져 주면 지칠 때까지 물어 옵니다.',
    baby=dict(pal=NEUN, line='l',
        idle='''
.....aaaaa..
...aattattaa
...aaieaieaa
a..aaeeaeeaa
a...awwnwwa.
.a..aawwwaa.
.aaaaaaawwww
.awwwwwwwwww
.ww.w...w.ww''',
        step_tail='''
..ww.w.ww.w.''',
        sleep='''
.....aaaaa..
...aattattaa
...aallallaa
aaaaawwnwwa.
.aaaaaaawwww
.wwwwwwwwww.'''),
    adult=dict(pal=NEUN, line='l',
        idle='''
........aaaaa..
......aattattaa
......aaieaieaa
......aaeeaeeaa
a......awwnwwa.
.a......wwwww..
.a.....dddyddd.
.aaaaaaaaawwww.
.awwwwwwwwwwww.
.ww.ww....ww.ww
.ww.ww....ww.ww''',
        step_tail='''
.ww..ww..ww.ww.
ww....ww.ww..ww''',
        sleep='''
........aaaaa..
......aattattaa
......aallallaa
aaaaaaaawwnwwa.
.aaaaaaadddyddd
.awwwwwwwwwwwww
..wwwwwwwwwwww.'''))

# 2) 흰둥이 강아지(제보 조의신): 하얀 강아지
WP = {'a': '#f8f6f0', 'b': '#ded6c6', 'n': '#2a1a14', 'r': '#e05a5a', 'y': '#f2c94c', 's': '#c8323a', 'e': E, 'i': I, 'p': PK}
pet(id='white_puppy', name='흰둥이 강아지', grade=1, kind='ward', likes='treat_rice',
    desc='눈처럼 하얀 털이 보송보송한 강아지입니다. 반가우면 말린 꼬리를 쉬지 않고 흔듭니다.',
    baby=dict(pal=WP,
        idle='''
...aa....aa.
...apaaaaapa
...aaieaieaa
a..aaeeaeeaa
aa..pabnbap.
.a...abrba..
.aaaaaaaaaaa
.aaaaaaaaaaa
.aa.a...a.aa''',
        step_tail='''
..aa.a.aa.a.''',
        sleep='''
...aa....aa.
...apaaaaapa
...aakkakkaa
aa..pabnbap.
.aaaaaaaaaaa
.aaaaaaaaaa.'''),
    adult=dict(pal=WP,
        idle='''
......aa.....aa
......apaaaaapa
......aaieaieaa
......aaeeaeeaa
.aa....pabnbap.
a..a....abrba..
.aa....sssysss.
...aaaaaaaabbaa
.aaaaaaaaaaaaa.
.aa.aa....aa.aa
.aa.aa....aa.aa''',
        step_tail='''
.aa..aa..aa.aa.
aa....aa.aa..aa''',
        sleep='''
......aa.....aa
......apaaaaapa
......aakkakkaa
.aa....pabnbap.
a..aaaaasssysss
aaaaaaaaaaabbaa
.aaaaaaaaaaaaa.'''))

# 3) 잿빛 장모 고양이(제보 여보): 회색 긴 털, 눈이 털에 가려 안 보임 → 눈 글자가 없어 깜빡임도 없다
GL = {'a': '#a2a2ac', 'b': '#78788a', 'c': '#cfcfd8', 'n': '#e07a86', 'p': PK}
pet(id='ash_longhair', name='잿빛 장모 고양이', grade=2, kind='shadow', likes='treat_fish',
    desc='털이 길게 늘어져 눈이 보이지 않는 잿빛 고양이입니다. 앞이 안 보일 텐데도 먹이 그릇만은 한 번에 찾아갑니다.',
    baby=dict(pal=GL,
        idle='''
....a.....a..
....aa...aa..
...aaaaaaaaa.
...acbcacbca.
...abbbabbba.
b..aacbnbcaa.
bb.aaacccaaa.
bbaaaaaccaaaa
.aaabaaabaaaa
.aaaaaaaaaaa.
..aa.aa.aa.aa''',
        step_tail='''
.aa.aa..aa.a.''',
        sleep='''
....a.....a..
....aa...aa..
...aaaaaaaaa.
...abbbabbba.
bbbaacbnbcaa.
bbaaaaacccaaa
.aaabaaabaaaa
.aaaaaaaaaaa.'''),
    adult=dict(pal=GL,
        idle='''
.........a.....a.
.........aa...aa.
........aaaaaaaaa
........acbcacbca
........abbbabbba
........aacbnbcaa
.b......caacccaac
bb.....ccaaccccac
bb..aaaaaaaacccaa
.baaaaaaaaaaaaaa.
.bbaabaaabaaabaa.
..aaaaaaaaaaaaaa.
..aa.aa.....aa.aa''',
        step_tail='''
...aa.aa..aa.aa..''',
        sleep='''
.........a.....a.
.........aa...aa.
........aaaaaaaaa
........abbbabbba
.b......aacbnbcaa
bb..aaaaccaacccac
bbaaaaaaaaaacccaa
.bbaabaaabaaabaaa
..aaaaaaaaaaaaaa.'''))

# 4) 점박이 하늘다람쥐(제보 윤아람): 하얀 바탕에 검은 무늬, 작은 동물(비막 c)
FS = {'a': '#f6f4ee', 'd': '#2e2c34', 'c': '#d2ced8', 'n': '#e8909a', 'e': '#0c0806', 'i': I, 'p': PK}
pet(id='spotted_glider', name='점박이 하늘다람쥐', grade=2, kind='sky', likes='treat_rice',
    desc='하얀 털에 먹물을 튀긴 듯한 검은 무늬가 있는 하늘다람쥐입니다. 높은 선반에서 팔다리를 쫙 펴고 폴짝 날아내립니다.',
    baby=dict(pal=FS,
        idle='''
....dd...dd
....daaaaad
....dieaied
dd..deeaeed
ada.paanaap
.aad.aaaa..
..dddddaaa.
.caaaaaaaac
..a.a..a.a.''',
        step_tail='''
...aa..aa..''',
        sleep='''
....dd...dd
....daaaaad
....dkkakkd
dd..paanaap
adaddddaaa.
.aaaaaaaaac'''),
    adult=dict(pal=FS,
        idle='''
........dd...dd
........daaaaad
........dieaied
.dd.....deeaeed
dadd....paanaap
daad.....aaaa..
.daad.dddddaaa.
..ddaaaaaaaaaaa
...caaaaaaaaaac
...cc.aa..aa.cc''',
        step_tail='''
...cc..aa.aa.cc''',
        sleep='''
........dd...dd
........daaaaad
........dkkakkd
.dd.....paanaap
dadd.ddddddaaa.
daadaaaaaaaaaaa
.dddcaaaaaaaaac'''))

# 5) 금빛 날개늑대(제보 나락): 금빛 털에 매의 날개
WOLF = {'a': '#e8b84a', 'b': '#c08a2a', 'c': '#f8e8b8', 'w': '#8a5a32', 'v': '#dcb48a', 'x': '#4a2e1a', 'n': '#2a1a14', 'e': '#5a2a0a', 'i': '#ffe8b0', 'p': '#e89a7a'}
pet(id='golden_wingwolf', name='금빛 날개늑대', grade=3, kind='sky', likes='treat_meat',
    desc='금빛 털 위로 매의 날개가 돋은 늑대 새끼입니다. 아직 날지는 못해서 날개를 퍼덕이며 달리기만 빨라졌습니다.',
    baby=dict(pal=WOLF,
        idle='''
x.x...ab...ba
wxwx..aaaaaaa
vwvwx.aieaiea
.wvwwxaeeaeea
b.wwwxbacncab
bb.xwaaaccca.
.baaaaaaacccc
.baaaaaaaaaaa
..aa.a...a.aa''',
        step_tail='''
...aa.a.aa.a.''',
        sleep='''
......ab...ba
......aaaaaaa
x.x...akkakka
wxwxwxbacncab
bvwvwaaaaccca
bbaaaaaaaaacc
.bbaaaaaaaaaa'''),
    adult=dict(pal=WOLF,
        idle='''
x.x.x.............
wxwxwx.....ab...ba
vwvwvwx....aaaaaaa
.wvwvwwx...aieaiea
..wwvwvwx..aeeaeea
...wwwwwwx.bacncab
....xwwwwaaaccccc.
b.....aaaaaaacccc.
bb..aaaaaaaaaaccc.
.bbaaaaaaaaaaaaaa.
..bbaaaaaaaaaaab..
...aa.aa....aa.aa.
...bb.bb....bb.bb.''',
        step_tail='''
....aa.aa..aa.aa..
...bb...bb.bb...bb''',
        sleep='''
...........ab...ba
...........aaaaaaa
x.x.x......akkakka
wxwxwxx....bacncab
.vwvwvwwxaaaccccc.
b.wwwwwwwwaaaacccc
bbaaaaaaaaaaaaaccc
.bbaaaaaaaaaaaaaa.'''))

# 6) 꼬마 족제비(제보 강산하): 약간 밝은 갈색 페럿, 까만 눈
FER = {'a': '#d2a274', 'b': '#8e6038', 'c': '#f4e4c8', 'n': '#d8808a', 'e': '#0c0806', 'i': I, 'p': PK}
pet(id='little_ferret', name='꼬마 족제비', grade=2, kind='shadow', likes='treat_meat',
    desc='몸이 길쭉한 밝은 갈색 족제비입니다. 까만 눈을 반짝이며 좁은 틈만 보이면 쏙 들어가 봅니다.',
    baby=dict(pal=FER,
        idle='''
......c.....c
......aaaaaaa
......aieaiea
......aeeaeea
......pccnccp
b.aaaaaaccccc
bbaaaaaaaaccc
.bb.aaaaaaaa.
...bb.....bb.''',
        step_tail='''
....bb...bb..''',
        sleep='''
......c.....c
......aaaaaaa
......akkakka
bb....pccnccp
baaaaaaaccccc
.bbaaaaaaaaa.'''),
    adult=dict(pal=FER,
        idle='''
...........c.....c
...........aaaaaaa
...........aieaiea
...........aeeaeea
...........pccnccp
b.........aacccca.
bb...aaaaaaaacccc.
.bb.aaaaaaaaaaccc.
..bbaaaaaaaaaaaaa.
....bb.bb...bb.bb.''',
        step_tail='''
.....bb.bb.bb.bb..''',
        sleep='''
...........c.....c
...........aaaaaaa
...........akkakka
b..........pccnccp
bb...aaaaaaaacccc.
.bbbaaaaaaaaaaccca
..aaaaaaaaaaaaaaa.'''))

# 7) 외뿔 팔족염소(제보 아도니스): 하얀 털, 검은 외뿔(오른쪽), 검은 눈, 다리 여덟
GOAT = {'a': '#f6f4ee', 'c': '#d6d0c4', 'h': '#2a2630', 'f': '#5a4e48', 'n': '#b88a7a', 'e': '#0c0806', 'i': '#8a8690', 'p': PK}
pet(id='onehorn_goat', name='외뿔 팔족염소', grade=4, kind='giant', likes='treat_herb',
    desc='검은 외뿔 하나와 다리 여덟을 지닌 하얀 염소입니다. 다리가 많아 비탈길에서도 미끄러지는 법이 없습니다.',
    baby=dict(pal=GOAT,
        idle='''
....h.........
.....hh.......
......aaaaaaa.
.....caieaieac
......aeeaeea.
......pacncap.
.a.....accca..
.aaaaaaaaaacc.
.acaacaacaaaa.
.ac.ac.ac.ac..
.ff.ff.ff.ff..''',
        step_tail='''
ac.ac.ac.ac...
ff.ff.ff.ff...''',
        sleep='''
....h.........
.....hh.......
......aaaaaaa.
.....cakkakkac
......pacncap.
.a.....accca..
.aaaaaaaaaacc.
.acaacaacaaaa.
.afafafafafa..'''),
    adult=dict(pal=GOAT,
        idle='''
.......h..........
........hh........
.........hh.......
..........aaaaaaa.
.........caieaieac
..........aeeaeea.
..........pacncap.
.a.........accca..
.aaaaaaaaaaaaccc..
aaaaaaaaaaaaaaac..
.acaacaacaacaaaa..
.aaaaaaaaaaaaaaa..
.a.a.a.a.a.a.a.a..
.f.f.f.f.f.f.f.f..''',
        step_tail='''
.a.a.a.a.a.a.a.a..
f.f.f.f.f.f.f.f...''',
        sleep='''
.......h..........
........hh........
.........hh.......
..........aaaaaaa.
.........cakkakkac
..........pacncap.
.a.........accca..
.aaaaaaaaaaaaccc..
.acaacaacaacaaaa..
.aaaaaaaaaaaaaaa..
.fafafafafafafaf..'''))

# 8) 꼬마 홍룡(제보 조의신): 붉은 용, 불을 쓴다(꼬리 끝 불꽃 · 걸을 때 입김 불꽃)
RED = {'a': '#d8402a', 'b': '#a02818', 'c': '#f6dca0', 'h': '#f0c850', 'f': '#ff9a3a', 'o': '#ffd84a', 'r': '#ff6a2a', 'w': '#f6dca0', 'n': '#5a1a10', 'e': E, 'i': I, 'p': '#ff9a8a'}
pet(id='little_hongryong', name='꼬마 홍룡', grade=4, kind='breaker', likes='treat_meat',
    desc='남쪽 불길에서 났다는 붉은 용의 새끼입니다. 딸꾹질을 할 때마다 작은 불꽃이 퐁퐁 튀어나옵니다.',
    baby=dict(pal=RED,
        idle='''
......h...h.
......haaah.
....faaaaaaa
....faieaiea
.o..faeeaeea
ror.wpacncap
.rafaaccccc.
..afaaccccc.
..aaaaacca..
....aa..aa..''',
        step='''
......h...h.
......haaah.
....faaaaaaa
o...faieaiea
ro..faeeaeea
.r..wpacncap
.rafaaccccc.
..afaaccccc.
..aaaaacca..
...aa..aa...''',
        sleep='''
......h...h.
......haaah.
....faaaaaaa
.o..fakkakka
ror.wpacncap
.rafaaaccccc
..aaaaaaaccc'''),
    adult=dict(pal=RED,
        idle='''
..........h...h.
..........haaah.
.........aaaaaaa
........faieaiea
.......ffaeeaeea
.......ffpacncap
......ffaaacccaw
..o..ffaaaccccw.
.ror.faaaccccc..
.raffaaabcccca..
..rf.aabbccccaa.
..r..ab.aacca...
..rabba.aa..aa..
...bb..bbb..bbb.''',
        step='''
..........h...h.
..........haaah.
.........aaaaaaa
........faieaiea
.......ffaeeaeea
.......ffpacncap
.o....ffaaacccaw
ror..ffaaaccccw.
.ro..faaaccccc..
.raffaaabcccca..
..rf.aabbccccaa.
..r..ab.aacca...
..rabba.aa..aa..
..bb..bbb...bbb.''',
        sleep='''
..........h...h.
..........haaah.
.........aaaaaaa
........fakkakka
.......ffpacncap
...o..ffaaacccaw
..ror.faaaccccw.
.raffaaaacccccc.
.rf.aaabbbccccaa
..rabbaaaaaaaaa.'''))

# 9) 꼬마 매(제보 아도니스): 송골매 — 짙은 회색 두건이 뺨까지(검은 뺨줄), 노란 눈테·부리 밑동, 검은 갈고리 부리,
#    하얀 목, 크림빛 가슴에 검은 반점, 줄무늬 날개·꼬리, 노란 발에 검은 발톱
HAWK = {'h': '#3a3e46', 'a': '#76706a', 'b': '#4a4540', 'w': '#f6f2ea', 'c': '#ebe0ca', 's': '#3a3634', 'y': '#f2c230', 'n': '#56606e', 't': '#1e2024', 'e': '#120c0a', 'i': I, 'p': PK}
pet(id='little_hawk', name='꼬마 매', grade=2, kind='bird', likes='treat_meat',
    desc='짙은 두건을 쓴 듯한 머리에 노란 눈테가 또렷한 어린 송골매입니다. 팔뚝에 앉혀 두면 사냥감이 지나는 쪽을 먼저 쳐다봅니다.',
    baby=dict(pal=HAWK, lid='h',
        idle='''
....hhhhh...
...hhhhhhh..
...hyyhhh...
...yeiyhyn..
...yeeyhnn..
...hyyhwt...
..ahhwcsc...
.abahcscw...
babaawcsc...
.ba..y.y....''',
        step_tail='''
.ba...y.y...''',
        sleep='''
....hhhhh...
...hhhhhhh..
...hyyhhh...
...hkkhhyn..
...hhhhhnt..
..ahhwwww...
.abahcscw...
babaawcsc...'''),
    adult=dict(pal=HAWK, lid='h',
        idle='''
......hhhhh.....
.....hhhhhhh....
....hhyyhhhh....
....hyeiyhhhyn..
....hyeeyhhnnn..
....hhyyhwwwt...
....hhhhwwww....
...aahhwcscw....
..abaawcscsc....
.ababawscscw....
ababaaacscsc....
babab.aawcsw....
.bab....yy.yy...
.ba....ytt.ytt..''',
        step_tail='''
.bab...yy..yy...
.ba...ytt..ytt..''',
        sleep='''
......hhhhh.....
.....hhhhhhh....
....hhyyhhhh....
....hkkkhhhhyn..
....hhhhwwwnnn..
....hhhwwwwt....
...aahhwwcsw....
..abaawcscsc....
.ababawscscw....
ababaaacscsc....
babab.aawcsw....'''))
