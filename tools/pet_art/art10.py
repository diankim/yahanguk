JELLY = {'a': '#b4e8f4', 'b': '#7cc6e2', 'w': '#ffffff', 's': '#3d8fc8', 't': '#b9a8ee', 'u': '#8c7ad6', 'e': '#23304a', 'i': I, 'p': '#f6a6c0'}
pet(id='ug_vortex_jelly', name='아기 소용돌이 해파리', grade=4, kind='water', likes='treat_fish',
    desc='귀허의 소용돌이 한가운데서 맴돌다 떨어져 나온 아기 해파리입니다. 머리 꼭대기에 작은 소용돌이 무늬가 늘 빙글빙글 돌고 있어, 오래 들여다보면 보는 사람이 먼저 어지러워집니다. 짧은 촉수를 파닥이며 헤엄치다가 제 무늬를 따라 한 바퀴 돌고 나서야 앞으로 나아갑니다.',
    baby=dict(pal=JELLY, idle='''
.....aaa.....
...aaaaaaa...
..awassaaaa..
.awasaasaaaa.
.aaasassaaaa.
.aaaasaaaaaa.
aaieaaaaaieaa
aaeeaaaaaeeaa
apaaaaaaaaapa
.bbbbbbbbbbb.
.t.u.t.u.t.u.
.t..u..t..u..''', step='''
.....aaa.....
...aaaaaaa...
..awassaaaa..
.awasaasaaaa.
.aaasassaaaa.
.aaaasaaaaaa.
aaieaaaaaieaa
aaeeaaaaaeeaa
apaaaaaaaaapa
.bbbbbbbbbbb.
.u.t.u.t.u.t.
..u..t..u..t.''', sleep='''
.....aaa.....
...aaaaaaa...
..awassaaaa..
.awasaasaaaa.
.aaasassaaaa.
.aaaasaaaaaa.
aakkaaaaakkaa
apaaaaaaaaapa
.bbbbbbbbbbb.
tutututututut'''),
    adult=dict(pal=JELLY, idle='''
......aaaa......
....aaaaaaaa....
...aawaassaaa...
..aawaasaasaaa..
..awaasaassaaaa.
.aaaaasaaaaaaaa.
.aaaaaassssaaaa.
.aaieaaaaaaaieaa
.aaeeaaaaaaaeeaa
.apaaaaaaaaaaapa
.bbabbabbabbabb.
..t.u.t..u.t.u..
..t..u.t..u..t..
...t....u....t..''', step='''
......aaaa......
....aaaaaaaa....
...aawaassaaa...
..aawaasaasaaa..
..awaasaassaaaa.
.aaaaasaaaaaaaa.
.aaaaaassssaaaa.
.aaieaaaaaaaieaa
.aaeeaaaaaaaeeaa
.apaaaaaaaaaaapa
.bbabbabbabbabb.
..u.t.u..t.u.t..
...u.t..u.t..u..
..u....t....u...''', sleep='''
......aaaa......
....aaaaaaaa....
...aawaassaaa...
..aawaasaasaaa..
..awaasaassaaaa.
.aaaaasaaaaaaaa.
.aaaaaassssaaaa.
.aakkaaaaaaakkaa
.apaaaaaaaaaaapa
.bbabbabbabbabb.
.tututututututu.'''))

TAD = {'a': '#33364c', 'h': '#4c5070', 'w': '#a6aed0', 'f': '#f2f4fa', 'g': '#d8ccae', 'm': '#a8987a', 't': '#1e2030', 'e': '#d4dcf2', 'i': I, 'p': '#e89ab4'}
pet(id='ug_ink_tadpole', name='먹방울 올챙이', grade=4, kind='shadow', likes='treat_fish',
    desc='명부 탑 벼루에서 똑 떨어진 먹 한 방울이 깨어난 올챙이입니다. 몸이 동글동글한 먹방울이라 지나간 자리마다 옅은 먹 자국이 남고, 꼬리 끝은 붓끝처럼 뾰족해서 바닥에 제멋대로 획을 긋습니다. 맑은 물에 넣으면 먹이 풀릴까 봐 벼루 연지에서만 헤엄치려 합니다.',
    baby=dict(pal=TAD, lid='a', idle='''
.........aaaa..
.......aahwaaa.
......ahwaaaaaa
......awaieaaie
......aaaeeaaee
..mgtahpaaaaapa
tmggtaaaaaaaaaa
..mgt.aaaaaaaa.
.........hhh...''', step='''
.........aaaa..
.......aahwaaa.
......ahwaaaaaa
......awaieaaie
..mgt.aaaeeaaee
tmggtahpaaaaapa
..mgtaaaaaaaaaa
......aaaaaaaa.
.........hhh...''', sleep='''
.........aaaa..
.......aahwaaa.
......ahwaaaaaa
......awaakkaak
..mgtahpaaaaapa
tmggtaaaaaaaaaa
..mgt.aaaaaaaa.'''),
    adult=dict(pal=TAD, lid='a', idle='''
............aaaaa..
..........aahwwaaa.
.........ahwaaaaaaa
.........awaaaaaaaa
.........aaaieaaaie
.........aaaeeaaaee
....mgt.ahpaaaaaapa
..mgggttaaaaaaaaaaa
tmgggttaaaaaaaaaaa.
..mgggt.aaaaaaaaaa.
....mgt...aahhhaa..''', step='''
............aaaaa..
..........aahwwaaa.
.........ahwaaaaaaa
.........awaaaaaaaa
.........aaaieaaaie
....mgt..aaaeeaaaee
..mgggt.ahpaaaaaapa
tmgggttaaaaaaaaaaaa
..mgggtaaaaaaaaaaa.
....mgt.aaaaaaaaaa.
..........aahhhaa..''', sleep='''
............aaaaa..
..........aahwwaaa.
.........ahwaaaaaaa
.........awaaaaaaaa
.........aaakkaaakk
....mgt.ahpaaaaaapa
..mgggttaaaaaaaaaaa
tmgggttaaaaaaaaaaa.
..mgggt.aaaaaaaaaa.'''))

ABAC = {'a': '#e0483c', 'b': '#b03028', 'n': '#3a2620', 'q': '#7a4a2c', 'o': '#e0a870', 'r': '#6a3020', 'y': '#e8cc80', 'f': '#fff2dc', 'e': E, 'i': I, 'p': PK}
pet(id='ug_abacus_ladybug', name='주판알 무당벌레', grade=4, kind='shell', likes='treat_honey',
    desc='값귀 장부를 덮던 주판에서 알 몇 개가 굴러 나와 무당벌레가 되었습니다. 빨간 등에 박힌 점이 모두 주판알이라 걸을 때마다 달그락달그락 셈하는 소리가 납니다. 더듬이는 셈가지 두 개인데, 누가 물건을 내밀면 더듬이를 톡톡 맞대어 값부터 헤아립니다.',
    baby=dict(pal=ABAC, lid='f', idle='''
............y....y.
.............y..y..
...aaaaa.....nnnn..
.aaqaaaraa..nnnnnnn
aaqoqaaqaaannfffffn
aaaqaaqoqaanfiefief
aaaqaaaqaaanfeefeef
aaqoqaaraaanpfffffp
.bbqbbbrbb..nnfffnn
..n.n...n.n........''', step_tail='''
...n.n...n.n.......''', sleep='''
............y....y.
.............y..y..
...aaaaa.....nnnn..
.aaqaaaraa..nnnnnnn
aaqoqaaqaaannfffffn
aaaqaaqoqaanfkkfkkf
aaaqaaaqaaanfffffff
aaqoqaaraaanpfffffp
.bbqbbbrbb..nnfffnn'''),
    adult=dict(pal=ABAC, lid='f', idle='''
.................y....y..
..................y..y...
.................nnnnn..
....aaaaaaa.....nnnnnnnn
..araaaqaaara..nnffffffn
.aaqaaqoqaaqaa.nfieffief
aaqoqaaqaaqoqaanfeeffeef
aaaqaaaqaaaqaaanpffffffp
aaaqaaqoqaaqaaannffffffn
aaqoqaaqaaqoqaa.nnnnnnn.
.bbqbbbrbbbqbb..........
...rbbbrbbbr............
..n.n...n...n.n.........''', step_tail='''
...n.n...n...n.n........''', sleep='''
.................y....y..
..................y..y...
.................nnnnn..
....aaaaaaa.....nnnnnnnn
..araaaqaaara..nnffffffn
.aaqaaqoqaaqaa.nfkkffkkf
aaqoqaaqaaqoqaanffffffff
aaaqaaaqaaaqaaanpffffffp
aaaqaaqoqaaqaaannffffffn
aaqoqaaqaaqoqaa.nnnnnnn.
.bbqbbbrbbbqbb..........
...rbbbrbbbr............'''))
