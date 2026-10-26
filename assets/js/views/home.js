// 현장: 지금 있는 지역에서 할 수 있는 일.
// 안전지대 — 상점·거래소·마구간·휴식 / 위험 지역 — 요괴 수색·전투·원정·채집·탐사 지점.
import { store, on, act, nameOf, esc, icon, bar, guard, $, $$, fmt, empty, emblem } from '../core.js';
import { load, panel, chip, danger, loading, errorBox, currentRegion, itemsText, safeZones } from './common.js';
import { renderShop, renderMarket, renderStable } from './services.js';
import { renderExpedition } from './expedition.js';

const TACTICS = [
  ['attack', '정면 공격', '근접 피해'], ['ranged', '원거리 사격', '거리 유지'], ['seal', '봉인 부적', '영력 소모·큰 피해'],
  ['analyze', '약점 분석', '다음 공격 강화'], ['support', '응급 지원', '체력 회복'], ['guard', '방어 태세', '피해 감소'],
];
let el, off = [], sub = '', safeTab = 'shop';

export async function render(root, s) {
  if (!store.character) return;
  el = root; sub = s;
  el.innerHTML = loading();
  off.forEach(f => f()); off = [on('changed', () => draw())];
  window.addEventListener('yahang:arrived', draw);
  await draw();
}
export function destroy() { off.forEach(f => f()); off = []; window.removeEventListener('yahang:arrived', draw); }

async function draw() {
  if (!el?.isConnected) return;
  const c = store.character;
  let map, enc, board, zones;
  try {
    [map, enc, board, zones] = await Promise.all([
      load('world_map_snapshot', undefined, { maxAge: 30000 }), load('world_region_encounter_snapshot'),
      load('world_expedition_board'), safeZones(),
    ]);
  } catch (e) { el.innerHTML = errorBox(e.message); return; }
  const region = currentRegion(map);
  const zone = region ? zones.get(region.region_id) : null;
  const safe = !!zone?.is_safe_zone;
  const [sites, roster] = await Promise.all([
    region && !safe ? load('world_region_site_snapshot', { p_region_id: region.region_id }).catch(() => null) : null,
    load('world_region_roster', undefined, { maxAge: 15000 }).catch(() => []),
  ]);
  const traveling = c.travel_arrives_at && new Date(c.travel_arrives_at) > new Date();
  const fighting = enc?.active;
  const downed = c.downed_at || c.health <= 0;
  const away = !!board?.active;
  const blocked = traveling || downed || fighting || away;

  el.innerHTML = `
    <div class="view-head">
      <div><p class="eyebrow">${icon('pin', 14)} ${esc(nameOf(region?.territory_id) || '미등록 지역')} ${safe ? '· 안전지대' : region ? `· 위험 ${region.danger_level}` : ''}</p>
        <h1>${esc(c.location)}</h1></div>
      <div class="head-actions"><a class="btn ghost" href="#/map">${icon('map', 16)}<span>지도</span></a></div>
    </div>
    ${downed ? `<div class="notice danger">${icon('heart', 18)}<div><b>전투불능</b><span>회생 부적을 쓰거나 다른 조사원의 구조를 기다리세요. 같은 지역 조사원에게 구조 요청이 전달됩니다.</span></div><a class="btn small" href="#/char/status">회복하기</a></div>` : ''}
    ${traveling ? `<div class="notice travel">${icon('route', 18)}<div><b>${esc(nameOf(c.travel_destination))}(으)로 이동 중</b><span>도착하면 그 지역에서 행동할 수 있습니다.</span></div></div>` : ''}
    ${safe ? safeLayout(region, zone) : dangerLayout(region, enc, blocked, away)}
    ${!safe ? sitesCard(sites, blocked) : ''}
    <div class="grid-2">${restCard(region, traveling || downed || fighting || away)}${peopleCard(roster)}</div>`;

  if (safe) {
    const box = $('#safe-body', el);
    const show = k => { safeTab = k; $$('[data-safe]', el).forEach(b => b.classList.toggle('on', b.dataset.safe === k)); (k === 'market' ? renderMarket : k === 'stable' ? renderStable : renderShop)(box); };
    $$('[data-safe]', el).forEach(b => b.onclick = () => show(b.dataset.safe));
    if (safeTab === 'stable' && !zone.has_stable) safeTab = 'shop';
    show(safeTab);
  } else {
    const ex = $('#exp-body', el); if (ex) renderExpedition(ex, board);
  }
  bind(region);
  if (sub === 'combat') $('#combat', el)?.scrollIntoView({ block: 'start', behavior: 'smooth' });
  if (sub === 'expedition') $('#expedition', el)?.scrollIntoView({ block: 'start', behavior: 'smooth' });
}

function regionCard(r, safe = false) {
  if (!r) return panel('지역 정보', empty('세계 지도에 등록되지 않은 장소입니다. 지도에서 지역을 골라 이동하세요.', 'map'), { ico: 'eye' });
  const monsters = (r.monsters || []).slice(0, 4);
  return panel('지역 정보', `
    <div class="chips">${safe ? chip('안전지대', 'ok') : danger(r.danger_level)}${chip(nameOf(r.region_type))}${chip(`권장 Lv.${r.min_level}+`)}${r.faction_control ? chip(r.faction_control) : ''}</div>
    <p class="desc">${esc(r.description || '')}</p>
    <dl class="kv">
      <div><dt>채집 자원</dt><dd>${(r.gather_nodes || []).length ? r.gather_nodes.map(nameOf).map(esc).join(', ') : '없음'}</dd></div>
      ${safe ? '' : `<div><dt>출현 요괴</dt><dd>${monsters.length ? monsters.map(m => `${esc(m.monster_name)} <small>Lv.${m.min_level}–${m.max_level}</small>`).join(', ') : '확인된 요괴 없음'}</dd></div>`}
    </dl>`, { ico: 'eye' });
}

function safeLayout(r, zone) {
  return `
    <div class="notice safe">${icon('shield', 18)}<div><b>안전지대</b><span>요괴가 들어오지 못하는 곳입니다. 상점과 거래소에서 물자를 정리하고 원정을 준비하세요.</span></div></div>
    <div class="grid-2 wide-left">
      ${panel(zone.shop_name || '상점', `<div class="seg-mini"><button data-safe="shop">상점</button><button data-safe="market">거래소</button>${zone.has_stable ? '<button data-safe="stable">마구간</button>' : ''}</div><div id="safe-body"></div>`, { ico: 'shop', id: 'services' })}
      ${regionCard(r, true)}
    </div>`;
}

function dangerLayout(r, enc, blocked, away) {
  return `
    <div class="grid-2">
      ${enc?.active ? combatCard(enc) : encounterCard(r, enc, blocked)}
      ${panel('원정', '<div id="exp-body"></div>', { ico: 'flame', id: 'expedition', cls: away ? 'combat' : '' })}
    </div>
    <div class="grid-2">${regionCard(r)}${gatherCard(r, blocked)}</div>`;
}

function encounterCard(r, enc, blocked) {
  const last = enc && (enc.defeated || enc.fled) ? `<p class="muted small">최근 전투: ${esc(enc.monster_name)} · ${enc.defeated ? `토벌 성공${enc.drops ? ' · ' + esc(itemsText(enc.drops)) : ''}` : '후퇴'}</p>` : '';
  return panel('요괴 수색', `
    <p class="desc">지역을 직접 수색해 요괴와 맞섭니다. 전술을 골라 싸우며, 원정보다 빠르게 전투 숙련과 전리품을 얻습니다.</p>
    ${last}
    <button class="btn primary block" id="encounter" ${blocked || !r ? 'disabled' : ''}>${icon('target', 16)}<span>수색 시작</span></button>`, { ico: 'sword', id: 'combat' });
}

function combatCard(e) {
  return panel(`전투 · ${e.monster_name}`, `
    <div class="enemy"><div class="enemy-top"><b>${esc(e.monster_name)}</b><span>${fmt.num(e.current_hp)} / ${fmt.num(e.max_hp)}</span></div>${bar(e.current_hp, e.max_hp, 'enemy')}
      ${e.monster_type ? `<p class="muted small">${esc(e.monster_type)} · 공격력 ${fmt.num(e.attack_power)}</p>` : ''}
      ${e.description ? `<p class="desc">${esc(e.description)}</p>` : ''}</div>
    <div class="tactics">${TACTICS.map(([k, n, d]) => `<button class="btn tactic" data-tactic="${k}"><b>${n}</b><small>${d}</small></button>`).join('')}</div>
    <div class="row-end"><button class="btn ghost small" data-combat="flee">${icon('back', 14)}<span>후퇴</span></button></div>
    <p class="muted small">전투 중에는 이동할 수 없습니다.</p>`, { ico: 'sword', cls: 'combat', id: 'combat' });
}

function gatherCard(r, blocked) {
  const nodes = r?.gather_nodes || [];
  const body = !r ? empty('지도에 등록된 지역에서 채집할 수 있습니다.', 'leaf')
    : !nodes.length ? empty('이 지역에는 채집할 자원이 없습니다. 다른 지역을 찾아보세요.', 'leaf')
    : `<p class="desc">도구(1단계 이상)를 장착해야 채집할 수 있고, 12초마다 한 번 가능합니다.</p>
      <div class="action-grid">
        <button class="btn primary" data-gather="field" ${blocked ? 'disabled' : ''}>${icon('leaf', 16)}<span>주변 채집</span><small>지역 자원 무작위</small></button>
        ${nodes.map(n => `<button class="btn" data-gather="${esc(n)}" ${blocked ? 'disabled' : ''}><span>${esc(nameOf(n))}</span><small>집중 채집</small></button>`).join('')}
        ${r.region_type === 'sealed_shrine' ? `<button class="btn" data-gather="shrine" ${blocked ? 'disabled' : ''}><span>사당 조사</span><small>영기 가루·비단</small></button>` : ''}
      </div>`;
  return panel('채집', body, { ico: 'leaf' });
}

function sitesCard(s, blocked) {
  const sites = s?.sites || [];
  const body = !sites.length ? empty('이 지역에서 확인된 탐사 지점이 없습니다.', 'search') : `<div class="cards">${sites.map(x => `
    <article class="site">
      <header><b>${esc(x.site_name.replace(/^.*·\s*/, ''))}</b>${chip(nameOf(x.site_type))}</header>
      <p>${esc(x.description || '')}</p>
      <p class="muted small">주요 획득: ${esc((x.loot_table || []).slice(0, 5).map(nameOf).join(', '))}</p>
      <button class="btn small" data-site="${esc(x.site_id)}" ${blocked ? 'disabled' : ''}>${icon('search', 14)}<span>지점 조사</span></button>
    </article>`).join('')}</div>
    <p class="muted small">지점 조사에서 찾은 단서는 일지 › 사건의 지역 답사 보고서에 쓰입니다.</p>`;
  return panel('탐사 지점', body, { ico: 'search' });
}

function restCard(r, blocked) {
  return panel('휴식', !r ? empty('휴식처가 없는 장소입니다.') : `
    <p class="desc">${esc(r.rest_spot_name || '임시 야영지')} · 품질 ${r.rest_quality ?? '-'} · 위험 ${r.rest_risk ?? 0}%</p>
    <div class="action-grid two">
      <button class="btn" data-rest="short" ${blocked ? 'disabled' : ''}><span>짧은 휴식</span><small>${fmt.jeon(r.rest_fee)}</small></button>
      <button class="btn" data-rest="full" ${blocked ? 'disabled' : ''}><span>깊은 휴식</span><small>상태이상 일부 해소</small></button>
    </div>`, { ico: 'moon' });
}

function peopleCard(roster) {
  const list = Array.isArray(roster) ? roster : [];
  const body = list.length ? `<ul class="people">${list.map(p => `<li>${emblem(p.owner_id, p.profile, 34)}<div><b>${esc(p.character_name)}</b><small>Lv.${p.level} · ${esc(nameOf(p.job_key))}${p.away ? ' · 원정 중' : ''}${p.in_combat ? ' · 전투 중' : ''}</small>${p.profile?.bio ? `<small class="muted">${esc(p.profile.bio)}</small>` : ''}</div>
      ${p.downed && !p.is_dead ? `<button class="btn small primary" data-rescue="${esc(p.owner_id)}">구조</button>` : ''}</li>`).join('')}</ul>`
    : empty('같은 지역에 다른 조사원이 없습니다.', 'users');
  return panel('같은 지역의 조사원', body, { ico: 'users', extra: '<a class="btn small ghost" href="#/party">동료</a>' });
}

function bind(region) {
  const enc = $('#encounter', el);
  if (enc) enc.onclick = () => guard(enc, async () => { const r = await act('world_region_encounter', { p_region_id: region.region_id }); return { content: r?.message || `${r?.monster_name || '요괴'}와(과) 마주쳤습니다.` }; });
  $$('[data-tactic]', el).forEach(b => b.onclick = () => guard(b, () => act('world_region_tactic_action', { p_action: b.dataset.tactic })));
  $$('[data-combat]', el).forEach(b => b.onclick = () => guard(b, () => act('world_region_combat_action', { p_action: b.dataset.combat })));
  $$('[data-gather]', el).forEach(b => b.onclick = () => guard(b, () => act('world_gather_action', { p_node: b.dataset.gather })));
  $$('[data-site]', el).forEach(b => b.onclick = () => guard(b, () => act('world_region_site_explore', { p_site_id: b.dataset.site })));
  $$('[data-rest]', el).forEach(b => b.onclick = () => guard(b, () => act('world_rest_at_spot', { p_region_id: region.region_id, p_style: b.dataset.rest })));
  $$('[data-rescue]', el).forEach(b => b.onclick = () => guard(b, () => act('world_rescue_character', { p_target: b.dataset.rescue })));
}
