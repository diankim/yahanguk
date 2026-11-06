import { rpc, store, esc, icon, $, $$, toast, guard, ask, openLayer, isGM } from '../core.js';
import { load } from './common.js';
import { PAL, PAL_NAMES, SIZE_NAME, dimsOf, picURL } from '../housing/drawing.js';

let book = null;
export async function drawingBook(force) {
  if (!book || force) book = await rpc('world_drawing_list');
  return book;
}
const setBook = r => { if (r?.mine) book = r; return r; };

const card = (d, btns = '') => `<div class="dr-card"><img class="dr-pic s${d.s}" src="${picURL(d, 4)}" alt="${esc(d.t || '그림')}">
  <b>${esc(d.t || '이름 없는 그림')}</b><small class="muted">${esc(d.a)}${d.gift ? ` · ${esc(d.gift)}님의 선물` : ''}</small>${btns ? `<span class="dr-btns">${btns}</span>` : ''}</div>`;

export async function openGallery(onChange) {
  let b;
  try { b = await drawingBook(true); } catch (e) { return toast(e.message, 'error'); }
  const layer = openLayer({ title: '그림첩', wide: true, body: '<div class="dr-gal"></div>' });
  const box = $('.dr-gal', layer);
  const paint = () => {
    const r = b.rules, mine = b.mine || [], left = Math.max(0, r.per_day - b.made_today), full = mine.length >= r.keep;
    box.innerHTML = `<p class="muted small">도트 그림을 그려 그림첩에 모아 두고, 별채의 그림 액자에 걸거나 친구에게 보냅니다. 새 그림은 하루 ${r.per_day}장(오늘 ${left}장 더) · 그림첩 ${mine.length}/${r.keep}장 · 보내기 하루 ${r.give_day}장. 이미 그린 그림은 언제든 고칠 수 있고, 받은 그림은 고칠 수 없습니다.</p>
      <div class="btn-row"><button class="btn small primary" data-new="S" ${left && !full ? '' : 'disabled'}>${icon('plus', 14)} ${SIZE_NAME.S} ${dimsOf('S', r).join('×')}</button><button class="btn small primary" data-new="L" ${left && !full ? '' : 'disabled'}>${icon('plus', 14)} ${SIZE_NAME.L} ${dimsOf('L', r).join('×')}</button></div>
      <div class="dr-grid">${mine.map(d => card(d, `${d.authored ? `<button class="btn small" data-edit="${d.id}">고치기</button>` : ''}<button class="btn small" data-give="${d.id}">보내기</button><button class="btn small danger" data-del="${d.id}">지우기</button>`)).join('') || '<p class="muted small">아직 그림이 없습니다.</p>'}</div>
      <p class="muted small">작은 그림은 「작은 그림 액자」, 큰 그림은 「큰 그림 액자」에 걸립니다. 꾸미기에서 액자를 고른 뒤 「그림 걸기」를 누르세요.</p>`;
  };
  paint();
  const changed = r => { if (r?.mine) b = setBook(r); paint(); onChange?.(); };
  box.addEventListener('click', e => {
    const t = e.target.closest('[data-new],[data-edit],[data-give],[data-del]'); if (!t) return;
    const find = id => (b.mine || []).find(x => String(x.id) === id);
    if (t.dataset.new) return openEditor({ s: t.dataset.new }, b.rules, changed);
    if (t.dataset.edit) return openEditor(find(t.dataset.edit), b.rules, changed);
    if (t.dataset.give) return openGive(find(t.dataset.give));
    guard(t, async () => {
      const d = find(t.dataset.del);
      if (!(await ask(`그림 「${d?.t || '이름 없는 그림'}」을(를) 지울까요? 걸어 둔 액자는 빈 액자가 되고, 되돌릴 수 없습니다.`, { title: '그림 지우기', ok: '지우기', danger: true }))) return;
      const r = await rpc('world_drawing_delete', { p_id: Number(t.dataset.del) }); changed(r); return r;
    });
  });
  return layer;
}

async function openGive(d) {
  if (!d) return;
  let fr; try { fr = await load('world_friend_overview'); } catch (e) { return toast(e.message, 'error'); }
  const friends = (fr?.friends || []).filter(f => !f.is_dead);
  if (!friends.length) return toast('그림은 친구에게만 보낼 수 있습니다. 먼저 친구를 맺으세요.', 'error');
  const layer = openLayer({ title: '그림 보내기', body: `<div class="dr-give">${card(d)}
    <label class="field"><span>받는 사람 (친구)</span><select name="to">${friends.map(f => `<option value="${esc(f.owner_id)}">${esc(f.character_name)} · Lv.${f.level}</option>`).join('')}</select></label>
    <p class="muted small">사본을 보냅니다. 내 그림은 그대로 남습니다.</p><div class="btn-row"><button class="btn primary" data-send>보내기</button></div></div>` });
  $('[data-send]', layer).onclick = e => guard(e.currentTarget, async () => {
    const r = await rpc('world_drawing_give', { p_id: d.id, p_target: $('select', layer).value }); layer.close(); return r;
  });
}

export function openEditor(d, rules, done) {
  const s = d.s, [w, h] = dimsOf(s, rules), px = (d.px || '.'.repeat(w * h)).split(''), undo = [];
  let color = 0, tool = 'pen', drawing = false, title = d.t || '';
  const layer = openLayer({ title: d.id ? '그림 고치기' : `새 ${SIZE_NAME[s]}`, wide: true, body: `<div class="dr-ed">
    <div class="dr-ed-main"><canvas class="dr-cv" aria-label="그림판"></canvas></div>
    <div class="dr-ed-side">
      <div class="dr-tools">${[['pen', '붓'], ['fill', '채우기'], ['erase', '지우개']].map(([k, l]) => `<button class="chip-btn ${k === tool ? 'on' : ''}" data-tool="${k}">${l}</button>`).join('')}<button class="chip-btn" data-undo>되돌리기</button><button class="chip-btn" data-clear>모두 지우기</button></div>
      <div class="dr-pal">${PAL.map((c, i) => `<button class="dr-sw ${i === color ? 'on' : ''}" data-c="${i}" style="--c:${c}" title="${esc(PAL_NAMES[i])}" aria-label="${esc(PAL_NAMES[i])}"></button>`).join('')}</div>
      <div class="dr-prev"><img alt="미리 보기"><small class="muted">실제 크기 ${w}×${h}</small></div>
      <label class="field"><span>그림 이름 (${rules?.title_max || 12}자까지)</span><input name="title" maxlength="${rules?.title_max || 12}" value="${esc(title)}" autocomplete="off"></label>
      <div class="btn-row"><button class="btn primary" data-save>${icon('chest', 15)} 그림첩에 담기</button></div>
      <p class="muted small">${d.id ? '고친 그림은 걸어 둔 액자에도 바로 보입니다. 이미 보낸 사본은 그대로입니다.' : '담으면 오늘 그릴 수 있는 장수가 하나 줄어듭니다. 담은 뒤에는 언제든 고칠 수 있습니다.'}</p>
    </div></div>` });
  const cv = $('.dr-cv', layer), g = cv.getContext('2d'), prev = $('.dr-prev img', layer);
  const fit = () => {
    const room = Math.min(($('.dr-ed-main', layer).getBoundingClientRect().width || 320) - 4, 520);
    const cs = Math.max(6, Math.floor(room / w)); cv.width = w * cs; cv.height = h * cs; cv.dataset.cs = cs; paint();
  };
  const paint = () => {
    const cs = Number(cv.dataset.cs || 10);
    g.fillStyle = '#f6ead0'; g.fillRect(0, 0, cv.width, cv.height);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const ch = px[y * w + x]; if (ch !== '.') { g.fillStyle = PAL[parseInt(ch, 16)]; g.fillRect(x * cs, y * cs, cs, cs); } }
    g.strokeStyle = 'rgba(0,0,0,.12)'; g.lineWidth = 1; g.beginPath();
    for (let x = 1; x < w; x++) { g.moveTo(x * cs + .5, 0); g.lineTo(x * cs + .5, cv.height); }
    for (let y = 1; y < h; y++) { g.moveTo(0, y * cs + .5); g.lineTo(cv.width, y * cs + .5); }
    g.stroke();
    prev.src = picURL({ s, px: px.join('') }, 2);
  };
  const cellAt = e => { const r = cv.getBoundingClientRect(); const x = Math.floor((e.clientX - r.left) / r.width * w), y = Math.floor((e.clientY - r.top) / r.height * h); return x >= 0 && y >= 0 && x < w && y < h ? [x, y] : null; };
  const ink = () => tool === 'erase' ? '.' : color.toString(16);
  const fill = (x, y) => {
    const from = px[y * w + x], to = ink(); if (from === to) return;
    const q = [[x, y]];
    while (q.length) { const [a, b] = q.pop(); if (a < 0 || b < 0 || a >= w || b >= h || px[b * w + a] !== from) continue; px[b * w + a] = to; q.push([a + 1, b], [a - 1, b], [a, b + 1], [a, b - 1]); }
  };
  const put = e => { const c = cellAt(e); if (!c) return; const i = c[1] * w + c[0], v = ink(); if (px[i] !== v) { px[i] = v; paint(); } };
  cv.addEventListener('pointerdown', e => {
    const c = cellAt(e); if (!c) return; e.preventDefault();
    undo.push(px.join('')); if (undo.length > 40) undo.shift();
    if (tool === 'fill') { fill(c[0], c[1]); return paint(); }
    drawing = true; cv.setPointerCapture?.(e.pointerId); put(e);
  });
  cv.addEventListener('pointermove', e => { if (drawing) put(e); });
  const stop = () => { drawing = false; };
  cv.addEventListener('pointerup', stop); cv.addEventListener('pointercancel', stop);
  layer.addEventListener('click', e => {
    const t = e.target.closest('[data-tool],[data-c],[data-undo],[data-clear],[data-save]'); if (!t) return;
    if (t.dataset.tool) { tool = t.dataset.tool; $$('[data-tool]', layer).forEach(b => b.classList.toggle('on', b === t)); return; }
    if (t.dataset.c) { color = Number(t.dataset.c); if (tool === 'erase') { tool = 'pen'; $$('[data-tool]', layer).forEach(b => b.classList.toggle('on', b.dataset.tool === 'pen')); } $$('[data-c]', layer).forEach(b => b.classList.toggle('on', b === t)); return; }
    if (t.dataset.undo != null) { const u = undo.pop(); if (u) { px.splice(0, px.length, ...u.split('')); paint(); } return; }
    if (t.dataset.clear != null) { undo.push(px.join('')); px.fill('.'); return paint(); }
    if (t.dataset.save != null) guard(t, async () => {
      const r = await rpc('world_drawing_save', { p_id: d.id || null, p_size: s, p_title: $('[name=title]', layer).value, p_px: px.join('') });
      setBook(r); layer.close(); done?.(r); return r;
    });
  });
  requestAnimationFrame(fit);
  return layer;
}

export async function pickDrawing(size, cur, onPick) {
  let b; try { b = await drawingBook(); } catch (e) { return toast(e.message, 'error'); }
  const list = (b.mine || []).filter(d => d.s === size);
  const layer = openLayer({ title: `그림 걸기 · ${SIZE_NAME[size]}`, wide: true, body: `<div class="dr-pick">
    ${list.length ? `<div class="dr-grid">${list.map(d => `<button class="dr-card pick ${String(d.id) === String(cur) ? 'on' : ''}" data-pick="${d.id}"><img class="dr-pic s${d.s}" src="${picURL(d, 4)}" alt=""><b>${esc(d.t || '이름 없는 그림')}</b><small class="muted">${esc(d.a)}</small></button>`).join('')}</div>`
      : `<p class="muted small">그림첩에 ${SIZE_NAME[size]}이 없습니다.</p>`}
    <div class="btn-row">${cur ? '<button class="btn small" data-pick="">빈 액자로</button>' : ''}<button class="btn small" data-book>그림첩 열기</button></div></div>` });
  layer.addEventListener('click', e => {
    if (e.target.closest('[data-book]')) { layer.close(); return openGallery(); }
    const t = e.target.closest('[data-pick]'); if (!t) return;
    const d = list.find(x => String(x.id) === t.dataset.pick) || null; layer.close(); onPick(d);
  });
}

export function openViewer(d, house, after) {
  const gm = isGM(store.user?.id), me = store.user?.id, foreign = d.ai !== me && !d.mine;
  const layer = openLayer({ title: d.t || '이름 없는 그림', body: `<div class="dr-view"><img class="dr-big s${d.s}" src="${picURL(d, 10)}" alt="${esc(d.t || '그림')}">
    <p>${esc(d.a)}님의 그림${d.gift ? ` · ${esc(d.gift)}님이 보낸 선물` : ''}</p>
    ${foreign || gm ? `<div class="btn-row">${foreign ? '<button class="btn small" data-hide>내 화면에서 숨기기</button><button class="btn small" data-report>운영진에게 제보</button>' : ''}${gm ? '<button class="btn small danger" data-remove>운영진 · 그림 내리기</button>' : ''}</div>` : ''}
    ${foreign ? '<p class="muted small">숨기면 이 그림이 나에게만 빈 액자로 보입니다. 불쾌한 그림은 제보해 주세요. 운영진이 확인해 내립니다.</p>' : ''}</div>` });
  layer.addEventListener('click', e => {
    const t = e.target.closest('[data-hide],[data-report],[data-remove]'); if (!t) return;
    if (t.dataset.report != null) {
      const f = openLayer({ title: '그림 제보', body: `<form class="dr-rep"><label class="field"><span>까닭 (적지 않아도 됩니다, 200자)</span><textarea name="why" rows="3" maxlength="200"></textarea></label><div class="btn-row"><button class="btn primary">보내기</button></div></form>` });
      $('form', f).onsubmit = ev => { ev.preventDefault(); guard($('button', f), async () => { const r = await rpc('world_drawing_report', { p_origin: d.o, p_house: house || null, p_reason: $('textarea', f).value }); f.close(); layer.close(); after?.(); return r; }); };
      return;
    }
    guard(t, async () => {
      if (t.dataset.remove != null) {
        if (!(await ask('이 그림과 모든 사본을 내릴까요? 그린 사람에게 알림이 갑니다.', { title: '그림 내리기', ok: '내리기', danger: true }))) return;
        const r = await rpc('world_drawing_remove', { p_origin: d.o, p_reason: '' }); layer.close(); after?.(); return r;
      }
      const r = await rpc('world_drawing_hide', { p_origin: d.o }); layer.close(); after?.(); return r;
    });
  });
}
