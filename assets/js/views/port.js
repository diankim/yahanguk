import { rpc, act, store, esc, icon, $, $$, toast, ask, openLayer, fmt, guard, bar, on, nameOf } from '../core.js';
import { loading, errorBox, panel, load } from './common.js';
import { qtyHtml, bindQty, qtyOf } from './itempick.js';
import { helpQ } from '../tips.js';
import { TRADE } from '../rules.js';
import { baseOf, hqCount } from '../hq.js';
import { SHIP_ART, SHIP_PAL, SHIP_MS } from '../ship_art.js';

let el = null, v = null, want = null, pick = null, mode = 'direct', party = false, bonus = 'time', timer = null, offs = [], busy = false, reTry = 0, stg = null;
const frames = new Map();

export async function render(root, sub) {
  el = root; want = sub || null; pick = null; v = null;
  el.innerHTML = head('항구') + loading();
  el.addEventListener('click', onClick);
  offs.push(on('changed', ev => { if (el && /^world_notice$|^world_travel_party_notice$/.test(ev?.name || '')) reload(); }));
  window.addEventListener('yahang:arrived', onArrive);
  await reload();
}
export function destroy() { clearInterval(timer); timer = null; offs.forEach(f => f()); offs = []; window.removeEventListener('yahang:arrived', onArrive); el = null; }
const onArrive = () => { want = null; pick = null; reload(); };

const head = (title, sub = '', actions = '') => `<div class="view-head"><div><p class="eyebrow">${icon('ship', 14)} 항구${sub ? ` · ${esc(sub)}` : ''}</p><h1>${esc(title)}</h1></div><div class="head-actions">${actions}</div></div>`;

async function reload() {
  if (!el) return;
  try {
    const [r, s] = await Promise.all([rpc('world_trade_view', { p_port: want }), load('world_storage_snapshot', undefined, { maxAge: 300000 }).catch(() => null)]);
    if (!el) return;
    v = r; stg = s;
    if (!pick || pick === v.here) pick = v.port && v.port !== v.here ? v.port : null;
    if (pick && pick !== v.port) return showOther();
    if (pick) v._other = { board: v.board, seen_at: v.seen_at };
    draw();
  } catch (e) { if (el) el.innerHTML = head('항구') + errorBox(e.message); }
}

const portName = k => TRADE.port(k)?.name || nameOf(k) || k;
const goodName = k => TRADE.goods?.[k]?.name || TRADE.foods?.[k]?.name || nameOf(k);
const hold = () => v.hold || [];
const holdOf = k => hold().find(h => h.good === k);
const priceOf = k => (v.live ? (v.board || []).find(b => b.good === k) : null);
function why() {
  if (!v.here) return TRADE.away;
  if (!v.ship) return '아직 배가 없습니다.';
  if (v.ship.status !== 'docked') return '배가 물길에 나가 있습니다.';
  if (v.ship.port !== v.here) return `배는 ${v.ship.port_name}에 대 있습니다. 그 항구에서 하세요.`;
  return '';
}
const off = w => w ? `disabled title="${esc(w)}"` : '';
function roomFor(k) {
  const s = v.ship; if (!s) return 0;
  const n = TRADE.slot_n || 10, q0 = holdOf(k)?.qty || 0, other = s.used - Math.ceil(q0 / n);
  return Math.max(0, (s.slots - other) * n - q0);
}

function shipCanvas(tier, cls = '') { return `<canvas class="tr-ship ${cls}" data-ship="${Math.max(1, Math.min(5, tier || 1)) - 1}" aria-label="${esc(TRADE.ship(tier)?.name || '배')}"></canvas>`; }
function frameCanvas(si, f) {
  const key = si + ':' + f; if (frames.has(key)) return frames.get(key);
  const s = SHIP_ART[si], c = document.createElement('canvas'); c.width = s.w; c.height = s.h;
  const x = c.getContext('2d'), im = x.createImageData(s.w, s.h), d = im.data;
  s.f[f].forEach((ri, y) => { const row = s.rows[ri]; for (let i = 0; i < row.length; i++) { const ch = row[i]; if (ch === '.') continue; const n = parseInt(SHIP_PAL[ch].slice(1), 16), p = (y * s.w + i) * 4; d[p] = n >> 16 & 255; d[p + 1] = n >> 8 & 255; d[p + 2] = n & 255; d[p + 3] = 255; } });
  x.putImageData(im, 0, 0); frames.set(key, c); return c;
}
const still = () => { try { return matchMedia('(prefers-reduced-motion: reduce)').matches; } catch { return false; } };
let fNo = 0, fAt = 0;
function paintShips(force) {
  if (!el) return;
  const t = Date.now();
  if (!force && (still() || document.hidden || t - fAt < SHIP_MS)) return;
  if (!force) { fAt = t; fNo++; }
  for (const cv of $$('canvas[data-ship]', el)) {
    const si = Number(cv.dataset.ship), s = SHIP_ART[si], f = cv.classList.contains('still') || still() ? 0 : fNo % s.f.length;
    if (cv.width !== s.w) { cv.width = s.w; cv.height = s.h; }
    const x = cv.getContext('2d'); x.clearRect(0, 0, s.w, s.h); x.drawImage(frameCanvas(si, f), 0, 0);
  }
}

function band() {
  const b = v.brief; if (!b) return '';
  const out = [], vy = b.voyage, me = store.user?.id;
  if (vy?.status === 'sail' && vy.mode === 'direct') out.push(`<div class="notice tr-band">${icon('ship', 18)}<div><b>${esc(vy.from_name)} → ${esc(vy.to_name)} 항해 중</b><span><em data-tr-left="${new Date(vy.arrives_at).getTime()}">${esc(TRADE.leftText(new Date(vy.arrives_at) - Date.now()))}</em>${vy.mates ? ` · 함께 탄 사람 ${vy.crew.map(c => esc(c.name)).join(', ')}` : ''}${vy.bonus ? ` · 덤: ${esc(TRADE.bonus?.[vy.bonus]?.name || '')}` : ''}</span></div></div>`);
  if (vy?.status === 'raid') out.push(`<div class="notice bad tr-band">${icon('sword', 18)}<div><b>뱃길 습격 · ${esc(vy.to_name)}로 가는 길</b><span>${esc(TRADE.raidText)}</span></div>${vy.fight_id ? `<a class="btn small primary" href="#/pfight/${esc(vy.fight_id)}">싸움으로</a>` : ''}</div>`);
  if (vy?.status === 'board' && vy.captain === me) out.push(`<div class="notice tr-band">${icon('users', 18)}<div><b>${esc(vy.to_name)}(으)로 띄울 준비</b><span><em data-tr-board="${new Date(vy.board_ends).getTime()}">${esc(TRADE.boardText(new Date(vy.board_ends) - Date.now()))}</em> · ${(vy.board || []).map(x => `${esc(x.name)} ${x.status === 'accepted' ? '함께 탐' : x.status === 'declined' ? '사양' : '답 기다림'}`).join(' · ')}</span></div>
    <button class="btn small primary" data-tr="depart" data-id="${esc(vy.id)}">지금 떠나기</button><button class="btn small" data-tr="bcancel" data-id="${esc(vy.id)}">그만두기</button></div>`);
  for (const x of b.invites || []) out.push(`<div class="notice tr-band">${icon('ship', 18)}<div><b>${esc(x.captain_name)}의 배 · ${esc(x.to_name)}행</b><span>함께 타자고 합니다${x.bonus ? ` · 덤: ${esc(TRADE.bonus?.[x.bonus]?.name || '')}` : ''} · <em data-tr-invite="${new Date(x.board_ends).getTime()}">${esc(TRADE.inviteText(new Date(x.board_ends) - Date.now()))}</em></span></div>
    <button class="btn small primary" data-tr="board" data-id="${esc(x.id)}" data-acc="1">함께 타기</button><button class="btn small" data-tr="board" data-id="${esc(x.id)}" data-acc="0">사양</button></div>`);
  for (const x of b.sends || []) out.push(`<div class="notice tr-band">${icon('ship', 18)}<div><b>보낸 배 · ${esc(x.from_name)} → ${esc(x.to_name)}</b><span><em data-tr-left="${new Date(x.arrives_at).getTime()}">${esc(TRADE.leftText(new Date(x.arrives_at) - Date.now()))}</em> · 닿으면 짐이 그 항구에서 팔립니다</span></div></div>`);
  return out.join('');
}

function tagChips(tags, live) {
  return (tags || []).filter(t => TRADE.tags[t]).map(t => `<span class="tr-tag t-${t}" data-tip="${esc(TRADE.tagTip[t])}">${esc(t === 'event' && live ? `${v.demand?.name || ''} ${TRADE.tags.event}` : TRADE.tags[t])}</span>`).join('');
}
function boardPanel() {
  const at = pick || v.port, live = v.live && !pick, rows = pick ? v._other?.board : v.board;
  const seenAt = live ? null : pick ? v._other?.seen_at : v.seen_at;
  const title = at ? `${portName(at)} 시세판` : '시세판';
  const sub = !at ? TRADE.away : live ? '오늘 값 · 한국 시각 0시에 바뀜 · 지금 보는 값' : seenAt ? `마지막으로 들렀을 때 본 값 · ${fmt.ago(seenAt)}` : `${TRADE.seenNone} · 그 항구에 가면 값이 보입니다`;
  const w = why();
  if (!at) return panel('시세판', `<p class="muted small tr-sub">${esc(v.brief?.voyage?.status === 'sail' ? '물길 위에서는 시세판을 볼 수 없습니다. 「다른 항구」에서 들렀던 항구를 누르면 그때 본 값이 보입니다.' : TRADE.away)}</p>`, { ico: 'scroll', cls: 'tr-p-board', extra: helpQ(TRADE.help, '교역선') });
  const list = rows || Object.entries(TRADE.goods || {}).map(([k, g]) => ({ good: k, name: g.name, base: g.base })).sort((a, b) => a.base - b.base);
  const body = `<p class="muted small tr-sub">${esc(sub)}</p>
    ${pick ? `<div class="btn-row tr-tabs"><button class="chip" data-tr="here">${icon('back', 13)} ${esc(v.here ? portName(v.here) : '이 항구')}로 돌아가기</button></div>` : ''}
    <table class="tr-board"><thead><tr><th>교역품</th><th>정가</th><th>${live ? '오늘' : '본 값'}</th><th>${live ? '어제보다' : ''}</th>${live ? '<th></th>' : ''}</tr></thead><tbody>
    ${list.map(r => { const h = holdOf(r.good), known = r.price != null;
      return `<tr class="${h ? 'mine' : ''}"><td><b>${esc(r.name || goodName(r.good))}</b>${tagChips(r.tags, live)}${h ? `<small class="tr-have">짐칸 ${h.qty}</small>` : ''}</td><td>${r.base ?? ''}</td><td><b>${known ? r.price : '?'}</b></td>
        <td>${live && r.pct != null ? (r.pct > 0 ? `<span class="tr-up">▲ ${r.pct}%</span>` : r.pct < 0 ? `<span class="tr-down">▼ ${-r.pct}%</span>` : '<span class="muted">—</span>') : ''}</td>
        ${live ? `<td>${r.buy != null ? `<button class="btn small primary" data-tr="buy" data-good="${esc(r.good)}" data-here="교역품 싣기" ${off(w)}>사기 ${r.buy}전</button>` : ''}</td>` : ''}</tr>`; }).join('')}
    </tbody></table>
    ${live ? `<p class="muted small">「찾는 물건」은 ${TRADE.seek?.days || 3}일마다 바뀝니다${v.demand?.port_name ? ` · 오늘 ${esc(v.demand.port_name)}에 ${esc(v.demand.name)}` : ''}</p>` : ''}`;
  return panel(title, body, { ico: 'scroll', cls: 'tr-p-board', extra: helpQ(TRADE.help, '교역선') });
}

function portsPanel() {
  const rows = (v.ports || []).filter(p => p.id !== v.here);
  const body = `<ul class="tr-ports">${rows.map(p => { const sel = pick === p.id, route = p.direct_min != null;
    return `<li class="${sel ? 'on' : ''}${p.open ? '' : ' shut'}"><button type="button" data-tr="pick" data-port="${esc(p.id)}">
      <span class="tr-pn"><b>${esc(p.name)}</b>${p.shipyard ? '<span class="tr-tag">조선소</span>' : ''}${p.realm !== 'main' ? '<span class="tr-tag t-far">건넛누리</span>' : ''}</span>
      <small>${esc(goodName(p.good))} 산지 · Lv.${p.lv ?? '?'}${p.open ? '' : ' · 아직 못 감'}</small>
      <small>${route ? `타고 가면 ${p.direct_min}분 · 보내면 ${p.send_min}분` : '뱃길 없음'}</small>
      <small class="${p.seen_at ? '' : 'muted'}">${p.seen_at ? `시세 ${fmt.ago(p.seen_at)} 봄` : TRADE.seenNone}</small></button></li>`; }).join('')}</ul>`;
  return panel('다른 항구', body, { ico: 'map', cls: 'tr-p-ports' });
}

function shipPanel() {
  const s = v.ship;
  if (!s) {
    const yard = v.here && TRADE.port(v.here)?.shipyard;
    const yards = Object.values(TRADE.ports || {}).filter(p => p.shipyard).map(p => p.name).join('·');
    return panel('내 배', `${shipCanvas(1, 'still ghost')}<p class="muted small">${yard ? `${esc(TRADE.ship(1)?.name)}를 받아 교역을 시작하세요.` : `조선소가 있는 항구(${esc(yards)})에서 ${esc(TRADE.ship(1)?.name)}를 받습니다.`}</p>
      ${yard ? `<button class="btn primary" data-tr="get" data-here="배 받기">${icon('ship', 15)} ${esc(TRADE.ship(1)?.name)} 받기</button>` : ''}`, { ico: 'ship', cls: 'tr-p-ship' });
  }
  const w = why(), rg = TRADE.dur?.repair_gil || 2;
  const body = `<div class="tr-shipbox">${shipCanvas(s.tier)}</div>
    <div class="tr-shipname"><b>${esc(s.name)}</b>${s.name !== s.kind ? `<small>${esc(s.kind)}</small>` : ''}<button class="btn small ghost" data-tr="rename">${icon('scroll', 13)} 이름</button></div>
    <dl class="kv"><div><dt>있는 곳</dt><dd>${s.status === 'docked' ? esc(s.port_name) : '물길 위'}</dd></div>
      <div><dt>짐칸</dt><dd>${s.used} / ${s.slots}칸 <small class="muted">(한 칸 ${TRADE.slot_n}개)</small></dd></div>
      <div><dt>태울 사람</dt><dd>${s.crew}명</dd></div>
      <div><dt>뱃길 시간</dt><dd>${s.speed < 1 ? `${Math.round((1 - s.speed) * 100)}% 빠름` : '나룻배 기준'}</dd></div>
      <div><dt>내구도</dt><dd>${s.broken ? '<b class="tr-down">부서짐</b> · ' : ''}${s.durability} / ${s.max}</dd></div></dl>
    ${bar(s.durability, s.max, s.durability <= s.max / 4 ? 'hp' : 'st')}
    ${s.durability < s.max ? `<div class="btn-row"><button class="btn small ${s.broken ? 'primary' : ''}" data-tr="repair" data-here="배 고치기" ${off(w)}>${icon('wrench', 14)} 고치기 ${fmt.jeon(s.repair_gil)}</button>${helpQ(TRADE.repairTip(rg), '배 고치기')}</div>` : ''}`;
  return panel('내 배', body, { ico: 'ship', cls: 'tr-p-ship' });
}

function invFoods() {
  const inv = store.character?.inventory || {};
  return Object.keys(inv).filter(k => Number(inv[k]) > 0 && TRADE.foods?.[baseOf(k)]).map(k => ({ id: k, n: Number(inv[k]), name: TRADE.foods[baseOf(k)].name + (k !== baseOf(k) ? ' (우수)' : '') }));
}
function holdPanel() {
  if (!v.ship) return '';
  const w = why(), d = v.day || { used: 0, cap: TRADE.day_cap }, leftBase = Math.max(0, d.cap - d.used);
  const sp = v.ship.sell_port === v.here && v.ship.sell_pct ? v.ship.sell_pct : 0;
  const rows = hold().map(h => { const p = priceOf(h.good), unit = p ? Math.round(p.price * (1 + sp / 100)) : null, cap = Math.min(h.qty, Math.floor(leftBase / Math.max(1, h.base)));
    return `<li><div><b>${esc(h.name)}</b>${h.food ? '<span class="tr-tag">특선 음식</span>' : ''}<small>${h.qty}개 · 산 값 ${fmt.jeon(h.cost)}${h.qty ? ` (하나 ${Math.round(h.cost / h.qty)}전)` : ''}</small>
      <small>${unit != null ? `여기서 하나 ${unit}전 · 다 팔면 약 ${fmt.jeon(unit * h.qty)}` : h.food ? '파는 값은 팔 때 이 항구 시세로 정해집니다' : v.live ? '' : '이 항구에서 팔 때 값이 정해집니다'}</small></div>
      ${qtyHtml({ key: h.good, max: w ? 0 : cap, value: 0, all: true, small: true, label: `${h.name} 팔 수량`, off: !!w })}</li>`; }).join('');
  const foods = invFoods();
  const body = `<div class="tr-day"><span>오늘 판 몫 <b>${fmt.num(d.used)}</b> / ${fmt.num(d.cap)}전 <small class="muted">(정가 기준)</small></span>${helpQ(TRADE.dayTip(d.cap), '하루 판매 몫')}</div>${bar(d.used, d.cap, 'xp')}
    ${sp ? `<p class="hint good small">함께 흥정 덤 · 이 항구에서 팔 때 +${sp}%</p>` : ''}
    ${rows ? `<ul class="tr-hold">${rows}</ul><div class="btn-row tr-sellrow"><span class="muted small" id="tr-sell-sum"></span><button class="btn primary" data-tr="sell" data-here="교역품 팔기" ${off(w || (leftBase <= 0 ? '오늘 팔 수 있는 몫이 찼습니다. 한국 시각 0시에 다시 찹니다.' : ''))}>${icon('coin', 15)} 고른 짐 팔기</button></div>` : '<p class="muted small">짐칸이 비었습니다. 산지 항구의 시세판에서 교역품을 사서 실으세요.</p>'}
    ${foods.length ? `<h3 class="sub-h">가방의 세력 특선 음식 ${helpQ(TRADE.foodTip, '특선 음식 싣기')}</h3><ul class="tr-food">${foods.map(f => `<li><b>${esc(f.name)}</b><small>${f.n}개 · 정가 ${TRADE.foods[baseOf(f.id)]?.base ?? '?'}전</small><button class="btn small" data-tr="load" data-item="${esc(f.id)}" data-here="짐 싣기" ${off(w)}>싣기</button></li>`).join('')}</ul>` : ''}`;
  return panel(`짐칸 ${v.ship.used}/${v.ship.slots}`, body, { ico: 'chest', cls: 'tr-p-hold' });
}

function sailPanel() {
  if (!v.ship) return '';
  const w = why(), to = pick && v.ports.find(p => p.id === pick), tk = TRADE.sail?.tokens ?? 2;
  const vy = v.brief?.voyage;
  const block = w || (v.ship.broken ? '배가 부서져 고치기 전에는 띄울 수 없습니다.' : '') || (vy && ['board', 'sail', 'raid'].includes(vy.status) ? '이미 띄우려는 배가 있습니다.' : '')
    || (v.tokens < tk ? `노정패가 모자랍니다. 필요 ${tk}개 / 가진 ${v.tokens}개.` : '')
    || (!to ? '「다른 항구」에서 갈 곳을 고르세요.' : to.direct_min == null ? '두 항구 사이에 뱃길이 없습니다.' : !to.open ? `${to.name}은(는) 아직 갈 수 없습니다(Lv.${to.lv}).` : '');
  const mins = to ? (mode === 'direct' ? to.direct_min : to.send_min) : null;
  const body = `<p class="tr-to">${to ? `<b>${esc(to.name)}</b>${mins != null ? ` · ${mode === 'direct' ? '타고 가면' : '보내면'} 약 ${mins}분` : ''}` : '<span class="muted">갈 곳을 고르세요</span>'}</p>
    <div class="seg-mini" role="tablist">${['direct', 'send'].map(k => `<button type="button" class="${mode === k ? 'on' : ''}" data-tr="mode" data-mode="${k}">${esc(TRADE.modeName[k])}</button>`).join('')}</div>
    <p class="muted small">${esc(TRADE.modeTip[mode])}</p>
    ${mode === 'direct' ? `<label class="tr-check"><input type="checkbox" data-tr-party ${party ? 'checked' : ''}><span>같은 항구의 파티원 태우기 ${helpQ(TRADE.boardTip, '함께 타기')}</span></label>
      ${party ? `<div class="tr-bonus">${['time', 'guard', 'haggle'].map(k => `<label class="${bonus === k ? 'on' : ''}"><input type="radio" name="tr-bonus" value="${k}" ${bonus === k ? 'checked' : ''}><b>${esc(TRADE.bonus?.[k]?.name || k)}</b><small>${esc(TRADE.bonusTip(k))}</small></label>`).join('')}</div>` : ''}` : ''}
    <div class="btn-row"><span class="muted small">노정패 ${tk}개 · 가진 ${fmt.num(v.tokens)}개</span><button class="btn primary" data-tr="sail" data-here="배 띄우기" ${off(block)}>${icon('ship', 15)} 배 띄우기</button></div>
    ${block && to ? `<p class="hint warn small">${esc(block)}</p>` : ''}`;
  return panel('배 띄우기', body, { ico: 'route', cls: 'tr-p-sail' });
}

function have(k) {
  const inv = store.character?.inventory || {}, st = stg?.use_here ? Object.fromEntries((stg.items || []).map(i => [i.item_id, Number(i.qty) || 0])) : {};
  return hqCount(inv, k) + hqCount(st, k);
}
function yardPanel() {
  const s = v.ship, yard = v.here && TRADE.port(v.here)?.shipyard;
  const ladder = `<ol class="tr-ladder">${(TRADE.ships || []).map(x => `<li class="${s && x.tier === s.tier ? 'on' : s && x.tier < s.tier ? 'done' : ''}">${shipCanvas(x.tier, 'still')}<b>${esc(x.name)}</b><small>짐칸 ${x.slots} · ${x.crew}명${x.lv > 1 ? ` · Lv.${x.lv}` : ''}</small></li>`).join('')}</ol>`;
  if (!s) return panel('조선소', ladder, { ico: 'hammer', cls: 'tr-p-yard' });
  const p = v.parts;
  if (!p) return panel('조선소', `${ladder}<p class="muted small">가장 큰 배입니다.</p>`, { ico: 'hammer', cls: 'tr-p-yard' });
  const w = why() || (yard ? '' : '조선소가 있는 항구에서만 배를 지을 수 있습니다.'), lvOk = (v.level || 0) >= p.lv, gilOk = (v.gil || 0) >= p.gil;
  const cats = Object.entries(p.cats || {}).map(([ck, c]) => {
    const items = Object.entries(c.items || {}), need = items.reduce((a, [, i]) => a + i.need, 0), got = items.reduce((a, [, i]) => a + i.have, 0);
    const can = items.some(([k, i]) => i.have < i.need && have(k) > 0);
    return `<li class="${got >= need ? 'full' : ''}"><div class="tr-cat"><b>${esc(c.name)}</b><small>${got} / ${need}</small><button class="btn small" data-tr="part" data-cat="${esc(ck)}" data-here="조선 재료 넣기" ${off(w || (got >= need ? '이 갈래는 다 찼습니다.' : !can ? '넣을 재료가 가방·창고에 없습니다.' : ''))}>넣기</button></div>${bar(got, need, 'st')}
      <small class="tr-items">${items.map(([k, i]) => `<span class="${i.have >= i.need ? 'ok' : ''}">${esc(i.name)} ${i.have}/${i.need}${i.have < i.need ? ` <em class="muted">(가진 ${have(k)})</em>` : ''}</span>`).join(' · ')}</small></li>`; }).join('');
  const body = `${ladder}<h3 class="sub-h">다음 배 · ${esc(p.name)} ${helpQ(TRADE.yardTip, '조선소')}</h3>
    <p class="tr-req"><span class="${lvOk ? 'ok' : 'bad'}">Lv.${p.lv}</span> · <span class="${gilOk ? 'ok' : 'bad'}">${fmt.jeon(p.gil)}</span></p>
    <ul class="tr-cats">${cats}</ul>
    <div class="btn-row"><button class="btn primary" data-tr="upgrade" data-here="배 짓기" ${off(w || (!p.done ? '아직 넣지 않은 재료가 있습니다.' : !lvOk ? `Lv.${p.lv}부터 지을 수 있습니다.` : !gilOk ? `전이 모자랍니다(필요 ${fmt.jeon(p.gil)}).` : ''))}>${icon('hammer', 15)} ${esc(p.name)} 짓기</button></div>`;
  return panel('조선소', body, { ico: 'hammer', cls: 'tr-p-yard' });
}

function draw() {
  if (!el || !v) return;
  const title = v.here ? `${portName(v.here)} 항구` : '항구';
  const sub = v.here ? TRADE.port(v.here)?.dock || '' : '';
  el.innerHTML = head(title, sub, `<span class="tr-gil">${icon('coin', 14)} ${fmt.jeon(v.gil)}</span>${helpQ(TRADE.help, '교역선')}`) + band()
    + (!v.here && !v.ship ? `<p class="hint">${esc(TRADE.away)}</p>` : '')
    + `<div class="tr-wrap"><div class="tr-col">${boardPanel()}${portsPanel()}</div><div class="tr-col">${shipPanel()}${holdPanel()}${sailPanel()}${yardPanel()}</div></div>`;
  bindQty(el, () => sellSum());
  sellSum();
  const pc = $('[data-tr-party]', el); if (pc) pc.onchange = () => { party = pc.checked; draw(); };
  $$('input[name="tr-bonus"]', el).forEach(r => r.onchange = () => { bonus = r.value; draw(); });
  paintShips(true);
  clearInterval(timer); timer = setInterval(tick, 250);
}
function sellSum() {
  const box = $('#tr-sell-sum', el); if (!box) return;
  let n = 0, g = 0, base = 0;
  const sp = v.ship?.sell_port === v.here ? v.ship.sell_pct || 0 : 0;
  for (const h of hold()) { const q = qtyOf(el, h.good); if (!q) continue; n += q; base += q * h.base; const p = priceOf(h.good); if (p) g += Math.round(p.price * (1 + sp / 100)) * q; }
  box.textContent = n ? `${n}개 · 정가 몫 ${fmt.num(base)}전${g ? ` · 약 ${fmt.jeon(g)}` : ''}` : '';
}
function tick() {
  if (!el || !v) return;
  paintShips(false);
  const t = Date.now();
  for (const e of $$('[data-tr-left]', el)) e.textContent = TRADE.leftText(Number(e.dataset.trLeft) - t);
  for (const e of $$('[data-tr-board]', el)) e.textContent = TRADE.boardText(Number(e.dataset.trBoard) - t);
  for (const e of $$('[data-tr-invite]', el)) e.textContent = TRADE.inviteText(Number(e.dataset.trInvite) - t);
  const b = v.brief, due = [b?.voyage?.check_at, ...(b?.sends || []).map(x => x.check_at), ...(b?.invites || []).map(x => x.board_ends)].filter(Boolean).some(x => new Date(x).getTime() <= t);
  if (due && t - reTry > 6000) { reTry = t; reload(); }
}

async function run(name, args, btn, after) {
  if (busy) return; busy = true;
  try { const r = await guard(btn, () => act(name, args)); if (r) { await after?.(r); await reload(); } return r; } finally { busy = false; }
}

async function onClick(e) {
  const b = e.target.closest?.('[data-tr]'); if (!b || !el?.contains(b) || b.disabled || b.classList.contains('here-locked')) return;
  const k = b.dataset.tr;
  if (k === 'pick') { pick = pick === b.dataset.port ? null : b.dataset.port; return showOther(); }
  if (k === 'here') { pick = null; want = null; return draw(); }
  if (k === 'mode') { mode = b.dataset.mode; return draw(); }
  if (k === 'get') return run('world_trade_ship_get', {}, b);
  if (k === 'rename') return rename();
  if (k === 'repair') { if (!(await ask(`배를 끝까지 고칩니다. ${fmt.jeon(v.ship.repair_gil)}이 듭니다.`, { title: '배 고치기', ok: '고치기' }))) return; return run('world_trade_repair', { p_points: null }, b); }
  if (k === 'buy') return buy(b.dataset.good);
  if (k === 'load') return loadFood(b.dataset.item);
  if (k === 'sell') return sell(b);
  if (k === 'sail') return sail(b);
  if (k === 'part') return putPart(b.dataset.cat, b);
  if (k === 'upgrade') { const p = v.parts; if (!(await ask(`${p.name}을(를) 짓습니다. ${fmt.jeon(p.gil)}이 들고, 넣은 재료는 모두 배에 쓰입니다. 짐칸의 짐은 그대로 옮겨 싣습니다.`, { title: '배 짓기', ok: '짓기' }))) return; return run('world_trade_ship_upgrade', {}, b); }
  if (k === 'board') return run('world_trade_board_respond', { p_voyage: b.dataset.id, p_accept: b.dataset.acc === '1' }, b);
  if (k === 'depart') return run('world_trade_depart', { p_voyage: b.dataset.id, p_bonus: null }, b, r => { if (r?.why) toast(r.why, 'error'); });
  if (k === 'bcancel') { if (!(await ask('배 띄우기를 그만둘까요? 함께 타기로 한 동료에게도 알립니다.', { title: '그만두기', ok: '그만두기', danger: true }))) return; return run('world_trade_board_cancel', { p_voyage: b.dataset.id }, b); }
}

async function showOther() {
  if (!pick) return draw();
  const p = v.ports.find(x => x.id === pick);
  if (!p?.seen_at) { v._other = { board: null, seen_at: null }; return draw(); }
  try { const r = await rpc('world_trade_view', { p_port: pick }); if (!el) return; v._other = { board: r.board, seen_at: r.seen_at }; } catch (e) { toast(e.message, 'error'); }
  draw();
}

function qtyLayer({ title, line, max, okText, onOk }) {
  const L = openLayer({ title, body: `<p class="muted small">${esc(line)}</p>${qtyHtml({ key: 'n', max, value: Math.min(max, 10), min: 1, all: true })}<p class="muted small" data-sum></p><div class="btn-row"><button class="btn primary" data-ok>${esc(okText)}</button></div>` });
  const upd = () => { const n = qtyOf(L, 'n'); $('[data-sum]', L).textContent = onOk.sum ? onOk.sum(n) : ''; };
  bindQty(L, upd); upd();
  $('[data-ok]', L).onclick = async () => { const n = qtyOf(L, 'n'); if (!n) return; L.close(); await onOk(n); };
}
function buy(good) {
  const r = (v.board || []).find(x => x.good === good); if (!r) return;
  const max = Math.min(roomFor(good), Math.floor((v.gil || 0) / Math.max(1, r.buy)));
  if (max <= 0) return toast(roomFor(good) <= 0 ? '짐칸에 자리가 없습니다.' : '전이 모자랍니다.', 'error');
  const f = n => run('world_trade_buy', { p_good: good, p_qty: n }, null);
  f.sum = n => `${n}개 · ${fmt.jeon(n * r.buy)}`;
  qtyLayer({ title: `${r.name} 사기`, line: `하나 ${r.buy}전 · 짐칸에 ${roomFor(good)}개 더 실을 수 있습니다.`, max, okText: '사서 싣기', onOk: f });
}
function loadFood(item) {
  const f0 = invFoods().find(x => x.id === item); if (!f0) return;
  const max = Math.min(f0.n, roomFor(baseOf(item)));
  if (max <= 0) return toast('짐칸에 자리가 없습니다.', 'error');
  qtyLayer({ title: `${f0.name} 싣기`, line: TRADE.foodTip, max, okText: '짐칸에 싣기', onOk: n => run('world_trade_load', { p_item: item, p_qty: n }, null) });
}
async function sell(btn) {
  const items = {};
  for (const h of hold()) { const q = qtyOf(el, h.good); if (q > 0) items[h.good] = q; }
  if (!Object.keys(items).length) return toast('팔 수량을 고르세요.', 'error');
  const r = await run('world_trade_sell', { p_items: items }, btn);
  if (r && Object.keys(r.left || {}).length) toast('오늘 팔 수 있는 몫이 차서 남은 짐은 배에 남았습니다.', 'info');
}
async function sail(btn) {
  const to = v.ports.find(p => p.id === pick); if (!to) return;
  const mins = mode === 'direct' ? to.direct_min : to.send_min;
  const msg = `${to.name}(으)로 ${mode === 'direct' ? '배를 타고 갑니다' : '배를 보냅니다'}. 약 ${mins}분 · 노정패 ${TRADE.sail?.tokens ?? 2}개.${mode === 'direct' && party ? `\n파티원에게 함께 타자고 하고 ${TRADE.sail?.board_s ?? 60}초 뒤에 떠납니다. 덤: ${TRADE.bonus?.[bonus]?.name || ''}.` : ''}\n${TRADE.modeTip[mode]}`;
  if (!(await ask(msg, { title: TRADE.modeName[mode], ok: '띄우기' }))) return;
  await run('world_trade_sail', { p_to: to.id, p_mode: mode, p_bonus: mode === 'direct' && party ? bonus : null, p_party: mode === 'direct' && party }, btn, () => { pick = null; });
}
async function putPart(cat, btn) {
  const c = v.parts?.cats?.[cat]; if (!c) return;
  const items = {};
  for (const [k, i] of Object.entries(c.items || {})) { const n = Math.min(i.need - i.have, have(k)); if (n > 0) items[k] = n; }
  if (!Object.keys(items).length) return toast('넣을 재료가 없습니다.', 'error');
  const line = Object.entries(items).map(([k, n]) => `${c.items[k].name} ${n}`).join(' · ');
  if (!(await ask(`${c.name} 갈래에 넣습니다.\n${line}\n재료는 가방을 먼저 쓰고 모자라면 창고에서 꺼냅니다.`, { title: '조선 재료 넣기', ok: '넣기' }))) return;
  return run('world_trade_ship_part', { p_items: items }, btn);
}
function rename() {
  const max = TRADE.name_max || 12;
  const L = openLayer({ title: '배 이름 짓기', body: `<label class="field"><span>배 이름 (${max}자까지, 비우면 배 종류 이름)</span><input type="text" maxlength="${max}" value="${esc(v.ship?.name === v.ship?.kind ? '' : v.ship?.name || '')}" data-nm></label><div class="btn-row"><button class="btn primary" data-ok>짓기</button></div>` });
  const inp = $('[data-nm]', L);
  $('[data-ok]', L).onclick = async () => { L.close(); await run('world_trade_ship_name', { p_name: inp.value.trim() || null }, null); };
}
