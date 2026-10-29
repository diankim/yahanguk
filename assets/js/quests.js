// 현장의 퀘스트 칸: 진행 중인 주 이야기·보조 퀘스트·세력 퀘스트와 여기서 받을 수 있는 퀘스트(접고 펼친다).
// 진행과 판정은 서버(world_quest_board·world_quest_report, 세력은 world_faction_*)가 하고, 여기서는 그리고 부른다.
// 할 일을 다 마치면 한 번 알리고(이 기기·접속 동안), 보고하면 장면 대사를 대화창으로 보인다.
import { store, act, rpc, esc, icon, guard, $, $$, nameOf, toast, RAID_ON } from './core.js';
import { load, invalidate, chip } from './views/common.js';
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

export const taskLine = t => `<li class="${t.cur >= t.n ? 'ok' : ''}">${icon(t.cur >= t.n ? 'check' : 'chevron', 12)}<span>${esc(t.label)}</span><b>${t.cur}/${t.n}</b></li>`;
export const giveLine = g => `<li class="${g.have >= g.n ? 'ok' : ''}">${icon('bag', 12)}<span>${esc(g.name || nameOf(g.item_id))} 넘기기</span><b>${g.have}/${g.n}</b></li>`;
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
  if (b.faction && (b.faction.regions || []).includes(here)) hits.push(b.faction.title);
  const givers = (b.available || []).filter(q => q.here && !q.locked).length;
  if (!hits.length && !givers) return '';
  return `<p class="hint accent q-here">${icon('flag', 14)}<span><b>퀘스트 지역</b> · ${hits.length ? `「${esc(hits.slice(0, 3).join('」·「'))}」의 할 일이 이곳에 있습니다.` : ''}${givers ? ` 이곳에서 받을 수 있는 퀘스트 ${givers}개.` : ''}</span></p>`;
}

export const questBox = () => `<section class="panel quest-box" id="quest-box"></section>`;

export async function fillQuests(box) {
  if (!box) return;
  let b;
  try { b = await load('world_quest_board', undefined, { maxAge: 15000 }); } catch { box.remove(); return; }
  if (!box.isConnected) return;
  // 진행 중인 퀘스트가 여럿이면 지금 있는 지역의 퀘스트를 위로(같은 무리 안에서는 원래 순서)
  const act_ = [...(b.active || [])].sort((x, y) => isHere(y, b.here_id) - isHere(x, b.here_id));
  const facHere = !!(b.faction && b.here_id && (b.faction.regions || []).includes(b.here_id));
  const nHere = act_.filter(q => isHere(q, b.here_id)).length;
  const here = (b.available || []).filter(q => q.here), other = (b.available || []).filter(q => !q.here);
  const nAct = act_.length + (b.faction ? 1 : 0);
  noteReady({ ...b, active: act_ });
  box.innerHTML = `${hereNote({ ...b, active: act_ })}
    <details class="fold" ${isOpen() ? 'open' : ''} data-q-fold>
      <summary class="panel-head"><h2>${icon('scroll', 16)}퀘스트 <small class="muted">진행 ${nAct} · 마침 ${b.done}/${b.total}</small></h2></summary>
      <div class="panel-body">
        ${nAct ? `<ul class="q-list">${facHere ? factionItem(b.faction) : ''}${act_.slice(0, nHere).map(activeItem).join('')}${facHere ? '' : factionItem(b.faction)}${act_.slice(nHere).map(activeItem).join('')}</ul>` : '<p class="muted small">진행 중인 퀘스트가 없습니다. 아래에서 받을 수 있는 퀘스트를 찾아보세요.</p>'}
        ${here.length ? `<h3 class="sub-h">여기서 받을 수 있는 퀘스트</h3><ul class="q-list">${here.map(availItem).join('')}</ul>` : ''}
        ${other.length ? `<details class="q-more"><summary>다른 곳에서 받을 수 있는 퀘스트 ${other.length}개</summary><ul class="q-list">${other.map(availItem).join('')}</ul></details>` : ''}
      </div></details>`;
  $('[data-q-fold]', box).addEventListener('toggle', e => { try { localStorage.setItem(foldKey, e.target.open ? '1' : '0'); } catch {} });
  $$('[data-q-report]', box).forEach(x => x.onclick = () => report(x));
  // 10장 최종 결전: 혼자 또는 같은 곳의 파티원(4명까지)과 결전을 연다 — 판정은 world_raid_final_start
  $('[data-q-final]', box)?.addEventListener('click', e => guard(e.currentTarget, async () => {
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
