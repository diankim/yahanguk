// 세계 지도의 물길: 낚시터가 있는 물가 지역을 이은 강·호수·늪·수로·심연과 해안의 얕은 물.
// 화면에만 그리는 장식이라 서버에 없다. 지역 좌표(world_x·world_y) 위에 손으로 그렸으므로
// 지역 좌표를 옮기면 이 파일도 함께 고친다. 물 하나마다 in: 그 지역이 지도에 있을 때만 그린다(귀허도는 열린 뒤).

// 강: [x, y, 폭] 점을 매끄럽게 잇고 내려갈수록 넓어진다. ice: 앞에서 몇 구간이 얼음물인지.
const RIVERS = [
  { in: 'sky_lake', ice: 4, pts: [[480,122,3],[472,150,3.4],[458,182,3.8],[446,212,4.2],[449,242,4.8],[458,272,5.2],[470,298,5.8],[500,312,6.2],[540,306,6.8],[585,313,7.2],[625,318,7.8],[655,314,8.2],[695,322,8.8],[722,336,9.2],[770,323,10],[805,306,10.8],[838,302,11.6],[864,324,12.6],[886,352,14],[918,372,15],[938,381,15.5]] },   // 끝은 만조의 갑문 해안(약 942) 안쪽에서 멈춘다(968까지 그려 땅 밖 바다로 삐져나왔다)
  { in: 'mirror_pavilion', small: 1, pts: [[762,244,2.4],[765,272,2.8],[767,300,3.2],[770,322,3.6]] },
  { in: 'salt_village', small: 1, pts: [[640,318,2.6],[650,340,2.8],[662,360,3],[676,380,3.1],[690,404,3.3],[704,428,3.5]] },
];
// 수로: 꺾인 직선, under는 땅 밑(점선)
const CANALS = [
  { in: 'old_canal', pts: [[468,300],[444,294],[422,290]], w: 3.6 },
  { in: 'old_canal', pts: [[422,290],[408,286],[400,302],[388,322],[380,340]], w: 3.2, under: 1 },
];
// 못: [x, y, 반지름, 가로, 세로]
const POOLS = [
  { in: 'sky_lake', at: [490,98,30,1.25,0.7], ice: 1, ripple: 1 },
  { in: 'mirror_pavilion', at: [760,230,18,1.25,0.75], ripple: 1 },
  { in: 'sunken_district', at: [370,362,20,1.1,0.85] },
  { in: 'sealed_garden', at: [553,416,12,1.2,0.8], lotus: 5, small: 1 },
  { in: 'glass_canyon', at: [138,260,17,1.3,0.8], ripple: 1 },   // 월영 유리못
  { in: 'lotus_marsh', at: [726,352,15,1.4,0.75] }, { in: 'lotus_marsh', at: [756,348,12,1.3,0.85] },
  { in: 'lotus_marsh', at: [750,312,9,1.4,0.8], small: 1 }, { in: 'lotus_marsh', at: [708,330,9,1.3,0.85], small: 1 }, { in: 'lotus_marsh', at: [772,340,7,1.2,0.9], small: 1 },
  { in: 'ash_reeds', at: [418,888,9,1.3,0.8] }, { in: 'ash_reeds', at: [444,920,8,1.2,0.8] }, { in: 'ash_reeds', at: [412,925,6,1.3,0.8], small: 1 },
];
const REEDS = { lotus_marsh: [[720,358],[742,334],[766,338],[735,306],[704,340],[760,356]], ash_reeds: [[410,875],[450,905],[430,935],[400,910],[456,930]] };
const ABYSS = [{ in: 'sealed_abyss', at: [530,642,24] }];
const RIFTS = [{ in: 'black_tide_rift', pts: [[702,424],[712,436],[704,448],[720,456],[712,470],[730,476],[748,494],[740,476],[754,468],[734,454],[738,440],[722,436],[716,424]] }];
const WHIRLS = [{ in: 'gwiheo_core', at: [630,1078,20] }];
// 구등대 군도 바깥 작은 섬(땅에 닿는 자리는 뺀다). 남는 섬 가운데 가장 큰 섬 하나에 등대(전에는 큰 섬마다 금빛 점 하나라 빨간 점처럼 보였다)
const ISLES = { in: 'nine_lighthouse', at: [[968,690,13],[996,646,8],[948,742,10],[1012,712,6],[930,770,7],[985,760,5]] };

function smooth(pts) { // Catmull-Rom → 구간마다 베지어 하나
  const segs = [];
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i - 1] || pts[i], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2] || p2;
    segs.push({ p1, c1: [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6], c2: [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6], p2, w: (p1[2] + p2[2]) / 2, i });
  }
  return segs;
}
function ring([x, y, r, sx, sy], seed) {
  const pts = [];
  for (let k = 0; k < 24; k++) { const a = 2 * Math.PI * k / 24, w = 1 + 0.12 * Math.sin(a * 3 + seed) + 0.07 * Math.sin(a * 5 + seed * 2); pts.push([x + Math.cos(a) * r * sx * w, y + Math.sin(a) * r * sy * w]); }
  return pts;
}
function inside(pt, poly) {
  let c = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) { const [xi, yi] = poly[i], [xj, yj] = poly[j]; if ((yi > pt[1]) !== (yj > pt[1]) && pt[0] < (xj - xi) * (pt[1] - yi) / (yj - yi) + xi) c = !c; }
  return c;
}
// 등대: 섬 위에 선 탑(아래가 넓은 사다리꼴 · 가운데 띠 · 불빛 방 · 지붕)과 가까이 볼 때만 양옆으로 퍼지는 불빛
function lighthouse(cx, by, s, near) {
  const f = v => v.toFixed(1), h = 13 * s, bw = 3.2 * s, tw = 2 * s, top = by - h;
  const body = `M${f(cx - bw)},${f(by)}L${f(cx - tw)},${f(top + 3 * s)}L${f(cx + tw)},${f(top + 3 * s)}L${f(cx + bw)},${f(by)}Z`;
  const yb = by - h * .45, wb = bw - (bw - tw) * .55, yb2 = yb - 2.2 * s, wb2 = bw - (bw - tw) * .72;
  const band = `M${f(cx - wb)},${f(yb)}L${f(cx - wb2)},${f(yb2)}L${f(cx + wb2)},${f(yb2)}L${f(cx + wb)},${f(yb)}Z`;
  const lamp = `<rect x="${f(cx - tw * .9)}" y="${f(top + .8 * s)}" width="${f(tw * 1.8)}" height="${f(2.2 * s)}" class="w-lh-lamp"/>`;
  const roof = `M${f(cx - tw * 1.2)},${f(top + .9 * s)}L${f(cx)},${f(top - 1.6 * s)}L${f(cx + tw * 1.2)},${f(top + .9 * s)}Z`;
  const ly = top + 1.9 * s;
  const rays = near ? `<path d="M${f(cx - tw)},${f(ly)}L${f(cx - 14 * s)},${f(ly - 4 * s)}L${f(cx - 14 * s)},${f(ly + 4 * s)}ZM${f(cx + tw)},${f(ly)}L${f(cx + 14 * s)},${f(ly - 4 * s)}L${f(cx + 14 * s)},${f(ly + 4 * s)}Z" class="w-lh-ray"/>` : '';
  return `<g class="w-lh">${rays}<path d="${body}" class="w-lh-body"/><path d="${band}" class="w-lh-band"/>${lamp}<path d="${roof}" class="w-lh-roof"/></g>`;
}
let isleCache = null, isleCells = null;
function isles(cells) {
  if (isleCells === cells) return isleCache;
  const land = ([x, y], pad) => [...cells.values()].some(poly => inside([x, y], poly) || poly.some(p => Math.hypot(p[0] - x, p[1] - y) < pad));
  isleCells = cells; isleCache = ISLES.at.filter(([x, y, r]) => !land([x, y], r + 6));
  return isleCache;
}

// 바다낚시를 할 수 있는 지역: 바다 물가 넷 + 바다 낚시터가 있는 다섯. 지도에서 이 지역의 해안만 물빛으로 짚는다.
// 서버 world_fish_spot의 바다 낚시터가 바뀌면 여기도 고친다(화면만의 장식, 서버에 묻지 않는다)
export const SEA_FISH = new Set(['ash_coast', 'nine_lighthouse', 'salt_village', 'tide_gate', 'hidden_bazaar', 'frost_valley', 'crimson_mine', 'red_moon_fort', 'star_observatory']);
const seg = (e, X, Y) => `M${X(e.p[0]).toFixed(1)},${Y(e.p[1]).toFixed(1)}L${X(e.q[0]).toFixed(1)},${Y(e.q[1]).toFixed(1)}`;

// 해안의 얕은 물 띠(땅보다 먼저 그려 바깥쪽 반만 보인다). 바다낚시 지역 앞바다는 띠를 조금 더 짙게(.sea)
export function waterUnder(g, X, Y, k) {
  let d = '', sea = '';
  for (const e of g.edges) if (!e.b) { d += seg(e, X, Y); if (SEA_FISH.has(e.a)) sea += seg(e, X, Y); }
  return (d ? `<path d="${d}" class="w-shallow" style="opacity:.45" stroke-width="${(34 * k).toFixed(1)}"/><path d="${d}" class="w-shallow" stroke-width="${(16 * k).toFixed(1)}"/>` : '')
    + (sea ? `<path d="${sea}" class="w-shallow sea" stroke-width="${(22 * k).toFixed(1)}"/>` : '');
}

// 땅 위·국경 아래. zoom이 낮으면(멀리) 잔 물줄기·갈대·연꽃은 그리지 않는다.
export function waterOver(g, has, X, Y, k, zoom) {
  const near = zoom >= 1.35, f = v => v.toFixed(1), P = p => `${f(X(p[0]))},${f(Y(p[1]))}`;
  const ringPath = (at, seed) => 'M' + ring(at, seed).map(P).join('L') + 'Z';
  let bank = '', flow = '', ice = '', under = '', pools = '', reeds = '', dark = '', isl = '';
  for (const rv of RIVERS) {
    if (!has(rv.in) || (rv.small && !near)) continue;
    for (const s of smooth(rv.pts)) {
      const d = `M${P(s.p1)}C${P(s.c1)} ${P(s.c2)} ${P(s.p2)}`, w = Math.max(1.2, s.w * k);
      bank += `<path d="${d}" stroke-width="${f(w + 2)}"/>`;
      if (rv.ice && s.i < rv.ice) ice += `<path d="${d}" stroke-width="${f(w)}"/>`; else flow += `<path d="${d}" stroke-width="${f(w)}"/>`;
    }
  }
  for (const c of CANALS) {
    if (!has(c.in) || !near) continue;
    const d = 'M' + c.pts.map(P).join('L'), w = Math.max(1, c.w * k);
    if (c.under) under += `<path d="${d}" stroke-width="${f(w)}"/>`;
    else { bank += `<path d="${d}" stroke-width="${f(w + 2)}" stroke-linejoin="miter"/>`; flow += `<path d="${d}" stroke-width="${f(w)}" stroke-linejoin="miter"/>`; }
  }
  POOLS.forEach((p, i) => {
    if (!has(p.in) || (p.small && !near)) return;
    pools += `<path d="${ringPath(p.at, i + 1)}" class="w-pool${p.ice ? ' ice' : ''}"/>`;
    const [x, y, r, sx, sy] = p.at;
    if (p.ripple && near) pools += `<path d="M${P([x - r * sx * .5, y + r * sy * .1])}q${f(r * .25 * k)},${f(-r * .18 * k)} ${f(r * .5 * k)},0t${f(r * .5 * k)},0M${P([x - r * sx * .2, y + r * sy * .45])}q${f(r * .2 * k)},${f(-r * .15 * k)} ${f(r * .4 * k)},0t${f(r * .4 * k)},0" class="w-ripple"/>`;
    if (p.lotus && near) for (let j = 0; j < p.lotus; j++) { const a = j * 2.4 + 0.5; pools += `<circle cx="${f(X(x + Math.cos(a) * r * .6))}" cy="${f(Y(y + Math.sin(a) * r * .45))}" r="1.8" class="w-lotus"/>`; }
  });
  if (near) for (const [id, list] of Object.entries(REEDS)) if (has(id)) for (const p of list) { const [x, y] = [X(p[0]), Y(p[1])]; reeds += `M${f(x)},${f(y)}l-1.5,-6M${f(x + 2)},${f(y)}l0.5,-7M${f(x + 4)},${f(y)}l2,-5`; }
  for (const r of RIFTS) if (has(r.in)) dark += `<path d="M${r.pts.map(P).join('L')}Z" class="w-rift"/>`;
  for (const a of ABYSS) if (has(a.in)) {
    const [x, y, r] = a.at;
    dark += `<path d="${ringPath([x, y, r, 1.15, 0.85], 7)}" class="w-abyss"/>`;
    for (let j = 1; j <= 2; j++) dark += `<ellipse cx="${f(X(x))}" cy="${f(Y(y))}" rx="${f(r * 1.15 * (1 - j * .3) * k)}" ry="${f(r * .85 * (1 - j * .3) * k)}" class="w-abyss-ring"/>`;
  }
  for (const w of WHIRLS) if (has(w.in)) {
    const [x, y, r] = w.at; let d = '';
    for (let t = 0; t <= 3.2 * Math.PI; t += 0.25) { const rr = r * (1 - t / (3.4 * Math.PI)); d += (d ? 'L' : 'M') + P([x + Math.cos(t) * rr * 1.2, y + Math.sin(t) * rr * 0.8]); }
    dark += `<path d="${ringPath([x, y, r, 1.2, 0.8], 4)}" class="w-abyss"/><path d="${d}" class="w-whirl"/>`;
  }
  if (has(ISLES.in)) {
    const list = isles(g.cells);
    list.forEach(([x, y, r], i) => { isl += `<path d="${ringPath([x, y, r, 1.2, 0.85], i + 3)}" class="w-isle"/>`; });
    const big = list.reduce((m, v) => (!m || v[2] > m[2] ? v : m), null);
    if (big && big[2] >= 8) isl += lighthouse(X(big[0]), Y(big[1] + big[2] * .25), Math.max(.8, Math.min(1.6, k * 1.1)), near);
  }
  return `<g class="water">${isl}<g class="w-bank">${bank}</g><g class="w-flow">${flow}</g><g class="w-ice">${ice}</g><g class="w-under">${under}</g>${pools}${reeds ? `<path d="${reeds}" class="w-reed"/>` : ''}${dark}</g>`;
}
