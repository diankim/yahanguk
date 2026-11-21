import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
from npcs import NPCS

designs = json.load(open(os.path.join(HERE, 'designs.json'), encoding='utf-8'))
out_d, tops, bots, looks = {}, {}, {}, {}
for k, n in NPCS.items():
    fid, hid = f'npc_f_{k}', f'npc_h_{k}'
    out_d[fid] = designs[str(n['designs']['face'])]
    out_d[hid] = designs[str(n['designs']['hair'])]
    t = n['top']
    tops[k] = {'name': n['name'], 'pal': t['pal'], 'part': {'x': t['x'], 'y': t['y'], 'rows': t['rows']}}
    bots[k] = {'name': n['name'], 'from': n['bottom']['from'], 'pal': n['bottom']['pal']}
    lk = {x: v for x, v in n['look'].items() if x not in ('top', 'bottom')}
    lk.update({'top': f'npc_{k}', 'bottom': f'npc_{k}', 'face_d': fid, 'hair_d': hid})
    if n.get('marks'):
        lk['marks'] = [[x, y, c] for x, y, c, _ in n['marks']]
    looks[k] = lk

js = ("import { AV } from './avatar.js';\n"
      f"export const NPC_DESIGNS = {json.dumps(out_d, ensure_ascii=False, separators=(',', ':'))};\n"
      f"const TOPS = {json.dumps(tops, ensure_ascii=False, separators=(',', ':'))};\n"
      f"const BOTS = {json.dumps(bots, ensure_ascii=False, separators=(',', ':'))};\n"
      f"export const NPC_LOOKS = {json.dumps(looks, ensure_ascii=False, separators=(',', ':'))};\n"
      "for (const [k, t] of Object.entries(TOPS)) AV.top['npc_' + k] = t;\n"
      "for (const [k, b] of Object.entries(BOTS)) { const s = AV.bottom[b.from]; AV.bottom['npc_' + k] = { ...s, name: b.name, pal: { ...s.pal, ...b.pal }, mask: undefined }; }\n")
open(os.path.join(ROOT, 'assets', 'js', 'housing', 'npcs.js'), 'w', encoding='utf-8').write(js)
print('npcs.js', len(looks))
