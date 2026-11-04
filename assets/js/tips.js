import { esc } from './core.js';

let tipEl = null, tipTimer = 0;
function showTip(t) {
  if (!tipEl) { tipEl = document.createElement('div'); tipEl.className = 'fx-tip'; tipEl.setAttribute('role', 'tooltip'); document.body.appendChild(tipEl); }
  tipEl.textContent = t.dataset.tip; tipEl.hidden = false;
  const r = t.getBoundingClientRect(), w = tipEl.offsetWidth, h = tipEl.offsetHeight;
  const x = Math.max(8, Math.min(window.innerWidth - w - 8, r.left + r.width / 2 - w / 2));
  const y = r.top - h - 6 >= 8 ? r.top - h - 6 : r.bottom + 6;
  tipEl.style.left = `${x}px`; tipEl.style.top = `${y}px`;
}
export function hideTip() { clearTimeout(tipTimer); if (tipEl) tipEl.hidden = true; }
export function bindTips(root) {
  if (!root || root.dataset.tips) return; root.dataset.tips = '1';
  root.addEventListener('mouseover', e => { const t = e.target.closest?.('[data-tip]'); if (t && root.contains(t)) showTip(t); });
  root.addEventListener('mouseout', e => { const t = e.target.closest?.('[data-tip]'); if (t && !t.contains(e.relatedTarget)) hideTip(); });
  root.addEventListener('click', e => { const t = e.target.closest?.('[data-tip]'); if (!t) return; e.stopPropagation(); e.preventDefault(); showTip(t); clearTimeout(tipTimer); tipTimer = setTimeout(hideTip, Math.min(7000, 1800 + (t.dataset.tip || '').length * 25)); }, true);
  window.addEventListener('scroll', hideTip, { passive: true, capture: true });
}
export const helpQ = (text, label = '안내') => `<i class="help-q" role="img" tabindex="0" aria-label="${esc(label)}" data-tip="${esc(text)}">?</i>`;
if (typeof document !== 'undefined' && document.body) bindTips(document.body);
else if (typeof document !== 'undefined') document.addEventListener('DOMContentLoaded', () => bindTips(document.body), { once: true });
