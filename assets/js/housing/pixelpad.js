export function pixelPad(canvas, { w, h, scale, at, cells, draw, onChange, nb }) {
  const undo = [];
  const pad = { tool: 'pen', color: '0', cells };
  let down = false, last = null;
  canvas.width = w * scale; canvas.height = h * scale;
  canvas.style.touchAction = 'none';
  const xyOf = e => { const r = canvas.getBoundingClientRect(); return [Math.floor((e.clientX - r.left) / r.width * w), Math.floor((e.clientY - r.top) / r.height * h)]; };
  const atXY = ([x, y]) => x >= 0 && y >= 0 && x < w && y < h ? at(x, y) : -1;
  const cellAt = e => atXY(xyOf(e));
  const near = k => {
    if (nb) return nb(k);
    const out = [];
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (at(x, y) === k) [[1, 0], [-1, 0], [0, 1], [0, -1]].forEach(([dx, dy]) => { const j = at(x + dx, y + dy); if (j >= 0) out.push(j); });
    return out;
  };
  const fill = (k, v) => {
    const from = cells[k];
    if (from === v) return;
    const seen = new Set([k]), todo = [k];
    while (todo.length) { const j = todo.pop(); cells[j] = v; for (const n of near(j)) if (!seen.has(n) && cells[n] === from) { seen.add(n); todo.push(n); } }
  };
  const paint = k => {
    if (k < 0) return false;
    const v = pad.tool === 'erase' ? '.' : pad.color;
    if (pad.tool === 'fill') { fill(k, v); return true; }
    if (cells[k] === v) return false;
    cells[k] = v; return true;
  };
  const changed = () => { draw(); onChange?.(); };
  pad.render = draw;
  pad.save = () => { undo.push(cells.join('')); if (undo.length > 40) undo.shift(); };
  pad.undo = () => { const u = undo.pop(); if (u == null) return false; u.split('').forEach((c, i) => { cells[i] = c; }); changed(); return true; };
  pad.clear = () => { pad.save(); cells.fill('.'); changed(); };
  pad.canUndo = () => undo.length > 0;
  canvas.addEventListener('pointerdown', e => {
    const k = cellAt(e); if (k < 0) return;
    e.preventDefault(); down = true; canvas.setPointerCapture?.(e.pointerId);
    pad.save(); if (paint(k)) changed();
    last = xyOf(e);
    if (pad.tool === 'fill') down = false;
  });
  canvas.addEventListener('pointermove', e => {
    if (!down) return;
    const to = xyOf(e), from = last || to, n = Math.max(Math.abs(to[0] - from[0]), Math.abs(to[1] - from[1]));
    let hit = false;
    for (let i = 1; i <= n || (i === 1 && n === 0); i++) { const t = n ? i / n : 1; if (paint(atXY([Math.round(from[0] + (to[0] - from[0]) * t), Math.round(from[1] + (to[1] - from[1]) * t)]))) hit = true; }
    last = to;
    if (hit) changed();
  });
  const up = () => { down = false; last = null; };
  canvas.addEventListener('pointerup', up); canvas.addEventListener('pointercancel', up); canvas.addEventListener('pointerleave', up);
  draw();
  return pad;
}
