import { $, $$, esc, icon, fmt, nameOf, brief, rarTag, openLayer, toast } from '../core.js';

const PICK_GEAR = new Set(['weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool', 'accessory', 'equipment']);
export const PICK_CATS = [['all', '전체'], ['gear', '장비'], ['consumable', '소모품'], ['material', '재료'], ['etc', '기타']];
export const pickCat = c => !c ? 'etc' : PICK_GEAR.has(c) ? 'gear' : c === 'consumable' ? 'consumable' : /material/.test(c) ? 'material' : 'etc';
export const listRowAttrs = (cat, name) => `data-mk-cat="${esc(cat || 'etc')}" data-mk-name="${esc(String(name || '').toLowerCase())}"`;
export const listFilterHtml = (st, { cats = PICK_CATS, have = null, label = '물품 찾기', cls = '', hidden = false } = {}) => {
  const list = have ? cats.filter(([k]) => k === 'all' || have.has(k)) : cats;
  if (have && st.cat !== 'all' && !have.has(st.cat)) st.cat = 'all';
  return `<div class="mk-filter ${cls}" data-lf ${hidden ? 'hidden' : ''}><div class="pick-cats">${list.map(([k, t]) => `<button type="button" class="chip ${k === st.cat ? 'accent' : ''}" data-lfc="${k}">${t}</button>`).join('')}</div>
    <input type="search" class="mk-q" placeholder="이름으로 찾기" aria-label="${esc(label)}" value="${esc(st.q || '')}"></div>`;
};
export function bindListFilter(root, st, rows, onShown) {
  const bar = $('[data-lf]', root); if (!bar) return () => {};
  const qi = $('.mk-q', bar);
  const apply = () => {
    st.q = qi.value; const q = st.q.trim().toLowerCase(); let shown = 0;
    rows().forEach(li => { const ok = (st.cat === 'all' || li.dataset.mkCat === st.cat) && (!q || (li.dataset.mkName || '').includes(q)); li.hidden = !ok; if (ok) shown++; });
    onShown?.(shown);
  };
  qi.addEventListener('input', e => { if (!e.isComposing) apply(); });
  qi.addEventListener('compositionend', apply);
  qi.addEventListener('keydown', e => { if (e.key === 'Enter' && !e.isComposing) { e.preventDefault(); apply(); qi.blur(); } });
  $$('[data-lfc]', bar).forEach(b => b.onclick = () => { st.cat = b.dataset.lfc; $$('[data-lfc]', bar).forEach(x => x.classList.toggle('accent', x === b)); apply(); });
  apply();
  return apply;
}
export const qtyHtml = ({ key, max = 99, value = 0, min = 0, all = false, label = '수량', off = false, small = false }) => {
  const dis = off || !max ? 'disabled' : '';
  return `<div class="stepper ${small ? 'sm' : ''}" data-qty="${esc(key)}" data-min="${min}">
    <button type="button" class="icon-btn" data-d="-1" aria-label="하나 빼기" ${dis}>${icon('minus', small ? 14 : 16)}</button>
    <input type="number" inputmode="numeric" min="${min}" max="${max}" value="${value}" aria-label="${esc(label)}" ${dis}>
    <button type="button" class="icon-btn" data-d="1" aria-label="하나 더" ${dis}>${icon('plus', small ? 14 : 16)}</button>${all && max > 1 ? `<button type="button" class="btn small ghost" data-all ${dis}>${allLabel(value >= max)}</button>` : ''}</div>`;
};
const allLabel = full => full ? '최소' : '전부';
export const qtyMark = st => { const b = st?.querySelector('[data-all]'); if (!b) return; const inp = st.querySelector('input'); b.textContent = allLabel(Number(inp.value) >= (Number(inp.max) || 0)); b.setAttribute('aria-label', b.textContent === '최소' ? '가장 적게' : '가진 것 전부'); };
export const qtyClamp = (st, v) => { const inp = st.querySelector('input'), min = Number(st.dataset.min) || 0, max = Number(inp.max) || 0; return Math.max(min, Math.min(max, Math.floor(Number(v) || 0))); };
export function bindQty(root, onChange) {
  $$('[data-qty]', root).forEach(st => {
    const inp = st.querySelector('input'), max = Number(inp.max) || 0, min = Number(st.dataset.min) || 0;
    const set = v => { v = qtyClamp(st, v); inp.value = v; qtyMark(st); onChange?.(st.dataset.qty, v, st); };
    st.querySelectorAll('[data-d]').forEach(b => b.onclick = () => set(Number(inp.value) + Number(b.dataset.d)));
    st.querySelector('[data-all]')?.addEventListener('click', () => set(Number(inp.value) === max ? min : max));
    inp.oninput = () => { if (inp.value !== '') set(inp.value); };
    inp.onchange = () => set(inp.value);
    inp.onkeydown = e => { if (e.key === 'Enter') { e.preventDefault(); inp.blur(); } };
    qtyMark(st);
  });
}
export const qtyOf = (root, key) => { const st = $(`[data-qty="${CSS.escape(key)}"]`, root); return st ? qtyClamp(st, st.querySelector('input').value) : 0; };
export const koSort = (a, b) => a.name.localeCompare(b.name, 'ko');
const LIMIT = 200;

export function pickRows(list, catalog) {
  const cmap = catalog instanceof Map ? catalog : new Map((catalog || []).map(i => [i.id, i]));
  return list.map(r => {
    const it = cmap.get(r.id) || {};
    return { cat: pickCat(it.category), rarity: it.rarity || 'common', tier: it.tier || 0, desc: it.description || '', ...r, name: r.name || it.name || nameOf(r.id) };
  }).sort(koSort);
}

export function openItemPick({ title = '물품 고르기', rows = [], many = false, picked = {}, kinds = Infinity, okText = '담기', empty = '고를 수 있는 물품이 없습니다.', note = '', onDone }) {
  const sel = new Map(Object.entries(picked || {}).filter(([, n]) => n > 0).map(([k, n]) => [k, Number(n)]));
  const cats = PICK_CATS.filter(([k]) => k === 'all' || rows.some(r => r.cat === k));
  let cat = 'all', q = '';
  const layer = openLayer({ title, wide: true, body: `<div class="ipk">
    ${rows.length ? `<div class="ipk-top"><div class="pick-cats">${cats.map(([k, t]) => `<button type="button" class="chip ${k === 'all' ? 'accent' : ''}" data-ipc="${k}">${t}</button>`).join('')}</div>
      <label class="search"><span>${icon('search', 16)}</span><input type="search" class="ipk-q" placeholder="이름으로 찾기" aria-label="물품 찾기"></label></div>
      <ul class="item-list ipk-list"></ul>${note}
      ${many ? `<div class="ipk-foot"><span class="ipk-sum muted small"></span><button type="button" class="btn primary ipk-ok">${icon('check', 15)}<span>${esc(okText)}</span></button></div>` : ''}`
      : `<p class="muted">${esc(empty)}</p>${note}`}</div>` });
  const box = $('.ipk', layer), list = $('.ipk-list', box); if (!list) return layer;
  const qty = r => sel.get(r.id) || 0;
  const rowHtml = r => `<li class="inv-item r-${esc(r.rarity)} ${qty(r) ? 'on' : ''}" data-ipk="${esc(r.id)}">
      <button type="button" class="ipk-row" data-ipk-pick="${esc(r.id)}"><span class="ipk-name"><b>${esc(r.name)}</b>${rarTag(r.rarity)}${r.have != null ? `<span class="qty">×${fmt.num(r.have)}</span>` : ''}</span>
        <small class="muted">${r.tier ? `${r.tier}단계` : ''}${r.tier && r.sub ? ' · ' : ''}${r.sub ? esc(r.sub) : ''}</small>${r.desc ? `<small class="brief">${esc(brief(r.desc))}</small>` : ''}</button>
      ${many ? qtyHtml({ key: r.id, max: r.max ?? 999, value: qty(r), all: true, small: true, label: `${r.name} 수량` }) : ''}</li>`;
  const sum = () => {
    const el = $('.ipk-sum', box); if (!el) return;
    const n = [...sel.values()].reduce((a, b) => a + b, 0);
    el.textContent = sel.size ? `${sel.size}가지 · ${fmt.num(n)}개${Number.isFinite(kinds) ? ` (${kinds}가지까지)` : ''}` : '고른 물품 없음';
  };
  const draw = () => {
    const t = q.trim().toLowerCase();
    const shown = rows.filter(r => (cat === 'all' || r.cat === cat) && (!t || r.name.toLowerCase().includes(t)));
    list.innerHTML = shown.slice(0, LIMIT).map(rowHtml).join('')
      + (shown.length > LIMIT ? `<li class="muted small ipk-more">${fmt.num(shown.length - LIMIT)}가지 더 있습니다. 이름으로 좁혀 찾으세요.</li>` : '')
      || '<li class="muted small ipk-more">맞는 물품이 없습니다.</li>';
    sum();
  };
  const setQty = (id, v) => {
    const r = rows.find(x => x.id === id); if (!r) return;
    const n = Math.max(0, Math.min(r.max ?? 999, Math.floor(Number(v) || 0)));
    if (n && !sel.has(id) && sel.size >= kinds) { toast(`한 번에 ${kinds}가지까지 담을 수 있습니다.`, 'error'); return draw(); }
    if (n) sel.set(id, n); else sel.delete(id);
    const li = list.querySelector(`[data-ipk="${CSS.escape(id)}"]`);
    if (li) { li.classList.toggle('on', n > 0); const i = li.querySelector('input'); if (i && Number(i.value) !== n) i.value = n; qtyMark(li.querySelector('[data-qty]')); }
    sum();
  };
  draw();
  $$('[data-ipc]', box).forEach(b => b.onclick = () => { cat = b.dataset.ipc; $$('[data-ipc]', box).forEach(x => x.classList.toggle('accent', x === b)); draw(); });
  const qi = $('.ipk-q', box);
  qi.addEventListener('input', e => { if (e.isComposing) return; q = qi.value; draw(); });
  qi.addEventListener('compositionend', () => { q = qi.value; draw(); });
  qi.addEventListener('keydown', e => { if (e.key === 'Enter' && !e.isComposing) { e.preventDefault(); qi.blur(); } });
  list.addEventListener('click', e => {
    const li = e.target.closest('[data-ipk]'); if (!li) return;
    const id = li.dataset.ipk, r = rows.find(x => x.id === id);
    if (!many) { if (e.target.closest('[data-ipk-pick]')) { layer.close(); onDone?.(id); } return; }
    const d = e.target.closest('[data-d]'), all = e.target.closest('[data-all]');
    if (d) setQty(id, qty(r) + Number(d.dataset.d));
    else if (all) setQty(id, qty(r) === (r.max ?? 999) ? 0 : r.max ?? 999);
    else if (e.target.closest('[data-ipk-pick]')) setQty(id, qty(r) ? 0 : 1);
  });
  list.addEventListener('change', e => { const i = e.target.closest('input'); if (i) setQty(i.closest('[data-ipk]').dataset.ipk, i.value); });
  list.addEventListener('keydown', e => { if (e.key === 'Enter' && e.target.matches('input')) { e.preventDefault(); e.target.blur(); } });
  $('.ipk-ok', box)?.addEventListener('click', () => { layer.close(); onDone?.(Object.fromEntries(sel)); });
  return layer;
}

export function pickerHtml(name, placeholder = '물품 고르기') {
  return `<div class="pick-field" data-pick="${name}"><input type="hidden" name="${name}" value=""><button type="button" class="btn pick-btn">${icon('bag', 15)}<span class="pick-label">${esc(placeholder)}</span>${icon('chevron', 13)}</button></div>`;
}
export function bindPicker(root, name, rows, onPick, opts = {}) {
  const box = $(`[data-pick="${name}"]`, root); if (!box) return { set() {} };
  const inp = box.querySelector('input'), lab = box.querySelector('.pick-label'), btn = box.querySelector('.pick-btn');
  const set = id => {
    const r = rows.find(x => x.id === id);
    inp.value = r ? id : '';
    lab.innerHTML = r ? `${esc(r.name)}${r.have != null ? ` <small class="muted">×${fmt.num(r.have)}</small>` : ''} ${rarTag(r.rarity)}` : esc(opts.placeholder || '물품 고르기');
  };
  btn.disabled = !rows.length;
  btn.onclick = () => openItemPick({ title: opts.title || '물품 고르기', rows, note: opts.note || '', onDone: id => { set(id); onPick?.(id); } });
  if (opts.value) set(opts.value);
  return { set };
}

export function bundleChips(items, rmAttr = 'data-rm') {
  return Object.entries(items || {}).map(([k, n]) => `<span class="chip">${esc(nameOf(k))} ×${fmt.num(n)}<button type="button" class="chip-x" ${rmAttr}="${esc(k)}" aria-label="빼기">${icon('close', 12)}</button></span>`).join('') || '<span class="muted small">없음</span>';
}
