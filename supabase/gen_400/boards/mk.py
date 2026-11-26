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

open('boards.py.out', 'w').write('\n'.join(f'<!--{k}-->' + f() for k, f in [('dohaesu', dohaesu), ('ttangul', ttangul)]))
