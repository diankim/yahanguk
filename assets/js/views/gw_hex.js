import { esc, icon } from '../core.js';

const Q = [0, 1, 1, 0, -1, -1, 0, 2, 2, 2, 1, 0, -1, -2, -2, -2, -1, 0, 1];
const R = [0, 0, -1, -1, 0, 1, 1, 0, -1, -2, -2, -2, -1, 0, 1, 2, 2, 2, 1];
const DQ = [1, 1, 0, -1, -1, 0], DR = [0, -1, -1, 0, 1, 1];
const S = 31, CX = 160, CY = 146;
const HZ_NAME = { drag: '사슬 끌림', burst: '봉인 터짐', charge: '기운 모으기', tide: '물살', name: '이름 빼앗김', vortex: '소용돌이' };

export const hexOn = s => !!s?.board?.hex;
const at = c => [CX + S * Math.sqrt(3) * (Q[c] + R[c] / 2), CY + S * 1.5 * R[c]];
const dist = (a, b) => (Math.abs(Q[a] - Q[b]) + Math.abs(R[a] - R[b]) + Math.abs(Q[a] + R[a] - Q[b] - R[b])) / 2;
const hexPath = (x, y, r = S - 1.5) => Array.from({ length: 6 }, (_, i) => { const t = Math.PI / 180 * (60 * i - 30); return `${(x + r * Math.cos(t)).toFixed(1)},${(y + r * Math.sin(t)).toFixed(1)}`; }).join(' ');
const due = h => Number(h.left) <= 0;
const num = h => due(h) ? '!' : String(h.left);
const nameOf = (s, id) => (s.members || []).find(m => m.id === id)?.name || '';

export function hexBoard(s, live, moveTo) {
  const b = s.board || {}, hz = b.hz || [], pillars = new Set(b.pillars || []), moves = new Set(live ? b.moves || [] : []), here = b.my_pos, dest = live ? moveTo : null;
  const wm = b.ug?.wm || null, seal = wm?.k === 'seal9' ? wm : null, sea = wm?.k === 'sea' ? wm : null;
  const fill = new Map(), add = (c, k) => fill.set(c, [...(fill.get(c) || []), k]);
  for (const h of hz) {
    const k = `hx-${h.k}${due(h) ? ' due' : ''}`;
    if (['drag', 'burst', 'tide'].includes(h.k)) for (const c of h.cells || []) add(c, k);
  }
  const vortex = hz.find(h => h.k === 'vortex');
  let cells = '';
  for (let c = 0; c < 19; c++) {
    const [x, y] = at(c);
    const cls = ['hx-cell', c === 0 ? 'core' : '', pillars.has(c) ? 'pillar' : '', (vortex || sea?.vortex) && c >= 1 && c <= 6 ? 'hx-ring' : '', seal?.due && pillars.has(c) ? 'wm-due' : '', ...(fill.get(c) || []), moves.has(c) ? 'mk-step' : '', c === dest ? 'dest' : '', c === here ? 'here' : ''].filter(Boolean).join(' ');
    const label = c === 0 ? '가운데 · 귀허 소용돌이(들어갈 수 없음)' : `${c}번 칸${pillars.has(c) ? ' · 봉인 기둥' : ''}${c <= 6 ? ' · 가운데 이웃' : ''}${moves.has(c) ? ' · 눌러서 옮겨 서기' : ''}`;
    cells += `<polygon class="${cls}" points="${hexPath(x, y)}" ${c && (moves.has(c) || (live && c === here)) ? `data-mk-step="${c}"` : ''}><title>${esc(label)}</title></polygon>`;
    if (pillars.has(c)) cells += `<g class="hx-pil"><rect x="${(x - 5).toFixed(0)}" y="${(y - 14).toFixed(0)}" width="10" height="24" rx="2"/><rect class="cap" x="${(x - 8).toFixed(0)}" y="${(y - 17).toFixed(0)}" width="16" height="5" rx="1"/></g>`
      + (seal?.order?.[c] ? `<g class="wm-n"><circle cx="${(x + 15).toFixed(0)}" cy="${(y - 15).toFixed(0)}" r="11"/><text x="${(x + 15).toFixed(0)}" y="${(y - 10).toFixed(0)}">${seal.order[c]}</text></g>` : seal?.due ? `<g class="wm-n due"><circle cx="${(x + 15).toFixed(0)}" cy="${(y - 15).toFixed(0)}" r="11"/><text x="${(x + 15).toFixed(0)}" y="${(y - 10).toFixed(0)}">!</text></g>` : '');
    else if (c) cells += `<text class="hx-no" x="${x.toFixed(0)}" y="${(y + 21).toFixed(0)}">${c}</text>`;
  }
  let marks = '';
  for (const h of hz) {
    if (h.k === 'drag') {
      const [ax, ay] = at(Number(h.a)), [bx, by] = at(Number(h.b)), mx = (ax + bx) / 2, my = (ay + by) / 2;
      const [lx, ly] = h.cells?.length === 2 ? at(Number(h.cells[0])) : [mx, my];
      marks += `<g class="hx-chain ${due(h) ? 'due' : ''}"><line x1="${ax.toFixed(0)}" y1="${ay.toFixed(0)}" x2="${bx.toFixed(0)}" y2="${by.toFixed(0)}"/><circle cx="${lx.toFixed(0)}" cy="${(ly - 9).toFixed(0)}" r="11"/><text x="${lx.toFixed(0)}" y="${(ly - 4).toFixed(0)}">${num(h)}</text></g>`;
    } else if (h.k === 'burst') {
      const [x, y] = at(Number(h.p));
      marks += `<circle class="hx-rip burst ${due(h) ? 'due' : ''}" cx="${x.toFixed(0)}" cy="${y.toFixed(0)}" r="26"/><g class="hx-tag burst ${due(h) ? 'due' : ''}"><circle cx="${(x + 14).toFixed(0)}" cy="${(y - 16).toFixed(0)}" r="10"/><text x="${(x + 14).toFixed(0)}" y="${(y - 11).toFixed(0)}">${num(h)}</text></g>`;
    } else if (h.k === 'tide') {
      const d = Number(h.d), ang = Math.atan2(S * 1.5 * DR[d], S * Math.sqrt(3) * (DQ[d] + DR[d] / 2));
      for (const c of h.cells || []) {
        const [x, y] = at(Number(c)), ex = x + 13 * Math.cos(ang), ey = y + 13 * Math.sin(ang), sx = x - 9 * Math.cos(ang), sy = y - 9 * Math.sin(ang);
        marks += `<g class="hx-arrow ${due(h) ? 'due' : ''}"><line x1="${sx.toFixed(1)}" y1="${sy.toFixed(1)}" x2="${ex.toFixed(1)}" y2="${ey.toFixed(1)}"/><circle cx="${ex.toFixed(1)}" cy="${ey.toFixed(1)}" r="3"/></g>`;
      }
      const [x, y] = at(Number((h.cells || [])[0]));
      marks += `<g class="hx-tag tide ${due(h) ? 'due' : ''}"><circle cx="${(x - 14).toFixed(0)}" cy="${(y - 16).toFixed(0)}" r="10"/><text x="${(x - 14).toFixed(0)}" y="${(y - 11).toFixed(0)}">${num(h)}</text></g>`;
    }
  }
  const [cx0, cy0] = at(0), face = b.face;
  const core = `<g class="hx-core ${vortex || sea?.vortex ? 'spin' : ''} ${(vortex && due(vortex)) || sea?.vortex ? 'due' : ''}"><circle cx="${cx0}" cy="${cy0}" r="24"/>${sea?.vortex ? `<text class="n" x="${cx0}" y="${cy0 + 6}">!</text>` : vortex ? `<text class="n" x="${cx0}" y="${cy0 + 6}">${num(vortex)}</text>` : `<text x="${cx0}" y="${cy0 + 4}">${face ? (face === 'human' ? '사람' : '요괴') : sea?.due ? '?' : s.boss === 'gwiheo' ? '주인' : '봉주'}</text>`}</g>`;
  const who = {};
  for (const m of s.members || []) if (m.pos != null && !m.out) (who[m.pos] = who[m.pos] || []).push(m);
  const named = new Map(hz.filter(h => h.k === 'name').map(h => [h.t, h]));
  let tokens = '';
  for (const [c, ms] of Object.entries(who)) {
    const [x, y] = at(Number(c));
    ms.slice(0, 4).forEach((m, i) => {
      const many = ms.length > 1, dx = many ? (i % 2 ? 9 : -9) : 0, dy = many ? (i > 1 ? 8 : -6) : -3, nh = named.get(m.id);
      tokens += `<g class="hx-tok ${m.id === s.me ? 'me' : ''} ${m.resting ? 'rest' : ''}"><circle cx="${(x + dx).toFixed(0)}" cy="${(y + dy).toFixed(0)}" r="11"/><text x="${(x + dx).toFixed(0)}" y="${(y + dy + 4).toFixed(0)}">${esc(String(m.name || '').slice(0, 1))}</text><title>${esc(m.name)}</title></g>`;
      if (nh) tokens += `<g class="hx-name ${due(nh) ? 'due' : ''}"><circle cx="${(x + dx).toFixed(0)}" cy="${(y + dy).toFixed(0)}" r="16"/><text x="${(x + dx + 15).toFixed(0)}" y="${(y + dy - 11).toFixed(0)}">${num(nh)}</text></g>`;
    });
  }
  if (dest) { const [x, y] = at(dest); tokens += `<polygon class="hx-destmark" points="${hexPath(x, y, S - 6)}"/>`; }
  const charge = hz.find(h => h.k === 'charge');
  const mechs = (b.mechs || []).map(k => HZ_NAME[k] || k).join(' · ');
  return `<div class="hx-wrap"><svg class="hx-map" viewBox="0 0 320 292" role="img" aria-label="구중 봉연 벌집 칸">${cells}${marks}${core}${tokens}</svg>
    <div class="hx-info">
      ${charge ? `<div class="hx-charge ${due(charge) ? 'due' : ''}"><span>${icon('spark', 13)} 기운 모으기 · ${due(charge) ? '이번 라운드 끝' : `${charge.left}라운드 뒤`}</span><div class="bar"><span style="width:${Math.min(100, Number(charge.dmg || 0) / Math.max(1, Number(charge.need || 1)) * 100).toFixed(0)}%"></span></div></div>` : ''}
      ${b.line ? `<p class="hx-line">${esc(b.line)}</p>` : ''}
      ${sea?.faces ? `<p class="wm-seq">${sea.faces.map((f, i) => `<b class="hx-face ${f}">${i + 1} ${f === 'human' ? '사람' : '요괴'}</b>`).join('<i>→</i>')}</p>` : ''}
      <p class="mk-hint muted small">${face ? `<b class="hx-face ${face}">${face === 'human' ? '사람 얼굴' : '요괴 얼굴'}</b> · ` : ''}${wm ? `<b class="wm-name">「${esc(wm.name || '')}」</b> · ` : ''}${esc(mechs)}</p>
      ${live ? `<p class="mk-hint muted small">${moveTo ? `${moveTo}번 칸으로 옮겨 섭니다 · 내 칸을 누르면 취소` : '점선 칸을 누르면 이번 라운드에 옮겨 섭니다(행동과 따로)'}</p>` : ''}
    </div></div>`;
}

export function hexGim(s, me, a, target, moveTo) {
  if (!hexOn(s) || me.out) return '';
  const b = s.board || {}, pos = moveTo || b.my_pos, onPil = (b.pillars || []).includes(pos);
  const hz = b.hz || [], named = hz.filter(h => h.k === 'name').map(h => h.t);
  const t = target && target !== s.me ? target : named.find(id => id !== s.me) || null;
  const tm = (s.members || []).find(m => m.id === t), near = tm?.pos != null && pos != null && dist(pos, tm.pos) === 1;
  return `<div class="gw-gim hx-gim"><span class="gw-gim-h" title="구중 봉연에서 늘 쓰는 행동">${icon('bell', 13)}<b>봉연</b></span>
    <button class="btn ${a?.a === 'chain' ? 'on' : ''}" data-gw="chain" data-c="" ${onPil ? '' : 'disabled'} title="${onPil ? '봉인 기둥 칸에서 사슬을 끊습니다' : '봉인 기둥 칸에 서야 합니다'}">${icon('close', 16)}<span>사슬 끊기${onPil ? ` · ${pos}번 기둥` : ''}</span></button>
    <button class="btn ${a?.a === 'call' ? 'on' : ''}" data-gw="call" data-t="${esc(t || '')}" ${t ? '' : 'disabled'} title="${t ? `${nameOf(s, t)}의 이름을 부릅니다 — 바로 옆 칸에 서 있을 때만 닿습니다${near ? '' : '(지금은 떨어져 있음)'}` : '부를 동료 이름을 누르세요'}">${icon('users', 16)}<span>이름 부르기${t ? ` · ${esc(nameOf(s, t))}` : ''}</span></button>
  </div>`;
}
