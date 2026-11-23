import os, re
H = os.path.dirname(os.path.abspath(__file__))
EMO = {'포옹하기': 'hug', '손 잡기': 'hand', '머리 쓰다듬기': 'pat', '장난치기': 'tease', '칭찬하기': 'praise', '위로하기': 'comfort', '하이파이브': 'five', '함께 춤추기': 'dance'}
TIER = {'공통': 'all', '설렘': 't1', '편안함': 't2', '애틋함': 't3', '오랜 사이': 't4'}
CTX = {'해돋이': 'time:dawn', '한낮': 'time:noon', '땅거미': 'time:dusk', '삼경': 'time:night', '비': 'w:rain', '눈': 'w:snow', '안개': 'w:fog', '바람': 'w:wind', '혈무': 'w:bloodmist',
       '침식 높음': 'st:erosion', '체력 낮음': 'st:hp', '요화': 'st:yohwa', '원정 귀환': 'st:exp'}
rows, emote = [], None
for l in open(os.path.join(H, 'lines.md')).read().split('\n'):
    m = re.match(r'^### (.+?) \(', l)
    if m: emote = EMO[m.group(1)]; continue
    if l.startswith('## '): emote = None if not l.startswith('## 기본') else emote; continue
    m = re.match(r'^- (.+?): (\{정인\}.+)$', l)
    if not m: continue
    tag, line = m.group(1), m.group(2)
    if '"' in line: raise SystemExit('대사가 들어간 줄: ' + line)
    if '·' in tag:
        k, t = tag.split('·'); rows.append(('any', CTX[k], TIER[t], line))
    else:
        assert emote, l; rows.append((emote, 'base', TIER[tag], line))
q = lambda s: "'" + s.replace("'", "''") + "'"
sql = 'delete from public.world_bond_emote_lines;\ninsert into public.world_bond_emote_lines(emote, ctx, tier, line) values\n' + ',\n'.join(f'  ({q(a)}, {q(b)}, {q(c)}, {q(d)})' for a, b, c, d in rows) + ';\n'
open(os.path.join(H, 'lines.sql'), 'w').write(open(os.path.join(H, 'engine.sql')).read() + '\n' + sql)
print(len(rows), 'lines')
