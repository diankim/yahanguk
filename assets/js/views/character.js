// 캐릭터: 상태(생존·침식·상태이상) · 성장(능력치·생활 전문화·숙련) · 기술 · 자율 활동 · 칭호.
// 이름·직업·소속은 생성 시 고정되며 여기서 바꿀 수 없다.
import { store, on, act, nameOf, JOBS, FACTIONS, esc, icon, bar, guard, $, $$, fmt, empty, segmented, bindSegmented } from '../core.js';
import { load, panel, chip, loading, errorBox, MAJOR_FACTIONS, itemsText } from './common.js';
import { openStatus } from '../hud.js';

const SUBS = [['status', '상태'], ['growth', '성장'], ['faction', '세력'], ['skills', '기술'], ['idle', '자율'], ['titles', '칭호']];
const STATS = [['strength', '근력', '근접 피해·운반'], ['agility', '민첩', '회피·선공'], ['vitality', '체질', '최대 체력·회복'], ['perception', '감각', '치명타·발견'], ['willpower', '의지', '정신 저항'], ['spirit_affinity', '영성', '부적·봉인 위력']];
const GATHER = ['fieldwork', 'mining', 'botany', 'spirit_harvest', 'fishing'];
const CRAFT = ['general', 'smithing', 'carpentry', 'alchemy', 'sealing', 'weaving', 'leatherwork', 'artifice'];
const IDLE = [
  ['training', '자율 수련', '전투 경험치와 능력 단련', 'sword'], ['research', '자료 조사', '조사 경험치와 단서 기록', 'search'],
  ['maintenance', '장비 정비', '제작 경험치와 장비 손질', 'hammer'], ['rest', '휴식', '체력·정신 회복, 침식 완화', 'moon'],
];
const DURATIONS = [[30, '30분'], [60, '1시간'], [240, '4시간'], [480, '8시간']];
const EROSION = ['안정', '경미', '주의', '위험', '붕괴 직전', '붕괴'];
let el, sub = 'status', off = [];

export async function render(root, s) {
  if (!store.character) return;
  el = root; sub = SUBS.some(x => x[0] === s) ? s : 'status';
  const c = store.character;
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('user', 14)} ${esc(JOBS[c.job_key]?.name || nameOf(c.job_key))} · ${esc(FACTIONS[c.faction_key]?.name || nameOf(c.faction_key))}</p><h1>${esc(c.character_name)} <small>Lv.${c.level}</small></h1></div></div>
    ${segmented('char-sub', SUBS, sub)}<div id="char-body"></div>`;
  bindSegmented(el, 'char-sub', k => { sub = k; history.replaceState(null, '', `#/char/${k}`); draw(); });
  off.forEach(f => f()); off = [on('changed', () => draw(true))];
  await draw();
}
export function destroy() { off.forEach(f => f()); off = []; }

async function draw(soft) {
  const body = $('#char-body', el); if (!body) return;
  if (!soft) body.innerHTML = loading();
  try { await ({ status, growth, faction, skills, idle, titles })[sub](body); }
  catch (e) { body.innerHTML = errorBox(e.message); }
}

const USE = [['tonic', '체력 35 · 마음 진정'], ['herbal_extract', '체력 22 · 출혈·화상·근맥 치료'], ['herb', '체력 12 · 중독·소화 불량 치료'],
  ['medicine_base', '정신 12 · 기력 저하·한기·탈진 치료'], ['ward_talisman', '정신 8 · 침식 완화 · 사념·동요·중독 치료'], ['travel_ration', '탐색력 +5']];
async function status(body) {
  const [sv, hud] = await Promise.all([load('world_survival_snapshot'), load('world_hud_snapshot').catch(() => null)]);
  const c = store.character, inv = c.inventory || {};
  const stage = Number(sv?.erosion_stage ?? c.erosion_stage ?? 0);
  const statuses = (hud?.statuses || []).filter(x => new Date(x.expires_at) > new Date());
  const downed = c.downed_at || c.health <= 0;
  const deathAt = c.downed_at ? new Date(c.downed_at).getTime() + 4 * 3600e3 : 0;
  body.innerHTML = `
    ${downed ? panel('전투불능', `
      <p class="desc">쓰러져 움직일 수 없습니다. 같은 지역의 조사원이 구조할 수 있고, 아래 방법으로 스스로 일어날 수도 있습니다.</p>
      <p class="bad"><b id="death-left">${deathAt ? `목숨이 다하기까지 ${fmt.remain(deathAt - Date.now())}` : ''}</b></p>
      <div class="action-grid">
        <button class="btn primary" data-use="revival_charm" ${inv.revival_charm > 0 ? '' : 'disabled'}><span>회생 부적 쓰기 <small>×${fmt.num(inv.revival_charm)}</small></span><small>그 자리에서 체력 50으로 일어납니다</small></button>
        <button class="btn" id="call-rescue"><span>본부 구조대 부르기</span><small>소지금의 30%(최소 50전) · 가장 가까운 안전지대로 옮겨집니다</small></button>
      </div>
      <p class="muted small">시간이 다하면 캐릭터는 목숨을 잃고 그 자리에 시신이 남습니다. 새로 시작하려면 계정 화면 맨 아래에서 캐릭터를 정리할 수 있습니다.</p>`, { ico: 'heart', cls: 'danger' }) : ''}
    <div class="grid-2">
      ${panel('생존 상태', `
        ${['health:체력:hp', 'mental:정신:mp', 'spiritual_power:영력:sp'].map(x => { const [k, l, cls] = x.split(':'); return `<div class="vital big"><span>${l}</span><b>${fmt.num(sv?.[k] ?? c[k])}</b>${bar(sv?.[k] ?? c[k], 100, cls)}</div>`; }).join('')}
        <div class="vital big"><span>침식</span><b>${fmt.num(sv?.erosion ?? c.erosion)} <small>${EROSION[Math.min(stage, 5)]}</small></b>${bar(sv?.erosion ?? c.erosion, 100, 'er')}</div>
        <p class="muted small">침식이 30을 넘으면 공격이 약해지고, 높아질수록 불이익이 커집니다. 정화 부적이나 휴식으로 관리하세요.</p>
        <div class="action-grid three">
          <button class="btn" data-surv="cleanse" ${downed ? 'disabled' : ''}><span>부적 정화</span><small>정화 부적 사용 · 침식 완화</small></button>
          <button class="btn" data-surv="ground" ${downed ? 'disabled' : ''}><span>마음 다잡기</span><small>정신 회복</small></button>
        </div>`, { ico: 'heart' })}
      ${panel(`상태 ${statuses.length}/10`, statuses.length ? `<ul class="status-list">${statuses.map((x, i) => `<li class="${x.polarity === 'positive' ? 'good' : 'bad'}">
          <button class="st-open" data-st="${i}"><b>${esc(x.name)}${x.stacks > 1 ? ` ×${x.stacks}` : ''}</b><small>${esc(x.description || '')}</small></button>
          <span class="muted small" data-left="${new Date(x.expires_at).getTime()}">${fmt.remain(new Date(x.expires_at) - Date.now())}</span></li>`).join('')}</ul>
          <p class="muted small">상태를 누르면 자세한 효과와 치료 방법을 볼 수 있습니다.</p>`
        : empty('걸린 상태가 없습니다.', 'shield'), { ico: 'shield' })}
    </div>
    ${panel('회복·치료 물품', `<div class="action-grid">${USE.map(([k, d]) => `<button class="btn" data-use="${k}" ${inv[k] > 0 && !downed ? '' : 'disabled'}><span>${esc(nameOf(k))} <small>×${fmt.num(inv[k])}</small></span><small>${d}</small></button>`).join('')}</div>
      <p class="muted small">전투불능일 때는 회생 부적만 쓸 수 있습니다.</p>`, { ico: 'plus' })}`;
  $$('[data-surv]', body).forEach(b => b.onclick = () => guard(b, () => act('world_survival_action', { p_action: b.dataset.surv })));
  $$('[data-use]', body).forEach(b => b.onclick = () => guard(b, () => act('world_use_item', { p_item_id: b.dataset.use })));
  $$('[data-st]', body).forEach(b => b.onclick = () => openStatus(statuses[Number(b.dataset.st)]));
  const cr = $('#call-rescue', body);
  if (cr) cr.onclick = () => { if (confirm('본부 구조대를 부를까요? 소지금의 30%(최소 50전)를 내고 가장 가까운 안전지대로 옮겨집니다.')) guard(cr, () => act('world_call_rescue')); };
  const t = setInterval(() => {
    if (!body.isConnected) return clearInterval(t);
    $$('[data-left]', body).forEach(x => x.textContent = fmt.remain(Number(x.dataset.left) - Date.now()));
    const d = $('#death-left', body); if (d && deathAt) d.textContent = `목숨이 다하기까지 ${fmt.remain(deathAt - Date.now())}`;
  }, 1000);
}

async function growth(body) {
  const inv = await load('world_inventory_snapshot', undefined, { maxAge: 5000 });
  const c = store.character, pts = Number(c.stat_points || 0);
  const ranks = [['전투', c.combat_rank, c.combat_xp], ['조사', c.investigation_rank, c.investigation_xp], ['채집', c.gathering_rank, c.gathering_xp], ['제작', c.crafting_rank, c.crafting_xp]];
  body.innerHTML = `
    <div class="grid-2">
      ${panel('능력치', `<p class="muted small">레벨이 오르면 능력치 포인트를 얻습니다. 남은 포인트: <b class="accent">${pts}</b></p>
        <ul class="stat-list">${STATS.map(([k, n, d]) => `<li><div><b>${n}</b><small>${d}</small></div><span class="stat-val">${fmt.num(c[k])}</span>
          <button class="icon-btn" data-stat="${k}" ${pts > 0 ? '' : 'disabled'} aria-label="${n} 올리기">${icon('plus', 16)}</button></li>`).join('')}</ul>`, { ico: 'spark' })}
      ${panel('기능 숙련', `<ul class="rank-list">${ranks.map(([n, r, xp]) => `<li><span>${n}</span><b>${fmt.num(r || 1)}단계</b><small>${fmt.num(xp)} 경험</small></li>`).join('')}</ul>
        <p class="muted small">숙련은 해당 행동을 할 때만 오릅니다. 관계없는 능력은 함께 오르지 않습니다.</p>`, { ico: 'target' })}
    </div>
    ${panel('생활 전문화', `<p class="desc">채집과 제작에서 집중할 분야입니다. 맞는 채집터에서는 채집량이 1 늘고, 맞는 제작법은 품질이 오릅니다.</p>
      <p class="${profWait(c) > 0 ? 'hint' : 'muted small'}">${profWait(c) > 0 ? `${icon('hourglass', 14)} 다음 변경까지 ${fmt.remain(profWait(c))}` : '한 번 바꾸면 3일 동안 다시 바꿀 수 없습니다.'}</p>
      <div class="form-grid">
        <label class="field"><span>채집 분야</span><select id="g-prof">${GATHER.map(k => `<option value="${k}" ${inv?.gathering_profession === k ? 'selected' : ''}>${esc(nameOf(k))}</option>`).join('')}</select></label>
        <label class="field"><span>제작 분야</span><select id="c-prof">${CRAFT.map(k => `<option value="${k}" ${inv?.crafting_profession === k ? 'selected' : ''}>${esc(nameOf(k))}</option>`).join('')}</select></label>
      </div><button class="btn" id="prof-save" ${profWait(c) > 0 ? 'disabled' : ''}>${icon('check', 16)}<span>전문화 정하기</span></button>`, { ico: 'leaf' })}
    ${panel('신원', `<dl class="kv"><div><dt>이름</dt><dd>${esc(c.character_name)}</dd></div><div><dt>직업</dt><dd>${esc(nameOf(c.job_key))} · ${esc(JOBS[c.job_key]?.trait || '')}</dd></div>
      <div><dt>소속</dt><dd>${esc(nameOf(c.faction_key))}</dd></div><div><dt>대세력</dt><dd>${c.major_faction_id ? `${esc(nameOf(c.major_faction_id))} · 평판 ${fmt.num(c.faction_reputation)}` : '미가입'}</dd></div></dl>
      <p class="muted small">이름·직업·소속은 캐릭터 생성 시 정해지며 바꿀 수 없습니다.</p>`, { ico: 'idcard' })}`;
  $$('[data-stat]', body).forEach(b => b.onclick = () => guard(b, () => act('world_allocate_stat', { p_stat: b.dataset.stat })));
  const save = $('#prof-save', body);
  save.onclick = () => { if (confirm('전문화를 이대로 정할까요? 3일 동안 다시 바꿀 수 없습니다.')) guard(save, () => act('world_set_life_profession_v2', { p_gathering: $('#g-prof', body).value, p_crafting: $('#c-prof', body).value })); };
}
function profWait(c) { return c.life_changed_at ? new Date(c.life_changed_at).getTime() + 72 * 3600e3 - Date.now() : 0; }

async function skills(body) {
  const list = await load('world_skill_snapshot', undefined, { maxAge: 10000 });
  const groups = {};
  (list || []).forEach(s => (groups[s.category] ||= []).push(s));
  const cats = Object.keys(groups);
  body.innerHTML = cats.length ? `<div class="skill-groups">${cats.map(cat => panel(nameOf(cat), `<ul class="skill-list">${groups[cat].map(s => `<li class="${s.unlocked ? 'on' : ''}">
      <div><b>${esc(s.skill_name)}</b><small>${esc(s.description || '')}</small></div>
      <span class="chip ${s.unlocked ? 'ok' : ''}">${s.unlocked ? '습득' : `${s.unlock_rank}단계 필요`}</span>
      <div class="skill-xp"><span>${fmt.num(s.rank)}단계 · ${fmt.num(s.xp)} 경험</span></div></li>`).join('')}</ul>`, { cls: 'compact' })).join('')}</div>`
    : empty('익힌 기술 정보가 없습니다.');
}

async function idle(body) {
  const snap = await load('world_idle_activity_snapshot');
  const active = snap?.active;
  const ready = active && (snap.ready || new Date(snap.ready_at) <= new Date());
  const name = IDLE.find(x => x[0] === snap?.activity_type)?.[1] || '자율 활동';
  body.innerHTML = `
    ${active ? panel('진행 중인 자율 활동', `
      <div class="idle-now"><div class="idle-ring ${ready ? 'done' : ''}">${icon(ready ? 'check' : 'hourglass', 24)}</div>
        <div><b>${esc(name)} · ${snap.duration_minutes}분</b><span id="idle-left">${ready ? '완료되었습니다. 보상을 받으세요.' : `${fmt.remain(new Date(snap.ready_at) - Date.now())} 남음`}</span>
        ${bar(Math.min(snap.elapsed_seconds || 0, snap.duration_minutes * 60), snap.duration_minutes * 60, 'xp')}</div></div>
      <button class="btn ${ready ? 'primary' : ''}" id="idle-claim" ${ready ? '' : 'disabled'}>${icon('check', 16)}<span>보상 수령</span></button>
      <p class="muted small">완료 시각은 서버가 기록합니다. 접속하지 않아도 진행되며, 한 번에 하나만 할 수 있습니다.</p>`, { ico: 'hourglass' }) : ''}
    <div class="idle-grid">${IDLE.map(([k, n, d, ic]) => `<article class="idle-card">
      <header>${icon(ic, 18)}<b>${n}</b></header><p>${d}</p>
      <div class="dur">${DURATIONS.map(([m, l]) => `<button class="btn small" data-idle="${k}" data-min="${m}" ${active ? 'disabled' : ''}>${l}</button>`).join('')}</div></article>`).join('')}</div>
    <p class="muted small">자율 활동은 접속하지 않는 동안의 보조 성장입니다. 직접 탐사·전투·제작이 더 큰 보상을 줍니다.</p>`;
  const claim = $('#idle-claim', body);
  if (claim) claim.onclick = () => guard(claim, async () => { const r = await act('world_claim_idle_activity'); return { content: `${r?.message || '보상을 받았습니다.'}${r?.experience ? ` · 경험치 +${r.experience}` : ''}` }; });
  $$('[data-idle]', body).forEach(b => b.onclick = () => guard(b, () => act('world_start_idle_activity', { p_activity: b.dataset.idle, p_duration_minutes: Number(b.dataset.min) })));
  if (active && !ready) {
    const t = setInterval(() => {
      const left = $('#idle-left', body); if (!left) return clearInterval(t);
      const ms = new Date(snap.ready_at) - Date.now();
      if (ms <= 0) { clearInterval(t); draw(true); } else left.textContent = `${fmt.remain(ms)} 남음`;
    }, 1000);
  }
}

async function titles(body) {
  const snap = await load('world_title_snapshot');
  const list = snap?.titles || [];
  const bonus = b => Object.entries(b || {}).map(([k, v]) => `${({ craft_quality: '제작 품질', clue_bonus_pct: '단서 발견', gather_qty_pct: '채집량', combat_damage_pct: '전투 피해', travel_speed_pct: '이동 속도', rest_bonus_pct: '휴식 효율' })[k] || nameOf(k)} +${v}${/pct/.test(k) ? '%' : ''}`).join(' · ');
  body.innerHTML = panel(`칭호 · 최대 ${snap?.max_equipped || 1}개 장착`, list.length ? `<ul class="title-list">${list.map(t => `<li class="${t.earned ? 'earned' : ''} ${t.equipped ? 'on' : ''}">
      <div><b>${esc(t.name)}</b><small>${esc(t.description || '')}</small><small class="muted">조건: ${esc(t.condition || '-')}</small>${t.bonus ? `<small class="accent">${esc(bonus(t.bonus))}</small>` : ''}</div>
      ${t.equipped ? chip('장착 중', 'accent') : t.earned ? `<button class="btn small" data-title="${esc(t.key)}">장착</button>` : chip('미획득')}</li>`).join('')}</ul>` : empty('칭호가 없습니다.'), { ico: 'spark' });
  $$('[data-title]', body).forEach(b => b.onclick = () => guard(b, () => act('world_title_equip', { p_title_key: b.dataset.title })));
}

/* ── 세력: 소속 임무·일일 보급·대세력 ─────────────────────── */
async function faction(body) {
  const [missions, base] = await Promise.all([load('world_faction_mission_snapshot'), load('world_faction_base_snapshot').catch(() => null)]);
  const c = store.character;
  const mine = (missions || []).filter(m => m.faction_key === c.faction_key || m.eligible);
  const major = c.major_faction_id;
  body.innerHTML = `
    <div class="grid-2">
      ${panel(`${nameOf(c.faction_key)} 임무`, mine.length ? `<ul class="mission-list">${mine.map(m => {
        const done = m.progress >= m.target_count;
        return `<li><div><b>${esc(m.title)}</b><small>${esc(m.description || '')}</small>
          <div class="mini-bar"><span style="width:${Math.min(100, m.progress / m.target_count * 100)}%"></span></div>
          <small class="muted">${Math.min(m.progress, m.target_count)}/${m.target_count} · 보상 경험치 ${m.reward_xp}${m.reward_items ? ' · ' + esc(itemsText(m.reward_items)) : ''}</small></div>
          ${m.claimed ? chip('완료', 'ok') : `<button class="btn small ${done ? 'primary' : ''}" data-mission="${esc(m.mission_id)}" ${done ? '' : 'disabled'}>${done ? '보상 받기' : '진행 중'}</button>`}</li>`; }).join('')}</ul>` : empty('진행할 수 있는 임무가 없습니다.'), { ico: 'scroll' })}
      ${panel('일일 보급', store.hud?.supply?.claimed_today
          ? `<p class="desc">${icon('check', 14)} 오늘 보급은 이미 받았습니다.</p><p class="muted small">다음 보급: ${store.hud.supply.next_at ? new Date(store.hud.supply.next_at).toLocaleString('ko-KR', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '내일'}</p><button class="btn" disabled>${icon('check', 16)}<span>수령 완료</span></button>`
          : `<p class="desc">소속 부서에서 하루 한 번 보급품을 받을 수 있습니다.</p><button class="btn primary" id="supply">${icon('bag', 16)}<span>오늘 보급 받기</span></button>`, { ico: 'bag' })}
    </div>
    ${major ? panel(`${nameOf(major)} 거점`, `
        <p class="desc">${esc(MAJOR_FACTIONS[major]?.desc || '')}</p><p class="accent small">${esc(PERKS[major] || '')}</p>
        <div class="chips">${chip(`평판 ${fmt.num(c.faction_reputation)}`, 'accent')}${chip(`거점: ${base?.base_region_name || nameOf(base?.base_region_id)}`)}${base?.at_base ? chip('거점에 있음', 'ok') : chip('거점 밖')}</div>
        ${(base?.contents || []).length ? `<ul class="mission-list">${base.contents.map(x => `<li><div><b>${esc(x.title)}</b><small>${esc(x.description || '')}</small><small class="muted">Lv.${x.min_level}+${x.reward ? ' · ' + esc(itemsText(x.reward.items || x.reward)) : ''}</small></div>
          ${x.used_today ? chip('오늘 완료') : `<button class="btn small" data-base="${esc(x.content_id)}" ${base.at_base && c.level >= x.min_level ? '' : 'disabled'}>수행</button>`}</li>`).join('')}</ul>
          ${base.at_base ? '' : `<p class="hint">${icon('pin', 14)} 거점 콘텐츠는 ${esc(base.base_region_name || '거점')}에 있을 때 이용할 수 있습니다.</p>`}` : empty('이용할 수 있는 거점 콘텐츠가 없습니다.')}`, { ico: 'shield' })
      : panel('대세력', `<p class="desc">대세력은 세계의 큰 흐름을 이끄는 조직입니다. 가입하면 전용 거점·임무·보상과 세력 채팅을 이용할 수 있습니다. 적대 세력 지역에서는 견제를 받을 수 있습니다.</p>
        <div class="faction-grid">${Object.entries(MAJOR_FACTIONS).map(([k, f]) => `<article class="faction">
          <header><b>${esc(f.name)}</b>${chip(f.type)}</header><p>${esc(f.desc)}</p><small class="accent">${esc(PERKS[k] || '')}</small><small class="muted">가입 조건: ${esc(f.entry)} · 거점 ${esc(nameOf(f.base))}</small>
          <button class="btn small" data-join="${k}">가입 신청</button></article>`).join('')}</div>`, { ico: 'shield' })}`;
  $$('[data-mission]', body).forEach(b => b.onclick = () => guard(b, () => act('world_faction_mission_action', { p_mission_id: b.dataset.mission })));
  const sup = $('#supply', body); if (sup) sup.onclick = () => guard(sup, async () => { const r = await act('world_claim_faction_supply'); if (store.hud) store.hud.supply = { claimed_today: true }; return r; });
  $$('[data-base]', body).forEach(b => b.onclick = () => guard(b, () => act('world_faction_base_action', { p_content_id: b.dataset.base })));
  $$('[data-join]', body).forEach(b => b.onclick = () => { if (confirm(`${MAJOR_FACTIONS[b.dataset.join].name}에 가입할까요? 가입 조건은 서버에서 확인합니다.`)) guard(b, () => act('world_join_major_faction', { p_faction_id: b.dataset.join })); });
}

const PERKS = {
  night_office: '원정·임무 보급이 안정적입니다(보급 보너스).', red_moon_cult: '강행 태세 원정의 전리품 +15%. 위험한 지역에 강합니다.',
  black_lotus: '정보·암시장에 밝습니다.', north_league: '원정 중 받는 피해 -20%.', river_alliance: '가방 +20칸. 교역과 운송에 강합니다.',
  southern_remnant: '원정 채집량 +15%.', mandate_court: '원정 답사도 상승 +20%.',
};
