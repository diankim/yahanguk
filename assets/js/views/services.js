// 안전지대 시설: 상점 · 거래소 · 마구간. 서버도 안전지대에서만 허용한다.
import { db, store, on, act, nameOf, esc, icon, guard, $, $$, fmt, empty, toast, bagLimit, bagUsed } from '../core.js';
import { load, chip, loading, errorBox } from './common.js';
import { openItemInfo, loadLocks, isLocked } from './item.js';

// 물품 이름을 누르면 정보 창(설명·효과·제작법)을 연다.
const infoName = (id, label) => `<button class="linkish item-name" data-info="${esc(id)}">${esc(label || nameOf(id))}</button>`;
const bindInfo = box => $$('[data-info]', box).forEach(b => b.onclick = e => { e.preventDefault(); openItemInfo(b.dataset.info); });

/* ── 상점 ─────────────────────────────────────────────── */
// 사고팔 때마다 창을 다시 그리므로, 고른 칸(사기·팔기)을 기억해 둔다.
let shopMode = 'buy';
export async function renderShop(box) {
  box.innerHTML = loading();
  try {
    const [s, prices] = await Promise.all([load('world_shop_snapshot'), load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => [])]);
    if (!s?.available) { box.innerHTML = empty('이곳에는 상점이 없습니다. 안전지대에서 이용하세요.', 'shop'); return; }
    const c = store.character, have = c?.inventory || {};
    const ref = new Map((prices || []).map(p => [p.item_id, p]));
    await loadLocks();
    const sellable = Object.entries(have).filter(([k, n]) => n > 0 && ref.get(k)?.npc_sell_price > 0 && !['tool', 'weapon', 'armor', 'equipment', 'quest'].includes(ref.get(k)?.category) && !isLocked(k));
    const space = bagLimit(c) - bagUsed(c);
    box.innerHTML = `
      <div class="shop-head"><div><b>${esc(s.shop_name)}</b><small>재고는 하루 세 번(07·15·23시) 새로 들어옵니다 · 다음 입고 ${s.next_refresh ? fmt.time(s.next_refresh) : '-'}</small></div>
        <span class="chip accent">${icon('coin', 14)} ${fmt.jeon(s.gil)}</span></div>
      <p class="muted small">가방 여유 ${Math.max(0, space)}칸 · 가방이 가득 차면 구매할 수 없습니다.</p>
      <div class="seg-mini" role="tablist"><button class="${shopMode === 'buy' ? 'on' : ''}" data-mode="buy">사기</button><button class="${shopMode === 'sell' ? 'on' : ''}" data-mode="sell">팔기</button></div>
      <ul class="item-list" data-list="buy" ${shopMode === 'buy' ? '' : 'hidden'}>${(s.stock || []).map(i => `<li>
        <div class="item-main"><b>${infoName(i.item_id, i.item_name)}</b><span class="qty">${fmt.jeon(i.unit_price)}</span>
          <div class="chips">${chip(nameOf(i.category))}${chip(`${i.tier}단계`)}${chip(`재고 ${i.stock}`, i.stock ? '' : 'bad')}</div><small>${esc(i.description || '')}</small></div>
        <div class="item-act qty-act"><input type="number" min="1" max="${i.stock}" value="1" aria-label="수량" ${i.stock ? '' : 'disabled'}>
          <button class="btn small primary" data-buy="${esc(i.item_id)}" ${i.stock ? '' : 'disabled'}>사기</button></div></li>`).join('') || `<li>${empty('지금은 판매 중인 물품이 없습니다.')}</li>`}</ul>
      <ul class="item-list" data-list="sell" ${shopMode === 'sell' ? '' : 'hidden'}>${sellable.map(([k, n]) => `<li>
        <div class="item-main"><b>${infoName(k)}</b><span class="qty">×${fmt.num(n)}</span><small>개당 약 ${fmt.jeon(Math.max(1, Math.round((ref.get(k).npc_sell_price))))}에 매입 · 세금 5%</small></div>
        <div class="item-act qty-act"><input type="number" min="1" max="${n}" value="1" aria-label="수량"><button class="btn small" data-sell="${esc(k)}">팔기</button></div></li>`).join('') || `<li>${empty('상점에 팔 수 있는 물품이 없습니다.', 'coin')}</li>`}</ul>
      <p class="muted small">상점 판매 수익은 하루 1,000전까지입니다. 더 비싸게 팔려면 거래소를 이용하세요. 잠근 물품은 팔기 목록에 나오지 않습니다.</p>`;
    $$('.seg-mini button', box).forEach(b => b.onclick = () => {
      shopMode = b.dataset.mode;
      $$('.seg-mini button', box).forEach(x => x.classList.toggle('on', x === b));
      $$('[data-list]', box).forEach(l => l.hidden = l.dataset.list !== b.dataset.mode);
    });
    const qty = b => Math.max(1, Math.floor(Number(b.closest('li').querySelector('input').value) || 1));
    $$('[data-buy]', box).forEach(b => b.onclick = () => guard(b, () => act('world_shop_buy', { p_item_id: b.dataset.buy, p_qty: qty(b) })));
    $$('[data-sell]', box).forEach(b => b.onclick = () => guard(b, () => act('world_shop_sell', { p_item_id: b.dataset.sell, p_qty: qty(b) })));
    bindInfo(box);
  } catch (e) { box.innerHTML = errorBox(e.message); }
}

/* ── 거래소 ───────────────────────────────────────────── */
// 거래소(누구나 사 가는 등록 판매)와 직접 거래(같은 안전지대의 조사원과 주고받기) 두 칸
let marketMode = 'board';
export async function renderMarket(box) {
  box.innerHTML = `<div class="seg-mini" role="tablist"><button class="${marketMode === 'board' ? 'on' : ''}" data-mm="board">거래소</button><button class="${marketMode === 'direct' ? 'on' : ''}" data-mm="direct">직접 거래</button></div><div class="mk-body">${loading()}</div>`;
  $$('[data-mm]', box).forEach(b => b.onclick = () => { marketMode = b.dataset.mm; renderMarket(box); });
  const body = $('.mk-body', box);
  if (marketMode === 'direct') return renderDirect(body);
  try {
    const [{ data: offers, error }, prices] = await Promise.all([
      db.from('world_trade_offers').select('offer_id,seller_id,item_id,quantity,unit_price,status,created_at,expires_at').eq('status', 'open').order('created_at', { ascending: false }).limit(60),
      load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => []), loadLocks(),
    ]);
    if (error) throw new Error(error.message);
    const c = store.character, me = c.owner_id, have = c.inventory || {};
    const ref = new Map((prices || []).map(p => [p.item_id, p]));
    const tradeable = Object.entries(have).filter(([k, n]) => n > 0 && ref.get(k)?.tradeable !== false && !isLocked(k));
    const mine = (offers || []).filter(o => o.seller_id === me), others = (offers || []).filter(o => o.seller_id !== me);
    const minPrice = k => { const r = ref.get(k)?.reference_price; return r ? Math.ceil(r * 0.3) : 1; };
    const row = (o, own) => `<li><div class="item-main"><b>${infoName(o.item_id)}</b><span class="qty">×${o.quantity}</span>
        <small>개당 ${fmt.jeon(o.unit_price)} · 합계 ${fmt.jeon(o.unit_price * o.quantity)}${ref.get(o.item_id) ? ` · 기준가 ${fmt.jeon(ref.get(o.item_id).reference_price)}` : ''}</small></div>
        <div class="item-act">${own ? `<button class="btn small" data-cancel="${o.offer_id}">등록 취소</button>` : `<button class="btn small primary" data-take="${o.offer_id}">사기</button>`}</div></li>`;
    body.innerHTML = `
      ${tradeable.length ? `<form class="form-grid trade-form" id="trade-form">
          <label class="field"><span>물품</span><select name="item">${tradeable.map(([k, n]) => `<option value="${esc(k)}">${esc(nameOf(k))} (${n})</option>`).join('')}</select></label>
          <label class="field"><span>수량</span><input name="qty" type="number" min="1" value="1"></label>
          <label class="field"><span>개당 가격(전)</span><input name="price" type="number" min="1" value="${ref.get(tradeable[0][0])?.reference_price || 10}"></label>
          <button class="btn primary" type="submit" ${mine.length >= 10 ? 'disabled' : ''}>${icon('plus', 16)}<span>판매 등록</span></button></form>
          <p class="muted small" id="trade-hint"></p>` : empty('거래할 수 있는 물품이 없습니다.', 'coin')}
      <p class="muted small">한 사람이 동시에 10건까지 등록할 수 있고(지금 ${mine.length}건), 기준 시세의 30%보다 싸게는 등록할 수 없습니다. 0전 등록은 불가하며, 희귀 성장 물품·잠근 물품·장착 중인 마지막 한 개는 올릴 수 없습니다. 등록한 물품은 팔리거나 취소할 때까지 가방에서 빠집니다.</p>
      <h3 class="sub-h">판매 중 ${others.length}</h3>
      ${others.length ? `<ul class="item-list">${others.map(o => row(o, false)).join('')}</ul>` : empty('다른 조사원이 등록한 물품이 없습니다.', 'shop')}
      <h3 class="sub-h">내 등록 ${mine.length}</h3>
      ${mine.length ? `<ul class="item-list">${mine.map(o => row(o, true)).join('')}</ul>` : `<p class="muted small">등록한 물품이 없습니다.</p>`}`;
    const form = $('#trade-form', body);
    if (form) {
      const hint = () => { const r = ref.get(form.item.value); $('#trade-hint', body).textContent = r?.reference_price ? `기준 시세 ${fmt.jeon(r.reference_price)} · 등록 가능 ${fmt.jeon(minPrice(form.item.value))} ~ ${fmt.jeon(r.reference_price * 10)}` : ''; };
      form.item.onchange = () => { const p = ref.get(form.item.value)?.reference_price; if (p) form.price.value = p; hint(); };
      hint();
      form.onsubmit = e => {
        e.preventDefault();
        const qty = Math.floor(Number(form.qty.value)), price = Math.floor(Number(form.price.value));
        if (!(qty >= 1) || !(price >= 1)) return toast('수량과 가격은 1 이상이어야 합니다.', 'error');
        if (price < minPrice(form.item.value)) return toast(`기준 시세의 30%(${fmt.jeon(minPrice(form.item.value))})보다 싸게 등록할 수 없습니다.`, 'error');
        guard(form.querySelector('button'), () => act('world_trade_offer_create', { p_item_id: form.item.value, p_qty: qty, p_unit_price: price }));
      };
    }
    $$('[data-take]', body).forEach(b => b.onclick = () => { if (confirm('이 물품을 살까요?')) guard(b, () => act('world_trade_offer_buy', { p_offer_id: b.dataset.take })); });
    $$('[data-cancel]', body).forEach(b => b.onclick = () => guard(b, () => act('world_trade_offer_cancel', { p_offer_id: b.dataset.cancel })));
    bindInfo(body);
  } catch (e) { body.innerHTML = errorBox(e.message); }
}

// 직접 거래: 받는 사람 · 내가 줄 것(물품·전) · 받을 것(물품·전) → 제안. 상대가 수락하면 서버가 한 번에 맞바꾼다.
let dt = { to: '', give: {}, giveGil: 0, want: {}, wantGil: 0 };
const bundle = (items, gil) => [...Object.entries(items || {}).map(([k, n]) => `${nameOf(k)} ×${n}`), gil > 0 ? fmt.jeon(gil) : ''].filter(Boolean).join(', ') || '없음';
async function renderDirect(body) {
  try {
    const [roster, prices, pending] = await Promise.all([load('world_region_roster', undefined, { maxAge: 10000 }).catch(() => []),
      load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => []), load('world_trade_direct_snapshot').catch(() => []), loadLocks()]);
    const c = store.character, have = c.inventory || {};
    const ref = new Map((prices || []).map(p => [p.item_id, p]));
    const people = (roster || []).filter(p => !p.is_dead);
    const mineTradeable = Object.entries(have).filter(([k, n]) => n > 0 && ref.get(k)?.tradeable !== false && !isLocked(k));
    const anyTradeable = (prices || []).filter(p => p.tradeable !== false).sort((a, b) => (a.item_name || '').localeCompare(b.item_name || '', 'ko'));
    if (!people.some(p => p.owner_id === dt.to)) dt.to = people[0]?.owner_id || '';
    const chipList = (items, side) => Object.entries(items).map(([k, n]) => `<span class="chip">${esc(nameOf(k))} ×${n}<button class="chip-x" data-rm="${side}:${esc(k)}" aria-label="빼기">${icon('close', 12)}</button></span>`).join('') || '<span class="muted small">없음</span>';
    const inc = (pending || []).filter(t => t.incoming), out = (pending || []).filter(t => !t.incoming);
    body.innerHTML = `
      ${inc.length ? `<h3 class="sub-h">받은 제안 ${inc.length}</h3><ul class="spot-list">${inc.map(t => `<li><div><b>${esc(t.other_name)}님의 제안</b>
          <small>받을 것: ${esc(bundle(t.give_items, t.give_gil))}</small><small>줄 것: ${esc(bundle(t.want_items, t.want_gil))}</small><small class="muted">${fmt.remain(new Date(t.expires_at) - Date.now())} 뒤 사라짐</small></div>
        <div class="btn-row"><button class="btn small primary" data-dt-acc="${esc(t.trade_id)}">수락</button><button class="btn small" data-dt-dec="${esc(t.trade_id)}">거절</button></div></li>`).join('')}</ul>` : ''}
      ${people.length ? `<form class="dt-form" id="dt-form">
        <label class="field"><span>거래할 조사원 (같은 곳에 있는 사람)</span><select name="to">${people.map(p => `<option value="${esc(p.owner_id)}" ${p.owner_id === dt.to ? 'selected' : ''}>${esc(p.character_name)} · Lv.${p.level}</option>`).join('')}</select></label>
        <fieldset class="dt-side"><legend>내가 줄 것</legend>
          <div class="chips">${chipList(dt.give, 'give')}</div>
          <div class="dt-add"><select name="giveItem">${mineTradeable.map(([k, n]) => `<option value="${esc(k)}">${esc(nameOf(k))} (${n})</option>`).join('')}</select><input name="giveQty" type="number" min="1" value="1" aria-label="수량"><button class="btn small" type="button" data-add="give" ${mineTradeable.length ? '' : 'disabled'}>담기</button></div>
          <label class="field"><span>줄 전 (가진 ${fmt.jeon(c.gil)})</span><input name="giveGil" type="number" min="0" value="${dt.giveGil}"></label></fieldset>
        <fieldset class="dt-side"><legend>받을 것</legend>
          <div class="chips">${chipList(dt.want, 'want')}</div>
          <div class="dt-add"><select name="wantItem">${anyTradeable.map(p => `<option value="${esc(p.item_id)}">${esc(p.item_name)}</option>`).join('')}</select><input name="wantQty" type="number" min="1" value="1" aria-label="수량"><button class="btn small" type="button" data-add="want">담기</button></div>
          <label class="field"><span>받을 전</span><input name="wantGil" type="number" min="0" value="${dt.wantGil}"></label></fieldset>
        <button class="btn primary block" type="submit">${icon('coin', 16)}<span>거래 제안 보내기</span></button>
      </form>` : empty('같은 곳에 거래할 조사원이 없습니다. 상대와 같은 안전지대에 있어야 합니다.', 'users')}
      ${out.length ? `<h3 class="sub-h">보낸 제안 ${out.length}</h3><ul class="spot-list">${out.map(t => `<li><div><b>${esc(t.other_name)}님에게</b><small>줄 것: ${esc(bundle(t.give_items, t.give_gil))}</small><small>받을 것: ${esc(bundle(t.want_items, t.want_gil))}</small></div>
        <button class="btn small" data-dt-cancel="${esc(t.trade_id)}">거두기</button></li>`).join('')}</ul>` : ''}
      <p class="muted small">상대가 수락하면 서버가 양쪽 가방과 전을 한 번에 맞바꿉니다. 전을 받는 쪽은 거래세 5%를 냅니다. 제안은 30분 동안 유효하고, 응답 대기는 3건까지입니다. 잠근 물품·장착 중인 마지막 한 개·거래 불가 물품은 줄 수 없습니다.</p>`;
    const f = $('#dt-form', body);
    if (f) {
      f.to.onchange = () => { dt.to = f.to.value; };
      f.giveGil.oninput = () => { dt.giveGil = Math.max(0, Math.floor(Number(f.giveGil.value) || 0)); };
      f.wantGil.oninput = () => { dt.wantGil = Math.max(0, Math.floor(Number(f.wantGil.value) || 0)); };
      $$('[data-add]', f).forEach(b => b.onclick = () => {
        const side = b.dataset.add, id = f[side + 'Item'].value, q = Math.floor(Number(f[side + 'Qty'].value) || 0);
        if (!id || q < 1) return toast('물품과 수량을 고르세요.', 'error');
        const box = dt[side]; if (!box[id] && Object.keys(box).length >= 8) return toast('한 번에 8가지까지 담을 수 있습니다.', 'error');
        const next = (box[id] || 0) + q;
        if (side === 'give' && next > Number(have[id] || 0)) return toast(`${nameOf(id)}은(는) ${have[id] || 0}개까지 줄 수 있습니다.`, 'error');
        box[id] = Math.min(999, next); renderDirect(body);
      });
      f.onsubmit = e => {
        e.preventDefault();
        if (!dt.to) return toast('거래할 조사원을 고르세요.', 'error');
        if (!Object.keys(dt.give).length && !dt.giveGil && !Object.keys(dt.want).length && !dt.wantGil) return toast('주거나 받을 것을 하나 이상 담으세요.', 'error');
        if (dt.giveGil > c.gil) return toast('가진 전보다 많이 줄 수 없습니다.', 'error');
        const who = people.find(p => p.owner_id === dt.to)?.character_name || '상대';
        if (!confirm(`${who}님에게 제안할까요?
줄 것: ${bundle(dt.give, dt.giveGil)}
받을 것: ${bundle(dt.want, dt.wantGil)}`)) return;
        guard(f.querySelector('[type=submit]'), async () => {
          const r = await act('world_trade_direct_offer', { p_to: dt.to, p_give: dt.give, p_give_gil: dt.giveGil, p_want: dt.want, p_want_gil: dt.wantGil });
          dt = { to: dt.to, give: {}, giveGil: 0, want: {}, wantGil: 0 };
          return r;
        });
      };
    }
    $$('[data-rm]', body).forEach(b => b.onclick = e => { e.preventDefault(); const [side, id] = b.dataset.rm.split(':'); delete dt[side][id]; renderDirect(body); });
    $$('[data-dt-acc]', body).forEach(b => b.onclick = () => { if (confirm('이 거래를 받아들일까요? 바로 맞바꿉니다.')) guard(b, () => act('world_trade_direct_respond', { p_trade_id: b.dataset.dtAcc, p_accept: true })); });
    $$('[data-dt-dec]', body).forEach(b => b.onclick = () => guard(b, () => act('world_trade_direct_respond', { p_trade_id: b.dataset.dtDec, p_accept: false })));
    $$('[data-dt-cancel]', body).forEach(b => b.onclick = () => guard(b, () => act('world_trade_direct_cancel', { p_trade_id: b.dataset.dtCancel })));
  } catch (e) { body.innerHTML = errorBox(e.message); }
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
