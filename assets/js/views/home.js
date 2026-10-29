// 현장: 지금 있는 곳에서 할 수 있는 일.
// 안전지대 — 시설(상점·거래소·마구간·여관·게시판)을 눌러 창으로 연다.
// 바깥 지역 — 탐색력을 써서 탐색하고, 찾아낸 길로 더 깊이 들어가며, 채집터에서 자원을 모은다.
import { cardName } from './card.js';
import { sealMark } from '../cosmetics.js';
import { gmBadge, ask, store, on, act, nameOf, esc, icon, bar, guard, $, $$, fmt, empty, emblem, openModal, closeModal, toast } from '../core.js';
import { load, panel, chip, danger, loading, errorBox, invalidate, safeZones, zonesNow } from './common.js';
import { factionColor } from '../geo.js';
import { renderShop, renderMarket, renderStable, renderSmithy, renderStorage } from './services.js';
import { openExpeditionWindow } from './expedition.js';
import { renderBattle, stopBattle, STYLE } from './battle.js';
import { setScene } from '../sound.js';
import { envChip } from '../env.js';
import { sceneArt } from '../scenery.js';
import { checklistHtml, noteRegion } from '../tutorial.js';
import { questBox, fillQuests } from '../quests.js';
import { raidBand, fillRaidBand } from './raid.js';

const THEME_SCENE = { city: '도성', wild: '들과 숲', shrine: '사당', water: '물가', mountain: '산악', desert: '황무지', deep: '지하', sky: '천문' };
const OUTCOME = {
  path: ['route', '길'], spot: ['leaf', '채집터'], clue: ['scroll', '단서'], regional: ['map', '기록'], encounter: ['sword', '조우'],
  cache: ['bag', '보급'], hazard: ['flame', '위험'], omen: ['moon', '징조'], quiet: ['eye', '고요'], gather: ['leaf', '채집'],
  combat: ['sword', '토벌'], battle_lost: ['heart', '패배'], battle_fled: ['back', '도주'],
};
const CAT = { herbs: '약초', ore: '광석', wood: '목재', water: '수변', spirit: '영물', relics: '유물', supplies: '보급' };
const DEPTH = ['초입', '권역', '구역', '깊은 곳', '가장 깊은 곳'];

let el, off = [], snap = null, timer = null, busy = false;
// 알림의 "결과 보기": 현장 화면이 그려진 뒤 원정 창을 연다.
// 상태판·알림의 「원정 보기」: 현장 화면이면 바로 열고, 다른 화면이면 현장으로 옮긴 뒤 연다.

export async function render(root) {
  if (!store.character) return;
  el = root;
  el.innerHTML = loading();
  off.forEach(f => f());
  off = [on('changed', ({ name }) => {
    if (/battle_action/.test(name)) return;
    if (/fish|travel|field_move|craft|shop|trade|discard/.test(name)) invalidate('world_fish_spot');
    if (/rest|survival|travel|idle/.test(name)) invalidate('world_rest_status');
    if (/idle/.test(name)) invalidate('world_idle_activity_snapshot');
    draw();
  }), on('env', () => { const x = $('.scene .env-slot', el); if (x) x.innerHTML = envChip(); const f = $('.scene .scene-fx', el); if (f) f.outerHTML = sceneFx(snap?.region); }), on('expedition', () => draw())];
  window.addEventListener('yahang:arrived', draw);
  await draw();
}
export function destroy() { off.forEach(f => f()); off = []; window.removeEventListener('yahang:arrived', draw); clearInterval(timer); stopBattle(); }

let again = false, fishSpot = null, restSt = null, idleSt = null;
const restAt = k => { const t = restSt?.[k + '_ready_at']; return t ? new Date(t).getTime() : 0; };
// 다음 휴식까지 남은 시간(잠깐·푹). 둘 다 가능하면 빈 문자열
// 야영 칸에는 잠깐·푹을 한 줄씩 나눠 보인다
function restParts(now = Date.now()) {
  const a = restAt('short') - now, b = restAt('full') - now;
  return [a > 0 ? `잠깐 ${fmt.remain(a)}` : '', b > 0 ? `푹 ${fmt.remain(b)}` : ''].filter(Boolean).map(t => `<span>${esc(t)}</span>`).join('');
}
function restLine(now = Date.now(), short = false) {
  const a = restAt('short') - now, b = restAt('full') - now;
  const p = [a > 0 ? `잠깐 ${fmt.remain(a)}` : '', b > 0 ? `푹 ${fmt.remain(b)}` : ''].filter(Boolean);
  return p.length ? (short ? p.join(' · ') : `다시 쉬기까지 ${p.join(' · ')}`) : '';
}
async function draw() {
  if (!el?.isConnected) return;
  if (busy) { again = true; return; } // 그리는 중에 들어온 갱신은 끝난 뒤 한 번 더 그린다
  busy = true; again = false;
  try {
    const [s, roster, fish, rest, idle, pty] = await Promise.all([load('world_field_snapshot'), load('world_region_roster', undefined, { maxAge: 30000 }).catch(() => []),
      // 낚시터·휴식·자율 상태는 잘 바뀌지 않아 1분 동안 다시 쓰고, 관련 행동 뒤에만 새로 읽는다(아래 changed)
      load('world_fish_spot', undefined, { maxAge: 60000 }).catch(() => null), load('world_rest_status', undefined, { maxAge: 60000 }).catch(() => null), load('world_idle_activity_snapshot', undefined, { maxAge: 60000 }).catch(() => null),
      // 파티 칸: 자리·파티가 바뀌는 행동 뒤에만 새로 읽는다(common.js ROSTER_CHANGERS)
      load('world_party_overview', undefined, { maxAge: 30000 }).catch(() => null)]);
    snap = s; fishSpot = fish; restSt = rest; idleSt = idle?.active ? idle : null;
    const c = store.character;
    const traveling = c.travel_arrives_at && new Date(c.travel_arrives_at) > new Date();
    const downed = c.downed_at || c.health <= 0;
    setScene({ safe: !!s.region.safe, battle: !!(s.battle && !downed) });
    if (s.battle && !downed) { drawBattle(); return; }
    stopBattle();
    noteRegion(s.region);
    el.innerHTML = `${scene(s, traveling, downed)}${checklistHtml()}${raidBand()}${questBox()}${partyHtml(pty, s)}${s.region.safe ? town(s, roster) : field(s, roster, traveling || downed || !!store.expedition || !!idleSt || s.overflow > 0)}`;
    bind(s);
    // 퀘스트 칸은 따로 읽어 채운다(15초 동안 다시 씀, 보고 뒤에는 새로 읽음)
    fillQuests($('#quest-box', el));
    fillRaidBand($('#raid-band', el));
    clearInterval(timer); timer = setInterval(tick, 1000); tick();
  } catch (e) { el.innerHTML = errorBox(e.message); }
  finally { busy = false; }
  if (again) return draw();
}

// 파티 칸: 동료마다 있는 곳·상황·체력·정신·침식. 같은 곳의 동료와 원정을 같은 지역으로 보내면 합동 전투와 함께 다녀온 보너스.
function partyHtml(p, s) {
  if (!p?.party || (p.members || []).length < 2) return '';
  const me = store.character.owner_id, here = store.character.location;
  const mates = p.members.filter(m => m.owner_id !== me);
  const near = mates.filter(m => m.location === here && !m.downed).length;
  const state = m => m.downed ? '<b class="bad">전투불능</b>' : m.expedition ? `원정 중 · ${fmt.remain(new Date(m.expedition.ends_at) - Date.now())} 남음` : m.in_combat ? '전투 중' : '';
  const row = m => `<li class="${m.location === here ? 'near' : ''}"><span class="fdot" style="--fc:${factionColor(m.major_faction_id)}"></span>
      <b>${cardName(m.owner_id, m.character_name)}</b>${m.role === 'leader' ? '<small class="accent">파티장</small>' : ''}
      <small>${esc(m.location || '')}${m.location === here ? ' (같은 곳)' : ''}${state(m) ? ' · ' + state(m) : ''}</small>
      <small class="pt-stat">체력 ${m.health} · 정신 ${m.mental ?? '-'} · 침식 ${m.erosion ?? 0}</small>
      ${m.downed && m.location === here && m.owner_id !== me ? `<button class="btn small primary" data-rescue="${esc(m.owner_id)}">구조</button>` : ''}</li>`;
  return `<section class="panel party-strip"><header class="panel-head"><h2>${icon('users', 16)} 파티 · ${p.members.length}명</h2>
      <div class="btn-row">${!s.region.safe ? `<button class="btn small primary" id="pt-exp" ${store.expedition ? 'disabled' : ''}>${icon('route', 14)}<span>파티 원정</span></button>` : ''}<a class="btn small ghost" href="#/party">동료 화면</a></div></header>
    <div class="panel-body"><ul class="pt-list">${mates.map(row).join('')}</ul>
      <p class="muted small">${near ? `같은 곳의 동료 ${near}명: 받는 피해 −${3 * Math.min(near, 3)}%·회복량 +4%. ` : '같은 곳에 있는 동료가 있으면 받는 피해가 줄고 회복량이 늘어납니다. '}같은 지역으로 원정을 보내면 합동 전투(동료 전투력 60%가 승률에 더해지고 요괴는 이목이 높은 쪽을 노림)를 하고, 함께 다녀온 동료 한 명마다 경험치·숙련 경험 +10%(세 명까지).</p></div></section>`;
}

function drawBattle() {
  el.innerHTML = `<div class="scene battle-scene theme-${esc(snap.region.theme || 'wild')}">${sceneFx(snap.region)}<span class="frame-c" aria-hidden="true"><i></i><i></i><i></i><i></i></span><p class="eyebrow">${icon('pin', 14)} ${esc(snap.region.region_name)} · ${esc(snap.node.name)}</p></div><div id="battle-box"></div>`;
  renderBattle($('#battle-box', el), snap, () => { store.snaps = {}; draw(); });
}

/* ── 장면 머리 ───────────────────────────────────────────── */
// 날씨·시간대·장소에 맞춘 움직이는 배경(글자 뒤에 옅게 깔린다). 실제 효과 수치는 서버가 정한다.
function sceneFx(r) {
  const e = store.env;
  const w = e?.weather?.key || '', p = e?.phase?.key || '';
  return `<div class="scene-fx" aria-hidden="true" data-w="${esc(w)}" data-p="${esc(p)}" data-t="${esc(r?.theme || '')}">${sceneArt(r?.theme || 'wild', p, w)}<i class="fx-veil"></i><i class="fx-a"></i><i class="fx-b"></i><i class="fx-c"></i></div>`;
}
// 침식 원형 게이지: 현장 머리 오른쪽 위. 단계(주의 30·위험 55·붕괴 직전 80)마다 색이 짙어지고, 누르면 캐릭터 › 상태로 간다.
function scene(s, traveling, downed) {
  const r = s.region, c = store.character, z = zonesNow()?.get(r.region_id);
  if (!zonesNow()) safeZones().catch(() => {});
  return `
    <div class="scene theme-${esc(r.theme || 'wild')} ${r.safe ? 'safe' : ''}">
      ${sceneFx(r)}
      <span class="frame-c" aria-hidden="true"><i></i><i></i><i></i><i></i></span>
      <div class="scene-top">
        <p class="eyebrow">${icon('pin', 14)} ${esc(r.territory_name || '')} · <span class="fdot" style="--fc:${factionColor(r.faction_id ?? z?.control_faction_id)}"></span>${esc(r.faction_name || '무주 금역')}${z?.contested ? ' · <b class="contest">분쟁 중</b>' : ''}</p>
        <h1>${esc(r.region_name)}</h1>
        <div class="env-slot">${envChip()}</div>
        <div class="chips">${r.safe ? chip('안전지대', 'ok') : danger(r.danger)}${chip(THEME_SCENE[r.theme] || '야외')}${!r.safe ? chip(`답사 ${s.survey?.pct ?? 0}%`, 'accent') : ''}</div>
        ${r.safe ? `<p class="scene-desc">${esc(r.description || '요괴가 들어오지 못하는 곳입니다. 물자를 정리하고 다음 길을 준비하세요.')}</p>` : ''}
      </div>
      ${!r.safe ? `<nav class="crumbs" aria-label="지금 있는 곳">${(s.path || []).map((p, i, a) => i === a.length - 1
          ? `<b>${esc(p.name)}</b>` : `<button data-move="${esc(p.node_id)}">${esc(p.name)}</button>${icon('chevron', 12)}`).join('')}</nav>` : ''}
    </div>
    ${s.overflow > 0 ? `<div class="notice warn">${icon('bag', 18)}<div><b>원정 짐 보따리 · ${fmt.num(s.overflow)}개</b><span>가방에 들어가지 못한 전리품입니다. 챙기거나 버려야 다시 길을 나설 수 있습니다.</span></div><button class="btn small primary" id="ov-open">정리하기</button></div>` : ''}
    ${downed ? `<div class="notice danger">${icon('heart', 18)}<div><b>전투불능</b><span>구조를 기다리거나 회생 부적·본부 구조대를 쓰세요. <em data-death></em></span></div><a class="btn small" href="#/char/status">대처하기</a></div>` : ''}
    ${traveling ? `<div class="notice travel">${icon('route', 18)}<div><b>${esc(nameOf(c.travel_destination) + '(으)로')} 이동 중</b><span>도착하면 그 지역에서 행동할 수 있습니다.</span></div></div>` : ''}
    ${store.expedition ? (new Date(store.expedition.ends_at) <= new Date()
      ? `<div class="notice ok">${icon('check', 18)}<div><b>원정 완료 · ${esc(store.expedition.place_name || '원정지')}</b><span>원정대가 돌아왔습니다. 결과를 받으면 다시 현장에서 행동할 수 있습니다.</span></div><button class="btn small primary" id="exp-open">결과 받기</button></div>`
      : `<div class="notice">${icon('flame', 18)}<div><b>원정 중</b><span>원정이 끝날 때까지 현장 행동을 할 수 없습니다.</span></div><button class="btn small" id="exp-open">원정 보기</button></div>`) : ''}
    ${idleSt ? `<div class="notice">${icon('hourglass', 18)}<div><b>자율 활동 중</b><span>활동이 끝나 보상을 받을 때까지 이동·탐색·전투·채집·낚시·제작·거래를 할 수 없습니다. 물품 사용과 장비 바꾸기는 됩니다. 도중에 그만두면 지난 시간만큼만 받습니다.</span></div><a class="btn small" href="#/char/idle">자율 활동 보기</a></div>` : ''}`;
}

/* ── 안전지대 ───────────────────────────────────────────── */
function town(s, roster) {
  const r = s.region;
  const tiles = [
    ['shop', 'shop', r.shop_name || '상점', '물자 사고팔기'],
    ['smithy', 'hammer', '대장간', '재료 사기 · 강화 · 수리 · 분해'],
    ['market', 'coin', '거래소', '조사원끼리 사고팔기'],
    ['storage', 'chest', '창고', '어디서나 같은 개인 창고'],
    r.has_stable ? ['stable', 'route', '마구간', '탈것 들이기'] : null,
    ['inn', 'moon', r.rest_spot_name || '숙소', restLine() || '쉬며 회복하고 탐색력 채우기'],
    ['idle', 'hourglass', '자율 휴식', '접속하지 않는 동안 쉬어 두기'],
    ['board', 'scroll', '의뢰 게시판', '사건과 상시 의뢰'],
    ['faction', 'flag', '세력', store.character?.major_faction_id ? `${nameOf(store.character.major_faction_id)} · 퀘스트·의뢰판·비고` : '대세력 살펴보기·가입'],
    ['depart', 'map', '길 떠나기', '지도에서 목적지 고르기'],
  ].filter(Boolean);
  return `
    <div class="facilities">${tiles.map(([k, ic, n, d]) => `<button class="facility" data-fac="${k}">${icon(ic, 26)}<b>${esc(n)}</b><small ${k === 'inn' ? 'data-rest-line' : ''}>${esc(d)}</small></button>`).join('')}</div>
    ${fishPanel(!!idleSt || !!store.expedition)}
    ${people(roster, s.corpses)}`;
}

/* ── 바깥 지역 ──────────────────────────────────────────── */
function field(s, roster, blocked) {
  const st = s.stamina || { now: 0, max: 20 }, n = s.node;
  const kids = (s.nodes || []).filter(x => x.parent_id === n.node_id);
  const parent = (s.nodes || []).find(x => x.node_id === n.parent_id);
  const w = s.weapon || {};
  const kinds = [...new Set((s.monsters || []).map(m => m.kind_name).filter(Boolean))];
  // 길을 못 가는 까닭(서버 world_field_move와 같은 순서): 전투불능 → 이동 중 → 원정 중 → 레벨
  const c = store.character;
  const stateWhy = !blocked ? '' : s.overflow > 0 ? '원정 짐 보따리를 먼저 정리하세요' : (c.downed_at || c.health <= 0) ? '전투불능 상태에서는 움직일 수 없습니다'
    : (c.travel_arrives_at && new Date(c.travel_arrives_at) > new Date()) ? '다른 지역으로 이동 중에는 움직일 수 없습니다'
    : store.expedition ? '원정 중에는 움직일 수 없습니다' : '지금은 움직일 수 없습니다';
  const whyNot = k => stateWhy || (c.level < k.min_level ? `Lv.${k.min_level}부터 들어갈 수 있습니다 · 지금 Lv.${c.level} (${k.min_level - c.level}레벨 더 필요)` : '');
  return `
    <div class="field-grid">
      <div class="fg-col fg-a">
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
        <div class="act-tiles">
          <button class="tile primary" id="search" title="탐색력 1 · 길·채집터·요괴·보급·단서" ${blocked || st.now <= 0 ? 'disabled' : ''}>${icon('search', 22)}<span>탐색</span></button>
          <button class="tile" id="exp-open2" title="원정 보내기" ${blocked ? 'disabled' : ''}>${icon('flame', 22)}<span>원정</span></button>
          <button class="tile" id="camp" title="야영" ${blocked ? 'disabled' : ''}>${icon('moon', 22)}<span>야영</span><small class="rest-cd" data-rest-line="short">${restParts()}</small></button>
          <button class="tile" id="idle-rest" title="자율 휴식: 접속하지 않는 동안 쉬어 체력·정신·영력을 채웁니다">${icon('hourglass', 22)}<span>자율 휴식</span></button>
          <a class="tile" href="#/map" title="지도">${icon('map', 22)}<span>지도</span></a>
        </div>
        ${(s.gear_warn || []).length ? `<p class="hint warn gear-warn">${icon('wrench', 14)} <span><b>닳은 장비</b> · ${s.gear_warn.map(g => `${esc(g.name)}(${g.dur > 0 ? `${g.dur}/${g.max}` : '부서짐'})`).join(', ')} — 부서진 장비는 효과가 없고, 4분의 1 아래면 성능이 20% 떨어집니다. 안전지대 대장간이나 수리 도구로 고치세요.</span></p>` : ''}
        ${s.trail?.expires_at && new Date(s.trail.expires_at) > new Date() ? `<p class="hint good trail-line">${icon('spark', 14)} <b>비경이 열려 있습니다</b> · ${esc(fmt.remain(new Date(s.trail.expires_at) - Date.now()))} 남음 · 채집량 +50% · 희귀품·단서 +10%</p>` : ''}
        ${!blocked && st.now <= 0 ? `<div class="hint warn st-empty">${icon('flame', 14)}<span>탐색력이 바닥났습니다. 차오르는 동안 <b>원정</b>을 보내 두면 시간을 버리지 않습니다. 원정은 탐색력을 쓰지 않습니다.</span><button class="btn small primary" id="exp-open3">원정 보내기</button></div>` : ''}
        ${s.story_here?.length ? `<p class="hint accent">${icon('scroll', 14)} 이 지역 어딘가에 「${esc(s.story_here[0].chapter)}」의 단서가 있습니다. 탐색을 이어가세요.</p>` : ''}
        <p class="weapon-line small">${icon('sword', 14)} ${esc(w.name || '맨손')} · ${STYLE[w.type] || '근접'}${kinds.length ? ` · 이 지역 요괴 갈래: ${kinds.map(k => esc(k)).join('·')}` : ''}</p>
      </section>

      <details class="panel fold log-card" data-fold="field-log" ${foldOpen('field-log') ? 'open' : ''}>
        <summary class="panel-head"><h2>${icon('scroll', 16)}탐사 기록 <small class="muted">${(s.recent || []).length}</small></h2></summary>
        <div class="panel-body"><ol class="field-log">${(s.recent || []).map(e => { const o = OUTCOME[e.kind] || OUTCOME.quiet; return `<li class="k-${esc(e.kind)}">${icon(o[0], 14)}<span>${esc(e.content)}</span><time>${fmt.time(e.at)}</time></li>`; }).join('') || `<li class="muted">아직 기록이 없습니다. 탐색을 시작하세요.</li>`}</ol></div>
      </details>
      </div>
      <div class="fg-col fg-b">
      <section class="panel">
        <header class="panel-head"><h2>${icon('route', 16)}이어진 길</h2><span class="muted small">${s.hidden_paths ? `찾지 못한 길 ${s.hidden_paths}` : '모두 찾음'}</span></header>
        <div class="panel-body">
          <ul class="paths">
            ${parent ? `<li><button class="path back" data-move="${esc(parent.node_id)}" ${blocked ? 'disabled' : ''}>${icon('back', 16)}<span><b>${esc(parent.name)}</b><small>되돌아가기</small>${stateWhy ? `<small class="path-why">${esc(stateWhy)}</small>` : ''}</span></button></li>` : ''}
            ${kids.map(k => { const why = whyNot(k); return `<li><button class="path ${why ? 'locked' : ''}" data-move="${esc(k.node_id)}" ${why ? 'disabled' : ''}>${icon('chevron', 16)}<span><b>${esc(k.name)}</b><small>${esc(DEPTH[k.level - 1] || '')} · Lv.${k.min_level}+ · 채집터 ${k.spots_found}/${k.spots_total}</small>${why ? `<small class="path-why">${esc(why)}</small>` : ''}</span></button></li>`; }).join('')}
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

      </div>
    </div>
    ${fishPanel(blocked)}
    <details class="panel fold"><summary class="panel-head"><h2>${icon('map', 16)}${esc(s.region.region_name)} 답사 지도 · ${s.survey?.pct ?? 0}%</h2></summary>
      <div class="panel-body">${tree(s)}</div></details>
    <details class="panel fold"><summary class="panel-head"><h2>${icon('sword', 16)}출몰 요괴</h2></summary>
      <div class="panel-body"><ul class="foe-list">${(s.monsters || []).map(m => m.revealed === false
        ? `<li class="locked"><b>???</b>${m.role === 'guardian' ? chip('우두머리', 'bad') : ''}<small>${esc(m.kind_name || '')} · 답사도 ${m.need}%에 드러납니다</small></li>`
        : `<li><b>${esc(m.name)}</b>${m.role === 'guardian' ? chip('우두머리', 'bad') : ''}<small>${esc(m.type || '')}${m.kind_name ? ` · ${esc(m.kind_name)}` : ''} · Lv.${m.min_level}–${m.max_level}</small></li>`).join('')}</ul>
        ${loreHtml(s.lore)}</div></details>
    ${people(roster, s.corpses)}`;
}

// 물가 지역의 낚시터: 낚싯대가 가방에 있으면 탐색력 1로 낚는다(20초 간격). 결과와 도감은 서버가 기록한다.
function fishPanel(blocked) {
  const f = fishSpot; if (!f) return '';
  const recent = (f.recent || []).slice(0, 3);
  return `<section class="panel fish-panel"><header class="panel-head"><h2>${icon('leaf', 16)}낚시터 · ${esc(f.ground_name)}</h2><a class="btn small ghost" href="#/log/codex">도감 ${f.species_caught}/${f.species_total}</a></header>
    <div class="panel-body">
      <p class="desc">${esc(f.description || '')}</p>
      <div class="fish-act">
        <button class="btn primary" id="fish-go" data-ready="${f.ready_at ? new Date(f.ready_at).getTime() : ''}" ${blocked || !f.rod ? 'disabled' : ''}>${icon('leaf', 16)}<span>낚시하기</span></button>
        <small class="muted">${f.rod ? `${esc(f.rod_name)} · 탐색력 1 · 20초마다` : '낚싯대가 없습니다. 상점에서 사거나 가방 › 제작에서 만들 수 있습니다.'}</small>
      </div>
      ${recent.length ? `<ol class="field-log">${recent.map(r => `<li>${icon('leaf', 14)}<span>${esc(r.text)}</span><time>${fmt.time(r.at)}</time></li>`).join('')}</ol>` : '<p class="muted small">시간대와 날씨에 따라 잘 무는 물고기가 다릅니다. 도감에서 힌트를 확인하세요.</p>'}
    </div></section>`;
}

// 접기 상태 기억(이 기기). 기본은 펼침.
function foldOpen(k) { try { return localStorage.getItem('yh-fold-' + k) !== '0'; } catch { return true; } }
document.addEventListener('toggle', e => { const d = e.target; if (d?.dataset?.fold) try { localStorage.setItem('yh-fold-' + d.dataset.fold, d.open ? '1' : '0'); } catch {} }, true);

// 답사 지도: 찾은 장소는 이름과 「길 찾음/전체 · 채집터 찾음/전체」를 말로 적고, 다 찾은 곳은 표시, 못 찾은 길은 그 자리에 빈칸으로 보인다
function tree(s) {
  const nodes = s.nodes || [], byParent = new Map();
  for (const n of nodes) { const k = n.parent_id || 'root'; (byParent.get(k) || byParent.set(k, []).get(k)).push(n); }
  const left = n => (n.paths_total - n.paths_found) + (n.spots_total - n.spots_found);
  const walk = pid => (byParent.get(pid) || []).map(n => {
    const missing = Math.max(0, n.paths_total - n.paths_found), done = !left(n);
    return `<li><button class="${n.here ? 'here' : ''} ${done ? 'done' : ''}" data-move="${esc(n.node_id)}">
        ${icon(done ? 'check' : n.here ? 'pin' : 'chevron', 13)}<span class="t-name">${esc(n.name)}${n.here ? '<em>지금 여기</em>' : ''}</span>
        <small>${n.paths_total ? `길 ${n.paths_found}/${n.paths_total}` : '막다른 곳'}${n.spots_total ? ` · 채집터 ${n.spots_found}/${n.spots_total}` : ''}</small></button>
      ${byParent.has(n.node_id) || missing ? `<ul>${walk(n.node_id)}${Array.from({ length: missing }, () => `<li class="t-unknown">${icon('help', 13)}<span>찾지 못한 곳</span><small>${esc(n.name)}에서 탐색</small></li>`).join('')}</ul>` : ''}</li>`;
  }).join('');
  const sv = s.survey || {}, pct = sv.pct ?? 0;
  const steps = [[30, '심부 원정지'], [70, '핵심 원정지'], [100, '완전 답사 · 가방 +1칸']];
  return `<div class="survey-sum">
      <div class="bar"><i style="width:${Math.min(100, pct)}%"></i>${steps.map(([p]) => `<b style="left:${p}%" class="${pct >= p ? 'on' : ''}"></b>`).join('')}</div>
      <p class="small">찾은 장소 <b>${sv.nodes_found ?? 0}/${sv.nodes_total ?? 0}</b> · 찾은 채집터 <b>${sv.spots_found ?? 0}/${sv.spots_total ?? 0}</b> · ${steps.map(([p, t]) => `<span class="${pct >= p ? 'ok' : 'muted'}">${p}% ${t}</span>`).join(' · ')}</p>
    </div>
    <ul class="tree">${walk('root')}</ul>
    <p class="muted small">「길」은 그 장소에서 이어지는 다음 장소, 「채집터」는 그 장소의 채집터입니다(찾은 수/전체). 표시된 곳은 다 찾았고, 「찾지 못한 곳」은 바로 위 장소에서 탐색하면 드러납니다. 이름을 누르면 그곳으로 갑니다.</p>`;
}

function people(roster, corpses) {
  const list = Array.isArray(roster) ? roster : [];
  const dead = corpses || [];
  return `<section class="panel"><header class="panel-head"><h2>${icon('users', 16)}여기 있는 이들</h2><a class="btn small ghost" href="#/party">동료</a></header><div class="panel-body">
    ${list.length ? `<ul class="people">${list.map(p => `<li>${emblem(p.owner_id, p.profile, 34)}<div><b>${cardName(p.owner_id, p.character_name)}${sealMark(p.profile?.seal)}${gmBadge(p.owner_id)}</b><small>Lv.${p.level} · ${esc(nameOf(p.job_key))}${p.away ? ' · 원정 중' : ''}${p.in_combat ? ' · 전투 중' : ''}${p.downed ? ' · 전투불능' : ''}</small></div>
      ${p.downed && !p.is_dead ? `<button class="btn small primary" data-rescue="${esc(p.owner_id)}">구조</button>` : ''}</li>`).join('')}</ul>` : `<p class="muted small">같은 곳에 다른 조사원이 없습니다.</p>`}
    ${dead.length ? `<h3 class="sub-h">쓰러진 이의 자리</h3><ul class="people">${dead.map(d => `<li><span class="emblem corpse">${icon('flame', 18)}</span><div><b>${esc(d.character_name)}의 시신</b><small>${new Date(d.died_at).toLocaleDateString('ko-KR')} · ${esc(d.death_reason || '')}${d.items_left ? ` · 유품 ${d.items_left}점` : ''}</small></div>
      <div class="btn-row">${d.can_respect ? `<button class="btn small" data-respect="${esc(d.corpse_id)}">명복 빌기</button>` : ''}${d.items_left ? `<button class="btn small" data-loot="${esc(d.corpse_id)}">유품 수습</button>` : ''}</div></li>`).join('')}</ul>` : ''}
  </div></section>`;
}

/* ── 동작 ──────────────────────────────────────────────── */
function bind(s) {
  $('#pt-exp', el)?.addEventListener('click', () => openExpeditionWindow());
  $('#search', el)?.addEventListener('click', e => doSearch(e.currentTarget));
  $$('[data-move]', el).forEach(b => b.onclick = () => guard(b, () => act('world_field_move', { p_node_id: b.dataset.move }), { success: '' }));
  $$('[data-gather]', el).forEach(b => b.onclick = () => guard(b, async () => { const r = await act('world_field_gather', { p_spot_id: b.dataset.gather }); window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'gather' })); return r; }));
  $$('[data-rescue]', el).forEach(b => b.onclick = () => guard(b, () => act('world_rescue_character', { p_target: b.dataset.rescue })));
  $$('[data-respect]', el).forEach(b => b.onclick = () => guard(b, () => act('world_corpse_respect', { p_corpse_id: b.dataset.respect })));
  $$('[data-loot]', el).forEach(b => b.onclick = async () => { if (await ask('유품을 수습할까요? 다른 조사원이 남긴 물건을 가져갑니다.', { title: '유품 수습', ok: '수습하기' })) guard(b, () => act('world_corpse_loot', { p_corpse_id: b.dataset.loot })); });
  const openExp = () => openExpedition();
  $('#exp-open', el)?.addEventListener('click', openExp); $('#exp-open2', el)?.addEventListener('click', openExp); $('#exp-open3', el)?.addEventListener('click', openExp);
  $('#camp', el)?.addEventListener('click', () => openRest(s.region));
  $('#idle-rest', el)?.addEventListener('click', goIdleRest);
  $('#ov-open', el)?.addEventListener('click', async () => (await import('../overflow.js')).openOverflow());
  $$('[data-fac]', el).forEach(b => b.onclick = () => openFacility(b.dataset.fac, s));
  $('#fish-go', el)?.addEventListener('click', e => doFish(e.currentTarget));
}

async function doSearch(btn) {
  if (btn.dataset.busy === '1') return;
  // 체력이 낮으면 요괴를 만났을 때 쓰러지기 쉽다: 한 번 묻는다
  const hp = Number(store.character?.health ?? 100);
  if (hp < 35 && !(await ask(`체력이 ${hp}입니다. 탐색하다 요괴를 만나면 쓰러질 수 있습니다. 쉬거나 회복약을 먼저 쓰는 것이 좋습니다.`, { title: '체력이 낮습니다', ok: '그래도 탐색', cancel: '그만두기' }))) return;
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
async function doFish(btn) {
  if (btn.dataset.busy === '1' || Number(btn.dataset.ready) > Date.now()) return;
  btn.dataset.busy = '1'; btn.disabled = true;
  window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'gather' }));
  try {
    const r = await act('world_fish');
    if (r.caught) { window.dispatchEvent(new CustomEvent('yh-sfx', { detail: ['rare', 'epic', 'legendary'].includes(r.rarity) || r.first ? 'find' : 'tick' })); showFind(['leaf', r.first ? '새 어종' : '낚시'], { outcome: r.first ? 'spot' : 'gather', content: r.content }); }
    else toast(r.content, 'info');
  } catch (e) { const { friendlyError } = await import('../core.js'); toast(friendlyError(e), 'error'); }
  finally { btn.dataset.busy = ''; }
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
  $$('#fish-go', el).forEach(b => { const t = Number(b.dataset.ready); if (!t || b.dataset.busy === '1') return; if (t > now) { b.disabled = true; b.querySelector('span').textContent = fmt.remain(t - now); } else { b.dataset.ready = ''; b.disabled = false; b.querySelector('span').textContent = '낚시하기'; } });
  $$('[data-gather]', el).forEach(b => { const t = Number(b.dataset.ready); if (!t) return; if (t > now) { b.disabled = true; b.textContent = fmt.remain(t - now); } else { b.dataset.ready = ''; b.disabled = false; b.textContent = '채집'; } });
  const line = restLine(now);
  $$('[data-rest-line]', el).forEach(x => { const fac = x.closest('.facility'); if (x.dataset.restLine === 'short') { const h = restParts(now); if (x.innerHTML !== h) x.innerHTML = h; } else x.textContent = line || (fac ? '쉬며 회복하고 탐색력 채우기' : ''); });
  $$('.modal [data-rest]').forEach(b => { const t = restAt(b.dataset.rest), sm = b.querySelector('[data-rest-cd]'); if (!sm) return;
    if (t > now) { b.disabled = true; sm.textContent = `다시 쉬기까지 ${fmt.remain(t - now)}`; } else if (sm.textContent) { b.disabled = false; sm.textContent = ''; } });
  const c = store.character;
  $$('[data-death]', el).forEach(s => { const t = c?.downed_at ? new Date(c.downed_at).getTime() + 4 * 3600e3 : 0; s.textContent = t ? `목숨이 다하기까지 ${fmt.remain(t - now)}` : ''; });
}

/* ── 창 ───────────────────────────────────────────────── */
// 자율 활동 › 휴식으로 바로 보낸다(캐릭터 › 자율 화면이 휴식 칸을 짚어 준다)
function goIdleRest() { try { sessionStorage.setItem('yh-idle-focus', 'rest'); } catch {} window.yahangGo('char', 'idle'); }
function openFacility(k, s) {
  if (k === 'depart') return window.yahangGo('map');
  if (k === 'board') return window.yahangGo('log', 'story');
  if (k === 'faction') return window.yahangGo('char', 'faction');
  if (k === 'inn') return openRest(s.region);
  if (k === 'idle') return goIdleRest();
  const title = { shop: s.region.shop_name || '상점', smithy: '대장간', market: '거래소', stable: '마구간', storage: '창고' }[k];
  const m = openModal({ title, wide: true, body: '<div class="fac-body"></div>' });
  const box = $('.fac-body', m);
  const fill = () => (k === 'market' ? renderMarket : k === 'stable' ? renderStable : k === 'smithy' ? renderSmithy : k === 'storage' ? renderStorage : renderShop)(box);
  fill();
  const offc = on('changed', () => { if (box.isConnected) fill(); else offc(); });
}

// 예상 회복량(서버 world_field_rest와 같은 식). 바깥 야영은 ⅔이고, 가득 찬 수치는 그만큼 덜 오른다.
function restGain(r, full) {
  const half = v => r.safe ? v : Math.floor(v * 2 / 3);
  const q = r.rest_quality ?? 1;
  return { hp: half((full ? 65 : 25) + q * 5), mn: half(full ? 50 : 20), sp: half(full ? 35 : 12), er: half(full ? 18 : 6) };
}
const gainText = g => `체력 +${g.hp} · 정신 +${g.mn} · 영력 +${g.sp} · 침식 -${g.er}`;

function openRest(r) {
  const safe = r.safe;
  const m = openModal({ title: safe ? (r.rest_spot_name || '숙소') : '야영', body: `
    <p class="desc">${safe ? '안전한 곳에서 쉬면 체력·정신·영력이 회복되고 나쁜 상태가 풀립니다. 푹 쉬면 탐색력이 가득 찹니다.' : '바깥에서 야영합니다. 회복은 적고, 쉬는 동안 습격받을 수 있습니다.'}</p>
    <div class="action-grid two">
      <button class="btn" data-rest="short"><span>잠깐 쉬기</span><small>${gainText(restGain(r, false))}</small><small>${fmt.jeon(r.rest_fee || 0)} · 탐색력 +3 · 10분마다</small><small class="rest-cd" data-rest-cd></small></button>
      <button class="btn primary" data-rest="full"><span>푹 쉬기</span><small>${gainText(restGain(r, true))}</small><small>${fmt.jeon((r.rest_fee || 0) * 2)} · ${safe ? '탐색력 가득' : '탐색력 +6'} · 30분마다</small><small class="rest-cd" data-rest-cd></small></button>
    </div>
    <p class="muted small">이미 가득 찬 수치는 그만큼 덜 오릅니다. 쉬고 나면 실제로 오른 만큼을 알려 드립니다. 같은 방식의 휴식은 잠깐 쉬기 10분, 푹 쉬기 30분이 지나야 다시 할 수 있습니다.</p>` });
  tick();
  $$('[data-rest]', m).forEach(b => b.onclick = () => guard(b, async () => { const out = await act('world_field_rest', { p_style: b.dataset.rest }); closeModal(); return out; }));
}

const openExpedition = () => openExpeditionWindow();

// 이 지역에서 얻는 것: 답사도 30% 채집 재료 → 70% 요괴 전리품 → 100% 희귀품(서버 world_field_snapshot.lore가 가린다)
function loreHtml(l) {
  if (!l) return '';
  const row = (label, need, list) => `<li class="${list ? '' : 'locked'}"><b>${label}</b>${list ? `<small>${list.map(k => esc(nameOf(k))).join(', ') || '없음'}</small>` : `<small>답사도 ${need}%에 드러납니다</small>`}</li>`;
  return `<h3 class="sub-h">이 지역에서 얻는 것 <small class="muted">답사도 ${l.pct ?? 0}%</small></h3><ul class="foe-list">
    ${row('채집 재료', 30, l.gather)}${row('요괴 전리품', 70, l.drops)}${row('희귀품', 100, l.rare)}</ul>
    <p class="muted small">원정과 탐색으로 답사도를 올리면 출몰 요괴와 얻는 것이 차례로 드러납니다. 이미 만난 요괴는 바로 보입니다.</p>`;
}
