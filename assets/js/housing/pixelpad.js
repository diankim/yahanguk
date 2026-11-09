export function pixelPad(canvas, { w, h, scale, at, cells, draw, onChange }) {
  const undo = [];
  const pad = { tool: 'pen', color: '0', cells };
  let down = false;
  canvas.width = w * scale; canvas.height = h * scale;
  canvas.style.touchAction = 'none';
  const cellAt = e => {
    const r = canvas.getBoundingClientRect();
    const x = Math.floor((e.clientX - r.left) / r.width * w), y = Math.floor((e.clientY - r.top) / r.height * h);
    return x >= 0 && y >= 0 && x < w && y < h ? at(x, y) : -1;
  };
  const near = k => {
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
    if (pad.tool === 'fill') down = false;
  });
  canvas.addEventListener('pointermove', e => { if (!down) return; if (paint(cellAt(e))) changed(); });
  const up = () => { down = false; };
  canvas.addEventListener('pointerup', up); canvas.addEventListener('pointercancel', up); canvas.addEventListener('pointerleave', up);
  draw();
  return pad;
}
