import { rpc, act, esc, icon, $, toast, guard, openLayer } from '../core.js';
import { helpQ } from '../tips.js';
import { PORTRAIT_BOOK, portraitImg } from '../portrait_book.js';
import { portraitPic } from '../housing/portraits.js';

const HELP = '초상 화첩 — 이야기에서 만난 인물의 초상을 모읍니다. ' +
  '얻는 곳: 그 인물이 처음 크게 나오는 이야기를 마치면 화첩에 열립니다. 열리기 전 칸에는 어느 이야기를 마치면 되는지 적혀 있습니다. ' +
  '액자로 거는 법: 열린 인물을 눌러 「꺼내기」를 누르면 초상 액자가 별채 곳간에 들어옵니다. 별채 「꾸미기」에서 벽에 걸고, 걸린 액자를 누르면 큰 그림을 봅니다. 같은 인물 액자는 하나만 가질 수 있고, 버려도 화첩에서 다시 꺼낼 수 있습니다. ' +
  '초상 그림은 생성형 AI로 만든 이미지입니다.';

const dotCache = {};
function dotURL(k, scale = 4) {
  const key = k + scale;
  if (dotCache[key]) return dotCache[key];
  const p = portraitPic(k); if (!p) return '';
  const c = document.createElement('canvas'); c.width = p.w * scale; c.height = p.h * scale;
  const g = c.getContext('2d');
  p.rgb.forEach((col, i) => { g.fillStyle = col; g.fillRect((i % p.w) * scale, Math.floor(i / p.w) * scale, scale, scale); });
  return dotCache[key] = c.toDataURL();
}

const nameOf = k => PORTRAIT_BOOK[k]?.n || k;

export function openPortraitView(k) {
  const b = PORTRAIT_BOOK[k]; if (!b) return;
  openLayer({ title: b.n, wide: true, body: `<div class="pt-view"><img class="pt-ill" src="${portraitImg(k)}" alt="${esc(b.n)}의 초상">
    <div class="pt-text"><p class="eyebrow">${esc(b.t)}</p><h3>${esc(b.n)}</h3><p>${esc(b.b)}</p><p class="muted small">초상 그림은 생성형 AI로 만든 이미지입니다.</p></div></div>` });
}

export async function openPortraitBook(onChange) {
  let data;
  try { data = await rpc('world_portrait_book'); } catch (e) { return toast(e.message, 'error'); }
  const layer = openLayer({ title: '초상 화첩', wide: true, body: '<div class="pt-book"></div>' });
  const box = $('.pt-book', layer);
  const paint = () => {
    const list = [...(data.list || [])].sort((a, b) => (b.open - a.open) || ((a.lv ?? 99) - (b.lv ?? 99))), open = list.filter(x => x.open).length;
    box.innerHTML = `<div class="pt-head"><span>열린 초상 <b>${open}</b> / ${list.length}</span>${helpQ(HELP, '초상 화첩 안내')}</div>
      ${data.house ? '' : '<p class="muted small">별채가 없어도 화첩은 볼 수 있습니다. 초상 액자는 별채를 얻은 뒤에 꺼낼 수 있습니다.</p>'}
      <div class="pt-grid">${list.map(x => x.open
        ? `<button class="pt-card" data-k="${esc(x.k)}"><img class="pt-dot" src="${dotURL(x.k)}" alt=""><b>${esc(nameOf(x.k))}</b><small class="muted">${x.have ? '액자 있음' : '꺼낼 수 있음'}</small></button>`
        : `<div class="pt-card locked"><span class="pt-dot pt-q">?</span><b>???</b><small class="muted">${esc(x.story || '')} 「${esc(x.quest || '')}」 (Lv.${x.lv ?? '?'})</small></div>`).join('')}</div>`;
  };
  paint();
  box.addEventListener('click', e => {
    const t = e.target.closest('[data-k]'); if (!t) return;
    const k = t.dataset.k, x = (data.list || []).find(v => v.k === k), b = PORTRAIT_BOOK[k];
    const d = openLayer({ title: b.n, wide: true, body: `<div class="pt-view"><img class="pt-ill" src="${portraitImg(k)}" alt="${esc(b.n)}의 초상">
      <div class="pt-text"><p class="eyebrow">${esc(b.t)}</p><h3>${esc(b.n)}</h3><p>${esc(b.b)}</p>
      <p class="muted small">${esc(x.story || '')} 「${esc(x.quest || '')}」에서 열린 초상입니다.</p>
      <div class="btn-row"><button class="btn primary small" data-take ${x.have || !data.house ? 'disabled' : ''}>${icon('chest', 14)} 꺼내기</button></div>
      <p class="muted small">${x.have ? '이미 이 초상 액자가 가방·창고·별채 어딘가에 있습니다.' : data.house ? '꺼내면 별채 곳간에 초상 액자가 들어옵니다.' : '별채를 얻은 뒤에 꺼낼 수 있습니다.'}</p>
      <p class="muted small">초상 그림은 생성형 AI로 만든 이미지입니다.</p></div></div>` });
    $('[data-take]', d)?.addEventListener('click', ev => guard(ev.currentTarget, async () => {
      const r = await act('world_portrait_take', { p_key: k });
      toast(`${r?.name || b.n} 액자를 곳간에 넣었습니다.`);
      x.have = true; d.close(); paint(); onChange?.();
      return r;
    }));
  });
}
