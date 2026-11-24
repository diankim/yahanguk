import { rpc, act, ask, esc, guard, $, $$, fmt, openModal } from './core.js';
import { ownSlot, fillOwned } from './owned.js';
import { rarRow } from './views/common.js';

const KIND = { frame: '테두리', pattern: '바탕 무늬', seal: '낙관', name_style: '이름 색', pet: '꼬마 동무', outfit: '옷·장신구' };
const kindOf = x => KIND[x.kind] || (String(x.id).startsWith('hp_') ? '벽지' : String(x.id).startsWith('hg_') ? '바닥재' : String(x.id).startsWith('hf_') ? '가구' : '물품');

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
      <p class="muted small">${esc(b.token_name || '')} <b>${fmt.num(have)}</b>개 · ${esc(`${b.name || ''}을(를)`)} 깰 때마다 얻습니다. 물품마다 한 번만 바꿀 수 있고, 모두 거래할 수 없으며 능력치 효과는 없습니다.</p>
      ${b.open ? '' : '<p class="hint warn">이곳에서 받는 무용담 퀘스트를 마치면 이 싸움이 열립니다.</p>'}
      <ul class="mt-shop">${rows.map(x => `<li class="${rarRow(x.id)} ${x.owned ? 'have' : ''}"><div><b>${esc(x.name)}</b>${String(x.name).endsWith(kindOf(x)) ? '' : `<small>${esc(kindOf(x))}</small>`}${x.owned ? '' : ownSlot(x.kind === 'pet' ? 'pet:' + x.id : x.kind === 'outfit' ? 'look:' + x.id : x.id)}</div>
        <span class="mt-price ug">${fmt.num(x.price)}<small> ${esc(b.token_name || '개')}</small></span>
        ${x.owned ? '<span class="chip ok">바꿈</span>' : `<button class="btn small ${have >= x.price ? 'primary' : ''}" data-here="토큰 교환" data-ug-buy="${esc(x.key)}" ${have >= x.price ? '' : 'disabled'}>바꾸기</button>`}</li>`).join('')}</ul>`;
    fillOwned($('#ug-body', m));
    $$('[data-ug-buy]', m).forEach(btn => btn.onclick = () => guard(btn, async () => {
      const x = (s.items || []).find(v => v.key === btn.dataset.ugBuy);
      if (!await ask(`${x.name}을(를) ${b.token_name} ${x.price}개로 바꿀까요? 같은 것은 다시 바꿀 수 없습니다.`, { title: '무용담 교환', ok: '바꾸기' })) return;
      const r = await act('world_ultimate_buy', { p_key: x.key });
      s = await rpc('world_ultimate_shop', { p_board: board || null }); draw(); return r;
    }));
  };
  draw();
  return m;
}
