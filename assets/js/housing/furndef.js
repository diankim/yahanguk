import { FUR } from './furniture.js';
import { GAMEDATA as GD } from '../gamedata.js';

export const FURN = GD.furn || { sizes: { '1x1': { w: 1, d: 1, pw: 32, ph: 56 }, '2x1': { w: 2, d: 1, pw: 48, ph: 64 }, '2x2': { w: 2, d: 2, pw: 64, ph: 72 } }, colors: 16, keep: 20, item: 'furn_pattern', tops: [0, 0.42, 0.92, 1.6], pets: ['bed', 'bowl', 'toy', 'perch'], mats: {} };
export const sizeOf = k => FURN.sizes[k] || FURN.sizes['1x1'];
export const palOf = s => (String(s || '').match(/.{6}/g) || []).map(c => '#' + c);

export function sprOf(size, pal, px) {
  const z = sizeOf(size), n = z.pw * z.ph, s = String(px || '');
  return { w: z.pw, h: z.ph, pal: palOf(pal), front: s.slice(0, n), back: s.length >= 2 * n ? s.slice(n, 2 * n) : null };
}

export function registerFurns(map) {
  for (const [k, f] of Object.entries(map || {})) {
    FUR[k] = { name: f.name, grade: 2, W: f.W || 1, D: f.D || 1, layer: f.layer || 'floor', cat: '직접 그림', top: f.top || undefined, pet: f.pet || undefined, petKind: f.pk || undefined,
      parts: f.gone || !f.px ? [{ x: .08, y: .08, w: (f.W || 1) - .16, d: (f.D || 1) - .16, h: .18, c: '#6b6560' }] : [], spr: f.gone || !f.px ? null : sprOf(f.size, f.pal, f.px), fd: { grp: f.grp, a: f.a, gone: !!f.gone } };
  }
}

const cache = new Map();
export function furnPicURL(size, pal, px, { scale = 3, back = false, flip = false } = {}) {
  const key = `${size}:${pal}:${scale}:${back}:${flip}:${px}`;
  if (cache.has(key)) return cache.get(key);
  const s = sprOf(size, pal, px), v = back && s.back ? s.back : s.front, c = document.createElement('canvas');
  c.width = s.w * scale; c.height = s.h * scale;
  const g = c.getContext('2d');
  for (let y = 0; y < s.h; y++) for (let x = 0; x < s.w; x++) { const ch = v[y * s.w + (flip ? s.w - 1 - x : x)]; if (ch && ch !== '.') { g.fillStyle = s.pal[parseInt(ch, 16)] || '#000'; g.fillRect(x * scale, y * scale, scale, scale); } }
  const url = c.toDataURL(); if (cache.size > 120) cache.clear(); cache.set(key, url);
  return url;
}
