import { $, $$, esc, icon, fmt, act, rpc, ask, guard, openModal, bar } from '../core.js';
import { PROJECT } from '../rules.js';
import { helpQ } from '../tips.js';
import { hqOf } from '../hq.js';
import { openItemPick } from './itempick.js';
import { catItem } from './common.js';

const RAR = ['', 'common', 'uncommon', 'rare', 'epic', 'legend', 'legend', 'legend', 'legend'];
const KIND = { craft: '제작품', gather: '채집' };
const urgentMul = it => (it.urgent ? PROJECT.urgent.mul : 1);
const unitOf = (it, hq) => Math.floor(it.v * Math.min(PROJECT.mul_cap, urgentMul(it) * (hq ? PROJECT.hq_mul : 1)));
const haveOf = it => (it.have || 0) + (it.have_st || 0);
const haveHqOf = it => (it.hq_have || 0) + (it.hq_st || 0);

function ladder(v) {
  return `<ol class="pj-ladder">${(v.perks || []).map(p => `<li class="${p.done ? 'done' : p.stage === v.stage + 1 ? 'now' : ''}" data-tip="${esc(p.text || '')}" tabindex="0"><b>${p.stage}</b><small>${esc(p.text || '')}</small></li>`).join('')}</ol>`;
}

function itemCard(it) {
  const h = haveOf(it), hq = haveHqOf(it);
  return `<li class="pj-item ${it.urgent ? 'urgent' : ''} ${h + hq ? 'has' : ''}">
    <header><button type="button" class="linkish" data-pj-info="${esc(it.id)}"><b>${esc(it.name)}</b></button>${it.urgent ? `<span class="chip warn pj-urgent">급히 ×${PROJECT.urgent.mul}</span>` : ''}</header>
    <small class="muted">${esc(KIND[it.kind] || '')} · ${it.tier}단계 · 1개 <b>${fmt.num(unitOf(it, false))}</b>몫${hq ? ` · 우수 ${fmt.num(unitOf(it, true))}몫` : ''}</small>
    <small class="pj-have">가방 ${fmt.num(it.have || 0)}${it.have_st ? ` · 창고 ${fmt.num(it.have_st)}` : ''}${hq ? ` · 우수 ${fmt.num(hq)}` : ''}</small>
    <button type="button" class="q-link" data-pj-src="${esc(it.id)}">${icon('pin', 12)}얻는 곳</button></li>`;
}

function body(v) {
  const kind = v.kind, after = v.after, pct = after || !v.goal ? 100 : Math.min(100, Math.floor(v.points * 100 / v.goal));
  const any = (v.items || []).some(it => haveOf(it) + haveHqOf(it) > 0);
  return `<div class="pj">
    <p class="eyebrow">${esc(v.place || '')} · ${esc((v.hubs || []).join('·'))}${helpQ(PROJECT.payTip(v.reward), '납품 안내')}</p>
    ${v.reward === 'help' ? `<p class="hint pj-help">${icon('hammer', 14)} ${esc(v.place || '')} 사업을 돕습니다 · 몫 1마다 ${PROJECT.pay.help.gil_rate}전${v.rel ? ` · ${esc(v.rel.with)}과(와)의 관계 오늘 +${v.rel.today}/${v.rel.cap}` : ''}${helpQ(PROJECT.helpTip(), '돕기 안내')}</p>` : ''}
    ${ladder(v)}
    <div class="pj-prog">${after ? `<b>${icon('check', 14)} 다섯 단계를 모두 마쳤습니다</b><small class="muted">계속 넘기면 기여·칭호에 셉니다(보상 ${PROJECT.pay.after_mul * 100}%). 모두 ${fmt.num(v.total)}몫</small>`
      : `<div class="pj-bar"><span>${v.stage + 1}단계</span>${bar(v.points, v.goal || 1, 'gold')}<b>${fmt.num(v.points)} / ${fmt.num(v.goal)}몫 · ${pct}%</b></div>
        <small class="muted">단계 목표${helpQ(PROJECT.goalTip(kind), '목표 안내')} · 이번 단계에 힘을 보탠 조사원 ${fmt.num(v.givers || 0)}명</small>`}</div>
    <dl class="kv pj-mine"><div><dt>오늘 내 몫(모든 사업)</dt><dd>${fmt.num(v.today?.pts || 0)} / ${fmt.num(v.today?.cap || 0)}${v.today?.here && v.today.here !== v.today.pts ? ` <small class="muted">· 여기 ${fmt.num(v.today.here)}</small>` : ''}</dd></div>
      ${after ? '' : `<div><dt>이번 단계 내 몫</dt><dd>${fmt.num(v.mine?.cur || 0)}${v.mine?.need ? ` <small class="${(v.mine.cur || 0) >= v.mine.need ? 'ok' : 'muted'}">(기념품 ${fmt.num(v.mine.need)}몫${helpQ(PROJECT.mementoTip(), '기념품 안내')})</small>` : ''}</dd></div>`}
      <div><dt>내 누계</dt><dd>${fmt.num(v.mine?.total || 0)}몫</dd></div></dl>
    ${v.benefit && !v.benefit.ok ? `<p class="hint warn">${icon('pin', 14)} ${esc(v.benefit.why)}</p>` : ''}
    <ul class="pj-items">${(v.items || []).map(itemCard).join('')}</ul>
    ${v.can?.give ? '' : `<p class="hint">${icon('pin', 14)} ${esc(v.can?.why || '')}</p>`}
    <div class="btn-row pj-foot"><span class="muted small">${v.storage ? '가방에 모자란 것은 창고에서 꺼내 넘깁니다.' : '가방에 든 것만 넘깁니다.'} 장착 중·잠금·강화한 장비는 빠집니다.</span>
      <button type="button" class="btn primary" data-here="사업 납품" id="pj-give" ${v.can?.give && any ? '' : 'disabled'}>${icon('bag', 15)}<span>골라 넘기기</span></button></div>
  </div>`;
}

function rowsOf(v) {
  const rows = [];
  for (const it of v.items || []) {
    const desc = catItem(it.id)?.description || '';
    const base = { cat: it.kind === 'gather' ? 'material' : (/material/.test(it.category) ? 'material' : it.category === 'consumable' ? 'consumable' : 'gear'), tier: it.tier, rarity: RAR[it.tier] || 'common', desc };
    if (haveOf(it)) rows.push({ ...base, id: it.id, name: it.name, have: haveOf(it), max: haveOf(it), sub: `1개 ${unitOf(it, false)}몫${it.urgent ? ' · 급히' : ''}` });
    if (haveHqOf(it)) rows.push({ ...base, id: hqOf(it.id), name: `${it.name} (우수)`, have: haveHqOf(it), max: haveHqOf(it), sub: `1개 ${unitOf(it, true)}몫${it.urgent ? ' · 급히' : ''}` });
  }
  return rows.sort((a, b) => a.name.localeCompare(b.name, 'ko'));
}

function estimate(v, sel) {
  let pts = 0;
  for (const it of v.items || []) {
    pts += unitOf(it, false) * (Number(sel[it.id]) || 0) + unitOf(it, true) * (Number(sel[hqOf(it.id)]) || 0);
  }
  return pts;
}

async function give(m, v, sel) {
  const n = Object.values(sel).reduce((a, b) => a + Number(b || 0), 0); if (!n) return;
  const pts = estimate(v, sel), left = Math.max(0, (v.today?.cap || 0) - (v.today?.pts || 0)), over = pts > left;
  const ok = await ask(`${n}개를 넘깁니다 · 약 ${fmt.num(pts)}몫 · ${PROJECT.rewardOf(v.reward, Math.min(pts, left + 1), v.after)} 안팎${over ? `\n\n오늘 남은 몫은 ${fmt.num(left)}입니다. 상한을 넘는 물품은 넘기지 않고 돌려받습니다.` : ''}`, { title: '사업에 넘기기', ok: '넘기기' });
  if (!ok) return;
  const r = await guard($('#pj-give', m), () => act('world_project_give', { p_key: v.key, p_items: sel }));
  if (r?.view) draw(m, r.view);
}

function draw(m, v) {
  const box = $('.pj-host', m); if (!box) return;
  box.innerHTML = body(v);
  $$('[data-pj-info]', box).forEach(b => b.onclick = () => import('./item.js').then(x => x.openItemInfo(b.dataset.pjInfo)));
  $$('[data-pj-src]', box).forEach(b => b.onclick = () => import('../sources.js').then(x => x.openAllSources(b.dataset.pjSrc)));
  const g = $('#pj-give', box);
  if (g) g.onclick = () => openItemPick({ title: `${v.name}에 넘길 물품`, rows: rowsOf(v), many: true, okText: '이대로 넘기기',
    note: `<p class="muted small">오늘 남은 몫 ${fmt.num(Math.max(0, (v.today?.cap || 0) - (v.today?.pts || 0)))}.</p>`, onDone: sel => give(m, v, sel) });
}

export async function openProject(key = null) {
  const m = openModal({ title: '사업', wide: true, body: '<div class="pj-host"><div class="loading"><span class="spinner"></span>불러오는 중…</div></div>' });
  try {
    const v = await rpc('world_project_view', { p_key: key });
    const t = $('.modal-head h2, .modal-title', m); if (t) t.textContent = `${v.kind === 'faction' ? v.reward === 'help' ? `${v.place} 사업 돕기` : '거점 사업' : '공동 사업'} · ${v.name}`;
    draw(m, v);
  } catch (e) {
    const box = $('.pj-host', m); if (box) box.innerHTML = `<p class="hint warn">${esc(e.message || '불러오지 못했습니다.')}</p>`;
  }
  return m;
}

export const projectBand = b => {
  const h = b?.here; if (!h) return '';
  const also = (h.also || []).map(a => `<button class="btn small ghost" type="button" data-pj-open="${esc(a.key)}">${esc(a.place || a.name)} 돕기</button>`).join('');
  return `<div class="notice pj-band">${icon('hammer', 18)}<div><b>${esc(h.name)} · ${h.stage >= 5 ? '다섯 단계 마침' : `${h.stage + 1}단계 · ${h.pct}%`}</b><span>${h.kind !== 'faction' ? '공동 사업 — 넘길수록 이 나루의 막힌 것이 하나씩 풀립니다' : h.help ? `${esc(h.place || '')} 거점 사업 — 다른 세력도 도울 수 있고, 몫은 전으로 받습니다` : '거점 사업 — 정한 물품을 넘겨 거점을 함께 세웁니다'}</span></div><button class="btn small primary" type="button" data-pj-open="${esc(h.key)}">${h.help ? '돕기' : '납품'}</button>${also}</div>`;
};
export const urgentSet = b => new Set(b?.urgent || []);
