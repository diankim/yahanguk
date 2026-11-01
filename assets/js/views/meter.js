// 피해 기록판(7.7.4, 사용자 요청): 합동 토벌·파티 토벌·귀허의 주인에서 파티원마다 준 피해·받은 피해·회복을 수치와 게이지로.
// 값은 각 전투 스냅샷의 참가자 줄(dmg·taken·heal, 서버가 셈)을 그대로 쓴다 — 따로 서버에 묻지 않는다.
// 휴대폰(899px 아래)은 화면 오른쪽 끝의 손잡이를 누르면 펼쳐지는 반투명 창, PC는 참가자 칸 아래에 늘 펼쳐 둔다.
// 펼침·고른 갈래는 이 기기에 남긴다(yh-meter-open · yh-meter-tab).
import { esc, icon, fmt, nameOf, JOBS } from '../core.js';

const TABS = [['dmg', '준 피해'], ['taken', '받은 피해'], ['heal', '회복']];
const get = (k, d) => { try { return localStorage.getItem(k) ?? d; } catch { return d; } };
const put = (k, v) => { try { localStorage.setItem(k, v); } catch { /* 저장이 막혀도 화면은 그대로 */ } };
let tab = get('yh-meter-tab', 'dmg'), open = get('yh-meter-open', '0') === '1';
if (!TABS.some(([k]) => k === tab)) tab = 'dmg';

// rows: [{ id, name, job, dmg, taken, heal, me }], secs: 싸운 시간(초, 모르면 0)
export function meterHtml(rows, secs = 0) {
  const list = (rows || []).map(r => ({ ...r, dmg: Number(r.dmg) || 0, taken: Number(r.taken) || 0, heal: Number(r.heal) || 0 }));
  const sum = list.reduce((a, r) => a + r[tab], 0);
  const top = Math.max(1, ...list.map(r => r[tab]));
  const sorted = list.slice().sort((a, b) => b[tab] - a[tab] || a.name.localeCompare(b.name));
  const healCol = list.some(r => r.heal > 0);
  const rowsHtml = sorted.map(r => {
    const v = r[tab], pct = sum > 0 ? v / sum * 100 : 0;
    return `<li class="dm-row jb-${esc(r.job || '')} ${r.me ? 'me' : ''}" title="${esc(`${r.name} · ${JOBS[r.job]?.name || nameOf(r.job) || ''} — 준 피해 ${fmt.num(r.dmg)} · 받은 피해 ${fmt.num(r.taken)} · 회복 ${fmt.num(r.heal)}`)}">
      <i class="dm-fill" style="width:${(v / top * 100).toFixed(1)}%"></i>
      <span class="dm-name">${esc(r.name)}</span>
      <b class="dm-val">${fmt.num(v)}</b><span class="dm-pct">${pct.toFixed(1)}%</span>
      <span class="dm-sub">${tab !== 'dmg' ? `<em class="o">${fmt.num(r.dmg)}</em>` : ''}${tab !== 'taken' ? `<em class="i">${fmt.num(r.taken)}</em>` : ''}${tab !== 'heal' && healCol ? `<em class="h">${fmt.num(r.heal)}</em>` : ''}</span></li>`;
  }).join('');
  const per = secs > 0 && sum > 0 ? ` · 초당 ${fmt.num(Math.round(sum / secs))}` : '';
  return `<aside class="dmeter ${open ? 'open' : ''}" data-meter>
    <button type="button" class="dm-handle" data-dm-toggle aria-expanded="${open}" aria-label="피해 기록 ${open ? '접기' : '펼치기'}" title="피해 기록">${icon('sword', 14)}<span>기록</span></button>
    <div class="dm-box">
      <div class="dm-head"><b>피해 기록</b><span class="dm-seg">${TABS.map(([k, n]) => `<button type="button" data-dm="${k}" class="${k === tab ? 'on' : ''}">${n}</button>`).join('')}</span>
        <button type="button" class="dm-x" data-dm-toggle aria-label="접기">${icon('close', 13)}</button></div>
      <ol class="dm-list">${rowsHtml || '<li class="dm-empty">아직 기록이 없습니다.</li>'}</ol>
      <p class="dm-foot">합 ${fmt.num(sum)}${per}<span class="dm-legend">${tab !== 'dmg' ? '<em class="o">준</em>' : ''}${tab !== 'taken' ? '<em class="i">받은</em>' : ''}${tab !== 'heal' && healCol ? '<em class="h">회복</em>' : ''}</span></p>
    </div></aside>`;
}

// box 안을 다시 그리고 단추를 잇는다(전투 화면이 다시 그릴 때마다 불러도 펼침·갈래는 그대로)
export function mountMeter(box, rows, secs = 0) {
  if (!box) return;
  box.innerHTML = meterHtml(rows, secs);
  box.querySelectorAll('[data-dm-toggle]').forEach(b => b.onclick = () => { open = !open; put('yh-meter-open', open ? '1' : '0'); mountMeter(box, rows, secs); });
  box.querySelectorAll('[data-dm]').forEach(b => b.onclick = () => { tab = b.dataset.dm; put('yh-meter-tab', tab); mountMeter(box, rows, secs); });
}
