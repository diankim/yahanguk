import { rpc, act, ask, esc, guard, $, $$, fmt, openModal, openLayer, store } from './core.js';
import { ownSlot, fillOwned } from './owned.js';
import { rarRow, load } from './views/common.js';
import { AV, fixLook, registerDesigns } from './housing/avatarsprite.js';
import { wornBar, wornImg } from './views/wornbar.js';

const KIND = { frame: '테두리', pattern: '바탕 무늬', seal: '낙관', name_style: '이름 색', pet: '꼬마 동무', outfit: '옷·장신구' };
const kindOf = x => KIND[x.kind] || (String(x.id).startsWith('hp_') ? '벽지' : String(x.id).startsWith('hg_') ? '바닥재' : String(x.id).startsWith('hf_') ? '가구' : '물품');
const isFurn = x => /^h[fpg]_/.test(String(x.id));
const lookOf = x => { const [slot, key] = String(x.id).split(':'); return AV[slot]?.[key] ? [slot, key] : null; };
const canPic = x => isFurn(x) || x.kind === 'pet' || (x.kind === 'outfit' && lookOf(x));
const CROP = { top: [4, 14, 22, 20], bottom: [5, 24, 20, 12], acc: [0, 0, 30, 26] };

async function myLook() {
  const job = store.character?.job_key;
  try { const s = await load('world_avatar_get', undefined, { maxAge: 600000 }); if (s?.look) { registerDesigns(s.designs); return [fixLook(s.look, s.job), s.job]; } } catch {}
  return [fixLook({}, job), job];
}

async function picOf(x, big) {
  if (isFurn(x)) { const { furnPic } = await import('./housing/thumbs.js'); return furnPic(x.id); }
  if (x.kind === 'pet') {
    const { petImage } = await import('./housing/petsprite.js');
    return big ? `<img class="ug-pet" src="${petImage(x.id, false, { scale: 5 })}" alt="아기 모습"><img class="ug-pet" src="${petImage(x.id, true, { scale: 5 })}" alt="다 자란 모습">`
      : `<img src="${petImage(x.id, true, { scale: 2 })}" alt="">`;
  }
  const lk = lookOf(x); if (!lk) return '';
  const [look, job] = await myLook(), l = { ...look, [lk[0]]: lk[1] };
  delete l[lk[0] + '_d'];
  return big ? wornImg(l, lk[0], { scale: 6, job }, 'ug-big') + wornBar(lk[0]) : wornImg(l, lk[0], { scale: 2, job, crop: CROP[lk[0]] || null }, '');
}

function openPreview(x) {
  const layer = openLayer({ title: x.name, body: `<div class="ug-prev" data-ug-big><p class="muted small">불러오는 중…</p></div><p class="muted small ug-prev-note">${esc(kindOf(x))}${x.kind === 'outfit' ? ' · 지금 내 모습에 입혀 본 그림입니다.' : x.kind === 'pet' ? ' · 아기 모습과 다 자란 모습입니다.' : ''}</p>` });
  picOf(x, true).then(h => { const box = $('[data-ug-big]', layer); if (box) box.innerHTML = h || '<p class="muted small">미리 볼 그림이 없습니다.</p>'; }).catch(() => {});
}

export async function openUltimateShop(board) {
  let s;
  try { s = await rpc('world_ultimate_shop', { p_board: board || null }); } catch { return null; }
  const boards = Object.entries(s.boards || {});
  let cur = board && s.boards?.[board] ? board : boards[0]?.[0];
  const m = openModal({ title: '무용담 교환', body: '<div id="ug-body"></div>' });
  const draw = () => {
    const b = s.boards[cur] || {}, have = Number(s.tokens?.[cur] || 0);
    const rows = (s.items || []).filter(x => x.board === cur);
    $('#ug-body', m).innerHTML = `<h3 class="sub-h">${esc(b.name || '')} 교환</h3>
      <p class="muted small">${esc(b.token_name || '')} <b>${fmt.num(have)}</b>개 · ${esc(`${b.name || ''}을(를)`)} 깰 때마다 얻습니다. 물품마다 한 번만 바꿀 수 있고, 모두 거래할 수 없으며 능력치 효과는 없습니다. 그림을 누르면 크게 봅니다.</p>
      ${b.open ? '' : '<p class="hint warn">이곳에서 받는 무용담 퀘스트를 마치면 이 싸움이 열립니다.</p>'}
      <ul class="mt-shop ug-shop">${rows.map(x => `<li class="${rarRow(x.id)} ${x.owned ? 'have' : ''}">${canPic(x) ? `<button type="button" class="ug-thumb" data-ug-pic="${esc(x.key)}" aria-label="${esc(x.name)} 크게 보기"></button>` : '<span class="ug-thumb none"></span>'}<div>${canPic(x) ? `<button type="button" class="link-btn ug-name" data-ug-see="${esc(x.key)}"><b>${esc(x.name)}</b></button>` : `<b>${esc(x.name)}</b>`}${String(x.name).endsWith(kindOf(x)) ? '' : `<small>${esc(kindOf(x))}</small>`}${x.owned ? '' : ownSlot(x.kind === 'pet' ? 'pet:' + x.id : x.kind === 'outfit' ? 'look:' + x.id : x.id)}</div>
        <span class="mt-price ug">${fmt.num(x.price)}<small> ${esc(b.token_name || '개')}</small></span>
        ${x.owned ? '<span class="chip ok">바꿈</span>' : `<button class="btn small ${have >= x.price ? 'primary' : ''}" data-here="토큰 교환" data-ug-buy="${esc(x.key)}" ${have >= x.price ? '' : 'disabled'}>바꾸기</button>`}</li>`).join('')}</ul>`;
    fillOwned($('#ug-body', m));
    const byKey = k => (s.items || []).find(v => v.key === k);
    $$('[data-ug-pic]', m).forEach(el => { const x = byKey(el.dataset.ugPic); picOf(x, false).then(h => { if (el.isConnected) el.innerHTML = h; }).catch(() => {}); el.onclick = () => openPreview(x); });
    $$('[data-ug-see]', m).forEach(el => el.onclick = () => openPreview(byKey(el.dataset.ugSee)));
    $$('[data-ug-buy]', m).forEach(btn => btn.onclick = () => guard(btn, async () => {
      const x = byKey(btn.dataset.ugBuy);
      if (!await ask(`${x.name}을(를) ${b.token_name} ${x.price}개로 바꿀까요? 같은 것은 다시 바꿀 수 없습니다.`, { title: '무용담 교환', ok: '바꾸기' })) return;
      const r = await act('world_ultimate_buy', { p_key: x.key });
      s = await rpc('world_ultimate_shop', { p_board: board || null }); draw(); return r;
    }));
  };
  draw();
  return m;
}
