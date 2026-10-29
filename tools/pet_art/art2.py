# ── 양품 ──
FIRE = {'f': '#3fc6e0', 'c': '#9cecff', 'w': '#e8fdff', 'd': '#2a7fb8', 'e': '#123048', 'i': '#6a9ac0', 'p': '#ff9ab8', 's': '#9af0ff'}
pet(id='dokkaebi_fire', name='도깨비불', grade=2, kind='ghost', likes='treat_rice',
    desc='밤길 무덤가를 떠도는 푸른 불씨가 정을 붙였습니다. 메밀묵 냄새만 나면 불꽃이 두 배로 커집니다.',
    baby=dict(pal=FIRE, lid='w', noline='s',
        idle='''
..f.......s.
..ff....f...
...ff..ff...
...fffffff..
..ffccccccf.
.ffcwwwwwwcf
.fcwiewiewcf
.fcweeweewcf
.fcpwwwwpcf.
..fcccccccf.
...fffffff..''',
        step='''
.f........s.
..ff...f....
..fff.ff....
...fffffff..
..ffccccccf.
.ffcwwwwwwcf
.fcwiewiewcf
.fcweeweewcf
.fcpwwwwpcf.
..fcccccccf.
s..fffffff..''',
        sleep='''
...f........
...ff..f....
..ffffffff..
.ffcccccccf.
.fcwkkwkkwcf
.fcpwwwwpcf.
..ffcccccf..
....fffff...'''),
    adult=dict(pal=FIRE, lid='w', noline='s',
        idle='''
.f.............
..f......f.....
.ff.....ff...s.
..ff...fff.....
..dfffffffd....
..ffcccccccff..
.ffcwwwwwwwcf..
.fcwwwwwwwwwcf.
.fcwwiewwiewcf.
.fcwweewweewcf.
.fcwpwwwwwpwcf.
s.fcwwwwwwwcf..
..ffcccccccff..
....fffffff....''',
        step='''
f..............
.f.......f.....
.ff.....ff.....
..fff..ff...s..
..dffffffff....
..ffcccccccff..
.ffcwwwwwwwcf..
.fcwwwwwwwwwcf.
.fcwwiewwiewcf.
.fcwweewweewcf.
.fcwpwwwwwpwcf.
..fcwwwwwwwcf.s
..ffcccccccff..
....fffffff....''',
        sleep='''
...f...........
...ff...f......
....ff.ff......
..dffffffffd...
..ffcccccccff..
.ffcwwwwwwwcf..
.fcwwkkwwkkwcf.
.fcwpwwwwwpwcf.
..ffcccccccff..
....fffffff....'''))

RAC = {'a': '#9a8468', 'b': '#4e4034', 'c': '#f0e8d8', 't': '#6a5a48', 'n': '#2a1a14', 'l': '#5aa040', 'm': '#3a7a2a', 'e': '#120c08', 'i': I, 'p': PK}
pet(id='little_raccoon', name='꼬마 너구리', grade=2, kind='shadow', likes='treat_fish',
    desc='눈가에 검은 탈을 쓴 듯한 꼬마 너구리입니다. 머리에 나뭇잎을 얹고 둔갑하는 흉내를 냅니다.',
    baby=dict(pal=RAC, line='c',
        idle='''
....bb...bb.
....acaaaca.
....biecieb.
....beeceeb.
tt..pccnccp.
tbtaaacccc..
.ttaaaaaaaaa
..aaaaaaaaa.
..bb.b..b.bb''',
        step_tail='''
..b.bb..bb.b''',
        sleep='''
....bb...bb.
....acaaaca.
tt..bccaccb.
tbt.pccnccp.
tbtaaaaaaaaa
.ttaaaaaaaa.'''),
    adult=dict(pal=RAC, line='c',
        idle='''
.........ll....
.......bbml.bb.
.......acaaaca.
.......biecieb.
.......beeceeb.
tt.....pccnccp.
tbt.....acca...
ttbtaaaaaaccaa.
.tbtaaaaaaaaaa.
..ttaaaaaaaaaa.
...bb.bb...bb.b
...bb.bb...bb.b''',
        step_tail='''
....bb.bb..bb.b
...bb...bb.b..b''',
        sleep='''
.........ll....
.......bbml.bb.
.......acaaaca.
tt.....bccaccb.
tbt....pccnccp.
ttbtaaaaaacccaa
.tbtaaaaaaaaaa.
..tttaaaaaaaa..'''))

CRANE = {'w': '#f6f4ee', 'g': '#d4d0c8', 'a': '#2c2c36', 'r': '#d8323a', 'n': '#c8a860', 'l': '#4a4a52', 'e': E, 'i': '#7a7a80', 'p': PK}
pet(id='baby_crane', name='아기 학', grade=2, kind='sky', likes='treat_fish',
    desc='정수리에 붉은 점이 돋기 시작한 아기 학입니다. 다리가 길어 걸을 때마다 휘청거립니다.',
    baby=dict(pal=CRANE, lid='w',
        idle='''
......wrrw..
.....wwwiew.
.....wwweewn
.....wwwwpw.
aa.ggwwwww..
.aaggggwwww.
..aggggwwww.
....gggww...
.....l.l....
....ll.ll...''',
        step_tail='''
.....l..l...
....ll...ll.''',
        sleep='''
......wrrw..
.....wwwwww.
.....wwkkwwn
aa.ggwwwwpw.
.aaggggwwww.
..aggggwwww.
...ggggggg..'''),
    adult=dict(pal=CRANE, lid='w',
        idle='''
.........rr....
........wwwww..
........wwiewnn
........aweew..
.........aaa...
........aaw....
..aa..wwwwww...
.aaaawwwwwwww..
aaaaawwwwwwww..
.aaaaawwwwww...
...aaawwwww....
.......l..l....
.......l..l....
......ll.ll....''',
        step_tail='''
.......l..l....
.......l.ll....
......ll.......''',
        sleep='''
.........rr....
........wwwww..
........wwkkwnn
........awwww..
........aaa....
..aa..wwwaww...
.aaaawwwwwwww..
aaaaawwwwwwww..
.aaaaawwwwwww..
...aaawwwwww...'''))

OTT = {'a': '#7a5236', 'b': '#553620', 'c': '#e4ccaa', 'n': '#2a1a14', 'f': '#8fb8d0', 'g': '#c8dce8', 'e': E, 'i': I, 'p': PK}
pet(id='baby_otter', name='새끼 수달', grade=2, kind='water', likes='treat_fish',
    desc='물가 바위에서 뒹굴기를 좋아하는 새끼 수달입니다. 마음에 드는 조약돌은 꼭 품에 안고 잡니다.',
    baby=dict(pal=OTT,
        idle='''
......a...a.
.....aaaaaaa
.....aieaiea
.....aeeaeea
.....pccnccp
.bbaaaacccc.
bbbaaaaaaaa.
.b.aaaaaaa..
...aa.a..aa.''',
        step_tail='''
....aa.a.aa.''',
        sleep='''
......a...a.
.....aaaaaaa
.....akkakka
.bbaapccnccp
bbbaaaacggca
.bbaaaaaaaa.'''),
    adult=dict(pal=OTT,
        idle='''
.........a...a..
........aaaaaaa.
........aieaiea.
........aeeaeea.
........pccnccp.
.......aacccca..
b...aaaaaaccccc.
bb.aaaaaaaaaccc.
.bbbaaaaaaaaaa..
...aa.aa...aa.aa''',
        step_tail='''
....aa.aa.aa.aa.''',
        sleep='''
.........a...a..
........aaaaaaa.
........akkakka.
........pccnccp.
b....aaaacggccc.
bbbbaaaaaaggcca.
.bbbbaaaaaaaaaa.'''))

OWL = {'a': '#8a6440', 'b': '#5e4028', 'c': '#ecdcb8', 'y': '#f0b030', 'n': '#d89a40', 'f': '#d8a050', 'e': E, 'i': I}
pet(id='baby_owl', name='아기 부엉이', grade=2, kind='bird', likes='treat_meat',
    desc='밤새 눈을 동그랗게 뜨고 집을 지켜 주는 아기 부엉이입니다. 낮에는 졸린 듯 자꾸 꾸벅입니다.',
    baby=dict(pal=OWL, eyes='eiy', lid='c',
        idle='''
..a......a..
..aa....aa..
.aaaaaaaaaa.
.cyyyccyyyc.
.cyiecyiecc.
.cyeeccyeec.
.acccnncccа.
.aabcbcbcaa.
..abcbcbca..
...ff..ff...'''.replace('а', 'a'),
        step_tail='''
..ff....ff..''',
        sleep='''
..a......a..
..aa....aa..
.aaaaaaaaaa.
.ccccccccccc
.ckkkcckkkc.
.acccnncccа.
.aabcbcbcaa.
..abcbcbca..'''.replace('а', 'a')),
    adult=dict(pal=OWL, eyes='eiy', lid='c',
        idle='''
..a.........a..
..aa.......aa..
..aaa.....aaa..
.aaaaaaaaaaaaa.
.acyyycccyyyca.
.acyiecccyieca.
.acyeecncyeeca.
.aaccccnccccaa.
.baacbcbcbcaab.
.baabcbcbcbaab.
.bbaacbcbcaabb.
..bbaaaaaaabb..
...fff...fff...''',
        step_tail='''
..fff.....fff..''',
        sleep='''
..a.........a..
..aa.......aa..
..aaa.....aaa..
.aaaaaaaaaaaaa.
.accccccccccca.
.ackkkcccckkka.
.aaccccnccccaa.
.baacbcbcbcaab.
.baabcbcbcbaab.
.bbaacbcbcaabb.
..bbaaaaaaabb..'''))

TOAD = {'a': '#93a04c', 'b': '#6a7a36', 'c': '#e6dca0', 'm': '#4a5420', 'y': '#e8c040', 'h': '#8a6a10', 'g': '#c8b850', 'e': E, 'i': '#8a8a60', 'p': PK}
pet(id='little_toad', name='꼬마 두꺼비', grade=2, kind='venom', likes='treat_meat',
    desc='우물가에 사는 통통한 두꺼비입니다. 복을 부른다는 말을 들었는지 늘 의젓하게 앉아 있습니다.',
    baby=dict(pal=TOAD,
        idle='''
.....ccc.ccc
.....cie.cie
..aaaceeacee
.abaaaaaaaap
.aaabaammmma
aabaaaacccca
.aaaaaccccc.
.aa.a...a.aa''',
        step_tail='''
.aaaaaccccc.
aa......a.aa''',
        sleep='''
.....ccc.ccc
..aaackkackk
.abaaaaaaaap
.aaabaammmma
aabaaaacccca
aaaaaacccccc'''),
    adult=dict(pal=TOAD,
        idle='''
.......ccc.ccc.
.......cie.cie.
...aaaaceeacee.
..abaagaaaaaap.
.aagaaaaaammyyy
aabaabaaaaamyhy
abaaagacccccyyy
.aaaabacccccc..
.aaa...a...a.a.
aaaa..aa..aa.aa''',
        step_tail='''
.aaa..........a
aaaa.......aa.a''',
        sleep='''
.......ccc.ccc.
...aaaackkackk.
..abaagaaaaaap.
.aagaaaaaammyyy
aabaabaaaaamyhy
abaaagacccccyyy
aaaaabaccccccc.'''))

FF = {'a': '#2e3b55', 'n': '#3a4a66', 'c': '#f2e8c8', 'w': '#d6eef6', 'g': '#c8e04a', 'h': '#fbffc0', 's': '#f6ffa0', 'e': E, 'i': '#8a8070', 'p': PK}
pet(id='firefly_spirit', name='반딧불 정령', grade=2, kind='swarm', likes='treat_honey',
    desc='여름밤 개울가의 반딧불이 모여 생긴 작은 정령입니다. 꽁무니 불빛으로 기분을 알려 줍니다.',
    baby=dict(pal=FF, lid='c', noline='s',
        idle='''
..s....h...h
..ww....n.n.
.wwww.ccccc.
wwwwwcieciec
.wwwwceeceec
.ghaapcccccp
ghhgaa.ccc..
ghhg..n..n..
.gg.s.......''',
        step='''
.......h...h
www.....n.n.
wwww..ccccc.
.wwwwcieciec
..wwwceeceec
.ghaapcccccp
ghhgaa.ccc..
ghhg..n..n..
.ggs........''',
        sleep='''
.......h...h
..www...n.n.
.wwwwwccccc.
gggwwckkckkc
ghhggpcccccp
.ggg..ccc...'''),
    adult=dict(pal=FF, lid='c', noline='s',
        idle='''
....s....h...h.
..........n.n..
..ww.....ccccc.
.wwww...ccccccc
wwwwww..cieciec
.wwwwww.ceeceec
..wwwwaapcccccp
.gghhgaaaccccc.
ghhhhhgaa.n..n.
ghhhhhg..s.....
.ghhhg.........
..ggg...s......''',
        step='''
.........h...h.
ww........n.n..
www......ccccc.
wwww....ccccccc
.wwwww..cieciec
..wwww..ceeceec
....wwaapcccccp
.gghhgaaaccccc.
ghhhhhgaa.n..n.
ghhhhhg........
.ghhhg...s.....
s.ggg..........''',
        sleep='''
.........h...h.
..........n.n..
..www....ccccc.
.wwwwww.ccccccc
.ggwwwwwckkckkc
gghhhgaapcccccp
ghhhhhgaaccccc.
.ghhhhg........
..gggg.........'''))
