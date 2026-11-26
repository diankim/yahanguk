import { esc } from '../core.js';
import { avatarImage } from '../housing/avatarsprite.js';

const SLOTS = [['top', '윗옷'], ['bottom', '아랫옷'], ['hair', '머리'], ['acc', '장신구']];
const off = new Set();
const subs = new Set();

export const wornLook = (look, keep) => ({ ...look, off: [...off].filter(k => k !== keep) });

export function wornBar(keep) {
  const keys = SLOTS.filter(([k]) => k !== keep);
  return `<div class="worn-bar" role="group" aria-label="입은 것 켜고 끄기"><span>입은 것</span>${keys.map(([k, n]) => `<button type="button" class="chip-btn${off.has(k) ? '' : ' on'}" data-wear="${k}" aria-pressed="${!off.has(k)}" title="${esc(n)} ${off.has(k) ? '보이기' : '끄기'}">${esc(n)}</button>`).join('')}</div>`;
}

export function wornImg(look, keep, opts = {}, cls = 'fpic-img') {
  const data = esc(JSON.stringify({ look, keep, opts }));
  return `<img class="${cls}" data-worn="${data}" src="${avatarImage(wornLook(look, keep), opts)}" alt="입어 본 모습">`;
}

export function onWorn(el, fn) {
  const f = () => { if (!el.isConnected) subs.delete(f); else fn(); };
  subs.add(f);
}

document.addEventListener('click', e => {
  const b = e.target.closest?.('[data-wear]');
  if (!b) return;
  const k = b.dataset.wear;
  if (off.has(k)) off.delete(k); else off.add(k);
  document.querySelectorAll(`[data-wear="${k}"]`).forEach(x => { const on = !off.has(k); x.classList.toggle('on', on); x.setAttribute('aria-pressed', String(on)); });
  document.querySelectorAll('img[data-worn]').forEach(img => { try { const { look, keep, opts } = JSON.parse(img.dataset.worn); img.src = avatarImage(wornLook(look, keep), opts); } catch {} });
  [...subs].forEach(f => f());
});
