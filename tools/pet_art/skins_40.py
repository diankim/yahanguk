E = '#2a1a14'; PK = '#f3a0a0'
SKINS = []
def skin(**kw): SKINS.append(kw)

PEACOCK_SPARROW_BABY = dict(pal={"a": "#2a62b0", "b": "#2f9a8a", "d": "#1d4f6a", "c": "#eef2e6", "n": "#4a3a30", "y": "#d09a6a", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "o": "#f0c040"}, lid='c', line='d', idle='''
......o.o...
......aaaa..
.....aaaaaa.
....aaaciec.
....aaaceecn
ob.aaaaccpd.
.bdbdbbcccc.
..bbdbbcccc.
....bbcccc..
.....y.y....''', step_tail='''
....bbcccc..
......yy....''', sleep='''
......o.o...
......aaaa..
.....aaaaaa.
....aaacddcn
ob.aaaaccpd.
.bdbdbbcccc.
..bbbbcccc..''')
PEACOCK_SPARROW_ADULT = dict(pal={"a": "#2a62b0", "b": "#2f9a8a", "d": "#1d4f6a", "c": "#eef2e6", "n": "#4a3a30", "y": "#d09a6a", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "o": "#f0c040"}, lid='c', line='d', idle='''
.........o.o...
.........aaaa..
........aaaaaa.
.......aaaciec.
.......aaaceecn
ob....aaaaaccpd
bob..bdbdbbcccc
.bbbbbdbdbbcccc
...bbdbdbbbccc.
.....bbbbbccc..
.......y..y....
......yy.yy....''', step_tail='''
........yy.....
.......yy.y....''', sleep='''
.........o.o...
.........aaaa..
........aaaaaa.
.......aaacddc.
.......aaaccccn
ob....aaaaaccpd
bob..bdbdbbcccc
.bbbbbdbdbbcccc
...bbbbbbbbccc.''')
skin(key='peacock_sparrow', pet='sparrow', name='공작깃 참새',
    desc='달맞이성 궁궐 뜰에서 공작 곁을 맴돌다 깃 빛이 옮아 붙었다는 참새입니다. 정수리에 깃 두 가닥이 서 있고, 꽁지 끝에 금빛 눈무늬가 하나 박혀 있습니다.',
    baby=PEACOCK_SPARROW_BABY, adult=PEACOCK_SPARROW_ADULT)

COCONUT_CRAB_BABY = dict(pal={"a": "#e0603c", "b": "#b84428", "s": "#93623a", "r": "#4a2e1a", "o": "#8a5a32", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "l": "#6ab84a", "m": "#3a7a2a"}, idle='''
...lm.......
..rrrr......
.rssssr..e.e
rsrrrsr..a.a
rssrsssaaaaa
.rsssr.aapaa
..rrrbaaaaa.
.....b.b.b.b''', step_tail='''
....b.b.b.b.''', sleep='''
...lm.......
..rrrr......
.rssssr.....
rsrrrsr.....
rssrsssaakak
.rsssr.aaaa.
..rrrrbbbbb.''')
COCONUT_CRAB_ADULT = dict(pal={"a": "#e0603c", "b": "#b84428", "s": "#93623a", "r": "#4a2e1a", "o": "#8a5a32", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "l": "#6ab84a", "m": "#3a7a2a"}, idle='''
.....l.........
....lm.........
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
.....l.........
....lm.........
...rrrrr.......
..rsssssr......
.rsrrrrssr.....
rssrsssrsr.....
rssrsrrssraakak
rsssrssssaaaaab
.rrrrrrrrbbbbb.''')
skin(key='coconut_crab', pet='hermit_crab', name='야자 껍데기 소라게',
    desc='파도너울성 물 위 장터에서 쪼개 버린 야자 껍데기를 집으로 삼은 소라게입니다. 껍데기 꼭지에 야자 싹이 돋아, 볕 좋은 날이면 싹이 자라는지 눈자루를 길게 빼고 올려다봅니다.',
    baby=COCONUT_CRAB_BABY, adult=COCONUT_CRAB_ADULT)

GOLD_PUPPET_BABY = dict(pal={"a": "#e4b04c", "h": "#b07a2a", "r": "#a8282e", "b": "#4a2a20", "g": "#6a4a2a", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "y": "#f6d860"}, lid='a', noline='g', idle='''
....y..y...
....bbbb...
...baaaab..
...aieaie..
...aeeaee..
....apap...
..aaarraaa.
...arraaa..
...ahahah..
...ahhhha..
....a..a...
..g......g.''', step='''
....y..y...
....bbbb...
...baaaab..
...aieaie..
...aeeaee..
....apap...
.aaaarraaaa
...arraaa..
...ahahah..
...ahhhha..
...a....a..
.g.......g.''', sleep='''
....y..y...
....bbbb...
...baaaab..
...akkakk..
....apap...
..aaarraaa.
...ahahah..
...ahhhha..''')
GOLD_PUPPET_ADULT = dict(pal={"a": "#e4b04c", "h": "#b07a2a", "r": "#a8282e", "b": "#4a2a20", "g": "#6a4a2a", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "y": "#f6d860"}, lid='a', noline='g', idle='''
.....y.y.y....
.....bbbbb....
....bbaaabb...
....aaieaie...
....aaeeaee...
.....aapap....
..aaaarrraaaa.
...aaarrraaa..
....aaaaaaa...
....ahahaha...
....ahhhhha...
.....a...a....
.....a...a....
..g.........g.''', step='''
.....y.y.y....
.....bbbbb....
....bbaaabb...
....aaieaie...
....aaeeaee...
.....aapap....
.aaaaarrraaaaa
...aaarrraaa..
....aaaaaaa...
....ahahaha...
....ahhhhha...
....a.....a...
....a.....a...
.g...........g''', sleep='''
.....y.y.y....
.....bbbbb....
....bbaaabb...
....aakkakk...
.....aapap....
..aaaarrraaaa.
....ahahaha...
....ahhhhha...''')
skin(key='gold_puppet', pet='paper_doll', name='금박 그림자 인형',
    desc='해오름성 탑 사원 그림자놀이에 쓰던 가죽 인형에 깃든 혼령입니다. 금박 몸에 구멍 무늬가 송송 뚫려 있고, 발밑 막대 둘을 짚고 다닙니다. 등불 앞에 서면 벽에 제 그림자를 크게 비춰 보고 뿌듯해합니다.',
    baby=GOLD_PUPPET_BABY, adult=GOLD_PUPPET_ADULT)

UMBRELLA_MUSHROOM_BABY = dict(pal={"a": "#d8483a", "b": "#9a3a2a", "w": "#f4ecd8", "s": "#efe2c4", "t": "#cbb894", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "y": "#f4c860", "r": "#6a3a2a"}, idle='''
.....r.....
...yayay...
..ayayaya..
.yayayayay.
abayayayayb
.bbbbbbbbb.
...sssss...
...ieies...
...psssp...
...sssss...
....t.t....''', step_tail='''
...t...t...''', sleep='''
.....r.....
...yayay...
..ayayaya..
.yayayayay.
abayayayayb
.bbbbbbbbb.
...kkkks...
...psssp...
..ttttttt..''', lid='s')
UMBRELLA_MUSHROOM_ADULT = dict(pal={"a": "#d8483a", "b": "#9a3a2a", "w": "#f4ecd8", "s": "#efe2c4", "t": "#cbb894", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "y": "#f4c860", "r": "#6a3a2a"}, idle='''
......rr......
....ayayay....
..ayayayayay..
.yayayayayaya.
ayayayayayayay
abayayayayayab
.bbbbbbbbbbbb.
....ssssss....
....ieiess....
....pssssp....
....ssssss....
....ssssss....
.....t..t.....''', step_tail='''
....t....t....''', sleep='''
......rr......
....ayayay....
..ayayayayay..
.yayayayayaya.
ayayayayayayay
abayayayayayab
.bbbbbbbbbbbb.
....kkkkss....
....pssssp....
...tttttttt...''', lid='s')
skin(key='umbrella_mushroom', pet='poison_mushroom', name='종이우산 버섯',
    desc='잿빛그늘숲 대나무 집 처마에 걸어 둔 기름 먹인 종이우산 곁에서 돋아난 버섯 정령입니다. 갓이 우산살처럼 붉고 노란 칸으로 갈라져, 먹비가 오면 그 밑에 개미들이 비를 그으러 모여듭니다.',
    baby=UMBRELLA_MUSHROOM_BABY, adult=UMBRELLA_MUSHROOM_ADULT)

PANDAN_SQUIRREL_BABY = dict(pal={"a": "#c0753a", "b": "#7a4420", "c": "#f2dcb0", "f": "#74b850", "t": "#c4e88a", "n": "#5a3020", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "g": "#3a8a34"}, idle='''
.ttt..a...a.
tffft.aaaaa.
tfgffaieaiea
tfgf.aeeaeea
.tfgfcpanapc
..tfaaacccc.
...tfabaccc.
....aaaaccc.
....aa.a.aa.''', step_tail='''
.....aa.aa..''', sleep='''
.ttt..a...a.
tffft.aaaaa.
tfgffakkakka
tfgffcpanapc
tffffaacccc.
.tttttaaaaa.''')
PANDAN_SQUIRREL_ADULT = dict(pal={"a": "#c0753a", "b": "#7a4420", "c": "#f2dcb0", "f": "#74b850", "t": "#c4e88a", "n": "#5a3020", "o": "#b8783a", "q": "#6a4020", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "g": "#3a8a34"}, idle='''
.ttt...........
tffft....a...a.
tfgfft...aaaaa.
tfggfft.aieaiea
tfgffft.aeeaeea
.tfgfft.cpanapc
..tfgft.aacccaa
...tfaabaaqqca.
....aaabaaaooc.
....aabaaacccc.
.....aaaaaccc..
....aaa....aa..''', step_tail='''
.....aaa..aa...''', sleep='''
.ttt...........
tffft....a...a.
tfgfft...aaaaa.
tfggfft.akkakka
tfgfffaacpanapc
.tffffaaabaaaaa
..tttttaaaaaaa.''')
skin(key='pandan_squirrel', pet='squirrel', name='향잎 꼬리 다람쥐',
    desc='잿빛그늘숲 약초 마을 텃밭에서 향잎을 깔고 자다 꼬리가 잎빛으로 물든 다람쥐입니다. 꼬리를 흔들 때마다 달큰한 잎 냄새가 나서, 마을 아이들이 밥 짓는 날이면 쫓아다닙니다.',
    baby=PANDAN_SQUIRREL_BABY, adult=PANDAN_SQUIRREL_ADULT)

SNOW_LEOPARD_CAT_BABY = dict(pal={"a": "#c8c2bc", "c": "#f6f3ec", "n": "#e48a96", "e": "#6a9a88", "i": "#e8f4ec", "p": "#d98a96", "d": "#5a5258"}, idle='''
.....a...a..
....aaa.aaa.
....aaadaaa.
d...aieaiea.
a...aeeaeea.
.d..pacncap.
.adaadacccc.
.aadaaacccc.
.cc.c..c.cc.''', step_tail='''
..cc.c.c.cc.''', sleep='''
......a...a.
.....aaa.aaa
.....aaaadaa
.adadakkakka
daaaapacncap
accccccccaa.''')
SNOW_LEOPARD_CAT_ADULT = dict(pal={"a": "#c8c2bc", "c": "#f6f3ec", "n": "#e48a96", "e": "#6a9a88", "i": "#e8f4ec", "p": "#d98a96", "d": "#5a5258"}, idle='''
........a...a..
.......aaa.aaa.
.......aaadaaa.
.d.....aieaiea.
a......aeeaeea.
d......pacncap.
.a......accca..
..adaadaaccccc.
..aadaadacccca.
..adaadaadaada.
..aa.aa...aa.a.
..cc.cc...cc.c.''', step_tail='''
...aa.aa..aa.a.
..cc...cc.c..c.''', sleep='''
.........a...a.
........aaa.aaa
........aaaadaa
.adaadaadkkakka
daadaadapacncap
aadaadaaacccada
.cccccaaaaccc..''')
skin(key='snow_leopard_cat', pet='tuxedo_cat', name='설표 무늬 고양이',
    desc='눈마루 돌집 화롯가에 눌러앉은 고양이입니다. 잿빛 털에 설표처럼 검은 꽃무늬가 앉았고, 꼬리 끝은 먹을 찍은 듯 까맣습니다. 추운 날이면 그 굵은 꼬리로 제 코를 덮고 잡니다.',
    baby=SNOW_LEOPARD_CAT_BABY, adult=SNOW_LEOPARD_CAT_ADULT)

CORAL_GOLDFISH_BABY = dict(pal={"g": "#bfe3ee", "q": "#e6f6fa", "w": "#6ab4d4", "d": "#4a90b8", "o": "#f0607a", "f": "#ffe2ea", "b": "#eaf8ff", "s": "#f0dcb0", "l": "#ff8a5a", "e": "#2a1a14", "i": "#ffffff", "r": "#c83a5a", "m": "#e0603a"}, lid='o', idle='''
..gggggggg..
..gqqqqqqg..
.gwwwwwwwbg.
gwwwwwwwwwwg
gwwfwooiwwwg
gwffoooeowwg
gwwfwooowwwg
gdwlwwwwwwdg
.gsllsssssg.
..gggggggg..''', step='''
..gggggggg..
..gqqqqqqb..
.gwwwwwwwwg.
gwwwwwwwwbwg
gwwwfwooiwwg
gwwffoooeowg
gwwwfwooowwg
gdwlwwwwwwdg
.gsllsssssg.
..gggggggg..''', sleep='''
..gggggggg..
..gqqqqqqg..
.gwwwwwwwwg.
gwwwwwwwwwwg
gwwwwwwwwwwg
gwwfwoooowwg
gwffoooookwg
gdwlfwooowdg
.gsllsssssg.
..gggggggg..''')
CORAL_GOLDFISH_ADULT = dict(pal={"g": "#bfe3ee", "q": "#e6f6fa", "w": "#6ab4d4", "d": "#4a90b8", "o": "#f0607a", "r": "#c83a5a", "f": "#ffe2ea", "b": "#eaf8ff", "s": "#f0dcb0", "l": "#ff8a5a", "m": "#e0603a", "e": "#2a1a14", "i": "#ffffff"}, lid='o', idle='''
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
..ggggggggggg..''', step='''
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
..ggggggggggg..''', sleep='''
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
..ggggggggggg..''')
skin(key='coral_goldfish', pet='goldfish', name='산호빛 금붕어',
    desc='파도너울성 장대 다리 밑 수상 가옥 처마에 매단 어항에서 사는 금붕어입니다. 산호처럼 붉은 몸에 지느러미 끝이 희고, 어항 바닥에는 바다에서 주워 온 산호 가지가 꽂혀 있습니다.',
    baby=CORAL_GOLDFISH_BABY, adult=CORAL_GOLDFISH_ADULT)

BRASS_LADYBUG_BABY = dict(pal={"a": "#d8a838", "b": "#9a7228", "n": "#2a2420", "w": "#f4f0e6", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "r": "#6a3018", "h": "#f8e6a8"}, idle='''
...ahaa....
..araarar..
.aaaaraaannn
.araaaaanwew
.aaaraarannn
..aaaaaan...
..n.n..n.n..''', step_tail='''
...n.n.n.n..''', sleep='''
...ahaa....
..araarar..
.aaaaraaannn
.araaaaankkn
.aaaraarannn
.rrrrrrrn...''')
BRASS_LADYBUG_ADULT = dict(pal={"a": "#d8a838", "b": "#9a7228", "n": "#2a2420", "w": "#f4f0e6", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "r": "#6a3018", "h": "#f8e6a8"}, idle='''
.....ahha.......
...aaraaaraa....
..aaaaaaraaaa...
.araaaraaaarannn
.aaaaaaaraaannnn
.aaraaaaaaaranwe
.aaaaraaraaannnn
..aaaaaaaaraa...
...aaaaaaaaa....
...n.n..n..n.n..''', step_tail='''
....n.n.n..n..n.''', sleep='''
.....ahha.......
...aaraaaraa....
..aaaaaaraaaa...
.araaaraaaarannn
.aaaaaaaraaannnn
.aaraaaaaaarkknn
.aaaaraaraaannnn
.rrrrrrrrrrrn...''')
skin(key='brass_ladybug', pet='ladybug', name='놋쇠 무당벌레',
    desc='불씨들녘 장인 마을 대장간 둘레를 날던 무당벌레가 두드려 편 놋쇠 등딱지를 얻어 입었다고 합니다. 점 일곱 개는 구리를 박아 넣은 것이라, 볕을 받으면 등이 그릇처럼 반짝입니다.',
    baby=BRASS_LADYBUG_BABY, adult=BRASS_LADYBUG_ADULT)

EMBER_PUPPY_BABY = dict(pal={"a": "#8c8690", "b": "#5c5660", "c": "#ddd6d0", "n": "#3a2418", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "o": "#f08a3a"}, idle='''
.....aaaaa..
...baaaaaaab
...baieaieab
o..obeeaeebo
b...pacncap.
.baaaaaccca.
.aaaaaaaaaaa
.aaaaaaaaaaa
.aa.a...a.aa''', step_tail='''
..aa.a.aa.a.''', sleep='''
.....aaaaa..
...baaaaaaab
...bakkakkab
oaaopacncapo
.aaaaaaaaaaa
.aaaaaaaaaa.''')
EMBER_PUPPY_ADULT = dict(pal={"a": "#8c8690", "b": "#5c5660", "c": "#ddd6d0", "n": "#3a2418", "d": "#d85a2a", "y": "#ffd060", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "o": "#f08a3a"}, idle='''
........aaaaa..
......baaaaaaab
......baieaieab
......obeeaeebo
o......pacncap.
.b......accca..
.b.....dddyddd.
.aaaaaaaacccaa.
.abbaaaaaaaaaa.
.aa.aa....aa.aa
.aa.aa....aa.aa''', step_tail='''
.aa..aa..aa.aa.
aa....aa.aa..aa''', sleep='''
........aaaaa..
......baaaaaaab
......bakkakkab
oaaaaaopacncapo
.aaaaaaadddyddd
aabbaaaaaaaaaaa
.aaaaaaaaaaaaa.''')
skin(key='ember_puppy', pet='nureong_puppy', name='잿불 강아지',
    desc='불씨들녘 화산 기슭 마을에서 재를 뒤집어쓰고 자란 강아지입니다. 털은 잿빛인데 귀 끝과 꼬리 끝만 불씨처럼 발갛게 남아, 신이 나면 그 끝을 파르르 떱니다.',
    baby=EMBER_PUPPY_BABY, adult=EMBER_PUPPY_ADULT)

LOTUS_FOX_BABY = dict(pal={"a": "#fff8f2", "c": "#f2b8c8", "o": "#ec7a96", "q": "#c8506e", "r": "#e0607e", "n": "#3a2418", "e": "#5a2410", "i": "#b07050"}, idle='''
.oo.oo.......
.aa.cc.o...o.
oaakcc.aa.aa.
oaakccaaaaaaa
ccakccaieaiea
.ccaccaeeaeea
..ccccraanaar
...aaaaaaaaa.
...aaaaaaaaa.
...oo.o..o.oo''', step='''
oo.oo........
aa.cc..o...o.
aakcc..aa.aa.
oakccaaaaaaa
cakccaaieaiea
.ccaccaeeaeea
..ccccraanaar
...aaaaaaaaa.
...aaaaaaaaa.
....oo.o.o.o.''', sleep='''
.......o...o.
.......aa.aa.
......aaaaaaa
oo....akkakka
ccaaaaraanaar
oaccaaaaaaaaa
.oocccccccaa.''')
LOTUS_FOX_ADULT = dict(pal={"a": "#fff8f2", "c": "#f2b8c8", "o": "#ec7a96", "q": "#c8506e", "r": "#e0607e", "n": "#3a2418", "e": "#5a2410", "i": "#b07050"}, idle='''
....q.o...o...o.
..ooqqoo..aa.aa.
.qooqca..aaaaaaa
oqcaaca..aieaiea
oacaaca..aeeaeea
caacaca..raanaar
ccaackk...acca..
aacakaaaaaaacca.
caakaaaaaaaaaaa.
ccckaaaaaaaaaa..
aa..aa.aa...aa.a
....oo.oo...oo.o''', step='''
.....q.o..o...o.
.q.ooqqoo.aa.aa.
oqqoocco.aaaaaaa
ooccacca.aieaiea
qaacacaa.aeeaeea
ccacaca..raanaar
accackk...acca..
aaackaaaaaaacca.
ccckaaaaaaaaaaa.
aaakaaaaaaaaaa..
.....aa.aa..aa.a
....oo...oo.oo.o''', sleep='''
..........o...o.
..........aa.aa.
.oqo.....aaaaaaa
oqoc.....akkakka
qockkaaaaraanaar
oakaaaaaaaaaaaaa
qckaaaaaaaaaaaa.''')
skin(key='lotus_fox', pet='baby_gumiho', name='연꽃 구미호',
    desc='해오름성 탑 사원 연못가에서 자란 어린 여우입니다. 꼬리 끝이 연꽃 봉오리처럼 분홍빛으로 물들어, 연못에 꼬리를 담그면 연꽃이 하나 더 핀 것처럼 보입니다.',
    baby=LOTUS_FOX_BABY, adult=LOTUS_FOX_ADULT)

FLAG_CRANE_BABY = dict(pal={"w": "#f6f4ee", "g": "#c4cad6", "a": "#2c2c36", "r": "#d8323a", "n": "#c8a860", "l": "#4a4a52", "e": "#2a1a14", "i": "#7a7a80", "p": "#f3a0a0", "u": "#3a78c8", "v": "#4aa860", "y": "#f2c94c"}, lid='w', idle='''
......wrrw..
.....wwwiew.
.....wwweewn
.....wwwwpw.
aa.ggurvyw..
.aaggggwwww.
..aggggwwww.
....gggww...
.....l.l....
....ll.ll...''', step_tail='''
.....l..l...
....ll...ll.''', sleep='''
......wrrw..
.....wwwwww.
.....wwkkwwn
aa.ggurvypw.
.aaggggwwww.
..aggggwwww.
...ggggggg..''')
FLAG_CRANE_ADULT = dict(pal={"w": "#f6f4ee", "g": "#c4cad6", "a": "#2c2c36", "r": "#d8323a", "n": "#c8a860", "l": "#4a4a52", "e": "#2a1a14", "i": "#7a7a80", "p": "#f3a0a0", "u": "#3a78c8", "v": "#4aa860", "y": "#f2c94c"}, lid='w', idle='''
.........rr....
........wwwww..
........wwiewnn
........aweew..
.........aaa...
........urvy...
..aa..wwwwww...
.aaaawwwwwwww..
aaaaawwwwwwww..
.aaaaawwwwww...
...aaawwwww....
.......l..l....
.......l..l....
......ll.ll....''', step_tail='''
.......l..l....
.......l.ll....
......ll.......''', sleep='''
.........rr....
........wwwww..
........wwkkwnn
........awwww..
........urv....
..aa..wwwyww...
.aaaawwwwwwww..
aaaaawwwwwwww..
.aaaaawwwwwww..
...aaawwwwww...''')
skin(key='flag_crane', pet='baby_crane', name='오색 깃발 두루미',
    desc='눈마루 설산 고개를 넘나드는 아기 두루미입니다. 돌탑에 걸린 오색 기도 깃발 한 줄을 목도리처럼 감고 내려왔는데, 풀어 주려 하면 고개를 저으며 날개로 꼭 감쌉니다.',
    baby=FLAG_CRANE_BABY, adult=FLAG_CRANE_ADULT)

YAK_CALF_BABY = dict(pal={"a": "#7a5844", "b": "#3e2c22", "c": "#c8b4a0", "h": "#f2e6c8", "n": "#e8a0a0", "e": "#2a1a14", "i": "#ffffff", "r": "#d8443a", "w": "#f4ece0"}, idle='''
.........h.h.
........raawa
b.aaaaaaaaiea
.aaaaaaaaaacc
.aaaaaaaaaanc
.bbabbabbab..
..bb.bb..bb..''', step_tail='''
...bb.bb.bb..''', sleep='''
.........h.h.
........raawa
b.aaaaaaaakka
.aaaaaaaaaacc
.bbbbbbbbbbnc''')
YAK_CALF_ADULT = dict(pal={"a": "#7a5844", "b": "#3e2c22", "c": "#c8b4a0", "h": "#f2e6c8", "n": "#e8a0a0", "e": "#2a1a14", "i": "#ffffff", "r": "#d8443a", "w": "#f4ece0"}, idle='''
............h..h.
............haah.
..........raawaaa
b..aaaaaaaaaaieaa
.baaaaaaaaaaaaccc
..aaaaaaaaaaaancc
..babbabbabbab...
..aa.aa...aa.aa..
..bb.bb...bb.bb..''', step_tail='''
...aa.aa..aa.aa..
...bb.bb..bb.bb..''', sleep='''
............h..h.
............haah.
..........raawaaa
b..aaaaaaaaaakkaa
.baaaaaaaaaaaaccc
..aaaaaaaaaaaancc
..bbbbbbbbbbbbb..''')
skin(key='yak_calf', pet='ox_calf', name='털북숭이 야크 송아지',
    desc='눈마루 고원에서 버터차 짓는 집 마당에 매여 있던 야크 송아지입니다. 배 밑으로 북슬북슬한 털이 치마처럼 늘어지고, 귀에는 주인이 달아 준 붉은 술이 달랑거립니다.',
    baby=YAK_CALF_BABY, adult=YAK_CALF_ADULT)

FESTIVE_ELEPHANT_BABY = dict(pal={"a": "#a8a4ac", "b": "#7c7880", "c": "#e8c0c6", "w": "#f4f0e6", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "r": "#d8443a", "y": "#f2c94c", "u": "#3a78c8"}, idle='''
.......cccay..
......ccccara.
..rrrrccaaiea.
.rryrrraaaaapa
.yuyuyyaaaaa.a
.aaaaaaaaaa..a
..aa.aa.aa..b.
..bb.bb.bb....''', step_tail='''
...aa.aa.aa.b.
...bb.bb.bb...''', sleep='''
.......cccay..
......ccccara.
..rrrrccaakka.
.rryrrraaaaapa
.yuyuyyaaaaaaa
.bbbbbbbbbbbbb''')
FESTIVE_ELEPHANT_ADULT = dict(pal={"a": "#a8a4ac", "b": "#7c7880", "c": "#e8c0c6", "w": "#f4f0e6", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "r": "#d8443a", "y": "#f2c94c", "u": "#3a78c8"}, idle='''
.........ccccaya...
........cccccaraa..
...rrrrrccccaaaaa..
..rryrryrccaaaieaa.
.rrrrrrrrraaaaaapaa
.yuyuyuyyaaaaaaa.wa
.aaaaaaaaaaaaaa...a
.aaaaaaaaaaaaa....a
..aaa.aaa..aaa...b.
..aaa.aaa..aaa.....
..bbb.bbb..bbb.....''', step_tail='''
...aaa.aaa.aaa...b.
...aaa.aaa.aaa.....
...bbb.bbb.bbb.....''', sleep='''
.........ccccaya...
........cccccaraa..
...rrrrrccccaaaaa..
..rryrryrccaaakkaa.
.rrrrrrrrraaaaaapaa
.yuyuyuyyaaaaaaa.wa
.aaaaaaaaaaaaaaaaaa
.bbbbbbbbbbbbbbbbbb''')
skin(key='festive_elephant', pet='baby_elephant', name='꽃단장 아기 코끼리',
    desc='달맞이성 잔칫날 행렬 맨 끝을 따라 걷는 아기 코끼리입니다. 이마에 금빛 장식을 달고 등에는 금실 술을 두른 붉은 천을 얹었습니다. 행렬이 멈추면 코를 들어 뿌우 하고 인사합니다.',
    baby=FESTIVE_ELEPHANT_BABY, adult=FESTIVE_ELEPHANT_ADULT)

LITTLE_STONECRY_BABY = dict(pal={"s": "#7c7a82", "h": "#aeacb2", "r": "#4a4850", "a": "#c2ae84", "c": "#e2d2a8", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "g": "#f2a23a", "m": "#5aa040"}, idle='''
....mm......
...rrrr.....
..rhhgsr.aa.
.rssgshhraaa
.rhhsgssraie
rccccccccaee
.accccccaap.
.aa.aa.aa...''', step_tail='''
..aa.aa.aa..''', sleep='''
....mm......
...rrrr.....
..rhhgsr....
.rssgshhr...
.rhhsgssraa.
rccccccccakk
.cccccccccc.''')
LITTLE_STONECRY_ADULT = dict(pal={"s": "#7c7a82", "h": "#aeacb2", "r": "#4a4850", "a": "#c2ae84", "c": "#e2d2a8", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "g": "#f2a23a", "m": "#5aa040"}, idle='''
......mm.......
....rrrrrr.....
...rhhsgshr....
..rsshgsshhr.aa
.rhhsshgsshhraa
.rshhsgshhshraie
rccccccccccccaee
.acccccccccaaap.
.aaa.aa...aa.a..
..aa.aa...aa.a..''', step_tail='''
..aa..aa.aa..a..
.aa..aa...aa.a..''', sleep='''
......mm.......
....rrrrrr.....
...rhhsgshr....
..rsshgsshhr...
.rhhsshgsshhr..
.rshhsgshhshraa.
rcccccccccccakk.
.cccccccccccccc.''')
skin(key='little_stonecry', pet='baby_turtle', name='꼬마 돌울이',
    desc='땅울이를 잠재운 날 고임터 돌판 틈에서 따라 나온 새끼 거북입니다. 등딱지가 돌판 조각처럼 단단해졌고, 그 금 사이로 지맥 빛이 가늘게 비칩니다. 등에 이끼 싹이 돋으면 땅이 숨 쉰다며 좋아합니다.',
    baby=LITTLE_STONECRY_BABY, adult=LITTLE_STONECRY_ADULT)


MARIGOLD_PUPPY_BABY = dict(pal={"a": "#f8f6f0", "b": "#ded6c6", "n": "#2a1a14", "r": "#f08a20", "y": "#ffd040", "s": "#f08a20", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
...aa....aa.
...apaaaaapa
...aaieaieaa
a..aaeeaeeaa
aa..pabnbap.
.a...sysys..
.aaaaaaaaaaa
.aaaaaaaaaaa
.aa.a...a.aa''', step_tail='''
..aa.a.aa.a.''', sleep='''
...aa....aa.
...apaaaaapa
...aakkakkaa
aa..pabnbap.
.aaaaaaaaaaa
.aaaaaaaaaa.''')
MARIGOLD_PUPPY_ADULT = dict(pal={"a": "#f8f6f0", "b": "#ded6c6", "n": "#2a1a14", "r": "#f08a20", "y": "#ffd040", "s": "#f08a20", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
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
.aa.aa....aa.aa''', step_tail='''
.aa..aa..aa.aa.
aa....aa.aa..aa''', sleep='''
......aa.....aa
......apaaaaapa
......aakkakkaa
.aa....pabnbap.
a..aaaaasssysss
aaaaaaaaaaabbaa
.aaaaaaaaaaaaa.''')
skin(key='marigold_puppy', pet='white_puppy', name='금잔화 목걸이 강아지',
    desc='달맞이성 잔칫날 향신료 시장에서 누가 걸어 준 금잔화 목걸이를 늘 차고 다니는 흰 강아지입니다. 꽃잎이 하나라도 떨어지면 주워 와서 내밉니다.',
    baby=MARIGOLD_PUPPY_BABY, adult=MARIGOLD_PUPPY_ADULT)

WAVE_DDONGGAE_BABY = dict(pal={"a": "#ead6ab", "b": "#4a3222", "g": "#8cc4d0", "m": "#5c3f2a", "c": "#fbf3e2", "n": "#1a0f0a", "q": "#4e2c12", "r": "#7e4a20", "d": "#2f6fb8", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "w": "#f4f4f0"}, idle='''
.......q....
......qrq...
.....qqrqq..
.....aaaaa..
...baaaaaaab
...baieaieab
b..bbeeaeebb
b...pamnmap.
.baaadwdwda.
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
.aaaaaggaaa.''')
WAVE_DDONGGAE_ADULT = dict(pal={"a": "#ead6ab", "b": "#4a3222", "g": "#8cc4d0", "m": "#5c3f2a", "c": "#fbf3e2", "n": "#1a0f0a", "q": "#4e2c12", "r": "#7e4a20", "d": "#2f6fb8", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "w": "#f4f4f0"}, idle='''
..........q....
.........qrq...
........qqrqq..
........aaaaa..
......baaaaaaab
......baieaieab
......bbeeaeebb
b......pamnmap.
.b......accca..
.b.....dwdwdwd.
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
.aaaaaaaaaaaaa.''')
skin(key='wave_ddonggae', pet='ddonggae', name='물결 목수건 똥개',
    desc='파도너울성 쪽배 사공 집에서 크는 똥개입니다. 사공이 매어 준 쪽빛 물결 목수건을 하고, 털에 바닷물 빛 얼룩이 앉았습니다. 배가 들어오면 장대 다리 끝까지 달려 나갑니다.',
    baby=WAVE_DDONGGAE_BABY, adult=WAVE_DDONGGAE_ADULT)

TURMERIC_CAT_BABY = dict(pal={"a": "#f2b820", "o": "#b86a10", "c": "#fbf1df", "n": "#e07a86", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
.....a...a..
....aaa.aaa.
....aoaoaoa.
o...aieaiea.
o...aeeaeea.
.o..pacncap.
.aaoaoacccc.
.aoaoaacccc.
.aa.a..c.cc.''', step_tail='''
..aa.a.c.cc.''', sleep='''
......a...a.
.....aaa.aaa
.....aoaoaoa
.aaaaakkakka
aoaoapacncap
accccccccaa.''')
TURMERIC_CAT_ADULT = dict(pal={"a": "#f2b820", "o": "#b86a10", "c": "#fbf1df", "n": "#e07a86", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
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
..aa.aa...cc.c.''', step_tail='''
...aa.aa..cc.c.
..aa...aa.c..c.''', sleep='''
.........a...a.
........aaa.aaa
........aoaoaoa
.aaaaaaaakkakka
aaoaoaoapacncap
aaaoaoaaacccaaa
.oooooooooooo..''')
skin(key='turmeric_cat', pet='cheese_cat', name='강황 줄고양이',
    desc='잿빛그늘숲 약초 마을 강황 자루 위에서 낮잠을 자다 털이 샛노랗게 물든 고양이입니다. 비비고 간 자리마다 노란 털이 묻어 남습니다.',
    baby=TURMERIC_CAT_BABY, adult=TURMERIC_CAT_ADULT)

MILK_LONGHAIR_BABY = dict(pal={"a": "#ecdcb8", "s": "#c0a070", "w": "#fbf4e2", "p": "#eaa6a6", "e": "#3a3440", "n": "#e58f98"}, idle='''
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
....asaasaasa...''', blink='''
..........a..a..
.........apaapa.
.......aaaaaaaa.
.....aaaaaaaaaaa
....aaasasasasaa
...aaaassasassaa
..aaaaaaaaanaaaa
s.aaawaaaaaaaaa.
ssaaaaaaaaaaaaa.
sssaaaaaaaaaaa..
sss.aaaaaaaaaa..
.s..asaasaasa...''')
MILK_LONGHAIR_ADULT = dict(pal={"a": "#ecdcb8", "s": "#c0a070", "w": "#fbf4e2", "p": "#eaa6a6", "e": "#3a3440", "n": "#e58f98"}, idle='''
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
..ss..asaaasaaasaa....''', blink='''
..............a...a...
.............apa.apa..
...........aaaaaaaaaa.
.........aaaaaaaaaaaaa
........aaasasasasasaa
.......aaaasasasasasaa
......aaaaaassasassaaa
.....aaaaaaaaaaanaaaaa
....aaaaaawaaaaaaaaaa.
s..aaawaaaaaaaaaaaaaa.
sssaaaaaaaaaaaaaaaaaa.
ssssaaaaaaaaaaaaaaaa..
sssssaaaaaaaaaaaaaaa..
.ss...asaaasaaasaa....''')
skin(key='milk_longhair', pet='ash_longhair', name='젖빛 장모 고양이',
    desc='눈마루 돌집에서 야크 젖 통 곁을 지키는 긴 털 고양이입니다. 털이 젖빛으로 포근해 아이들이 목도리 대신 안고 다닙니다.',
    baby=MILK_LONGHAIR_BABY, adult=MILK_LONGHAIR_ADULT)

KINGFISHER_MAGPIE_BABY = dict(pal={"a": "#1f8aa8", "b": "#1e5aa8", "w": "#f08a3a", "n": "#4a4a58", "h": "#5ab8d0", "e": "#0c0806", "i": "#ffffff", "p": "#f3a0a0"}, line='h', idle='''
......aaa...
.....aaaaa..
....aaaaiea.
....aaaaeenn
bb..baaaapa.
.bbbbbbwwww.
..bbbbbwwww.
....bbwwww..
.....n.n....''', step_tail='''
...bbbwwww..
......nn....''', sleep='''
.......aaa..
......aaaaa.
.....aaahhan
bb..baaaapa.
.bbbbbbwwww.
..bbbbwwwww.''')
KINGFISHER_MAGPIE_ADULT = dict(pal={"a": "#1f8aa8", "b": "#1e5aa8", "w": "#f08a3a", "n": "#4a4a58", "h": "#5ab8d0", "e": "#0c0806", "i": "#ffffff", "p": "#f3a0a0"}, line='h', idle='''
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
.......nn.nn...''', step_tail='''
.........nn....
........nn.n...''', sleep='''
.........aaa...
........aaaaa..
........aaahhan
.......aaaaap..
......bwwbbaww.
bb..bbbwwbbbwww
.bbbbbbbbbbwww.
...bbbbbbbwww..''')
skin(key='kingfisher_magpie', pet='magpie', name='물총새 깃 까치',
    desc='파도너울성 물가 말뚝에 앉아 물고기를 노리다 물총새 빛이 옮았다는 까치입니다. 등은 옥빛, 배는 주황빛이라 물 위에서 금방 눈에 띕니다.',
    baby=KINGFISHER_MAGPIE_BABY, adult=KINGFISHER_MAGPIE_ADULT)

SNOW_OWL_BABY = dict(pal={"a": "#f4f4f6", "b": "#8a90a0", "c": "#e2e6ee", "y": "#f0b030", "n": "#a8a0a0", "f": "#c8b070", "e": "#2a1a14", "i": "#ffffff"}, eyes='eiy', lid='c', idle='''
..a......a..
..aa....aa..
.aaaaaaaaaa.
.cyyyccyyyc.
.cyiecyiecc.
.cyeeccyeec.
.acccnnccca.
.aabcbcbcaa.
..abcbcbca..
...ff..ff...''', step_tail='''
..ff....ff..''', sleep='''
..a......a..
..aa....aa..
.aaaaaaaaaa.
.ccccccccccc
.ckkkcckkkc.
.acccnnccca.
.aabcbcbcaa.
..abcbcbca..''')
SNOW_OWL_ADULT = dict(pal={"a": "#f4f4f6", "b": "#8a90a0", "c": "#e2e6ee", "y": "#f0b030", "n": "#a8a0a0", "f": "#c8b070", "e": "#2a1a14", "i": "#ffffff"}, eyes='eiy', lid='c', idle='''
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
...fff...fff...''', step_tail='''
..fff.....fff..''', sleep='''
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
..bbaaaaaaabb..''')
skin(key='snow_owl', pet='baby_owl', name='설산 흰부엉이',
    desc='눈마루 설산 돌탑 틈에 사는 아기 부엉이입니다. 눈처럼 흰 깃에 잿빛 점이 박혀, 눈밭에 앉으면 노란 눈만 동그랗게 보입니다.',
    baby=SNOW_OWL_BABY, adult=SNOW_OWL_ADULT)

PALM_SUGAR_RABBIT_BABY = dict(pal={"a": "#d09a60", "c": "#a06a38", "p": "#f2a2b2", "n": "#e07a8a", "e": "#3a1a10", "i": "#ffffff"}, idle='''
.....aa.aa..
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
..aaaa......
...appaaaaa.
....akkakka.
.cc.paanaap.
ccaaaaaaaaaa
.caaaaaaaaa.''')
PALM_SUGAR_RABBIT_ADULT = dict(pal={"a": "#d09a60", "c": "#a06a38", "p": "#f2a2b2", "n": "#e07a8a", "e": "#3a1a10", "i": "#ffffff"}, idle='''
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
.aaaa....aa.a.''', step_tail='''
..caaaaaaaaa..
aaaa......aa..''', sleep='''
...aaaaa......
....apppaaaaa.
......akkakka.
.cc...paanaap.
cccaaaaaaaaaaa
.caaaaaaaaaaa.
..aaaaaaaaaaa.''')
skin(key='palm_sugar_rabbit', pet='white_rabbit', name='야자 설탕 토끼',
    desc='해오름성 탑 사원 앞 엿장수 집 토끼입니다. 야자 설탕 졸이는 솥 곁에서 자라 털이 달큰한 갈색이 되었습니다.',
    baby=PALM_SUGAR_RABBIT_BABY, adult=PALM_SUGAR_RABBIT_ADULT)

SILVERGRASS_FAWN_BABY = dict(pal={"a": "#aeaaa6", "b": "#5a5650", "c": "#ece8e0", "w": "#fff4e0", "n": "#2a1a14", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
.......bb.bb..
.......bcbbc..
........aaaa..
.......aaaaaa.
.......aieaaaa
.......aeeaacn
.......paaacc.
.w.aaaaaaaa...
..awawawaaa...
..aaaaaaaa....
..a.a...a.a...
..a.a...a.a...
..b.b...b.b...''', step_tail='''
...a.a..a.a...
...a.a..a.a...
...b.b..b.b...''', sleep='''
.......bb.bb..
.......bcbbc..
........aaaa..
.......aaaaaa.
.......akkaaaa
.......paaaacn
.w.aaaaaaaacc.
..awawawaaaa..
.bbbbbbbbbbb..''')
SILVERGRASS_FAWN_ADULT = dict(pal={"a": "#aeaaa6", "b": "#5a5650", "c": "#ece8e0", "w": "#fff4e0", "n": "#2a1a14", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
.........bb.bb...
.........bcbbcb..
..........aaaa...
.........aaaaaa..
.........aaaaaaa.
.........aieaaaaa
.........aeeaaacn
.........paaaacc.
.........aaaaa...
.waaaaaaaaaaaa...
..awawawawaaaa...
..aaaaaaaaaaa....
..a.a......a.a...
..a.a......a.a...
..b.b......b.b...''', step_tail='''
...a.a....a.a....
...a.a....a.a....
...b.b....b.b....''', sleep='''
.........bb.bb...
.........bcbbcb..
..........aaaa...
.........aaaaaa..
.........aaaaaaa.
.........akkaaaaa
.........paaaaacn
.........aaaaacc.
.waaaaaaaaaaaa...
..awawawawaaaa...
.bbbbbbbbbbbbb...''')
skin(key='silvergrass_fawn', pet='roe_fawn', name='흰 억새 노루',
    desc='잿빛그늘숲 흰 억새밭에서 태어난 아기 노루입니다. 털이 억새처럼 은빛이라, 바람에 억새가 눕는 날이면 어디 있는지 찾기 어렵습니다.',
    baby=SILVERGRASS_FAWN_BABY, adult=SILVERGRASS_FAWN_ADULT)

CHILI_CRAB_BABY = dict(pal={"a": "#d8261e", "b": "#9a1810", "c": "#5ab040", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
c.c........c.c
ccc........ccc
.c..aaaaaa..c.
.c.aaaaaaaa.c.
.caaieaaieaac.
..aaeeaaeeaa..
..apaaaaaapa..
.b.b.b..b.b.b.''', step_tail='''
..b.b.b.b.b.b.''', sleep='''
....aaaaaa....
cc.aaaaaaaa.cc
ccakkaaaakkacc
..apaaaaaapa..
.bbbbbbbbbbbb.''')
CHILI_CRAB_ADULT = dict(pal={"a": "#d8261e", "b": "#9a1810", "c": "#5ab040", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
.c..c........c..c.
.cccc........cccc.
..cc..aaaaaa..cc..
..c..aaaaaaaa..c..
..c.aaaaaaaaaa.c..
..caaieaaaaieaac..
...aaeeaaaaeeaa...
...aapaaaaaapaa...
....aaaaaaaaaa....
..b.b.b....b.b.b..''', step_tail='''
...b.b.b..b.b.b...''', sleep='''
......aaaaaa......
.cc..aaaaaaaa..cc.
ccc.aaaaaaaaaa.ccc
.c.aakkaaaakkaa.c.
...aapaaaaaapaa...
..bbbbbbbbbbbbbb..''')
skin(key='chili_crab', pet='baby_crab', name='고추 양념 게',
    desc='불씨들녘 장터 고추 양념 항아리 곁을 기어다니던 게입니다. 몸은 고추처럼 새빨갛고 집게만 꼭지처럼 초록빛입니다.',
    baby=CHILI_CRAB_BABY, adult=CHILI_CRAB_ADULT)

EBONY_PANGOLIN_BABY = dict(pal={"a": "#34362e", "b": "#6e7e54", "c": "#cec6aa", "n": "#1e1e1a", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
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
..bbbbbbb.''')
EBONY_PANGOLIN_ADULT = dict(pal={"a": "#34362e", "b": "#6e7e54", "c": "#cec6aa", "n": "#1e1e1a", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
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
..bbbbbbbbb..''')
skin(key='ebony_pangolin', pet='baby_pangolin', name='흑단 비늘 천산갑',
    desc='잿빛그늘숲 흑단 고목 밑에서 몸을 말고 자던 아기 천산갑입니다. 비늘이 흑단과 이끼 빛으로 번갈아 앉았습니다.',
    baby=EBONY_PANGOLIN_BABY, adult=EBONY_PANGOLIN_ADULT)

BOATMAN_OTTER_BABY = dict(pal={"a": "#7a5236", "b": "#553620", "c": "#e4ccaa", "n": "#2a1a14", "f": "#8fb8d0", "g": "#c8dce8", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "y": "#e2b45a", "q": "#a07830"}, idle='''
.......yy...
.....yyyyyy.
....qqqqqqqq
......a...a.
.....aaaaaaa
.....aieaiea
.....aeeaeea
.....pccnccp
.bbaaaacccc.
bbbaaaaaaaa.
.b.aaaaaaa..
...aa.a..aa.''', step_tail='''
....aa.a.aa.''', sleep='''
.......yy...
.....yyyyyy.
....qqqqqqqq
......a...a.
.....aaaaaaa
.....akkakka
.bbaapccnccp
bbbaaaacggca
.bbaaaaaaaa.''')
BOATMAN_OTTER_ADULT = dict(pal={"a": "#7a5236", "b": "#553620", "c": "#e4ccaa", "n": "#2a1a14", "f": "#8fb8d0", "g": "#c8dce8", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "y": "#e2b45a", "q": "#a07830"}, idle='''
..........yy....
........yyyyyy..
.......qqqqqqqq.
.........a...a..
........aaaaaaa.
........aieaiea.
........aeeaeea.
........pccnccp.
.......aacccca..
b...aaaaaaccccc.
bb.aaaaaaaaaccc.
.bbbaaaaaaaaaa..
...aa.aa...aa.aa''', step_tail='''
....aa.aa.aa.aa.''', sleep='''
..........yy....
........yyyyyy..
.......qqqqqqqq.
.........a...a..
........aaaaaaa.
........akkakka.
........pccnccp.
b....aaaacggccc.
bbbbaaaaaaggcca.
.bbbbaaaaaaaaaa.''')
skin(key='boatman_otter', pet='baby_otter', name='삿갓 사공 수달',
    desc='파도너울성 물 위 장터를 쪽배로 오가는 사공 곁에서 자란 수달입니다. 제 머리만 한 삿갓을 쓰고 노를 젓는 시늉을 합니다.',
    baby=BOATMAN_OTTER_BABY, adult=BOATMAN_OTTER_ADULT)

ICEPOND_SEAL_BABY = dict(pal={"a": "#e6eef6", "s": "#5a86b0", "w": "#f4f4f6", "n": "#3a3a44", "f": "#a8c0d6", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
...aaaaaa...
..aaaaaaaa..
.aieaaaaiea.
.aeeaaaaeea.
.paaannaaap.
faaaawwaaaaf
.aasaaaasaa.
..aaaaaaaa..''', step_tail='''
.aaaaaaaaaa.''', sleep='''
...aaaaaa...
..aaaaaaaa..
.akkaaaakka.
.paaannaaap.
faaaawwaaaaf
.aasaaaasaa.
..aaaaaaaa..''')
ICEPOND_SEAL_ADULT = dict(pal={"a": "#e6eef6", "s": "#5a86b0", "w": "#f4f4f6", "n": "#3a3a44", "f": "#a8c0d6", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
....aaaaaaa....
...aaaaaaaaa...
..aaaaaaaaaaa..
..aieaaaaaiea..
..aeeaaaaaeea..
..paaaannaaaap.
.faaaaawwaaaaf.
ffaasaaaaasaaff
..aaaaaaaaaaa..
...aaaaaaaaa...''', step_tail='''
....aaaaaaa....''', sleep='''
....aaaaaaa....
...aaaaaaaaa...
..aaaaaaaaaaa..
..akkaaaaakka..
..paaaannaaaap.
.faaaaawwaaaaf.
ffaasaaaaasaaff
..aaaaaaaaaaa..
...aaaaaaaaa...''')
skin(key='icepond_seal', pet='spotted_seal', name='얼음못 점박이물범',
    desc='눈마루 얼어붙은 못 얼음 구멍에서 고개를 내미는 아기 물범입니다. 얼음빛 흰 털에 푸른 점이 박혀 있습니다.',
    baby=ICEPOND_SEAL_BABY, adult=ICEPOND_SEAL_ADULT)

LOTUS_LANTERN_BABY = dict(pal={"a": "#f08aa8", "b": "#c85a80", "c": "#3a7a3a", "y": "#fff0a0", "t": "#f2c040", "e": "#2a1a14", "i": "#ffffff", "p": "#ffc0d0"}, idle='''
....c....
...ccc...
..aaaaa..
.abayaba.
.aieyiea.
.apayapa.
.abayaba.
..aaaaa..
...ccc...
....t....''', step_tail='''
...t.....''', sleep='''
....c....
...ccc...
..aaaaa..
.abayaba.
.akkykka.
.apayapa.
..aaaaa..
...ccc...''')
LOTUS_LANTERN_ADULT = dict(pal={"a": "#f08aa8", "b": "#c85a80", "c": "#3a7a3a", "y": "#fff0a0", "t": "#f2c040", "e": "#2a1a14", "i": "#ffffff", "p": "#ffc0d0"}, idle='''
......c......
.....ccc.....
....ccccc....
...aaaaaaa...
..abaayaaba..
.aabayyyabaa.
.aieayyyaiea.
.aapayyyapaa.
.aabayyyabaa.
..abaayaaba..
...aaaaaaa...
....ccccc....
.....t.t.....
......t......''', step_tail='''
....t.t......
.....t.......''', sleep='''
......c......
.....ccc.....
....ccccc....
...aaaaaaa...
..abaayaaba..
.aabayyyabaa.
.akkayyyakka.
.aapayyyapaa.
..abaayaaba..
...aaaaaaa...
....ccccc....''')
skin(key='lotus_lantern', pet='lantern_spirit', name='연꽃 등 혼령',
    desc='해오름성 연못에 띄우는 연꽃 등에 깃든 혼령입니다. 분홍 꽃잎 등 안에서 촛불이 깜박이고, 물에 띄워 주면 빙그르르 돕니다.',
    baby=LOTUS_LANTERN_BABY, adult=LOTUS_LANTERN_ADULT)

EMBER_WISP_BABY = dict(pal={"f": "#f06a28", "c": "#ffb060", "w": "#fff0d0", "d": "#a83018", "e": "#4a1a10", "i": "#c07050", "p": "#ff9ab8", "s": "#ffd060"}, lid='w', noline='s', idle='''
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
...fffffff..''', step='''
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
s..fffffff..''', sleep='''
...f........
...ff..f....
..ffffffff..
.ffcccccccf.
.fcwkkwkkwcf
.fcpwwwwpcf.
..ffcccccf..
....fffff...''')
EMBER_WISP_ADULT = dict(pal={"f": "#f06a28", "c": "#ffb060", "w": "#fff0d0", "d": "#a83018", "e": "#4a1a10", "i": "#c07050", "p": "#ff9ab8", "s": "#ffd060"}, lid='w', noline='s', idle='''
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
....fffffff....''', step='''
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
....fffffff....''', sleep='''
...f...........
...ff...f......
....ff.ff......
..dffffffffd...
..ffcccccccff..
.ffcwwwwwwwcf..
.fcwwkkwwkkwcf.
.fcwpwwwwwpwcf.
..ffcccccccff..
....fffffff....''')
skin(key='ember_wisp', pet='dokkaebi_fire', name='불씨 도깨비불',
    desc='불씨들녘 화산 기슭에서 재비를 맞으며 노는 도깨비불입니다. 파랗던 불이 화산 열기에 주홍빛으로 물들었습니다.',
    baby=EMBER_WISP_BABY, adult=EMBER_WISP_ADULT)

PLANTAIN_RACCOON_BABY = dict(pal={"a": "#8a8c90", "b": "#34343a", "c": "#f0e8d8", "t": "#55575e", "n": "#2a1a14", "l": "#7ac050", "m": "#3a8a3a", "e": "#120c08", "i": "#ffffff", "p": "#f3a0a0"}, line='c', idle='''
....bblllbb.
....acaaaca.
....biecieb.
....beeceeb.
tt..pccnccp.
tbtaaacccc..
.ttaaaaaaaaa
..aaaaaaaaa.
..bb.b..b.bb''', step_tail='''
..b.bb..bb.b''', sleep='''
....bblllbb.
....acaaaca.
tt..bccaccb.
tbt.pccnccp.
tbtaaaaaaaaa
.ttaaaaaaaa.''')
PLANTAIN_RACCOON_ADULT = dict(pal={"a": "#8a8c90", "b": "#34343a", "c": "#f0e8d8", "t": "#55575e", "n": "#2a1a14", "l": "#7ac050", "m": "#3a8a3a", "e": "#120c08", "i": "#ffffff", "p": "#f3a0a0"}, line='c', idle='''
........llll...
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
...bb.bb...bb.b''', step_tail='''
....bb.bb..bb.b
...bb...bb.b..b''', sleep='''
........llll...
.......bbml.bb.
.......acaaaca.
tt.....bccaccb.
tbt....pccnccp.
ttbtaaaaaacccaa
.tbtaaaaaaaaaa.
..tttaaaaaaaa..''')
skin(key='plantain_raccoon', pet='little_raccoon', name='파초잎 너구리',
    desc='잿빛그늘숲 먹비를 큰 파초잎 하나로 막고 다니는 너구리입니다. 털은 비에 젖은 잿빛이고, 잎을 머리에 얹으면 둔갑을 다 했다고 믿습니다.',
    baby=PLANTAIN_RACCOON_BABY, adult=PLANTAIN_RACCOON_ADULT)

FEAST_MASK_BABY = dict(pal={"a": "#f6d48a", "h": "#2a3a8a", "e": "#5a3a22", "p": "#f29a8a", "o": "#d0503a", "w": "#f0a030", "r": "#3a78c8"}, idle='''
.....hh.....
....hhhh....
..aaaaaaaa..
.aaaaaaaaaa.
.aaeaaaaeaa.
.aeaeaaeaea.
.apaaaaaapa.
..aaaooaaa..
...aaaaaa...
..wwrrrrww..
..wwwwwwww..
...ww..ww...''', blink='''
.....hh.....
....hhhh....
..aaaaaaaa..
.aaaaaaaaaa.
.aaeaaaaeaa.
.aeaeaaeaea.
.apaaaaaapa.
..aaaooaaa..
...aaaaaa...
..wwrrrrww..
..wwwwwwww..
...ww..ww...''', step_tail='''
..ww....ww..''', sleep='''
.....hh.....
....hhhh....
..aaaaaaaa..
.aaaaaaaaaa.
.akkaaaakka.
.apaaaaaapa.
..aaaooaaa..
...aaaaaa...
.wwwwrrwwww.''')
FEAST_MASK_ADULT = dict(pal={"a": "#f6d48a", "h": "#2a3a8a", "e": "#5a3a22", "p": "#f29a8a", "o": "#d0503a", "w": "#f0a030", "r": "#3a78c8"}, idle='''
......hh......
.....hhhh.....
...aaaaaaaa...
..aaaaaaaaaa..
.aaaaaaaaaaaa.
.aaaeaaaaeaaa.
.aaeaeaaeaeaa.
.apaaaaaaaapa.
..aaaaooaaaa..
...aaaaaaaa...
..wwwrrrrwww..
.wwwwwrrwwwww.
..wwwwwwwwww..
...ww....ww...''', blink='''
......hh......
.....hhhh.....
...aaaaaaaa...
..aaaaaaaaaa..
.aaaaaaaaaaaa.
.aaaeaaaaeaaa.
.aaeaeaaeaeaa.
.apaaaaaaaapa.
..aaaaooaaaa..
...aaaaaaaa...
..wwwrrrrwww..
.wwwwwrrwwwww.
..wwwwwwwwww..
...ww....ww...''', step_tail='''
..ww......ww..''', sleep='''
......hh......
.....hhhh.....
...aaaaaaaa...
..aaaaaaaaaa..
.aaaaaaaaaaaa.
.aakkaaaakkaa.
.apaaaaaaaapa.
..aaaaooaaaa..
...aaaaaaaa...
.wwwwwrrwwwww.
.wwwwwwwwwwww.''')
skin(key='feast_mask', pet='mask_spirit', name='잔치 탈 정령',
    desc='달맞이성 잔치 행렬에서 쓰는 금빛 탈에 깃든 정령입니다. 주황 옷에 쪽빛 띠를 매고, 북소리가 나면 어깨를 들썩입니다.',
    baby=FEAST_MASK_BABY, adult=FEAST_MASK_ADULT)

GOLDEN_MOON_RABBIT_BABY = dict(pal={"a": "#f8e2a8", "c": "#e0b860", "p": "#f2a8bc", "y": "#e8443a", "n": "#b07a42", "r": "#fbf8ee", "g": "#7ab060", "e": "#2a2a4a", "i": "#8a8ab0"}, lid='a', idle='''
.....aa.aa..
.....pa.pa..
.....pa.pa..
....aaayaaa.
....aieaiea.
....aeeaeea.
....paanaap.
.....caaarrg
..ccaaaaaa..
....aaa.aaa.''', step_tail='''
..ccaaaaaa..
...aaa...aa.''', sleep='''
....aaaa....
...apppaaa..
....aaayaaa.
....akkakka.
....paanaap.
..cccaaaarrg
.ccaaaaaaaa.''')
GOLDEN_MOON_RABBIT_ADULT = dict(pal={"a": "#f8e2a8", "c": "#e0b860", "p": "#f2a8bc", "y": "#e8443a", "n": "#b07a42", "r": "#fbf8ee", "g": "#7ab060", "e": "#2a2a4a", "i": "#8a8ab0"}, lid='a', idle='''
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
...aaa.aaann..''', step='''
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
..aaa...aann..''', sleep='''
.....aaaa.....
....apppaaa...
....aaaayaa...
....akkakka...
....paanaap...
.cc.caaaaaa...
.ccaaaaaaaaa..
..aaaaaaaaaann''')
skin(key='golden_moon_rabbit', pet='moon_rabbit', name='금빛 달맞이 토끼',
    desc='달맞이성 궁궐 지붕에서 달을 맞는 토끼입니다. 금빛 털에 이마의 점은 붉은 보석처럼 빛납니다.',
    baby=GOLDEN_MOON_RABBIT_BABY, adult=GOLDEN_MOON_RABBIT_ADULT)

PASS_GLIDER_BABY = dict(pal={"a": "#f6f4ee", "d": "#5a6a8a", "c": "#c8d4e8", "n": "#e8909a", "e": "#0c0806", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
....dd...dd
....daaaaad
....dieaied
dd..deeaeed
ada.paanaap
.aad.aaaa..
..dddddaaa.
.caaaaaaaac
..a.a..a.a.''', step_tail='''
...aa..aa..''', sleep='''
....dd...dd
....daaaaad
....dkkakkd
dd..paanaap
adaddddaaa.
.aaaaaaaaac''')
PASS_GLIDER_ADULT = dict(pal={"a": "#f6f4ee", "d": "#5a6a8a", "c": "#c8d4e8", "n": "#e8909a", "e": "#0c0806", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
........dd...dd
........daaaaad
........dieaied
.dd.....deeaeed
dadd....paanaap
daad.....aaaa..
.daad.dddddaaa.
..ddaaaaaaaaaaa
...caaaaaaaaaac
...cc.aa..aa.cc''', step_tail='''
...cc..aa.aa.cc''', sleep='''
........dd...dd
........daaaaad
........dkkakkd
.dd.....paanaap
dadd.ddddddaaa.
daadaaaaaaaaaaa
.dddcaaaaaaaaac''')
skin(key='pass_glider', pet='spotted_glider', name='구름 고개 하늘다람쥐',
    desc='눈마루 높은 고개를 구름 타듯 건너는 하늘다람쥐입니다. 검던 무늬가 하늘빛 도는 잿빛으로 바뀌었습니다.',
    baby=PASS_GLIDER_BABY, adult=PASS_GLIDER_ADULT)

EMBER_FROG_BABY = dict(pal={"a": "#f07a28", "b": "#2a2026", "c": "#ffe0a0", "r": "#d83a2a", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
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
aaaaaaacccca''')
EMBER_FROG_ADULT = dict(pal={"a": "#f07a28", "b": "#2a2026", "c": "#ffe0a0", "r": "#d83a2a", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
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
aaaaaaaaacccccca''')
skin(key='ember_frog', pet='tree_frog', name='불씨 개구리',
    desc='불씨들녘 붉은 수액 밀림 잎 위에 앉는 개구리입니다. 주황 몸에 숯 같은 검은 점이 박혀, 불씨가 앉은 것처럼 보입니다.',
    baby=EMBER_FROG_BABY, adult=EMBER_FROG_ADULT)

LOTUSLEAF_NEWT_BABY = dict(pal={"a": "#4a9a68", "b": "#2a6a44", "y": "#f4a0b8", "c": "#7ab88a", "e": "#2a1a14", "i": "#f0e8c0", "p": "#f3a0a0"}, idle='''
...........aa.
......yaaaaaie
yy.aayaaayaaaa
.aaaaaaayaaaap
...aa..aa..aa.''', step_tail='''
....aa..aa.aa.''', sleep='''
..........aaa.
yy.aayaaaaakka
.aaaaaayaayaap
...aaaaaaaaaa.''')
LOTUSLEAF_NEWT_ADULT = dict(pal={"a": "#4a9a68", "b": "#2a6a44", "y": "#f4a0b8", "c": "#7ab88a", "e": "#2a1a14", "i": "#f0e8c0", "p": "#f3a0a0"}, idle='''
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
....aaaaaaaaaaaaaa.''')
skin(key='lotusleaf_newt', pet='baby_salamander', name='연잎 도롱뇽',
    desc='해오름성 연못 연잎 밑에 숨어 사는 아기 도롱뇽입니다. 연잎 빛 몸에 분홍 점이 꽃잎처럼 떨어져 있습니다.',
    baby=LOTUSLEAF_NEWT_BABY, adult=LOTUSLEAF_NEWT_ADULT)

INKRAIN_FIREFLY_BABY = dict(pal={"a": "#34343c", "n": "#4a4a54", "c": "#f2e8c8", "w": "#d0e0da", "g": "#7ae0b0", "h": "#e0fff0", "s": "#b0ffd8", "e": "#2a1a14", "i": "#8a8070", "p": "#f3a0a0"}, lid='c', noline='s', idle='''
..s....h...h
..ww....n.n.
.wwww.ccccc.
wwwwwcieciec
.wwwwceeceec
.ghaapcccccp
ghhgaa.ccc..
ghhg..n..n..
.gg.s.......''', step='''
.......h...h
www.....n.n.
wwww..ccccc.
.wwwwcieciec
..wwwceeceec
.ghaapcccccp
ghhgaa.ccc..
ghhg..n..n..
.ggs........''', sleep='''
.......h...h
..www...n.n.
.wwwwwccccc.
gggwwckkckkc
ghhggpcccccp
.ggg..ccc...''')
INKRAIN_FIREFLY_ADULT = dict(pal={"a": "#34343c", "n": "#4a4a54", "c": "#f2e8c8", "w": "#d0e0da", "g": "#7ae0b0", "h": "#e0fff0", "s": "#b0ffd8", "e": "#2a1a14", "i": "#8a8070", "p": "#f3a0a0"}, lid='c', noline='s', idle='''
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
..ggg...s......''', step='''
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
s.ggg..........''', sleep='''
.........h...h.
..........n.n..
..www....ccccc.
.wwwwww.ccccccc
.ggwwwwwckkckkc
gghhhgaapcccccp
ghhhhhgaaccccc.
.ghhhhg........
..gggg.........''')
skin(key='inkrain_firefly', pet='firefly_spirit', name='먹비 반딧불',
    desc='잿빛그늘숲 먹비 속에서도 꺼지지 않는 반딧불 정령입니다. 몸은 먹빛이고 꽁무니 불은 박하잎처럼 서늘한 빛입니다.',
    baby=INKRAIN_FIREFLY_BABY, adult=INKRAIN_FIREFLY_ADULT)

OBSIDIAN_BEETLE_BABY = dict(pal={"a": "#463e56", "h": "#ff7a3a", "n": "#1e1a22", "i": "#f0e0c0", "e": "#2a1a14", "p": "#f3a0a0"}, lid='n', idle='''
.........nn..
..........nn.
...aaaaa.nn..
..aahhaaannn.
.aahaaaaanin.
.aaaaaaaannnn
..aaaaaaa.n..
..n.n..n.n...''', step_tail='''
...n.n.n..n..''', sleep='''
.........nn..
..........nn.
...aaaaa.nn..
..aahhaaannn.
.aahaaaaannnn
.aaaaaaaannnn
.nnnnnnnn....''')
OBSIDIAN_BEETLE_ADULT = dict(pal={"a": "#463e56", "h": "#ff7a3a", "n": "#1e1a22", "i": "#f0e0c0", "e": "#2a1a14", "p": "#f3a0a0"}, lid='n', idle='''
............nn...
.............nn..
.............nn..
....aaaaaa..nnn..
..aaahhhaaa.nnnn.
.aaahhaaaaaanninn
.aaaahaaaaaaannnn
.aaaaaaaaaaaannn.
..aaaaaaaaaa.nn..
...aaaaaaaa......
...n.n...n..n....
..n..n...n...n...''', step_tail='''
....n.n..n.n.....
...n...n..n..n...''', sleep='''
............nn...
.............nn..
....aaaaaa..nnn..
..aaahhhaaa.nnnn.
.aaahhaaaaaannnnn
.aaaahaaaaaaannnn
.aaaaaaaaaaaannn.
.nnnnnnnnnnnnn...''')
skin(key='obsidian_beetle', pet='rhino_beetle', name='흑요 장수풍뎅이',
    desc='불씨들녘 검은 화산 해안에서 자란 장수풍뎅이입니다. 등딱지가 흑요석처럼 반들거리고, 볕을 받으면 용암빛 줄이 비칩니다.',
    baby=OBSIDIAN_BEETLE_BABY, adult=OBSIDIAN_BEETLE_ADULT)

REDSAP_BOAR_BABY = dict(pal={"a": "#b0502e", "c": "#f0b080", "d": "#7a2a18", "n": "#4a2c1a", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
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
.aaaaaaaaaaaaa.''')
REDSAP_BOAR_ADULT = dict(pal={"a": "#8a3a24", "c": "#c06040", "d": "#5a2014", "n": "#2a1a10", "t": "#f0e8d4", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
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
.ddddddddddddd..''')
skin(key='redsap_boar', pet='baby_boar', name='붉은 수액 멧돼지',
    desc='불씨들녘 붉은 수액 밀림에서 수액을 핥다 털이 붉어진 멧돼지입니다. 코끝이 늘 끈적해서 아무 데나 코를 박고 다닙니다.',
    baby=REDSAP_BOAR_BABY, adult=REDSAP_BOAR_ADULT)

MONSOON_CLOUD_BABY = dict(pal={"a": "#b0cade", "b": "#6a8aa8", "y": "#3a86d0", "w": "#c8e4f8", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
....aaa.....
..aaaaaaa...
.aaaaaaaaaa.
aaaieaaieaaa
aapaaaaaapaa
.bbbbbbbbbb.
...y...y....
..y...y.....''', step_tail='''
....y...y...
...y...y....''', sleep='''
....aaa.....
..aaaaaaa...
.aaaaaaaaaa.
aaakkaakkaaa
aapaaaaaapaa
.bbbbbbbbbb.''')
MONSOON_CLOUD_ADULT = dict(pal={"a": "#b0cade", "b": "#6a8aa8", "y": "#3a86d0", "w": "#c8e4f8", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
......aaaa......
...aaaaaaaaa....
..aaaaaaaaaaaa..
.aaaaaaaaaaaaaa.
aaaaieaaaaieaaaa
aaapaaaaaaaapaaa
.aaaaaaaaaaaaaa.
..bbbbbbbbbbbb..
....yw....yw....
...yy....yy.....
....y.....y.....''', step_tail='''
.....yw....yw...
....yy....yy....
.....y.....y....''', sleep='''
......aaaa......
...aaaaaaaaa....
..aaaaaaaaaaaa..
.aaaaaaaaaaaaaa.
aaaakkaaaakkaaaa
aaapaaaaaaaapaaa
.aaaaaaaaaaaaaa.
..bbbbbbbbbbbb..''')
skin(key='monsoon_cloud', pet='thunder_cloud', name='큰비 꼬마 구름',
    desc='파도너울성에 큰비 철을 몰고 오는 꼬마 구름입니다. 번개 대신 굵은 빗방울을 떨구고, 수상 가옥 지붕 위를 맴돌기를 좋아합니다.',
    baby=MONSOON_CLOUD_BABY, adult=MONSOON_CLOUD_ADULT)

JADE_WHALE_BABY = dict(pal={"a": "#2a9a98", "b": "#1a6a6a", "c": "#f6e8cc", "w": "#cfe8f6", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
.........w.w..
..........w...
b......aaaaa..
bb...aaaaaaaa.
.baaaaaaaaieaa
.aaaaaaaaaapaa
..aacccccccca.
....ccccccc...''', step_tail='''
..aacccccccca.
...cccccccc...''', sleep='''
b......aaaaa..
bb...aaaaaaaa.
.baaaaaaaakkaa
.aaaaaaaaaapaa
..aacccccccca.
...cccccccc...''')
JADE_WHALE_ADULT = dict(pal={"a": "#2a9a98", "b": "#1a6a6a", "c": "#f6e8cc", "w": "#cfe8f6", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0"}, idle='''
.............w..w..
..............ww...
...............w...
b..........aaaaaa..
bb.......aaaaaaaaa.
.bb...aaaaaaaaaaaaa
..baaaaaaaaaaaaieaa
..aaaaaaaaaaaaapaaa
...aaaccccccccccaa.
....aaccccccccccc..
......cccccccccc...''', step_tail='''
...aaaccccccccccaa.
...aaccccccccccc...
.....cccccccccc....''', sleep='''
b..........aaaaaa..
bb.......aaaaaaaaa.
.bb...aaaaaaaaaaaaa
..baaaaaaaaaaaakkaa
..aaaaaaaaaaaaapaaa
...aaaccccccccccaa.
....aaccccccccccc..
......cccccccccc...''')
skin(key='jade_whale', pet='baby_whale', name='옥빛 아기 고래',
    desc='파도너울성 앞바다 얕은 산호밭에서 노는 아기 고래입니다. 몸이 옥빛이라 물 위로 뛰어오르면 물보라와 구분이 안 됩니다.',
    baby=JADE_WHALE_BABY, adult=JADE_WHALE_ADULT)

BARLEY_BEAR_BABY = dict(pal={"a": "#dcbc8c", "h": "#b08a58", "s": "#8a6a40", "n": "#2a2428", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "r": "#d8443a", "y": "#f2c94c"}, idle='''
....hhrrrhh.
....hhyyyhh.
....aaaaaaa.
....aieaiea.
.h..aeeaeea.
hh.aaaanaaap
.haaaaaaaaa.
.aaaaaaaaaa.
.aa.aa.aa.aa''', step_tail='''
..aa.aa.aa.a''', sleep='''
....hhrrrhh.
....hhyyyhh.
....aakkakka
hh.aaaanaaap
.aaaaaaaaaa.
aaaaaaaaaaa.
.hhhhhhhhhh.''')
BARLEY_BEAR_ADULT = dict(pal={"a": "#dcbc8c", "h": "#b08a58", "s": "#8a6a40", "n": "#2a2428", "e": "#2a1a14", "i": "#ffffff", "p": "#f3a0a0", "r": "#d8443a", "y": "#f2c94c"}, idle='''
.......hhrrrrhh.
.......hhyyyyhh.
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
.......hhrrrrhh.
.......hhyyyyhh.
.......aakkaakka
..h...aaaanaaap.
.hhaaaaaaaaaaaa.
.aaaaaaaaaaaaaa.
aaaaaaaaaaaaaaa.
.hhhhhhhhhhhhhh.''')
skin(key='barley_bear', pet='baby_white_bear', name='털모자 보릿빛 곰',
    desc='눈마루 고원에서 볶은 보릿가루를 얻어먹고 자란 아기 곰입니다. 털은 보릿빛이고, 장날 받은 붉은 털모자를 벗지 않습니다.',
    baby=BARLEY_BEAR_BABY, adult=BARLEY_BEAR_ADULT)

