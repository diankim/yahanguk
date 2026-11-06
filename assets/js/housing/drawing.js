export const PAL = ['#1a1a1f', '#f4efe2', '#8a8a8a', '#c8382e', '#e8833a', '#f2c94c', '#5b9a4b', '#2f6b5a', '#3f6fb5', '#263a73', '#7b4fa0', '#e58fa8', '#8a5a34', '#d9a877', '#4a3020', '#9ad0e0'];
export const PAL_NAMES = ['먹', '한지', '잿빛', '단청 붉음', '주황', '송화', '풀빛', '청록', '쪽빛', '남색', '보라', '도화', '밤색', '살구', '흙빛', '하늘'];
export const SIZES = { S: [16, 16], L: [32, 24] };
export const SIZE_NAME = { S: '작은 그림', L: '큰 그림' };
export const dimsOf = (s, rules) => rules?.sizes?.[s] || SIZES[s] || SIZES.S;

const cache = new Map();
export function picURL(d, scale = 1, bg = '#f6ead0') {
  if (!d?.px) return '';
  const key = `${d.s}:${scale}:${bg}:${d.px}`;
  if (cache.has(key)) return cache.get(key);
  const [w, h] = dimsOf(d.s), c = document.createElement('canvas'); c.width = w * scale; c.height = h * scale;
  const g = c.getContext('2d'); g.fillStyle = bg; g.fillRect(0, 0, c.width, c.height);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const ch = d.px[y * w + x]; if (ch && ch !== '.') { g.fillStyle = PAL[parseInt(ch, 16)]; g.fillRect(x * scale, y * scale, scale, scale); } }
  const url = c.toDataURL(); if (cache.size > 200) cache.clear(); cache.set(key, url);
  return url;
}
