import { esc, icon } from '../core.js';

export const UG_HZ = {
  line: { name: '먹줄', short: '줄', tip: '줄 전체에 먹줄이 그어집니다. 숫자가 0(!)이 되는 라운드 끝에 그 줄에 서 있으면 맞습니다 — 줄 밖으로 나가세요. 두 줄이 겹친 칸은 두 번 맞습니다.' },
  step: { name: '발자국', short: '발', tip: '밟고 선 자리에 먹이 고였습니다. 숫자가 0(!)이 되는 라운드 끝에 그 칸에 있으면 먹이 터집니다 — 그 전에 옮겨 서세요.' },
  mem: { name: '기억', short: '억', tip: '지워진 칸에 기억이 떠올랐습니다. 0(!)인 라운드에 그 칸에 서서 「되새기기」를 누르면 칸이 다시 빛나고 이름 획이 하나 돌아옵니다.' },
  erase: { name: '이름 지우기', short: '名', tip: '그림자가 가운데 칸의 이름을 지우려 합니다. 0(!)인 라운드에 누군가 가운데 칸에 서 있고, 다른 사람이 「이름 부르기」를 눌러야 막습니다.' },
  mimic: { name: '흉내', short: '흉', tip: '그림자가 이 사람의 몸짓을 베끼려 합니다. 0(!)인 라운드에 이 사람이 공격하면 그 칼끝이 되돌아옵니다 — 그 라운드에는 방어나 버티기를 고르세요.' },
};
const due = h => Number(h.left) <= 0;
const num = h => (due(h) ? '!' : String(h.left));

export function mkugCells(s) {
  const out = {}, hz = s.board?.hz || [];
  const add = (c, cls, tag) => { const o = (out[c] = out[c] || { cls: new Set(), tags: [], tips: [] }); cls.forEach(x => o.cls.add(x)); if (tag) o.tags.push(tag); };
  const lineHits = {};
  for (const h of hz) {
    const k = UG_HZ[h.k]; if (!k || h.k === 'mimic') continue;
    for (const c of h.cells || []) {
      if (h.k === 'line') lineHits[c] = (lineHits[c] || 0) + (due(h) ? 1 : 0);
      add(c, [`ug-${h.k}`, due(h) ? 'ug-due' : ''].filter(Boolean), `<b class="ug-t ug-${h.k} ${due(h) ? 'due' : ''}" title="${esc(`${k.name} · ${due(h) ? '이번 라운드 끝' : `${h.left}라운드 뒤`} — ${k.tip}`)}">${k.short}${num(h)}</b>`);
      out[c].tips.push(`${k.name} ${due(h) ? '이번 라운드 끝' : `${h.left}라운드 뒤`}`);
    }
  }
  for (const [c, n] of Object.entries(lineHits)) if (n > 1) out[c].cls.add('ug-x2');
  return out;
}

export function mkugMimic(s, id) {
  const h = (s.board?.hz || []).find(x => x.k === 'mimic' && x.t === id);
  return h ? { due: due(h), n: num(h) } : null;
}

export function mkugMemTag(s, m) {
  const h = mkugMimic(s, m.id);
  return h ? `<b class="${h.due ? 'bad' : 'warn'}" title="${esc(UG_HZ.mimic.tip)}">흉내 ${h.n}</b>` : '';
}

export function mkugGim(s, me, a, moveTo, nameOf, cellName) {
  if (me.out) return '';
  const b = s.board || {}, dest = moveTo || b.my_pos;
  const keeper = (s.members || []).find(m => m.pos === 5 && !m.out && !m.resting && m.id !== s.me);
  const callT = keeper?.id || s.me;
  return `<div class="gw-gim mkug-gim"><span class="gw-gim-h" title="아홉 칸 명부에서 늘 쓰는 행동 — 맞는 라운드(!)에만 통하고, 그 밖에 누르면 한 라운드를 그냥 보냅니다">${icon('bell', 13)}<b>명부</b></span>
    <button class="btn ${a?.a === 'recall' ? 'on' : ''}" data-gw="recall" title="${esc(UG_HZ.mem.tip)}">${icon('scroll', 16)}<span>되새기기${dest ? ` · 「${esc(cellName(dest))}」 칸` : ''}</span></button>
    <button class="btn ${a?.a === 'call' ? 'on' : ''}" data-gw="call" data-t="${esc(callT)}" title="${esc(UG_HZ.erase.tip)}">${icon('users', 16)}<span>이름 부르기${keeper ? ` · ${esc(nameOf(s, keeper.id))}` : ''}</span></button>
  </div>`;
}

export function mkugCue(s) {
  const cue = s.fight?.mech?.cue || [], now = [...new Set((s.board?.hz || []).filter(due).map(h => UG_HZ[h.k]?.name).filter(Boolean))];
  if (!cue.length && !now.length) return '';
  return `<p class="gw-tell ug-cue">${now.length ? `<b class="bad">! ${now.map(esc).join(' · ')}</b>` : ''}${now.length && cue.length ? ' / ' : ''}${cue.length ? `${icon('bell', 13)} ${cue.map(esc).join(' · ')}` : ''}</p>`;
}
