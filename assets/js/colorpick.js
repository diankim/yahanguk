import { openLayer, $, esc } from './core.js';

export const PICKS = [
  ['#101014', '먹'], ['#16202c', '밤 쪽빛'], ['#1b2620', '송연'], ['#261a1d', '흑적'], ['#1f1b2e', '자흑'], ['#2b2a26', '숯'],
  ['#f3ead8', '한지'], ['#ece8df', '백자'],
  ['#c8432d', '단청 주홍'], ['#b23a48', '홍매'], ['#d9634a', '석류'], ['#e08a6d', '살구'],
  ['#d1a65a', '금박'], ['#c9a227', '송화'], ['#a8784a', '황토'], ['#7a5a3c', '갈색'],
  ['#4f8a74', '청자'], ['#5f9e6e', '녹두'], ['#2f6f8f', '쪽'], ['#5b7fbf', '하늘'],
  ['#3e5aa8', '군청'], ['#7d5ba6', '자수정'], ['#a0608f', '자주'], ['#8c97a6', '은회'],
];

const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
export function normHex(s) {
  let h = String(s || '').trim().replace(/^#/, '').toLowerCase();
  if (/^[0-9a-f]{3}$/.test(h)) h = h.split('').map(c => c + c).join('');
  return /^[0-9a-f]{6}$/.test(h) ? `#${h}` : null;
}
function hexToHsv(hex) {
  const n = parseInt(hex.slice(1), 16), r = (n >> 16 & 255) / 255, g = (n >> 8 & 255) / 255, b = (n & 255) / 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
  let h = 0;
  if (d) h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
  return { h: (h * 60 + 360) % 360, s: mx ? d / mx : 0, v: mx };
}
function hsvToHex({ h, s, v }) {
  const f = n => { const k = (n + h / 60) % 6; return v - v * s * Math.max(0, Math.min(k, 4 - k, 1)); };
  return '#' + [f(5), f(3), f(1)].map(x => Math.round(x * 255).toString(16).padStart(2, '0')).join('');
}

export function openColorPicker(start, { title = '색 고르기' } = {}) {
  return new Promise(resolve => {
    let hsv = hexToHsv(normHex(start) || '#c8432d'), done = false;
    const layer = openLayer({ title, body: `<div class="cpk">
      <div class="cpk-sv" tabindex="0" aria-label="채도와 밝기"><i class="cpk-dot"></i></div>
      <div class="cpk-hue" tabindex="0" aria-label="색조"><i class="cpk-knob"></i></div>
      <div class="cpk-row"><span class="cpk-prev"></span><label class="cpk-hex"><span>Hex</span><input maxlength="7" spellcheck="false" autocomplete="off" inputmode="text" aria-label="Hex 코드"></label></div>
      <p class="cpk-h">추천색</p>
      <div class="cpk-picks">${PICKS.map(([c, n]) => `<button type="button" class="cpk-sw" style="--sw:${c}" data-c="${c}" title="${esc(n)} ${c}" aria-label="${esc(n)}"></button>`).join('')}</div>
      <div class="btn-row cpk-acts"><button type="button" class="btn ghost" data-x>취소</button><button type="button" class="btn primary" data-ok>설정</button></div></div>` });
    const sv = $('.cpk-sv', layer), hue = $('.cpk-hue', layer), hex = $('.cpk-hex input', layer);
    const draw = (fromHex) => {
      const c = hsvToHex(hsv);
      sv.style.setProperty('--hue', `hsl(${hsv.h} 100% 50%)`);
      $('.cpk-dot', layer).style.cssText = `left:${hsv.s * 100}%;top:${(1 - hsv.v) * 100}%;background:${c}`;
      $('.cpk-knob', layer).style.left = `${hsv.h / 360 * 100}%`;
      $('.cpk-prev', layer).style.background = c;
      if (!fromHex) hex.value = c;
      layer.querySelectorAll('.cpk-sw').forEach(b => b.classList.toggle('on', b.dataset.c === c));
    };
    const drag = (box, fn) => box.addEventListener('pointerdown', e => {
      e.preventDefault(); box.setPointerCapture?.(e.pointerId);
      const move = ev => { const r = box.getBoundingClientRect(); fn(clamp((ev.clientX - r.left) / r.width, 0, 1), clamp((ev.clientY - r.top) / r.height, 0, 1)); draw(); };
      move(e);
      const up = () => { box.removeEventListener('pointermove', move); box.removeEventListener('pointerup', up); box.removeEventListener('pointercancel', up); };
      box.addEventListener('pointermove', move); box.addEventListener('pointerup', up); box.addEventListener('pointercancel', up);
    });
    drag(sv, (x, y) => { hsv.s = x; hsv.v = 1 - y; });
    drag(hue, x => { hsv.h = Math.min(359.9, x * 360); });
    const key = (box, fn) => box.addEventListener('keydown', e => { const d = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }[e.key]; if (!d) return; e.preventDefault(); fn(...d); draw(); });
    key(sv, (dx, dy) => { hsv.s = clamp(hsv.s + dx * 0.02, 0, 1); hsv.v = clamp(hsv.v - dy * 0.02, 0, 1); });
    key(hue, dx => { hsv.h = (hsv.h + dx * 3 + 360) % 360; });
    hex.addEventListener('input', () => { const c = normHex(hex.value); hex.classList.toggle('bad', !c && hex.value.trim() !== ''); if (c) { hsv = hexToHsv(c); draw(true); } });
    hex.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); $('[data-ok]', layer).click(); } });
    layer.querySelectorAll('.cpk-sw').forEach(b => b.onclick = () => { hsv = hexToHsv(b.dataset.c); draw(); });
    const finish = v => { if (done) return; done = true; resolve(v); layer.close(); };
    $('[data-ok]', layer).onclick = () => finish(normHex(hex.value) || hsvToHex(hsv));
    $('[data-x]', layer).onclick = () => finish(null);
    new MutationObserver((_, ob) => { if (!layer.isConnected) { ob.disconnect(); if (!done) { done = true; resolve(null); } } }).observe(document.body, { childList: true });
    draw();
  });
}

let installed = false;
export function installColorPicker() {
  if (installed) return; installed = true;
  document.addEventListener('click', async e => {
    const inp = e.target.closest?.('input[type=color]');
    if (!inp || inp.disabled) return;
    e.preventDefault(); e.stopPropagation();
    const label = inp.closest('label')?.querySelector('span')?.textContent?.trim();
    const v = await openColorPicker(inp.value, { title: label ? `색 고르기 · ${label}` : '색 고르기' });
    if (!v || v === inp.value) return;
    inp.value = v;
    inp.dispatchEvent(new Event('input', { bubbles: true }));
    inp.dispatchEvent(new Event('change', { bubbles: true }));
  }, true);
}
