import { ID_RULE, idToEmail } from './config.js';
// 야행국 앱 진입점: 인증 → (최초 1회) 캐릭터 생성 → 게임 화면.
import { ask, loadStaff, db, store, on, emit, loadCharacter, rpc, JOBS, FACTIONS, esc, h, $, $$, icon, toast, friendlyError, guard } from './core.js';
import { mountHud } from './hud.js';
import { mountChat } from './chat.js';
import { mountWhisper } from './whisper.js';
import { mountGrowth } from './growth.js';
import { mountVersionCheck } from './version.js';
import { mountBug } from './bug.js';
import { applySavedTheme, openProfile, initSound, mountNotifications } from './settings.js';
import { mountEnv } from './env.js';
import { maybeStartTutorial, markPending } from './tutorial.js';
import { mountTravelBanner } from './banner.js';
import { mountCards } from './views/card.js';
import { mountTitleDot } from './titledot.js';
import { claimSession, expectLogin, loginFailed, mountSessionGuard, stopSessionGuard, takeKickNote, logout } from './session.js';
import * as home from './views/home.js';
import * as map from './views/map.js';
import * as character from './views/character.js';
import * as bag from './views/bag.js';
import * as journal from './views/journal.js';
import * as party from './views/party.js';
import * as guide from './views/guide.js';
import * as account from './views/account.js';
import * as settingsPage from './views/settings.js';
import * as patchPage from './views/patch.js';
import * as raidPage from './views/raid.js';
import { preloadNames, hasNameCache } from './views/common.js';

mountCards(); // 이름을 누르면 조사원 카드(한 번만 건다)

applySavedTheme();
initSound();

const app = $('#app');
const VIEWS = {
  home: { mod: home, label: '현장', icon: 'home' },
  map: { mod: map, label: '지도', icon: 'map' },
  char: { mod: character, label: '캐릭터', icon: 'user' },
  bag: { mod: bag, label: '가방', icon: 'bag' },
  log: { mod: journal, label: '일지', icon: 'scroll' },
};
// 탭에는 없지만 헤더에서 여는 화면
const PAGES = { party: { mod: party, label: '동료' }, guide: { mod: guide, label: '도움말' }, account: { mod: account, label: '계정' }, settings: { mod: settingsPage, label: '설정' }, patch: { mod: patchPage, label: '패치노트' }, raid: { mod: raidPage, label: '토벌' } };

/* ── 인증 상태 흐름 ─────────────────────────────────────── */
let routedFor = null, routing = null;
// 로그인 이벤트가 연달아 두 번(INITIAL_SESSION·SIGNED_IN) 와도 같은 사람이면 한 번만 화면을 꾸린다
function route(session) {
  const uid = session?.user?.id || null;
  if (uid && routing?.uid === uid) return routing.p;
  const p = routeOnce(session).finally(() => { if (routing?.p === p) routing = null; });
  routing = uid ? { uid, p } : null;
  return p;
}
async function routeOnce(session) {
  const uid = session?.user?.id || null;
  if (uid && routedFor === uid && $('.shell')) return; // 이미 게임 화면
  store.user = session?.user || null;
  if (!store.user) { routedFor = null; return renderAuth('login', takeKickNote()); }
  mountSessionGuard();
  try {
    const c = await loadCharacter();
    routedFor = uid;
    if (!c) return renderCreate();
    if (c.is_dead) return renderDeath(c);
    renderGame();
  } catch (e) {
    renderError(friendlyError(e));
  }
}
db.auth.onAuthStateChange((evt, session) => {
  if (evt === 'SIGNED_OUT') { stopSessionGuard(); routedFor = null; store.user = null; store.character = null; return renderAuth('login', takeKickNote()); }
  if (evt === 'SIGNED_IN' || evt === 'INITIAL_SESSION') route(session);
});

function renderError(msg) {
  app.replaceChildren(h(`<div class="center-screen"><div class="card narrow"><h1>연결 오류</h1><p class="muted">${esc(msg)}</p><button class="btn primary" id="retry">다시 시도</button></div></div>`));
  $('#retry').onclick = () => location.reload();
}

/* ── 로그인 / 회원가입 ──────────────────────────────────── */
function renderAuth(mode = 'login', notice = '') {
  window.dispatchEvent(new Event('yh-booted'));
  document.title = '야행국 · 입국';
  app.replaceChildren(h(`
  <div class="auth-screen">
    <div class="auth-hero">
      <div class="seal seal-lg">夜</div>
      <h1>야행국</h1>
      <p>밤의 도시를 조사하는 비밀 관청. 공용 세계에서 다른 조사원과 함께 탐사·전투·채집·제작·사건 조사를 이어갑니다.</p>
    </div>
    <form class="card auth-card" id="auth-form" novalidate>
      <div class="segmented" style="--n:2" role="tablist">
        <button type="button" data-mode="login" class="${mode === 'login' ? 'on' : ''}">로그인</button>
        <button type="button" data-mode="signup" class="${mode === 'signup' ? 'on' : ''}">회원가입</button>
      </div>
      <label class="field"><span>아이디</span><input name="uid" type="text" autocomplete="username" autocapitalize="none" spellcheck="false" inputmode="latin" required maxlength="40" placeholder="영문 소문자·숫자 4~16자"></label>
      <label class="field"><span>비밀번호</span><input name="password" type="password" autocomplete="${mode === 'login' ? 'current-password' : 'new-password'}" required minlength="6" placeholder="6자 이상"></label>
      ${mode === 'signup' ? `<label class="field"><span>비밀번호 확인</span><input name="password2" type="password" autocomplete="new-password" required minlength="6"></label>` : ''}
      <p class="form-msg ${notice ? 'show' : ''}" id="auth-msg">${esc(notice)}</p>
      <button class="btn primary block" type="submit">${mode === 'login' ? '로그인' : '계정 만들기'}</button>
      <p class="fine">${mode === 'login' ? '처음이라면 회원가입 후 캐릭터를 만들어 입국합니다.' : '아이디는 로그인에만 쓰이고 다른 조사원에게 보이지 않습니다. 가입 후 캐릭터 이름·직업·소속을 정하며, 세 가지는 생성 후 바꿀 수 없습니다.'}</p>
    </form>
  </div>`));
  $$('[data-mode]').forEach(b => b.onclick = () => renderAuth(b.dataset.mode));
  $('#auth-form').onsubmit = async e => {
    e.preventDefault();
    const f = new FormData(e.target), raw = String(f.get('uid') || '').trim().toLowerCase(), pw = String(f.get('password') || '');
    // 예전 이메일 계정도 로그인할 수 있게 @가 있으면 그대로 쓴다(가입은 아이디만)
    const email = raw.includes('@') ? raw : idToEmail(raw);
    const msg = $('#auth-msg'), btn = e.submitter || $('button[type=submit]', e.target);
    const say = (t, ok = false) => { msg.textContent = t; msg.className = 'form-msg show' + (ok ? ' ok' : ''); };
    if (!raw || pw.length < 6) return say('아이디와 6자 이상의 비밀번호를 입력하세요.');
    if (mode === 'signup' && !ID_RULE.test(raw)) return say('아이디는 영문 소문자와 숫자 4~16자로 정하세요.');
    if (mode === 'signup' && pw !== String(f.get('password2') || '')) return say('비밀번호 확인이 일치하지 않습니다.');
    btn.disabled = true;
    expectLogin();
    try {
      if (mode === 'login') {
        const { error } = await db.auth.signInWithPassword({ email, password: pw });
        if (error) throw error;
        await claimSession(); // 이 브라우저가 현재 접속이 되고, 다른 곳의 접속은 로그아웃된다
      } else {
        const { data, error } = await db.auth.signUp({ email, password: pw });
        if (error) throw error;
        if (data.session) await claimSession();
        if (!data.session) return renderAuth('login', '가입은 되었지만 바로 로그인되지 않았습니다. 관리자에게 Supabase의 "Confirm email" 설정을 꺼 달라고 알려 주세요.');
      }
    } catch (err) { loginFailed(); say(friendlyError(err)); }
    finally { btn.disabled = false; loginFailed(); }
  };
}

/* ── 캐릭터 생성 (최초 1회) ─────────────────────────────── */
const STAT_KO = { strength: '힘', agility: '민첩', vitality: '체질', perception: '감각', willpower: '의지', spirit_affinity: '영기' };
const baseText = b => Object.entries(b).sort((x, y) => y[1] - x[1]).map(([k, v]) => `${STAT_KO[k]} ${v}`).join(' · ');
function renderCreate() {
  document.title = '야행국 · 캐릭터 생성';
  // 쓰던 이름·고른 직업·소속을 이 기기에 잠시 남겨, 다른 앱에 다녀오거나 화면이 다시 그려져도 되살린다(입국하면 지운다).
  const draftKey = `yh-create-draft:${store.user?.id || ''}`;
  let draft = {};
  try { draft = JSON.parse(localStorage.getItem(draftKey) || '{}') || {}; } catch {}
  const pick = { job: JOBS[draft.job] ? draft.job : '', faction: FACTIONS[draft.faction] ? draft.faction : '' };
  const saveDraft = () => { try { localStorage.setItem(draftKey, JSON.stringify({ name: form.name.value, job: pick.job, faction: pick.faction })); } catch {} };
  const cards = (obj, kind) => Object.entries(obj).map(([k, v]) => `
    <button type="button" class="choice-card" data-${kind}="${k}" aria-pressed="false">
      <strong>${esc(v.name)}</strong><span class="tag">${esc(v.trait)}</span><small>${esc(v.desc)}</small>${v.base ? `<small class="muted">기본 능력치 ${baseText(v.base)}<br>시작 장비: ${esc(v.kit)}</small>` : ''}
    </button>`).join('');
  app.replaceChildren(h(`
  <div class="create-screen">
    <header class="create-head"><div class="seal">夜</div><div><h1>조사원 등록</h1><p class="muted">야행국에 입국할 캐릭터를 만듭니다.</p></div>
      <button class="btn ghost small" id="create-logout">${icon('logout', 16)}<span>로그아웃</span></button></header>
    <form id="create-form" class="create-body" novalidate>
      <section class="card"><h2 class="step"><b>1</b>이름</h2>
        <label class="field"><span>캐릭터 이름 (2~12자 · 한글·영문·숫자)</span><input name="name" maxlength="12" autocomplete="off" required placeholder="예: 서하윤"></label>
      </section>
      <section class="card"><h2 class="step"><b>2</b>직업</h2><p class="muted small">직업은 역할(근접·원거리 물리·술법·생활 특화·치유·보조)과 기본 능력치·시작 장비를 정합니다. 무기는 어느 직업이나 들 수 있지만 직업 효과는 그 역할의 무기에서 가장 잘 살아납니다.</p><div class="choice-grid">${cards(JOBS, 'job')}</div></section>
      <section class="card"><h2 class="step"><b>3</b>소속</h2><p class="muted small">소속은 일일 보급과 전용 임무를 정합니다.</p><div class="choice-grid">${cards(FACTIONS, 'faction')}</div></section>
      <section class="card confirm-card">
        <div class="confirm-row"><span>이름</span><b id="sum-name">—</b></div>
        <div class="confirm-row"><span>직업</span><b id="sum-job">—</b></div>
        <div class="confirm-row"><span>소속</span><b id="sum-faction">—</b></div>
        <p class="warn">${icon('shield', 16)} 이름·직업·소속은 생성 후 변경할 수 없습니다. 이름은 다른 조사원과 중복될 수 없습니다.</p>
        <p class="form-msg" id="create-msg"></p>
        <button class="btn primary block" type="submit" id="create-btn">이 조사원으로 입국하기</button>
      </section>
    </form>
  </div>`));
  const form = $('#create-form');
  const sync = () => {
    $('#sum-name').textContent = form.name.value.trim() || '—';
    $('#sum-job').textContent = pick.job ? JOBS[pick.job].name : '—';
    $('#sum-faction').textContent = pick.faction ? FACTIONS[pick.faction].name : '—';
  };
  if (typeof draft.name === 'string') form.name.value = draft.name.slice(0, 12);
  for (const kind of ['job', 'faction']) if (pick[kind]) $$(`[data-${kind}]`, form).forEach(x => x.setAttribute('aria-pressed', x.dataset[kind] === pick[kind]));
  sync();
  form.addEventListener('input', () => { sync(); saveDraft(); });
  form.addEventListener('click', e => {
    const b = e.target.closest('.choice-card'); if (!b) return;
    const kind = b.dataset.job ? 'job' : 'faction';
    pick[kind] = b.dataset[kind];
    $$(`[data-${kind}]`, form).forEach(x => x.setAttribute('aria-pressed', x === b));
    sync(); saveDraft();
  });
  $('#create-logout').onclick = () => logout();
  form.onsubmit = async e => {
    e.preventDefault();
    const name = form.name.value.trim(), msg = $('#create-msg');
    const say = t => { msg.textContent = t; msg.classList.add('show'); };
    if (name.length < 2 || name.length > 12) return say('이름은 2~12자로 입력하세요.');
    if (!/^[가-힣A-Za-z0-9 ]+$/.test(name)) return say('이름에는 한글·영문·숫자·공백만 사용할 수 있습니다.');
    if (!pick.job) return say('직업을 선택하세요.');
    if (!pick.faction) return say('소속을 선택하세요.');
    const btn = $('#create-btn'); btn.disabled = true;
    try {
      await rpc('world_create_character_v2', { p_name: name, p_job: pick.job, p_faction: pick.faction });
      const made = await loadCharacter();
      if (!made) throw new Error('캐릭터 정보를 불러오지 못했습니다. 새로고침해 주세요.');
      markPending(made.owner_id);
      try { localStorage.removeItem(draftKey); } catch {}
      toast(`${name} 조사원으로 입국했습니다.`, 'ok');
      renderGame();
    } catch (err) { say(friendlyError(err)); btn.disabled = false; }
  };
}

/* ── 사망 ────────────────────────────────────────────────── */
function renderDeath(c) {
  document.title = '야행국 · 영면';
  app.replaceChildren(h(`<div class="center-screen"><div class="card narrow death-card">
    <div class="seal seal-lg">夜</div><h1>${esc(c.character_name)}, 영면하다</h1>
    <p class="muted">${esc(c.death_reason || '구조를 받지 못하고 숨을 거두었습니다.')} · ${c.died_at ? new Date(c.died_at).toLocaleString('ko-KR') : ''}</p>
    <p>마지막으로 머문 ${esc(c.location)}에 시신이 남았습니다. 다른 조사원이 명복을 빌고 유품을 수습할 수 있습니다.</p>
    <button class="btn primary block" id="reborn">${icon('plus', 16)}<span>새 조사원으로 다시 시작</span></button>
    <button class="btn ghost block" id="death-logout">${icon('logout', 16)}<span>로그아웃</span></button></div></div>`));
  $('#death-logout').onclick = () => logout();
  $('#reborn').onclick = e => guard(e.currentTarget, async () => { await rpc('world_character_delete', { p_confirm: c.character_name }); await loadCharacter(); return { content: '새 조사원을 만드세요.' }; });
}

/* ── 게임 화면 ──────────────────────────────────────────── */
let current = null;
function renderGame() {
  window.dispatchEvent(new Event('yh-booted'));
  document.title = '야행국';
  const tabs = Object.entries(VIEWS).map(([k, v]) => `<a href="#/${k}" data-view="${k}" aria-label="${v.label}" title="${v.label}">${icon(v.icon, 20)}<span>${v.label}</span></a>`).join('');
  app.replaceChildren(h(`
  <div class="shell">
    <header class="topbar">
      <a class="brand" href="#/home"><span class="seal">夜</span><span class="brand-name">야행국</span></a>
      <nav class="topnav" aria-label="주요 메뉴">${tabs}</nav>
      <div class="top-actions">
        <button class="icon-btn" id="btn-bell" aria-label="알림">${icon('bell')}<i class="dot" hidden></i></button>
        <button class="icon-btn" id="btn-whisper" aria-label="귓속말" title="귓속말">${icon('letter')}</button>
        <a class="icon-btn" href="#/party" data-page="party" aria-label="동료" title="동료">${icon('users')}</a>
        <a class="icon-btn" href="#/guide" data-page="guide" aria-label="도움말" title="도움말">${icon('help')}</a>
        <a class="icon-btn" href="#/settings" data-page="settings" aria-label="설정 (프로필·테마·소리·계정·로그아웃)" title="설정 · 프로필 · 테마 · 로그아웃">${icon('gear')}</a>
      </div>
    </header>
    <div class="travel-banner" id="travel-banner" hidden></div>
    <div class="layout">
      <aside class="hud" id="hud" aria-label="캐릭터 상태"></aside>
      <main class="main" id="main"><div id="view"></div></main>
      <aside class="chat-col" id="chat-col" aria-label="채팅"></aside>
    </div>
    <nav class="tabbar" aria-label="주요 메뉴">${tabs}</nav>
    <button class="chat-fab" id="chat-fab" aria-label="채팅 열기">${icon('chat', 22)}</button>
  </div>`));
  mountTravelBanner($('#travel-banner'));
  mountNotifications($('#btn-bell'));
  mountHud($('#hud'));
  mountEnv();
  mountChat($('#chat-col'), $('#chat-fab'));
  mountWhisper($('#btn-whisper'));
  mountVersionCheck(); // 배포·SQL 적용 뒤 새로고침 안내
  mountBug(); // 제보 창은 도움말·설정 페이지의 단추와 알림에서 연다
  mountTitleDot();
  if (!location.hash.startsWith('#/')) location.replace('#/home');
  // 지역·아이템 이름을 먼저 받아 두어 내부 코드가 화면에 보이지 않게 한다.
  const names = Promise.allSettled([preloadNames(), loadStaff()]);
  if (hasNameCache()) { onHash(); names.finally(maybeStartTutorial); }
  else names.finally(() => { onHash(); maybeStartTutorial(); });
}

function parseHash() {
  const [, view = 'home', sub = ''] = location.hash.match(/^#\/([a-z]+)\/?([a-z0-9.-]*)/) || [];
  return { view: VIEWS[view] || PAGES[view] ? view : 'home', sub };
}
async function onHash() {
  if (!$('.shell')) return;
  const { view, sub } = parseHash();
  $$('[data-view]').forEach(a => a.classList.toggle('on', a.dataset.view === view));
  markHeader(view, sub);
  const entry = VIEWS[view] || PAGES[view];
  const el = $('#view');
  if (current?.mod?.destroy) { try { current.mod.destroy(); } catch (e) { console.error(e); } }
  current = { name: view, mod: entry.mod };
  el.replaceChildren();
  el.dataset.view = view;
  $('#main').scrollTop = 0; window.scrollTo(0, 0);
  try { await entry.mod.render(el, sub); }
  catch (e) { console.error(e); el.replaceChildren(h(`<div class="card"><h2>화면을 불러오지 못했습니다</h2><p class="muted">${esc(friendlyError(e))}</p></div>`)); }
}
// 헤더 단추 강조: 테마(설정의 테마 칸)와 게임 설정(나머지 칸)이 함께 켜지지 않게 한다.
function markHeader(view, sub) {
  $$('[data-page]').forEach(a => {
    const want = a.dataset.pageSub;
    const subOk = !want || (want.startsWith('!') ? sub !== want.slice(1) : sub === want);
    a.classList.toggle('on', a.dataset.page === view && subOk);
  });
}
window.addEventListener('yh-subpage', () => { const { view, sub } = parseHash(); markHeader(view, sub); });
window.addEventListener('hashchange', onHash);
export function go(view, sub = '') { const target = `#/${view}${sub ? '/' + sub : ''}`; if (location.hash === target) onHash(); else location.hash = target; }
window.yahangGo = go;
mountGrowth(); // 레벨·숙련이 오르면 화면 위에 잠깐 알린다

// 다른 계정으로 바뀌거나 캐릭터가 사라지면 처음 흐름으로 돌아간다.
on('character', c => { if (!store.user) return; if (!c && ($('.shell') || $('.death-card'))) renderCreate(); else if (c?.is_dead && $('.shell')) renderDeath(c); });
emit('boot');
