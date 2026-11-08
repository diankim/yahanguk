import { db, store, rpc, esc, fmt, icon, $, $$, toast, friendlyError, openModal, closeModal, isGM } from './core.js';
import { cardName } from './views/card.js';
import { growInput, keepKeyboard } from './grow.js';
import { playAlarm } from './sound.js';
import { bgroup, bclear } from './rtb.js';

const COLS = 'id,channel_type,sender_id,sender_name,sender_title,recipient_id,content,created_at';
let btn = null, threads = [], unreadTotal = 0, box = null, cur = null, msgs = [], refreshTimer = null;
const wide = () => matchMedia('(min-width: 760px)').matches;
const draftKey = t => `yh-wh-draft:${t?.id || t?.name || ''}`;

export function mountWhisper(button) {
  btn = button;
  btn.onclick = () => openWhisperWindow();
  whLink();
  refresh();
  let hiddenAt = 0;
  document.addEventListener('visibilitychange', () => { if (document.hidden) { hiddenAt = Date.now(); return; } if (Date.now() - hiddenAt > 60000) refresh(); });
}

let whOut = false, whBeat = 0, wbc = null;
const isPopWin = () => document.body.classList.contains('pop-win');
export const whisperOut = () => whOut;
function whLink() {
  if (!('BroadcastChannel' in window)) return;
  wbc = new BroadcastChannel('yh-pop');
  const mine = d => !d?.uid || d.uid === store.user?.id;
  if (isPopWin()) {
    const say = (t, x = {}) => { try { wbc.postMessage({ t, uid: store.user?.id, ...x }); } catch {} };
    say('wh-open'); setInterval(() => say('wh-open', { n: unreadTotal }), 20000);
    window.addEventListener('pagehide', () => say('wh-closed'));
    $('.wh-home')?.addEventListener('click', () => { say('wh-closed'); window.close(); setTimeout(() => { if (!window.closed) toast('게임 창의 귓속말을 되돌렸습니다. 이 창은 직접 닫아 주세요.'); }, 300); });
    wbc.onmessage = e => {
      const d = e.data; if (!mine(d)) return;
      if (d.t === 'wh-ping') say('wh-open', { n: unreadTotal });
      if (d.t === 'wh-target') { window.focus(); if (d.id || d.name) openWhisperWindow({ id: d.id, name: d.name }); }
    };
    return;
  }
  const setOut = v => {
    if (whOut === v) return; whOut = v;
    if (document.body.classList.contains('chat-out')) whisperFeed(!v);
    if (!v) refresh();
  };
  wbc.onmessage = e => {
    const d = e.data; if (!mine(d)) return;
    if (d.t === 'wh-open') { whBeat = Date.now(); setOut(true); if (d.n != null) { unreadTotal = Number(d.n) || 0; paintDot(); } }
    if (d.t === 'wh-unread') { unreadTotal = Number(d.n) || 0; paintDot(); }
    if (d.t === 'wh-closed') setOut(false);
  };
  try { wbc.postMessage({ t: 'wh-ping', uid: store.user?.id }); } catch {}
  setInterval(() => { if (whOut && Date.now() - whBeat > 60000) setOut(false); }, 15000);
}
function focusWhisperPop(target) {
  let w = null;
  try { w = window.open('', 'yh-pop-whisper'); } catch {}
  if (!w) { whOut = false; return false; }
  try { if (w.location.href === 'about:blank') w.location.replace(`${location.pathname}?pop=whisper`); } catch {}
  try { w.focus(); } catch {}
  try { wbc?.postMessage({ t: 'wh-target', uid: store.user?.id, id: target?.id || null, name: target?.name || null }); } catch {}
  return true;
}

export async function refresh() {
  if (whOut && !isPopWin()) return;
  try {
    const r = await rpc('world_whisper_threads');
    threads = r?.threads || []; unreadTotal = Number(r?.unread_total || 0);
  } catch { return; }
  paintDot();
  if (box?.isConnected) drawList();
  if (isPopWin()) try { wbc?.postMessage({ t: 'wh-unread', uid: store.user?.id, n: unreadTotal }); } catch {}
}
const refreshSoon = () => { clearTimeout(refreshTimer); refreshTimer = setTimeout(refresh, 400); };

function paintDot() {
  if (!btn) return;
  btn.classList.toggle('has-dot', unreadTotal > 0);
  btn.setAttribute('aria-label', unreadTotal > 0 ? `귓속말 · 안 읽은 ${unreadTotal}개` : '귓속말');
}

const whSeen = new Set();
export function onWhisper(m) {
  if (m?.id != null) { if (whSeen.has(m.id)) return; whSeen.add(m.id); if (whSeen.size > 300) whSeen.clear(); }
  const me = store.user?.id;
  const partner = m.sender_id === me ? m.recipient_id : m.sender_id;
  const open = box?.isConnected && cur?.id === partner;
  if (open) {
    if (!msgs.some(x => x.id === m.id)) { msgs.push(m); drawMsgs(); }
    if (m.sender_id !== me) markRead(partner);
  } else if (m.sender_id !== me) {
    toast(`귓속말 · ${m.sender_name || '조사원'}: ${String(m.content || '').slice(0, 40)}`);
  }
  if (m.sender_id !== me && (!m.created_at || Date.now() - new Date(m.created_at) < 120000) && !(open && document.hasFocus())) playAlarm('whisper', 'w:' + m.id);
  if (!whOut || isPopWin()) refreshSoon();
}

let pageHost = null;
export function openWhisperWindow(target) {
  if (pageHost?.isConnected) {
    box = $('.wh', pageHost);
    if (target?.id || target?.name) { const known = threads.find(t => (target.id && t.partner_id === target.id) || t.name === target.name); openThread(known ? { id: known.partner_id, name: known.name } : { id: target.id || null, name: target.name }); }
    return;
  }
  if (whOut && !isPopWin() && focusWhisperPop(target)) return;
  const m = openModal({ title: '귓속말', wide: true, onClose: () => { box = null; cur = null; }, body: '<div class="wh-host"></div>' });
  buildUI($('.wh-host', m), target);
}
export function mountWhisperPage(el) {
  pageHost = el;
  buildUI(el).then(() => { if (!cur && wide() && threads[0]) openThread({ id: threads[0].partner_id, name: threads[0].name }); });
  whLink();
  whisperFeed(true);
  let hiddenAt = 0;
  document.addEventListener('visibilitychange', () => { if (document.hidden) { hiddenAt = Date.now(); return; } if (Date.now() - hiddenAt > 30000) { refresh(); if (cur) reloadMsgs(cur); } });
}
export function whisperFeed(on) {
  bgroup('whfeed', on && store.user?.id ? [`whisper:${store.user.id}`] : [], 'msg', p => { if (p.new?.channel_type === 'whisper') onWhisper(p.new); });
}
const canPop = () => matchMedia('(pointer: fine)').matches && !document.body.classList.contains('pop-win');
function buildUI(host, target) {
  host.innerHTML = `<div class="wh">
      <aside class="wh-side">
        <form class="wh-new" autocomplete="off"><input name="to" maxlength="24" placeholder="이름으로 새 귓속말" aria-label="받는 사람 이름"><button class="btn small" type="submit">시작</button>${canPop() ? `<button class="icon-btn wh-pop" type="button" aria-label="새 창으로 열기" title="새 창으로 열기">${icon('popout', 16)}</button>` : ''}${isPopWin() ? `<button class="icon-btn wh-home" type="button" aria-label="게임 창으로 되돌리기" title="이 창을 닫고 게임 창에서 귓속말을 엽니다">${icon('back', 16)}</button>` : ''}</form>
        <ul class="wh-threads" id="wh-threads"></ul>
      </aside>
      <section class="wh-main" id="wh-main"></section>
    </div>`;
  box = $('.wh', host);
  $('.wh-pop', box)?.addEventListener('click', () => { closeModal(); window.yahangPop?.('whisper'); });
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
  return refresh();
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
      msgs = mergeMsgs(data, msgs);
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
  keepKeyboard(form);
  $('.wh-back', main).onclick = () => { box.classList.remove('thread-open'); };
  if (matchMedia('(pointer: fine)').matches) setTimeout(() => form.text.focus({ preventScroll: true }), 30);
}
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

function mergeMsgs(data, old) {
  const got = (data || []).reverse(), seen = new Set(got.map(m => m.id)), last = got.length ? Date.parse(got[got.length - 1].created_at) : -Infinity;
  return got.concat(old.filter(m => !seen.has(m.id) && Date.parse(m.created_at) > last));
}
async function reloadMsgs(t) {
  if (!t.id) return drawMsgs();
  const me = store.user?.id;
  try {
    const { data, error } = await db.from('world_chat_messages').select(COLS).eq('channel_type', 'whisper')
      .or(`and(sender_id.eq.${me},recipient_id.eq.${t.id}),and(sender_id.eq.${t.id},recipient_id.eq.${me})`)
      .order('created_at', { ascending: false }).limit(100);
    if (!error && cur === t) { msgs = mergeMsgs(data, msgs); drawMsgs(); drawList(); }
  } catch {}
}
async function markRead(id) {
  const t = threads.find(x => x.partner_id === id);
  if (t && t.unread > 0) { unreadTotal = Math.max(0, unreadTotal - t.unread); t.unread = 0; paintDot(); drawList(); if (isPopWin()) try { wbc?.postMessage({ t: 'wh-unread', uid: store.user?.id, n: unreadTotal }); } catch {} }
  try { await rpc('world_whisper_mark_read', { p_partner: id }); } catch {}
}
