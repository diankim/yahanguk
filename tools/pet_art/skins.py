E = '#2a1a14'; PK = '#f3a0a0'
SKINS = []
def skin(**kw): SKINS.append(kw)

CALICO_PAL = {'a': '#fbf9f4', 'o': '#e8964a', 'd': '#4a3f3a', 'n': '#e07a86', 'e': E, 'i': '#8a7a74', 'p': PK}
CALICO_BABY = dict(pal=CALICO_PAL, idle='''
.....a...a..
....aoo.dda.
....odaaoda.
o...aieaiea.
d...aeeaeea.
.o..paanaap.
.daaaaaaaaa.
.aaaaaaaaaa.
.aa.a..a.aa.''', step_tail='''
..aa.a.a.aa.''', sleep='''
......a...a.
.....aoo.dda
.....odaaoda
.aaaaakkakka
aaaaapaanaap
aodododoaaa.''')
CALICO_ADULT = dict(pal=CALICO_PAL, idle='''
........a...a..
.......aoo.dda.
.......odaoada.
.o.....aieaiea.
d......aeeaeea.
o......paanaap.
.d......aaaaa..
..oaaaaaaaaaaa.
..aaaaaaaaaaaa.
..aaaaaaaaaaaa.
..aa.aa...aa.a.
..aa.aa...aa.a.''', step_tail='''
...aa.aa..aa.a.
..aa...aa.a..a.''', sleep='''
.........a...a.
........aoo.dda
........odaoada
.aaaaaaaakkakka
aaaaaaaapaanaap
aaaaaaaaaaaaaaa
.odododododdo..''')

skin(key='snow_calico', pet='spotted_cat', name='눈송이 삼색',
    desc='온몸이 눈처럼 하얗고 정수리와 꼬리에만 삼색 얼룩이 앉은 모습입니다.',
    baby=CALICO_BABY, adult=CALICO_ADULT)
