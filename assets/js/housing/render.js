// 별채 도트 그림(7.2): 작은 픽셀 버퍼에 번짐 없이 직접 찍고 캔버스를 정수 배율로 키운다(2026-10-29 시안 minihome_px를 옮김).
// 방은 N×N 칸(6~9), 가구는 칸 단위 W×D와 부품(상자·타원)으로 정의한다(housing/furniture.js). 벽 장식은 왼쪽·오른쪽 벽에 건다.
// 이 파일은 그리기만 한다. 놓기·겹침 검사는 화면(views/housing.js)과 서버(world_housing_save)가 함께 한다.
export const TW = 32, TH = 16, ZU = 20, WALLH = 78, PAD = 10;
const rgb = h => { const n = parseInt(String(h).slice(1), 16); return [n >> 16 & 255, n >> 8 & 255, n & 255]; };
export const pack = (r, g, b) => (255 << 24 | b << 16 | g << 8 | r) >>> 0;
export const sh = (h, k) => { const [r, g, b] = rgb(h); const f = c => Math.max(0, Math.min(255, Math.round(c * k))); return pack(f(r), f(g), f(b)); };
export const P = h => sh(h, 1);
export const OUT = pack(26, 18, 14);
const hash = (x, y) => { let h = x * 374761393 + y * 668265263; h = (h ^ (h >>> 13)) * 1274126177; return ((h ^ (h >>> 16)) >>> 0) / 4294967295; };

// 방 하나를 그리는 그리개. defs = { FUR, WALL, PAPER, GROUND } (furniture.js)
export function makeRoom(N, defs) {
  const O = { x: N * TW / 2 + PAD, y: WALLH + PAD + 4 };
  const W = N * TW + PAD * 2, H = O.y + N * TH + 12;
  const iso = (gx, gy, z = 0) => [O.x + (gx - gy) * TW / 2, O.y + (gx + gy) * TH / 2 - z];
  const main = new Uint32Array(W * H), ids = new Int16Array(W * H), layer = new Uint32Array(W * H);
  let bb;
  const { FUR, WALL, PAPER, GROUND } = defs;
  function put(buf, x, y, c) { x |= 0; y |= 0; if (x < 0 || y < 0 || x >= W || y >= H) return; buf[y * W + x] = c; if (buf === layer) { if (x < bb[0]) bb[0] = x; if (y < bb[1]) bb[1] = y; if (x > bb[2]) bb[2] = x; if (y > bb[3]) bb[3] = y; } }
  function fillPoly(buf, pts, c) {
    const ys = pts.map(p => p[1]); const y0 = Math.max(0, Math.floor(Math.min(...ys))), y1 = Math.min(H - 1, Math.ceil(Math.max(...ys)));
    for (let y = y0; y <= y1; y++) {
      const sy = y + .5, xs = [];
      for (let i = 0; i < pts.length; i++) { const a = pts[i], b = pts[(i + 1) % pts.length]; if ((a[1] <= sy && b[1] > sy) || (b[1] <= sy && a[1] > sy)) xs.push(a[0] + (sy - a[1]) * (b[0] - a[0]) / (b[1] - a[1])); }
      xs.sort((p, q) => p - q);
      for (let i = 0; i + 1 < xs.length; i += 2) for (let x = Math.ceil(xs[i] - .5); x <= Math.floor(xs[i + 1] - .5); x++) put(buf, x, y, c);
    }
  }
  function fillEll(buf, cx, cy, rx, ry, c) {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) { const dy = (y + .5 - cy) / ry; if (Math.abs(dy) > 1) continue; const dx = rx * Math.sqrt(1 - dy * dy); for (let x = Math.ceil(cx - dx - .5); x <= Math.floor(cx + dx - .5); x++) put(buf, x, y, c); }
  }
  function line(buf, a, b, c, dash) {
    let [x0, y0] = a.map(Math.round), [x1, y1] = b.map(Math.round); const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1; let e = dx + dy, n = 0;
    for (;;) { if (!dash || (n++ % 4) < 2) put(buf, x0, y0, c); if (x0 === x1 && y0 === y1) break; const e2 = 2 * e; if (e2 >= dy) { e += dy; x0 += sx; } if (e2 <= dx) { e += dx; y0 += sy; } }
  }
  function begin() { layer.fill(0); bb = [W, H, -1, -1]; }
  function commit(id, outline = true) {
    if (bb[2] < 0) return;
    if (outline) {
      const add = [];
      for (let y = Math.max(0, bb[1] - 1); y <= Math.min(H - 1, bb[3] + 1); y++) for (let x = Math.max(0, bb[0] - 1); x <= Math.min(W - 1, bb[2] + 1); x++) {
        const i = y * W + x; if (layer[i]) continue;
        if ((x > 0 && layer[i - 1]) || (x < W - 1 && layer[i + 1]) || (y > 0 && layer[i - W]) || (y < H - 1 && layer[i + W])) add.push(i);
      }
      for (const i of add) layer[i] = OUT;
      bb = [bb[0] - 1, bb[1] - 1, bb[2] + 1, bb[3] + 1];
    }
    for (let y = Math.max(0, bb[1]); y <= Math.min(H - 1, bb[3]); y++) for (let x = Math.max(0, bb[0]); x <= Math.min(W - 1, bb[2]); x++) { const i = y * W + x; if (layer[i]) { main[i] = layer[i]; ids[i] = id; } }
  }

  const dims = it => { const f = FUR[it.k]; if (!f) return [1, 1]; return it.r % 2 ? [f.D, f.W] : [f.W, f.D]; };
  function rotParts(f, r) {
    let Wd = f.W, ps = f.parts.map(p => Object.assign({ z: 0, t: 'box' }, p));
    for (let i = 0; i < r; i++) { ps = ps.map(p => p.t === 'ell' ? Object.assign({}, p, { x: p.y, y: Wd - p.x }) : Object.assign({}, p, { x: p.y, y: Wd - p.x - p.w, w: p.d, d: p.w })); Wd = i % 2 ? f.W : f.D; }
    const key = p => p.t === 'ell' ? p.x + p.y : p.x + p.w / 2 + p.y + p.d / 2;
    return ps.sort((a, b) => (key(a) - key(b)) || (a.z - b.z));
  }
  function drawBox(gx, gy, p, z0) {
    const x = gx + p.x, y = gy + p.y, z = p.z * ZU + z0, h = Math.max(1, p.h * ZU);
    const top = [iso(x, y, z + h), iso(x + p.w, y, z + h), iso(x + p.w, y + p.d, z + h), iso(x, y + p.d, z + h)];
    fillPoly(layer, [iso(x, y + p.d, z + h), iso(x + p.w, y + p.d, z + h), iso(x + p.w, y + p.d, z), iso(x, y + p.d, z)], sh(p.c, .8));
    fillPoly(layer, [iso(x + p.w, y, z + h), iso(x + p.w, y + p.d, z + h), iso(x + p.w, y + p.d, z), iso(x + p.w, y, z)], sh(p.c, .62));
    fillPoly(layer, top, P(p.c));
    if (h >= 3) { const hl = sh(p.c, 1.18); line(layer, top[0], top[1], hl); line(layer, top[0], top[3], hl); }
  }
  // it.z0: 소품을 올린 가구의 윗면 높이(칸 높이 단위)
  function drawItem(it) {
    const z0 = (it.z0 || 0) * ZU;
    for (const p of rotParts(FUR[it.k], it.r || 0)) {
      if (p.t === 'ell') { const [cx, cy] = iso(it.x + p.x, it.y + p.y, p.z * ZU + z0); fillEll(layer, cx, cy, p.rx, p.ry, P(p.c)); fillEll(layer, cx - p.rx * .3, cy - p.ry * .35, Math.max(1, p.rx * .35), Math.max(1, p.ry * .3), sh(p.c, 1.14)); }
      else drawBox(it.x, it.y, p, z0);
    }
  }
  const wallPoly = (side, t, z, w, h) => side === 'R' ? [iso(t, 0, z), iso(t + w, 0, z), iso(t + w, 0, z + h), iso(t, 0, z + h)] : [iso(0, t, z), iso(0, t + w, z), iso(0, t + w, z + h), iso(0, t, z + h)];
  const glyphCache = {};
  function glyphs(text) {
    if (glyphCache[text]) return glyphCache[text];
    const c = document.createElement('canvas'); c.width = 40; c.height = 14; const g = c.getContext('2d');
    g.fillStyle = '#fff'; g.font = 'bold 11px serif'; g.textBaseline = 'middle'; g.textAlign = 'center'; g.fillText(text, 20, 7.5);
    const d = g.getImageData(0, 0, 40, 14).data, out = []; for (let y = 0; y < 14; y++) for (let x = 0; x < 40; x++) if (d[(y * 40 + x) * 4 + 3] > 140) out.push([x, y]);
    return glyphCache[text] = out;
  }
  // 벽 장식: 부품(rects: [t0, z0, w, h, 색])과 글자(text: [글, 색])로 그린다
  function drawWallItem(it) {
    const d = WALL[it.k]; if (!d) return;
    for (const [t0, z0, w0, h0, col] of d.rects || []) fillPoly(layer, wallPoly(it.side, it.t + t0, it.z + z0, w0, h0), P(col));
    if (d.text) {
      const [ox, oy] = it.side === 'R' ? iso(it.t + d.w / 2, 0, it.z + d.h / 2) : iso(0, it.t + d.w / 2, it.z + d.h / 2); const s = it.side === 'R' ? .5 : -.5;
      for (const [gx, gy] of glyphs(d.text[0])) { const u = gx - 20, v = gy - 7; put(layer, ox + u, oy + v + u * s, P(d.text[1] || '#d8b25a')); }
    }
  }

  function background(st, bgCol) {
    const pp = PAPER[st.paper] || Object.values(PAPER)[0], gg = GROUND[st.ground] || Object.values(GROUND)[0];
    const ga = P(gg.a), gb = P(gg.b), gd = sh(gg.a, .78), gl = sh(gg.a, 1.1);
    const wc = [P(pp.c), sh(pp.c, .84)], wl = [P(pp.l), sh(pp.l, .84)], wd = [sh(pp.c, .7), sh(pp.c, .6)];
    const BG = P(bgCol || '#1b1d24'), dark = '#553420';
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const i = y * W + x, px = x + .5, py = y + .5; ids[i] = -1;
      const a = (px - O.x) / (TW / 2), b = (py - O.y) / (TH / 2), gx = (a + b) / 2, gy = (b - a) / 2;
      if (gx >= 0 && gy >= 0 && gx < N && gy < N) { main[i] = floorPix(gg, gx, gy, ga, gb, gd, gl, x, y); continue; }
      if (gx >= 0 && gy >= 0 && (gx < N + .5 && gy < N + .5) && (gx >= N || gy >= N)) { const e = gx >= N ? iso(N, gy)[1] : iso(gx, N)[1]; if (py - e < 6 && py > e) { main[i] = gx >= N ? sh(gg.a, .42) : sh(gg.a, .55); continue; } }
      let side = -1, t = 0, z = 0;
      if (px < O.x) { t = (O.x - px) / (TW / 2); z = O.y + t * TH / 2 - py; side = 1; } else { t = (px - O.x) / (TW / 2); z = O.y + t * TH / 2 - py; side = 0; }
      if (t >= 0 && t <= N && z >= 0 && z <= WALLH) { main[i] = wallPix(pp, side, t, z, wc, wl, wd, x, y, dark); continue; }
      main[i] = BG;
    }
  }
  // 바닥 무늬: pat(grid 장판 · plank 마루 · mat 자리 · stone 전돌 · check 바둑 · herring 엇결)
  function floorPix(gg, gx, gy, ga, gb, gd, gl, x, y) {
    const u = gx % 1, v = gy % 1, tx = Math.floor(gx), ty = Math.floor(gy);
    switch (gg.pat) {
      case 'plank': { const pl = Math.floor(gy * 3), pv = (gy * 3) % 1; if (pv < .1) return gd; if (((gx + pl * .73) % 2.5) < .05) return gd; return pl % 2 ? gb : (hash(x >> 1, y) < .1 ? gl : ga); }
      case 'mat': { const mat = (tx + ty) % 2, w = mat ? u : v; if (u < .05 || v < .05 || u > .95 || v > .95) return sh(gg.a, .62); return Math.floor(w * 10) % 2 ? gb : ga; }
      case 'stone': if (u < .07 || v < .07) return sh(gg.a, .6); return hash(tx, ty) < .5 ? ga : gb;
      case 'check': if (u < .04 || v < .04) return gd; return ((Math.floor(gx * 2) + Math.floor(gy * 2)) % 2) ? gb : ga;
      case 'herring': { const k = Math.floor(gx * 2 + gy * 2) % 2; if (((gx * 2 - gy * 2) % 1 + 1) % 1 < .08) return gd; return k ? gb : ga; }
      default: if (u < .05 || v < .05) return gd; return (tx + ty) % 2 ? gb : (hash(x, y) < .06 ? gl : ga);
    }
  }
  // 벽 무늬: pat(plain 한지 · stripe 대나무 · dan 먹빛 단청 · lattice 연지 · cloud 구름 · brick 벽돌)
  function wallPix(pp, side, t, z, wc, wl, wd, x, y, dark) {
    if (z < 4) return side ? sh(dark, .85) : P(dark);
    if (z > WALLH - 3) return side ? sh(dark, .7) : sh(dark, .85);
    switch (pp.pat) {
      case 'stripe': { const s = (t * 4) % 1; if (s < .14) return wd[side]; if ((z % 19) < 1.2) return wd[side]; return Math.floor(t * 4) % 2 ? wl[side] : wc[side]; }
      case 'dan': if (z > WALLH - 15) { const dot = Math.hypot(((t % 1) - .5) * TW / 2, (z - (WALLH - 9)) * .9); return dot < 3 ? (side ? sh('#9a3326', .84) : P('#9a3326')) : (side ? sh('#3a7c6d', .84) : P('#3a7c6d')); } if (z > WALLH - 17) return P('#d8b25a'); return hash(x, y) < .04 ? wl[side] : wc[side];
      case 'lattice': { const q = ((t * 3) + z / 10) % 2, r = ((t * 3) - z / 10 + 40) % 2; return (q < .08 || r < .08) ? wl[side] : wc[side]; }
      case 'cloud': { const c = Math.hypot(((t * 2) % 1 - .5) * 10, ((z / 14) % 1 - .5) * 6); return c < 1.6 || (c > 2.4 && c < 2.9) ? wl[side] : wc[side]; }
      case 'brick': { const row = Math.floor(z / 7), off = row % 2 ? .25 : 0; if (z % 7 < 1 || ((t * 2 + off) % 1) < .06) return wd[side]; return hash(Math.floor(t * 2 + off), row) < .3 ? wl[side] : wc[side]; }
      default: if ((z % 16) < 1) return wl[side]; return hash(x, y) < .05 ? wl[side] : wc[side];
    }
  }
  function glow(it) {
    const [w, d] = dims(it), [cx, cy] = iso(it.x + w / 2, it.y + d / 2); const [gr, gg, gb] = [255, 196, 110];
    for (let y = Math.floor(cy - 13); y <= cy + 13; y++) for (let x = Math.floor(cx - 26); x <= cx + 26; x++) {
      if (x < 0 || y < 0 || x >= W || y >= H) continue; const r = Math.hypot((x - cx) / 26, (y - cy) / 13); if (r > 1) continue;
      if (((x + y) & 1) && r > .55) continue; const i = y * W + x, c = main[i], k = r > .55 ? .22 : .3;
      main[i] = pack(Math.round((c & 255) * (1 - k) + gr * k), Math.round((c >> 8 & 255) * (1 - k) + gg * k), Math.round((c >> 16 & 255) * (1 - k) + gb * k));
    }
  }
  // 그리는 순서: 깔개 → 나머지(앞뒤 관계) · 소품은 올린 가구 바로 뒤
  function depthOrder(items) {
    const rugs = items.filter(i => FUR[i.k]?.layer === 'rug'), surf = items.filter(i => FUR[i.k]?.layer === 'surface'), rest = items.filter(i => FUR[i.k] && !['rug', 'surface'].includes(FUR[i.k].layer));
    const key = i => { const [w, d] = dims(i); return i.x + i.y + (w + d) / 2; };
    const behind = (a, b) => { const [aw, ad] = dims(a), [bw, bd] = dims(b); const fa = a.x + aw <= b.x || a.y + ad <= b.y, fb = b.x + bw <= a.x || b.y + bd <= a.y; if (fa && !fb) return true; if (fb && !fa) return false; return key(a) < key(b); };
    const out = [], left = rest.slice().sort((a, b) => key(a) - key(b));
    while (left.length) { const i = left.findIndex(a => !left.some(b => b !== a && behind(b, a))); out.push(left.splice(i < 0 ? 0 : i, 1)[0]); }
    const res = rugs.slice();
    for (const it of out) { res.push(it); for (const s of surf) if (s.host === it) res.push(s); }
    for (const s of surf) if (!res.includes(s)) res.push(s);
    return res;
  }
  // 소품이 올라앉은 가구와 높이를 찾는다
  function hostOf(items, s) {
    for (const o of items) {
      const f = FUR[o.k]; if (!f?.top || o === s) continue; const [w, d] = dims(o);
      if (s.x >= o.x && s.y >= o.y && s.x < o.x + w && s.y < o.y + d) return o;
    }
    return null;
  }

  // st = { paper, ground, items: [{k,x,y,r}], wall: [{k,side,t,z}] }, opts = { sel, bad, bg, pets: [{x,y,draw(put)}] }
  let drawn = [];
  function render(st, opts = {}) {
    background(st, opts.bg); drawn = [];
    for (const it of st.wall || []) {
      begin(); drawWallItem(it); drawn.push(it); commit(drawn.length - 1);
      if (opts.sel === it) { const d = WALL[it.k]; const p = wallPoly(it.side, it.t, it.z, d.w, d.h); const col = opts.bad ? P('#e05a4c') : P('#d8b25a'); for (let k = 0; k < 4; k++) line(main, p[k], p[(k + 1) % 4], col, true); }
    }
    const items = (st.items || []).filter(i => FUR[i.k]);
    for (const s of items) if (FUR[s.k].layer === 'surface') { s.host = hostOf(items, s); s.z0 = s.host ? FUR[s.host.k].top : 0; }
    const order = depthOrder(items);
    for (const it of order) if (FUR[it.k].glow) glow(it);
    const pets = (opts.pets || []).slice();
    for (const it of order) {
      // 펫은 자기 칸보다 뒤(앞뒤 합이 작은) 가구를 다 그린 뒤에 그린다
      while (pets.length && pets[0].x + pets[0].y < it.x + it.y) { const p = pets.shift(); p.draw({ put: (x, y, c) => put(main, x, y, c), iso, main, W, H }); }
      if (opts.sel === it) { const [w, d] = dims(it), q = [iso(it.x, it.y), iso(it.x + w, it.y), iso(it.x + w, it.y + d), iso(it.x, it.y + d)], col = opts.bad ? P('#e05a4c') : P('#d8b25a'); for (let k = 0; k < 4; k++) line(main, q[k], q[(k + 1) % 4], col, true); }
      begin(); drawItem(it); drawn.push(it); commit(drawn.length - 1);
    }
    for (const p of pets) p.draw({ put: (x, y, c) => put(main, x, y, c), iso, main, W, H });
    return new ImageData(new Uint8ClampedArray(main.buffer.slice(0)), W, H);
  }
  // 화면 좌표(버퍼 픽셀) → 그 자리에 그린 물체
  const hit = (bx, by) => { const i = Math.floor(by) * W + Math.floor(bx); return i >= 0 && i < W * H && ids[i] >= 0 ? drawn[ids[i]] : null; };
  const toGrid = (sx, sy) => { const a = (sx - O.x) / (TW / 2), b = (sy - O.y) / (TH / 2); return [(a + b) / 2, (b - a) / 2]; };
  // 고르기 칸의 작은 그림
  const thumbs = {};
  function thumb(k) {
    if (thumbs[k]) return thumbs[k];
    const keep = main.slice(), keepIds = ids.slice(); main.fill(0);
    begin(); if (FUR[k]) drawItem({ k, x: 1, y: 1, r: 0 }); else drawWallItem({ k, side: 'R', t: 2, z: 20 }); commit(0);
    const box = bb.slice(), w = box[2] - box[0] + 1, h = box[3] - box[1] + 1, c = document.createElement('canvas'); c.width = Math.max(1, w); c.height = Math.max(1, h);
    const img = new ImageData(c.width, c.height); const v = new Uint32Array(img.data.buffer); for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) v[y * w + x] = main[(y + box[1]) * W + x + box[0]];
    c.getContext('2d').putImageData(img, 0, 0); main.set(keep); ids.set(keepIds);
    return thumbs[k] = c.toDataURL();
  }
  return { N, W, H, O, iso, dims, render, hit, toGrid, thumb, wallPoly };
}

// 펫 도트: rows(글자 격자) + pal(글자 → 색). '.'은 빈칸
export function drawSprite(put, rows, pal, x0, y0, flip = false) {
  const w = rows[0].length;
  for (let y = 0; y < rows.length; y++) for (let x = 0; x < w; x++) { const ch = rows[y][flip ? w - 1 - x : x]; if (ch !== '.' && pal[ch] != null) put(x0 + x, y0 + y, pal[ch]); }
}
