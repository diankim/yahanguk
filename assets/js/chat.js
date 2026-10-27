// 인게임 채팅: 전체·지역·세력·파티·모임. PC는 우측 열, 모바일은 하단 시트. 귓속말은 따로 상대별 창(whisper.js)으로 연다.
// 모임 탭은 모임에 든 사람에게만 보이고, 탭 아래 단추로 볼 모임을 하나 골라 그 모임의 말만 보여 준다(모임마다 내가 정한 색으로).
import { cardName } from './views/card.js';
import { isGM, db, store, on, rpc, act, esc, fmt, icon, $, $$, h, toast, friendlyError } from './core.js';
import { onWhisper, openWhisperWindow } from './whisper.js';
import { loadCircles, circles } from './circles.js';

const BASE_TABS = [['global', '전체'], ['region', '지역'], ['faction', '세력'], ['party', '파티']];
const tabsNow = () => circles().length ? [...BASE_TABS, ['circle', '모임']] : BASE_TABS;
const HINT = {
  global: '모든 조사원에게 보입니다 · 하루 20회',
  region: '같은 지역에 있는 조사원에게만 보입니다',
  faction: '같은 대세력 소속에게만 보입니다',
  party: '파티원에게만 보입니다',
  circle: '고른 모임의 모임원에게만 보입니다 · 색은 동료 › 모임 › 관리에서 바꿉니다',
};
let panel, col, fab, tab = 'global', msgs = [], partyMsgs = [], channel, partyPoll, unread = 0;
// live: 실시간 연결이 살아 있는지. 끊겨 있으면 새 메시지만 짧게 다시 읽어 온다(다른 지역의 전체 채팅도 놓치지 않게).
let live = false, lastFull = 0, blocked = new Set();
// 모임: 고른 모임, 모임별 최근 말, 안 읽은 수
let circleId = null, circleMsgs = {}, circleUnread = {}, circleChannel = null, circleLive = false, readTimer = null;
try { circleId = sessionStorage.getItem('yh-chat-circle') || null; } catch {}

export function mountChat(colEl, fabEl) {
  col = colEl; fab = fabEl;
  panel = h(`<section class="chat" aria-label="채팅">
    <header class="chat-head"><h2>${icon('chat', 16)} 통신망</h2><button class="icon-btn chat-close" aria-label="채팅 닫기">${icon('close')}</button></header>
    <div class="segmented chat-tabs"></div>
    <div class="chat-circles" id="chat-circles" hidden></div>
    <p class="chat-hint" id="chat-hint"></p>
    <ol class="chat-list" id="chat-list" aria-live="polite"></ol>
    <form class="chat-form" id="chat-form">
      <div class="chat-row"><textarea name="text" rows="1" maxlength="500" placeholder="메시지 입력" aria-label="메시지"></textarea>
      <button class="btn primary" type="submit" aria-label="전송">${icon('chevron', 18)}</button></div>
    </form>
  </section>`);
  placePanel();
  matchMedia('(min-width: 1280px)').addEventListener('change', placePanel);
  fab.onclick = () => toggleSheet(true);
  $('.chat-close', panel).onclick = () => toggleSheet(false);
  panel.querySelector('.chat-tabs').onclick = e => { const b = e.target.closest('[data-tab]'); if (b) switchTab(b.dataset.tab); };
  $('#chat-circles', panel).onclick = e => { const b = e.target.closest('[data-circle]'); if (b) pickCircle(b.dataset.circle); };
  renderTabs();
  window.addEventListener('yh-circles', () => { syncCircles(); });
  loadCircles().then(syncCircles);
  const form = $('#chat-form', panel);
  form.text.addEventListener('keydown', e => { if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); form.requestSubmit(); } });
  form.onsubmit = send;
  // 쓰던 메시지는 새로고침하거나 시트를 닫았다 열어도 남는다(이 탭에만 저장).
  try { form.text.value = sessionStorage.getItem('yh-chat-draft') || ''; } catch {}
  form.text.addEventListener('input', () => { try { sessionStorage.setItem('yh-chat-draft', form.text.value); } catch {} });
  switchTab(tab);
  subscribe();
  loadBlocks();
  on('changed', ({ name }) => { if (/travel|join_major_faction/.test(name)) load(); if (/block|friend/.test(name)) loadBlocks().then(draw); });
  subscribeCircles();
  window.addEventListener('yahang:arrived', load);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) loadNew(); });
  setInterval(() => {
    if (document.hidden || tab === 'party') return;
    if (tab === 'circle') { if (!circleLive) loadCircleMsgs(); return; }
    // 실시간이 끊겼으면 10초마다, 살아 있어도 1분마다 한 번은 빠진 메시지를 채운다
    if (!live || Date.now() - lastFull > 60000) loadNew();
  }, 10000);
}

// 조사원 카드·친구 목록의 [귓속말]: 그 상대와의 귓속말 창을 연다
export function openWhisper(name, id) { openWhisperWindow({ name, id }); }

function placePanel() {
  const wide = matchMedia('(min-width: 1280px)').matches;
  if (wide) { col.append(panel); document.body.classList.remove('chat-open'); }
  else if (!document.body.classList.contains('chat-open')) col.append(panel);
}
function toggleSheet(open) {
  document.body.classList.toggle('chat-open', open);
  // 모바일에서는 시트를 열 때 키패드를 띄우지 않는다(입력칸을 눌렀을 때만). 마우스를 쓰는 화면에서만 바로 입력칸으로 간다.
  if (open) { unread = 0; badge(); loadNew(); if (matchMedia('(pointer: fine)').matches) setTimeout(() => $('#chat-form textarea', panel)?.focus({ preventScroll: true }), 50); scrollEnd(); }
}
function badge() { fab.dataset.count = unread ? String(Math.min(unread, 99)) : ''; }
function renderTabs() {
  const t = tabsNow(), box = $('.chat-tabs', panel);
  if (!t.some(x => x[0] === tab)) tab = 'global';
  box.style.setProperty('--n', t.length);
  box.innerHTML = t.map(([k, l]) => `<button data-tab="${k}" class="${k === tab ? 'on' : ''}">${l}</button>`).join('');
  paintCircleDots();
}

function switchTab(t) {
  tab = t;
  $$('.chat-tabs button', panel).forEach(b => b.classList.toggle('on', b.dataset.tab === t));
  $('#chat-hint', panel).textContent = HINT[t];
  $('#chat-circles', panel).hidden = t !== 'circle';
  clearInterval(partyPoll);
  if (t === 'party') { loadParty(); partyPoll = setInterval(() => { if (!document.hidden) loadParty(); }, 20000); }
  else if (t === 'circle') { drawCircleChips(); loadCircleMsgs(); }
  else load();
}

/* ── 모임 ───────────────────────────────────────────── */
function syncCircles() {
  const list = circles();
  for (const c of list) if (circleUnread[c.circle_id] == null || c.unread > circleUnread[c.circle_id]) circleUnread[c.circle_id] = c.unread || 0;
  if (circleId && !list.some(c => c.circle_id === circleId)) circleId = null;
  if (!circleId && list[0]) circleId = list[0].circle_id;
  const had = tab;
  renderTabs();
  if (had === 'circle' && tab !== 'circle') switchTab(tab);
  else if (tab === 'circle') { drawCircleChips(); draw(); }
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
  circleId = id; try { sessionStorage.setItem('yh-chat-circle', id); } catch {}
  drawCircleChips(); loadCircleMsgs();
}
async function loadCircleMsgs() {
  const id = circleId; if (!id) return draw();
  try {
    const { data, error } = await db.from('world_circle_messages').select('id,circle_id,sender_id,sender_name,sender_title,kind,content,created_at').eq('circle_id', id).order('created_at', { ascending: false }).limit(80);
    if (error) throw error;
    circleMsgs[id] = (data || []).reverse();
    if (tab === 'circle' && circleId === id) { draw(); markCircleRead(id); }
  } catch (e) { if (tab === 'circle') drawError(friendlyError(e)); }
}
function markCircleRead(id) {
  circleUnread[id] = 0; drawCircleChips(); paintCircleDots();
  clearTimeout(readTimer); readTimer = setTimeout(() => rpc('world_circle_mark_read', { p_circle: id }).catch(() => {}), 800);
}
function onCircleMsg(m) {
  if (!m?.circle_id || blocked.has(m.sender_id)) return;
  const arr = circleMsgs[m.circle_id] || (circleMsgs[m.circle_id] = []);
  if (arr.some(x => x.id === m.id)) return;
  arr.push(m); if (arr.length > 120) arr.shift();
  // 모임 이름·인원이 바뀌는 안내 줄이면 목록도 새로 읽는다
  if (m.kind === 'notice') loadCircles(true);
  const viewing = tab === 'circle' && circleId === m.circle_id;
  if (viewing) { draw(); if (m.sender_id !== store.user?.id) markCircleRead(m.circle_id); }
  else if (m.kind === 'chat' && m.sender_id !== store.user?.id) { circleUnread[m.circle_id] = (circleUnread[m.circle_id] || 0) + 1; drawCircleChips(); paintCircleDots(); }
  const sheetClosed = !matchMedia('(min-width: 1280px)').matches && !document.body.classList.contains('chat-open');
  if (sheetClosed && m.kind === 'chat' && m.sender_id !== store.user?.id) { unread++; badge(); }
}
function subscribeCircles() {
  try {
    if (circleChannel) db.removeChannel(circleChannel);
    const ch = db.channel('yh-circle-chat').on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'world_circle_messages' }, p => onCircleMsg(p.new));
    circleChannel = ch;
    ch.subscribe(status => {
      if (circleChannel !== ch) return;
      circleLive = status === 'SUBSCRIBED';
      if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT' || status === 'CLOSED') setTimeout(() => { if (circleChannel === ch && !circleLive) subscribeCircles(); }, 15000);
    });
  } catch { circleLive = false; }
}

const COLS = 'id,channel_type,sender_id,sender_name,sender_title,recipient_id,content,created_at';
async function load() {
  try {
    const { data, error } = await db.from('world_chat_messages').select(COLS).order('created_at', { ascending: false }).limit(80);
    if (error) throw error;
    msgs = (data || []).reverse(); lastFull = Date.now();
    draw();
  } catch (e) { drawError(friendlyError(e)); }
}
// 마지막으로 받은 메시지 뒤의 것만 가져와 붙인다
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
async function loadBlocks() {
  try { const { data, error } = await db.from('world_blocks').select('blocked_id'); if (!error) blocked = new Set((data || []).map(r => r.blocked_id)); } catch {}
}
function addMsg(m) {
  if (!m || msgs.some(x => x.id === m.id)) return;
  msgs.push(m); if (msgs.length > 120) msgs.shift();
  // 귓속말은 채팅 목록에 섞지 않고 귓속말 창으로 넘긴다
  if (m.channel_type === 'whisper') { if (!blocked.has(m.sender_id)) onWhisper(m); return; }
  if (m.channel_type === tab) draw();
  const sheetClosed = !matchMedia('(min-width: 1280px)').matches && !document.body.classList.contains('chat-open');
  if (sheetClosed && m.sender_id !== store.user?.id && !blocked.has(m.sender_id)) { unread++; badge(); }
}
async function loadParty() {
  try { const s = await rpc('world_party_chat_snapshot'); partyMsgs = s?.messages || []; store.partyId = s?.party_id || null; draw(); }
  catch (e) { drawError(friendlyError(e)); }
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
    list.innerHTML = ms.length ? ms.map(m => m.kind === 'notice' ? `<li class="chat-notice">${esc(m.content)}<time>${fmt.time(m.created_at)}</time></li>`
      : `<li class="${m.sender_id === me ? 'mine' : ''} ${isGM(m.sender_id) ? 'gm' : ''}"><div class="meta">${m.sender_title ? `<em class="c-title">「${esc(m.sender_title)}」</em>` : ''}<b>${cardName(m.sender_id, m.sender_name)}</b>${isGM(m.sender_id) ? '<span class="gm-badge" title="운영진(GM)">GM</span>' : ''}<time>${fmt.time(m.created_at)}</time></div><p>${esc(m.content)}</p></li>`).join('')
      : `<li class="chat-empty">「${esc(c.name)}」에 아직 말이 없습니다.</li>`;
    scrollEnd(); return;
  }
  if (tab === 'party') {
    if (!store.partyId) { list.innerHTML = `<li class="chat-empty">파티에 가입하면 파티 채팅을 쓸 수 있습니다.</li>`; return; }
    rows = partyMsgs.filter(m => !blocked.has(m.sender_id)).map(m => ({ sid: m.sender_id, gm: isGM(m.sender_id), who: m.sender_name || m.character_name, text: m.content, at: m.created_at, mine: m.sender_id === me }));
  } else {
    rows = msgs.filter(m => m.channel_type === tab && !blocked.has(m.sender_id)).map(m => ({ sid: m.sender_id, gm: isGM(m.sender_id), who: m.sender_name, title: m.sender_title, text: m.content, at: m.created_at, mine: m.sender_id === me, to: m.channel_type === 'whisper' && m.sender_id === me }));
  }
  list.innerHTML = rows.length ? rows.map(r => `<li class="${r.mine ? 'mine' : ''} ${r.gm ? 'gm' : ''}"><div class="meta">${r.title ? `<em class="c-title">「${esc(r.title)}」</em>` : ''}<b>${cardName(r.sid, r.who)}</b>${r.gm ? '<span class="gm-badge" title="운영진(GM)">GM</span>' : ''}<time>${r.at ? fmt.time(r.at) : ''}</time></div><p>${esc(r.text)}</p></li>`).join('')
    : `<li class="chat-empty">아직 메시지가 없습니다.</li>`;
  scrollEnd();
}
function drawError(msg) { const list = $('#chat-list', panel); if (list) list.innerHTML = `<li class="chat-empty">${esc(msg)}</li>`; }
function scrollEnd() { const list = $('#chat-list', panel); if (list) list.scrollTop = list.scrollHeight; }

async function send(e) {
  e.preventDefault();
  const form = e.target, text = form.text.value.trim();
  if (!text) return;
  const btn = form.querySelector('button[type=submit]'); if (btn.disabled) return;
  btn.disabled = true;
  try {
    if (tab === 'party') { await act('world_party_chat_send', { p_content: text }); await loadParty(); }
    else if (tab === 'circle') { if (!circleId) throw new Error('모임을 골라 주세요.'); await rpc('world_circle_send', { p_circle: circleId, p_content: text }); await loadCircleMsgs(); }
    else {
      await rpc('world_chat_send', { p_channel: tab, p_content: text, p_recipient_name: null });
      await load();
    }
    form.text.value = ''; try { sessionStorage.removeItem('yh-chat-draft'); } catch {}
  } catch (err) { toast(friendlyError(err), 'error'); }
  finally { btn.disabled = false; }
}

function subscribe() {
  try {
    if (channel) db.removeChannel(channel);
    const ch = db.channel('yh-chat').on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'world_chat_messages' }, p => addMsg(p.new));
    channel = ch;
    ch.subscribe(status => {
      if (channel !== ch) return;
      live = status === 'SUBSCRIBED';
      if (live) loadNew();
      // 연결이 끊기면 잠시 뒤 다시 잇는다(그동안은 짧은 주기로 새 메시지를 읽는다)
      if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT' || status === 'CLOSED') setTimeout(() => { if (channel === ch && !live) subscribe(); }, 15000);
    });
  } catch (e) { live = false; console.warn('실시간 채팅 연결 실패', e); }
}
