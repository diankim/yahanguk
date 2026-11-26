import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mk import C, txt, rect, boss, num, arrow, svg
def player(x, y, n):
    if n == '': return ''
    t = '가나다라'[int(n) - 1]
    return f'<rect x="{x-10}" y="{y-10}" width="20" height="20" rx="5" fill="#fff" stroke="{C["p"]}" stroke-width="2"/>' + txt(x, y, t, 11, C['p'], 800)

S, OX, OY = 52, 56, 22
def cell(r, c): return OX + c * S + S / 2 - 2, OY + r * S + S / 2 - 2
def sea(head=(0, 0), rift_hot=False, mark=()):
    b = rect(0, 0, 320, 280, C['deep'])
    for r in range(4):
        for c in range(4):
            rf = r in (1, 2) and c in (1, 2)
            col = C['rift'] if rf else C['sea']
            if (r, c) == head: col = '#3f8fb0'
            b += rect(OX + c * S, OY + r * S, S - 4, S - 4, col, 'stroke-width="2"' + (f' stroke="{C["lamp"]}"' if (r, c) == head else ''))
            if rf and rift_hot: b += f'<circle cx="{cell(r,c)[0]}" cy="{cell(r,c)[1]}" r="12" fill="none" stroke="#7fb4d8" stroke-dasharray="3 3"/>'
    x, y = cell(*head); b += txt(x, y - 15, '머리', 9, C['lamp'])
    b += boss(OX + 2 * S - 2, OY + 2 * S - 2, '도해수', 22)
    return b
def cap(b, t1, t2=''):
    b += txt(160, 252, t1, 11, '#fff', 700) + (txt(160, 268, t2, 9.5, '#d6e4ee', 500) if t2 else '')
    return svg(b, 320, 280)

def dh1():
    b = sea()
    b += arrow(OX - 40, 110, OX - 8, 110, '#cfe8ff', 3) + txt(OX - 26, 94, '해류', 10) + num(OX - 26, 128, 2, '#cfe8ff')
    b += player(*cell(1, 0), 1) + player(*cell(0, 2), 2) + player(*cell(3, 3), 3) + player(*cell(2, 0), 4)
    b += arrow(cell(1, 0)[0] + 12, cell(1, 0)[1], cell(1, 1)[0] - 12, cell(1, 1)[1], '#ff8a8a', 2)
    return cap(b, '① 해류 — 숫자가 0이 되면 모두 한 칸 밀림', '「가」는 밀리면 틈으로 빨려 듦(낙사) → 버티기 또는 미리 비켜서기')
def dh2():
    b = sea()
    b += arrow(OX + 4 * S + 34, 110, OX + 4 * S + 6, 110, '#ff9f6b', 4) + txt(OX + 4 * S + 20, 92, '뒤집힘', 10, '#ff9f6b') + num(OX + 4 * S + 20, 130, 2, '#ff9f6b')
    for rc in [(0, 1), (3, 2), (3, 0)]: b += num(*cell(*rc), 3)
    b += player(*cell(0, 3), 1) + player(*cell(3, 3), 2) + player(*cell(0, 0), 3)
    return cap(b, '② 해류 뒤집힘(두 칸) · ③ 물보라 덮침(칸 셋)', '반대쪽 가장자리에 붙으면 벽에 막혀 제자리')
def dh3():
    b = sea()
    p1, p2 = cell(0, 3), cell(1, 0)
    b += f'<path d="M{p1[0]},{p1[1]} Q{160},{40} {p2[0]},{p2[1]}" stroke="#ffb0d0" stroke-width="3" stroke-dasharray="5 4" fill="none"/>'
    b += num((p1[0] + p2[0]) / 2, 44, 3, '#ffb0d0')
    b += player(*p1, 1) + player(*p2, 2) + player(*cell(3, 3), 3)
    b += arrow(p2[0], p2[1] + 14, cell(3, 0)[0], cell(3, 0)[1] - 14, '#ffffffaa', 2)
    return cap(b, '④ 촉수 감기 — 묶인 둘이 세 칸 넘게 떨어져야 끊김', '못 끊으면 둘 다 틈 쪽으로 한 칸 끌려감')
def dh4():
    b = sea(rift_hot=True)
    for (r, c) in [(0, 1), (0, 2), (3, 1), (3, 2), (1, 0), (2, 0), (1, 3), (2, 3)]:
        x, y = cell(r, c); dx, dy = 160 - 2 - x, 126 - 2 - y; d = math.hypot(dx, dy)
        b += arrow(x - dx / d * 2, y - dy / d * 2, x + dx / d * 14, y + dy / d * 14, '#7fb4d8', 2)
    b += num(*cell(0, 3), 3, '#7fb4d8')
    b += player(*cell(0, 0), 1) + player(*cell(1, 0), 2) + player(*cell(0, 1), 3) + player(*cell(3, 3), 4)
    b += txt(cell(0, 0)[0] + 2, cell(0, 0)[1] + 16, '길 알려 주기', 8.5, C['lamp'])
    return cap(b, '⑤ 틈의 숨(마지막 구간) — 가운데로 두 칸 끌어당김', '머리 칸에 절반 이상 모여 ! 라운드에 「길 알려 주기」 → 막힘')

def drops(x, y, n):
    return ''.join(f'<circle cx="{x - 8 + i * 8}" cy="{y + 15}" r="3" fill="#7fd0ff" stroke="#003" stroke-width=".8"/>' for i in range(n))
def dh5():
    b = sea(head=(0, 3))
    x0, y0 = cell(0, 0); b += f'<path d="M{x0 + 10},{y0 - 18} C{x0 + 60},{y0 - 34} {cell(0, 3)[0] - 40},{y0 - 34} {cell(0, 3)[0] - 14},{y0 - 20}" stroke="{C["lamp"]}" stroke-width="2" fill="none" stroke-dasharray="4 3"/>'
    b += txt((x0 + cell(0, 3)[0]) / 2, y0 - 34, '머리 칸이 구간마다 옮겨 감', 9, C['lamp'])
    for rc in [(3, 0), (3, 1)]:
        x, y = cell(*rc); b += f'<circle cx="{x}" cy="{y}" r="15" fill="none" stroke="#bfe0ff" stroke-width="3" stroke-dasharray="6 4"/>'
    b += txt(cell(3, 0)[0], cell(3, 0)[1] + 20, '소용돌이', 8.5, '#bfe0ff') + arrow(cell(3, 0)[0] + 16, cell(3, 0)[1], cell(3, 1)[0] - 16, cell(3, 1)[1], '#bfe0ff', 2)
    b += player(*cell(1, 0), 1) + drops(*cell(1, 0), 3) + player(*cell(2, 3), 2) + drops(*cell(2, 3), 1) + player(*cell(0, 3), 3) + player(*cell(3, 2), 4) + drops(*cell(3, 2), 2)
    return cap(b, '⑥ 젖은 몸(0~3겹) · ⑦ 소용돌이 기둥', '「가」는 3겹이라 다음 해류에 두 칸 밀림 · 머리 칸에서 말림')
R = 24
def hx(q, r): return 160 + R * 1.5 * q, 122 + R * math.sqrt(3) * (r + q / 2)
CELLS = [(q, r) for q in range(-2, 3) for r in range(-2, 3) if abs(q + r) <= 2]
ring = lambda q, r: max(abs(q), abs(r), abs(q + r))
def hexcell(q, r, f):
    x, y = hx(q, r); pts = ' '.join(f'{x + (R - 2) * math.cos(math.pi / 3 * i):.1f},{y + (R - 2) * math.sin(math.pi / 3 * i):.1f}' for i in range(6))
    return f'<polygon points="{pts}" fill="{f}" stroke="#00000066" stroke-width="1.5"/>'
PULL = [(2, -2), (-2, 2), (2, 0), (-2, 0)]
def stone(holes=(), gone=False, pulls=True):
    b = rect(0, 0, 320, 280, C['fall'])
    for q, r in CELLS:
        if (q, r) == (0, 0): continue
        if gone and ring(q, r) == 2: b += hexcell(q, r, '#2a221b'); continue
        b += hexcell(q, r, '#120d0a' if (q, r) in holes else (C['edge'] if ring(q, r) == 2 else C['land']))
    if pulls and not gone:
        for q, r in PULL: x, y = hx(q, r); b += txt(x, y + 13, '끌개', 8, '#ffe9b0')
    b += boss(160, 122, '땅울이', 19)
    return b
def du1():
    b = stone()
    for q, r in [(0, -1), (0, -2), (1, -2), (-1, -1)]:
        x, y = hx(q, r); b += arrow(x, y + 6, x, y - 12, '#ff6b4a', 3)
    b += num(*hx(1, -1), 2, '#ff6b4a')
    b += player(*hx(0, -1), 1) + player(*hx(-1, -1), 2) + player(*hx(1, 1), 3) + player(*hx(-2, 1), 4)
    return cap(b, '② 산사태 밀기 — 앞쪽 부채꼴, 0에 바깥으로 두 칸', '판 밖으로 나가면 낙사 · 버티기면 한 칸 · 부채꼴 밖으로 비키면 무사')
def du2():
    b = stone()
    for q, r in [(1, 1), (-1, 2), (2, -1)]: b += num(*hx(q, r), 3)
    b += player(*hx(1, 1), 1) + player(*hx(-1, 0), 2) + player(*hx(0, 1), 3)
    x, y = hx(2, -2); b += num(x + 22, y - 18, 1, '#ffe9b0') + player(x, y + 2, 4)
    return cap(b, '③ 땅의 무게(칸 셋이 두 라운드 구멍) · 끌개 멈추기', '「라」가 끌개 칸에서 ! 라운드에 「끌개 멈추기」 → 세 라운드 멈춤')
def du3():
    b = stone()
    x, y = hx(0, 2); b += player(x, y, 1)
    b += arrow(160, 142, x, y - 14, '#ffcf4a', 4) + arrow(x, y + 10, x, y + 34, '#ff6b4a', 3)
    b += txt(x + 52, y + 10, '가장자리 등짐 ×', 9, '#ff9c8a')
    x2, y2 = hx(0, 1); b += player(x2 + 0, y2, 2)
    b += player(*hx(-1, 0), 3) + player(*hx(1, -1), 4)
    return cap(b, '④ 돌주먹 — 이목 1위에게 큰 한 방 + 뒤로 한 칸', '방패는 바깥 고리에서 맞으면 떨어짐 → 안쪽에서 받거나 버티기')
def du4():
    b = stone(gone=True)
    ang = -30
    for q, r in [(0, -1), (1, -1), (1, 0), (0, 1), (-1, 1), (-1, 0)]:
        x, y = hx(q, r); b += player(x, y, [1, 2, 3, 4, '', ''][[(0, -1), (1, -1), (1, 0), (0, 1), (-1, 1), (-1, 0)].index((q, r))]) if (q, r) in [(0, -1), (1, -1), (1, 0), (0, 1)] else ''
    b += arrow(40, 40, 90, 70, '#ff6b4a', 5) + txt(52, 26, '기울어짐', 10, '#ff9c8a') + num(100, 40, 1, '#ff6b4a')
    return cap(b, '⑤ 판 깎기(25%) → 바깥 고리가 무너져 일곱 칸', '마지막 몸부림 세 라운드 — 라운드마다 한쪽으로 기울어 모두 버티기')

def du5():
    b = stone(holes=((1, 1),))
    x, y = hx(1, 1); b += txt(x, y, '구멍', 8.5, '#c9b08a')
    for q, r in [(2, 0), (0, 2)]:
        x, y = hx(q, r); b += f'<polygon points="{x-7},{y+4} {x},{y-8} {x+7},{y+4}" fill="#cfd6dc" stroke="#222"/>'
    x, y = hx(0, 2); b += txt(x, y + 13, '쐐기돌', 8, '#e8eef2')
    xa, ya = hx(-2, 1); xb, yb = hx(2, -1)
    b += f'<line x1="{xa - 20}" y1="{ya + 10}" x2="{xb + 20}" y2="{yb - 10}" stroke="#ff9f6b" stroke-width="10" stroke-opacity=".25"/>'
    b += f'<circle cx="{xa - 22}" cy="{ya + 12}" r="10" fill="#8a7a66" stroke="#222"/>' + num(xa - 22, ya - 12, 2, '#ff9f6b')
    b += player(*hx(1, 0), 1) + player(*hx(-1, 1), 2) + player(*hx(0, -1), 3) + player(*hx(2, -2), 4)
    x, y = hx(2, -2); b += f'<polygon points="{x+8},{y-6} {x+14},{y-16} {x+20},{y-6}" fill="#cfd6dc" stroke="#222"/>'
    return cap(b, '⑥ 쐐기돌 · ⑦ 굴러오는 바위 · 금 간 칸', '쐐기돌을 든 「라」만 끌개를 멈춤 · 바위 줄의 「나」는 비켜야 함')
OUT = sys.argv[1]
for k, f in [('dh1', dh1), ('dh2', dh2), ('dh3', dh3), ('dh4', dh4), ('dh5', dh5), ('du1', du1), ('du2', du2), ('du3', du3), ('du4', du4), ('du5', du5)]:
    open(os.path.join(OUT, k + '.svg'), 'w').write(f().replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" ', 1))
