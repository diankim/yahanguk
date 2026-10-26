// 의뢰: 상점 · 거래소 · 세력(임무·보급·대세력·거점) · 사건 조사 · 파티.
import { db, store, on, act, nameOf, esc, icon, guard, $, $$, fmt, empty, segmented, bindSegmented, openModal, h, toast } from '../core.js';
import { load, panel, chip, loading, errorBox, MAJOR_FACTIONS, itemsText } from './common.js';

const SUBS = [['shop', '상점'], ['market', '거래소'], ['faction', '세력'], ['case', '사건'], ['party', '파티']];
let el, sub = 'shop', off = [];

export async function render(root, s) {
  if (!store.character) return;
  el = root; sub = SUBS.some(x => x[0] === s) ? s : 'shop';
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('scroll', 14)} 임무와 경제</p><h1>의뢰</h1></div></div>
    ${segmented('q-sub', SUBS, sub)}<div id="q-body"></div>`;
  bindSegmented(el, 'q-sub', k => { sub = k; history.replaceState(null, '', `#/quest/${k}`); draw(); });
  off.forEach(f => f()); off = [on('changed', () => draw(true))];
  await draw();
}
export function destroy() { off.forEach(f => f()); off = []; }

async function draw(soft) {
  const body = $('#q-body', el); if (!body) return;
  if (!soft) body.innerHTML = loading();
  try { await ({ shop, market, faction, case: cases, party })[sub](body); }
  catch (e) { body.innerHTML = errorBox(e.message); }
}

/* ── 상점 (지도·현장에서도 열 수 있도록 모달로도 제공) ─────────────── */
export function openShop() {
  const box = h(`<div class="shop-modal">${loading()}</div>`);
  openModal({ title: '상점', body: box, wide: true });
  const stop = on('changed', () => box.isConnected ? shop(box) : stop());
  shop(box).catch(e => { box.innerHTML = errorBox(e.message); });
}
async function shop(body) {
  const [s, prices] = await Promise.all([load('world_shop_snapshot'), load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => [])]);
  const have = store.character?.inventory || {};
  const sellRef = new Map((prices || []).map(p => [p.item_id, p]));
  const sellable = Object.entries(have).filter(([k, n]) => n > 0 && sellRef.get(k)?.npc_sell_price > 0);
  body.innerHTML = `
    <div class="shop-head"><div><b>${esc(s?.shop_name || '야행 상회')}</b><small>재고는 하루 세 번 새로 들어옵니다${s?.next_refresh ? ` · 다음 입고 ${fmt.time(s.next_refresh)}` : ''}</small></div>
      <span class="chip accent">${icon('coin', 14)} ${fmt.jeon(s?.gil ?? store.character?.gil)}</span></div>
    ${panel('구매', (s?.stock || []).length ? `<ul class="item-list">${s.stock.map(i => `<li>
      <div class="item-main"><b>${esc(i.item_name)}</b><span class="qty">${fmt.jeon(i.unit_price)}</span>
        <div class="chips">${chip(nameOf(i.category))}${chip(`T${i.tier}`)}${chip(`재고 ${i.stock}`, i.stock ? '' : 'bad')}</div><small>${esc(i.description || '')}</small></div>
      <div class="item-act qty-act"><input type="number" min="1" max="${i.stock}" value="1" aria-label="수량" ${i.stock ? '' : 'disabled'}>
        <button class="btn small primary" data-buy="${esc(i.item_id)}" ${i.stock ? '' : 'disabled'}>구매</button></div></li>`).join('')}</ul>`
      : empty('지금은 판매 중인 물품이 없습니다.', 'shop'), { ico: 'shop', cls: 'compact' })}
    ${panel('판매', sellable.length ? `<ul class="item-list">${sellable.map(([k, n]) => `<li>
      <div class="item-main"><b>${esc(nameOf(k))}</b><span class="qty">×${fmt.num(n)}</span><small>개당 ${fmt.jeon(sellRef.get(k).npc_sell_price)}에 매입</small></div>
      <div class="item-act qty-act"><input type="number" min="1" max="${n}" value="1" aria-label="수량"><button class="btn small" data-sell="${esc(k)}">판매</button></div></li>`).join('')}</ul>`
      : empty('상점에 팔 수 있는 물품이 없습니다.', 'coin'), { ico: 'coin', cls: 'compact' })}`;
  const qty = b => Math.max(1, Math.floor(Number(b.closest('li').querySelector('input').value) || 1));
  $$('[data-buy]', body).forEach(b => b.onclick = () => guard(b, () => act('world_shop_buy', { p_item_id: b.dataset.buy, p_qty: qty(b) })));
  $$('[data-sell]', body).forEach(b => b.onclick = () => guard(b, () => act('world_shop_sell', { p_item_id: b.dataset.sell, p_qty: qty(b) })));
}

/* ── 거래소 ─────────────────────────────────────────────── */
async function market(body) {
  const [{ data: offers, error }, prices] = await Promise.all([
    db.from('world_trade_offers').select('offer_id,seller_id,item_id,quantity,unit_price,status,created_at,expires_at').eq('status', 'open').order('created_at', { ascending: false }).limit(60),
    load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => []),
  ]);
  if (error) throw new Error(error.message);
  const me = store.character.owner_id, have = store.character.inventory || {};
  const ref = new Map((prices || []).map(p => [p.item_id, p]));
  const tradeable = Object.entries(have).filter(([k, n]) => n > 0 && ref.get(k)?.tradeable !== false);
  const mine = (offers || []).filter(o => o.seller_id === me), others = (offers || []).filter(o => o.seller_id !== me);
  const row = (o, own) => `<li><div class="item-main"><b>${esc(nameOf(o.item_id))}</b><span class="qty">×${o.quantity}</span>
      <small>개당 ${fmt.jeon(o.unit_price)} · 합계 ${fmt.jeon(o.unit_price * o.quantity)}${ref.get(o.item_id) ? ` · 기준가 ${fmt.jeon(ref.get(o.item_id).reference_price)}` : ''}</small></div>
      <div class="item-act">${own ? `<button class="btn small" data-cancel="${o.offer_id}">등록 취소</button>` : `<button class="btn small primary" data-take="${o.offer_id}">구매</button>`}</div></li>`;
  body.innerHTML = `
    ${panel('판매 등록', tradeable.length ? `<form class="form-grid trade-form" id="trade-form">
        <label class="field"><span>물품</span><select name="item">${tradeable.map(([k, n]) => `<option value="${esc(k)}">${esc(nameOf(k))} (${n})</option>`).join('')}</select></label>
        <label class="field"><span>수량</span><input name="qty" type="number" min="1" value="1"></label>
        <label class="field"><span>개당 가격(전)</span><input name="price" type="number" min="1" value="${ref.get(tradeable[0][0])?.reference_price || 10}"></label>
        <button class="btn primary" type="submit">${icon('plus', 16)}<span>등록</span></button></form>
        <p class="muted small">0전 등록은 불가합니다. 희귀 성장 물품은 거래할 수 없으며 서버에서 확인합니다. 등록한 물품은 판매 또는 취소될 때까지 가방에서 빠집니다.</p>`
      : empty('거래할 수 있는 물품이 없습니다.', 'coin'), { ico: 'plus' })}
    <div class="grid-2">
      ${panel(`판매 중인 물품 ${others.length}`, others.length ? `<ul class="item-list">${others.map(o => row(o, false)).join('')}</ul>` : empty('다른 조사원이 등록한 물품이 없습니다.', 'shop'), { ico: 'shop', cls: 'compact' })}
      ${panel(`내 등록 ${mine.length}`, mine.length ? `<ul class="item-list">${mine.map(o => row(o, true)).join('')}</ul>` : empty('등록한 물품이 없습니다.'), { ico: 'idcard', cls: 'compact' })}
    </div>`;
  const form = $('#trade-form', body);
  if (form) {
    form.item.onchange = () => { const p = ref.get(form.item.value)?.reference_price; if (p) form.price.value = p; };
    form.onsubmit = e => {
      e.preventDefault();
      const qty = Math.floor(Number(form.qty.value)), price = Math.floor(Number(form.price.value));
      if (!(qty >= 1) || !(price >= 1)) return toast('수량과 가격은 1 이상이어야 합니다.', 'error');
      guard(form.querySelector('button'), () => act('world_trade_offer_create', { p_item_id: form.item.value, p_qty: qty, p_unit_price: price }));
    };
  }
  $$('[data-take]', body).forEach(b => b.onclick = () => { if (confirm('이 물품을 구매할까요?')) guard(b, () => act('world_trade_offer_buy', { p_offer_id: b.dataset.take })); });
  $$('[data-cancel]', body).forEach(b => b.onclick = () => guard(b, () => act('world_trade_offer_cancel', { p_offer_id: b.dataset.cancel })));
}

/* ── 세력 ───────────────────────────────────────────────── */
async function faction(body) {
  const [missions, base] = await Promise.all([load('world_faction_mission_snapshot'), load('world_faction_base_snapshot').catch(() => null)]);
  const c = store.character;
  const mine = (missions || []).filter(m => m.faction_key === c.faction_key || m.eligible);
  const major = c.major_faction_id;
  body.innerHTML = `
    <div class="grid-2">
      ${panel(`${nameOf(c.faction_key)} 임무`, mine.length ? `<ul class="mission-list">${mine.map(m => {
        const done = m.progress >= m.target_count;
        return `<li><div><b>${esc(m.title)}</b><small>${esc(m.description || '')}</small>
          <div class="mini-bar"><span style="width:${Math.min(100, m.progress / m.target_count * 100)}%"></span></div>
          <small class="muted">${Math.min(m.progress, m.target_count)}/${m.target_count} · 보상 경험치 ${m.reward_xp}${m.reward_items ? ' · ' + esc(itemsText(m.reward_items)) : ''}</small></div>
          ${m.claimed ? chip('완료', 'ok') : `<button class="btn small ${done ? 'primary' : ''}" data-mission="${esc(m.mission_id)}" ${done ? '' : 'disabled'}>${done ? '보상 받기' : '진행 중'}</button>`}</li>`; }).join('')}</ul>` : empty('진행할 수 있는 임무가 없습니다.'), { ico: 'scroll' })}
      ${panel('일일 보급', `<p class="desc">소속 부서에서 하루 한 번 보급품을 받을 수 있습니다.</p><button class="btn primary" id="supply">${icon('bag', 16)}<span>오늘 보급 받기</span></button>`, { ico: 'bag' })}
    </div>
    ${major ? panel(`${nameOf(major)} 거점`, `
        <p class="desc">${esc(MAJOR_FACTIONS[major]?.desc || '')}</p>
        <div class="chips">${chip(`평판 ${fmt.num(c.faction_reputation)}`, 'accent')}${chip(`거점: ${base?.base_region_name || nameOf(base?.base_region_id)}`)}${base?.at_base ? chip('거점에 있음', 'ok') : chip('거점 밖')}</div>
        ${(base?.contents || []).length ? `<ul class="mission-list">${base.contents.map(x => `<li><div><b>${esc(x.title)}</b><small>${esc(x.description || '')}</small><small class="muted">Lv.${x.min_level}+${x.reward ? ' · ' + esc(itemsText(x.reward.items || x.reward)) : ''}</small></div>
          ${x.used_today ? chip('오늘 완료') : `<button class="btn small" data-base="${esc(x.content_id)}" ${base.at_base && c.level >= x.min_level ? '' : 'disabled'}>수행</button>`}</li>`).join('')}</ul>
          ${base.at_base ? '' : `<p class="hint">${icon('pin', 14)} 거점 콘텐츠는 ${esc(base.base_region_name || '거점')}에 있을 때 이용할 수 있습니다.</p>`}` : empty('이용할 수 있는 거점 콘텐츠가 없습니다.')}`, { ico: 'shield' })
      : panel('대세력', `<p class="desc">대세력은 세계의 큰 흐름을 이끄는 조직입니다. 가입하면 전용 거점·임무·보상과 세력 채팅을 이용할 수 있습니다. 적대 세력 지역에서는 견제를 받을 수 있습니다.</p>
        <div class="faction-grid">${Object.entries(MAJOR_FACTIONS).map(([k, f]) => `<article class="faction">
          <header><b>${esc(f.name)}</b>${chip(f.type)}</header><p>${esc(f.desc)}</p><small class="muted">가입 조건: ${esc(f.entry)} · 거점 ${esc(nameOf(f.base))}</small>
          <button class="btn small" data-join="${k}">가입 신청</button></article>`).join('')}</div>`, { ico: 'shield' })}`;
  $$('[data-mission]', body).forEach(b => b.onclick = () => guard(b, () => act('world_faction_mission_action', { p_mission_id: b.dataset.mission })));
  const sup = $('#supply', body); sup.onclick = () => guard(sup, () => act('world_claim_faction_supply'));
  $$('[data-base]', body).forEach(b => b.onclick = () => guard(b, () => act('world_faction_base_action', { p_content_id: b.dataset.base })));
  $$('[data-join]', body).forEach(b => b.onclick = () => { if (confirm(`${MAJOR_FACTIONS[b.dataset.join].name}에 가입할까요? 가입 조건은 서버에서 확인합니다.`)) guard(b, () => act('world_join_major_faction', { p_faction_id: b.dataset.join })); });
}

/* ── 사건 조사: 단서를 모으고 조합해 원인을 추론한다 ─────────────── */
const CLUES = [
  ['redseal_footprints', '젖은 발자국', '흔적', 'hq_archive', '뒤꿈치가 깊다. 누군가 뒤로 걸어간 흔적이다.'],
  ['redseal_ink', '먹물 속 이름', '기록', 'hq_archive', '장부의 먹물은 오래된 피와 섞였다. 지워진 이름은 봉인의 매개체다.'],
  ['redseal_bell', '역행하는 방울', '소리', 'shrine_ruins', '방울 소리가 사당 벽 너머에서 울린다. 봉인식의 방향을 가리킨다.'],
  ['redseal_ash', '인장 재의 결', '재료', 'shrine_ruins', '인장 재와 부적 가루는 같은 봉인식에서 비롯되었다.'],
];
const COMBOS = [
  ['redseal_true_identity', '기록에서 지워진 이름', ['redseal_footprints', 'redseal_ink'], '발자국과 장부를 대조해 존재의 정체를 추론한다.'],
  ['redseal_reseal', '역행 봉인식', ['redseal_bell', 'redseal_ash'], '방울과 인장 재의 결을 맞춰 안전한 재봉인을 복원한다.'],
];
const ids = v => Array.isArray(v) ? v.map(x => typeof x === 'string' ? x : x?.clue_id || x?.id).filter(Boolean) : v && typeof v === 'object' ? Object.keys(v) : [];
async function cases(body) {
  const uid = store.character.owner_id;
  const [{ data, error }] = await Promise.all([
    db.from('world_case_progress').select('case_id,clues,combined').eq('owner_id', uid).in('case_id', ['red_seal', 'regional_discoveries']),
    load('world_map_snapshot', undefined, { maxAge: 60000 }).catch(() => null),
  ]);
  if (error) throw new Error(error.message);
  const red = (data || []).find(r => r.case_id === 'red_seal'), reg = (data || []).find(r => r.case_id === 'regional_discoveries');
  const got = new Set(ids(red?.clues)), combined = new Set(ids(red?.combined));
  const regClues = Array.isArray(reg?.clues) ? reg.clues.filter(x => x?.site_id) : [];
  const regRegions = new Set(regClues.map(x => x.region_id));
  const here = store.character.location;
  const solved = COMBOS.every(([k]) => combined.has(k));
  body.innerHTML = `
    ${panel('붉은 인장의 실종', `
      <p class="desc">지난 초하루 회수된 부적의 기록이 장부에서 사라졌습니다. 두 장소에서 단서를 모으고, 짝이 맞는 단서를 조합해 가설을 세우세요. 두 가설을 모두 확정하면 사건이 종결되고 보상(경험치 +50 · 영력 +10 · 요기 결정 ×2)을 한 번 받습니다.</p>
      <div class="chips">${chip(`단서 ${got.size}/4`, 'accent')}${chip(`가설 ${[...combined].filter(k => COMBOS.some(c => c[0] === k)).length}/2`)}${solved ? chip('사건 종결', 'ok') : ''}</div>
      <div class="clue-grid">${CLUES.map(([k, n, tag, reg, d]) => {
        const has = got.has(k), there = here === nameOf(reg) || here === reg;
        return `<article class="clue ${has ? 'on' : ''}"><header><b>${has ? esc(n) : '미확인 단서'}</b>${chip(tag)}</header>
          <p>${has ? esc(d) : `${esc(nameOf(reg))}에서 조사할 수 있습니다.`}</p>
          ${has ? chip('확보', 'ok') : `<button class="btn small ${there ? 'primary' : ''}" data-clue="${k}" ${there ? '' : 'disabled'}>${there ? '조사' : `${esc(nameOf(reg))}에서 조사`}</button>`}</article>`; }).join('')}</div>
      <h3 class="sub-h">가설 조합</h3>
      <div class="combo-grid">${COMBOS.map(([k, n, need, d]) => {
        const done = combined.has(k), ready = need.every(x => got.has(x));
        return `<article class="combo ${done ? 'on' : ''}"><b>${esc(n)}</b><p>${esc(d)}</p>
          <div class="combo-need">${need.map(x => `<span class="${got.has(x) ? 'ok' : ''}">${got.has(x) ? esc(CLUES.find(c => c[0] === x)[1]) : '?'}</span>`).join(icon('plus', 12))}</div>
          ${done ? chip('결론 확정', 'ok') : `<button class="btn small ${ready ? 'primary' : ''}" data-combo="${k}" ${ready ? '' : 'disabled'}>${ready ? '가설 확정' : '단서 부족'}</button>`}</article>`; }).join('')}</div>`, { ico: 'search' })}
    ${panel('지역 답사 보고서', `
      <p class="desc">현장의 탐사 지점을 조사하면 지역 단서가 기록됩니다. 서로 다른 3개 지역의 단서를 모으면 보고서를 제출해 보상을 받습니다.</p>
      <div class="chips">${chip(`단서 ${regClues.length}개`)}${chip(`지역 ${regRegions.size}/3`, regRegions.size >= 3 ? 'ok' : '')}</div>
      ${regRegions.size ? `<p class="muted small">기록된 지역: ${esc([...regRegions].map(nameOf).join(', '))}</p>` : ''}
      <button class="btn ${regRegions.size >= 3 ? 'primary' : ''}" id="reg-submit" ${regRegions.size >= 3 ? '' : 'disabled'}>${icon('scroll', 16)}<span>보고서 제출</span></button>`, { ico: 'map' })}`;
  $$('[data-clue]', body).forEach(b => b.onclick = () => guard(b, () => act('world_case_investigate', { p_clue_id: b.dataset.clue })));
  $$('[data-combo]', body).forEach(b => b.onclick = () => guard(b, () => act('world_case_combine', { p_combination_id: b.dataset.combo })));
  const rs = $('#reg-submit', body); if (rs) rs.onclick = () => guard(rs, () => act('world_case_combine_regional'));
}

/* ── 파티 ───────────────────────────────────────────────── */
const LOOT = [['contribution', '기여도순'], ['designated', '지정순'], ['equal', '균등 분배']];
async function party(body) {
  const [p, loot, cands] = await Promise.all([load('world_party_snapshot'), load('world_party_loot_snapshot').catch(() => null), load('world_party_candidates').catch(() => [])]);
  const me = store.character.owner_id, pt = p?.party;
  const isLeader = pt?.leader_id === me;
  const invites = (p?.invites || []).filter(i => i.invitee_id === me);
  if (!pt) {
    body.innerHTML = `
      ${invites.length ? panel('받은 초대', `<ul class="spot-list">${invites.map(i => `<li><div><b>${esc(i.party_name || '파티')}</b><small>파티 초대가 도착했습니다</small></div>
        <div class="btn-row"><button class="btn small primary" data-inv="${esc(i.invite_id)}" data-acc="1">수락</button><button class="btn small" data-inv="${esc(i.invite_id)}" data-acc="0">거절</button></div></li>`).join('')}</ul>`, { ico: 'users' }) : ''}
      ${panel('파티 만들기', `<p class="desc">파티를 맺으면 함께 이동(동승)하고, 파티 채팅과 전리품 분배를 쓸 수 있습니다. 혼자서도 모든 핵심 콘텐츠를 진행할 수 있습니다.</p>
        <form class="form-grid" id="party-form"><label class="field"><span>파티 이름</span><input name="name" maxlength="20" placeholder="예: 야간 순찰조" required></label><button class="btn primary" type="submit">${icon('plus', 16)}<span>만들기</span></button></form>`, { ico: 'users' })}`;
    const f = $('#party-form', body);
    f.onsubmit = e => { e.preventDefault(); const n = f.name.value.trim(); if (!n) return; guard(f.querySelector('button'), () => act('world_party_create', { p_party_name: n })); };
    bindInvites(body);
    return;
  }
  body.innerHTML = `
    <div class="grid-2">
      ${panel(pt.party_name, `<ul class="people">${(p.members || []).map(m => `<li><span class="avatar sm">${esc((m.character_name || '?')[0])}</span>
          <div><b>${esc(m.character_name)} ${m.role === 'leader' ? chip('파티장', 'accent') : ''}</b><small>Lv.${m.level} · ${esc(m.location)} · 체력 ${m.health}${m.in_combat ? ' · 전투 중' : ''}</small></div>
          ${m.downed ? (m.owner_id !== me ? `<button class="btn small primary" data-rescue="${esc(m.owner_id)}">구조</button>` : chip('전투불능', 'bad')) : ''}</li>`).join('')}</ul>
        ${isLeader && (cands || []).length ? `<form class="form-grid" id="invite-form"><label class="field"><span>초대할 조사원</span><select name="who">${cands.map(x => `<option value="${esc(x.owner_id)}">${esc(x.character_name)} (Lv.${x.level})</option>`).join('')}</select></label><button class="btn" type="submit">초대</button></form>` : ''}`, { ico: 'users' })}
      ${panel('전리품 분배', `
        <p class="muted small">현재 방식: <b>${esc(LOOT.find(x => x[0] === (loot?.method || pt.loot_distribution_method))?.[1] || '균등 분배')}</b> · 수령 가능 ${fmt.num(loot?.claimable_count)}건</p>
        ${isLeader ? `<div class="btn-row">${LOOT.map(([k, n]) => `<button class="btn small ${k === (loot?.method || pt.loot_distribution_method) ? 'primary' : ''}" data-method="${k}">${n}</button>`).join('')}</div>` : ''}
        ${(loot?.loot || []).length ? `<ul class="spot-list">${loot.loot.map(l => `<li><div><b>${esc(nameOf(l.item_id))} ×${l.quantity}</b><small>${l.status === 'available' ? '분배 대기' : '분배 완료'}</small></div>
          ${isLeader && l.status === 'available' ? `<button class="btn small" data-dist="${esc(l.loot_id)}">분배</button>` : ''}</li>`).join('')}</ul>` : empty('공동 전리품이 없습니다.', 'bag')}
        ${loot?.claimable_count ? `<button class="btn primary" id="loot-claim">${icon('check', 16)}<span>내 몫 받기</span></button>` : ''}
        <p class="muted small">지정순은 파티원 목록 순서(파티장 먼저)대로 우선권을 줍니다.</p>`, { ico: 'bag' })}
    </div>`;
  $('#invite-form', body)?.addEventListener('submit', e => { e.preventDefault(); guard(e.target.querySelector('button'), () => act('world_party_invite', { p_invitee_id: e.target.who.value })); });
  $$('[data-method]', body).forEach(b => b.onclick = () => guard(b, () => act('world_party_set_loot_distribution', { p_method: b.dataset.method, p_priority: b.dataset.method === 'designated' ? (p.members || []).map(m => m.owner_id) : [] })));
  $$('[data-dist]', body).forEach(b => b.onclick = () => guard(b, () => act('world_party_loot_distribute', { p_loot_id: b.dataset.dist })));
  $$('[data-rescue]', body).forEach(b => b.onclick = () => guard(b, () => act('world_rescue_character', { p_target: b.dataset.rescue })));
  const cl = $('#loot-claim', body); if (cl) cl.onclick = () => guard(cl, () => act('world_party_loot_claim'));
  bindInvites(body);
}
function bindInvites(body) {
  $$('[data-inv]', body).forEach(b => b.onclick = () => guard(b, () => act('world_party_respond', { p_invite_id: b.dataset.inv, p_accept: b.dataset.acc === '1' })));
}
