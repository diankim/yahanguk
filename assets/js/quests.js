import { store, act, esc, icon, guard, $, $$, nameOf, toast, ask, RAID_ON, on, midBattle } from './core.js';
import { load, invalidate, chip, knownRecipes } from './views/common.js';
import { playDialogue } from './factionquest.js';
import { itemSources, sourcePlaces, sourceTotal, regionBtn, sourcesMore, regionsMore, shopNow, shopNowHtml, nearAny, nearH } from './sources.js';
import { TASK_ACTS, CHANGES, hit } from './changes.js';
import { baseOf } from './hq.js';
import { askPartySize, partyHere } from './views/fightui.js';
import { storyArcOf, isStoryMain } from './rules.js';

const KIND = { main: '주 이야기', side: '보조', faction: '세력' };
const foldKey = 'yh-fold-quests';
const isOpen = () => { try { return localStorage.getItem(foldKey) !== '0'; } catch { return true; } };

function noteReady(b) {
  let seen; try { seen = new Set(JSON.parse(sessionStorage.getItem('yh-q-ready') || '[]')); } catch { seen = new Set(); }
  const ready = [...(b.active || []).filter(q => q.phase === 'step' && q.ready).map(q => [`${q.quest_id}:${q.step}`, q.title]),
    ...(b.faction?.ready ? [[`f:${b.faction.scene_key}`, b.faction.title]] : [])];
  let fresh = false;
  for (const [k, t] of ready) if (!seen.has(k)) { seen.add(k); fresh = true; toast(`「${t}」 할 일을 모두 마쳤습니다. 보고하세요.`, 'ok'); }
  if (fresh) { window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'find' })); try { sessionStorage.setItem('yh-q-ready', JSON.stringify([...seen].slice(-200))); } catch {} }
}

const taskPrev = new Map();
function noteTasks(b) {
  const qs = [...(b.active || []).filter(q => q.phase === 'step').map(q => [`${q.quest_id}:${q.step}`, q]),
    ...(b.faction && !b.faction.locked ? [[`f:${b.faction.scene_key}`, b.faction]] : [])];
  for (const [k, q] of qs) (q.tasks || []).forEach((t, i) => {
    const key = `${k}:${i}`, done = t.cur >= t.n;
    if (taskPrev.get(key) === false && done && !q.ready) toast(`「${q.title}」의 「${t.label}」 할 일을 마쳤습니다.`, 'ok');
    taskPrev.set(key, done);
  });
}

const mapBtns = (regs, n = 3) => (regs || []).slice(0, n).map(r => `<button type="button" class="q-link" data-q-map="${esc(r)}" title="지도에서 보기">${icon('map', 12)}<span>${esc(nameOf(r))}</span></button>`).join('');
const craftBtn = id => `<button type="button" class="q-link" data-q-craft="${esc(nameOf(id))}" title="제작법 찾기">${icon('hammer', 12)}<span>제작법</span></button>`;
const srcSlot = id => `<span class="q-src" data-q-src="${esc(id)}"></span>`;
const itemsOf = t => Array.isArray(t.items) ? t.items : Object.keys(t.items || {});
export const taskLine = t => { const done = t.cur >= t.n, items = t.t === 'craft' ? itemsOf(t) : [];
  const src = !done && t.t === 'gather' && !(t.regions || []).length ? itemsOf(t).slice(0, 1).map(srcSlot).join('') : '';
  return `<li class="${done ? 'ok' : ''}">${icon(done ? 'check' : 'chevron', 12)}<span>${esc(t.label)}</span><b>${t.cur}/${t.n}${t.unit || ''}</b>${done ? '' : `<span class="q-links">${mapBtns(t.regions)}${items.slice(0, 1).map(craftBtn).join('')}${src}</span>`}</li>`; };
export const giveLine = g => { const done = g.have >= g.n;
  return `<li class="${done ? 'ok' : ''}">${icon('bag', 12)}<span>${esc(g.name || nameOf(g.item_id))} 넘기기</span><b>${g.have}/${g.n}개</b>${done ? '' : `<span class="q-links">${hasRecipe(g.item_id) ? craftBtn(g.item_id) : ''}${srcSlot(g.item_id)}</span>`}</li>`; };
async function fillSrc(root = document) {
  for (const el of root.querySelectorAll('[data-q-src]:not([data-f])')) {
    el.dataset.f = '1';
    const id = el.dataset.qSrc;
    try {
      const s = await itemSources(id) || {};
      const places = sourcePlaces(s), total = sourceTotal(s);
      const sh = s.shop ? shopNowHtml(await shopNow(id).catch(() => null), t => `<small class="muted">${t}</small>`) : '';
      if (!el.isConnected) continue;
      el.innerHTML = (places.length ? `<small class="muted">얻는 곳</small>${places.slice(0, 5).map(r => regionBtn(r, true, nearH(nearAny(s), r))).join('')}${sourcesMore(id, total - Math.min(5, places.length))}`
        : s.smithy ? '<small class="muted">안전지대 대장간에서 삽니다</small>' : s.shop && !sh ? '<small class="muted">안전지대 상점에서 삽니다</small>' : '') + (sh ? `<span class="q-shop">${sh}</span>` : '');
    } catch {}
  }
}
let srcTimer = 0;
new MutationObserver(() => { clearTimeout(srcTimer); srcTimer = setTimeout(() => { if (document.querySelector('[data-q-src]:not([data-f])')) fillSrc(); }, 80); })
  .observe(document.body, { childList: true, subtree: true });
const hasRecipe = id => knownRecipes().some(r => r.output === baseOf(id));
document.addEventListener('click', e => {
  const m = e.target.closest?.('[data-q-map]'), c = e.target.closest?.('[data-q-craft]');
  if (!m && !c) return;
  e.preventDefault(); e.stopPropagation();
  if (m) import('./views/map.js').then(x => { x.focusRegion(m.dataset.qMap); window.yahangGo('map', 'world'); });
  else { window.dispatchEvent(new CustomEvent('yh-craft-focus', { detail: { search: c.dataset.qCraft } })); window.yahangGo('bag', 'craft'); }
});
export const atLine = q => {
  const at = q.at_names || [], here = store.character?.location;
  const left = (q.tasks || []).filter(t => t.cur < t.n);
  const where = [...new Set(left.flatMap(t => (t.regions || []).map(r => nameOf(r))))];
  const links = names => names.map(n => n === here ? esc(n) : `<button type="button" class="q-link" data-q-map="${esc(n)}" title="지도에서 보기">${icon('map', 12)}<span>${esc(n)}</span></button>`).join('·');
  const doLine = where.length ? `<p class="q-at do ${where.includes(here) ? 'ok' : ''}">${icon('flag', 12)} 할 곳: ${links(where.slice(0, 3))}${where.length > 3 ? ` ${regionsMore('할 곳', where, 3)}` : ''}${where.includes(here) ? ' (지금 여기)' : ''}</p>` : '';
  if (!at.length) return doLine;
  const done = !left.length;
  return doLine + `<p class="q-at ${done && q.here_ok ? 'ok' : ''}">${icon('pin', 12)} ${done ? '보고' : '다 하면 보고'}: ${links(at)}${q.here_ok ? (done ? ' (지금 여기)' : ' (여기)') : ''}</p>`;
};
const head = (kind, q) => { const arcN = storyArcOf(q.cat); return `<header>${arcN ? (isStoryMain(q) ? chip('본편', 'accent') : chip('보조')) + chip(arcN) : chip(kind !== 'main' && isStoryMain(q) ? '본편' : KIND[kind] || '보조', kind === 'main' || isStoryMain(q) ? 'accent' : kind === 'faction' ? 'warn' : '') + (kind === 'main' ? '' : chip(q.cat || ''))}${q.replay ? chip('다시하기', 'ok') : ''}<b>${esc(q.title)}</b></header>` };

const mapLink = n => n === store.character?.location ? `<b>${esc(n)}</b>` : `<button type="button" class="q-link" data-q-map="${esc(n)}" title="지도에서 보기">${icon('map', 12)}<span>${esc(n)}</span></button>`;
function clueItem(q) {
  const c = q.clues || {}, list = c.list || [], combos = c.combos || [];
  const has = new Set(list.filter(k => k.found).map(k => k.id));
  const left = {}; list.filter(k => !k.found).forEach(k => { left[k.rn] = (left[k.rn] || 0) + 1; });
  const where = Object.keys(left), here = store.character?.location, all = !where.length;
  const ready = combos.filter(x => !x.done && (x.needs || []).every(n => has.has(n)));
  const doneN = combos.filter(x => x.done).length;
  return `<li class="q-item q-clue ${ready.length ? 'ready' : ''}">${head(q.kind, q)}
    <p class="q-step">장면을 모두 마쳤습니다 · 단서 ${c.found ?? 0}/${c.total ?? 0} · 가설 ${doneN}/${combos.length}</p>
    <p class="q-goal">${all ? '단서를 모두 모았습니다. 가설을 확정하면 이 장이 끝납니다.' : `남은 단서를 찾으세요. 아래 곳을 <b>탐색</b>하면 나옵니다${ready.length ? ' — 모인 단서로 먼저 세울 수 있는 가설도 있습니다' : ''}.`}</p>
    ${all ? '' : `<p class="q-at do ${where.includes(here) ? 'ok' : ''}">${icon('flag', 12)} 찾을 곳: ${where.map(n => `${mapLink(n)} ${left[n]}개`).join(' · ')}${where.includes(here) ? ' (지금 여기 — 탐색하세요)' : ''}</p>`}
    ${combos.length ? `<ul class="q-tasks q-combos">${combos.map(x => {
      const ok = (x.needs || []).every(n => has.has(n));
      return `<li class="${x.done ? 'done' : ''}">${icon(x.done ? 'check' : 'scroll', 12)}<span>${esc(x.name)}</span>${x.done ? '<small class="ok">확정</small>' : ok ? `<button class="btn small primary" data-here="가설 확정" data-story-combo="${esc(x.id)}">가설 확정</button>` : `<small class="muted">단서 ${(x.needs || []).filter(n => has.has(n)).length}/${(x.needs || []).length}</small>`}</li>`; }).join('')}</ul>` : ''}
    <div class="btn-row"><a class="btn small ghost" href="#/log/story">${icon('scroll', 14)}<span>일지에서 단서 보기</span></a></div></li>`;
}
const arcOf = q => storyArcOf(q?.cat) || '홍인사';
async function nextStoryHtml(doneArc) {
  invalidate('world_quest_board');
  let b; try { b = await load('world_quest_board'); } catch { return ''; }
  return (b?.active || []).filter(x => x.auto && isStoryMain(x)).slice(0, 2).map(x => {
    const at = (x.at_names || [])[0], arc = arcOf(x);
    return `<p class="hint accent q-next-arc">${icon('chevron', 14)}<span>${arc !== doneArc ? `다음 이야기 <b>「${esc(arc)}」</b> · ` : '다음 장 · '}<b>「${esc(x.title)}」</b>${at ? ` — 받는 곳 ${mapLink(at)}` : ''}<br><small class="muted">현장 퀘스트 칸 「진행 중」 맨 위에 올라 있습니다.</small></span></p>`;
  }).join('');
}
export function storyCombine(btn) {
  return guard(btn, async () => {
    const r = await act('world_story_combine', { p_combo_id: btn.dataset.storyCombo || btn.dataset.combo });
    if (r?.epilogue?.lines?.length) playDialogue({ title: r.epilogue.title, lines: r.epilogue.lines, cast: r.epilogue.cast,
      extra: `<p class="hint good">${icon('check', 14)} 장을 마쳤습니다</p>${await nextStoryHtml('홍인사')}` });
    return r;
  });
}
function activeItem(q) {
  if (q.phase === 'clues') return clueItem(q);
  return `<li class="q-item ${q.ready ? 'ready' : ''}">${head(q.kind, q)}
    <p class="q-step">장면 ${q.step}/${q.steps} · ${esc(q.step_title || '')}</p>
    <p class="q-goal">${esc(q.goal || '')}</p>
    ${(q.tasks || []).length || (q.give || []).length ? `<ul class="q-tasks">${(q.tasks || []).map(taskLine).join('')}${(q.give || []).map(giveLine).join('')}</ul>` : ''}
    ${atLine(q)}
    <div class="btn-row">${RAID_ON && q.quest_id === 'fq_sealed_lord' && q.step === 2 && !q.ready ? `<button class="btn small primary" data-here="결전" data-q-final>${icon('sword', 14)}<span>결전 시작</span></button>` : ''}<button class="btn small ${q.ready ? 'primary' : ''}" data-here="퀘스트 받기·보고" data-q-report="${esc(q.quest_id)}" ${q.ready ? '' : 'disabled'}>${icon('scroll', 14)}<span>${q.ready ? '보고하기' : '진행 중'}</span></button></div></li>`;
}
function factionItem(f) {
  if (!f) return '';
  if (f.locked) return `<li class="q-item locked">${head('faction', { cat: nameOf(f.faction_id), title: f.title })}
    <p class="muted small">아직 열리지 않았습니다 · ${esc(f.locked)}</p>
    <div class="btn-row"><button class="btn small ghost" data-go-faction>세력 화면</button></div></li>`;
  return `<li class="q-item ${f.ready ? 'ready' : ''}">${head('faction', { cat: nameOf(f.faction_id), title: f.title })}
    <p class="q-goal">${esc(f.goal || '')}</p>
    ${f.locked ? `<p class="muted small">${esc(f.locked)}</p>` : ''}
    ${(f.tasks || []).length ? `<ul class="q-tasks">${f.tasks.map(taskLine).join('')}</ul>` : ''}
    ${atLine(f)}
    <div class="btn-row">${f.ready ? `<button class="btn small primary" data-here="세력 퀘스트 보고" data-f-report>${icon('scroll', 14)}<span>보고하기</span></button>` : ''}<button class="btn small ghost" data-go-faction>세력 화면</button></div></li>`;
}
function availItem(q) {
  return `<li class="q-item avail${isStoryMain(q) ? ' story' : ''}">${head(q.kind, q)}
    <p class="q-goal">${esc(q.summary || '')}</p>
    <p class="q-at ${q.here ? 'ok' : ''}">${icon('pin', 12)} ${esc(q.region_name || '')} · Lv.${q.min_level}${q.locked ? ` · <b class="bad">Lv.${q.min_level}부터</b>` : ''}</p>
    ${q.here && !q.locked ? `<div class="btn-row"><button class="btn small primary" data-here="퀘스트 받기·보고" data-q-report="${esc(q.quest_id)}">${icon('scroll', 14)}<span>이야기 듣기</span></button></div>` : ''}</li>`;
}

const isHere = (q, here) => !!here && new Set([...(q.at || []), ...(q.tasks || []).flatMap(t => t.regions || []), ...(q.clues?.regions || [])]).has(here);
function hereNote(b) {
  const here = b.here_id; if (!here) return '';
  const hits = [];
  for (const q of b.active || []) if (isHere(q, here)) hits.push(q.title);
  if (b.faction && !b.faction.locked && (b.faction.regions || []).includes(here)) hits.push(b.faction.title);
  const givers = (b.available || []).filter(q => q.here && !q.locked).length;
  if (!hits.length && !givers) return '';
  return `<p class="hint accent q-here">${icon('flag', 14)}<span><b>퀘스트 지역</b> · ${hits.length ? `「${esc(hits.slice(0, 3).join('」·「'))}」의 할 일이 이곳에 있습니다.` : ''}${givers ? ` 이곳에서 받을 수 있는 퀘스트 ${givers}개.` : ''}</span></p>`;
}

async function askFinal() {
  return askPartySize('final', await partyHere());
}

const GKEY = 'yh-q-group';
const GROUPS = [['', '순서대로'], ['field', '분야별'], ['place', '장소별']];
const grp = () => { try { return localStorage.getItem(GKEY) || ''; } catch { return ''; } };
const fieldOf = q => q.kind === 'main' ? '주 이야기' : storyArcOf(q.cat) || (q.cat || '').split('·')[0] || '기타';
const placeOf = q => { const left = (q.tasks || []).find(t => t.cur < t.n && (t.regions || []).length);
  return left ? nameOf(left.regions[0]) : (q.at_names || [])[0] || '어디서나'; };
function grouped(list, b) {
  const by = grp() === 'place' ? placeOf : fieldOf, map = new Map();
  for (const q of list) { const k = by(q); if (!map.has(k)) map.set(k, []); map.get(k).push(q); }
  const here = store.character?.location;
  const keys = [...map.keys()].sort((x, y) => (y === here) - (x === here) || (x === '주 이야기' ? -1 : y === '주 이야기' ? 1 : 0) || x.localeCompare(y, 'ko'));
  return `${facBox(b.faction)}
    ${keys.map(k => `<details class="q-grp" data-q-grp="${esc(grp() + ':' + k)}" ${opened().includes(grp() + ':' + k) ? 'open' : ''}>
      <summary class="sub-h">${esc(k)}${k === here ? ' <small class="ok">· 지금 여기</small>' : ''} <small class="muted">${map.get(k).length}</small></summary>
      <ul class="q-list">${map.get(k).map(activeItem).join('')}</ul></details>`).join('')}`;
}
const AV_ORDER = ['직업', '소속', '세력', '연계', '전투', '조사', '채집', '낚시', '제작', '생활', '연담', '뒷이야기', '요인록', '묵적록', '명등기', '무용담'];
const avField = q => storyArcOf(q.cat) || (q.cat || '').split('·')[0] || '기타';
const avRank = k => { const i = AV_ORDER.indexOf(k); return i < 0 ? AV_ORDER.length : i; };
const canHere = q => !!q.here && !q.locked;
function availGroups(list) {
  const map = new Map();
  for (const q of list) { const k = avField(q); if (!map.has(k)) map.set(k, []); map.get(k).push(q); }
  const keys = [...map.keys()].sort((x, y) => avRank(x) - avRank(y) || x.localeCompare(y, 'ko'));
  const op = opened();
  return keys.map(k => {
    const qs = map.get(k).sort((x, y) => x.min_level - y.min_level || String(x.title).localeCompare(String(y.title), 'ko'));
    return `<details class="q-grp q-av" data-q-av="${esc(k)}" ${op.includes('av:' + k) ? 'open' : ''}>
      <summary class="sub-h">${esc(k)} <small class="muted">${qs.length}</small></summary>
      <ul class="q-list">${qs.map(availItem).join('')}</ul></details>`;
  }).join('');
}
function facBox(f) {
  if (!f) return '';
  return `<details class="q-grp" data-q-fac ${opened().includes('!fac') ? '' : 'open'}>
    <summary class="sub-h">세력 <small class="muted">${esc(nameOf(f.faction_id))}${f.locked ? ' · 잠김' : f.ready ? ' · <b class="ok">보고 가능</b>' : ''}</small></summary>
    <ul class="q-list">${factionItem(f)}</ul></details>`;
}
const OKEY = 'yh-q-open';
const opened = () => { try { return JSON.parse(localStorage.getItem(OKEY) || '[]'); } catch { return []; } };
function setOpen(k, open) {
  const s = new Set(opened()); open ? s.add(k) : s.delete(k);
  try { localStorage.setItem(OKEY, JSON.stringify([...s].slice(-40))); } catch {}
}

let qbWatch = null, qbAt = 0, qbSeen = null;
const HERE_KINDS = new Set(['win', 'gather', 'fish', 'search', 'clue']);
const setOf = a => (a || []).length ? new Set(a) : null;
function watchOf(b) {
  const res = [], give = new Set();
  const add = (k, regs, t) => res.push({ k, re: TASK_ACTS[k] || CHANGES.boardOther, regs: HERE_KINDS.has(k) ? setOf(regs) : null, mn: setOf(t?.mn), items: setOf(t?.items), left: t ? t.n - t.cur : 0, src: t || null });
  for (const q of [...(b.active || []), ...(b.faction && !b.faction.locked ? [b.faction] : [])]) {
    for (const t of q.tasks || []) if (t.cur < t.n) add(t.t, t.regions, t);
    for (const g of q.give || []) give.add(g.item_id);
    if (q.clues) add('clue', q.clues.regions);
  }
  return { res, give, level: b.level, here: b.here_id };
}
const GATHERS = new Set(['world_field_gather', 'world_meisho_dig']);
const gotIds = data => [data.item_id, ...Object.keys(data.extra || {})].map(baseOf);
const won = (name, data) => name === 'world_battle_action' && data?.ended === 'victory';
const FISHING = name => TASK_ACTS.fish.test(name);
function counts(t, name, data) {
  if (FISHING(name)) return t.k !== 'fish' || !!data?.caught;
  if (name === 'world_battle_action') return t.k !== 'win' || (won(name, data) && (!t.mn || t.mn.has(data?.result?.monster)));
  if (hit('boardSearch', name) && t.k === 'clue') return data?.outcome === 'clue';
  if (GATHERS.has(name) && t.k === 'gather' && t.items && data?.item_id) return gotIds(data).some(id => t.items.has(id));
  return true;
}
const ONE_STEP = (t, name) => (t.k === 'search' && hit('boardSearch', name)) || (t.k === 'fish' && FISHING(name)) || (t.k === 'win' && name === 'world_battle_action') || (t.k === 'gather' && !t.items && GATHERS.has(name));
const itemArg = a => a?.p_item_id || a?.p_item || null;
function gains(w, name, data, args) {
  if (!w.give.size || !hit('boardItems', name)) return false;
  if (name === 'world_battle_action') return won(name, data) && Object.keys(data?.result?.loot || {}).some(id => w.give.has(baseOf(id)));
  if (GATHERS.has(name) && data?.item_id) return gotIds(data).some(id => w.give.has(id));
  if (FISHING(name)) return !!data?.caught && w.give.has(baseOf(data.fish));
  const id = itemArg(args);
  if (id) return w.give.has(baseOf(id));
  if (hit('boardPet', name)) return [...w.give].some(g => /^(pet_|treat_)/.test(g));
  return true;
}
function progress(w, name, data) {
  let soon = false, now = false;
  for (const t of w.res) {
    if (!t.re.test(name) || (t.regs && !t.regs.has(w.here) && !hit('boardAway', name)) || !counts(t, name, data)) continue;
    if (!ONE_STEP(t, name)) { now = true; break; }
    t.left -= 1; if (t.left <= 0) { now = true; break; }
    if (t.src && t.src.cur < t.src.n) t.src.cur += 1;
    soon = true;
  }
  return now ? 'now' : soon ? 'soon' : '';
}
on('changed', ev => {
  const name = ev?.name || '';
  if (midBattle(ev) || !qbWatch) return;
  const w = qbWatch;
  const p = progress(w, name, ev?.data);
  if (hit('board', name) || (store.character && w.level != null && store.character.level !== w.level)
    || p === 'now' || (p === 'soon' && Date.now() - qbAt > 60000) || gains(w, name, ev?.data, ev?.args)) invalidate('world_quest_board');
});
window.addEventListener('yahang:arrived', () => invalidate('world_quest_board'));

export function neededItems(b) {
  const need = new Map();
  const add = (id, left, title) => { if (!id || left <= 0) return; const cur = need.get(id) || { left: 0, quests: [] }; cur.left += left; if (!cur.quests.includes(title)) cur.quests.push(title); need.set(id, cur); };
  for (const q of [...(b?.active || []), ...(b?.faction && !b.faction.locked ? [b.faction] : [])]) {
    for (const t of q.tasks || []) if (t.t === 'gather' && t.cur < t.n && (!(t.regions || []).length || t.regions.includes(b.here_id))) for (const id of itemsOf(t)) add(id, t.n - t.cur, q.title);
    for (const g of q.give || []) add(g.item_id, g.n - g.have, q.title);
  }
  return need;
}
export function markNeeded(root, b) {
  const need = neededItems(b);
  $$('[data-need-item]', root).forEach(el => { const n = need.get(el.dataset.needItem); el.classList.toggle('q-need', !!n); if (n) el.title = `퀘스트: ${n.quests.join(', ')} · ${n.left}개 더`; else el.removeAttribute('title'); });
  $$('[data-need-spot]', root).forEach(el => { const ids = (el.dataset.needSpot || '').split(','), hit_ = ids.filter(id => need.has(id));
    let tag = el.querySelector('.q-need-tag:not(.pj-tag)'); if (!hit_.length) { tag?.remove(); return; }
    if (!tag) { tag = document.createElement('span'); tag.className = 'q-need-tag'; el.querySelector('b')?.append(tag); }
    tag.textContent = '퀘스트'; tag.title = [...new Set(hit_.flatMap(id => need.get(id).quests))].join(', '); });
}

export const questBox = () => `<section class="panel quest-box" id="quest-box"></section>`;

export async function fillQuests(box) {
  if (!box) return;
  let b;
  try { b = await load('world_quest_board', undefined, { maxAge: 600000 }); if (b !== qbSeen) { qbSeen = b; qbAt = Date.now(); qbWatch = watchOf(b); } } catch { box.remove(); return; }
  markNeeded(document, b);
  if (!box.isConnected) return;
  const mainFirst = (x, y) => isStoryMain(y) - isStoryMain(x);
  const act_ = [...(b.active || [])].sort((x, y) => mainFirst(x, y) || isHere(y, b.here_id) - isHere(x, b.here_id));
  const avail = b.available || [], story = avail.filter(isStoryMain).sort((x, y) => (y.here && !y.locked) - (x.here && !x.locked) || x.min_level - y.min_level);
  const hereAv = avail.filter(q => !isStoryMain(q) && canHere(q)).sort((x, y) => avRank(avField(x)) - avRank(avField(y)) || x.min_level - y.min_level), rest = avail.filter(q => !isStoryMain(q) && !canHere(q));
  const nAct = act_.length + (b.faction && !b.faction.locked ? 1 : 0);
  noteTasks(b);
  noteReady({ ...b, active: act_ });
  box.innerHTML = `${hereNote({ ...b, active: act_ })}
    <details class="fold" ${isOpen() ? 'open' : ''} data-q-fold>
      <summary class="panel-head"><h2>${icon('scroll', 16)}퀘스트 <small class="muted">진행 ${nAct} · 마침 ${b.done}/${b.total}</small></h2></summary>
      <div class="panel-body q-board">
        ${RAID_ON && b.final_again && b.here_id === 'sealed_abyss' ? `<div class="btn-row q-again"><span class="muted small">구중 봉주와 다시 겨룰 수 있습니다</span><button class="btn small primary" data-here="결전" data-q-final>${icon('sword', 14)}<span>결전 다시 도전</span></button></div>` : ''}
        ${nAct > 1 ? `<div class="chips kind-chips q-group" role="group" aria-label="묶어 보기"><span class="muted small">묶어 보기</span>${GROUPS.map(([k, n]) => `<button class="chip ${grp() === k ? 'on' : ''}" data-q-group="${k}">${n}</button>`).join('')}</div>` : ''}
        ${grp() && act_.length > 1 ? grouped(act_, b) : `${facBox(b.faction)}${act_.length ? `<ul class="q-list">${act_.map(activeItem).join('')}</ul>` : '<p class="muted small">진행 중인 퀘스트가 없습니다. 아래에서 받을 수 있는 퀘스트를 찾아보세요.</p>'}`}
        ${story.length ? `<h3 class="sub-h q-story-h">${icon('scroll', 14)}받을 수 있는 본편</h3><ul class="q-list">${story.map(availItem).join('')}</ul>` : ''}
        ${hereAv.length ? `<h3 class="sub-h">여기서 받을 수 있는 퀘스트</h3><ul class="q-list">${hereAv.map(availItem).join('')}</ul>` : ''}
        ${rest.length ? `<details class="q-grp q-av-all" data-q-avall ${opened().includes('!avall') ? 'open' : ''}><summary class="sub-h q-av-h">${hereAv.length ? '다른 곳에서' : ''} 받을 수 있는 퀘스트 <small class="muted">${rest.length}</small></summary>${availGroups(rest)}</details>` : ''}
      </div></details>`;
  $('[data-q-fold]', box).addEventListener('toggle', e => { try { localStorage.setItem(foldKey, e.target.open ? '1' : '0'); } catch {} });
  $$('[data-q-grp]', box).forEach(d => d.addEventListener('toggle', () => setOpen(d.dataset.qGrp, d.open)));
  $('[data-q-fac]', box)?.addEventListener('toggle', e => setOpen('!fac', !e.target.open));
  $('[data-q-avall]', box)?.addEventListener('toggle', e => setOpen('!avall', e.target.open));
  $$('[data-q-av]', box).forEach(d => d.addEventListener('toggle', () => setOpen('av:' + d.dataset.qAv, d.open)));
  $$('[data-q-report]', box).forEach(x => x.onclick = () => report(x));
  $$('[data-story-combo]', box).forEach(x => x.onclick = () => storyCombine(x));
  $$('[data-q-group]', box).forEach(x => x.onclick = () => { try { localStorage.setItem(GKEY, x.dataset.qGroup); } catch {} fillQuests(box); });
  $('[data-q-final]', box)?.addEventListener('click', e => guard(e.currentTarget, async () => {
    if (!(await askFinal())) return null;
    const r = await act('world_raid_final_start'); window.yahangGo('raid', r?.raid_id || ''); return null;
  }));
  $('[data-f-report]', box)?.addEventListener('click', e => guard(e.currentTarget, async () => {
    const r = await act('world_faction_report');
    playDialogue(r, store.character?.major_faction_id); return null;
  }));
  $('[data-go-faction]', box)?.addEventListener('click', () => { try { sessionStorage.setItem('yh-fpop', 'rank'); } catch {} window.yahangGo('char', 'faction'); });
}

export async function report(btn) {
  await guard(btn, async () => {
    const id = btn.dataset.qReport, was = [...(qbSeen?.active || []), ...(qbSeen?.available || [])].find(x => x.quest_id === id);
    const r = await act('world_quest_report', { p_quest: id });
    invalidate('world_quest_board');
    const nextHtml = r.done && isStoryMain(was || { quest_id: id }) ? await nextStoryHtml(arcOf(was)) : '';
    window.dispatchEvent(new CustomEvent('yh-sfx', { detail: r.done ? 'reward' : 'confirm' }));
    const extra = r.done ? `<p class="hint good q-done">${icon('check', 14)}<span><b>퀘스트 완료</b> · 「${esc(r.quest_title)}」</span></p>${nextHtml}`
      : r.clues_open ? `<p class="hint accent">${icon('scroll', 14)}<span>이제 이 장의 단서를 탐색에서 찾을 수 있습니다. 모으면 일지 › 주 이야기에서 가설을 확정하세요.</span></p>`
      : r.next ? `<p class="hint">${icon('chevron', 14)}<span>다음 · <b>${esc(r.next.title)}</b> — ${esc(r.next.goal)}</span></p>` : '';
    playDialogue({ title: `${r.quest_title} · ${r.title}`, lines: r.lines, cast: r.cast, reward: r.reward, extra, again: '마친 장면은 일지의 퀘스트 장면 목록에서 다시 볼 수 있습니다.' }, null);
    return null;
  });
}
