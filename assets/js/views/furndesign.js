import { act, store, esc, icon, guard, $, $$, openLayer, ask, nameOf } from '../core.js';
import { load, errorBox } from './common.js';
import { GAMEDATA as GD } from '../gamedata.js';
import { pixelPad } from '../housing/pixelpad.js';
import { PAL, PAL_NAMES } from '../housing/drawing.js';
import { openColorPicker } from '../colorpick.js';
import { hqCount } from '../hq.js';
import { reportFlag } from '../reportflag.js';
import { qtyHtml, bindQty, qtyOf } from './itempick.js';
import { FURN, sizeOf, palOf, furnPicURL } from '../housing/furndef.js';
import { openDesignGive, openDesignReport } from './outfitdesign.js';

const SIZE_NAME = { '1x1': '1×1', '2x1': '2×1', '2x2': '2×2' };
const TOP_NAME = { 0.42: '낮은 상', 0.92: '탁자', 1.6: '장' };
const PET_NAME = { bed: '잠자리', bowl: '밥그릇', toy: '장난감', perch: '횃대' };
const KIND = [['plain', '보통 가구'], ['table', '탁자(위에 소품)'], ['rug', '깔개'], ['pet', '동무 가구']];
const START = ['#4a3020', '#8a5a34', '#d9a877', '#f4efe2', '#1a1a1f'];
const tiles = size => sizeOf(size).w * sizeOf(size).d;
const kindOf = a => a?.pet ? 'pet' : a?.layer === 'rug' ? 'rug' : a?.top ? 'table' : 'plain';
export const furnAttrText = a => [a?.layer === 'rug' ? '깔개' : a?.top ? `윗면 ${TOP_NAME[a.top] || a.top}` : '', a?.pet ? `동무 ${PET_NAME[a.pet]}` : '', a?.pk ? `${GD.kinds?.[a.pk] || ''} 동무가 좋아함` : ''].filter(Boolean).join(' · ');
export const furnPic = (d, o) => d?.px ? furnPicURL(d.base || d.size, d.pal, d.px, o) : '';

function guides(g, size, k, top) {
  const z = sizeOf(size), W = z.w, D = z.d, base = z.ph - 8 * (W + D);
  const ix = (a, b) => ((a - b) * 16 + 16 * D) * k, iy = (a, b, h) => ((a + b) * 8 - h * 20 + base) * k;
  const dia = (h, col) => { g.setLineDash([k * .8, k * .6]); g.strokeStyle = col; g.lineWidth = Math.max(1.5, k / 4); g.beginPath(); [[0, 0], [W, 0], [W, D], [0, D]].forEach(([a, b], i) => i ? g.lineTo(ix(a, b), iy(a, b, h)) : g.moveTo(ix(a, b), iy(a, b, h))); g.closePath(); g.stroke(); g.setLineDash([]); };
  dia(0, 'rgba(224,90,76,.9)'); if (top) dia(top, 'rgba(95,208,255,.95)');
}

export function openFurnEditor(done, edit = null, have = 0) {
  const max = FURN.colors || 16;
  let size = edit?.base || '1x1', attr = { layer: 'floor', top: 0, ...(edit?.furn || {}) }, kind = kindOf(attr);
  let pal = edit?.pal ? palOf(edit.pal).slice(0, max) : START.slice(), cur = 1, view = 0, same = true, pad = null, cells = [];
  const reset = () => {
    const z = sizeOf(size), n = z.pw * z.ph, src = String(edit?.px || '');
    same = !(src.length >= 2 * n);
    cells = Array.from({ length: 2 * n }, (_, i) => src[i < n || !same ? i : i - n] || '.');
  };
  reset();
  const n = () => sizeOf(size).pw * sizeOf(size).ph;
  const pxStr = () => same ? cells.slice(0, n()).join('') : cells.join('');
  const palStr = () => pal.map(c => c.slice(1)).join('');
  const first = pxStr() + palStr();
  const confirmClose = async () => pxStr() + palStr() === first || ask(edit ? '고친 것을 담지 않고 닫을까요?' : '그리던 가구를 담지 않고 닫을까요? 칠한 칸은 사라집니다.', { title: '가구 도안 닫기', ok: '닫기', cancel: '계속 그리기' });
  const opt = (v, l, on) => `<option value="${v}"${on ? ' selected' : ''}>${esc(l)}</option>`;
  const layer = openLayer({ title: edit ? '가구 도안 고치기' : '가구 그리기', wide: true, confirmClose, body: `<div class="od-ed fd-ed">
    <div class="od-left">
      <div class="od-slot"><button class="chip-btn" data-view="0">앞모습</button><button class="chip-btn" data-view="1">뒷모습</button>
        <label class="fd-same"><input type="checkbox" data-same> 앞뒤 같음</label></div>
      <canvas class="od-canvas fd-canvas" aria-label="가구 그리는 칸"></canvas>
      <div class="dr-tools od-tools">${[['pen', '붓'], ['fill', '채우기'], ['erase', '지우개']].map(([k, l]) => `<button class="chip-btn" data-tool="${k}">${l}</button>`).join('')}<button class="chip-btn" data-undo>되돌리기</button><button class="chip-btn" data-clear>모두 지우기</button></div>
      <p class="muted small fd-guide"><span class="fd-red">— 바닥 칸</span> <span class="fd-blue">— 윗면(소품·동무가 올라앉는 높이)</span></p>
    </div>
    <div class="od-right">
      <div class="fd-rots" aria-label="네 방향"></div>
      <div class="fd-opts">
      <label class="field"><span>크기</span><select name="size" ${edit ? 'disabled' : ''}>${Object.keys(FURN.sizes).map(k => opt(k, `${SIZE_NAME[k] || k} 칸 · 도안 ${tiles(k)}장`, k === size)).join('')}</select></label>
      <label class="field"><span>쓰임</span><select name="kind" ${edit ? 'disabled' : ''}>${KIND.map(([k, l]) => opt(k, l, k === kind)).join('')}</select></label>
      <label class="field" data-for="pet"><span>동무 쓰임</span><select name="pet" ${edit ? 'disabled' : ''}>${Object.entries(PET_NAME).map(([k, l]) => opt(k, l, k === (attr.pet || 'bed'))).join('')}</select></label>
      <label class="field" data-for="top"><span>윗면 높이</span><select name="top" ${edit ? 'disabled' : ''}>${FURN.tops.filter(t => t > 0).map(t => opt(t, TOP_NAME[t] || t, Number(attr.top) === t)).join('')}</select></label>
      <label class="field" data-for="pk"><span>좋아하는 갈래</span><select name="pk" ${edit ? 'disabled' : ''}>${opt('', '없음', !attr.pk)}${Object.entries(GD.kinds || {}).map(([k, l]) => opt(k, `${l} 동무`, attr.pk === k)).join('')}</select></label>
      </div>
      <p class="od-h">내 색 <small class="muted">${max}칸까지</small></p>
      <div class="od-pal"></div>
      <div class="dr-pal od-picks">${PAL.map((c, i) => `<button class="dr-sw" data-pick="${c}" style="--c:${c}" title="${esc(PAL_NAMES[i])}" aria-label="${esc(PAL_NAMES[i])}"></button>`).join('')}<button class="chip-btn" data-own>${icon('palette', 14)} 직접 고르기</button></div>
      <label class="field"><span>가구 이름</span><input maxlength="${FURN.title_max || 12}" name="t" placeholder="비워 두면 「${esc(FURN.name || '직접 그린 가구')}」" value="${esc(edit?.t || '')}"></label>
      <p class="muted small fd-note"></p>
      <div class="btn-row"><button class="btn primary" data-save>${icon('check', 16)} ${edit ? '고친 것 담기' : '도안첩에 담기'}</button></div>
    </div></div>` });
  let cv = $('.fd-canvas', layer);
  const sc = () => Math.max(4, Math.min(10, Math.floor(Math.min(innerWidth - 56, 460) / sizeOf(size).pw)));
  const off = () => view && !same ? n() : 0;
  const readAttr = () => {
    kind = $('[name=kind]', layer).value;
    const pet = kind === 'pet' ? $('[name=pet]', layer).value : null;
    const needTop = kind === 'table' || pet === 'perch';
    attr = { layer: kind === 'rug' ? 'rug' : 'floor', top: needTop ? Number($('[name=top]', layer).value) : 0, ...(pet ? { pet } : {}), ...(pet && $('[name=pk]', layer).value ? { pk: $('[name=pk]', layer).value } : {}) };
    $('[data-for=pet]', layer).hidden = kind !== 'pet';
    $('[data-for=pk]', layer).hidden = kind !== 'pet';
    $('[data-for=top]', layer).hidden = !needTop;
    $('.fd-note', layer).textContent = edit ? '크기와 쓰임은 바꿀 수 없습니다. 고쳐 담으면 이미 지은 가구도 고친 모습으로 바뀝니다.'
      : `담으면 가구 그리기 도안 ${tiles(size)}장을 씁니다(가방 ${have}장). 담은 도안은 도안첩에서 목공 재료로 지어 별채 곳간에 넣습니다. 앞모습은 오른쪽 아래를 보는 모습이고, 돌리면 좌우가 뒤집힙니다.`;
  };
  const rots = () => {
    const px = pxStr(), p = palStr();
    $('.fd-rots', layer).innerHTML = [[false, false], [false, true], [true, false], [true, true]].map(([bk, f], i) => `<figure><img src="${furnPicURL(size, p, px, { scale: 2, back: bk, flip: f })}" alt=""><figcaption>${i + 1}</figcaption></figure>`).join('');
  };
  const drawCanvas = () => {
    const z = sizeOf(size), k = cv.width / z.pw, o = off(), g = cv.getContext('2d');
    for (let y = 0; y < z.ph; y++) for (let x = 0; x < z.pw; x++) {
      const c = cells[o + y * z.pw + x];
      g.fillStyle = c !== '.' ? pal[parseInt(c, 16)] || '#000' : (x + y) & 1 ? '#2a2733' : '#332f3d';
      g.fillRect(x * k, y * k, k, k);
    }
    guides(g, size, k, attr.top);
    rots();
  };
  const mount = () => {
    const z = sizeOf(size), w = z.pw, h = z.ph;
    const at = (x, y) => off() + y * w + x;
    const nb = idx => { const i = idx - off(), x = i % w, y = Math.floor(i / w), out = []; if (x > 0) out.push(idx - 1); if (x < w - 1) out.push(idx + 1); if (y > 0) out.push(idx - w); if (y < h - 1) out.push(idx + w); return out; };
    const fresh = cv.cloneNode(false); cv.replaceWith(fresh); cv = fresh;
    const tool = pad?.tool;
    pad = pixelPad(cv, { w, h, scale: sc(), at, cells, draw: drawCanvas, nb });
    pad.color = cur.toString(16); if (tool) pad.tool = tool;
    tools();
  };
  const tools = () => {
    $$('[data-tool]', layer).forEach(b => { b.classList.toggle('on', b.dataset.tool === pad.tool); b.onclick = () => { pad.tool = b.dataset.tool; $$('[data-tool]', layer).forEach(x => x.classList.toggle('on', x === b)); }; });
    $$('[data-view]', layer).forEach(b => { b.classList.toggle('on', Number(b.dataset.view) === view); b.disabled = same && b.dataset.view === '1'; });
    $('[data-same]', layer).checked = same;
  };
  const paintPal = () => {
    $('.od-pal', layer).innerHTML = pal.map((c, i) => `<button class="od-sw${i === cur ? ' on' : ''}" data-slotc="${i}" style="--c:${c}" aria-label="색 ${i + 1}"><b>${i + 1}</b></button>`).join('') + (pal.length < max ? '<button class="chip-btn" data-addc>+ 색</button>' : '');
    $$('[data-slotc]', layer).forEach(b => b.onclick = () => { cur = +b.dataset.slotc; pad.color = cur.toString(16); paintPal(); });
    $('[data-addc]', layer)?.addEventListener('click', () => { pal.push('#f4efe2'); cur = pal.length - 1; pad.color = cur.toString(16); paintPal(); drawCanvas(); });
  };
  $('[data-undo]', layer).onclick = () => pad.undo();
  $('[data-clear]', layer).onclick = () => { pad.save(); const o = off(); for (let i = 0; i < n(); i++) cells[o + i] = '.'; drawCanvas(); };
  $$('[data-view]', layer).forEach(b => b.onclick = () => { if (same && b.dataset.view === '1') return; view = Number(b.dataset.view); tools(); drawCanvas(); });
  $('[data-same]', layer).onchange = e => {
    same = e.target.checked;
    if (!same) for (let i = 0; i < n(); i++) cells[n() + i] = cells[i];
    view = 0; tools(); drawCanvas();
  };
  $('[name=size]', layer).onchange = async e => {
    const to = e.target.value;
    if (cells.some(c => c !== '.') && !(await ask('크기를 바꾸면 칠한 칸이 모두 지워집니다. 바꿀까요?', { title: '크기 바꾸기', ok: '바꾸기' }))) { e.target.value = size; return; }
    size = to; cells.length = 0; cells.push(...Array(2 * n()).fill('.')); view = 0; same = true; readAttr(); mount();
  };
  ['kind', 'pet', 'top', 'pk'].forEach(k => $(`[name=${k}]`, layer).onchange = () => { readAttr(); drawCanvas(); });
  $$('[data-pick]', layer).forEach(b => b.onclick = () => { pal[cur] = b.dataset.pick.toLowerCase(); paintPal(); drawCanvas(); });
  $('[data-own]', layer).onclick = async () => { const c = await openColorPicker(pal[cur], { title: `색 ${cur + 1}` }); if (c) { pal[cur] = c.toLowerCase(); paintPal(); drawCanvas(); } };
  $('[data-save]', layer).onclick = e => guard(e.currentTarget, async () => {
    if (!cells.slice(0, n()).some(c => c !== '.')) throw new Error('앞모습을 한 칸 이상 칠해 주세요.');
    const tv = $('[name=t]', layer).value.trim();
    const r = edit ? await act('world_outfit_design_edit', { p_id: Number(edit.id), p_title: tv, p_pal: palStr(), p_px: pxStr(), p_deco: '' })
      : await act('world_furn_design_save', { p_size: size, p_attr: attr, p_title: tv, p_pal: palStr(), p_px: pxStr() });
    layer.close(); done?.(r); return r;
  });
  readAttr(); paintPal(); mount();
  return layer;
}

function weaveLine(d, nWeave, st) {
  const inv = store.character?.inventory || {}, stored = Object.fromEntries((st?.can_move ? st.items || [] : []).map(i => [i.item_id, Number(i.qty) || 0]));
  const t = tiles(d.base);
  const need = Object.entries(FURN.mats || {}).map(([k, v]) => [k, v * t * nWeave]);
  const lack = need.some(([k, v]) => hqCount(inv, k) + hqCount(stored, k) < v);
  return { lack, html: `<p class="small od-mats">재료 ${need.map(([k, v]) => { const a = hqCount(inv, k), b = hqCount(stored, k); return `<span class="${a + b >= v ? 'ok' : 'bad'}">${esc(nameOf(k))} ${v}개 (가방 ${a}${b ? ` · 창고 ${b}` : ''})</span>`; }).join(' · ')}</p>` };
}

function openWeave(d, st, done) {
  const l = openLayer({ title: '가구 짓기', body: `<div class="od-weave"><img class="od-pic fd-pic" src="${furnPic(d)}" alt="">
    <p>「${esc(d.t || FURN.name)}」을(를) 지어 별채 곳간에 넣습니다. 도안은 도안첩에 그대로 남아 몇 번이든 다시 지을 수 있습니다.</p>
    ${qtyHtml({ key: 'n', min: 1, max: 10, value: 1, label: '지을 수' })}<div class="fd-mats"></div>
    <div class="btn-row"><button class="btn primary" data-go data-here="가구 짓기">짓기</button></div></div>` });
  const paint = () => { const w = weaveLine(d, qtyOf(l, 'n') || 1, st); $('.fd-mats', l).innerHTML = w.html; $('[data-go]', l).disabled = w.lack; };
  bindQty(l, paint); paint();
  $('[data-go]', l).onclick = e => guard(e.currentTarget, async () => { const res = await act('world_furn_weave', { p_id: d.id, p_n: qtyOf(l, 'n') || 1 }); l.close(); done?.(res); return res; });
}

export async function furnBook(box, { onChange } = {}) {
  box.innerHTML = '<p class="muted small">불러오는 중…</p>';
  let r, st;
  try { [r, st] = await Promise.all([load('world_outfit_design_list', undefined, { maxAge: 0 }), load('world_storage_snapshot', undefined, { maxAge: 300000 }).catch(() => null)]); }
  catch (e) { box.innerHTML = errorBox(e.message); return; }
  const items = (r.items || []).filter(d => d.slot === 'furn'), trash = (r.trash || []).filter(d => d.slot === 'furn');
  const have = Number(r.furn_items) || 0, keep = FURN.keep || 20, full = items.length >= keep;
  const card = d => `<li class="od-card" data-id="${d.id}">${d.mine ? '' : reportFlag(`data-report="${d.id}"`, '도안 제보')}
    <img class="od-pic fd-pic" src="${furnPic(d)}" alt="">
    <div class="od-meta"><b>${esc(d.t || FURN.name)}</b><small class="muted">${SIZE_NAME[d.base] || d.base} 칸${furnAttrText(d.furn) ? ` · ${esc(furnAttrText(d.furn))}` : ''}</small>
      <small class="muted">${d.mine ? '내가 그림' : `${esc(d.a)} 그림${d.gift ? ` · ${esc(d.gift)}님이 보냄` : ''}`}</small>${d.woven ? '<span class="chip ok">지은 적 있음</span>' : ''}</div>
    <div class="od-acts"><button class="btn small primary" data-weave="${d.id}" data-here="가구 짓기">${icon('hammer', 14)} 짓기</button>${d.mine ? `<button class="btn small" data-edit="${d.id}">고치기</button><button class="btn small" data-give="${d.id}">보내기</button>` : ''}<button class="btn small ghost" data-del="${d.id}">지우기</button></div></li>`;
  box.innerHTML = `<div class="od-book">
    <div class="od-head"><span class="chip">가구 도안 ${items.length}/${keep}</span><span class="chip">가구 그리기 도안 ${have}장</span>
      <button class="btn small primary" data-new ${full || have < 1 ? 'disabled' : ''}>${icon('plus', 14)} 가구 그리기</button></div>
    ${have < 1 ? '<p class="muted small">가구를 그리려면 「가구 그리기 도안」이 있어야 합니다. 바닥 칸 하나에 한 장씩 씁니다(1×1 한 장 · 2×1 두 장 · 2×2 네 장). 비장고 마지막 방에서 나오고, 거래소에서 사고팔 수 있습니다.</p>' : full ? '<p class="muted small">도안첩이 가득 찼습니다. 안 쓰는 도안을 지우면 새로 그릴 수 있습니다.</p>' : ''}
    ${items.length ? `<ul class="od-list">${items.map(card).join('')}</ul>` : '<p class="muted small">아직 그린 가구가 없습니다.</p>'}
    ${trash.length ? `<details class="fold od-trash"><summary>지운 도안 ${trash.length}</summary><ul class="od-list">${trash.map(d => `<li class="od-card"><img class="od-pic fd-pic" src="${furnPic(d)}" alt=""><div class="od-meta"><b>${esc(d.t || FURN.name)}</b></div><div class="od-acts"><button class="btn small" data-restore="${d.id}">되살리기</button></div></li>`).join('')}</ul></details>` : ''}
  </div>`;
  const again = res => { onChange?.(res); furnBook(box, { onChange }); };
  const find = id => items.find(x => String(x.id) === String(id));
  $('[data-new]', box).onclick = () => openFurnEditor(again, null, have);
  $$('[data-edit]', box).forEach(b => b.onclick = () => { const d = find(b.dataset.edit); if (d) openFurnEditor(again, d, have); });
  $$('[data-weave]', box).forEach(b => b.onclick = () => { const d = find(b.dataset.weave); if (d) openWeave(d, st, again); });
  $$('[data-give]', box).forEach(b => b.onclick = () => { const d = find(b.dataset.give); if (d) openDesignGive(d, furnPic(d), '받은 사람이 가구를 지어 별채에 놓을 수 있고', r, again); });
  $$('[data-del]', box).forEach(b => b.onclick = async () => {
    const d = find(b.dataset.del); if (!d) return;
    if (!(await ask(`가구 도안 「${d.t || FURN.name}」을(를) 지울까요? 이미 지은 가구는 그대로 남고, 「지운 도안」에서 되살릴 수 있습니다.`, { title: '도안 지우기', ok: '지우기' }))) return;
    guard(b, async () => { const res = await act('world_outfit_design_delete', { p_id: d.id }); again(res); return res; });
  });
  $$('[data-restore]', box).forEach(b => b.onclick = () => guard(b, async () => { const res = await act('world_outfit_design_restore', { p_id: Number(b.dataset.restore) }); again(res); return res; }));
  $$('[data-report]', box).forEach(b => b.onclick = () => openDesignReport(Number(b.dataset.report), again));
}

export function openFurnBook(onChange) {
  const l = openLayer({ title: '가구 도안', wide: true, body: '<div class="fd-book"></div>' });
  furnBook($('.fd-book', l), { onChange });
  return l;
}
