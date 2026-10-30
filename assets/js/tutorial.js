// 처음 입국한 조사원을 위한 길잡이: 화면 요소를 하나씩 짚어 주는 단계별 안내와, 현장에 붙는 "첫 걸음" 체크리스트.
// 진행은 서버의 행동 기록에서 세고, 표시 상태(안내 마침·접기·닫기·다시 열기)는 서버(world_tutorial_state)에 캐릭터별로 둔다.
// 그래서 모바일에서 마치면 PC에서도 마친 상태다. 서버를 못 읽을 때만 이 기기의 기록으로 대신한다.
import { store, on, esc, icon, $, h, toast, rpc } from './core.js';

const key = k => `yh-tut-${k}-${store.character?.owner_id || 'x'}`;
const localGet = (k, d = null) => { try { const v = localStorage.getItem(key(k)); return v == null ? d : JSON.parse(v); } catch { return d; } };
const localSet = (k, v) => { try { localStorage.setItem(key(k), JSON.stringify(v)); } catch {} };
const FLAGS = ['done', 'fold', 'closed', 'reopened'];
// st.owner: 서버에서 읽어 온 캐릭터. 읽기 전에는 기기 기록을 쓴다.
const st = { owner: null, flags: {}, prog: {}, failed: false };
const ready = () => st.owner && st.owner === store.character?.owner_id;
const get = (k, d = null) => {
  if (k === 'prog') return ready() ? { ...st.prog } : localGet('prog', d);
  if (ready()) return st.flags[k] ?? d;
  return localGet(k, d);
};
const set = (k, v) => {
  if (k === 'prog') { st.prog = { ...v }; localSet('prog', v); return; }
  localSet(k, v);
  if (ready()) { st.flags[k] = v; rpc('world_tutorial_set', { p_flags: { [k]: !!v } }).catch(() => {}); }
};
// 서버에서 진행·표시 상태를 읽는다. 서버에 아직 표시 상태가 없으면 이 기기에 남아 있던 것을 한 번 올린다.
let loading = null;
export function loadTutorial() {
  const c = store.character; if (!c) return Promise.resolve();
  if (ready()) return Promise.resolve();
  if (loading?.owner === c.owner_id) return loading.p;
  loading = { owner: c.owner_id, p: readTutorial(c) };
  return loading.p;
}
async function readTutorial(c) {
  try {
    const r = await rpc('world_tutorial_snapshot');
    const flags = { ...(r?.flags || {}) };
    if (!r?.saved) {
      const up = {}; FLAGS.forEach(k => { const v = localGet(k); if (v != null) up[k] = !!v; });
      if (Object.keys(up).length) { Object.assign(flags, up); rpc('world_tutorial_set', { p_flags: up }).catch(() => {}); }
    }
    st.owner = c.owner_id; st.flags = flags; st.prog = { ...(r?.progress || {}) };
    drawChecklist();
  } catch { st.failed = true; drawChecklist(); }
  finally { loading = null; }
}
// 행동 뒤에 서버 기록으로 진행을 다시 맞춘다(여러 번 눌러도 한 번만 읽는다)
// 서버 부담을 줄이려 15초에 한 번까지만 읽는다(그 사이 행동은 마지막에 한 번 반영)
let syncTimer = null, lastSync = 0;
function syncSoon() { clearTimeout(syncTimer); syncTimer = setTimeout(async () => {
  if (!ready()) return;
  lastSync = Date.now();
  try { const r = await rpc('world_tutorial_snapshot'); const before = { ...st.prog }; st.prog = { ...(r?.progress || {}) };
    TASKS.forEach(([k]) => { if ((before[k] || 0) > (st.prog[k] || 0)) st.prog[k] = before[k]; });
    drawChecklist(); } catch {}
}, Math.max(1500, 15000 - (Date.now() - lastSync))); }

/* ── 단계별 안내 ─────────────────────────────────────── */
// sel: 짚어 줄 요소(보이는 첫 번째). view: 그 단계에서 열 화면.
const STEPS = [
  { title: '야행국에 오신 것을 환영합니다', body: '밤의 요괴와 변칙을 조사하는 관청의 신입 조사원이 되었습니다. 화면 구성과 처음 할 일을 1분 정도로 짚어 드릴게요. 언제든 건너뛸 수 있습니다.' },
  { sel: ['.hud-body .hud-card', '.hud-strip'], title: '상태판', body: '체력·정신·영력·침식과 탐색력, 지금 진행 중인 일(이동·전투·원정·자율 활동)이 늘 여기 보입니다. 모바일에서는 위쪽 띠를 누르면 펼쳐집니다. 날씨·시간대 표시를 누르면 지금 받는 효과가 나옵니다.' },
  { sel: ['.topnav', '.tabbar'], title: '다섯 개의 탭', body: '<b>현장</b> 지금 있는 곳에서 할 일 · <b>지도</b> 이동 · <b>캐릭터</b> 능력치·장비·칭호 · <b>가방</b> 소지품·장비·제작 · <b>일지</b> 이야기와 의뢰.' },
  { view: 'home', sel: ['.facilities', '.scene'], title: '현장 · 안전지대', body: '처음에는 안전지대인 본부에 있습니다. 안전지대에서는 상점·거래소·숙소를 쓰고, 싸움과 탐색은 할 수 없습니다. 숙소에서 쉬면 체력과 탐색력이 찹니다.' },
  { view: 'char/faction', sel: ['#supply', '.panel'], title: '먼저 일일 보급 받기', body: '소속 부서에서 하루 한 번 회복약·부적 같은 보급품을 줍니다. 첫 원정과 전투에 큰 도움이 되니 오늘 것부터 받아 두세요.' },
  { view: 'bag/equip', sel: ['.equip-list', '.panel'], title: '무기 확인하기', body: '무기 종류가 공격 방식을 정합니다. 칼·창은 근접, 활·쇠뇌는 원거리, 방울·부채·거울은 술법입니다. 가진 무기가 있다면 여기서 장착하세요. 장비는 쓸수록 닳으니 가끔 수리해야 합니다.' },
  { view: 'map', sel: ['#map-frame'], title: '지도에서 바깥으로', body: '지도를 끌고 확대해 지역을 고르면 아래에 경로와 이동 시간이 나옵니다. 처음에는 레벨 1부터 갈 수 있는 <b>잿빛 들녘</b>이나 <b>연무장·팔괘진</b>을 추천합니다. 빗금 친 곳은 아직 레벨이 모자란 곳입니다.' },
  { view: 'home', sel: ['#search', '.scene'], title: '탐색하기', body: '바깥 지역에 도착하면 현장에 <b>탐색하기</b> 버튼이 생깁니다. 탐색력 1을 써서 안쪽 길·채집터·단서·보급 꾸러미를 찾거나 요괴를 만납니다. 찾은 채집터에서는 재료를 캘 수 있습니다.' },
  { title: '전투의 요령', body: '요괴는 다음 행동을 미리 보여 줍니다. <b>강타·기습</b>이 예고되면 <b>막기</b>로 크게 줄이세요. 체력이 낮으면 가방의 청심환을 쓰고, 불리하면 달아날 수도 있습니다. 쓰러지면 회생 부적이나 구조가 필요합니다.' },
  { view: 'log/story', sel: ['.chapter-line', '.panel'], title: '이야기와 의뢰', body: '일지의 <b>이야기</b>에는 장마다 모을 단서가 있고, 단서가 있는 지역으로 바로 출발할 수 있습니다. 단서는 그 지역을 탐색하면 찾습니다. <b>의뢰</b>는 날마다 새로 붙는 소소한 일거리입니다.' },
  { sel: ['.top-actions'], title: '위쪽 버튼', body: '알림 · 귓속말 · 동료(함께 이동하고 전리품을 나누는 모임) · 도움말 · 설정입니다. 프로필·테마·소리·로그아웃은 설정에, 제보·소감는 도움말과 설정에 있습니다.' },
  { sel: ['.chat-col .chat', '#chat-fab'], title: '채팅', body: '전체·지역·세력·귓속말·동료 채팅을 언제든 쓸 수 있습니다. 쓰러졌을 때 지역 채팅으로 도움을 청해 보세요.' },
  { view: 'home', title: '이제 떠나 볼까요', body: '현장 화면 위쪽의 <b>첫 걸음</b> 목록을 따라가면 기본을 모두 익힐 수 있습니다. 더 자세한 규칙과 수치는 위쪽 <b>도움말</b>에 모두 정리되어 있습니다. 이 안내는 도움말에서 다시 볼 수 있습니다.', last: true },
];
let idx = 0, layer = null;
const visible = el => { if (!el) return false; const r = el.getBoundingClientRect(); return r.width > 0 && r.height > 0 && getComputedStyle(el).visibility !== 'hidden'; };
const pick = sels => { for (const s of sels || []) { const el = [...document.querySelectorAll(s)].find(visible); if (el) return el; } return null; };

export function startTutorial(from = 0) {
  idx = from; closeTutorial(false);
  layer = h(`<div class="tut" role="dialog" aria-modal="true" aria-label="처음 안내"><div class="tut-ring" hidden></div>
    <div class="tut-card"><p class="tut-step"></p><h3></h3><p class="tut-body"></p>
      <div class="tut-act"><button class="btn small ghost" data-tut="skip">건너뛰기</button><span></span><button class="btn small" data-tut="prev">이전</button><button class="btn small primary" data-tut="next">다음</button></div></div></div>`);
  document.body.append(layer);
  lockScroll(true);
  layer.addEventListener('click', e => {
    const b = e.target.closest('[data-tut]'); if (!b) return;
    if (b.dataset.tut === 'skip') return closeTutorial(true);
    if (b.dataset.tut === 'prev') return show(Math.max(0, idx - 1));
    if (STEPS[idx].last) return closeTutorial(true);
    show(idx + 1);
  });
  document.addEventListener('keydown', onKey);
  window.addEventListener('resize', place);
  show(idx);
}
// 안내 중에는 화면이 손가락·휠로 움직이지 않게 한다(짚는 위치가 어긋나지 않도록). 안내가 짚을 곳으로 옮기는 것만 허용한다.
const stopScroll = e => { if (!e.target.closest?.('.tut-card')) e.preventDefault(); };
const SCROLL_KEYS = new Set(['ArrowUp', 'ArrowDown', 'PageUp', 'PageDown', 'Home', 'End', ' ']);
const stopKeys = e => { if (SCROLL_KEYS.has(e.key) && !e.target.closest?.('input,textarea,select')) e.preventDefault(); };
function lockScroll(on) {
  document.documentElement.classList.toggle('tut-lock', on);
  const m = on ? 'addEventListener' : 'removeEventListener';
  document[m]('wheel', stopScroll, { passive: false });
  document[m]('touchmove', stopScroll, { passive: false });
  document[m]('keydown', stopKeys);
}
function onKey(e) { if (e.key === 'Escape') closeTutorial(true); if (e.key === 'ArrowRight' && !STEPS[idx].last) show(idx + 1); if (e.key === 'ArrowLeft') show(Math.max(0, idx - 1)); }
export function closeTutorial(done) {
  if (layer) { layer.remove(); layer = null; }
  lockScroll(false);
  document.removeEventListener('keydown', onKey); window.removeEventListener('resize', place);
  if (done) { set('done', true); try { localStorage.removeItem('yh-tut-pending'); } catch {} drawChecklist(); }
}
async function show(i) {
  idx = i; const s = STEPS[i];
  if (s.view && !location.hash.startsWith('#/' + s.view)) { window.yahangGo?.(...s.view.split('/')); await new Promise(r => setTimeout(r, 650)); }
  if (!layer) return;
  $('.tut-step', layer).textContent = `${i + 1} / ${STEPS.length}`;
  $('h3', layer).textContent = s.title;
  $('.tut-body', layer).innerHTML = s.body;
  $('[data-tut="prev"]', layer).hidden = i === 0;
  $('[data-tut="next"]', layer).textContent = s.last ? '시작하기' : '다음';
  const t = pick(s.sel);
  if (t) t.scrollIntoView({ block: 'nearest' });
  place();
}
function place() {
  if (!layer) return;
  const s = STEPS[idx], t = pick(s.sel), ring = $('.tut-ring', layer), card = $('.tut-card', layer);
  const narrow = innerWidth < 700;
  if (!t) { ring.hidden = true; card.className = 'tut-card center'; card.style.cssText = ''; return; }
  const r = t.getBoundingClientRect(), pad = 6;
  ring.hidden = false;
  Object.assign(ring.style, { left: `${Math.max(4, r.left - pad)}px`, top: `${Math.max(4, r.top - pad)}px`, width: `${Math.min(innerWidth - 8, r.width + pad * 2)}px`, height: `${Math.min(innerHeight - 8, r.height + pad * 2)}px` });
  card.className = 'tut-card';
  if (narrow) { card.style.cssText = ''; card.classList.add(r.top + r.height / 2 > innerHeight / 2 ? 'top' : 'bottom'); return; }
  const cw = Math.min(360, innerWidth - 32), below = r.bottom + 14 + 200 < innerHeight;
  const left = Math.min(innerWidth - cw - 16, Math.max(16, r.left));
  card.style.cssText = `width:${cw}px;left:${left}px;${below ? `top:${r.bottom + 14}px` : `top:${Math.max(16, r.top - 14 - card.offsetHeight)}px`}`;
}

/* ── 첫 걸음 체크리스트 ───────────────────────────────── */
const TASKS = [
  ['supply', '일일 보급 받기', '캐릭터 › 세력', 'char/faction'],
  ['outside', '바깥 지역으로 나가기', '지도에서 잿빛 들녘·연무장 추천', 'map'],
  ['search', '탐색 3번 해 보기', '현장 › 탐색하기', 'home'],
  ['gather', '채집 1번 하기', '탐색으로 찾은 채집터에서', 'home'],
  ['victory', '요괴 1마리 물리치기', '예고를 보고 막기를 섞어 싸우기', 'home'],
  ['clue', '이야기 단서 1개 찾기', '일지 › 이야기의 지역을 탐색', 'log/story'],
];
function progress() { return get('prog', {}); }
function mark(k, n = 1) {
  const p = progress(); const before = done(p, k);
  // 이미 마친 항목이거나 목록이 보이지 않으면(닫음·Lv6 이상) 서버에 다시 묻지 않는다(탐색할 때마다 15초 간격으로 읽던 것)
  p[k] = (p[k] || 0) + n; set('prog', p);
  if (!before && !get('closed') && ((store.character?.level || 1) < 6 || get('reopened'))) syncSoon();
  if (!before && done(p, k)) {
    const t = TASKS.find(x => x[0] === k);
    const left = TASKS.filter(([x]) => !done(p, x)).length;
    if (t) toast(`첫 걸음 완료: ${t[1]}${left ? ` · 남은 일 ${left}개` : ' · 모두 마쳤습니다!'}`, 'ok');
    set('closed', false); // 완료한 걸 확인할 수 있게 닫아 둔 목록도 다시 보인다(접힌 상태는 그대로)
    drawChecklist(true);
  }
}
const need = { search: 3 };
const done = (p, k) => (p[k] || 0) >= (need[k] || 1);

// 상태: 접기(fold) — 한 줄로 줄어들 뿐 사라지지 않는다. 닫기(closed) — 모두 마친 뒤에만 닫을 수 있고, 도움말에서 다시 연다.
export function checklistHtml() {
  const c = store.character; if (!c) return '';
  if (!ready() && !st.failed) return ''; // 서버 기록을 읽기 전에는 그리지 않는다(다른 기기에서 마친 목록이 잠깐 보이지 않게)
  if (get('closed')) return '';
  const p = progress(); if (store.hud?.supply?.claimed_today) p.supply = Math.max(1, p.supply || 0);
  const n = TASKS.filter(([k]) => done(p, k)).length, all = n === TASKS.length;
  if (!all && (c.level || 1) >= 6 && !get('reopened')) return '';
  const fold = !!get('fold');
  return `<section class="panel firststeps ${fold ? 'folded' : ''} ${all ? 'complete' : ''}" id="firststeps"><header class="panel-head"><h2>${icon(all ? 'check' : 'spark', 16)}첫 걸음 <small>${n}/${TASKS.length}${all ? ' · 모두 마침' : ''}</small></h2>
      <div class="btn-row">${all ? '<button class="btn small" data-fs="close">닫기</button>' : ''}<button class="btn small ghost" data-fs="fold" aria-expanded="${!fold}">${fold ? '펼치기' : '접기'}</button></div></header>
    ${fold ? '' : `<div class="panel-body"><ol class="fs-list">${TASKS.map(([k, t, d, v]) => `<li class="${done(p, k) ? 'done' : ''}">
      <span class="fs-box">${done(p, k) ? icon('check', 14) : ''}</span><a href="#/${v}"><b>${esc(t)}</b><small>${done(p, k) ? '마침' : esc(d)}${k === 'search' && !done(p, k) ? ` · ${p.search || 0}/3` : ''}</small></a></li>`).join('')}</ol>
      <p class="muted small">${all ? '기본을 모두 익혔습니다. 닫아도 도움말에서 다시 볼 수 있습니다.' : '처음 할 일입니다. 접어 두어도 진행은 계속 기록됩니다.'} <button class="linkish" data-fs="tour">안내 다시 보기</button></p></div>`}</section>`;
}
function drawChecklist(celebrate) {
  const box = document.getElementById('firststeps');
  const html = checklistHtml();
  if (!box) { if (html) { const slot = document.querySelector('#view[data-view="home"] .scene'); if (slot) slot.insertAdjacentHTML('afterend', html); } return; }
  if (!html) { box.remove(); return; }
  box.outerHTML = html;
  if (celebrate) window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'find' }));
}
// 도움말의 "첫 걸음 다시 보기"
export function reopenChecklist() { set('closed', false); set('fold', false); set('reopened', true); }
document.addEventListener('click', e => {
  const b = e.target.closest('[data-fs]'); if (!b) return;
  if (b.dataset.fs === 'fold') { set('fold', !get('fold')); drawChecklist(); }
  if (b.dataset.fs === 'close') { set('closed', true); drawChecklist(); toast('첫 걸음 목록을 닫았습니다. 도움말에서 다시 볼 수 있습니다.', 'info'); }
  if (b.dataset.fs === 'tour') startTutorial(0);
});

// 행동 결과로 체크리스트를 채운다.
on('changed', ({ name, data }) => {
  if (!store.character) return;
  if (/world_claim_faction_supply/.test(name)) mark('supply');
  if (name === 'world_field_search' || name === 'world_field_search_quiet') { mark('search'); if (data?.outcome === 'clue') mark('clue'); }
  if (name === 'world_field_gather') mark('gather');
  if (name === 'world_battle_action' && data?.ended === 'victory') mark('victory');
});
window.addEventListener('yahang:arrived', () => setTimeout(() => { if (store.snaps?.world_field_snapshot?.region && !store.snaps.world_field_snapshot.region.safe) mark('outside'); }, 1500));
export function noteRegion(region) { if (region && !region.safe && !done(progress(), 'outside')) mark('outside'); }

// 처음 만든 캐릭터(또는 아직 안내를 보지 않은 낮은 레벨 캐릭터)에게 한 번 띄운다.
export async function maybeStartTutorial() {
  await loadTutorial();
  const c = store.character; if (!c || get('done')) return;
  let pending = false; try { pending = localStorage.getItem('yh-tut-pending') === c.owner_id; } catch {}
  if (pending || (c.level || 1) <= 2) setTimeout(() => startTutorial(0), 900);
}
export function markPending(ownerId) { try { localStorage.setItem('yh-tut-pending', ownerId || ''); } catch {} }
