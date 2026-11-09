import { act, store, esc, icon, guard, $, $$ } from '../core.js';
import { load, errorBox } from './common.js';
import { AV, avatarImage, fixLook } from '../housing/avatarsprite.js';

let draft = null, draftOwner = '', homeOn = true;
const FACE = [['skin', '피부', 'skins', 'color', 's'], ['hair', '머리 모양', 'hair'], ['hair_color', '머리 색', 'hairColors', 'color', 'h'], ['eyes', '눈', 'eyes'], ['eye_color', '눈 색', 'eyeColors', 'color', 'e'], ['mouth', '입', 'mouth']];
const WEAR = [['top', '윗옷', 'top'], ['bottom', '아랫옷', 'bottom']];

function owns(snap, slot, key) {
  return AV.jobDefault[snap.job]?.[slot] === key || (snap.owned || []).includes(`${slot}:${key}`);
}

function chooser(slot, label, table, kind, swatch, snap) {
  const keys = Object.keys(AV[table]), cur = draft[slot];
  const opts = keys.filter(k => !WEAR.some(w => w[0] === slot) || owns(snap, slot, k));
  const locked = keys.length - opts.length;
  const btn = k => {
    const on = k === cur ? ' on' : '', name = esc(AV[table][k].name);
    if (kind === 'color') return `<button class="lk-sw${on}" data-lk="${slot}" data-v="${esc(k)}" title="${name}" aria-label="${name}" style="--c:${AV[table][k][swatch]}"></button>`;
    return `<button class="lk-opt${on}" data-lk="${slot}" data-v="${esc(k)}" title="${name}"><img src="${avatarImage({ ...draft, [slot]: k }, { scale: 2 })}" alt=""><small>${name}</small></button>`;
  };
  return `<section class="lk-sec"><h3>${label}${locked ? ` <small class="muted">· 아직 없는 옷 ${locked}</small>` : ''}</h3><div class="${kind === 'color' ? 'lk-sws' : 'lk-opts'}">${opts.map(btn).join('')}</div></section>`;
}

export async function lookTab(body) {
  const c = store.character;
  const snap = await load('world_avatar_get', undefined, { maxAge: 600000 });
  if (!snap) { body.innerHTML = errorBox('모습을 불러오지 못했습니다.'); return; }
  if (!draft || draftOwner !== c.owner_id) { draft = fixLook(snap.look, snap.job); draftOwner = c.owner_id; homeOn = snap.home_on !== false; }
  const saved = JSON.stringify(fixLook(snap.look, snap.job)), dirty = saved !== JSON.stringify(draft) || homeOn !== (snap.home_on !== false);
  body.innerHTML = `<div class="lk-wrap">
    <div class="panel lk-stage">
      <img class="lk-big" src="${avatarImage(draft, { scale: 6 })}" alt="내 모습">
      <div class="lk-frames">${['stand', 'blink', 'walk'].map(f => `<img src="${avatarImage(draft, { frame: f, scale: 2 })}" alt="">`).join('')}</div>
      <label class="lk-home"><input type="checkbox" id="lk-home" ${homeOn ? 'checked' : ''}> 별채에 세우기</label>
      <div class="lk-act"><button class="btn ghost sm" id="lk-reset" ${dirty ? '' : 'disabled'}>되돌리기</button><button class="btn primary" id="lk-save" ${dirty ? '' : 'disabled'}>${icon('palette', 16)} 이 모습으로</button></div>
      <p class="muted small">옷은 직업 기본 한 벌이 처음부터 있고, 다른 옷은 상점·제작·퀘스트로 얻습니다.</p>
    </div>
    <div class="lk-picks">${FACE.map(([s, l, t, k, w]) => chooser(s, l, t, k, w, snap)).join('')}${WEAR.map(([s, l, t]) => chooser(s, l, t, '', '', snap)).join('')}</div>
  </div>`;
  $$('[data-lk]', body).forEach(b => b.onclick = () => { draft = { ...draft, [b.dataset.lk]: b.dataset.v }; lookTab(body); });
  $('#lk-home', body).onchange = e => { homeOn = e.target.checked; lookTab(body); };
  $('#lk-reset', body).onclick = () => { draft = fixLook(snap.look, snap.job); homeOn = snap.home_on !== false; lookTab(body); };
  $('#lk-save', body).onclick = e => guard(e.currentTarget, () => act('world_avatar_set', { p_look: draft, p_home_on: homeOn }), { success: '모습을 바꿨습니다.' });
}
