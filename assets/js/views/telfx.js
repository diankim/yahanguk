const BOARD = '.hx-map, .by-map, .gg-map, .mk-board';
const BOOM = '.due:not(text):not(.wm-n):not(.mk-who):not(.hx-tag):not(.hx-cell):not(.tel-wave):not(.tel-chev):not(.tel-push):not(.hx-chain), .tel-push.due .tel-wall, .hx-cell.due:not(.hx-tide):not(.hx-drag), .mk-cell.mk-line';
const deg = a => (a * 180 / Math.PI).toFixed(1);
const still = () => matchMedia('(prefers-reduced-motion: reduce)').matches;

export const TEL_DEFS = '<defs><clipPath id="tel-clip"><circle r="15"/></clipPath></defs>';

export function telWave(x, y, ang, due) {
  const line = '<path d="M0 -21 q3 3 0 6 t0 6 t0 6 t0 6 t0 6 t0 6 t0 6"/>';
  return `<g class="tel-wave ${due ? 'due' : ''}" data-a="${deg(ang)}" transform="translate(${x.toFixed(1)} ${y.toFixed(1)}) rotate(${deg(ang)})"><g clip-path="url(#tel-clip)">${line}${line}${line}</g></g>`;
}

export function telChev(x, y, ang, due) {
  const c = dx => `<path d="M${dx - 4} -6 l5 6 l-5 6"/>`;
  return `<g class="tel-chev ${due ? 'due' : ''}" data-a="${deg(ang)}" transform="translate(${x.toFixed(1)} ${y.toFixed(1)}) rotate(${deg(ang)})">${c(-7)}${c(0)}${c(7)}</g>`;
}

export function telPush(x1, y1, x2, y2, kind, due, label, wall) {
  const a = Math.atan2(y2 - y1, x2 - x1), ex = x2 - 13 * Math.cos(a), ey = y2 - 13 * Math.sin(a);
  const hd = (r, t) => `${(ex + r * Math.cos(a + t)).toFixed(1)},${(ey + r * Math.sin(a + t)).toFixed(1)}`;
  const tip = `${(ex + 7 * Math.cos(a)).toFixed(1)},${(ey + 7 * Math.sin(a)).toFixed(1)}`;
  const end = wall
    ? `<g class="tel-wall"><polygon points="${Array.from({ length: 10 }, (_, i) => { const r = i % 2 ? 5 : 12, t = Math.PI / 5 * i; return `${(x2 + r * Math.cos(t)).toFixed(1)},${(y2 + r * Math.sin(t)).toFixed(1)}`; }).join(' ')}"/><text x="${x2.toFixed(1)}" y="${(y2 + 4).toFixed(1)}">벽</text></g>`
    : `<g class="tel-ghost"><circle cx="${x2.toFixed(1)}" cy="${y2.toFixed(1)}" r="11"/><text x="${x2.toFixed(1)}" y="${(y2 + 4).toFixed(1)}">${label}</text></g>`;
  return `<g class="tel-push ${kind} ${due ? 'due' : ''}"><line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${ex.toFixed(1)}" y2="${ey.toFixed(1)}"/><polygon points="${tip} ${hd(6, 2.2)} ${hd(6, -2.2)}"/>${end}</g>`;
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
  return { toks, fx };
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

export function telPlay(root, before) {
  if (!before || still()) return;
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
    const shoved = forces.some(f => Math.hypot(f.x - old[0], f.y - old[1]) < 46);
    t.animate([{ transform: `translate(${dx * unit}px, ${dy * unit}px)` }, { transform: 'translate(0, 0)' }],
      shoved ? { duration: 620, easing: 'cubic-bezier(.15, 1.45, .35, 1)' } : { duration: 380, easing: 'ease-out' });
    if (shoved && ov) piece(ov, 'tel-dust', nx, ny);
  }
  if (!ov) return;
  let boom = false;
  for (const f of before.fx) {
    if (f.kind === 'boom') { boom = true; piece(ov, 'tel-boom', f.x, f.y, '<i></i><b></b>'); ov.lastChild.style.setProperty('--w', `${Math.max(44, f.w)}px`); }
    else piece(ov, f.kind === 'wave' ? 'tel-surge' : 'tel-yank', f.x, f.y, f.kind === 'wave' ? WAVES : CHEVS, f.a);
  }
  if (boom) { b.classList.remove('tel-shake'); void b.getBoundingClientRect(); b.classList.add('tel-shake'); setTimeout(() => b.classList.remove('tel-shake'), 500); }
}
