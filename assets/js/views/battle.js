// 전투 화면: 요괴가 다음 행동을 미리 드러내고, 조사원은 장착 무기에 따라 정해진 방식으로 싸운다.
// 공격·직업 기술·방어·물품·도주 중 하나를 고르면 서버가 한 턴을 계산해 돌려준다. 행동 사이에는 1초 간격이 있다.
import { store, act, rpc, emit, nameOf, esc, icon, bar, $, $$, fmt, toast, friendlyError, openModal, closeModal } from '../core.js';
import { chip } from './common.js';

export const STYLE = { melee: '근접', ranged: '원거리', magic: '술법' };
export const JOB = { exorcist: '퇴마관', sealmaster: '봉인술사', scout: '현장 조사원', analyst: '기록 분석관', medic: '의무관', artificer: '법구 제작사' };
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
const FX = { airborne: '공중', harden: '껍질', barrier: '결계', mirror: '거울막', marked: '표식', stunned: '봉인됨', swarm: '무리', evade: '허상', thorns: '가시' };
const RANK = { elite: ['정예', 'warn'], guardian: ['우두머리', 'bad'] };
const ITEMS = [['tonic', '체력 35'], ['herbal_extract', '체력 22'], ['herb', '체력 12'], ['ward_talisman', '정신 8 · 정화'], ['rejuv_pill', '체력 60'], ['grand_pill', '체력 100'],
  ['spirit_tea', '영력 10'], ['clear_spirit_pill', '영력 20'], ['spirit_qi_pill', '영력 35'], ['moonlight_essence', '영력 55'], ['heavenly_dew', '영력 80']];

// 상성(갈래별 무기 배율 · 유리한 직업 +20%)은 그 요괴를 한 번 쓰러뜨려 도감에 적은 뒤에만 서버가 내보낸다(b.eff)
export function effectiveness(style, eff) {
  const m = eff?.[style]; if (m == null) return null;
  return m >= 1.2 ? ['효과 좋음', 'ok'] : m <= 0.85 ? ['효과 약함', 'bad'] : ['보통', ''];
}

let host = null, data = null, onEnd = null, cdTimer = null, nextAt = 0;

// box: 그릴 곳, snap: world_field_snapshot, done: 전투가 끝나면 부를 함수
export function renderBattle(box, snap, done) {
  host = box; data = snap; onEnd = done;
  // 서버 시각을 그대로 쓰면 기기 시계가 늦을 때 대기가 길어지므로, 남은 시간은 최대 1초로 자른다
  // 첫 수(아직 한 번도 행동하지 않은 전투)는 기다리지 않는다(서버도 전투를 열 때 바로 행동할 수 있게 둔다)
  nextAt = Number(snap.battle?.turn || 0) === 0 ? 0 : Math.min(new Date(snap.battle?.next_action_at || 0).getTime(), Date.now() + GAP);
  draw();
}
export function stopBattle() { clearInterval(cdTimer); host = null; }

function draw(fresh = []) {
  if (!host || !data?.battle) return;
  const b = data.battle, c = store.character, w = data.weapon || { type: 'melee', name: '맨손' };
  const ef = effectiveness(w.type, b.eff);
  // 기믹(g:키 · 터뜨리는 턴 g!:키)은 이름과 낌새만 보인다. 대처법은 도감에서 쓰러뜨린 뒤에 열린다.
  const intent = b.gimmick ? [b.gimmick.name, b.gimmick.burst ? '모은 기운이 터지려 한다.' : b.gimmick.tell, b.gimmick.burst ? 3 : 2] : (INTENT[b.intent] || INTENT.strike);
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
        <div class="chips">${b.kind_name ? `<button class="chip mech" id="mech-info">${esc(b.kind_name)} ${icon('help', 12)}</button>` : ''}${Object.entries(b.fx || {}).filter(([, v]) => v).map(([k]) => chip(FX[k] || k, 'warn')).join('')}${b.pfx?.bound ? chip('붙잡힘', 'bad') : ''}</div>
        <div class="intent lvl-${intent[2]}">${icon(intent[2] >= 2 ? 'flame' : 'eye', 18)}<div><b>다음 행동 · ${esc(intent[0])}</b><span>${esc(intent[1])}</span></div></div>
        <div class="float-layer" id="foe-float"></div>
      </div>
      <div class="me" id="me">
        <div class="me-bars">
          <div class="vital"><span>체력</span><b>${c.health}</b>${bar(c.health, 100, 'hp')}</div>
          <div class="vital"><span>정신</span><b>${c.mental}</b>${bar(c.mental, 100, 'mp')}</div>
          <div class="vital"><span>영력</span><b>${c.spiritual_power}</b>${bar(c.spiritual_power, 100, 'sp')}</div>
        </div>
        <p class="weapon-line">${icon('sword', 14)} ${esc(w.name)} · ${STYLE[w.type] || '근접'} 공격 ${ef ? chip(ef[0], ef[1]) : ''}${(data.gear_warn || []).filter(g => g.slot === 'weapon' || g.slot === 'armor').map(g => chip(`${g.slot === 'weapon' ? '무기' : '방어구'} ${g.dur > 0 ? '닳음' : '부서짐'}`, 'bad')).join('')}${w.type === 'magic' ? ' <small class="muted">술법은 영력 3을 씁니다</small>' : ''}</p>
        <div class="float-layer" id="me-float"></div>
      </div>
      <div class="actions" id="actions">
        <button class="act primary" data-a="attack">${icon('sword', 20)}<b>${STYLE[w.type] || '근접'} 공격</b><small>${esc(w.name)}</small><i class="cd"></i></button>
        <button class="act" data-a="skill" ${skillWait ? 'data-wait="' + skillWait + '"' : ''}>${icon('spark', 20)}<b>${esc(skill[0])}</b><small>${skillWait ? `${skillWait}턴 뒤` : '영력 12'}</small><i class="cd"></i></button>
        <button class="act" data-a="guard">${icon('shield', 20)}<b>방어</b><small>피해 크게 감소 · 영력 +4</small><i class="cd"></i></button>
        <button class="act" data-a="item">${icon('plus', 20)}<b>물품</b><small>회복·정화·영력</small><i class="cd"></i></button>
        <button class="act ghost" data-a="flee">${icon('back', 20)}<b>도주</b><small>민첩이 높을수록</small><i class="cd"></i></button>
      </div>
      <div class="item-tray" id="item-tray" hidden>${ITEMS.filter(([k], i) => i < 4 || inv[k] > 0).map(([k, d]) => `<button class="btn small" data-item="${k}" ${inv[k] > 0 ? '' : 'disabled'}>${esc(nameOf(k))} ×${fmt.num(inv[k])}<small>${d}</small></button>`).join('')}</div>
      <ol class="battle-log">${log.map((l, i) => `<li class="${i >= log.length - fresh.length ? 'new' : ''}">${esc(l)}</li>`).join('')}</ol>
      <p class="muted small">${esc(skill[0])}: ${esc(skill[1])}</p>
    </section>`;
  $('#mech-info', host)?.addEventListener('click', () => openModal({ title: `갈래 · ${b.kind_name}`, body: `<p>${esc(b.kind_desc || '')}</p>
    ${b.eff ? `<p class="small">상성: 근접 ×${b.eff.melee} · 원거리 ×${b.eff.ranged} · 술법 ×${b.eff.magic}${b.eff.job ? ` · ${esc(JOB[b.eff.job] || '')} +20%` : ''}</p>` : '<p class="muted small">이 요괴를 한 번 쓰러뜨리면 일지 › 도감에 상성과 기믹 파훼법이 적힙니다.</p>'}` }));
  $$('[data-a]', host).forEach(btn => btn.onclick = async () => {
    const a = btn.dataset.a;
    if (a === 'item') { $('#item-tray', host).hidden = !$('#item-tray', host).hidden; return; }
    send(a);
  });
  $$('[data-item]', host).forEach(btn => btn.onclick = () => send('item', btn.dataset.item));
  clearInterval(cdTimer); cdTimer = setInterval(tickCooldown, 50); tickCooldown();
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
    // 공용 act는 캐릭터를 다시 읽을 때까지 기다리므로, 전투는 응답을 바로 쓰고 캐릭터·알림은 뒤에서 맞춘다
    const r = await rpc('world_battle_action', item ? { p_action: action, p_item: item } : { p_action: action });
    // 응답을 받은 때부터 이 기기 시계로 1초(서버 검사는 서버 시각으로 1초라 요청 왕복만큼 늘 여유가 있다)
    nextAt = Date.now() + GAP;
    const c = store.character;
    if (c) c.health = r.health ?? c.health;
    sfx(r);
    floats(r);
    const foe = data.battle?.name || r.result?.monster || '요괴';
    if (r.ended) {
      data.battle = null;
      refreshCharacter().then(() => emit('changed', { name: 'world_battle_action', data: r }));
      setTimeout(() => { showEnd(r, foe); onEnd?.(r); }, 650);
    } else {
      if (action === 'flee') setTimeout(() => showFleeFail(r, foe), 400);
      data.battle = r.battle;
      draw(r.lines || []);
      if (r.damage) shake('#foe'); if (r.taken) shake('#me');
      // 체력·정신·영력·물품은 단추를 잠그지 않고 뒤에서 다시 받아 생존 막대와 물품 칸만 고친다
      refreshCharacter().then(() => { emit('changed', { name: 'world_battle_action', data: r }); if (data.battle && host?.isConnected) refreshVitals(); });
    }
  } catch (e) {
    toast(friendlyError(e), 'error');
    if (/전투가 없습니다/.test(String(e.message))) onEnd?.(null);
  } finally { busy = false; tickCooldown(); }
}
function refreshVitals() {
  const c = store.character, box = $('.me-bars', host); if (!c || !box) return;
  box.innerHTML = `<div class="vital"><span>체력</span><b>${c.health}</b>${bar(c.health, 100, 'hp')}</div>
    <div class="vital"><span>정신</span><b>${c.mental}</b>${bar(c.mental, 100, 'mp')}</div>
    <div class="vital"><span>영력</span><b>${c.spiritual_power}</b>${bar(c.spiritual_power, 100, 'sp')}</div>`;
  const inv = c.inventory || {};
  $$('[data-item]', host).forEach(b => { const k = b.dataset.item, n = Number(inv[k] || 0); b.disabled = n <= 0; const t = b.firstChild; if (t?.nodeType === 3) t.textContent = `${nameOf(k)} ×${fmt.num(n)}`; });
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
