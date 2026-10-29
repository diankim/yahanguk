// 원정: 찾아낸 세부 지역 한 곳을 골라 기간·태세를 정해 보낸다. 보급품은 가방에 있는 것을 자동으로 챙겨 가서
// 필요할 때 쓰고, 남은 것은 돌아오면 가방에 돌려놓는다. 결과는 서버가 능력치·장비·직업·대세력을 반영해 계산한다.
import { ask, store, on, act, rpc, toast, nameOf, esc, icon, guard, $, $$, fmt, empty, openModal, bar, bagLimit, bagUsed, loadCharacter } from '../core.js';
import { chip, danger, load, loading, errorBox } from './common.js';

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
  analyst: ['현장 가공', '채집할 때 25% 확률로 재료를 하나 더 손질해 챙깁니다.'],
  artificer: ['반격 태세', '싸움에서 밀리면 다음 싸움의 승률이 15% 오릅니다.'],
};
const KIND_ICON = { start: 'flame', round: 'route', walk: 'pin', env: 'cloud', supply: 'bag', warn: 'heart', end: 'check',
  fight: 'sword', atk: 'sword', hurt: 'heart', heal: 'plus', skill: 'spark', win: 'check', lose: 'back', down: 'heart', gather: 'leaf', find: 'search', guard: 'shield', foe: 'flame' };
let seenLines = 0; // 새로 붙은 줄만 살짝 강조한다
let pick = { node: null, minutes: 60, stance: 'balanced' };
// 같은 설정으로 다시 보내기: 마지막으로 보낸 곳·기간·태세를 기기에 남긴다
const LAST_KEY = 'yh-exp-last';
const lastPick = () => { try { return JSON.parse(localStorage.getItem(LAST_KEY) || 'null'); } catch { return null; } };
const saveLast = p => { try { localStorage.setItem(LAST_KEY, JSON.stringify(p)); } catch {} };
const STANCE_NAME = { cautious: '신중', balanced: '균형', bold: '강행' };
const DUR_NAME = Object.fromEntries(DURATIONS);
async function launch(p) {
  const out = await act('world_expedition_start', { p_node_id: p.node, p_minutes: p.minutes, p_stance: p.stance });
  saveLast({ node: p.node, minutes: p.minutes, stance: p.stance });
  return out;
}
// 파티 원정 함께 출발: 파티장이 제안하고 같은 곳의 동료가 답하면 서버가 한 번에 모두 출발시킨다(출발·귀환 시각이 같다)
async function partyInfo() {
  const [p, offer] = await Promise.all([load('world_party_overview', undefined, { maxAge: 30000 }).catch(() => null), rpc('world_party_expedition_offer_status').catch(() => null)]);
  const me = store.character, members = p?.members || [];
  return { offer, leader: members.some(m => m.owner_id === me.owner_id && m.role === 'leader'), inParty: members.length > 1,
    here: members.filter(m => m.owner_id !== me.owner_id && m.location === me.location && !m.downed && !m.expedition).length };
}
const ANSWER = { accepted: '수락', declined: '거절' };
function partyBox(info) {
  const o = info.offer;
  if (o) {
    const head = `<b>${esc(o.leader)} 파티장의 제안</b> · ${esc(o.node_name || '원정지')} · ${DUR_NAME[o.minutes] || o.minutes + '분'} · ${STANCE_NAME[o.stance] || ''}`;
    const who = (o.members || []).map(m => `${esc(m.name)} <i class="${m.answer || 'wait'}">${ANSWER[m.answer] || '대기'}</i>`).join(' · ');
    if (o.is_leader) return `<div class="pexp-box">${icon('users', 14)}<div>${head}<small>동료 답: ${who} · ${fmt.remain(new Date(o.expires_at) - Date.now())} 남음</small>
      <div class="btn-row"><button class="btn small primary" data-pexp-go="${esc(o.offer_id)}">지금 출발</button><button class="btn small" data-pexp-cancel="${esc(o.offer_id)}">제안 거두기</button></div></div></div>`;
    if (!o.my_answer) return `<div class="pexp-box">${icon('users', 14)}<div>${head}<small>수락하면 모두 답한 순간 함께 출발합니다. 동료 답: ${who}</small>
      <div class="btn-row"><button class="btn small primary" data-pexp-ans="1" data-offer="${esc(o.offer_id)}">수락</button><button class="btn small" data-pexp-ans="0" data-offer="${esc(o.offer_id)}">거절</button></div></div></div>`;
    return `<div class="pexp-box">${icon('users', 14)}<div>${head}<small>${o.my_answer === 'accepted' ? '수락했습니다. 다른 동료의 답을 기다립니다.' : '이번 원정에서 빠졌습니다.'} 동료 답: ${who}</small></div></div>`;
  }
  if (info.leader && info.here > 0) return `<button class="btn block" id="exp-propose">${icon('users', 16)}<span>같은 곳의 동료 ${info.here}명과 함께 출발 제안</span></button>
    <p class="muted small">동료가 수락하면 모두 같은 시각에 출발해 함께 돌아옵니다. 둘이면 동료가 수락해야, 셋 이상이면 거절한 사람을 빼고 출발합니다.</p>`;
  if (info.inParty && !info.leader) return '<p class="muted small">파티 원정은 파티장이 제안합니다. 제안을 수락하면 모두 같은 시각에 출발합니다.</p>';
  return '';
}

// 원정 창(팝업): 현장·상태판·알림 어디서든 이 창을 띄운다. 화면은 옮기지 않는다.
export async function openExpeditionWindow(preset) {
  if (preset?.node) pick = { node: preset.node, minutes: Number(preset.minutes) || pick.minutes, stance: preset.stance || pick.stance };
  const m = openModal({ title: '원정', wide: true, body: `<div class="exp-body">${loading()}</div>` });
  const box = $('.exp-body', m);
  const fill = async () => { try { renderExpedition(box, await load('world_expedition_overview')); } catch (e) { box.innerHTML = errorBox(e.message); } };
  await fill();
  const offc = on('changed', ({ name }) => { if (!box.isConnected) return offc(); if (/expedition/.test(name)) fill(); });
}
window.addEventListener('yh-open-expedition', e => openExpeditionWindow(e.detail));

export function renderExpedition(box, ov) {
  const c = store.character;
  if (ov?.active) return renderActive(box, ov.active);
  const opts = ov?.options || [];
  if (!opts.length) { box.innerHTML = empty('원정을 보낼 곳이 없습니다. 바깥 지역에서 탐색으로 장소를 먼저 찾으세요.', 'map'); return; }
  if (!opts.some(o => o.node_id === pick.node && !o.locked)) pick.node = opts.find(o => !o.locked)?.node_id || null;
  const sup = Object.entries(ov.supplies || {}).filter(([, n]) => n > 0);
  const tokens = Number(ov.tokens ?? c.mount_tokens ?? 0);
  const fareOf = id => Number(opts.find(o => o.node_id === id)?.fare || 1);
  const last = lastPick(), lastOpt = last && opts.find(o => o.node_id === last.node && !o.locked);
  const rations = Number(ov.supplies?.travel_ration || 0);
  // PC: 왼쪽에 보낼 곳·기간·태세, 오른쪽에 보급품·안내·출발. 모바일: 한 줄로 쌓는다.
  box.innerHTML = `
    <div class="exp-progress"><span>${esc(ov.region_name || '')} 답사</span><b>${ov.survey?.pct ?? 0}%</b>${bar(ov.survey?.pct ?? 0, 100, 'xp')}<small>원정에서 길과 채집터를 새로 찾으면 답사가 오릅니다. 깊은 곳일수록 위험하고 얻는 것이 많습니다.</small></div>
    ${lastOpt ? `<div class="exp-again"><span>${icon('route', 14)} 지난 설정 · <b>${esc(lastOpt.name)}</b> · ${esc(DUR_NAME[last.minutes] || '')} · ${esc(STANCE_NAME[last.stance] || '')} · 노정패 ${lastOpt.fare || 1}</span>
      <button class="btn small primary" id="exp-again" ${tokens < (lastOpt.fare || 1) ? 'disabled' : ''}>같은 설정으로 다시 보내기</button></div>` : ''}
    <div class="exp-plan">
      <div class="exp-col">
        <h3 class="sub-h">보낼 곳</h3>
        <div class="ground-list">${opts.map(o => `<button class="ground ${o.node_id === pick.node ? 'on' : ''}" data-node="${esc(o.node_id)}" ${o.locked ? 'disabled' : ''}>
            <header><b>${esc(o.name)}</b>${chip(DEPTH[o.depth] || '', o.depth >= 3 ? 'bad' : o.depth === 2 ? 'warn' : '')}</header>
            <small>${o.locked ? `Lv.${o.min_level}부터` : `${danger(o.danger)} 권장 Lv.${o.min_level}+ · 운임 노정패 ${o.fare || 1}`}</small></button>`).join('')}</div>
        <h3 class="sub-h">기간</h3><div class="chip-pick" data-pick="minutes">${DURATIONS.map(([m, l]) => `<button data-v="${m}" class="${m === pick.minutes ? 'on' : ''}">${l}</button>`).join('')}</div>
        <h3 class="sub-h">태세</h3><div class="stance-pick">${STANCES.map(([k, n, d]) => `<button data-stance="${k}" class="${k === pick.stance ? 'on' : ''}"><b>${n}</b><small>${d}</small></button>`).join('')}</div>
      </div>
      <aside class="exp-col exp-side">
        <h3 class="sub-h">챙겨 갈 보급품 <small class="muted">가방에서 자동으로 챙깁니다</small></h3>
        ${sup.length ? `<ul class="supply-auto">${sup.map(([k, n]) => `<li><b>${esc(nameOf(k))} <span class="muted">×${n}</span></b><small>${esc(SUPPLY_USE[k] || '필요할 때')} 씁니다</small></li>`).join('')}</ul>`
          : `<p class="muted small">가방에 원정용 보급품이 없습니다. 청심환·약초·정화 부적·노정 건량을 챙기면 더 오래 버팁니다.</p>`}
        <ul class="exp-notes">
          <li id="exp-fare-row">${icon('route', 14)}<span id="exp-fare"></span></li>
          ${c.level <= 10 ? `<li>${icon('spark', 14)}<span><b>신입 원정 지원</b>Lv.10까지는 원정 경험치가 30% 더 붙습니다.</span></li>` : ''}
          <li>${icon('bag', 14)}<span><b>원정에서만 얻는 것</b>길잡이 등불·비경 지도·비약·봉인된 보따리·강화 재료·원정 장비. 2시간 넘게 끝까지 다녀오면 그 지역의 비경을 찾기도 합니다.</span></li>
          <li>${icon('check', 14)}<span><b>끝까지 다녀오면</b>1시간 이상은 원정지 수준 장비 하나(1시간 50%, 2시간 이상 반드시), 2시간 이상은 경험치·전·숙련 경험 +20%(4시간 +30%·8시간 +40%). 일찍 귀환하면 받지 못합니다.</span></li>
          ${JOB_SKILL[c.job_key] ? `<li class="skill">${icon('spark', 14)}<span><b>${esc(nameOf(c.job_key))} 원정 기술 · ${esc(JOB_SKILL[c.job_key][0])}</b>${esc(JOB_SKILL[c.job_key][1])}</span></li>` : ''}
          <li id="exp-hint-row">${icon('bag', 14)}<span id="exp-hint"></span></li>
        </ul>
        <div id="exp-party"></div>
        <button class="btn primary block" id="exp-go" ${pick.node ? '' : 'disabled'}>${icon('flame', 16)}<span>원정 출발</span></button>
        <p class="muted small exp-foot">원정 중에는 이동·전투·채집·거래를 할 수 없습니다. 언제든 일찍 돌아올 수 있지만 지난 시간만큼만 성과를 얻습니다.</p>
      </aside>
    </div>
    ${recent(ov.recent)}`;
  const hint = () => {
    const need = Math.floor(pick.minutes / 60);
    const short = need > rations;
    $('#exp-hint', box).textContent = short ? `노정 건량이 ${need - rations}개 모자랍니다. 허기 때문에 정신이 깎이고 수확이 줄어듭니다.` : `가방 ${bagUsed(c)}/${bagLimit(c)}칸 · 전리품이 가방을 넘치면 남는 것은 두고 옵니다.`;
    $('#exp-hint-row', box).classList.toggle('warn', short);
    const fare = fareOf(pick.node), poor = !!pick.node && tokens < fare;
    $('#exp-fare', box).textContent = pick.node ? `운임 노정패 ${fare}개 · 가진 노정패 ${tokens}개${poor ? ' — 모자랍니다' : ''}` : `가진 노정패 ${tokens}개`;
    $('#exp-fare-row', box).classList.toggle('warn', poor);
    $('#exp-go', box).disabled = !pick.node || poor;
  };
  $$('[data-node]', box).forEach(b => b.onclick = () => { pick.node = b.dataset.node; $$('[data-node]', box).forEach(x => x.classList.toggle('on', x === b)); hint(); });
  $$('[data-pick=minutes] button', box).forEach(b => b.onclick = () => { pick.minutes = Number(b.dataset.v); $$('[data-pick=minutes] button', box).forEach(x => x.classList.toggle('on', x === b)); hint(); });
  $$('[data-stance]', box).forEach(b => b.onclick = () => { pick.stance = b.dataset.stance; $$('[data-stance]', box).forEach(x => x.classList.toggle('on', x === b)); });
  hint();
  bindRecent(box, ov.recent);
  $('#exp-go', box).onclick = e => guard(e.currentTarget, () => launch(pick));
  partyInfo().then(info => {
    const slot = $('#exp-party', box); if (!slot) return;
    slot.innerHTML = partyBox(info);
    const prop = $('#exp-propose', slot);
    if (prop) prop.onclick = e => guard(e.currentTarget, () => act('world_party_expedition_propose', { p_node_id: pick.node, p_minutes: pick.minutes, p_stance: pick.stance }));
    $$('[data-pexp-ans]', slot).forEach(b => b.onclick = () => guard(b, () => act('world_party_expedition_respond', { p_offer: b.dataset.offer, p_accept: b.dataset.pexpAns === '1' })));
    $$('[data-pexp-go]', slot).forEach(b => b.onclick = () => guard(b, () => act('world_party_expedition_depart', { p_offer: b.dataset.pexpGo, p_cancel: false })));
    $$('[data-pexp-cancel]', slot).forEach(b => b.onclick = () => guard(b, () => act('world_party_expedition_depart', { p_offer: b.dataset.pexpCancel, p_cancel: true })));
  });
  const again = $('#exp-again', box);
  if (again) again.onclick = e => guard(e.currentTarget, () => { pick = { ...last }; return launch(last); });
}

function renderActive(box, a) {
  seenLines = 0; delete box.dataset.stopped;
  const end = new Date(a.ends_at).getTime(), start = new Date(a.started_at).getTime();
  box.innerHTML = `
    <div class="exp-active">
      <div class="idle-ring">${icon('flame', 24)}</div>
      <div><b>${esc(a.place_name || a.ground_name)} 원정 중</b><span id="exp-left"></span>${bar(0, 100, 'xp')}
        <small class="muted">${esc(a.region_name || '')} · ${a.minutes}분 · ${nameOf(a.stance)} · 보급 ${Object.entries(a.supplies || {}).map(([k, n]) => `${nameOf(k)} ×${n}`).join(', ') || '없음'}</small></div>
    </div>
    <div class="btn-row"><button class="btn primary" id="exp-claim">${icon('check', 16)}<span>결과 확인</span></button><button class="btn" id="exp-recall">${icon('back', 16)}<span>일찍 귀환</span></button></div>
    <h3 class="sub-h">원정 일지 <small class="muted" id="exp-rounds"></small></h3>
    <p class="exp-now" id="exp-now">${icon('pin', 14)}<span>기록을 불러오는 중…</span></p>
    <ol class="exp-feed" id="exp-feed"></ol>
    <div id="exp-party"></div>
    <p class="muted small exp-foot">원정 일지에는 걸음마다 마주친 풍경·흔적·기척, 수색 회차, 전투(공격·반격·회복·승패)가 시간에 맞춰 쌓이고 같은 파티원의 일지도 함께 보입니다. 전투로 바뀐 체력·정신·침식은 곧바로 상태에 반영되고, 전리품은 돌아왔을 때 정리됩니다. 원정 중에는 현장 행동을 할 수 없습니다. 능력치 분배·임무 보상·사건 추론·거래 취소는 할 수 있습니다.</p>`;
  const tick = () => {
    const left = end - Date.now(), span = $('#exp-left', box); if (!span) return clearInterval(t);
    span.textContent = left > 0 ? `${fmt.remain(left)} 남음` : '돌아왔습니다. 결과를 확인하세요.';
    box.querySelector('.bar span').style.width = `${Math.min(100, (Date.now() - start) / (end - start) * 100)}%`;
    const stopped = !!box.dataset.stopped;
    $('#exp-claim', box).disabled = left > 0 && !stopped; $('#exp-recall', box).hidden = left <= 0 || stopped;
  };
  const t = setInterval(tick, 1000); tick();
  feed(box);
  $('#exp-claim', box).onclick = e => guard(e.currentTarget, async () => { const r = await act('world_expedition_complete', { p_recall: false }); showResult(r); return null; });
  $('#exp-recall', box).onclick = async e => { const b = e.currentTarget; if (await ask('지금 귀환할까요? 지난 시간만큼의 성과만 얻습니다.', { title: '일찍 귀환', ok: '귀환하기' })) guard(b, async () => { const r = await act('world_expedition_complete', { p_recall: true }); showResult(r); return null; }); };
}

// 전투 줄(마주침부터 승패까지)은 한 덩어리로 묶어 결과 한 줄만 보이고, 누르면 주고받은 내용을 펼친다
const BATTLE = new Set(['fight', 'atk', 'hurt', 'heal', 'skill', 'guard', 'foe', 'win', 'lose', 'down']);
const openBattles = new Set();
function battleGroups(ls) {
  const out = [], open = new Map(); // 사람마다 진행 중인 전투(파티원 일지가 섞여도 끊기지 않게)
  ls.forEach((l, i) => {
    const g = open.get(l.owner);
    if (g && BATTLE.has(l.kind)) {
      g.lines.push([l, i]);
      if (['win', 'lose', 'down'].includes(l.kind)) open.delete(l.owner);
      return;
    }
    // 싸우는 중에 끼어든 다른 줄(보급품 먹기 등)은 전투를 끊지 않는다. 뒤따르는 전투 줄은 계속 그 칸에 담는다.
    if (l.kind === 'fight') { const ng = { lines: [[l, i]], key: `${l.owner}|${l.at}` }; open.set(l.owner, ng); out.push(ng); return; }
    out.push({ l, i });
  });
  return out;
}
function battleBlock(g, row, me, myName) {
  const f = g.lines[0][0], end = g.lines[g.lines.length - 1][0], done = ['win', 'lose', 'down'].includes(end.kind) ? end.kind : '';
  const cnt = k => g.lines.filter(([l]) => l.kind === k).length;
  const res = done === 'win' ? '<b class="ok">승리</b>' : done === 'lose' ? '<b class="bad">밀려남</b>' : done === 'down' ? '<b class="bad">쓰러짐</b>' : '<b class="muted">싸우는 중</b>';
  return `<li class="exp-battle ${done ? 'b-' + done : ''} ${f.owner && f.owner !== me ? 'other' : 'mine'} ${openBattles.has(g.key) ? 'open' : ''}">
    <button type="button" data-k="${esc(g.key)}">${icon('sword', 14)}<span class="eb-head"><b class="who">${esc(f.who || myName || '')}</b>${esc(f.text)}</span>
      <span class="eb-sum">${res} · 공격 ${cnt('atk')} · 반격 ${cnt('hurt')}${cnt('heal') ? ` · 회복 ${cnt('heal')}` : ''}${cnt('skill') ? ` · 기술 ${cnt('skill')}` : ''}${cnt('guard') ? ` · 막기·회피 ${cnt('guard')}` : ''}</span><time>${fmt.time(f.at)}</time></button>
    <ul>${g.lines.slice(1).map(([l, i]) => row(l, i)).join('')}</ul></li>`;
}

// 진행 기록: 다음 수색 시각에 맞춰(없으면 1분마다) 다시 읽는다. 창이 닫히면 멈춘다.
async function feed(box) {
  const list = $('#exp-feed', box); if (!list?.isConnected) return;
  let p = null;
  try { p = await load('world_expedition_progress'); } catch (e) { list.innerHTML = `<li class="muted">${esc(e.message)}</li>`; }
  if (p?.active) {
    $('#exp-rounds', box).textContent = `수색 ${p.rounds_done}/${p.total_rounds} · 기록 ${(p.lines || []).length}줄${p.job_skill ? ` · 기술 ${p.job_skill}` : ''}`;
    // 일지처럼 위에서 아래로 쌓고, 가장 새 줄이 보이게 아래로 내린다(직접 위로 올려 읽는 중이면 그대로 둔다)
    const ls = p.lines || [], first = !seenLines, atEnd = first || list.scrollHeight - list.scrollTop - list.clientHeight < 40;
    const fresh = seenLines && ls.length > seenLines ? ls.length - seenLines : 0;
    const me = store.character?.owner_id;
    const row = (l, i) => `<li class="k-${esc(l.kind)} ${l.owner && l.owner !== me ? 'other' : 'mine'} ${i >= ls.length - fresh ? 'fresh' : ''}">${icon(KIND_ICON[l.kind] || 'route', 14)}<span><b class="who">${esc(l.who || p.me || '')}</b>${esc(l.text)}</span><time>${fmt.time(l.at)}</time></li>`;
    list.innerHTML = battleGroups(ls).map(g => g.lines ? battleBlock(g, row, me, p.me) : row(g.l, g.i)).join('');
    $$('.exp-battle > button', list).forEach(b => b.onclick = () => { const k = b.dataset.k; openBattles.has(k) ? openBattles.delete(k) : openBattles.add(k); b.parentElement.classList.toggle('open'); });
    seenLines = ls.length || 1;
    // 처음 열면 가장 아래(가장 새 줄)를 보여 준다. 그 뒤로는 아래를 보고 있을 때만 따라 내려간다.
    if (atEnd) { list.scrollTop = list.scrollHeight; requestAnimationFrame(() => { list.scrollTop = list.scrollHeight; }); }
    // 회차 정산으로 바뀐 체력·정신·침식을 상태판에도 곧바로 반영한다
    const c0 = store.character;
    if (c0 && (c0.health !== p.health || c0.mental !== p.mental || c0.erosion !== p.erosion)) loadCharacter().catch(() => {});
    const last = ls[ls.length - 1], nextIn = p.next_at ? Math.max(0, new Date(p.next_at) - Date.now()) : 0;
    if (p.stopped) box.dataset.stopped = '1';
    $('#exp-now', box).innerHTML = p.stopped
      ? `${icon('heart', 14)}<span><b>멈춤</b> 더 나아갈 수 없어 원정이 멈췄습니다. 지금 결과를 받고 돌아올 수 있습니다.</span>`
      : `${icon('pin', 14)}<span><b>지금</b> ${esc(last?.who ? last.who + ' · ' : '')}${esc(last?.text || '')}${nextIn ? ` <small class="muted">· 다음 기록 약 ${Math.max(1, Math.round(nextIn / 60000))}분 뒤</small>` : ''}</span>`;
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
      ${lost.length ? `<p class="bad small">가방에 자리가 없어 짐 보따리에 담은 것: ${lost.map(([k, n]) => `${esc(nameOf(k))} ×${n}`).join(', ')} · 현장의 「정리하기」에서 챙기거나 버리세요.</p>` : ''}
      ${x.full_bonus ? `<p class="hint good">${icon('check', 14)} 끝까지 다녀온 긴 원정 — 경험치·전·숙련 경험 +${x.full_bonus}%</p>` : ''}
      ${x.full_gear ? `<p class="hint good">${icon('gear', 14)} 원정 끝에 ${esc(nameOf(x.full_gear))}을(를) 챙겼습니다.</p>` : ''}
      ${x.trail ? `<p class="hint good">${icon('spark', 14)} 비경을 찾았습니다. 3시간 동안 이 지역을 탐색하면 채집량 +50%·희귀품·단서 +10%입니다.</p>` : ''}
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
