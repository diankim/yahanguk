# 제보 동무 2종(2026-11-02, 두 조사원 몫 — 사용자 전달 그림): 은빛 아프간 하운드 · 분홍 포메라니안
# ── 아프간 하운드: 은빛 긴 털이 머리부터 다리까지 늘어지고, 꼬리 끝이 고리처럼 말린다 ──
AFG = {'a': '#c4c9d5', 'h': '#eef0f5', 's': '#9aa1b3', 't': '#aab0c0', 'n': '#2a2830', 'p': PK, 'e': E, 'i': I}
pet(id='silver_afghan', name='은빛 아프간 하운드', grade=2, kind='sky', likes='treat_meat',
    desc='은빛 긴 털이 머리부터 발끝까지 비단처럼 늘어진 사냥개입니다. 걸을 때마다 털이 물결처럼 흔들리고, 꼬리 끝은 고리처럼 말려 있습니다. 늘 조금 졸린 눈을 하고 있지만 달리면 누구보다 빠릅니다.',
    baby=dict(pal=AFG, idle='''
.....hhhhh...
....shhhhhhhs
....saieaieas
....saeeaeeas
....sspanapss
....sssaaasss
.t..ss.aaa.ss
t.taaaaaaa...
.aaaaaaaaaa..
.hhhhhhhhhh..
.hh.hh..hh.hh
.ss.ss..ss.ss''', step_tail='''
..hh.hh.hh.hh
..ss.ss.ss.ss''', sleep='''
.....hhhhh...
....shhhhhhhs
....sakkakkas
.t..sspanapss
t.taaaaaaasss
.aaaaaaaaaaa.
hhhhhhhhhhhh.'''),
    adult=dict(pal=AFG, idle='''
........hhhhh...
.......hhhhhhh..
......shaieaiehs
......shaeeaeehs
......sshpanaphs
......sssaaaasss
.tt...sssaaaasss
t..t..ss.aaaa.ss
.t.aaaaaaaaaa...
..aaaaaaaaaaaa..
..hhhhhhhhhhhh..
..hh.hh...hh.hh.
..hh.hh...hh.hh.
..hh.hh...hh.hh.
..ss.ss...ss.ss.''', step_tail='''
...hh.hh.hh..hh.
...hh.hh.hh..hh.
...ss.ss.ss..ss.''', sleep='''
........hhhhh...
.......hhhhhhh..
......shakkakkhs
......sshpanaphs
.tt..asssaaaasss
t..taaaaaaaaaaa.
.taaaaaaaaaaaaa.
hhhhhhhhhhhhhhh.'''))

# ── 포메라니안: 분홍 털뭉치에 꼬리 깃털을 등 위로 얹은 작은 개 ──
POM = {'a': '#f6b3c8', 'l': '#fde0ea', 'd': '#e48aa8', 'p': '#e3668c', 'n': '#3a2028', 'e': E, 'i': I}
pet(id='pink_pomeranian', name='분홍 포메라니안', grade=1, kind='ward', likes='treat_rice',
    desc='솜사탕처럼 부푼 분홍 털뭉치 강아지입니다. 등 위에 깃털 같은 꼬리를 얹고 다니며, 저보다 열 배는 큰 개 앞에서도 물러서지 않습니다.',
    baby=dict(pal=POM, idle='''
......a...a.
.ll..aaaaaaa
llll.aieaiea
.lldaaeeaeea
..ldapanaap.
.aaaaaaaaaa.
aaaaaaaaaaa.
.dd.d...d.dd''', step_tail='''
..dd.d.dd.d.''', sleep='''
.ll..a...a..
llll.aaaaaaa
.lldaakkakka
aaaaapanaap.
aaaaaaaaaaa.
.aaaaaaaaaa.'''),
    adult=dict(pal=POM, idle='''
........a...a.
.lll...aaa.aaa
lllll..aaaaaaa
lldll.aaieaiea
.llldaaaeeaeea
..lldaaapanap.
.aaaaaaaaaaaaa
aaaaaaaaaallla
aaaaaaaaaaaaaa
.aaaaaaaaaaaa.
..dd.dd..dd.dd''', step_tail='''
...dd.dd.dd.dd''', sleep='''
.lll...a...a..
lllll.aaa.aaa.
lldll.aakkakka
.llldaaapanap.
aaaaaaaaaallla
aaaaaaaaaaaaaa
.aaaaaaaaaaaa.'''))
