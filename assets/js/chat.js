import { cardName } from './views/card.js';
import { isGM, db, store, on, rpc, act, esc, fmt, icon, $, $$, h, toast, friendlyError } from './core.js';
import { onWhisper, openWhisperWindow, whisperFeed, whisperOut } from './whisper.js';
import { loadCircles, circles } from './circles.js';
import { growInput, keepKeyboard } from './grow.js';
import { playAlarm } from './sound.js';
import { face } from './people.js';
import { bgroup, bclear } from './rtb.js';
import { load as loadSnap } from './views/common.js';
import { hit } from './changes.js';

const BASE_TABS = [['global', '전체'], ['region', '지역'], ['faction', '세력'], ['party', '파티']];
const tabsNow = () => circles().length ? [...BASE_TABS, ['circle', '모임']] : BASE_TABS;
const HINT = {
  global: '모든 조사원에게 보입니다 · 하루 50회',
  region: '같은 지역에 있는 조사원에게만 보입니다',
  faction: '같은 대세력 소속에게만 보입니다',
  party: '파티원에게만 보입니다',
  circle: '고른 모임의 모임원에게만 보입니다 · 색은 동료 › 모임 › 관리에서 바꿉니다',
};
let panel, col, fab, tab = 'global', msgs = [], partyMsgs = [], partyPoll, unread = 0;
let live = false, lastFull = 0, blocked = new Set();
let stick = true, forceEnd = true;
let circleId = null, circleMsgs = {}, circleUnread = {}, circleLive = false, readTimer = null;
try { circleId = sessionStorage.getItem('yh-chat-circle') || null; } catch {}

export const canPop = () => matchMedia('(pointer: fine)').matches && !document.body.classList.contains('pop-win');
export function mountChat(colEl, fabEl) {
  col = colEl; fab = fabEl;
  panel = h(`<section class="chat" aria-label="채팅">
    <div class="chat-grip" role="separator" aria-orientation="horizontal" aria-label="채팅창 크기 조절 (위아래로 끌기)" tabindex="0"><i></i></div>
    <header class="chat-head"><h2>${icon('chat', 15)} 통신망</h2>${canPop() ? `<button class="icon-btn chat-pop" aria-label="새 창으로 열기" title="새 창으로 열기">${icon('popout', 16)}</button>` : ''}${document.body.classList.contains('pop-win') ? `<button class="btn small chat-home" type="button" title="이 창을 닫고 게임 창의 채팅 칸으로 되돌립니다">${icon('back', 14)}<span>게임 창으로 되돌리기</span></button>` : ''}<button class="icon-btn chat-close" aria-label="채팅 닫기">${icon('close')}</button></header>
    <div class="segmented chat-tabs"></div>
    <div class="chat-circles" id="chat-circles" hidden></div>
    <p class="chat-hint" id="chat-hint"></p>
    <div class="chat-list-wrap"><ol class="chat-list" id="chat-list" aria-live="polite"></ol>
      <button class="chat-jump" id="chat-jump" type="button" hidden>${icon('chevron', 14)}<span>새 메시지 · 맨 아래로</span></button></div>
    <form class="chat-form" id="chat-form">
      <div class="chat-row"><textarea name="text" rows="1" maxlength="500" placeholder="메시지 입력" aria-label="메시지"></textarea>
      <button class="chat-send" type="submit" aria-label="전송">${icon('chevron', 16)}</button></div>
    </form>
  </section>`);
  placePanel();
  matchMedia('(min-width: 1280px)').addEventListener('change', placePanel);
  fab.onclick = () => toggleSheet(true);
  $('.chat-close', panel).onclick = () => toggleSheet(false);
  $('.chat-pop', panel)?.addEventListener('click', () => { toggleSheet(false); window.yahangPop?.('chat'); });
  const closeOnNav = () => { if (document.body.classList.contains('chat-open')) toggleSheet(false); };
  window.addEventListener('hashchange', closeOnNav);
  panel.addEventListener('click', e => { if (e.target.closest('a[href^="#/"]')) closeOnNav(); });
  window.addEventListener('yh-nav', closeOnNav);
  panel.querySelector('.chat-tabs').onclick = e => { const b = e.target.closest('[data-tab]'); if (b) switchTab(b.dataset.tab); };
  $('#chat-circles', panel).onclick = e => { const b = e.target.closest('[data-circle]'); if (b) pickCircle(b.dataset.circle); };
  renderTabs();
  const list = $('#chat-list', panel);
  list.addEventListener('scroll', () => { stick = list.scrollHeight - list.scrollTop - list.clientHeight < 40; if (stick) $('#chat-jump', panel).hidden = true; if (list.scrollTop < 80) loadOlder(); }, { passive: true });
  if ('ResizeObserver' in window) { let lh = 0; new ResizeObserver(() => { const h = list.clientHeight; if (h === lh) return; lh = h; if (stick && !holdScroll) list.scrollTop = list.scrollHeight; }).observe(list); }
  $('#chat-jump', panel).onclick = () => { forceEnd = true; scrollEnd(); };
  bindGrip();
  window.addEventListener('yh-circles', () => { syncCircles(); });
  loadCircles().then(syncCircles);
  const form = $('#chat-form', panel);
  form._fit = growInput(form);
  form.text.addEventListener('keydown', e => { if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); form.requestSubmit(); } });
  form.onsubmit = send;
  keepKeyboard(form);
  try { form.text.value = sessionStorage.getItem('yh-chat-draft') || ''; } catch {}
  form._fit?.();
  form.text.addEventListener('input', () => { try { sessionStorage.setItem('yh-chat-draft', form.text.value); } catch {} });
  switchTab(tab);
  subscribe();
  loadBlocks();
  on('changed', ({ name }) => { if (away) return; if (hit('chatParty', name)) { partyLoaded = false; setTimeout(syncPartySub, 300); } if (hit('chatRooms', name)) load(); if (hit('chatBlocks', name)) loadBlocks().then(draw); });
  subscribeCircles();
  syncPartySub();
  on('character', () => { if (!away) subscribe(); });
  window.addEventListener('yahang:arrived', () => { if (!away) load(); });
  popLink();
  let hiddenAt = 0;
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) { hiddenAt = Date.now(); return; }
    if (away) return;
    const gone = Date.now() - hiddenAt > 30000;
    if (!live || gone) loadNew();
    if (gone) {
      [...circleLoaded].forEach(x => { if (x !== circleId) circleLoaded.delete(x); });
      if (tab === 'circle') loadCircleNew(); else if (tab === 'party') loadParty(); else partyLoaded = false;
    }
  });
  setInterval(() => {
    if (away || document.hidden || tab === 'party') return;
    if (tab === 'circle') { if (!circleLive) loadCircleMsgs(); return; }
    if (!live || Date.now() - lastFull > 300000) loadNew();
  }, 10000);
}

export function openWhisper(name, id) { openWhisperWindow({ name, id }); }

function placePanel() {
  const wide = matchMedia('(min-width: 1280px)').matches;
  if (wide) { col.append(panel); document.body.classList.remove('chat-open'); lockSheetPage(false); fitSheetToKeyboard(); }
  else if (!document.body.classList.contains('chat-open')) col.append(panel);
}
let sheetLockY = null;
function lockSheetPage(on) {
  const b = document.body.style;
  if (on && sheetLockY == null) {
    sheetLockY = window.scrollY;
    Object.assign(b, { position: 'fixed', top: `-${sheetLockY}px`, left: '0', right: '0', width: '100%' });
  } else if (!on && sheetLockY != null) {
    const y = sheetLockY; sheetLockY = null;
    Object.assign(b, { position: '', top: '', left: '', right: '', width: '' });
    window.scrollTo(0, y);
  }
}
function fitSheetToKeyboard() {
  const vv = window.visualViewport;
  if (!vv || !document.body.classList.contains('chat-open') || !matchMedia('(max-width: 1099px)').matches) { col.style.removeProperty('--kb'); col.style.removeProperty('--vvh'); return; }
  const reset = vv.offsetTop > 0 && sheetLockY != null;
  const kb = Math.max(0, Math.round(innerHeight - vv.height - (reset ? 0 : vv.offsetTop)));
  if (kb > 40) { col.style.setProperty('--kb', `${kb}px`); col.style.setProperty('--vvh', `${Math.round(vv.height)}px`); }
  else { col.style.removeProperty('--kb'); col.style.removeProperty('--vvh'); }
  if (reset) { window.scrollTo(0, 0); requestAnimationFrame(() => { if (window.visualViewport?.offsetTop > 0) window.scrollTo(0, 0); }); }
}
function toggleSheet(open) {
  document.body.classList.toggle('chat-open', open);
  if (matchMedia('(max-width: 1099px)').matches) lockSheetPage(open);
  if (!open) fitSheetToKeyboard();
  if (open) { unread = 0; badge(); forceEnd = true; applyHeight(); requestAnimationFrame(() => $('#chat-form', panel)?._fit?.()); loadNew(); if (matchMedia('(pointer: fine)').matches) setTimeout(() => $('#chat-form textarea', panel)?.focus({ preventScroll: true }), 50); scrollEnd(); }
}
function badge() { fab.dataset.count = unread ? String(Math.min(unread, 99)) : ''; }
function renderTabs() {
  const t = tabsNow(), box = $('.chat-tabs', panel);
  if (!t.some(x => x[0] === tab)) tab = 'global';
  box.style.setProperty('--n', t.length);
  box.innerHTML = t.map(([k, l]) => `<button data-tab="${k}" class="${k === tab ? 'on' : ''}">${l}</button>`).join('');
  paintCircleDots(); paintPartyDot(); paintChanDots();
}
const chanNew = { global: false, region: false, faction: false };
function paintChanDots() { for (const k of Object.keys(chanNew)) $(`.chat-tabs [data-tab="${k}"]`, panel)?.classList.toggle('has-dot', chanNew[k] && tab !== k); }

function switchTab(t) {
  tab = t; forceEnd = true;
  if (t in chanNew) { chanNew[t] = false; paintChanDots(); }
  $$('.chat-tabs button', panel).forEach(b => b.classList.toggle('on', b.dataset.tab === t));
  $('#chat-hint', panel).textContent = HINT[t];
  $('#chat-circles', panel).hidden = t !== 'circle';
  clearInterval(partyPoll);
  if (t === 'party') {
    if (!partyLoaded || partyNew || !partyLive) loadParty(); else draw();
    partyNew = false; paintPartyDot();
    partyPoll = setInterval(() => { if (!document.hidden && !partyLive) loadParty(); }, 20000);
  }
  else if (t === 'circle') { drawCircleChips(); showCircle(); }
  else if (msgs.length && live) draw();
  else load();
}

function syncCircles() {
  const list = circles();
  subscribeCircles();
  for (const c of list) if (circleUnread[c.circle_id] == null || c.unread > circleUnread[c.circle_id]) circleUnread[c.circle_id] = c.unread || 0;
  if (circleId && !list.some(c => c.circle_id === circleId)) circleId = null;
  if (!circleId && list[0]) circleId = list[0].circle_id;
  const had = tab;
  renderTabs();
  if (had === 'circle' && tab !== 'circle') switchTab(tab);
  else if (tab === 'circle') { drawCircleChips(); showCircle(); }
}
function drawCircleChips() {
  const box = $('#chat-circles', panel); if (!box) return;
  box.innerHTML = circles().map(c => `<button data-circle="${esc(c.circle_id)}" class="${c.circle_id === circleId ? 'on' : ''}" style="--cc:${esc(c.color)}" aria-pressed="${c.circle_id === circleId}">
    <span class="cc-dot"></span><span class="cc-name">${esc(c.name)}</span>${circleUnread[c.circle_id] > 0 && c.circle_id !== circleId ? `<i class="cc-count">${Math.min(99, circleUnread[c.circle_id])}</i>` : ''}</button>`).join('');
}
function paintCircleDots() {
  const any = Object.entries(circleUnread).some(([id, n]) => n > 0 && !(tab === 'circle' && id === circleId));
  $('.chat-tabs [data-tab="circle"]', panel)?.classList.toggle('has-dot', any);
}
function pickCircle(id) {
  forceEnd = true;
  circleId = id; try { sessionStorage.setItem('yh-chat-circle', id); } catch {}
  drawCircleChips(); showCircle();
}
const circleLoaded = new Set();
const byTime = a => a.sort((x, y) => (x.created_at < y.created_at ? -1 : x.created_at > y.created_at ? 1 : (x.id > y.id ? 1 : -1)));
function showCircle() {
  const id = circleId;
  if (!id || !circleLoaded.has(id) || !circleLive) return loadCircleMsgs();
  draw(); if ((circleUnread[id] || 0) > 0) markCircleRead(id);
}
async function loadCircleNew() {
  const id = circleId, arr = circleMsgs[id] || [];
  if (!id || !circleLoaded.has(id) || !arr.length) return loadCircleMsgs();
  try {
    const { data, error } = await db.from('world_circle_messages').select('id,circle_id,sender_id,sender_name,sender_title,sender_color,sender_mark,kind,content,created_at').eq('circle_id', id).gt('created_at', arr[arr.length - 1].created_at).order('created_at', { ascending: true }).limit(60);
    if (!error) (data || []).forEach(onCircleMsg);
  } catch {}
}
async function loadCircleMsgs() {
  const id = circleId; if (!id) return draw();
  try {
    const { data, error } = await db.from('world_circle_messages').select('id,circle_id,sender_id,sender_name,sender_title,sender_color,sender_mark,kind,content,created_at').eq('circle_id', id).order('created_at', { ascending: false }).limit(80);
    if (error) throw error;
    const got = (data || []).reverse(), seen = new Set(got.map(m => m.id));
    circleMsgs[id] = byTime(got.concat((circleMsgs[id] || []).filter(m => !seen.has(m.id)))).slice(-KEEP);
    circleLoaded.add(id); delete olderDone['c:' + id];
    if (tab === 'circle' && circleId === id) { draw(); if ((circleUnread[id] || 0) > 0) markCircleRead(id); }
  } catch (e) { if (tab === 'circle') drawError(friendlyError(e)); }
}
let readPending = null;
function markCircleRead(id) {
  circleUnread[id] = 0; drawCircleChips(); paintCircleDots();
  if (readPending && readPending !== id) flushCircleRead();
  readPending = id;
  if (!readTimer) readTimer = setTimeout(flushCircleRead, 20000);
}
function flushCircleRead() {
  clearTimeout(readTimer); readTimer = null;
  if (!readPending) return;
  if (document.hidden) { readTimer = setTimeout(flushCircleRead, 20000); return; }
  const id = readPending; readPending = null;
  rpc('world_circle_mark_read', { p_circle: id }).catch(() => {});
}
document.addEventListener('visibilitychange', () => { if (!document.hidden && readPending) flushCircleRead(); });
window.addEventListener('pagehide', () => { if (readPending) { const id = readPending; readPending = null; rpc('world_circle_mark_read', { p_circle: id }).catch(() => {}); } });
function onCircleMsg(m) {
  if (!m?.circle_id || blocked.has(m.sender_id)) return;
  const arr = circleMsgs[m.circle_id] || (circleMsgs[m.circle_id] = []);
  if (arr.some(x => x.id === m.id)) return;
  mentionAlarm(m, 'c');
  arr.push(m); if (arr.length > 1 && arr[arr.length - 2].created_at > m.created_at) byTime(arr);
  if (arr.length > KEEP) arr.shift();
  if (m.kind === 'notice') loadCircles(true);
  const viewing = tab === 'circle' && circleId === m.circle_id;
  if (viewing) { draw(); if (m.sender_id !== store.user?.id) markCircleRead(m.circle_id); }
  else if (m.kind === 'chat' && m.sender_id !== store.user?.id) { circleUnread[m.circle_id] = (circleUnread[m.circle_id] || 0) + 1; drawCircleChips(); paintCircleDots(); }
  const sheetClosed = !matchMedia('(min-width: 1280px)').matches && !document.body.classList.contains('chat-open');
  if (sheetClosed && m.kind === 'chat' && m.sender_id !== store.user?.id) { unread++; badge(); }
}
let partyNew = false, partyLive = false, partyLoaded = false, partySubId;
async function syncPartySub() {
  if (away) return;
  let pid = null;
  try { const p = await loadSnap('world_party_overview', undefined, { maxAge: 60000 }); pid = p?.party?.party_id || null; } catch { return; }
  if (pid === partySubId) return;
  partySubId = pid;
  subscribeParty();
}
const partySeen = new Set();
const partyOnce = m => { if (!m?.message_id || partySeen.has(m.message_id)) return; partySeen.add(m.message_id); if (partySeen.size > 300) partySeen.clear(); onPartyMsg(m); };
function subscribeParty() {
  bgroup('party', partySubId && !away ? [`party:${partySubId}`] : [], 'msg', p => partyOnce(p.new), l => { partyLive = l; if (!l) partyLoaded = false; });
}
function onPartyMsg(m) {
  if (!m || blocked.has(m.sender_id) || m.sender_id === store.user?.id) return;
  mentionAlarm(m, 'p');
  if (tab === 'party') loadParty();
  else { partyNew = true; paintPartyDot(); }
  const sheetClosed = !matchMedia('(min-width: 1280px)').matches && !document.body.classList.contains('chat-open');
  if (sheetClosed || tab !== 'party') window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'chime' }));
  if (sheetClosed) { unread++; badge(); }
}
function paintPartyDot() { $('.chat-tabs [data-tab="party"]', panel)?.classList.toggle('has-dot', partyNew && tab !== 'party'); }
const circleTopics = () => away ? [] : circles().map(c => `circle:${c.circle_id}`);
function subscribeCircles() {
  bgroup('circle', circleTopics(), 'msg', p => onCircleMsg(p.new), l => { circleLive = l; if (!l) circleLoaded.clear(); });
}

const COLS = 'id,channel_type,sender_id,sender_name,sender_title,sender_color,sender_mark,recipient_id,content,created_at';
async function load() {
  try {
    const { data, error } = await db.from('world_chat_messages').select(COLS).order('created_at', { ascending: false }).limit(80);
    if (error) throw error;
    msgs = (data || []).reverse(); lastFull = Date.now();
    for (const k of Object.keys(olderDone)) if (!k.startsWith('c:')) delete olderDone[k];
    draw();
  } catch (e) { drawError(friendlyError(e)); }
}
async function loadNew() {
  const last = msgs[msgs.length - 1]?.created_at;
  if (!last) return load();
  try {
    const { data, error } = await db.from('world_chat_messages').select(COLS).gt('created_at', last).order('created_at', { ascending: true }).limit(60);
    if (error) throw error;
    lastFull = Date.now();
    (data || []).forEach(addMsg);
  } catch {}
}
const KEEP = 600, PAGE = 50, olderDone = {};
let olderBusy = false, holdScroll = false;
async function loadOlder() {
  if (olderBusy) return;
  const circle = tab === 'circle', key = circle ? 'c:' + circleId : tab;
  if (circle ? !circleId || !circleLoaded.has(circleId) : !(tab in chanNew)) return;
  if (olderDone[key]) return;
  const have = circle ? (circleMsgs[circleId] || []) : msgs.filter(m => m.channel_type === tab);
  const first = have.reduce((a, m) => (!a || m.created_at < a ? m.created_at : a), null);
  olderBusy = true;
  try {
    let q = circle
      ? db.from('world_circle_messages').select('id,circle_id,sender_id,sender_name,sender_title,sender_color,sender_mark,kind,content,created_at').eq('circle_id', circleId)
      : db.from('world_chat_messages').select(COLS).eq('channel_type', tab);
    if (first) q = q.lt('created_at', first);
    const { data, error } = await q.order('created_at', { ascending: false }).limit(PAGE);
    if (error || key !== (tab === 'circle' ? 'c:' + circleId : tab)) return;
    if ((data || []).length < PAGE) olderDone[key] = true;
    const got = (data || []).reverse();
    if (circle) { const seen = new Set(have.map(m => m.id)); circleMsgs[circleId] = got.filter(m => !seen.has(m.id)).concat(have); }
    else { const seen = new Set(msgs.map(m => m.id)); msgs = got.filter(m => !seen.has(m.id)).concat(msgs); }
    const list = $('#chat-list', panel), h0 = list.scrollHeight, top0 = list.scrollTop;
    holdScroll = true; draw(); holdScroll = false;
    list.scrollTop = top0 + (list.scrollHeight - h0); list.dataset.h = String(list.scrollHeight);
  } catch {} finally { olderBusy = false; }
}
const topNote = key => olderDone[key] ? `<li class="chat-notice chat-top">여기까지가 남아 있는 말입니다(채팅은 2일 보관)</li>` : '';
async function loadBlocks() {
  try { const { data, error } = await db.from('world_blocks').select('blocked_id'); if (!error) blocked = new Set((data || []).map(r => r.blocked_id)); } catch {}
}
function mentionAlarm(m, kind = 'm') {
  const n = store.character?.character_name;
  if (!n || !m || m.sender_id === store.user?.id || blocked.has(m.sender_id)) return;
  if (!String(m.content || '').includes('@' + n)) return;
  if (m.created_at && Date.now() - new Date(m.created_at) > 120000) return;
  playAlarm('mention', kind + ':' + (m.id ?? m.message_id ?? m.created_at));
}
function addMsg(m) {
  if (!m || msgs.some(x => x.id === m.id)) return;
  msgs.push(m); if (msgs.length > KEEP) msgs.shift();
  if (m.channel_type === 'whisper') { if (!blocked.has(m.sender_id)) onWhisper(m); return; }
  mentionAlarm(m);
  if (m.channel_type === tab) draw();
  else if (m.channel_type in chanNew && m.sender_id !== store.user?.id && !blocked.has(m.sender_id) && !chanNew[m.channel_type]) { chanNew[m.channel_type] = true; paintChanDots(); }
  const sheetClosed = !matchMedia('(min-width: 1280px)').matches && !document.body.classList.contains('chat-open');
  if (sheetClosed && m.sender_id !== store.user?.id && !blocked.has(m.sender_id)) { unread++; badge(); }
}
async function loadParty() {
  try { const s = await rpc('world_party_chat_snapshot'); partyMsgs = s?.messages || []; store.partyId = s?.party_id || null; partyLoaded = true; draw(); }
  catch (e) { drawError(friendlyError(e)); }
}

const faces = new Map(); let faceAsk = null; const faceWait = new Set();
function wantFace(id) {
  if (!id || faces.has(id) || faceWait.has(id)) return;
  faceWait.add(id);
  clearTimeout(faceAsk); faceAsk = setTimeout(async () => {
    const ids = [...faceWait].slice(0, 60); ids.forEach(x => faceWait.delete(x));
    try { const r = await rpc('world_chat_faces', { p_ids: ids }); ids.forEach(x => faces.set(x, r?.[x] || {})); draw(); }
    catch { ids.forEach(x => faces.set(x, null)); setTimeout(() => { ids.forEach(x => { if (faces.get(x) === null) faces.delete(x); }); draw(); }, 30000); }
  }, 120);
}
function draw() {
  const list = $('#chat-list', panel); if (!list) return;
  const me = store.user?.id;
  let rows;
  list.style.removeProperty('--cc'); list.classList.toggle('circle-feed', tab === 'circle');
  if (tab === 'circle') {
    const c = circles().find(x => x.circle_id === circleId);
    if (!c) { list.innerHTML = `<li class="chat-empty">모임을 골라 주세요.</li>`; return; }
    list.style.setProperty('--cc', c.color);
    const ms = (circleMsgs[c.circle_id] || []).filter(m => !blocked.has(m.sender_id));
    list.innerHTML = ms.length ? topNote('c:' + c.circle_id) + ms.map((m, i) => m.kind === 'notice' ? `<li class="chat-notice">${esc(m.content)}<time>${fmt.time(m.created_at)}</time></li>`
      : msgRow({ sid: m.sender_id, gm: isGM(m.sender_id), who: m.sender_name, title: m.sender_title, color: m.sender_color, mark: m.sender_mark, text: m.content, at: m.created_at, mine: m.sender_id === me }, ms[i - 1]?.kind === 'notice' ? null : ms[i - 1] && { sid: ms[i - 1].sender_id, at: ms[i - 1].created_at })).join('')
      : `<li class="chat-empty">「${esc(c.name)}」에 아직 말이 없습니다.</li>`;
    scrollEnd(); return;
  }
  if (tab === 'party') {
    if (!store.partyId) { list.innerHTML = `<li class="chat-empty">파티에 가입하면 파티 채팅을 쓸 수 있습니다.</li>`; return; }
    rows = partyMsgs.filter(m => !blocked.has(m.sender_id)).map(m => ({ sid: m.sender_id, gm: isGM(m.sender_id), who: m.sender_name || m.character_name, color: m.sender_color, text: m.content, at: m.created_at, mine: m.sender_id === me }));
  } else {
    rows = msgs.filter(m => m.channel_type === tab && !blocked.has(m.sender_id)).map(m => ({ sys: (m.sender_name === '구조 알림' && /쓰러졌습니다|일어났습니다/.test(m.content || '')) || (m.sender_name === '세력 소식' && /차지했습니다/.test(m.content || '')) || m.sender_name === '봉연 소식', up: m.sender_name === '구조 알림' && /일어났습니다/.test(m.content || ''), seal: m.sender_name === '봉연 소식', sid: m.sender_id, gm: isGM(m.sender_id), who: m.sender_name, title: m.sender_title, color: m.sender_color, mark: m.sender_mark, text: m.content, at: m.created_at, mine: m.sender_id === me, to: m.channel_type === 'whisper' && m.sender_id === me }));
  }
  list.innerHTML = rows.length ? (tab in chanNew ? topNote(tab) : '') + rows.map((r, i) => msgRow(r, rows[i - 1])).join('')
    : `<li class="chat-empty">아직 메시지가 없습니다.</li>`;
  scrollEnd();
}
export const NAME_STYLES = {
  1001: ['자개빛', '명품 이상 칭호를 하나 얻으면'], 1002: ['주홍 칠', '신품 칭호를 하나 얻으면'], 1003: ['금박', '칭호를 30개 얻으면'],
  1004: ['청자빛', '칭호를 15개 얻으면'], 1005: ['물비늘', '낚시 칭호를 3개 얻으면'], 1006: ['월백', '이야기 칭호를 5개 얻으면'],
  1007: ['묵영', '비밀 칭호를 5개 얻으면'], 1008: ['단풍', '탐사 칭호를 5개 얻으면'], 1009: ['송화', '채집 칭호를 3개 얻으면'],
  1010: ['무쇠', '제작 칭호를 3개 얻으면'], 1011: ['혈홍', '전투 칭호를 6개 얻으면'], 1012: ['무혼', '비무 칭호를 3개 얻으면'],
  1013: ['도화', '교류 칭호를 2개 얻으면'], 1014: ['바람결', '이동 칭호를 4개 얻으면'], 1015: ['성운', '성장 칭호를 4개 얻으면'],
  1016: ['야행묵금', '「야행의 흔적」을 받은 이만'],
  1021: ['정청 남빛', '정통파 비고에서 받으면'], 1022: ['월식 핏빛', '적월교 비고에서 받으면'], 1023: ['흑련 먹자주', '흑련회 비고에서 받으면'],
  1024: ['설한 은청', '북령맹 비고에서 받으면'], 1025: ['물길 청록', '수향연맹 비고에서 받으면'], 1026: ['잔불 주황', '남명회 비고에서 받으면'], 1027: ['성좌 금청', '천명원 비고에서 받으면'], 1028: ['귀허청', '귀허의 주인을 처음 쓰러뜨리면'], 1029: ['장원 금빛', '1:1 비무회에서 우승하면'], 1030: ['쌍룡 청홍', '비무회 팀전에서 우승하면'],
};
export const nameStyle = (v, id) => NAME_STYLES[v] ? { cls: ` ns-${v}`, hu: hue(id) } : { cls: '', hu: Number.isInteger(v) ? v : hue(id) };
export function hue(id) { let x = 0; for (const c of String(id || '')) x = (x * 31 + c.charCodeAt(0)) % 360; return x; }
export function richText(t) {
  return esc(t).replace(/#패치노트(?::([0-9][0-9.-]{2,11}))?/g, (_, id) => `<a class="patch-link" href="#/patch${id ? `/${id}` : ''}">${icon('scroll', 12)}패치노트${id ? ` ${id}` : ''}</a>`);
}
const YOHWA_MARK = '<em class="yohwa-mark" title="요괴화 — 요괴의 힘이 몸을 차지한 채 한 시간을 버티는 중입니다">요괴화</em>';
function msgRow(r, prev) {
  if (r.sys) return `<li class="chat-notice sys${r.up ? ' up' : ''}${r.seal ? ' raidnote' : ''}">${icon(r.up ? 'check' : r.seal ? 'flame' : 'heart', 12)}<span>${richText(r.text)}</span><time>${r.at ? fmt.time(r.at) : ''}</time></li>`;
  const cont = prev && !prev.sys && prev.sid === r.sid && r.at && prev.at && new Date(r.at) - new Date(prev.at) < 300000;
  const cls = ['msg', r.mine ? 'mine' : '', r.gm ? 'gm' : '', cont ? 'cont' : ''].filter(Boolean).join(' ');
  if (cont) return `<li class="${cls}"><p>${richText(r.text)}</p></li>`;
  const fc = faces.get(r.sid);
  if (!faces.has(r.sid)) wantFace(r.sid);
  const av = face(r.sid, fc, 28, r.who);
  const ns = nameStyle(r.color, r.sid);
  return `<li class="${cls}${ns.cls}" style="--hu:${ns.hu}">${av}<div class="meta">${r.gm ? `<b><button type="button" class="name-link" data-card="${esc(r.sid)}" title="운영진(GM)"><span class="gm-badge">GM</span></button></b>` : `<b>${cardName(r.sid, r.who)}</b>`}${r.mark === 'frenzy' ? YOHWA_MARK : ''}${r.title ? `<em class="c-title">${esc(r.title)}</em>` : ''}<time>${r.at ? fmt.time(r.at) : ''}</time></div><p>${richText(r.text)}</p></li>`;
}
function drawError(msg) { const list = $('#chat-list', panel); if (list) list.innerHTML = `<li class="chat-empty">${esc(msg)}</li>`; }
function scrollEnd() {
  const list = $('#chat-list', panel); if (!list) return;
  const grew = list.scrollHeight > (Number(list.dataset.h) || 0); list.dataset.h = String(list.scrollHeight);
  if (holdScroll) return;
  if (forceEnd || stick) { list.scrollTop = list.scrollHeight; stick = true; forceEnd = false; $('#chat-jump', panel).hidden = true; }
  else if (grew) $('#chat-jump', panel).hidden = false;
}

const H_KEY = 'yh-chat-h';
function sheetBounds() {
  const vv = window.visualViewport, vh = vv?.height || innerHeight, vvBottom = vv ? vv.offsetTop + vv.height : innerHeight;
  const gap = Math.max(0, vvBottom - col.getBoundingClientRect().bottom);
  return [Math.round(vh * 0.35), Math.round(vh - gap - 56)];
}
function applyHeight(px) {
  let h = px; if (h == null) { try { h = Number(localStorage.getItem(H_KEY)) || 0; } catch { h = 0; } }
  if (!h) { col.style.removeProperty('--chat-h'); return; }
  const [lo, hi] = sheetBounds(); col.style.setProperty('--chat-h', `${Math.max(lo, Math.min(hi, h))}px`);
}
function bindGrip() {
  const grip = $('.chat-grip', panel); let y0 = 0, h0 = 0, moved = false;
  const move = e => { const h = h0 + (y0 - e.clientY); moved = true; applyHeight(h); };
  const up = () => {
    grip.releasePointerCapture?.(grip._pid); grip.removeEventListener('pointermove', move); grip.classList.remove('drag');
    if (moved) { const h = col.getBoundingClientRect().height; try { localStorage.setItem(H_KEY, String(Math.round(h))); } catch {} if (stick) { forceEnd = true; scrollEnd(); } }
  };
  grip.addEventListener('pointerdown', e => {
    if (!document.body.classList.contains('chat-open')) return;
    e.preventDefault(); y0 = e.clientY; h0 = col.getBoundingClientRect().height; moved = false; grip._pid = e.pointerId;
    grip.setPointerCapture?.(e.pointerId); grip.classList.add('drag');
    grip.addEventListener('pointermove', move); grip.addEventListener('pointerup', up, { once: true }); grip.addEventListener('pointercancel', up, { once: true });
  });
  grip.addEventListener('dblclick', () => { const [, hi] = sheetBounds(); const big = col.getBoundingClientRect().height >= hi - 4; try { big ? localStorage.removeItem(H_KEY) : localStorage.setItem(H_KEY, String(hi)); } catch {} applyHeight(big ? 0 : hi); });
  grip.addEventListener('keydown', e => { if (e.key !== 'ArrowUp' && e.key !== 'ArrowDown') return; e.preventDefault(); const h = col.getBoundingClientRect().height + (e.key === 'ArrowUp' ? 40 : -40); applyHeight(h); try { localStorage.setItem(H_KEY, String(Math.round(h))); } catch {} });
  window.visualViewport?.addEventListener('resize', () => { if (document.body.classList.contains('chat-open')) { fitSheetToKeyboard(); applyHeight(); } });
  window.visualViewport?.addEventListener('scroll', () => { if (document.body.classList.contains('chat-open')) fitSheetToKeyboard(); });
  $('#chat-form textarea', panel)?.addEventListener('focus', () => {
    const go = () => { forceEnd = true; scrollEnd(); };
    go(); setTimeout(go, 120); setTimeout(go, 400);
  });
  $('#chat-form textarea', panel)?.addEventListener('blur', () => { const go = () => { fitSheetToKeyboard(); applyHeight(); }; setTimeout(go, 80); setTimeout(go, 350); });
}

async function send(e) {
  e.preventDefault();
  const form = e.target, text = form.text.value.trim();
  if (!text) return;
  const btn = form.querySelector('button[type=submit]'); if (btn.disabled) return;
  btn.disabled = true; forceEnd = true;
  try {
    if (tab === 'party') { await act('world_party_chat_send', { p_content: text }); await loadParty(); }
    else if (tab === 'circle') { if (!circleId) throw new Error('모임을 골라 주세요.'); await rpc('world_circle_send', { p_circle: circleId, p_content: text }); await loadCircleNew(); }
    else {
      await rpc('world_chat_send', { p_channel: tab, p_content: text, p_recipient_name: null });
      await (live && msgs.length ? loadNew() : load());
    }
    form.text.value = ''; try { sessionStorage.removeItem('yh-chat-draft'); } catch {} form._fit?.();
  } catch (err) { toast(friendlyError(err), 'error'); }
  finally { btn.disabled = false; }
}

let away = false, beat = 0, bc = null;
function popLink() {
  if (!('BroadcastChannel' in window)) return;
  bc = new BroadcastChannel('yh-pop');
  if (document.body.classList.contains('pop-win')) {
    const say = t => { try { bc.postMessage({ t, uid: store.user?.id }); } catch {} };
    say('chat-open'); setInterval(() => say('chat-open'), 20000);
    bc.onmessage = e => { if (e.data?.t === 'ping') say('chat-open'); if (e.data?.t === 'chat-close-req') window.close(); };
    window.addEventListener('pagehide', () => say('chat-closed'));
    $('.chat-home', panel)?.addEventListener('click', () => { say('chat-closed'); window.close(); setTimeout(() => { if (!window.closed) toast('게임 창의 채팅을 되돌렸습니다. 이 창은 직접 닫아 주세요.'); }, 300); });
    return;
  }
  bc.onmessage = e => {
    if (e.data?.uid && e.data.uid !== store.user?.id) return;
    if (e.data?.t === 'chat-open') { beat = Date.now(); if (!away) suspend(); }
    if (e.data?.t === 'chat-closed' && away) resume();
  };
  try { bc.postMessage({ t: 'ping' }); } catch {}
  setInterval(() => { if (away && Date.now() - beat > 60000) resume(); }, 15000);
}
function suspend() {
  away = true;
  live = circleLive = partyLive = false; partySubId = undefined;
  bclear('chat'); bclear('party'); bclear('circle');
  toggleSheet(false);
  document.body.classList.add('chat-out');
  panel.hidden = true;
  const top = $('.top-actions');
  if (top && !$('#btn-chat-back')) {
    const b = h(`<button class="icon-btn chat-back" id="btn-chat-back" aria-label="채팅을 이 창으로 되돌리기" title="채팅을 이 창으로 되돌리기">${icon('chat')}</button>`);
    b.onclick = () => { try { bc?.postMessage({ t: 'chat-close-req' }); } catch {} resume(); };
    top.prepend(b);
  }
  whisperFeed(!whisperOut());
}
function resume() {
  if (!away) return;
  away = false;
  whisperFeed(false);
  document.body.classList.remove('chat-out');
  $('#btn-chat-back')?.remove();
  panel.hidden = false;
  subscribe(); subscribeCircles(); syncPartySub(); refillAfterPop();
}
async function refillAfterPop() {
  await load();
  const got = await Promise.all(['global', 'region', 'faction'].map(t => db.from('world_chat_messages').select(COLS).eq('channel_type', t)
    .order('created_at', { ascending: false }).limit(PAGE).then(r => r.data || [], () => [])));
  const seen = new Set(msgs.map(m => m.id)), add = got.flat().filter(m => !seen.has(m.id));
  if (add.length) { msgs = byTime(msgs.concat(add)); forceEnd = true; draw(); }
  circleLoaded.clear(); partyLoaded = false;
  if (tab === 'circle') loadCircleMsgs(); else if (tab === 'party') loadParty();
}

function subscribe() {
  if (away) { bclear('chat'); return; }
  const c = store.character, me = store.user?.id;
  bgroup('chat', ['chat:global', c?.location && `chat:region:${c.location}`, c?.major_faction_id && `chat:faction:${c.major_faction_id}`, me && `whisper:${me}`], 'msg', p => addMsg(p.new),
    l => { const was = live; live = l; if (l && !was) loadNew(); });
}
