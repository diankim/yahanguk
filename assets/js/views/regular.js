import { $, $$, esc, icon, fmt, act, rpc, ask, guard, openModal, bar } from '../core.js';
import { REGULAR } from '../rules.js';
import { helpQ } from '../tips.js';

const hearts = n => `<span class="rg-hearts" aria-label="친밀도 ${n}단계">${[1, 2, 3, 4, 5].map(i => `<i class="${i <= n ? 'on' : ''}">${icon('heart', 13)}</i>`).join('')}</span>`;
const haveOf = o => (o.have || 0) + (o.have_st || 0);
const haveHqOf = o => (o.hq_have || 0) + (o.hq_st || 0);

function orderCard(o, v) {
  const h = haveOf(o), hq = haveHqOf(o), off = o.done || !v.can?.give;
  return `<li class="rg-order ${o.done ? 'done' : h + hq >= o.qty ? 'ready' : ''}">
    <header><button type="button" class="linkish" data-rg-info="${esc(o.id)}"><b>${esc(o.name)}</b></button><span class="chip">${o.qty}개</span>${o.done ? `<span class="chip ok">${icon('check', 12)}넘김</span>` : ''}</header>
    <small class="muted">${o.tier}단계 · 가방 ${fmt.num(o.have || 0)}${o.have_st ? ` · 창고 ${fmt.num(o.have_st)}` : ''}${o.hq_ok ? ` · 우수 ${fmt.num(hq)}` : ''}</small>
    <small class="rg-pay">${esc(v.line_name)} 경험 +${fmt.num(v.xp)} · ${fmt.jeon(o.gil)} · 친밀도 +${REGULAR.aff.give}${o.hq_ok ? ` <span class="muted">(우수품 경험 +${fmt.num(v.xp_fine)} · 친밀도 +${REGULAR.aff.hq})</span>` : ''}</small>
    <div class="btn-row"><button type="button" class="q-link" data-rg-src="${esc(o.id)}">${icon('pin', 12)}얻는 곳</button>
      ${o.done ? '' : `${o.hq_ok && hq >= o.qty ? `<button type="button" class="btn small" data-here="연담 납품" data-rg-give="${o.i}" data-hq="1" ${off ? 'disabled' : ''}>우수품 넘기기</button>` : ''}
      <button type="button" class="btn small primary" data-here="연담 납품" data-rg-give="${o.i}" ${off || h + hq < o.qty ? 'disabled' : ''}>넘기기</button>`}</div></li>`;
}

function body(v) {
  const top = v.next == null, from = REGULAR.stageAt(v.stage), to = v.next ?? v.cap;
  return `<div class="rg">
    <p class="eyebrow">${esc(v.place || '')} · ${esc(v.line_name)} 연담${helpQ(REGULAR.tip(), '연담 안내')}</p>
    <div class="rg-head">${hearts(v.stage)}<b>친밀도 ${v.stage}단계</b>
      ${top ? `<small class="ok">가장 높은 단계</small>` : `<div class="rg-bar">${bar(v.aff - from, to - from || 1, 'gold')}<small class="muted">${fmt.num(v.aff)} / ${fmt.num(to)} · 다음 단계까지 ${fmt.num(to - v.aff)}</small></div>`}</div>
    <ol class="rg-quests">${(v.quests || []).map(q => `<li class="${q.done ? 'done' : q.open ? 'now' : ''}" title="${esc(q.done ? '마침' : q.open ? '열림 — 일지 › 보조 퀘스트' : `친밀도 ${q.n}단계에 열림`)}"><b>${q.n}</b>${q.done ? icon('check', 12) : q.open ? icon('scroll', 12) : icon('knot', 12)}</li>`).join('')}
      <li class="rg-title" title="${esc(REGULAR.titleTip(v.short))}">${icon('spark', 13)}<small>${esc(v.title || '')}</small></li></ol>
    <p class="muted small">오늘 납품 ${fmt.num(v.today?.n || 0)} / ${fmt.num(v.today?.cap || 0)} <span>· 모든 연담 합쳐</span> · 내 ${esc(v.line_name)} ${v.rank}단계</p>
    <ul class="rg-orders">${(v.orders || []).map(o => orderCard(o, v)).join('')}</ul>
    ${v.can?.give ? '' : `<p class="hint">${icon('pin', 14)} ${esc(v.can?.why || '')}</p>`}
    <p class="muted small">${v.storage ? '가방에 모자란 것은 창고에서 꺼내 넘깁니다.' : '가방에 든 것만 넘깁니다.'} 장착 중·잠금·강화한 장비는 빠집니다.</p>
  </div>`;
}

function draw(m, v) {
  const box = $('.rg-host', m); if (!box) return;
  box.innerHTML = body(v);
  $$('[data-rg-info]', box).forEach(b => b.onclick = () => import('./item.js').then(x => x.openItemInfo(b.dataset.rgInfo)));
  $$('[data-rg-src]', box).forEach(b => b.onclick = () => import('../sources.js').then(x => x.openAllSources(b.dataset.rgSrc)));
  $$('[data-rg-give]', box).forEach(b => b.onclick = async () => {
    const o = (v.orders || []).find(x => x.i === Number(b.dataset.rgGive)); if (!o) return;
    const hq = b.dataset.hq === '1';
    const mix = !hq && haveOf(o) < o.qty ? ` (보통 ${fmt.num(haveOf(o))}개 + 우수품 ${fmt.num(o.qty - haveOf(o))}개)` : '';
    if (!(await ask(`「${o.name}${hq ? ' (우수)' : ''}」 ${o.qty}개${mix}를 ${v.short}에게 넘길까요?`, { title: '연담 납품', ok: '넘기기' }))) return;
    const r = await guard(b, () => act('world_regular_give', { p_npc: v.npc, p_order: o.i, p_fine: hq }));
    if (r?.view) { draw(m, r.view); if (r.stage_up) window.dispatchEvent(new CustomEvent('yh-regular-stage', { detail: r })); }
  });
}

export async function openRegular(npc = null) {
  const m = openModal({ title: '연담', wide: true, body: '<div class="rg-host"><div class="loading"><span class="spinner"></span>불러오는 중…</div></div>' });
  try {
    const v = await rpc('world_regular_view', { p_npc: npc });
    const t = $('.modal-head h2, .modal-title', m); if (t) t.textContent = `연담 · ${v.name}`;
    draw(m, v);
  } catch (e) {
    const box = $('.rg-host', m); if (box) box.innerHTML = `<p class="hint warn">${esc(e.message || '불러오지 못했습니다.')}</p>`;
  }
  return m;
}

export function regularListHtml(d) {
  const list = d?.list || [];
  if (!list.length) return `<p class="muted small">${esc(REGULAR.none)}</p>`;
  return `<p class="muted small">오늘 납품 ${fmt.num(d.today || 0)} / ${fmt.num(d.cap || 0)} · 모든 연담 합쳐${helpQ(REGULAR.tip(), '연담 안내')}</p>
    <ul class="rg-list">${list.map(x => `<li><button type="button" class="rg-row" data-rg-open="${esc(x.npc)}" data-rg-region="${esc(x.region)}">
      ${hearts(x.stage)}<b>${esc(x.name)}</b><small class="muted">${esc(x.line_name)} · ${esc(x.place)}</small>
      <small class="${x.left > 0 ? '' : 'muted'}">오늘 주문 ${x.left}개 남음</small></button></li>`).join('')}</ul>`;
}

export const regularTile = b => b ? ['regular', 'heart', `연담 · ${b.short}`, `${b.line_name} · 친밀도 ${b.stage}단계 · 오늘 주문 ${b.left}개`] : null;
