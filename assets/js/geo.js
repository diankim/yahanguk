// 세계 지도의 땅 모양: 지역 좌표마다 물결진 땅덩이를 만들고 이웃 지역과의 수직이등분선으로 잘라
// 보로노이 영역을 얻는다. 영역 경계 중 다른 세력과 맞닿은 선은 국경, 이웃이 없는 선은 해안선이 된다.
// 같은 좌표에서는 항상 같은 모양이 나오므로 서버와 따로 저장할 필요가 없다.

const R = 95, STEPS = 40;

function seedOf(id) {
  let h = 0;
  for (const ch of id) h = (h * 131 + ch.charCodeAt(0)) >>> 0;
  return h;
}
function blob(id, x, y) {
  const s = seedOf(id), pts = [];
  for (let k = 0; k < STEPS; k++) {
    const a = 2 * Math.PI * k / STEPS;
    const w = 1 + 0.18 * Math.sin(a * 3 + s % 7) + 0.10 * Math.sin(a * 5 + s % 11) + 0.06 * Math.sin(a * 9 + s % 5);
    pts.push([x + Math.cos(a) * R * w, y + Math.sin(a) * R * w]);
  }
  return pts;
}
// a*x + b*y <= c 쪽만 남긴다(Sutherland–Hodgman, 볼록한 자르개라 바깥 모양은 오목해도 된다).
function clip(poly, a, b, c) {
  const out = [];
  for (let k = 0; k < poly.length; k++) {
    const p = poly[k], q = poly[(k + 1) % poly.length];
    const fp = a * p[0] + b * p[1] - c, fq = a * q[0] + b * q[1] - c;
    if (fp <= 0) out.push(p);
    if ((fp < 0) !== (fq < 0) && fp !== fq) { const t = fp / (fp - fq); out.push([p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t]); }
  }
  return out;
}

// regions: [{region_id, world_x, world_y}] → { cells: Map(id → poly), edges: [{a, b|null, p, q}] }
export function buildCells(regions) {
  const cells = new Map();
  for (const r of regions) {
    let poly = blob(r.region_id, r.world_x, r.world_y);
    for (const o of regions) {
      if (o === r) continue;
      const a = o.world_x - r.world_x, b = o.world_y - r.world_y;
      poly = clip(poly, a, b, (o.world_x ** 2 + o.world_y ** 2 - r.world_x ** 2 - r.world_y ** 2) / 2);
    }
    cells.set(r.region_id, poly);
  }
  // 각 변이 어느 이웃과의 경계인지 찾는다. 같은 경계가 양쪽에서 나오므로 a<b 쪽만 남긴다.
  const edges = [];
  for (const r of regions) {
    const poly = cells.get(r.region_id);
    for (let k = 0; k < poly.length; k++) {
      const p = poly[k], q = poly[(k + 1) % poly.length];
      if (Math.hypot(p[0] - q[0], p[1] - q[1]) < 0.5) continue;
      let nb = null;
      for (const o of regions) {
        if (o === r) continue;
        const a = o.world_x - r.world_x, b = o.world_y - r.world_y, c = (o.world_x ** 2 + o.world_y ** 2 - r.world_x ** 2 - r.world_y ** 2) / 2;
        const n = Math.hypot(a, b);
        if (Math.abs(a * p[0] + b * p[1] - c) / n < 0.5 && Math.abs(a * q[0] + b * q[1] - c) / n < 0.5) { nb = o.region_id; break; }
      }
      if (nb && nb < r.region_id) continue;
      edges.push({ a: r.region_id, b: nb, p, q });
    }
  }
  return { cells, edges };
}

export function centroid(poly) {
  let x = 0, y = 0, A = 0;
  for (let k = 0; k < poly.length; k++) {
    const [x0, y0] = poly[k], [x1, y1] = poly[(k + 1) % poly.length], f = x0 * y1 - x1 * y0;
    A += f; x += (x0 + x1) * f; y += (y0 + y1) * f;
  }
  return A ? [x / (3 * A), y / (3 * A)] : poly[0];
}

// 세력 색(어두운 바탕에서 구분되되 채도를 낮춘다)
export const FACTION_COLORS = {
  night_office: '#3e5f9a', north_league: '#6f8193', mandate_court: '#a68a3c', river_alliance: '#2f8a80',
  red_moon_cult: '#9a3a3e', black_lotus: '#6a4c8c', southern_remnant: '#9a6a34', null: '#4a4a4f',
};
export function factionColor(id) { return FACTION_COLORS[id] || FACTION_COLORS.null; }
