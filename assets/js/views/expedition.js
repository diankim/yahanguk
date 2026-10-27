// 원정: 찾아낸 세부 지역 한 곳을 골라 기간·태세를 정해 보낸다. 보급품은 가방에 있는 것을 자동으로 챙겨 가서
// 필요할 때 쓰고, 남은 것은 돌아오면 가방에 돌려놓는다. 결과는 서버가 능력치·장비·직업·대세력을 반영해 계산한다.
import { store, act, nameOf, esc, icon, guard, $, $$, fmt, empty, openModal, bar, bagLimit, bagUsed } from '../core.js';
import { chip, danger, load } from './common.js';

const DURATIONS = [[30, '30분'], [60, '1시간'], [120, '2시간'], [240, '4시간'], [480, '8시간']];
const STANCES = [
  ['cautious', '신중', '조우를 피하고 일찍 치료합니다. 안전하지만 얻는 것이 적습니다.'],
  ['balanced', '균형', '싸울 때는 싸우고 물러날 때는 물러납니다.'],
  ['bold', '강행', '요괴를 찾아다니며 깊이 들어갑니다. 전리품과 발견이 늘지만 다치기 쉽습니다.'],
];
const SUPPLY_USE = { tonic: '체력이 떨어지면', herbal_extract: '체력이 떨어지면', herb: '체력이 떨어지면', ward_talisman: '침식이 50을 넘으면',
  seal_paper: '영체·결계 요괴를 만나면', revival_charm: '쓰러지기 직전', travel_ration: '한 시간마다' };
const DEPTH = ['초입', '권역', '구역', '깊은 곳', '가장 깊은 곳'];
// 직업별 원정 기술(서버 world_expedition_complete가 계산한다)
export const JOB_SKILL = {
  exorcist: ['파사 부적', '원정마다 한 번, 영체·결계 요괴를 부적으로 단번에 퇴치합니다.'],
  scout: ['흔적 추적', '요괴와 마주치기 전에 흔적을 읽고 30% 확률로 피해 가며, 대신 무언가를 발견합니다.'],
  medic: ['야전 처치', '보급품이 떨어졌을 때 원정마다 한 번 주변 약초로 체력을 30 되찾습니다.'],
  sealmaster: ['결계 야영', '스며드는 요기(침식·정신 손실)를 50% 확률로 결계로 막습니다.'],
  analyst: ['약점 간파', '싸움에서 밀리면 다음 싸움의 승률이 15% 오릅니다.'],
  artificer: ['현장 가공', '채집할 때 25% 확률로 재료를 하나 더 손질해 챙깁니다.'],
};
const KIND_ICON = { start: 'flame', round: 'route', env: 'cloud', supply: 'bag', warn: 'heart', end: 'check' };
let pick = { node: null, minutes: 60, stance: 'balanced' };

export function renderExpedition(box, ov) {
  const c = store.character;
  if (ov?.active) return renderActive(box, ov.active);
  const opts = ov?.options || [];
  if (!opts.length) { box.innerHTML = empty('원정을 보낼 곳이 없습니다. 바깥 지역에서 탐색으로 장소를 먼저 찾으세요.', 'map'); return; }
  if (!opts.some(o => o.node_id === pick.node && !o.locked)) pick.node = opts.find(o => !o.locked)?.node_id || null;
  const sup = Object.entries(ov.supplies || {}).filter(([, n]) => n > 0);
  const rations = Number(ov.supplies?.travel_ration || 0);
  box.innerHTML = `
    <div class="exp-progress"><span>${esc(ov.region_name || '')} 답사</span><b>${ov.survey?.pct ?? 0}%</b>${bar(ov.survey?.pct ?? 0, 100, 'xp')}<small>원정에서 길과 채집터를 새로 찾으면 답사가 오릅니다. 깊은 곳일수록 위험하고 얻는 것이 많습니다.</small></div>
    <h3 class="sub-h">보낼 곳</h3>
    <div class="ground-list">${opts.map(o => `<button class="ground ${o.node_id === pick.node ? 'on' : ''}" data-node="${esc(o.node_id)}" ${o.locked ? 'disabled' : ''}>
        <header><b>${esc(o.name)}</b>${chip(DEPTH[o.depth] || '', o.depth >= 3 ? 'bad' : o.depth === 2 ? 'warn' : '')}</header>
        <small>${o.locked ? `Lv.${o.min_level}부터` : `${danger(o.danger)} 권장 Lv.${o.min_level}+`}</small></button>`).join('')}</div>
    <h3 class="sub-h">기간</h3><div class="chip-pick" data-pick="minutes">${DURATIONS.map(([m, l]) => `<button data-v="${m}" class="${m === pick.minutes ? 'on' : ''}">${l}</button>`).join('')}</div>
    <h3 class="sub-h">태세</h3><div class="stance-pick">${STANCES.map(([k, n, d]) => `<button data-stance="${k}" class="${k === pick.stance ? 'on' : ''}"><b>${n}</b><small>${d}</small></button>`).join('')}</div>
    <h3 class="sub-h">챙겨 갈 보급품 <small class="muted">— 가방에서 자동으로 챙깁니다</small></h3>
    ${sup.length ? `<ul class="supply-auto">${sup.map(([k, n]) => `<li><b>${esc(nameOf(k))} ×${n}</b><small>${esc(SUPPLY_USE[k] || '')} 씁니다</small></li>`).join('')}</ul>`
      : `<p class="hint">가방에 원정용 보급품이 없습니다. 청심환·약초·정화 부적·노정 건량을 챙기면 더 오래 버팁니다.</p>`}
    ${JOB_SKILL[c.job_key] ? `<p class="hint">${icon('spark', 14)} <b>${esc(nameOf(c.job_key))} 원정 기술 · ${esc(JOB_SKILL[c.job_key][0])}</b> — ${esc(JOB_SKILL[c.job_key][1])}</p>` : ''}
    <p class="hint" id="exp-hint"></p>
    <button class="btn primary block" id="exp-go" ${pick.node ? '' : 'disabled'}>${icon('flame', 16)}<span>원정 출발</span></button>
    <p class="muted small">원정 중에는 이동·전투·채집·거래를 할 수 없습니다. 언제든 일찍 돌아올 수 있지만 지난 시간만큼만 성과를 얻습니다.</p>
    ${recent(ov.recent)}`;
  const hint = () => {
    const need = Math.floor(pick.minutes / 60);
    $('#exp-hint', box).textContent = need > rations ? `노정 건량이 ${need - rations}개 모자랍니다. 허기 때문에 정신이 깎이고 수확이 줄어듭니다.` : `가방 ${bagUsed(c)}/${bagLimit(c)}칸 · 전리품이 가방을 넘치면 남는 것은 두고 옵니다.`;
  };
  $$('[data-node]', box).forEach(b => b.onclick = () => { pick.node = b.dataset.node; $$('[data-node]', box).forEach(x => x.classList.toggle('on', x === b)); $('#exp-go', box).disabled = false; });
  $$('[data-pick=minutes] button', box).forEach(b => b.onclick = () => { pick.minutes = Number(b.dataset.v); $$('[data-pick=minutes] button', box).forEach(x => x.classList.toggle('on', x === b)); hint(); });
  $$('[data-stance]', box).forEach(b => b.onclick = () => { pick.stance = b.dataset.stance; $$('[data-stance]', box).forEach(x => x.classList.toggle('on', x === b)); });
  hint();
  bindRecent(box, ov.recent);
  $('#exp-go', box).onclick = e => guard(e.currentTarget, () => act('world_expedition_start', { p_node_id: pick.node, p_minutes: pick.minutes, p_stance: pick.stance }));
}

function renderActive(box, a) {
  const end = new Date(a.ends_at).getTime(), start = new Date(a.started_at).getTime();
  box.innerHTML = `
    <div class="exp-active">
      <div class="idle-ring">${icon('flame', 24)}</div>
      <div><b>${esc(a.place_name || a.ground_name)} 원정 중</b><span id="exp-left"></span>${bar(0, 100, 'xp')}
        <small class="muted">${esc(a.region_name || '')} · ${a.minutes}분 · ${nameOf(a.stance)} · 보급 ${Object.entries(a.supplies || {}).map(([k, n]) => `${nameOf(k)} ×${n}`).join(', ') || '없음'}</small></div>
    </div>
    <div class="btn-row"><button class="btn primary" id="exp-claim">${icon('check', 16)}<span>결과 확인</span></button><button class="btn" id="exp-recall">${icon('back', 16)}<span>일찍 귀환</span></button></div>
    <h3 class="sub-h">진행 기록 <small class="muted" id="exp-rounds"></small></h3>
    <ol class="exp-feed" id="exp-feed"><li class="muted">기록을 불러오는 중…</li></ol>
    <div id="exp-party"></div>
    <p class="muted small">진행 기록에는 수색 회차·건량·날씨 변화·주변의 기척이 시간에 맞춰 올라옵니다. 싸움의 승패와 전리품은 돌아왔을 때 한꺼번에 밝혀집니다. 원정 중에는 현장 행동을 할 수 없습니다. 능력치 분배·임무 보상·사건 추론·거래 취소는 할 수 있습니다.</p>`;
  const tick = () => {
    const left = end - Date.now(), span = $('#exp-left', box); if (!span) return clearInterval(t);
    span.textContent = left > 0 ? `${fmt.remain(left)} 남음` : '돌아왔습니다. 결과를 확인하세요.';
    box.querySelector('.bar span').style.width = `${Math.min(100, (Date.now() - start) / (end - start) * 100)}%`;
    $('#exp-claim', box).disabled = left > 0; $('#exp-recall', box).hidden = left <= 0;
  };
  const t = setInterval(tick, 1000); tick();
  feed(box);
  $('#exp-claim', box).onclick = e => guard(e.currentTarget, async () => { const r = await act('world_expedition_complete', { p_recall: false }); showResult(r); return null; });
  $('#exp-recall', box).onclick = e => { if (confirm('지금 귀환할까요? 지난 시간만큼의 성과만 얻습니다.')) guard(e.currentTarget, async () => { const r = await act('world_expedition_complete', { p_recall: true }); showResult(r); return null; }); };
}

// 진행 기록: 다음 수색 시각에 맞춰(없으면 1분마다) 다시 읽는다. 창이 닫히면 멈춘다.
async function feed(box) {
  const list = $('#exp-feed', box); if (!list?.isConnected) return;
  let p = null;
  try { p = await load('world_expedition_progress'); } catch (e) { list.innerHTML = `<li class="muted">${esc(e.message)}</li>`; }
  if (p?.active) {
    $('#exp-rounds', box).textContent = `수색 ${p.rounds_done}/${p.total_rounds}${p.job_skill ? ` · 기술 ${p.job_skill}` : ''}`;
    list.innerHTML = [...(p.lines || [])].reverse().map(l => `<li class="k-${esc(l.kind)}">${icon(KIND_ICON[l.kind] || 'route', 14)}<span>${esc(l.text)}</span><time>${fmt.time(l.at)}</time></li>`).join('');
    const party = p.party || [];
    $('#exp-party', box).innerHTML = party.length ? `<h3 class="sub-h">원정 중인 동료</h3><ul class="spot-list">${party.map(m => `<li><div><b>${esc(m.name)}</b>
        <small>${esc(m.region || '')} · ${esc(m.place || '')}${m.same_region ? ' · 같은 지역' : ''} · 수색 ${m.rounds_done}/${m.total_rounds}</small></div>${bar(m.rounds_done, m.total_rounds, 'xp')}</li>`).join('')}</ul>` : '';
  }
  const wait = p?.next_at ? Math.max(5000, new Date(p.next_at) - Date.now() + 1500) : 60000;
  setTimeout(() => { if (list.isConnected && !document.hidden) feed(box); else if (list.isConnected) setTimeout(() => feed(box), 30000); }, Math.min(wait, 120000));
}

const ENDED = { complete: '무사히 돌아왔습니다', recalled: '일찍 귀환했습니다', downed: '쓰러졌습니다 — 구조가 필요합니다', exhausted: '지쳐서 서둘러 돌아왔습니다' };
export function showResult(r) {
  const x = r?.result || r; if (!x) return;
  const items = Object.entries(x.loot || {}).filter(([, n]) => n > 0);
  const lost = Object.entries(x.lost || {}).filter(([, n]) => n > 0);
  openModal({ title: `${r?.place_name || r?.ground_name || '원정'} 결과`, wide: true, body: `
    <div class="exp-result ended-${esc(x.ended)}">
      <p class="lead">${esc(ENDED[x.ended] || '원정을 마쳤습니다')}</p>
      <div class="stat-tiles">
        <div><span>전투</span><b>${x.wins}승 ${x.losses}패</b></div><div><span>채집</span><b>${x.gathers}회</b></div>
        <div><span>발견</span><b>${x.finds}회</b></div><div><span>답사</span><b>${x.progress_before}% → ${x.progress_after}%</b></div>
        <div><span>경험치</span><b>+${x.experience}${x.levels ? ` · Lv +${x.levels}` : ''}</b></div><div><span>전</span><b>+${fmt.num(x.gil)}</b></div>
      </div>
      <h3 class="sub-h">챙겨 온 것</h3>
      <p>${items.length ? items.map(([k, n]) => `${esc(nameOf(k))} ×${n}`).join(', ') : '없음'}</p>
      ${lost.length ? `<p class="bad small">가방이 가득 차 두고 온 것: ${lost.map(([k, n]) => `${esc(nameOf(k))} ×${n}`).join(', ')}</p>` : ''}
      ${x.job_skill?.name ? `<p class="hint">${icon('spark', 14)} 직업 기술 「${esc(x.job_skill.name)}」 ${x.job_skill.count ? `${x.job_skill.count}번 발동` : '발동하지 않음'}</p>` : ''}
      <h3 class="sub-h">원정 기록</h3>
      <ol class="exp-log">${(x.log || []).map(l => `<li>${esc(l)}</li>`).join('') || '<li>조용한 원정이었습니다.</li>'}</ol>
      <p class="muted small">돌아온 상태 — 체력 ${x.health} · 정신 ${x.mental} · 침식 ${x.erosion} · 숙련 경험 전투 +${x.combat_xp} / 채집 +${x.gathering_xp} / 조사 +${x.investigation_xp}</p>
    </div>` });
}

function recent(list) {
  if (!list?.length) return '';
  return `<h3 class="sub-h">최근 원정</h3><ul class="spot-list">${list.map((r, i) => `<li><div><b>${esc(r.place_name || r.ground_name)}</b><small>${r.minutes}분 · ${nameOf(r.stance)} · ${esc(ENDED[r.result?.ended] || '')} · 답사 ${r.result?.progress_after ?? '-'}%</small></div>
    <button class="btn small ghost" data-recent="${i}">기록</button></li>`).join('')}</ul>`;
}
export function bindRecent(box, list) {
  $$('[data-recent]', box).forEach(b => b.onclick = () => { const r = list[Number(b.dataset.recent)]; showResult({ place_name: r.place_name || r.ground_name, result: r.result }); });
}
