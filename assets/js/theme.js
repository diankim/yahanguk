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
  // 7.2: 바탕 무늬(tex)·모서리 장식(frame)·머리글(head)까지 다른 테마 20가지
  { id: 'giwa', name: '기와', desc: '먹빛 기왓골 위로 번진 황토', tone: 'dark', r: 4, font: 'serif', bw: 1, deco: { tex: 'tile', frame: 'bracket', head: 'under' },
    c: ['#17191c', '#202328', '#292d33', '#3d434b', '#ece6d8', '#a59f92', '#c2814a', '#1a0f06', '#d9b36c'] },
  { id: 'nokcha', name: '녹차', desc: '갓 우린 찻잎의 연두와 다기 빛', tone: 'light', r: 14, font: 'mixed', bw: 1, deco: { tex: 'brush', frame: 'round', head: 'plain' },
    c: ['#e6ecd7', '#f3f6ea', '#dbe4c8', '#b9c79c', '#24301a', '#5f6e4c', '#5d7f2e', '#f6fbee', '#8a6a3a'] },
  { id: 'jaun', name: '자운영', desc: '봄 논두렁의 연보랏빛 꽃밭', tone: 'light', r: 16, font: 'sans', bw: 1, deco: { tex: 'dot', frame: 'round', head: 'band' },
    c: ['#eee7f2', '#f8f4fa', '#e4dbea', '#c9b8d4', '#2c2133', '#6c5d76', '#7d4fa0', '#fbf6ff', '#5f8a4a'] },
  { id: 'noeul', name: '노을', desc: '해 지는 강 위의 주황과 보랏빛', tone: 'dark', r: 10, font: 'sans', bw: 1, deco: { tex: 'none', frame: 'bracket', head: 'band' },
    c: ['#1c1420', '#26192a', '#312035', '#4a3150', '#f4e6df', '#b39aa8', '#f08a4b', '#2a1008', '#e7c063'] },
  { id: 'seolwon', name: '설원', desc: '눈 덮인 북령 들판의 푸른 그림자', tone: 'light', r: 8, font: 'sans', bw: 1, deco: { tex: 'star', frame: 'dot', head: 'under' },
    c: ['#e7eef4', '#f6f9fc', '#dbe5ee', '#b7c8d8', '#16222e', '#566a7d', '#2f6a9e', '#f3f9ff', '#8a5a3a'] },
  { id: 'daesup', name: '대숲', desc: '바람 지나는 대숲의 짙은 초록', tone: 'dark', r: 3, font: 'serif', bw: 1, deco: { tex: 'bamboo', frame: 'line', head: 'plain' },
    c: ['#0f1a14', '#16241c', '#1d2f24', '#2c4636', '#e3ece2', '#9db3a2', '#7fbf5a', '#0d1a07', '#d8c070'] },
  { id: 'yeonji', name: '연지', desc: '연지 곤지 찍은 고운 분홍', tone: 'light', r: 18, font: 'mixed', bw: 1, deco: { tex: 'wave', frame: 'round', head: 'plain' },
    c: ['#f6e8ea', '#fff7f8', '#f0dcdf', '#dfbcc2', '#3b1f26', '#7f5b63', '#c23b5a', '#fff2f5', '#3f7a6a'] },
  { id: 'bichwi', name: '비취', desc: '깊은 물빛 비취 노리개', tone: 'dark', r: 12, font: 'mixed', bw: 1, deco: { tex: 'lattice', frame: 'bracket', head: 'plain' },
    c: ['#0b1d1c', '#112927', '#163432', '#24504c', '#e2f0ec', '#93b6ae', '#3fc2a6', '#04201a', '#e0c279'] },
  { id: 'geumbak', name: '금박', desc: '검은 비단에 찍은 금박 무늬', tone: 'dark', r: 2, font: 'serif', bw: 2, deco: { tex: 'star', frame: 'double', head: 'under' },
    c: ['#100d08', '#1a1610', '#231e16', '#3a3122', '#f2e9d2', '#ab9f84', '#e2b549', '#1c1203', '#f0d48a'] },
  { id: 'bada', name: '바다', desc: '밤바다 위 등대 불빛', tone: 'dark', r: 14, font: 'sans', bw: 1, deco: { tex: 'wave', frame: 'round', head: 'plain' },
    c: ['#0c1626', '#122035', '#192a43', '#284062', '#e4edf8', '#93a6c0', '#59b5e8', '#04121f', '#f2c35c'] },
  { id: 'danpung', name: '단풍', desc: '가을 산 단풍잎과 마른 풀빛', tone: 'light', r: 6, font: 'serif', bw: 1, deco: { tex: 'brush', frame: 'bracket', head: 'band' },
    c: ['#f2e6d6', '#fbf4ea', '#eadac4', '#d4b894', '#33190e', '#77553e', '#b8401f', '#fff3ea', '#6b7a2a'] },
  { id: 'cheongsa', name: '청사초롱', desc: '푸른 비단 초롱에 붉은 띠', tone: 'dark', r: 8, font: 'sans', bw: 1, deco: { tex: 'dot', frame: 'bracket', head: 'band' },
    c: ['#101a2e', '#16233d', '#1d2c4b', '#2d416a', '#edf0f8', '#9fabc6', '#e0503e', '#ffffff', '#7fb4ff'] },
  { id: 'angae', name: '안개', desc: '새벽 안개 낀 잿빛 마을', tone: 'light', r: 10, font: 'sans', bw: 1, deco: { tex: 'none', frame: 'none', head: 'under' },
    c: ['#e4e5e3', '#f2f3f1', '#dadbd8', '#bfc1bd', '#22252a', '#636770', '#4c5f78', '#f4f7fb', '#8a6d3b'] },
  { id: 'cheongdong', name: '청동', desc: '녹슨 청동 거울의 푸른 녹', tone: 'dark', r: 6, font: 'serif', bw: 1, deco: { tex: 'grain', frame: 'dot', head: 'plain' },
    c: ['#141a15', '#1c241d', '#242e25', '#384637', '#e8e6d8', '#a3a690', '#6aa889', '#0b1a12', '#c79a52'] },
  { id: 'jangji', name: '장지', desc: '장지문 창살에 비친 한낮', tone: 'light', r: 0, font: 'serif', bw: 1, deco: { tex: 'lattice', frame: 'line', head: 'under' },
    c: ['#eee6d3', '#f9f4e8', '#e6dcc4', '#cbbb98', '#2b2215', '#6c5e46', '#7a4b23', '#fff8ec', '#9b3a2a'] },
  { id: 'yasijang', name: '야시장', desc: '백등 야시장 천막 아래 주홍 등', tone: 'dark', r: 12, font: 'sans', bw: 1, deco: { tex: 'star', frame: 'bracket', head: 'band' },
    c: ['#1a1222', '#22182c', '#2b1f37', '#423152', '#f3e9ee', '#ab9bb0', '#ff9a3d', '#2a1300', '#e8d06a'] },
  { id: 'jusa', name: '주사', desc: '부적 쓰는 주사 빛 붉은 먹', tone: 'light', r: 4, font: 'serif', bw: 2, deco: { tex: 'hanji', frame: 'double', head: 'band' },
    c: ['#f0e4d2', '#faf3e6', '#e8d8c0', '#d0b48e', '#2e1810', '#70533f', '#c2261b', '#fff4ec', '#2e5f8a'] },
  { id: 'eunha', name: '은하', desc: '무극 관성대에서 올려다본 별밭', tone: 'dark', r: 16, font: 'mixed', bw: 1, deco: { tex: 'star', frame: 'round', head: 'plain' },
    c: ['#090c1c', '#10142a', '#161b36', '#262d52', '#e7e9fb', '#9aa0c8', '#a7b4ff', '#0b1036', '#f4d57a'] },
  { id: 'jae', name: '재', desc: '남명의 잿빛 해안과 꺼진 불씨', tone: 'dark', r: 4, font: 'sans', bw: 1, deco: { tex: 'brush', frame: 'line', head: 'under' },
    c: ['#1b1917', '#24211e', '#2d2925', '#433d37', '#ebe5dc', '#a59c90', '#e06a3a', '#1f0d04', '#b8a27a'] },
  { id: 'bomnal', name: '봄날', desc: '개나리 핀 담장과 새싹', tone: 'light', r: 18, font: 'sans', bw: 1, deco: { tex: 'dot', frame: 'round', head: 'band' },
    c: ['#f3f0d8', '#fcfaec', '#ebe6c4', '#d4cb98', '#2a2a14', '#6a6942', '#c79a10', '#1d1600', '#4f8a3a'] },
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
  const d = t.deco || {}; root.dataset.tex = d.tex || 'none'; root.dataset.frame = d.frame || 'bracket'; root.dataset.head = d.head || 'plain';
  document.querySelector('meta[name=theme-color]')?.setAttribute('content', t.c[0]);
  if (save) try { localStorage.setItem('yh-theme', t.id); if (custom) localStorage.setItem('yh-theme-custom', JSON.stringify(custom)); } catch {}
}
export function savedThemeId() { try { return localStorage.getItem('yh-theme') || 'yahang'; } catch { return 'yahang'; } }
export function applySavedTheme() { applyTheme(savedThemeId(), false); applyFontSize(savedFontSize(), false); }
// 글자 크기 다섯 단계(기기에 남김): 글자만 키우고 줄이며 단추·칸 크기는 그대로다. 터치 화면 입력칸은 16px 아래로 내려가지 않는다
export const FONT_SIZES = [['xs', '아주 작게', 0.85], ['s', '작게', 0.92], ['m', '보통', 1], ['l', '크게', 1.1], ['xl', '아주 크게', 1.22]];
export function savedFontSize() { try { return localStorage.getItem('yh-fz') || 'm'; } catch { return 'm'; } }
export function applyFontSize(k, save = true) {
  const f = FONT_SIZES.find(x => x[0] === k) || FONT_SIZES[2];
  document.documentElement.style.setProperty('--fz', String(f[2]));
  document.documentElement.dataset.fz = f[0];
  if (save) try { localStorage.setItem('yh-fz', f[0]); } catch {}
}
const TEX_NAME = { none: '민무늬', tile: '기왓골', brush: '붓결', dot: '점무늬', bamboo: '대나무 결', wave: '물결', lattice: '살창', star: '별밭', grain: '나뭇결', hanji: '한지 결' };
export function themeCard(t, on) {
  return `<button class="theme-card ${on ? 'on' : ''}" data-theme-id="${t.id}" style="--tb:${t.c[0]};--ts:${t.c[1]};--tl:${t.c[3]};--tt:${t.c[4]};--ta:${t.c[6]};--tg:${t.c[8]};--tr:${t.r}px;--tf:${t.font === 'sans' ? 'var(--font-sans)' : 'var(--font-serif)'}">
    <span class="tc-preview tex-${t.deco?.tex || 'none'}"><i></i><i></i><i></i><em>가</em></span><b>${esc(t.name)}</b><small>${esc(t.desc)}${t.deco ? ` · ${esc(TEX_NAME[t.deco.tex] || '')}` : ''}</small></button>`;
}

