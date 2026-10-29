exec(open('fix1.py').read())
def sub(src, old, new, n=None):
    c = src.count(old)
    assert c and (n is None or c == n), (old, c)
    return src.replace(old, new)
a1 = open('art1.py').read()
a1 = sub(a1, "'n': '#e07a86', 'e': E, 'i': I, 'p': PK}", "'n': '#e07a86', 'e': E, 'i': '#8a7a74', 'p': PK}", 2)
a1 = sub(a1, "'n': '#e07a8a', 'e': '#8e2232', 'i': I}", "'n': '#e07a8a', 'e': '#8e2232', 'i': '#d27482'}", 2)
open('art1.py', 'w').write(a1)
a2 = open('art2.py').read()
a2 = sub(a2, "'e': '#123048', 'i': I, 'p': '#ff9ab8'", "'e': '#123048', 'i': '#6a9ac0', 'p': '#ff9ab8'")
a2 = sub(a2, "'l': '#4a4a52', 'e': E, 'i': I, 'p': PK}", "'l': '#4a4a52', 'e': E, 'i': '#7a7a80', 'p': PK}")
a2 = sub(a2, "'g': '#c8b850', 'e': E, 'i': I, 'p': PK}", "'g': '#c8b850', 'e': E, 'i': '#8a8a60', 'p': PK}")
a2 = sub(a2, "'s': '#f6ffa0', 'e': E, 'i': I, 'p': PK}", "'s': '#f6ffa0', 'e': E, 'i': '#8a8070', 'p': PK}")
open('art2.py', 'w').write(a2)
a = open('art3.py').read()
a = sub(a, "'n': '#3a2418', 'e': '#5a2410', 'i': I}", "'n': '#3a2418', 'e': '#5a2410', 'i': '#b07050'}")
a = sub(a, "'g': '#7ab060', 'e': '#2a2a4a', 'i': I}", "'g': '#7ab060', 'e': '#2a2a4a', 'i': '#8a8ab0'}")
a = sub(a, "'e': '#3a3a6e', 'i': I, 'p': PK, 'n': '#8a8aa8'}", "'e': '#3a3a6e', 'i': '#8a8ac8', 'p': PK, 'n': '#8a8aa8'}")
a = sub(a, "'c': '#d8d4f0', 'e': '#20203a', 'i': I, 'p': PK}", "'c': '#d8d4f0', 'e': '#20203a', 'i': '#8a88b0', 'p': PK}")
# 백택 반짝이: 한 점 → 작은 십자
a = sub(a, """        idle='''
g.....h...h.
......haiah.""", """        idle='''
.g....h...h.
ggg...haiah.
.g..........""".replace('\n.g..........', ''))
open('art3.py', 'w').write(a)
a = open('art3.py').read()
s = a.index("pet(id='bead_imugi'"); s = a.index("adult=dict(pal=IMU", s); e = a.index("TIG = ", s)
a = a[:s] + """adult=dict(pal=IMU,
        idle='''
.........f..f...
........aaaaaa..
.......afaaaafa.
.......aieaaiea.
.......aeeaeeea.
.......paccccap.
........acccca..
.bf......acca...
.ba.....aacb..gg
.bab...aaccb.ggh
..baabaacccb.ghh
..bacccccccb....
...bbbbbbbb.....''',
        step='''
.........f..f...
........aaaaaa..
.......afaaaafa.
.......aieaaiea.
.......aeeaeeea.
.......paccccap.
........acccca..
.........acca...
fb......aacb..gg
.bab...aaccb.ggh
..baabaacccb.ghh
..bacccccccb....
...bbbbbbbb.....''',
        sleep='''
.........f..f...
........aaaaaa..
.......afaaaafa.
.......akkaakka.
.bf....paccccap.
.bab...aacccab..
..baabaaccccb.gg
..bacccccccb.ggh
...bbbbbbbb...hh'''))

""" + a[e:]
a = a.replace("aeeaeeea", "aeeaaeea")
open('art3.py', 'w').write(a)
