import { AV } from './avatar.js';
import { P } from './render.js';

const OUT = '#1a120e';
const SLOTS = [['skin', 'skins'], ['hair', 'hair'], ['hair_color', 'hairColors'], ['eyes', 'eyes'], ['eye_color', 'eyeColors'], ['mouth', 'mouth'], ['top', 'top'], ['bottom', 'bottom']];

export function defaultLook(job) {
  const d = AV.jobDefault[job] || AV.jobDefault.artificer;
  return { skin: 'warm', hair: 'calm', hair_color: 'brown', eyes: 'round', eye_color: 'brown', mouth: 'small', top: d.top, bottom: d.bottom, acc: '' };
}

export function fixLook(look, job) {
  const d = defaultLook(job), l = { ...d, ...(look || {}) };
  for (const [k, t] of SLOTS) if (!AV[t][l[k]]) l[k] = d[k];
  if (l.acc && !AV.acc[l.acc]) l.acc = '';
  return l;
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
export function registerDesigns(map) {
  for (const [id, d] of Object.entries(map || {})) if (d && d.px) designs.set(String(id), d);
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

export function avatarPixels(look, frame = 'stand') {
  const l = fixLook(look), W = AW, H = AH, px = new Array(W * H).fill(null);
  const base = { ...AV.fixed, ...AV.skins[l.skin], ...AV.hairColors[l.hair_color], ...AV.eyeColors[l.eye_color] };
  const step = frame === 'walk' ? 'walk' : 'stand', hair = AV.hair[l.hair], top = AV.top[l.top], bot = AV.bottom[l.bottom];
  put(px, hair.back, base);
  put(px, AV.body[step], base);
  const bd = designOf(l, 'bottom'), td = designOf(l, 'top');
  if (bd) putDesign(px, bot[step], designPal({ ...base, ...bot.pal }, bot.mask, bd), bot.mask, bd, step === 'walk' ? bot.mask.walk : null);
  else put(px, bot[step], { ...base, ...bot.pal });
  if (td) putDesign(px, top.part, designPal({ ...base, ...top.pal }, top.mask, td), top.mask, td, null);
  else put(px, top.part, { ...base, ...top.pal });
  put(px, AV.eyes[l.eyes][frame === 'blink' ? 'closed' : 'open'], base);
  put(px, AV.mouth[l.mouth].part, base);
  put(px, hair.front, base);
  if (l.acc) put(px, AV.acc[l.acc].part, { ...base, ...AV.acc[l.acc].pal });
  const out = px.slice();
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (px[y * W + x]) continue;
    if ([[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => { const nx = x + dx, ny = y + dy; return nx >= 0 && ny >= 0 && nx < W && ny < H && px[ny * W + nx]; })) out[y * W + x] = OUT;
  }
  return out;
}

const pxCache = new Map();
export function drawAvatar(putPx, look, frame, x0, y0, flip = false, job) {
  const l = fixLook(look, job), key = JSON.stringify([l, frame, !!designOf(l, 'top'), !!designOf(l, 'bottom')]);
  if (!pxCache.has(key)) { if (pxCache.size > 64) pxCache.clear(); pxCache.set(key, avatarPixels(l, frame)); }
  const px = pxCache.get(key), W = AW, H = AH, gx = Math.round(x0 - W / 2), gy = Math.round(y0 - H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const c = px[y * W + (flip ? W - 1 - x : x)];
    if (c) putPx(gx + x, gy + y, P(c));
  }
}

const cache = new Map();
export function avatarImage(look, { frame = 'stand', scale = 4, job, crop = null } = {}) {
  const l = fixLook(look, job), key = JSON.stringify([l, frame, scale, crop, !!designOf(l, 'top'), !!designOf(l, 'bottom')]);
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
