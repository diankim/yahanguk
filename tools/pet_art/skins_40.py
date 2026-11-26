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

