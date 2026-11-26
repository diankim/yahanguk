const K = {
  wa: '#ebb676', wb: '#c4884e', wc: '#9c6438', wd: '#704228', we: '#4a2a1a',
  sail: '#f1dca4', sail2: '#fff6dc', sailT: '#d8b672', sailS: '#a88650',
  red: '#e0483a', redD: '#a32a22', teal: '#3f9a8c', tealD: '#2a6a66',
  sea: '#2c5b86', sea2: '#4a86b6', sky: '#9ccbe0', glass: '#cfeaf6',
  brassL: '#ffe27a', brass: '#c89a44', brassD: '#8a6a30',
  ironL: '#7f8aa6', iron: '#565d78', ironD: '#383d52',
  rope: '#c8ae78', ropeD: '#8a7450', net: '#7d6c4c', net2: '#958358', net3: '#ab9a6c',
  cork: '#e0a050', glow: '#ffe6a8', glow2: '#fff4d2', flame: '#ffb84a',
};

const cyl = (x, y, z0, z1, rx, ry, col) => {
  const out = [], n = Math.round((z1 - z0) * 20);
  for (let i = 0; i <= n; i++) {
    const z = z0 + i / 20, f = i / Math.max(1, n), r = typeof rx === 'function' ? rx(f) : rx, c = col(f);
    out.push({ t: 'ell', x, y, z, rx: r, ry, c: c[0] });
    out.push({ t: 'ell', x: x - .05, y: y + .05, z, rx: r * .7, ry: ry * .7, c: c[1] });
    out.push({ t: 'ell', x: x - .11, y: y + .11, z, rx: Math.max(1, r * .3), ry: ry * .35, c: c[2] });
  }
  return out;
};
const WOOD3 = [K.wd, K.wc, K.wb], HOOP3 = [K.ironD, K.iron, K.ironL];

const lying = (x0, x1, c) => [[.14, .06, .36, .28], [.2, .1, .26, .48], [.3, .24, .2, .6], [.54, .1, .26, .48], [.64, .06, .36, .28]]
  .map(([z, h, y, d]) => ({ x: x0, y, w: x1 - x0, d, h, z, c }));

const cells = (w, h, fn) => {
  const rects = [];
  for (let v = 0; v < h; v++) {
    let u = 0;
    while (u < w) {
      const c = fn(u, v); if (!c) { u++; continue; }
      let n = 1; while (u + n < w && fn(u + n, v) === c) n++;
      rects.push([u / 16, h - 1 - v, n / 16, 1, c]); u += n;
    }
  }
  return rects;
};
const rowsArt = (rows, pal) => cells(rows[0].length, rows.length, (u, v) => pal[rows[v][u]] || null);

const MESH = [];
for (let i = 0; i < 6; i++) for (let j = 0; j < 6; j++) {
  const x = .16 + i * .13 + (j % 2) * .06, y = .18 + j * .12, r = Math.hypot((x - .46) / .42, (y - .5) / .36);
  if (r < .95) MESH.push({ t: 'ell', x: x + .35, y: y + .35, z: .06 + .4 * (1 - r * r) + .02 + .56, rx: 1, ry: .6, c: K.ropeD });
}

export const CABIN_FUR = {
  cb_hammock: { name: '해먹 침상', grade: 2, W: 2, D: 1, layer: 'floor', cat: '침구', pet: 'bed', parts: [
    { x: 0, y: .3, w: .26, d: .36, h: .08, c: K.we }, { x: 1.74, y: .3, w: .26, d: .36, h: .08, c: K.we },
    { x: .06, y: .4, w: .14, d: .14, h: 1.46, z: .08, c: K.wd }, { x: 1.8, y: .4, w: .14, d: .14, h: 1.46, z: .08, c: K.wd },
    { x: .04, y: .38, w: .18, d: .18, h: .06, z: 1.54, c: K.brass }, { x: 1.78, y: .38, w: .18, d: .18, h: .06, z: 1.54, c: K.brass },
    { x: .2, y: .45, w: .07, d: .05, h: .06, z: 1.34, c: K.rope }, { x: .27, y: .45, w: .07, d: .05, h: .06, z: 1.2, c: K.rope },
    { x: .34, y: .45, w: .06, d: .05, h: .06, z: 1.06, c: K.rope }, { x: .38, y: .45, w: .04, d: .05, h: .06, z: .94, c: K.rope },
    { x: 1.73, y: .45, w: .07, d: .05, h: .06, z: 1.34, c: K.rope }, { x: 1.66, y: .45, w: .07, d: .05, h: .06, z: 1.2, c: K.rope },
    { x: 1.6, y: .45, w: .06, d: .05, h: .06, z: 1.06, c: K.rope }, { x: 1.58, y: .45, w: .04, d: .05, h: .06, z: .94, c: K.rope },
    { x: .38, y: .16, w: .05, d: .68, h: .06, z: .88, c: K.wc }, { x: 1.57, y: .16, w: .05, d: .68, h: .06, z: .88, c: K.wc },
    { x: .43, y: .14, w: .2, d: .72, h: .08, z: .82, c: K.sail }, { x: .63, y: .14, w: .22, d: .72, h: .08, z: .7, c: K.sail },
    { x: .85, y: .14, w: .3, d: .72, h: .08, z: .64, c: K.sail }, { x: 1.15, y: .14, w: .22, d: .72, h: .08, z: .7, c: K.sail },
    { x: 1.37, y: .14, w: .2, d: .72, h: .08, z: .82, c: K.sail },
    { x: .66, y: .14, w: .19, d: .72, h: .04, z: .78, c: K.red }, { x: .85, y: .14, w: .3, d: .72, h: .04, z: .72, c: K.red },
    { x: 1.15, y: .14, w: .19, d: .72, h: .04, z: .78, c: K.red },
    { x: .85, y: .2, w: .3, d: .08, h: .01, z: .76, c: K.sail2 }, { x: .85, y: .72, w: .3, d: .08, h: .01, z: .76, c: K.sail2 },
    { x: .45, y: .28, w: .16, d: .44, h: .12, z: .9, c: K.sail2 }] },
  cb_captain_desk: { name: '선장 책상', grade: 3, W: 2, D: 1, layer: 'floor', cat: '좌석·탁자', top: .81, parts: [
    { x: .06, y: .1, w: .58, d: .8, h: .7, c: K.wc }, { x: 1.36, y: .1, w: .58, d: .8, h: .7, c: K.wc },
    { x: .64, y: .1, w: .72, d: .12, h: .7, c: K.wd },
    { x: .1, y: .9, w: .5, d: .02, h: .18, z: .06, c: K.wb }, { x: .1, y: .9, w: .5, d: .02, h: .18, z: .27, c: K.wb }, { x: .1, y: .9, w: .5, d: .02, h: .18, z: .48, c: K.wb },
    { x: 1.4, y: .9, w: .5, d: .02, h: .18, z: .06, c: K.wb }, { x: 1.4, y: .9, w: .5, d: .02, h: .18, z: .27, c: K.wb }, { x: 1.4, y: .9, w: .5, d: .02, h: .18, z: .48, c: K.wb },
    { x: .31, y: .92, w: .08, d: .02, h: .05, z: .12, c: K.brass }, { x: .31, y: .92, w: .08, d: .02, h: .05, z: .33, c: K.brass }, { x: .31, y: .92, w: .08, d: .02, h: .05, z: .54, c: K.brass },
    { x: 1.61, y: .92, w: .08, d: .02, h: .05, z: .12, c: K.brass }, { x: 1.61, y: .92, w: .08, d: .02, h: .05, z: .33, c: K.brass }, { x: 1.61, y: .92, w: .08, d: .02, h: .05, z: .54, c: K.brass },
    { x: 0, y: .04, w: 2, d: .92, h: .1, z: .7, c: K.wd },
    { x: .12, y: .14, w: 1.76, d: .72, h: .01, z: .8, c: K.tealD },
    { x: 0, y: .04, w: .12, d: .12, h: .01, z: .8, c: K.brass }, { x: 1.88, y: .04, w: .12, d: .12, h: .01, z: .8, c: K.brass },
    { x: 0, y: .84, w: .12, d: .12, h: .01, z: .8, c: K.brass }, { x: 1.88, y: .84, w: .12, d: .12, h: .01, z: .8, c: K.brass },
    { x: 1.24, y: .26, w: .4, d: .3, h: .06, z: .81, c: K.redD }, { x: 1.26, y: .28, w: .36, d: .26, h: .01, z: .87, c: K.red },
    { x: 1.72, y: .22, w: .12, d: .12, h: .08, z: .81, c: K.ironD }, { x: 1.77, y: .25, w: .03, d: .03, h: .26, z: .89, c: K.sail2 }] },
  cb_chart_table: { name: '해도 탁자', grade: 2, W: 2, D: 1, layer: 'floor', cat: '좌석·탁자', top: .77, parts: [
    { x: .08, y: .08, w: .1, d: .1, h: .66, c: K.wd }, { x: 1.82, y: .08, w: .1, d: .1, h: .66, c: K.wd },
    { x: .08, y: .82, w: .1, d: .1, h: .66, c: K.wd }, { x: 1.82, y: .82, w: .1, d: .1, h: .66, c: K.wd },
    { x: .12, y: .46, w: 1.76, d: .08, h: .06, z: .16, c: K.wd },
    { x: 0, y: 0, w: 2, d: 1, h: .1, z: .66, c: K.wb },
    { x: .16, y: .1, w: 1.68, d: .8, h: .01, z: .76, c: K.sail },
    { x: .9, y: .14, w: .9, d: .72, h: .01, z: .77, c: '#8fb8c8' }, { x: .7, y: .5, w: .22, d: .36, h: .01, z: .77, c: '#8fb8c8' },
    { x: 1.2, y: .3, w: .2, d: .16, h: .01, z: .78, c: K.sail },
    { x: .5, y: .3, w: .06, d: .04, h: .01, z: .78, c: K.red }, { x: .66, y: .38, w: .06, d: .04, h: .01, z: .78, c: K.red },
    { x: .82, y: .44, w: .06, d: .04, h: .01, z: .78, c: K.red }, { x: 1.0, y: .48, w: .06, d: .04, h: .01, z: .78, c: K.red },
    { x: 1.16, y: .5, w: .06, d: .04, h: .01, z: .78, c: K.red },
    { x: .3, y: .62, w: .12, d: .12, h: .01, z: .77, c: K.redD }, { x: .34, y: .58, w: .04, d: .2, h: .01, z: .78, c: '#2a2a2e' },
    { x: .16, y: .1, w: .08, d: .08, h: .06, z: .77, c: K.ironD }, { x: 1.76, y: .82, w: .08, d: .08, h: .06, z: .77, c: K.ironD },
    { x: 1.5, y: .64, w: .2, d: .03, h: .02, z: .78, c: K.brassL }, { x: 1.5, y: .67, w: .03, d: .14, h: .02, z: .78, c: K.brass },
    { x: .2, y: .86, w: 1.1, d: .1, h: .1, z: .76, c: K.sail2 }, { x: .2, y: .86, w: .06, d: .1, h: .1, z: .76, c: K.sailT }] },
  cb_compass_stand: { name: '나침반 받침', grade: 3, W: 1, D: 1, layer: 'floor', cat: '장식', parts: [
    { x: .2, y: .14, w: .6, d: .72, h: .08, c: K.we },
    { x: .3, y: .3, w: .4, d: .4, h: .9, z: .08, c: K.wc },
    { x: .27, y: .27, w: .46, d: .46, h: .06, z: .3, c: K.wd }, { x: .27, y: .27, w: .46, d: .46, h: .06, z: .9, c: K.wd },
    { x: .14, y: .42, w: .14, d: .14, h: .14, z: .96, c: K.red }, { x: .17, y: .45, w: .08, d: .08, h: .04, z: 1.1, c: K.brass },
    { x: .72, y: .42, w: .14, d: .14, h: .14, z: .96, c: K.teal }, { x: .75, y: .45, w: .08, d: .08, h: .04, z: 1.1, c: K.brass },
    { t: 'ell', x: .5, y: .5, z: .98, rx: 10, ry: 5, c: K.brassD },
    { t: 'ell', x: .5, y: .5, z: 1.03, rx: 10, ry: 5, c: K.brass },
    { t: 'ell', x: .5, y: .5, z: 1.06, rx: 8, ry: 4, c: K.brassL },
    { t: 'ell', x: .5, y: .5, z: 1.08, rx: 7, ry: 3.5, c: K.sail2 },
    { x: .45, y: .44, w: .1, d: .12, h: .01, z: 1.08, c: K.red }, { x: .45, y: .56, w: .1, d: .06, h: .01, z: 1.08, c: K.ironD }] },
  cb_water_cask: { name: '물통', grade: 1, W: 1, D: 1, layer: 'floor', cat: '수납', parts: [
    ...cyl(.5, .5, 0, .62, f => 8 + Math.sin(f * Math.PI) * 1.2, 4.2, f => (f > .12 && f < .2) || (f > .78 && f < .86) ? HOOP3 : WOOD3),
    { t: 'ell', x: .5, y: .5, z: .64, rx: 8.4, ry: 4.2, c: K.we },
    { t: 'ell', x: .5, y: .5, z: .65, rx: 6.8, ry: 3.3, c: K.sea },
    { t: 'ell', x: .47, y: .53, z: .65, rx: 3.6, ry: 1.6, c: K.sea2 },
    { x: .58, y: .36, w: .04, d: .04, h: .42, z: .56, c: K.wb }, { x: .5, y: .3, w: .14, d: .1, h: .04, z: .96, c: K.wa }] },
  cb_wine_barrel: { name: '술통', grade: 2, W: 1, D: 1, layer: 'floor', cat: '수납', parts: [
    { x: .16, y: .16, w: .12, d: .68, h: .2, c: K.we }, { x: .72, y: .16, w: .12, d: .68, h: .2, c: K.we },
    ...lying(.06, .16, K.wc), ...lying(.16, .23, K.iron), ...lying(.23, .77, K.wc), ...lying(.77, .84, K.iron), ...lying(.84, .94, K.wc),
    { x: .38, y: .8, w: .24, d: .02, h: .2, z: .32, c: K.red }, { x: .44, y: .82, w: .12, d: .01, h: .1, z: .37, c: K.sail2 },
    { x: .94, y: .44, w: .06, d: .12, h: .06, z: .34, c: K.brass }, { x: .96, y: .46, w: .04, d: .08, h: .08, z: .26, c: K.brassD },
    { x: .44, y: .38, w: .12, d: .12, h: .04, z: .74, c: K.wd }] },
  cb_cargo_crate: { name: '짐 궤짝', grade: 1, W: 1, D: 1, layer: 'floor', cat: '수납', top: .92, parts: [
    { x: .06, y: .1, w: .86, d: .82, h: .52, c: K.wb },
    { x: .06, y: .92, w: .86, d: .01, h: .02, z: .17, c: K.wd }, { x: .06, y: .92, w: .86, d: .01, h: .02, z: .34, c: K.wd },
    { x: .92, y: .1, w: .01, d: .82, h: .02, z: .17, c: K.wd }, { x: .92, y: .1, w: .01, d: .82, h: .02, z: .34, c: K.wd },
    { x: .06, y: .92, w: .08, d: .02, h: .52, c: K.ironD }, { x: .84, y: .92, w: .08, d: .02, h: .52, c: K.ironD },
    { x: .44, y: .92, w: .08, d: .02, h: .52, c: K.rope }, { x: .44, y: .1, w: .08, d: .82, h: .01, z: .52, c: K.rope },
    { x: .2, y: .2, w: .62, d: .58, h: .38, z: .53, c: K.wc },
    { x: .2, y: .78, w: .62, d: .01, h: .02, z: .7, c: K.wd },
    { x: .32, y: .78, w: .14, d: .02, h: .12, z: .62, c: K.redD }, { x: .56, y: .78, w: .14, d: .02, h: .12, z: .62, c: K.redD },
    { x: .2, y: .2, w: .62, d: .58, h: .01, z: .91, c: K.wb }] },
  cb_janggi: { name: '장기판', grade: 2, W: 1, D: 1, layer: 'floor', cat: '좌석·탁자', parts: [
    { x: .14, y: .14, w: .1, d: .1, h: .12, c: K.wd }, { x: .76, y: .14, w: .1, d: .1, h: .12, c: K.wd },
    { x: .14, y: .76, w: .1, d: .1, h: .12, c: K.wd }, { x: .76, y: .76, w: .1, d: .1, h: .12, c: K.wd },
    { x: .08, y: .08, w: .84, d: .84, h: .2, z: .12, c: K.wb },
    { x: .12, y: .12, w: .76, d: .76, h: .01, z: .32, c: K.wa },
    { x: .16, y: .22, w: .68, d: .02, h: .01, z: .33, c: K.wd }, { x: .16, y: .4, w: .68, d: .02, h: .01, z: .33, c: K.wd },
    { x: .16, y: .58, w: .68, d: .02, h: .01, z: .33, c: K.wd }, { x: .16, y: .76, w: .68, d: .02, h: .01, z: .33, c: K.wd },
    { x: .22, y: .16, w: .02, d: .68, h: .01, z: .33, c: K.wd }, { x: .4, y: .16, w: .02, d: .68, h: .01, z: .33, c: K.wd },
    { x: .58, y: .16, w: .02, d: .68, h: .01, z: .33, c: K.wd }, { x: .76, y: .16, w: .02, d: .68, h: .01, z: .33, c: K.wd },
    { x: .18, y: .18, w: .1, d: .1, h: .05, z: .34, c: K.red }, { x: .54, y: .18, w: .1, d: .1, h: .05, z: .34, c: K.red },
    { x: .36, y: .36, w: .1, d: .1, h: .05, z: .34, c: K.red },
    { x: .54, y: .54, w: .1, d: .1, h: .05, z: .34, c: K.teal }, { x: .36, y: .72, w: .1, d: .1, h: .05, z: .34, c: K.teal },
    { x: .72, y: .72, w: .1, d: .1, h: .05, z: .34, c: K.teal }] },
  cb_net_pile: { name: '그물 더미', grade: 1, W: 1, D: 1, layer: 'floor', cat: '소품', pet: 'bed', parts: [
    { t: 'ell', x: .5, y: .5, z: .02, rx: 14, ry: 7, c: K.net },
    { t: 'ell', x: .48, y: .5, z: .14, rx: 12, ry: 6, c: K.net },
    { t: 'ell', x: .46, y: .5, z: .24, rx: 10, ry: 5, c: K.net2 },
    { t: 'ell', x: .44, y: .5, z: .34, rx: 7, ry: 3.6, c: K.net2 },
    { t: 'ell', x: .42, y: .52, z: .42, rx: 4, ry: 2.2, c: K.net3 },
    ...MESH,
    { t: 'ell', x: .55, y: 1.01, z: .68, rx: 2, ry: 1.5, c: K.cork }, { t: 'ell', x: .71, y: 1.11, z: .7, rx: 2, ry: 1.5, c: K.cork },
    { t: 'ell', x: .91, y: 1.09, z: .72, rx: 2, ry: 1.5, c: K.cork }, { t: 'ell', x: 1.05, y: .95, z: .76, rx: 2, ry: 1.5, c: K.cork },
    { t: 'ell', x: .84, y: .84, z: .14, rx: 4, ry: 4, c: K.red }, { t: 'ell', x: .84, y: .84, z: .14, rx: 4, ry: 1, c: K.sail2 }] },
};

const porthole = cells(26, 26, (u, v) => {
  const dx = u - 12.5, dy = v - 12.5, r = Math.hypot(dx, dy), a = Math.atan2(dy, dx);
  if (r > 12.6) return null;
  if (r > 11.2) return K.we;
  if (r > 8) {
    const bolt = [0, 1, 2, 3, 4, 5, 6, 7].some(k => Math.hypot(dx - 9.6 * Math.cos(k * Math.PI / 4 + .39), dy - 9.6 * Math.sin(k * Math.PI / 4 + .39)) < .8);
    if (bolt) return K.brassD;
    return dx + dy < -6 ? K.brassL : dx + dy > 6 ? K.brassD : K.brass;
  }
  if (r > 7.2) return K.brassD;
  if (dy < 1) return (dx < -2 && dy < -2 && dx > -5 && dy > -5 && (u + v) % 3 === 0) ? K.sail2 : dy < -3 ? K.sky : '#b8dcea';
  if (dy < 2) return K.sea2;
  return ((u * 3 + v) % 7 === 0) ? K.sea2 : K.sea;
});

const lampRows = [
  'eeeeeeeeeeeeee..',
  'edcccccccccccde.',
  'ede......Y......',
  'ed......Y.Y.....',
  'ed.......Y......',
  'ed.......B......',
  'ee.....BYYYB....',
  'e.....BYyyyYB...',
  'e....BBBBBBBBB..',
  'e....BgGGGGGgB..',
  '.....BgGGfGGgB..',
  '.....YgGfFfGgY..',
  '.....YgGfFfGgY..',
  '.....BgGGfGGgB..',
  '.....BggGGGggB..',
  '.....BBBBBBBBB..',
  '......BYYYYYB...',
  '.......BYYYB....',
  '........BBB.....',
];
const LAMP_PAL = { e: K.we, d: K.wd, c: K.wc, B: K.brassD, Y: K.brass, y: K.brassL, g: K.glow, G: K.glow2, f: K.flame, F: K.red };

const fishPlaque = cells(26, 16, (u, v) => {
  const pr = Math.hypot((u - 12.5) / 12.5, (v - 7.5) / 7.6);
  const fx = u - 11, fy = v - 7.5, body = Math.hypot(fx / 7.5, fy / 3.2) <= 1, tail = fx > 6 && fx < 11 && Math.abs(fy) <= (fx - 6) * .8 + .3;
  if (body || tail) {
    if (Math.abs(fx + 5) < .6 && Math.abs(fy + 1) < .6) return K.ironD;
    if (body && fx > -3.5 && fx < -2.5 && Math.abs(fy) < 2) return K.tealD;
    if (tail) return fx > 9 ? K.tealD : K.teal;
    return fy < -1.2 ? '#3f6478' : fy < .8 ? '#6f9fb5' : K.glass;
  }
  if (fy < -2.6 && fy > -5 && fx > -2 && fx < 3 && fy > -2.6 - (fx + 2) * .6) return K.teal;
  if (fy > 2.6 && fy < 4.2 && fx > 0 && fx < 3) return K.teal;
  if (pr > 1) return v < 1 && u > 11 && u < 14 ? K.brass : null;
  if (pr > .86) return K.we;
  if (pr > .76) return v < 7 ? K.wb : K.wd;
  return (u + v * 2) % 9 === 0 ? K.wb : K.wc;
});

const anchorArt = cells(28, 34, (u, v) => {
  if (v < 5) {
    if ((u === 5 || u === 22) && v < 5) return v === 0 ? K.brassL : K.brassD;
    if (u > 1 && u < 26) return v === 0 ? K.wa : v < 3 ? K.wb : v === 3 ? K.wc : K.wd;
    return null;
  }
  const cx = 13.5;
  if (Math.abs(u - cx) <= .5 && v >= 5 && v < 8) return K.rope;
  const ring = Math.hypot(u - cx, v - 9.5);
  if (ring > 1.2 && ring < 2.6) return u < cx ? K.ironL : K.iron;
  if (v >= 12 && v <= 13 && Math.abs(u - cx) <= 6.5) return v === 12 ? K.ironL : K.ironD;
  if (Math.abs(u - cx) <= 1 && v >= 11 && v <= 29) {
    if (v >= 16 && v <= 19) return (u + v) % 2 ? K.rope : K.ropeD;
    return u < cx ? K.ironL : K.iron;
  }
  const arc = Math.hypot(u - cx, v - 22);
  if (arc >= 6.4 && arc <= 8.2 && v >= 22 && v <= 31) return arc < 7.2 ? K.ironL : K.ironD;
  if (v >= 18 && v <= 23) {
    const d1 = Math.abs(u - 6.2), d2 = Math.abs(u - 20.8), w = (23 - v) * .55 + .6;
    if (d1 < w) return u < 6.2 ? K.ironL : K.iron;
    if (d2 < w) return u < 20.8 ? K.iron : K.ironD;
  }
  if (Math.hypot(u - cx, v - 30) < 1.6) return K.ironD;
  return null;
});

const helmArt = cells(28, 28, (u, v) => {
  const dx = u - 13.5, dy = v - 13.5, r = Math.hypot(dx, dy), lit = dx + dy;
  if (r < 2.2) return r < 1 ? K.brassL : K.brass;
  if (r < 3) return K.brassD;
  let sp = -1;
  for (let k = 0; k < 8; k++) {
    const a = k * Math.PI / 4 + Math.PI / 8, along = dx * Math.cos(a) + dy * Math.sin(a), off = Math.abs(-dx * Math.sin(a) + dy * Math.cos(a));
    if (along > 0 && off < (along > 10.4 ? 1.15 : .7)) sp = along;
  }
  if (r >= 6.8 && r < 7.6) return K.we;
  if (r >= 7.6 && r < 10) return lit < -4 ? K.wa : lit > 4 ? K.wc : K.wb;
  if (r >= 10 && r < 10.7) return K.we;
  if (sp > 0 && r < 13.6) return r > 12.6 ? K.wd : lit < 0 ? K.wb : K.wc;
  return null;
});

export const CABIN_WALL = {
  cb_porthole: { name: '둥근 창', grade: 2, kind: 'window', cat: '창문', w: 26 / 16, h: 26, rects: porthole },
  cb_ship_lamp: { name: '뱃등', grade: 2, kind: 'deco', cat: '조명', w: 1, h: lampRows.length, rects: rowsArt(lampRows, LAMP_PAL) },
  cb_fish_mount: { name: '물고기 박제 판', grade: 3, kind: 'deco', cat: '장식', w: 26 / 16, h: 16, rects: fishPlaque },
  cb_anchor_rack: { name: '닻 걸개', grade: 3, kind: 'deco', cat: '장식', w: 28 / 16, h: 34, rects: anchorArt },
  cb_helm: { name: '키 장식', grade: 4, kind: 'deco', cat: '장식', w: 28 / 16, h: 28, rects: helmArt },
};

export const CABIN_PAPER = {
  cb_sailcloth: { name: '돛천 휘장', grade: 2, c: '#d6be88', l: '#e6d2a0', pat: 'stripe' },
};

export const CABIN_GROUND = {
  cb_deck: { name: '뱃판 바닥', grade: 2, a: '#9c6438', b: '#8a5630', pat: 'plank' },
};
