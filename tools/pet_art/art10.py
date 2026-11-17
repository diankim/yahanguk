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


WISP = {'a': '#eef3fb', 'b': '#bccbe2', 'y': '#eec64a', 'o': '#c8962a', 'r': '#e0506a', 'e': '#2a2e48', 'i': '#8f9ad0', 'p': '#f6aec4'}
pet(id='ug_crown_wisp', name='왕관 쓴 꼬마 넋', grade=4, kind='ghost', likes='treat_rice',
    desc='귀허의 빈 왕좌 둘레를 맴돌던 작은 넋이 주인 없는 왕관을 주워 쓰고 따라왔습니다. 왕관이 머리보다 커서 고개를 숙일 때마다 눈 위로 미끄러져 내려옵니다. 누가 「전하」 하고 불러 주면 몸이 반짝 밝아지고, 그 밖에는 왕관을 두 손으로 꼭 붙들고 다닙니다.',
    baby=dict(pal=WISP, idle='''
...y.y.y....
...yyryy....
...ooooo....
..aaaaaaaa..
.aaaaaaaaaa.
.aaieaaieaa.
.aaeeaaeeaa.
.apaaaaaapa.
.aaaaaaaaab.
..aaaaaaabb.
...ab.aab...
....b...b...''', step='''
............
...y.y.y....
...yyryy....
...ooooo....
..aaaaaaaa..
.aaaaaaaaaa.
.aaieaaieaa.
.aaeeaaeeaa.
.apaaaaaapa.
.aaaaaaaaab.
..aaaaaaabb.
..ab.aab....''', sleep='''
....y.y.y...
....yyryy...
....ooooo...
..aaaaaaaa..
.aaaaaaaaaa.
.aakkaakkaa.
.apaaaaaapa.
aaaaaaaaaabb'''),
    adult=dict(pal=WISP, idle='''
....y..y..y...
....yy.y.yy...
....yyyryyy...
....ooooooo...
...aaaaaaaaa..
..aaaaaaaaaaa.
.aaaieaaaieaa.
.aaaeeaaaeeaa.
.aapaaaaaaapa.
.aaaaaaaaaaab.
.aaaaaaaaaabb.
..aaaaaaaabb..
..ab.aab.ab...
...b...b..b...''', step='''
..............
....y..y..y...
....yy.y.yy...
....yyyryyy...
....ooooooo...
...aaaaaaaaa..
..aaaaaaaaaaa.
.aaaieaaaieaa.
.aaaeeaaaeeaa.
.aapaaaaaaapa.
.aaaaaaaaaaab.
.aaaaaaaaaabb.
..aaaaaaaabb..
.ab.aab.ab....''', sleep='''
.....y..y..y..
.....yy.y.yy..
.....yyyryyy..
.....ooooooo..
...aaaaaaaaa..
..aaaaaaaaaaa.
.aaakkaaakkaa.
.aapaaaaaaapa.
.aaaaaaaaaaab.
aaaaaaaaaaaabb'''))

RHINO = {'a': '#a6aabc', 'b': '#80849a', 'm': '#cdd0dc', 'u': '#8cd8ea', 'h': '#f6ecd4', 'c': '#eef2f8', 'd': '#9aa4b6', 'e': E, 'i': I, 'p': PK}
pet(id='ug_chain_rhino', name='사슬 아기 코뿔소', grade=4, kind='breaker', likes='treat_herb',
    desc='귀허의 사슬 넷이 끊어지던 날, 끊긴 고리 하나를 목에 건 채 굴러 나온 아기 코뿔소입니다. 코끝의 작은 뿔로 무엇이든 톡톡 밀어 보는데, 아직 힘이 약해 밀리는 것은 늘 자기 쪽입니다. 목에 건 사슬 고리가 짤랑거리면 신이 나서 더 빨리 뛰어다닙니다.',
    baby=dict(pal=RHINO, idle='''
..................h..
.........a.......hh..
.........aa.uuh..hh..
..........uuaahuhhh..
.........uaaaaaahhh..
....uuuuuaaaaieaaa...
..uuaaaaaaaaaeeaaau..
.uaaaaaaaaaapaaaaaau.
.aaaaaaaaccccaammmm..
.bbaaaaaac..caaa.....
...bbbbbbc..cb.bb....
..bb.bb..ccccb.bb....
..bb.bb...dd.........
.........ccc.........
.........c...........''', step='''
..................h..
.........a.......hh..
.........aa.uuh..hh..
..........uuaahuhhh..
.........uaaaaaahhh..
....uuuuuaaaaieaaa...
..uuaaaaaaaaaeeaaau..
.uaaaaaaaaaapaaaaaau.
.aaaaaaaaccccaammmm..
.bbaaaaaac..caaa.....
...bbbbbbc..cb.bb....
...bb.bb.ccccbb.bb...
...bb.bb..dd.........
.........ccc.........
.........c...........''', sleep='''
..................h..
.........a.......hh..
.........aa.uuh..hh..
..........uuaahuhhh..
.........uaaaaaahhh..
....uuuuuaaaaaaaaa...
..uuaaaaaaaaakkaaau..
.uaaaaaaaaaapaaaaaau.
.aaaaaaaaccccaammmm..
.bbaaaaaac..caaa.....
...bbbbbbc..c........
.........cccc........'''),
    adult=dict(pal=RHINO, idle='''
........................h..
.......................hh..
.............a.........hh..
.............aauuuuh..hhh..
.............uuaaahhuuhhh..
............uaaaaaaaahhhh..
............aaaaaaieaaa....
....uuuuuuuuaaaaaaeeaaau...
..uuaaaaaaaaaaaaaaaaaaaau..
.uaaaaaaaaaaaaaaapaaaaaaa..
.aaaaaaaaaaacccccaaammmmm..
.baaaaaaaaaac...caaaammm...
..bbaaaaaaaac...caaa.......
....bbbbbbbbc...cb..bb.....
...bb.bb....cccccb..bb.....
...bb.bb.....ddd...........
............cccc...........
............c..............''', step='''
........................h..
.......................hh..
.............a.........hh..
.............aauuuuh..hhh..
.............uuaaahhuuhhh..
............uaaaaaaaahhhh..
............aaaaaaieaaa....
....uuuuuuuuaaaaaaeeaaau...
..uuaaaaaaaaaaaaaaaaaaaau..
.uaaaaaaaaaaaaaaapaaaaaaa..
.aaaaaaaaaaacccccaaammmmm..
.baaaaaaaaaac...caaaammm...
..bbaaaaaaaac...caaa.......
....bbbbbbbbc...cb..bb.....
....bb.bb...cccccbb..bb....
....bb.bb....ddd...........
............cccc...........
............c..............''', sleep='''
........................h..
.......................hh..
.............a.........hh..
.............aauuuuh..hhh..
.............uuaaahhuuhhh..
............uaaaaaaaahhhh..
............aaaaaaaaaaa....
....uuuuuuuuaaaaaakkaaau...
..uuaaaaaaaaaaaaaaaaaaaau..
.uaaaaaaaaaaaaaaapaaaaaaa..
.aaaaaaaaaaacccccaaammmmm..
.baaaaaaaaaac...caaaammm...
..bbaaaaaaaac...caaa.......
....bbbbbbbbc...c..........
............ccccc..........'''))

MAMMO = {'a': '#b07e5a', 'b': '#86583a', 'f': '#d6a67c', 't': '#f8f0e0', 's': '#f4e2a6', 'r': '#cc3e3a', 'e': E, 'i': I, 'p': PK}
pet(id='ug_seal_mammoth', name='봉연 아기 매머드', grade=4, kind='giant', likes='treat_herb',
    desc='구중 봉연 아홉 겹 문 가장 안쪽에서 잠들어 있던 아기 매머드입니다. 이마에 붙은 봉인 부적 한 장 때문에 오래 깨지 않았는데, 부적이 반쯤 떨어진 지금은 졸음만 많이 남았습니다. 긴 털 속에 온기를 잔뜩 품고 있어 추운 밤이면 다들 그 옆에 붙어 앉습니다.',
    baby=dict(pal=MAMMO, idle='''
.....fffff.....
...aaaaaaaaa...
..aaaasssaaaa..
.baaaasrsaaaab.
bbaaaasssaaaabb
bbaieaaaaaieabb
bbaeeaaaaaeeabb
bbapaaabaaapabb
.bbaaaabaaaabb.
..aaat.b.taaa..
..aaa.tbt.aaa..
..aaa..b..aaa..
..bb..bb...bb..''', step_tail='''
...bb.bb..bb...''', sleep='''
.....fffff.....
...aaaaaaaaa...
..aaaasssaaaa..
.baaaasrsaaaab.
bbaaaasssaaaabb
bbakkaaaaakkabb
bbapaaabaaapabb
.bbaaaabaaaabb.
..aaat.b.taaa..
.aaaaaabaaaaaa.'''),
    adult=dict(pal=MAMMO, idle='''
......fffffff......
....aaaaaaaaaaa....
...aaaaasssaaaaa...
..aaaaaasrsaaaaaa..
.baaaaaasssaaaaaab.
bbaaaaaaaaaaaaaaabb
bbaaieaaaaaaaieaabb
bbaaeeaaaaaaaeeaabb
bbaapaaaabaaaapaabb
.bbaaaaaabaaaaaabb.
..aaaat..b..taaaa..
..aaaaat.b.taaaaa..
..aaaaa.tbt.aaaaa..
..aaaaa..b..aaaaa..
..bb.bb.bb...bb.bb.''', step_tail='''
...bb.bb.b..bb.bb..''', sleep='''
......fffffff......
....aaaaaaaaaaa....
...aaaaasssaaaaa...
..aaaaaasrsaaaaaa..
.baaaaaasssaaaaaab.
bbaaaaaaaaaaaaaaabb
bbaakkaaaaaaakkaabb
bbaapaaaabaaaapaabb
.bbaaaaaabaaaaaabb.
..aaaat..b..taaaa..
.aaaaaaaabaaaaaaaa.'''))

CHAM = {'a': '#f4ead4', 'b': '#d6c49e', 'l': '#c4ae86', 'g': '#a8dcb8', 'm': '#f4b4c4', 'e': E, 'i': I, 'p': PK}
pet(id='ug_hanji_chameleon', name='한지 카멜레온', grade=4, kind='mirror', likes='treat_meat',
    desc='명부 탑의 빈 한지 더미 속에서 깨어난 카멜레온입니다. 몸이 한지 그 자체라 결이 그대로 비치고, 무엇이든 가까이 대면 그 빛깔이 종이에 번지듯 몸에 옮아옵니다. 먹이 묻으면 큰일이라 붓을 든 사람만 보면 꼬리를 돌돌 말고 한 발짝 물러섭니다.',
    baby=dict(pal=CHAM, idle='''
..........ll....
........aaaaa...
.aaa...aaaaaaaa.
a...a.aaaaaieaaa
a.aaaaalaaaeeaaa
a.a.aagaaapaaaa.
.aa.aalaaamaaa..
....aaaaaaaal...
....b..b..b..b..''', step_tail='''
.....b..b..b..b.''', sleep='''
..........ll....
........aaaaa...
.aaa...aaaaaaaa.
a...a.aaaaakkaaa
a.aaaaalaaapaaaa
a.a.aagaaamaaa..
.aa.aaaaaaaal...'''),
    adult=dict(pal=CHAM, idle='''
..............lll...
............aaaaaa..
..aaaa.....aaaaaaaa.
.a....a...aaaaaaaaaa
a..aa.a.aaaaaaaieaaa
a.a..aaaagaaaaeeaaaa
a.a.aaaaaaalaapaaaa.
a..aaaamaaaaaaaaaa..
.aa.aaaaaaalaaaa....
....aaagaaaaaaal....
....b..b....b..b....''', step_tail='''
.....b..b....b..b...''', sleep='''
..............lll...
............aaaaaa..
..aaaa.....aaaaaaaa.
.a....a...aaaaaaaaaa
a..aa.a.aaaaaaakkaaa
a.a..aaaagaaaapaaaaa
a.a.aaaaaaalaaaaaaa.
a..aaaamaaaaaaaaaa..
.aa.aaaaaaalaaaa....'''))

PANDA = {'w': '#f6f4ee', 'n': '#3a3640', 'g': '#d4d0c8', 'y': '#a8c060', 'h': '#e8d8b0', 't': '#1e1c24', 'e': '#0e0c12', 'i': I, 'p': PK}
pet(id='ug_brush_panda', name='붓꼬리 아기 판다', grade=4, kind='wood', likes='treat_herb',
    desc='명부 탑 붓걸이 옆 대숲에서 자란 아기 판다입니다. 늘 제 키만 한 대나무 붓을 끌어안고 다니며, 심심하면 붓끝을 먹에 찍어 바닥에 동그라미만 잔뜩 그려 놓습니다. 그림을 칭찬해 주면 붓을 내밀어 한 획 그어 보라고 조릅니다.',
    baby=dict(pal=PANDA, lid='n', idle='''
.nn.......nn..
nnnwwwwwwwnnn.
.wwwwwwwwwww..
wwnnnwwwnnnww.
wwniewwwnieww.
wwneewwwneeww.
wwpwwwnwwwpww.
.wwwwwwwwwww..
.nnwwwwwwwnny.
.nnwwwwwwwnny.
..wwwwwwwww.h.
.nnn.....nnnt.''', step_tail='''
..nnn...nnn.t.''', sleep='''
.nn.......nn..
nnnwwwwwwwnnn.
.wwwwwwwwwww..
wwnnnwwwnnnww.
wwnkkwwwnkkww.
wwpwwwnwwwpww.
.wwwwwwwwwww..
.nnwwwwwwwnny.
.nnnnnnnnnnnh.'''),
    adult=dict(pal=PANDA, lid='n', idle='''
.nnn.........nnn.
nnnnwwwwwwwwwnnnn
.nwwwwwwwwwwwwwn.
wwwwwwwwwwwwwwwww
wwwnnnwwwwwnnnwww
wwwnniewwwnniewww
wwwnneewwwnneewww
wwpwwwwwnwwwwwpww
.wwwwwwwwwwwwwww.
..nnwwwwwwwwwnny.
.nnnwwwwwwwwwnny.
..wwwwwwwwwwww.h.
..wwwwwwwwwwww.t.
.nnnn.....nnnn...''', step_tail='''
..nnnn...nnnn....''', sleep='''
.nnn.........nnn.
nnnnwwwwwwwwwnnnn
.nwwwwwwwwwwwwwn.
wwwwwwwwwwwwwwwww
wwwnnnwwwwwnnnwww
wwwnkkwwwwwnkkwww
wwpwwwwwnwwwwwpww
.wwwwwwwwwwwwwww.
..nnwwwwwwwwwnny.
.nnnnnnnnnnnnnnh.'''))

PENG = {'n': '#2e3044', 'w': '#f6f6f0', 'l': '#c4c4d2', 'y': '#f0b040', 'e': E, 'i': I, 'p': PK}
pet(id='ug_go_penguin', name='바둑판 아기 펭귄', grade=4, kind='bird', likes='treat_fish',
    desc='아홉 칸 뜰 돌바닥에서 미끄럼을 타던 아기 펭귄입니다. 배에 아홉 칸 바둑판 무늬가 그려져 있어 누가 그 위에 바둑돌을 올려놓으면 꼼짝 않고 한 판이 끝나길 기다립니다. 이기는 쪽 편을 들어 날개를 파닥이는데, 대개는 진 쪽 편입니다.',
    baby=dict(pal=PENG, lid='w', idle='''
...nnnnnn...
..nnnnnnnn..
.nnwwnnwwnn.
.nwiewwiewn.
.nweewweewn.
.npwwyywwpn.
nnwllllllwnn
nnwwlwwlwwnn
.nwllllllwn.
.nwwlwwlwwn.
..nwlwwlwn..
...yy..yy...''', step_tail='''
..yy....yy..''', sleep='''
...nnnnnn...
..nnnnnnnn..
.nnwwnnwwnn.
.nwkkwwkkwn.
.npwwyywwpn.
nnwllllllwnn
nnwwlwwlwwnn
.nwllllllwn.
..nnnnnnnn..'''),
    adult=dict(pal=PENG, lid='w', idle='''
....nnnnnn....
..nnnnnnnnnn..
.nnnwwnnwwnnn.
.nnwwwwwwwwnn.
.nwwiewwiewwn.
.nwweewweewwn.
.nwpwwyywwpwn.
nnwwwwwwwwwwnn
nnwllllllllwnn
nnwwwlwwlwwwnn
.nwllllllllwn.
.nwwwlwwlwwwn.
..nwwlwwlwwn..
..nnnnnnnnnn..
...yy....yy...''', step_tail='''
..yy......yy..''', sleep='''
....nnnnnn....
..nnnnnnnnnn..
.nnnwwnnwwnnn.
.nnwwwwwwwwnn.
.nwwkkwwkkwwn.
.nwpwwyywwpwn.
nnwwwwwwwwwwnn
nnwllllllllwnn
nnwwwlwwlwwwnn
.nwllllllllwn.
..nnnnnnnnnn..'''))

HEDGE = {'y': '#ecd08a', 'x': '#b8944c', 'r': '#cc3e3a', 'f': '#f4dcbc', 'b': '#c89c74', 'o': '#3a2620', 'e': E, 'i': I, 'p': PK}
pet(id='ug_tally_hedgehog', name='셈가지 고슴도치', grade=4, kind='shell', likes='treat_honey',
    desc='값귀의 장부 곁에서 셈가지 묶음을 등에 지고 다니던 고슴도치입니다. 등의 가시가 모두 붉은 끈으로 묶은 셈가지라, 놀라서 몸을 동그랗게 말면 영락없이 커다란 주판알 하나가 됩니다. 셈이 틀리면 가시 하나를 쏙 뽑아 바로잡아 주고는 뿌듯해합니다.',
    baby=dict(pal=HEDGE, lid='f', idle='''
.....x.x.x.......
....yxyxyxy......
...xyxyxyxyxf....
..yxyrrrrxyxfff..
.xyxyxyxyxyffffff
.xyxyxyxyxfffieff
yxyxyxyxyxffpeefo
.xyxyxyxybffffff.
..bbbbbbbbbbbbb..
...b.b.....b.b...''', step_tail='''
....b.b...b.b....''', sleep='''
....y.y.y....
..yxyxyxyxy..
.xyxyxyxyxyx.
yxyrrrrrrryxy
yxyxyxyxyxyxy
yxyxffkkfxyxy
.xyxyfpfyxyx.
..bbbbbbbbb..'''),
    adult=dict(pal=HEDGE, lid='f', idle='''
.......x.x.x.x.......
.....xyxyxyxyxy......
....yxyxyxyxyxyx.....
...xyxyxyxyxyxyxf....
..yxyxrrrrrxyxyxfff..
.xyxyxyxyxyxyxyffffff
.xyxyxyxyxyxyxfffieff
yxyxyxyxyxyxyxffpeefo
.xyxyxyxyxyxybffffff.
..bbbbbbbbbbbbbbbbb..
...bb.bb......bb.bb..''', step_tail='''
....bb.bb....bb.bb...''', sleep='''
......y.y.y......
....yxyxyxyxy....
..yxyxyxyxyxyxy..
.xyxyrrrrrrryxyx.
yxyxyxyxyxyxyxyxy
yxyxyxffkkffyxyxy
.xyxyxffpffxyxyx.
..yxyxyxyxyxyxy..
...bbbbbbbbbbb...'''))

BSNAKE = {'a': '#e2b07a', 'b': '#b8844e', 'q': '#8a5634', 'o': '#e0a870', 'r': '#5a3220', 't': '#e0506a', 'e': E, 'i': I, 'p': PK}
pet(id='ug_bead_snake', name='주판알 꼬마 뱀', grade=4, kind='venom', likes='treat_meat',
    desc='값귀의 주판에서 알이 한 줄로 꿰인 채 빠져나와 꼬마 뱀이 되었습니다. 몸통이 모두 주판알이라 기어갈 때마다 알이 대롱대롱 미끄러지며 딸깍딸깍 셈 소리를 냅니다. 똬리를 틀면 알이 가지런히 모여 제 키가 몇인지 스스로 세어 봅니다.',
    baby=dict(pal=BSNAKE, idle='''
...........aaaa..
..........aaaaaa.
..........aieaiea
..........aeeaeea
..........apaaapa
.qq..qq...aaaaaa.
qoqqqoqqrraaaaa..
.qq..qq..........''', step_tail='''
qqoqqqoqrraaaaa..
.qq..qq..........''', sleep='''
...........aaaa..
..........aaaaaa.
..........akkakka
..........apaaapa
.qq..qq...aaaaaa.
qoqqqoqqrraaaaa..
.qq..qq..........'''),
    adult=dict(pal=BSNAKE, idle='''
...............aaaaa..
..............aaaaaaa.
..............aieaaiea
..............aeeaaeea
..............apaaaapa
.qq..qq..qq...aaaaaaa.
qoqqqoqqqoqqrraaaaaa..
.qq..qq..qq...........''', step_tail='''
qqoqqqoqqqoqrraaaaaa..
.qq..qq..qq...........''', sleep='''
...............aaaaa..
..............aaaaaaa.
..............akkaakka
..............apaaaapa
.qq..qq..qq...aaaaaaa.
qoqqqoqqqoqqrraaaaaa..
.qq..qq..qq...........'''))

LANT = {'a': '#c06c40', 'b': '#8a4628', 'c': '#3a5a8c', 'w': '#f6efe0', 'l': '#b8ac94', 'n': '#4a2a1c', 'e': E, 'i': I, 'p': PK}
pet(id='ug_ledger_ant', name='장부 지기 개미', grade=4, kind='swarm', likes='treat_honey',
    desc='제 몸보다 큰 장부 한 권을 등에 지고 다니는 개미입니다. 값귀의 장부에서 떨어진 낱장을 하나하나 주워 모아 제 장부를 꾸렸다고 합니다. 무엇을 주면 꼭 장부를 펴고 다리 하나로 꾹꾹 눌러 적어 두는데, 아직 글을 몰라 점만 찍습니다.',
    baby=dict(pal=LANT, idle='''
...........n...n
..ccccc.....n.n.
.cwwwwwc..aaaaa.
.cwlwlwc.aaaaaaa
.ccccccc.aieaaie
aaaaa.aa.aeeaaee
aaaaaaaa.apaaapa
.aaaa.aa..aaaaa.
..n.n..n.n..n...''', step_tail='''
...n.n..n.n..n..''', sleep='''
...........n...n
..ccccc.....n.n.
.cwwwwwc..aaaaa.
.cwlwlwc.aaaaaaa
.ccccccc.akkaakk
aaaaa.aa.apaaapa
.aaaaaaaaaaaaaa.'''),
    adult=dict(pal=LANT, idle='''
...............n...n
..cccccc........n.n.
.cwwwwwwc.....aaaaa.
.cwlwlwlc....aaaaaaa
.cwwwwwwc...aaaaaaaa
.cccccccc...aieaaiea
aaaaaaa.aa..aeeaaeea
aaaaaaaaaaaaapaaaapa
.aaaaaa.aa..aaaaaaa.
..aaaa......aaaaa...
..n.n..n.n...n.n....''', step_tail='''
...n.n..n.n...n.n...''', sleep='''
...............n...n
..cccccc........n.n.
.cwwwwwwc.....aaaaa.
.cwlwlwlc....aaaaaaa
.cwwwwwwc...aaaaaaaa
.cccccccc...akkaakka
aaaaaaa.aa..apaaaapa
aaaaaaaaaaaaaaaaaaa.
.aaaaaaaaaaaaaaaaa..'''))

LBEAR = {'n': '#3a343e', 'm': '#ccA27a', 'o': '#1a1416', 'w': '#f4f0e6', 'l': '#d8443a', 'g': '#ffd476', 'd': '#5a3a2a', 'y': '#9a7642', 'e': '#0c0a0c', 'i': I, 'p': PK}
pet(id='ug_lantern_bear', name='등롱 반달곰', grade=4, kind='ward', likes='treat_honey',
    desc='흰 밤 등도에서 꺼진 등을 하나씩 켜고 다니던 등지기의 곁을 지키던 아기 반달곰입니다. 가슴의 반달 무늬가 등불을 받으면 은은하게 빛나고, 작은 등롱 하나를 꼭 쥐고 놓지 않습니다. 등불이 흔들리면 제가 먼저 놀라서 등롱을 두 팔로 감싸 안습니다.',
    baby=dict(pal=LBEAR, lid='n', idle='''
.nn.......nn...
nnnnnnnnnnnnn..
nnnnnnnnnnnnn..
nniennnnnienn..
nneennnnneenn..
npnnmmommnnpn..
.nnnmmmmmnnn...
..nnnnnnnnn..y.
.nnwnnnnnwnn.y.
.nnnwnnnwnnnddd
.nnnnwnwnnnnlgl
.nnnnnwnnnnnlll
..nnn...nnn..d.''', step_tail='''
...nnn.nnn...d.''', sleep='''
.nn.......nn...
nnnnnnnnnnnnn..
nnnnnnnnnnnnn..
nnkknnnnnkknn..
npnnmmommnnpn..
.nnnmmmmmnnn...
..nnnnnnnnn..y.
.nnwnnnnnwnn.y.
.nnnwnnnwnnnddd
.nnnnwnwnnnnlgl
.nnnnnwnnnnnlll'''),
    adult=dict(pal=LBEAR, lid='n', idle='''
.nnn.........nnn...
nnnnnnnnnnnnnnnnn..
nnnnnnnnnnnnnnnnn..
nnnnnnnnnnnnnnnnn..
nnniennnnnnniennn..
nnneennnnnnneennn..
nnpnnnmmommnnnpnn..
.nnnnmmmmmmmnnnn...
..nnnnnnnnnnnnn..y.
..nnwnnnnnnnwnn..y.
..nnnwnnnnnwnnn.ddd
..nnnnwnnnwnnnn.lgl
..nnnnnwnwnnnnn.lgl
..nnnnnnwnnnnnn.lll
...nnnn...nnnn...d.''', step_tail='''
..nnnn.....nnnn..d.''', sleep='''
.nnn.........nnn...
nnnnnnnnnnnnnnnnn..
nnnnnnnnnnnnnnnnn..
nnnnnnnnnnnnnnnnn..
nnnkknnnnnnnkknnn..
nnpnnnmmommnnnpnn..
.nnnnmmmmmmmnnnn...
..nnnnnnnnnnnnn..y.
..nnwnnnnnnnwnn..y.
..nnnwnnnnnwnnn.ddd
..nnnnwnnnwnnnn.lgl
..nnnnnwnwnnnnn.lgl
..nnnnnnwnnnnnn.lll'''))

WBAT = {'a': '#f6f4f0', 'b': '#c8c0d0', 'w': '#d6d2ea', 'm': '#a49ccc', 'p': '#f4a6bc', 'e': '#3a3448', 'i': I}
pet(id='ug_whitenight_bat', name='흰 밤 아기 박쥐', grade=4, kind='sky', likes='treat_honey',
    desc='밤이 오지 않는 등도에서 어둠을 찾다 지쳐 하얗게 바래 버린 아기 박쥐입니다. 흰 밤에는 숨을 그림자가 없어 아무 데서나 꾸벅꾸벅 졸고, 누가 손바닥으로 그늘을 만들어 주면 그 안으로 쏙 들어가 날개를 접습니다. 귀가 커서 등심 타는 소리까지 다 듣습니다.',
    baby=dict(pal=WBAT, idle='''
.....a.......a.....
.....aa.....aa.....
m....apaaaaapa....m
mm..aaaaaaaaaaa..mm
mwm.aaieaaaieaa.mwm
mwwmaaeeaaaeeaamwwm
mwwwaapaaaaapaawwwm
mwwwwaaaaaaaaawwwwm
.mw.mwaaaaaaawm.wm.
..m....b...b....m..''', step='''
m....a.......a....m
mm...aa.....aa...mm
mwm..apaaaaapa..mwm
mwwm.aaaaaaaaa.mwwm
.mwwaaieaaaieaawwm.
..mwaaeeaaaeeaawm..
....aapaaaaapaa....
.....aaaaaaaaa.....
......aaaaaaa......
.......b...b.......''', sleep='''
.....a.......a.....
.....aa.....aa.....
.....apaaaaapa.....
....aaaaaaaaaaa....
...mwakkaaakkawm...
...mwwapaaapawwm...
...mwwwwwwwwwwwm...
....mmmmmmmmmmm....'''),
    adult=dict(pal=WBAT, idle='''
......a.........a......
......aa.......aa......
......apa.....apa......
m.....apaaaaaaapa.....m
mm...aaaaaaaaaaaaa...mm
mwm..aaaieaaaaieaaa.mwm
mwwmaaaaeeaaaaeeaaamwwm
mwwwaaapaaaaaaaapaawwwm
mwwwwaaaaaaaaaaaaawwwwm
mwwwwwaaaaaaaaaaawwwwwm
.mw.mw.aaaaaaaaa.wm.wm.
..m......b.....b....m..''', step='''
m.....a.........a.....m
mm....aa.......aa....mm
mwm...apa.....apa...mwm
mwwm..apaaaaaaapa..mwwm
.mwwm.aaaaaaaaaaa.mwwm.
..mwwaaaieaaaaieaaawwm.
...mwaaaeeaaaaeeaaawm..
.....aapaaaaaaaapaa....
......aaaaaaaaaaa......
.......aaaaaaaaa.......
.........b.....b.......
.......................''', sleep='''
......a.........a......
......aa.......aa......
......apa.....apa......
......apaaaaaaapa......
.....aaaaaaaaaaaaa.....
...mwaaakkaaaakkaaawm..
...mwwapaaaaaaaapawwm..
...mwwwwwwwwwwwwwwwm...
....mmmmmmmmmmmmmmm....'''))
