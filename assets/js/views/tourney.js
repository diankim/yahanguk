// 야행 비무회(7.1, #/tourney): 비무 방(신청·작전·이번 주 대회·지난 결과)과 대진표·경기 다시 보기.
// 판정은 서버(world_tourney_*, 1분마다 예약 작업)가 하고, 경기 기록은 합마다 2초씩 서버 시각에 맞춰 펼친다.
// 다시 읽는 때: 화면을 열 때 · 신청·작전 뒤 · 대회가 진행 중이면 다음 회차 시각에 한 번(실시간 구독 없음).
import { rpc, store, esc, icon, fmt, $, $$, toast, nameOf, guard, ask, openModal } from '../core.js';
import { loading, errorBox, chip, panel } from './common.js';

const MODE = { solo: '1:1', team: '팀전(2:2)' };
const STATUS = { signup: '신청 받는 중', locked: '대진 확정 · 곧 시작', running: '진행 중', done: '끝남', cancelled: '열리지 않음' };
const STANCE = [['attack', '공격', '주는 피해 +15% · 받는 피해 +10%'], ['balanced', '균형', '보정 없음'], ['defense', '수비', '주는 피해 −15% · 받는 피해 −20% · 회피 +5']];
const SKILL_AT = [['open', '처음에'], ['mid', '몰릴 때(기세 60% 아래)'], ['finish', '마무리(상대 35% 아래)']];
const HEALS = ['tonic', 'herbal_extract', 'herb', 'rejuv_pill', 'grand_pill', 'banyo_salve'];
const GAP = 2000; // 합마다 2초

let el = null, board = null, view = null, timer = null, tick = null, skew = 0, sub = '', busy = false;

export async function render(root, s) {
  el = root; sub = s || ''; view = null;
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('sword', 14)} 야행 비무회</p><h1>비무 방</h1></div></div>${loading()}`;
  clearInterval(tick); tick = setInterval(liveTick, 500);
  await refresh();
}
export function destroy() { clearTimeout(timer); clearInterval(tick); el = null; }

const now = () => Date.now() + skew;
async function refresh() {
  if (!el || busy) return;
  busy = true;
  clearTimeout(timer);
  try {
    if (sub) { view = await rpc('world_tourney_view', { p_t: sub }); if (view?.now) skew = new Date(view.now) - Date.now(); }
    else { board = await rpc('world_tourney_board'); if (board?.now) skew = new Date(board.now) - Date.now(); }
    draw(); plan();
  } catch (e) { if (el) el.innerHTML = errorBox(e.message); }
  finally { busy = false; }
}
// 진행 중인 대회는 다음 회차 시각에 맞춰 한 번 더 읽는다
function plan() {
  const t = sub ? view : null;
  if (!t || document.hidden) return;
  const at = t.status === 'running' ? new Date(t.round_at || 0).getTime() : t.status === 'locked' ? new Date(t.starts_at).getTime() : 0;
  if (at && at > now()) timer = setTimeout(refresh, Math.min(10 * 60e3, at - now() + 61e3));
}

function draw() { if (!el) return; sub ? drawView() : drawBoard(); }

function drawBoard() {
  const b = board || {}, c = store.character || {};
  const cur = b.current || [];
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('sword', 14)} 야행 비무회</p><h1>비무 방</h1></div></div>
    <div class="notice">${icon('help', 18)}<div><b>한 주의 흐름</b><span>월요일 0시부터 금요일 23시 59분까지 안전지대의 비무 방에서 신청합니다. 토요일 21시 1:1, 일요일 21시 팀전(같은 파티 2명)이 개최지에서 열립니다. 시작 10분 전에 개최지에 없으면 불참입니다. 목숨·체력·물품·전·경험치는 그대로이고, 능력치·장비 차이는 절반만 반영됩니다.</span></div></div>
    <div class="grid-2">${cur.map(t => tCard(t, b, c)).join('') || panel('이번 주 대회', '<p class="muted">대회를 준비하는 중입니다.</p>')}</div>
    ${panel('지난 대회', (b.past || []).length ? `<ul class="tn-past">${b.past.map(p => `<li><button class="linkish" data-view="${esc(p.t_id)}"><b>${esc(MODE[p.mode])}</b> · ${fmt.date ? fmt.date(p.starts_at) : new Date(p.starts_at).toLocaleDateString('ko-KR')} · ${esc(p.venue_name || '')}</button>
        <small>${p.status === 'done' ? `장원 ${esc(p.result?.champion_names || '')}${p.result?.runner_up ? ` · 준우승 ${esc(p.result.runner_up)}` : ''}` : '열리지 않음'}</small></li>`).join('')}</ul>` : '<p class="muted small">지난 일주일 사이 열린 대회가 없습니다.</p>', { ico: 'scroll' })}`;
  bindBoard();
}

function tCard(t, b, c) {
  const mine = t.mine, open = t.status === 'signup' && now() < new Date(t.signup_ends);
  const tac = mine?.tactic || { stance: 'balanced', items: [], skill: 'mid' };
  const canTac = mine && ['signup', 'locked'].includes(t.status) && now() < new Date(t.starts_at);
  const inv = c.inventory || {};
  return panel(`${MODE[t.mode]} · ${STATUS[t.status] || t.status}`, `
    <dl class="kv"><div><dt>열리는 때</dt><dd>${new Date(t.starts_at).toLocaleString('ko-KR', { weekday: 'short', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })}</dd></div>
      <div><dt>개최지</dt><dd>${esc(t.venue_name || '')}</dd></div><div><dt>신청</dt><dd>${fmt.num(t.count)}${t.mode === 'solo' ? '명' : '팀'}${open ? ` · ${new Date(t.signup_ends).toLocaleString('ko-KR', { weekday: 'short', hour: '2-digit', minute: '2-digit' })} 마감` : ''}</dd></div></dl>
    ${(t.entries || []).length ? `<p class="small muted">${t.entries.map(esc).join(' · ')}</p>` : ''}
    ${mine ? `<p class="hint good">${icon('check', 14)} ${esc((mine.names || []).join('·'))}${mine.status === 'absent' ? ' · 불참 처리됨' : ' · 신청함'}</p>` : ''}
    ${canTac ? `<details class="tn-tac" open><summary>${icon('target', 14)} 작전</summary>
      <div class="tn-row"><span>태세</span>${STANCE.map(([k, n, d]) => `<label class="chk" title="${esc(d)}"><input type="radio" name="st-${t.mode}" value="${k}" ${tac.stance === k ? 'checked' : ''}><span>${n}</span></label>`).join('')}</div>
      <div class="tn-row"><span>직업 기술</span>${SKILL_AT.map(([k, n]) => `<label class="chk"><input type="radio" name="sk-${t.mode}" value="${k}" ${tac.skill === k ? 'checked' : ''}><span>${n}</span></label>`).join('')}</div>
      <div class="tn-row"><span>회복품 둘</span>${HEALS.map(k => `<label class="chk"><input type="checkbox" name="it-${t.mode}" value="${k}" ${(tac.items || []).includes(k) ? 'checked' : ''}><span>${esc(nameOf(k))}${inv[k] ? '' : ' <small class="muted">(없음)</small>'}</span></label>`).join('')}</div>
      <p class="muted small">회복품은 기세가 40% 아래로 떨어지면 하나씩 씁니다(가방에서 줄지 않음). 정하지 않으면 균형·몰릴 때·회복품 없음.</p>
      <button class="btn small primary" data-tac="${t.mode}">작전 정하기</button></details>` : ''}
    <div class="btn-row">
      ${open && !mine ? (b.here_safe ? (t.mode === 'solo' ? `<button class="btn primary" data-sign="solo">신청하기</button>`
          : (b.party || []).length ? `<select id="tn-partner" aria-label="함께 나갈 파티원">${b.party.map(p => `<option value="${esc(p.id)}">${esc(p.name)}</option>`).join('')}</select><button class="btn primary" data-sign="team">함께 신청하기</button>`
          : '<span class="hint">팀전은 파티원 한 명과 함께 나갑니다.</span>') : '<span class="hint">안전지대에서 신청할 수 있습니다.</span>') : ''}
      ${open && mine ? `<button class="btn ghost" data-unsign="${t.mode}">신청 물리기</button>` : ''}
      ${['locked', 'running', 'done'].includes(t.status) ? `<button class="btn" data-view="${esc(t.t_id)}">${icon('flag', 16)}<span>대진표·관람</span></button>` : ''}
    </div>`, { ico: t.mode === 'solo' ? 'sword' : 'users' });
}

function bindBoard() {
  $$('[data-sign]', el).forEach(b => b.onclick = () => guard(b, async () => {
    const r = await rpc('world_tourney_signup', { p_mode: b.dataset.sign, p_partner: b.dataset.sign === 'team' ? $('#tn-partner', el)?.value : null });
    await refresh(); return r;
  }));
  $$('[data-unsign]', el).forEach(b => b.onclick = async () => {
    if (!(await ask('신청을 물릴까요?', { title: '비무회 신청', ok: '물리기' }))) return;
    guard(b, async () => { const r = await rpc('world_tourney_cancel', { p_mode: b.dataset.unsign }); await refresh(); return r; });
  });
  $$('[data-tac]', el).forEach(b => b.onclick = () => guard(b, async () => {
    const m = b.dataset.tac, box = b.closest('.tn-tac');
    const items = $$(`input[name="it-${m}"]:checked`, box).map(x => x.value);
    if (items.length > 2) throw new Error('회복품은 두 가지까지 고를 수 있습니다.');
    const r = await rpc('world_tourney_tactic', { p_mode: m, p_stance: $(`input[name="st-${m}"]:checked`, box)?.value || 'balanced', p_items: items, p_skill: $(`input[name="sk-${m}"]:checked`, box)?.value || 'mid' });
    await refresh(); return r;
  }));
  $$('[data-view]', el).forEach(b => b.onclick = () => window.yahangGo('tourney', b.dataset.view));
}

/* ── 대진표·관람 ── */
const nameOfEntry = (v, id) => id ? (v.entries?.[id]?.names || []).join('·') : '부전승';
function drawView() {
  const v = view || {};
  const rounds = Math.max(1, v.rounds || 1);
  const col = r => (v.matches || []).filter(m => m.round === r);
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('sword', 14)} 야행 비무회 · ${esc(MODE[v.mode] || '')}</p><h1>대진표 <small>${esc(STATUS[v.status] || '')}</small></h1></div>
      <div class="head-actions"><a class="btn small ghost" href="#/tourney">비무 방</a></div></div>
    <p class="muted small">${esc(v.venue_name || '')} · ${new Date(v.starts_at).toLocaleString('ko-KR', { weekday: 'short', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })}${v.can_watch ? '' : ' · 경기 기록은 개최지에서 볼 수 있습니다(대회가 끝나면 모두 볼 수 있음)'}</p>
    ${v.result?.champion_names ? `<div class="raid-result ok"><b>장원 ${esc(v.result.champion_names)}</b>${v.result.runner_up ? `<p class="small">준우승 ${esc(v.result.runner_up)}</p>` : ''}</div>` : ''}
    <div class="tn-bracket" style="--r:${rounds}">${Array.from({ length: rounds }, (_, i) => i + 1).map(r => `<div class="tn-col"><h3>${r === rounds ? '결승' : r === rounds - 1 ? '4강' : `${r}회전`}</h3>
      ${col(r).map(m => matchCard(v, m)).join('') || '<p class="muted small">아직</p>'}</div>`).join('')}</div>
    <section class="panel" id="tn-watch" hidden><header class="panel-head"><h2>${icon('eye', 16)} <span id="tn-watch-title"></span></h2><button class="btn small ghost" id="tn-watch-close">닫기</button></header>
      <div class="panel-body"><ol class="raid-log tn-log"></ol></div></section>`;
  $$('[data-match]', el).forEach(b => b.onclick = () => openWatch(b.dataset.match));
  $('#tn-watch-close', el).onclick = () => { watching = null; $('#tn-watch', el).hidden = true; };
  if (watching) openWatch(watching);
}
function matchCard(v, m) {
  const live = m.starts_at && new Date(m.ends_at) > now();
  const win = m.winner;
  const row = id => `<span class="${win && win === id ? 'won' : win ? 'lost' : ''} ${v.entries?.[id]?.mine ? 'mine' : ''}">${esc(nameOfEntry(v, id))}</span>`;
  return `<button class="tn-match ${live ? 'live' : ''}" data-match="${esc(m.id)}" ${m.log ? '' : 'disabled'}>${row(m.a)}${row(m.b)}${live ? `<small>${icon('eye', 12)} 진행 중</small>` : ''}</button>`;
}

let watching = null;
function openWatch(id) {
  const m = (view?.matches || []).find(x => x.id === id); if (!m?.log) return;
  watching = id;
  $('#tn-watch', el).hidden = false;
  $('#tn-watch-title', el).textContent = `${nameOfEntry(view, m.a)} 대 ${nameOfEntry(view, m.b)}`;
  paintLog();
}
// 합마다 2초: 서버가 정한 경기 시작 시각부터 지난 만큼만 보여 준다
function paintLog() {
  if (!el || !watching) return;
  const m = (view?.matches || []).find(x => x.id === watching); const box = $('.tn-log', el); if (!m || !box) return;
  const shown = Math.floor((now() - new Date(m.starts_at)) / GAP);
  const lines = (m.log || []).filter(l => (l.x || 0) <= shown);
  if (box.childElementCount === lines.length) return;
  box.innerHTML = lines.map(l => `<li class="k-${esc(l.k || '')} ${l.w ? `side-${l.w}` : ''}"><time>${l.x || ''}</time><span>${esc(l.t)}</span></li>`).join('');
  box.scrollTop = box.scrollHeight;
}
function liveTick() {
  if (!el || !sub) return;
  paintLog();
  $$('.tn-match.live', el).forEach(x => { const m = (view?.matches || []).find(y => y.id === x.dataset.match); if (m && new Date(m.ends_at) <= now()) refresh(); });
}
document.addEventListener('visibilitychange', () => { if (el && !document.hidden) refresh(); });
