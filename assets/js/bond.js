// 연리(連理): 조사원끼리 맺는 연인 관계. 상대는 「정인」이라 부른다(서버 world_bond_*).
// 정표는 가방과 별개로 「정표 칸」에 착용·벗기를 하고, 둘 다 착용하고 같은 곳·같은 파티이면 연리의 기운(회복량 +5% · 침식 -5%)을 받는다.
// 동료 화면의 연리 칸, 조사원 카드의 [연리 맺기], 장비 목록의 정표 칸, 마음 전하기·선물·파기 창을 맡는다.
import { store, rpc, act, ask, esc, icon, guard, $, $$, fmt, openModal, closeModal, openLayer, closeLayers, nameOf, toast, MARKET_ONLY } from './core.js';
import { cardName } from './views/card.js';

// 정표 종류: [이름, 뜻, 그림(24×24 선)]
export const TOKENS = {
  knot: ['연리 매듭', '두 가닥을 엮어 풀리지 않게 맺은 매듭', 'M7 9a3 3 0 106 0 3 3 0 10-6 0M11 9a3 3 0 106 0 3 3 0 10-6 0M12 12v8M10 20h4'],
  jade: ['반쪽 옥패', '둘로 쪼개 하나씩 나눠 가진 옥패', 'M12 3a9 9 0 000 18zM12 8a4 4 0 000 8M12 3v18'],
  heart: ['동심결', '한마음으로 맺은 매듭', 'M12 20s-7-4.5-7-10a4 4 0 017-2.5A4 4 0 0119 10c0 5.5-7 10-7 10zM9 11h6'],
  ring: ['쌍가락지', '한 쌍으로 지은 은가락지', 'M9 14a4 4 0 100-8 4 4 0 000 8zM15 18a4 4 0 100-8 4 4 0 000 8z'],
  duck: ['원앙 노리개', '늘 짝지어 다니는 원앙을 새긴 노리개', 'M5 15c0-3 2-5 5-5 1-2 3-3 5-2-1 1-1 2-1 3 2 1 3 3 3 4H5zM12 19v3'],
  mirror: ['달 거울 조각', '한 거울을 둘로 나눈 달빛 조각', 'M12 3a8 8 0 108 8 6 6 0 01-8-8zM12 19v3'],
};
export const tokenSvg = (k, size = 22) => `<svg class="ico token-ico" viewBox="0 0 24 24" width="${size}" height="${size}" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="${TOKENS[k]?.[2] || TOKENS.knot[2]}"/></svg>`;
const STAGES = ['', '정을 나눔', '마음이 이어짐', '연리', '백년해로'];

let snap = null, loading = null;
export const bond = () => snap?.bond || null;
export const bondSnap = () => snap;
export async function loadBond(force) {
  if (snap && !force) return snap;
  if (loading) return loading;
  loading = rpc('world_bond_snapshot').then(s => { snap = s || {}; window.dispatchEvent(new CustomEvent('yh-bond', { detail: snap })); return snap; })
    .catch(() => snap || {}).finally(() => { loading = null; });
  return loading;
}
const refresh = () => loadBond(true);
const run = (b, fn, args, after) => guard(b, async () => { const r = await act(fn, args); await refresh(); after?.(); return r; });

/* ── 동료 화면의 연리 칸 ─────────────────────────────── */
export function bondPanelHtml(s) {
  const b = s?.bond, br = s?.broken, inc = s?.incoming || [], out = s?.outgoing;
  if (b) {
    const nextAt = b.next_at, pct = nextAt ? Math.min(100, Math.round(b.affinity / nextAt * 100)) : 100;
    return `
      <div class="bond-card">
        <div class="bond-token ${b.my_wear ? 'on' : ''}">${tokenSvg(b.token_key, 34)}</div>
        <div class="bond-main">
          <b>정인 · ${cardName(b.partner_id, b.partner_name)}</b>
          <small>${esc(b.token_name)} · 연리를 맺은 지 ${fmt.num(b.days + 1)}일째 · Lv.${b.partner_level || 1} · ${esc(b.partner_location || '')}</small>
          <div class="bond-stage"><span>인연 · ${esc(b.stage_name)}</span><span class="muted small">${fmt.num(b.affinity)}${nextAt ? ` / ${fmt.num(nextAt)}` : ''} · 오늘 +${b.gain_today}/30</span></div>
          <div class="bar xp"><span style="width:${pct}%"></span></div>
          <p class="small ${b.together ? 'ok' : 'muted'}">${b.together ? '연리의 기운: 회복량 +5% · 침식 -5%' : '연리의 기운은 둘 다 정표를 착용하고 같은 곳·같은 파티일 때 생깁니다.'}</p>
        </div>
      </div>
      <div class="bond-acts">
        <button class="btn small" data-bond="wear">${b.my_wear ? '정표 벗기' : '정표 착용'}</button>
        <button class="btn small" data-bond="hide">${b.my_hide ? '연리 보이기' : '연리 숨기기'}</button>
        <button class="btn small primary" data-bond="gift" ${b.gifted_today ? 'disabled' : ''}>${icon('plus', 14)}<span>${b.gifted_today ? '오늘 선물함' : '선물 보내기'}</span></button>
        <button class="btn small ghost danger-text" data-bond="break">정표 파기</button>
      </div>
      <p class="muted small">인연은 정인과 같은 파티로 함께 토벌(+1)·하루 한 번 안부 귓속말(+3${b.greeted_today ? ', 오늘 함' : ''})·선물(+5)·구조(+10)로 하루 30까지 오릅니다. 마음이 이어짐(100)·연리(300)·백년해로(700)에 이르면 둘 다 꾸미기를 받습니다. 정인을 구조하면 체력 50으로 일어납니다.${b.partner_hide || b.my_hide ? ' 지금은 다른 조사원에게 연리가 보이지 않습니다.' : ''}</p>`;
  }
  return `
    ${br ? `<div class="bond-card broken"><div class="bond-token">${tokenSvg(br.token_key, 34)}</div><div class="bond-main"><b>깨진 정표 · ${esc(br.token_name)}</b>
      <small>${esc(br.partner_name || '정인')}님이 정표를 파기해 연리가 끝났습니다 (${fmt.time(br.ended_at)}, 함께한 날 ${fmt.num(br.days + 1)}일).</small></div>
      <button class="btn small" data-bond="clear">정리하기</button></div>` : ''}
    ${inc.length ? `<h3 class="sub-h">받은 마음 ${inc.length}</h3><ul class="spot-list">${inc.map(r => `<li><div class="bond-req">${tokenSvg(r.token_key, 26)}<div><b>${cardName(r.from_id, r.from_name)}님이 「${esc(r.token_name)}」을(를) 건넸습니다</b>
      <small>${r.message ? `“${esc(r.message)}” · ` : ''}${fmt.remain(new Date(r.expires_at) - Date.now())} 남음</small></div></div>
      <div class="btn-row"><button class="btn small primary" data-bond-acc="${esc(r.request_id)}">받기</button><button class="btn small" data-bond-dec="${esc(r.request_id)}">돌려보내기</button></div></li>`).join('')}</ul>` : ''}
    ${out ? `<p class="hint">${tokenSvg(out.token_key, 18)} ${esc(out.to_name || '상대')}님에게 「${esc(out.token_name)}」을(를) 건네고 답을 기다립니다 · ${fmt.remain(new Date(out.expires_at) - Date.now())} 남음 <button class="btn small ghost" data-bond="cancel">거두기</button></p>` : ''}
    ${!inc.length && !out ? `<p class="muted small">아직 정인이 없습니다. 친구의 조사원 카드에서 [연리 맺기]로 정표를 건네 마음을 전할 수 있습니다(둘 다 Lv.5 이상, 정표 짓는 값 300전 · 거절되거나 24시간이 지나면 돌려받음).</p>` : ''}
    ${s?.cooldown_until && new Date(s.cooldown_until) > new Date() ? `<p class="muted small">연리가 끝난 지 3일이 지나지 않아 ${fmt.remain(new Date(s.cooldown_until) - Date.now())} 뒤부터 새로 맺을 수 있습니다.</p>` : ''}`;
}
export function bindBondPanel(root, redraw) {
  const after = () => redraw?.();
  $$('[data-bond-acc],[data-bond-dec]', root).forEach(b => b.onclick = () => run(b, 'world_bond_respond', { p_request: b.dataset.bondAcc || b.dataset.bondDec, p_accept: !!b.dataset.bondAcc }, after));
  $$('[data-bond]', root).forEach(b => b.onclick = async () => {
    const k = b.dataset.bond, cur = bond();
    if (k === 'wear') return run(b, 'world_bond_set', { p_wear: !cur?.my_wear, p_hide: null }, after);
    if (k === 'hide') return run(b, 'world_bond_set', { p_wear: null, p_hide: !cur?.my_hide }, after);
    if (k === 'cancel') return run(b, 'world_bond_cancel', {}, after);
    if (k === 'clear') return run(b, 'world_bond_clear', {}, after);
    if (k === 'gift') return openGift(after);
    if (k === 'break') {
      if (!(await ask(`「${cur?.token_name || '정표'}」을(를) 파기할까요?\n연리가 끝나고, ${cur?.partner_name || '정인'}님에게는 정표가 파기되었다고 알려집니다. 3일 동안은 새 연리를 맺을 수 없습니다.`, { title: '정표 파기', ok: '파기하기', danger: true }))) return;
      return run(b, 'world_bond_break', { p_reason: 'break' }, after);
    }
  });
}

/* ── 마음 전하기(조사원 카드) ───────────────────────── */
export async function openPropose(targetId, targetName) {
  await loadBond();
  let pick = 'knot';
  const l = openLayer({ title: `${targetName}님에게 마음 전하기`, body: `<div class="bond-propose">
    <p class="desc">정표를 하나 골라 건네며 연리를 청합니다. 받아 주면 둘 다 같은 정표를 정표 칸에 지니게 되고, 서로를 「정인」이라 부릅니다.</p>
    <div class="token-grid" role="radiogroup" aria-label="정표">${Object.entries(TOKENS).map(([k, [n, d]]) => `<button class="token-pick ${k === pick ? 'on' : ''}" data-token="${k}" role="radio" aria-checked="${k === pick}">${tokenSvg(k, 30)}<b>${esc(n)}</b><small>${esc(d)}</small></button>`).join('')}</div>
    <label class="field"><span>전할 말 (100자까지, 없어도 됩니다)</span><input name="msg" maxlength="100" placeholder="예: 앞으로도 같은 길을 걸어요"></label>
    <p class="muted small">정표 짓는 값 300전이 듭니다. 거절되거나 24시간 안에 답이 없으면 돌려받습니다. 한 번에 한 사람에게만 마음을 전할 수 있습니다.</p>
    <button class="btn primary block" id="bond-send">${tokenSvg('heart', 16)}<span>정표를 건네며 마음 전하기</span></button></div>` });
  $$('[data-token]', l).forEach(b => b.onclick = () => { pick = b.dataset.token; $$('[data-token]', l).forEach(x => { x.classList.toggle('on', x === b); x.setAttribute('aria-checked', x === b); }); });
  $('#bond-send', l).onclick = e => guard(e.currentTarget, async () => {
    const r = await act('world_bond_propose', { p_target: targetId, p_token: pick, p_message: $('[name=msg]', l).value.trim() });
    closeLayers(); await refresh(); return r;
  });
}

/* ── 선물 ───────────────────────────────────────────── */
async function openGift(after) {
  const b = bond(); if (!b) return;
  const inv = await rpc('world_inventory_snapshot').catch(() => null);
  const have = inv?.inventory || {}, equipped = new Set(Object.values(inv?.equipment || {}));
  const cmap = new Map((inv?.catalog || []).map(i => [i.id, i]));
  const items = Object.entries(have).filter(([id, n]) => Number(n) - (equipped.has(id) ? 1 : 0) > 0 && cmap.get(id)?.tradeable !== false && !MARKET_ONLY.has(id))
    .map(([id, n]) => ({ id, n: Number(n) - (equipped.has(id) ? 1 : 0), name: nameOf(id) })).sort((a, b2) => a.name.localeCompare(b2.name, 'ko'));
  const m = openModal({ title: `${b.partner_name}님에게 선물`, body: `<form class="bond-gift">
    <p class="desc">하루에 한 번, 물품이나 전 가운데 하나를 보냅니다. 잠근 물품·거래할 수 없는 물품·장착 중인 마지막 한 개는 보낼 수 없습니다.</p>
    <div class="segmented" style="--n:2"><button type="button" data-gk="item" class="on">물품</button><button type="button" data-gk="gil">전</button></div>
    <div data-g="item"><label class="field"><span>물품</span><select name="item">${items.map(x => `<option value="${esc(x.id)}" data-max="${x.n}">${esc(x.name)} (×${fmt.num(x.n)})</option>`).join('') || '<option value="">보낼 물품이 없습니다</option>'}</select></label>
      <label class="field"><span>수량</span><input name="qty" type="number" min="1" value="1"></label></div>
    <div data-g="gil" hidden><label class="field"><span>보낼 전 (가진 전 ${fmt.jeon(store.character?.gil || 0)})</span><input name="gil" type="number" min="1" value="10"></label></div>
    <button class="btn primary block" type="submit">${icon('plus', 16)}<span>보내기</span></button></form>` });
  const f = $('.bond-gift', m); let kind = 'item';
  $$('[data-gk]', f).forEach(x => x.onclick = () => { kind = x.dataset.gk; $$('[data-gk]', f).forEach(y => y.classList.toggle('on', y === x)); $$('[data-g]', f).forEach(y => y.hidden = y.dataset.g !== kind); });
  f.onsubmit = e => {
    e.preventDefault();
    const args = kind === 'item' ? { p_item: f.item.value || null, p_qty: Math.max(1, Number(f.qty.value || 1)), p_gil: 0 } : { p_item: null, p_qty: 1, p_gil: Math.max(0, Number(f.gil.value || 0)) };
    guard(f.querySelector('button[type=submit]'), async () => { const r = await act('world_bond_gift', args); closeModal(); await refresh(); after?.(); return r; });
  };
}

/* ── 장비 목록의 정표 칸 ─────────────────────────────── */
export function tokenRowHtml() {
  const b = bond();
  if (!b) return `<li class="empty-slot">${tokenSvg('knot', 18)}<div><b>정표</b><small>비어 있음 · 정인과 연리를 맺으면 정표를 지닙니다</small></div></li>`;
  return `<li class="token-row">${tokenSvg(b.token_key, 18)}<div><b>정표 · ${esc(b.token_name)}</b><small>${esc(b.partner_name)}님과의 연리 · ${esc(b.stage_name)}${b.together ? ' · 연리의 기운(회복량 +5% · 침식 -5%)' : ''}</small></div>
    <button class="btn small ghost eq-off" data-bond-wear>${b.my_wear ? '벗기' : '착용'}</button></li>`;
}
export function bindTokenRow(root) {
  $$('[data-bond-wear]', root).forEach(b => b.onclick = () => run(b, 'world_bond_set', { p_wear: !bond()?.my_wear, p_hide: null }));
}
