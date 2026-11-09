import { act, store, esc, icon, guard, $, $$ } from '../core.js';
import { load, errorBox } from './common.js';
import { AV, avatarImage, fixLook } from '../housing/avatarsprite.js';

let draft = null, draftOwner = '', homeOn = true, faceOn = false, tab = 'hair';
const CROP = { head: [0, 0, 30, 25], face: [5, 11, 20, 12], top: [4, 22, 22, 12], legs: [5, 27, 20, 9], all: null };
const TABS = [
  ['skin', '피부', 'face', [['skin', 'skins', 's']]],
  ['hair', '머리', 'head', [['hair_color', 'hairColors', 'h'], ['hair', 'hair']]],
  ['eyes', '눈', 'face', [['eye_color', 'eyeColors', 'e'], ['eyes', 'eyes']]],
  ['mouth', '입', 'face', [['mouth', 'mouth']]],
  ['top', '윗옷', 'top', [['top', 'top']]],
  ['bottom', '아랫옷', 'legs', [['bottom', 'bottom']]],
  ['acc', '장신구', 'all', [['acc', 'acc']]],
];
const WEAR = ['top', 'bottom', 'acc'];
const FACE_CROP = [2, 0, 26, 26];
const faceNow = () => !!store.character?.profile?.avatar_px;

function owns(snap, slot, key) {
  return AV.jobDefault[snap.job]?.[slot] === key || (snap.owned || []).includes(`${slot}:${key}`);
}

function pickBlock([slot, table, swatch], crop, snap) {
  const keys = Object.keys(AV[table]), cur = draft[slot];
  const owned = WEAR.includes(slot) ? keys.filter(k => owns(snap, slot, k)) : keys;
  const opts = slot === 'acc' ? ['', ...owned] : owned;
  const locked = keys.length - owned.length;
  if (swatch) return `<div class="lk-sws">${opts.map(k => { const n = esc(AV[table][k].name); return `<button class="lk-sw${k === cur ? ' on' : ''}" data-lk="${slot}" data-v="${esc(k)}" title="${n}" aria-label="${n}" style="--c:${AV[table][k][swatch]}"></button>`; }).join('')}</div>`;
  return `<div class="lk-grid">${opts.map(k => { const n = esc(AV[table][k]?.name || '없음'); return `<button class="lk-opt${k === cur ? ' on' : ''}" data-lk="${slot}" data-v="${esc(k)}" title="${n}" aria-label="${n}"><img src="${avatarImage({ ...draft, [slot]: k }, { scale: 3, crop: CROP[crop] })}" alt=""></button>`; }).join('')}</div>
    ${locked ? `<p class="muted small">아직 없는 ${slot === 'acc' ? '장신구' : '옷'} ${locked}${slot === 'acc' ? '가지' : '벌'} — 상점·제작·퀘스트로 얻습니다.</p>` : ''}`;
}

export async function lookTab(body) {
  const c = store.character;
  const snap = await load('world_avatar_get', undefined, { maxAge: 600000 });
  if (!snap) { body.innerHTML = errorBox('모습을 불러오지 못했습니다.'); return; }
  if (!draft || draftOwner !== c.owner_id) { draft = fixLook(snap.look, snap.job); draftOwner = c.owner_id; homeOn = snap.home_on !== false; faceOn = faceNow(); }
  const saved = JSON.stringify(fixLook(snap.look, snap.job)), dirty = saved !== JSON.stringify(draft) || homeOn !== (snap.home_on !== false) || faceOn !== faceNow();
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
      ${cur[3].map(b => pickBlock(b, cur[2], snap)).join('')}
    </div>
  </div>`;
  $$('[data-lktab]', body).forEach(b => b.onclick = () => { tab = b.dataset.lktab; lookTab(body); });
  $$('[data-lk]', body).forEach(b => b.onclick = () => { draft = { ...draft, [b.dataset.lk]: b.dataset.v }; lookTab(body); });
  $('#lk-home', body).onchange = e => { homeOn = e.target.checked; lookTab(body); };
  $('#lk-face', body).onchange = e => { faceOn = e.target.checked; lookTab(body); };
  $('#lk-reset', body).onclick = () => { draft = fixLook(snap.look, snap.job); homeOn = snap.home_on !== false; faceOn = faceNow(); lookTab(body); };
  $('#lk-save', body).onclick = e => guard(e.currentTarget, async () => {
    const r = await act('world_avatar_set', { p_look: draft, p_home_on: homeOn });
    if (faceOn) await act('world_set_avatar_px', { p_image: avatarImage(draft, { scale: 4, crop: FACE_CROP, job: snap.job }) });
    else if (faceNow()) await act('world_set_avatar', { p_image: null });
    return r;
  }, { success: '모습을 바꿨습니다.' });
}
