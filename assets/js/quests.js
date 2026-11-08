import { store, act, rpc, esc, icon, guard, $, $$, nameOf, toast, ask, RAID_ON, on, midBattle } from './core.js';
import { load, invalidate, chip, knownRecipes } from './views/common.js';
import { playDialogue } from './factionquest.js';
import { itemSources, sourcePlaces, sourceTotal, regionBtn, sourcesMore, regionsMore } from './sources.js';
import { TASK_ACTS, CHANGES, hit } from './changes.js';
import { baseOf } from './hq.js';
import { askPartySize, partyHere } from './views/fightui.js';

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
      if (!el.isConnected) continue;
      el.innerHTML = places.length ? `<small class="muted">얻는 곳</small>${places.slice(0, 5).map(r => regionBtn(r, true)).join('')}${sourcesMore(id, total - Math.min(5, places.length))}`
        : s.shop || s.smithy ? `<small class="muted">안전지대 ${s.smithy ? '대장간' : '상점'}에서 삽니다</small>` : '';
    } catch {}
  }
}
let srcTimer = 0;
new MutationObserver(() => { clearTimeout(srcTimer); srcTimer = setTimeout(() => { if (document.querySelector('[data-q-src]:not([data-f])')) fillSrc(); }, 80); })
  .observe(document.body, { childList: true, subtree: true });
const hasRecipe = id => knownRecipes().some(r => r.output === id);
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
const head = (kind, q) => `<header>${chip(KIND[kind] || '보조', kind === 'main' ? 'accent' : kind === 'faction' ? 'warn' : '')}${kind === 'main' ? '' : chip(q.cat || '')}<b>${esc(q.title)}</b></header>`;

function activeItem(q) {
  if (q.phase === 'clues') {
    const c = q.clues || {};
    return `<li class="q-item">${head(q.kind, q)}
      <p class="q-goal">단서 찾기 · ${c.found ?? 0}/${c.total ?? 0} — ${esc(((c.region_names || []).join('·') || '이 장의 지역') + '을(를)')} 탐색하고, 모으면 일지 › 주 이야기에서 가설을 확정하세요.</p>
      <div class="btn-row"><a class="btn small" href="#/log/story">${icon('scroll', 14)}<span>일지 보기</span></a></div></li>`;
  }
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
  return `<li class="q-item avail">${head(q.kind, q)}
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
const fieldOf = q => q.kind === 'main' ? '주 이야기' : (q.cat || '').split('·')[0] || '기타';
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

let qbWatch = null;
const HERE_KINDS = new Set(['win', 'gather', 'fish', 'search', 'clue']);
const setOf = a => (a || []).length ? new Set(a) : null;
function watchOf(b) {
  const res = [], give = new Set();
  const add = (k, regs, t) => res.push({ k, re: TASK_ACTS[k] || CHANGES.boardOther, regs: HERE_KINDS.has(k) ? setOf(regs) : null, mn: setOf(t?.mn), items: setOf(t?.items) });
  for (const q of [...(b.active || []), ...(b.faction && !b.faction.locked ? [b.faction] : [])]) {
    for (const t of q.tasks || []) if (t.cur < t.n) add(t.t, t.regions, t);
    for (const g of q.give || []) give.add(g.item_id);
    if (q.clues) add('clue', q.clues.regions);
  }
  return { res, give, level: b.level, here: b.here_id };
}
const won = (name, data) => name === 'world_battle_action' && data?.ended === 'victory';
function counts(t, name, data) {
  if (name === 'world_battle_action') return t.k !== 'win' || (won(name, data) && (!t.mn || t.mn.has(data?.result?.monster)));
  if (name === 'world_field_gather' && t.k === 'gather' && t.items && data?.item_id) return t.items.has(baseOf(data.item_id));
  return true;
}
function gains(w, name, data) {
  if (!w.give.size || !hit('boardItems', name)) return false;
  if (name === 'world_battle_action') return won(name, data) && Object.keys(data?.result?.loot || {}).some(id => w.give.has(baseOf(id)));
  if (name === 'world_field_gather' && data?.item_id) return w.give.has(baseOf(data.item_id));
  return true;
}
const hits = (w, name, data) => w.res.some(t => t.re.test(name) && (!t.regs || t.regs.has(w.here) || hit('boardAway', name)) && counts(t, name, data));
on('changed', ev => {
  const name = ev?.name || '';
  if (midBattle(ev) || !qbWatch) return;
  const w = qbWatch;
  if (hit('board', name) || (store.character && w.level != null && store.character.level !== w.level)
    || hits(w, name, ev?.data) || gains(w, name, ev?.data)) invalidate('world_quest_board');
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
    let tag = el.querySelector('.q-need-tag'); if (!hit_.length) { tag?.remove(); return; }
    if (!tag) { tag = document.createElement('span'); tag.className = 'q-need-tag'; el.querySelector('b')?.append(tag); }
    tag.textContent = '퀘스트'; tag.title = [...new Set(hit_.flatMap(id => need.get(id).quests))].join(', '); });
}

export const questBox = () => `<section class="panel quest-box" id="quest-box"></section>`;

export async function fillQuests(box) {
  if (!box) return;
  let b;
  try { b = await load('world_quest_board', undefined, { maxAge: 600000 }); qbWatch = watchOf(b); } catch { box.remove(); return; }
  markNeeded(document, b);
  if (!box.isConnected) return;
  const act_ = [...(b.active || [])].sort((x, y) => isHere(y, b.here_id) - isHere(x, b.here_id));
  const here = (b.available || []).filter(q => q.here), other = (b.available || []).filter(q => !q.here);
  const nAct = act_.length + (b.faction && !b.faction.locked ? 1 : 0);
  noteReady({ ...b, active: act_ });
  box.innerHTML = `${hereNote({ ...b, active: act_ })}
    <details class="fold" ${isOpen() ? 'open' : ''} data-q-fold>
      <summary class="panel-head"><h2>${icon('scroll', 16)}퀘스트 <small class="muted">진행 ${nAct} · 마침 ${b.done}/${b.total}</small></h2></summary>
      <div class="panel-body q-board">
        ${nAct > 1 ? `<div class="chips kind-chips q-group" role="group" aria-label="묶어 보기"><span class="muted small">묶어 보기</span>${GROUPS.map(([k, n]) => `<button class="chip ${grp() === k ? 'on' : ''}" data-q-group="${k}">${n}</button>`).join('')}</div>` : ''}
        ${grp() && act_.length > 1 ? grouped(act_, b) : `${facBox(b.faction)}${act_.length ? `<ul class="q-list">${act_.map(activeItem).join('')}</ul>` : '<p class="muted small">진행 중인 퀘스트가 없습니다. 아래에서 받을 수 있는 퀘스트를 찾아보세요.</p>'}`}
        ${here.length ? `<h3 class="sub-h">여기서 받을 수 있는 퀘스트</h3><ul class="q-list">${here.map(availItem).join('')}</ul>` : ''}
        ${other.length ? `<details class="q-more"><summary>다른 곳에서 받을 수 있는 퀘스트 ${other.length}개</summary><ul class="q-list">${other.map(availItem).join('')}</ul></details>` : ''}
      </div></details>`;
  $('[data-q-fold]', box).addEventListener('toggle', e => { try { localStorage.setItem(foldKey, e.target.open ? '1' : '0'); } catch {} });
  $$('[data-q-grp]', box).forEach(d => d.addEventListener('toggle', () => setOpen(d.dataset.qGrp, d.open)));
  $('[data-q-fac]', box)?.addEventListener('toggle', e => setOpen('!fac', !e.target.open));
  $$('[data-q-report]', box).forEach(x => x.onclick = () => report(x));
  $$('[data-q-group]', box).forEach(x => x.onclick = () => { try { localStorage.setItem(GKEY, x.dataset.qGroup); } catch {} fillQuests(box); });
  $('[data-q-final]', box)?.addEventListener('click', e => guard(e.currentTarget, async () => {
    if (!(await askFinal())) return null;
    const r = await rpc('world_raid_final_start'); window.yahangGo('raid', r?.raid_id || ''); return null;
  }));
  $('[data-f-report]', box)?.addEventListener('click', e => guard(e.currentTarget, async () => {
    const r = await act('world_faction_report'); invalidate('world_quest_board'); invalidate('world_faction_snapshot');
    playDialogue(r, store.character?.major_faction_id); return null;
  }));
  $('[data-go-faction]', box)?.addEventListener('click', () => { try { sessionStorage.setItem('yh-fpop', 'rank'); } catch {} window.yahangGo('char', 'faction'); });
}

export async function report(btn) {
  await guard(btn, async () => {
    const r = await act('world_quest_report', { p_quest: btn.dataset.qReport });
    invalidate('world_quest_board');
    window.dispatchEvent(new CustomEvent('yh-sfx', { detail: r.done ? 'reward' : 'confirm' }));
    const extra = r.done ? `<p class="hint good q-done">${icon('check', 14)} <b>퀘스트 완료</b> · 「${esc(r.quest_title)}」</p>`
      : r.clues_open ? `<p class="hint accent">${icon('scroll', 14)} 이제 이 장의 단서를 탐색에서 찾을 수 있습니다. 모으면 일지 › 주 이야기에서 가설을 확정하세요.</p>`
      : r.next ? `<p class="hint">${icon('chevron', 14)} 다음 · <b>${esc(r.next.title)}</b> — ${esc(r.next.goal)}</p>` : '';
    playDialogue({ title: `${r.quest_title} · ${r.title}`, lines: r.lines, cast: r.cast, reward: r.reward, extra, again: '마친 장면은 일지의 퀘스트 장면 목록에서 다시 볼 수 있습니다.' }, null);
    return null;
  });
}
