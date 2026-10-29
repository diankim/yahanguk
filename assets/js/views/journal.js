// 일지: 주 이야기(장마다 단서를 모아 가설을 세운다) · 상시 의뢰 · 지역 답사 · 원정 기록.
// 단서가 있는 지역으로 바로 출발할 수 있다. 단서는 그 지역을 탐색하면 찾을 수 있다.
import { store, on, act, nameOf, esc, icon, guard, $, $$, fmt, empty, segmented, bindSegmented, bar } from '../core.js';
import { load, panel, chip, loading, errorBox, currentRegion } from './common.js';
import { focusRegion } from './map.js';
import { showResult } from './expedition.js';

const SUBS = [['story', '이야기', 'scroll'], ['commission', '의뢰', 'letter'], ['survey', '답사', 'map'], ['history', '원정', 'flame'], ['codex', '도감', 'eye']];
let el, sub = 'story', off = [];

export async function render(root, s) {
  if (!store.character) return;
  el = root; sub = SUBS.some(x => x[0] === s) ? s : 'story';
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('scroll', 14)} 조사원 일지</p><h1>일지</h1></div></div>
    ${segmented('log-sub', SUBS, sub)}<div id="log-body"></div>`;
  bindSegmented(el, 'log-sub', k => { sub = k; window.history.replaceState(null, '', `#/log/${k}`); draw(); });
  off.forEach(f => f()); off = [on('changed', () => draw(true))];
  await draw();
}
export function destroy() { off.forEach(f => f()); off = []; }

async function draw(soft) {
  const body = $('#log-body', el); if (!body) return;
  if (!soft) body.innerHTML = loading();
  try { await ({ story, commission, survey, history: expHistory, codex })[sub](body); }
  catch (e) { body.innerHTML = errorBox(e.message); }
}

// 지역 바로가기: 인접하면 바로 출발, 아니면 지도에서 경로를 보여 준다.
function goButton(regionId, map) {
  const r = (map?.regions || []).find(x => x.region_id === regionId);
  const here = currentRegion(map);
  if (!r) return '';
  if (here?.region_id === regionId) return chip('현재 위치', 'ok');
  if (!r.level_locked) return `<span class="btn-row"><button class="btn small primary" data-travel="${esc(regionId)}">${icon('route', 14)}<span>${esc(r.region_name + '(으)로')} 출발</span></button><button class="btn small ghost" data-route="${esc(regionId)}">${icon('map', 14)}</button></span>`;
  return `<button class="btn small" data-route="${esc(regionId)}">${icon('map', 14)}<span>${esc(r.region_name)} · Lv.${r.min_level}</span></button>`;
}
function bindGo(body) {
  $$('[data-travel]', body).forEach(b => b.onclick = () => guard(b, () => act('world_travel_route', { p_region_id: b.dataset.travel })));
  $$('[data-route]', body).forEach(b => b.onclick = () => { focusRegion(b.dataset.route); window.yahangGo('map', 'world'); });
}

/* ── 이야기: 장마다 단서를 모으고 짝을 맞춰 가설을 세운다 ───────────────── */
async function story(body) {
  const [b, map] = await Promise.all([load('world_story_board'), load('world_map_snapshot', undefined, { maxAge: 30000 })]);
  const chapters = b?.chapters || [];
  const cur = chapters.find(c => c.status === 'active');
  body.innerHTML = `
    ${b?.all_done ? `<div class="notice safe">${icon('moon', 18)}<div><b>지금까지의 이야기를 모두 마쳤습니다</b><span>다음 장은 준비 중입니다. 그동안 의뢰 게시판의 상시 의뢰로 보상을 받을 수 있습니다.</span></div><button class="btn small" data-sub="commission">의뢰 보기</button></div>` : ''}
    <ol class="chapter-line">${chapters.map(c => `<li class="${c.status}"><b>${c.seq}장</b><span>${esc(c.title)}</span></li>`).join('')}</ol>
    ${cur ? chapterCard(cur, map) : ''}
    ${chapters.filter(c => c.status === 'done').reverse().map(c => `<details class="panel fold"><summary class="panel-head"><h2>${icon('check', 16)}${c.seq}장 · ${esc(c.title)}</h2></summary>
      <div class="panel-body"><p class="desc">${esc(c.outro)}</p>${(c.combos || []).map(x => `<p class="muted small"><b>${esc(x.name)}</b> — ${esc(x.conclusion)}</p>`).join('')}</div></details>`).join('')}
    ${chapters.filter(c => c.status === 'locked').map(c => `<section class="panel locked-ch"><header class="panel-head"><h2>${icon('help', 16)}${c.seq}장 · ${esc(c.title)}</h2>${chip(`Lv.${c.min_level}`)}</header>
      <div class="panel-body"><p class="muted small">${c.locked_reason === 'level' ? `레벨 ${c.min_level}부터 시작할 수 있습니다.` : '앞의 장을 마치면 열립니다.'}</p></div></section>`).join('')}
    ${regional(b?.regional)}`;
  // 장을 마치면 장 결말(epilogue)을 대화창으로 보인다
  $$('[data-combo]', body).forEach(x => x.onclick = () => guard(x, async () => {
    const r = await act('world_story_combine', { p_combo_id: x.dataset.combo });
    if (r?.epilogue?.lines?.length) (await import('../factionquest.js')).playDialogue({ title: r.epilogue.title, lines: r.epilogue.lines, cast: r.epilogue.cast,
      extra: `<p class="hint good">${icon('check', 14)} 장을 마쳤습니다</p>` });
    return r;
  }));
  const rs = $('#reg-submit', body); if (rs) rs.onclick = () => guard(rs, () => act('world_case_combine_regional'));
  $$('[data-sub]', body).forEach(x => x.onclick = () => { sub = x.dataset.sub; window.yahangGo('log', sub); });
  bindGo(body);
}
function chapterCard(ch, map) {
  const got = (ch.clues || []).filter(c => c.found).length;
  return panel(`${ch.seq}장 · ${ch.title}`, `
    <p class="desc">${esc(ch.intro)}</p>
    ${ch.scenes_open === false ? `<p class="hint accent">${icon('scroll', 14)} 먼저 현장의 「퀘스트」 칸에서 이 장의 이야기를 따라가세요. 장면을 모두 마치면 단서를 탐색에서 찾을 수 있습니다.</p>` : ''}
    ${ch.rewards?.text ? `<p class="muted small">마치면: ${esc(ch.rewards.text)}</p>` : ''}
    <div class="chips">${chip(`단서 ${got}/${(ch.clues || []).length}`, 'accent')}${chip(`가설 ${(ch.combos || []).filter(x => x.done).length}/${(ch.combos || []).length}`)}</div>
    <div class="clue-grid">${(ch.clues || []).map(k => `<article class="clue ${k.found ? 'on' : ''}"><header><b>${k.found ? esc(k.name) : '찾지 못한 단서'}</b>${chip(k.tag)}</header>
        <p>${k.found ? esc(k.description) : `${esc(k.region_name)} 어딘가에 있습니다. 그곳을 탐색하세요. 깊이 들어갈수록 찾기 쉽습니다.`}</p>
        ${k.found ? chip('확보', 'ok') : goButton(k.region_id, map)}</article>`).join('')}</div>
    <h3 class="sub-h">가설 세우기</h3>
    <div class="combo-grid">${(ch.combos || []).map(x => {
      const ready = (x.needs || []).every(n => (ch.clues || []).find(k => k.clue_id === n)?.found);
      return `<article class="combo ${x.done ? 'on' : ''}"><b>${esc(x.name)}</b><p>${esc(x.done ? x.conclusion : x.description)}</p>
        <div class="combo-need">${(x.needs || []).map(n => { const k = (ch.clues || []).find(y => y.clue_id === n); return `<span class="${k?.found ? 'ok' : ''}">${k?.found ? esc(k.name) : '?'}</span>`; }).join(icon('plus', 12))}</div>
        ${x.done ? chip('결론 확정', 'ok') : `<button class="btn small ${ready ? 'primary' : ''}" data-combo="${esc(x.combo_id)}" ${ready ? '' : 'disabled'}>${ready ? '가설 확정' : '단서 부족'}</button>`}</article>`; }).join('')}</div>`, { ico: 'scroll' });
}
function regional(r) {
  const n = r?.regions || 0;
  return panel('지역 답사 보고서', `
    <p class="desc">탐색하다 보면 지역만의 흔적을 기록할 때가 있습니다. 서로 다른 3개 지역의 기록을 모아 보고서를 내면 보상과 함께 <b>가방 +4칸</b>을 받습니다.</p>
    <div class="chips">${chip(`기록 ${r?.clues || 0}개`)}${chip(`지역 ${Math.min(n, 3)}/3`, n >= 3 ? 'ok' : '')}${r?.submitted ? chip('제출 완료', 'ok') : ''}</div>
    ${r?.submitted ? '' : `<button class="btn ${n >= 3 ? 'primary' : ''}" id="reg-submit" ${n >= 3 ? '' : 'disabled'}>${icon('scroll', 16)}<span>보고서 제출</span></button>`}`, { ico: 'map' });
}

/* ── 상시 의뢰: 날마다 바뀌는 세 가지 일 ─────────────────────── */
async function commission(body) {
  const b = await load('world_commission_board');
  const list = b?.items || [];
  body.innerHTML = `
    <p class="desc">의뢰는 날마다 세 가지씩 새로 붙습니다. 이야기를 다 마친 뒤에도 계속 받을 수 있는 소소한 일거리입니다.</p>
    <p class="muted small">다음 갱신: ${b?.resets_at ? new Date(b.resets_at).toLocaleString('ko-KR', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '자정'}</p>
    <div class="commission-grid">${list.map(x => `<article class="commission ${x.claimed ? 'done' : x.progress >= x.need ? 'ready' : ''}">
      <header>${icon(x.kind === 'hunt' ? 'sword' : x.kind === 'gather' ? 'leaf' : x.kind === 'deliver' ? 'bag' : 'search', 18)}<b>${esc(x.title)}</b></header>
      <p>${esc(x.description)}</p>${bar(Math.min(x.progress, x.need), x.need, 'xp')}
      <small class="muted">${Math.min(x.progress, x.need)}/${x.need} · 보상 ${fmt.jeon(x.reward_gil)} · 경험치 ${x.reward_xp}${x.reward_item ? ` · ${esc(nameOf(x.reward_item))}` : ''}</small>
      ${x.claimed ? chip('완료', 'ok') : `<button class="btn small ${x.progress >= x.need ? 'primary' : ''}" data-claim="${x.slot}" ${x.progress >= x.need ? '' : 'disabled'}>${x.kind === 'deliver' ? '납품하기' : '보상 받기'}</button>`}
    </article>`).join('') || empty('오늘의 의뢰가 없습니다.', 'scroll')}</div>`;
  $$('[data-claim]', body).forEach(x => x.onclick = () => guard(x, () => act('world_commission_claim', { p_slot: Number(x.dataset.claim) })));
}

/* ── 답사: 지역별 답사도 ──────────────────────────────────── */
async function survey(body) {
  const [o, map] = await Promise.all([load('world_survey_overview'), load('world_map_snapshot', undefined, { maxAge: 30000 })]);
  const groups = {};
  (o.regions || []).forEach(r => (groups[r.territory_name || '기타'] ||= []).push(r));
  const done = (o.regions || []).filter(r => r.progress >= 100).length;
  body.innerHTML = `
    <p class="desc">지역마다 숨은 장소와 채집터를 찾아낸 만큼 답사가 오릅니다. 탐색과 원정으로 찾을 수 있습니다. 한 지역을 100% 답사하면 가방이 1칸 넓어지고, 다섯 지역을 완전히 답사하면 특별한 동행이 나타난다고 합니다.</p>
    <div class="chips">${chip(`완전 답사 ${done}곳`, 'accent')}</div>
    ${Object.entries(groups).map(([t, list]) => panel(t, `<ul class="survey-list">${list.map(r => `<li class="${r.safe_zone ? 'safe' : ''}">
        <div><b>${esc(r.region_name)}</b><small>${r.safe_zone ? '안전지대' : `위험 ${r.danger} · Lv.${r.min_level}+ · 장소 ${r.nodes_found}/${r.nodes_total} · 채집터 ${r.spots_found}/${r.spots_total}`}</small></div>
        ${r.safe_zone ? chip('상점·거래소', 'ok') : `<div class="sv-bar">${bar(r.progress, 100, 'xp')}<span>${r.progress}%</span></div>`}
        ${goButton(r.region_id, map)}</li>`).join('')}</ul>`, { cls: 'compact' })).join('')}`;
  bindGo(body);
}

/* ── 원정 기록 ─────────────────────────────────────────── */
const ENDED = { complete: '무사 귀환', recalled: '조기 귀환', downed: '쓰러짐', exhausted: '탈진' };
async function expHistory(body) {
  const o = await load('world_expedition_overview');
  const list = o.recent || [];
  body.innerHTML = list.length ? `<ul class="spot-list">${list.map((h, i) => `<li><div><b>${esc(h.place_name || h.ground_name)}</b>
      <small>${new Date(h.finished_at || h.started_at).toLocaleString('ko-KR', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })} · ${h.minutes}분 · ${nameOf(h.stance)} · ${ENDED[h.result?.ended] || ''} · 전투 ${h.result?.wins ?? 0}승 · 답사 ${h.result?.progress_after ?? '-'}%</small></div>
      <button class="btn small ghost" data-h="${i}">자세히</button></li>`).join('')}</ul>` : empty('아직 다녀온 원정이 없습니다. 바깥 지역의 현장에서 원정을 보내 보세요.', 'flame');
  $$('[data-h]', body).forEach(b => b.onclick = () => { const h = list[Number(b.dataset.h)]; showResult({ place_name: h.place_name || h.ground_name, result: h.result }); });
}

/* ── 어종 도감 ─────────────────────────────────────────── */
const HABITAT = { river: '강', marsh: '늪', sea: '바다', lake: '호수', deep: '깊은 물', canal: '수로', abyss: '심연' };
const PHASE = { dawn: '해돋이', noon: '한낮', dusk: '땅거미', night: '삼경' };
const WEATHER = { clear: '청명', cloudy: '담운', rain: '장우', fog: '농무', wind: '삭풍', snow: '설한', bloodmist: '혈무' };
const RAR = { common: '범품', uncommon: '양품', rare: '진품', epic: '명품', legendary: '신품' };
// 도감: 요괴 · 채집 · 어종. 요괴는 만나면 기본 정보, 쓰러뜨리면 상성·기믹 파훼법·전리품이 열린다.
const CODEX = [['monster', '요괴', 'sword'], ['gather', '채집', 'leaf'], ['fish', '어종', 'eye']];
let cx = 'monster', cxKind = '';
async function codex(body) {
  body.innerHTML = `${segmented('cx-sub', CODEX, cx)}<div id="cx-body">${loading()}</div>`;
  bindSegmented(body, 'cx-sub', k => { cx = k; codex(body); });
  const box = $('#cx-body', body);
  try { await ({ monster: monsterCodex, gather: gatherCodex, fish: fishCodex })[cx](box); }
  catch (e) { box.innerHTML = errorBox(e.message); }
}
const JOBN = { exorcist: '퇴마관', sealmaster: '봉인술사', scout: '현장 조사원', analyst: '기록 분석관', medic: '의무관', artificer: '법구 제작사' };
const mul = v => { const n = Number(v); return `<span class="eff ${n >= 1.2 ? 'ok' : n <= 0.85 ? 'bad' : ''}">×${n}</span>`; };
const codexTitles = list => (list || []).length ? panel('도감 칭호', `<ul class="spot-list">${list.map(t => `<li><div><b>${esc(t.name)}</b><small>${esc(t.condition)}${t.need && !t.earned ? ` · ${fmt.num(t.progress ?? 0)}/${fmt.num(t.need)}` : ''}</small></div>${t.earned ? chip('얻음', 'ok') : chip('아직', '')}</li>`).join('')}</ul>`, { ico: 'spark' }) : '';
async function monsterCodex(box) {
  const o = await load('world_monster_codex_snapshot', undefined, { maxAge: 20000 });
  const kinds = o.kinds || [], all = o.monsters || [];
  const got = all.filter(m => m.defeated > 0).length, seen = all.filter(m => m.known).length;
  if (!kinds.some(k => k.key === cxKind)) cxKind = '';
  const list = all.filter(m => !cxKind || m.kind === cxKind);
  const kname = Object.fromEntries(kinds.map(k => [k.key, k.name]));
  box.innerHTML = `
    <div class="codex-head"><p class="desc">요괴는 열세 갈래로 나뉘고, 갈래마다 잘 듣는 무기(근접·원거리·술법)와 유리한 직업이 있습니다. 만난 요괴는 기본 정보가, 한 번 쓰러뜨린 요괴는 상성·기믹 파훼법·전리품이 적힙니다.</p>
      <div class="chips">${chip(`만남 ${seen}/${all.length}`, '')}${chip(`토벌 ${got}/${all.length}`, 'accent')}</div>${bar(got, all.length || 1, 'xp')}</div>
    <div class="chips kind-chips"><button class="chip ${cxKind ? '' : 'on'}" data-kind="">전체</button>${kinds.map(k => `<button class="chip ${cxKind === k.key ? 'on' : ''}" data-kind="${esc(k.key)}">${esc(k.name)} <small>${k.defeated}/${k.total}</small></button>`).join('')}</div>
    ${cxKind ? `<p class="muted small">${esc(kinds.find(k => k.key === cxKind)?.desc || '')}</p>` : ''}
    <ul class="mon-grid">${list.map(m => m.known ? `<li class="mon-card ${m.defeated > 0 ? 'done' : ''}">
        <div class="mon-top"><b>${esc(m.name)}</b>${m.role === 'guardian' ? chip('우두머리', 'bad') : ''}</div>
        <small>${esc(kname[m.kind] || '')} · ${esc(m.region)} · Lv.${m.level}–${m.max_level}</small>
        ${m.desc ? `<small class="muted">${esc(m.desc)}</small>` : ''}
        <small class="best">만남 ${fmt.num(m.seen)} · 토벌 ${fmt.num(m.defeated)}</small>
        ${m.counter ? `<details class="mon-counter"><summary>${icon('scroll', 12)} 파훼법</summary>
          <p class="small">상성: 근접 ${mul(m.counter.melee)} · 원거리 ${mul(m.counter.ranged)} · 술법 ${mul(m.counter.magic)}${m.counter.job ? ` · ${esc(JOBN[m.counter.job] || '')} +20%` : ''}</p>
          ${m.counter.habit ? `<p class="small muted">${esc(m.counter.habit)}</p>` : ''}
          <ul class="gim-list">${(m.counter.gimmicks || []).map(g => `<li><b>「${esc(g.name)}」</b><small>Lv.${g.from}부터 · ${esc(g.tell)}</small><small>${esc(g.tip)}</small></li>`).join('')}</ul>
          ${(m.counter.drops || []).length ? `<p class="small">전리품: ${m.counter.drops.map(d => esc(d.name)).join(', ')}</p>` : ''}</details>` : '<small class="muted">쓰러뜨리면 파훼법이 적힙니다</small>'}
      </li>` : `<li class="mon-card unknown"><b>???</b><small>${esc(kname[m.kind] || '')} · ${esc(m.region)}${m.role === 'guardian' ? ' · 우두머리' : ''}</small><small>아직 만나지 못했습니다</small></li>`).join('')}</ul>
    ${codexTitles(o.titles)}`;
  $$('[data-kind]', box).forEach(b => b.onclick = () => { cxKind = b.dataset.kind; monsterCodex(box); });
}
const GCAT = { herbs: '약초', ore: '광맥', spirit: '영기', relics: '유물', supplies: '보급', wood: '목재', water: '물가' };
async function gatherCodex(box) {
  const o = await load('world_gather_codex_snapshot', undefined, { maxAge: 20000 });
  const items = o.items || [], got = items.filter(x => x.known).length;
  box.innerHTML = `
    <div class="codex-head"><p class="desc">현장 채집터에서 거둔 재료가 적힙니다. 아직 거두지 못한 재료는 이름이 가려져 있고, 분류와 처음 나오는 레벨만 알려 줍니다.</p>
      <div class="chips">${chip(`도감 ${got}/${items.length}`, 'accent')}</div>${bar(got, items.length || 1, 'xp')}</div>
    ${Object.entries(GCAT).map(([c, cn]) => { const list = items.filter(x => x.cat === c); if (!list.length) return '';
      return panel(`${cn} · ${list.filter(x => x.known).length}/${list.length}`, `<ul class="fish-grid">${list.map(x => x.known ? `<li class="fish-card">
        <b>${esc(x.name)}</b><small>Lv.${x.level}+ · ${fmt.num(x.count)}번 · ${fmt.num(x.qty)}개</small>${x.desc ? `<small>${esc(x.desc)}</small>` : ''}
        <small class="muted">${esc((x.regions || []).join(', '))}</small></li>` : `<li class="fish-card unknown"><b>???</b><small>${esc(cn)} · Lv.${x.level}+</small><small>아직 거두지 못했습니다</small></li>`).join('')}</ul>`, { ico: 'leaf', cls: 'compact' }); }).join('')}
    ${codexTitles(o.titles)}`;
}
async function fishCodex(body) {
  const [o, map] = await Promise.all([load('world_fish_codex'), load('world_map_snapshot', undefined, { maxAge: 30000 })]);
  const sp = o.species || [], got = sp.filter(x => x.caught).length;
  const grounds = o.grounds || [];
  const when = x => [x.phase ? PHASE[x.phase] : '', x.weather ? WEATHER[x.weather] : ''].filter(Boolean).join('·');
  body.innerHTML = `
    <div class="codex-head"><p class="desc">강·늪·바다·호수·깊은 물에서 낚은 물고기가 여기에 기록됩니다. 아직 낚지 못한 어종은 이름이 가려져 있고, 사는 곳과 잘 무는 때만 알려 줍니다. 낚싯대를 가방에 넣고 물가 지역의 현장에서 낚으세요.</p>
      <div class="chips">${chip(`도감 ${got}/${sp.length}`, 'accent')}${chip(`낚은 물고기 ${fmt.num(o.total_caught)}마리`)}</div>
      ${bar(got, sp.length || 1, 'xp')}</div>
    ${Object.entries(HABITAT).map(([h, hn]) => {
      const list = sp.filter(x => x.habitat === h); if (!list.length) return '';
      const gs = grounds.filter(g => g.habitat === h);
      return panel(`${hn} · ${list.filter(x => x.caught).length}/${list.length}`, `
        <p class="muted small">낚시터: ${gs.map(g => `${esc(g.region_name)}(${esc(g.ground_name)}${g.safe ? ' · 안전지대' : ''} · Lv.${g.min_level}+)`).join(', ') || '없음'}</p>
        <div class="btn-row">${gs.map(g => goButton(g.region_id, map)).join('')}</div>
        <ul class="fish-grid">${list.map(x => `<li class="fish-card r-${esc(x.rarity)} ${x.caught ? '' : 'unknown'}">
          <b>${esc(x.name)}</b><small>${esc(RAR[x.rarity] || '')}${when(x) ? ` · ${esc(when(x))}에 잘 뭄` : ''}${x.min_level > 1 ? ` · Lv.${x.min_level}+` : ''}</small>
          ${x.caught ? `<small>${esc(x.description || '')}</small><small class="best">${fmt.num(x.count)}마리 · 가장 큰 것 ${x.best_size}cm</small>` : '<small>아직 낚지 못했습니다</small>'}</li>`).join('')}</ul>`, { ico: 'leaf', cls: 'compact' });
    }).join('')}
    ${panel('낚시 칭호', `<ul class="spot-list">${(o.titles || []).map(t => `<li><div><b>${esc(t.name)}</b><small>${esc(t.condition)}</small></div>${t.earned ? chip('얻음', 'ok') : chip('아직', '')}</li>`).join('')}</ul>
      <p class="muted small">칭호는 캐릭터 › 칭호에서 장착하면 낚시 효과(입질·희귀 어종·크기)가 붙습니다.</p>`, { ico: 'spark' })}`;
  bindGo(body);
}
