// 원정 짐 보따리: 원정에서 돌아올 때 가방에 다 들어가지 않은 전리품. 골라서 챙기거나 버린다.
// 보따리가 비기 전에는 서버가 이동·탐색·채집·낚시·전투·원정 출발을 막는다(world_guard_action_context·world_field_move).
import { rpc, act, esc, icon, h, $, $$, openModal, guard, ask, fmt, emit } from './core.js';

const RARITY = { common: '범품', uncommon: '양품', rare: '진품', epic: '명품', legendary: '신품' };

export async function openOverflow() {
  const body = h(`<div class="overflow-box"><p class="muted small">불러오는 중…</p></div>`);
  openModal({ title: '원정 짐 보따리', body });
  await draw(body);
}

async function draw(body) {
  let s;
  try { s = await rpc('world_overflow_snapshot'); } catch (e) { body.innerHTML = `<p class="bad">${esc(e.message || '보따리를 불러오지 못했습니다.')}</p>`; return; }
  const items = s?.items || [], bag = s?.bag || {};
  if (!items.length) {
    body.innerHTML = `<p class="hint ok">${icon('check', 14)}<span>보따리를 모두 정리했습니다. 다시 길을 나설 수 있습니다.</span></p>
      <div class="row-end"><button class="btn primary" data-close>닫기</button></div>`;
    return;
  }
  body.innerHTML = `
    <p class="ov-lead">${icon('bag', 16)}<span>가방 <b>${fmt.num(bag.used)} / ${fmt.num(bag.limit)}칸</b> · 들어가지 못한 전리품입니다. 챙기거나 버려야 다시 길을 나설 수 있습니다.</span></p>
    <ul class="item-list ov-list">${items.map(i => `<li>
      <div class="item-main"><b>${esc(i.name)} <span class="qty">×${fmt.num(i.qty)}</span></b>
        <small>${esc(RARITY[i.rarity] || '')}${i.room > 0 ? ` · 지금 ${fmt.num(Math.min(i.room, i.qty))}개 들어감` : ' · 가방에 자리 없음'}</small></div>
      <div class="item-act">
        <button class="btn small primary" data-take="${esc(i.item_id)}" ${i.room > 0 ? '' : 'disabled'}>${icon('plus', 14)}<span>챙기기</span></button>
        <button class="btn small ghost" data-drop="${esc(i.item_id)}" data-name="${esc(i.name)}" data-qty="${i.qty}">버리기</button>
      </div></li>`).join('')}</ul>
    <div class="btn-row ov-foot">
      <a class="btn small" href="#/bag/items" data-close>${icon('bag', 14)}<span>가방 정리하러 가기</span></a>
      <button class="btn small ghost" data-drop-all>모두 버리기</button>
    </div>
    <p class="muted small">가방에서 물품을 쓰거나 버리거나 팔아 자리를 만들면 더 챙길 수 있습니다. 버린 것은 되찾을 수 없습니다.</p>`;
  $$('[data-take]', body).forEach(b => b.onclick = async () => { await guard(b, () => act('world_overflow_take', { p_item: b.dataset.take, p_qty: null })); draw(body); });
  $$('[data-drop]', body).forEach(b => b.onclick = async () => {
    if (!await ask(`${b.dataset.name} ×${b.dataset.qty}을(를) 버릴까요? 되찾을 수 없습니다.`, { title: '보따리에서 버리기', ok: '버리기', danger: true })) return;
    await guard(b, () => act('world_overflow_discard', { p_item: b.dataset.drop, p_qty: null })); draw(body);
  });
  const all = $('[data-drop-all]', body);
  all.onclick = async () => {
    if (!await ask(`보따리에 남은 ${items.length}가지를 모두 버릴까요? 되찾을 수 없습니다.`, { title: '모두 버리기', ok: '모두 버리기', danger: true })) return;
    await guard(all, async () => { for (const i of items) await rpc('world_overflow_discard', { p_item: i.item_id, p_qty: null }); emit('changed', { name: 'world_overflow_discard' }); return { content: '보따리를 비웠습니다.' }; });
    draw(body);
  };
}

