// 전투 화면: 요괴가 다음 행동을 미리 드러내고, 조사원은 장착 무기에 따라 정해진 방식으로 싸운다.
// 공격·직업 기술·방어·물품·도주 중 하나를 고르면 서버가 한 턴을 계산해 돌려준다. 행동 사이에는 1초 간격이 있다.
import { store, act, rpc, nameOf, esc, icon, bar, $, $$, fmt, toast, friendlyError, openModal, closeModal, ask } from '../core.js';
import { chip } from './common.js';

export const STYLE = { melee: '근접', ranged: '원거리', magic: '술법' };
// 서버 world_battle_action과 같은 배율
const WEAK = {
  aerial: { melee: 0.6, ranged: 1.35, magic: 1 }, armored: { melee: 0.85, ranged: 0.7, magic: 1.25 },
  spectral: { melee: 0.6, ranged: 0.8, magic: 1.4 }, warded: { melee: 1.1, ranged: 1, magic: 0.8 },
  reflect: { melee: 1, ranged: 1.15, magic: 0.7 }, swarm: { melee: 1.25, ranged: 0.9, magic: 1.1 },
  toxic: { melee: 0.9, ranged: 1.15, magic: 1 }, tide: { melee: 1, ranged: 0.9, magic: 1.15 },
  seal_breaker: { melee: 1.1, ranged: 1, magic: 0.85 },
};
export const MECH = {
  aerial: ['비행', '날아올랐다가 내리꽂힙니다. 원거리가 잘 맞고, 공중에 있을 때 근접은 거의 닿지 않습니다.'],
  armored: ['갑각', '단단한 껍질이 있습니다. 술법이 잘 통하고, 껍질을 굳히면 무기 공격이 막힙니다.'],
  spectral: ['영체', '형체가 흐릿합니다. 술법에 약하고 근접은 잘 통하지 않습니다. 곡성으로 정신을 깎습니다.'],
  warded: ['결계', '결계를 둘러 피해를 삼킵니다. 술법은 결계를 두 배로 깎습니다.'],
  reflect: ['반사', '거울막으로 술법을 되돌립니다. 거울막이 있을 때 술법을 피하세요.'],
  swarm: ['무리', '무리를 불러 회복하고 다음 공격이 강해집니다. 근접 공격이 잘 통합니다.'],
  toxic: ['독성', '독을 뿜어 중독시킵니다. 거리를 두는 원거리가 유리합니다.'],
  tide: ['수계', '물살로 몸을 식혀 한기를 남깁니다. 술법이 조금 더 잘 통합니다.'],
  ambush: ['매복', '숨었다가 크게 덮칩니다. 숨어들면 방어를 준비하세요.'],
  boss: ['우두머리', '기를 모았다가 폭발시킵니다. 기를 모으면 방어하거나 봉인술로 끊으세요.'],
  seal_breaker: ['봉인 파괴', '봉인을 깨뜨려 침식을 일으킵니다. 근접 공격이 조금 더 잘 통합니다.'],
};
export const INTENT = {
  strike: ['공격', '평범한 공격입니다.', 0], heavy: ['강타 준비', '큰 피해가 옵니다. 방어하면 4분의 1로 줄이고, 근접 무기면 받아칩니다.', 2],
  soar: ['날아오름', '하늘로 솟구칩니다. 다음 턴에 급강하합니다.', 1], dive: ['급강하', '높은 곳에서 내리꽂습니다. 방어하세요.', 2],
  harden: ['껍질 굳히기', '다음 무기 공격의 방어가 세 배가 됩니다. 술법이나 기술로 노리세요.', 1],
  wail: ['곡성', '정신을 깎고 심신을 흔듭니다.', 1], venom: ['독 분사', '중독될 수 있습니다.', 1],
  swarm: ['무리 부르기', '체력을 조금 회복하고 다음 공격이 강해집니다.', 1], mirror: ['거울막', '다음 술법의 절반을 되돌립니다.', 1],
  tide: ['물살', '한기가 스며들 수 있습니다.', 1], lurk: ['숨어듦', '다음 턴에 크게 덮칩니다. 방어를 준비하세요.', 1],
  pounce: ['덮치기', '두 배 피해. 방어하세요.', 2], barrier: ['결계', '피해를 삼키는 결계를 칩니다.', 1],
  charge: ['기 모으기', '다음 턴에 폭발합니다. 방어하거나 봉인술로 끊으세요.', 1], unleash: ['기 폭발', '매우 큰 피해. 반드시 방어하세요.', 3],
  breach: ['봉인 깨기', '침식이 오릅니다.', 1], rest: ['숨 고르기', '조금 회복합니다. 몰아칠 기회입니다.', 0],
};
export const SKILL = {
  exorcist: ['퇴마진', '술법으로 두 배 피해를 주고 결계를 깨뜨립니다.'],
  sealmaster: ['봉인술', '피해를 주고 요괴의 다음 행동을 묶습니다. 우두머리는 절반 확률.'],
  scout: ['급소 사격', '원거리로 반드시 치명타를 내고 두 턴 동안 표식을 남깁니다.'],
  medic: ['응급 처방', '체력을 크게 회복하고 나쁜 상태 하나를 걷어냅니다.'],
  analyst: ['약점 간파', '다음 세 번의 공격이 40% 강해지고 치명타가 잘 납니다.'],
  artificer: ['폭렬 부적', '방어·껍질·결계를 무시하고 1.7배 피해를 줍니다.'],
};
const FX = { airborne: '공중', harden: '껍질', barrier: '결계', mirror: '거울막', marked: '표식', stunned: '봉인됨', swarm: '무리' };
const RANK = { elite: ['정예', 'warn'], guardian: ['우두머리', 'bad'] };
const ITEMS = [['tonic', '체력 35'], ['herbal_extract', '체력 22'], ['herb', '체력 12'], ['ward_talisman', '정신 8 · 정화']];

export function effectiveness(style, mech) {
  const m = WEAK[mech]?.[style] ?? 1;
  return m >= 1.2 ? ['효과 좋음', 'ok'] : m <= 0.85 ? ['효과 약함', 'bad'] : ['보통', ''];
}

let host = null, data = null, onEnd = null, cdTimer = null, nextAt = 0;

// box: 그릴 곳, snap: world_field_snapshot, done: 전투가 끝나면 부를 함수
export function renderBattle(box, snap, done) {
  host = box; data = snap; onEnd = done;
  nextAt = new Date(snap.battle?.next_action_at || 0).getTime();
  draw();
}
export function stopBattle() { clearInterval(cdTimer); host = null; }

function draw(fresh = []) {
  if (!host || !data?.battle) return;
  const b = data.battle, c = store.character, w = data.weapon || { type: 'melee', name: '맨손' };
  const [eff, effK] = effectiveness(w.type, b.mechanic);
  const intent = INTENT[b.intent] || INTENT.strike, mech = MECH[b.mechanic];
  const skill = SKILL[c.job_key] || ['기술', ''];
  const ready = Number(b.pfx?.skill_ready || 0), turnNow = Number(b.turn || 0) + 1;
  const skillWait = Math.max(0, ready - turnNow);
  const inv = c.inventory || {};
  const log = (b.log || []).slice(-8);
  host.innerHTML = `
    <section class="battle">
      <div class="foe ${b.rank !== 'normal' ? 'rank-' + esc(b.rank) : ''}" id="foe">
        <div class="foe-top">
          <div><p class="eyebrow">${esc(b.type || '요괴')} · Lv.${b.level}</p><h2>${esc(b.name)} ${RANK[b.rank] ? chip(RANK[b.rank][0], RANK[b.rank][1]) : ''}</h2></div>
          <span class="foe-hp">${fmt.num(b.hp)} / ${fmt.num(b.max_hp)}</span>
        </div>
        ${bar(b.hp, b.max_hp, 'enemy big')}
        <div class="chips">${mech ? `<button class="chip mech" id="mech-info">${esc(mech[0])} ${icon('help', 12)}</button>` : ''}${Object.entries(b.fx || {}).filter(([, v]) => v).map(([k]) => chip(FX[k] || k, 'warn')).join('')}</div>
        <div class="intent lvl-${intent[2]}">${icon(intent[2] >= 2 ? 'flame' : 'eye', 18)}<div><b>다음 행동 · ${esc(intent[0])}</b><span>${esc(intent[1])}</span></div></div>
        <div class="float-layer" id="foe-float"></div>
      </div>
      <div class="me" id="me">
        <div class="me-bars">
          <div class="vital"><span>체력</span><b>${c.health}</b>${bar(c.health, 100, 'hp')}</div>
          <div class="vital"><span>정신</span><b>${c.mental}</b>${bar(c.mental, 100, 'mp')}</div>
          <div class="vital"><span>영력</span><b>${c.spiritual_power}</b>${bar(c.spiritual_power, 100, 'sp')}</div>
        </div>
        <p class="weapon-line">${icon('sword', 14)} ${esc(w.name)} · ${STYLE[w.type] || '근접'} 공격 ${chip(eff, effK)}${w.type === 'magic' ? ' <small class="muted">술법은 영력 3을 씁니다</small>' : ''}</p>
        <div class="float-layer" id="me-float"></div>
      </div>
      <div class="actions" id="actions">
        <button class="act primary" data-a="attack">${icon('sword', 20)}<b>${STYLE[w.type] || '근접'} 공격</b><small>${esc(w.name)}</small><i class="cd"></i></button>
        <button class="act" data-a="skill" ${skillWait ? 'data-wait="' + skillWait + '"' : ''}>${icon('spark', 20)}<b>${esc(skill[0])}</b><small>${skillWait ? `${skillWait}턴 뒤` : '영력 12'}</small><i class="cd"></i></button>
        <button class="act" data-a="guard">${icon('shield', 20)}<b>방어</b><small>피해 크게 감소 · 영력 +4</small><i class="cd"></i></button>
        <button class="act" data-a="item">${icon('plus', 20)}<b>물품</b><small>회복·정화</small><i class="cd"></i></button>
        <button class="act ghost" data-a="flee">${icon('back', 20)}<b>도주</b><small>민첩이 높을수록</small><i class="cd"></i></button>
      </div>
      <div class="item-tray" id="item-tray" hidden>${ITEMS.map(([k, d]) => `<button class="btn small" data-item="${k}" ${inv[k] > 0 ? '' : 'disabled'}>${esc(nameOf(k))} ×${fmt.num(inv[k])}<small>${d}</small></button>`).join('')}</div>
      <ol class="battle-log">${log.map((l, i) => `<li class="${i >= log.length - fresh.length ? 'new' : ''}">${esc(l)}</li>`).join('')}</ol>
      <p class="muted small">${esc(skill[0])}: ${esc(skill[1])}</p>
    </section>`;
  $('#mech-info', host)?.addEventListener('click', () => openModal({ title: `습성 · ${mech[0]}`, body: `<p>${esc(mech[1])}</p><p class="muted small">지금 무기(${STYLE[w.type] || '근접'})의 상성: ${eff}</p>` }));
  $$('[data-a]', host).forEach(btn => btn.onclick = async () => {
    const a = btn.dataset.a;
    if (a === 'item') { $('#item-tray', host).hidden = !$('#item-tray', host).hidden; return; }
    if (a === 'flee' && !(await ask(`${data.battle?.name || '요괴'}에게서 도망칠까요? 실패하면 요괴의 공격을 받습니다.`, { title: '도주', ok: '도망치기', cancel: '계속 싸우기' }))) return;
    send(a);
  });
  $$('[data-item]', host).forEach(btn => btn.onclick = () => send('item', btn.dataset.item));
  clearInterval(cdTimer); cdTimer = setInterval(tickCooldown, 100); tickCooldown();
}

// 행동 간격(1초, 서버 world_battle_action과 같은 값)을 버튼 위에 옅게 보여 준다.
const GAP = 1000;
function tickCooldown() {
  if (!host?.isConnected) return clearInterval(cdTimer);
  const left = nextAt - Date.now();
  $$('.act', host).forEach(btn => {
    const cd = $('.cd', btn), wait = Number(btn.dataset.wait || 0);
    const blocked = left > 0 || busy || wait > 0;
    btn.disabled = blocked;
    btn.classList.toggle('cooling', left > 0 && !busy && !(wait > 0));
    if (cd) { cd.textContent = left > 0 ? (left / 1000).toFixed(1) : ''; cd.style.setProperty('--p', left > 0 ? Math.min(1, left / GAP) : 0); }
  });
}

let busy = false;
async function send(action, item) {
  if (busy || Date.now() < nextAt) return;
  busy = true; tickCooldown();
  try {
    const r = await act('world_battle_action', item ? { p_action: action, p_item: item } : { p_action: action });
    nextAt = new Date(r.next_action_at || Date.now() + GAP).getTime();
    const c = store.character;
    if (c) c.health = r.health ?? c.health;
    sfx(r);
    floats(r);
    const foe = data.battle?.name || r.result?.monster || '요괴';
    if (r.ended) {
      data.battle = null;
      setTimeout(() => { showEnd(r, foe); onEnd?.(r); }, 650);
    } else {
      if (action === 'flee') setTimeout(() => showFleeFail(r, foe), 400);
      data.battle = r.battle;
      // 체력·영력·물품은 서버 값을 다시 받아 그린다
      await refreshCharacter();
      draw(r.lines || []);
      if (r.damage) shake('#foe'); if (r.taken) shake('#me');
    }
  } catch (e) {
    toast(friendlyError(e), 'error');
    if (/전투가 없습니다/.test(String(e.message))) onEnd?.(null);
  } finally { busy = false; tickCooldown(); }
}
async function refreshCharacter() {
  const { loadCharacter } = await import('../core.js');
  await loadCharacter().catch(() => {});
}

function floats(r) {
  const put = (id, text, cls) => { const layer = $(id, host); if (!layer) return; const s = document.createElement('span'); s.className = `float ${cls}`; s.textContent = text; layer.append(s); setTimeout(() => s.remove(), 1100); };
  if (r.damage) put('#foe-float', `-${r.damage}`, r.crit ? 'crit' : 'dmg');
  if (r.taken) put('#me-float', `-${r.taken}`, 'hurt');
  if (r.heal) put('#me-float', `+${r.heal}`, 'heal');
}
function shake(sel) { const n = $(sel, host); if (!n) return; n.classList.remove('shake'); void n.offsetWidth; n.classList.add('shake'); }
function sfx(r) {
  const k = r.ended === 'victory' ? 'victory' : r.ended === 'defeat' ? 'defeat' : r.crit ? 'crit' : r.damage ? 'hit' : r.heal ? 'heal' : r.taken ? 'hurt' : 'guard';
  window.dispatchEvent(new CustomEvent('yh-sfx', { detail: k }));
}

// 도주 결과: 성공·실패 모두 게임 안 팝업으로 한눈에
function fleeCard(ok, r, foe) {
  const c = store.character || {};
  const hp = Math.max(0, Math.round(r.health ?? c.health ?? 0));
  const lines = (r.lines || []).slice(-3);
  openModal({ title: ok ? '도주 성공' : '도주 실패', body: `<div class="end-card ${ok ? 'fled' : 'lose'}">
    <p class="lead">${ok ? esc(`${foe}에게서 무사히 달아났습니다.`) : esc(`${foe}에게서 달아나지 못했습니다.`)}</p>
    <div class="stat-tiles"><div><span>받은 피해</span><b>${r.taken ? `-${fmt.num(r.taken)}` : '없음'}</b></div><div><span>남은 체력</span><b>${hp} / 100</b></div></div>
    ${bar(hp, 100, 'hp')}
    ${lines.length ? `<ul class="end-lines">${lines.map(l => `<li>${esc(l)}</li>`).join('')}</ul>` : ''}
    <p class="muted small">${ok ? '전리품은 없습니다. 이 지역에서 계속 탐색할 수 있습니다.' : '요괴가 다음 행동을 이어 갑니다. 다시 도망치거나 맞서 싸우세요.'}</p>
    <button class="btn primary block" data-close>${ok ? '계속 탐색' : '전투로 돌아가기'}</button></div>` });
}
function showFleeFail(r, foe) { fleeCard(false, r, foe); }

function showEnd(r, foe) {
  const x = r.result || {};
  if (r.ended === 'victory') {
    const loot = Object.entries(x.loot || {});
    openModal({ title: '토벌 성공', body: `<div class="end-card win">
      <p class="lead">${esc(`${x.monster}을(를)`)}${x.rank === 'guardian' ? ' (우두머리)' : x.rank === 'elite' ? ' (정예)' : ''} 쓰러뜨렸습니다.</p>
      <div class="stat-tiles"><div><span>경험치</span><b>+${fmt.num(x.xp)}</b></div><div><span>전</span><b>+${fmt.num(x.gil)}</b></div></div>
      <h3 class="sub-h">전리품</h3><ul class="loot">${loot.map(([k, n]) => `<li>${esc(nameOf(k))} <b>×${n}</b></li>`).join('') || '<li>없음</li>'}</ul>
      <p class="muted small">가방이 가득 차면 넘치는 전리품은 두고 옵니다.</p>
      <button class="btn primary block" data-close>계속 탐색</button></div>` });
  } else if (r.ended === 'defeat') {
    openModal({ title: '쓰러졌습니다', body: `<div class="end-card lose"><p class="lead">${esc(x.monster)}에게 쓰러졌습니다.</p>
      <p>전투불능 상태입니다. 같은 지역의 조사원이 구조하거나, 회생 부적을 쓰거나, 본부 구조대를 부를 수 있습니다. 4시간 안에 일어나지 못하면 목숨을 잃습니다.</p>
      <button class="btn primary block" data-close>확인</button></div>` });
  } else if (r.ended === 'fled') {
    fleeCard(true, r, x.monster || foe || '요괴');
  }
}
