// 헤더 설정: 도움말 · 프로필 설정 · 테마 · 게임 설정(음향) · 알림
import { db, store, on, rpc, act, nameOf, esc, icon, h, $, $$, openModal, closeModal, toast, guard, friendlyError, fmt } from './core.js';

/* ── 테마 프리셋 10종 ─────────────────────────────────────
   bg / surface / surface2 / line / text / muted / accent / accentInk / gold / glow */
export const THEMES = [
  { id: 'yahang', name: '야행', desc: '먹빛 밤과 주홍 등불', c: ['#0c0a0e', '#16131a', '#1e1a23', '#2e2733', '#efe7da', '#a39889', '#c8432d', '#fff4ea', '#d1a65a', '#c8432d'] },
  { id: 'lantern', name: '청등', desc: '푸른 등롱이 켜진 항구', c: ['#080d16', '#101826', '#162132', '#243349', '#e4ecf5', '#8d9cb0', '#3aa6c9', '#06141c', '#b9c7d6', '#2d8fb3'] },
  { id: 'jade', name: '비취', desc: '이끼 낀 사당과 옥빛', c: ['#08100d', '#0f1a16', '#15241f', '#233830', '#e3efe8', '#8ea79a', '#3fae8a', '#04140e', '#d7c487', '#2f9677'] },
  { id: 'palace', name: '자금', desc: '금지된 궁의 보랏빛', c: ['#0e0a12', '#18121e', '#21192a', '#33283f', '#efe6f3', '#a597b0', '#9b5cd6', '#fbf4ff', '#e0b38a', '#7d45b8'] },
  { id: 'maple', name: '단풍', desc: '가을 산사의 늦은 밤', c: ['#100b08', '#1b130e', '#251a13', '#3a2a1f', '#f1e6db', '#ab9a89', '#e0742c', '#1a0c03', '#e8c27a', '#c45f1e'] },
  { id: 'moonwhite', name: '월백', desc: '달빛 아래 잿빛 도시', c: ['#0d0e10', '#16181b', '#1e2125', '#2e3238', '#eceef1', '#9aa0a8', '#d9dde3', '#111317', '#9ec3e6', '#7f9bb8'] },
  { id: 'bloodmoon', name: '혈월', desc: '붉은 달이 뜬 금단지', c: ['#0d0608', '#1a0c10', '#241116', '#3b1c23', '#f3e3e5', '#b0929a', '#d22e45', '#fff1f3', '#c99761', '#a31d33'] },
  { id: 'ghostfire', name: '귀화', desc: '도깨비불이 떠도는 숲', c: ['#060d0d', '#0c1717', '#122121', '#1e3434', '#e0f2ef', '#8aa8a3', '#5fe0b4', '#03130d', '#9fd0ff', '#2fb38a'] },
  { id: 'goldorchid', name: '금란', desc: '황금 난초의 정원', c: ['#0d0c07', '#18160d', '#211e12', '#363120', '#f2ecd9', '#a9a185', '#d8b04a', '#171103', '#efe2b5', '#b38d2b'] },
  { id: 'snownight', name: '설야', desc: '눈 내린 북령의 밤', c: ['#0a0d12', '#131820', '#1a212c', '#2a3443', '#e9f0f7', '#94a2b4', '#7fb6ff', '#06101e', '#dbe6f2', '#5b93e0'] },
];
const VARS = ['--bg', '--surface', '--surface-2', '--line', '--text', '--muted', '--accent', '--accent-ink', '--gold', '--glow'];
export function applyTheme(id, save = true) {
  const t = THEMES.find(x => x.id === id) || THEMES[0];
  VARS.forEach((v, i) => document.documentElement.style.setProperty(v, t.c[i]));
  document.documentElement.dataset.theme = t.id;
  document.querySelector('meta[name=theme-color]')?.setAttribute('content', t.c[0]);
  if (save) try { localStorage.setItem('yh-theme', t.id); } catch {}
}
export function applySavedTheme() {
  let id = null;
  try { id = localStorage.getItem('yh-theme'); if (!id) { const old = Number(localStorage.getItem('yae-theme')); if (Number.isInteger(old) && THEMES[old]) id = THEMES[old].id; } } catch {}
  applyTheme(id || 'yahang', false);
}
export function openTheme() {
  const cur = document.documentElement.dataset.theme;
  const body = h(`<div class="theme-grid">${THEMES.map(t => `
    <button class="theme-card ${t.id === cur ? 'on' : ''}" data-id="${t.id}" style="--tb:${t.c[0]};--ts:${t.c[1]};--tl:${t.c[3]};--tt:${t.c[4]};--ta:${t.c[6]};--tg:${t.c[8]}">
      <span class="tc-preview"><i></i><i></i><i></i></span><b>${esc(t.name)}</b><small>${esc(t.desc)}</small></button>`).join('')}</div>`);
  body.addEventListener('click', e => {
    const b = e.target.closest('.theme-card'); if (!b) return;
    applyTheme(b.dataset.id); $$('.theme-card', body).forEach(x => x.classList.toggle('on', x === b));
  });
  openModal({ title: '테마', body, wide: true });
}

/* ── 음향: 배경음(앰비언트)과 효과음, 개별 음량 ──────────────────── */
const sound = { bgm: 0.35, sfx: 0.6, bgmOn: false, sfxOn: true };
let ctx, bgmGain, sfxGain, bgmNodes = [], bellTimer;
export function initSound() {
  try { Object.assign(sound, JSON.parse(localStorage.getItem('yh-sound') || '{}')); } catch {}
  on('changed', () => playSfx('chime'));
  document.addEventListener('click', e => { if (e.target.closest('.btn, .segmented button, .tabbar a, .topnav a')) playSfx('tap'); }, { capture: true });
}
function saveSound() { try { localStorage.setItem('yh-sound', JSON.stringify(sound)); } catch {} }
function ensureCtx() {
  if (ctx) return ctx;
  const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return null;
  ctx = new AC(); bgmGain = ctx.createGain(); sfxGain = ctx.createGain();
  bgmGain.connect(ctx.destination); sfxGain.connect(ctx.destination);
  bgmGain.gain.value = sound.bgm * 0.25; sfxGain.gain.value = sound.sfx * 0.5;
  return ctx;
}
function startBgm() {
  if (!ensureCtx() || bgmNodes.length) return;
  ctx.resume?.();
  // 낮은 지속음 두 개와 가끔 울리는 풍경 소리로 밤 분위기를 만든다.
  [[55, 'sine'], [82.4, 'triangle']].forEach(([f, type]) => {
    const o = ctx.createOscillator(), g = ctx.createGain(), lfo = ctx.createOscillator(), lg = ctx.createGain();
    o.type = type; o.frequency.value = f; g.gain.value = 0.5;
    lfo.frequency.value = 0.07; lg.gain.value = 0.25; lfo.connect(lg); lg.connect(g.gain);
    o.connect(g); g.connect(bgmGain); o.start(); lfo.start(); bgmNodes.push(o, lfo);
  });
  const bell = () => { if (!bgmNodes.length) return; tone([523.3, 659.3, 784, 880][Math.floor(Math.random() * 4)], 2.8, bgmGain, 0.18); bellTimer = setTimeout(bell, 5000 + Math.random() * 9000); };
  bellTimer = setTimeout(bell, 2500);
}
function stopBgm() { bgmNodes.forEach(n => { try { n.stop(); } catch {} }); bgmNodes = []; clearTimeout(bellTimer); }
function tone(freq, dur, out, vol = 0.3) {
  const o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'sine'; o.frequency.value = freq;
  g.gain.setValueAtTime(0.0001, ctx.currentTime); g.gain.exponentialRampToValueAtTime(vol, ctx.currentTime + 0.02);
  g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + dur); o.connect(g); g.connect(out); o.start(); o.stop(ctx.currentTime + dur + 0.05);
}
export function playSfx(kind) {
  if (!sound.sfxOn || !ctx) return;
  if (kind === 'tap') tone(880, 0.08, sfxGain, 0.12); else tone(660, 0.5, sfxGain, 0.2);
}
export function openSound() {
  const body = h(`<div class="settings-form">
    <label class="toggle-row"><span><b>배경음</b><small>밤거리 분위기의 잔잔한 소리</small></span><input type="checkbox" id="s-bgm-on" ${sound.bgmOn ? 'checked' : ''}></label>
    <label class="range-row"><span>배경음 음량</span><input type="range" id="s-bgm" min="0" max="1" step="0.05" value="${sound.bgm}"></label>
    <label class="toggle-row"><span><b>효과음</b><small>버튼과 행동 완료 소리</small></span><input type="checkbox" id="s-sfx-on" ${sound.sfxOn ? 'checked' : ''}></label>
    <label class="range-row"><span>효과음 음량</span><input type="range" id="s-sfx" min="0" max="1" step="0.05" value="${sound.sfx}"></label>
    <p class="muted small">설정은 이 기기에 저장됩니다.</p></div>`);
  body.addEventListener('input', e => {
    const t = e.target; ensureCtx();
    if (t.id === 's-bgm') { sound.bgm = Number(t.value); bgmGain.gain.value = sound.bgm * 0.25; }
    if (t.id === 's-sfx') { sound.sfx = Number(t.value); sfxGain.gain.value = sound.sfx * 0.5; playSfx('tap'); }
    if (t.id === 's-bgm-on') { sound.bgmOn = t.checked; t.checked ? startBgm() : stopBgm(); }
    if (t.id === 's-sfx-on') sound.sfxOn = t.checked;
    saveSound();
  });
  openModal({ title: '게임 설정', body });
}
document.addEventListener('pointerdown', () => { if (sound.bgmOn && !bgmNodes.length) startBgm(); else ensureCtx(); }, { once: true });

/* ── 프로필 설정 (읽기 전용 신원 + 계정) ─────────────────────────── */
export function openAccount() {
  const c = store.character || {};
  const body = h(`<div class="account">
    <div class="account-id"><div class="avatar lg">${esc((c.character_name || '?').slice(0, 1))}</div>
      <div><h3>${esc(c.character_name || '')}</h3><p>${esc(nameOf(c.job_key))} · ${esc(nameOf(c.faction_key))}</p></div></div>
    <dl class="kv">
      <dt>계정</dt><dd>${esc(store.user?.email || '')}</dd>
      <dt>이름</dt><dd>${esc(c.character_name || '')}</dd>
      <dt>직업</dt><dd>${esc(nameOf(c.job_key))}</dd>
      <dt>소속</dt><dd>${esc(nameOf(c.faction_key))}</dd>
      <dt>대세력</dt><dd>${c.major_faction_id ? esc(nameOf(c.major_faction_id)) : '미가입 · 의뢰 > 세력에서 가입'}</dd>
    </dl>
    <p class="note">${icon('shield', 16)} 이름·직업·소속은 캐릭터를 만들 때 정해지며 변경할 수 없습니다.</p>
    <button class="btn danger block" id="acc-logout">${icon('logout', 16)}<span>로그아웃</span></button></div>`);
  $('#acc-logout', body).onclick = async () => { closeModal(); await db.auth.signOut(); };
  openModal({ title: '프로필 설정', body });
}

/* ── 도움말 ──────────────────────────────────────────────── */
const HELP = [
  ['시작하기', '야행국은 여러 조사원이 같은 세계를 공유하는 RPG입니다. 위치를 옮기며 지역을 탐사하고, 전투·채집·제작·사건 조사로 성장합니다. 진행 상황은 모두 서버에 저장됩니다.'],
  ['화면 구성', 'PC에서는 왼쪽에 캐릭터 상태와 지금 진행 중인 일(이동·자율 활동·전투·원정)이, 오른쪽에 채팅이 항상 보입니다. 모바일에서는 위쪽 상태 띠를 누르면 자세히 볼 수 있고, 오른쪽 아래 버튼으로 채팅을 엽니다.'],
  ['이동', '지도에서 지역을 누르면 정보와 예상 이동 시간이 나옵니다. 현재 위치와 길이 이어진 지역만 바로 갈 수 있습니다. 이동은 실제 시간이 걸리며, 탈것을 장착하면 빨라지지만 이동마다 노정패를 씁니다. 도착하면 자동으로 위치가 바뀝니다.'],
  ['탐사와 채집', '현장 탭의 지점 탐사로 물자와 단서를 찾습니다. 지도 > 세부 탐사에서 세부 지역(5단계)까지 들어가 파밍 지점을 수색하고 채집할 수 있습니다. 같은 지점은 재사용 대기시간이 지나야 다시 채집할 수 있습니다.'],
  ['전투', '현장 탭에서 조우를 시작하면 전투가 열립니다. 공격 외에 원거리·봉인·분석·지원·방어 전술이 있고, 직업에 따라 효율이 다릅니다. 전투 중에는 이동할 수 없습니다. 체력이 0이 되면 전투불능이 되어 회복 부적이나 다른 조사원의 구조가 필요합니다.'],
  ['제작', '가방 > 제작에서 재료가 있으면 어디서나 만들 수 있습니다. 제작법에 표시된 장소에서 만들면 품질이 더 높아집니다. 품질이 높으면 결과물을 추가로 얻습니다.'],
  ['원정', '원정은 위험한 지역에 오래 머물기 전에 회복품을 따로 챙겨 두는 기능입니다. ① 지도 > 이동·원정에서 가져갈 회복품을 고르고 원정을 시작하면 ② 원정 중 회복품은 꾸러미에서 먼저 사용됩니다. ③ 돌아오면 철수해 남은 보급품을 가방으로 돌려받습니다.'],
  ['자율 활동', '캐릭터 > 자율 활동에서 수련·조사·정비·휴식을 30분~8시간 맡겨 둘 수 있습니다. 접속하지 않아도 시간이 흐르며, 끝나면 보상을 직접 수령합니다.'],
  ['파티와 동승', '의뢰 > 파티에서 파티를 만들고 초대합니다. 같은 지역의 파티원에게 동승을 요청하면 수락 즉시 함께 출발합니다. 탈것 운임은 요청한 파티장만 한 번 냅니다.'],
  ['경제', '화폐 단위는 전입니다. 상점 재고는 하루 세 번 바뀝니다. 거래소에서 다른 조사원과 아이템을 사고팔 수 있으며, 0전 등록과 희귀 성장 아이템 거래는 막혀 있습니다.'],
  ['사건과 세력', '의뢰 > 사건에서 단서를 모아 가설을 조합합니다. 의뢰 > 세력에서 대세력에 가입하면 전용 거점 활동과 세력 채팅을 이용할 수 있습니다.'],
];
export function openHelp() {
  const body = h(`<div class="help">${HELP.map(([t, d], i) => `<details ${i < 2 ? 'open' : ''}><summary>${esc(t)}</summary><p>${esc(d)}</p></details>`).join('')}</div>`);
  openModal({ title: '도움말', body, wide: true });
}

/* ── 알림 ────────────────────────────────────────────────── */
let notes = [], bell;
export function mountNotifications(btn) {
  bell = btn;
  bell.onclick = openNotifications;
  loadNotes();
  try {
    db.channel('yh-notes').on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'world_notifications' }, p => {
      if (p.new?.user_id !== store.user?.id) return;
      notes.unshift(p.new); drawDot(); toast(p.new.title || '새 알림', 'info');
    }).subscribe();
  } catch {}
  setInterval(() => { if (!document.hidden) loadNotes(); }, 120000);
}
async function loadNotes() {
  try {
    const { data, error } = await db.from('world_notifications').select('*').is('read_at', null).order('created_at', { ascending: false }).limit(30);
    if (error) throw error; notes = data || []; drawDot();
  } catch {}
}
function drawDot() { const d = bell?.querySelector('.dot'); if (d) { d.hidden = !notes.length; d.textContent = notes.length > 9 ? '9+' : String(notes.length || ''); } }
function openNotifications() {
  const body = h(`<div class="notes">${notes.length ? notes.map((n, i) => `<article class="note-item">
      <div><b>${esc(n.title || '알림')}</b><p>${esc(n.content || '')}</p><time>${fmt.time(n.created_at)}</time></div>
      <div class="note-actions">${n.kind === 'rescue_request' && n.payload?.target_id ? `<button class="btn primary small" data-rescue="${i}">구조</button>` : ''}
        <button class="btn ghost small" data-read="${i}">확인</button></div></article>`).join('') : '<p class="muted">새 알림이 없습니다.</p>'}</div>`);
  body.addEventListener('click', async e => {
    const r = e.target.closest('[data-read]'), s = e.target.closest('[data-rescue]');
    if (r) { const n = notes[Number(r.dataset.read)]; await guard(r, () => rpc('world_mark_notification_read', { p_id: n.id }), { success: '' }); notes = notes.filter(x => x !== n); drawDot(); r.closest('.note-item').remove(); }
    if (s) { const n = notes[Number(s.dataset.rescue)]; await guard(s, () => act('world_rescue_character', { p_target: n.payload.target_id })); }
  });
  openModal({ title: '알림', body });
}
