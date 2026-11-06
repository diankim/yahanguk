CRAB = {'a': '#e0603c', 'b': '#b84428', 's': '#f2d6a8', 'r': '#c89a62', 'o': '#8a5a32', 'e': E, 'i': I, 'p': PK}
pet(id='hermit_crab', name='소라게', grade=1, kind='shell', likes='treat_fish',
    desc='제 몸보다 큰 소라 껍데기를 집처럼 이고 다니는 게입니다. 낯선 소리가 나면 쏙 숨었다가, 아무 일 없으면 눈자루만 먼저 내밀어 살핍니다. 더 좋은 껍데기를 보면 한참을 망설입니다.',
    baby=dict(pal=CRAB, idle='''
..rrrr......
.rssssr..e.e
rsrrrsr..a.a
rssrsssaaaaa
.rsssr.aapaa
..rrrbaaaaa.
.....b.b.b.b''', step_tail='''
....b.b.b.b.''', sleep='''
..rrrr......
.rssssr.....
rsrrrsr.....
rssrsssaakak
.rsssr.aaaa.
..rrrrbbbbb.'''),
    adult=dict(pal=CRAB, idle='''
...rrrrr.......
..rsssssr...e.e
.rsrrrrssr..a.a
rssrsssrsr..a.a
rssrsrrssraaaaa
rsssrssssaaapaa
.rssssssraaaaab
..rrrrrrbaaaaa.
.......b.b.b.b.''', step_tail='''
......b.b.b.b..''', sleep='''
...rrrrr.......
..rsssssr......
.rsrrrrssr.....
rssrsssrsr.....
rssrsrrssraakak
rsssrssssaaaaab
.rrrrrrrrbbbbb.'''))

PANG = {'a': '#a87a4e', 'b': '#7e5634', 'c': '#d8b48a', 'n': '#5a3c22', 'e': E, 'i': I, 'p': PK}
pet(id='baby_pangolin', name='아기 천산갑', grade=2, kind='shell', likes='treat_honey',
    desc='솔방울 같은 비늘을 겹겹이 두른 작은 짐승입니다. 놀라면 몸을 동그랗게 말아 공처럼 굴러가고, 그대로 잠들기도 합니다. 개미굴 냄새를 맡으면 코끝이 쉬지 않고 움직입니다.',
    baby=dict(pal=PANG, idle='''
...babab....
..bababab...
b.abababaccc
bbababababie
.bbababaacee
..abababaccn
...cc..cc...''', step_tail='''
....cc..cc..''', sleep='''
...babab..
.bababab..
bababababa
babakbabab
.babababab
..bbbbbbb.'''),
    adult=dict(pal=PANG, idle='''
.....bababa.....
....babababab...
...bababababab..
bb.abababababcccc
bbbababababababie
.bbbabababababcee
..bbababababacccn
...ababababa.....
....cc...cc......''', step_tail='''
.....cc...cc.....''', sleep='''
....bababab..
..babababab..
.bababababab.
babababakbaba
bababababbaba
.bababababab.
..bbbbbbbbb..'''))

LADY = {'a': '#d8342c', 'b': '#a82420', 'n': '#2a2420', 'w': '#f4f0e6', 'e': E, 'i': I, 'p': PK}
pet(id='ladybug', name='무당벌레', grade=1, kind='swarm', likes='treat_honey',
    desc='빨간 등에 까만 점이 일곱 개 박힌 벌레입니다. 손가락 끝까지 기어 올라가서야 날개를 펴고 날아오릅니다. 점을 세어 주면 좋아하는지 잠깐 멈춰 섭니다.',
    baby=dict(pal=LADY, idle='''
...aaaa....
..anaanan..
.aaaanaaannn
.anaaaaanwew
.aaanaanannn
..aaaaaan...
..n.n..n.n..''', step_tail='''
...n.n.n.n..''', sleep='''
...aaaa....
..anaanan..
.aaaanaaannn
.anaaaaankkn
.aaanaanannn
.nnnnnnnn...'''),
    adult=dict(pal=LADY, idle='''
.....aaaa.......
...aanaaanaa....
..aaaaaanaaaa...
.anaaanaaaanannn
.aaaaaaanaaannnn
.aanaaaaaaananwe
.aaaanaanaaannnn
..aaaaaaaanaa...
...aaaaaaaaa....
...n.n..n..n.n..''', step_tail='''
....n.n.n..n..n.''', sleep='''
.....aaaa.......
...aanaaanaa....
..aaaaaanaaaa...
.anaaanaaaanannn
.aaaaaaanaaannnn
.aanaaaaaaankknn
.aaaanaanaaannnn
.nnnnnnnnnnnn...'''))

BEE = {'a': '#f0c030', 'b': '#2a2018', 'w': '#dceef6', 'c': '#fff4c0', 'e': E, 'i': I, 'p': PK}
pet(id='bee_trio', name='꿀벌 삼형제', grade=2, kind='swarm', likes='treat_honey',
    desc='늘 셋이 붙어 다니는 꿀벌 형제입니다. 맏이가 앞장서면 둘째와 막내가 같은 박자로 날갯짓을 합니다. 하나를 쓰다듬으면 나머지 둘도 머리를 들이밉니다.',
    baby=dict(pal=BEE, idle='''
.ww.......ww
wwww.....wwww
.ababie.ababie
..babe...babe.
.....ww.......
....wwww......
....ababie....
.....babe.....''', step='''
wwww.......ww
.ww.....wwww.
.ababie.ababie
..babe...babe.
....wwww......
.....ww.......
....ababie....
.....babe.....''', sleep='''
.ababak.ababak
..babb...babb.
.....ababak...
......babb....'''),
    adult=dict(pal=BEE, idle='''
..ww...........ww
.wwww.........wwww
..aababie....aababie
..babbaee....babbaee
...aaba.......aaba..
.......ww...........
......wwww..........
......aababie.......
......babbaee.......
.......aaba.........''', step='''
.wwww.........wwww
..ww...........ww.
..aababie....aababie
..babbaee....babbaee
...aaba.......aaba..
......wwww..........
.......ww...........
......aababie.......
......babbaee.......
.......aaba.........''', sleep='''
..aababak....aababak
..babbaaa....babbaaa
...aaba.......aaba..
......aababak.......
......babbaaa.......
.......aaba.........'''))

FROG = {'a': '#5cbf4a', 'b': '#3c9032', 'c': '#e8f0c0', 'r': '#e86a5a', 'e': E, 'i': I, 'p': PK}
pet(id='tree_frog', name='청개구리', grade=1, kind='venom', likes='treat_meat',
    desc='빗방울 소리를 누구보다 먼저 알아듣는 손톱만 한 개구리입니다. 오라 하면 가고 가라 하면 오는 고집쟁이라, 부를 때는 반대로 부르는 편이 빠릅니다.',
    baby=dict(pal=FROG, idle='''
......aa.aa.
.....aiea.ie
.....aeeaeea
...aaaaaaaap
..abaaaaarra
.aaaaaacccc.
.aa..a..a.aa''', step_tail='''
..aa.a..a.aa''', sleep='''
......aa.aa.
.....akkaakk
...aaaaaaaap
..abaaaaarra
aaaaaaacccca'''),
    adult=dict(pal=FROG, idle='''
........aaa.aaa.
.......aaieaaie.
.......aaeeaaee.
....aaaaaaaaaaap
...abaaaaaaarrra
..aaabaaaaccccc.
.aaaaaaaacccccc.
.aa...aa...a..aa
aaa..aa...aa.aaa''', step_tail='''
..aa..aa...a..aa
.aaa.aa...aa.aaa''', sleep='''
........aaa.aaa.
.......aakkaakk.
....aaaaaaaaaaap
...abaaaaaaarrra
..aaabaaaaccccc.
aaaaaaaaacccccca'''))

SALA = {'a': '#3a3440', 'b': '#2a2430', 'y': '#f0c838', 'c': '#5a5060', 'e': E, 'i': '#f0e8c0', 'p': PK}
pet(id='baby_salamander', name='아기 도롱뇽', grade=2, kind='venom', likes='treat_fish',
    desc='까만 몸에 노란 점이 흩어진 도롱뇽입니다. 비 온 뒤 이끼 위를 느릿느릿 기어 다니고, 손에 올리면 차갑고 매끄럽습니다. 겁이 많아 그늘이 아니면 잘 나오지 않습니다.',
    baby=dict(pal=SALA, idle='''
...........aa.
......yaaaaaie
yy.aayaaayaaaa
.aaaaaaayaaaap
...aa..aa..aa.''', step_tail='''
....aa..aa.aa.''', sleep='''
..........aaa.
yy.aayaaaaakka
.aaaaaayaayaap
...aaaaaaaaaa.'''),
    adult=dict(pal=SALA, idle='''
...............aaa.
..........yaaaaaiea
yyy...aayaaayaaaeea
..yaaaaaaayaaaayaaap
....aayaaaaayaaaaaa.
......aa...aa...aa..
......a....a....a...''', step_tail='''
.......aa...aa..aa..
.......a.....a..a...''', sleep='''
...............aaa.
yyy...aayaaayaaakka
..yaaaaaaayaaaayaap
....aaaaaaaaaaaaaa.'''))

TAPB = {'a': '#8a5a3a', 'c': '#e8d4a8', 'd': '#6a4228', 'n': '#4a3020', 'e': E, 'i': I, 'p': PK}
TAPA = {'a': '#2a2628', 'w': '#ece6dc', 'c': '#ece6dc', 'n': '#1a1618', 'd': '#4a4446', 'e': E, 'i': I, 'p': PK}
pet(id='baby_tapir', name='아기 맥', grade=1, kind='mirror', likes='treat_herb',
    desc='수박처럼 줄무늬가 진 새끼 맥입니다. 자라면 줄이 지워지고 검은 몸에 흰 띠를 두른 모습이 됩니다. 옛사람들은 맥이 나쁜 꿈을 먹는다 하여, 머리맡에 맥 그림을 두고 잤습니다.',
    baby=dict(pal=TAPB, idle='''
.....aaaaa......
...aaaaaaaaa....
..acaacaaacaaie.
..aaacaacaaaaeen
..acaaacaacaaann
...aaaaaaaaaa.n.
...aa.aa..aa.a..''', step_tail='''
....aa.aa.aa..a.''', sleep='''
.....aaaaa......
...aaaaaaaaa....
..acaacaaacaakk.
..aaacaacaaaaann
.aaaaaaaaaaaaa.n'''),
    adult=dict(pal=TAPA, idle='''
.....aawwwwaa....
...aaawwwwwwaaa..
..aaaawwwwwwaaaaa
..aaaawwwwwwaaie.
..aaaawwwwwwaaeenn
...aaaawwwwaaapnnn
...aaa..aa..aa....
...aa...aa..aa....''', step_tail='''
....aa..aa...aa...
...aa....aa.aa....''', sleep='''
.....aawwwwaa....
...aaawwwwwwaaa..
..aaaawwwwwwaaakk
..aaaawwwwwwaaannn
..aaaaaaaaaaaaaaa.'''))

JANG = {'a': '#f4f2ee', 'h': '#d8d4ce', 's': '#b8b2aa', 'n': '#3a3236', 'e': E, 'i': I, 'p': PK}
pet(id='baby_jangsanbeom', name='아기 장산범', grade=2, kind='mirror', likes='treat_meat',
    desc='흰 털이 눈까지 덮어 늘 앞을 못 보는 것 같은 작은 짐승입니다. 들은 소리를 고스란히 흉내 내어, 문밖에서 낯익은 목소리로 부르기도 합니다. 털을 걷어 주면 동그란 눈이 수줍게 드러납니다.',
    baby=dict(pal=JANG, idle='''
.....hhhhh...
....haaaaahh.
...haaaaaaaah
.h.hshshshshh
h..hhshshshan
.haaaaaaaaaap
.aaaaaaaaaaa.
.hh.hh.hh.hh.''', step_tail='''
..hh.hh.hh.h.''', sleep='''
.....hhhhh...
....haaaaahh.
...haaaaaaaah
h..hshshshshh
.haaaaaaaaaan
aaaaaaaaaaaap
.hhhhhhhhhhh.'''),
    adult=dict(pal=JANG, idle='''
.......hhhhhh....
......haaaaaahh..
.....haaaaaaaaah.
..h..hshshshshshh
.h...hhshshshshan
h....haaaaaaaaaap
.h.haaaaaaaaaaah.
..haaaaaaaaaaaa..
..aaaaaaaaaaaaa..
..hh.hh...hh.hh.
..ss.ss...ss.ss.''', step_tail='''
...hh.hh.hh..hh.
...ss.ss.ss..ss.''', sleep='''
.......hhhhhh....
......haaaaaahh..
..h..haaaaaaaaah.
.h...hshshshshshh
h..haaaaaaaaaaaan
.haaaaaaaaaaaaaap
haaaaaaaaaaaaaaa.
.hhhhhhhhhhhhhh..'''))

DOLL = {'a': '#f4f0e4', 'h': '#dcd6c4', 'r': '#c8323a', 'b': '#2a2a3a', 'g': '#cfe3f2', 'e': E, 'i': I, 'p': PK}
pet(id='paper_doll', name='종이 인형 혼령', grade=1, kind='ghost', likes='treat_rice',
    desc='아이가 오려 만든 종이 인형에 깃든 작은 혼령입니다. 바람이 불면 팔랑이며 날아가 버릴까 봐 늘 무언가에 매달려 있습니다. 이름을 적어 주면 그 글자를 소매 속에 소중히 넣어 둡니다.',
    baby=dict(pal=DOLL, lid='a', noline='g', idle='''
....bbbb...
...baaaab..
...aieaie..
...aeeaee..
....apap...
..aaarraaa.
...arraaa..
...aaaaaa..
...ahhhha..
....a..a...
..g......g.''', step='''
....bbbb...
...baaaab..
...aieaie..
...aeeaee..
....apap...
.aaaarraaaa
...arraaa..
...aaaaaa..
...ahhhha..
...a....a..
.g.......g.''', sleep='''
....bbbb...
...baaaab..
...akkakk..
....apap...
..aaarraaa.
...aaaaaa..
...ahhhha..'''),
    adult=dict(pal=DOLL, lid='a', noline='g', idle='''
.....bbbbb....
....bbaaabb...
....aaieaie...
....aaeeaee...
.....aapap....
..aaaarrraaaa.
...aaarrraaa..
....aaaaaaa...
....aaaaaaa...
....ahhhhha...
.....a...a....
.....a...a....
..g.........g.''', step='''
.....bbbbb....
....bbaaabb...
....aaieaie...
....aaeeaee...
.....aapap....
.aaaaarrraaaaa
...aaarrraaa..
....aaaaaaa...
....aaaaaaa...
....ahhhhha...
....a.....a...
....a.....a...
.g...........g''', sleep='''
.....bbbbb....
....bbaaabb...
....aakkakk...
.....aapap....
..aaaarrraaaa.
....aaaaaaa...
....ahhhhha...'''))

BOAR_B = {'a': '#a87048', 'c': '#e8c890', 'd': '#7a4a2a', 'n': '#4a2c1a', 'e': E, 'i': I, 'p': PK}
BOAR_A = {'a': '#6a4a32', 'c': '#8a6448', 'd': '#4a3222', 'n': '#2a1a10', 't': '#f0e8d4', 'e': E, 'i': I, 'p': PK}
pet(id='baby_boar', name='아기 멧돼지', grade=1, kind='breaker', likes='treat_herb',
    desc='등에 참외 같은 줄무늬가 난 새끼 멧돼지입니다. 도토리 냄새가 나면 코로 땅을 파헤치며 돌진하고, 멈추는 법은 아직 잘 모릅니다. 자라면 줄무늬가 지워지고 작은 엄니가 돋습니다.',
    baby=dict(pal=BOAR_B, idle='''
..........d.d..
.d.aaaaaaaaaa..
d.accccccccaaie
..aaaaaaaaaaaee
..accccccccaapp
...aaaaaaaaaapn
...aa.aa..aa.a.''', step_tail='''
....aa.aa.aa.a.''', sleep='''
..........d.d..
.d.aaaaaaaaaa..
d.accccccccaakk
..aaaaaaaaaaapp
.acccccccccaapn
.aaaaaaaaaaaaa.'''),
    adult=dict(pal=BOAR_A, idle='''
......d.d.......
.d..aadadaaad...
d.aaaaaaaaaaaa..
.aaaaaaaaaaaaie.
.aaaaaaaaaaaaee.
.aacaaaaaaaaapnn
..aaaaaaaaaaa.tn
..aa.aa..aa.aa..
..dd.dd..dd.dd..''', step_tail='''
...aa.aa.aa..aa.
...dd.dd.dd..dd.''', sleep='''
......d.d.......
.d..aadadaaad...
d.aaaaaaaaaaaa..
.aaaaaaaaaaaakk.
.aacaaaaaaaaapnn
.aaaaaaaaaaaaatn
.ddddddddddddd..'''))

BEAR = {'a': '#f6f4f0', 'h': '#dcd8d0', 's': '#c0bab0', 'n': '#2a2428', 'e': E, 'i': I, 'p': PK}
pet(id='baby_white_bear', name='아기 흰곰', grade=3, kind='giant', likes='treat_fish',
    desc='눈처럼 흰 털을 가진 아기 곰입니다. 뒤뚱뒤뚱 걷다가 제풀에 넘어져도 아무 일 없다는 듯 그대로 앉아 버립니다. 크면 문짝만 해지지만, 생선 한 마리 앞에서는 여전히 아기처럼 굽니다.',
    baby=dict(pal=BEAR, idle='''
....hh...hh.
....hhaaahh.
....aaaaaaa.
....aieaiea.
.h..aeeaeea.
hh.aaaanaaap
.haaaaaaaaa.
.aaaaaaaaaa.
.aa.aa.aa.aa''', step_tail='''
..aa.aa.aa.a''', sleep='''
....hh...hh.
....hhaaahh.
....aakkakka
hh.aaaanaaap
.aaaaaaaaaa.
aaaaaaaaaaa.
.hhhhhhhhhh.'''),
    adult=dict(pal=BEAR, idle='''
.......hh...hh..
.......hhaaaahh.
.......aaaaaaaa.
.......aieaaiea.
.......aeeaaeea.
..h...aaaanaaap.
.hhaaaaaaaaaaaa.
.haaaaaaaaaaaaa.
.aaaaaaaaaaaaaa.
.aaaaaaaaaaaaaa.
.aaa.aaa..aaa.aa
.sss.sss..sss.ss''', step_tail='''
..aaa.aaa.aaa.a.
..sss.sss.sss.s.''', sleep='''
.......hh...hh..
.......hhaaaahh.
.......aakkaakka
..h...aaaanaaap.
.hhaaaaaaaaaaaa.
.aaaaaaaaaaaaaa.
aaaaaaaaaaaaaaa.
.hhhhhhhhhhhhhh.'''))
