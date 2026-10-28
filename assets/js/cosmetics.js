// 프로필 꾸미기 그림: 테두리(문장 둘레) · 바탕 무늬(프로필 카드 바탕) · 낙관(이름 옆 도장).
// 이름·얻는 조건·소유는 서버(world_cosmetic_*)가 정하고, 여기에는 키별 그림만 둔다.
// 모두 평면 선 그림(그라데이션·그림자·흐림 없음)이며 색은 테마 색을 따른다. 움직임은 아직 넣지 않는다.

// 테두리: 등급(tier)과 모서리에 놓는 문양(motif, 가운데가 0,0인 약 16×16 선 그림)
const M = {
  lantern: 'M-4-7h8M-5-5h10v9h-10zM0 4v3M-2 7h4',
  path: 'M-8 0h4M-2 0h4M4 0h4',
  compass: 'M0-8L2-2 8 0 2 2 0 8-2 2-8 0-2-2z',
  blade: 'M-7 7L4-4l3-3-1 4-11 10zM-4 2l2 2',
  gate: 'M-6 7V-3M6 7V-3M-8-3h16M-7-6h14',
  ghost: 'M0-8c4 4 6 7 6 10a6 6 0 01-12 0c0-3 2-6 6-10zM-2 2h0M2 2h0',
  hoof: 'M-6 6a6 6 0 1112 0h-3a3 3 0 10-6 0z',
  wind: 'M-8-3h10a3 3 0 10-3-3M-8 3h13a3 3 0 11-3 3',
  seal: 'M-6-6h12v12h-12zM-3-3h6v6h-6z',
  talisman: 'M-4-8h8v16h-8zM-2-4h4M-2 0h4M-2 4h4',
  hammer: 'M-6-7h8v4h-8zM-2-3l7 10',
  anvil: 'M-7-3h14l-3 4h-8zM-2 1v5M2 1v5M-5 6h10',
  leaf: 'M-7 7C-7-3 0-7 7-7 7 3 0 7-7 7zM-7 7L3-3',
  mountain: 'M-8 6L-2-4 2 2 4-1 8 6z',
  wave: 'M-8 1c2-3 4-3 6 0s4 3 6 0 4-3 6 0',
  scale: 'M-8 4a4 4 0 018 0 4 4 0 018 0M-4-2a4 4 0 018 0',
  knot: 'M-7 0a3.5 3.5 0 107 0 3.5 3.5 0 10-7 0M0 0a3.5 3.5 0 107 0 3.5 3.5 0 10-7 0',
  tree: 'M-4 8V1M4 8V1M-4 1C-4-5 4-5 4 1M-7-2a3 3 0 016 0M1-2a3 3 0 016 0',
  coin: 'M0-7a7 7 0 110 14 7 7 0 110-14zM-2-2h4v4h-4z',
  moon: 'M3-7a7 7 0 100 14 5.5 5.5 0 010-14z',
  lamp: 'M-4-7h8M-5-5h10v9h-10zM0 4v3M-9 0h-2M9 0h2M-8-7l-1-1M8-7l1-1',
  drop: 'M0-7c3 4 5 6 5 8a5 5 0 01-10 0c0-2 2-4 5-8z',
  branch: 'M-6 8C-6 1 0-1 0-8M6 8C6 1 0-1 0-8M-3 3h6M-5-2l-2-2M5-2l2-2',
  // 야행(夜行)의 흔적(레거시): 그믐달 품에 든 등롱, 가장자리에는 별
  nightwalk: 'M3-8a8 8 0 100 16 6.3 6.3 0 010-16zM-4-3h4v6h-4zM-2-5v2M-2 3v3M-6 0h-1M2 0h1',
  star: 'M0-6l1.6 4.4L6 0 1.6 1.6 0 6-1.6 1.6-6 0-1.6-1.6z',
};
export const FRAMES = {
  fr_lantern: ['common', 'lantern'], fr_path: ['common', 'path'], fr_compass: ['legend', 'compass'],
  fr_blade: ['common', 'blade'], fr_gatekeeper: ['rare', 'gate'], fr_hundred_ghosts: ['legend', 'ghost'],
  fr_hoof: ['common', 'hoof'], fr_wind: ['rare', 'wind'], fr_red_seal: ['common', 'seal'], fr_talisman: ['legend', 'talisman'],
  fr_hammer: ['common', 'hammer'], fr_workshop: ['rare', 'anvil'], fr_leaf: ['common', 'leaf'], fr_earth: ['legend', 'mountain'],
  fr_wave: ['common', 'wave'], fr_dragon_scale: ['legend', 'scale'], fr_knot: ['common', 'knot'], fr_twin_tree: ['rare', 'tree'],
  fr_coin: ['common', 'coin'], fr_moon: ['rare', 'moon'], fr_night_lamp: ['legend', 'lamp'], fr_bloodmist: ['rare', 'drop'],
  fr_yeonri: ['legend', 'branch'],
  fr_yahaeng: ['legacy', 'nightwalk'], // 레거시: 롤백 전 첫 시대를 함께한 이만(얻는 길 없음)
};
const CORNERS = [[12, 12, 0], [88, 12, 90], [88, 88, 180], [12, 88, 270]];
const MIDS = [[50, 4, 0], [96, 50, 90], [50, 96, 180], [4, 50, 270]];

// 테두리 선은 CSS 테두리로 그려(안쪽 문장과 같은 픽셀 격자에 맞아 화면 배율이 달라도 가운데가 어긋나지 않는다),
// 모서리 문양만 SVG로 얹는다. 작은 크기(목록·상태판)에서는 문양 없이 선만 그린다.
function glyphSvg(key) {
  const [tier, motif] = FRAMES[key] || ['common', 'lantern'];
  const d = M[motif];
  const glyph = (x, y, r, s = 1) => `<g transform="translate(${x} ${y}) rotate(${r}) scale(${s})"><circle r="8.5" class="fr-bg"/><path d="${d}"/></g>`;
  const spots = tier === 'common' ? [CORNERS[0], CORNERS[2]] : CORNERS;
  let body = spots.map(([x, y, r]) => glyph(x, y, r, tier === 'legend' || tier === 'legacy' ? 0.9 : 0.8)).join('');
  if (tier === 'legend') body += MIDS.map(([x, y, r]) => glyph(x, y, r, 0.55)).join('');
  if (tier === 'legacy') body += MIDS.map(([x, y, r]) => `<g transform="translate(${x} ${y}) rotate(${r}) scale(.6)"><circle r="8.5" class="fr-bg"/><path d="${M.star}"/></g>`).join('');
  return `<svg class="fr-svg" viewBox="0 0 100 100" aria-hidden="true" focusable="false">${body}</svg>`;
}
// 레거시 테두리: 팔각 패(牌). 끊긴 자리는 오른쪽 위 빗변 가운데(둘레의 15~23%)다. 핏빛 굵은 테와 금빛 가는 테가 오른쪽 위에서 끊기고, 끊긴 자리에 육각 별이 앉는다(「미완」).
// 네 변 가운데의 작은 별은 첫 시안의 문양을 이어받았다. 작은 크기에서는 테만 그린다.
const HEX_STAR = 'M0-7L6.06 3.5H-6.06zM0 7L-6.06-3.5H6.06z';
function legacySvg(small) {
  const oct = i => { const a = 2 + i, b = 29 + i * .4; return `M${b} ${a}L${100 - b} ${a}L${100 - a} ${b}L${100 - a} ${100 - b}L${100 - b} ${100 - a}L${b} ${100 - a}L${a} ${100 - b}L${a} ${b}Z`; };
  const mids = small ? '' : [[50, 3, 0], [97, 50, 90], [50, 97, 180], [3, 50, 270]].map(([x, y, r]) => `<g transform="translate(${x} ${y}) rotate(${r}) scale(.5)"><circle r="8.5" class="fr-bg"/><path d="${M.star}"/></g>`).join('');
  return `<svg class="fr-svg lg" viewBox="0 0 100 100" aria-hidden="true" focusable="false">
    <path class="lg-out" d="${oct(0)}" pathLength="100" stroke-dasharray="92 8" stroke-dashoffset="77"/>
    ${small ? '' : `<path class="lg-in" d="${oct(6)}" pathLength="100" stroke-dasharray="90 10" stroke-dashoffset="76"/>`}
    ${mids}<g class="lg-star" transform="translate(84 16) scale(${small ? .9 : .75})"><circle r="9" class="fr-bg"/><path d="${HEX_STAR}"/></g></svg>`;
}
export const frameTier = key => FRAMES[key]?.[0] || 'common';
// 테두리 두께(px)와 안쪽 여백: 정수로 잡아 위아래·좌우 간격이 똑같게 한다.
const frameBox = (key, size) => {
  const small = size < 56, tier = frameTier(key);
  const bw = tier === 'common' ? (small ? 2 : 3) : (small ? 3 : 5), gap = small ? 2 : 4;
  return { small, bw, gap, inner: size - 2 * (bw + gap) };
};
// 문장(emblem) 둘레에 테두리를 두른다.
export function framed(inner, key, size) {
  if (!FRAMES[key]) return inner;
  const f = frameBox(key, size);
  const legacy = frameTier(key) === 'legacy';
  return `<span class="fr-wrap t-${frameTier(key)} ${f.small ? 'small' : ''}" style="width:${size}px;height:${size}px;--fbw:${f.bw}px">${inner}${legacy ? legacySvg(f.small) : f.small ? '' : glyphSvg(key)}</span>`;
}
export const framedInner = (key, size) => FRAMES[key] ? frameBox(key, size).inner : size;

// 바탕 무늬: 프로필 카드 뒤에 아주 옅게 깐다(20×20 반복)
const P = {
  pt_mapline: '<path d="M0 10h20M10 0v20" stroke-dasharray="2 3"/><path d="M2 16c4-6 10-6 16-12"/>',
  pt_ripple: '<path d="M0 10a5 5 0 0110 0 5 5 0 0110 0M-5 20a5 5 0 0110 0 5 5 0 0110 0 5 5 0 0110 0"/>',
  pt_cloud: '<path d="M2 13c0-3 3-4 5-2 1-3 6-3 7 0 2-1 4 0 4 2z"/>',
  pt_lattice: '<path d="M10 1L19 10 10 19 1 10z"/><path d="M10 6l4 4-4 4-4-4z"/>',
  pt_stars: '<circle cx="4" cy="5" r=".9"/><circle cx="15" cy="9" r=".7"/><circle cx="8" cy="16" r=".8"/><path d="M4 5l11 4-7 7"/>',
  pt_bamboo: '<path d="M5 0v20M15 0v20M3 7h4M13 14h4M5 7c3-2 5-2 7-4"/>',
  pt_yeonri: '<path d="M3 19C3 12 10 11 10 3M17 19C17 12 10 11 10 3"/><circle cx="10" cy="3" r=".9"/>',
  pt_yahaeng: '<path d="M15 2a4 4 0 100 8 3.2 3.2 0 010-8z"/><path d="M1 18c0-2 2-3 4-2 1-2 4-2 5 0 1-.5 3 0 3 2z"/><path d="M5 6h2v3H5zM6 5v1"/><circle cx="18" cy="15" r=".6"/><circle cx="2" cy="10" r=".5"/>',
};
export const PATTERNS = Object.keys(P);
let pid = 0;
// 레거시 바탕 무늬는 되풀이하는 타일이 아니라 한 폭의 장면(그믐달·구름 두 줄·올라가는 불티, 위쪽 핏빛 줄)이다
const SCENE = {
  pt_yahaeng: `<svg class="pt-layer pt-scene" viewBox="0 0 400 200" preserveAspectRatio="xMidYMid slice" aria-hidden="true" focusable="false">
    <path class="sc-moon" d="M352 22a26 26 0 1 0 0 52a20 20 0 0 1 0-52z"/>
    <path d="M-10 150C40 138 80 140 120 150S200 162 250 150S340 136 410 148M-10 166C50 156 110 158 160 168S260 178 320 166S380 158 410 162M60 150q10-12 22 0M200 162q12-14 26 0M300 150q8-10 18 0"/>
    <g class="sc-ember"><circle cx="60" cy="120" r="1.6"/><circle cx="74" cy="96" r="1.1"/><circle cx="66" cy="72" r=".8"/><circle cx="250" cy="128" r="1.4"/><circle cx="262" cy="104" r="1"/><circle cx="330" cy="118" r="1.2"/></g>
    <path class="sc-top" d="M0 1H400"/></svg>`,
};
export function patternLayer(key) {
  if (SCENE[key]) return SCENE[key];
  if (!P[key]) return '';
  const id = `ptn${++pid}`;
  return `<svg class="pt-layer" aria-hidden="true" focusable="false"><defs><pattern id="${id}" width="20" height="20" patternUnits="userSpaceOnUse">${P[key]}</pattern></defs><rect width="100%" height="100%" fill="url(#${id})"/></svg>`;
}
// 무늬 하나만 보여 주는 작은 견본(설정 화면)
export const patternSwatch = key => `<span class="pt-swatch">${patternLayer(key)}</span>`;

// 낙관: 이름 옆 작은 도장
export const SEALS = { sl_tao: '討', sl_tam: '探', sl_jang: '匠', sl_hae: '解', sl_yu: '遊', sl_eo: '漁', sl_woo: '友', sl_ya: '夜', sl_yeon: '緣', sl_deung: '燈', sl_heun: '痕' };
const SEAL_TIER = { sl_tao: 'rare', sl_jang: 'rare', sl_eo: 'rare', sl_woo: 'rare', sl_ya: 'legend', sl_yeon: 'legend', sl_deung: 'legend', sl_heun: 'legacy' };
// 글자는 SVG의 가운데 기준선(central)에 둔다. 글꼴마다 위아래 여백이 달라 글자 상자 가운데에 두면 한쪽으로 쏠린다.
export const sealMark = key => SEALS[key] ? `<span class="seal-mark t-${SEAL_TIER[key] || 'common'}" aria-hidden="true"><svg viewBox="0 0 20 20" focusable="false"><text x="10" y="10" text-anchor="middle" dominant-baseline="central">${SEALS[key]}</text></svg></span>` : '';
