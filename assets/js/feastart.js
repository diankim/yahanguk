const BOWL = {
  meat: [
    '............',
    '...kkkkkk...',
    '..khhmmmMk..',
    '.kkmmmmmMkk.',
    'kpkkMMMMkkpk',
    'kppppppppppk',
    '.kPPPPPPPPk.',
    '..kkkkkkkk..',
  ],
  soban: [
    '....kkkk....',
    '..kkwwwwkk..',
    '.kwwwwwwwwk.',
    'kkkkkkkkkkkk',
    'kcccCcccCcck',
    '.kcccccccck.',
    '..kCCCCCCk..',
    '...kkkkkk...',
  ],
  sea: [
    '............',
    '.....kkkk...',
    '.k.kkffffkk.',
    'kfkffeffffFk',
    '.kfkFFFFFFk.',
    'kpkkkkkkkkpk',
    'kPPPPPPPPPPk',
    '.kkkkkkkkkk.',
  ],
};
const PAL = {
  k: '#1a120e', p: '#efe7d6', P: '#b9ab92', w: '#fbf7ee',
  h: '#e48a66', m: '#b8553b', M: '#7a3424',
  c: '#8fc7b4', C: '#5d9784',
  f: '#a9cfe6', F: '#6d9fc4', e: '#1a120e',
};
const RUNNER = { meat: '#c9473b', soban: '#5f9a4e', sea: '#4787cc' };
const BW = 12, BH = 8;
const TW = 100, TH = 46;
const SEATS = Array.from({ length: 12 }, (_, i) => [6 + (i % 6) * 15, i < 6 ? 8 : 20]);
const cache = new Map();

function runs(rows, ox, oy) {
  const out = [];
  rows.forEach((row, y) => {
    let x = 0;
    while (x < row.length) {
      const fill = row[x] === '.' ? null : PAL[row[x]];
      if (!fill) { x++; continue; }
      let e = x + 1;
      while (e < row.length && row[e] !== '.' && PAL[row[e]] === fill) e++;
      out.push(`<rect x="${ox + x}" y="${oy + y}" width="${e - x}" height="1" fill="${fill}"/>`);
      x = e;
    }
  });
  return out.join('');
}
function bowl(kind) {
  if (!cache.has(kind)) cache.set(kind, runs(BOWL[kind] || BOWL.soban, 0, 0));
  return cache.get(kind);
}
const steam = (x, y, d) => `<g class="fa-steam" style="--fa-d:${d}s"><rect x="${x + 4}" y="${y - 3}" width="1" height="2"/><rect x="${x + 7}" y="${y - 4}" width="1" height="2"/></g>`;

export const FEAST_KINDS = Object.keys(BOWL);
export function bowlSvg(kind, size = 24) {
  return `<svg class="fa-art still" viewBox="0 0 ${BW} ${BH}" width="${size}" height="${Math.round(size * BH / BW)}" shape-rendering="crispEdges" aria-hidden="true">${bowl(kind)}</svg>`;
}
export function feastTableSvg(bowls = [], { need = 12, kind = null, open = false, fresh = 0, size = 320, label = '' } = {}) {
  const seats = SEATS.slice(0, Math.max(1, Math.min(SEATS.length, need)));
  const runner = kind && RUNNER[kind] ? `<rect x="3" y="17" width="94" height="2" fill="${RUNNER[kind]}"/><rect x="3" y="17" width="94" height="1" fill="${RUNNER[kind]}" opacity=".6"/>` : '';
  const top = `<rect x="1" y="4" width="98" height="30" fill="#1a120e"/><rect x="2" y="5" width="96" height="28" fill="#c58b55"/><rect x="2" y="5" width="96" height="2" fill="#e0a96c"/><rect x="2" y="31" width="96" height="2" fill="#9a6538"/>${runner}`;
  const side = `<rect x="1" y="34" width="98" height="4" fill="#1a120e"/><rect x="2" y="34" width="96" height="3" fill="#8a5730"/>`;
  const legs = [6, 30, 66, 90].map(x => `<rect x="${x}" y="37" width="4" height="8" fill="#1a120e"/><rect x="${x + 1}" y="37" width="2" height="7" fill="#6e4425"/>`).join('');
  const cells = seats.map(([x, y], i) => {
    const b = bowls[i];
    if (!b) return `<rect class="fa-empty" x="${x + 2}" y="${y + 2}" width="8" height="5" rx="2"/>`;
    return `<g transform="translate(${x} ${y})"><g class="fa-bowl${fresh && b.n === fresh ? ' pop' : ''}">${bowl(b.kind)}</g></g>${open ? steam(x, y, -((i * 0.37) % 2.2).toFixed(2)) : ''}`;
  }).join('');
  const h = Math.round(size * TH / TW);
  return `<svg class="fa-art${open ? ' open' : ''}" viewBox="0 0 ${TW} ${TH}" width="${size}" height="${h}" shape-rendering="crispEdges" role="img" aria-label="${String(label).replace(/"/g, '&quot;')}">${legs}${side}${top}${cells}</svg>`;
}
