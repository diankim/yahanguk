import { rpc, esc, icon, openModal, store, $, toast } from './core.js';
import { replayLog } from './replay.js';
import { SPAR_WATCH } from './rules.js';

const KIND_ICON = { start: 'flame', hit: 'sword', crit: 'spark', miss: 'wind', end: 'check', skill: 'star', heal: 'heart', stun: 'chain', down: 'down' };
export function openSparResult(x, { start = 0, watch = false } = {}) {
  if (!x?.names) return;
  const me = store.character?.owner_id, mine = (x.ids || []).indexOf(me) + 1, won = mine && mine === x.winner;
  const m = openModal({ title: watch ? '비무 관전' : '비무', body: `
    <div class="spar-result">
      <p class="muted small">${esc(x.names[0])} 대 ${esc(x.names[1])}</p>
      <ol class="spar-log replay"></ol>
      <button class="btn small ghost" data-skip>건너뛰기</button>
      <div class="spar-end" hidden>
        <p class="lead ${mine ? (won ? 'ok' : 'bad') : ''}">${mine ? (won ? '이겼습니다' : '졌습니다') : esc(x.names[x.winner - 1] + ' 승')}${x.ko ? '' : ' · 판정'}</p>
        <div class="stat-tiles">${[0, 1].map(i => `<div class="${x.winner === i + 1 ? 'win' : ''}"><span>${esc(x.names[i])}</span><b>기세 ${x.hp[i]}</b><small>적중 ${x.hits[i]} · 치명타 ${x.crits[i]}</small></div>`).join('')}</div>
      </div>
      <p class="muted small">${watch ? esc(SPAR_WATCH.tip) : '비무는 목숨을 걸지 않는 겨루기입니다. 체력·물품·전·경험치는 그대로이고, 같은 상대와는 3분에 한 번 겨룹니다.'}</p>
    </div>` });
  replayLog($('.spar-log', m), x.log || [], l => logRow(l), { start, step: SPAR_WATCH.step, skipBtn: $('[data-skip]', m), onDone: () => { $('.spar-end', m).hidden = false; } });
}
export const logRow = l => `<li class="k-${esc(l.kind)}${l.who ? ` s${l.who}` : ''}">${icon(KIND_ICON[l.kind] || 'sword', 14)}<span>${esc(l.text)}</span></li>`;
export async function viewSpar(id) {
  const r = await rpc('world_spar_view', { p_spar: id });
  if (r?.result) openSparResult(r.result);
  return r;
}
export async function openSparWatch(id) {
  const r = await rpc('world_spar_view', { p_spar: id }).catch(() => null);
  if (!r?.result) return toast(SPAR_WATCH.gone, 'error');
  const el = Math.max(0, new Date(r.now || Date.now()) - new Date(r.finished_at || Date.now()));
  openSparResult(r.result, { watch: !!r.watch, start: r.watch ? Math.floor(el / SPAR_WATCH.step) : 0 });
}
export const sparWatchRow = s => `<li><button class="sw-row${s.live ? ' live' : ''}" data-sw="${esc(s.id)}"><b>${esc((s.names || []).join(' 대 '))}</b><small>${s.live ? esc(SPAR_WATCH.live) : esc(SPAR_WATCH.done(s.winner))}</small></button></li>`;
export function openSparWatchList(list) {
  const m = openModal({ title: '비무 관전', body: `<div class="sw-list"><p class="muted small">${esc(SPAR_WATCH.listTip)}</p><ul>${list.map(sparWatchRow).join('')}</ul></div>` });
  m.querySelectorAll('[data-sw]').forEach(b => b.onclick = () => openSparWatch(b.dataset.sw));
}
