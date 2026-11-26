import { esc, icon } from '../core.js';
import { SEA_BOSS as T } from '../rules.js';
import { TEL_DEFS, telWave, telChev } from './telfx.js';
import { GAMEDATA as GD } from '../gamedata.js';

const due = h => Number(h.left) <= 0;
const num = h => due(h) ? '!' : String(h.left);
const fx = n => Number(n).toFixed(1);
const nameOf = (s, id) => (s.members || []).find(m => m.id === id)?.name || '';
const C = T.common;

const hasMech = (s, k) => { const B = GD.boss?.[s.boss] || {}, seq = (s.mode === 'story' ? B.story?.board?.seq : B.board?.seq) || []; return !seq.length || seq.some(e => (e.m || []).includes(k)); };
export const seaOn = s => s?.boss === 'dohaesu' || s?.boss === 'ttangul';
const memOf = (s, id) => (s.members || []).find(m => m.id === id);
export const seaFell = (s, id) => seaOn(s) && !!(memOf(s, id)?.fell ?? (s.board?.fell || []).includes(id));
export const seaDue = s => (s.board?.hz || []).some(h => h.k !== 'whirl' && due(h));

let seen = { key: '', at: 0 };
function moved(s) {
  const f = s.fight || {}, key = `${f.id}:${f.round}`, ms = (s.members || []).filter(m => m.pushed && m.pos != null);
  if (seen.key !== key) seen = { key, at: Date.now() };
  return {
    trails: ms.filter(m => m.prev != null).map(m => ({ id: m.id, from: Number(m.prev), to: Number(m.pos), fell: !!m.fell })),
    fresh: new Set(Date.now() - seen.at < 3000 ? ms.filter(m => m.fell).map(m => Number(m.pos)) : []),
  };
}

export const seaMoves = s => s.board?.moves || [];

function trailSvg(t, at) {
  const [x1, y1] = at(t.from), [x2, y2] = at(t.to), a = Math.atan2(y2 - y1, x2 - x1), d = Math.hypot(x2 - x1, y2 - y1);
  if (d < 4) return '';
  const ex = x2 - 13 * Math.cos(a), ey = y2 - 13 * Math.sin(a);
  return `<g class="sea-trail ${t.fell ? 'fell' : ''}"><line x1="${fx(x1)}" y1="${fx(y1)}" x2="${fx(ex)}" y2="${fx(ey)}"/><path d="M${fx(ex + 7 * Math.cos(a))} ${fx(ey + 7 * Math.sin(a))} L${fx(ex - 6 * Math.cos(a - .6))} ${fx(ey - 6 * Math.sin(a - .6))} L${fx(ex - 6 * Math.cos(a + .6))} ${fx(ey - 6 * Math.sin(a + .6))}Z"/></g>`;
}
function tag(x, y, h, cls = '', r = 10) { return `<g class="hx-tag ${cls} ${r < 10 ? 'sm' : ''} ${due(h) ? 'due' : ''}"><circle cx="${fx(x)}" cy="${fx(y)}" r="${r}"/><text x="${fx(x)}" y="${fx(y + r / 2)}">${num(h)}</text></g>`; }
function tokens(s, at, extra) {
  const who = {}, ms = s.members || [];
  for (const m of ms) if (m.pos != null && !m.out && !seaFell(s, m.id)) (who[m.pos] = who[m.pos] || []).push(m);
  let g = '';
  for (const m of ms) {
    if (!seaFell(s, m.id) || m.pos == null) continue;
    const busy = !!who[m.pos], [cx, cy] = at(Number(m.pos)), x = busy ? cx + 13 : cx, y = busy ? cy + 12 : cy, r = busy ? 6 : 10, k = r / 2;
    g += `<g class="sea-ghost"><circle cx="${fx(x)}" cy="${fx(y)}" r="${r}"/><path d="M${fx(x - k)} ${fx(y - k)}L${fx(x + k)} ${fx(y + k)}M${fx(x + k)} ${fx(y - k)}L${fx(x - k)} ${fx(y + k)}"/><title>${esc(m.name)} · ${esc(C.fellLong)}</title></g>`;
  }
  for (const [c, list] of Object.entries(who)) {
    const [x, y] = at(Number(c));
    list.slice(0, 4).forEach((m, i) => {
      const many = list.length > 1, dx = many ? (i % 2 ? 10 : -10) : 0, dy = many ? (i > 1 ? 9 : -7) : -2, r = list.length > 2 ? 9.5 : 11;
      g += `<g data-mid="${esc(m.id)}" class="hx-tok ${m.id === s.me ? 'me' : ''} ${m.resting ? 'rest' : ''}"><circle cx="${fx(x + dx)}" cy="${fx(y + dy)}" r="${r}"/><text x="${fx(x + dx)}" y="${fx(y + dy + 4)}">${esc(String(m.name || '').slice(0, 1))}</text><title>${esc(m.name)}</title></g>${extra(m, x + dx, y + dy)}`;
    });
  }
  return g;
}
function hint(s, live, moveTo, lines) {
  const b = s.board || {}, cut = b.cut, enr = Number(s.fight?.enrage || 0);
  const cutTxt = cut?.next != null && cut.i < 3 ? C.cut([75, 50, 25][cut.i], Math.max(0, cut.next - (s.fight?.round || 0))) : '';
  const top = [b.phase_name ? `<b>${esc(b.phase_name)}</b>` : '', ...lines, cutTxt ? esc(cutTxt) : '', enr ? `<b class="bad">${esc(C.cutLate(enr))}</b>` : ''].filter(Boolean).join(' · ');
  return `<p class="mk-hint muted small">${top}</p>${live ? `<p class="mk-hint muted small">${esc(moveTo ? C.stepTo(moveTo) : C.step)}</p>` : ''}`;
}

const DH_G = 64, DH_X = 14, DH_Y = 30;
const dhAt = c => [DH_X + ((c - 1) % 4) * (DH_G + 4) + DH_G / 2, DH_Y + Math.floor((c - 1) / 4) * (DH_G + 4) + DH_G / 2];
const DH_ANG = { E: 0, S: Math.PI / 2, W: Math.PI, N: -Math.PI / 2 };
const DH_ARROW = { E: '→', S: '↓', W: '←', N: '↑' };

function dhBoard(s, live, moveTo) {
  const b = s.board || {}, hz = b.hz || [], rift = new Set((b.rift || [6, 7, 10, 11]).map(Number)), head = Number(b.head), here = b.my_pos, dest = live ? moveTo : null;
  const moves = new Set(live ? seaMoves(s) : []), mm = moved(s), freshCells = mm.fresh;
  const flow = hz.find(h => h.k === 'surge') || hz.find(h => h.k === 'current'), breath = hz.find(h => h.k === 'breath'), headH = hz.find(h => h.k === 'head');
  const wave = flow && breath ? (Number(breath.left) <= Number(flow.left) ? breath : flow) : flow || breath;
  let cells = '', marks = '';
  for (let c = 1; c <= 16; c++) {
    const [x, y] = dhAt(c), r = rift.has(c), pushed = wave && due(wave) && !r;
    const cls = ['dh-cell', r ? 'rift' : 'sea', c === head ? 'head' : '', pushed ? 'sea-push due' : '', moves.has(c) ? 'mk-step' : '', c === dest ? 'dest' : '', c === here ? 'here' : '', freshCells.has(c) ? 'sea-fell-new' : ''].filter(Boolean).join(' ');
    const label = `${c}번 칸 · ${r ? T.dohaesu.cell.rift : c === head ? T.dohaesu.cell.head : T.dohaesu.cell.sea}${moves.has(c) ? ' · 눌러서 옮겨 서기' : ''}`;
    cells += `<rect class="${cls}" ${pushed ? 'data-push="water"' : ''} x="${fx(x - DH_G / 2)}" y="${fx(y - DH_G / 2)}" width="${DH_G}" height="${DH_G}" rx="6" ${moves.has(c) || (live && c === here) ? `data-mk-step="${c}"` : ''}><title>${esc(label)}</title></rect>`;
    if (!r) cells += `<text class="hx-no" x="${fx(x - DH_G / 2 + 8)}" y="${fx(y - DH_G / 2 + 12)}">${c}</text>`;
    if (c === head) cells += `<text class="dh-head-t" x="${fx(x)}" y="${fx(y + DH_G / 2 - 6)}">${esc(T.dohaesu.hz.head)}</text>`;
    if (wave === flow && !r) marks += telWave(x, y, DH_ANG[flow.dir] ?? 0, due(flow));
    if (wave === breath && !r) { const [cx, cy] = dhAt(6); marks += telWave(x, y, Math.atan2(cy + DH_G / 2 + 2 - y, cx + DH_G / 2 + 2 - x), due(breath)); }
  }
  const [rx, ry] = dhAt(6), mid = [rx + DH_G / 2 + 2, ry + DH_G / 2 + 2];
  cells += `<g class="dh-rift ${breath ? 'spin' : ''} ${breath && due(breath) ? 'due' : ''}"><path d="M${fx(mid[0] - 50)} ${fx(mid[1] - 8)} q20 -18 34 -4 t30 -10 t20 14 M${fx(mid[0] - 46)} ${fx(mid[1] + 14)} q18 10 36 0 t32 6"/><circle class="eye" cx="${fx(mid[0])}" cy="${fx(mid[1])}" r="22"/><text x="${fx(mid[0])}" y="${fx(mid[1] + 5)}">${breath ? num(breath) : esc(T.dohaesu.boss.name)}</text></g>`;
  for (const h of hz) {
    if (h.k === 'spray') for (const c of h.cells || []) { const [x, y] = dhAt(Number(c)); marks += `<circle class="dh-spray ${due(h) ? 'due' : ''}" cx="${fx(x)}" cy="${fx(y)}" r="24"/>${tag(x + 20, y - 20, h, 'tide')}`; }
    if (h.k === 'whirl') { const [x, y] = dhAt(Number(h.c)); marks += `<g class="dh-whirl"><circle cx="${fx(x)}" cy="${fx(y)}" r="18"/><path d="M${fx(x)} ${fx(y)} m-10 0 a10 10 0 1 1 10 10 a6 6 0 1 1 -6 -6"/><text x="${fx(x + 19)}" y="${fx(y - 15)}">${esc(String(h.life ?? ''))}</text><title>${esc(T.dohaesu.hz.whirl)}</title></g>`; }
    if (h.k === 'tentacle' && (h.cells || []).length === 2) {
      const [x1, y1] = dhAt(Number(h.cells[0])), [x2, y2] = dhAt(Number(h.cells[1]));
      marks += `<g class="dh-tent ${due(h) ? 'due' : ''}"><line x1="${fx(x1)}" y1="${fx(y1)}" x2="${fx(x2)}" y2="${fx(y2)}"/></g>${tag(x1 + (x2 - x1) * .3, y1 + (y2 - y1) * .3 - 10, h)}`;
    }
  }
  if (headH) { const [x, y] = dhAt(head); marks += `<circle class="dh-headring ${due(headH) ? 'due' : ''}" cx="${fx(x)}" cy="${fx(y)}" r="28"/>${tag(x + 22, y - 22, headH, 'burst')}`; }
  if (b.stun > 0) { const [x, y] = dhAt(head); marks += `<text class="dh-stun" x="${fx(x)}" y="${fx(y - 18)}">${esc(String(b.stun))}</text>`; }
  const top = flow ? `<text class="dh-flow ${flow.k} ${due(flow) ? 'due' : ''}" x="150" y="18">${esc(T.dohaesu.hz[flow.k])} ${DH_ARROW[flow.dir] || ''} ${num(flow)}</text>` : '';
  const wet = b.wet || {}, wmax = Number(b.wet_max || 3);
  const toks = tokens(s, dhAt, (m, x, y) => { const n = Math.min(wmax, Number(wet[m.id] || 0)); return n ? `<g class="dh-wet">${Array.from({ length: n }, (_, i) => `<circle cx="${fx(x - 5 + i * 5)}" cy="${fx(y + 15)}" r="2.4"/>`).join('')}</g>` : ''; });
  let destMark = '';
  if (dest) { const [x, y] = dhAt(dest); destMark = `<rect class="hx-destmark" x="${fx(x - DH_G / 2 + 5)}" y="${fx(y - DH_G / 2 + 5)}" width="${DH_G - 10}" height="${DH_G - 10}" rx="5"/>`; }
  const tent = hz.find(h => h.k === 'tentacle' && (h.cells || []).length === 2 && [h.a, h.b].includes(s.me));
  const lines = [b.mine != null && Number(b.mine) > 0 ? `<b class="${Number(b.mine) >= wmax ? 'bad' : ''}" data-tip="${esc(T.dohaesu.wetTip)}">${esc(T.dohaesu.wet(b.mine))}</b>` : '',
    tent ? esc(T.dohaesu.tent(Math.abs((tent.cells[0] - 1) % 4 - (tent.cells[1] - 1) % 4) + Math.abs(Math.floor((tent.cells[0] - 1) / 4) - Math.floor((tent.cells[1] - 1) / 4)))) : '',
    b.stun > 0 ? esc(T.dohaesu.stun(b.stun)) : '', breath ? `<b class="bad">${esc(T.dohaesu.gim.breath)}</b>` : ''];
  return `<div class="sea-wrap"><svg class="sea-map dh-map" viewBox="0 0 300 310" role="img" aria-label="${esc(T.dohaesu.boss.place)}">${TEL_DEFS}${top}${cells}${marks}${mm.trails.map(t => trailSvg(t, dhAt)).join('')}${toks}${destMark}</svg>
    ${hint(s, live, moveTo, lines)}</div>`;
}

const DU_S = 27, DU_CX = 150, DU_CY = 140;
const DU_D = [[1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1]];
const duQR = (b, c) => (b.cells || [])[c - 1] || [0, 0];
const duRing = (b, c) => { const [q, r] = duQR(b, c); return Math.max(Math.abs(q), Math.abs(r), Math.abs(q + r)); };
function duOpen(b, c) {
  if (c == null || Number(c) === Number(b.center || 10)) return false;
  if (b.gone && duRing(b, c) === 2) return false;
  return !(String(c) in (b.holes || {}));
}
const hexPts = (x, y, r = DU_S - 1.5) => Array.from({ length: 6 }, (_, i) => { const t = Math.PI / 180 * (60 * i - 30); return `${fx(x + r * Math.cos(t))},${fx(y + r * Math.sin(t))}`; }).join(' ');
const DU_SLOT = { tr: [13, -15], tl: [-13, -15], r: [19, 3], l: [-19, 3] }, DU_SLOT_ORDER = ['tr', 'tl', 'r', 'l'];
const duAngD = d => { const [q, r] = DU_D[((d % 6) + 6) % 6]; return Math.atan2(1.5 * r, Math.sqrt(3) * (q + r / 2)); };

function duBoard(s, live, moveTo) {
  const b = s.board || {}, hz = b.hz || [], here = b.my_pos, dest = live ? moveTo : null, center = Number(b.center || 10), round = Number(b.round ?? s.fight?.round ?? 0);
  const at = c => { const [q, r] = duQR(b, c); return [DU_CX + DU_S * Math.sqrt(3) * (q + r / 2), DU_CY + DU_S * 1.5 * r]; };
  const outAng = c => { const [x, y] = at(c); return Math.atan2(y - DU_CY, x - DU_CX); };
  const moves = new Set(live ? seaMoves(s) : []), mm = moved(s), freshCells = mm.fresh;
  const holes = b.holes || {}, cracked = new Set((b.cracked || []).map(Number)), wedges = new Set((b.wedges || []).map(Number)), pulls = b.pulls || {};
  const zone = new Map(), add = (c, k) => zone.set(Number(c), [...(zone.get(Number(c)) || []), k]);
  const pushCell = new Set();
  for (const h of hz) {
    if (['slide', 'weight', 'boulder', 'shave'].includes(h.k)) for (const c of h.cells || []) add(c, `du-${h.k}${due(h) ? ' due' : ''}`);
    if (due(h) && ['slide', 'boulder', 'fist'].includes(h.k)) for (const c of h.cells || []) pushCell.add(Number(c));
  }
  const tilt = hz.find(h => h.k === 'tilt');
  const crowd = {};
  for (const m of s.members || []) if (m.pos != null && !m.out && !seaFell(s, m.id)) crowd[m.pos] = (crowd[m.pos] || 0) + 1;
  const occ = new Set(Object.keys(crowd).map(Number)), packed = new Set([...occ, ...(s.members || []).filter(m => m.pos != null && seaFell(s, m.id)).map(m => Number(m.pos))]);
  const used = new Map([...wedges].filter(c => !packed.has(c)).map(c => [c, new Set(['tl'])]));
  let cells = '', marks = '', tags = '';
  const put = (c, h, cls = '') => {
    const u = used.get(c) || new Set(), k = DU_SLOT_ORDER.find(z => !u.has(z)) || 'tr', [x, y] = at(c), [dx, dy] = DU_SLOT[k], w = (crowd[c] || 0) > 2 ? 1.3 : 1;
    u.add(k); used.set(c, u);
    tags += tag(x + dx * w, y + dy * w, h, cls, 8.5);
  };
  for (let c = 1; c <= (b.cells || []).length; c++) {
    if (c === center) continue;
    const [x, y] = at(c), hk = holes[String(c)], pit = (b.gone && duRing(b, c) === 2) || Number(hk) > 50, hole = hk != null && !pit;
    const push = !pit && !hole && (pushCell.has(c) || (tilt && due(tilt)));
    const cls = ['du-cell', duRing(b, c) === 1 ? 'inner' : 'outer', pit ? 'pit' : hole ? 'hole' : '', ...(pit || hole ? [] : zone.get(c) || []), push ? 'sea-push due' : '', moves.has(c) ? 'mk-step' : '', c === dest ? 'dest' : '', c === here ? 'here' : '', freshCells.has(c) ? 'sea-fell-new' : ''].filter(Boolean).join(' ');
    const label = `${c}번 칸 · ${pit ? T.ttangul.cell.pit : hole ? T.ttangul.cell.hole(hk) : cracked.has(c) ? T.ttangul.cell.cracked : duRing(b, c) === 1 ? T.ttangul.cell.inner : T.ttangul.cell.outer}${wedges.has(c) ? ` · ${T.ttangul.cell.wedge}` : ''}${moves.has(c) ? ' · 눌러서 옮겨 서기' : ''}`;
    cells += `<polygon class="${cls}" ${push ? 'data-push="ground"' : ''} points="${hexPts(x, y)}" ${moves.has(c) || (live && c === here) ? `data-mk-step="${c}"` : ''}><title>${esc(label)}</title></polygon>`;
    if (pit || hole) cells += `<text class="du-hole-t" x="${fx(x)}" y="${fx(y + 4)}">${pit ? '' : esc(String(hk))}</text>`;
    else {
      cells += `<text class="hx-no" x="${fx(x - 13)}" y="${fx(y + 15)}">${c}</text>`;
      if (cracked.has(c)) cells += `<path class="du-crack" d="M${fx(x - 13)} ${fx(y - 6)} l7 4 l4 -6 l6 8 l7 -3"/>`;
      const [wx, wy, ww] = packed.has(c) ? [x - 18, y + 3, 4] : [x - 13, y - 3, 6];
      if (wedges.has(c)) cells += `<g class="du-wedge"><path d="M${fx(wx - ww)} ${fx(wy)} L${fx(wx)} ${fx(wy - ww * 2)} L${fx(wx + ww)} ${fx(wy)}Z"/><title>${esc(T.ttangul.cell.wedge)}</title></g>`;
    }
    if (push) marks += telChev(x, y, tilt && due(tilt) ? duAngD(tilt.dir) : (hz.find(h => due(h) && h.k === 'boulder' && (h.cells || []).includes(c)) ? duAngD(hz.find(h => due(h) && h.k === 'boulder' && (h.cells || []).includes(c)).dir) : outAng(c)), true);
  }
  for (const k of hasMech(s, 'pull') ? Object.keys(pulls) : []) {
    const c = Number(k), [x, y0] = at(c), until = Number(pulls[k] || 0), stopped = until > round, act = hz.find(h => h.k === 'pull' && Number(h.c) === c);
    if (!duOpen(b, c)) continue;
    const r = packed.has(c) ? 5 : 8, y = packed.has(c) ? y0 + 15 : y0 + 11;
    marks += `<g class="du-pull ${act ? 'on' : ''} ${stopped ? 'stopped' : ''} ${act && due(act) ? 'due' : ''}"><circle cx="${fx(x)}" cy="${fx(y)}" r="${r}"/><path d="M${fx(x - r + 2)} ${fx(y)}H${fx(x + r - 2)}M${fx(x)} ${fx(y - r + 2)}V${fx(y + r - 2)}"/><title>${esc(stopped ? T.ttangul.cell.stopped(until - round) : T.ttangul.cell.pull)}</title></g>`;
    if (act) put(c, act, 'burst');
    else if (stopped) { const [dx, dy] = DU_SLOT.r; marks += `<text class="du-stop-t" x="${fx(x + dx)}" y="${fx(y0 + dy + 4)}">${esc(String(until - round))}</text>`; }
  }
  for (const h of hz) {
    if (h.k === 'slide' && h.cells?.length) put(Number(h.cells[0]), h);
    if (h.k === 'weight') for (const c of h.cells || []) { const [x, y] = at(Number(c)); marks += `<polygon class="du-weight-mark ${due(h) ? 'due' : ''}" points="${hexPts(x, y, DU_S - 7)}"/>`; put(Number(c), h, 'burst'); }
    if (h.k === 'boulder' && h.cells?.length) {
      const [x1, y1] = at(Number(h.cells[0])), [x2, y2] = at(Number(h.cells[h.cells.length - 1]));
      marks += `<g class="du-boulder ${due(h) ? 'due' : ''}"><line x1="${fx(x1)}" y1="${fx(y1)}" x2="${fx(x2)}" y2="${fx(y2)}"/></g>`;
      if (!due(h)) for (const c of h.cells) { const [x, y] = at(Number(c)); marks += telChev(x, y, duAngD(h.dir), false); }
      put(Number(h.cells[0]), h);
    }
    if (h.k === 'fist' && h.cells?.length) { const [x, y] = at(Number(h.cells[0])); marks += `<circle class="du-fist ${due(h) ? 'due' : ''}" cx="${fx(x)}" cy="${fx(y)}" r="20"/>`; put(Number(h.cells[0]), h); }
  }
  const shave = hz.find(h => h.k === 'shave');
  const core = `<g class="du-core ${tilt ? 'due' : ''}"><polygon points="${hexPts(DU_CX, DU_CY, DU_S - 2)}"/><text x="${DU_CX}" y="${DU_CY + 4}">${shave ? num(shave) : esc(T.ttangul.boss.name)}</text></g>`;
  const carry = b.carry || {};
  const toks = tokens(s, at, (m, x, y) => Number(carry[m.id] || 0) > 0 ? `<path class="du-carry" d="M${fx(x + 8)} ${fx(y + 10)} L${fx(x + 12.5)} ${fx(y + 2)} L${fx(x + 17)} ${fx(y + 10)}Z"/>` : '');
  let destMark = '';
  if (dest) { const [x, y] = at(dest); destMark = `<polygon class="hx-destmark" points="${hexPts(x, y, DU_S - 6)}"/>`; }
  const lines = [Number(b.mine || 0) > 0 ? `<b>${esc(T.ttangul.gim.carry)}</b>` : '', pushCell.size || (tilt && due(tilt)) ? esc(T.ttangul.gim.brace) : '', Number(b.final || 0) > 0 || tilt ? `<b class="bad">${esc(T.ttangul.gim.final(Number(b.final || 0) + (tilt ? 1 : 0)))}</b>` : '',
    shave ? `<b class="bad">${esc(T.ttangul.hz.shave)} ${num(shave)}</b>` : ''];
  return `<div class="sea-wrap"><svg class="sea-map du-map" viewBox="18 20 264 244" role="img" aria-label="${esc(T.ttangul.boss.place)}">${TEL_DEFS}${cells}${marks}${core}${mm.trails.map(t => trailSvg(t, at)).join('')}${toks}${tags}${destMark}</svg>
    ${hint(s, live, moveTo, lines)}</div>`;
}

export const seaBoard = (s, live, moveTo) => s.boss === 'dohaesu' ? dhBoard(s, live, moveTo) : duBoard(s, live, moveTo);

export function seaGim(s, me, a, moveTo) {
  if (!seaOn(s) || me.out || seaFell(s, me.id)) return '';
  const b = s.board || {}, at = moveTo || b.my_pos;
  if (s.boss === 'dohaesu') {
    const G = T.dohaesu.gim, head = Number(b.head), ok = Number(at) === head;
    return `<div class="gw-gim sea-gim"><span class="gw-gim-h" title="${esc(C.gimTip(G.head))}">${icon('bell', 13)}<b>${esc(G.head)}</b></span>
      <button class="btn ${a?.a === 'guide' ? 'on' : ''}" data-gw="guide" ${ok ? '' : 'disabled'} title="${esc(ok ? G.guide(head) : G.off(head))}">${icon('flag', 16)}<span>${esc(T.dohaesu.act.guide)}${ok ? ` · ${head}번 칸` : ''}</span></button>
    </div>`;
  }
  if (!hasMech(s, 'pull')) return '';
  const G = T.ttangul.gim, has = Number(b.mine || 0) > 0, onPull = at != null && String(at) in (b.pulls || {});
  const ok = has && onPull;
  return `<div class="gw-gim sea-gim"><span class="gw-gim-h" title="${esc(C.gimTip(G.head))}">${icon('bell', 13)}<b>${esc(G.head)}</b></span>
    <button class="btn ${a?.a === 'stop' ? 'on' : ''}" data-gw="stop" ${ok ? '' : 'disabled'} title="${esc(!has ? G.noWedge : !onPull ? G.noPull : G.stop(at))}">${icon('close', 16)}<span>${esc(T.ttangul.act.stop)}${ok ? ` · ${at}번 칸` : ''}</span></button>
  </div>`;
}

export function seaMemTag(s, m) {
  if (!seaOn(s)) return '';
  if (seaFell(s, m.id)) return `<b class="bad">${esc(C.fell)}</b>`;
  const out = [m.pos != null ? `${m.pos}번 칸` : ''];
  if (s.boss === 'dohaesu' && Number(m.val || 0) > 0) out.push(`<b class="${Number(m.val) >= Number(s.board?.wet_max || 3) ? 'warn' : ''}">${esc(T.dohaesu.wet(m.val))}</b>`);
  if (s.boss === 'ttangul' && Number(m.val || 0) > 0) out.push(`<b>${esc(T.ttangul.gim.carry)}</b>`);
  return out.filter(Boolean).join(' · ');
}

export const seaState = (s, m) => seaFell(s, m.id) ? C.fellLong : null;
