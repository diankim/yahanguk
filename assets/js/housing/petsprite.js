// 꼬마 동무 그림 도우미(7.2): pets.js의 글자 격자를 색으로 바꿔 두고, 별채 방·조사원 카드·도감이 함께 쓴다.
import { PETS, EFFECTS } from './pets.js';
import { P, drawSprite } from './render.js';

const packed = new Map();
const pal = p => { if (!packed.has(p)) packed.set(p, Object.fromEntries(Object.entries(p).map(([c, h]) => [c, P(h)]))); return packed.get(p); };
export const formOf = (id, adult) => { const s = PETS[id]; return s ? (adult ? s.adult : s.baby) : null; };
// 방 그리개(render.js)의 put으로 찍는다. x0,y0는 발밑 가운데.
export function drawPet(put, id, adult, frame, x0, y0, flip) {
  const f = formOf(id, adult); if (!f) return;
  const rows = f[frame] || f.idle, w = rows[0].length;
  drawSprite(put, rows, pal(f.pal), Math.round(x0 - w / 2), Math.round(y0 - rows.length), flip);
}
export function drawEffect(put, key, x0, y0) {
  const e = EFFECTS[key]; if (!e) return;
  drawSprite(put, e.rows, pal(e.pal), Math.round(x0 - e.rows[0].length / 2), Math.round(y0 - e.rows.length), false);
}
// 작은 그림(도감·카드): 캔버스 dataURL. dark면 실루엣(아직 못 만난 동무)
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
