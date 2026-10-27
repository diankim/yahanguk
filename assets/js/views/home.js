// 현장: 지금 있는 곳에서 할 수 있는 일.
// 안전지대 — 시설(상점·거래소·마구간·여관·게시판)을 눌러 창으로 연다.
// 바깥 지역 — 탐색력을 써서 탐색하고, 찾아낸 길로 더 깊이 들어가며, 채집터에서 자원을 모은다.
import { store, on, act, nameOf, esc, icon, bar, guard, $, $$, fmt, empty, emblem, openModal, closeModal, toast } from '../core.js';
import { load, panel, chip, danger, loading, errorBox } from './common.js';
import { renderShop, renderMarket, renderStable } from './services.js';
import { renderExpedition } from './expedition.js';
import { renderBattle, stopBattle, MECH, effectiveness, STYLE } from './battle.js';
import { setScene } from '../sound.js';
import { envChip } from '../env.js';

const THEME_SCENE = { city: '도성', wild: '들과 숲', shrine: '사당', water: '물가', mountain: '산악', desert: '황무지', deep: '지하', sky: '천문' };
const OUTCOME = {
  path: ['route', '길'], spot: ['leaf', '채집터'], clue: ['scroll', '단서'], regional: ['map', '기록'], encounter: ['sword', '조우'],
  cache: ['bag', '보급'], hazard: ['flame', '위험'], omen: ['moon', '징조'], quiet: ['eye', '고요'], gather: ['leaf', '채집'],
  combat: ['sword', '토벌'], battle_lost: ['heart', '패배'], battle_fled: ['back', '도주'],
};
const CAT = { herbs: '약초', ore: '광석', wood: '목재', water: '수변', spirit: '영물', relics: '유물', supplies: '보급' };
const DEPTH = ['초입', '권역', '구역', '깊은 곳', '가장 깊은 곳'];

let el, off = [], snap = null, timer = null, busy = false;

export async function render(root) {
  if (!store.character) return;
  el = root;
  el.innerHTML = loading();
  off.forEach(f => f());
  off = [on('changed', ({ name }) => { if (!/battle_action/.test(name)) draw(); }), on('env', () => { const x = $('.scene .env-slot', el); if (x) x.innerHTML = envChip(); })];
  window.addEventListener('yahang:arrived', draw);
  await draw();
}
export function destroy() { off.forEach(f => f()); off = []; window.removeEventListener('yahang:arrived', draw); clearInterval(timer); stopBattle(); }

async function draw() {
  if (!el?.isConnected || busy) return;
  busy = true;
  try {
    const [s, roster] = await Promise.all([load('world_field_snapshot'), load('world_region_roster', undefined, { maxAge: 15000 }).catch(() => [])]);
    snap = s;
    const c = store.character;
    const traveling = c.travel_arrives_at && new Date(c.travel_arrives_at) > new Date();
    const downed = c.downed_at || c.health <= 0;
    setScene({ safe: !!s.region.safe, battle: !!(s.battle && !downed) });
    if (s.battle && !downed) { drawBattle(); return; }
    stopBattle();
    el.innerHTML = `${scene(s, traveling, downed)}${s.region.safe ? town(s, roster) : field(s, roster, traveling || downed || !!store.expedition)}`;
    bind(s);
    clearInterval(timer); timer = setInterval(tick, 1000); tick();
  } catch (e) { el.innerHTML = errorBox(e.message); }
  finally { busy = false; }
}

function drawBattle() {
  el.innerHTML = `<div class="scene battle-scene theme-${esc(snap.region.theme || 'wild')}"><p class="eyebrow">${icon('pin', 14)} ${esc(snap.region.region_name)} · ${esc(snap.node.name)}</p></div><div id="battle-box"></div>`;
  renderBattle($('#battle-box', el), snap, () => { store.snaps = {}; draw(); });
}

/* ── 장면 머리 ───────────────────────────────────────────── */
function scene(s, traveling, downed) {
  const r = s.region, c = store.character;
  return `
    <div class="scene theme-${esc(r.theme || 'wild')} ${r.safe ? 'safe' : ''}">
      <div class="scene-top">
        <p class="eyebrow">${icon('pin', 14)} ${esc(r.territory_name || '')} · ${esc(r.faction_name || '무주 금역')}</p>
        <h1>${esc(r.region_name)}</h1>
        <div class="env-slot">${envChip()}</div>
        <div class="chips">${r.safe ? chip('안전지대', 'ok') : danger(r.danger)}${chip(THEME_SCENE[r.theme] || '야외')}${!r.safe ? chip(`답사 ${s.survey?.pct ?? 0}%`, 'accent') : ''}</div>
      </div>
      ${!r.safe ? `<nav class="crumbs" aria-label="지금 있는 곳">${(s.path || []).map((p, i, a) => i === a.length - 1
          ? `<b>${esc(p.name)}</b>` : `<button data-move="${esc(p.node_id)}">${esc(p.name)}</button>${icon('chevron', 12)}`).join('')}</nav>` : ''}
    </div>
    ${downed ? `<div class="notice danger">${icon('heart', 18)}<div><b>전투불능</b><span>구조를 기다리거나 회생 부적·본부 구조대를 쓰세요. <em data-death></em></span></div><a class="btn small" href="#/char/status">대처하기</a></div>` : ''}
    ${traveling ? `<div class="notice travel">${icon('route', 18)}<div><b>${esc(nameOf(c.travel_destination))}(으)로 이동 중</b><span>도착하면 그 지역에서 행동할 수 있습니다.</span></div></div>` : ''}
    ${store.expedition ? `<div class="notice">${icon('flame', 18)}<div><b>원정 중</b><span>원정이 끝날 때까지 현장 행동을 할 수 없습니다.</span></div><button class="btn small" id="exp-open">원정 보기</button></div>` : ''}`;
}

/* ── 안전지대 ───────────────────────────────────────────── */
function town(s, roster) {
  const r = s.region;
  const tiles = [
    ['shop', 'shop', r.shop_name || '상점', '물자 사고팔기'],
    ['market', 'coin', '거래소', '조사원끼리 사고팔기'],
    r.has_stable ? ['stable', 'route', '마구간', '탈것 들이기'] : null,
    ['inn', 'moon', r.rest_spot_name || '숙소', '쉬며 회복하고 탐색력 채우기'],
    ['board', 'scroll', '의뢰 게시판', '사건과 상시 의뢰'],
    ['depart', 'map', '길 떠나기', '지도에서 목적지 고르기'],
  ].filter(Boolean);
  return `
    <p class="desc scene-desc">${esc(r.description || '요괴가 들어오지 못하는 곳입니다. 물자를 정리하고 다음 길을 준비하세요.')}</p>
    <div class="facilities">${tiles.map(([k, ic, n, d]) => `<button class="facility" data-fac="${k}">${icon(ic, 26)}<b>${esc(n)}</b><small>${esc(d)}</small></button>`).join('')}</div>
    ${people(roster, s.corpses)}`;
}

/* ── 바깥 지역 ──────────────────────────────────────────── */
function field(s, roster, blocked) {
  const st = s.stamina || { now: 0, max: 20 }, n = s.node;
  const kids = (s.nodes || []).filter(x => x.parent_id === n.node_id);
  const parent = (s.nodes || []).find(x => x.node_id === n.parent_id);
  const w = s.weapon || {};
  const mechs = [...new Set((s.monsters || []).map(m => m.mechanic).filter(Boolean))];
  return `
    <div class="field-grid">
      <section class="panel explore-card">
        <div class="place">
          <p class="eyebrow">${esc(DEPTH[n.depth] || '')} · 권장 Lv.${n.min_level}+</p>
          <h2>${esc(n.name)}</h2>
          <p class="desc">${esc(n.description || '')}</p>
        </div>
        <div class="stamina">
          <div class="st-top"><span>${icon('spark', 14)} 탐색력</span><b>${st.now} / ${st.max}</b></div>
          <div class="st-pips">${Array.from({ length: st.max }, (_, i) => `<i class="${i < st.now ? 'on' : ''}"></i>`).join('')}</div>
          <small class="muted" data-st-next="${st.next_at ? new Date(st.next_at).getTime() : ''}">${st.now >= st.max ? '가득 찼습니다' : ''}</small>
        </div>
        <button class="btn primary big-act" id="search" ${blocked || st.now <= 0 ? 'disabled' : ''}>${icon('search', 22)}<span>탐색하기</span><small>탐색력 1 · 길·채집터·요괴·보급·단서</small></button>
        ${s.story_here?.length ? `<p class="hint accent">${icon('scroll', 14)} 이 지역 어딘가에 「${esc(s.story_here[0].chapter)}」의 단서가 있습니다. 탐색을 이어가세요.</p>` : ''}
        <div class="sub-acts">
          <button class="btn" id="exp-open2" ${blocked ? 'disabled' : ''}>${icon('flame', 16)}<span>원정 보내기</span></button>
          <button class="btn" id="camp" ${blocked ? 'disabled' : ''}>${icon('moon', 16)}<span>야영</span></button>
          <a class="btn ghost" href="#/map">${icon('map', 16)}<span>지도</span></a>
        </div>
        <p class="weapon-line small">${icon('sword', 14)} ${esc(w.name || '맨손')} · ${STYLE[w.type] || '근접'}${mechs.length ? ` · 이 지역 요괴: ${mechs.map(m => { const [e, k] = effectiveness(w.type, m); return `<span class="eff ${k}">${esc(MECH[m]?.[0] || m)} ${esc(e)}</span>`; }).join(' ')}` : ''}</p>
      </section>

      <section class="panel">
        <header class="panel-head"><h2>${icon('route', 16)}이어진 길</h2><span class="muted small">${s.hidden_paths ? `찾지 못한 길 ${s.hidden_paths}` : '모두 찾음'}</span></header>
        <div class="panel-body">
          <ul class="paths">
            ${parent ? `<li><button class="path back" data-move="${esc(parent.node_id)}" ${blocked ? 'disabled' : ''}>${icon('back', 16)}<span><b>${esc(parent.name)}</b><small>되돌아가기</small></span></button></li>` : ''}
            ${kids.map(k => `<li><button class="path" data-move="${esc(k.node_id)}" ${blocked || store.character.level < k.min_level ? 'disabled' : ''}>${icon('chevron', 16)}<span><b>${esc(k.name)}</b><small>${esc(DEPTH[k.level - 1] || '')} · Lv.${k.min_level}+ · 채집터 ${k.spots_found}/${k.spots_total}</small></span></button></li>`).join('')}
            ${Array.from({ length: s.hidden_paths || 0 }, () => `<li><div class="path unknown">${icon('help', 16)}<span><b>아직 찾지 못한 길</b><small>탐색하면 드러납니다</small></span></div></li>`).join('')}
          </ul>
          ${!kids.length && !s.hidden_paths && !parent ? empty('더 이어진 길이 없습니다.', 'route') : ''}
        </div>
      </section>

      <section class="panel">
        <header class="panel-head"><h2>${icon('leaf', 16)}채집터</h2><span class="muted small">${s.hidden_spots ? `숨은 채집터 ${s.hidden_spots}` : ''}</span></header>
        <div class="panel-body">
          ${(s.spots || []).length ? `<ul class="spots">${s.spots.map(p => `<li>
              <div><b>${esc(p.name)}</b><small>${esc(CAT[p.category] || '')} · ${esc((p.items || []).map(nameOf).join(', '))}</small></div>
              <button class="btn small primary" data-gather="${esc(p.spot_id)}" data-ready="${p.ready_at ? new Date(p.ready_at).getTime() : ''}" ${blocked ? 'disabled' : ''}>채집</button></li>`).join('')}</ul>`
            : empty(s.hidden_spots ? '이곳의 채집터를 아직 찾지 못했습니다. 탐색해 보세요.' : '이곳에는 채집터가 없습니다.', 'leaf')}
          <p class="muted small">채집은 탐색력 1을 쓰고, 같은 채집터는 5분 뒤에 다시 쓸 수 있습니다.</p>
        </div>
      </section>

      <section class="panel log-card">
        <header class="panel-head"><h2>${icon('scroll', 16)}탐사 기록</h2></header>
        <div class="panel-body"><ol class="field-log">${(s.recent || []).map(e => { const o = OUTCOME[e.kind] || OUTCOME.quiet; return `<li class="k-${esc(e.kind)}">${icon(o[0], 14)}<span>${esc(e.content)}</span><time>${fmt.time(e.at)}</time></li>`; }).join('') || `<li class="muted">아직 기록이 없습니다. 탐색을 시작하세요.</li>`}</ol></div>
      </section>
    </div>
    <details class="panel fold"><summary class="panel-head"><h2>${icon('map', 16)}${esc(s.region.region_name)} 답사 지도 · ${s.survey?.pct ?? 0}%</h2></summary>
      <div class="panel-body">${tree(s)}<p class="muted small">찾은 장소 ${s.survey?.nodes_found ?? 0}/${s.survey?.nodes_total ?? 0} · 채집터 ${s.survey?.spots_found ?? 0}/${s.survey?.spots_total ?? 0}. 모두 찾으면 가방이 넓어집니다.</p></div></details>
    <details class="panel fold"><summary class="panel-head"><h2>${icon('sword', 16)}출몰 요괴</h2></summary>
      <div class="panel-body"><ul class="foe-list">${(s.monsters || []).map(m => `<li><b>${esc(m.name)}</b>${m.role === 'guardian' ? chip('우두머리', 'bad') : ''}<small>${esc(m.type || '')} · ${esc(MECH[m.mechanic]?.[0] || '')} · Lv.${m.min_level}–${m.max_level}</small>${MECH[m.mechanic] ? `<small class="muted">${esc(MECH[m.mechanic][1])}</small>` : ''}</li>`).join('')}</ul></div></details>
    ${people(roster, s.corpses)}`;
}

function tree(s) {
  const nodes = s.nodes || [], byParent = new Map();
  for (const n of nodes) { const k = n.parent_id || 'root'; (byParent.get(k) || byParent.set(k, []).get(k)).push(n); }
  const walk = pid => (byParent.get(pid) || []).map(n => `<li><button class="${n.here ? 'here' : ''}" data-move="${esc(n.node_id)}">${esc(n.name)}<small>${n.paths_found}/${n.paths_total} · ${n.spots_found}/${n.spots_total}</small></button>${byParent.has(n.node_id) ? `<ul>${walk(n.node_id)}</ul>` : ''}</li>`).join('');
  return `<ul class="tree">${walk('root')}</ul>`;
}

function people(roster, corpses) {
  const list = Array.isArray(roster) ? roster : [];
  const dead = corpses || [];
  return `<section class="panel"><header class="panel-head"><h2>${icon('users', 16)}여기 있는 이들</h2><a class="btn small ghost" href="#/party">동료</a></header><div class="panel-body">
    ${list.length ? `<ul class="people">${list.map(p => `<li>${emblem(p.owner_id, p.profile, 34)}<div><b>${esc(p.character_name)}</b><small>Lv.${p.level} · ${esc(nameOf(p.job_key))}${p.away ? ' · 원정 중' : ''}${p.in_combat ? ' · 전투 중' : ''}${p.downed ? ' · 전투불능' : ''}</small></div>
      ${p.downed && !p.is_dead ? `<button class="btn small primary" data-rescue="${esc(p.owner_id)}">구조</button>` : ''}</li>`).join('')}</ul>` : `<p class="muted small">같은 곳에 다른 조사원이 없습니다.</p>`}
    ${dead.length ? `<h3 class="sub-h">쓰러진 이의 자리</h3><ul class="people">${dead.map(d => `<li><span class="emblem corpse">${icon('flame', 18)}</span><div><b>${esc(d.character_name)}의 시신</b><small>${new Date(d.died_at).toLocaleDateString('ko-KR')} · ${esc(d.death_reason || '')}${d.items_left ? ` · 유품 ${d.items_left}점` : ''}</small></div>
      <div class="btn-row">${d.can_respect ? `<button class="btn small" data-respect="${esc(d.corpse_id)}">명복 빌기</button>` : ''}${d.items_left ? `<button class="btn small" data-loot="${esc(d.corpse_id)}">유품 수습</button>` : ''}</div></li>`).join('')}</ul>` : ''}
  </div></section>`;
}

/* ── 동작 ──────────────────────────────────────────────── */
function bind(s) {
  $('#search', el)?.addEventListener('click', e => doSearch(e.currentTarget));
  $$('[data-move]', el).forEach(b => b.onclick = () => guard(b, () => act('world_field_move', { p_node_id: b.dataset.move }), { success: '' }));
  $$('[data-gather]', el).forEach(b => b.onclick = () => guard(b, async () => { const r = await act('world_field_gather', { p_spot_id: b.dataset.gather }); window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'gather' })); return r; }));
  $$('[data-rescue]', el).forEach(b => b.onclick = () => guard(b, () => act('world_rescue_character', { p_target: b.dataset.rescue })));
  $$('[data-respect]', el).forEach(b => b.onclick = () => guard(b, () => act('world_corpse_respect', { p_corpse_id: b.dataset.respect })));
  $$('[data-loot]', el).forEach(b => b.onclick = () => { if (confirm('유품을 수습할까요? 다른 조사원이 남긴 물건을 가져갑니다.')) guard(b, () => act('world_corpse_loot', { p_corpse_id: b.dataset.loot })); });
  const openExp = () => openExpedition();
  $('#exp-open', el)?.addEventListener('click', openExp); $('#exp-open2', el)?.addEventListener('click', openExp);
  $('#camp', el)?.addEventListener('click', () => openRest(s.region));
  $$('[data-fac]', el).forEach(b => b.onclick = () => openFacility(b.dataset.fac, s));
}

async function doSearch(btn) {
  if (btn.dataset.busy === '1') return;
  btn.dataset.busy = '1'; btn.disabled = true; btn.classList.add('searching');
  window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'search' }));
  try {
    const r = await act('world_field_search');
    const o = OUTCOME[r.outcome] || OUTCOME.quiet;
    window.dispatchEvent(new CustomEvent('yh-sfx', { detail: r.outcome === 'encounter' ? 'encounter' : r.outcome === 'hazard' ? 'hurt' : ['path', 'spot', 'clue', 'cache', 'regional'].includes(r.outcome) ? 'find' : 'tick' }));
    if (r.outcome === 'encounter') toast(r.content, 'warn');
    else showFind(o, r);
  } catch (e) { const { friendlyError } = await import('../core.js'); toast(friendlyError(e), 'error'); }
  finally { btn.dataset.busy = ''; btn.classList.remove('searching'); }
}
// 발견은 화면 가운데 잠깐 떠오르는 쪽지로 보여 준다.
function showFind([ic, label], r) {
  const n = document.createElement('div');
  n.className = `find-pop k-${r.outcome}`;
  n.innerHTML = `${icon(ic, 22)}<div><b>${esc(label)}</b><span>${esc(r.content)}</span></div>`;
  document.body.append(n);
  setTimeout(() => n.classList.add('out'), 2600); setTimeout(() => n.remove(), 3100);
}

function tick() {
  if (!el?.isConnected) return clearInterval(timer);
  const now = Date.now();
  $$('[data-st-next]', el).forEach(s => { const t = Number(s.dataset.stNext); if (t) s.textContent = t > now ? `${fmt.remain(t - now)} 뒤 1 회복` : '곧 회복'; if (t && t <= now) { s.dataset.stNext = ''; draw(); } });
  $$('[data-gather]', el).forEach(b => { const t = Number(b.dataset.ready); if (!t) return; if (t > now) { b.disabled = true; b.textContent = fmt.remain(t - now); } else { b.dataset.ready = ''; b.disabled = false; b.textContent = '채집'; } });
  const c = store.character;
  $$('[data-death]', el).forEach(s => { const t = c?.downed_at ? new Date(c.downed_at).getTime() + 4 * 3600e3 : 0; s.textContent = t ? `목숨이 다하기까지 ${fmt.remain(t - now)}` : ''; });
}

/* ── 창 ───────────────────────────────────────────────── */
function openFacility(k, s) {
  if (k === 'depart') return window.yahangGo('map');
  if (k === 'board') return window.yahangGo('log', 'story');
  if (k === 'inn') return openRest(s.region);
  const title = { shop: s.region.shop_name || '상점', market: '거래소', stable: '마구간' }[k];
  const m = openModal({ title, wide: true, body: '<div class="fac-body"></div>' });
  const box = $('.fac-body', m);
  const fill = () => (k === 'market' ? renderMarket : k === 'stable' ? renderStable : renderShop)(box);
  fill();
  const offc = on('changed', () => { if (box.isConnected) fill(); else offc(); });
}

function openRest(r) {
  const safe = r.safe;
  const m = openModal({ title: safe ? (r.rest_spot_name || '숙소') : '야영', body: `
    <p class="desc">${safe ? '안전한 곳에서 쉬면 체력·정신·영력이 회복되고 나쁜 상태가 풀립니다. 푹 쉬면 탐색력이 가득 찹니다.' : '바깥에서 야영합니다. 회복은 적고, 쉬는 동안 습격받을 수 있습니다.'}</p>
    <div class="action-grid two">
      <button class="btn" data-rest="short"><span>잠깐 쉬기</span><small>${fmt.jeon(r.rest_fee || 0)} · 탐색력 +3</small></button>
      <button class="btn primary" data-rest="full"><span>푹 쉬기</span><small>${fmt.jeon((r.rest_fee || 0) * 2)} · ${safe ? '탐색력 가득' : '탐색력 +6'}</small></button>
    </div>` });
  $$('[data-rest]', m).forEach(b => b.onclick = () => guard(b, async () => { const out = await act('world_field_rest', { p_style: b.dataset.rest }); closeModal(); return out; }));
}

async function openExpedition() {
  const m = openModal({ title: '원정', wide: true, body: `<div class="exp-body">${loading()}</div>` });
  const box = $('.exp-body', m);
  const fill = async () => { try { renderExpedition(box, await load('world_expedition_overview')); } catch (e) { box.innerHTML = errorBox(e.message); } };
  await fill();
  const offc = on('changed', ({ name }) => { if (!box.isConnected) return offc(); if (/expedition/.test(name)) fill(); });
}
