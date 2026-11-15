import { esc, icon, openLayer } from './core.js';

export const reportFlag = (attrs = '', title = '운영진에게 제보') => `<button type="button" class="rep-flag" ${attrs} title="${esc(title)}" aria-label="${esc(title)}">${icon('flag', 13)}</button>`;

export function pickReport(items) {
  if (!items.length) return;
  if (items.length === 1) return items[0].run();
  const l = openLayer({ title: '제보할 것 고르기', body: `<p class="small muted">운영진에게 알릴 것을 고르세요.</p><div class="rep-pick">${items.map((it, i) => `<button type="button" class="btn small" data-rp="${i}">${icon('flag', 13)} ${esc(it.label)}</button>`).join('')}</div>` });
  l.addEventListener('click', e => { const b = e.target.closest('[data-rp]'); if (b) { l.close(); items[Number(b.dataset.rp)].run(); } });
}
