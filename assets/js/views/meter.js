import { esc, icon, fmt } from '../core.js';
import { jobName } from './fightui.js';

const TABS = [['dmg', '준 피해'], ['taken', '받은 피해'], ['heal', '회복'], ['share', '기여']];
const get = (k, d) => { try { return localStorage.getItem(k) ?? d; } catch { return d; } };
const put = (k, v) => { try { localStorage.setItem(k, v); } catch { } };
let tab = get('yh-meter-tab', 'dmg'), open = get('yh-meter-open', '0') === '1';
if (!TABS.some(([k]) => k === tab)) tab = 'dmg';

export function meterHtml(rows, secs = 0) {
  const list = (rows || []).map(r => ({ ...r, dmg: Number(r.dmg) || 0, taken: Number(r.taken) || 0, heal: Number(r.heal) || 0, share: Number(r.share) || 0 }));
  const sum = list.reduce((a, r) => a + r[tab], 0);
  const top = Math.max(1, ...list.map(r => r[tab]));
  const sorted = list.slice().sort((a, b) => b[tab] - a[tab] || a.name.localeCompare(b.name));
  const healCol = list.some(r => r.heal > 0);
  const rowsHtml = sorted.map(r => {
    const v = r[tab], pct = tab === 'share' ? v : sum > 0 ? v / sum * 100 : 0;
    return `<li class="dm-row jb-${esc(r.job || '')} ${r.me ? 'me' : ''}" title="${esc(`${r.name} · ${jobName(r.job) || ''} — 준 피해 ${fmt.num(r.dmg)} · 받은 피해 ${fmt.num(r.taken)} · 회복 ${fmt.num(r.heal)} · 기여 ${r.share.toFixed(1)}%`)}">
      <i class="dm-fill" style="width:${(v / top * 100).toFixed(1)}%"></i>
      <span class="dm-name">${esc(r.name)}</span>
      <b class="dm-val">${tab === 'share' ? `${v.toFixed(1)}%` : fmt.num(v)}</b><span class="dm-pct">${tab === 'share' ? '' : `${pct.toFixed(1)}%`}</span>
      <span class="dm-sub">${tab !== 'dmg' ? `<em class="o">${fmt.num(r.dmg)}</em>` : ''}${tab !== 'taken' ? `<em class="i">${fmt.num(r.taken)}</em>` : ''}${tab !== 'heal' && healCol ? `<em class="h">${fmt.num(r.heal)}</em>` : ''}</span></li>`;
  }).join('');
  const per = tab !== 'share' && secs > 0 && sum > 0 ? ` · 초당 ${fmt.num(Math.round(sum / secs))}` : '';
  return `<aside class="dmeter ${open ? 'open' : ''}" data-meter>
    <button type="button" class="dm-handle" data-dm-toggle aria-expanded="${open}" aria-label="피해 기록 ${open ? '접기' : '펼치기'}" title="피해 기록">${icon('sword', 14)}<span>기록</span></button>
    <div class="dm-box">
      <div class="dm-head"><b>피해 기록</b><span class="dm-seg">${TABS.map(([k, n]) => `<button type="button" data-dm="${k}" class="${k === tab ? 'on' : ''}">${n}</button>`).join('')}</span>
        <button type="button" class="dm-x" data-dm-toggle aria-label="접기">${icon('close', 13)}</button></div>
      <ol class="dm-list">${rowsHtml || '<li class="dm-empty">아직 기록이 없습니다.</li>'}</ol>
      <p class="dm-foot">${tab === 'share' ? '준 피해·북돋움·막아 줌·회복·받아 냄을 한 공식으로' : `합 ${fmt.num(sum)}${per}`}<span class="dm-legend">${tab !== 'dmg' ? '<em class="o">준</em>' : ''}${tab !== 'taken' ? '<em class="i">받은</em>' : ''}${tab !== 'heal' && healCol ? '<em class="h">회복</em>' : ''}</span></p>
    </div></aside>`;
}

export function mountMeter(box, rows, secs = 0) {
  if (!box) return;
  box.innerHTML = meterHtml(rows, secs);
  box.querySelectorAll('[data-dm-toggle]').forEach(b => b.onclick = () => { open = !open; put('yh-meter-open', open ? '1' : '0'); mountMeter(box, rows, secs); });
  box.querySelectorAll('[data-dm]').forEach(b => b.onclick = () => { tab = b.dataset.dm; put('yh-meter-tab', tab); mountMeter(box, rows, secs); });
}
