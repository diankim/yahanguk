// 처음 입국한 조사원을 위한 길잡이: 화면 요소를 하나씩 짚어 주는 단계별 안내와, 현장에 붙는 "첫 걸음" 체크리스트.
// 진행 기록은 이 기기에 캐릭터별로 저장한다(서버 데이터가 아니므로 다른 기기에서는 다시 볼 수 있다).
import { store, on, esc, icon, $, h } from './core.js';

const key = k => `yh-tut-${k}-${store.character?.owner_id || 'x'}`;
const get = (k, d = null) => { try { const v = localStorage.getItem(key(k)); return v == null ? d : JSON.parse(v); } catch { return d; } };
const set = (k, v) => { try { localStorage.setItem(key(k), JSON.stringify(v)); } catch {} };

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
  { sel: ['.top-actions'], title: '위쪽 버튼', body: '알림 · 동료(함께 이동하고 전리품을 나누는 모임) · 도움말 · 프로필 · 테마 · 게임 설정입니다. 소리와 테마는 게임 설정에서 바꿉니다.' },
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
function onKey(e) { if (e.key === 'Escape') closeTutorial(true); if (e.key === 'ArrowRight' && !STEPS[idx].last) show(idx + 1); if (e.key === 'ArrowLeft') show(Math.max(0, idx - 1)); }
export function closeTutorial(done) {
  if (layer) { layer.remove(); layer = null; }
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
  p[k] = (p[k] || 0) + n; set('prog', p);
  if (!before && done(p, k)) drawChecklist(true);
}
const need = { search: 3 };
const done = (p, k) => (p[k] || 0) >= (need[k] || 1);

export function checklistHtml() {
  const c = store.character; if (!c || get('hide') || (c.level || 1) >= 6) return '';
  const p = progress(); if (store.hud?.supply?.claimed_today) p.supply = Math.max(1, p.supply || 0);
  const n = TASKS.filter(([k]) => done(p, k)).length;
  if (n === TASKS.length) return '';
  return `<section class="panel firststeps" id="firststeps"><header class="panel-head"><h2>${icon('spark', 16)}첫 걸음 <small>${n}/${TASKS.length}</small></h2>
      <button class="btn small ghost" data-fs="hide">접기</button></header>
    <div class="panel-body"><ol class="fs-list">${TASKS.map(([k, t, d, v]) => `<li class="${done(p, k) ? 'done' : ''}">
      <span class="fs-box">${done(p, k) ? icon('check', 14) : ''}</span><a href="#/${v}"><b>${esc(t)}</b><small>${esc(d)}${k === 'search' && !done(p, k) ? ` · ${p.search || 0}/3` : ''}</small></a></li>`).join('')}</ol>
      <p class="muted small">처음 할 일입니다. 다 하면 이 목록은 사라집니다. <button class="linkish" data-fs="tour">안내 다시 보기</button></p></div></section>`;
}
function drawChecklist(celebrate) {
  const box = document.getElementById('firststeps'); if (!box) return;
  const html = checklistHtml();
  if (!html) { box.remove(); return; }
  box.outerHTML = html;
  if (celebrate) window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'find' }));
}
document.addEventListener('click', e => {
  const b = e.target.closest('[data-fs]'); if (!b) return;
  if (b.dataset.fs === 'hide') { set('hide', true); document.getElementById('firststeps')?.remove(); }
  if (b.dataset.fs === 'tour') startTutorial(0);
});

// 행동 결과로 체크리스트를 채운다.
on('changed', ({ name, data }) => {
  if (!store.character) return;
  if (/world_claim_faction_supply/.test(name)) mark('supply');
  if (name === 'world_field_search') { mark('search'); if (data?.outcome === 'clue') mark('clue'); }
  if (name === 'world_field_gather') mark('gather');
  if (name === 'world_battle_action' && data?.ended === 'victory') mark('victory');
});
window.addEventListener('yahang:arrived', () => setTimeout(() => { if (store.snaps?.world_field_snapshot?.region && !store.snaps.world_field_snapshot.region.safe) mark('outside'); }, 1500));
export function noteRegion(region) { if (region && !region.safe && !done(progress(), 'outside')) mark('outside'); }

// 처음 만든 캐릭터(또는 아직 안내를 보지 않은 낮은 레벨 캐릭터)에게 한 번 띄운다.
export function maybeStartTutorial() {
  const c = store.character; if (!c || get('done')) return;
  let pending = false; try { pending = localStorage.getItem('yh-tut-pending') === c.owner_id; } catch {}
  if (pending || (c.level || 1) <= 2) setTimeout(() => startTutorial(0), 900);
}
export function markPending(ownerId) { try { localStorage.setItem('yh-tut-pending', ownerId || ''); } catch {} }
