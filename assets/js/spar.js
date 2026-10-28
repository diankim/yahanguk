// 비무(比武): 같은 곳의 조사원과 목숨을 걸지 않고 겨룬다. 겨루기는 서버(world_spar_respond)가 한 번에 계산하고, 화면은 결과만 보여 준다.
import { rpc, esc, icon, openModal, store } from './core.js';

const KIND_ICON = { start: 'flame', hit: 'sword', crit: 'spark', miss: 'wind', end: 'check' };
export function openSparResult(x) {
  if (!x?.names) return;
  const me = store.character?.owner_id, mine = (x.ids || []).indexOf(me) + 1, won = mine && mine === x.winner;
  openModal({ title: '비무 결과', body: `
    <div class="spar-result">
      <p class="lead ${mine ? (won ? 'ok' : 'bad') : ''}">${mine ? (won ? '이겼습니다' : '졌습니다') : esc(x.names[x.winner - 1] + ' 승')}${x.ko ? '' : ' · 판정'}</p>
      <div class="stat-tiles">${[0, 1].map(i => `<div class="${x.winner === i + 1 ? 'win' : ''}"><span>${esc(x.names[i])}</span><b>기세 ${x.hp[i]}</b><small>적중 ${x.hits[i]} · 치명타 ${x.crits[i]}</small></div>`).join('')}</div>
      <ol class="spar-log">${(x.log || []).map(l => `<li class="k-${esc(l.kind)}${l.who ? ` s${l.who}` : ''}">${icon(KIND_ICON[l.kind] || 'sword', 14)}<span>${esc(l.text)}</span></li>`).join('')}</ol>
      <p class="muted small">비무는 목숨을 걸지 않는 겨루기입니다. 체력·물품·전·경험치는 그대로이고, 같은 상대와는 3분에 한 번 겨룹니다.</p>
    </div>` });
}
export async function viewSpar(id) {
  const r = await rpc('world_spar_view', { p_spar: id });
  if (r?.result) openSparResult(r.result);
  return r;
}
