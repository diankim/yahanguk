import { store, rpc, act, ask, esc, icon, guard, $, $$, fmt, openModal, closeModal } from './core.js';
import { load } from './views/common.js';
import { untradeNote, giveable } from './views/services.js';
import { pickRows, openItemPick, bundleChips } from './views/itempick.js';
import { loadLocks } from './views/item.js';
import { playDialogue } from './factionquest.js';
import { NPC_LOOKS, NPC_DESIGNS } from './housing/npcs.js';
import { avatarImage, registerDesigns } from './housing/avatarsprite.js';
import { KIN } from './rules.js';
import { helpQ } from './tips.js';
import { kinTokenSvg } from './kintoken.js';

let ready = false;
export function kinLook(npc) {
  if (!ready) { registerDesigns(NPC_DESIGNS); ready = true; }
  return NPC_LOOKS[npc] || null;
}
const bondAgain = () => import('./bond.js').then(m => m.loadBond(true)).catch(() => {});
export const kinFace = (npc, scale = 2) => { const l = kinLook(npc); return l ? avatarImage(l, { scale, crop: [2, 0, 26, 26] }) : ''; };

export function playKin(name, ...talks) {
  const lines = [];
  for (const t of talks) for (const [s, x] of t?.lines || []) lines.push({ s: s || null, t: x });
  if (!lines.length) return;
  const cast = Object.fromEntries(lines.filter(l => l.s).map(l => [l.s, { name: l.s }]));
  playDialogue({ title: name || '백년지기', lines, cast });
}

export async function kinTalk(k, after) {
  const r = await act('world_kin_talk');
  if (!r) return;
  playKin(k.name, r.talk);
  bondAgain();
  after?.(r);
  return r;
}

export async function kinGreet(k) {
  const r = await rpc('world_kin_greet', { p_owner: k.owner });
  playKin(k.name, r.talk);
}

export async function kinWear(k, wear, after) {
  const r = await act('world_kin_wear', { p_wear: wear });
  bondAgain();
  after?.(r);
  return r;
}

export async function kinRoom(room, after) {
  const r = await act('world_kin_room_set', { p_room: room });
  after?.(r);
  return r;
}

export async function kinGift(k, after) {
  const [inv] = await Promise.all([load('world_inventory_snapshot', undefined, { maxAge: 10000 }).catch(() => null), loadLocks()]);
  const have = inv?.inventory || store.character?.inventory || {};
  const ref = new Map((inv?.catalog || []).map(i => [i.id, i]));
  const rows = pickRows(giveable(have, ref, false).map(([id, n]) => ({ id, have: n, max: 1 })), inv?.catalog);
  const note = untradeNote(have, ref, false);
  let sel = {};
  const m = openModal({ title: `${k.name}에게 선물`, body: `<form class="kin-gift">
    <p class="desc">${esc(KIN.giftTip(k.name, k.line_name, k.npc))}</p>
    <div class="chips" data-gift-chips></div>
    <button class="btn small dt-pick" type="button" data-gift-add ${rows.length ? '' : 'disabled'}>${icon('bag', 15)}<span>가방에서 고르기</span></button>
    ${note}
    <button class="btn primary block" type="submit">${icon('heart', 16)}<span>건네기</span></button></form>` });
  const f = $('.kin-gift', m);
  const draw = () => { const box = $('[data-gift-chips]', f); box.innerHTML = bundleChips(sel); $$('[data-rm]', box).forEach(x => x.onclick = () => { sel = {}; draw(); }); };
  draw();
  $('[data-gift-add]', f).onclick = () => openItemPick({ title: '건넬 물품', rows, many: true, picked: sel, kinds: 1, okText: '이대로 고르기', note, onDone: p => { sel = Object.fromEntries(Object.keys(p).slice(0, 1).map(id => [id, 1])); draw(); } });
  f.onsubmit = e => {
    e.preventDefault();
    const [id] = Object.keys(sel); if (!id) return;
    guard(f.querySelector('button[type=submit]'), async () => {
      const r = await act('world_kin_gift', { p_item: id });
      closeModal();
      playKin(k.name, r.talk, r.reward_talk);
      after?.(r);
      return r;
    });
  };
}

export function kinSectionHtml(v) {
  if (!v) return '';
  const tok = `${kinTokenSvg(v.npc, 16)}「${esc(v.token)}」`;
  let body;
  if (v.mine) {
    body = `<p>${esc(v.name + '이(가)')} 내 백년지기입니다 · 정표 ${tok}${v.wear ? ' <span class="chip ok">차는 중</span>' : ' <span class="chip">벗어 둠</span>'}</p>
      <p class="muted small">${esc(KIN.mineTip)}</p>
      <div class="btn-row"><button type="button" class="btn small" data-kin-break data-here="백년지기 끊기">끊기</button></div>`;
  } else if (v.can_make) {
    body = `<p>${esc(KIN.offer(v.name, v.token, v.cost, v.again))}</p>
      <div class="btn-row"><button type="button" class="btn small primary" data-kin-make data-here="백년지기 맺기">${icon('knot', 14)} 백년지기 맺기 · ${fmt.jeon(v.cost)}</button></div>`;
  } else {
    body = `<p class="muted small">${esc(v.why || '')}${v.rebond_until ? ` · ${esc(fmt.when(v.rebond_until))}부터` : ''}</p>`;
  }
  return `<section class="kin-sec"><h3>${icon('knot', 15)} 백년지기 ${helpQ(KIN.tip(), '백년지기 안내')}</h3>${body}</section>`;
}

export function bindKinSection(box, v, redraw) {
  $('[data-kin-make]', box)?.addEventListener('click', e => guard(e.currentTarget, async () => {
    if (!(await ask(KIN.makeAsk(v.name, v.token, v.cost), { title: '백년지기 맺기', ok: '맺기' }))) return;
    const r = await act('world_kin_make', { p_npc: v.npc });
    playKin(v.name, r.talk);
    bondAgain();
    redraw?.(r.view);
    return r;
  }));
  $('[data-kin-break]', box)?.addEventListener('click', e => guard(e.currentTarget, async () => {
    if (!(await ask(KIN.breakAsk(v.name, v.token), { title: '백년지기 끊기', ok: '끊기', danger: true }))) return;
    const r = await act('world_kin_break');
    playKin(v.name, r.talk);
    bondAgain();
    redraw?.(r.view);
    return r;
  }));
}
