// 테마: 저장된 테마를 읽어 색·모서리·글꼴을 적용한다. 다른 모듈에 기대지 않아 점검 페이지에서도 쓴다.
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

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

