// 일지: 사건 조사 · 지역 답사 · 원정 기록. 사건 단서가 있는 지역으로 바로 이동할 수 있다.
import { db, store, on, act, nameOf, esc, icon, guard, $, $$, fmt, empty, segmented, bindSegmented, bar } from '../core.js';
import { load, panel, chip, loading, errorBox, currentRegion } from './common.js';
import { focusRegion } from './map.js';
import { showResult } from './expedition.js';

const SUBS = [['case', '사건'], ['survey', '답사'], ['history', '원정 기록']];
let el, sub = 'case', off = [];

export async function render(root, s) {
  if (!store.character) return;
  el = root; sub = SUBS.some(x => x[0] === s) ? s : 'case';
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('scroll', 14)} 조사원 일지</p><h1>일지</h1></div></div>
    ${segmented('log-sub', SUBS, sub)}<div id="log-body"></div>`;
  bindSegmented(el, 'log-sub', k => { sub = k; history.replaceState(null, '', `#/log/${k}`); draw(); });
  off.forEach(f => f()); off = [on('changed', () => draw(true))];
  await draw();
}
export function destroy() { off.forEach(f => f()); off = []; }

async function draw(soft) {
  const body = $('#log-body', el); if (!body) return;
  if (!soft) body.innerHTML = loading();
  try { await ({ case: cases, survey, history })[sub](body); }
  catch (e) { body.innerHTML = errorBox(e.message); }
}

// 지역 바로가기: 인접하면 바로 출발, 아니면 지도에서 경로를 보여 준다.
function goButton(regionId, map) {
  const r = (map?.regions || []).find(x => x.region_id === regionId);
  const here = currentRegion(map);
  if (!r) return '';
  if (here?.region_id === regionId) return chip('현재 위치', 'ok');
  if (r.reachable && !r.level_locked) return `<button class="btn small primary" data-travel="${esc(regionId)}">${icon('route', 14)}<span>${esc(r.region_name)}(으)로 이동</span></button>`;
  return `<button class="btn small" data-route="${esc(regionId)}">${icon('map', 14)}<span>${esc(r.region_name)} 경로 보기</span></button>`;
}
function bindGo(body) {
  $$('[data-travel]', body).forEach(b => b.onclick = () => guard(b, () => act('world_travel_region', { p_region_id: b.dataset.travel })));
  $$('[data-route]', body).forEach(b => b.onclick = () => { focusRegion(b.dataset.route); window.yahangGo('map', 'world'); });
}

/* ── 사건: 단서를 모으고 짝을 맞춰 가설을 세운다 ───────────────── */
const CLUES = [
  ['redseal_footprints', '젖은 발자국', '흔적', 'hq_archive', '뒤꿈치가 깊다. 누군가 뒤로 걸어간 흔적이다.'],
  ['redseal_ink', '먹물 속 이름', '기록', 'hq_archive', '장부의 먹물은 오래된 피와 섞였다. 지워진 이름은 봉인의 매개체다.'],
  ['redseal_bell', '역행하는 방울', '소리', 'shrine_ruins', '방울 소리가 사당 벽 너머에서 울린다. 봉인식의 방향을 가리킨다.'],
  ['redseal_ash', '인장 재의 결', '재료', 'shrine_ruins', '인장 재와 부적 가루는 같은 봉인식에서 비롯되었다.'],
];
const COMBOS = [
  ['redseal_true_identity', '기록에서 지워진 이름', ['redseal_footprints', 'redseal_ink'], '발자국과 장부를 대조해 존재의 정체를 추론한다.'],
  ['redseal_reseal', '역행 봉인식', ['redseal_bell', 'redseal_ash'], '방울과 인장 재의 결을 맞춰 안전한 재봉인을 복원한다.'],
];
const ids = v => Array.isArray(v) ? v.map(x => typeof x === 'string' ? x : x?.clue_id || x?.id).filter(Boolean) : v && typeof v === 'object' ? Object.keys(v) : [];
async function cases(body) {
  const uid = store.character.owner_id;
  const [{ data, error }, map] = await Promise.all([
    db.from('world_case_progress').select('case_id,clues,combined').eq('owner_id', uid).in('case_id', ['red_seal', 'regional_discoveries']),
    load('world_map_snapshot', undefined, { maxAge: 30000 }),
  ]);
  if (error) throw new Error(error.message);
  const red = (data || []).find(r => r.case_id === 'red_seal'), reg = (data || []).find(r => r.case_id === 'regional_discoveries');
  const got = new Set(ids(red?.clues)), combined = new Set(ids(red?.combined));
  const regClues = Array.isArray(reg?.clues) ? reg.clues.filter(x => x?.site_id) : [];
  const regRegions = new Set(regClues.map(x => x.region_id));
  const here = currentRegion(map)?.region_id;
  const solved = COMBOS.every(([k]) => combined.has(k));
  body.innerHTML = `
    ${panel('붉은 인장의 실종', `
      <p class="desc">지난 초하루 회수된 부적의 기록이 장부에서 사라졌습니다. 장서각 지하서고와 폐쇄 사당에서 단서를 모으고, 짝이 맞는 단서를 조합해 가설을 세우세요.</p>
      <p class="muted small">두 가설을 모두 세우면 사건이 끝나고 경험치·영력·요기 결정과 함께 <b>가방 +20칸</b>, 특별 탈것 <b>홍인 해태</b>를 받습니다.</p>
      <div class="chips">${chip(`단서 ${got.size}/4`, 'accent')}${chip(`가설 ${[...combined].filter(k => COMBOS.some(c => c[0] === k)).length}/2`)}${solved ? chip('사건 종결', 'ok') : ''}</div>
      <div class="clue-grid">${CLUES.map(([k, n, tag, reg, d]) => {
        const has = got.has(k), there = here === reg;
        return `<article class="clue ${has ? 'on' : ''}"><header><b>${has ? esc(n) : '미확인 단서'}</b>${chip(tag)}</header>
          <p>${has ? esc(d) : `${esc(nameOf(reg))}에서 조사할 수 있습니다.`}</p>
          ${has ? chip('확보', 'ok') : there ? `<button class="btn small primary" data-clue="${k}">${icon('search', 14)}<span>조사</span></button>` : goButton(reg, map)}</article>`; }).join('')}</div>
      <h3 class="sub-h">가설 조합</h3>
      <div class="combo-grid">${COMBOS.map(([k, n, need, d]) => {
        const done = combined.has(k), ready = need.every(x => got.has(x));
        return `<article class="combo ${done ? 'on' : ''}"><b>${esc(n)}</b><p>${esc(d)}</p>
          <div class="combo-need">${need.map(x => `<span class="${got.has(x) ? 'ok' : ''}">${got.has(x) ? esc(CLUES.find(c => c[0] === x)[1]) : '?'}</span>`).join(icon('plus', 12))}</div>
          ${done ? chip('결론 확정', 'ok') : `<button class="btn small ${ready ? 'primary' : ''}" data-combo="${k}" ${ready ? '' : 'disabled'}>${ready ? '가설 확정' : '단서 부족'}</button>`}</article>`; }).join('')}</div>`, { ico: 'search' })}
    ${panel('지역 답사 보고서', `
      <p class="desc">지점 조사나 원정에서 지역 단서를 얻을 수 있습니다. 서로 다른 3개 지역의 단서를 모아 보고서를 내면 보상과 함께 <b>가방 +20칸</b>을 받습니다.</p>
      <div class="chips">${chip(`단서 ${regClues.length}개`)}${chip(`지역 ${regRegions.size}/3`, regRegions.size >= 3 ? 'ok' : '')}</div>
      ${regRegions.size ? `<p class="muted small">기록한 지역: ${esc([...regRegions].map(nameOf).join(', '))}</p>` : ''}
      <button class="btn ${regRegions.size >= 3 ? 'primary' : ''}" id="reg-submit" ${regRegions.size >= 3 ? '' : 'disabled'}>${icon('scroll', 16)}<span>보고서 제출</span></button>`, { ico: 'map' })}`;
  $$('[data-clue]', body).forEach(b => b.onclick = () => guard(b, () => act('world_case_investigate', { p_clue_id: b.dataset.clue })));
  $$('[data-combo]', body).forEach(b => b.onclick = () => guard(b, () => act('world_case_combine', { p_combination_id: b.dataset.combo })));
  const rs = $('#reg-submit', body); if (rs) rs.onclick = () => guard(rs, () => act('world_case_combine_regional'));
  bindGo(body);
}

/* ── 답사: 지역별 답사도 ──────────────────────────────────── */
async function survey(body) {
  const [o, map] = await Promise.all([load('world_exploration_overview'), load('world_map_snapshot', undefined, { maxAge: 30000 })]);
  const groups = {};
  (o.regions || []).forEach(r => (groups[r.territory_name || '기타'] ||= []).push(r));
  const done = (o.regions || []).filter(r => r.progress >= 100).length;
  body.innerHTML = `
    <p class="desc">원정을 다녀올수록 지역 답사도가 오릅니다. 30%에서 심부, 70%에서 핵심 원정지가 열리고, 100%에 이르면 가방이 넓어집니다. 다섯 지역을 완전히 답사하면 특별한 동행이 나타난다고 합니다.</p>
    <div class="chips">${chip(`완전 답사 ${done}곳`, 'accent')}</div>
    ${Object.entries(groups).map(([t, list]) => panel(t, `<ul class="survey-list">${list.map(r => `<li class="${r.safe_zone ? 'safe' : ''}">
        <div><b>${esc(r.region_name)}</b><small>${r.safe_zone ? '안전지대' : `위험 ${r.danger} · Lv.${r.min_level}+ · 원정 ${r.expeditions}회`}</small></div>
        ${r.safe_zone ? chip('상점·거래소', 'ok') : `<div class="sv-bar">${bar(r.progress, 100, 'xp')}<span>${r.progress}%</span></div>`}
        ${goButton(r.region_id, map)}</li>`).join('')}</ul>`, { cls: 'compact' })).join('')}`;
  bindGo(body);
}

/* ── 원정 기록 ─────────────────────────────────────────── */
const ENDED = { complete: '무사 귀환', recalled: '조기 귀환', downed: '쓰러짐', exhausted: '탈진' };
async function history(body) {
  const o = await load('world_exploration_overview');
  const list = o.history || [];
  body.innerHTML = list.length ? `<ul class="spot-list">${list.map((h, i) => `<li><div><b>${esc(h.ground_name)}</b>
      <small>${new Date(h.finished_at).toLocaleString('ko-KR', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })} · ${h.minutes}분 · ${nameOf(h.stance)} · ${ENDED[h.result?.ended] || ''} · 전투 ${h.result?.wins ?? 0}승 · 답사도 ${h.result?.progress_after ?? '-'}%</small></div>
      <button class="btn small ghost" data-h="${i}">자세히</button></li>`).join('')}</ul>` : empty('아직 다녀온 원정이 없습니다. 위험 지역의 현장에서 원정을 떠나 보세요.', 'flame');
  $$('[data-h]', body).forEach(b => b.onclick = () => { const h = list[Number(b.dataset.h)]; showResult({ ground_name: h.ground_name, result: h.result }); });
}
