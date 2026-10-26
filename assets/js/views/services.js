// 안전지대 시설: 상점 · 거래소 · 마구간. 서버도 안전지대에서만 허용한다.
import { db, store, on, act, nameOf, esc, icon, guard, $, $$, fmt, empty, toast, bagLimit, bagUsed } from '../core.js';
import { load, chip, loading, errorBox } from './common.js';

/* ── 상점 ─────────────────────────────────────────────── */
export async function renderShop(box) {
  box.innerHTML = loading();
  try {
    const [s, prices] = await Promise.all([load('world_shop_snapshot'), load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => [])]);
    if (!s?.available) { box.innerHTML = empty('이곳에는 상점이 없습니다. 안전지대에서 이용하세요.', 'shop'); return; }
    const c = store.character, have = c?.inventory || {};
    const ref = new Map((prices || []).map(p => [p.item_id, p]));
    const sellable = Object.entries(have).filter(([k, n]) => n > 0 && ref.get(k)?.npc_sell_price > 0 && !['tool', 'weapon', 'armor', 'equipment', 'quest'].includes(ref.get(k)?.category));
    const space = bagLimit(c) - bagUsed(c);
    box.innerHTML = `
      <div class="shop-head"><div><b>${esc(s.shop_name)}</b><small>재고는 하루 세 번(07·15·23시) 새로 들어옵니다 · 다음 입고 ${s.next_refresh ? fmt.time(s.next_refresh) : '-'}</small></div>
        <span class="chip accent">${icon('coin', 14)} ${fmt.jeon(s.gil)}</span></div>
      <p class="muted small">가방 여유 ${Math.max(0, space)}칸 · 가방이 가득 차면 구매할 수 없습니다.</p>
      <div class="seg-mini" role="tablist"><button class="on" data-mode="buy">사기</button><button data-mode="sell">팔기</button></div>
      <ul class="item-list" data-list="buy">${(s.stock || []).map(i => `<li>
        <div class="item-main"><b>${esc(i.item_name)}</b><span class="qty">${fmt.jeon(i.unit_price)}</span>
          <div class="chips">${chip(nameOf(i.category))}${chip(`${i.tier}단계`)}${chip(`재고 ${i.stock}`, i.stock ? '' : 'bad')}</div><small>${esc(i.description || '')}</small></div>
        <div class="item-act qty-act"><input type="number" min="1" max="${i.stock}" value="1" aria-label="수량" ${i.stock ? '' : 'disabled'}>
          <button class="btn small primary" data-buy="${esc(i.item_id)}" ${i.stock ? '' : 'disabled'}>사기</button></div></li>`).join('') || `<li>${empty('지금은 판매 중인 물품이 없습니다.')}</li>`}</ul>
      <ul class="item-list" data-list="sell" hidden>${sellable.map(([k, n]) => `<li>
        <div class="item-main"><b>${esc(nameOf(k))}</b><span class="qty">×${fmt.num(n)}</span><small>개당 약 ${fmt.jeon(Math.max(1, Math.round((ref.get(k).npc_sell_price))))}에 매입 · 세금 5%</small></div>
        <div class="item-act qty-act"><input type="number" min="1" max="${n}" value="1" aria-label="수량"><button class="btn small" data-sell="${esc(k)}">팔기</button></div></li>`).join('') || `<li>${empty('상점에 팔 수 있는 물품이 없습니다.', 'coin')}</li>`}</ul>
      <p class="muted small">상점 판매 수익은 하루 1,000전까지입니다. 더 비싸게 팔려면 거래소를 이용하세요.</p>`;
    $$('.seg-mini button', box).forEach(b => b.onclick = () => {
      $$('.seg-mini button', box).forEach(x => x.classList.toggle('on', x === b));
      $$('[data-list]', box).forEach(l => l.hidden = l.dataset.list !== b.dataset.mode);
    });
    const qty = b => Math.max(1, Math.floor(Number(b.closest('li').querySelector('input').value) || 1));
    $$('[data-buy]', box).forEach(b => b.onclick = () => guard(b, () => act('world_shop_buy', { p_item_id: b.dataset.buy, p_qty: qty(b) })));
    $$('[data-sell]', box).forEach(b => b.onclick = () => guard(b, () => act('world_shop_sell', { p_item_id: b.dataset.sell, p_qty: qty(b) })));
  } catch (e) { box.innerHTML = errorBox(e.message); }
}

/* ── 거래소 ───────────────────────────────────────────── */
export async function renderMarket(box) {
  box.innerHTML = loading();
  try {
    const [{ data: offers, error }, prices] = await Promise.all([
      db.from('world_trade_offers').select('offer_id,seller_id,item_id,quantity,unit_price,status,created_at,expires_at').eq('status', 'open').order('created_at', { ascending: false }).limit(60),
      load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => []),
    ]);
    if (error) throw new Error(error.message);
    const c = store.character, me = c.owner_id, have = c.inventory || {};
    const ref = new Map((prices || []).map(p => [p.item_id, p]));
    const tradeable = Object.entries(have).filter(([k, n]) => n > 0 && ref.get(k)?.tradeable !== false);
    const mine = (offers || []).filter(o => o.seller_id === me), others = (offers || []).filter(o => o.seller_id !== me);
    const row = (o, own) => `<li><div class="item-main"><b>${esc(nameOf(o.item_id))}</b><span class="qty">×${o.quantity}</span>
        <small>개당 ${fmt.jeon(o.unit_price)} · 합계 ${fmt.jeon(o.unit_price * o.quantity)}${ref.get(o.item_id) ? ` · 기준가 ${fmt.jeon(ref.get(o.item_id).reference_price)}` : ''}</small></div>
        <div class="item-act">${own ? `<button class="btn small" data-cancel="${o.offer_id}">등록 취소</button>` : `<button class="btn small primary" data-take="${o.offer_id}">사기</button>`}</div></li>`;
    box.innerHTML = `
      ${tradeable.length ? `<form class="form-grid trade-form" id="trade-form">
          <label class="field"><span>물품</span><select name="item">${tradeable.map(([k, n]) => `<option value="${esc(k)}">${esc(nameOf(k))} (${n})</option>`).join('')}</select></label>
          <label class="field"><span>수량</span><input name="qty" type="number" min="1" value="1"></label>
          <label class="field"><span>개당 가격(전)</span><input name="price" type="number" min="1" value="${ref.get(tradeable[0][0])?.reference_price || 10}"></label>
          <button class="btn primary" type="submit">${icon('plus', 16)}<span>판매 등록</span></button></form>` : empty('거래할 수 있는 물품이 없습니다.', 'coin')}
      <p class="muted small">0전 등록은 불가합니다. 희귀 성장 물품은 거래할 수 없습니다. 등록한 물품은 팔리거나 취소할 때까지 가방에서 빠집니다.</p>
      <h3 class="sub-h">판매 중 ${others.length}</h3>
      ${others.length ? `<ul class="item-list">${others.map(o => row(o, false)).join('')}</ul>` : empty('다른 조사원이 등록한 물품이 없습니다.', 'shop')}
      <h3 class="sub-h">내 등록 ${mine.length}</h3>
      ${mine.length ? `<ul class="item-list">${mine.map(o => row(o, true)).join('')}</ul>` : `<p class="muted small">등록한 물품이 없습니다.</p>`}`;
    const form = $('#trade-form', box);
    if (form) {
      form.item.onchange = () => { const p = ref.get(form.item.value)?.reference_price; if (p) form.price.value = p; };
      form.onsubmit = e => {
        e.preventDefault();
        const qty = Math.floor(Number(form.qty.value)), price = Math.floor(Number(form.price.value));
        if (!(qty >= 1) || !(price >= 1)) return toast('수량과 가격은 1 이상이어야 합니다.', 'error');
        guard(form.querySelector('button'), () => act('world_trade_offer_create', { p_item_id: form.item.value, p_qty: qty, p_unit_price: price }));
      };
    }
    $$('[data-take]', box).forEach(b => b.onclick = () => { if (confirm('이 물품을 살까요?')) guard(b, () => act('world_trade_offer_buy', { p_offer_id: b.dataset.take })); });
    $$('[data-cancel]', box).forEach(b => b.onclick = () => guard(b, () => act('world_trade_offer_cancel', { p_offer_id: b.dataset.cancel })));
  } catch (e) { box.innerHTML = errorBox(e.message); }
}

/* ── 마구간 ───────────────────────────────────────────── */
export async function renderStable(box) {
  box.innerHTML = loading();
  try {
    const m = await load('world_mount_snapshot');
    const here = (m.mounts || []).filter(x => x.at_stable);
    const c = store.character;
    box.innerHTML = here.length ? `<div class="mount-grid">${here.map(x => `<article class="mount ${x.owned ? 'on' : ''}">
        <header><b>${esc(x.mount_name)}</b>${chip(x.tier)}</header><p>${esc(x.description || '')}</p>
        <dl class="kv tight"><div><dt>속도</dt><dd>×${x.speed_multiplier}</dd></div><div><dt>정원</dt><dd>${x.passenger_capacity}명</dd></div><div><dt>운임</dt><dd>${x.fare_free ? '없음' : `노정패 ${x.fare_tokens}`}</dd></div></dl>
        <small class="muted">${esc(conditions(x, c))}</small>
        ${x.owned ? chip('보유 중', 'ok') : `<button class="btn small primary" data-buy="${esc(x.mount_id)}">${fmt.jeon(x.price)}에 들이기</button>`}</article>`).join('')}</div>`
      : empty('이 마구간에서 들일 수 있는 탈것이 없습니다.', 'route');
    $$('[data-buy]', box).forEach(b => b.onclick = () => { if (confirm('이 탈것을 들일까요?')) guard(b, () => act('world_mount_acquire', { p_mount_id: b.dataset.buy })); });
  } catch (e) { box.innerHTML = errorBox(e.message); }
}
export function conditions(m, c) {
  const p = [];
  if (m.unlock_level > 1) p.push(`Lv.${m.unlock_level}${c && c.level < m.unlock_level ? ' (부족)' : ''}`);
  if (m.unlock_faction) p.push(`${nameOf(m.unlock_faction)} 소속`);
  if (m.unlock_reputation) p.push(`평판 ${m.unlock_reputation}`);
  if (m.unlock_item) p.push(`${nameOf(m.unlock_item)} 공물`);
  return p.length ? '조건: ' + p.join(' · ') : '누구나 들일 수 있습니다.';
}
