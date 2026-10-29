# ── 범품 ──
pet(id='nureong_puppy', name='누렁 강아지', grade=1, kind='ward', likes='treat_meat',
    desc='마을 어귀마다 한 마리씩은 있는 누런 강아지입니다. 낯선 기척이 나면 제일 먼저 짖어 알려 줍니다.',
    baby=dict(pal={'a': '#dba54a', 'b': '#a8722a', 'c': '#f5e2b0', 'n': '#3a2418', 'e': E, 'i': I, 'p': PK},
        idle='''
.....aaaaa..
...baaaaaaab
...baieaieab
b..bbeeaeebb
b...pacncap.
.baaaaaccca.
.aaaaaaaaaaa
.aaaaaaaaaaa
.aa.a...a.aa''',
        step_tail='''
..aa.a.aa.a.''',
        sleep='''
.....aaaaa..
...baaaaaaab
...bakkakkab
baabpacncapb
.aaaaaaaaaaa
.aaaaaaaaaa.'''),
    adult=dict(pal={'a': '#dba54a', 'b': '#a8722a', 'c': '#f5e2b0', 'n': '#3a2418', 'd': '#c0392b', 'y': '#f2c94c', 'e': E, 'i': I, 'p': PK},
        idle='''
........aaaaa..
......baaaaaaab
......baieaieab
......bbeeaeebb
b......pacncap.
.b......accca..
.b.....dddyddd.
.aaaaaaaacccaa.
.abbaaaaaaaaaa.
.aa.aa....aa.aa
.aa.aa....aa.aa''',
        step_tail='''
.aa..aa..aa.aa.
aa....aa.aa..aa''',
        sleep='''
........aaaaa..
......baaaaaaab
......bakkakkab
baaaaabpacncapb
.aaaaaaadddyddd
aabbaaaaaaaaaaa
.aaaaaaaaaaaaa.'''))

pet(id='spotted_cat', name='얼룩 고양이', grade=1, kind='shadow', likes='treat_fish',
    desc='세 빛깔 얼룩이 박힌 고양이입니다. 볕 드는 자리를 귀신같이 찾아내 낮잠을 잡니다.',
    baby=dict(pal={'a': '#f6f1e6', 'o': '#e8964a', 'd': '#4a3f3a', 'n': '#e07a86', 'e': E, 'i': '#8a7a74', 'p': PK},
        idle='''
.....o...a..
....ooo.aaa.
....ooaaaaa.
d...aieaiea.
d...aeeaeea.
.d..paanaap.
.daaaoooaaa.
.aaaaooaaaa.
.aa.a..a.aa.''',
        step_tail='''
..aa.a.a.aa.''',
        sleep='''
......o...a.
.....ooo.aaa
.....ooaaaaa
.aaaaakkakka
aooaapaanaap
addddddddaa.'''),
    adult=dict(pal={'a': '#f6f1e6', 'o': '#e8964a', 'd': '#4a3f3a', 'n': '#e07a86', 'e': E, 'i': '#8a7a74', 'p': PK},
        idle='''
........o...a..
.......ooo.aaa.
.......ooaaaaa.
.d.....aieaiea.
d......aeeaeea.
d......paanaap.
.d......aaaaa..
..daaaaaaaaaaa.
..aooooaaaddaa.
..aaooaaaaaaaa.
..aa.aa...aa.a.
..aa.aa...aa.a.''',
        step_tail='''
...aa.aa..aa.a.
..aa...aa.a..a.''',
        sleep='''
.........o...a.
........ooo.aaa
........ooaaaaa
.aaaaaaaakkakka
aaoooaaapaanaap
aaooaaaaaddaaaa
.dddddddddddd..'''))

pet(id='magpie', name='까치', grade=1, kind='bird', likes='treat_meat',
    desc='반가운 손님이 온다고 먼저 울어 주는 새입니다. 반짝이는 것을 보면 꼭 한 번 쪼아 봅니다.',
    baby=dict(pal={'a': '#34364a', 'b': '#2f4f96', 'w': '#f4f2ec', 'n': '#4a4a58', 'h': '#6a6c88', 'e': '#0c0806', 'i': I, 'p': PK},
        line='h',
        idle='''
......aaa...
.....aaaaa..
....aaaaiea.
....aaaaeenn
bb..baaaapa.
.bbbbbbwwww.
..bbbbbwwww.
....bbwwww..
.....n.n....''',
        step_tail='''
...bbbwwww..
......nn....''',
        sleep='''
.......aaa..
......aaaaa.
.....aaahhan
bb..baaaapa.
.bbbbbbwwww.
..bbbbwwwww.'''),
    adult=dict(pal={'a': '#34364a', 'b': '#2f4f96', 'w': '#f4f2ec', 'n': '#4a4a58', 'h': '#6a6c88', 'e': '#0c0806', 'i': I, 'p': PK},
        line='h',
        idle='''
.........aaa...
........aaaaa..
........aaaiea.
........aaaeenn
.......aaaaap..
......bwwbbaww.
bb..bbbwwbbbwww
.bbbbbbbbbbwww.
...bbbbbbbwww..
.......bbwww...
........n..n...
.......nn.nn...''',
        step_tail='''
.........nn....
........nn.n...''',
        sleep='''
.........aaa...
........aaaaa..
........aaahhan
.......aaaaap..
......bwwbbaww.
bb..bbbwwbbbwww
.bbbbbbbbbbwww.
...bbbbbbbwww..'''))

pet(id='sparrow', name='참새', grade=1, kind='bird', likes='treat_rice',
    desc='처마 밑에서 짹짹거리며 낟알을 줍는 작은 새입니다. 겁이 많아 쓰다듬으면 몸을 동그랗게 부풀립니다.',
    baby=dict(pal={'a': '#8a5634', 'b': '#c08a5a', 'd': '#3a2a22', 'c': '#f2ead8', 'n': '#4a3a30', 'y': '#d09a6a', 'e': E, 'i': I, 'p': PK},
        lid='c', line='d',
        idle='''
......aaaa..
.....aaaaaa.
....aaaciec.
....aaaceecn
bb.aaaaccpd.
.bdbdbbcccc.
..bbdbbcccc.
....bbcccc..
.....y.y....''',
        step_tail='''
....bbcccc..
......yy....''',
        sleep='''
......aaaa..
.....aaaaaa.
....aaacddcn
bb.aaaaccpd.
.bdbdbbcccc.
..bbbbcccc..'''),
    adult=dict(pal={'a': '#8a5634', 'b': '#c08a5a', 'd': '#3a2a22', 'c': '#f2ead8', 'n': '#4a3a30', 'y': '#d09a6a', 'e': E, 'i': I, 'p': PK},
        lid='c', line='d',
        idle='''
.........aaaa..
........aaaaaa.
.......aaaciec.
.......aaaceecn
......aaaaaccpd
bb...bdbdbbcccc
.bbbbbdbdbbcccc
...bbdbdbbbccc.
.....bbbbbccc..
.......y..y....
......yy.yy....''',
        step_tail='''
........yy.....
.......yy.y....''',
        sleep='''
.........aaaa..
........aaaaaa.
.......aaacddc.
.......aaaccccn
......aaaaaccpd
bb...bdbdbbcccc
.bbbbbdbdbbcccc
...bbbbbbbbccc.'''))

pet(id='squirrel', name='다람쥐', grade=1, kind='wood', likes='treat_honey',
    desc='볼주머니가 터지도록 먹이를 모아 두는 다람쥐입니다. 숨겨 둔 곳은 금세 잊어버립니다.',
    baby=dict(pal={'a': '#c0753a', 'b': '#7a4420', 'c': '#f2dcb0', 'f': '#d88a48', 't': '#f0b070', 'n': '#5a3020', 'e': E, 'i': I, 'p': PK},
        idle='''
.ttt..a...a.
tffft.aaaaa.
tfbffaieaiea
tfbf.aeeaeea
.tfbfcpanapc
..tfaaacccc.
...tfabaccc.
....aaaaccc.
....aa.a.aa.''',
        step_tail='''
.....aa.aa..''',
        sleep='''
.ttt..a...a.
tffft.aaaaa.
tfbffakkakka
tfbffcpanapc
tffffaacccc.
.tttttaaaaa.'''),
    adult=dict(pal={'a': '#c0753a', 'b': '#7a4420', 'c': '#f2dcb0', 'f': '#d88a48', 't': '#f0b070', 'n': '#5a3020', 'o': '#b8783a', 'q': '#6a4020', 'e': E, 'i': I, 'p': PK},
        idle='''
.ttt...........
tffft....a...a.
tfbfft...aaaaa.
tfbbfft.aieaiea
tfbffft.aeeaeea
.tfbfft.cpanapc
..tfbft.aacccaa
...tfaabaaqqca.
....aaabaaaooc.
....aabaaacccc.
.....aaaaaccc..
....aaa....aa..''',
        step_tail='''
.....aaa..aa...''',
        sleep='''
.ttt...........
tffft....a...a.
tfbfft...aaaaa.
tfbbfft.akkakka
tfbfffaacpanapc
.tffffaaabaaaaa
..tttttaaaaaaa.'''))

pet(id='white_rabbit', name='흰 토끼', grade=1, kind='wood', likes='treat_herb',
    desc='눈처럼 하얀 털에 빨간 눈을 가진 토끼입니다. 기분이 좋으면 제자리에서 폴짝 뜁니다.',
    baby=dict(pal={'a': '#f8f5ef', 'c': '#ddd4c8', 'p': '#f2a2b2', 'n': '#e07a8a', 'e': '#8e2232', 'i': '#d27482'},
        idle='''
.....aa.aa..
.....pa.pa..
.....pa.pa..
....aaaaaaa.
....aieaiea.
....aeeaeea.
.cc.paanaap.
ccaaaaaaaaa.
.caaaaaaaaa.
.aaa...a.aa.''',
        step_tail='''
..caaaaaaaa.
aaa.....aa..''',
        sleep='''
..aaaa......
...appaaaaa.
....akkakka.
.cc.paanaap.
ccaaaaaaaaaa
.caaaaaaaaa.'''),
    adult=dict(pal={'a': '#f8f5ef', 'c': '#ddd4c8', 'p': '#f2a2b2', 'n': '#e07a8a', 'e': '#8e2232', 'i': '#d27482'},
        idle='''
.......aa..aa.
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
.aaaa....aa.a.''',
        step_tail='''
..caaaaaaaaa..
aaaa......aa..''',
        sleep='''
...aaaaa......
....apppaaaaa.
......akkakka.
.cc...paanaap.
cccaaaaaaaaaaa
.caaaaaaaaaaa.
..aaaaaaaaaaa.'''))

pet(id='baby_turtle', name='새끼 거북', grade=1, kind='shell', likes='treat_herb',
    desc='등딱지가 손바닥만 한 거북입니다. 느릿느릿 걷다가도 먹이 소리에는 고개를 번쩍 듭니다.',
    baby=dict(pal={'s': '#4e8a3e', 'h': '#7ab858', 'r': '#365e2c', 'a': '#b6d27a', 'c': '#e8dca0', 'e': E, 'i': I, 'p': PK},
        idle='''
...rrrr.....
..rshhsr.aa.
.rshsshsraaa
.rhsshhsraie
rccccccccaee
.accccccaap.
.aa.aa.aa...''',
        step_tail='''
..aa.aa.aa..''',
        sleep='''
...rrrr.....
..rshhsr....
.rshsshsr...
.rhsshhsraa.
rccccccccakk
.cccccccccc.'''),
    adult=dict(pal={'s': '#4e8a3e', 'h': '#7ab858', 'r': '#365e2c', 'a': '#b6d27a', 'c': '#e8dca0', 'e': E, 'i': I, 'p': PK},
        idle='''
....rrrrrr.....
...rshhshhr....
..rshsshsshr.aa
.rhhsshhsshhraa
.rshhsshhsshraie
rccccccccccccaee
.acccccccccaaap.
.aaa.aa...aa.a..
..aa.aa...aa.a..''',
        step_tail='''
..aa..aa.aa..a..
.aa..aa...aa.a..''',
        sleep='''
....rrrrrr.....
...rshhshhr....
..rshsshsshr...
.rhhsshhsshhr..
.rshhsshhsshraa.
rcccccccccccakk.
.cccccccccccccc.'''))

pet(id='goldfish', name='금붕어', grade=1, kind='water', likes='treat_rice',
    desc='동그란 어항 속에서 사는 금붕어입니다. 손가락을 대면 졸졸 따라 헤엄칩니다.',
    baby=dict(pal={'g': '#bfe3ee', 'q': '#e6f6fa', 'w': '#6ab4d4', 'd': '#4a90b8', 'o': '#f07030', 'f': '#ffb060', 'b': '#eaf8ff', 's': '#d8c090', 'l': '#4a9a50', 'e': E, 'i': I},
        lid='o',
        idle='''
..gggggggg..
..gqqqqqqg..
.gwwwwwwwbg.
gwwwwwwwwwwg
gwwfwooiwwwg
gwffoooeowwg
gwwfwooowwwg
gdwlwwwwwwdg
.gsllsssssg.
..gggggggg..''',
        step='''
..gggggggg..
..gqqqqqqb..
.gwwwwwwwwg.
gwwwwwwwwbwg
gwwwfwooiwwg
gwwffoooeowg
gwwwfwooowwg
gdwlwwwwwwdg
.gsllsssssg.
..gggggggg..''',
        sleep='''
..gggggggg..
..gqqqqqqg..
.gwwwwwwwwg.
gwwwwwwwwwwg
gwwwwwwwwwwg
gwwfwoooowwg
gwffoooookwg
gdwlfwooowdg
.gsllsssssg.
..gggggggg..'''),
    adult=dict(pal={'g': '#bfe3ee', 'q': '#e6f6fa', 'w': '#6ab4d4', 'd': '#4a90b8', 'o': '#f07030', 'r': '#d84a20', 'f': '#ffb060', 'b': '#eaf8ff', 's': '#d8c090', 'l': '#4a9a50', 'm': '#2e7a3a', 'e': E, 'i': I},
        lid='o',
        idle='''
...ggggggggg...
...gqqqqqqqg...
..gwwwwwwwwbg..
.gwwwwwwwwwwwg.
gwwwwwwwwwwwbwg
gwffwwwoooiwwwg
gwfffwoorooewwg
gwwffooororowwg
gwfffwoooooowwg
gwffwwwwfwwwwwg
gdlwwwwwwwwwwdg
gdlmwwwwwwwwldg
.gsllsssssslsg.
..ggggggggggg..''',
        step='''
...ggggggggg...
...gqqqqqqqgb..
..gwwwwwwwwwg..
.gwwwwwwwwwbwg.
gwwwwwwwwwwwwwg
gwwffwwwoooiwwg
gwwfffwoorooewg
gwwwffooororowg
gwwfffwoooooowg
gwwwffwwwfwwwwg
gdlwwwwwwwwwwdg
gdlmwwwwwwwwldg
.gsllsssssslsg.
..ggggggggggg..''',
        sleep='''
...ggggggggg...
...gqqqqqqqg...
..gwwwwwwwwwg..
.gwwwwwwwwwwwg.
gwwwwwwwwwwwwwg
gwwwwwwwwwwwwwg
gwwwwwwwwwwwwwg
gwffwwwoooowwwg
gwfffwoorooowwg
gwwffooorookwwg
gdfffwoooooowdg
gdlmwwwwfwwwldg
.gsllsssssslsg.
..ggggggggggg..'''))

# ── 진품 일부(먹물 고양이는 시안 모습) ──
INK = {'a': '#2c2a3a', 'h': '#45425a', 'i': '#f4f0e6', 'e': '#f2c94c', 'p': '#e79aa8', 'y': '#f0d070', 'r': '#c0392b'}
pet(id='ink_cat', name='먹물 고양이', grade=3, kind='shadow', likes='treat_fish',
    desc='벼루 먹물을 뒤집어쓴 듯 새까만 고양이입니다. 밤이 되면 노란 눈만 동그랗게 떠 있습니다.',
    baby=dict(pal=INK, line='h',
        idle='''
.....a...a..
....apa.apa.
....ahaaaha.
a...aieaiea.
a...aaeaaea.
.a..aaapaaa.
.ahhaaaaaaa.
.aaaaaaaaaa.
.aa.a..a.aa.''',
        step_tail='''
..aa.a.a.aa.''',
        sleep='''
......a...a.
.....apa.apa
.....ahaaaha
.aaaaahhahha
ahhaaaaapaaa
aaaaaaaaaaa.'''),
    adult=dict(pal=INK, line='h',
        idle='''
........a...a..
.......apa.apa.
.......ahaaaha.
.a.....aieaiea.
a......aaeaaea.
a......aaapaaa.
.a......rryrr..
..ahhhaaaaaaaa.
..aaahhaaaaaaa.
..aaaaaaaaaaaa.
..aa.aa...aa.a.
..aa.aa...aa.a.''',
        step_tail='''
...aa.aa..aa.a.
..aa...aa.a..a.''',
        sleep='''
.........a...a.
........apa.apa
........ahaaaha
.aaaaaaaahhahha
ahhhaaaaaaapaaa
aaahhaaaarryrra
.aaaaaaaaaaaaa.'''))

pet(id='baby_crow', name='아기 까마귀', grade=2, kind='bird', likes='treat_rice',
    desc='깃털이 아직 보송한 까마귀 새끼입니다. 은혜를 잊지 않아 가끔 작은 조약돌을 물어 옵니다.',
    baby=dict(pal={'a': '#363a52', 'h': '#5a6290', 'n': '#5a5a68', 'e': '#0c0806', 'i': I, 'p': '#c89aa8'},
        line='h',
        idle='''
.......a.a..
......aaaa..
.....aaaaaa.
....aaaaiea.
....aaaaeenn
aa..ahhaaap.
.aahhhhaaaa.
..ahhhaaaaa.
....aaaaaa..
.....n.n....''',
        step_tail='''
....aaaaaa..
......nn....''',
        sleep='''
.......a.a..
......aaaa..
.....aaaaaa.
....aaahhaan
aa..ahhaaap.
.aahhhhaaaa.
..aaaaaaaa..'''),
    adult=dict(pal={'a': '#363a52', 'h': '#5a6290', 'n': '#5a5a68', 'e': '#0c0806', 'i': I, 'p': '#c89aa8'},
        line='h',
        idle='''
.........aaa...
........aaaaa..
.......aaaaiea.
.......aaaaeenn
......aaaaaap..
......ahhhaaaa.
aa..aahhhhaaaa.
.aaaahhhhhaaaa.
...aaahhhaaaa..
.......aaaaa...
........n..n...
.......nn.nn...''',
        step_tail='''
.........nn....
........nn.n...''',
        sleep='''
.........aaa...
........aaaaa..
.......aaaahhan
......aaaaaap..
......ahhhaaaa.
aa..aahhhhaaaa.
.aaaahhhhhaaaa.
...aaaaaaaaaa..'''))
