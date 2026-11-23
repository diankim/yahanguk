const rnd = (a, b) => a + Math.random() * (b - a);

function brush(len, w) {
  const n = 26, bend = rnd(-w * 0.35, w * 0.35), top = [], bot = [];
  for (let i = 0; i <= n; i++) {
    const t = i / n, x = t * len, c = w / 2 + bend * Math.sin(Math.PI * t);
    const th = w * (t < 0.1 ? 0.55 + 4.5 * t : Math.pow(1 - t, 0.65)) * (1 + rnd(-0.12, 0.12));
    top.push(`${x.toFixed(1)} ${(c - th / 2 + rnd(-0.6, 0.6)).toFixed(1)}`);
    bot.push(`${x.toFixed(1)} ${(c + th / 2 + rnd(-0.6, 0.6)).toFixed(1)}`);
  }
  return `M${top.join(' L')} L${bot.reverse().join(' L')} Z`;
}
function dry(len, w) {
  let s = '';
  for (let i = 0; i < 5; i++) {
    const y = w / 2 + rnd(-w * 0.38, w * 0.38), x0 = len * rnd(0.35, 0.6), x1 = len * rnd(0.9, 1.08), g = rnd(4, 14).toFixed(1);
    s += `<path d="M${x0.toFixed(1)} ${y.toFixed(1)} L${x1.toFixed(1)} ${(y + rnd(-1.5, 1.5)).toFixed(1)}" stroke-width="${rnd(0.7, 1.6).toFixed(2)}" fill="none" stroke="currentColor" stroke-dasharray="${rnd(10, 30).toFixed(1)} ${g}" opacity=".7"/>`;
  }
  return s;
}
function strokeSvg({ len, w, rot, dx = 0, dy = 0, cls = '', delay = 0 }) {
  return `<svg class="ink-stroke ${cls}" width="${len}" height="${w}" viewBox="0 0 ${len} ${w}" style="--rot:${rot}deg;--dx:${dx}px;--dy:${dy}px;--dl:${delay}ms;margin:${-w / 2}px 0 0 ${-len / 2}px"><path d="${brush(len, w)}" fill="currentColor"/>${dry(len, w)}</svg>`;
}
function drops(n, spread, color = '') {
  let s = '';
  for (let i = 0; i < n; i++) {
    const a = rnd(0, Math.PI * 2), d = rnd(spread * 0.4, spread), r = rnd(1.6, 4.2);
    s += `<i class="ink-drop ${color}" style="--x:${(Math.cos(a) * d).toFixed(1)}px;--y:${(Math.sin(a) * d * 0.7).toFixed(1)}px;width:${(r * 2).toFixed(1)}px;height:${(r * 2).toFixed(1)}px;--dl:${Math.round(rnd(60, 140))}ms"></i>`;
  }
  return s;
}
let uid = 0;
function enso(size, w, cls = '', sweep = 320) {
  const cx = size / 2, r = size / 2 - w, n = 40, a0 = rnd(0, 360) * Math.PI / 180, out = [], inn = [], id = `ie${++uid}`;
  for (let i = 0; i <= n; i++) {
    const t = i / n, a = a0 + t * sweep * Math.PI / 180;
    const th = w * (t < 0.08 ? 0.6 + 5 * t : Math.pow(1 - t, 0.55)) * (1 + rnd(-0.12, 0.12));
    out.push(`${(cx + Math.cos(a) * (r + th / 2)).toFixed(1)} ${(cx + Math.sin(a) * (r + th / 2)).toFixed(1)}`);
    inn.push(`${(cx + Math.cos(a) * (r - th / 2)).toFixed(1)} ${(cx + Math.sin(a) * (r - th / 2)).toFixed(1)}`);
  }
  const deg = a0 * 180 / Math.PI;
  return `<svg class="ink-enso ${cls}" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" style="margin:${-size / 2}px 0 0 ${-size / 2}px"><mask id="${id}"><circle cx="${cx}" cy="${cx}" r="${r}" fill="none" stroke="#fff" stroke-width="${w * 2.4}" pathLength="100" stroke-dasharray="100 100" transform="rotate(${deg.toFixed(1)} ${cx} ${cx})"/></mask><path d="M${out.join(' L')} L${inn.reverse().join(' L')} Z" fill="currentColor" mask="url(#${id})"/></svg>`;
}

const MAKE = {
  slash: o => { const rot = rnd(-38, -24); return strokeSvg({ len: 170, w: 16, rot, cls: 'ghost', dx: -7, dy: 5, delay: 40 }) + strokeSvg({ len: 170, w: 16, rot }) + drops(6, 70, o.tone); },
  arrow: o => strokeSvg({ len: 150, w: 9, rot: rnd(-6, 6), cls: 'ghost fly', dy: 7, delay: 30 }) + strokeSvg({ len: 150, w: 11, rot: rnd(-4, 4), cls: 'fly' }) + drops(5, 50, o.tone),
  burst: o => enso(96, 9, 'ghost') + enso(84, 10) + drops(7, 64, o.tone),
  crit: () => strokeSvg({ len: 150, w: 16, rot: rnd(26, 40), cls: 'verm', delay: 70 }) + drops(5, 66, 'verm'),
  claw: o => [-14, 0, 14].map((d, i) => strokeSvg({ len: 104, w: 8, rot: 34, dx: d, dy: -d * 0.4, delay: i * 45 })).join('') + drops(4, 44, o.tone),
  guard: () => enso(72, 8, '', 170),
};

export function inkFx(layer, kind, opts = {}) {
  if (!layer || !MAKE[kind]) return;
  const box = document.createElement('div');
  box.className = `ink-fx ink-${kind} ${opts.tone || ''}`;
  box.innerHTML = MAKE[kind](opts);
  layer.append(box);
  setTimeout(() => box.remove(), opts.ms || 820);
}
