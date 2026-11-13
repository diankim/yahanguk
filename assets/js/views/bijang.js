import { rpc, act, esc, icon, fmt, $, $$, store, guard, ask, nameOf, openModal } from '../core.js';
import { loading, errorBox, chip } from './common.js';
import { resultBox, settleFight, jobName, logRow } from './fightui.js';
import { BIJANG } from '../rules.js';

const DOOR = ['一', '二', '三'];
let el = null, rid = null, snap = null, timer = null, sending = false;

export async function render(root, sub) {
  el = root; rid = sub || null; snap = null;
  el.innerHTML = `${head()}${loading()}`;
  await refresh();
}
export function destroy() { clearTimeout(timer); el = null; }
document.addEventListener('visibilitychange', () => { if (el && !document.hidden) refresh(); });

const head = (s = null) => `<div class="view-head"><div><p class="eyebrow">${icon('chest', 14)} 비장고${s ? ` · ${esc(s.name)}` : ''}</p><h1>${s ? esc(s.region_name || '') : '비장도와 비장고'}</h1></div>
  <div class="head-actions">${s ? statusChip(s) : ''}</div></div>`;
const statusChip = s => s.status === 'fight' ? chip('파수꾼과 싸우는 중', 'bad') : s.status === 'room' ? chip(`${s.room}번 방`, 'warn') : chip(BIJANG.result[s.result] || '끝남', s.result === 'final' ? 'ok' : '');

async function refresh() {
  if (!el) return;
  clearTimeout(timer);
  try {
    const prev = snap?.status;
    snap = await rpc('world_bijang_snapshot', { p_run: rid });
    if (!el) return;
    if (!snap) { el.innerHTML = `${head()}${errorBox('지금 도는 비장고가 없습니다.')}<p class="muted small">${esc(BIJANG.how)}</p><a class="btn" href="#/home">현장으로</a>`; return; }
    if (!rid) { rid = snap.run_id; history.replaceState(null, '', `#/bijang/${rid}`); }
    if (prev && prev !== snap.status) await settleFight('world_bijang_snapshot');
    draw(); plan(); gainsPop();
  } catch (e) { if (el) el.innerHTML = `${head()}${errorBox(e.message)}`; }
}
function plan() {
  if (!snap || snap.status === 'end' || document.hidden || !el) return;
  timer = setTimeout(refresh, snap.status === 'fight' ? 3000 : 4000);
}

function ladder(s) {
  const n = s.rooms || 5;
  return `<ol class="bj-ladder">${Array.from({ length: n }, (_, i) => {
    const k = i + 1, last = k === n, at = s.status !== 'end' && s.room === k, done = s.room > k || (s.result === 'final' && k <= n);
    return `<li class="${at ? 'now' : ''} ${done ? 'done' : ''} ${last ? 'last' : ''}">${last ? icon('star', 12) : `<b>${k}</b>`}<span>${last ? '마지막 방' : `${k}번 방`}</span></li>`; }).join('')}</ol>`;
}

function doorsHtml(s) {
  const pick = s.me?.can_pick, picker = (s.members || []).find(m => m.id === s.picker_id);
  return `<div class="bj-doors">${DOOR.map((d, i) => `<button type="button" class="bj-door ${s.shown === i + 1 ? 'lit' : ''}" data-door="${i + 1}" ${pick ? '' : 'disabled'} title="${i + 1}번 문">
      <span class="bj-arch"><i></i><i></i></span><b>${d}</b><small>${s.shown === i + 1 ? '먹빛 이름이 비침' : `${i + 1}번 문`}</small></button>`).join('')}</div>
    <p class="muted small bj-turn">${pick ? '문 하나를 고르세요. 맞으면 다음 방으로, 틀리면 비장고가 무너집니다(얻은 것은 그대로).' : `길잡이 <b>${esc(picker?.name || '…')}</b>이(가) 문을 고르는 중입니다.`}</p>`;
}

function fightHtml(s) {
  const f = s.fight || {}, pct = f.max_hp ? Math.max(0, Math.min(100, f.hp / f.max_hp * 100)) : 100;
  return `<div class="bj-guard">${icon('flame', 18)}<div><b>${esc(f.monster || '파수꾼')}</b><span>${s.room ? `${s.room}번 방을 지키는 파수꾼` : '비장도를 따라 판 자리에서 일어난 파수꾼'}</span>
      <div class="raid-hp"><div class="bar boss"><span style="width:${pct}%"></span></div><b>${fmt.num(f.hp || 0)} / ${fmt.num(f.max_hp || 0)}</b></div></div></div>
    <div class="btn-row">${f.mine ? `<a class="btn primary" href="#/pfight/${esc(f.id)}">${icon('sword', 16)}<span>파수꾼 싸움으로</span></a>` : ''}
      ${f.can_join ? `<button class="btn primary" id="bj-join" data-here="함께 싸우기">${icon('flag', 16)}<span>합류하기 · 탐색력 1</span></button>` : ''}
      ${!f.mine && !f.can_join ? '<span class="muted small">함께 선 이들이 싸우고 있습니다.</span>' : ''}</div>`;
}

function gotText(m, s) {
  const g = m.got || {}, items = Object.entries(g.items || {});
  const parts = [g.gil ? `${fmt.num(g.gil)}전` : '', ...items.map(([k, v]) => `${s.names?.[k] || nameOf(k)} ×${v}`)].filter(Boolean);
  return parts.length ? parts.join(' · ') : '아직 없음';
}

function draw() {
  if (!el || !snap) return;
  const s = snap, c = store.character || {}, me = s.me || {};
  const ended = s.status === 'end';
  el.innerHTML = `${head(s)}
    <div class="bj-wrap">
      <section class="panel bj-main"><div class="panel-body">
        ${ladder(s)}
        ${s.status === 'fight' ? fightHtml(s) : ''}
        ${s.status === 'room' ? doorsHtml(s) : ''}
        ${ended ? resultBox(s.result === 'final', esc(BIJANG.result[s.result] || '비장고 탐색이 끝났습니다'), `<p class="small">${esc(BIJANG.end[s.result] || '')}</p><a class="btn small" href="#/home">현장으로</a>`) : ''}
        <p class="bj-entry ${me.entries_left ? '' : 'none'}">${icon('chest', 14)} 오늘 비장고 들어가기 <b>${me.entries_left ?? 0}</b> / ${me.entry_day ?? 3}번 남음${me.member && !me.entered && s.room > 0 ? ' · 이번 비장고에는 들어가지 못했습니다' : ''}</p>
      </div></section>
      <section class="panel bj-members"><header class="panel-head"><h2>${icon('users', 16)} 함께 간 이 ${(s.members || []).length}명</h2></header><div class="panel-body">
        <ul class="bj-mem">${(s.members || []).map(m => `<li class="${m.id === c.owner_id ? 'me' : ''} ${m.entered ? '' : 'out'}">
            <span class="bj-mn"><b>${esc(m.name)}</b>${m.owner ? '<small class="accent">비장도 주인</small>' : ''}${m.id === s.picker_id ? '<small>길잡이</small>' : ''}</span>
            <small class="muted">${esc(jobName(m.job))} · ${s.room > 0 ? (m.entered ? '비장고에 듦' : '들지 못함') : '파수꾼과 싸움'}${m.here ? '' : ' · 자리 비움'}</small>
            <span class="bj-got">${esc(gotText(m, s))}</span></li>`).join('') || '<li class="muted">파수꾼을 쓰러뜨리면 함께 선 이들이 여기에 적힙니다.</li>'}</ul>
        <p class="muted small">${esc(BIJANG.rule)}</p></div></section>
      <section class="panel bj-log-box"><header class="panel-head"><h2>${icon('scroll', 16)} 기록</h2></header><div class="panel-body">
        <ol class="raid-log bj-log">${[...(s.log || [])].reverse().map(l => logRow('no-time', esc(l))).join('') || '<li class="muted">아직 기록이 없습니다.</li>'}</ol></div></section>
    </div>`;
  bind();
}

function bind() {
  $$('[data-door]', el).forEach(b => b.onclick = async () => {
    const d = Number(b.dataset.door);
    if (!(await ask(`${d}번 문을 엽니다. 틀리면 비장고가 무너지고 여기서 끝납니다(얻은 것은 그대로 가집니다).`, { title: `${snap.room}번 방 · ${d}번 문`, ok: '문 열기' }))) return;
    run(b, () => act('world_bijang_pick', { p_run: rid, p_door: d }));
  });
  const j = $('#bj-join', el);
  if (j) j.onclick = () => run(j, async () => { await act('world_pfight_join', { p_fight: snap.fight.id }); window.yahangGo('pfight', snap.fight.id); return null; });
}

async function run(btn, fn) {
  if (sending) return;
  sending = true;
  try {
    const out = await guard(btn, fn, { success: '' });
    if (out && el) { clearTimeout(timer); snap = out; draw(); plan(); gainsPop(); if (out.status === 'fight' && out.fight?.mine) window.yahangGo('pfight', out.fight.id); }
  } finally { sending = false; }
}

const seenKey = () => `yh-bj-seen:${snap?.run_id}`;
function seenGet() { try { return Number(sessionStorage.getItem(seenKey()) || 0); } catch { return 0; } }
function seenSet(n) { try { sessionStorage.setItem(seenKey(), String(n)); } catch { } }
const gainTitle = g => g.final ? '마지막 방' : g.room ? `${g.room}번 방 상자` : '묻힌 상자';
async function gainsPop() {
  const gs = snap?.me?.gains || [], seen = seenGet();
  if (!el || gs.length <= seen) return;
  seenSet(gs.length);
  const fresh = gs.slice(seen), final = fresh.some(g => g.final);
  const pets = fresh.flatMap(g => g.pets || []);
  const petNames = pets.length ? await import('../housing/pets.js').then(m => m.PETS).catch(() => ({})) : {};
  const rows = fresh.map(g => {
    const parts = [g.gil ? `<li class="bj-gain-gil">${icon('coin', 14)}<b>${fmt.num(g.gil)}전</b></li>` : '',
      ...Object.entries(g.items || {}).map(([k, v]) => `<li>${icon('chest', 14)}<b>${esc(snap.names?.[k] || nameOf(k))}</b><span>×${v}</span></li>`),
      ...(g.pets || []).map(id => `<li class="bj-gain-pet">${icon('star', 14)}<b>꼬마 동무 ${esc(petNames[id]?.name || nameOf(id))}</b><span>별채 동무 도감으로</span></li>`)].filter(Boolean).join('');
    return `<section class="bj-gain${g.final ? ' final' : ''}"><h3>${esc(gainTitle(g))}</h3><ul>${parts || '<li class="muted">빈 상자였습니다.</li>'}</ul>${g.stored ? '<p class="muted small">가방이 차서 일부는 개인 창고로 갔습니다.</p>' : ''}</section>`;
  }).join('');
  openModal({ title: final ? '비장고 마지막 방' : '상자를 열었습니다', body: `<div class="bj-gains">${rows}</div><div class="btn-row end"><button class="btn primary" data-close>확인</button></div>` });
  if (final) confetti();
}
function confetti() {
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  const cv = document.createElement('canvas'), dpr = Math.min(2, devicePixelRatio || 1);
  cv.className = 'bj-confetti'; cv.width = innerWidth * dpr; cv.height = innerHeight * dpr;
  document.body.append(cv);
  const g = cv.getContext('2d'), cs = getComputedStyle(document.documentElement);
  const cols = ['--gold', '--accent', '--ok', '--hp', '--mp', '--sp'].map(v => cs.getPropertyValue(v).trim()).filter(Boolean);
  const ps = Array.from({ length: 140 }, () => ({ x: cv.width * (0.2 + Math.random() * 0.6), y: cv.height * 0.35, vx: (Math.random() - 0.5) * 16 * dpr, vy: (-8 - Math.random() * 12) * dpr,
    r: Math.random() * 6.28, vr: (Math.random() - 0.5) * 0.4, w: (5 + Math.random() * 5) * dpr, h: (3 + Math.random() * 4) * dpr, c: cols[Math.floor(Math.random() * cols.length)] || '#d1a65a' }));
  const t0 = performance.now();
  const step = t => {
    const k = (t - t0) / 2600;
    g.clearRect(0, 0, cv.width, cv.height);
    ps.forEach(p => { p.vy += 0.35 * dpr; p.vx *= 0.99; p.x += p.vx; p.y += p.vy; p.r += p.vr;
      g.save(); g.globalAlpha = Math.max(0, 1 - k); g.translate(p.x, p.y); g.rotate(p.r); g.fillStyle = p.c; g.fillRect(-p.w / 2, -p.h / 2, p.w, p.h); g.restore(); });
    if (k < 1) requestAnimationFrame(step); else cv.remove();
  };
  requestAnimationFrame(step);
}
