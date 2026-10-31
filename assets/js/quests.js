// 현장의 퀘스트 칸: 진행 중인 주 이야기·보조 퀘스트·세력 퀘스트와 여기서 받을 수 있는 퀘스트(접고 펼친다).
// 진행과 판정은 서버(world_quest_board·world_quest_report, 세력은 world_faction_*)가 하고, 여기서는 그리고 부른다.
// 할 일을 다 마치면 한 번 알리고(이 기기·접속 동안), 보고하면 장면 대사를 대화창으로 보인다.
import { store, act, rpc, esc, icon, guard, $, $$, nameOf, toast, ask, RAID_ON } from './core.js';
import { load, invalidate, chip, knownRecipes } from './views/common.js';
import { playDialogue } from './factionquest.js';

const KIND = { main: '주 이야기', side: '보조', faction: '세력' };
const foldKey = 'yh-fold-quests';
const isOpen = () => { try { return localStorage.getItem(foldKey) !== '0'; } catch { return true; } };

// 할 일을 다 마친 퀘스트를 한 번만 알린다(퀘스트·장면마다)
function noteReady(b) {
  let seen; try { seen = new Set(JSON.parse(sessionStorage.getItem('yh-q-ready') || '[]')); } catch { seen = new Set(); }
  const ready = [...(b.active || []).filter(q => q.phase === 'step' && q.ready).map(q => [`${q.quest_id}:${q.step}`, q.title]),
    ...(b.faction?.ready ? [[`f:${b.faction.scene_key}`, b.faction.title]] : [])];
  let fresh = false;
  for (const [k, t] of ready) if (!seen.has(k)) { seen.add(k); fresh = true; toast(`「${t}」 할 일을 모두 마쳤습니다. 보고하세요.`, 'ok'); }
  if (fresh) { window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'find' })); try { sessionStorage.setItem('yh-q-ready', JSON.stringify([...seen].slice(-200))); } catch {} }
}

// 할 일 줄 끝의 바로 가기(7.4.6): 할 일 지역 → 지도에서 짚기, 만들기·넘길 물품 → 제작 화면(검색칸에 이름)
const mapBtns = (regs, n = 3) => (regs || []).slice(0, n).map(r => `<button type="button" class="q-link" data-q-map="${esc(r)}" title="지도에서 보기">${icon('map', 12)}<span>${esc(nameOf(r))}</span></button>`).join('');
const craftBtn = id => `<button type="button" class="q-link" data-q-craft="${esc(nameOf(id))}" title="제작법 찾기">${icon('hammer', 12)}<span>제작법</span></button>`;
// 얻는 곳(7.5.9, 사용자 요청): 지역을 정하지 않은 채집 할 일·넘길 물품은 그 물품이 나오는 지역을 5곳까지(물품 정보의 「얻는 곳」과 같은 world_item_sources).
// 줄을 그린 뒤 비어 있는 칸만 채운다(물품마다 이 접속 동안 한 번 읽음).
const srcSlot = id => `<span class="q-src" data-q-src="${esc(id)}"></span>`;
const itemsOf = t => Array.isArray(t.items) ? t.items : Object.keys(t.items || {});
// 단위(7.5.9d, 사용자 요청): 물품을 정한 채집·제작은 「야령초 모으기 0/3개」, 물품을 정하지 않은 채집은 「채집하기 0/3회」
const unitOf = t => t.t === 'gather' ? (itemsOf(t).length ? '개' : '회') : t.t === 'craft' && itemsOf(t).length ? '개' : '';
export const taskLine = t => { const done = t.cur >= t.n, items = t.t === 'craft' ? itemsOf(t) : [];
  const src = !done && t.t === 'gather' && !(t.regions || []).length ? itemsOf(t).slice(0, 1).map(srcSlot).join('') : '';
  return `<li class="${done ? 'ok' : ''}">${icon(done ? 'check' : 'chevron', 12)}<span>${esc(t.label)}</span><b>${t.cur}/${t.n}${unitOf(t)}</b>${done ? '' : `<span class="q-links">${mapBtns(t.regions)}${items.slice(0, 1).map(craftBtn).join('')}${src}</span>`}</li>`; };
export const giveLine = g => { const done = g.have >= g.n;
  return `<li class="${done ? 'ok' : ''}">${icon('bag', 12)}<span>${esc(g.name || nameOf(g.item_id))} 넘기기</span><b>${g.have}/${g.n}</b>${done ? '' : `<span class="q-links">${hasRecipe(g.item_id) ? craftBtn(g.item_id) : ''}${srcSlot(g.item_id)}</span>`}</li>`; };
const srcCache = new Map();
async function fillSrc(root = document) {
  for (const el of root.querySelectorAll('[data-q-src]:not([data-f])')) {
    el.dataset.f = '1';
    const id = el.dataset.qSrc;
    try {
      if (!srcCache.has(id)) srcCache.set(id, rpc('world_item_sources', { p_item: id }));
      const s = await srcCache.get(id) || {};
      const places = [...new Set([...(s.gather || []), ...(s.sites || []), ...(s.monsters || []), ...(s.fish || [])])];
      const total = Math.max(places.length, (s.gather_n || 0), (s.sites_n || 0), (s.monsters_n || 0), (s.fish_n || 0));
      if (!el.isConnected) continue;
      el.innerHTML = places.length ? `<small class="muted">얻는 곳</small>${mapBtns(places, 5)}${total > 5 ? `<small class="muted">외 ${total - 5}곳</small>` : ''}`
        : s.shop || s.smithy ? `<small class="muted">안전지대 ${s.smithy ? '대장간' : '상점'}에서 삽니다</small>` : '';
    } catch { srcCache.delete(id); }
  }
}
// 퀘스트 칸·일지가 다시 그려질 때마다 빈 칸을 채운다(그리기 뒤 한 번 모아서)
let srcTimer = 0;
new MutationObserver(() => { clearTimeout(srcTimer); srcTimer = setTimeout(() => { if (document.querySelector('[data-q-src]:not([data-f])')) fillSrc(); }, 80); })
  .observe(document.body, { childList: true, subtree: true });
// 넘길 물품에 제작법이 있는가(가방 정보를 이미 받았을 때만 — 없으면 단추를 달지 않음)
const hasRecipe = id => knownRecipes().some(r => r.output === id);
// 퀘스트 칸·일지 어디서든 바로 가기를 누르면
document.addEventListener('click', e => {
  const m = e.target.closest?.('[data-q-map]'), c = e.target.closest?.('[data-q-craft]');
  if (!m && !c) return;
  e.preventDefault(); e.stopPropagation();
  if (m) import('./views/map.js').then(x => { x.focusRegion(m.dataset.qMap); window.yahangGo('map', 'world'); });
  else { window.dispatchEvent(new CustomEvent('yh-craft-focus', { detail: { search: c.dataset.qCraft } })); window.yahangGo('bag', 'craft'); }
});
export const atLine = q => (q.at_names || []).length ? `<p class="q-at ${q.here_ok ? 'ok' : ''}">${icon('pin', 12)} 보고: ${esc(q.at_names.join('·'))}${q.here_ok ? ' (지금 여기)' : ''}</p>` : '';
const head = (kind, q) => `<header>${chip(KIND[kind] || '보조', kind === 'main' ? 'accent' : kind === 'faction' ? 'warn' : '')}${chip(q.cat || '')}<b>${esc(q.title)}</b></header>`;

function activeItem(q) {
  if (q.phase === 'clues') {
    const c = q.clues || {};
    return `<li class="q-item">${head(q.kind, q)}
      <p class="q-goal">단서 찾기 · ${c.found ?? 0}/${c.total ?? 0} — ${esc((c.region_names || []).join('·'))}을(를) 탐색하고, 모으면 일지 › 주 이야기에서 가설을 확정하세요.</p>
      <div class="btn-row"><a class="btn small" href="#/log/story">${icon('scroll', 14)}<span>일지 보기</span></a></div></li>`;
  }
  return `<li class="q-item ${q.ready ? 'ready' : ''}">${head(q.kind, q)}
    <p class="q-step">장면 ${q.step}/${q.steps} · ${esc(q.step_title || '')}</p>
    <p class="q-goal">${esc(q.goal || '')}</p>
    ${(q.tasks || []).length || (q.give || []).length ? `<ul class="q-tasks">${(q.tasks || []).map(taskLine).join('')}${(q.give || []).map(giveLine).join('')}</ul>` : ''}
    ${atLine(q)}
    <div class="btn-row">${RAID_ON && q.quest_id === 'fq_sealed_lord' && q.step === 2 && !q.ready ? `<button class="btn small primary" data-q-final>${icon('sword', 14)}<span>결전 시작</span></button>` : ''}<button class="btn small ${q.ready ? 'primary' : ''}" data-q-report="${esc(q.quest_id)}" ${q.ready ? '' : 'disabled'}>${icon('scroll', 14)}<span>${q.ready ? '보고하기' : '진행 중'}</span></button></div></li>`;
}
function factionItem(f) {
  if (!f) return '';
  // 등급 퀘스트가 아직 잠겨 있으면(평판·레벨) 할 일을 보이지 않고 언제 열리는지만 적는다(7.5.7 — 다시 가입한 뒤 잠긴 2등급이 진행 중처럼 보이던 것)
  if (f.locked) return `<li class="q-item locked">${head('faction', { cat: nameOf(f.faction_id), title: f.title })}
    <p class="muted small">아직 열리지 않았습니다 · ${esc(f.locked)}</p>
    <div class="btn-row"><button class="btn small ghost" data-go-faction>세력 화면</button></div></li>`;
  return `<li class="q-item ${f.ready ? 'ready' : ''}">${head('faction', { cat: nameOf(f.faction_id), title: f.title })}
    <p class="q-goal">${esc(f.goal || '')}</p>
    ${f.locked ? `<p class="muted small">${esc(f.locked)}</p>` : ''}
    ${(f.tasks || []).length ? `<ul class="q-tasks">${f.tasks.map(taskLine).join('')}</ul>` : ''}
    ${atLine(f)}
    <div class="btn-row">${f.ready ? `<button class="btn small primary" data-f-report>${icon('scroll', 14)}<span>보고하기</span></button>` : ''}<button class="btn small ghost" data-go-faction>세력 화면</button></div></li>`;
}
function availItem(q) {
  return `<li class="q-item avail">${head(q.kind, q)}
    <p class="q-goal">${esc(q.summary || '')}</p>
    <p class="q-at ${q.here ? 'ok' : ''}">${icon('pin', 12)} ${esc(q.region_name || '')} · Lv.${q.min_level}${q.locked ? ` · <b class="bad">Lv.${q.min_level}부터</b>` : ''}</p>
    ${q.here && !q.locked ? `<div class="btn-row"><button class="btn small primary" data-q-report="${esc(q.quest_id)}">${icon('scroll', 14)}<span>이야기 듣기</span></button></div>` : ''}</li>`;
}

// 진행 중인 퀘스트의 할 일·보고 장소·단서 지역에 지금 있는 곳이 들어 있는가
const isHere = (q, here) => !!here && new Set([...(q.at || []), ...(q.tasks || []).flatMap(t => t.regions || []), ...(q.clues?.regions || [])]).has(here);
// 이 지역이 퀘스트 지역인가(할 일·보고 장소·의뢰인이 여기)
function hereNote(b) {
  const here = b.here_id; if (!here) return '';
  const hits = [];
  for (const q of b.active || []) if (isHere(q, here)) hits.push(q.title);
  if (b.faction && !b.faction.locked && (b.faction.regions || []).includes(here)) hits.push(b.faction.title);
  const givers = (b.available || []).filter(q => q.here && !q.locked).length;
  if (!hits.length && !givers) return '';
  return `<p class="hint accent q-here">${icon('flag', 14)}<span><b>퀘스트 지역</b> · ${hits.length ? `「${esc(hits.slice(0, 3).join('」·「'))}」의 할 일이 이곳에 있습니다.` : ''}${givers ? ` 이곳에서 받을 수 있는 퀘스트 ${givers}개.` : ''}</span></p>`;
}

// 결전을 열기 전에 인원에 맞춰 묻는다(7.4.3). 체력은 인원마다 늘지만(1·1.7·2.3·2.8배) 혼자서는 거의 이길 수 없고, 둘은 어렵지만 해볼 만하다.
// 셈은 같은 곳에 있는 파티원 가운데 쓰러짐·원정이 아닌 사람(초대 알림이 가는 사람)이고, 실제로 오는지는 90초 안에 정해진다.
async function askFinal() {
  const p = await load('world_party_overview', undefined, { maxAge: 30000 }).catch(() => null);
  const here = store.character?.location, me = store.user?.id;
  const n = 1 + Math.min(3, (p?.party ? p.members || [] : []).filter(m => m.owner_id !== me && m.location === here && !m.downed && !m.expedition).length);
  const tail = '결전은 20분 동안 이어지고, 체력이 다하면 1분씩 물러납니다. 모두 물러나 있는 동안 구중 봉주가 기운을 되찾습니다.\n싸우는 동안에는 이동·탐색을 할 수 없고, 결전 화면의 「포기하고 나오기」로만 먼저 나올 수 있습니다.';
  if (n === 1) return ask(`혼자서는 거의 이길 수 없습니다.\n구중 봉주는 넷이 함께 맞서도록 만든 최종 보스입니다. 같은 곳에 함께할 파티원이 없어 혼자 시작하게 됩니다.\n${tail}\n파티원을 모아 함께 오기를 강하게 권합니다.`,
    { title: '혼자서 결전을 엽니까?', ok: '그래도 혼자 시작', cancel: '돌아가기', alarm: true });
  const msg = { 2: '둘이서는 어렵지만 해볼 만한 싸움입니다. 회복품을 넉넉히 챙기고, 한 사람이 막는 동안 다른 사람이 몰아치세요.',
    3: '셋이면 해볼 만한 싸움입니다. 막는 사람·치는 사람·돌보는 사람으로 나누면 한결 수월합니다.',
    4: '넷이 함께하는 것이 이 결전에 가장 알맞은 인원입니다.' }[n];
  return ask(`같은 곳의 파티원 ${n - 1}명에게 합류 알림이 갑니다(90초 안에 합류, 함께 ${n}명).\n${msg}\n${tail}`, { title: `${n}명이 함께 결전을 엽니까?`, ok: '결전 시작', cancel: '돌아가기' });
}

// 진행 중인 퀘스트 묶어 보기(7.4.6): 분야(주 이야기·전투·채집…) 또는 장소(아직 남은 할 일의 지역, 다 했으면 보고 장소)
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
// 세력 퀘스트 칸(7.5.7): 다른 묶음처럼 접을 수 있다. 처음엔 펼친 채, 접은 것만 '!fac'으로 남긴다
function facBox(f) {
  if (!f) return '';
  return `<details class="q-grp" data-q-fac ${opened().includes('!fac') ? '' : 'open'}>
    <summary class="sub-h">세력 <small class="muted">${esc(nameOf(f.faction_id))}${f.locked ? ' · 잠김' : f.ready ? ' · <b class="ok">보고 가능</b>' : ''}</small></summary>
    <ul class="q-list">${factionItem(f)}</ul></details>`;
}
// 묶음마다 접기(7.5.1, 제보 44): 처음엔 모두 접힌 채로, 펼친 묶음만 기기에 남긴다(7.5.3)
const OKEY = 'yh-q-open';
const opened = () => { try { return JSON.parse(localStorage.getItem(OKEY) || '[]'); } catch { return []; } };
function setOpen(k, open) {
  const s = new Set(opened()); open ? s.add(k) : s.delete(k);
  try { localStorage.setItem(OKEY, JSON.stringify([...s].slice(-40))); } catch {}
}

export const questBox = () => `<section class="panel quest-box" id="quest-box"></section>`;

export async function fillQuests(box) {
  if (!box) return;
  let b;
  try { b = await load('world_quest_board', undefined, { maxAge: 15000 }); } catch { box.remove(); return; }
  if (!box.isConnected) return;
  // 진행 중인 퀘스트가 여럿이면 지금 있는 지역의 퀘스트를 위로(같은 무리 안에서는 원래 순서)
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
  // 10장 최종 결전: 혼자 또는 같은 곳의 파티원(4명까지)과 결전을 연다 — 판정은 world_raid_final_start
  $('[data-q-final]', box)?.addEventListener('click', e => guard(e.currentTarget, async () => {
    if (!(await askFinal())) return null;
    const r = await rpc('world_raid_final_start'); window.yahangGo('raid', r?.raid_id || ''); return null;
  }));
  $('[data-f-report]', box)?.addEventListener('click', e => guard(e.currentTarget, async () => {
    const r = await act('world_faction_report'); invalidate('world_quest_board'); invalidate('world_faction_snapshot');
    playDialogue(r, store.character?.major_faction_id); return null;
  }));
  // 세력 화면으로 넘어가 등급·퀘스트 팝업을 바로 연다
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
    playDialogue({ title: `${r.quest_title} · ${r.title}`, lines: r.lines, cast: r.cast, reward: r.reward, extra }, null);
    return null;
  });
}
