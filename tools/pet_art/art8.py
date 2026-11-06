CRAB2 = {'a': '#e8553a', 'b': '#b03a24', 'c': '#f2805e', 'e': E, 'i': I, 'p': PK}
pet(id='baby_crab', name='아기 게', grade=1, kind='shell', likes='treat_fish',
    desc='등딱지가 손바닥만 한 갯벌의 아기 게입니다. 집게발 두 개를 번쩍 들고 옆으로만 걸어가, 앞으로 오라고 부르면 늘 비스듬히 다가옵니다. 놀라면 집게를 딱딱 부딪쳐 제법 사나운 척을 합니다.',
    baby=dict(pal=CRAB2, idle='''
..ie....ie..
..aa....aa..
cc.aaaaaa.cc
cbaaaaaaaabc
.capaaaapac.
..aaaaaaaa..
..b.b..b.b..''', step_tail='''
...b.b..b.b.''', sleep='''
..kk....kk..
cc.aaaaaa.cc
cbaaaaaaaabc
.capaaaapac.
.bbbbbbbbbb.'''),
    adult=dict(pal=CRAB2, idle='''
...ie......ie...
...aa......aa...
ccc.aaaaaaaa.ccc
cbcaaaaaaaaaacbc
.ccaaaaaaaaaacc.
..apaaaaaaaapa..
...aaaaaaaaaa...
..b.b.b..b.b.b..
.b..b......b..b.''', step_tail='''
.b.b.b....b.b.b.
..b..b....b..b..''', sleep='''
...kk......kk...
ccc.aaaaaaaa.ccc
cbcaaaaaaaaaacbc
.ccaaaaaaaaaacc.
..apaaaaaaaapa..
.bbbbbbbbbbbbbb.'''))

PILL = {'a': '#8e939c', 'b': '#686d77', 'n': '#4a4e56', 'e': E, 'i': I, 'p': PK}
pet(id='pill_bug', name='아기 공벌레', grade=2, kind='shell', likes='treat_herb',
    desc='돌 밑 축축한 그늘에 사는 작은 쥐며느리입니다. 손끝으로 살짝 건드리면 몸을 동그랗게 말아 구슬처럼 굴러가 버립니다. 한참 지나 아무도 없다 싶으면 슬그머니 몸을 펴고 더듬이부터 내밉니다.',
    baby=dict(pal=PILL, idle='''
....ababa...n
..abababab.n.
.ababababaaa.
abababababaie
.ababababapa.
..n.n.n.n.n..''', step_tail='''
.n.n.n.n.n...''', sleep='''
...abab...
.abababab.
ababababab
bababababa
.bababab..'''),
    adult=dict(pal=PILL, idle='''
.......ababa....n
....ababababab.n.
..abababababaaa..
.ababababababaaie
abababababababpa.
.ababababababaaa.
..n.n.n.n.n.n.n..''', step_tail='''
.n.n.n.n.n.n.n...''', sleep='''
...ababab...
.abababababa
abababababab
babababababa
.bababababa.
..bbbbbbbb..'''))

HELM = {'a': '#a3adb8', 'b': '#66707c', 'r': '#c8402e', 'd': '#26222c', 'e': '#ffd46a', 'i': '#fff6d0'}
pet(id='empty_helm', name='빈 투구 정령', grade=3, kind='shell', likes='treat_rice',
    desc='주인을 잃고 오래 버려져 있던 낡은 투구에 깃든 넋입니다. 투구 속 어둠에서 두 눈만 반짝이고, 꼭대기 붉은 술이 기분 따라 흔들립니다. 누가 머리에 써 주면 그날 하루는 그 사람을 꼭 지키려 듭니다.',
    lid='d',
    baby=dict(pal=HELM, idle='''
.....r.....
....rrr....
.....a.....
...aaaaa...
..abbbbba..
.aaaaaaaaa.
.addddddda.
..dieddie..
.bd.....db.''', step_tail='''
..bd...db..''', sleep='''
....rrr....
...aaaaa...
..abbbbba..
.aaaaaaaaa.
.addddddda.
..dkkddkkd.
.bbbbbbbbb.'''),
    adult=dict(pal=HELM, idle='''
......rr......
.....rrrr.....
......aa......
....aaaaaa....
...abbbbbba...
..abaaaaaaba..
.aaaaaaaaaaaa.
.adddddddddda.
..ddieddiedd..
.bdd......ddb.''', step_tail='''
..bdd....ddb..''', sleep='''
.....rrrr.....
....aaaaaa....
...abbbbbba...
..abaaaaaaba..
.aaaaaaaaaaaa.
.adddddddddda.
..ddkkddkkdd..
.bbbbbbbbbbbb.'''))

SHROOM = {'a': '#a0449c', 'b': '#6e2a70', 'w': '#f4ecd8', 's': '#efe2c4', 't': '#cbb894', 'e': E, 'i': I, 'p': PK}
pet(id='poison_mushroom', name='꼬마 독버섯', grade=1, kind='venom', likes='treat_herb',
    desc='보랏빛 갓에 흰 점이 박힌, 먹으면 큰일 나는 버섯에 깃든 정령입니다. 저도 그걸 알아서 누가 다가오면 갓을 흔들며 먹지 말라고 손사래를 칩니다. 비 온 다음 날이면 키가 한 뼘쯤 자라 있습니다.',
    lid='s',
    baby=dict(pal=SHROOM, idle='''
...aaaaa...
..awaaawa..
.aaaawaaaa.
abaaaaaawab
.bbbbbbbbb.
...sssss...
...ieies...
...psssp...
...sssss...
....t.t....''', step_tail='''
...t...t...''', sleep='''
...aaaaa...
..awaaawa..
.aaaawaaaa.
abaaaaaawab
.bbbbbbbbb.
...kkkks...
...psssp...
..ttttttt..'''),
    adult=dict(pal=SHROOM, idle='''
....aaaaaa....
..aawaaaawaa..
.aaaaaawaaaaa.
aawaaaaaaaawaa
abaaawaaaaaaab
.bbbbbbbbbbbb.
....ssssss....
....ieiess....
....pssssp....
....ssssss....
....ssssss....
.....t..t.....''', step_tail='''
....t....t....''', sleep='''
....aaaaaa....
..aawaaaawaa..
.aaaaaawaaaaa.
aawaaaaaaaawaa
abaaawaaaaaaab
.bbbbbbbbbbbb.
....kkkkss....
....pssssp....
...tttttttt...'''))

CROC = {'a': '#5a8a3c', 'b': '#3e6a2a', 'c': '#c8d690', 'w': '#f4f0e6', 'e': E, 'i': I}
pet(id='baby_croc', name='새끼 악어', grade=2, kind='venom', likes='treat_meat',
    desc='알에서 나온 지 얼마 안 된 새끼 악어입니다. 이빨이 벌써 삐죽 나와 있지만, 무는 시늉만 하고 정작 물지는 못합니다. 햇볕 좋은 날이면 입을 쩍 벌린 채로 한나절을 꼼짝 않고 볕을 쬡니다.',
    baby=dict(pal=CROC, idle='''
..........aie...
.b.b.b..aaaaaaaa
bbaaaaaaaaaaawaw
..aaccccccaaaaa.
...a.a....a.a...''', step_tail='''
....a.a..a.a....''', sleep='''
..........akk...
.b.b.b..aaaaaaaa
bbaaaaaaaaaaaaaa
..aacccccccaaaa.
..aaaaaaaaaaa...'''),
    adult=dict(pal=CROC, idle='''
.............aaie...
..b.b.b.b...aaaaaaa.
bbbaaaaaaaaaaaaaaaaa
...aaaaaaaaaaaawawaw
...accccccccccaaaaa.
....aa.aa....aa.aa..''', step_tail='''
.....aa.aa..aa.aa...''', sleep='''
.............aakk...
..b.b.b.b...aaaaaaa.
bbbaaaaaaaaaaaaaaaaa
...accccccccccaaaaa.
...aaaaaaaaaaaaaaa..'''))

SCORP = {'a': '#c88a3a', 'b': '#8e5a22', 'c': '#d89e54', 's': '#a63c9c', 'e': E, 'i': I, 'p': PK}
pet(id='baby_scorpion', name='아기 전갈', grade=3, kind='venom', likes='treat_meat',
    desc='모래빛 껍질을 두른 아기 전갈입니다. 꼬리 끝 독침을 늘 하늘 높이 치켜들고 다니지만, 아직 독이 차지 않아 찔려도 간지러울 뿐입니다. 집게로 무언가를 꼭 쥐고 있어야 마음을 놓습니다.',
    baby=dict(pal=SCORP, idle='''
...bbbb........
..b....s.......
..a............
..a............
..a.......c.c..
..aaaaaaa..cc..
.aaaaaaaaaiea..
..aaaaaaaapa...
..b.b.b.b......''', step_tail='''
...b.b.b.b.....''', sleep='''
..........c.c..
.saaaaaaa..cc..
aaaaaaaaaakka..
..aaaaaaaapa...
..bbbbbbbb.....'''),
    adult=dict(pal=SCORP, idle='''
....bbbbb........
...b.....b.......
..b.......s......
..a..............
..a..............
..a.........c..c.
..aaaaaaaaa..ccc.
.aaaaaaaaaaaiea..
.aaaaaaaaaaapa...
..aaaaaaaaaa.....
..b.b.b.b.b......''', step_tail='''
...b.b.b.b.b.....''', sleep='''
............c..c.
..saaaaaaaa..ccc.
.aaaaaaaaaaakka..
.aaaaaaaaaaapa...
..bbbbbbbbbb.....'''))

DRAGON = {'a': '#d84a30', 'b': '#a83420', 'w': '#e2f0f8', 'v': '#b4d0e2', 'e': E, 'i': I}
pet(id='dragonfly', name='잠자리', grade=1, kind='swarm', likes='treat_honey',
    desc='가을 들판을 맴도는 빨간 고추잠자리입니다. 손가락을 세우고 가만히 있으면 슬그머니 내려앉아 커다란 눈으로 이리저리 살핍니다. 빙글빙글 원을 그리면 따라 돌다가 어지러운지 금세 날아가 버립니다.',
    baby=dict(pal=DRAGON, idle='''
....ww.ww.....
...wwvwwvw....
aaaaaaaaaaaie.
...wwvwwvw.a..
....ww.ww.....''', step_tail='''
...wwvwwvw....
..............''', sleep='''
...wwwwww.....
aaaaaaaaaaakk.
...wwwwww.a...'''),
    adult=dict(pal=DRAGON, idle='''
.....www..www.....
....wwvww.wwvww...
...wwwvwwwwwvww...
aaaaaaaaaaaaaaaie.
...wwwvwwwwwvww.a.
....wwvww.wwvww...
.....www..www.....''', step_tail='''
....wwvwwwwvww....
..................
..................''', sleep='''
...wwwwwwwwww.....
aaaaaaaaaaaaaaakk.
...wwwwwwwwww.a...'''))

MANTIS = {'a': '#7ab848', 'b': '#5a9032', 'c': '#c4e08c', 'e': E, 'i': I}
pet(id='mantis', name='꼬마 사마귀', grade=2, kind='swarm', likes='treat_meat',
    desc='풀잎 색 몸에 세모난 머리를 얹은 꼬마 사마귀입니다. 앞발을 가지런히 모으고 있는 모습이 꼭 절을 하는 것 같지만, 실은 날벌레가 지나가기만 기다리는 중입니다. 고개를 갸웃 돌려 뒤를 돌아볼 줄 압니다.',
    baby=dict(pal=MANTIS, idle='''
.......aa..
......aiea.
.......aa..
......bb...
.....bab...
..aaaaab...
aaaaaaa.b..
..b.b..b...''', step_tail='''
...b.b.b...''', sleep='''
.......aa..
......akka.
.......aa..
..aaaaabb..
aaaaaaab...
.bbbbbbb...'''),
    adult=dict(pal=MANTIS, idle='''
.........aaa..
........aaiea.
.........aaa..
........bb....
.......bab.b..
......bab..b..
...aaaaab.....
.aaaaaaaa.....
aaaaaaaa.b....
..b.b.b..b....''', step_tail='''
...b.b.b.b....''', sleep='''
.........aaa..
........aakka.
.........aaa..
...aaaaabbb...
.aaaaaaaab....
aaaaaaaab.....
.bbbbbbbb.....'''))

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

DOKK = {'a': '#e08a5a', 'b': '#b0603a', 'h': '#f2e6c8', 'd': '#3a2a24', 'm': '#8a5a32', 'n': '#5a3a22', 'w': '#ffffff', 'e': E, 'i': I, 'p': PK}
pet(id='little_dokkaebi', name='꼬마 도깨비', grade=2, kind='mirror', likes='treat_rice',
    desc='뿔 하나에 제 키만 한 방망이를 질질 끌고 다니는 꼬마 도깨비입니다. 씨름을 걸어 와서 일부러 져 주면 몹시 좋아하고, 이기면 분해서 밤새 다시 하자고 조릅니다. 메밀묵 냄새만 맡으면 어디선가 불쑥 나타납니다.',
    baby=dict(pal=DOKK, idle='''
.....h......
....dhdd....
...daaaad...
...aieiea...
...apwwpa.m.
....aaaa.mm.
...baaaabmn.
...aaaaaa.m.
...b....b...''', step_tail='''
....b..b....''', sleep='''
.....h......
....dhdd....
...daaaad...
...akkkka...
...apwwpa...
...baaaabmmm
...bbbbbbmnm'''),
    adult=dict(pal=DOKK, idle='''
.......h.......
......hh.......
.....dhddd.....
....dddddd.....
....daaaaad....
....aieaiea..m.
....aapwwpa.mmm
.....aaaaa..mnm
....baaaaab.mmm
...b.aaaaa.bm..
.....aaaaa..m..
.....b...b.....''', step_tail='''
......b.b......''', sleep='''
.......h.......
......hh.......
.....dhddd.....
....dddddd.....
....daaaaad....
....akkakka....
....aapwwpa....
....baaaaab.mmm
...b.aaaaa.bmnm
.....bbbbb..mmm'''))

MASK = {'a': '#efd9a8', 'b': '#c8a874', 'd': '#5a3a22', 'r': '#c8402e', 'o': '#e0a06a', 'e': '#3a2418', 'i': '#8a6040', 'p': '#f09a8a'}
pet(id='mask_spirit', name='꼬마 탈 정령', grade=3, kind='mirror', likes='treat_rice',
    desc='마을 굿판에서 쓰던 탈에 깃든 장난꾸러기 정령입니다. 웃는 탈로 웃다가도 눈 깜짝할 새 성난 얼굴, 우는 얼굴로 표정을 바꿔 가며 사람을 놀립니다. 풍물 소리가 들리면 턱을 덜컥거리며 어깨춤을 춥니다.',
    lid='a', eyes='e',
    baby=dict(pal=MASK, idle='''
...aaaaa...
..aaaaaaa..
.addaaadda.
.aeeaaaeea.
.apaaaaapa.
.aaabbbaaa.
..aaoooaa..
...aaaaa...
....rrr....
...r.r.r...''', step_tail='''
....r.r.r..''', sleep='''
...aaaaa...
..aaaaaaa..
.addaaadda.
.abbaaabba.
.apaaaaapa.
.aaaoooaaa.
..aaaaaaa..
...rrrrr...'''),
    adult=dict(pal=MASK, idle='''
....aaaaaa....
..aaaaaaaaaa..
.aaaaaaaaaaaa.
.adddaaaaddda.
.aaeeaaaaeeaa.
.apaaaabaaapa.
.aaaaaabaaaaa.
.aaabbbbbbaaa.
..aaaoooooaa..
...aaaaaaaa...
.....rrrr.....
....r.rr.r....
...r..r...r...''', step_tail='''
....r..r..r...
.....r..r.....''', sleep='''
....aaaaaa....
..aaaaaaaaaa..
.aaaaaaaaaaaa.
.adddaaaaddda.
.aabbaaaabbaa.
.apaaaabaaapa.
.aaaaaaaaaaaa.
..aaaoooooaa..
...aaaaaaaa...
....rrrrrr....'''))

OX = {'a': '#b87a3e', 'b': '#8a5428', 'c': '#e6c89a', 'h': '#f2e6c8', 'n': '#e8a0a0', 'e': E, 'i': I}
pet(id='ox_calf', name='새끼 황소', grade=1, kind='breaker', likes='treat_herb',
    desc='뿔이 이제 막 돋기 시작한 누런 송아지입니다. 머리를 앞으로 숙이고 무엇이든 들이받아 보는 게 요즘 제일 재미있는 일입니다. 쓰다듬어 주면 꼬리를 휙휙 내젓고 음매 하고 길게 웁니다.',
    baby=dict(pal=OX, idle='''
.........h.h.
.........aaaa
b.aaaaaaaaiea
.aaaaaaaaaacc
.aaaaaaaaaanc
..aa.aa..aa..''', step_tail='''
...aa.aa.aa..''', sleep='''
.........h.h.
.........aaaa
b.aaaaaaaakka
.aaaaaaaaaacc
.bbbbbbbbbbnc'''),
    adult=dict(pal=OX, idle='''
............h..h.
............haah.
...........aaaaaa
b..aaaaaaaaaaieaa
.baaaaaaaaaaaaccc
..aaaaaaaaaaaancc
..aaaaaaaaaaaa...
..aa.aa...aa.aa..
..bb.bb...bb.bb..''', step_tail='''
...aa.aa..aa.aa..
...bb.bb..bb.bb..''', sleep='''
............h..h.
............haah.
...........aaaaaa
b..aaaaaaaaaakkaa
.baaaaaaaaaaaaccc
..aaaaaaaaaaaancc
..bbbbbbbbbbbbb..'''))

JANG = {'a': '#7a4428', 'b': '#4a2614', 'c': '#a8643c', 'l': '#b07a4a', 'm': '#8a5a34', 'y': '#e8c88a', 'd': '#140c08', 'e': '#ffe08a', 'i': '#ffffff'}
pet(id='cracked_jar', name='금 간 장독 정령', grade=1, kind='breaker', likes='treat_rice',
    desc='장독대 맨 끝자리를 지키던 오래된 장독에 깃든 정령입니다. 몸에 금이 갔어도 깨지지 않고 버티는 것이 자랑이라, 누가 두드려 보면 일부러 더 크게 둥 하고 울립니다. 뚜껑과 독 사이 틈으로 두 눈이 반짝 빛나며 바깥을 내다봅니다.',
    lid='d',
    baby=dict(pal=JANG, idle='''
....ll....
..llllll..
.mmmmmmmm.
.ddieieddd
.aaaaaaaa.
aaacaaayaa
aacaaayaaa
aacaaaayaa
.aaaaaaaa.
..bbbbbb..''', step_tail='''
...bbbbbb.''', sleep='''
....ll....
..llllll..
.mmmmmmmm.
.dddddddd.
.aaaaaaaa.
aacaaayaaa
aacaaaayaa
.bbbbbbbb.'''),
    adult=dict(pal=JANG, idle='''
......lll.....
...llllllll...
..llllllllll..
.mmmmmmmmmmmm.
.dddieddieddd.
.aaaaaaaaaaaa.
aaacaaaaayaaaa
aacaaaaaayaaaa
aacaaaaaaayaaa
aacaaaaayyaaaa
.aaaaaaaaaaaa.
..aaaaaaaaaa..
...bbbbbbbb...''', step_tail='''
....bbbbbbbb..''', sleep='''
......lll.....
...llllllll...
..llllllllll..
.mmmmmmmmmmmm.
.dddddddddddd.
.aaaaaaaaaaaa.
aacaaaaaayaaaa
aacaaaaaaayaaa
.aaaaaaaaaaaa.
..bbbbbbbbbb..'''))

CLOUD = {'a': '#e6eaf2', 'b': '#b4bccc', 'y': '#f6d040', 'w': '#fff8d8', 'e': E, 'i': I, 'p': PK}
pet(id='thunder_cloud', name='꼬마 벼락구름', grade=2, kind='breaker', likes='treat_honey',
    desc='산마루에서 떨어져 나온 손바닥만 한 먹구름입니다. 신이 나거나 심통이 나면 몸 아래로 작은 번개를 찌릿찌릿 튀기고, 그 기운으로 이것저것 들이받으며 돌아다닙니다. 울고 나면 보슬비가 조금 내리고 금세 개운해집니다.',
    baby=dict(pal=CLOUD, idle='''
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
.bbbbbbbbbb.'''),
    adult=dict(pal=CLOUD, idle='''
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
..bbbbbbbbbbbb..'''))

EGG = {'a': '#f6f2ea', 'b': '#d8d0c4', 'c': '#ece6da', 'e': E, 'i': I, 'p': PK}
pet(id='egg_ghost', name='아기 달걀귀신', grade=2, kind='ghost', likes='treat_rice',
    desc='눈도 코도 입도 없다는 달걀귀신의 아기입니다. 아직 어려서 얼굴이 다 지워지지 않아 동그란 눈 두 개가 남아 있습니다. 매끈한 머리를 쓰다듬어 주면 데굴데굴 굴러 다니며 좋아하고, 놀래려다 오히려 제가 더 놀랍니다.',
    baby=dict(pal=EGG, idle='''
...aaaa...
..aaaaaa..
.aaaaaaaa.
.aieaaiea.
.apaaaapa.
.aaaaaaaa.
.caaaaaac.
..cbcbcb..
...b.b.b..''', step_tail='''
..b.b.b...''', sleep='''
...aaaa...
..aaaaaa..
.aaaaaaaa.
.akkaakka.
.apaaaapa.
.caaaaaac.
..bbbbbb..'''),
    adult=dict(pal=EGG, idle='''
....aaaaa....
...aaaaaaa...
..aaaaaaaaa..
.aaaaaaaaaaa.
.aaieaaaieaa.
.aapaaaaapaa.
.aaaaaaaaaaa.
.caaaaaaaaac.
..caaaaaaac..
...cbcbcbcb..
....b.b.b.b..''', step_tail='''
...b.b.b.b...''', sleep='''
....aaaaa....
...aaaaaaa...
..aaaaaaaaa..
.aaaaaaaaaaa.
.aakkaaakkaa.
.aapaaaaapaa.
.caaaaaaaaac.
..cbbbbbbbc..'''))

LANT = {'a': '#d8442e', 'b': '#a8301e', 'c': '#3a2a24', 'y': '#ffd46a', 't': '#e8b040', 'e': E, 'i': I, 'p': '#ff9a7a'}
pet(id='lantern_spirit', name='등롱 혼령', grade=3, kind='ghost', likes='treat_rice',
    desc='밤길을 밝히던 붉은 종이 등롱에 깃든 혼령입니다. 길 잃은 넋을 보면 제 불빛을 조금 나눠 주고, 그 탓에 새벽이면 늘 불이 가물가물합니다. 바람이 세게 불면 꺼질까 봐 몸을 웅크리고 처마 밑으로 숨어듭니다.',
    baby=dict(pal=LANT, idle='''
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
...ccc...'''),
    adult=dict(pal=LANT, idle='''
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
....ccccc....'''))

ROE = {'a': '#c08a52', 'b': '#8e5e32', 'w': '#f6ead2', 'n': '#3a2418', 'e': E, 'i': I, 'p': PK}
pet(id='roe_fawn', name='아기 노루', grade=2, kind='wood', likes='treat_herb',
    desc='등에 흰 점무늬가 아직 남아 있는 아기 노루입니다. 귀가 밝아 풀잎 하나 스치는 소리에도 겅중 뛰어오르고, 엉덩이의 하얀 털을 깃발처럼 세웁니다. 겁이 많지만 한번 친해지면 졸졸 따라다닙니다.',
    baby=dict(pal=ROE, idle='''
.........bb.
.........aab
.........aie
w.aaaaaaaaan
.awawawaaa..
..aaaaaaa...
..b.b..b.b..
..b.b..b.b..''', step_tail='''
...b.b.b.b..
..b...b...b.''', sleep='''
.........bb.
.........aab
w.aaaaaaaakn
.awawawaaaa.
.bbbbbbbbb..'''),
    adult=dict(pal=ROE, idle='''
............bb..
............aab.
...........aaaab
...........aaiea
w..aaaaaaaaaaaan
.awawawawaaaa...
..aaaaaaaaaa....
..aaaaaaaaa.....
..b.b....b.b....
..b.b....b.b....
..b.b....b.b....''', step_tail='''
...b.b..b.b.....
..b...b.b...b...
..b....b....b...''', sleep='''
............bb..
............aab.
...........aaaab
w..aaaaaaaaaakkn
.awawawawaaaaaa.
..aaaaaaaaaaaa..
.bbbbbbbbbbbb...'''))

SEAL = {'a': '#b8bcc4', 'b': '#8a8e98', 'c': '#e2e4e8', 's': '#5a5e68', 'n': '#2a2420', 'e': E, 'i': I, 'p': PK}
pet(id='spotted_seal', name='아기 점박이물범', grade=2, kind='water', likes='treat_fish',
    desc='서해 바위섬에서 태어난 아기 점박이물범입니다. 뭍에서는 배를 끌며 엉금엉금 기지만, 물에 들어가면 누구보다 날쌔게 헤엄칩니다. 까만 눈을 끔뻑이며 쳐다보면 아무도 생선을 안 줄 수가 없습니다.',
    baby=dict(pal=SEAL, idle='''
........aaa.
.......aaiea
..aasaaaaapn
.aaaaasaaaa.
saaacccccaa.
.b..b.....b.''', step_tail='''
..b..b...b..''', sleep='''
........aaa.
..aasaaaakka
.aaaaasaaapn
saaacccccaa.
.bbbbbbbbbb.'''),
    adult=dict(pal=SEAL, idle='''
...........aaaa.
..........aaaiea
...aasaaaaaaapan
..aaaaasaaasaan.
.aasaaaaaaaaaa..
saaaacccccccaa..
.bb..b......bb..''', step_tail='''
..bb...b...bb...''', sleep='''
...........aaaa.
...aasaaaaaakkaa
..aaaaasaaasapan
.aasaaaaaaaaaa..
saaaacccccccaa..
.bbbbbbbbbbbbb..'''))

ELE = {'a': '#a8a4ac', 'b': '#7c7880', 'c': '#c8c4cc', 'w': '#f4f0e6', 'e': E, 'i': I, 'p': PK}
pet(id='baby_elephant', name='아기 코끼리', grade=2, kind='giant', likes='treat_herb',
    desc='먼 남쪽 나라에서 배를 타고 건너왔다는 아기 코끼리입니다. 코로 물을 빨아올려 머리 위로 뿌리며 놀기를 좋아하고, 기분이 좋으면 귀를 부채처럼 펄럭입니다. 한번 본 얼굴은 절대 잊지 않습니다.',
    baby=dict(pal=ELE, idle='''
.......cccaa..
......ccccaaa.
..aaaaccaaiea.
.aaaaaaaaaaapa
.aaaaaaaaaaa.a
.aaaaaaaaaa..a
..aa.aa.aa..b.
..bb.bb.bb....''', step_tail='''
...aa.aa.aa.b.
...bb.bb.bb...''', sleep='''
.......cccaa..
......ccccaaa.
..aaaaccaakka.
.aaaaaaaaaaapa
.aaaaaaaaaaaaa
.bbbbbbbbbbbbb'''),
    adult=dict(pal=ELE, idle='''
.........ccccaaa...
........cccccaaaa..
...aaaaaccccaaaaa..
..aaaaaaaccaaaieaa.
.aaaaaaaaaaaaaaapaa
.aaaaaaaaaaaaaaa.wa
.aaaaaaaaaaaaaa...a
.aaaaaaaaaaaaa....a
..aaa.aaa..aaa...b.
..aaa.aaa..aaa.....
..bbb.bbb..bbb.....''', step_tail='''
...aaa.aaa.aaa...b.
...aaa.aaa.aaa.....
...bbb.bbb.bbb.....''', sleep='''
.........ccccaaa...
........cccccaaaa..
...aaaaaccccaaaaa..
..aaaaaaaccaaakkaa.
.aaaaaaaaaaaaaaapaa
.aaaaaaaaaaaaaaa.wa
.aaaaaaaaaaaaaaaaaa
.bbbbbbbbbbbbbbbbbb'''))

WHALE = {'a': '#4a7ab8', 'b': '#2e5a94', 'c': '#dce8f2', 'w': '#cfe8f6', 'e': E, 'i': I, 'p': PK}
pet(id='baby_whale', name='아기 고래', grade=3, kind='giant', likes='treat_fish',
    desc='큰 바다에서 길을 잃고 포구까지 흘러든 아기 고래입니다. 기분이 좋으면 머리 위로 물을 뿜어 작은 무지개를 띄우고, 노래하듯 낮고 길게 웁니다. 아직 어려도 몸집은 별채 마당을 꽉 채울 만큼 큽니다.',
    baby=dict(pal=WHALE, idle='''
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
...cccccccc...'''),
    adult=dict(pal=WHALE, idle='''
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
......cccccccccc...'''))

for _p in PETS:
    for _k in ('lid', 'eyes'):
        if _k in _p:
            for _f in ('baby', 'adult'):
                _p[_f].setdefault(_k, _p[_k])
