// 동료: 파티 관리·전리품 분배·초대, 같은 지역의 조사원과 구조.
import { cardName } from './card.js';
import { sealMark } from '../cosmetics.js';
import { openWhisper } from '../chat.js';
import { loadCircles, circlesPanelHtml, bindCirclesPanel } from '../circles.js';
import { loadBond, bondPanelHtml, bindBondPanel, tokenSvg } from '../bond.js';

const ago = t => { const s = Math.max(0, (Date.now() - new Date(t)) / 1000); return !t ? '알 수 없음' : s < 120 ? '방금' : s < 3600 ? `${Math.floor(s / 60)}분 전` : s < 86400 ? `${Math.floor(s / 3600)}시간 전` : `${Math.floor(s / 86400)}일 전`; };
import { gmBadge, ask, store, on, act, nameOf, esc, icon, guard, $, $$, fmt, empty, emblem } from '../core.js';
import { load, panel, chip, loading, errorBox } from './common.js';

const LOOT = [['contribution', '기여도순'], ['designated', '지정순'], ['equal', '균등 분배']];
let el, off = [], poll = null;

export async function render(root) {
  if (!store.character) return;
  el = root;
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('users', 14)} 함께 걷는 이들</p><h1>동료</h1></div>
    <button class="btn small ghost" id="party-refresh">${icon('back', 14)}<span>새로 보기</span></button></div><div id="party-body">${loading()}</div>`;
  off.forEach(f => f()); off = [on('changed', draw)];
  $('#party-refresh', el).onclick = e => guard(e.currentTarget, () => draw(), { success: '' });
  // 다른 조사원이 오가는 것은 내 행동으로 알 수 없으므로, 화면을 보고 있는 동안만 20초마다 다시 읽는다.
  clearInterval(poll); poll = setInterval(() => { if (!document.hidden && el?.isConnected && !el.contains(document.activeElement?.closest('select,input'))) draw(); }, 20000);
  await draw();
}
export function destroy() { off.forEach(f => f()); off = []; clearInterval(poll); poll = null; }

async function draw() {
  const body = $('#party-body', el); if (!body) return;
  try {
    const [p, loot, roster, fr, cs, bs] = await Promise.all([load('world_party_overview'), load('world_party_loot_snapshot').catch(() => null), load('world_region_roster').catch(() => []), load('world_friend_overview').catch(() => null), loadCircles(true), loadBond(true)]);
    const me = store.character.owner_id, pt = p?.party, isLeader = pt?.leader_id === me;
    const incoming = (p?.invites || []).filter(i => i.incoming), outgoing = (p?.invites || []).filter(i => !i.incoming);
    const member = m => `<li>${emblem(m.owner_id, m.profile, 36)}<div><b>${cardName(m.owner_id, m.character_name)}${sealMark(m.profile?.seal)}${gmBadge(m.owner_id)} ${m.role === 'leader' ? chip('파티장', 'accent') : ''}</b>
        <small>Lv.${m.level} · ${esc(nameOf(m.job_key))} · ${esc(m.location)} · 체력 ${m.health}${m.away ? ' · 원정 중' : ''}${m.in_combat ? ' · 전투 중' : ''}</small></div>
        ${m.downed ? (m.owner_id !== me ? `<button class="btn small primary" data-rescue="${esc(m.owner_id)}">구조</button>` : chip('전투불능', 'bad')) : ''}</li>`;
    const canInvite = !pt || isLeader, memberIds = new Set((p?.members || []).map(m => m.owner_id));
    const fState = f => f.is_dead ? '숨을 거둠' : f.downed ? '전투불능' : f.in_combat ? '전투 중' : f.away ? '원정 중' : f.traveling ? '이동 중' : '';
    const friendsPanel = fr ? panel(`친구 · ${(fr.friends || []).length}명`, `
      ${(fr.incoming || []).length ? `<h3 class="sub-h">받은 친구 신청 ${fr.incoming.length}</h3><ul class="people">${fr.incoming.map(f => `<li>${emblem(f.owner_id, f.profile, 34)}<div><b>${cardName(f.owner_id, f.character_name)}${sealMark(f.profile?.seal)}${gmBadge(f.owner_id)}</b><small>Lv.${f.level} · ${esc(nameOf(f.job_key))}</small></div>
          <div class="btn-row"><button class="btn small primary" data-fr-acc="${esc(f.owner_id)}">수락</button><button class="btn small" data-fr-dec="${esc(f.owner_id)}">거절</button></div></li>`).join('')}</ul>` : ''}
      ${(fr.friends || []).length ? `<ul class="people">${fr.friends.map(f => `<li>${emblem(f.owner_id, f.profile, 34)}<div><b>${cardName(f.owner_id, f.character_name)}${sealMark(f.profile?.seal)}${gmBadge(f.owner_id)}</b>
          <small>Lv.${f.level} · ${esc(nameOf(f.job_key))} · ${esc(f.location || '')}${fState(f) ? ' · ' + fState(f) : ''}</small><small class="muted">최근 활동 ${esc(ago(f.last_active))}</small></div>
          <div class="btn-row"><button class="btn small" data-whisper="${esc(f.character_name)}" data-whisper-id="${esc(f.owner_id)}">귓속말</button>
            ${canInvite && !memberIds.has(f.owner_id) && !f.is_dead ? `<button class="btn small" data-fr-inv="${esc(f.owner_id)}">초대</button>` : ''}
            ${f.downed && !f.is_dead && f.location === store.character.location ? `<button class="btn small primary" data-rescue="${esc(f.owner_id)}">구조</button>` : ''}</div></li>`).join('')}</ul>`
        : empty('아직 친구가 없습니다. 채팅이나 같은 곳에 있는 조사원의 이름을 눌러 친구 신청을 보내 보세요.', 'users')}
      ${(fr.outgoing || []).length ? `<p class="muted small">응답을 기다리는 신청: ${fr.outgoing.map(f => `${esc(f.character_name)} <button class="linkish" data-fr-cancel="${esc(f.owner_id)}">취소</button>`).join(' · ')}</p>` : ''}
      ${(fr.blocked || []).length ? `<details class="fold"><summary>차단한 조사원 ${fr.blocked.length}</summary><ul class="spot-list">${fr.blocked.map(f => `<li><div><b>${esc(f.character_name)}</b></div><button class="btn small" data-unblock="${esc(f.owner_id)}">차단 풀기</button></li>`).join('')}</ul></details>` : ''}
      <p class="muted small">친구는 어디에 있든 위치와 상황을 볼 수 있고, 귓속말과 파티 초대를 바로 보낼 수 있습니다.</p>`, { ico: 'heart' }) : '';
    const circlePanel = panel(`모임 · ${(cs?.circles || []).length}개`, circlesPanelHtml(cs), { ico: 'chat' });
    const bondPanel = panel('연리', bondPanelHtml(bs), { ico: 'heart' });
    body.innerHTML = `
      ${bondPanel}
      ${friendsPanel}
      ${circlePanel}
      ${incoming.length ? panel('받은 초대', `<ul class="spot-list">${incoming.map(i => `<li><div><b>${esc(i.inviter_name || '조사원')}의 동료 초대</b><small>수락하면 함께 이동하고 전리품을 나눕니다</small></div>
        <div class="btn-row"><button class="btn small primary" data-inv="${esc(i.invite_id)}" data-acc="1">수락</button><button class="btn small" data-inv="${esc(i.invite_id)}" data-acc="0">거절</button></div></li>`).join('')}</ul>`, { ico: 'bell' }) : ''}
      ${pt ? `<div class="grid-2">
        ${panel(`우리 동료 · ${(p.members || []).length}명`, `<ul class="people">${(p.members || []).map(member).join('')}</ul>
          ${isLeader && (p.candidates || []).length ? `<form class="form-grid" id="invite-form"><label class="field"><span>초대할 조사원</span><select name="who">${p.candidates.map(x => `<option value="${esc(x.owner_id)}">${esc(x.character_name)} (Lv.${x.level} · ${esc(x.location)})</option>`).join('')}</select></label><button class="btn" type="submit">초대</button></form>` : ''}
          ${outgoing.length ? `<p class="muted small">응답을 기다리는 초대: ${outgoing.map(i => esc(i.invitee_name)).join(', ')}</p>` : ''}
          <p class="muted small">파티장이 지도에서 목적지를 고르면 같은 지역의 파티원에게 동승을 요청할 수 있습니다. 운임은 파티장만 냅니다.</p>
          <button class="btn small ghost" id="party-leave">${icon('back', 14)}<span>${(p.members || []).length <= 1 ? '파티 해체' : isLeader ? '파티 나가기(파티장 넘김)' : '파티 나가기'}</span></button>`, { ico: 'users' })}
        ${panel('전리품 분배', `
          <p class="muted small">현재 방식: <b>${esc(LOOT.find(x => x[0] === (loot?.method || pt.loot_distribution_method))?.[1] || '균등 분배')}</b> · 받을 몫 ${fmt.num(loot?.claimable_count)}건</p>
          ${isLeader ? `<div class="btn-row">${LOOT.map(([k, n]) => `<button class="btn small ${k === (loot?.method || pt.loot_distribution_method) ? 'primary' : ''}" data-method="${k}">${n}</button>`).join('')}</div>` : ''}
          ${(loot?.loot || []).length ? `<ul class="spot-list">${loot.loot.map(l => `<li><div><b>${esc(nameOf(l.item_id))} ×${l.quantity}</b><small>${l.status === 'available' ? '분배 대기' : '분배 완료'}</small></div>
            ${isLeader && l.status === 'available' ? `<button class="btn small" data-dist="${esc(l.loot_id)}">분배</button>` : ''}</li>`).join('')}</ul>` : empty('공동 전리품이 없습니다.', 'bag')}
          ${loot?.claimable_count ? `<button class="btn primary" id="loot-claim">${icon('check', 16)}<span>내 몫 받기</span></button>` : ''}
          <p class="muted small">지정순은 파티원 목록 순서(파티장 먼저)대로 우선권을 줍니다.</p>`, { ico: 'bag' })}
      </div>` : panel('동료 맺기', `<p class="desc">동료를 맺으면 함께 이동(동승)하고, 동료 채팅과 전리품 분배를 쓸 수 있습니다. 혼자서도 모든 핵심 콘텐츠를 진행할 수 있습니다.</p>
        <button class="btn primary" id="party-make">${icon('plus', 16)}<span>동료 모임 만들기</span></button>
        <p class="muted small">만든 뒤 같은 지역의 조사원을 초대할 수 있습니다.</p>`, { ico: 'users' })}
      ${panel(`같은 지역의 조사원 · ${store.character.location}`, (roster || []).length ? `<ul class="people">${roster.map(m => `<li>${emblem(m.owner_id, m.profile, 36)}<div><b>${cardName(m.owner_id, m.character_name)}${sealMark(m.profile?.seal)}${gmBadge(m.owner_id)}</b>
          <small>Lv.${m.level} · ${esc(nameOf(m.job_key))}${m.major_faction_id ? ' · ' + esc(nameOf(m.major_faction_id)) : ''}${m.away ? ' · 원정 중' : ''}</small>${m.profile?.bio ? `<small class="muted">${esc(m.profile.bio)}</small>` : ''}</div>
          ${m.downed && !m.is_dead ? `<button class="btn small primary" data-rescue="${esc(m.owner_id)}">구조</button>` : ''}</li>`).join('')}</ul>` : empty('같은 지역에 다른 조사원이 없습니다.', 'users'), { ico: 'pin' })}`;
    // 이름은 쓰지 않는다. 서버가 요구하는 이름 자리에는 만든 사람 이름을 넣는다.
    const mk = $('#party-make', body);
    if (mk) mk.onclick = () => guard(mk, () => act('world_party_create', { p_party_name: `${store.character.character_name}의 동료`.slice(0, 20) }));
    $('#invite-form', body)?.addEventListener('submit', e => { e.preventDefault(); guard(e.target.querySelector('button'), () => act('world_party_invite', { p_invitee_id: e.target.who.value })); });
    $$('[data-inv]', body).forEach(b => b.onclick = () => guard(b, () => act('world_party_respond', { p_invite_id: b.dataset.inv, p_accept: b.dataset.acc === '1' })));
    $$('[data-method]', body).forEach(b => b.onclick = () => guard(b, () => act('world_party_set_loot_distribution', { p_method: b.dataset.method, p_priority: b.dataset.method === 'designated' ? (p.members || []).map(m => m.owner_id) : [] })));
    $$('[data-dist]', body).forEach(b => b.onclick = () => guard(b, () => act('world_party_loot_distribute', { p_loot_id: b.dataset.dist })));
    $$('[data-rescue]', body).forEach(b => b.onclick = () => guard(b, () => act('world_rescue_character', { p_target: b.dataset.rescue })));
    $$('[data-fr-acc],[data-fr-dec]', body).forEach(b => b.onclick = () => guard(b, () => act('world_friend_respond', { p_from: b.dataset.frAcc || b.dataset.frDec, p_accept: !!b.dataset.frAcc })));
    $$('[data-fr-cancel]', body).forEach(b => b.onclick = () => guard(b, () => act('world_friend_remove', { p_target: b.dataset.frCancel })));
    $$('[data-unblock]', body).forEach(b => b.onclick = () => guard(b, () => act('world_block_set', { p_target: b.dataset.unblock, p_blocked: false })));
    $$('[data-whisper]', body).forEach(b => b.onclick = () => openWhisper(b.dataset.whisper, b.dataset.whisperId));
    $$('[data-fr-inv]', body).forEach(b => b.onclick = () => guard(b, async () => {
      if (!pt) await act('world_party_create', { p_party_name: `${store.character.character_name}의 동료`.slice(0, 20) });
      return act('world_party_invite', { p_invitee_id: b.dataset.frInv });
    }));
    const lv = $('#party-leave', body);
    if (lv) lv.onclick = async () => {
      const alone = (p.members || []).length <= 1;
      if (await ask(alone ? '파티를 해체할까요? 보낸 초대도 함께 취소됩니다.' : isLeader ? '파티를 나갈까요? 가장 먼저 들어온 파티원이 파티장이 됩니다.' : '파티를 나갈까요?', { title: alone ? '파티 해체' : '파티 나가기', ok: alone ? '해체하기' : '나가기', danger: true })) guard(lv, () => act('world_party_leave'));
    };
    const cl = $('#loot-claim', body); if (cl) cl.onclick = () => guard(cl, () => act('world_party_loot_claim'));
    bindCirclesPanel(body);
    bindBondPanel(body, draw);
  } catch (e) { body.innerHTML = errorBox(e.message); }
}
