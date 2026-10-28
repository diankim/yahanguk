// 귓속말 창: 채팅과 따로, 상대별로 나눈 대화. 헤더 단추로 열고, 안 읽은 귓속말이 있으면 단추에 빨간 점을 찍는다.
// 대화 목록·안 읽은 수는 서버(world_whisper_threads), 읽음 표시는 world_whisper_mark_read로 어느 기기에서든 같다.
// 메시지는 world_chat_messages(channel_type = 'whisper')를 그대로 쓰고, 새 귓속말은 채팅의 실시간 연결(chat.js)이 넘겨준다.
import { db, store, rpc, esc, fmt, icon, $, $$, toast, friendlyError, openModal, isGM } from './core.js';
import { cardName } from './views/card.js';
import { growInput } from './grow.js';

const COLS = 'id,channel_type,sender_id,sender_name,sender_title,recipient_id,content,created_at';
let btn = null, threads = [], unreadTotal = 0, box = null, cur = null, msgs = [], refreshTimer = null;
const wide = () => matchMedia('(min-width: 760px)').matches;
const draftKey = t => `yh-wh-draft:${t?.id || t?.name || ''}`;

export function mountWhisper(button) {
  btn = button;
  btn.onclick = () => openWhisperWindow();
  refresh();
  document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });
}

export async function refresh() {
  try {
    const r = await rpc('world_whisper_threads');
    threads = r?.threads || []; unreadTotal = Number(r?.unread_total || 0);
  } catch { return; }
  paintDot();
  if (box?.isConnected) drawList();
}
const refreshSoon = () => { clearTimeout(refreshTimer); refreshTimer = setTimeout(refresh, 400); };

function paintDot() {
  if (!btn) return;
  btn.classList.toggle('has-dot', unreadTotal > 0);
  btn.setAttribute('aria-label', unreadTotal > 0 ? `귓속말 · 안 읽은 ${unreadTotal}개` : '귓속말');
}

// chat.js가 받은 귓속말(실시간·빠진 메시지 채우기)을 넘긴다. 차단한 상대의 것은 chat.js에서 이미 거른다.
export function onWhisper(m) {
  const me = store.user?.id;
  const partner = m.sender_id === me ? m.recipient_id : m.sender_id;
  const open = box?.isConnected && cur?.id === partner;
  if (open) {
    if (!msgs.some(x => x.id === m.id)) { msgs.push(m); drawMsgs(); }
    if (m.sender_id !== me) markRead(partner);
  } else if (m.sender_id !== me) {
    toast(`귓속말 · ${m.sender_name || '조사원'}: ${String(m.content || '').slice(0, 40)}`);
  }
  refreshSoon();
}

// 조사원 카드·친구 목록의 [귓속말]: 그 상대와의 대화를 바로 연다(이름만 알면 새 대화로 시작한다).
export function openWhisperWindow(target) {
  const m = openModal({ title: '귓속말', wide: true, onClose: () => { box = null; cur = null; },
    body: `<div class="wh">
      <aside class="wh-side">
        <form class="wh-new" autocomplete="off"><input name="to" maxlength="24" placeholder="이름으로 새 귓속말" aria-label="받는 사람 이름"><button class="btn small" type="submit">시작</button></form>
        <ul class="wh-threads" id="wh-threads"></ul>
      </aside>
      <section class="wh-main" id="wh-main"></section>
    </div>` });
  box = $('.wh', m);
  $('.wh-new', box).onsubmit = e => {
    e.preventDefault();
    const name = e.target.to.value.trim(); if (!name) return;
    e.target.to.value = '';
    const known = threads.find(t => t.name === name);
    openThread(known ? { id: known.partner_id, name: known.name } : { id: null, name });
  };
  drawList();
  if (target?.id || target?.name) {
    const known = threads.find(t => (target.id && t.partner_id === target.id) || t.name === target.name);
    openThread(known ? { id: known.partner_id, name: known.name } : { id: target.id || null, name: target.name });
  } else if (wide() && threads[0]) openThread({ id: threads[0].partner_id, name: threads[0].name });
  else drawThread();
  refresh();
}

function drawList() {
  const ul = $('#wh-threads', box); if (!ul) return;
  ul.innerHTML = threads.length ? threads.map(t => `<li><button class="wh-thread ${cur?.id === t.partner_id ? 'on' : ''}" data-partner="${esc(t.partner_id)}">
      <span class="wh-t-top"><b>${esc(t.name)}</b><time>${fmt.time(t.last_at)}</time></span>
      <span class="wh-t-bottom"><small>${t.last_mine ? '나: ' : ''}${esc(t.last_text || '')}</small>${t.unread > 0 ? `<i class="wh-count">${t.unread > 99 ? '99+' : t.unread}</i>` : ''}</span>
    </button></li>`).join('')
    : `<li class="wh-none muted small">아직 주고받은 귓속말이 없습니다. 위에 이름을 적거나 조사원 카드에서 [귓속말]을 누르세요.</li>`;
  $$('[data-partner]', ul).forEach(b => b.onclick = () => { const t = threads.find(x => x.partner_id === b.dataset.partner); if (t) openThread({ id: t.partner_id, name: t.name }); });
}

async function openThread(t) {
  cur = t; msgs = [];
  box.classList.add('thread-open');
  drawList(); drawThread(true);
  if (t.id) {
    const me = store.user?.id;
    try {
      const { data, error } = await db.from('world_chat_messages').select(COLS).eq('channel_type', 'whisper')
        .or(`and(sender_id.eq.${me},recipient_id.eq.${t.id}),and(sender_id.eq.${t.id},recipient_id.eq.${me})`)
        .order('created_at', { ascending: false }).limit(100);
      if (error) throw error;
      if (cur !== t) return;
      msgs = (data || []).reverse();
    } catch (e) { const l = cur === t && $('#wh-list', box); if (l) l.innerHTML = `<li class="chat-empty">${esc(friendlyError(e))}</li>`; return; }
    markRead(t.id);
  }
  if (cur === t) drawMsgs();
}

function drawThread(loading) {
  const main = $('#wh-main', box); if (!main) return;
  if (!cur) { main.innerHTML = `<p class="wh-empty muted">${icon('chat', 18)}<span>왼쪽에서 대화를 고르거나 새 귓속말을 시작하세요.</span></p>`; return; }
  let draft = ''; try { draft = sessionStorage.getItem(draftKey(cur)) || ''; } catch {}
  main.innerHTML = `
    <header class="wh-head"><button class="icon-btn wh-back" aria-label="대화 목록으로">${icon('back')}</button>
      ${cur.id && isGM(cur.id) ? `<b><button type="button" class="name-link" data-card="${esc(cur.id)}" title="운영진(GM)"><span class="gm-badge">GM</span></button></b>` : `<b>${cur.id ? cardName(cur.id, cur.name) : esc(cur.name)}</b>`}<small class="muted">둘만 보는 대화</small></header>
    <ol class="chat-list wh-list" id="wh-list">${loading ? '<li class="chat-empty">불러오는 중…</li>' : ''}</ol>
    <form class="chat-form" id="wh-form"><div class="chat-row"><textarea name="text" rows="1" maxlength="500" placeholder="${esc(cur.name)}님에게 귓속말" aria-label="귓속말"></textarea>
      <button class="chat-send" type="submit" aria-label="보내기">${icon('chevron', 16)}</button></div></form>`;
  if (!loading) drawMsgs();
  const form = $('#wh-form', main);
  form.text.value = draft;
  form._fit = growInput(form);
  form.text.addEventListener('input', () => { try { sessionStorage.setItem(draftKey(cur), form.text.value); } catch {} });
  form.text.addEventListener('keydown', e => { if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); form.requestSubmit(); } });
  form.onsubmit = send;
  $('.wh-back', main).onclick = () => { box.classList.remove('thread-open'); };
  if (matchMedia('(pointer: fine)').matches) setTimeout(() => form.text.focus({ preventScroll: true }), 30);
}
// 대화 줄만 다시 그린다(쓰던 글과 키패드는 그대로 둔다)
function drawMsgs() {
  const list = box && $('#wh-list', box); if (!list || !cur) return;
  const me = store.user?.id;
  list.innerHTML = msgs.length ? msgs.map(m => `<li class="${m.sender_id === me ? 'mine' : ''}"><div class="meta"><b>${esc(m.sender_id === me ? '나' : (m.sender_name || cur.name))}</b><time>${fmt.time(m.created_at)}</time></div><p>${esc(m.content)}</p></li>`).join('')
    : `<li class="chat-empty">${esc(cur.name)}님에게 첫 귓속말을 보내 보세요.</li>`;
  list.scrollTop = list.scrollHeight;
}

async function send(e) {
  e.preventDefault();
  const form = e.target, text = form.text.value.trim(), t = cur;
  if (!text || !t) return;
  const b = form.querySelector('button[type=submit]'); if (b.disabled) return;
  b.disabled = true;
  try {
    await rpc('world_chat_send', { p_channel: 'whisper', p_content: text, p_recipient_name: t.name });
    form.text.value = ''; try { sessionStorage.removeItem(draftKey(t)); } catch {} form._fit?.();
    await refresh();
    if (!t.id) { const found = threads.find(x => x.name === t.name); if (found) t.id = found.partner_id; }
    if (cur === t) reloadMsgs(t);
  } catch (err) { toast(friendlyError(err), 'error'); }
  finally { b.disabled = false; }
}

async function reloadMsgs(t) {
  if (!t.id) return drawMsgs();
  const me = store.user?.id;
  try {
    const { data, error } = await db.from('world_chat_messages').select(COLS).eq('channel_type', 'whisper')
      .or(`and(sender_id.eq.${me},recipient_id.eq.${t.id}),and(sender_id.eq.${t.id},recipient_id.eq.${me})`)
      .order('created_at', { ascending: false }).limit(100);
    if (!error && cur === t) { msgs = (data || []).reverse(); drawMsgs(); drawList(); }
  } catch {}
}
async function markRead(id) {
  const t = threads.find(x => x.partner_id === id);
  if (t && t.unread > 0) { unreadTotal = Math.max(0, unreadTotal - t.unread); t.unread = 0; paintDot(); drawList(); }
  try { await rpc('world_whisper_mark_read', { p_partner: id }); } catch {}
}
