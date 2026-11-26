const SHAPES = {
  round: [
    '......kkkk......',
    '......kddk......',
    '....kkkkkkkk....',
    '...kddddddddk...',
    '..kkkkkkkkkkkk..',
    '.kmaahaaaaaaamk.',
    '.kahhaaooaaaamk.',
    'kmahaaoffoaaaamk',
    'kssssssssssssssk',
    'kmaaaaoffoaaaamk',
    'kmaaaaoffoaaaamk',
    'kssssssssssssssk',
    '.kmaaaaooaaaamk.',
    '.kmmaaaaaaaammk.',
    '..kkkkkkkkkkkk..',
    '...kddddddddk...',
    '....kkkkkkkk....',
    '.......gg.......',
    '......gttg......',
    '......gttg......',
    '.......tt.......',
  ],
  cho: [
    '.......kk.......',
    '......kddk......',
    '...kkkkkkkkkk...',
    '..kddddddddddk..',
    '..kkkkkkkkkkkk..',
    '..kssssssssssk..',
    '..kmaahaaaaamk..',
    '..kmahaooaaamk..',
    '..kmahoffoaamk..',
    '..kmaaoffoaamk..',
    '..kmaaoffoaamk..',
    '..kmaaaooaaamk..',
    '..kmaaaaaaaamk..',
    '..kssssssssssk..',
    '..kkkkkkkkkkkk..',
    '..kddddddddddk..',
    '...kkkkkkkkkk...',
    '.....g....g.....',
    '.....t....t.....',
    '.....t....t.....',
  ],
  lotus: [
    '.......kk.......',
    '......kaak......',
    '.....kahaak.....',
    '.....kaooak.....',
    '..k..kaofak..k..',
    '.kak.kaofak.kak.',
    '.kahkkaoofakkhak',
    '.kahakaoofakkahk',
    'kahhakaoofakmaak',
    'kahaamkaoakmmaak',
    'kmaaamskaksmmamk',
    '.kmamsssksssmmk.',
    '..kksssssssskk..',
    '...kkkkkkkkkk...',
    '..kjjjjjjjjjjk..',
    '.kjljjjjjjjjljk.',
    '..kkkkkkkkkkkk..',
  ],
  fish: [
    '.......kk.......',
    '......kmmk......',
    '....kkkkkkk.....',
    '...kaahaaaak..kk',
    '..kahhaaaaamkkak',
    '.kahaaoooaaamkak',
    'kaekaoofoaaammak',
    'kaaaaoffoaaammak',
    '.kmaaaoooaaamkak',
    '..kmsmsmsmsmkkak',
    '...kmmmmmmmk..kk',
    '....kkkkkkk.....',
  ],
};
const BODY = {
  red: { h: '#ffc2b0', a: '#f26a4f', m: '#d6432f', s: '#9c2b25' },
  blue: { h: '#cdeaff', a: '#78b8ee', m: '#4787cc', s: '#2c5c99' },
  yellow: { h: '#fff6c0', a: '#ffd85a', m: '#eda92f', s: '#b47521' },
  white: { h: '#ffffff', a: '#f5efe3', m: '#ddd2bc', s: '#a99d88' },
};
const FIX = { k: '#1a120e', e: '#1a120e', d: '#5a3720', w: '#8f5e36', f: '#fffbe0', o: '#ffe27a', g: '#d8b25a', t: '#c9473b', j: '#4f7a3a', l: '#7fae55' };
const W = 16, BASE = 21, VH = 24;
const cache = new Map();
const colorOf = (ch, c) => BODY[c]?.[ch] || FIX[ch] || null;
function runs(rows, top, paint) {
  const out = [];
  rows.forEach((row, y) => {
    let x = 0;
    while (x < W) {
      const ch = row[x], fill = ch === '.' ? null : paint(ch);
      if (!fill) { x++; continue; }
      let e = x + 1;
      while (e < W && row[e] !== '.' && paint(row[e]) === fill) e++;
      out.push(`<rect x="${x}" y="${top + y}" width="${e - x}" height="1" fill="${fill}"/>`);
      x = e;
    }
  });
  return out.join('');
}
function body(shape, color, locked) {
  const key = `${shape}:${color}:${locked ? 1 : 0}`;
  if (cache.has(key)) return cache.get(key);
  const rows = SHAPES[shape] || SHAPES.round, top = BASE - rows.length;
  const g = locked ? runs(rows, top, ch => ch === 'k' || ch === 'e' ? 'var(--lt-lock-line, #2a2f3a)' : 'var(--lt-lock, #3a4150)') : runs(rows, top, ch => colorOf(ch, BODY[color] ? color : 'red'));
  cache.set(key, g);
  return g;
}
const ripple = '<rect class="lt-rip" x="1" y="21" width="4" height="1"/><rect class="lt-rip" x="7" y="21" width="3" height="1"/><rect class="lt-rip" x="12" y="21" width="3" height="1"/><rect class="lt-rip b" x="3" y="22" width="3" height="1"/><rect class="lt-rip b" x="9" y="22" width="4" height="1"/>';
export const LANTERN_SHAPES = Object.keys(SHAPES);
export const LANTERN_COLORS = Object.keys(BODY);
export const lanternGlow = color => BODY[color]?.a || BODY.red.a;
export function lanternSvg(shape, color, { size = 48, water = true, locked = false, still = false, delay = 0, label = '' } = {}) {
  const h = Math.round(size * (water ? VH : BASE) / W);
  return `<svg class="lt-art${still ? ' still' : ''}${locked ? ' locked' : ''}" viewBox="0 0 ${W} ${water ? VH : BASE}" width="${size}" height="${h}" shape-rendering="crispEdges" role="img" aria-label="${label.replace(/"/g, '&quot;')}" style="--lt-d:${-Number(delay) || 0}s">${water && !locked ? ripple : ''}<g class="lt-bob">${body(shape, color, locked)}</g></svg>`;
}
