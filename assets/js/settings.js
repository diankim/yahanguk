// 헤더 설정: 프로필 · 테마(프리셋·흑백·직접 설정) · 게임 설정(음향) · 알림
import { db, store, on, rpc, act, esc, icon, h, $, $$, openModal, closeModal, toast, guard, fmt, emblem, profileOf, EMBLEMS, EMBLEM_COLORS, loadCharacter, nameOf, JOBS } from './core.js';

/* ── 테마 ────────────────────────────────────────────────
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
  { id: 'ink', name: '흑', desc: '먹 한 가지로 칠한 흑백', c: ['#000000', '#0d0d0d', '#171717', '#2a2a2a', '#f2f2f2', '#9a9a9a', '#ffffff', '#000000', '#cfcfcf', '#555555'] },
  { id: 'paper', name: '백', desc: '한지 위의 먹 글씨', light: true, c: ['#f4f0e8', '#fbf8f2', '#efe9df', '#d8cfc1', '#1f1b16', '#6e655a', '#b23a26', '#ffffff', '#8a6420', '#d9a38f'] },
];
const VARS = ['--bg', '--surface', '--surface-2', '--line', '--text', '--muted', '--accent', '--accent-ink', '--gold', '--glow'];

// 직접 설정: 바탕·강조·포인트 세 가지 색만 고르면 나머지는 어울리게 만든다.
const hex = s => { const m = /^#?([0-9a-f]{6})$/i.exec(s || ''); if (!m) return null; const n = parseInt(m[1], 16); return [n >> 16, n >> 8 & 255, n & 255]; };
const toHex = rgb => '#' + rgb.map(v => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, '0')).join('');
const mix = (a, b, t) => toHex(hex(a).map((v, i) => v + (hex(b)[i] - v) * t));
const lum = c => { const [r, g, b] = hex(c).map(v => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
function derive({ bg, accent, gold }) {
  const light = lum(bg) > 0.45, text = light ? '#1d1a17' : '#efeae2';
  return { light, c: [bg, mix(bg, text, 0.05), mix(bg, text, 0.09), mix(bg, text, 0.18), text, mix(text, bg, 0.42), accent, lum(accent) > 0.45 ? '#111111' : '#ffffff', gold, accent] };
}
function readCustom() { try { return JSON.parse(localStorage.getItem('yh-theme-custom') || 'null'); } catch { return null; } }

export function applyTheme(id, save = true) {
  let t = THEMES.find(x => x.id === id), light = false, colors;
  if (id === 'custom' && readCustom()) { const d = derive(readCustom()); colors = d.c; light = d.light; }
  else { t = t || THEMES[0]; colors = t.c; light = !!t.light; id = t.id; }
  VARS.forEach((v, i) => document.documentElement.style.setProperty(v, colors[i]));
  document.documentElement.dataset.theme = id;
  document.documentElement.dataset.tone = light ? 'light' : 'dark';
  document.documentElement.style.colorScheme = light ? 'light' : 'dark';
  document.querySelector('meta[name=theme-color]')?.setAttribute('content', colors[0]);
  if (save) try { localStorage.setItem('yh-theme', id); } catch {}
}
export function applySavedTheme() {
  let id = null;
  try { id = localStorage.getItem('yh-theme'); if (!id) { const old = Number(localStorage.getItem('yae-theme')); if (Number.isInteger(old) && THEMES[old]) id = THEMES[old].id; } } catch {}
  applyTheme(id || 'yahang', false);
}
export function openTheme() {
  const cur = document.documentElement.dataset.theme;
  const custom = readCustom() || { bg: '#101014', accent: '#c8432d', gold: '#d1a65a' };
  const card = t => `<button class="theme-card ${t.id === cur ? 'on' : ''}" data-id="${t.id}" style="--tb:${t.c[0]};--ts:${t.c[1]};--tl:${t.c[3]};--tt:${t.c[4]};--ta:${t.c[6]};--tg:${t.c[8]}">
      <span class="tc-preview"><i></i><i></i><i></i></span><b>${esc(t.name)}</b><small>${esc(t.desc)}</small></button>`;
  const body = h(`<div class="theme-modal">
    <h3 class="sub-h">프리셋</h3>
    <div class="theme-grid">${THEMES.map(card).join('')}</div>
    <h3 class="sub-h">직접 설정</h3>
    <div class="custom-theme ${cur === 'custom' ? 'on' : ''}">
      <label class="color-row"><span>바탕</span><input type="color" name="bg" value="${custom.bg}"></label>
      <label class="color-row"><span>강조</span><input type="color" name="accent" value="${custom.accent}"></label>
      <label class="color-row"><span>포인트</span><input type="color" name="gold" value="${custom.gold}"></label>
      <p class="muted small">바탕색이 밝으면 글자가 자동으로 어두워집니다. 세 가지 색에서 나머지 색을 만들어 씁니다.</p>
      <button class="btn primary" id="apply-custom">${icon('check', 16)}<span>이 색으로 적용</span></button>
    </div></div>`);
  const mark = id => { $$('.theme-card', body).forEach(x => x.classList.toggle('on', x.dataset.id === id)); $('.custom-theme', body).classList.toggle('on', id === 'custom'); };
  body.addEventListener('click', e => { const b = e.target.closest('.theme-card'); if (!b) return; applyTheme(b.dataset.id); mark(b.dataset.id); });
  const pick = () => ({ bg: $('[name=bg]', body).value, accent: $('[name=accent]', body).value, gold: $('[name=gold]', body).value });
  $$('input[type=color]', body).forEach(i => i.oninput = () => { try { localStorage.setItem('yh-theme-custom', JSON.stringify(pick())); } catch {} applyTheme('custom', false); mark('custom'); });
  $('#apply-custom', body).onclick = () => { try { localStorage.setItem('yh-theme-custom', JSON.stringify(pick())); } catch {} applyTheme('custom'); mark('custom'); toast('직접 설정한 테마를 적용했습니다.', 'ok'); };
  openModal({ title: '테마', body, wide: true });
}

/* ── 음향: 배경음과 상황별 효과음, 개별 음량 ───────────────────────── */
const sound = { bgm: 0.35, sfx: 0.6, bgmOn: false, sfxOn: true };
let ctx, bgmGain, sfxGain, bgmNodes = [], bellTimer;
// 행동 RPC → 효과음 종류
const SFX_OF = [
  [/shop_buy|shop_sell|trade_offer|mount_acquire/, 'coin'], [/craft/, 'craft'], [/region_tactic|region_combat|region_encounter/, 'hit'],
  [/travel_region|travel_party/, 'travel'], [/expedition_launch/, 'drum'], [/expedition_finish|claim|case_combine|mission_action|faction_supply/, 'reward'],
  [/gather|site_explore|exploration/, 'leaf'], [/equip|title_equip|allocate/, 'equip'], [/rest|survival|recovery|status_treat/, 'heal'],
];
export function initSound() {
  try { Object.assign(sound, JSON.parse(localStorage.getItem('yh-sound') || '{}')); } catch {}
  on('changed', ({ name }) => playSfx((SFX_OF.find(([re]) => re.test(name)) || [, 'chime'])[1]));
  window.addEventListener('yh-sfx', e => playSfx(e.detail));
  document.addEventListener('click', e => {
    const b = e.target.closest('.btn, .segmented button, .tabbar a, .topnav a, .icon-btn'); if (!b || b.disabled) return;
    playSfx(b.closest('.tabbar, .topnav') ? 'nav' : b.closest('.segmented') ? 'tab' : b.classList.contains('primary') ? 'confirm' : 'tap');
  }, { capture: true });
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
function tone(freq, dur, out, vol = 0.3, type = 'sine', at = 0, glide) {
  const t0 = ctx.currentTime + at, o = ctx.createOscillator(), g = ctx.createGain(); o.type = type; o.frequency.setValueAtTime(freq, t0);
  if (glide) o.frequency.exponentialRampToValueAtTime(glide, t0 + dur);
  g.gain.setValueAtTime(0.0001, t0); g.gain.exponentialRampToValueAtTime(vol, t0 + 0.015);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur); o.connect(g); g.connect(out); o.start(t0); o.stop(t0 + dur + 0.05);
}
function noise(dur, out, vol = 0.2, at = 0, freq = 1200) {
  const t0 = ctx.currentTime + at, buf = ctx.createBuffer(1, Math.ceil(ctx.sampleRate * dur), ctx.sampleRate), d = buf.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / d.length);
  const s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
  s.buffer = buf; f.type = 'bandpass'; f.frequency.value = freq; g.gain.value = vol; s.connect(f); f.connect(g); g.connect(out); s.start(t0);
}
const SFX = {
  tap: () => tone(880, 0.06, sfxGain, 0.08, 'triangle'),
  nav: () => tone(520, 0.09, sfxGain, 0.1, 'sine', 0, 640),
  tab: () => tone(700, 0.05, sfxGain, 0.07, 'square'),
  confirm: () => { tone(660, 0.1, sfxGain, 0.14); tone(990, 0.14, sfxGain, 0.1, 'sine', 0.06); },
  coin: () => { tone(1320, 0.12, sfxGain, 0.12, 'triangle'); tone(1760, 0.2, sfxGain, 0.1, 'triangle', 0.07); },
  craft: () => { noise(0.08, sfxGain, 0.35, 0, 3200); tone(420, 0.25, sfxGain, 0.12, 'square', 0.02, 300); noise(0.06, sfxGain, 0.25, 0.16, 2600); },
  hit: () => { noise(0.12, sfxGain, 0.4, 0, 600); tone(160, 0.18, sfxGain, 0.2, 'sawtooth', 0, 70); },
  travel: () => { tone(220, 0.5, sfxGain, 0.15, 'triangle', 0, 330); tone(330, 0.5, sfxGain, 0.1, 'sine', 0.2, 440); },
  arrive: () => [523, 659, 784].forEach((f, i) => tone(f, 0.9, sfxGain, 0.12, 'sine', i * 0.08)),
  drum: () => { tone(90, 0.35, sfxGain, 0.3, 'sine', 0, 50); tone(90, 0.35, sfxGain, 0.25, 'sine', 0.22, 50); },
  reward: () => [784, 988, 1175, 1568].forEach((f, i) => tone(f, 0.25, sfxGain, 0.1, 'triangle', i * 0.07)),
  leaf: () => noise(0.18, sfxGain, 0.2, 0, 4200),
  equip: () => { noise(0.05, sfxGain, 0.3, 0, 5000); tone(1200, 0.08, sfxGain, 0.08, 'square', 0.03); },
  heal: () => tone(440, 0.6, sfxGain, 0.12, 'sine', 0, 660),
  chime: () => tone(660, 0.4, sfxGain, 0.15),
  error: () => { tone(200, 0.2, sfxGain, 0.15, 'square'); tone(150, 0.25, sfxGain, 0.12, 'square', 0.12); },
};
export function playSfx(kind) {
  if (!sound.sfxOn || !ensureCtx()) return;
  try { (SFX[kind] || SFX.tap)(); } catch {}
}
export function openSound() {
  const body = h(`<div class="settings-form">
    <label class="toggle-row"><span><b>배경음</b><small>밤거리 분위기의 잔잔한 소리</small></span><input type="checkbox" id="s-bgm-on" ${sound.bgmOn ? 'checked' : ''}></label>
    <label class="range-row"><span>배경음 음량</span><input type="range" id="s-bgm" min="0" max="1" step="0.05" value="${sound.bgm}"></label>
    <label class="toggle-row"><span><b>효과음</b><small>이동·전투·거래·제작마다 다른 소리</small></span><input type="checkbox" id="s-sfx-on" ${sound.sfxOn ? 'checked' : ''}></label>
    <label class="range-row"><span>효과음 음량</span><input type="range" id="s-sfx" min="0" max="1" step="0.05" value="${sound.sfx}"></label>
    <div class="sfx-preview">${['confirm', 'coin', 'craft', 'hit', 'travel', 'reward'].map(k => `<button class="btn small" data-try="${k}">${({ confirm: '확인', coin: '거래', craft: '제작', hit: '전투', travel: '출발', reward: '보상' })[k]}</button>`).join('')}</div>
    <a class="btn block" href="#/account">${icon('idcard', 16)}<span>계정 관리 (이메일·비밀번호)</span></a>
    <p class="muted small">음향 설정은 이 기기에 저장됩니다.</p></div>`);
  body.addEventListener('input', e => {
    const t = e.target; ensureCtx();
    if (t.id === 's-bgm') { sound.bgm = Number(t.value); bgmGain.gain.value = sound.bgm * 0.25; }
    if (t.id === 's-sfx') { sound.sfx = Number(t.value); sfxGain.gain.value = sound.sfx * 0.5; playSfx('tap'); }
    if (t.id === 's-bgm-on') { sound.bgmOn = t.checked; t.checked ? startBgm() : stopBgm(); }
    if (t.id === 's-sfx-on') sound.sfxOn = t.checked;
    saveSound();
  });
  body.addEventListener('click', e => { const b = e.target.closest('[data-try]'); if (b) { e.stopPropagation(); playSfx(b.dataset.try); } if (e.target.closest('a[href="#/account"]')) closeModal(); });
  openModal({ title: '게임 설정', body });
}
document.addEventListener('pointerdown', () => { if (sound.bgmOn && !bgmNodes.length) startBgm(); else ensureCtx(); }, { once: true });

/* ── 캐릭터 프로필: 문장·색·소개 (이름·직업·소속은 고정) ───────────────── */
export function openProfile() {
  const c = store.character || {}, cur = profileOf(c.owner_id, c.profile);
  const pick = { ...cur };
  const body = h(`<div class="profile-edit">
    <div class="profile-card"><div class="pc-emblem">${emblem(c.owner_id, pick, 72)}</div>
      <div><h3>${esc(c.character_name || '')}</h3><p>${esc(nameOf(c.job_key))} · ${esc(nameOf(c.faction_key))}${c.major_faction_id ? ' · ' + esc(nameOf(c.major_faction_id)) : ''}</p><p class="muted small">Lv.${c.level || 1} · ${esc(JOBS[c.job_key]?.trait || '')}</p></div></div>
    <h3 class="sub-h">문장</h3><div class="emblem-grid">${Object.entries(EMBLEMS).map(([k, [n]]) => `<button class="em-pick" data-em="${k}" aria-label="${n}">${emblem('x', { emblem: k, color: pick.color }, 40)}<small>${n}</small></button>`).join('')}</div>
    <h3 class="sub-h">색</h3><div class="color-grid">${Object.entries(EMBLEM_COLORS).map(([k, [n, col]]) => `<button class="col-pick" data-col="${k}" style="--c:${col}" aria-label="${n}"><i></i><small>${n}</small></button>`).join('')}</div>
    <label class="field"><span>한 줄 소개 (60자)</span><input name="bio" maxlength="60" value="${esc(cur.bio)}" placeholder="예: 밤길을 걷는 조사원"></label>
    <p class="note">${icon('shield', 16)} 이름·직업·소속은 캐릭터를 만들 때 정해지며 바꿀 수 없습니다.</p>
    <button class="btn primary block" id="pf-save">${icon('check', 16)}<span>프로필 저장</span></button></div>`);
  const draw = () => {
    $('.pc-emblem', body).innerHTML = emblem(c.owner_id, pick, 72);
    $$('.em-pick', body).forEach(b => { b.classList.toggle('on', b.dataset.em === pick.emblem); b.querySelector('.emblem').style.setProperty('--em', EMBLEM_COLORS[pick.color][1]); });
    $$('.col-pick', body).forEach(b => b.classList.toggle('on', b.dataset.col === pick.color));
  };
  body.addEventListener('click', e => {
    const em = e.target.closest('[data-em]'), col = e.target.closest('[data-col]');
    if (em) pick.emblem = em.dataset.em; if (col) pick.color = col.dataset.col; if (em || col) draw();
  });
  $('#pf-save', body).onclick = e => guard(e.currentTarget, async () => {
    const out = await act('world_set_profile', { p_emblem: pick.emblem, p_color: pick.color, p_bio: $('[name=bio]', body).value });
    await loadCharacter(); closeModal(); return out;
  });
  draw();
  openModal({ title: '프로필', body });
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
