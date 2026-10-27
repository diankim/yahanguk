// 헤더 기능: 테마(프리셋·흑백·직접 설정) · 프로필 보기 · 알림. 고치는 화면은 설정 페이지(views/settings.js)에 있다.
import { db, store, rpc, act, esc, icon, h, $, $$, openModal, closeModal, toast, guard, fmt, emblem, profileOf, loadCharacter, nameOf, JOBS } from './core.js';
export { initSound, playSfx } from './sound.js';

/* ── 테마 ────────────────────────────────────────────────
   색: 바탕 / 면 / 면2 / 선 / 글자 / 흐린 글자 / 강조 / 강조 위 글자 / 포인트
   모양: 모서리(r), 글꼴(font: sans·serif·mixed), 선 굵기(bw) */
export const THEMES = [
  { id: 'yahang', name: '야행', desc: '먹빛 밤거리에 주홍 등불', tone: 'dark', r: 10, font: 'sans', bw: 1,
    c: ['#0e0c10', '#18151b', '#221e26', '#332d38', '#efe7da', '#a2978a', '#c8432d', '#fff4ea', '#d1a65a'] },
  { id: 'hanji', name: '한지', desc: '누런 한지에 먹으로 쓴 글씨', tone: 'light', r: 2, font: 'serif', bw: 1,
    c: ['#ece2cc', '#f6efdf', '#e4d8bd', '#c9b993', '#2a2017', '#6f604b', '#a8321f', '#fff8ec', '#6b4f2a'] },
  { id: 'celadon', name: '청자', desc: '비색 청자처럼 맑고 둥근 면', tone: 'light', r: 16, font: 'mixed', bw: 1,
    c: ['#d9e6df', '#ecf3ef', '#cfe0d7', '#a9c4b6', '#1d332d', '#557067', '#2f7a68', '#f2fbf7', '#8a6d3b'] },
  { id: 'dancheong', name: '단청', desc: '전각 처마의 녹청 바탕과 주홍·황색', tone: 'dark', r: 4, font: 'sans', bw: 2,
    c: ['#11251e', '#183128', '#1f3d32', '#2f5a4a', '#f3ead6', '#a9bfb3', '#d4452f', '#fff6ee', '#e5b53c'] },
  { id: 'indigo', name: '쪽빛', desc: '쪽물 들인 무명의 깊은 남색', tone: 'dark', r: 12, font: 'sans', bw: 1,
    c: ['#18213a', '#212c4a', '#29365a', '#3d4c78', '#eef1fa', '#a3adc9', '#9db8ff', '#0f1730', '#f2c879'] },
  { id: 'ocher', name: '황토', desc: '볕에 마른 흙벽과 숯빛 글씨', tone: 'light', r: 6, font: 'mixed', bw: 1,
    c: ['#e3d0ad', '#efe2c8', '#d9c39b', '#bfa274', '#33240f', '#6e5835', '#8b3f1c', '#fff4e2', '#3c6a48'] },
  { id: 'moonlit', name: '월하', desc: '달빛 아래 잿빛 기와', tone: 'dark', r: 8, font: 'sans', bw: 1,
    c: ['#2a2f37', '#343a44', '#3d4450', '#525b6a', '#e8eaef', '#a7aebb', '#d3dbe8', '#1c2027', '#9ccabd'] },
  { id: 'plum', name: '홍매', desc: '늦겨울 흰 담장에 핀 붉은 매화', tone: 'light', r: 18, font: 'mixed', bw: 1,
    c: ['#f5e9ea', '#fff8f8', '#efdcde', '#ddbfc3', '#3a2127', '#7c5a61', '#a8344f', '#fff4f6', '#56743f'] },
  { id: 'pine', name: '송연', desc: '소나무 그을음으로 만든 먹과 송화', tone: 'dark', r: 6, font: 'serif', bw: 1,
    c: ['#151913', '#1e241b', '#262e22', '#384433', '#e6e8da', '#a3a993', '#a9bd4f', '#141907', '#d6a65c'] },
  { id: 'najeon', name: '나전', desc: '검은 옻칠 위 자개 빛', tone: 'dark', r: 18, font: 'mixed', bw: 1,
    c: ['#0b0b0e', '#151519', '#1d1d23', '#2e2e37', '#f0ebe1', '#a39e95', '#82d4c8', '#04201c', '#c8b4ea'] },
  { id: 'ink', name: '흑', desc: '먹 한 가지만 쓴 흑백', tone: 'dark', r: 0, font: 'sans', bw: 1,
    c: ['#000000', '#0d0d0d', '#181818', '#333333', '#f2f2f2', '#9a9a9a', '#ffffff', '#000000', '#cfcfcf'] },
  { id: 'baekja', name: '백자', desc: '흰 바탕에 먹빛만 남긴 백자', tone: 'light', r: 0, font: 'sans', bw: 1,
    c: ['#f7f7f5', '#ffffff', '#efefec', '#d6d6d1', '#191919', '#6d6d6a', '#2a2a2a', '#ffffff', '#7d7d7a'] },
];
const OLD = { lantern: 'indigo', jade: 'celadon', palace: 'najeon', maple: 'ocher', moonwhite: 'moonlit', bloodmoon: 'yahang', ghostfire: 'pine', goldorchid: 'ocher', snownight: 'moonlit', paper: 'hanji' };
const VARS = ['--bg', '--surface', '--surface-2', '--line', '--text', '--muted', '--accent', '--accent-ink', '--gold'];
const FONTS = {
  sans: ["var(--font-sans)", "var(--font-sans)"],
  serif: ["var(--font-serif)", "var(--font-serif)"],
  mixed: ["var(--font-sans)", "var(--font-serif)"],
};

const hex = s => { const m = /^#?([0-9a-f]{6})$/i.exec(s || ''); if (!m) return null; const n = parseInt(m[1], 16); return [n >> 16, n >> 8 & 255, n & 255]; };
const toHex = rgb => '#' + rgb.map(v => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, '0')).join('');
const mix = (a, b, t) => toHex(hex(a).map((v, i) => v + (hex(b)[i] - v) * t));
const lum = c => { const [r, g, b] = hex(c).map(v => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
// 직접 설정: 바탕·강조·포인트 세 가지 색과 모서리·글꼴만 고르면 나머지는 어울리게 만든다.
export function deriveCustom({ bg, accent, gold, r = 10, font = 'sans' }) {
  const light = lum(bg) > 0.45, text = light ? '#1d1a17' : '#efeae2';
  return { id: 'custom', tone: light ? 'light' : 'dark', r: Number(r), font, bw: 1,
    c: [bg, mix(bg, text, 0.05), mix(bg, text, 0.09), mix(bg, text, 0.2), text, mix(text, bg, 0.42), accent, lum(accent) > 0.45 ? '#111111' : '#ffffff', gold] };
}
export function readCustom() { try { return JSON.parse(localStorage.getItem('yh-theme-custom') || 'null'); } catch { return null; } }
export function themeOf(id) {
  if (id === 'custom' && readCustom()) return deriveCustom(readCustom());
  return THEMES.find(x => x.id === (OLD[id] || id)) || THEMES[0];
}
export function applyTheme(id, save = true, custom) {
  const t = custom ? deriveCustom(custom) : themeOf(id);
  const root = document.documentElement;
  VARS.forEach((v, i) => root.style.setProperty(v, t.c[i]));
  root.style.setProperty('--r-sm', `${Math.round(t.r * 0.7)}px`);
  root.style.setProperty('--r', `${t.r}px`);
  root.style.setProperty('--r-lg', `${Math.round(t.r * 1.3)}px`);
  root.style.setProperty('--bw', `${t.bw}px`);
  root.style.setProperty('--font', FONTS[t.font]?.[0] || FONTS.sans[0]);
  root.style.setProperty('--font-head', FONTS[t.font]?.[1] || FONTS.sans[1]);
  root.dataset.theme = t.id; root.dataset.tone = t.tone; root.style.colorScheme = t.tone;
  document.querySelector('meta[name=theme-color]')?.setAttribute('content', t.c[0]);
  if (save) try { localStorage.setItem('yh-theme', t.id); if (custom) localStorage.setItem('yh-theme-custom', JSON.stringify(custom)); } catch {}
}
export function savedThemeId() { try { return localStorage.getItem('yh-theme') || 'yahang'; } catch { return 'yahang'; } }
export function applySavedTheme() { applyTheme(savedThemeId(), false); }
export function themeCard(t, on) {
  return `<button class="theme-card ${on ? 'on' : ''}" data-theme-id="${t.id}" style="--tb:${t.c[0]};--ts:${t.c[1]};--tl:${t.c[3]};--tt:${t.c[4]};--ta:${t.c[6]};--tg:${t.c[8]};--tr:${t.r}px;--tf:${t.font === 'sans' ? 'var(--font-sans)' : 'var(--font-serif)'}">
    <span class="tc-preview"><i></i><i></i><i></i><em>가</em></span><b>${esc(t.name)}</b><small>${esc(t.desc)}</small></button>`;
}

/* ── 프로필 보기(고치기는 설정 페이지에서) ─────────────────── */
export function openProfile() {
  const c = store.character || {}, p = profileOf(c.owner_id, c.profile);
  openModal({ title: '프로필', body: `<div class="profile-view">
    <div class="profile-card"><div class="pc-emblem">${emblem(c.owner_id, c.profile, 80)}</div>
      <div><h3>${esc(c.character_name || '')}</h3>${c.profile?.title_name ? `<p class="title-badge">「${esc(c.profile.title_name)}」</p>` : ''}
        <p>${esc(nameOf(c.job_key))} · ${esc(nameOf(c.faction_key))}${c.major_faction_id ? ' · ' + esc(nameOf(c.major_faction_id)) : ''}</p>
        <p class="muted small">Lv.${c.level || 1} · ${esc(JOBS[c.job_key]?.trait || '')} · ${esc(c.location || '')}</p></div></div>
    <p class="bio">${p.bio ? esc(p.bio) : '<span class="muted">한 줄 소개가 없습니다.</span>'}</p>
    <div class="btn-row"><a class="btn primary" href="#/settings/profile" data-close>${icon('gear', 16)}<span>프로필 수정</span></a>
      <a class="btn" href="#/char/titles" data-close>${icon('spark', 16)}<span>칭호 보기</span></a></div>
    <p class="muted small">이름·직업·소속은 캐릭터를 만들 때 정해지며 바꿀 수 없습니다.</p></div>` });
}

// 사진 자르기: 정사각형 안에서 끌어 옮기고 확대해 128px WebP로 만든다. 저장은 부르는 쪽이 한다.
export function bindCrop(root, onReady) {
  const cv = $('#crop-cv', root), g = cv.getContext('2d'), zoom = $('#av-zoom', root);
  let img = null, k = 1, ox = 0, oy = 0, drag = null;
  const S = cv.width;
  const paint = () => {
    g.fillStyle = '#111'; g.fillRect(0, 0, S, S);
    if (!img) return;
    const base = S / Math.min(img.width, img.height), w = img.width * base * k, hgt = img.height * base * k;
    ox = Math.min(0, Math.max(S - w, ox)); oy = Math.min(0, Math.max(S - hgt, oy));
    g.drawImage(img, ox, oy, w, hgt);
  };
  $('#av-file', root).onchange = e => {
    const f = e.target.files?.[0]; if (!f) return;
    if (f.size > 15 * 1024 * 1024) return toast('15MB 이하의 사진을 고르세요.', 'error');
    const url = URL.createObjectURL(f), im = new Image();
    im.onload = () => { img = im; k = 1; zoom.value = 1; zoom.disabled = false;
      const base = S / Math.min(im.width, im.height); ox = (S - im.width * base) / 2; oy = (S - im.height * base) / 2; paint(); URL.revokeObjectURL(url); onReady?.(); };
    im.onerror = () => toast('사진을 읽지 못했습니다.', 'error');
    im.src = url;
  };
  zoom.oninput = () => { const c0 = (S / 2 - ox) / k, c1 = (S / 2 - oy) / k; k = Number(zoom.value); ox = S / 2 - c0 * k; oy = S / 2 - c1 * k; paint(); };
  cv.onpointerdown = e => { if (!img) return; cv.setPointerCapture(e.pointerId); drag = { x: e.clientX, y: e.clientY }; };
  cv.onpointermove = e => { if (!drag) return; const r = S / cv.getBoundingClientRect().width; ox += (e.clientX - drag.x) * r; oy += (e.clientY - drag.y) * r; drag = { x: e.clientX, y: e.clientY }; paint(); };
  cv.onpointerup = cv.onpointercancel = () => { drag = null; };
  paint();
  return {
    has: () => !!img,
    dataUrl() {
      const out = document.createElement('canvas'); out.width = out.height = 128;
      out.getContext('2d').drawImage(cv, 0, 0, 128, 128);
      const d = out.toDataURL('image/webp', 0.82);
      return d.startsWith('data:image/webp') ? d : out.toDataURL('image/jpeg', 0.82);
    },
  };
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
        <button class="btn ghost small" data-read="${i}">확인</button></div></article>`).join('') : '<p class="muted">새 알림이 없습니다.</p>'}
      ${notes.length > 1 ? '<button class="btn block" data-read-all>모두 확인</button>' : ''}</div>`);
  body.addEventListener('click', async e => {
    const r = e.target.closest('[data-read]'), s = e.target.closest('[data-rescue]'), all = e.target.closest('[data-read-all]');
    if (r) { const n = notes[Number(r.dataset.read)]; await guard(r, () => rpc('world_mark_notification_read', { p_id: n.id }), { success: '' }); notes = notes.filter(x => x !== n); drawDot(); r.closest('.note-item').remove(); }
    if (s) { const n = notes[Number(s.dataset.rescue)]; await guard(s, () => act('world_rescue_character', { p_target: n.payload.target_id })); }
    if (all) { await guard(all, async () => { for (const n of [...notes]) await rpc('world_mark_notification_read', { p_id: n.id }); notes = []; drawDot(); closeModal(); }, { success: '알림을 모두 확인했습니다.' }); }
  });
  openModal({ title: '알림', body });
}
export { loadCharacter };
