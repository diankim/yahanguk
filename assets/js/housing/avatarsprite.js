import { AV } from './avatar.js';
import { P } from './render.js';

const OUT = [40, 28, 24];
const SLOTS = [['skin', 'skins'], ['hair', 'hair'], ['hair_color', 'hairColors'], ['eyes', 'eyes'], ['eye_color', 'eyeColors'], ['mouth', 'mouth'], ['top', 'top'], ['bottom', 'bottom']];
const rgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const hex = c => '#' + c.map(v => v.toString(16).padStart(2, '0')).join('');

export function defaultLook(job) {
  const d = AV.jobDefault[job] || AV.jobDefault.artificer;
  return { skin: 'warm', hair: 'short', hair_color: 'brown', eyes: 'round', eye_color: 'brown', mouth: 'small', top: d.top, bottom: d.bottom, acc: '' };
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

export function avatarPixels(look, frame = 'stand') {
  const l = fixLook(look), W = AW, H = AH, px = new Array(W * H).fill(null);
  const base = { ...AV.fixed, ...AV.skins[l.skin], ...AV.hairColors[l.hair_color], ...AV.eyeColors[l.eye_color] };
  const step = frame === 'walk' ? 'walk' : 'stand', hair = AV.hair[l.hair], top = AV.top[l.top], bot = AV.bottom[l.bottom];
  put(px, hair.back, base);
  put(px, AV.body[step], base);
  put(px, bot[step], { ...base, ...bot.pal });
  put(px, top.part, { ...base, ...top.pal });
  put(px, AV.eyes[l.eyes][frame === 'blink' ? 'closed' : 'open'], base);
  put(px, AV.mouth[l.mouth].part, base);
  put(px, hair.front, base);
  if (l.acc) put(px, AV.acc[l.acc].part, { ...base, ...AV.acc[l.acc].pal });
  const out = px.slice();
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (px[y * W + x]) continue;
    let best = null, sum = 1e9;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= W || ny >= H || !px[ny * W + nx]) continue;
      const c = rgb(px[ny * W + nx]).map((v, i) => Math.round(v * 0.25 + OUT[i] * 0.75)), s = c[0] + c[1] + c[2];
      if (s < sum) { sum = s; best = c; }
    }
    if (best) out[y * W + x] = hex(best);
  }
  return out;
}

export function drawAvatar(putPx, look, frame, x0, y0, flip = false) {
  const px = avatarPixels(look, frame), W = AW, H = AH, gx = Math.round(x0 - W / 2), gy = Math.round(y0 - H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const c = px[y * W + (flip ? W - 1 - x : x)];
    if (c) putPx(gx + x, gy + y, P(c));
  }
}

const cache = new Map();
export function avatarImage(look, { frame = 'stand', scale = 4, job, crop = null } = {}) {
  const l = fixLook(look, job), key = JSON.stringify([l, frame, scale, crop]);
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
