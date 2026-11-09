import { ask, store, on, act, rpc, nameOf, esc, icon, guard, $, $$, fmt, empty, openModal, bar, bagLimit, bagUsed, loadCharacter } from '../core.js';
import { PARTY_EXP } from '../rules.js';
import { GAMEDATA } from '../gamedata.js';
import { chip, danger, load, loading, errorBox } from './common.js';
import { hit } from '../changes.js';

const DURATIONS = [[30, '30분'], [60, '1시간'], [120, '2시간'], [240, '4시간'], [480, '8시간']];
const STANCES = [
  ['cautious', '신중', '조우를 피하고 일찍 치료합니다. 안전하지만 얻는 것이 적습니다.'],
  ['balanced', '균형', '싸울 때는 싸우고 물러날 때는 물러납니다.'],
  ['bold', '강행', '요괴를 찾아다니며 깊이 들어갑니다. 전리품과 발견이 늘지만 다치기 쉽습니다.'],
];
const SUPPLY_USE = { tonic: '체력이 떨어지면', herbal_extract: '체력이 떨어지면', herb: '체력이 떨어지면', ward_talisman: '침식이 50을 넘으면',
  seal_paper: '영체·결계 요괴를 만나면', revival_charm: '쓰러지기 직전', travel_ration: '한 시간마다' };
const DEPTH = ['초입', '권역', '구역', '깊은 곳', '가장 깊은 곳'];
export const JOB_SKILL = {
  exorcist: ['파사 부적', '원정마다 한 번, 영체·결계 요괴를 부적으로 단번에 퇴치합니다.'],
  scout: ['선제 사격', '싸울 때마다 30% 확률로 먼저 쏘아 그 싸움의 승률 +12%p.'],
  tamer: ['동무의 코', `데리고 다니는 동무가 길·채집터·숨은 것을 더 잘 찾고(발견 최대 +${GAMEDATA.petPartner?.exp?.find}%), 원정 전투력이 최대 +${GAMEDATA.petPartner?.exp?.atk}%, 싸움마다 승률이 최대 +${Math.round((GAMEDATA.petPartner?.exp?.win || 0) * 100)}%p 오릅니다(동무의 힘만큼). 동무가 없으면 쓰지 못합니다.`],
  medic: ['야전 처치', '체력이 회복 기준 아래로 떨어지면 보급품보다 먼저 주변 약초로 체력을 25 되찾습니다(원정마다 세 번, 회복 보정 적용).'],
  sealmaster: ['결계 야영', '스며드는 요기(침식·정신 손실)를 50% 확률로 결계로 막습니다.'],
  analyst: ['급소 찌르기', '싸울 때마다 25% 확률로 급소를 짚어 그 싸움의 승률 +10%p.'],
  artificer: ['반격 태세', '싸움에서 밀리면 다음 싸움의 승률이 15% 오릅니다.'],
};
const KIND_ICON = { start: 'flame', round: 'route', walk: 'pin', env: 'cloud', supply: 'bag', warn: 'heart', end: 'check',
  fight: 'sword', atk: 'sword', hurt: 'heart', heal: 'plus', skill: 'spark', win: 'check', lose: 'back', down: 'heart', gather: 'leaf', find: 'search', guard: 'shield', foe: 'flame' };
let seenLines = 0;
let pick = { node: null, minutes: 60, stance: 'balanced' };
let preferHere = false;
const LAST_KEY = 'yh-exp-last';
const lastPick = () => { try { return JSON.parse(localStorage.getItem(LAST_KEY) || 'null'); } catch { return null; } };
const saveLast = p => { try { localStorage.setItem(LAST_KEY, JSON.stringify(p)); } catch {} };
const STANCE_NAME = { cautious: '신중', balanced: '균형', bold: '강행' };
const DUR_NAME = Object.fromEntries(DURATIONS);
let supPick = {};
async function launch(p) {
  const sup = Object.fromEntries(Object.entries(supPick).filter(([, n]) => n >= 0));
  const out = await act('world_expedition_start', Object.keys(sup).length ? { p_node_id: p.node, p_minutes: p.minutes, p_stance: p.stance, p_supplies: sup } : { p_node_id: p.node, p_minutes: p.minutes, p_stance: p.stance });
  supPick = {};
  saveLast({ node: p.node, minutes: p.minutes, stance: p.stance });
  return out;
}
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

export async function openExpeditionWindow(preset) {
  if (preset?.node) pick = { node: preset.node, minutes: Number(preset.minutes) || pick.minutes, stance: preset.stance || pick.stance };
  preferHere = !preset?.node;
  const m = openModal({ title: '원정', wide: true, body: `<div class="exp-body">${loading()}</div>` });
  const box = $('.exp-body', m);
  const fill = async () => { try { renderExpedition(box, await load('world_expedition_overview')); } catch (e) { box.innerHTML = errorBox(e.message); } };
  await fill();
  const offc = on('changed', ({ name }) => { if (!box.isConnected) return offc(); if (hit('expedition', name)) fill(); });
}
window.addEventListener('yh-open-expedition', e => openExpeditionWindow(e.detail));

export function renderExpedition(box, ov) {
  const c = store.character;
  if (ov?.active) return renderActive(box, ov.active);
  const opts = ov?.options || [];
  if (!opts.length) { box.innerHTML = empty('원정을 보낼 곳이 없습니다. 바깥 지역에서 탐색으로 장소를 먼저 찾으세요.', 'map'); return; }
  const hereId = c?.current_exploration_node_id;
  if (preferHere) { preferHere = false; if (opts.some(o => o.node_id === hereId && !o.locked)) pick.node = hereId; }
  if (!opts.some(o => o.node_id === pick.node && !o.locked)) pick.node = opts.find(o => !o.locked)?.node_id || null;
  const SUP_CAP = 20, capOf = k => Math.min(SUP_CAP, Number(ov.supplies?.[k] || 0));
  const sup = Object.entries(ov.supplies || {}).filter(([, n]) => n > 0).map(([k, n]) => [k, Math.min(SUP_CAP, n)]);
  const tokens = Number(ov.tokens ?? c.mount_tokens ?? 0);
  const fareOf = id => Number(opts.find(o => o.node_id === id)?.fare || 1);
  const last = lastPick(), lastOpt = last && opts.find(o => o.node_id === last.node && !o.locked);
  for (const k of Object.keys(supPick)) if (!(ov.supplies?.[k] > 0) || supPick[k] > capOf(k)) delete supPick[k];
  const supN = k => supPick[k] ?? capOf(k);
  const rations = () => supN('travel_ration');
  box.innerHTML = `
    <div class="exp-progress"><span>${esc(ov.region_name || '')} 답사</span><b>${ov.survey?.pct ?? 0}%</b>${bar(ov.survey?.pct ?? 0, 100, 'xp')}<small>원정에서 길과 채집터를 새로 찾으면 답사가 오릅니다. 깊은 곳일수록 위험하고 얻는 것이 많습니다.</small></div>
    ${lastOpt ? `<div class="exp-again"><span>${icon('route', 14)} 지난 설정 · <b>${esc(lastOpt.name)}</b> · ${esc(DUR_NAME[last.minutes] || '')} · ${esc(STANCE_NAME[last.stance] || '')} · 노정패 ${lastOpt.fare || 1}</span>
      <button class="btn small primary" id="exp-again" ${tokens < (lastOpt.fare || 1) ? 'disabled' : ''}>같은 설정으로 다시 보내기</button></div>` : ''}
    <div class="exp-plan">
      <div class="exp-col">
        <h3 class="sub-h">보낼 곳</h3>
        <div class="ground-list">${[...opts.filter(o => o.node_id === hereId), ...opts.filter(o => o.node_id !== hereId)].map(o => `<button class="ground ${o.node_id === pick.node ? 'on' : ''}" data-node="${esc(o.node_id)}" ${o.locked ? 'disabled' : ''}>
            <b class="g-name">${esc(o.name)}</b>
            <small>${o.node_id === hereId ? chip('지금 있는 곳', 'ok') : ''}${chip(DEPTH[o.depth] || '', o.depth >= 3 ? 'bad' : o.depth === 2 ? 'warn' : '')}${o.locked ? `Lv.${o.min_level}부터` : `${danger(o.danger)} 권장 Lv.${o.min_level}+ · 노정패 ${o.fare || 1}`}</small></button>`).join('')}</div>
        <h3 class="sub-h">기간</h3><div class="chip-pick" data-pick="minutes">${DURATIONS.map(([m, l]) => `<button data-v="${m}" class="${m === pick.minutes ? 'on' : ''}">${l}</button>`).join('')}</div>
        <h3 class="sub-h">태세</h3><div class="stance-pick">${STANCES.map(([k, n, d]) => `<button data-stance="${k}" class="${k === pick.stance ? 'on' : ''}" title="${esc(d)}"><b>${n}</b><small>${d}</small></button>`).join('')}</div>
        <p class="stance-desc muted small">${esc((STANCES.find(x => x[0] === pick.stance) || [])[2] || '')}</p>
      </div>
      <aside class="exp-col exp-side">
        <h3 class="sub-h">챙겨 갈 보급품 <small class="muted">기본은 가진 만큼(가지마다 20개까지) · 개수를 줄이거나 빼도 됩니다</small></h3>
        ${sup.length ? `<ul class="supply-auto">${sup.map(([k, n]) => `<li class="${supN(k) === 0 ? 'off' : ''}"><b>${esc(nameOf(k))}</b>
            <span class="sup-step" data-sup="${esc(k)}" data-max="${n}" role="group" aria-label="${esc(nameOf(k))} 챙길 개수"><button type="button" class="btn small" data-op="none">없음</button><button type="button" class="btn small" data-op="minus" aria-label="하나 덜">−</button><b>${supN(k)}</b><button type="button" class="btn small" data-op="plus" aria-label="하나 더">+</button><button type="button" class="btn small" data-op="all">전부</button></span>
            <small>${esc(SUPPLY_USE[k] || '필요할 때')} 씁니다</small></li>`).join('')}</ul>`
          : `<p class="muted small">가방에 원정용 보급품이 없습니다. 청심환·약초·정화 부적·노정 건량을 챙기면 더 오래 버팁니다.</p>`}
        <ul class="exp-notes">
          <li id="exp-fare-row">${icon('route', 14)}<span id="exp-fare"></span></li>
          ${c.level <= 10 ? `<li>${icon('spark', 14)}<span><b>신입 원정 지원</b>Lv.10까지는 원정 경험치가 30% 더 붙습니다.</span></li>` : ''}
          <li>${icon('bag', 14)}<span><b>원정에서만 얻는 것</b>길잡이 등불·비경 지도·비약·봉인된 보따리·강화 재료·원정 장비. 2시간 넘게 끝까지 다녀오면 그 지역의 비경을 찾기도 합니다.</span></li>
          <li>${icon('check', 14)}<span><b>끝까지 다녀오면</b>2시간 이상은 원정지 수준 장비 하나(2시간 50%, 4시간 이상 반드시), 2시간 이상은 경험치·전·숙련 경험 +20%(4시간 +30%·8시간 +40%). 일찍 귀환하면 받지 못합니다.</span></li>
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
    const short = need > rations();
    $('#exp-hint', box).textContent = short ? `노정 건량이 ${need - rations()}개 모자랍니다. 허기 때문에 정신이 깎이고 수확이 줄어듭니다.` : `가방 ${bagUsed(c)}/${bagLimit(c)}칸 · 전리품이 가방을 넘치면 남는 것은 두고 옵니다.`;
    $('#exp-hint-row', box).classList.toggle('warn', short);
    const fare = fareOf(pick.node), poor = !!pick.node && tokens < fare;
    $('#exp-fare', box).textContent = pick.node ? `운임 노정패 ${fare}개 · 가진 노정패 ${tokens}개${poor ? ' — 모자랍니다' : ''}` : `가진 노정패 ${tokens}개`;
    $('#exp-fare-row', box).classList.toggle('warn', poor);
    $('#exp-go', box).disabled = !pick.node || poor;
  };
  $$('[data-node]', box).forEach(b => b.onclick = () => { pick.node = b.dataset.node; $$('[data-node]', box).forEach(x => x.classList.toggle('on', x === b)); hint(); });
  $$('[data-pick=minutes] button', box).forEach(b => b.onclick = () => { pick.minutes = Number(b.dataset.v); $$('[data-pick=minutes] button', box).forEach(x => x.classList.toggle('on', x === b)); hint(); });
  $$('.sup-step', box).forEach(g => g.onclick = e => {
    const op = e.target.closest('[data-op]')?.dataset.op; if (!op) return;
    const k = g.dataset.sup, max = Number(g.dataset.max), cur = supN(k);
    const v = op === 'none' ? 0 : op === 'all' ? max : Math.max(0, Math.min(max, cur + (op === 'plus' ? 1 : -1)));
    if (v === max) delete supPick[k]; else supPick[k] = v;
    $('b', g).textContent = v; g.closest('li')?.classList.toggle('off', v === 0); hint();
  });
  $$('[data-stance]', box).forEach(b => b.onclick = () => { pick.stance = b.dataset.stance; $$('[data-stance]', box).forEach(x => x.classList.toggle('on', x === b)); const sd = $('.stance-desc', box); if (sd) sd.textContent = (STANCES.find(x => x[0] === pick.stance) || [])[2] || ''; });
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
    <p class="muted small exp-foot">원정 일지에는 걸음마다 마주친 풍경·흔적·기척, 수색 회차, 전투(공격·반격·회복·승패)가 시간에 맞춰 쌓이고 ${PARTY_EXP.who}와는 같은 싸움을 함께 치르고 일지도 함께 보입니다(${PARTY_EXP.apart}). 전투로 바뀐 체력·정신·침식은 곧바로 상태에 반영되고, 전리품은 돌아왔을 때 정리됩니다. 원정 중에는 현장 행동과 그 자리에서 하는 일(퀘스트 보고·상점·창고·물품 사용 등)을 할 수 없습니다. 능력치 분배·칭호·채팅은 됩니다.</p>`;
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

const BATTLE = new Set(['fight', 'atk', 'hurt', 'heal', 'skill', 'guard', 'foe', 'win', 'lose', 'down']);
const openBattles = new Set();
function battleGroups(ls) {
  const out = [], open = new Map();
  ls.forEach((l, i) => {
    const key = l.fk || l.owner, g = open.get(key);
    if (g && BATTLE.has(l.kind)) {
      g.lines.push([l, i]);
      if (['win', 'lose', 'down'].includes(l.kind)) open.delete(key);
      return;
    }
    if (l.kind === 'fight') { const ng = { lines: [[l, i]], key: l.fk || `${l.owner}|${l.at}` }; open.set(key, ng); out.push(ng); return; }
    out.push({ l, i });
  });
  return out;
}
function battleBlock(g, row, me, myName) {
  const f = g.lines[0][0], end = g.lines[g.lines.length - 1][0], done = ['win', 'lose', 'down'].includes(end.kind) ? end.kind : '';
  const cnt = k => g.lines.filter(([l]) => l.kind === k).length;
  const res = done === 'win' ? '<b class="ok">승리</b>' : done === 'lose' ? `<b class="bad">${/함께 물러났/.test(end.text || '') ? '함께 물러남' : '밀려남'}</b>` : done === 'down' ? '<b class="bad">쓰러짐</b>' : '<b class="muted">싸우는 중</b>';
  return `<li class="exp-battle ${done ? 'b-' + done : ''} ${f.owner && f.owner !== me ? 'other' : 'mine'} ${openBattles.has(g.key) ? 'open' : ''}">
    <button type="button" data-k="${esc(g.key)}">${icon('sword', 14)}<span class="eb-head"><b class="who">${esc(f.who || myName || '')}</b>${esc(f.text)}</span>
      <span class="eb-sum">${res} · 공격 ${cnt('atk')} · 반격 ${cnt('hurt')}${cnt('heal') ? ` · 회복 ${cnt('heal')}` : ''}${cnt('skill') ? ` · 기술 ${cnt('skill')}` : ''}${cnt('guard') ? ` · 막기·회피 ${cnt('guard')}` : ''}</span><time>${fmt.time(f.at)}</time></button>
    <ul>${g.lines.slice(1).map(([l, i]) => row(l, i)).join('')}</ul></li>`;
}

let feedT = null, paintT = null;
async function feed(box) {
  const list = $('#exp-feed', box); if (!list?.isConnected) return;
  clearTimeout(feedT); clearTimeout(paintT);
  let p = null;
  try { p = await load('world_expedition_progress'); } catch (e) { list.innerHTML = `<li class="muted">${esc(e.message)}</li>`; }
  if (p?.active) {
    const skew = p.server_now ? Date.now() - new Date(p.server_now).getTime() : 0;
    paintFeed(box, p, skew);
    const c0 = store.character;
    if (c0 && (c0.health !== p.health || c0.mental !== p.mental || c0.erosion !== p.erosion)) loadCharacter().catch(() => {});
    const party = p.party || [];
    $('#exp-party', box).innerHTML = party.length ? `<h3 class="sub-h">원정 중인 동료</h3><ul class="spot-list">${party.map(m => `<li><div><b>${esc(m.name)}</b>
        <small>${esc(m.region || '')} · ${esc(m.place || '')}${m.same_region ? ' · 같은 지역' : ''} · 수색 ${m.rounds_done}/${m.total_rounds}</small></div>${bar(m.rounds_done, m.total_rounds, 'xp')}</li>`).join('')}</ul>` : '';
  }
  const nextRound = p?.active && !p.stopped && p.next_round_at ? new Date(p.next_round_at).getTime() : 0;
  const wait = !p ? 60000 : nextRound ? Math.max(5000, nextRound - Date.now() + 1500) : 0;
  if (wait) feedT = setTimeout(() => { if (!list.isConnected) return; if (!document.hidden) feed(box); else feedT = setTimeout(() => feed(box), 30000); }, Math.min(wait, 600000));
}
function paintFeed(box, p, skew) {
  const list = $('#exp-feed', box); if (!list?.isConnected) return;
  const now = Date.now() - skew;
  const all = p.lines || [], ls = all.filter(l => new Date(l.at).getTime() <= now);
  $('#exp-rounds', box).textContent = `수색 ${p.rounds_done}/${p.total_rounds} · 기록 ${ls.length}줄${p.job_skill ? ` · 기술 ${p.job_skill}` : ''}`;
  const first = !seenLines, atEnd = first || list.scrollHeight - list.scrollTop - list.clientHeight < 40;
  const fresh = seenLines && ls.length > seenLines ? ls.length - seenLines : 0;
  const me = store.character?.owner_id;
  const row = (l, i) => `<li class="k-${esc(l.kind)} ${l.owner && l.owner !== me ? 'other' : 'mine'} ${i >= ls.length - fresh ? 'fresh' : ''}">${icon(KIND_ICON[l.kind] || 'route', 14)}<span><b class="who">${esc(l.who || p.me || '')}</b>${esc(l.text)}</span><time>${fmt.time(l.at)}</time></li>`;
  list.innerHTML = battleGroups(ls).map(g => g.lines ? battleBlock(g, row, me, p.me) : row(g.l, g.i)).join('');
  $$('.exp-battle > button', list).forEach(b => b.onclick = () => { const k = b.dataset.k; openBattles.has(k) ? openBattles.delete(k) : openBattles.add(k); b.parentElement.classList.toggle('open'); });
  seenLines = ls.length || 1;
  if (atEnd) { list.scrollTop = list.scrollHeight; requestAnimationFrame(() => { list.scrollTop = list.scrollHeight; }); }
  const last = ls[ls.length - 1], nextLine = all.find(l => new Date(l.at).getTime() > now);
  const nextAt = nextLine ? new Date(nextLine.at).getTime() : (p.next_round_at ? new Date(p.next_round_at).getTime() : 0);
  const nextIn = nextAt ? Math.max(0, nextAt - now) : 0;
  if (p.stopped) box.dataset.stopped = '1';
  $('#exp-now', box).innerHTML = p.stopped
    ? `${icon('heart', 14)}<span><b>멈춤</b> 더 나아갈 수 없어 원정이 멈췄습니다. 지금 결과를 받고 돌아올 수 있습니다.</span>`
    : `${icon('pin', 14)}<span><b>지금</b> ${esc(last?.who ? last.who + ' · ' : '')}${esc(last?.text || '')}${nextIn ? ` <small class="muted">· 다음 기록 약 ${Math.max(1, Math.round(nextIn / 60000))}분 뒤</small>` : ''}</span>`;
  if (nextLine) paintT = setTimeout(() => paintFeed(box, p, skew), Math.max(500, new Date(nextLine.at).getTime() - now + 300));
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
      ${x.full_gear ? `<p class="hint good">${icon('gear', 14)} 원정 끝에 ${esc(`${nameOf(x.full_gear)}을(를)`)} 챙겼습니다.</p>` : ''}
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
