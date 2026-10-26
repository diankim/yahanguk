// 원정: 지역의 원정지(외곽·심부·핵심)를 골라 시간·태세·보급품을 정해 보낸다.
// 전투·채집·발견·위험 결과는 서버가 능력치·장비·직업·대세력을 반영해 계산한다.
import { store, act, nameOf, esc, icon, guard, $, $$, fmt, empty, openModal, bar, bagLimit, bagUsed } from '../core.js';
import { chip, danger } from './common.js';

const DURATIONS = [[30, '30분'], [60, '1시간'], [120, '2시간'], [240, '4시간'], [480, '8시간']];
const STANCES = [
  ['cautious', '신중', '조우를 피하고 일찍 치료합니다. 안전하지만 얻는 것이 적습니다.'],
  ['balanced', '균형', '싸울 때는 싸우고 물러날 때는 물러납니다.'],
  ['bold', '강행', '요괴를 찾아다니며 깊이 들어갑니다. 전리품과 답사도가 크게 오르지만 다치기 쉽습니다.'],
];
const SUPPLIES = [['tonic', '체력 35 회복'], ['herbal_extract', '체력 22 회복'], ['herb', '체력 12 회복'], ['ward_talisman', '침식이 50을 넘으면 15 정화'],
  ['seal_paper', '영체·결계 요괴 전투 승률 상승'], ['revival_charm', '쓰러지기 직전 한 번 일으켜 세움'], ['travel_ration', '1시간마다 1개 · 없으면 정신 소모·수확 감소']];
const DEPTH = ['', '외곽', '심부', '핵심'];
let pick = { ground: null, minutes: 60, stance: 'balanced', supplies: {} };

export function renderExpedition(box, board) {
  const c = store.character;
  if (board?.active) return renderActive(box, board.active);
  const grounds = board?.grounds || [];
  if (!grounds.length) { box.innerHTML = empty('이 지역에는 원정지가 없습니다.', 'map'); return; }
  if (!grounds.some(g => g.ground_id === pick.ground && g.unlocked)) pick.ground = grounds.find(g => g.unlocked)?.ground_id || null;
  const have = c.inventory || {};
  const mechs = [...new Set((board.monsters || []).map(m => m.mechanic).filter(Boolean))];
  box.innerHTML = `
    <div class="exp-progress"><span>지역 답사도</span><b>${board.progress}%</b>${bar(board.progress, 100, 'xp')}<small>30%에서 심부, 70%에서 핵심 원정지가 열리고, 100%면 가방이 넓어집니다.</small></div>
    <div class="ground-list">${grounds.map(g => `<button class="ground ${g.ground_id === pick.ground ? 'on' : ''}" data-ground="${esc(g.ground_id)}" ${g.unlocked ? '' : 'disabled'}>
        <header><b>${esc(g.ground_name)}</b>${chip(DEPTH[g.depth], g.depth === 3 ? 'bad' : g.depth === 2 ? 'warn' : '')}</header>
        <p>${esc(g.description)}</p>
        <small>${g.unlocked ? `${danger(g.danger)} 권장 Lv.${g.min_level}+` : `잠김 · 답사도 ${g.unlock_progress}% · Lv.${g.min_level}`}</small></button>`).join('')}</div>
    ${mechs.length ? `<p class="muted small">이 지역 요괴의 습성: ${esc(mechs.map(nameOf).join(', '))}. 영체·결계 요괴에게는 봉인 부적이 효과적입니다.</p>` : ''}
    <h3 class="sub-h">기간</h3><div class="chip-pick" data-pick="minutes">${DURATIONS.map(([m, l]) => `<button data-v="${m}" class="${m === pick.minutes ? 'on' : ''}">${l}</button>`).join('')}</div>
    <h3 class="sub-h">태세</h3><div class="stance-pick">${STANCES.map(([k, n, d]) => `<button data-stance="${k}" class="${k === pick.stance ? 'on' : ''}"><b>${n}</b><small>${d}</small></button>`).join('')}</div>
    <h3 class="sub-h">보급품 <small class="muted">— 가방에서 꺼내 가며, 쓰지 않은 것은 돌아오면 돌려받습니다</small></h3>
    <div class="supply-grid">${SUPPLIES.map(([k, d]) => `<div class="stepper" data-k="${k}"><span>${esc(nameOf(k))}<small>${d} · 보유 ${fmt.num(have[k])}</small></span>
      <div><button class="icon-btn" data-d="-1" aria-label="줄이기">${icon('minus', 14)}</button><b>${pick.supplies[k] || 0}</b><button class="icon-btn" data-d="1" aria-label="늘리기">${icon('plus', 14)}</button></div></div>`).join('')}</div>
    <p class="hint" id="exp-hint"></p>
    <button class="btn primary block" id="exp-go" ${pick.ground ? '' : 'disabled'}>${icon('flame', 16)}<span>원정 출발</span></button>
    <p class="muted small">원정을 떠나면 끝날 때까지 이동·전투·채집·거래를 할 수 없습니다. 언제든 일찍 귀환할 수 있지만 지난 시간만큼만 성과를 얻습니다.</p>
    ${recent(board.recent)}`;
  const hint = () => {
    const need = Math.floor(pick.minutes / 60), r = pick.supplies.travel_ration || 0;
    $('#exp-hint', box).textContent = need > r ? `노정 건량이 ${need - r}개 모자랍니다. 허기 때문에 정신이 깎이고 수확이 줄어듭니다.` : `가방 ${bagUsed(c)}/${bagLimit(c)}칸 · 전리품이 가방을 넘치면 남는 것은 두고 옵니다.`;
  };
  $$('[data-ground]', box).forEach(b => b.onclick = () => { pick.ground = b.dataset.ground; $$('[data-ground]', box).forEach(x => x.classList.toggle('on', x === b)); $('#exp-go', box).disabled = false; });
  $$('[data-pick=minutes] button', box).forEach(b => b.onclick = () => { pick.minutes = Number(b.dataset.v); $$('[data-pick=minutes] button', box).forEach(x => x.classList.toggle('on', x === b)); hint(); });
  $$('[data-stance]', box).forEach(b => b.onclick = () => { pick.stance = b.dataset.stance; $$('[data-stance]', box).forEach(x => x.classList.toggle('on', x === b)); });
  $$('.stepper', box).forEach(s => s.onclick = e => {
    const d = Number(e.target.closest('[data-d]')?.dataset.d || 0); if (!d) return;
    const k = s.dataset.k, max = Math.min(20, Number(have[k] || 0));
    pick.supplies[k] = Math.max(0, Math.min(max, (pick.supplies[k] || 0) + d));
    $('b', s).textContent = pick.supplies[k]; hint();
  });
  hint();
  bindRecent(box, board.recent);
  $('#exp-go', box).onclick = e => {
    const supplies = Object.fromEntries(Object.entries(pick.supplies).filter(([, n]) => n > 0));
    guard(e.currentTarget, async () => { const r = await act('world_expedition_launch', { p_ground_id: pick.ground, p_minutes: pick.minutes, p_stance: pick.stance, p_supplies: supplies }); pick.supplies = {}; return r; });
  };
}

function renderActive(box, a) {
  const end = new Date(a.ends_at).getTime(), start = new Date(a.started_at).getTime();
  box.innerHTML = `
    <div class="exp-active">
      <div class="idle-ring">${icon('flame', 24)}</div>
      <div><b>${esc(a.ground_name)} 원정 중</b><span id="exp-left"></span>${bar(0, 100, 'xp')}
        <small class="muted">${a.minutes}분 · ${nameOf(a.stance)} · 보급 ${Object.entries(a.supplies || {}).map(([k, n]) => `${nameOf(k)} ×${n}`).join(', ') || '없음'}</small></div>
    </div>
    <div class="btn-row"><button class="btn primary" id="exp-claim">${icon('check', 16)}<span>결과 확인</span></button><button class="btn" id="exp-recall">${icon('back', 16)}<span>일찍 귀환</span></button></div>
    <p class="muted small">원정 중에는 현장 행동을 할 수 없습니다. 능력치 분배·임무 보상·사건 추론·거래 취소는 할 수 있습니다.</p>`;
  const tick = () => {
    const left = end - Date.now(), span = $('#exp-left', box); if (!span) return clearInterval(t);
    span.textContent = left > 0 ? `${fmt.remain(left)} 남음` : '돌아왔습니다. 결과를 확인하세요.';
    box.querySelector('.bar span').style.width = `${Math.min(100, (Date.now() - start) / (end - start) * 100)}%`;
    $('#exp-claim', box).disabled = left > 0; $('#exp-recall', box).hidden = left <= 0;
  };
  const t = setInterval(tick, 1000); tick();
  $('#exp-claim', box).onclick = e => guard(e.currentTarget, async () => { const r = await act('world_expedition_finish', { p_recall: false }); showResult(r); return null; });
  $('#exp-recall', box).onclick = e => { if (confirm('지금 귀환할까요? 지난 시간만큼의 성과만 얻습니다.')) guard(e.currentTarget, async () => { const r = await act('world_expedition_finish', { p_recall: true }); showResult(r); return null; }); };
}

const ENDED = { complete: '무사히 돌아왔습니다', recalled: '일찍 귀환했습니다', downed: '쓰러졌습니다 — 구조가 필요합니다', exhausted: '지쳐서 서둘러 돌아왔습니다' };
export function showResult(r) {
  const x = r?.result || r; if (!x) return;
  const items = Object.entries(x.loot || {}).filter(([, n]) => n > 0);
  const lost = Object.entries(x.lost || {}).filter(([, n]) => n > 0);
  openModal({ title: `${r?.ground_name || '원정'} 결과`, wide: true, body: `
    <div class="exp-result ended-${esc(x.ended)}">
      <p class="lead">${esc(ENDED[x.ended] || '원정을 마쳤습니다')}</p>
      <div class="stat-tiles">
        <div><span>전투</span><b>${x.wins}승 ${x.losses}패</b></div><div><span>채집</span><b>${x.gathers}회</b></div>
        <div><span>발견</span><b>${x.finds}회</b></div><div><span>답사도</span><b>${x.progress_before}% → ${x.progress_after}%</b></div>
        <div><span>경험치</span><b>+${x.experience}${x.levels ? ` · Lv +${x.levels}` : ''}</b></div><div><span>전</span><b>+${fmt.num(x.gil)}</b></div>
      </div>
      <h3 class="sub-h">챙겨 온 것</h3>
      <p>${items.length ? items.map(([k, n]) => `${esc(nameOf(k))} ×${n}`).join(', ') : '없음'}</p>
      ${lost.length ? `<p class="bad small">가방이 가득 차 두고 온 것: ${lost.map(([k, n]) => `${esc(nameOf(k))} ×${n}`).join(', ')}</p>` : ''}
      <h3 class="sub-h">원정 기록</h3>
      <ol class="exp-log">${(x.log || []).map(l => `<li>${esc(l)}</li>`).join('') || '<li>조용한 원정이었습니다.</li>'}</ol>
      <p class="muted small">돌아온 상태 — 체력 ${x.health} · 정신 ${x.mental} · 침식 ${x.erosion} · 숙련 경험 전투 +${x.combat_xp} / 채집 +${x.gathering_xp} / 조사 +${x.investigation_xp}</p>
    </div>` });
}

function recent(list) {
  if (!list?.length) return '';
  return `<h3 class="sub-h">최근 원정</h3><ul class="spot-list">${list.map((r, i) => `<li><div><b>${esc(r.ground_name)}</b><small>${r.minutes}분 · ${nameOf(r.stance)} · ${esc(ENDED[r.result?.ended] || '')} · 답사도 ${r.result?.progress_after ?? '-'}%</small></div>
    <button class="btn small ghost" data-recent="${i}">기록</button></li>`).join('')}</ul>`;
}
export function bindRecent(box, list) {
  $$('[data-recent]', box).forEach(b => b.onclick = () => { const r = list[Number(b.dataset.recent)]; showResult({ ground_name: r.ground_name, result: r.result }); });
}
