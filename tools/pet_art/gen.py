#!/usr/bin/env python3
"""꼬마 동무 도트 생성기: 안쪽 그림만 그리면 바깥 테(k)를 둘러 pets.js를 만든다."""
import json, sys, os, importlib.util
HERE = os.path.dirname(os.path.abspath(__file__))
import os
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'js', 'housing', 'pets.js')

def rows(s):
    r = [l.rstrip() for l in s.strip('\n').split('\n')]
    r = [l.split('|')[0] if '|' in l else l for l in r]  # '|' 뒤는 주석
    return r

def outline(r, noline=''):
    h, w = len(r), max(len(x) for x in r)
    g = [['.'] * (w + 2) for _ in range(h + 2)]
    for y, line in enumerate(r):
        for x, ch in enumerate(line):
            g[y + 1][x + 1] = ch
    out = [row[:] for row in g]
    for y in range(h + 2):
        for x in range(w + 2):
            if g[y][x] != '.':
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w + 2 and 0 <= yy < h + 2 and g[yy][xx] not in '.k' and g[yy][xx] not in noline:
                    out[y][x] = 'k'; break
    return [''.join(row) for row in out]

def blink(r, eyes, lid, line):
    g = [list(x) for x in r]
    h, w = len(g), len(g[0])
    seen = set()
    for y in range(h):
        for x in range(w):
            if g[y][x] in eyes and (x, y) not in seen:
                st, cl = [(x, y)], []
                seen.add((x, y))
                while st:
                    cx, cy = st.pop(); cl.append((cx, cy))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            nx, ny = cx + dx, cy + dy
                            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and g[ny][nx] in eyes:
                                seen.add((nx, ny)); st.append((nx, ny))
                ymax = max(p[1] for p in cl)
                xs = sorted(set(p[0] for p in cl))
                for (cx, cy) in cl:
                    g[cy][cx] = lid
                for cx in range(xs[0], xs[-1] + 1):
                    g[ymax][cx] = line
    return [''.join(x) for x in g]

def build_form(f, tag):
    pal = dict(f['pal']); pal['k'] = '#1a120e'
    idle = rows(f['idle'])
    W = max(len(x) for x in idle)
    def norm(rr, name):
        for i, x in enumerate(rr):
            if len(x) > W:
                raise SystemExit(f'{tag}.{name} row {i} too long ({len(x)}>{W}): {x!r}')
        return [x.ljust(W, '.') for x in rr]
    idle = norm(idle, 'idle')
    if 'step' in f:
        step = norm(rows(f['step']), 'step')
    else:
        tail = norm(rows(f['step_tail']), 'step_tail')
        step = idle[:len(idle) - len(tail)] + tail
    if len(step) != len(idle):
        raise SystemExit(f'{tag}: step height {len(step)} != idle {len(idle)}')
    sleep = norm(rows(f['sleep']), 'sleep')
    if len(sleep) > len(idle):
        raise SystemExit(f'{tag}: sleep taller than idle')
    eyes = f.get('eyes', 'ei'); lid = f.get('lid', 'a'); line = f.get('line', 'k')
    bl = norm(rows(f['blink']), 'blink') if 'blink' in f else blink(idle, eyes, lid, line)
    noline = f.get('noline', '')
    frames = [idle, bl, step, sleep]
    while all(all(r[0] == '.' for r in fr) for fr in frames):
        frames = [[r[1:] for r in fr] for fr in frames]
    while all(all(r[-1] == '.' for r in fr) for fr in frames):
        frames = [[r[:-1] for r in fr] for fr in frames]
    idle, bl, step, sleep = frames
    while all(c == '.' for c in idle[0]) and all(c == '.' for c in bl[0]) and all(c == '.' for c in step[0]):
        idle, bl, step = idle[1:], bl[1:], step[1:]
    while all(c == '.' for c in sleep[0]):
        sleep = sleep[1:]
    out = {}
    for name, rr in (('idle', idle), ('blink', bl), ('step', step), ('sleep', sleep)):
        for y, x in enumerate(rr):
            for ch in x:
                if ch != '.' and ch not in pal:
                    raise SystemExit(f'{tag}.{name} row {y}: char {ch!r} not in pal')
        out[name] = outline(rr, noline)
    used = set(''.join(''.join(v) for v in out.values())) - {'.'}
    return {'pal': {k: v for k, v in pal.items() if k in used}, **out}

def main():
    spec = importlib.util.spec_from_file_location('data', os.path.join(HERE, 'data.py'))
    d = importlib.util.module_from_spec(spec); spec.loader.exec_module(d)
    pets = {}
    sizes = []
    for p in d.PETS:
        pid = p['id']
        e = {k: p[k] for k in ('name', 'grade', 'kind', 'desc', 'likes')}
        for form in ('baby', 'adult'):
            e[form] = build_form(p[form], f'{pid}.{form}')
            fr = e[form]
            sizes.append(f"{pid}.{form}: {len(fr['idle'][0])}x{len(fr['idle'])} sleep {len(fr['sleep'][0])}x{len(fr['sleep'])}")
        pets[pid] = e
    effects = {}
    for k, v in d.EFFECTS.items():
        pal = dict(v['pal']); pal['k'] = '#1a120e'
        rr = rows(v['rows']); W = max(len(x) for x in rr); rr = [x.ljust(W, '.') for x in rr]
        used = set(''.join(rr)) - {'.'}
        effects[k] = {'pal': {a: b for a, b in pal.items() if a in used}, 'rows': rr}
    def js(o, ind=0):
        sp = '  ' * ind
        if isinstance(o, dict):
            if all(isinstance(v, str) and len(v) <= 8 for v in o.values()):
                return '{ ' + ', '.join(f'{k}: {json.dumps(v)}' for k, v in o.items()) + ' }'
            return '{\n' + ',\n'.join(f'{sp}  {k}: {js(v, ind + 1)}' for k, v in o.items()) + f'\n{sp}}}'
        if isinstance(o, list) and all(isinstance(x, str) for x in o):
            return '[' + ', '.join(json.dumps(x) for x in o) + ']'
        return json.dumps(o, ensure_ascii=False)
    head = ("// 꼬마 동무(7.x 별채 펫) 도트 자료. 그림은 오른쪽을 보고, 화면이 뒤집어 왼쪽을 그린다(drawSprite flip).\n"
            "// 프레임: idle 가만히 · blink 눈 감기 · step 걷기(idle과 번갈아) · sleep 자기(폭은 같고 키는 낮을 수 있음).\n"
            "// pal: 글자 → '#rrggbb'(k는 테두리 #1a120e), '.'은 빈칸. 화면이 render.js P()로 바꿔 쓴다.\n"
            "// 등급 grade 1 범품 · 2 양품 · 3 진품 · 4 명품 · 5 신품, kind는 요괴 13갈래, likes는 좋아하는 별미.\n"
            "// 자동 생성: 작업 공간 pets/gen.py(안쪽 그림 + 자동 테두리). 직접 고쳐도 된다.\n\n")
    s = head + 'export const PETS = ' + js(pets) + ';\n\nexport const EFFECTS = ' + js(effects) + ';\n'
    open(OUT, 'w').write(s)
    print('\n'.join(sizes))
    print('pets', len(pets), 'bytes', len(s))

main()
