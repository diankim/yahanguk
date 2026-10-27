// 실시간 상태 HUD: PC는 좌측 고정 패널, 모바일은 상단 접이식 띠.
// 이동·자율 활동·전투·원정·전투불능처럼 "지금 진행 중인 일"을 한눈에 보여 준다.
import { gmBadge, ask, store, on, emit, rpc, act, loadCharacter, nameOf, fmt, esc, icon, bar, $, $$, h, guard, toast, emblem, bagLimit, bagUsed, openModal, closeModal, effectText as fxText, xpNeed, LEVEL_CAP, midBattle } from './core.js';
import { envChip } from './env.js';

const IDLE_LABEL = { training: '자율 수련', research: '자료 조사', maintenance: '장비 정비', rest: '휴식' };
let root, tick, poll, refreshTimer, state = { idle: null, hud: null, exp: null };

export function mountHud(el) {
  root = el;
  root.innerHTML = `<button class="hud-strip" id="hud-strip" aria-expanded="false"></button><div class="hud-body" id="hud-body"></div>`;
  $('#hud-strip', root).onclick = () => {
    const open = root.classList.toggle('open');
    $('#hud-strip', root).setAttribute('aria-expanded', open);
  };
  on('character', render);
  on('env', render);
  // 행동 직후에는 캐릭터를 이미 다시 읽었으니(act) 상태판 요약만 읽는다. 전투 턴 중에는 그리기만 한다. 자율 활동 상태는 자율 행동 뒤에만.
  on('changed', ev => {
    if (midBattle(ev)) return render();
    const idle = /idle/.test(ev.name || '');
    clearTimeout(refreshTimer); refreshTimer = setTimeout(() => refresh({ char: false, idle }), 350);
  });
  refresh();
  clearInterval(tick); tick = setInterval(onTick, 1000);
  clearInterval(poll); poll = setInterval(() => { if (!document.hidden) refresh(); }, 60000);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });
}

export async function refresh({ char = true, idle: readIdle = true } = {}) {
  try {
    // 원정 중이면 지난 수색 회차를 먼저 정산해 체력·정신·침식이 바로 맞게 한다
    if (store.expedition) await rpc('world_expedition_tick').catch(() => null);
    const first = !state.hud; // 처음에는 게임 화면을 열면서 방금 캐릭터를 읽었으므로 다시 읽지 않는다
    const [idle, hud] = await Promise.all([
      readIdle || first ? rpc('world_idle_activity_snapshot').catch(() => null) : state.idle,
      rpc('world_hud_snapshot').catch(() => null),
      (first || !char) && store.character ? null : loadCharacter(),
    ]);
    const was = !!store.expedition;
    state = { idle, hud, exp: hud?.expedition || null };
    store.expedition = state.exp;
    store.hud = hud;
    render();
    // 원정을 보내거나 돌아오면 현장 화면이 곧바로 행동을 막거나 풀도록 알린다(새로고침 없이).
    if (!first && was !== !!state.exp) emit('expedition', state.exp); // 첫 읽기는 화면이 이미 그 상태로 그린다
  } catch (e) { console.warn('HUD 갱신 실패', e); }
}

function effectText(effects, potency = 1) { return fxText(effects, potency); }
export function openStatus(st) {
  const good = st.polarity === 'positive';
  const left = new Date(st.expires_at).getTime() - Date.now();
  const inv = store.character?.inventory || {};
  const m = openModal({ title: `${good ? '이로운 효과' : '상태이상'} · ${st.name}`, body: `
    <div class="status-detail ${good ? 'good' : 'bad'}">
      <p>${esc(st.description || '')}</p>
      <ul class="fx-list">${effectText(st.effects, st.potency).map(t => `<li>${esc(t)}</li>`).join('')}</ul>
      <p class="muted small">남은 시간 <b data-left="${new Date(st.expires_at).getTime()}">${fmt.remain(left)}</b>${st.stacks > 1 ? ` · ${st.stacks}겹` : ''}</p>
      ${good ? '' : `<h3 class="sub-h">치료 방법</h3><p>${esc(st.cure || '시간이 지나면 사라집니다.')}</p>
        ${(st.cure_items || []).length ? `<div class="btn-row">${st.cure_items.map(k => `<button class="btn small primary" data-cure="${esc(k)}" ${inv[k] > 0 ? '' : 'disabled'}>${esc(nameOf(k))} 쓰기 <small>×${fmt.num(inv[k])}</small></button>`).join('')}</div>` : ''}`}
    </div>` });
  const t = setInterval(() => { const b = m.querySelector('[data-left]'); if (!b) return clearInterval(t); b.textContent = fmt.remain(Number(b.dataset.left) - Date.now()); }, 1000);
  $$('[data-cure]', m).forEach(b => b.onclick = () => guard(b, async () => { const r = await act('world_use_item', { p_item_id: b.dataset.cure }); closeModal(); return r; }));
}

function idleReadyAt(idle) {
  if (!idle?.active) return null;
  if (idle.ready_at) return new Date(idle.ready_at).getTime();
  if (idle.started_at && idle.duration_minutes) return new Date(idle.started_at).getTime() + idle.duration_minutes * 60000;
  return null;
}

function statusItems(c) {
  const items = [];
  if (c.is_dead) items.push({ kind: 'danger', icon: 'flame', title: '영구 사망', text: c.death_reason || '이 캐릭터는 더 이상 행동할 수 없습니다.' });
  else if (c.downed_at || c.health <= 0) items.push({ kind: 'danger', icon: 'heart', title: '전투불능', timer: new Date(c.downed_at || Date.now()).getTime() + 4 * 3600e3, text: '구조를 기다리거나 회생 부적·구조대를 쓰세요.', action: ['대처하기', () => window.yahangGo('char', 'status')] });
  if (c.travel_arrives_at) {
    const left = new Date(c.travel_arrives_at).getTime() - Date.now();
    items.push({ kind: 'travel', icon: 'route', title: `이동 중 → ${nameOf(c.travel_destination) || '목적지'}`, timer: c.travel_arrives_at, text: left > 0 ? `${fmt.remain(left)} 후 도착` : '도착 처리 중…', action: left > 0 ? ['이동 취소', cancelTravel] : null });
  }
  const e = state.hud?.battle;
  if (e) items.push({ kind: 'combat', icon: 'sword', title: `전투 중 · ${e.name}`, text: `적 체력 ${e.hp}/${e.max_hp}`, meter: [e.hp, e.max_hp], action: ['전투로', () => window.yahangGo('home')] });
  const ready = idleReadyAt(state.idle);
  if (ready) {
    const left = ready - Date.now();
    items.push({ kind: 'idle', icon: 'hourglass', title: IDLE_LABEL[state.idle.activity_type] || '자율 활동', timer: ready, text: left > 0 ? `${fmt.remain(left)} 남음` : '완료 · 보상 수령 가능', action: left > 0 ? null : ['보상 수령', claimIdle], ready: left <= 0 });
  }
  if (state.exp) {
    const left = new Date(state.exp.ends_at).getTime() - Date.now();
    items.push({ kind: 'exp', icon: 'flame', title: `원정 · ${state.exp.place_name || ''}`, timer: state.exp.ends_at, text: left > 0 ? `${fmt.remain(left)} 남음` : '귀환 · 결과 확인 가능', action: ['원정 보기', openExpeditionView], ready: left <= 0,
      // 현장 화면을 보고 있지 않을 때만 현장으로 가는 단추를 함께 둔다
      action2: onField() ? null : ['현장 보기', () => window.yahangGo('home')] });
  }
  if (!items.length) items.push({ kind: 'calm', icon: 'moon', title: '대기 중', text: '지도에서 이동하거나 현재 지역을 탐사하세요.' });
  return items;
}

// 원정 창(팝업)을 그 자리에서 연다. 모바일 상태 띠는 접는다.
function openExpeditionView() { closeStrip(); window.dispatchEvent(new CustomEvent('yh-open-expedition')); }
function closeStrip() { root?.classList.remove('open'); $('#hud-strip', root)?.setAttribute('aria-expanded', 'false'); }
const onField = () => !location.hash || location.hash === '#' || /^#\/(home)?(\/|$)/.test(location.hash);
// 화면을 옮기면 「현장 보기」 단추가 생기거나 사라지도록 다시 그린다
window.addEventListener('hashchange', () => render());
function render() {
  const c = store.character; if (!root || !c) return;
  const items = statusItems(c);
  const need = xpNeed(c.level);
  const first = items[0];
  $('#hud-strip', root).innerHTML = `
    <span class="hs-name"><b>${esc(c.character_name)}${gmBadge(c.owner_id)}</b><small>Lv.${c.level}</small></span>
    <span class="hs-bars"><i style="--v:${c.health}%" class="hp"></i><i style="--v:${c.mental}%" class="mp"></i><i style="--v:${c.spiritual_power}%" class="sp"></i></span>
    ${(state.hud?.statuses || []).length ? `<span class="hs-debuff">${icon('flame', 12)}${(state.hud.statuses || []).filter(x => x.polarity !== 'positive').length}</span>` : ''}
    ${store.env ? `<span class="hs-env">${esc(store.env.phase?.name || '')}·${esc(store.env.weather?.name || '')}</span>` : ''}
    <span class="hs-status st-${first.kind}">${icon(first.icon, 14)}<em data-timer="${first.timer ? new Date(first.timer).getTime() : ''}">${esc(first.title)}</em></span>
    <span class="hs-caret">${icon('chevron', 14)}</span>`;
  const body = $('#hud-body', root);
  body.innerHTML = `
    <section class="hud-card">
      <div class="hud-id">${emblem(c.owner_id, c.profile, 44)}
        <div><h2>${esc(c.character_name)}${gmBadge(c.owner_id)}</h2><p>${esc(nameOf(c.job_key))} · ${esc(nameOf(c.faction_key))}</p></div>
        <span class="lv">Lv.${c.level}</span></div>
      ${c.profile?.title_name ? `<p class="title-badge">「${esc(c.profile.title_name)}」</p>` : ''}
      ${envChip()}
      <div class="xp"><span>경험치</span><span>${(c.level || 1) >= LEVEL_CAP ? '최고 레벨' : `${fmt.num(c.experience)} / ${fmt.num(need)}`}</span></div>${bar((c.level || 1) >= LEVEL_CAP ? 1 : c.experience, (c.level || 1) >= LEVEL_CAP ? 1 : need, 'xp')}
    </section>
    <section class="hud-card vitals">
      ${vital('체력', c.health, 'hp')}${vital('정신', c.mental, 'mp')}${vital('영력', c.spiritual_power, 'sp')}${vital('침식', c.erosion || 0, 'er')}
      ${stamina(c)}
    </section>
    ${statusCard()}
    <section class="hud-card money">
      <div>${icon('coin', 16)}<span>소지금</span><b>${fmt.jeon(c.gil)}</b></div>
      <div>${icon('token', 16)}<span>노정패</span><b>${fmt.num(c.mount_tokens)}개</b></div>
      <div>${icon('bag', 16)}<span>가방</span><b>${bagUsed(c)} / ${bagLimit(c)}칸</b></div>
      <div>${icon('pin', 16)}<span>위치</span><b>${esc(c.location)}</b></div>
    </section>
    <section class="hud-card now"><h3>진행 중</h3>
      ${items.map((it, i) => `<div class="now-item st-${it.kind}">
        <div class="now-ico">${icon(it.icon, 18)}</div>
        <div class="now-text"><b>${esc(it.title)}</b><span data-timer="${it.timer ? new Date(it.timer).getTime() : ''}" data-kind="${it.kind}">${esc(it.text)}</span>
          ${it.meter ? bar(it.meter[0], it.meter[1], 'enemy') : ''}</div>
        ${it.action || it.action2 ? `<div class="now-acts">${it.action ? `<button class="btn small ${it.ready ? 'primary' : 'ghost'}" data-act="${i}">${esc(it.action[0])}</button>` : ''}${it.action2 ? `<button class="btn small ghost" data-act2="${i}">${esc(it.action2[0])}</button>` : ''}</div>` : ''}
      </div>`).join('')}
    </section>`;
  body.querySelectorAll('[data-act]').forEach(b => b.onclick = () => items[Number(b.dataset.act)].action[1](b));
  body.querySelectorAll('[data-act2]').forEach(b => b.onclick = () => { closeStrip(); items[Number(b.dataset.act2)].action2[1](b); });
  const sts = (state.hud?.statuses || []).filter(s => new Date(s.expires_at) > new Date());
  body.querySelectorAll('[data-st]').forEach(b => b.onclick = () => openStatus(sts[Number(b.dataset.st)]));
}
function stamina(c) {
  const st = state.hud?.stamina; if (!st) return '';
  return `<div class="vital st"><span>탐색력</span><b>${st.now}/${st.max}</b>${bar(st.now, st.max, 'st')}<small class="muted" data-timer="${st.next_at ? new Date(st.next_at).getTime() : ''}" data-kind="stamina">${st.now >= st.max ? '가득' : ''}</small></div>`;
}
function statusCard() {
  const list = (state.hud?.statuses || []).filter(s => new Date(s.expires_at) > new Date());
  return `<section class="hud-card statuses"><h3>상태 ${list.length}/10</h3>${list.length ? `<div class="st-chips">${list.map((s, i) => `<button class="st-chip ${s.polarity === 'positive' ? 'good' : 'bad'}" data-st="${i}">
      <b>${esc(s.name)}${s.stacks > 1 ? `×${s.stacks}` : ''}</b><i data-timer="${new Date(s.expires_at).getTime()}" data-kind="status">${fmt.remain(new Date(s.expires_at) - Date.now())}</i></button>`).join('')}</div>`
    : '<p class="muted small">걸린 상태가 없습니다.</p>'}</section>`;
}
function vital(label, v, kind) {
  return `<div class="vital"><span>${label}</span><b>${Math.round(v || 0)}</b>${bar(v, 100, kind)}</div>`;
}

let arriving = false, lastArriveTry = 0; // 도착 확인은 5초에 한 번까지만
function onTick() {
  if (!root) return;
  const now = Date.now();
  root.querySelectorAll('[data-timer]').forEach(el => {
    const t = Number(el.dataset.timer); if (!t) return;
    const left = t - now, kind = el.dataset.kind;
    if (el.tagName === 'EM') return;
    if (kind === 'travel') el.textContent = left > 0 ? `${fmt.remain(left)} 후 도착` : '도착 처리 중…';
    if (kind === 'idle') el.textContent = left > 0 ? `${fmt.remain(left)} 남음` : '완료 · 보상 수령 가능';
    if (kind === 'exp') el.textContent = left > 0 ? `${fmt.remain(left)} 남음` : '귀환 · 결과 확인 가능';
    if (kind === 'danger') el.textContent = left > 0 ? `목숨이 다하기까지 ${fmt.remain(left)}` : '시간이 다했습니다';
    if (kind === 'status') { el.textContent = left > 0 ? fmt.remain(left) : '끝'; if (left <= 0 && !root.dataset.stDirty) { root.dataset.stDirty = '1'; setTimeout(() => { delete root.dataset.stDirty; refresh(); }, 1500); } }
    if (kind === 'stamina') { el.textContent = left > 0 ? `${fmt.remain(left)} 뒤 +1` : ''; if (left <= 0 && !root.dataset.stamDirty) { root.dataset.stamDirty = '1'; setTimeout(() => { delete root.dataset.stamDirty; refresh(); }, 1500); } }
  });
  const c = store.character;
  if (c?.travel_arrives_at && new Date(c.travel_arrives_at).getTime() <= now && !arriving && now - lastArriveTry > 5000) {
    arriving = true; lastArriveTry = now;
    let where = null;
    rpc('world_travel_status').then(s => { if (!s?.in_transit) where = s.location; return refresh(); })
      .catch(() => {}).finally(() => { arriving = false; if (where) window.dispatchEvent(new CustomEvent('yahang:arrived', { detail: { location: where } })); });
  }
  const ready = idleReadyAt(state.idle);
  if (ready && ready <= now && !root.dataset.idleReady) { root.dataset.idleReady = '1'; render(); }
  // 원정 귀환 시각이 되면 화면 위에 알리고(원정마다 한 번), 현장에 완료를 표시한다.
  const expEnd = state.exp?.ends_at ? new Date(state.exp.ends_at).getTime() : 0;
  if (expEnd && expEnd <= now && root.dataset.expDone !== String(expEnd)) {
    root.dataset.expDone = String(expEnd);
    render(); emit('expedition', state.exp);
    const seen = `yh-exp-done-${c?.owner_id}-${expEnd}`;
    let shown = false; try { shown = !!localStorage.getItem(seen); localStorage.setItem(seen, '1'); } catch {}
    if (!shown) window.dispatchEvent(new CustomEvent('yh-local-note', { detail: { id: `exp-${expEnd}`, kind: 'expedition_done', title: '원정 귀환',
      content: `${state.exp.place_name || '원정지'}에서 돌아왔습니다. 결과를 받아 보세요.` } }));
  }
  if (!ready) delete root.dataset.idleReady;
}

async function cancelTravel(btn) {
  if (!(await ask('이동을 취소할까요? 위약금 5전이 소모됩니다.', { title: '이동 취소', ok: '취소하기', cancel: '계속 가기', danger: true }))) return;
  await guard(btn, () => act('world_travel_cancel'));
}
async function claimIdle(btn) {
  await guard(btn, async () => {
    const r = await act('world_claim_idle_activity');
    return { content: `${r.message || '보상 수령'} · 경험치 +${r.experience || 0}` };
  });
}
