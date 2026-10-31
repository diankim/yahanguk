// 현장 머리 배경: 산수화처럼 거리감이 다른 네 겹(하늘 · 먼 산 · 장소의 상징물 · 앞쪽 땅과 풀)을 평면 도형으로 쌓는다.
// 그라데이션·그림자·흐림 없이 장소 색(--sc)을 겹마다 다른 농도로 섞어 깊이를 만들고, 글자가 있는 왼쪽은 비워 둔다.
const VB = '0 0 640 150';

/* ── 그리기 도우미 ──────────────────────────────────────── */
const r1 = (seed => () => (seed = (seed * 9301 + 49297) % 233280) / 233280);
// 소나무: 굽은 줄기 + 옆으로 퍼진 구름 모양 잎 덩어리 세 단(한국 소나무처럼 납작하고 넓게)
function pine(x, y, s = 1, lean = 1) {
  const L = lean * s;
  const trunk = `M${x - 2 * s} ${y}c${1 * L} ${-12 * s} ${-4 * L} ${-20 * s} ${2 * L} ${-34 * s}c${3 * L} ${-6 * s} ${8 * L} ${-8 * s} ${10 * L} ${-12 * s}l${2 * s} ${1 * s}c${-3 * L} ${5 * s} ${-8 * L} ${8 * s} ${-9 * L} ${12 * s}c${-4 * L} ${12 * s} ${1 * L} ${22 * s} ${1 * L} ${33 * s}z`;
  const cloud = (cx, cy, w, h) => `M${cx - w} ${cy}c0 ${-h} ${w * 0.6} ${-h * 1.4} ${w} ${-h * 0.9}c${w * 0.4} ${-h * 0.6} ${w} ${-h * 0.3} ${w} ${h * 0.4}c${w * 0.2} ${h * 0.1} ${w * 0.1} ${h * 0.5} 0 ${h * 0.5}z`;
  return trunk + cloud(x + 12 * L, y - 44 * s, 15 * s, 7 * s) + cloud(x - 6 * L, y - 30 * s, 13 * s, 6 * s) + cloud(x + 8 * L, y - 20 * s, 11 * s, 5 * s);
}
// 둥근 활엽수
function tree(x, y, s = 1) {
  return `M${x - 1.5 * s} ${y}v${-14 * s}h${3 * s}v${14 * s}z` +
    `M${x} ${y - 34 * s}a${11 * s} ${11 * s} 0 1 1 0.1 0z` + `M${x - 9 * s} ${y - 22 * s}a${8 * s} ${8 * s} 0 1 1 0.1 0z` + `M${x + 9 * s} ${y - 22 * s}a${8 * s} ${8 * s} 0 1 1 0.1 0z`;
}
// 기와지붕 집: 처마 끝이 살짝 들린 지붕 + 몸채
function hanok(x, y, w, h, roof = 10) {
  const e = w * 0.12;
  return `M${x} ${y}v${-h}h${w}v${h}z` +
    `M${x - e} ${y - h + 2}q${e * 0.6} ${-2} ${e * 1.2} ${-roof * 0.7}l${w - e * 0.4} 0q${e * 0.6} ${roof * 0.7 - 2} ${e * 1.2} ${roof * 0.7}z`;
}
// 탑: 층마다 줄어드는 지붕
function pagoda(x, y, s = 1, floors = 4) {
  let d = '', cy = y, w = 26 * s;
  for (let i = 0; i < floors; i++) {
    const bh = 10 * s;
    d += `M${x - w / 2 + 3 * s} ${cy}v${-bh}h${w - 6 * s}v${bh}z`;
    cy -= bh;
    d += `M${x - w / 2 - 4 * s} ${cy + 1}q${3 * s} ${-1} ${5 * s} ${-5 * s}h${w - 2 * s}q${2 * s} ${4 * s} ${5 * s} ${5 * s}z`;
    cy -= 5 * s; w *= 0.82;
  }
  return d + `M${x - 1} ${cy}v${-10 * s}h2v${10 * s}z`;
}
// 석등
const lantern = (x, y, s = 1) => `M${x - 5 * s} ${y}h${10 * s}v${-3 * s}h${-10 * s}z M${x - 2 * s} ${y - 3 * s}h${4 * s}v${-10 * s}h${-4 * s}z M${x - 6 * s} ${y - 13 * s}h${12 * s}v${-8 * s}h${-12 * s}z M${x - 8 * s} ${y - 21 * s}l${8 * s} ${-6 * s}l${8 * s} ${6 * s}z`;
// 풀 포기
function grass(x, y, n = 5, s = 1) {
  let d = '';
  for (let i = 0; i < n; i++) { const dx = (i - n / 2) * 2.2 * s, h = (8 + (i % 3) * 4) * s; d += `M${x + dx} ${y}q${1.5 * s} ${-h * 0.6} ${(i % 2 ? 3 : -2) * s} ${-h}q${-0.5 * s} ${h * 0.5} ${1.6 * s} ${h}z`; }
  return d;
}
// 산줄기: 부드러운 봉우리 목록
function ridge(base, pts) {
  let d = `M0 150V${base}`;
  for (const [x, y] of pts) d += `Q${x - 30} ${y + 6} ${x} ${y}`;
  return d + `L640 ${base}V150z`;
}

/* ── 장소별 그림 ───────────────────────────────────────── */
// far: 먼 산(가장 옅게) · mid: 상징물 · near: 앞쪽 땅·풀 · gold: 등불처럼 작게 빛나는 점 · line: 물결 같은 가는 선
const LAND = {
  city: () => ({
    far: ridge(98, [[250, 80], [330, 62], [410, 82], [490, 58], [570, 76], [640, 64]]),
    far2: 'M240 150v-34h20v-6h12v6h30v-10h8l6-6 6 6h8v10h40v-8h14v8h30v-14l10-8 10 8v14h36v-6h18v6h40v-12h14v12h58v34z',
    mid: hanok(300, 128, 70, 22) + hanok(380, 128, 54, 30, 12) + pagoda(480, 128, 1.2, 4) + hanok(520, 128, 80, 18) + hanok(590, 128, 60, 26),
    near: 'M200 150v-20c60-4 120-6 200-4s160 2 240-2v26z' + lantern(330, 130, 0.9) + lantern(560, 130, 0.9),
    gold: '<circle cx="330" cy="114" r="2.2"/><circle cx="560" cy="114" r="2.2"/><rect x="398" y="108" width="6" height="7" rx="1"/><rect x="452" y="110" width="6" height="7" rx="1"/>',
  }),
  wild: () => ({
    far: ridge(100, [[250, 82], [340, 64], [430, 86], [520, 60], [600, 80], [640, 72]]),
    far2: ridge(118, [[280, 108], [380, 98], [470, 110], [560, 96], [640, 104]]),
    mid: 'M220 150v-26c50-12 110-14 170-6s120 6 250-8v40z' + tree(330, 126, 0.9) + tree(352, 128, 0.7) + pine(470, 124, 1, 1) + tree(560, 124, 1.1) + tree(588, 126, 0.8),
    near: 'M180 150v-12c80-8 170-10 260-4s130 4 200-2v18z' + grass(260, 140, 6) + grass(420, 140, 5, 1.1) + grass(610, 140, 6),
    gold: '<circle cx="300" cy="118" r="1.4"/><circle cx="410" cy="110" r="1.2"/><circle cx="520" cy="116" r="1.4"/>',
  }),
  shrine: () => ({
    far: ridge(96, [[270, 78], [350, 56], [430, 80], [520, 52], [610, 74], [640, 66]]),
    far2: ridge(120, [[300, 110], [400, 102], [500, 112], [600, 100], [640, 106]]),
    // 도리이: 끝이 들린 갓돌(가사기)·꿰뚫은 들보(누키)·두 기둥·가운데 현판
    mid: 'M455 72q4 4 14 4h96q10 0 14-4l2 6q-6 4-16 4h-96q-10 0-16-4z M468 82h94v5h-94z M462 92h106v4h-106z M474 96h7v52h-7z M549 96h7v52h-7z M509 83h12v11h-12z'
      + pine(360, 140, 1.15, -1) + pine(620, 142, 1, 1) + 'M490 150v-6h50v6z M500 144v-4h30v4z',
    near: 'M200 150v-10c90-6 180-8 280-4s110 3 160 0v14z' + lantern(440, 144, 1) + lantern(590, 144, 1) + grass(300, 146, 5),
    gold: '<rect x="434" y="127" width="12" height="5" rx="1"/><rect x="584" y="127" width="12" height="5" rx="1"/>',
  }),
  water: () => ({
    far: ridge(104, [[270, 90], [360, 76], [440, 94], [540, 72], [640, 88]]),
    far2: 'M260 122q30-16 60-6t40 2 50-14 60 10 40-4 50 6 40-8 50 10v4H260z',
    mid: 'M0 150v-30h640v30z'
      // 돛단배와 갈대
      + 'M430 116h56l-8 8h-40z M456 116v-30l20 26z M452 94l3-6 1 28h-4z'
      + 'M560 118q2-22 1-34h2q2 14 0 34z M568 118q4-18 6-30h2q-2 14-4 30z M576 118q-1-14 2-24h2q-2 12-1 24z',
    near: '',
    line: '<path d="M260 128h60M340 134h80M450 128h40M520 138h70M300 142h50M470 144h60"/><path d="M430 124h56" class="soft"/>',
    gold: '<circle cx="586" cy="70" r="0"/>',
  }),
  mountain: () => ({
    far: ridge(98, [[240, 76], [320, 44], [390, 74], [470, 30], [550, 66], [620, 40], [640, 56]]),
    mid: 'M300 150l70-62 40 30 60-64 70 56 40-26 60 66z' + pine(440, 98, 0.8, -1),
    near: 'M200 150v-14c70-10 150-12 240-6s140 4 200-4v24z' + pine(590, 142, 1.1, 1) + grass(330, 146, 5),
    snow: 'M458 70l12-16 12 14-8-2-4 6-6-4z M362 96l8-8 8 6-5-1-3 4z',
    line: '<path d="M520 84v40" class="fall"/>',
  }),
  desert: () => ({
    far: ridge(100, [[280, 86], [380, 74], [480, 88], [580, 70], [640, 80]]),
    far2: 'M200 150v-34c60-16 120-18 180-8s120 10 260-8v50z',
    mid: 'M260 150v-22c70-14 150-16 230-6s110 6 150 0v28z' + 'M450 128v-34h8v34z M446 94h16v-4h-16z M470 128v-22h8v22z M466 106h16v-4h-16z' + 'M560 128q-6-20 4-34q6 10 2 18q8-4 10 4q-6 6-8 12z',
    near: 'M180 150v-8c100-8 220-8 320-2s90 2 140-1v11z' + grass(380, 146, 4, 0.8),
    gold: '<circle cx="600" cy="60" r="0"/>',
  }),
  deep: () => ({
    far: 'M0 0h640v18c-20 4-30 14-40 22-8-12-20-18-34-14-10 10-14 22-28 26-6-14-18-20-30-14-12 8-20 22-34 22-10-12-24-16-36-10-16 6-26 20-40 18-10-10-26-14-38-6-12 8-22 18-36 14-8-8-18-12-30-8L0 34z',
    mid: 'M260 150v-30q30-30 70-24t60 20q40-34 90-30t80 30q40-8 80 6v28z M300 18l6 30 6-30z M380 16l4 22 4-22z M470 20l7 34 7-34z M560 16l5 26 5-26z',
    near: 'M200 150v-10c80-8 180-8 260-4s120 4 180 0v14z M420 140l8-22 8 22z M434 140l6-14 6 14z M590 140l7-18 7 18z',
    gold: '<circle cx="428" cy="124" r="2"/><circle cx="597" cy="126" r="1.8"/><circle cx="340" cy="112" r="1.2"/><circle cx="512" cy="104" r="1.2"/>',
  }),
  sky: () => ({
    far: ridge(110, [[280, 98], [380, 88], [480, 100], [580, 86], [640, 94]]),
    far2: 'M200 150v-26c60-8 120-10 180-4s140 6 260-6v36z',
    // 관성대: 계단 단·탑·혼천의
    mid: 'M470 150v-18h90v18z M480 132v-12h70v12z M492 120v-44h46v44z M486 76h58l-8-10h-42z M515 66a14 14 0 1 1 0.1 0z',
    near: 'M180 150v-8c110-6 230-8 330-2s90 2 130-1v11z',
    line: '<path d="M515 38a14 14 0 1 0 0.1 0M501 52h28M515 38v28" class="ring"/><path d="M300 40l30 14 26-8 34 18M380 30l22 6" class="soft"/>',
    gold: '<circle cx="300" cy="40" r="1.6"/><circle cx="330" cy="54" r="1.4"/><circle cx="356" cy="46" r="1.6"/><circle cx="390" cy="64" r="1.4"/><circle cx="380" cy="30" r="1.2"/><circle cx="402" cy="36" r="1.2"/>',
  }),
};
LAND.default = LAND.wild;

/* ── 하늘: 해·달과 둘레의 고리, 구름 띠, 별 ─────────────────── */
function sky(phase, weather) {
  const dim = ['cloudy', 'rain', 'drizzle', 'fog', 'snow', 'bloodmist'].includes(weather);
  const bands = (n, y0) => Array.from({ length: n }, (_, i) => `<rect x="${330 + i * 70 + (i % 2) * 24}" y="${y0 + (i % 3) * 9}" width="${70 + (i % 2) * 40}" height="5" rx="2.5"/>`).join('');
  let out = '';
  if (phase === 'night') {
    const rnd = r1(7);
    out += `<g class="sk-stars">${Array.from({ length: 16 }, () => `<circle cx="${(260 + rnd() * 370).toFixed(0)}" cy="${(10 + rnd() * 56).toFixed(0)}" r="${(0.6 + rnd() * 0.9).toFixed(1)}"/>`).join('')}</g>`;
    out += `<g class="sk-moon ${dim ? 'dim' : ''}"><circle cx="560" cy="40" r="26" class="halo"/><circle cx="560" cy="40" r="19" class="halo2"/><circle cx="560" cy="40" r="13"/><circle cx="566" cy="36" r="11" class="sk-cut"/></g>`;
  } else if (!dim) {
    const low = phase === 'dawn' || phase === 'dusk';
    const cx = phase === 'dawn' ? 520 : phase === 'dusk' ? 590 : 560, cy = low ? 82 : 40, rr = low ? 20 : 12;
    out += `<g class="sk-sun ${low ? 'low' : ''}"><circle cx="${cx}" cy="${cy}" r="${rr + 16}" class="halo"/><circle cx="${cx}" cy="${cy}" r="${rr + 8}" class="halo2"/><circle cx="${cx}" cy="${cy}" r="${rr}"/></g>`;
  }
  out += `<g class="sk-cloud">${bands(dim ? 5 : 3, dim ? 18 : 30)}</g>`;
  return out;
}

export function sceneArt(theme, phase, weather) {
  const L = (LAND[theme] || LAND.default)();
  return `<svg class="scene-art" viewBox="${VB}" preserveAspectRatio="xMaxYMax slice" aria-hidden="true" focusable="false">
    ${sky(phase, weather)}
    <path class="ln-far" d="${L.far}"/>
    ${L.far2 ? `<path class="ln-far2" d="${L.far2}"/>` : ''}
    ${L.mid ? `<path class="ln-mid" d="${L.mid}"/>` : ''}
    ${L.snow ? `<path class="ln-snow" d="${L.snow}"/>` : ''}
    ${L.line ? `<g class="ln-line">${L.line}</g>` : ''}
    ${L.near ? `<path class="ln-near" d="${L.near}"/>` : ''}
    ${L.gold ? `<g class="ln-gold">${L.gold}</g>` : ''}
  </svg>`;
}
