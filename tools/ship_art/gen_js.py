import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim
import art

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
OUT = os.path.join(ROOT, 'assets', 'js', 'ship_art.js')


def js(v):
    return json.dumps(v, ensure_ascii=False, separators=(',', ':'))


def main():
    ships = []
    for name, frames, base in anim.all_frames():
        idx = {}
        fr = [[idx.setdefault(r, len(idx)) for r in g] for g in frames]
        ships.append({'name': name, 'w': len(frames[0][0]), 'h': len(frames[0]), 'base': base, 'rows': sorted(idx, key=idx.get), 'f': fr})
    used = sorted({c for s in ships for r in s['rows'] for c in r} - {'.'})
    pal = {c: art.PAL[c] for c in used}
    with open(OUT, 'w', encoding='utf-8') as fh:
        fh.write(f'export const SHIP_PAL = {js(pal)};\n')
        fh.write(f'export const SHIP_MS = {anim.MS};\n')
        fh.write('export const SHIP_ART = [\n' + ',\n'.join('  ' + js(s) for s in ships) + '\n];\n')
    print(OUT, os.path.getsize(OUT))


if __name__ == '__main__':
    main()
