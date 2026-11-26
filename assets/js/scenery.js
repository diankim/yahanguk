import { store } from './core.js';
const r1 = (seed => () => (seed = (seed * 9301 + 49297) % 233280) / 233280);
function pine(x, y, s = 1, lean = 1) {
  const L = lean * s;
  const trunk = `M${x - 2 * s} ${y}c${1 * L} ${-12 * s} ${-4 * L} ${-20 * s} ${2 * L} ${-34 * s}c${3 * L} ${-6 * s} ${8 * L} ${-8 * s} ${10 * L} ${-12 * s}l${2 * s} ${1 * s}c${-3 * L} ${5 * s} ${-8 * L} ${8 * s} ${-9 * L} ${12 * s}c${-4 * L} ${12 * s} ${1 * L} ${22 * s} ${1 * L} ${33 * s}z`;
  const cloud = (cx, cy, w, h) => `M${cx - w} ${cy}c0 ${-h} ${w * 0.6} ${-h * 1.4} ${w} ${-h * 0.9}c${w * 0.4} ${-h * 0.6} ${w} ${-h * 0.3} ${w} ${h * 0.4}c${w * 0.2} ${h * 0.1} ${w * 0.1} ${h * 0.5} 0 ${h * 0.5}z`;
  return trunk + cloud(x + 12 * L, y - 44 * s, 15 * s, 7 * s) + cloud(x - 6 * L, y - 30 * s, 13 * s, 6 * s) + cloud(x + 8 * L, y - 20 * s, 11 * s, 5 * s);
}
function tree(x, y, s = 1) {
  return `M${x - 1.5 * s} ${y}v${-14 * s}h${3 * s}v${14 * s}z` +
    `M${x} ${y - 34 * s}a${11 * s} ${11 * s} 0 1 1 0.1 0z` + `M${x - 9 * s} ${y - 22 * s}a${8 * s} ${8 * s} 0 1 1 0.1 0z` + `M${x + 9 * s} ${y - 22 * s}a${8 * s} ${8 * s} 0 1 1 0.1 0z`;
}
function hanok(x, y, w, h, roof = 10) {
  const e = w * 0.12;
  return `M${x} ${y}v${-h}h${w}v${h}z` +
    `M${x - e} ${y - h + 2}q${e * 0.6} ${-2} ${e * 1.2} ${-roof * 0.7}l${w - e * 0.4} 0q${e * 0.6} ${roof * 0.7 - 2} ${e * 1.2} ${roof * 0.7}z`;
}
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
const lantern = (x, y, s = 1) => `M${x - 5 * s} ${y}h${10 * s}v${-3 * s}h${-10 * s}z M${x - 2 * s} ${y - 3 * s}h${4 * s}v${-10 * s}h${-4 * s}z M${x - 6 * s} ${y - 13 * s}h${12 * s}v${-8 * s}h${-12 * s}z M${x - 8 * s} ${y - 21 * s}l${8 * s} ${-6 * s}l${8 * s} ${6 * s}z`;
function grass(x, y, n = 5, s = 1) {
  let d = '';
  for (let i = 0; i < n; i++) { const dx = (i - n / 2) * 2.2 * s, h = (8 + (i % 3) * 4) * s; d += `M${x + dx} ${y}q${1.5 * s} ${-h * 0.6} ${(i % 2 ? 3 : -2) * s} ${-h}q${-0.5 * s} ${h * 0.5} ${1.6 * s} ${h}z`; }
  return d;
}
function ridge(base, pts) {
  let d = `M0 150V${base}`;
  for (const [x, y] of pts) d += `Q${x - 30} ${y + 6} ${x} ${y}`;
  return d + `L640 ${base}V150z`;
}

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
    mid: 'M455 72q4 4 14 4h96q10 0 14-4l2 6q-6 4-16 4h-96q-10 0-16-4z M468 82h94v5h-94z M462 92h106v4h-106z M474 96h7v52h-7z M549 96h7v52h-7z M509 83h12v11h-12z'
      + pine(360, 140, 1.15, -1) + pine(620, 142, 1, 1) + 'M490 150v-6h50v6z M500 144v-4h30v4z',
    near: 'M200 150v-10c90-6 180-8 280-4s110 3 160 0v14z' + lantern(440, 144, 1) + lantern(590, 144, 1) + grass(300, 146, 5),
    gold: '<rect x="434" y="127" width="12" height="5" rx="1"/><rect x="584" y="127" width="12" height="5" rx="1"/>',
  }),
  water: () => ({
    far: ridge(104, [[270, 90], [360, 76], [440, 94], [540, 72], [640, 88]]),
    far2: 'M260 122q30-16 60-6t40 2 50-14 60 10 40-4 50 6 40-8 50 10v4H260z',
    mid: 'M0 150v-30h640v30z'
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
    mid: 'M470 150v-18h90v18z M480 132v-12h70v12z M492 120v-44h46v44z M486 76h58l-8-10h-42z M515 66a14 14 0 1 1 0.1 0z',
    near: 'M180 150v-8c110-6 230-8 330-2s90 2 130-1v11z',
    line: '<path d="M515 38a14 14 0 1 0 0.1 0M501 52h28M515 38v28" class="ring"/><path d="M300 40l30 14 26-8 34 18M380 30l22 6" class="soft"/>',
    gold: '<circle cx="300" cy="40" r="1.6"/><circle cx="330" cy="54" r="1.4"/><circle cx="356" cy="46" r="1.6"/><circle cx="390" cy="64" r="1.4"/><circle cx="380" cy="30" r="1.2"/><circle cx="402" cy="36" r="1.2"/>',
  }),
};
LAND.default = LAND.wild;

function stilt(x, base, w, h, leg) {
  return `M${x + 2} ${base}v${-leg}h2v${leg}z M${x + w - 4} ${base}v${-leg}h2v${leg}z M${x} ${base - leg}v${-h}h${w}v${h}z M${x - 3} ${base - leg - h + 1}l${w / 2 + 3} ${-h * 0.8}l${w / 2 + 3} ${h * 0.8}z`;
}
const sampan = (x, y) => `M${x} ${y}h36l-6 6h-24z M${x + 8} ${y}q10-12 20 0z M${x + 30} ${y}l10 -22h1.5l-10 22z`;
const kelp = (x, h) => `M${x} 150c-7 ${-h * 0.3} 7 ${-h * 0.6} 0 ${-h}h5c7 ${h * 0.4} -7 ${h * 0.7} 0 ${h}z`;
const shed = (x, base, w, h) => `M${x} ${base}v${-h}h${w}v${h}z M${x - 3} ${base - h}l${w / 2 + 3} -6l${w / 2 + 3} 6z`;
const flue = (x, base, w, h) => `M${x} ${base}v${-h}h${w}v${h}z M${x - 1} ${base - h}h${w + 2}v-3h${-w - 2}z`;
const puff = (x, y, r) => `M${x - r} ${y}q0 ${-r} ${r} ${-r}q${r * 0.4} ${-r * 0.7} ${r * 1.1} ${-r * 0.2}q${r} 0 ${r} ${r * 0.8}q0 ${r * 0.6} ${-r} ${r * 0.6}h${-r * 1.2}q${-r * 0.9} 0 ${-r * 0.9} ${-r * 0.4}z`;
function bamboo(x, base, h, s = 1) {
  let d = '', y = base; const seg = 13 * s, w = 3 * s;
  while (y - seg > base - h) { d += `M${x} ${y}v${-(seg - 1.4)}h${w}v${seg - 1.4}z`; y -= seg; }
  const top = y;
  d += `M${x + w} ${top + 4}l${15 * s} ${-5 * s}l${-14 * s} ${2 * s}z M${x} ${top + 9}l${-14 * s} ${-3 * s}l${13 * s} ${3.5 * s}z M${x + w} ${top + 16}l${12 * s} ${-1 * s}l${-12 * s} ${3 * s}z`;
  return d;
}
const brolly = (x, y, s = 1) => `M${x - 14 * s} ${y}q${14 * s} ${-12 * s} ${28 * s} 0z M${x - 0.8} ${y}v${16 * s}h1.6v${-16 * s}z`;
const plume = (x, y, s = 1) => `M${x} ${y}q${-2 * s} ${-6 * s} ${1 * s} ${-12 * s}q${3 * s} ${6 * s} ${-1 * s} ${12 * s}z`;
function cap(px, py, w) { return `M${px - w} ${py + w * 0.9}L${px} ${py}L${px + w} ${py + w * 0.9}l${-w * 0.4} -3l${-w * 0.3} 5l${-w * 0.3} -4z`; }
const stoneHouse = (x, base, w, h) => `M${x} ${base}v${-h}h${w}v${h}z M${x - 2} ${base - h}h${w + 4}v-3h${-w - 4}z`;
function cairn(x, base, s = 1) {
  let d = '', y = base;
  [7, 5.5, 4.2, 3, 2].forEach(r0 => { const r = r0 * s, ry = r * 0.6; d += `M${x - r} ${y}a${r} ${ry} 0 0 1 ${2 * r} 0z`; y -= ry; });
  return d;
}
const flags = (pts) => pts.map(([x, y]) => `<path d="M${x} ${y}h6l-3 7z"/>`).join('');
function dome(x, base, w, h) {
  return `M${x} ${base}v${-h}h${w}v${h}z M${x - 1.5} ${base - h}q0 ${-w * 0.55} ${w / 2 + 1.5} ${-w * 0.8}q${w / 2 + 1.5} ${w * 0.25} ${w / 2 + 1.5} ${w * 0.8}z M${x + w / 2 - 0.8} ${base - h - w * 0.8}v-5h1.6v5z`;
}
const minaret = (x, base, h) => `M${x} ${base}v${-h}h5v${h}z M${x - 1.5} ${base - h + 8}h8v-2h-8z ${dome(x - 1, base - h, 7, 0)}`;
function palm(x, base, h, lean = 1) {
  const L = lean;
  return `M${x - 2} ${base}c${2 * L} ${-h * 0.4} ${6 * L} ${-h * 0.8} ${10 * L} ${-h}l2 1c${-4 * L} ${h * 0.25} ${-7 * L} ${h * 0.6} ${-8 * L} ${h}z`
    + `M${x + 9 * L} ${base - h}q${12 * L} -6 ${22 * L} 4q${-12 * L} -2 ${-22 * L} -2z M${x + 9 * L} ${base - h}q${-10 * L} -8 ${-22 * L} -2q${12 * L} -3 ${22 * L} 4z M${x + 9 * L} ${base - h}q${4 * L} -12 ${14 * L} -14q${-6 * L} 6 ${-12 * L} 15z M${x + 9 * L} ${base - h}q${-6 * L} -10 ${-16 * L} -10q${8 * L} 4 ${14 * L} 11z`;
}
function prang(x, base, s = 1) {
  let d = '', y = base, w = 26 * s;
  for (let i = 0; i < 4; i++) { const h = (i ? 7 : 12) * s; d += `M${x - w / 2} ${y}v${-h}h${w}v${h}z`; y -= h; w *= 0.74; }
  d += `M${x - w / 2 - 1} ${y}q${w / 2 + 1} ${-26 * s} ${w + 2} 0z M${x - 0.8} ${y - 22 * s}v${-10 * s}h1.6v${10 * s}z`;
  return d;
}
const pad = (x, y, r = 8) => `M${x - r} ${y}a${r} ${r * 0.34} 0 1 0 ${2 * r} 0a${r} ${r * 0.34} 0 0 0 ${-r * 0.9} ${-r * 0.3}z`;
const bud = (x, y, s = 1) => `<path d="M${x} ${y}q${-4 * s} ${-5 * s} 0 ${-10 * s}q${4 * s} ${5 * s} 0 ${10 * s}z"/>`;
const piers = (a, b, step, top, bot) => { let d = ''; for (let x = a; x < b; x += step) d += `M${x} ${top}v${bot - top}h2v${top - bot}z`; return d; };
const rain = (n, seed) => { const r = r1(seed); return Array.from({ length: n }, () => { const x = 250 + r() * 390, y = r() * 100; return `<path d="M${x.toFixed(0)} ${y.toFixed(0)}l-4 ${(14 + r() * 10).toFixed(0)}" class="soft"/>`; }).join(''); };
const grove = (a, b, step, seed) => { const r = r1(seed); let d = ''; for (let x = a; x < b; x += step) { const h = 34 + r() * 30; d += `M${x} 150v${-h.toFixed(0)}h1.6v${h.toFixed(0)}z`; } return d; };

const REALM = {
  pado: {
    water: () => ({
      far: ridge(110, [[300, 104], [400, 100], [500, 106], [600, 100], [640, 104]]),
      far2: 'M0 150v-30h640v30z' + stilt(262, 122, 18, 9, 8) + stilt(296, 122, 22, 10, 8) + stilt(566, 122, 20, 9, 7) + stilt(604, 122, 16, 8, 7),
      mid: 'M0 150v-26h640v26z' + stilt(330, 124, 34, 16, 14) + stilt(374, 124, 24, 12, 14) + stilt(500, 124, 40, 18, 14) + stilt(550, 124, 26, 13, 14)
        + 'M250 110h390v3h-390z' + piers(252, 640, 26, 113, 124),
      near: sampan(426, 132) + sampan(598, 138) + 'M200 150v-6c90-4 200-4 300-1s100 2 140 0v7z',
      line: '<path d="M260 134h50M330 140h70M440 138h40M520 144h60M300 146h40"/><path d="M250 128h390" class="soft"/>',
      gold: '<rect x="342" y="98" width="5" height="5"/><rect x="514" y="96" width="6" height="6"/><rect x="560" y="100" width="4" height="4"/><circle cx="402" cy="117" r="1.8"/><circle cx="480" cy="117" r="1.8"/>',
    }),
    deep: () => ({
      far: 'M0 0h640v20q-20 6-40 0t-40 0-40 0-40 0-40 0-40 0-40 0-40 0-40 0-40 0-40 0-40 0-40 0-40 0-40 0-40 0V0z',
      mid: 'M260 150v-24q40-20 80-12t60 14q40-20 90-14t70 18q30-6 80 4v14z' + kelp(300, 44) + kelp(316, 30) + kelp(462, 52) + kelp(478, 36) + kelp(604, 46)
        + 'M540 132q-10-14-4-26q4 8 4 16q2-14 8-20q2 12-2 22q8-6 12-4q-6 6-12 12z',
      near: 'M200 150v-10c80-8 180-8 260-4s120 4 180 0v14z M380 142v-26h4v26z M394 142v-20h4v20z M408 142v-14h3v14z',
      line: '<path d="M260 30q30 6 60 0M420 36q40 6 80 0" class="soft"/>',
      gold: '<circle cx="320" cy="70" r="1.6"/><circle cx="326" cy="56" r="1.1"/><circle cx="470" cy="84" r="1.4"/><circle cx="474" cy="66" r="1"/><circle cx="560" cy="96" r="1.4"/>',
    }),
  },
  bulssi: {
    mountain: () => ({
      far: 'M0 150V104L260 100L320 92L380 96L432 64L462 36h26L522 62L572 88L620 94L640 98V150z',
      far2: ridge(120, [[280, 112], [360, 104], [440, 114], [540, 106], [640, 112]]),
      mid: 'M220 150v-22c60-6 140-8 220-4s120 4 200-2v28z' + shed(300, 130, 46, 16) + flue(332, 130, 6, 36) + shed(410, 130, 36, 14) + shed(520, 130, 54, 18) + flue(550, 130, 7, 42) + flue(604, 130, 5, 28),
      snow: puff(470, 30, 8) + puff(488, 16, 7) + puff(504, 4, 6) + puff(338, 88, 4) + puff(346, 78, 3.4) + puff(556, 82, 4.5) + puff(566, 70, 3.6) + puff(608, 96, 3),
      line: '<path d="M470 40q-4 14 -14 26" class="ring"/><path d="M480 40q6 16 16 28" class="ring"/>',
      near: 'M200 150v-12c70-8 150-10 240-6s140 4 200-2v20z M360 140q6-10 14-6q6 2 6 6z M590 140q8-12 18-6q4 4 2 6z M440 140v-6h16v-3h-22v-3h30v6h-8v6z',
      gold: '<ellipse cx="475" cy="37" rx="12" ry="2.5"/><rect x="318" y="120" width="8" height="10"/><rect x="540" y="118" width="9" height="12"/><rect x="424" y="122" width="6" height="8"/>',
    }),
  },
  jaebit: {
    wild: () => ({
      far: ridge(96, [[260, 80], [340, 70], [420, 84], [500, 66], [580, 78], [640, 72]]),
      far2: grove(246, 640, 11, 3),
      mid: 'M220 150v-22c60-8 130-10 200-6s140 6 220-2v30z' + bamboo(286, 130, 96) + bamboo(300, 130, 80, 0.85) + bamboo(452, 130, 110) + bamboo(470, 130, 88, 0.9) + bamboo(612, 130, 100)
        + 'M360 130v-10h3v10z M396 130v-10h3v10z M356 120h44v-3h-44z M352 117l26-14l26 14z',
      near: 'M180 150v-12c80-8 170-10 260-4s130 4 200-2v18z' + grass(260, 140, 6) + grass(420, 140, 5, 1.1) + grass(560, 140, 6),
      snow: plume(256, 128) + plume(262, 126, 0.8) + plume(418, 126) + plume(424, 128, 0.9) + plume(556, 126) + plume(564, 128, 0.8),
      line: rain(22, 5),
      gold: '<circle cx="378" cy="112" r="1.4"/><circle cx="330" cy="118" r="1.1"/><circle cx="540" cy="112" r="1.2"/>',
    }),
    water: () => ({
      far: ridge(100, [[260, 86], [350, 74], [440, 88], [540, 72], [640, 84]]),
      far2: grove(246, 400, 10, 9) + 'M0 150v-28h640v28z',
      mid: 'M0 150v-26h640v26z' + bamboo(262, 124, 96) + bamboo(278, 124, 78, 0.85) + bamboo(316, 124, 104)
        + 'M450 120h150v3h-150z' + piers(452, 600, 24, 123, 132),
      near: 'M200 150v-6c90-4 200-4 300-1s100 2 140 0v7z' + sampan(500, 136) + brolly(528, 122, 0.6),
      line: rain(18, 11) + '<path d="M260 134h50M330 140h70M440 138h40M520 144h60"/>',
      gold: '<circle cx="456" cy="116" r="1.8"/><circle cx="596" cy="116" r="1.8"/>',
    }),
  },
  nunmaru: {
    mountain: () => ({
      far: 'M0 150V90L250 84L300 50L340 74L400 30L450 62L500 22L560 60L610 40L640 56V150z',
      snow: cap(300, 50, 12) + cap(400, 30, 16) + cap(500, 22, 18) + cap(610, 40, 12),
      far2: ridge(116, [[290, 108], [380, 102], [470, 110], [560, 100], [640, 106]]),
      mid: 'M220 150v-22c60-6 140-8 220-4s120 4 200-2v28z' + stoneHouse(300, 130, 30, 16) + stoneHouse(334, 130, 22, 12) + stoneHouse(560, 130, 34, 18)
        + 'M390 130v-44h2v44z M480 130v-38h2v38z' + cairn(430, 130, 1.1) + cairn(520, 130, 0.8),
      near: 'M200 150v-12c70-8 150-10 240-6s140 4 200-2v20z' + cairn(270, 140, 0.7) + 'M600 140q8-10 16-6q4 3 2 6z',
      line: '<path d="M391 86q45 16 90 6" class="soft"/>',
      gold: flags([[398, 89], [410, 92], [422, 95], [434, 97], [446, 98], [458, 97], [470, 94]]) + '<rect x="310" y="120" width="5" height="5"/><rect x="574" y="118" width="6" height="6"/>',
    }),
  },
  dalmaji: {
    city: () => ({
      far: ridge(104, [[260, 92], [350, 84], [440, 96], [540, 80], [640, 90]]),
      far2: 'M240 150v-30h400v30z' + dome(266, 120, 14, 10) + minaret(300, 120, 30) + dome(560, 120, 16, 12) + minaret(600, 120, 26),
      mid: 'M220 150v-22h420v22z' + dome(420, 128, 52, 26) + dome(380, 128, 22, 16) + dome(488, 128, 22, 16) + minaret(360, 128, 52) + minaret(522, 128, 52) + shed(290, 128, 50, 18) + shed(560, 128, 56, 16),
      near: 'M200 150v-20h190v4h8v4h8v4h8v4h8v4h40v-4h8v-4h8v-4h8v-4h8v-4h138v20z',
      line: '<path d="M432 148h40" class="soft"/><path d="M398 134h108M406 138h92M414 142h76" class="soft"/>',
      gold: '<rect x="436" y="114" width="20" height="8" rx="4"/><rect x="384" y="118" width="5" height="6"/><rect x="494" y="118" width="5" height="6"/><circle cx="300" cy="118" r="1.8"/><circle cx="600" cy="118" r="1.8"/>',
    }),
    wild: () => ({
      far: ridge(100, [[250, 82], [340, 70], [430, 86], [520, 64], [600, 80], [640, 74]]),
      far2: ridge(122, [[300, 116], [400, 110], [500, 118], [600, 108], [640, 112]]) + dome(470, 114, 12, 8) + minaret(492, 114, 22) + dome(510, 114, 10, 6),
      mid: 'M220 150v-24c50-12 110-14 170-6s120 6 250-8v38z' + palm(320, 128, 46, 1) + palm(344, 130, 36, -1) + palm(560, 126, 50, -1) + tree(430, 128, 0.9),
      near: 'M180 150v-12c80-8 170-10 260-4s130 4 200-2v18z' + grass(260, 140, 6) + grass(420, 140, 5, 1.1) + grass(610, 140, 6),
      gold: '<circle cx="300" cy="118" r="1.4"/><circle cx="480" cy="104" r="1.6"/><circle cx="520" cy="116" r="1.4"/>',
    }),
  },
  goimteo: {
    deep: () => ({
      far: 'M0 0h640v18c-20 4-30 14-40 22-8-12-20-18-34-14-10 10-14 22-28 26-6-14-18-20-30-14-12 8-20 22-34 22-10-12-24-16-36-10-16 6-26 20-40 18-10-10-26-14-38-6-12 8-22 18-36 14-8-8-18-12-30-8L0 34z',
      mid: 'M256 92h372v7h-372z' + [270, 330, 390, 450, 510, 570].map(x => `M${x} 132v-33h9v33z M${x + 9} 99h51v2q-25 14 -51 0z`).join('') + 'M620 132v-33h8v33z',
      near: 'M200 150v-24h40v4h10v4h10v4h10v4h10v8z M640 150v-24h-40v4h-10v4h-10v4h-10v4h-10v8z',
      line: '<path d="M290 140h50M370 144h70M460 140h60M330 147h40" class="soft"/>',
      gold: '<circle cx="300" cy="112" r="1.8"/><circle cx="420" cy="112" r="1.8"/><circle cx="540" cy="112" r="1.8"/><circle cx="360" cy="124" r="1.2"/><circle cx="480" cy="124" r="1.2"/>',
    }),
  },
  haeoreum: {
    city: () => ({
      far: ridge(104, [[260, 92], [350, 84], [440, 96], [540, 80], [640, 90]]),
      far2: 'M240 150v-30h400v30z' + prang(274, 120, 0.6) + prang(604, 120, 0.7),
      mid: 'M220 132v-6h420v6z M0 150v-18h640v18z M380 126v-6h150v6z M392 120v-6h126v6z' + prang(455, 114, 1.4) + prang(410, 114, 0.9) + prang(500, 114, 0.9) + palm(310, 126, 44, 1) + palm(600, 126, 40, -1),
      near: pad(290, 142, 11) + pad(340, 145, 8) + pad(520, 142, 11) + pad(566, 146, 9) + pad(612, 141, 7),
      line: '<path d="M260 146h60M390 146h120M540 147h70" class="soft"/>',
      gold: bud(300, 140, 1.2) + bud(530, 140, 1.2) + bud(590, 143) + '<circle cx="455" cy="44" r="1.6"/>',
    }),
    water: () => ({
      far: ridge(106, [[270, 94], [360, 82], [440, 98], [540, 78], [640, 92]]),
      far2: 'M0 150v-30h640v30z' + prang(300, 120, 0.7) + prang(330, 120, 0.5) + prang(580, 120, 0.6),
      mid: 'M0 150v-26h640v26z',
      near: 'M200 150v-4c90-3 200-3 300-1s100 2 140 0v5z' + pad(270, 130, 9) + pad(310, 133, 7) + pad(360, 130, 10) + pad(470, 134, 8) + pad(540, 130, 9) + pad(600, 133, 7) + pad(300, 142, 11) + pad(560, 143, 10) + sampan(410, 136),
      line: '<path d="M260 136h50M330 142h70M440 138h40M520 146h60"/>',
      gold: bud(280, 129) + bud(366, 129) + bud(548, 129) + bud(306, 140, 1.1) + bud(566, 141, 1.1),
    }),
  },
};

function sky(phase, weather) {
  const dim = ['cloudy', 'rain', 'drizzle', 'fog', 'snow', 'bloodmist'].includes(weather);
  const bands = (n, y0) => Array.from({ length: n }, (_, i) => `<rect x="${330 + i * 70 + (i % 2) * 24}" y="${y0 + (i % 3) * 9}" width="${70 + (i % 2) * 40}" height="5" rx="2.5"/>`).join('');
  let out = '', orb = '';
  if (phase === 'night') {
    const rnd = r1(7);
    out += `<g class="sk-stars">${Array.from({ length: 16 }, () => `<circle cx="${(260 + rnd() * 370).toFixed(0)}" cy="${(10 + rnd() * 56).toFixed(0)}" r="${(0.6 + rnd() * 0.9).toFixed(1)}"/>`).join('')}</g>`;
    orb = `<g class="sk-moon ${dim ? 'dim' : ''}"><circle cx="560" cy="40" r="26" class="halo"/><circle cx="560" cy="40" r="19" class="halo2"/><circle cx="560" cy="40" r="13"/><circle cx="566" cy="36" r="11" class="sk-cut"/></g>`;
  } else if (!dim) {
    const low = phase === 'dawn' || phase === 'dusk';
    const cx = phase === 'dawn' ? 520 : phase === 'dusk' ? 590 : 560, cy = low ? 82 : 40, rr = low ? 20 : 12;
    orb = `<g class="sk-sun ${low ? 'low' : ''}"><circle cx="${cx}" cy="${cy}" r="${rr + 16}" class="halo"/><circle cx="${cx}" cy="${cy}" r="${rr + 8}" class="halo2"/><circle cx="${cx}" cy="${cy}" r="${rr}"/></g>`;
  }
  out += `<g class="sk-cloud">${bands(dim ? 5 : 3, dim ? 18 : 30)}</g>`;
  return { orb, out };
}

const TILE_X = 240, TILE_W = 640 - TILE_X, SPAN = 1920;
let sceneSeq = 0;
const decoArt = d => {
  const n = Math.max(0, Math.min(5, Number(d?.stage) || 0)); if (!n) return '';
  const lamps = Array.from({ length: n }, (_, i) => { const x = 628 - i * 22, y = 96 - (i % 2) * 6;
    return `<rect class="ln-deco-pole" x="${x}" y="${y}" width="2" height="${145 - y}"/><rect class="ln-deco-lamp" x="${x - 4}" y="${y + 4}" width="10" height="12" rx="3"/>`; }).join('');
  const flag = n >= 5 ? `<rect class="ln-deco-pole" x="512" y="58" width="2" height="87"/><path class="ln-deco-flag" d="M514 60 L540 64 L536 72 L540 80 L514 78 Z"/>` : '';
  return `<g class="ln-deco">${flag}${lamps}</g>`;
};
export function sceneArt(theme, phase, weather, deco, realm = store.env?.territory_id) {
  const L = (REALM[realm]?.[theme] || LAND[theme] || LAND.default)();
  const sk = sky(phase, weather);
  const land = `${sk.out}
    <path class="ln-far" d="${L.far}"/>
    ${L.far2 ? `<path class="ln-far2" d="${L.far2}"/>` : ''}
    ${L.mid ? `<path class="ln-mid" d="${L.mid}"/>` : ''}
    ${L.snow ? `<path class="ln-snow" d="${L.snow}"/>` : ''}
    ${L.line ? `<g class="ln-line">${L.line}</g>` : ''}
    ${L.near ? `<path class="ln-near" d="${L.near}"/>` : ''}
    ${L.gold ? `<g class="ln-gold">${L.gold}</g>` : ''}`;
  const n = Math.ceil((SPAN - 640 + TILE_W) / TILE_W) + 1, id = `sc${++sceneSeq}`;
  const tiles = Array.from({ length: n }, (_, i) => `<g mask="url(#${id}-${i})"><g transform="translate(${-i * (TILE_W - 2)} 0)${i % 2 ? ` translate(${TILE_X + 640} 0) scale(-1 1)` : ''}">${land}</g></g>`).join('');
  const clips = Array.from({ length: n }, (_, i) => `<mask id="${id}-${i}" maskUnits="userSpaceOnUse" x="${TILE_X - i * (TILE_W - 2)}" y="0" width="${TILE_W}" height="150"><rect x="${TILE_X - i * (TILE_W - 2)}" y="0" width="${TILE_W}" height="150" fill="#fff"/></mask>`).join('');
  return `<svg class="scene-art" viewBox="${640 - SPAN} 0 ${SPAN} 150" preserveAspectRatio="xMaxYMax slice" aria-hidden="true" focusable="false">
    <defs>${clips}</defs>
    ${sk.orb}
    ${tiles}
    <rect class="ln-near" x="${640 - SPAN}" y="145" width="${SPAN}" height="5"/>
    ${decoArt(deco)}
  </svg>`;
}
