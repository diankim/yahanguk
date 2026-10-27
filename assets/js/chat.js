// 인게임 채팅: 전체·지역·세력·귓속말·파티. PC는 우측 열, 모바일은 하단 시트.
import { cardName } from './views/card.js';
import { isGM, db, store, on, rpc, act, esc, fmt, icon, $, $$, h, toast, friendlyError } from './core.js';

const TABS = [['global', '전체'], ['region', '지역'], ['faction', '세력'], ['whisper', '귓속말'], ['party', '파티']];
const HINT = {
  global: '모든 조사원에게 보입니다 · 하루 20회',
  region: '같은 지역에 있는 조사원에게만 보입니다',
  faction: '같은 대세력 소속에게만 보입니다',
  whisper: '받는 사람 이름을 입력하세요',
  party: '파티원에게만 보입니다',
};
let panel, col, fab, tab = 'global', msgs = [], partyMsgs = [], channel, partyPoll, unread = 0;

export function mountChat(colEl, fabEl) {
  col = colEl; fab = fabEl;
  panel = h(`<section class="chat" aria-label="채팅">
    <header class="chat-head"><h2>${icon('chat', 16)} 통신망</h2><button class="icon-btn chat-close" aria-label="채팅 닫기">${icon('close')}</button></header>
    <div class="segmented chat-tabs" style="--n:${TABS.length}">${TABS.map(([k, l]) => `<button data-tab="${k}" class="${k === tab ? 'on' : ''}">${l}</button>`).join('')}</div>
    <p class="chat-hint" id="chat-hint"></p>
    <ol class="chat-list" id="chat-list" aria-live="polite"></ol>
    <form class="chat-form" id="chat-form">
      <input name="to" class="chat-to" placeholder="받는 사람" maxlength="24" hidden>
      <div class="chat-row"><textarea name="text" rows="1" maxlength="500" placeholder="메시지 입력" aria-label="메시지"></textarea>
      <button class="btn primary" type="submit" aria-label="전송">${icon('chevron', 18)}</button></div>
    </form>
  </section>`);
  placePanel();
  matchMedia('(min-width: 1280px)').addEventListener('change', placePanel);
  fab.onclick = () => toggleSheet(true);
  $('.chat-close', panel).onclick = () => toggleSheet(false);
  panel.querySelector('.chat-tabs').onclick = e => { const b = e.target.closest('[data-tab]'); if (b) switchTab(b.dataset.tab); };
  const form = $('#chat-form', panel);
  form.text.addEventListener('keydown', e => { if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); form.requestSubmit(); } });
  form.onsubmit = send;
  // 쓰던 메시지는 새로고침하거나 시트를 닫았다 열어도 남는다(이 탭에만 저장).
  try { form.text.value = sessionStorage.getItem('yh-chat-draft') || ''; form.to.value = sessionStorage.getItem('yh-chat-to') || ''; } catch {}
  form.text.addEventListener('input', () => { try { sessionStorage.setItem('yh-chat-draft', form.text.value); } catch {} });
  form.to.addEventListener('input', () => { try { sessionStorage.setItem('yh-chat-to', form.to.value); } catch {} });
  switchTab(tab);
  subscribe();
  on('changed', ({ name }) => { if (/travel|join_major_faction/.test(name)) load(); });
  window.addEventListener('yahang:arrived', load);
}

function placePanel() {
  const wide = matchMedia('(min-width: 1280px)').matches;
  if (wide) { col.append(panel); document.body.classList.remove('chat-open'); }
  else if (!document.body.classList.contains('chat-open')) col.append(panel);
}
function toggleSheet(open) {
  document.body.classList.toggle('chat-open', open);
  // 모바일에서는 시트를 열 때 키패드를 띄우지 않는다(입력칸을 눌렀을 때만). 마우스를 쓰는 화면에서만 바로 입력칸으로 간다.
  if (open) { unread = 0; badge(); if (matchMedia('(pointer: fine)').matches) setTimeout(() => $('#chat-form textarea', panel)?.focus({ preventScroll: true }), 50); scrollEnd(); }
}
function badge() { fab.dataset.count = unread ? String(Math.min(unread, 99)) : ''; }

function switchTab(t) {
  tab = t;
  $$('.chat-tabs button', panel).forEach(b => b.classList.toggle('on', b.dataset.tab === t));
  $('#chat-hint', panel).textContent = HINT[t];
  $('.chat-to', panel).hidden = t !== 'whisper';
  clearInterval(partyPoll);
  if (t === 'party') { loadParty(); partyPoll = setInterval(() => { if (!document.hidden) loadParty(); }, 20000); }
  else load();
}

async function load() {
  try {
    const { data, error } = await db.from('world_chat_messages')
      .select('id,channel_type,sender_id,sender_name,sender_title,recipient_id,content,created_at')
      .order('created_at', { ascending: false }).limit(80);
    if (error) throw error;
    msgs = (data || []).reverse();
    draw();
  } catch (e) { drawError(friendlyError(e)); }
}
async function loadParty() {
  try { const s = await rpc('world_party_chat_snapshot'); partyMsgs = s?.messages || []; store.partyId = s?.party_id || null; draw(); }
  catch (e) { drawError(friendlyError(e)); }
}

function draw() {
  const list = $('#chat-list', panel); if (!list) return;
  const me = store.user?.id;
  let rows;
  if (tab === 'party') {
    if (!store.partyId) { list.innerHTML = `<li class="chat-empty">파티에 가입하면 파티 채팅을 쓸 수 있습니다.</li>`; return; }
    rows = partyMsgs.map(m => ({ sid: m.sender_id, gm: isGM(m.sender_id), who: m.sender_name || m.character_name, text: m.content, at: m.created_at, mine: m.sender_id === me }));
  } else {
    rows = msgs.filter(m => m.channel_type === tab).map(m => ({ sid: m.sender_id, gm: isGM(m.sender_id), who: m.sender_name, title: m.sender_title, text: m.content, at: m.created_at, mine: m.sender_id === me, to: m.channel_type === 'whisper' && m.sender_id === me }));
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
    else {
      const to = form.to.value.trim();
      if (tab === 'whisper' && !to) throw new Error('받는 사람 이름을 입력하세요.');
      await rpc('world_chat_send', { p_channel: tab, p_content: text, p_recipient_name: tab === 'whisper' ? to : null });
      await load();
    }
    form.text.value = ''; try { sessionStorage.removeItem('yh-chat-draft'); } catch {}
  } catch (err) { toast(friendlyError(err), 'error'); }
  finally { btn.disabled = false; }
}

function subscribe() {
  try {
    channel?.unsubscribe();
    channel = db.channel('yh-chat').on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'world_chat_messages' }, p => {
      const m = p.new; if (!m || msgs.some(x => x.id === m.id)) return;
      msgs.push(m); if (msgs.length > 120) msgs.shift();
      if (m.channel_type === tab) draw();
      const sheetClosed = !matchMedia('(min-width: 1280px)').matches && !document.body.classList.contains('chat-open');
      if (sheetClosed && m.sender_id !== store.user?.id) { unread++; badge(); }
    }).subscribe();
  } catch (e) { console.warn('실시간 채팅 연결 실패', e); }
}
