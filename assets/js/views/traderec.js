import { esc, icon, fmt, bar, GRADES } from '../core.js';
import { load, foldOpen } from './common.js';
import { TRADE } from '../rules.js';
import { regionBtn } from '../sources.js';

export const loadTradeRecord = (force = false) => load('world_trade_record_view', undefined, { maxAge: force ? 0 : 600000 });

const day = t => { if (!t) return ''; const d = new Date(t); return `${d.getFullYear()}.${d.getMonth() + 1}.${d.getDate()}`; };
const md = t => { if (!t) return ''; const d = new Date(t); return `${d.getMonth() + 1}.${d.getDate()}`; };
const kv = rows => `<dl class="kv trl-kv">${rows.map(([k, v]) => `<div><dt>${esc(k)}</dt><dd>${v}</dd></div>`).join('')}</dl>`;
const mobile = () => { try { return matchMedia('(max-width: 899px)').matches; } catch { return false; } };
const MO_OPEN = new Set(['ship', 'sale']);
const box = (key, title, ico, sum, body, cls = '') => `<details class="trl-box ${cls}" data-fold="trr-${key}" ${foldOpen('trr-' + key, !mobile() || MO_OPEN.has(key)) ? 'open' : ''}><summary><h3>${icon(ico, 14)} ${esc(title)}${sum ? `<small class="muted trl-sum">${esc(sum)}</small>` : ''}</h3></summary>${body}</details>`;

function ladder(r) {
  const tier = r.ship?.tier || 0, tiers = r.tiers || {};
  return `<ol class="trl-ladder">${(TRADE.ships || []).map(x => { const k = String(x.tier), got = k in tiers || x.tier <= tier;
    return `<li class="${x.tier === tier ? 'on' : got ? 'done' : ''}"><b>${esc(x.name)}</b><small>${got ? (tiers[k] ? esc(md(tiers[k])) : '지음') : '아직'}</small></li>`; }).join('')}</ol>`;
}

function portsTable(r) {
  const rows = [...(r.ports || [])].sort((a, b) => (a.realm !== 'main') - (b.realm !== 'main') || b.g - a.g || String(a.name).localeCompare(String(b.name), 'ko'));
  const top = Math.max(0, ...rows.map(p => p.g || 0));
  return `<table class="tr-board trl-ports"><thead><tr><th>항구</th><th>판 개수</th><th>벌이</th><th>시세 본 때</th></tr></thead><tbody>
    ${rows.map(p => `<tr class="${top > 0 && p.g === top ? 'best' : ''}"><td>${regionBtn(p.name)}${p.realm !== 'main' ? '<span class="tr-tag t-far">건넛누리</span>' : ''}</td>
      <td>${p.n ? fmt.num(p.n) : '<span class="muted">—</span>'}</td><td>${p.g ? `<b>${fmt.jeon(p.g)}</b>` : '<span class="muted">—</span>'}</td>
      <td class="muted">${p.seen_at ? esc(fmt.ago(p.seen_at)) : '?'}</td></tr>`).join('')}</tbody></table>`;
}

function titleList(r) {
  const list = [...(r.titles || [])].sort((a, b) => !!b.earned - !!a.earned), got = list.filter(t => t.earned).length;
  return `<p class="muted small">얻은 교역 칭호 ${got} / ${list.length}</p><ul class="trl-titles">${list.map(t => t.hidden && !t.earned
    ? `<li class="secret"><b>???</b><small>숨겨진 칭호</small></li>`
    : `<li class="${t.earned ? 'earned' : ''}"><div><b><span class="t-grade g${t.grade}">${esc(GRADES[t.grade] || '')}</span> ${esc(t.name)}</b><small>${esc(t.cond)}</small></div>
      ${t.earned ? '<span class="chip ok">얻음</span>' : `<div class="trl-prog">${bar(t.progress, t.need, 'xp')}<small>${fmt.num(t.progress)} / ${fmt.num(t.need)}</small></div>`}</li>`).join('')}</ul>`;
}

export function tradeRecordHtml(r) {
  if (!r) return '<p class="muted small">아직 교역 기록이 없습니다.</p>';
  const s = r.ship, avg = r.sold_base > 0 ? Math.round(r.sold_gil / r.sold_base * 100) / 100 : null;
  const left = Math.max(0, (r.day?.cap || 0) - (r.day?.used || 0));
  const bonus = ['time', 'guard', 'haggle'].map(k => [TRADE.bonus?.[k]?.name || k, `${fmt.num(r.bonus?.[k] || 0)}번`]);
  const titles = r.titles || [], tGot = titles.filter(t => t.earned).length;
  const bonusN = ['time', 'guard', 'haggle'].reduce((a, k) => a + (Number(r.bonus?.[k]) || 0), 0);
  return `<div class="trl-grid">
    ${box('ship', '내 배', 'ship', s ? `${s.name} · 내구도 ${s.durability}/${s.max}` : '배 없음', `${s ? `<p class="trl-ship"><b>${esc(s.name)}</b>${s.name !== s.kind ? ` <small class="muted">${esc(s.kind)}</small>` : ''} · 내구도 ${s.durability}/${s.max}</p>` : '<p class="muted small">아직 배가 없습니다.</p>'}${ladder(r)}`, 'wide')}
    ${box('sale', '장사', 'coin', `정가 합 ${fmt.jeon(r.sold_base)}`, kv([['판 교역품', `${fmt.num(r.sold_n)}개`], ['정가 합', fmt.jeon(r.sold_base)], ['받은 돈 합', `<b>${fmt.jeon(r.sold_gil)}</b>`],
      ['평균', avg ? `정가의 ${avg}배에 팖` : '—'], ['오늘 남은 몫', `${fmt.num(left)} / ${fmt.num(r.day?.cap || 0)}전`]]))}
    ${box('best', '기록', 'star', r.best ? `가장 큰 한 번 ${fmt.jeon(r.best.gil)}` : '아직 없음', kv([['가장 큰 한 번', r.best ? `<b>${fmt.jeon(r.best.gil)}</b> <small class="muted">${esc(r.best.port_name || '')} · ${esc(day(r.best.at))}</small>` : '—'],
      ['하루 몫을 한 번에', `${fmt.num(r.full_n)}번`], ['수요 사건 맞춘 날', `${fmt.num(r.demand_n)}일`]]))}
    ${box('route', '뱃길', 'route', `항해 ${fmt.num(r.voy_n)}번 · 건넘 ${fmt.num(r.cross_n)}번`, kv([['직접 항해', `${fmt.num(r.voy_n)}번`], ['바다 건너기', `${fmt.num(r.cross_n)}번`], ['보내 둔 배가 닿음', `${fmt.num(r.send_n)}번`], ['배로 닿은 항구', `${r.seen} / ${r.port_n}곳`]]))}
    ${box('raid', '습격', 'sword', `물리침 ${fmt.num(r.raid_win)} · 밀림 ${fmt.num(r.raid_lose)}`, kv([['물리침', `${fmt.num(r.raid_win)}번`], ['밀림', `${fmt.num(r.raid_lose)}번`], ['보낸 배가 맞음', `${fmt.num(r.send_raid)}번`]]))}
    ${box('bonus', '함께', 'users', `덤 ${fmt.num(bonusN)}번`, kv(bonus))}
  </div>
  ${box('ports', '항구별', 'map', `들른 곳 ${r.seen ?? 0}/${r.port_n ?? (r.ports || []).length}`, portsTable(r))}
  ${box('titles', '교역 칭호', 'spark', `얻음 ${tGot}/${titles.length}`, titleList(r))}`;
}
