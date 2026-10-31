// 일지: 퀘스트를 보는 곳. 주 이야기(장마다 장면 → 단서 → 가설) · 보조 퀘스트(분야별) · 상시 의뢰 · 기록(답사·원정·도감).
// 마친 장면과 장 결말은 다시 읽을 수 있다(world_quest_scene). 진행 판정은 서버(world_quest_journal·world_quest_report)가 한다.
import { store, on, act, rpc, ask, nameOf, esc, icon, guard, $, $$, fmt, empty, segmented, bindSegmented, bar, RAID_ON } from '../core.js';
import { loreBundle, refreshLore } from '../lore.js';
import { load, panel, chip, loading, errorBox, currentRegion } from './common.js';
import { focusRegion } from './map.js';
import { showResult } from './expedition.js';
import { taskLine, giveLine, atLine, report } from '../quests.js';

const SUBS = [['story', '주 이야기', 'scroll'], ['side', '보조 퀘스트', 'flag'], ['commission', '의뢰', 'letter'], ['record', '기록', 'map']];
const REC = [['survey', '답사', 'map'], ...(RAID_ON ? [['lore', '지역', 'scroll']] : []), ['history', '원정', 'flame'], ['monster', '요괴', 'sword'], ['gather', '채집', 'leaf'], ['fish', '어종', 'eye']];
let el, sub = 'story', rec = 'survey', off = [];

export async function render(root, s) {
  if (!store.character) return;
  el = root;
  // 옛 주소(#/log/survey·history·codex)와 기록 칸 주소(#/log/fish 등)는 기록 칸으로
  if (REC.some(x => x[0] === s)) { sub = 'record'; rec = s; }
  else if (s === 'codex') { sub = 'record'; rec = 'monster'; }
  else sub = SUBS.some(x => x[0] === s) ? s : 'story';
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
  try { await ({ story, side, commission, record })[sub](body); }
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

/* ── 퀘스트 공통: 장면 목록·다시 보기·보고 ───────────────────── */
// 일지 목록(6.1.0 서버 함수). 없으면(배포 전) 장면 없이 단서·가설만 보인다
const journal = () => load('world_quest_journal', undefined, { maxAge: 15000 }).catch(() => null);
function sceneList(q, map) {
  const cur = q.cur, next = q.status === 'done' ? null : (q.scenes || []).find(x => !x.done);
  return `<ol class="scene-line">${(q.scenes || []).map(x => {
    if (x.done) return `<li class="done">${icon('check', 12)}<div><b>장면 ${x.step} · ${esc(x.title)}</b><small>${esc(x.goal || '')}</small></div>
      <button class="btn small ghost" data-scene="${esc(q.quest_id)}:${x.step}">${icon('scroll', 12)}<span>다시 보기</span></button></li>`;
    if (x === next) return `<li class="now">${icon('chevron', 12)}<div><b>장면 ${x.step} · ${esc(x.title)}</b><small>${esc(x.goal || '')}</small>
      ${cur && ((cur.tasks || []).length || (cur.give || []).length) ? `<ul class="q-tasks">${(cur.tasks || []).map(taskLine).join('')}${(cur.give || []).map(giveLine).join('')}</ul>` : ''}
      ${cur ? atLine(cur) : ''}
      ${q.status === 'locked' ? '' : `<div class="btn-row">${cur?.ready ? `<button class="btn small primary" data-q-report="${esc(q.quest_id)}">${icon('scroll', 14)}<span>${q.status === 'available' ? '이야기 듣기' : '보고하기'}</span></button>`
        : (cur?.at || [])[0] && !cur.here_ok ? goButton(cur.at[0], map) : ''}</div>`}</div></li>`;
    return `<li class="later">${icon('help', 12)}<div><b>장면 ${x.step}</b><small>앞 장면을 마치면 열립니다</small></div></li>`;
  }).join('')}${q.has_epilogue ? `<li class="done">${icon('moon', 12)}<div><b>결말</b><small>단서를 맞춰 세운 결론</small></div>
      <button class="btn small ghost" data-scene="${esc(q.quest_id)}:0">${icon('scroll', 12)}<span>다시 보기</span></button></li>` : ''}</ol>`;
}
function bindQuests(body) {
  $$('[data-scene]', body).forEach(b => b.onclick = () => guard(b, async () => {
    const [qid, step] = b.dataset.scene.split(':');
    const r = await rpc('world_quest_scene', { p_quest: qid, p_step: Number(step) });
    (await import('../factionquest.js')).playDialogue({ title: `${r.quest_title} · ${r.title}`, lines: r.lines, cast: r.cast }, null);
    return null;
  }));
  $$('[data-q-report]', body).forEach(x => x.onclick = () => report(x));
  bindGo(body);
  // 보조 퀘스트 포기: 처음부터 다시 받을 수 있고, 포기 전에 보상을 받은 장면은 다시 보고해도 보상이 없다(서버 world_quest_abandon)
  $$('[data-q-abandon]', body).forEach(x => x.onclick = async () => {
    if (!(await ask(`「${x.dataset.qTitle}」을(를) 포기할까요?\n진행이 처음으로 돌아가고, 다시 받아 처음부터 할 수 있습니다.\n이미 보상을 받은 장면은 다시 보고해도 보상이 없습니다.`, { title: '퀘스트 포기', ok: '포기하기', danger: true }))) return;
    guard(x, () => act('world_quest_abandon', { p_quest: x.dataset.qAbandon }));
  });
}

/* ── 주 이야기: 위의 장 목록을 누르면 그 장(장면 → 단서 → 가설)이 아래에 펼쳐진다 ── */
// 장·거르기만 바꿀 때는 서버를 다시 읽지 않고 지난 응답으로 다시 그린다
let selCh = '', lastStory = null, lastSide = null;
async function story(body, keep) {
  const [b, j, map] = keep && lastStory ? lastStory : (lastStory = await Promise.all([load('world_story_board'), journal(), load('world_map_snapshot', undefined, { maxAge: 30000 })]));
  const chapters = b?.chapters || [];
  const mains = new Map((j?.quests || []).filter(q => q.kind === 'main').map(q => [q.chapter_id, q]));
  if (!chapters.some(c => c.chapter_id === selCh && c.status !== 'locked'))
    selCh = (chapters.find(c => c.status === 'active') || [...chapters].reverse().find(c => c.status === 'done') || chapters[0])?.chapter_id || '';
  const ch = chapters.find(c => c.chapter_id === selCh);
  const doneN = chapters.filter(c => c.status === 'done').length;
  body.innerHTML = `
    ${b?.all_done ? `<div class="notice safe">${icon('moon', 18)}<div><b>지금까지의 이야기를 모두 마쳤습니다</b><span>장을 눌러 지난 장면과 결말을 다시 읽을 수 있습니다. 보조 퀘스트와 의뢰도 계속 받을 수 있습니다.</span></div><button class="btn small" data-sub="side">보조 퀘스트</button></div>` : ''}
    <div class="chips">${chip(`마친 장 ${doneN}/${chapters.length}`, 'accent')}<span class="muted small">장을 누르면 아래에 펼쳐집니다</span></div>
    <ol class="chapter-line">${chapters.map(c => `<li class="${c.status} ${c.chapter_id === selCh ? 'sel' : ''}"><button data-ch="${esc(c.chapter_id)}" ${c.status === 'locked' ? 'disabled' : ''} aria-pressed="${c.chapter_id === selCh}">
      <b>${c.seq}장</b><span>${c.status === 'locked' ? `Lv.${c.min_level}` : esc(c.title)}</span></button></li>`).join('')}</ol>
    ${ch ? chapterView(ch, mains.get(ch.chapter_id), map) : ''}
    ${chapters.filter(c => c.status === 'locked').length ? `<p class="muted small">잠긴 장 ${chapters.filter(c => c.status === 'locked').length}개 — 앞 장을 마치고 레벨이 되면 열립니다.</p>` : ''}
    ${regional(b?.regional)}`;
  $$('[data-ch]', body).forEach(x => x.onclick = () => { selCh = x.dataset.ch; story(body, true); });
  // 장을 마치면 장 결말(epilogue)을 대화창으로 보인다
  $$('[data-combo]', body).forEach(x => x.onclick = () => guard(x, async () => {
    const r = await act('world_story_combine', { p_combo_id: x.dataset.combo });
    if (r?.epilogue?.lines?.length) (await import('../factionquest.js')).playDialogue({ title: r.epilogue.title, lines: r.epilogue.lines, cast: r.epilogue.cast,
      extra: `<p class="hint good">${icon('check', 14)} 장을 마쳤습니다</p>` });
    return r;
  }));
  const rs = $('#reg-submit', body); if (rs) rs.onclick = () => guard(rs, () => act('world_case_combine_regional'));
  $$('[data-sub]', body).forEach(x => x.onclick = () => { sub = x.dataset.sub; window.yahangGo('log', sub); });
  bindQuests(body);
}
function chapterView(ch, q, map) {
  const done = ch.status === 'done';
  const scenesDone = done || !q || q.step >= q.steps;
  const head = `<p class="desc">${esc(ch.intro)}</p>${ch.rewards?.text ? `<p class="muted small">마치면: ${esc(ch.rewards.text)}</p>` : ''}
    ${q ? `<div class="chips">${chip(`장면 ${q.step}/${q.steps}`, scenesDone ? 'ok' : 'accent')}${chip(`단서 ${(ch.clues || []).filter(c => c.found).length}/${(ch.clues || []).length}`)}${chip(`가설 ${(ch.combos || []).filter(x => x.done).length}/${(ch.combos || []).length}`)}${q.region_name ? chip(q.region_name) : ''}</div>` : ''}`;
  const scenes = q ? `<h3 class="sub-h">장면</h3>${q.status === 'available' && !q.cur?.here_ok ? `<p class="hint">${icon('pin', 14)} ${esc(q.region_name || '')}에서 이 장의 이야기를 들을 수 있습니다.</p>` : ''}${sceneList(q, map)}` : '';
  const clues = done ? `<h3 class="sub-h">결론</h3><p class="desc">${esc(ch.outro)}</p>${(ch.combos || []).map(x => `<p class="muted small"><b>${esc(x.name)}</b> — ${esc(x.conclusion)}</p>`).join('')}`
    : scenesDone ? clueBlock(ch, map)
    : `<h3 class="sub-h">단서와 가설</h3><p class="muted small">장면을 모두 마치면 이 장의 단서 ${(ch.clues || []).length}개를 탐색에서 찾을 수 있고, 모은 단서로 가설을 세웁니다.</p>`;
  return panel(`${ch.seq}장 · ${ch.title}`, head + scenes + clues, { ico: done ? 'check' : 'scroll' });
}
function clueBlock(ch, map) {
  return `<h3 class="sub-h">단서</h3>
    <div class="clue-grid">${(ch.clues || []).map(k => `<article class="clue ${k.found ? 'on' : ''}"><header><b>${k.found ? esc(k.name) : '찾지 못한 단서'}</b>${chip(k.tag)}</header>
        <p>${k.found ? esc(k.description) : `${esc(k.region_name)} 어딘가에 있습니다. 그곳을 탐색하세요. 깊이 들어갈수록 찾기 쉽습니다.`}</p>
        ${k.found ? chip('확보', 'ok') : goButton(k.region_id, map)}</article>`).join('')}</div>
    <h3 class="sub-h">가설 세우기</h3>
    <div class="combo-grid">${(ch.combos || []).map(x => {
      const ready = (x.needs || []).every(n => (ch.clues || []).find(k => k.clue_id === n)?.found);
      return `<article class="combo ${x.done ? 'on' : ''}"><b>${esc(x.name)}</b><p>${esc(x.done ? x.conclusion : x.description)}</p>
        <div class="combo-need">${(x.needs || []).map(n => { const k = (ch.clues || []).find(y => y.clue_id === n); return `<span class="${k?.found ? 'ok' : ''}">${k?.found ? esc(k.name) : '?'}</span>`; }).join(icon('plus', 12))}</div>
        ${x.done ? chip('결론 확정', 'ok') : `<button class="btn small ${ready ? 'primary' : ''}" data-combo="${esc(x.combo_id)}" ${ready ? '' : 'disabled'}>${ready ? '가설 확정' : '단서 부족'}</button>`}</article>`; }).join('')}</div>`;
}
function regional(r) {
  const n = r?.regions || 0;
  return panel('지역 답사 보고서', `
    <p class="desc">탐색하다 보면 지역만의 흔적을 기록할 때가 있습니다. 서로 다른 3개 지역의 기록을 모아 보고서를 내면 보상과 함께 <b>가방 +4칸</b>을 받습니다.</p>
    <div class="chips">${chip(`기록 ${r?.clues || 0}개`)}${chip(`지역 ${Math.min(n, 3)}/3`, n >= 3 ? 'ok' : '')}${r?.submitted ? chip('제출 완료', 'ok') : ''}</div>
    ${r?.submitted ? '' : `<button class="btn ${n >= 3 ? 'primary' : ''}" id="reg-submit" ${n >= 3 ? '' : 'disabled'}>${icon('scroll', 16)}<span>보고서 제출</span></button>`}`, { ico: 'map' });
}

/* ── 보조 퀘스트: 분야별로 나눠 보고, 상태로 거르고, 정렬한다 ───────────── */
const FIELDS = [['외전', 'scroll'], ['직업', 'user'], ['소속', 'flag'], ['전투', 'sword'], ['채집', 'leaf'], ['제작', 'hammer'], ['조사', 'search'], ['낚시', 'eye'], ['생활', 'home']];
const STATUS = [['', '전체'], ['active', '진행 중'], ['available', '받을 수 있음'], ['done', '마침'], ['locked', '레벨 부족']];
const STATUS_N = { active: ['진행 중', 'accent'], available: ['받을 수 있음', 'ok'], done: ['마침', ''], locked: ['레벨 부족', 'bad'] };
const SORTS = { level: (a, b) => a.min_level - b.min_level || a.title.localeCompare(b.title, 'ko'),
  region: (a, b) => (a.region_name || '').localeCompare(b.region_name || '', 'ko') || a.min_level - b.min_level,
  name: (a, b) => a.title.localeCompare(b.title, 'ko') };
const ORDER = { active: 0, available: 1, locked: 2, done: 3 };
const fieldOf = q => (q.cat || '').split('·')[0] || '기타';
let sField = '', sStatus = '', sSort = 'level';
async function side(body, keep) {
  const [j, map] = keep && lastSide ? lastSide : (lastSide = await Promise.all([journal(), load('world_map_snapshot', undefined, { maxAge: 30000 })]));
  if (!j) { body.innerHTML = empty('보조 퀘스트 목록은 다음 서버 갱신 뒤에 열립니다. 지금은 현장의 퀘스트 칸에서 볼 수 있습니다.', 'flag'); return; }
  const all = (j.quests || []).filter(q => q.kind === 'side');
  const fields = [...FIELDS.filter(([f]) => all.some(q => fieldOf(q) === f)), ...[...new Set(all.map(fieldOf))].filter(f => !FIELDS.some(x => x[0] === f)).map(f => [f, 'flag'])];
  if (sField && !fields.some(([f]) => f === sField)) sField = '';
  const pass = q => (!sField || fieldOf(q) === sField) && (!sStatus || q.status === sStatus);
  const sorted = list => [...list].sort((a, b) => (sStatus ? 0 : ORDER[a.status] - ORDER[b.status]) || SORTS[sSort](a, b));
  const cnt = (list, st) => list.filter(q => q.status === st).length;
  const group = ([f, ic]) => {
    const list = sorted(all.filter(q => fieldOf(q) === f && pass(q))); if (!list.length) return '';
    const mine = all.filter(q => fieldOf(q) === f);
    return `<details class="panel fold q-field" ${sField || cnt(list, 'active') || sStatus ? 'open' : ''}><summary class="panel-head"><h2>${icon(ic, 16)}${esc(f)} <small class="muted">마침 ${cnt(mine, 'done')}/${mine.length}${cnt(mine, 'active') ? ` · 진행 ${cnt(mine, 'active')}` : ''}</small></h2></summary>
      <div class="panel-body"><ul class="q-list">${list.map(q => sideItem(q, map)).join('')}</ul></div></details>`;
  };
  const shown = all.filter(pass).length;
  body.innerHTML = `
    <p class="desc">보조 퀘스트는 지역의 인물에게서 받습니다. 받은 퀘스트의 할 일을 마치고 보고 장소에서 보고하면 보상과 다음 장면이 나옵니다. 마친 퀘스트도 장면을 다시 읽을 수 있습니다.</p>
    <div class="chips">${chip(`마침 ${cnt(all, 'done')}/${all.length + (j.hidden || 0)}`, 'accent')}${chip(`진행 ${cnt(all, 'active')}`)}${chip(`받을 수 있음 ${cnt(all, 'available')}`, 'ok')}</div>
    <div class="q-filter">
      <div class="chips kind-chips" role="group" aria-label="분야"><button class="chip ${sField ? '' : 'on'}" data-f="">전체</button>${fields.map(([f]) => `<button class="chip ${sField === f ? 'on' : ''}" data-f="${esc(f)}">${esc(f)} <small>${cnt(all.filter(q => fieldOf(q) === f), 'done')}/${all.filter(q => fieldOf(q) === f).length}</small></button>`).join('')}</div>
      <div class="chips kind-chips" role="group" aria-label="상태">${STATUS.map(([k, n]) => `<button class="chip ${sStatus === k ? 'on' : ''}" data-st="${k}">${n}</button>`).join('')}</div>
      <label class="q-sort"><span class="muted small">정렬</span><select id="q-sort"><option value="level" ${sSort === 'level' ? 'selected' : ''}>레벨순</option><option value="region" ${sSort === 'region' ? 'selected' : ''}>지역순</option><option value="name" ${sSort === 'name' ? 'selected' : ''}>이름순</option></select></label>
    </div>
    ${shown ? (sField ? group(fields.find(([f]) => f === sField)) : fields.map(group).join('')) : empty('조건에 맞는 퀘스트가 없습니다.', 'flag')}
    ${j.hidden ? `<p class="muted small">앞 퀘스트를 마치면 열리는 퀘스트가 ${j.hidden}개 더 있습니다.</p>` : ''}`;
  $$('[data-f]', body).forEach(b => b.onclick = () => { sField = b.dataset.f; side(body, true); });
  $$('[data-st]', body).forEach(b => b.onclick = () => { sStatus = b.dataset.st; side(body, true); });
  $('#q-sort', body).onchange = e => { sSort = e.target.value; side(body, true); };
  bindQuests(body);
}
// 진행 중인 퀘스트는 접혀 있어도 지금 할 일과 장소가 보이게(7.4.6, 제보)
function nowLine(q) {
  if (q.status !== 'active' || !q.cur) return '';
  const left = (q.cur.tasks || []).filter(t => t.cur < t.n), regs = [...new Set(left.flatMap(t => t.regions || []))].map(nameOf);
  const where = q.cur.ready ? `보고: ${(q.cur.at_names || []).join('·') || '의뢰인에게'}` : regs.length ? `할 곳: ${regs.slice(0, 3).join('·')}` : (q.cur.at_names || []).length ? `보고: ${q.cur.at_names.join('·')}` : '';
  return `<p class="q-now">${icon('chevron', 12)}<span><b>${q.cur.ready ? '보고하면 끝' : `장면 ${q.cur.step}`}</b> · ${esc(q.cur.goal || q.cur.title || '')}${where ? ` <small class="muted">(${esc(where)})</small>` : ''}</span></p>`;
}
function sideItem(q, map) {
  const [sn, tone] = STATUS_N[q.status] || ['', ''];
  const subCat = (q.cat || '').split('·')[1] || '';
  const where = `${icon('pin', 12)} ${esc(q.region_name || '')} · Lv.${q.min_level}${q.here ? ' · 지금 여기' : ''}`;
  return `<li class="q-item ${q.status} ${q.cur?.ready ? 'ready' : ''}"><details ${q.status === 'active' ? 'open' : ''}>
    <summary><header>${chip(sn, tone)}${subCat ? chip(subCat) : ''}<b>${esc(q.title)}</b>${q.steps ? `<small class="muted">${q.step}/${q.steps}</small>` : ''}</header>
      <p class="q-at ${q.here ? 'ok' : ''}">${where}</p>${nowLine(q)}</summary>
    <p class="q-goal">${esc(q.summary || '')}</p>
    ${q.status === 'locked' ? `<p class="muted small">레벨 ${q.min_level}부터 받을 수 있습니다.</p>`
      : q.status === 'available' && !q.here ? `<div class="btn-row">${goButton(q.region_id, map)}</div>` : sceneList(q, map)}
    ${q.status === 'active' ? `<div class="btn-row q-abandon"><button class="btn small ghost" data-q-abandon="${esc(q.quest_id)}" data-q-title="${esc(q.title)}">${icon('close', 14)}<span>포기하기</span></button></div>` : ''}
  </details></li>`;
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

/* ── 기록: 답사 · 원정 · 도감(요괴·채집·어종) ─────────────────── */
async function record(body) {
  body.innerHTML = `${segmented('rec-sub', REC, rec)}<div id="rec-body">${loading()}</div>`;
  bindSegmented(body, 'rec-sub', k => { rec = k; window.history.replaceState(null, '', `#/log/${k}`); record(body); });
  const box = $('#rec-body', body);
  try { await ({ survey, lore: regionLore, history: expHistory, monster: monsterCodex, gather: gatherCodex, fish: fishCodex })[rec](box); }
  catch (e) { box.innerHTML = errorBox(e.message); }
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

/* ── 지역 기록(6.1.1): 처음 들어갈 때 본 지역의 내력 ─────────────────── */
async function regionLore(body) {
  const list = await load('world_region_lore_seen');
  const groups = {};
  (list || []).forEach(r => (groups[r.territory || '기타'] ||= []).push(r));
  body.innerHTML = (list || []).length ? `<p class="desc">처음 들어간 지역의 내력이 여기에 남습니다. 아직 가 보지 않은 곳은 비어 있습니다.</p>
    ${Object.entries(groups).map(([t, l]) => panel(`${t} · ${l.length}곳`, `<ul class="lore-list">${l.map(r => `<li><b>${esc(r.region_name)}</b>${(r.lines || []).map(x => `<p>${esc(x.t)}</p>`).join('')}</li>`).join('')}</ul>`, { ico: 'map', cls: 'compact' })).join('')}`
    : empty('아직 남긴 지역 기록이 없습니다. 새 지역에 들어가면 그곳의 내력이 적힙니다.', 'scroll');
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
const WEATHER = { clear: '청명', cloudy: '담운', rain: '장우', drizzle: '세우', fog: '농무', wind: '삭풍', snow: '설한', bloodmist: '혈무' };
const RAR = { common: '범품', uncommon: '양품', rare: '진품', epic: '명품', legendary: '신품' };
// 도감: 요괴 · 채집 · 어종. 요괴는 만나면 기본 정보, 쓰러뜨리면 상성·수법 대처법·전리품이 열린다.
let cxKind = '';
const JOBN = { exorcist: '퇴마관', sealmaster: '봉인술사', scout: '현장 조사원', analyst: '백공 기술관', medic: '의무관', artificer: '호위 무사' };
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
    <div class="codex-head"><p class="desc">요괴는 열세 갈래로 나뉘고, 갈래마다 잘 듣는 무기(근접·원거리·술법)와 유리한 직업이 있습니다. 만난 요괴는 기본 정보가, 한 번 쓰러뜨린 요괴는 상성·수법 대처법·전리품이 적힙니다.</p>
      <div class="chips">${chip(`만남 ${seen}/${all.length}`, '')}${chip(`토벌 ${got}/${all.length}`, 'accent')}</div>${bar(got, all.length || 1, 'xp')}</div>
    <div class="chips kind-chips"><button class="chip ${cxKind ? '' : 'on'}" data-kind="">전체</button>${kinds.map(k => `<button class="chip ${cxKind === k.key ? 'on' : ''}" data-kind="${esc(k.key)}">${esc(k.name)} <small>${k.defeated}/${k.total}</small></button>`).join('')}</div>
    ${cxKind ? `<p class="muted small">${esc(kinds.find(k => k.key === cxKind)?.desc || '')}</p><div class="witness" data-witness></div>` : ''}
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
  // 목격담(6.1.1): 그 갈래를 1·10마리 쓰러뜨리면 이야기 속 인물의 한마디가 열린다
  const wb = $('[data-witness]', box);
  // 열림은 서버가 정하고(그 갈래 토벌 수), 화면이 센 수가 넘었는데 아직 잠긴 줄이 있으면 한 번 다시 읽는다
  const n = all.filter(m => m.kind === cxKind).reduce((s, m) => s + (Number(m.defeated) || 0), 0);
  const paint = l => { const arr = l.witness?.[cxKind] || [];
    wb.innerHTML = arr.map(w => w.open ? `<p class="w-line"><b>${esc(w.name)}</b> 「${esc(w.t)}」</p>` : `<p class="w-line locked">${icon('help', 12)} 이 갈래를 ${w.need}마리 쓰러뜨리면 열리는 목격담</p>`).join(''); return arr; };
  if (wb) loreBundle().then(l => { if (paint(l).some(w => !w.open && n >= w.need)) refreshLore().then(l2 => wb.isConnected && paint(l2)); });
}
const GCAT = { herbs: '약초', ore: '광맥', spirit: '영기', relics: '유물', supplies: '보급', wood: '목재', water: '물가' };
// 채집 도감의 세부 채집터(7.5.9, 사용자 요청): 지역 한 줄(지도 바로 가기·출입 레벨·찾은 수/채집터 수) 아래 채집터 이름 꼬리표(찾은 곳 먼저, 넷까지).
// 지역은 셋까지 펼치고 나머지는 「지역 n곳 더」로 접는다(줄글처럼 길어지지 않게)
const spotRow = g => `<div class="gx-row"><div class="gx-head"><button type="button" class="q-link" data-q-map="${esc(g.r)}" title="지도에서 보기">${icon('map', 12)}<span>${esc(g.r)}</span></button>
    <small class="muted">Lv.${g.l}+ · 찾음 ${g.fc}/${g.c}</small></div>
  <div class="gx-tags">${(g.s || []).map(t => `<span class="gx-tag ${t.f ? 'f' : ''}" title="${t.f ? '찾은 채집터' : '아직 찾지 못한 채집터'} · Lv.${t.lv}">${t.f ? icon('check', 10) : ''}${esc(t.n)}<i>${t.lv}</i></span>`).join('')}${g.c > (g.s || []).length ? `<span class="gx-more">외 ${g.c - (g.s || []).length}곳</span>` : ''}</div></div>`;
function spotsHtml(x) {
  const sp = x.spots || [];
  if (!sp.length) return `<small class="muted">${esc((x.regions || []).join(', '))}</small>`;
  return `<div class="gx-spots">${sp.slice(0, 3).map(spotRow).join('')}${sp.length > 3 ? `<details class="gx-rest"><summary>지역 ${sp.length - 3}곳 더</summary>${sp.slice(3).map(spotRow).join('')}</details>` : ''}</div>`;
}
async function gatherCodex(box) {
  const o = await load('world_gather_codex_snapshot', undefined, { maxAge: 20000 });
  const items = o.items || [], got = items.filter(x => x.known).length;
  box.innerHTML = `
    <div class="codex-head"><p class="desc">현장 채집터에서 거둔 재료가 적힙니다. 아직 거두지 못한 재료는 이름이 가려져 있고, 분류와 처음 나오는 레벨만 알려 줍니다.</p>
      <div class="chips">${chip(`도감 ${got}/${items.length}`, 'accent')}</div>${bar(got, items.length || 1, 'xp')}</div>
    ${Object.entries(GCAT).map(([c, cn]) => { const list = items.filter(x => x.cat === c); if (!list.length) return '';
      return panel(`${cn} · ${list.filter(x => x.known).length}/${list.length}`, `<ul class="fish-grid">${list.map(x => x.known ? `<li class="fish-card">
        <b>${esc(x.name)}</b><small>Lv.${x.level}+ · ${fmt.num(x.count)}번 · ${fmt.num(x.qty)}개</small>${x.desc ? `<small>${esc(x.desc)}</small>` : ''}
        ${spotsHtml(x)}</li>` : `<li class="fish-card unknown"><b>???</b><small>${esc(cn)} · Lv.${x.level}+</small><small>아직 거두지 못했습니다</small></li>`).join('')}</ul>`, { ico: 'leaf', cls: 'compact' }); }).join('')}
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
          ${x.where?.length ? `<small class="muted">${esc(x.where.join('·'))}에서만</small>` : ''}
          ${x.caught ? `<small>${esc(x.description || '')}</small><small class="best">${fmt.num(x.count)}마리 · 가장 큰 것 ${x.best_size}cm</small>` : '<small>아직 낚지 못했습니다</small>'}</li>`).join('')}</ul>`, { ico: 'leaf', cls: 'compact' });
    }).join('')}
    ${panel('낚시 칭호', `<ul class="spot-list">${(o.titles || []).map(t => `<li><div><b>${esc(t.name)}</b><small>${esc(t.condition)}</small></div>${t.earned ? chip('얻음', 'ok') : chip('아직', '')}</li>`).join('')}</ul>
      <p class="muted small">칭호는 캐릭터 › 칭호에서 장착하면 낚시 효과(입질·희귀 어종·크기)가 붙습니다.</p>`, { ico: 'spark' })}`;
  bindGo(body);
}
