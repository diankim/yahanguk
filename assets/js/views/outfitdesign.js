import { act, store, esc, icon, guard, $, $$, openLayer, ask, toast, nameOf, fmt } from '../core.js';
import { load, knownRecipes, errorBox } from './common.js';
import { AV, AW, avatarImage, avatarPixels, fixLook, registerDesigns } from '../housing/avatarsprite.js';
import { pixelPad } from '../housing/pixelpad.js';
import { PAL, PAL_NAMES } from '../housing/drawing.js';
import { openColorPicker } from '../colorpick.js';
import { hqCount } from '../hq.js';

const SLOT_NAME = { top: '윗옷', bottom: '아랫옷' };
const DECO_NAME = { c: '장식 하나', d: '장식 둘', e: '장식 셋', z: '신' };
const EDIT = 'axyb';
let seq = 0;

const partOf = (slot, base) => slot === 'top' ? AV.top[base]?.part : AV.bottom[base]?.stand;
const maskOf = (slot, base) => AV[slot][base]?.mask || null;

function layout(slot, base) {
  const p = partOf(slot, base), pos = [];
  let x0 = AW, y0 = 99, x1 = 0, y1 = 0;
  p.rows.forEach((r, y) => { for (let x = 0; x < r.length; x++) { if (r[x] === '.') continue; const gx = p.x + x + 1, gy = p.y + y + 1; x0 = Math.min(x0, gx); y0 = Math.min(y0, gy); x1 = Math.max(x1, gx); y1 = Math.max(y1, gy); if (EDIT.includes(r[x])) pos.push([gx, gy]); } });
  return { pos, crop: [x0 - 1, y0 - 1, x1 - x0 + 3, y1 - y0 + 3] };
}

export function cropOf(slot, base) { return AV[slot]?.[base]?.mask ? layout(slot, base).crop : null; }

export function designPic(d, { job, scale = 3, look } = {}) {
  if (!d?.px || !AV[d.slot]?.[d.base]?.mask) return '';
  const id = 'v' + (++seq);
  registerDesigns({ [id]: { slot: d.slot, base: d.base, pal: d.pal, px: d.px, deco: d.deco || '' } });
  const l = { ...fixLook(look || {}, job), [d.slot]: d.base, [d.slot + '_d']: id };
  return avatarImage(l, { scale, crop: layout(d.slot, d.base).crop, job });
}

const ownedBases = (snap, slot) => Object.keys(AV[slot]).filter(k => AV[slot][k].mask && (AV.jobDefault[snap.job]?.[slot] === k || (snap.owned || []).includes(`${slot}:${k}`)));

function startPal(slot, base) {
  const p = AV[slot][base].pal, out = [];
  for (const c of [p.a, p.b, p.c, p.d, p.e, p.z, '#f4efe2', '#1a1a1f', '#c8382e', '#3f6fb5', '#f2c94c', '#5b9a4b']) if (c && /^#[0-9a-f]{6}$/i.test(c) && !out.includes(c.toLowerCase())) out.push(c.toLowerCase());
  return out.slice(0, 8);
}

export function openDesignEditor(snap, rules, done, { slot: s0 } = {}) {
  let slot = s0 || 'top';
  let base = ownedBases(snap, slot)[0];
  if (!base) { slot = slot === 'top' ? 'bottom' : 'top'; base = ownedBases(snap, slot)[0]; }
  if (!base) return toast('도안 바탕으로 쓸 옷이 없습니다.', 'error');
  const me = fixLook(snap.look, snap.job), max = rules?.colors || 8;
  let pal = startPal(slot, base), deco = [], cells = [], lay = null, pad = null, cur = 0, flip = false, frame = 0, title = '', timer = null, look = null;
  const reset = () => { lay = layout(slot, base); cells = Array(maskOf(slot, base).n).fill('.'); deco = (maskOf(slot, base).deco || []).map(() => ''); pal = startPal(slot, base); cur = 0; };
  reset();
  const palStr = () => pal.map(c => c.slice(1)).join('');
  const decoStr = () => deco.map(c => c ? c.slice(1) : '......').join('');
  const draft = () => ({ slot, base, pal: palStr(), px: cells.join(''), deco: decoStr() });
  const sync = () => { const id = 'e' + (++seq); registerDesigns({ [id]: draft() }); look = { ...me, [slot]: base, [slot + '_d']: id }; };
  const layer = openLayer({ title: '새 옷 도안', wide: true, body: `<div class="od-ed">
    <div class="od-left">
      <div class="seg od-slot">${['top', 'bottom'].map(k => `<button class="chip-btn" data-slot="${k}">${SLOT_NAME[k]}</button>`).join('')}</div>
      <div class="od-bases"></div>
      <canvas class="od-canvas" aria-label="도안 칸"></canvas>
      <div class="dr-tools od-tools">${[['pen', '붓'], ['fill', '채우기'], ['erase', '지우개']].map(([k, l]) => `<button class="chip-btn" data-tool="${k}">${l}</button>`).join('')}<button class="chip-btn" data-undo>되돌리기</button><button class="chip-btn" data-clear>모두 지우기</button></div>
    </div>
    <div class="od-right">
      <div class="od-prev"><img class="od-anim" alt="걷는 모습"><div class="od-frames"></div><button class="chip-btn" data-flip>좌우 바꿔 보기</button></div>
      <p class="od-h">내 색 <small class="muted">칸을 고르고 아래에서 색을 정합니다</small></p>
      <div class="od-pal"></div>
      <div class="dr-pal od-picks">${PAL.map((c, i) => `<button class="dr-sw" data-pick="${c}" style="--c:${c}" title="${esc(PAL_NAMES[i])}" aria-label="${esc(PAL_NAMES[i])}"></button>`).join('')}<button class="chip-btn" data-own>${icon('palette', 14)} 직접 고르기</button></div>
      <div class="od-deco"></div>
      <label class="field"><span>도안 이름</span><input maxlength="${rules?.title_max || 12}" name="t" placeholder="비워 두어도 됩니다"></label>
      <p class="muted small">밝고 어두운 부분은 원래 옷의 명암을 따라 저절로 칠해집니다. 저장한 도안은 「옷 짓기」로 지어야 입을 수 있습니다.</p>
      <div class="btn-row"><button class="btn primary" data-save>${icon('check', 16)} 도안첩에 담기</button></div>
    </div></div>` });
  let cv = $('.od-canvas', layer), g = cv.getContext('2d');
  const at = (x, y) => { const gx = x + lay.crop[0], gy = y + lay.crop[1]; return lay.pos.findIndex(([px, py]) => px === gx && py === gy); };
  const draw = () => {
    sync();
    const [cx, cy, cw, ch] = lay.crop, px = avatarPixels(look, 'stand'), sc = cv.width / cw;
    g.fillStyle = '#efe6d2'; g.fillRect(0, 0, cv.width, cv.height);
    for (let y = 0; y < ch; y++) for (let x = 0; x < cw; x++) {
      const v = px[(cy + y) * AW + cx + x];
      if (v) { g.fillStyle = v; g.fillRect(x * sc, y * sc, sc, sc); }
      if (at(x, y) < 0) { g.fillStyle = 'rgba(20,16,14,.45)'; g.fillRect(x * sc, y * sc, sc, sc); }
      else { g.strokeStyle = 'rgba(255,255,255,.18)'; g.strokeRect(x * sc + .5, y * sc + .5, sc - 1, sc - 1); }
    }
    paintPrev();
  };
  const paintPrev = () => {
    $('.od-frames', layer).innerHTML = ['stand', 'blink', 'walk'].map(f => `<img src="${avatarImage(look, { frame: f, scale: 2, job: snap.job })}" alt="">`).join('');
    anim();
  };
  const anim = () => { const img = $('.od-anim', layer); if (img) { img.src = avatarImage(look, { frame: frame % 2 ? 'walk' : 'stand', scale: 4, job: snap.job }); img.style.transform = flip ? 'scaleX(-1)' : ''; } };
  timer = setInterval(() => { if (!layer.isConnected) return clearInterval(timer); frame++; anim(); }, 260);
  const paintPal = () => {
    $('.od-pal', layer).innerHTML = pal.map((c, i) => `<button class="od-sw${i === cur ? ' on' : ''}" data-slotc="${i}" style="--c:${c}" aria-label="색 ${i + 1}"><b>${i + 1}</b></button>`).join('') + (pal.length < max ? `<button class="chip-btn" data-addc>+ 색</button>` : '');
    $$('[data-slotc]', layer).forEach(b => b.onclick = () => { cur = +b.dataset.slotc; if (pad) pad.color = String(cur); paintPal(); });
    $('[data-addc]', layer)?.addEventListener('click', () => { pal.push('#f4efe2'); cur = pal.length - 1; if (pad) pad.color = String(cur); paintPal(); draw(); });
  };
  const paintDeco = () => {
    const ks = maskOf(slot, base).deco || [], bp = AV[slot][base].pal;
    $('.od-deco', layer).innerHTML = ks.length ? `<p class="od-h">장식 색 <small class="muted">비우면 원래 색</small></p><div class="od-decos">${ks.map((k, j) => `<span class="od-dk"><button class="od-sw sm" data-deco="${j}" style="--c:${deco[j] || bp[k]}" aria-label="${DECO_NAME[k] || k}"></button><small>${DECO_NAME[k] || k}</small>${deco[j] ? `<button class="chip-btn" data-deco0="${j}">원래대로</button>` : ''}</span>`).join('')}</div>` : '';
    $$('[data-deco]', layer).forEach(b => b.onclick = async () => { const j = +b.dataset.deco, c = await openColorPicker(deco[j] || bp[ks[j]], { title: '장식 색' }); if (c) { deco[j] = c.toLowerCase(); paintDeco(); draw(); } });
    $$('[data-deco0]', layer).forEach(b => b.onclick = () => { deco[+b.dataset.deco0] = ''; paintDeco(); draw(); });
  };
  const paintBases = () => {
    $$('[data-slot]', layer).forEach(b => b.classList.toggle('on', b.dataset.slot === slot));
    $('.od-bases', layer).innerHTML = ownedBases(snap, slot).map(k => `<button class="lk-opt${k === base ? ' on' : ''}" data-base="${esc(k)}" title="${esc(AV[slot][k].name)}"><img src="${avatarImage({ ...me, [slot]: k, top_d: undefined, bottom_d: undefined }, { scale: 2, crop: layout(slot, k).crop, job: snap.job })}" alt=""></button>`).join('') || '<p class="muted small">이 칸에 고를 옷이 없습니다.</p>';
    $$('[data-base]', layer).forEach(b => b.onclick = async () => { if (b.dataset.base === base) return; if (cells.some(c => c !== '.') && !(await ask('바탕 옷을 바꾸면 칠한 칸이 지워집니다. 바꿀까요?', { ok: '바꾸기' }))) return; base = b.dataset.base; build(); });
  };
  const build = () => {
    reset();
    const n = cv.cloneNode(); cv.replaceWith(n); cv = n; g = cv.getContext('2d');
    const sc = Math.max(10, Math.min(24, Math.floor(Math.min(innerWidth - 64, 420) / lay.crop[2])));
    pad = pixelPad(cv, { w: lay.crop[2], h: lay.crop[3], scale: sc, at, cells, draw });
    pad.color = String(cur);
    $$('[data-tool]', layer).forEach(b => b.classList.toggle('on', b.dataset.tool === pad.tool));
    paintBases(); paintPal(); paintDeco();
  };
  $$('[data-slot]', layer).forEach(b => b.onclick = async () => {
    const k = b.dataset.slot; if (k === slot) return;
    const nb = ownedBases(snap, k)[0]; if (!nb) return toast(`${SLOT_NAME[k]}으로 고를 옷이 없습니다.`, 'error');
    if (cells.some(c => c !== '.') && !(await ask('바탕 옷을 바꾸면 칠한 칸이 지워집니다. 바꿀까요?', { ok: '바꾸기' }))) return;
    slot = k; base = nb; build();
  });
  $$('[data-tool]', layer).forEach(b => b.onclick = () => { pad.tool = b.dataset.tool; $$('[data-tool]', layer).forEach(x => x.classList.toggle('on', x === b)); });
  $('[data-undo]', layer).onclick = () => pad.undo();
  $('[data-clear]', layer).onclick = () => pad.clear();
  $('[data-flip]', layer).onclick = () => { flip = !flip; anim(); };
  $$('[data-pick]', layer).forEach(b => b.onclick = () => { pal[cur] = b.dataset.pick.toLowerCase(); paintPal(); draw(); });
  $('[data-own]', layer).onclick = async () => { const c = await openColorPicker(pal[cur], { title: `색 ${cur + 1}` }); if (c) { pal[cur] = c.toLowerCase(); paintPal(); draw(); } };
  $('[data-save]', layer).onclick = e => guard(e.currentTarget, async () => {
    if (!cells.some(c => c !== '.')) throw new Error('한 칸 이상 칠해 주세요.');
    const r = await act('world_outfit_design_save', { p_slot: slot, p_base: base, p_title: $('[name=t]', layer).value.trim(), p_pal: palStr(), p_px: cells.join(''), p_deco: decoStr() });
    clearInterval(timer); layer.close(); done?.(r); return r;
  });
  build();
  return layer;
}

function recipeLine(slot, rules, st) {
  const r = knownRecipes().find(x => x.id === rules?.weave?.[slot]);
  if (!r) return '<p class="muted small">옷 짓는 재료를 불러오지 못했습니다. 가방을 한 번 연 뒤 다시 보세요.</p>';
  const inv = store.character?.inventory || {}, stored = new Map((st?.can_move ? st.items || [] : []).map(i => [i.item_id, Number(i.qty) || 0]));
  const has = k => hqCount(inv, k);
  const box = k => hqCount(Object.fromEntries(stored), k);
  return `<p class="small od-mats">재료 ${Object.entries(r.ingredients || {}).map(([k, n]) => { const ok = has(k) + box(k) >= n; return `<span class="${ok ? 'ok' : 'bad'}">${esc(nameOf(k))} ${n}개 (가방 ${has(k)}${box(k) ? ` · 창고 ${box(k)}` : ''})</span>`; }).join(' · ')}${r.minimum_level > 1 ? ` · Lv.${r.minimum_level}부터` : ''}</p>`;
}

export async function designBook(box, snap, { onWear } = {}) {
  box.innerHTML = '<p class="muted small">불러오는 중…</p>';
  let r, st;
  try { [r, st] = await Promise.all([load('world_outfit_design_list', undefined, { maxAge: 60000 }), load('world_storage_snapshot', undefined, { maxAge: 300000 }).catch(() => null)]); }
  catch (e) { box.innerHTML = errorBox(e.message); return; }
  const rules = r.rules || {}, items = r.items || [], trash = r.trash || [];
  const full = r.kept >= rules.keep, dayFull = r.made_today >= rules.per_day;
  const woven = new Set((snap.owned || []).filter(k => /:@\d+$/.test(k)).map(k => k.split('@')[1]));
  const card = d => `<li class="od-card" data-id="${d.id}">
      <img class="od-pic" src="${designPic(d, { job: snap.job, look: snap.look })}" alt="">
      <div class="od-meta"><b>${esc(d.t || '이름 없는 도안')}</b><small class="muted">${SLOT_NAME[d.slot]} · ${esc(AV[d.slot][d.base]?.name || '')}</small>
        <small class="muted">${d.mine ? '내가 그림' : `${esc(d.a)} 그림${d.gift ? ` · ${esc(d.gift)}님이 보냄` : ''}`}</small>
        ${d.woven ? '<span class="chip ok">옷장에 있음</span>' : ''}</div>
      <div class="od-acts">${d.woven ? (woven.has(String(d.id)) && onWear ? `<button class="btn small primary" data-wear="${d.id}">입기</button>` : '') : `<button class="btn small primary" data-weave="${d.id}" data-here="옷 짓기">${icon('palette', 14)} 옷 짓기</button>`}
        ${d.mine ? `<button class="btn small" data-give="${d.id}">보내기</button>` : `<button class="btn small ghost" data-report="${d.grp}">제보</button>`}
        <button class="btn small ghost" data-del="${d.id}">지우기</button></div></li>`;
  box.innerHTML = `<div class="od-book">
    <div class="od-head"><span class="chip">오늘 새 도안 ${r.made_today}/${rules.per_day}</span><span class="chip">도안첩 ${r.kept}/${rules.keep}</span><span class="chip">오늘 보낸 도안 ${r.given_today}/${rules.give_day}</span>
      <button class="btn small primary" data-new ${full || dayFull ? 'disabled' : ''}>${icon('plus', 14)} 새 도안</button></div>
    ${full ? '<p class="muted small">도안첩이 가득 찼습니다. 안 쓰는 도안을 지우면 새로 그릴 수 있습니다.</p>' : dayFull ? '<p class="muted small">오늘은 새 도안을 다 그렸습니다. 내일 다시 그릴 수 있습니다.</p>' : ''}
    ${items.length ? `<ul class="od-list">${items.map(card).join('')}</ul>` : '<p class="muted small">아직 도안이 없습니다. 옷장에 있는 옷을 바탕으로 무늬를 직접 칠해 보세요.</p>'}
    ${trash.length ? `<details class="fold od-trash"><summary>지운 도안 ${trash.length}</summary><ul class="od-list">${trash.map(d => `<li class="od-card"><img class="od-pic" src="${designPic(d, { job: snap.job, look: snap.look })}" alt=""><div class="od-meta"><b>${esc(d.t || '이름 없는 도안')}</b><small class="muted">${SLOT_NAME[d.slot]}</small></div><div class="od-acts"><button class="btn small" data-restore="${d.id}">되살리기</button></div></li>`).join('')}</ul></details>` : ''}
  </div>`;
  const again = () => designBook(box, snap, { onWear });
  const find = id => items.find(x => String(x.id) === String(id));
  $('[data-new]', box).onclick = () => openDesignEditor(snap, rules, again);
  $$('[data-wear]', box).forEach(b => b.onclick = () => { const d = find(b.dataset.wear); if (d) onWear(d.slot, d.base, d.id); });
  $$('[data-weave]', box).forEach(b => b.onclick = async () => {
    const d = find(b.dataset.weave); if (!d) return;
    const l = openLayer({ title: '옷 짓기', body: `<div class="od-weave"><img class="od-pic" src="${designPic(d, { job: snap.job, look: snap.look })}" alt="">
      <p>${esc(d.t || '이 도안')}으로 ${SLOT_NAME[d.slot]}을 지어 옷장에 넣습니다. 도안은 도안첩에 그대로 남습니다.</p>${recipeLine(d.slot, rules, st)}
      <div class="btn-row"><button class="btn primary" data-go data-here="옷 짓기">짓기</button></div></div>` });
    $('[data-go]', l).onclick = e => guard(e.currentTarget, async () => { const res = await act('world_outfit_design_weave', { p_id: d.id }); l.close(); again(); return res; });
  });
  $$('[data-give]', box).forEach(b => b.onclick = async () => {
    const d = find(b.dataset.give); if (!d) return;
    let fr; try { fr = await load('world_friend_overview'); } catch (e) { return toast(e.message, 'error'); }
    const friends = (fr?.friends || []).filter(f => !f.is_dead);
    if (!friends.length) return toast('도안은 친구에게만 보낼 수 있습니다. 먼저 친구를 맺으세요.', 'error');
    const l = openLayer({ title: '도안 보내기', body: `<div class="od-weave"><img class="od-pic" src="${designPic(d, { job: snap.job, look: snap.look })}" alt="">
      <label class="field"><span>받는 사람 (친구)</span><select name="to">${friends.map(f => `<option value="${esc(f.owner_id)}">${esc(f.character_name)} · Lv.${f.level}</option>`).join('')}</select></label>
      <p class="muted small">사본을 보냅니다. 받은 사람이 옷을 지어 입을 수 있고, 받은 사본은 다시 넘길 수 없습니다. 오늘 ${r.given_today}/${rules.give_day}번 보냈습니다.</p>
      <div class="btn-row"><button class="btn primary" data-send>보내기</button></div></div>` });
    $('[data-send]', l).onclick = e => guard(e.currentTarget, async () => { const res = await act('world_outfit_design_give', { p_id: d.id, p_target: $('select', l).value }); l.close(); again(); return res; });
  });
  $$('[data-del]', box).forEach(b => b.onclick = async () => {
    const d = find(b.dataset.del); if (!d) return;
    if (!(await ask(`도안 「${d.t || '이름 없는 도안'}」을(를) 지울까요? 이미 지은 옷은 그대로 입을 수 있고, 「지운 도안」에서 되살릴 수 있습니다. 오늘 그린 장수는 돌아오지 않습니다.`, { title: '도안 지우기', ok: '지우기' }))) return;
    guard(b, async () => { const res = await act('world_outfit_design_delete', { p_id: d.id }); again(); return res; });
  });
  $$('[data-restore]', box).forEach(b => b.onclick = () => guard(b, async () => { const res = await act('world_outfit_design_restore', { p_id: Number(b.dataset.restore) }); again(); return res; }));
  $$('[data-report]', box).forEach(b => b.onclick = () => {
    const l = openLayer({ title: '도안 제보', body: `<div class="od-weave"><p class="small">이 도안이 부적절하면 운영진에게 알립니다. 제보한 도안은 내 화면에서 숨겨집니다.</p>
      <label class="field"><span>까닭 (200자까지)</span><textarea name="why" rows="3" maxlength="200"></textarea></label>
      <div class="btn-row"><button class="btn danger" data-rep>제보하기</button></div></div>` });
    $('[data-rep]', l).onclick = e => guard(e.currentTarget, async () => { const res = await act('world_outfit_design_report', { p_grp: Number(b.dataset.report), p_reason: $('textarea', l).value.trim() }); l.close(); again(); return res; });
  });
}

export const fmtDesign = d => `${SLOT_NAME[d.slot] || ''} · ${esc(AV[d.slot]?.[d.base]?.name || '')}${d.copies != null ? ` · 사본 ${fmt.num(d.copies)}장` : ''}`;
