exec(open('fix1.py').read())
a = open('art3.py').read()
a = a.replace("'c': '#e2cba4',", "'c': '#d9bd90',")
a = replace_pet(a, 'baby_girin', """
pet(id='baby_girin', name='아기 기린', grade=4, kind='sky', likes='treat_herb',
    desc='사슴 몸에 외뿔과 비늘을 지닌 상서로운 기린의 새끼입니다. 풀 한 포기도 밟지 않으려 사뿐사뿐 걷습니다.',
    baby=dict(pal=GIR,
        idle='''
......a.h.a.
....maaaaaaa
...mmaieaiea
...mmaeeaeea
m.mm.pacncap
.mmasaaccc..
.aasasaaaa..
..asasaaas..
..a.a..a.a..
..f.f..f.f..''',
        step_tail='''
...a.a.a.a..
...f.f.f..f.''',
        sleep='''
......a.h.a.
....maaaaaaa
...mmakkakka
m.mm.pacncap
.mmasaacccc.
.aasasasaaaa
..ffaaaaaff.'''),
    adult=dict(pal=GIR,
        idle='''
...........h....
.........a.h.a..
.......maaaaaaa.
......mmaieaiea.
......mmaeeaeea.
.....mmmpacncap.
.......mmaacca..
m....mmmaaaccc..
mm.aaasasasaac..
.mmasasasasaaa..
...asasasasaas..
...aa.a....a.a..
...a..a....a..a.
...f..f....f..f.''',
        step_tail='''
...aa.a...a.a...
..a....a.a...a..
..f....f.f...f..''',
        sleep='''
...........h....
.........a.h.a..
.......maaaaaaa.
......mmakkakka.
.....mmmpacncap.
m....mmmaaacc...
mm.aaasasasaacc.
.mmasasasasasaaa
...afasasasaafa.
....ffffffffff..'''))
""")
a = replace_pet(a, 'little_cheongryong', """
pet(id='little_cheongryong', name='꼬마 청룡', grade=4, kind='water', likes='treat_fish',
    desc='동쪽 하늘을 지킨다는 푸른 용의 새끼입니다. 재채기를 하면 작은 구름이 퐁 하고 나옵니다.',
    baby=dict(pal=DRA,
        idle='''
.....h.h.h.h
......haaah.
.....aaaaaaa
.....aieaiea
.f...aeeaeea
af..wpacncap
aaf.aaccccc.
.aafaacccca.
..aaaaacca..
....aa..aa..''',
        step_tail='''
..aaaaacca..
...aa..aa...''',
        sleep='''
.....h.h.h.h
......haaah.
.....aaaaaaa
.f...akkakka
af..wpacncap
aafaaaccccca
.aaaaaaacccc'''),
    adult=dict(pal=DRA,
        idle='''
.........h.h.h.h
..........haaah.
.........aaaaaaa
........faieaiea
.......ffaeeaeea
.......ffpacncap
......ffaaacccaw
..f..ffaaaccccw.
.faf.faaaccccc..
fabaffaabcccca..
fab..aabbccccaa.
fab..ab.aacca...
.fabba..aa..aa..
..bb...bbb..bbb.''',
        step_tail='''
.fabba.aa...aa..
..bb..bbb...bbb.''',
        sleep='''
.........h.h.h.h
..........haaah.
.........aaaaaaa
........fakkakka
.......ffpacncap
...f..ffaaacccaw
..faf.faaaccccw.
.fabaffaaacccccc
fab.aaabbbccccaa
.fabbaaaaaaaaaa.'''))
""")
a = replace_pet(a, 'gwiheo_butterfly', """
pet(id='gwiheo_butterfly', name='귀허 나비', grade=5, kind='ghost', likes='treat_honey',
    desc='귀허의 검푸른 바다 위를 날던 나비가 길을 잃고 따라왔습니다. 날갯짓마다 물빛 가루가 흩날립니다.',
    baby=dict(pal=BUT, noline='s', lid='c',
        idle='''
.ddd...a...a
dbbbd...a.a.
dbtgbd.cccc.
dbttbdciecie
.dbbbdceecee
..ddddapcccp
.dbtbdaa....
.dbgbd.a..s.
..ddd.......''',
        step='''
.dd....a...a
dbbd....a.a.
dbtgd..cccc.
dbttd.ciecie
dbbtd.ceecee
.dddd.apcccp
..dbdaa.....
..dgd..a....
...d......s.''',
        sleep='''
..ddd.......
.dbbbd......
.dbtbd.a..a.
.dbgtd..aa..
.dbttbdcccc.
..dbbdckkckk
..ddddacccp.'''),
    adult=dict(pal=BUT, noline='s', lid='c',
        idle='''
.dddd......a...a
dbbbbdd.....a.a.
dbttgbbd...cccc.
dbtgttbbd.ciecie
dbbttbbbd.ceecee
.dbbbbbbdaapcccp
..dddddddaa.....
..dbbtbbda......
.dbtgtbd.a......
.dbbtbd.....s...
..dbbd..........
...dd.....s.....''',
        step='''
.ddd.......a...a
dbbbd.......a.a.
dbtgbd.....cccc.
dbttgbd...ciecie
dbbttbd...ceecee
.dbbbbdddaapcccp
..ddddddaa......
...dbtbda.......
..dbtgbd.a......
..dbbbd.........
...dbd.....s....
....d...........''',
        sleep='''
...dd...........
..dbbd..........
..dbtbd.........
..dbgtbd...a...a
..dbttbd....a.a.
..dbbbbd...cccc.
...dbbbbd.ckkckk
...dddddd.acccp.
.........aa.....'''))
""")
for old, new in [(""".awkwkwa.
.aabbbaa.
.aaabaaa.
..b...b..''',""", """.awkwkwa.
.aabbbaa.
..b...b..''',"""), (""".awkwkwa.
.aabbbaa.
.aaabaaa.
...b.b...''',""", """.awkwkwa.
.aabbbaa.
...b.b...''',"""), ("""..aabbbaa..
..aaabaaa..
..aabbbaa..
..aaabaaa..
...b...b...""", """..aabbbaa..
..aaabaaa..
...b...b..."""), ("""..aabbbaa..
..aaabaaa..
..aabbbaa..
..aaabaaa..
....b.b....""", """..aabbbaa..
..aaabaaa..
....b.b....""")]:
    assert old in a, old
    a = a.replace(old, new)
open('art3.py', 'w').write(a)

b = open('art2.py').read()
for old, new in [("""        idle='''
......aa.aa.
.....aieaiea
..aaaaeeaeea
.abaaaaaaaap""", """        idle='''
.....ccc.ccc
.....cie.cie
..aaaceeacee
.abaaaaaaaap"""), ("""        sleep='''
......aa.aa.
.....aaaaaaa
..aaaakkakka
.abaaaaaaaap""", """        sleep='''
.....ccc.ccc
..aaackkackk
.abaaaaaaaap"""), ("""        idle='''
........aa.aa..
.......aieaiea.
...aaaaaeeaeea.""", """        idle='''
.......ccc.ccc.
.......cie.cie.
...aaaaceeacee."""), ("""        sleep='''
........aa.aa..
.......aaaaaaa.
...aaaaakkakka.""", """        sleep='''
.......ccc.ccc.
...aaaackkackk.""")]:
    assert old in b, old
    b = b.replace(old, new)
open('art2.py', 'w').write(b)
c = open('art1.py').read()
c = c.replace("'n': '#e07a8a', 'e': '#c03848', 'i': I}", "'n': '#e07a8a', 'e': '#8e2232', 'i': I}")
open('art1.py', 'w').write(c)
