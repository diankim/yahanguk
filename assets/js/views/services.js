// 안전지대 시설: 상점 · 대장간 · 거래소 · 마구간. 서버도 안전지대에서만 허용한다.
import { openModal, ask, db, store, on, act, rpc, emit, loadCharacter, friendlyError, nameOf, esc, icon, guard, $, $$, fmt, empty, toast, bagLimit, bagUsed, equippedIds, bar, registerNames, brief } from '../core.js';
import { load, chip, loading, errorBox } from './common.js';
import { openItemInfo, loadLocks, isLocked } from './item.js';

// 물품 이름을 누르면 정보 창(설명·효과·제작법)을 연다.
const infoName = (id, label) => `<button class="linkish item-name" data-info="${esc(id)}">${esc(label || nameOf(id))}</button>`;
const bindInfo = box => $$('[data-info]', box).forEach(b => b.onclick = e => { e.preventDefault(); openItemInfo(b.dataset.info); });

/* ── 상점 ─────────────────────────────────────────────── */
// 사기·팔기 칸마다 항목별 수량을 고르고, 아래 단추 하나로 한꺼번에 사고판다(확인 팝업 뒤 서버가 항목마다 검사).
// 품목과 값은 하루 세 번(07·15·23시) 바뀌고, 나온 품목은 수량 제한 없이 산다(한 번에 99개).
// 창이 다시 그려져도 고른 칸과 수량은 기억한다.
let shopMode = 'buy';
const carts = { shop: { buy: {}, sell: {} }, smithy: { buy: {}, sell: {} } };
export async function renderShop(box) {
  box.innerHTML = loading();
  try {
    const [s, prices, inv] = await Promise.all([load('world_shop_snapshot'), load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => []),
      load('world_inventory_snapshot').catch(() => null), loadLocks()]);
    if (!s?.available) { box.innerHTML = empty('이곳에는 상점이 없습니다. 안전지대에서 이용하세요.', 'shop'); return; }
    tradePane(box, s, { kind: 'shop', sell: true, prices, equipment: inv?.equipment || {}, catalog: inv?.catalog || [] });
  } catch (e) { box.innerHTML = errorBox(e.message); }
}

function tradePane(box, s, { kind, sell, prices = [], equipment = {}, catalog = [] }) {
  const descOf = new Map((catalog || []).map(i => [i.id, i.description]));
  const cart = carts[kind], c = store.character, have = c?.inventory || {};
  const mode = sell ? shopMode : 'buy';
  const ref = new Map((prices || []).map(p => [p.item_id, p]));
  const equipped = new Set(Object.values(equipment || {}));
  // 장착 중인 장비는 마지막 하나를 남긴다(서버도 막는다)
  const sellMax = k => Math.max(0, (Number(have[k]) || 0) - (equipped.has(k) ? 1 : 0));
  const sellable = sell ? Object.entries(have).filter(([k, n]) => n > 0 && ref.get(k)?.npc_sell_price > 0 && ref.get(k)?.category !== 'quest' && !isLocked(k) && sellMax(k) > 0) : [];
  const list = (s.stock || []).filter(i => i.stock !== 0);
  const stock = new Map(list.map(i => [i.item_id, i]));
  const sellPrice = k => Math.max(1, Math.round(Number(ref.get(k)?.npc_sell_price) || 1));
  for (const k of Object.keys(cart.buy)) if (!stock.has(k)) delete cart.buy[k];
  for (const k of Object.keys(cart.sell)) if (!sellMax(k)) delete cart.sell[k];
  const space = bagLimit(c) - bagUsed(c);
  const sold = s.sell; // { sold, cap, left, resets_at }
  const stepper = (m, id, max) => `<div class="stepper" data-step="${m}:${esc(id)}">
      <button class="icon-btn" data-d="-1" aria-label="하나 빼기" ${max ? '' : 'disabled'}>${icon('minus', 16)}</button>
      <input type="number" inputmode="numeric" min="0" max="${max}" value="${cart[m][id] || 0}" aria-label="수량" ${max ? '' : 'disabled'}>
      <button class="icon-btn" data-d="1" aria-label="하나 더" ${max ? '' : 'disabled'}>${icon('plus', 16)}</button></div>`;
  box.innerHTML = `
    <div class="shop-head"><div><b>${esc(s.shop_name)}</b><small>품목과 값은 하루 세 번(07·15·23시) 바뀝니다 · 다음 바뀜 ${s.next_refresh ? fmt.time(s.next_refresh) : '-'}</small></div>
      <span class="chip accent">${icon('coin', 14)} ${fmt.jeon(c?.gil ?? s.gil)}</span></div>
    ${sell ? `<div class="seg-mini" role="tablist"><button class="${mode === 'buy' ? 'on' : ''}" data-mode="buy">사기</button><button class="${mode === 'sell' ? 'on' : ''}" data-mode="sell">팔기</button></div>` : ''}
    <section data-list="buy" ${mode === 'buy' ? '' : 'hidden'}>
      <p class="muted small">가방 여유 ${Math.max(0, space)}칸 · 같은 물품은 한 칸에 묶음으로 쌓입니다. 가방이 가득 차면 살 수 없습니다.</p>
      <ul class="item-list shop-list">${list.map(i => `<li>
        <div class="item-main"><b>${infoName(i.item_id, i.item_name)}</b><span class="qty">${fmt.jeon(i.unit_price)}</span>
          <small>${esc(nameOf(i.category))} · ${i.tier}단계${have[i.item_id] ? ` · 가진 것 ${fmt.num(have[i.item_id])}` : ''}</small>${i.description ? `<small class="brief">${esc(brief(i.description))}</small>` : ''}</div>
        ${stepper('buy', i.item_id, 99)}</li>`).join('') || `<li>${empty('지금은 파는 물품이 없습니다.')}</li>`}</ul>
    </section>
    ${sell ? `<section data-list="sell" ${mode === 'sell' ? '' : 'hidden'}>
      ${sold ? `<div class="sell-cap ${sold.left <= 0 ? 'full' : ''}"><span>오늘 판매 수익 <b>${fmt.jeon(sold.sold)}</b> / ${fmt.jeon(sold.cap)}</span>${bar(sold.sold, sold.cap, sold.left <= 0 ? 'enemy' : 'xp')}
        <small>${sold.left > 0 ? `앞으로 ${fmt.jeon(sold.left)}까지 더 받을 수 있습니다` : '오늘 한도를 다 채웠습니다'}${sold.resets_at ? ` · ${fmt.time(sold.resets_at)}부터 차례로 풀립니다` : ''} · 한도는 24시간에 2,000전</small></div>`
        : '<p class="muted small">상점 판매 수익은 하루 한도가 있고 세금 5%가 붙습니다.</p>'}
      <p class="muted small">장비도 팔 수 있습니다. 잠근 물품·임무 물품·장착 중인 마지막 하나는 나오지 않습니다.</p>
      <ul class="item-list shop-list">${sellable.map(([k, n]) => `<li>
        <div class="item-main"><b>${infoName(k)}</b><span class="qty">×${fmt.num(n)}</span><small>개당 약 ${fmt.jeon(sellPrice(k))}에 매입${equipped.has(k) ? ' · 장착 중 하나는 남김' : ''}</small>${descOf.get(k) ? `<small class="brief">${esc(brief(descOf.get(k)))}</small>` : ''}</div>
        ${stepper('sell', k, sellMax(k))}</li>`).join('') || `<li>${empty('상점에 팔 수 있는 물품이 없습니다.', 'coin')}</li>`}</ul>
    </section>` : ''}
    <div class="shop-foot"><span id="shop-sum"></span><button class="btn primary" id="shop-go"></button></div>`;
  const cur = () => sell ? shopMode : 'buy';
  const total = m => Object.entries(cart[m]).reduce((t, [k, n]) => t + n * (m === 'buy' ? Number(stock.get(k)?.unit_price || 0) : sellPrice(k)), 0);
  const foot = () => {
    const m = cur(), n = Object.values(cart[m]).filter(x => x > 0).length, sum = total(m), gil = c?.gil ?? s.gil;
    const net = Math.round(sum * 0.95);
    $('#shop-sum', box).innerHTML = n ? `${n}가지 · ${m === 'buy' ? '합계' : '받을 돈 약'} <b>${fmt.jeon(m === 'sell' ? net : sum)}</b>` : '<span class="muted">수량을 고르세요</span>';
    const go = $('#shop-go', box); go.textContent = m === 'buy' ? '구매하기' : '판매하기';
    go.disabled = !n || (m === 'buy' && sum > gil) || (m === 'sell' && sold && net > sold.left);
    if (m === 'buy' && sum > gil) $('#shop-sum', box).innerHTML += ' <span class="bad">· 전이 모자랍니다</span>';
    if (m === 'sell' && sold && n && net > sold.left) $('#shop-sum', box).innerHTML += ` <span class="bad">· 오늘 남은 한도 ${fmt.jeon(sold.left)}을 넘습니다</span>`;
  };
  $$('.seg-mini button[data-mode]', box).forEach(b => b.onclick = () => {
    shopMode = b.dataset.mode;
    $$('.seg-mini button[data-mode]', box).forEach(x => x.classList.toggle('on', x === b));
    $$('[data-list]', box).forEach(l => l.hidden = l.dataset.list !== b.dataset.mode);
    foot();
  });
  $$('[data-step]', box).forEach(st => {
    const [m, id] = st.dataset.step.split(':'), inp = st.querySelector('input'), max = Number(inp.max) || 0;
    const set = v => { v = Math.max(0, Math.min(max, Math.floor(Number(v) || 0))); inp.value = v; if (v) cart[m][id] = v; else delete cart[m][id]; st.closest('li').classList.toggle('picked', v > 0); foot(); };
    st.querySelectorAll('[data-d]').forEach(b => b.onclick = () => set(Number(inp.value) + Number(b.dataset.d)));
    inp.oninput = () => set(inp.value);
    if (cart[m][id]) st.closest('li').classList.add('picked');
  });
  $('#shop-go', box).onclick = async e => {
    const btn = e.currentTarget, m = cur(), items = Object.entries(cart[m]).filter(([, n]) => n > 0);
    if (!items.length || btn.dataset.busy === '1') return;
    const label = m === 'buy' ? '구매' : '판매', sum = total(m);
    const ok = await ask(`${items.map(([k, n]) => `${m === 'buy' ? stock.get(k)?.item_name || nameOf(k) : nameOf(k)} ×${n}`).join('\n')}\n${m === 'buy' ? `합계 ${fmt.jeon(sum)}` : `받을 돈 약 ${fmt.jeon(Math.round(sum * 0.95))}(세금 5% 뺌)`}`,
      { title: `${label}할까요?`, ok: `${label}하기` });
    if (!ok) return;
    btn.dataset.busy = '1'; btn.disabled = true;
    const fail = [];
    let last = null;
    for (const [k, n] of items) {
      try { last = await rpc(m === 'buy' ? 'world_shop_buy' : 'world_shop_sell', { p_item_id: k, p_qty: n }); delete cart[m][k]; }
      catch (err) { fail.push(`${nameOf(k)}: ${friendlyError(err)}`); }
    }
    const done = items.length - fail.length;
    if (done) toast(`${label} 완료 ${done}가지${fail.length ? ` · 실패 ${fail.length}가지` : ''}${m === 'sell' && last?.cap ? ` · 오늘 판매 ${fmt.jeon(last.sold)} / ${fmt.jeon(last.cap)}` : ''}`, fail.length ? 'warn' : 'ok');
    if (fail.length) toast(fail.join(' / '), 'error');
    window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'trade' }));
    btn.dataset.busy = '';
    await loadCharacter().catch(() => {});
    emit('changed', { name: m === 'buy' ? 'world_shop_buy' : 'world_shop_sell' });
  };
  foot();
  bindInfo(box);
}

/* ── 대장간 ───────────────────────────────────────────── */
// 재료 사기(장비 제작·강화 재료와 수리 도구) · 무기 강화 · 일괄 수리 · 분해
let smithyTab = 'buy';
const SMITHY_TABS = [['buy', '재료 사기'], ['enhance', '무기 강화'], ['repair', '수리'], ['dismantle', '분해']];
const GEAR_CATS = new Set(['weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool']);
const DISMANTLE_NEED = t => ({ 1: 1, 2: 4, 3: 8, 4: 12 })[t] || 16; // 서버 world_dismantle_need와 같다
export async function renderSmithy(box) {
  box.innerHTML = `<div class="seg-mini smithy-tabs" role="tablist">${SMITHY_TABS.map(([k, n]) => `<button class="${smithyTab === k ? 'on' : ''}" data-st="${k}">${n}</button>`).join('')}</div><div class="sm-body">${loading()}</div>`;
  $$('[data-st]', box).forEach(b => b.onclick = () => { smithyTab = b.dataset.st; renderSmithy(box); });
  const body = $('.sm-body', box);
  try {
    if (smithyTab === 'buy') {
      const s = await load('world_smithy_snapshot');
      if (!s?.available) { body.innerHTML = empty(s?.content || '대장간은 안전지대에만 있습니다.', 'shop'); return; }
      return tradePane(body, s, { kind: 'smithy', sell: false });
    }
    if (smithyTab === 'enhance') return enhancePane(body);
    if (smithyTab === 'repair') return repairPane(body);
    return dismantlePane(body);
  } catch (e) { body.innerHTML = errorBox(e.message); }
}

async function enhancePane(body) {
  const q = await rpc('world_enhance_quote');
  if (!q?.weapon) { body.innerHTML = empty('장착 중인 무기가 없습니다. 가방 › 장비에서 무기를 끼우고 오세요.', 'sword'); return; }
  registerNames(Object.entries(q.names || {}));
  const have = q.have || {}, items = Object.entries(q.items || {});
  const short = items.filter(([k, n]) => (have[k] || 0) < n);
  const maxed = q.level >= q.max;
  body.innerHTML = `
    <div class="enh-card">
      <div class="enh-head"><b>${infoName(q.weapon, q.name)}</b><span class="enh-lv">+${q.level}</span></div>
      <dl class="kv tight">
        <div><dt>위력</dt><dd>${q.power}${maxed ? '' : ` → <b>${q.next_power}</b>`}</dd></div>
        ${maxed ? '' : `<div><dt>성공 확률</dt><dd>${q.chance}%</dd></div><div><dt>비용</dt><dd>${fmt.jeon(q.gil)}${q.have_gil < q.gil ? ' <span class="bad">(모자람)</span>' : ''}</dd></div>`}
      </dl>
      ${maxed ? '<p class="hint ok">+10까지 강화했습니다.</p>' : `<ul class="enh-mats">${items.map(([k, n]) => `<li class="${(have[k] || 0) < n ? 'bad' : 'ok'}">${infoName(k)} <span>${fmt.num(have[k] || 0)} / ${n}</span></li>`).join('')}</ul>
      <div class="btn-row"><button class="btn primary" id="enh-go" ${short.length || q.have_gil < q.gil ? 'disabled' : ''}>${icon('sword', 16)}<span>+${q.level + 1} 강화하기</span></button></div>
      ${short.length ? `<p class="muted small">모자란 재료는 「재료 사기」에서 살 수 있습니다(강철 주괴·응축 영핵은 회차에 따라 나옵니다).</p>` : ''}`}
    </div>
    <p class="muted small">장착 중인 무기를 +10까지 강화합니다. 단계마다 위력 +5%. +3까지는 반드시 성공하고, 그 뒤로는 확률이 낮아집니다(법구 제작사는 +10%p). 실패하면 재료와 전만 들고 단계는 내려가지 않습니다. 강화는 그 무기에 붙고, 그 무기를 모두 팔거나 내주면 사라집니다.</p>`;
  bindInfo(body);
  const go = $('#enh-go', body);
  if (go) go.onclick = async () => {
    if (!await ask(`${q.name} +${q.level + 1} 강화\n성공 확률 ${q.chance}% · ${fmt.jeon(q.gil)}\n${items.map(([k, n]) => `${nameOf(k)} ×${n}`).join(', ')}`, { title: '강화할까요?', ok: '강화하기' })) return;
    await guard(go, async () => {
      const r = await rpc('world_weapon_enhance');
      window.dispatchEvent(new CustomEvent('yh-sfx', { detail: r.success ? 'craft' : 'error' }));
      toast(r.content, r.success ? 'ok' : 'warn');
      await loadCharacter().catch(() => {});
      emit('changed', { name: 'world_weapon_enhance' });
    });
    enhancePane(body);
  };
}

async function repairPane(body) {
  const q = await rpc('world_repair_quote');
  const items = q?.items || [];
  body.innerHTML = items.length ? `
    <ul class="item-list">${items.map(i => `<li><div class="item-main"><b>${infoName(i.item_id, i.name)}</b><span class="qty">${fmt.jeon(i.cost)}</span>
      <small>내구도 ${fmt.num(i.durability)} / ${fmt.num(i.max)}${i.equipped ? ' · 장착 중' : ''}</small></div>
      <div class="item-act"><button class="btn small" data-rep-one="${esc(i.item_id)}" ${store.character?.gil < i.cost ? 'disabled' : ''}>고치기</button></div></li>`).join('')}</ul>
    <div class="shop-foot"><span>${items.length}개 · 합계 <b>${fmt.jeon(q.total)}</b>${store.character?.gil < q.total ? ' <span class="bad">· 전이 모자랍니다</span>' : ''}</span>
      <button class="btn primary" id="rep-all" ${store.character?.gil < q.total ? 'disabled' : ''}>모두 고치기</button></div>
    <p class="muted small">하나씩 고치거나 한 번에 모두 새것처럼 고칩니다. 값은 어느 쪽이든 같습니다.</p>`
    : empty('고칠 장비가 없습니다. 모두 멀쩡합니다.', 'shield');
  bindInfo(body);
  $$('[data-rep-one]', body).forEach(b => b.onclick = async () => {
    await guard(b, () => act('world_equipment_repair', { p_item_id: b.dataset.repOne, p_method: 'gil' }));
    repairPane(body);
  });
  const go = $('#rep-all', body);
  if (go) go.onclick = async () => {
    if (!await ask(`장비 ${items.length}개를 ${fmt.jeon(q.total)}에 모두 고칠까요?`, { title: '일괄 수리', ok: '모두 고치기' })) return;
    await guard(go, () => act('world_equipment_repair_all'));
    repairPane(body);
  };
}

async function dismantlePane(body) {
  const inv = await load('world_inventory_snapshot');
  const c = store.character, rank = inv.crafting_rank || c?.crafting_rank || 1;
  const cat = new Map((inv.catalog || []).map(i => [i.id, i])), equipped = new Set(Object.values(inv.equipment || {}));
  const rows = Object.entries(inv.inventory || {}).filter(([k, n]) => n > 0 && GEAR_CATS.has(cat.get(k)?.category))
    .map(([k, n]) => ({ k, n, it: cat.get(k), free: n - (equipped.has(k) ? 1 : 0) }))
    .sort((a, b) => (a.it.tier || 0) - (b.it.tier || 0) || nameOf(a.k).localeCompare(nameOf(b.k), 'ko'));
  body.innerHTML = rows.length ? `<ul class="item-list">${rows.map(({ k, n, it, free }) => {
      const need = DISMANTLE_NEED(it.tier || 1), why = rank < need ? `제작 숙련 ${need}단계 필요(지금 ${rank})` : free < 1 ? '장착 중인 마지막 하나' : isLocked(k) ? '잠금' : '';
      return `<li><div class="item-main"><b>${infoName(k)}</b><span class="qty">×${fmt.num(n)}</span><small>${it.tier || 1}단계${why ? ` · <span class="bad">${esc(why)}</span>` : ''}</small></div>
        <div class="item-act"><button class="btn small" data-dis="${esc(k)}" ${why ? 'disabled' : ''}>분해</button></div></li>`; }).join('')}</ul>`
    : empty('분해할 장비가 없습니다.', 'bag');
  body.innerHTML += `<p class="muted small">장비를 부수어 제작 재료 일부(제작법 재료의 절반)를 돌려받고 제작 경험을 얻습니다. 단계마다 필요한 제작 숙련: 1단계 1 · 2단계 4 · 3단계 8 · 4단계 12 · 5단계 16. 강화한 무기를 분해하면 강화도 사라집니다.</p>`;
  bindInfo(body);
  $$('[data-dis]', body).forEach(b => b.onclick = async () => {
    if (!await ask(`${nameOf(b.dataset.dis)} 하나를 분해할까요? 되돌릴 수 없습니다.`, { title: '분해', ok: '분해하기' })) return;
    await guard(b, () => act('world_dismantle_item', { p_item_id: b.dataset.dis }));
    dismantlePane(body);
  });
}

// 물품 고르기(거래소 등록·직접 거래): 분류 칩 + 이름 검색 + 가나다순 목록. 입력칸은 다시 그리지 않아 한글 조합이 깨지지 않는다.
const PICK_GEAR = new Set(['weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool', 'accessory', 'equipment']);
const PICK_CATS = [['all', '전체'], ['gear', '장비'], ['consumable', '소모품'], ['material', '재료'], ['etc', '기타']];
const pickCat = c => !c ? 'etc' : PICK_GEAR.has(c) ? 'gear' : c === 'consumable' ? 'consumable' : /material/.test(c) ? 'material' : 'etc';
function pickerHtml(name, opts) {
  return `<div class="pick" data-pick="${name}"><div class="pick-cats">${PICK_CATS.map(([k, t]) => `<button type="button" class="chip ${k === 'all' ? 'accent' : ''}" data-pc="${k}">${t}</button>`).join('')}</div>
    <input type="search" class="pick-q" placeholder="이름으로 찾기" aria-label="물품 찾기">
    <select name="${name}" aria-label="물품">${opts.map(o => `<option value="${esc(o.id)}">${esc(o.label)}</option>`).join('')}</select><small class="pick-n muted">${opts.length}가지</small></div>`;
}
// opts: [{id, label, cat}] (가나다순), onPick: 고른 물품이 바뀌면
function bindPicker(root, name, opts, onPick) {
  const box = $(`[data-pick="${name}"]`, root); if (!box) return;
  const sel = box.querySelector('select'), qi = box.querySelector('.pick-q'), n = box.querySelector('.pick-n');
  let cat = 'all';
  const apply = () => {
    const q = qi.value.trim().toLowerCase(), keep = sel.value;
    const list = opts.filter(o => (cat === 'all' || o.cat === cat) && (!q || o.label.toLowerCase().includes(q)));
    sel.innerHTML = list.map(o => `<option value="${esc(o.id)}">${esc(o.label)}</option>`).join('') || '<option value="">맞는 물품이 없습니다</option>';
    if (list.some(o => o.id === keep)) sel.value = keep;
    n.textContent = `${list.length}가지`;
    if (sel.value !== keep) onPick?.();
  };
  qi.addEventListener('input', e => { if (!e.isComposing) apply(); });
  qi.addEventListener('compositionend', apply);
  box.querySelectorAll('[data-pc]').forEach(b => b.onclick = () => { cat = b.dataset.pc; box.querySelectorAll('[data-pc]').forEach(x => x.classList.toggle('accent', x === b)); apply(); });
}
const koSort = (a, b) => a.label.localeCompare(b.label, 'ko');
// 목록에 안 보이는 가진 물품의 까닭: 거래 불가(희귀 성장 재료 등)·잠금
function untradeNote(have, ref) {
  const own = Object.entries(have || {}).filter(([, n]) => Number(n) > 0).map(([k]) => k);
  const bound = own.filter(k => ref.get(k)?.tradeable === false).map(nameOf).sort((a, b) => a.localeCompare(b, 'ko'));
  const locked = own.filter(k => ref.get(k)?.tradeable !== false && isLocked(k)).map(nameOf).sort((a, b) => a.localeCompare(b, 'ko'));
  const part = (t, l) => l.length ? `<b>${t}</b> ${esc(l.slice(0, 8).join(' · '))}${l.length > 8 ? ` 외 ${l.length - 8}가지` : ''}` : '';
  const txt = [part('거래 불가', bound), part('잠금', locked)].filter(Boolean).join(' / ');
  return txt ? `<p class="muted small untrade">${icon('help', 13)} 목록에 없는 물품 — ${txt}. 거래 불가 물품(희귀 성장 재료·귀속품 등)은 거래소·직접 거래에 올릴 수 없고, 잠근 물품은 가방에서 잠금을 풀면 올라옵니다.</p>` : '';
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
    const [{ data: offers, error }, prices, , inv] = await Promise.all([
      db.from('world_trade_offers').select('offer_id,seller_id,item_id,quantity,unit_price,status,created_at,expires_at').eq('status', 'open').order('created_at', { ascending: false }).limit(60),
      load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => []), loadLocks(), load('world_inventory_snapshot', undefined, { maxAge: 30000 }).catch(() => null),
    ]);
    const catMap = new Map((inv?.catalog || []).map(i => [i.id, pickCat(i.category)]));
    if (error) throw new Error(error.message);
    const c = store.character, me = c.owner_id, have = c.inventory || {};
    const ref = new Map((prices || []).map(p => [p.item_id, p]));
    const tradeable = Object.entries(have).filter(([k, n]) => n > 0 && ref.get(k)?.tradeable !== false && !isLocked(k))
      .sort(([a], [b]) => nameOf(a).localeCompare(nameOf(b), 'ko'));
    const sellOpts = tradeable.map(([k, n]) => ({ id: k, label: `${nameOf(k)} (${n})`, cat: catMap.get(k) || 'etc' }));
    const hiddenNote = untradeNote(have, ref);
    const mine = (offers || []).filter(o => o.seller_id === me), others = (offers || []).filter(o => o.seller_id !== me);
    const row = (o, own) => `<li><div class="item-main"><b>${infoName(o.item_id)}</b><span class="qty">×${o.quantity}</span>
        <small>개당 ${fmt.jeon(o.unit_price)} · 합계 ${fmt.jeon(o.unit_price * o.quantity)}${ref.get(o.item_id) ? ` · 기준가 ${fmt.jeon(ref.get(o.item_id).reference_price)}` : ''}</small></div>
        <div class="item-act">${own ? `<button class="btn small" data-cancel="${o.offer_id}">등록 취소</button>` : `<button class="btn small primary" data-take="${o.offer_id}">사기</button>`}</div></li>`;
    body.innerHTML = `
      ${tradeable.length ? `<form class="form-grid trade-form" id="trade-form">
          <div class="field"><span>물품</span>${pickerHtml('item', sellOpts)}</div>
          <label class="field"><span>수량</span><input name="qty" type="number" min="1" value="1"></label>
          <label class="field"><span>개당 가격(전)</span><input name="price" type="number" min="1" value="${ref.get(tradeable[0][0])?.reference_price || 10}"></label>
          <button class="btn primary" type="submit" ${mine.length >= 10 ? 'disabled' : ''}>${icon('plus', 16)}<span>판매 등록</span></button></form>
          <p class="muted small" id="trade-hint"></p>` : empty('거래할 수 있는 물품이 없습니다.', 'coin')}
      ${hiddenNote}
      <p class="muted small">한 사람이 동시에 <b>10건</b>까지 올려 둘 수 있습니다(지금 ${mine.length}/10건). 0전 등록은 불가하며, 희귀 성장 물품·잠근 물품·장착 중인 마지막 한 개는 올릴 수 없습니다. 등록한 물품은 팔리거나 취소할 때까지 가방에서 빠집니다.</p>
      <h3 class="sub-h">판매 중 ${others.length}</h3>
      ${others.length ? `<ul class="item-list">${others.map(o => row(o, false)).join('')}</ul>` : empty('다른 조사원이 등록한 물품이 없습니다.', 'shop')}
      <h3 class="sub-h">내 등록 ${mine.length}</h3>
      ${mine.length ? `<ul class="item-list">${mine.map(o => row(o, true)).join('')}</ul>` : `<p class="muted small">등록한 물품이 없습니다.</p>`}`;
    const form = $('#trade-form', body);
    if (form) {
      const hint = () => { const r = ref.get(form.item.value); $('#trade-hint', body).textContent = r?.reference_price ? `기준 시세 ${fmt.jeon(r.reference_price)} · 최대 ${fmt.jeon(r.reference_price * 10)}` : ''; };
      form.item.onchange = () => { const p = ref.get(form.item.value)?.reference_price; if (p) form.price.value = p; hint(); };
      bindPicker(form, 'item', sellOpts, () => form.item.onchange());
      hint();
      form.onsubmit = e => {
        e.preventDefault();
        const qty = Math.floor(Number(form.qty.value)), price = Math.floor(Number(form.price.value));
        if (!(qty >= 1) || !(price >= 1)) return toast('수량과 가격은 1 이상이어야 합니다.', 'error');
        if (mine.length >= 10) return toast('거래소에는 동시에 10건까지 올려 둘 수 있습니다. 팔리거나 취소된 뒤 다시 등록하세요.', 'error');
        if (!form.item.value) return toast('올릴 물품을 고르세요.', 'error');
        guard(form.querySelector('[type=submit]'), () => act('world_trade_offer_create', { p_item_id: form.item.value, p_qty: qty, p_unit_price: price }));
      };
    }
    $$('[data-take]', body).forEach(b => b.onclick = async () => { if (await ask('이 물품을 살까요?', { title: '거래소 구매', ok: '사기' })) guard(b, () => act('world_trade_offer_buy', { p_offer_id: b.dataset.take })); });
    $$('[data-cancel]', body).forEach(b => b.onclick = () => guard(b, () => act('world_trade_offer_cancel', { p_offer_id: b.dataset.cancel })));
    bindInfo(body);
  } catch (e) { body.innerHTML = errorBox(e.message); }
}

// 직접 거래: 받는 사람 · 내가 줄 것(물품·전) · 받을 것(물품·전) → 제안. 상대가 수락하면 서버가 한 번에 맞바꾼다.
let dt = { to: '', give: {}, giveGil: 0, want: {}, wantGil: 0 };
const bundle = (items, gil) => [...Object.entries(items || {}).map(([k, n]) => `${nameOf(k)} ×${n}`), gil > 0 ? fmt.jeon(gil) : ''].filter(Boolean).join(', ') || '없음';
async function renderDirect(body) {
  try {
    const [roster, prices, pending, , inv] = await Promise.all([load('world_region_roster', undefined, { maxAge: 10000 }).catch(() => []),
      load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => []), load('world_trade_direct_snapshot').catch(() => []), loadLocks(),
      load('world_inventory_snapshot', undefined, { maxAge: 30000 }).catch(() => null)]);
    const catMap = new Map((inv?.catalog || []).map(i => [i.id, pickCat(i.category)]));
    const c = store.character, have = c.inventory || {};
    const ref = new Map((prices || []).map(p => [p.item_id, p]));
    // 직접 거래는 같은 곳에 있는 조사원과(5.0.0부터 안전지대 밖에서도)
    const people = (roster || []).filter(p => !p.is_dead);
    const mineTradeable = Object.entries(have).filter(([k, n]) => n > 0 && ref.get(k)?.tradeable !== false && !isLocked(k));
    const anyTradeable = (prices || []).filter(p => p.tradeable !== false).sort((a, b) => (a.item_name || '').localeCompare(b.item_name || '', 'ko'));
    const hiddenNote = untradeNote(have, ref);
    const giveOpts = mineTradeable.map(([k, n]) => ({ id: k, label: `${nameOf(k)} (${n})`, cat: catMap.get(k) || 'etc' })).sort(koSort);
    const wantOpts = anyTradeable.map(p => ({ id: p.item_id, label: p.item_name || nameOf(p.item_id), cat: catMap.get(p.item_id) || 'etc' }));
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
          ${pickerHtml('giveItem', giveOpts)}<div class="dt-add"><input name="giveQty" type="number" min="1" value="1" aria-label="수량"><button class="btn small" type="button" data-add="give" ${mineTradeable.length ? '' : 'disabled'}>담기</button></div>
          ${hiddenNote}<label class="field"><span>줄 전 (가진 ${fmt.jeon(c.gil)})</span><input name="giveGil" type="number" min="0" value="${dt.giveGil}"></label></fieldset>
        <fieldset class="dt-side"><legend>받을 것</legend>
          <div class="chips">${chipList(dt.want, 'want')}</div>
          ${pickerHtml('wantItem', wantOpts)}<div class="dt-add"><input name="wantQty" type="number" min="1" value="1" aria-label="수량"><button class="btn small" type="button" data-add="want">담기</button></div>
          <label class="field"><span>받을 전</span><input name="wantGil" type="number" min="0" value="${dt.wantGil}"></label></fieldset>
        <button class="btn primary block" type="submit">${icon('coin', 16)}<span>거래 제안 보내기</span></button>
      </form>` : empty('같은 곳에 거래할 조사원이 없습니다. 상대와 같은 곳에 있어야 합니다(안전지대가 아니어도 됩니다).', 'users')}
      ${out.length ? `<h3 class="sub-h">보낸 제안 ${out.length}</h3><ul class="spot-list">${out.map(t => `<li><div><b>${esc(t.other_name)}님에게</b><small>줄 것: ${esc(bundle(t.give_items, t.give_gil))}</small><small>받을 것: ${esc(bundle(t.want_items, t.want_gil))}</small></div>
        <button class="btn small" data-dt-cancel="${esc(t.trade_id)}">거두기</button></li>`).join('')}</ul>` : ''}
      <p class="muted small">상대와 같은 곳에만 있으면 안전지대 밖에서도 거래할 수 있습니다. 상대가 수락하면 서버가 양쪽 가방과 전을 한 번에 맞바꿉니다. 전을 받는 쪽은 거래세 5%를 냅니다(수향연맹은 등급에 따라 덜 냄). 제안은 30분 동안 유효하고, 응답 대기는 3건까지입니다. 잠근 물품·장착 중인 마지막 한 개·거래 불가 물품은 줄 수 없습니다.</p>`;
    const f = $('#dt-form', body);
    if (f) {
      f.to.onchange = () => { dt.to = f.to.value; };
      bindPicker(f, 'giveItem', giveOpts); bindPicker(f, 'wantItem', wantOpts);
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
      f.onsubmit = async e => {
        e.preventDefault();
        if (!dt.to) return toast('거래할 조사원을 고르세요.', 'error');
        if (!Object.keys(dt.give).length && !dt.giveGil && !Object.keys(dt.want).length && !dt.wantGil) return toast('주거나 받을 것을 하나 이상 담으세요.', 'error');
        if (dt.giveGil > c.gil) return toast('가진 전보다 많이 줄 수 없습니다.', 'error');
        const who = people.find(p => p.owner_id === dt.to)?.character_name || '상대';
        if (!(await ask(`${who}님에게 제안할까요?
줄 것: ${bundle(dt.give, dt.giveGil)}
받을 것: ${bundle(dt.want, dt.wantGil)}`, { title: '직접 거래 제안', ok: '제안하기' }))) return;
        guard(f.querySelector('[type=submit]'), async () => {
          const r = await act('world_trade_direct_offer', { p_to: dt.to, p_give: dt.give, p_give_gil: dt.giveGil, p_want: dt.want, p_want_gil: dt.wantGil });
          dt = { to: dt.to, give: {}, giveGil: 0, want: {}, wantGil: 0 };
          return r;
        });
      };
    }
    $$('[data-rm]', body).forEach(b => b.onclick = e => { e.preventDefault(); const [side, id] = b.dataset.rm.split(':'); delete dt[side][id]; renderDirect(body); });
    $$('[data-dt-acc]', body).forEach(b => b.onclick = async () => { if (await ask('이 거래를 받아들일까요? 바로 맞바꿉니다.', { title: '거래 수락', ok: '받아들이기' })) guard(b, () => act('world_trade_direct_respond', { p_trade_id: b.dataset.dtAcc, p_accept: true })); });
    $$('[data-dt-dec]', body).forEach(b => b.onclick = () => guard(b, () => act('world_trade_direct_respond', { p_trade_id: b.dataset.dtDec, p_accept: false })));
    $$('[data-dt-cancel]', body).forEach(b => b.onclick = () => guard(b, () => act('world_trade_direct_cancel', { p_trade_id: b.dataset.dtCancel })));
  } catch (e) { body.innerHTML = errorBox(e.message); }
}

// 조사원 카드의 [거래 제안]: 거래소 창을 직접 거래 칸으로 열고 상대를 미리 고른다
export function openDirectTrade(to) {
  marketMode = 'direct'; dt = { to, give: {}, giveGil: 0, want: {}, wantGil: 0 };
  const m = openModal({ title: '거래소', wide: true, body: '<div class="fac-body"></div>' });
  const box = $('.fac-body', m);
  renderMarket(box);
  const offc = on('changed', () => { if (box.isConnected) renderMarket(box); else offc(); });
}

/* ── 창고 ─────────────────────────────────────────────── */
// 어느 안전지대에서 열어도 같은 개인 창고. 기본 30칸이고 전·이야기 6~10장·세력 평판·지역 완전 답사로 넓어진다(서버 world_storage_capacity).
let storeMode = 'put';
const STORE_PRICES = [1000, 2500, 5000, 10000];
export async function renderStorage(box) {
  box.innerHTML = loading();
  try {
    const [s] = await Promise.all([load('world_storage_snapshot'), loadLocks()]);
    const c = store.character, have = c?.inventory || {};
    const src = s.sources || {}, steps = Number(src.bought_steps || 0);
    // 안전지대 밖·이동·원정·자율 중에는 보기만 한다(서버 can_move)
    const ro = !s.can_move, mode = ro && storeMode === 'put' ? 'take' : storeMode;
    const equippedSet = new Set(equippedIds());
    const putMax = k => Math.max(0, (Number(have[k]) || 0) - (equippedSet.has(k) ? 1 : 0));
    const putList = Object.entries(have).filter(([k, n]) => n > 0 && putMax(k) > 0);
    const bagSpace = bagLimit(c) - bagUsed(c);
    const row = (id, label, n, max, m, note) => `<li>
        <div class="item-main"><b>${infoName(id, label)}</b><span class="qty">×${fmt.num(n)}</span>${note ? `<small>${note}</small>` : ''}</div>
        ${ro ? '' : `<div class="row-act"><input type="number" inputmode="numeric" min="1" max="${max}" value="${max}" aria-label="수량" ${max ? '' : 'disabled'}>
          <button class="btn small ${m === 'put' ? '' : 'primary'}" data-${m}="${esc(id)}" ${max ? '' : 'disabled'}>${m === 'put' ? '맡기기' : '꺼내기'}</button></div>`}</li>`;
    const parts = [['기본', src.base], ['전으로 넓힘', src.bought], ['이야기', src.story], ['세력 평판', src.faction], ['지역 답사', src.survey]]
      .filter(([, v]) => Number(v) > 0).map(([n, v]) => `${n} ${v}`).join(' · ');
    box.innerHTML = `
      <div class="shop-head"><div><b>개인 창고</b><small>어느 안전지대에서 열어도 같은 창고입니다 · ${esc(parts)}</small></div>
        <span class="chip ${s.used >= s.capacity ? 'warn' : 'accent'}">${icon('chest', 14)} ${s.used} / ${s.capacity}칸</span></div>
      ${bar(s.used, s.capacity, s.used >= s.capacity ? 'enemy' : 'xp')}
      ${ro ? `<p class="notice-line">${icon('chest', 14)} 보기만 할 수 있습니다 · ${esc(s.reason || '넣고 꺼내기는 안전지대에서만 됩니다.')}</p>` : ''}
      <div class="seg-mini" role="tablist">${ro ? '' : `<button class="${mode === 'put' ? 'on' : ''}" data-mode="put">맡기기</button>`}<button class="${mode === 'take' ? 'on' : ''}" data-mode="take">${ro ? '보관 물품' : '꺼내기'}</button><button class="${mode === 'grow' ? 'on' : ''}" data-mode="grow">넓히기</button></div>
      <section data-list="put" ${mode === 'put' ? '' : 'hidden'}>
        <p class="muted small">창고 여유 ${Math.max(0, s.capacity - s.used)}칸 · 칸은 가방과 같이 묶음으로 셉니다. 장착 중인 마지막 하나·강화한 장비의 마지막 하나·임무 물품은 맡길 수 없습니다.</p>
        <ul class="item-list shop-list">${putList.map(([k, n]) => row(k, null, n, putMax(k), 'put', equippedSet.has(k) ? '장착 중 하나는 남김' : (isLocked(k) ? '잠금' : ''))).join('') || `<li>${empty('맡길 물품이 없습니다.', 'bag')}</li>`}</ul>
      </section>
      <section data-list="take" ${mode === 'take' ? '' : 'hidden'}>
        ${ro ? '' : `<p class="muted small">가방 여유 ${Math.max(0, bagSpace)}칸 · 가방에 들어가는 만큼만 꺼냅니다.</p>`}
        <ul class="item-list shop-list">${(s.items || []).map(i => row(i.item_id, i.name, i.qty, Math.min(i.qty, i.room), 'take', !ro && i.room <= 0 ? '<span class="bad">가방에 자리가 없습니다</span>' : '')).join('') || `<li>${empty('창고가 비어 있습니다.', 'chest')}</li>`}</ul>
      </section>
      <section data-list="grow" ${mode === 'grow' ? '' : 'hidden'}>
        <ul class="spot-list">
          <li><div><b>전으로 넓히기</b><small>4번까지 +4칸씩 · ${STORE_PRICES.map((p, i) => `<span class="${i < steps ? 'ok' : ''}">${fmt.num(p)}전</span>`).join(' → ')} · 넓힌 횟수 ${steps}/4</small></div>
            ${steps >= 4 ? chip('다 넓힘', 'ok') : `<button class="btn small primary" id="st-grow" ${ro || (c?.gil ?? s.gil) < src.next_price ? 'disabled' : ''}>+4칸 · ${fmt.jeon(src.next_price)}</button>`}</li>
          <li><div><b>이야기 6~10장</b><small>장을 해결할 때마다 +2칸 (최대 +10)</small></div>${chip(`+${src.story || 0}`, src.story ? 'ok' : '')}</li>
          <li><div><b>대세력 평판</b><small>평판 300·600·1000에서 +2칸씩 (최대 +6) · 세력을 떠나면 사라집니다</small></div>${chip(`+${src.faction || 0}`, src.faction ? 'ok' : '')}</li>
          <li><div><b>지역 완전 답사</b><small>10·20·30곳에서 +2칸씩 (최대 +6) · 지금 ${src.surveyed || 0}곳</small></div>${chip(`+${src.survey || 0}`, src.survey ? 'ok' : '')}</li>
        </ul>
        <p class="muted small">용량이 줄어 창고가 넘쳐도 물품은 그대로 남고, 새로 맡기기만 막힙니다.</p>
      </section>`;
    $$('.seg-mini button[data-mode]', box).forEach(b => b.onclick = () => {
      storeMode = b.dataset.mode;
      $$('.seg-mini button[data-mode]', box).forEach(x => x.classList.toggle('on', x === b));
      $$('[data-list]', box).forEach(l => l.hidden = l.dataset.list !== storeMode);
    });
    const move = (b, fn, id) => guard(b, () => {
      const q = Math.floor(Number(b.closest('li').querySelector('input')?.value) || 0);
      return act(fn, { p_item: id, p_qty: q > 0 ? q : null });
    });
    $$('[data-put]', box).forEach(b => b.onclick = () => move(b, 'world_storage_put', b.dataset.put));
    $$('[data-take]', box).forEach(b => b.onclick = () => move(b, 'world_storage_take', b.dataset.take));
    const g = $('#st-grow', box);
    if (g) g.onclick = async () => { if (await ask(`${fmt.jeon(src.next_price)}을 내고 창고를 4칸 넓힐까요?`, { title: '창고 넓히기', ok: '넓히기' })) guard(g, () => act('world_storage_expand')); };
    bindInfo(box);
  } catch (e) { box.innerHTML = errorBox(e.message); }
}

// 가방 화면 등 어디서나 여는 창고 창(안전지대 밖에서는 보기만)
export function openStorage() {
  const m = openModal({ title: '창고', wide: true, body: '<div class="fac-body"></div>' });
  const box = $('.fac-body', m);
  renderStorage(box);
  const offc = on('changed', () => { if (box.isConnected) renderStorage(box); else offc(); });
}

/* ── 마구간 ───────────────────────────────────────────── */
export async function renderStable(box) {
  box.innerHTML = loading();
  try {
    const m = await load('world_mount_snapshot');
    const here = (m.mounts || []).filter(x => x.at_stable && x.acquire_method !== 'faction'); // 세력 탈것은 비고에서만
    const c = store.character;
    // 단련: 가진 탈것을 노정패로 1~5단계까지 단련한다(단계마다 이동 속도 +4%, 값 20×다음 단계)
    const mine = (m.mounts || []).filter(x => x.owned);
    const tokens = Number(m.mount_tokens || 0);
    const train = mine.length ? `<h3 class="sub-h">탈것 단련 <small class="muted">가진 노정패 ${tokens}개 · 단계마다 이동 속도 +4% (최고 5단계)</small></h3>
      <ul class="spot-list train-list">${mine.map(x => { const lv = Number(x.training || 0), cost = 20 * (lv + 1);
        return `<li><div><b>${esc(x.mount_name)}${x.equipped ? ' · 타는 중' : ''}</b><small>단련 ${lv}/5 · 이동 속도 +${lv * 4}%</small></div>
          ${lv >= 5 ? chip('단련 완료', 'ok') : `<button class="btn small" data-train="${esc(x.mount_id)}" ${tokens < cost ? 'disabled' : ''}>노정패 ${cost}개로 단련</button>`}</li>`; }).join('')}</ul>` : '';
    box.innerHTML = train + (here.length ? `<h3 class="sub-h">들일 수 있는 탈것</h3>` : '') + (here.length ? `<div class="mount-grid">${here.map(x => `<article class="mount ${x.owned ? 'on' : ''}">
        <header><b>${esc(x.mount_name)}</b>${chip(x.tier)}</header><p>${esc(x.description || '')}</p>
        <dl class="kv tight"><div><dt>속도</dt><dd>×${x.speed_multiplier}</dd></div><div><dt>정원</dt><dd>${x.passenger_capacity}명</dd></div><div><dt>운임</dt><dd>${x.fare_free ? '없음' : `구간당 노정패 ${x.fare_tokens}`}</dd></div></dl>
        <small class="muted">${esc(conditions(x, c))}</small>
        ${x.owned ? chip('보유 중', 'ok') : `<button class="btn small primary" data-buy="${esc(x.mount_id)}">${fmt.jeon(x.price)}에 들이기</button>`}</article>`).join('')}</div>`
      : (mine.length ? '' : empty('이 마구간에서 들일 수 있는 탈것이 없습니다.', 'route')));
    $$('[data-train]', box).forEach(b => b.onclick = () => guard(b, async () => { const out = await act('world_mount_train', { p_mount_id: b.dataset.train }); renderStable(box); return out; }));
    $$('[data-buy]', box).forEach(b => b.onclick = async () => { if (await ask('이 탈것을 들일까요?', { title: '탈것 들이기', ok: '들이기' })) guard(b, () => act('world_mount_acquire', { p_mount_id: b.dataset.buy })); });
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
