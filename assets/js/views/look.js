import { act, store, esc, icon, guard, $, $$, ask, toast } from '../core.js';
import { load, errorBox, invalidate } from './common.js';
import { AV, avatarImage, fixLook, registerDesigns, TONE_KEYS } from '../housing/avatarsprite.js';
import { designBook, cropOf, designPic, openFreeEditor } from './outfitdesign.js';
import { openColorPicker } from '../colorpick.js';
import { hqCount } from '../hq.js';
import { GAMEDATA as GD } from '../gamedata.js';

let draft = null, draftOwner = '', draftJob = '', homeOn = true, faceOn = false, tab = 'hair';
const CROP = { head: [0, 0, 30, 25], face: [5, 11, 20, 12], top: [4, 22, 22, 12], legs: [5, 27, 20, 9], all: null };
const TABS = [
  ['skin', '피부', 'face', [['skin', 'skins', 's']]],
  ['hair', '머리', 'head', [['hair_color', 'hairColors', 'h'], ['hair', 'hair']]],
  ['eyes', '눈', 'face', [['eye_color', 'eyeColors', 'e'], ['eyes', 'eyes']]],
  ['mouth', '입', 'face', [['mouth', 'mouth']]],
  ['top', '윗옷', 'top', [['top', 'top']]],
  ['bottom', '아랫옷', 'legs', [['bottom', 'bottom']]],
  ['acc', '장신구', 'all', [['acc', 'acc']]],
  ['design', '내 도안', 'top', []],
];
const WEAR = ['top', 'bottom', 'acc'];
const FACE_CROP = [2, 0, 26, 26];
const faceNow = () => !!store.character?.profile?.avatar_px;
const plain = l => { const { top_d, bottom_d, ...rest } = l || {}; return rest; };
const pickLook = (slot, k) => { const l = { ...plain(draft), [slot]: k }; if (OVER[slot]) delete l[OVER[slot]]; return l; };
const LOOK_KEYS = ['skin', 'hair', 'hair_color', 'eyes', 'eye_color', 'mouth', 'top', 'bottom', 'acc', 'skin_c', 'hair_c', 'eye_c'];
const dnum = v => v == null || v === '' ? null : Number(v);
const sameLook = (a, b) => LOOK_KEYS.every(k => (a?.[k] || '') === (b?.[k] || '')) && ['top_d', 'bottom_d', 'face_d', 'hair_d'].every(k => dnum(a?.[k]) === dnum(b?.[k]));
const OVER = { eyes: 'face_d', mouth: 'face_d', hair: 'hair_d' };
const FREE_NAME = { face: '직접 그린 눈·입', hair: '직접 그린 머리' };
const FREE_TAB = { face: 'eyes', hair: 'hair' };
const wovenOf = (snap, slot) => (snap.owned || []).filter(k => k.startsWith(slot + ':@')).map(k => k.split('@')[1]).filter(id => snap.designs?.[id]?.base);

function owns(snap, slot, key) {
  return AV.jobDefault[snap.job]?.[slot] === key || (snap.owned || []).includes(`${slot}:${key}`);
}
const wearable = (snap, look) => { const l = fixLook(look, snap.job);
  for (const s of WEAR) if (s !== 'acc' && !l[s + '_d'] && !owns(snap, s, l[s])) l[s] = AV.jobDefault[snap.job]?.[s] ?? l[s];
  return l; };

function pickBlock([slot, table, swatch], crop, snap) {
  const keys = Object.keys(AV[table]), cur = draft[slot];
  const owned = WEAR.includes(slot) ? keys.filter(k => owns(snap, slot, k)) : keys;
  const opts = slot === 'acc' ? ['', ...owned] : owned;
  const locked = keys.length - owned.length;
  if (swatch) {
    const ck = TONE_KEYS[slot]?.[0], own = ck && draft[ck];
    return `<div class="lk-sws">${opts.map(k => { const n = esc(AV[table][k].name); return `<button class="lk-sw${k === cur && !own ? ' on' : ''}" data-lk="${slot}" data-v="${esc(k)}" title="${n}" aria-label="${n}" style="--c:${AV[table][k][swatch]}"></button>`; }).join('')}${ck ? `<button class="lk-sw own${own ? ' on' : ''}" data-lkc="${ck}" data-from="${esc(AV[table][cur]?.[swatch] || '#888888')}" title="직접 고르기" aria-label="직접 고르기" style="--c:${own ? '#' + own : 'transparent'}">${own ? '' : icon('palette', 14)}</button>` : ''}</div>`;
  }
  const dkey = OVER[slot] || slot + '_d', woven = slot === 'top' || slot === 'bottom' ? wovenOf(snap, slot) : [];
  return `<div class="lk-grid">${opts.map(k => { const n = esc(AV[table][k]?.name || '없음'); return `<button class="lk-opt${k === cur && !draft[dkey] ? ' on' : ''}" data-lk="${slot}" data-v="${esc(k)}" title="${n}" aria-label="${n}"><img src="${avatarImage(pickLook(slot, k), { scale: 3, crop: CROP[crop] })}" alt=""></button>`; }).join('')}</div>
    ${woven.length ? `<p class="lk-cur">지은 도안</p><div class="lk-grid">${woven.map(id => { const d = snap.designs[id]; return `<button class="lk-opt${String(draft[dkey]) === id ? ' on' : ''}" data-lkd="${slot}" data-id="${esc(id)}" data-base="${esc(d.base)}" title="도안 · ${esc(AV[slot][d.base]?.name || '')}"><img src="${avatarImage({ ...draft, [slot]: d.base, [dkey]: id }, { scale: 3, crop: cropOf(slot, d.base) || CROP[crop] })}" alt=""></button>`; }).join('')}</div>` : ''}
    ${locked ? `<p class="lk-cur">아직 없는 ${slot === 'acc' ? '장신구' : '옷'} <small class="muted">${locked}${slot === 'acc' ? '가지' : '벌'} · 눌러 얻는 곳 보기</small></p>
    <div class="lk-grid">${keys.filter(k => !owned.includes(k)).map(k => { const n = AV[table][k].name, src = GD.outfit?.src?.[`${slot}:${k}`] || ''; return `<span class="lk-opt lk-lock" tabindex="0" data-tip="${esc(n)}${src ? ' — ' + esc(src) : ''}" aria-label="${esc(n)}"><img src="${avatarImage(pickLook(slot, k), { scale: 3, crop: CROP[crop] })}" alt=""></span>`; }).join('')}</div>
    <p class="muted small">물품으로 얻은 옷은 가방에서 「옷장에」를 누르고, 칭호·행사로 얻는 옷은 옷장에 바로 들어갑니다.</p>` : ''}`;
}

function freeBlock(slot, snap) {
  const ds = Object.entries(snap.designs || {}).filter(([, d]) => d.slot === slot);
  const keep = GD.outfit?.[slot]?.keep || (slot === 'face' ? 3 : 10), has = slot === 'hair' ? hqCount(store.character?.inventory || {}, 'hair_pattern') : 1;
  const can = ds.length < keep && has > 0;
  return `<p class="lk-cur">${FREE_NAME[slot]} <small class="muted">${ds.length}/${keep}${slot === 'hair' ? ` · 머리 그리기 도안 ${has}장` : ''}</small></p>
    <div class="lk-grid">${ds.map(([id, d]) => `<button class="lk-opt${String(draft[slot + '_d'] ?? '') === id ? ' on' : ''}" data-lkf="${slot}" data-id="${esc(id)}" title="${FREE_NAME[slot]}"><img src="${designPic(d, { job: snap.job, look: draft })}" alt=""></button>`).join('')}<button class="lk-opt lk-new" data-lknew="${slot}" ${can ? '' : 'disabled'} title="${slot === 'face' ? '눈·입 그리기' : '머리 그리기'}" aria-label="${slot === 'face' ? '눈·입 그리기' : '머리 그리기'}">${icon('plus', 20)}</button></div>
    ${ds.some(([id]) => String(draft[slot + '_d'] ?? '') === id) ? `<div class="btn-row lk-free-acts"><button class="btn small" data-lkedit="${slot}">${icon('palette', 14)} 이 ${slot === 'face' ? '눈·입' : '머리'} 고치기</button><button class="btn small ghost" data-lkdel="${slot}">지우기</button></div>` : ''}
    ${slot === 'hair' && has < 1 ? '<p class="muted small">머리를 그리려면 「머리 그리기 도안」이 있어야 합니다. 비장고에서 나오고, 거래소에서 사고팔 수 있습니다.</p>' : ''}`;
}

export async function lookTab(body) {
  const c = store.character;
  const snap = await load('world_avatar_get', undefined, { maxAge: 600000 });
  if (!snap) { body.innerHTML = errorBox('모습을 불러오지 못했습니다.'); return; }
  registerDesigns(snap.designs);
  if (!draft || draftOwner !== c.owner_id || draftJob !== snap.job) { draft = wearable(snap, snap.look); draftJob = snap.job; draftOwner = c.owner_id; homeOn = snap.home_on !== false; faceOn = faceNow(); }
  const dirty = !sameLook(fixLook(snap.look, snap.job), draft) || homeOn !== (snap.home_on !== false) || faceOn !== faceNow();
  const cur = TABS.find(t => t[0] === tab) || TABS[1];
  const curName = cur[3].filter(x => !x[2]).map(([s, t]) => AV[t][draft[s]]?.name).concat(cur[3].filter(x => x[2]).map(([s, t]) => AV[t][draft[s]]?.name)).filter(Boolean).join(' · ');
  body.innerHTML = `<div class="lk-wrap">
    <div class="panel lk-stage">
      <img class="lk-big" src="${avatarImage(draft, { scale: 6 })}" alt="내 모습">
      <div class="lk-side">
        <div class="lk-frames">${['stand', 'blink', 'walk'].map(f => `<img src="${avatarImage(draft, { frame: f, scale: 2 })}" alt="">`).join('')}</div>
        <label class="lk-home"><input type="checkbox" id="lk-home" ${homeOn ? 'checked' : ''}> 별채에 세우기</label>
        <label class="lk-home" title="채팅·조사원 카드·목록의 얼굴을 내 모습의 얼굴로 씁니다(올린 사진 대신)"><input type="checkbox" id="lk-face" ${faceOn ? 'checked' : ''}> 얼굴로 쓰기<img class="lk-face" src="${avatarImage(draft, { scale: 1, crop: FACE_CROP })}" alt=""></label>
        <div class="lk-act"><button class="btn ghost sm" id="lk-reset" ${dirty ? '' : 'disabled'}>되돌리기</button><button class="btn primary sm" id="lk-save" ${dirty ? '' : 'disabled'}>${icon('palette', 16)} 이 모습으로</button></div>
      </div>
    </div>
    <div class="panel lk-pick">
      <div class="lk-tabs" role="tablist">${TABS.map(([k, l, crop]) => `<button role="tab" class="lk-tab${k === cur[0] ? ' on' : ''}" data-lktab="${k}" aria-selected="${k === cur[0]}" title="${l}"><img src="${avatarImage(draft, { scale: 2, crop: CROP[crop] })}" alt=""><span>${l}</span></button>`).join('')}</div>
      <p class="lk-cur">${esc(cur[1])} <small class="muted">${esc(curName)}</small></p>
      ${cur[0] === 'design' ? '<div class="lk-design"></div>' : cur[3].map(b => pickBlock(b, cur[2], snap)).join('') + (cur[0] === 'eyes' || cur[0] === 'mouth' ? freeBlock('face', snap) : cur[0] === 'hair' ? freeBlock('hair', snap) : '')}
    </div>
  </div>`;
  $$('[data-lktab]', body).forEach(b => b.onclick = () => { tab = b.dataset.lktab; lookTab(body); });
  $$('[data-lk]', body).forEach(b => b.onclick = () => { const k = b.dataset.lk; draft = { ...draft, [k]: b.dataset.v }; delete draft[OVER[k] || k + '_d']; if (TONE_KEYS[k]) delete draft[TONE_KEYS[k][0]]; lookTab(body); });
  $$('[data-lkc]', body).forEach(b => b.onclick = async () => { const k = b.dataset.lkc, c = await openColorPicker(draft[k] ? '#' + draft[k] : b.dataset.from, { title: '직접 고르는 색' }); if (c) { draft = { ...draft, [k]: c.slice(1).toLowerCase() }; lookTab(body); } });
  $$('[data-lkf]', body).forEach(b => b.onclick = () => { draft = { ...draft, [b.dataset.lkf + '_d']: dnum(b.dataset.id) }; lookTab(body); });
  $$('[data-lkedit]', body).forEach(b => b.onclick = async () => {
    const sl = b.dataset.lkedit, id = String(draft[sl + '_d'] ?? '');
    let list; try { list = await load('world_outfit_design_list', undefined, { maxAge: 60000 }); } catch (e) { return toast(e.message, 'error'); }
    const d = (list?.items || []).find(x => String(x.id) === id);
    if (!d) return toast('도안을 찾을 수 없습니다.', 'error');
    if (!d.mine) return toast('받은 도안은 고칠 수 없습니다.', 'error');
    openFreeEditor(sl, { ...snap, look: draft }, () => { invalidate('world_outfit_design_list'); lookTab(body); }, d);
  });
  $$('[data-lkdel]', body).forEach(b => b.onclick = async () => {
    const sl = b.dataset.lkdel, id = dnum(draft[sl + '_d']), nm = sl === 'face' ? '눈·입' : '머리';
    if (!(await ask(`쓰고 있는 ${nm} 도안을 지울까요? 처음 고른 모양으로 돌아가고, 「내 도안」의 「지운 도안」에서 되살릴 수 있습니다.`, { title: '도안 지우기', ok: '지우기' }))) return;
    guard(b, async () => {
      const res = await act('world_outfit_design_delete', { p_id: id });
      invalidate('world_avatar_get'); invalidate('world_outfit_design_list');
      draft = { ...draft }; delete draft[sl + '_d'];
      if (snap.designs) delete snap.designs[String(id)];
      lookTab(body); return res;
    });
  });
  $$('[data-lknew]', body).forEach(b => b.onclick = () => openFreeEditor(b.dataset.lknew, { ...snap, look: draft }, r => { invalidate('world_avatar_get'); if (r?.saved) draft = { ...draft, [b.dataset.lknew + '_d']: r.saved }; lookTab(body); }));
  $$('[data-lkd]', body).forEach(b => b.onclick = () => { const k = b.dataset.lkd; draft = { ...draft, [k]: b.dataset.base, [k + '_d']: dnum(b.dataset.id) }; lookTab(body); });
  if (cur[0] === 'design') designBook($('.lk-design', body), snap, { onDel: d => { invalidate('world_avatar_get'); const k = d.slot + '_d'; if (FREE_TAB[d.slot] && dnum(draft[k]) === dnum(d.id)) { draft = { ...draft }; delete draft[k]; } }, onWear: (slot, base, id) => { invalidate('world_avatar_get'); draft = FREE_TAB[slot] ? { ...draft, [slot + '_d']: dnum(id) } : { ...draft, [slot]: base, [slot + '_d']: dnum(id) }; tab = FREE_TAB[slot] || slot; lookTab(body); } });
  $('#lk-home', body).onchange = e => { homeOn = e.target.checked; lookTab(body); };
  $('#lk-face', body).onchange = e => { faceOn = e.target.checked; lookTab(body); };
  $('#lk-reset', body).onclick = () => { draft = wearable(snap, snap.look); homeOn = snap.home_on !== false; faceOn = faceNow(); lookTab(body); };
  $('#lk-save', body).onclick = e => guard(e.currentTarget, async () => {
    const r = await act('world_avatar_set', { p_look: draft, p_home_on: homeOn });
    if (r?.look) draft = wearable(snap, r.look);
    if (typeof r?.home_on === 'boolean') homeOn = r.home_on;
    if (faceOn) await act('world_set_avatar_px', { p_image: avatarImage(draft, { scale: 4, crop: FACE_CROP, job: snap.job }) });
    else if (faceNow()) await act('world_set_avatar', { p_image: null });
    return r;
  }, { success: '모습을 바꿨습니다.' });
}
