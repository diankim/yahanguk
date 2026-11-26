const BOARD = '.hx-map, .by-map, .gg-map, .mk-board';
const BOOM = '.due:not(text):not(.wm-n):not(.mk-who):not(.hx-tag):not(.hx-cell):not(.tel-wave):not(.tel-chev):not(.hx-chain), .hx-cell.due:not(.hx-tide):not(.hx-drag), .mk-cell.mk-line';
const deg = a => (a * 180 / Math.PI).toFixed(1);

export const TEL_DEFS = '<defs><clipPath id="tel-clip"><circle r="15"/></clipPath></defs>';

export function telWave(x, y, ang, due) {
  const line = '<path d="M0 -21 q3 3 0 6 t0 6 t0 6 t0 6 t0 6 t0 6 t0 6"/>';
  return `<g class="tel-wave ${due ? 'due' : ''}" data-a="${deg(ang)}" transform="translate(${x.toFixed(1)} ${y.toFixed(1)}) rotate(${deg(ang)})"><g clip-path="url(#tel-clip)">${line}${line}${line}</g></g>`;
}

export function telChev(x, y, ang, due) {
  const c = dx => `<path d="M${dx - 4} -6 l5 6 l-5 6"/>`;
  return `<g class="tel-chev ${due ? 'due' : ''}" data-a="${deg(ang)}" transform="translate(${x.toFixed(1)} ${y.toFixed(1)}) rotate(${deg(ang)})">${c(-7)}${c(0)}${c(7)}</g>`;
}

export function telSnap(root) {
  const b = root?.querySelector(BOARD); if (!b) return null;
  const base = b.getBoundingClientRect(), mid = r => [r.left + r.width / 2 - base.left, r.top + r.height / 2 - base.top];
  const toks = {};
  for (const t of b.querySelectorAll('[data-mid]')) toks[t.dataset.mid] = mid((t.querySelector('circle') || t).getBoundingClientRect());
  const fx = [], near = (x, y) => fx.some(f => Math.hypot(f.x - x, f.y - y) < 10);
  for (const e of b.querySelectorAll('.tel-wave.due, .tel-chev.due')) {
    const r = e.getBoundingClientRect(), [x, y] = mid(r);
    fx.push({ kind: e.classList.contains('tel-wave') ? 'wave' : 'chev', x, y, a: Number(e.dataset.a) || 0 });
  }
  for (const e of b.querySelectorAll(BOOM)) {
    const r = e.getBoundingClientRect(); if (!r.width) continue;
    const [x, y] = mid(r); if (near(x, y)) continue;
    fx.push({ kind: 'boom', x, y, w: Math.min(140, Math.max(r.width, r.height)) });
  }
  const push = [];
  for (const e of b.querySelectorAll('.hx-cell.hx-tide.due, .hx-cell.hx-drag.due, [data-push].due')) {
    const [x, y] = mid(e.getBoundingClientRect());
    const w = fx.find(f => f.kind === 'wave' && Math.hypot(f.x - x, f.y - y) < 12);
    push.push({ kind: e.classList.contains('hx-drag') || e.dataset.push === 'ground' ? 'ground' : 'water', x, y, a: w ? w.a : null });
  }
  return { toks, fx, push };
}

function overlay(b) {
  const host = b.parentElement;
  if (getComputedStyle(host).position === 'static') host.style.position = 'relative';
  const hr = host.getBoundingClientRect(), br = b.getBoundingClientRect();
  const ov = document.createElement('div');
  ov.className = 'tel-ovl';
  Object.assign(ov.style, { left: `${br.left - hr.left}px`, top: `${br.top - hr.top}px`, width: `${br.width}px`, height: `${br.height}px` });
  host.appendChild(ov);
  setTimeout(() => ov.remove(), 1400);
  return ov;
}

function piece(ov, cls, x, y, html, rot) {
  const d = document.createElement('div');
  d.className = cls;
  d.style.left = `${x}px`; d.style.top = `${y}px`;
  if (rot != null) d.style.setProperty('--rot', `${rot}deg`);
  d.innerHTML = html || '';
  ov.appendChild(d);
}

const WAVES = '<svg viewBox="-30 -15 60 30"><path d="M-12 -15 q3 2.5 0 5 t0 5 t0 5 t0 5 t0 5 t0 5"/><path d="M0 -15 q3 2.5 0 5 t0 5 t0 5 t0 5 t0 5 t0 5"/><path d="M12 -15 q3 2.5 0 5 t0 5 t0 5 t0 5 t0 5 t0 5"/></svg>';
const CHEVS = '<svg viewBox="-16 -9 32 18"><path d="M-14 -7 l7 7 l-7 7"/><path d="M-4 -7 l7 7 l-7 7"/><path d="M6 -7 l7 7 l-7 7"/></svg>';

function spray(ov, x1, y1, x2, y2, kind, delay, n, cone) {
  const len = Math.hypot(x2 - x1, y2 - y1) || 1, ux = (x2 - x1) / len, uy = (y2 - y1) / len;
  for (let i = 0; i < n; i++) {
    const t = cone ? 0 : i / n, side = (Math.random() - .5) * (cone ? 4 : 12);
    const d = document.createElement('div'), sz = 1.5 + Math.random() * 2;
    d.className = `tel-pt ${kind === 'water' ? 'pw' : 'pg'}`;
    Object.assign(d.style, { left: `${x1 + ux * len * t - uy * side}px`, top: `${y1 + uy * len * t + ux * side}px`, width: `${sz}px`, height: `${sz}px` });
    ov.appendChild(d);
    const sp = cone ? (Math.random() - .5) * cone : (Math.random() - .5) * .9, go = cone ? 14 + Math.random() * 22 : 10 + Math.random() * 18;
    const vx = ux * Math.cos(sp) - uy * Math.sin(sp), vy = uy * Math.cos(sp) + ux * Math.sin(sp);
    d.animate([{ transform: 'translate(-50%, -50%) scale(1)', opacity: 1 }, { transform: `translate(calc(-50% + ${vx * go}px), calc(-50% + ${vy * go}px)) scale(.3)`, opacity: 0 }],
      { duration: 320 + Math.random() * 300, delay: delay + t * 320 + Math.random() * 60, easing: 'cubic-bezier(.2, .7, .4, 1)', fill: 'both' });
  }
}

function star(n, lo, hi, jag) {
  return Array.from({ length: n * 2 }, (_, i) => {
    const t = Math.PI / n * i + (Math.random() - .5) * jag, r = i % 2 ? lo * (.7 + Math.random() * .6) : hi * (.55 + Math.random() * .45);
    return `${(r * Math.cos(t)).toFixed(1)},${(r * Math.sin(t)).toFixed(1)}`;
  }).join(' ');
}

function burst(ov, x, y, w, delay) {
  const d = document.createElement('div');
  d.className = 'tel-burst';
  Object.assign(d.style, { left: `${x}px`, top: `${y}px`, width: `${w}px`, height: `${w}px` });
  d.innerHTML = `<svg viewBox="-50 -50 100 100"><polygon class="o" points="${star(11, 15, 50, .25)}"/><polygon class="i" points="${star(9, 9, 24, .3)}"/></svg>`;
  ov.appendChild(d);
  d.animate([{ transform: 'translate(-50%, -50%) scale(.25) rotate(-8deg)', opacity: 1 }, { transform: 'translate(-50%, -50%) scale(1.05) rotate(0deg)', opacity: 1, offset: .35 }, { transform: 'translate(-50%, -50%) scale(1.15) rotate(3deg)', opacity: 0 }],
    { duration: 480, delay, easing: 'ease-out', fill: 'both' });
  for (let i = 0; i < 6; i++) {
    const a = Math.random() * Math.PI * 2, go = w * (.55 + Math.random() * .35), sh = document.createElement('div');
    sh.className = 'tel-shard';
    Object.assign(sh.style, { left: `${x}px`, top: `${y}px`, '--r': `${(a * 180 / Math.PI).toFixed(0)}deg` });
    ov.appendChild(sh);
    sh.animate([{ transform: `translate(-50%, -50%) rotate(${a}rad) translateX(${w * .2}px) scale(1)`, opacity: 1 }, { transform: `translate(-50%, -50%) rotate(${a}rad) translateX(${go}px) scale(.4)`, opacity: 0 }],
      { duration: 420 + Math.random() * 160, delay: delay + 40, easing: 'cubic-bezier(.2, .8, .4, 1)', fill: 'both' });
  }
}

export function telPlay(root, before) {
  if (!before) return;
  const b = root?.querySelector(BOARD); if (!b) return;
  const base = b.getBoundingClientRect(), svg = b instanceof SVGElement;
  const unit = svg ? (b.viewBox?.baseVal?.width || base.width) / base.width : 1;
  const forces = before.fx.filter(f => f.kind !== 'boom');
  const ov = (before.fx.length || Object.keys(before.toks).length) ? overlay(b) : null;
  for (const t of b.querySelectorAll('[data-mid]')) {
    const old = before.toks[t.dataset.mid]; if (!old) continue;
    const r = (t.querySelector('circle') || t).getBoundingClientRect();
    const nx = r.left + r.width / 2 - base.left, ny = r.top + r.height / 2 - base.top, dx = old[0] - nx, dy = old[1] - ny;
    if (Math.hypot(dx, dy) < 4) continue;
    const pc = (before.push || []).find(f => Math.hypot(f.x - old[0], f.y - old[1]) < 24);
    const shoved = pc || forces.some(f => Math.hypot(f.x - old[0], f.y - old[1]) < 46);
    t.animate([{ transform: `translate(${dx * unit}px, ${dy * unit}px)` }, { transform: 'translate(0, 0)' }],
      shoved ? { duration: 560, delay: 140, easing: 'cubic-bezier(.15, 1.4, .35, 1)', fill: 'backwards' } : { duration: 380, easing: 'ease-out' });
    if (shoved && ov) {
      spray(ov, old[0], old[1], nx, ny, pc?.kind || 'ground', 140, 26, 0);
    }
  }
  for (const pc of before.push || []) {
    if (pc.kind !== 'water' || pc.a == null) continue;
    for (const t of b.querySelectorAll('[data-mid]')) {
      const old = before.toks[t.dataset.mid]; if (!old || Math.hypot(pc.x - old[0], pc.y - old[1]) > 24) continue;
      const r = (t.querySelector('circle') || t).getBoundingClientRect();
      if (Math.hypot(r.left + r.width / 2 - base.left - old[0], r.top + r.height / 2 - base.top - old[1]) > 4) continue;
      const ra = pc.a * Math.PI / 180, bx = Math.cos(ra), by = Math.sin(ra);
      t.animate([{ transform: 'translate(0, 0)' }, { transform: `translate(${bx * 14 * unit}px, ${by * 14 * unit}px)`, offset: .35 }, { transform: `translate(${-bx * 4 * unit}px, ${-by * 4 * unit}px)`, offset: .6 }, { transform: 'translate(0, 0)' }], { duration: 650, delay: 140, easing: 'ease-out' });
      if (ov) { burst(ov, old[0] + bx * 20, old[1] + by * 20, 36, 300); spray(ov, old[0] + bx * 20, old[1] + by * 20, old[0] - bx * 20, old[1] - by * 20, 'water', 330, 14, 2.4); }
    }
  }
  if (!ov) return;
  let boom = false;
  for (const f of before.fx) {
    if (f.kind === 'boom') { boom = true; burst(ov, f.x, f.y, Math.min(110, Math.max(50, f.w * 1.1)), 0); }
    else piece(ov, f.kind === 'wave' ? 'tel-surge' : 'tel-yank', f.x, f.y, f.kind === 'wave' ? WAVES : CHEVS, f.a);
  }
  if (boom) { b.classList.remove('tel-shake'); void b.getBoundingClientRect(); b.classList.add('tel-shake'); setTimeout(() => b.classList.remove('tel-shake'), 500); }
}
