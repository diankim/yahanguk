import { store, rpc, emit, nameOf, esc, icon, bar, $, $$, fmt, toast, friendlyError, openModal, spOf, JOBS, xpPct, xpGot, xpNote } from '../core.js';
import { chip } from './common.js';
import { USABLE } from './item.js';
import { baseOf, hqOf } from '../hq.js';
import { GAMEDATA } from '../gamedata.js';

export const STYLE = { melee: '근접', ranged: '원거리', magic: '술법' };
export const JOB = Object.fromEntries(Object.entries(JOBS).map(([k, v]) => [k, v.name]));
export const INTENT = {
  strike: ['공격', '평범한 공격입니다.', 0], heavy: ['강타 준비', '큰 피해가 옵니다. 방어하면 4분의 1로 줄이고, 근접 무기면 받아칩니다.', 2],
  soar: ['날아오름', '하늘로 솟구칩니다. 다음 턴에 급강하합니다.', 1], dive: ['급강하', '높은 곳에서 내리꽂습니다. 방어하세요.', 2],
  harden: ['껍질 굳히기', '다음 무기 공격의 방어가 세 배가 됩니다. 술법이나 기술로 노리세요.', 1],
  wail: ['곡성', '정신을 깎고 심신을 흔듭니다.', 1], venom: ['독 분사', '중독될 수 있습니다.', 1],
  swarm: ['무리 부르기', '체력을 조금 회복하고 다음 공격이 강해집니다.', 1], mirror: ['거울막', '다음 술법 피해의 일부를 되돌립니다.', 1],
  tide: ['물살', '한기가 스며들 수 있습니다.', 1], lurk: ['숨어듦', '다음 턴에 크게 덮칩니다. 방어를 준비하세요.', 1],
  pounce: ['덮치기', '두 배 피해. 방어하세요.', 2], barrier: ['결계', '피해를 삼키는 결계를 칩니다.', 1],
  charge: ['기 모으기', '다음 턴에 폭발합니다. 방어하거나 봉인술로 끊으세요.', 1], unleash: ['기 폭발', '매우 큰 피해. 반드시 방어하세요.', 3],
  breach: ['봉인 깨기', '침식이 오릅니다.', 1], rest: ['숨 고르기', '조금 회복합니다. 몰아칠 기회입니다.', 0],
};
export const SKILL = Object.fromEntries(Object.entries(GAMEDATA.jobSkills || {}).map(([k, v]) => [k, [v.name, v.desc]]));
const FX = { airborne: '공중', harden: '껍질', barrier: '결계', mirror: '거울막', marked: '표식', stunned: '봉인됨', swarm: '무리', evade: '허상', thorns: '가시', broken: '방어 무너짐', pierce: '꿰뚫림', dazed: '무방비', weak: '공격 약화' };
const RANK = { elite: ['정예', 'warn'], guardian: ['우두머리', 'bad'] };
const ITEM_IDS = ['tonic', 'herbal_extract', 'herb', 'ward_talisman', 'rejuv_pill', 'grand_pill', 'spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew'];
export function trayList(inv, always = 0) {
  return ITEM_IDS.flatMap((k, i) => { const d = USABLE[k] || ''; return [[k, d, i < always], [hqOf(k), `${d} · 우수품 +15%`, false]]; })
    .filter(([k, , show]) => show || Number(inv[k]) > 0);
}

export function effectiveness(style, eff) {
  const m = eff?.[style]; if (m == null) return null;
  return m >= 1.2 ? ['효과 좋음', 'ok'] : m <= 0.85 ? ['효과 약함', 'bad'] : ['보통', ''];
}

let host = null, data = null, onEnd = null, cdTimer = null, nextAt = 0;

let callOpt = null;
export function renderBattle(box, snap, done, opts) {
  host = box; data = snap; onEnd = done; callOpt = opts?.call ? opts : null;
  nextAt = Number(snap.battle?.turn || 0) === 0 ? 0 : Math.min(new Date(snap.battle?.next_action_at || 0).getTime(), Date.now() + GAP);
  draw();
}
export function stopBattle() { clearInterval(cdTimer); host = null; }
window.addEventListener('yh-battle-item', e => {
  if (!host?.isConnected || !data?.battle) return;
  e.detail.handled = true;
  const id = e.detail.id, base = baseOf(id);
  if (!ITEM_IDS.includes(base)) { toast('싸우는 동안에는 이 물품을 쓸 수 없습니다. 회복약·정화 부적·영력약만 전투의 「물품」으로 씁니다.', 'warn'); return; }
  if (busy || Date.now() < nextAt) { toast('아직 다음 행동을 할 수 없습니다.', 'warn'); return; }
  send('item', id);
});

function draw(fresh = []) {
  if (!host || !data?.battle) return;
  const b = data.battle, c = store.character, w = data.weapon || { type: 'melee', name: '맨손' };
  const ef = effectiveness(w.type, b.eff);
  const intent = b.gimmick ? [b.gimmick.name, b.gimmick.burst ? '모은 기운이 터지려 한다.' : b.gimmick.tell, b.gimmick.burst ? 3 : 2] : (INTENT[b.intent] || INTENT.strike);
  const skill = SKILL[c.job_key] || ['기술', ''];
  const ready = Number(b.pfx?.skill_ready || 0), turnNow = Number(b.turn || 0) + 1;
  const skillWait = Math.max(0, ready - turnNow);
  const medUsed = c.job_key === 'medic' && !!b.pfx?.med_used, skillCost = c.job_key === 'medic' ? 25 : 12;
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
          <div class="vital"><span>${spOf()[0]}</span><b>${c.spiritual_power}</b>${bar(c.spiritual_power, 100, spOf()[1])}</div>
        </div>
        <p class="weapon-line">${icon('sword', 14)} ${esc(w.name)} · ${STYLE[w.type] || '근접'} 공격 ${ef ? chip(ef[0], ef[1]) : ''}${(data.gear_warn || []).filter(g => g.slot === 'weapon' || g.slot === 'armor').map(g => chip(`${g.slot === 'weapon' ? '무기' : '방어구'} ${g.dur > 0 ? '닳음' : '부서짐'}`, 'bad')).join('')}${w.type === 'magic' ? ' <small class="muted">술법은 영력 3을 씁니다</small>' : (w.type || 'melee') === 'melee' ? ' <small class="muted">근접 공격은 기력 2를 씁니다</small>' : ''}</p>
        <div class="float-layer" id="me-float"></div>
      </div>
      ${b.sneak != null ? `<div class="hint accent sneak-ask" id="sneak-ask">${icon('eye', 16)}<span><b>기척을 숨기겠습니까?</b> 성공 ${b.sneak}% · 실패하면 요괴가 먼저 덤벼듭니다. 탐색력은 돌아오지 않습니다.</span>
        <span class="btn-row"><button class="btn small primary" data-sneak>기척 숨기기</button><button class="btn small" data-sneak-no>맞서기</button></span></div>` : ''}
      <div class="actions ${callOpt ? 'has-call' : ''}" id="actions">
        <button class="act primary" data-a="attack">${icon('sword', 20)}<b>${STYLE[w.type] || '근접'} 공격</b><small>${esc(w.name)}</small><i class="cd"></i></button>
        <button class="act" data-a="skill" ${medUsed || skillWait ? 'data-wait="' + (medUsed ? 99 : skillWait) + '"' : ''}>${icon('spark', 20)}<b>${esc(skill[0])}</b><small>${medUsed ? '이번 전투에 씀' : skillWait ? `${skillWait}턴 뒤` : `${spOf()[0]} ${skillCost}`}</small><i class="cd"></i></button>
        <button class="act" data-a="guard">${icon('shield', 20)}<b>방어</b><small>피해 크게 감소 · ${spOf()[0]} +4</small><i class="cd"></i></button>
        <button class="act" data-a="item">${icon('plus', 20)}<b>물품</b><small>회복·정화·영력·기력</small><i class="cd"></i></button>
        <button class="act ghost" data-a="flee">${icon('back', 20)}<b>도주</b><small>민첩이 높을수록</small><i class="cd"></i></button>
        ${callOpt ? `<button class="act call" id="act-call" title="같은 곳의 파티원에게 합류 알림(60초) · 합류한 사람마다 요괴 체력이 늘고, 이기면 경험치를 한 사람마다 10% 더 받습니다">${icon('users', 20)}<b>동료 부르기</b><small>같은 곳 ${callOpt.call}명 · 차례대로 함께</small></button>` : ''}
      </div>
      <div class="item-tray" id="item-tray" hidden>${trayList(inv, 4).map(([k, d]) => `<button class="btn small" data-item="${k}" ${inv[k] > 0 ? '' : 'disabled'}>${esc(nameOf(k))} ×${fmt.num(inv[k])}<small>${d}</small></button>`).join('')}</div>
      <ol class="battle-log">${log.map((l, i) => `<li class="${i >= log.length - fresh.length ? 'new' : ''}">${esc(l)}</li>`).join('')}</ol>
      <p class="muted small">${esc(skill[0])}: ${esc(skill[1])}</p>
    </section>`;
  $('#mech-info', host)?.addEventListener('click', () => openModal({ title: `갈래 · ${b.kind_name}`, body: `<p>${esc(b.kind_desc || '')}</p>
    ${b.eff ? `<p class="small">상성: 근접 ×${b.eff.melee} · 원거리 ×${b.eff.ranged} · 술법 ×${b.eff.magic}${b.eff.job ? ` · ${esc(JOB[b.eff.job] || '')} +20%` : ''}</p>` : '<p class="muted small">이 요괴를 한 번 쓰러뜨리면 일지 › 도감에 상성과 수법 대처법이 적힙니다.</p>'}` }));
  $$('[data-a]', host).forEach(btn => btn.onclick = async () => {
    const a = btn.dataset.a;
    if (a === 'item') { $('#item-tray', host).hidden = !$('#item-tray', host).hidden; return; }
    send(a);
  });
  $$('[data-item]', host).forEach(btn => btn.onclick = () => send('item', btn.dataset.item));
  const cb = $('#act-call', host); if (cb && callOpt?.onCall) cb.onclick = () => callOpt.onCall(cb);
  $('[data-sneak]', host)?.addEventListener('click', () => send('sneak'));
  $('[data-sneak-no]', host)?.addEventListener('click', () => { $('#sneak-ask', host)?.remove(); });
  clearInterval(cdTimer); cdTimer = setInterval(tickCooldown, 50); tickCooldown();
}

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
const WEAK = { ammo: '무기에 맞는 탄(화살·쇠뇌살·취관 침)이 없습니다 · 피해가 절반으로 줄었습니다', sp: '기력이 없습니다 · 피해가 절반으로 줄었습니다', mp: '영력이 없습니다 · 술법 피해가 절반으로 줄었습니다' };
const weakAt = {};
export function weakNote(code) {
  const msg = WEAK[code];
  if (msg && Date.now() - (weakAt[code] || 0) > 5000) { weakAt[code] = Date.now(); toast(msg, 'warn'); }
}
async function send(action, item) {
  if (busy || Date.now() < nextAt) return;
  busy = true; tickCooldown();
  try {
    const r = await rpc('world_battle_action', item ? { p_action: action, p_item: item } : { p_action: action });
    nextAt = Date.now() + GAP;
    const c = store.character;
    if (c) c.health = r.health ?? c.health;
    sfx(r);
    floats(r);
    weakNote(r.weak);
    const foe = data.battle?.name || r.result?.monster || '요괴';
    if (r.ended) {
      data.battle = null;
      refreshCharacter().then(() => emit('changed', { name: 'world_battle_action', data: r }));
      setTimeout(() => { if (action === 'sneak') toast(`기척을 숨겨 ${foe}의 눈을 피했습니다.`, 'ok'); else showEnd(r, foe); onEnd?.(r); }, 650);
    } else {
      if (action === 'flee') setTimeout(() => showFleeFail(r, foe), 400);
      data.battle = r.battle;
      draw(r.lines || []);
      if (r.damage) shake('#foe'); if (r.taken) shake('#me');
      applyMe(r).then(() => { emit('changed', { name: 'world_battle_action', data: r }); if (data.battle && host?.isConnected) refreshVitals(); });
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
    <div class="vital"><span>${spOf()[0]}</span><b>${c.spiritual_power}</b>${bar(c.spiritual_power, 100, spOf()[1])}</div>`;
  const inv = c.inventory || {};
  $$('[data-item]', host).forEach(b => { const k = b.dataset.item, n = Number(inv[k] || 0); b.disabled = n <= 0; const t = b.firstChild; if (t?.nodeType === 3) t.textContent = `${nameOf(k)} ×${fmt.num(n)}`; });
}
async function refreshCharacter() {
  const { loadCharacter } = await import('../core.js');
  await loadCharacter({ hud: true, field: true }).catch(() => {});
}
function applyMe(r) {
  const c = store.character;
  if (!r?.me || !c) return import('../core.js').then(m => m.loadCharacter()).catch(() => {});
  Object.assign(c, r.me); store.charAt = Date.now(); emit('character', c);
  return Promise.resolve();
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
      <p class="lead">${esc(`${x.monster || '요괴'}을(를)`)}${x.rank === 'guardian' ? ' (우두머리)' : x.rank === 'elite' ? ' (정예)' : ''} 쓰러뜨렸습니다.</p>
      <div class="stat-tiles"><div title="${esc(xpNote())}"><span>경험치</span><b>+${fmt.num(xpGot(x.xp))}</b>${xpPct() < 100 ? `<small class="muted">조절 ${xpPct()}%</small>` : ''}</div><div><span>전</span><b>+${fmt.num(x.gil)}</b></div></div>
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
