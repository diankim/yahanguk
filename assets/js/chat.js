// 인게임 채팅: 전체·지역·세력·파티·모임. PC는 우측 열, 모바일은 하단 시트. 귓속말은 따로 상대별 창(whisper.js)으로 연다.
// 모임 탭은 모임에 든 사람에게만 보이고, 탭 아래 단추로 볼 모임을 하나 골라 그 모임의 말만 보여 준다(모임마다 내가 정한 색으로).
import { cardName } from './views/card.js';
import { isGM, db, store, on, rpc, act, esc, fmt, icon, $, $$, h, toast, friendlyError, emblem } from './core.js';
import { onWhisper, openWhisperWindow } from './whisper.js';
import { loadCircles, circles } from './circles.js';
import { growInput } from './grow.js';

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
// 목록을 위로 올려 읽는 중이면(stick=false) 새 메시지·자동 갱신이 와도 맨 아래로 끌어내리지 않는다.
let stick = true, forceEnd = true;
// 모임: 고른 모임, 모임별 최근 말, 안 읽은 수
let circleId = null, circleMsgs = {}, circleUnread = {}, circleChannel = null, circleLive = false, readTimer = null;
try { circleId = sessionStorage.getItem('yh-chat-circle') || null; } catch {}

export function mountChat(colEl, fabEl) {
  col = colEl; fab = fabEl;
  panel = h(`<section class="chat" aria-label="채팅">
    <div class="chat-grip" role="separator" aria-orientation="horizontal" aria-label="채팅창 크기 조절 (위아래로 끌기)" tabindex="0"><i></i></div>
    <header class="chat-head"><h2>${icon('chat', 15)} 통신망</h2><button class="icon-btn chat-close" aria-label="채팅 닫기">${icon('close')}</button></header>
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
  panel.querySelector('.chat-tabs').onclick = e => { const b = e.target.closest('[data-tab]'); if (b) switchTab(b.dataset.tab); };
  $('#chat-circles', panel).onclick = e => { const b = e.target.closest('[data-circle]'); if (b) pickCircle(b.dataset.circle); };
  renderTabs();
  const list = $('#chat-list', panel);
  list.addEventListener('scroll', () => { stick = list.scrollHeight - list.scrollTop - list.clientHeight < 40; if (stick) $('#chat-jump', panel).hidden = true; }, { passive: true });
  $('#chat-jump', panel).onclick = () => { forceEnd = true; scrollEnd(); };
  bindGrip();
  window.addEventListener('yh-circles', () => { syncCircles(); });
  loadCircles().then(syncCircles);
  const form = $('#chat-form', panel);
  form._fit = growInput(form);
  form.text.addEventListener('keydown', e => { if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); form.requestSubmit(); } });
  form.onsubmit = send;
  // 쓰던 메시지는 새로고침하거나 시트를 닫았다 열어도 남는다(이 탭에만 저장).
  try { form.text.value = sessionStorage.getItem('yh-chat-draft') || ''; } catch {}
  form._fit?.();
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
  if (open) { unread = 0; badge(); forceEnd = true; applyHeight(); requestAnimationFrame(() => $('#chat-form', panel)?._fit?.()); loadNew(); if (matchMedia('(pointer: fine)').matches) setTimeout(() => $('#chat-form textarea', panel)?.focus({ preventScroll: true }), 50); scrollEnd(); }
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
  tab = t; forceEnd = true;
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
  forceEnd = true;
  circleId = id; try { sessionStorage.setItem('yh-chat-circle', id); } catch {}
  drawCircleChips(); loadCircleMsgs();
}
async function loadCircleMsgs() {
  const id = circleId; if (!id) return draw();
  try {
    const { data, error } = await db.from('world_circle_messages').select('id,circle_id,sender_id,sender_name,sender_title,sender_color,kind,content,created_at').eq('circle_id', id).order('created_at', { ascending: false }).limit(80);
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

const COLS = 'id,channel_type,sender_id,sender_name,sender_title,sender_color,recipient_id,content,created_at';
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

// 얼굴(프로필 사진·문장): 처음 보는 사람만 모아 한 번에 묻고 이 접속 동안 기억한다(world_chat_faces)
const faces = new Map(); let faceAsk = null; const faceWait = new Set();
function wantFace(id) {
  if (!id || faces.has(id) || faceWait.has(id)) return;
  faceWait.add(id);
  clearTimeout(faceAsk); faceAsk = setTimeout(async () => {
    const ids = [...faceWait].slice(0, 60); ids.forEach(x => faceWait.delete(x));
    try { const r = await rpc('world_chat_faces', { p_ids: ids }); ids.forEach(x => faces.set(x, r?.[x] || {})); draw(); }
    // 못 읽었으면 잠시 이름 첫 글자로 두고 30초 뒤 다시 묻는다(서버 함수가 아직 없거나 연결이 끊긴 때)
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
    list.innerHTML = ms.length ? ms.map((m, i) => m.kind === 'notice' ? `<li class="chat-notice">${esc(m.content)}<time>${fmt.time(m.created_at)}</time></li>`
      : msgRow({ sid: m.sender_id, gm: isGM(m.sender_id), who: m.sender_name, title: m.sender_title, color: m.sender_color, text: m.content, at: m.created_at, mine: m.sender_id === me }, ms[i - 1]?.kind === 'notice' ? null : ms[i - 1] && { sid: ms[i - 1].sender_id, at: ms[i - 1].created_at })).join('')
      : `<li class="chat-empty">「${esc(c.name)}」에 아직 말이 없습니다.</li>`;
    scrollEnd(); return;
  }
  if (tab === 'party') {
    if (!store.partyId) { list.innerHTML = `<li class="chat-empty">파티에 가입하면 파티 채팅을 쓸 수 있습니다.</li>`; return; }
    rows = partyMsgs.filter(m => !blocked.has(m.sender_id)).map(m => ({ sid: m.sender_id, gm: isGM(m.sender_id), who: m.sender_name || m.character_name, color: m.sender_color, text: m.content, at: m.created_at, mine: m.sender_id === me }));
  } else {
    rows = msgs.filter(m => m.channel_type === tab && !blocked.has(m.sender_id)).map(m => ({ sid: m.sender_id, gm: isGM(m.sender_id), who: m.sender_name, title: m.sender_title, color: m.sender_color, text: m.content, at: m.created_at, mine: m.sender_id === me, to: m.channel_type === 'whisper' && m.sender_id === me }));
  }
  list.innerHTML = rows.length ? rows.map((r, i) => msgRow(r, rows[i - 1])).join('')
    : `<li class="chat-empty">아직 메시지가 없습니다.</li>`;
  scrollEnd();
}
// 이름 색: 조사원이 고른 색(sender_color, 색상환 각도)이 있으면 그것, 없으면 이름에 따라 정해지는 색
// 한 줄: 이름 첫 글자 인장 + 이름·칭호·시각, 같은 사람이 5분 안에 이어 말하면 머리글 없이 붙인다.
export function hue(id) { let x = 0; for (const c of String(id || '')) x = (x * 31 + c.charCodeAt(0)) % 360; return x; }
function msgRow(r, prev) {
  const cont = prev && prev.sid === r.sid && r.at && prev.at && new Date(r.at) - new Date(prev.at) < 300000;
  const cls = ['msg', r.mine ? 'mine' : '', r.gm ? 'gm' : '', cont ? 'cont' : ''].filter(Boolean).join(' ');
  if (cont) return `<li class="${cls}"><p>${esc(r.text)}</p></li>`;
  const initial = esc([...String(r.who || '?')][0] || '?'), face = faces.get(r.sid);
  if (!faces.has(r.sid)) wantFace(r.sid);
  const av = face ? `<i class="av face" aria-hidden="true">${emblem(r.sid, face, 26)}</i>` : `<i class="av" aria-hidden="true">${initial}</i>`;
  return `<li class="${cls}" style="--hu:${Number.isInteger(r.color) ? r.color : hue(r.sid)}">${av}<div class="meta"><b>${cardName(r.sid, r.who)}</b>${r.gm ? '<span class="gm-badge" title="운영진(GM)">GM</span>' : ''}${r.title ? `<em class="c-title">${esc(r.title)}</em>` : ''}<time>${r.at ? fmt.time(r.at) : ''}</time></div><p>${esc(r.text)}</p></li>`;
}
function drawError(msg) { const list = $('#chat-list', panel); if (list) list.innerHTML = `<li class="chat-empty">${esc(msg)}</li>`; }
function scrollEnd() {
  const list = $('#chat-list', panel); if (!list) return;
  const grew = list.scrollHeight > (Number(list.dataset.h) || 0); list.dataset.h = String(list.scrollHeight);
  if (forceEnd || stick) { list.scrollTop = list.scrollHeight; stick = true; forceEnd = false; $('#chat-jump', panel).hidden = true; }
  else if (grew) $('#chat-jump', panel).hidden = false; // 위를 읽는 중: 자리는 그대로 두고 새 메시지가 왔음만 알린다
}

/* ── 시트 높이(좁은 화면): 위쪽 손잡이를 위아래로 끌어 넓히거나 줄인다. 높이는 이 기기에 남긴다. ── */
const H_KEY = 'yh-chat-h';
function sheetBounds() { const vh = window.visualViewport?.height || innerHeight, gap = Math.max(0, innerHeight - col.getBoundingClientRect().bottom); return [Math.round(vh * 0.35), Math.round(vh - gap - 56)]; }
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
  // 손잡이를 두 번 누르면 가장 넓게 ↔ 처음 크기
  grip.addEventListener('dblclick', () => { const [, hi] = sheetBounds(); const big = col.getBoundingClientRect().height >= hi - 4; try { big ? localStorage.removeItem(H_KEY) : localStorage.setItem(H_KEY, String(hi)); } catch {} applyHeight(big ? 0 : hi); });
  grip.addEventListener('keydown', e => { if (e.key !== 'ArrowUp' && e.key !== 'ArrowDown') return; e.preventDefault(); const h = col.getBoundingClientRect().height + (e.key === 'ArrowUp' ? 40 : -40); applyHeight(h); try { localStorage.setItem(H_KEY, String(Math.round(h))); } catch {} });
  window.visualViewport?.addEventListener('resize', () => { if (document.body.classList.contains('chat-open')) applyHeight(); });
}

async function send(e) {
  e.preventDefault();
  const form = e.target, text = form.text.value.trim();
  if (!text) return;
  const btn = form.querySelector('button[type=submit]'); if (btn.disabled) return;
  btn.disabled = true; forceEnd = true;
  try {
    if (tab === 'party') { await act('world_party_chat_send', { p_content: text }); await loadParty(); }
    else if (tab === 'circle') { if (!circleId) throw new Error('모임을 골라 주세요.'); await rpc('world_circle_send', { p_circle: circleId, p_content: text }); await loadCircleMsgs(); }
    else {
      await rpc('world_chat_send', { p_channel: tab, p_content: text, p_recipient_name: null });
      await load();
    }
    form.text.value = ''; try { sessionStorage.removeItem('yh-chat-draft'); } catch {} form._fit?.();
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
