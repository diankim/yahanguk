import { PETS, EFFECTS } from './pets.js';
import { P, drawSprite } from './render.js';

const packed = new Map();
const pal = p => { if (!packed.has(p)) packed.set(p, Object.fromEntries(Object.entries(p).map(([c, h]) => [c, P(h)]))); return packed.get(p); };
export const formOf = (id, adult) => { const s = PETS[id]; return s ? (adult ? s.adult : s.baby) : null; };
export function drawPet(put, id, adult, frame, x0, y0, flip) {
  const f = formOf(id, adult); if (!f) return;
  const rows = f[frame] || f.idle, w = rows[0].length;
  drawSprite(put, rows, pal(f.pal), Math.round(x0 - w / 2), Math.round(y0 - rows.length), flip);
}
export function drawEffect(put, key, x0, y0) {
  const e = EFFECTS[key]; if (!e) return;
  drawSprite(put, e.rows, pal(e.pal), Math.round(x0 - e.rows[0].length / 2), Math.round(y0 - e.rows.length), false);
}
const cache = new Map();
export function petImage(id, adult = false, { frame = 'idle', dark = false, scale = 3 } = {}) {
  const key = `${id}|${adult}|${frame}|${dark}|${scale}`;
  if (cache.has(key)) return cache.get(key);
  const f = formOf(id, adult); if (!f) return '';
  const rows = f[frame] || f.idle, w = rows[0].length, h = rows.length;
  const c = document.createElement('canvas'); c.width = w * scale; c.height = h * scale;
  const g = c.getContext('2d');
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const ch = rows[y][x]; if (ch === '.' || !f.pal[ch]) continue;
    g.fillStyle = dark ? (ch === 'k' ? '#0e0c0a' : '#3a3440') : f.pal[ch];
    g.fillRect(x * scale, y * scale, scale, scale);
  }
  const url = c.toDataURL(); cache.set(key, url); return url;
}
export { PETS };
