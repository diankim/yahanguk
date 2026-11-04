import { store, rpc, act, ask, esc, icon, guard, $, $$, fmt, openModal, closeModal, nameOf, toast } from './core.js';
import { load } from './views/common.js';
import { cardName } from './views/card.js';
import { untradeNote } from './views/services.js';
import { pickRows, openItemPick, bundleChips } from './views/itempick.js';
import { loadLocks, isLocked } from './views/item.js';
import { MARKET_ONLY } from './core.js';

let snap = null, at = 0;
export async function loadLetters(force) {
  if (snap && !force && Date.now() - at < 60000) return snap;
  at = Date.now();
  snap = await rpc('world_letter_box').catch(() => snap || { letters: [], sent_today: 0, limits: { per_day: 10, kinds: 5, box: 10, pins: 5 } });
  return snap;
}
const when = t => { const d = new Date(t), s = (Date.now() - d) / 1000; return s < 3600 ? `${Math.max(1, Math.floor(s / 60))}분 전` : s < 86400 ? `${Math.floor(s / 3600)}시간 전` : `${Math.floor(s / 86400)}일 전`; };
const itemsText = items => Object.entries(items || {}).map(([k, n]) => `${nameOf(k)} ×${n}`).join(', ');

export function lettersPanelHtml(b) {
  const L = b?.letters || [], lim = b?.limits || {}, unread = L.filter(l => !l.read).length;
  return `<div class="btn-row lt-head"><button class="btn small primary" data-lt-new>${icon('letter', 14)}<span>서신 쓰기</span></button>
      <span class="muted small">오늘 보낸 서신 ${b?.sent_today || 0}/${lim.per_day || 10}통 · 서신함 ${L.length}/${lim.box || 10}통${unread ? ` · 안 읽음 ${unread}` : ''}</span></div>
    ${L.length ? `<ul class="spot-list lt-list">${L.map(l => `<li class="${l.read ? '' : 'unread'}"><div>
        <b>${l.read ? '' : '<span class="lt-dot" aria-label="안 읽음"></span>'}${l.pinned ? `<span class="chip accent">고정</span> ` : ''}「${esc(l.title)}」</b>
        <small>${cardName(l.from, l.from_name)} · ${when(l.created_at)}${l.pinned ? '' : ` · ${fmt.remain(new Date(l.expires_at) - Date.now())} 뒤 지워짐`}</small>
        ${Object.keys(l.items || {}).length ? `<small class="${l.claimed ? 'muted' : 'ok'}">${icon('bag', 12)} ${esc(itemsText(l.items))}${l.claimed ? ' · 받음' : ''}</small>` : ''}</div>
      <button class="btn small" data-lt-open="${l.id}">읽기</button></li>`).join('')}</ul>`
      : '<p class="muted small">받은 서신이 없습니다.</p>'}
    <p class="muted small">친구에게만 보낼 수 있습니다. 물품은 다섯 가지까지 붙이고, 물품이 든 서신은 안전지대(반요촌 제외)에서 부치고 받습니다. 고정하지 않은 서신은 받은 지 3일 뒤, 또는 10통을 넘으면 오래된 것부터 지워집니다(받지 않은 물품은 개인 창고로).</p>`;
}

export function bindLettersPanel(root, redraw) {
  const again = async () => { await loadLetters(true); redraw?.(); };
  $$('[data-lt-new]', root).forEach(b => b.onclick = () => openCompose('', '', again));
  $$('[data-lt-open]', root).forEach(b => b.onclick = () => {
    const l = (snap?.letters || []).find(x => String(x.id) === b.dataset.ltOpen);
    if (l) openLetter(l, again);
  });
}

function openLetter(l, again) {
  const hasItems = Object.keys(l.items || {}).length > 0;
  const m = openModal({ title: '서신', body: `<div class="letter">
      <h3>「${esc(l.title)}」</h3><p class="muted small">${cardName(l.from, l.from_name)} · ${new Date(l.created_at).toLocaleString('ko-KR', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })}</p>
      <div class="letter-body">${l.body ? esc(l.body) : '<span class="muted">(본문 없음)</span>'}</div>
      ${hasItems ? `<p class="small">${icon('bag', 14)} 함께 온 물품: <b>${esc(itemsText(l.items))}</b>${l.claimed ? ' <span class="muted">(받음)</span>' : ''}</p>` : ''}
      <div class="btn-row">
        ${hasItems && !l.claimed ? `<button class="btn primary" data-l="claim" data-here="서신 물품 받기">${icon('check', 14)}<span>물품 받기</span></button>` : ''}
        ${l.from ? `<button class="btn" data-l="reply">${icon('letter', 14)}<span>답장</span></button>` : ''}
        <button class="btn" data-l="${l.pinned ? 'unpin' : 'pin'}">${l.pinned ? '고정 풀기' : '고정'}</button>
        <button class="btn ghost danger-text" data-l="delete">지우기</button></div></div>` });
  if (!l.read) rpc('world_letter_mark', { p_id: l.id, p_op: 'read' }).then(() => { l.read = true; again(); }).catch(() => {});
  $$('[data-l]', m).forEach(b => b.onclick = async () => {
    const k = b.dataset.l;
    if (k === 'reply') { closeModal(); return openCompose(l.from, l.from_name, again, `답: ${l.title}`.slice(0, 24)); }
    if (k === 'claim') return guard(b, async () => { const r = await act('world_letter_claim', { p_id: l.id }); closeModal(); again(); return r; });
    if (k === 'delete' && !(await ask('이 서신을 지울까요?', { title: '서신 지우기', ok: '지우기', danger: true }))) return;
    guard(b, async () => { const r = await rpc('world_letter_mark', { p_id: l.id, p_op: k }); closeModal(); again(); return r; });
  });
}

export async function openCompose(to, toName, done, title = '') {
  const m = openModal({ title: '서신 쓰기', wide: true, body: '<div class="lt-compose"><p class="muted">불러오는 중…</p></div>' });
  const box = $('.lt-compose', m);
  try {
    const [fr, prices, inv, , stg] = await Promise.all([load('world_friend_overview').catch(() => null), load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => []),
      load('world_inventory_snapshot', undefined, { maxAge: 30000 }).catch(() => null), loadLocks(), load('world_storage_snapshot', undefined, { maxAge: 15000 }).catch(() => null)]);
    const placeOk = !stg || stg.can_move !== false, placeWhy = store.character?.travel_destination ? '이동 중에는 물품을 붙일 수 없습니다.' : '물품이 든 서신은 안전지대(반요촌 제외)에서, 이동·원정·자율 활동 중이 아닐 때만 부칩니다.';
    const friends = (fr?.friends || []).filter(f => !f.is_dead);
    if (!friends.length) { box.innerHTML = '<p class="muted">서신은 친구에게만 보낼 수 있습니다. 먼저 친구를 맺으세요.</p>'; return; }
    const have = store.character?.inventory || {}, ref = new Map((prices || []).map(p => [p.item_id, p]));
    const opts = pickRows(Object.entries(have).filter(([k, n]) => n > 0 && ref.get(k)?.tradeable !== false && !isLocked(k) && !MARKET_ONLY.has(k))
      .map(([k, n]) => ({ id: k, have: n, max: Math.min(999, n) })), inv?.catalog);
    const st = { to: friends.some(f => f.owner_id === to) ? to : friends[0].owner_id, title, body: '', items: {} };
    const draw = () => {
      box.innerHTML = `<form class="form-grid" id="lt-form">
        <label class="field"><span>받는 사람 (친구)</span><select name="to">${friends.map(f => `<option value="${esc(f.owner_id)}" ${f.owner_id === st.to ? 'selected' : ''}>${esc(f.character_name)} · Lv.${f.level}</option>`).join('')}</select></label>
        <label class="field"><span>제목 (24자)</span><input name="title" maxlength="24" value="${esc(st.title)}" required></label>
        <label class="field"><span>본문 (400자)</span><textarea name="body" maxlength="400" rows="5">${esc(st.body)}</textarea></label>
        <fieldset class="dt-side"><legend>붙일 물품 (다섯 가지까지 · 안전지대에서)</legend>
          ${placeOk ? '<p class="muted small">물품은 안전지대(반요촌 제외)에서 이동·원정·자율 활동 중이 아닐 때만 붙여 부칠 수 있고, 받는 사람도 안전지대에서 받습니다. 글만 적은 서신은 어디서나 부칩니다.</p>' : `<p class="notice-line">${icon('letter', 14)} ${esc(placeWhy)} 글만 적은 서신은 지금도 부칠 수 있습니다.</p>`}
          <div class="chips">${bundleChips(st.items)}</div>
          <button class="btn small dt-pick" type="button" data-add ${opts.length ? '' : 'disabled'}>${icon('bag', 15)}<span>가방에서 붙이기</span></button>
          ${untradeNote(have, ref, true)}</fieldset>
        <button class="btn primary block" type="submit">${icon('letter', 16)}<span>부치기</span></button></form>`;
      const f = $('#lt-form', box);
      f.addEventListener('keydown', e => { if (e.key === 'Enter' && e.target.tagName === 'INPUT') e.preventDefault(); });
      if (!placeOk) $$('[data-add]', f).forEach(b => b.disabled = true);
      f.to.onchange = () => { st.to = f.to.value; };
      f.title.oninput = () => { st.title = f.title.value; };
      f.body.oninput = () => { st.body = f.body.value; };
      $('[data-add]', f).onclick = () => openItemPick({ title: '서신에 붙일 물품', rows: opts, many: true, picked: st.items, kinds: 5, okText: '이대로 붙이기',
        note: untradeNote(have, ref, true), onDone: picked => { st.items = picked; draw(); } });
      $$('[data-rm]', f).forEach(b => b.onclick = () => { delete st.items[b.dataset.rm]; draw(); });
      f.onsubmit = async e => {
        e.preventDefault();
        if (!st.title.trim()) return toast('제목을 적으세요.', 'error');
        const who = friends.find(x => x.owner_id === st.to)?.character_name || '친구';
        if (Object.keys(st.items).length && !(await ask(`${who}님에게 서신을 부칠까요?\n붙인 물품: ${itemsText(st.items)}\n물품은 부치는 즉시 가방에서 빠집니다.`, { title: '서신 부치기', ok: '부치기' }))) return;
        guard(f.querySelector('[type=submit]'), async () => {
          const r = await act('world_letter_send', { p_to: st.to, p_title: st.title.trim(), p_body: st.body, p_items: st.items });
          closeModal(); done?.(); return r;
        });
      };
    };
    draw();
  } catch (e) { box.innerHTML = `<p class="bad">${esc(e.message)}</p>`; }
}
