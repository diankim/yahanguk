import math, html
C = dict(sea='#4f86a8', deep='#1f3f57', rift='#0b1a26', land='#b59b73', edge='#5b4a35', fall='#1a1410',
         grass='#8fa766', fire='#d9572b', ash='#6b625a', wind='#ffffff', dream='#5b4f86', wake='#a9a36f',
         lamp='#f2c14e', ice='#bfe0ee', thin='#8ec5dd', snow='#f3f6f8', rock='#7d8790', camp='#e07b39',
         sun='#e8a33c', moon='#5f8fbf', bridge='#a68457', boss='#c03838', p='#2b2b2b')
def txt(x, y, t, s=11, c='#fff', w=600):
    return f'<text x="{x:.1f}" y="{y:.1f}" font-size="{s}" fill="{c}" font-weight="{w}" text-anchor="middle" dominant-baseline="central">{html.escape(t)}</text>'
def rect(x, y, w, h, f, extra=''):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" fill="{f}" stroke="#00000055" {extra}/>'
def player(x, y, n):
    return f'<circle cx="{x}" cy="{y}" r="9" fill="#fff" stroke="{C["p"]}" stroke-width="2"/>' + txt(x, y, str(n), 10, C['p'], 700)
def boss(x, y, t, r=22):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{C["boss"]}" stroke="#fff" stroke-width="2"/>' + txt(x, y, t, 11)
def num(x, y, n, c='#ffd84d'):
    return f'<circle cx="{x}" cy="{y}" r="10" fill="#000a" stroke="{c}" stroke-width="2"/>' + txt(x, y, str(n), 11, c, 800)
def arrow(x1, y1, x2, y2, c='#fff', w=3):
    a = math.atan2(y2 - y1, x2 - x1); h = 8
    pts = f'{x2},{y2} {x2 - h*math.cos(a-0.45):.1f},{y2 - h*math.sin(a-0.45):.1f} {x2 - h*math.cos(a+0.45):.1f},{y2 - h*math.sin(a+0.45):.1f}'
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{c}" stroke-width="{w}" stroke-linecap="round"/><polygon points="{pts}" fill="{c}"/>'
def svg(body, w=320, h=260):
    return f'<svg viewBox="0 0 {w} {h}" role="img">{body}</svg>'

def dohaesu():
    b = rect(0, 0, 320, 260, C['deep'])
    S, ox, oy = 58, 44, 14
    for r in range(4):
        for c in range(4):
            rift = r in (1, 2) and c in (1, 2)
            b += rect(ox + c*S, oy + r*S, S-4, S-4, C['rift'] if rift else C['sea'])
    for c in range(4): b += arrow(ox + c*S + 27, oy - 6 + 4*S + 2, ox + c*S + 27, oy + 4*S + 14, '#cfe8ff', 2) if False else ''
    b += arrow(ox - 30, 130, ox - 6, 130, '#cfe8ff') + txt(ox - 22, 112, '해류', 10)
    b += boss(ox + 2*S - 2, oy + 2*S - 2, '도해수', 26)
    b += txt(ox + 27, oy + 27, '머리', 10, C['lamp']) + txt(ox + 3*S + 27, oy + 3*S + 27, '꼬리', 10, '#cfe8ff')
    b += num(ox + 3*S + 27, oy + 27, 2) + num(ox + 27, oy + 3*S + 27, 1)
    b += player(ox + 27, oy + S + 27, 1) + player(ox + S + 27, oy + 27, 2) + player(ox + 3*S + 27, oy + 2*S + 27, 3) + player(ox + 2*S + 27, oy + 3*S + 27, 4)
    b += f'<path d="M{ox+S+27},{oy+27} Q{ox+2*S+60},{oy+S} {ox+3*S+27},{oy+2*S+27}" stroke="#ffb0d0" stroke-width="2" stroke-dasharray="4 3" fill="none"/>'
    return svg(b)

def ttangul():
    b = rect(0, 0, 320, 260, C['fall'])
    R = 30; cx, cy = 160, 130
    def hx(q, r): return cx + R*1.5*q, cy + R*math.sqrt(3)*(r + q/2)
    def poly(x, y, f, s='#00000066'):
        pts = ' '.join(f'{x + (R-2)*math.cos(math.pi/3*i):.1f},{y + (R-2)*math.sin(math.pi/3*i):.1f}' for i in range(6))
        return f'<polygon points="{pts}" fill="{f}" stroke="{s}" stroke-width="1.5"/>'
    cells = [(q, r) for q in range(-2, 3) for r in range(-2, 3) if abs(q + r) <= 2]
    for q, r in cells:
        x, y = hx(q, r); ring = max(abs(q), abs(r), abs(q + r))
        b += poly(x, y, C['edge'] if ring == 2 else C['land'])
    for q, r in [(2, -2), (-2, 2), (2, 0), (-2, 0)]:
        x, y = hx(q, r); b += txt(x, y + 13, '끌개', 9, '#ffe9b0')
    x, y = hx(0, -1); b += arrow(x, y - 4, x, y - 50, '#ff6b4a', 4)
    x, y = hx(1, -1); b += arrow(x + 4, y - 2, x + 44, y - 26, '#ff6b4a', 4)
    x, y = hx(-1, 0); b += arrow(x - 4, y - 2, x - 44, y - 26, '#ff6b4a', 4)
    for (q, r), n in [((1, 1), 2), ((-1, 2), 1), ((0, 2), 3)]:
        x, y = hx(q, r); b += num(x, y, n)
    b += boss(cx, cy, '땅울이', 22)
    for (q, r), n in [((0, -2), 1), ((2, -1), 2), ((-2, 1), 3), ((1, 0), 4)]:
        x, y = hx(q, r); b += player(x, y + (0 if n != 1 else 0), n)
    b += txt(160, 248, '판 밖은 고임 구덩이 — 밀려 나가면 낙사', 10, '#ffb39c')
    return svg(b)

def deulbul():
    b = rect(0, 0, 320, 260, '#3b3226')
    S, ox, oy = 56, 20, 22
    fire = {(0, 3), (1, 3), (1, 4)}; ash = {(2, 0), (2, 1)}
    for r in range(4):
        for c in range(5):
            f = C['fire'] if (r, c) in fire else C['ash'] if (r, c) in ash else C['grass']
            b += rect(ox + c*S, oy + r*S, S-4, S-4, f)
    b += txt(ox + 3*S + 27, oy + 1*S + 14, '맞불 자리', 9, '#3b3226')
    b += arrow(ox + 4*S + 4, oy + 3*S + 27, ox + 3*S + 30, oy + 3*S + 27, C['wind']) + txt(ox + 4*S + 27, oy + 3*S + 8, '바람', 10, '#3b3226')
    b += boss(ox + 2*S + 26, oy + 2*S + 26, '들불어미', 26)
    b += num(ox + 27, oy + 27, 2) + num(ox + 4*S + 27, oy + 27, 1)
    b += f'<circle cx="{ox+S+27}" cy="{oy+S+27}" r="12" fill="#ffb347" stroke="#fff"/>' + txt(ox + S + 27, oy + S + 27, '불새끼', 8, '#3b3226')
    b += player(ox + 2*S + 14, oy + 14, 1) + player(ox + 2*S + 40, oy + S + 40, 2) + player(ox + 4*S + 27, oy + 2*S + 27, 3) + player(ox + 27, oy + 2*S + 27, 4)
    return svg(b)

def jamgeuneul():
    b = rect(0, 0, 320, 260, '#1e1b2b')
    S = 44
    for layer, (ox, oy, f, name) in enumerate([(14, 40, C['wake'], '깬 층'), (166, 40, C['dream'], '꿈 층')]):
        b += txt(ox + 3*S/2, 22, name, 12, '#fff')
        for r in range(3):
            for c in range(3):
                b += rect(ox + c*S, oy + r*S, S-4, S-4, f)
        b += boss(ox + S + 20, oy + S + 20, '잠그늘' if layer else '그늘', 18)
    b += f'<circle cx="{14+20}" cy="{40+20}" r="13" fill="{C["lamp"]}"/>' + txt(14 + 20, 40 + 20, '등불', 9, '#3b2a00')
    b += f'<circle cx="{14+2*S+20}" cy="{40+2*S+20}" r="13" fill="{C["lamp"]}" opacity=".45"/>' + txt(14 + 2*S + 20, 40 + 2*S + 20, '꺼져감', 8, '#3b2a00')
    b += player(14 + 2*S + 20, 40 + 20, 1) + player(14 + 20, 40 + 2*S + 20, 2) + player(166 + 20, 40 + 20, 3) + player(166 + 2*S + 20, 40 + S + 20, 4)
    b += f'<path d="M{14+20},{40+2*S+20} C120,230 200,230 {166+20},{40+20}" stroke="#d6c7ff" stroke-width="2" stroke-dasharray="4 3" fill="none"/>' + txt(160, 222, '이름 부르기(2 → 3)', 10, '#d6c7ff')
    b += txt(160, 246, '졸음 세 겹이면 꿈 층으로 끌려감', 10, '#cfc8e6')
    return svg(b)

def nunullim():
    b = rect(0, 0, 320, 260, '#203040')
    S, ox, oy = 50, 35, 10
    rock = {(0, 4), (3, 1), (4, 3)}; thin = {(1, 1), (2, 3), (3, 3)}; camp = (2, 0)
    for r in range(5):
        for c in range(5):
            f = C['rock'] if (r, c) in rock else C['thin'] if (r, c) in thin else C['ice']
            b += rect(ox + c*S, oy + r*S, S-4, S-4, f)
            if (r, c) in thin: b += f'<path d="M{ox+c*S+8},{oy+r*S+10} l12,10 l-4,10 l14,8" stroke="#3b6f8a" fill="none" stroke-width="1.5"/>'
    x, y = ox + camp[1]*S + 23, oy + camp[0]*S + 23
    b += f'<circle cx="{x}" cy="{y}" r="14" fill="{C["camp"]}"/>' + txt(x, y, '모닥불', 8, '#fff')
    b += boss(ox + 4*S + 23, oy + 0*S + 23, '눈울림', 20)
    b += f'<rect x="{ox}" y="{oy+2*S}" width="{5*S-4}" height="{S-4}" fill="#ffffff55" stroke="#fff" stroke-dasharray="5 3"/>' + num(ox + 5*S - 18, oy + 2*S + 23, 2)
    b += arrow(ox + 23, oy + 4*S + 23, ox + 23 + 2*S, oy + 4*S + 23, '#2b4a5c', 3) + txt(ox + 23 + S, oy + 4*S + 10, '미끄러짐', 9, '#2b4a5c')
    b += player(ox + 23, oy + 4*S + 23, 1) + player(ox + S + 23, oy + 23, 2) + player(ox + 3*S + 23, oy + 23, 3) + player(ox + 2*S + 23, oy + 3*S + 23, 4)
    return svg(b)

def nurisae():
    b = rect(0, 0, 320, 260, '#2a2230')
    S = 40
    for (ox, f, name) in [(12, C['moon'], '본토 쪽'), (188, C['sun'], '건넛누리 쪽')]:
        b += txt(ox + 60, 18, name, 11)
        for r in range(3):
            for c in range(3): b += rect(ox + c*S, 34 + r*S, S-4, S-4, f)
    for r in range(3): b += rect(140, 34 + r*S, S + 6, S-4, C['bridge'])
    b += txt(160, 34 + 3*S + 4, '다리', 10, '#e9d7b8')
    b += boss(52, 196, '본토 머리', 22) + boss(268, 196, '누리 머리', 22)
    b += f'<rect x="80" y="232" width="70" height="8" fill="{C["moon"]}"/><rect x="170" y="232" width="82" height="8" fill="{C["sun"]}"/>' + txt(160, 236, '|', 12)
    b += txt(160, 252, '두 머리 기세 차 15% 넘으면 큰 쪽이 모두를 침', 9, '#e8d9ff')
    b += player(12 + 20, 34 + 20, 1) + player(12 + 2*S + 18, 34 + S + 18, 2) + player(188 + S + 18, 34 + 20, 3) + player(160, 34 + S + 18, 4)
    b += f'<line x1="{12+2*S+18}" y1="{34+S+18}" x2="{188+S+18}" y2="{34+20}" stroke="#fff" stroke-width="2" stroke-dasharray="3 3"/>'
    b += f'<circle cx="160" cy="{34+2*S+18}" r="11" fill="#ffe7a3"/>' + txt(160, 34 + 2*S + 18, '종', 10, '#5a3d00')
    return svg(b)

open('boards.py.out', 'w').write('\n'.join(f'<!--{k}-->' + f() for k, f in [('dohaesu', dohaesu), ('ttangul', ttangul), ('deulbul', deulbul), ('jam', jamgeuneul), ('nun', nunullim), ('nuri', nurisae)]))
