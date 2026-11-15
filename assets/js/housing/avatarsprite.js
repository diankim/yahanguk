import { AV } from './avatar.js';
import { P } from './render.js';

const OUT = '#1a120e';
const SLOTS = [['skin', 'skins'], ['hair', 'hair'], ['hair_color', 'hairColors'], ['eyes', 'eyes'], ['eye_color', 'eyeColors'], ['mouth', 'mouth'], ['top', 'top'], ['bottom', 'bottom']];

export function defaultLook(job) {
  const d = AV.jobDefault[job] || AV.jobDefault.artificer;
  return { skin: 'warm', hair: 'calm', hair_color: 'brown', eyes: 'round', eye_color: 'brown', mouth: 'small', top: d.top, bottom: d.bottom, acc: '' };
}

export const TONE_KEYS = { skin: ['skin_c', 'skins'], hair_color: ['hair_c', 'hairColors'], eye_color: ['eye_c', 'eyeColors'] };

export function fixLook(look, job) {
  const d = defaultLook(job), l = { ...d, ...(look || {}) };
  for (const [k, t] of SLOTS) if (!AV[t][l[k]]) l[k] = d[k];
  if (l.acc && !AV.acc[l.acc]) l.acc = '';
  for (const [c] of Object.values(TONE_KEYS)) if (l[c] != null && !/^[0-9a-f]{6}$/.test(String(l[c]))) delete l[c];
  return l;
}

export function toned(table, hex) {
  const t = AV.tones[table], out = { [t.key]: hex };
  for (const [k, f] of Object.entries(t.f)) out[k] = shade(hex, f);
  return out;
}

function tonePal(l) {
  const pick = (slot, cur) => { const [c, t] = TONE_KEYS[slot]; return l[c] ? toned(t, '#' + l[c]) : AV[t][cur]; };
  return { ...pick('skin', l.skin), ...pick('hair_color', l.hair_color), ...pick('eye_color', l.eye_color) };
}

function put(px, p, pal) {
  if (!p) return;
  p.rows.forEach((r, y) => {
    for (let x = 0; x < r.length; x++) {
      const c = r[x] === '.' ? null : pal[r[x]];
      if (c) px[(p.y + y + 1) * AW + p.x + x + 1] = c;
    }
  });
}

export const AW = AV.w + 2, AH = AV.h + 2;

const pmod = (a, b) => { let r = a % b; if (r !== 0 && (r < 0) !== (b < 0)) r += b; return r; };
function hls(hex) {
  const n = parseInt(hex.slice(1), 16), r = (n >> 16 & 255) / 255, g = (n >> 8 & 255) / 255, b = (n & 255) / 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2;
  if (mn === mx) return [0, l, 0];
  const s = l <= 0.5 ? (mx - mn) / (mx + mn) : (mx - mn) / (2 - mx - mn);
  const rc = (mx - r) / (mx - mn), gc = (mx - g) / (mx - mn), bc = (mx - b) / (mx - mn);
  let h = r === mx ? bc - gc : g === mx ? 2 + rc - bc : 4 + gc - rc;
  h = pmod(h / 6, 1);
  return [h, l, s];
}
function hv(m1, m2, h) {
  h = pmod(h, 1);
  if (h < 1 / 6) return m1 + (m2 - m1) * h * 6;
  if (h < 0.5) return m2;
  if (h < 2 / 3) return m1 + (m2 - m1) * (2 / 3 - h) * 6;
  return m1;
}
export function shade(hex, f) {
  let [h, l, s] = hls(hex);
  l = Math.max(0, Math.min(1, l * f));
  s = Math.min(1, s * (f < 1 ? 1.15 : 0.9));
  let rgb;
  if (s === 0) rgb = [l, l, l];
  else {
    const m2 = l <= 0.5 ? l * (1 + s) : l + s - l * s, m1 = 2 * l - m2;
    rgb = [hv(m1, m2, h + 1 / 3), hv(m1, m2, h), hv(m1, m2, h - 1 / 3)];
  }
  return '#' + rgb.map(v => Math.trunc(v * 255).toString(16).padStart(2, '0')).join('');
}

const designs = new Map();
let designVer = 0;
export function registerDesigns(map) {
  for (const [id, d] of Object.entries(map || {})) if (d && d.px) {
    const k = String(id), o = designs.get(k);
    if (o && (o.px !== d.px || o.pal !== d.pal || (o.deco || '') !== (d.deco || ''))) designVer++;
    designs.set(k, d);
  }
}
export function faceOf(look) {
  const id = look?.face_d, d = id != null && designs.get(String(id));
  return d && d.slot === 'face' && d.px?.length === AV.face.w * AV.face.h ? d : null;
}
function putFace(px, d) {
  const F = AV.face;
  for (let j = 0; j < F.h; j++) for (let i = 0; i < F.w; i++) {
    const v = d.px[j * F.w + i];
    if (v == null || v === '.') continue;
    const c = d.pal.slice(+v * 6, +v * 6 + 6);
    if (c.length === 6) px[(F.y + j + 1) * AW + F.x + i + 1] = '#' + c;
  }
}
const HB = AV.hairBox, FB = AV.face;
const HEAD = (() => { const b = AV.body.stand, set = new Set(); b.rows.forEach((r, y) => { for (let x = 0; x < r.length; x++) if (r[x] !== '.' && b.y + y <= 23) set.add((b.y + y) * 100 + b.x + x); }); return set; })();
export const hairBlocked = (i, j) => { const x = HB.x + i, y = HB.y + j; return x >= FB.x && x < FB.x + FB.w && y >= FB.y && y < FB.y + FB.h; };
export function hairOf(look) {
  const id = look?.hair_d, d = id != null && designs.get(String(id));
  return d && d.slot === 'hair' && d.px?.length === HB.w * HB.h ? d : null;
}
function putHair(px, d, layer) {
  for (let j = 0; j < HB.h; j++) for (let i = 0; i < HB.w; i++) {
    const v = d.px[j * HB.w + i];
    if (v == null || v === '.' || hairBlocked(i, j)) continue;
    const x = HB.x + i, y = HB.y + j, front = HEAD.has(y * 100 + x);
    if (layer !== 'all' && front !== (layer === 'front')) continue;
    const n = parseInt(v, 16), c = d.pal.slice(n * 6, n * 6 + 6);
    if (c.length === 6) px[(y + 1) * AW + x + 1] = '#' + c;
  }
}
export function hairStart(look) {
  const l = fixLook(look), base = { ...AV.fixed, ...tonePal(l) }, h = AV.hair[l.hair], cell = new Array(HB.w * HB.h).fill(null);
  const lay = (p, back) => p && p.rows.forEach((r, y) => { for (let x = 0; x < r.length; x++) { const c = r[x] === '.' ? null : base[r[x]], i = x + p.x - HB.x, j = y + p.y - HB.y; if (c && i >= 0 && j >= 0 && i < HB.w && j < HB.h && !hairBlocked(i, j) && !(back && HEAD.has((p.y + y) * 100 + p.x + x))) cell[j * HB.w + i] = c; } });
  lay(h.back, true); lay(h.front, false);
  const pal = [], rgb = c => [1, 3, 5].map(k => parseInt(c.slice(k, k + 2), 16));
  for (const c of cell) if (c && !pal.includes(c) && pal.length < 16) pal.push(c);
  const near = c => { if (pal.includes(c)) return pal.indexOf(c); const a = rgb(c); let b = 0, bd = 1e9; pal.forEach((p, k) => { const q = rgb(p), dd = Math.abs(q[0] - a[0]) + Math.abs(q[1] - a[1]) + Math.abs(q[2] - a[2]); if (dd < bd) { bd = dd; b = k; } }); return b; };
  return { pal, px: cell.map(c => c ? near(c).toString(16) : '.') };
}
export function faceStart(look) {
  const l = fixLook(look), base = { ...AV.fixed, ...tonePal(l) }, F = AV.face, cell = new Array(F.w * F.h).fill(null);
  const lay = p => p && p.rows.forEach((r, y) => { for (let x = 0; x < r.length; x++) { const c = r[x] === '.' ? null : base[r[x]], i = x + p.x - F.x, j = y + p.y - F.y; if (c && i >= 0 && j >= 0 && i < F.w && j < F.h) cell[j * F.w + i] = c; } });
  lay(AV.eyes[l.eyes].open); lay(AV.mouth[l.mouth].part);
  const pal = [];
  for (const c of cell) if (c && !pal.includes(c) && pal.length < 8) pal.push(c);
  return { pal, px: cell.map(c => c && pal.includes(c) ? String(pal.indexOf(c)) : '.') };
}
export function designOf(look, slot) {
  const id = look?.[slot + '_d'], d = id != null && designs.get(String(id));
  return d && d.slot === slot && d.base === look[slot] && AV[slot][d.base]?.mask ? d : null;
}
function designPal(pal, mask, d) {
  const out = { ...pal };
  (mask.deco || []).forEach((k, j) => {
    const t = (d.deco || '').slice(j * 6, j * 6 + 6);
    if (/^[0-9a-f]{6}$/.test(t)) { out[k] = '#' + t; if (k === 'z') out.u = shade('#' + t, .7); }
  });
  return out;
}
function putDesign(px, p, pal, mask, d, map) {
  let k = 0;
  p.rows.forEach((r, y) => {
    for (let x = 0; x < r.length; x++) {
      const ch = r[x];
      if (ch === '.') continue;
      let c = pal[ch];
      if ('axyb'.includes(ch)) {
        const i = map ? map[k] : k, v = d.px[i];
        k++;
        if (v != null && v !== '.') {
          const base = '#' + d.pal.slice(+v * 6, +v * 6 + 6);
          if (base.length === 7) c = ch === 'a' ? base : shade(base, ch === 'x' ? 1.14 : ch === 'y' ? 0.74 : mask.bf);
        }
      }
      if (c) px[(p.y + y + 1) * AW + p.x + x + 1] = c;
    }
  });
}

export function avatarPixels(look, frame = 'stand', { front } = {}) {
  const l = fixLook(look), W = AW, H = AH, px = new Array(W * H).fill(null);
  const base = { ...AV.fixed, ...tonePal(l) };
  const step = frame === 'walk' ? 'walk' : 'stand', hair = AV.hair[l.hair], top = AV.top[l.top], bot = AV.bottom[l.bottom];
  const hd = hairOf(l);
  if (hd) putHair(px, hd, 'back'); else put(px, hair.back, base);
  put(px, AV.body[step], base);
  const bd = designOf(l, 'bottom'), td = designOf(l, 'top'), fd = faceOf(l);
  const wear = {
    hair: () => hd && putHair(px, hd, 'all'),
    face: () => fd && putFace(px, fd),
    bottom: () => bd ? putDesign(px, bot[step], designPal({ ...base, ...bot.pal }, bot.mask, bd), bot.mask, bd, step === 'walk' ? bot.mask.walk : null) : put(px, bot[step], { ...base, ...bot.pal }),
    top: () => td ? putDesign(px, top.part, designPal({ ...base, ...top.pal }, top.mask, td), top.mask, td, null) : put(px, top.part, { ...base, ...top.pal }),
  };
  wear.bottom();
  wear.top();
  if (fd) { if (front !== 'face') wear.face(); }
  else { put(px, AV.eyes[l.eyes][frame === 'blink' ? 'closed' : 'open'], base); put(px, AV.mouth[l.mouth].part, base); }
  if (hd) putHair(px, hd, 'front'); else put(px, hair.front, base);
  if (l.acc) put(px, AV.acc[l.acc].part, { ...base, ...AV.acc[l.acc].pal });
  wear[front]?.();
  const out = px.slice();
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (px[y * W + x]) continue;
    if ([[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => { const nx = x + dx, ny = y + dy; return nx >= 0 && ny >= 0 && nx < W && ny < H && px[ny * W + nx]; })) out[y * W + x] = OUT;
  }
  return out;
}

const pxCache = new Map();
export function drawAvatar(putPx, look, frame, x0, y0, flip = false, job) {
  const l = fixLook(look, job), key = JSON.stringify([l, frame, !!designOf(l, 'top'), !!designOf(l, 'bottom'), !!faceOf(l), !!hairOf(l), designVer]);
  if (!pxCache.has(key)) { if (pxCache.size > 64) pxCache.clear(); pxCache.set(key, avatarPixels(l, frame)); }
  const px = pxCache.get(key), W = AW, H = AH, gx = Math.round(x0 - W / 2), gy = Math.round(y0 - H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const c = px[y * W + (flip ? W - 1 - x : x)];
    if (c) putPx(gx + x, gy + y, P(c));
  }
}

const cache = new Map();
export function avatarImage(look, { frame = 'stand', scale = 4, job, crop = null } = {}) {
  const l = fixLook(look, job), key = JSON.stringify([l, frame, scale, crop, !!designOf(l, 'top'), !!designOf(l, 'bottom'), !!faceOf(l), !!hairOf(l), designVer]);
  if (cache.has(key)) return cache.get(key);
  const [cx, cy, cw, ch] = crop || [0, 0, AW, AH];
  const px = avatarPixels(l, frame), c = document.createElement('canvas');
  c.width = cw * scale; c.height = ch * scale;
  const g = c.getContext('2d');
  px.forEach((v, i) => {
    const x = i % AW - cx, y = Math.floor(i / AW) - cy;
    if (v && x >= 0 && y >= 0 && x < cw && y < ch) { g.fillStyle = v; g.fillRect(x * scale, y * scale, scale, scale); }
  });
  const url = c.toDataURL();
  if (cache.size > 400) cache.clear();
  cache.set(key, url);
  return url;
}

export { AV };
