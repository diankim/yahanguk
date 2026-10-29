// 모임: 유저가 직접 꾸리는 채팅방. 서버 world_circle_* 함수가 직위·한도·권한을 모두 검사한다.
// 여기서는 소속 목록(채팅의 모임 탭이 쓴다)과, 동료 화면의 모임 칸·관리 창·조사원 카드의 [모임에 초대]를 맡는다.
import { store, rpc, act, ask, esc, icon, guard, $, $$, fmt, openModal, openLayer, closeLayers, closeModal, nameOf, toast } from './core.js';
import { cardName } from './views/card.js';

export const ROLE = { leader: '모임장', manager: '총무', member: '모임원' };
// 채팅 색 견본(직접 고르는 색도 쓸 수 있다)
export const SWATCH = ['#c8a25a', '#6fa8dc', '#8fbf7f', '#d78a8a', '#b08fd8', '#5fb3a8', '#d9a15f', '#9aa8b8', '#e07b5f', '#7fc4d8'];
let snap = null, loading = null;

export const circles = () => snap?.circles || [];
export async function loadCircles(force) {
  if (snap && !force) return snap;
  if (loading) return loading;
  loading = rpc('world_circle_snapshot').then(s => { snap = s || { circles: [], received: [] }; window.dispatchEvent(new CustomEvent('yh-circles', { detail: snap })); return snap; })
    .catch(() => snap || { circles: [], received: [] }).finally(() => { loading = null; });
  return loading;
}
const refresh = () => loadCircles(true);
const run = (b, fn, args) => guard(b, async () => { const r = await act(fn, args); await refresh(); return r; });

/* ── 동료 화면의 모임 칸 ─────────────────────────────── */
export function circlesPanelHtml(s) {
  const list = s?.circles || [], got = s?.received || [], lim = s?.limits || { lead: 2, join: 5, size: 20, level: 5 };
  const canMake = (store.character?.level || 1) >= lim.level && (s?.leading || 0) < lim.lead && (s?.joined || 0) < lim.join;
  return `
    ${got.length ? `<h3 class="sub-h">받은 모임 초대 ${got.length}</h3><ul class="spot-list">${got.map(i => `<li><div><b>「${esc(i.circle_name)}」</b><small>${esc(i.from || '조사원')}님의 초대 · ${i.member_count}명 · ${fmt.remain(new Date(i.expires_at) - Date.now())} 남음</small></div>
      <div class="btn-row"><button class="btn small primary" data-circle-acc="${esc(i.invite_id)}">수락</button><button class="btn small" data-circle-dec="${esc(i.invite_id)}">거절</button></div></li>`).join('')}</ul>` : ''}
    ${list.length ? `<ul class="circle-list">${list.map((c, i) => `<li style="--cc:${esc(c.color)}"><span class="cc-dot"></span><div><b>${esc(c.name)}</b>
        <small>${esc(ROLE[c.role] || '')} · ${c.member_count}/${lim.size}명${c.intro ? ' · ' + esc(c.intro) : ''}</small></div>
        ${list.length > 1 ? `<span class="circle-ord"><button class="btn small ghost" data-circle-up="${esc(c.circle_id)}" ${i === 0 ? 'disabled' : ''} aria-label="위로">${icon('up', 14)}</button><button class="btn small ghost" data-circle-down="${esc(c.circle_id)}" ${i === list.length - 1 ? 'disabled' : ''} aria-label="아래로">${icon('down', 14)}</button></span>` : ''}
        <button class="btn small" data-circle-open="${esc(c.circle_id)}">관리</button></li>`).join('')}</ul>`
      : '<p class="muted small">아직 든 모임이 없습니다. 모임을 만들거나, 다른 조사원의 초대를 받아 보세요.</p>'}
    <form class="circle-new" autocomplete="off">
      <input name="name" maxlength="12" placeholder="새 모임 이름 (2~12자)" ${canMake ? '' : 'disabled'} aria-label="새 모임 이름">
      <input name="intro" maxlength="60" placeholder="한 줄 소개 (없어도 됩니다)" ${canMake ? '' : 'disabled'} aria-label="한 줄 소개">
      <button class="btn small primary" type="submit" ${canMake ? '' : 'disabled'}>${icon('plus', 14)}<span>모임 만들기</span></button>
    </form>
    <p class="muted small">Lv.${lim.level}부터 만들 수 있고, 모임장인 모임 ${lim.lead}개 · 든 모임(만든 것 포함) ${lim.join}개 · 정원 ${lim.size}명까지입니다. 지금 모임장 ${s?.leading || 0}개 · 든 모임 ${s?.joined || 0}개.
      모임 채팅은 통신망의 「모임」 탭에서 모임을 골라 봅니다.</p>`;
}
export function bindCirclesPanel(root) {
  $$('[data-circle-acc],[data-circle-dec]', root).forEach(b => b.onclick = () => run(b, 'world_circle_respond', { p_invite: b.dataset.circleAcc || b.dataset.circleDec, p_accept: !!b.dataset.circleAcc }));
  $$('[data-circle-open]', root).forEach(b => b.onclick = () => openCircle(b.dataset.circleOpen));
  // 순서: 내 화면의 모임 순서(채팅의 모임 단추 줄도 이 순서)를 서버에 저장한다
  $$('[data-circle-up],[data-circle-down]', root).forEach(b => b.onclick = () => guard(b, async () => {
    const ids = circles().map(c => c.circle_id), id = b.dataset.circleUp || b.dataset.circleDown, i = ids.indexOf(id), j = i + (b.dataset.circleUp ? -1 : 1);
    if (i < 0 || j < 0 || j >= ids.length) return null;
    [ids[i], ids[j]] = [ids[j], ids[i]];
    await rpc('world_circle_reorder', { p_ids: ids }); await refresh(); return null;
  }));
  const f = $('.circle-new', root);
  if (f) f.onsubmit = e => { e.preventDefault(); const b = f.querySelector('button'); run(b, 'world_circle_create', { p_name: f.name.value.trim(), p_intro: f.intro.value.trim() }); };
}

/* ── 모임 관리 창 ─────────────────────────────────────── */
export async function openCircle(id) {
  const m = openModal({ title: '모임', wide: true, body: '<div class="circle-box"></div>' });
  const box = $('.circle-box', m);
  const draw = () => {
    const c = circles().find(x => x.circle_id === id);
    if (!c) { box.innerHTML = '<p class="muted">이 모임에 들어 있지 않습니다.</p>'; return; }
    const me = store.character?.owner_id, lead = c.role === 'leader', staff = lead || c.role === 'manager';
    $('.modal-head h2', m).textContent = `모임 · ${c.name}`;
    box.innerHTML = `
      <p class="desc">${esc(c.intro || '소개가 없습니다.')}</p>
      <div class="chips"><span class="chip accent">${esc(ROLE[c.role])}</span><span class="chip">${c.member_count}/20명</span></div>
      <h3 class="sub-h">내 화면의 채팅 색</h3>
      <div class="cc-pick" role="radiogroup" aria-label="채팅 색">${SWATCH.map(col => `<button class="cc-sw ${col === c.color ? 'on' : ''}" style="--cc:${col}" data-color="${col}" aria-label="${col}" role="radio" aria-checked="${col === c.color}"></button>`).join('')}
        <label class="cc-custom" title="직접 고르기"><input type="color" value="${esc(c.color)}" aria-label="직접 고르기"><span>직접</span></label></div>
      <p class="muted small">이 색은 나에게만 보입니다. 모임마다 다른 색을 정해 두면 채팅이 섞여도 알아보기 쉽습니다.</p>
      <h3 class="sub-h">모임원 ${c.members.length}</h3>
      <ul class="people circle-members">${c.members.map(x => {
        const self = x.owner_id === me;
        const btns = self ? '' : [
          lead && x.role === 'member' ? `<button class="btn small" data-m="manager" data-t="${esc(x.owner_id)}">총무로</button>` : '',
          lead && x.role === 'manager' ? `<button class="btn small" data-m="member" data-t="${esc(x.owner_id)}">모임원으로</button>` : '',
          lead ? `<button class="btn small" data-m="transfer" data-t="${esc(x.owner_id)}" data-n="${esc(x.name)}">모임장 넘기기</button>` : '',
          (lead || (c.role === 'manager' && x.role === 'member')) ? `<button class="btn small ghost danger-text" data-m="kick" data-t="${esc(x.owner_id)}" data-n="${esc(x.name)}">내보내기</button>` : '',
        ].join('');
        return `<li><div><b>${cardName(x.owner_id, x.name)} <span class="chip ${x.role === 'leader' ? 'accent' : x.role === 'manager' ? 'ok' : ''}">${esc(ROLE[x.role])}</span></b>
          <small>Lv.${x.level || 1} · ${esc(nameOf(x.job_key))} · ${esc(x.location || '')}</small></div>${btns ? `<div class="btn-row">${btns}</div>` : ''}</li>`;
      }).join('')}</ul>
      ${staff && c.invites.length ? `<h3 class="sub-h">보낸 초대</h3><ul class="spot-list">${c.invites.map(i => `<li><div><b>${esc(i.name || '조사원')}</b><small>${fmt.remain(new Date(i.expires_at) - Date.now())} 남음</small></div>
        <button class="btn small ghost" data-cancel="${esc(i.invite_id)}">거두기</button></li>`).join('')}</ul>` : ''}
      ${staff ? `<p class="muted small">초대는 조사원 카드(채팅·동료·여기 있는 이들에서 이름을 누름)의 [모임에 초대]로 보냅니다. 24시간 안에 수락해야 합니다.</p>
        <h3 class="sub-h">고치기</h3>
        <form class="circle-edit" data-k="intro"><input name="v" maxlength="60" value="${esc(c.intro || '')}" placeholder="한 줄 소개" aria-label="한 줄 소개"><button class="btn small">소개 고치기</button></form>
        ${lead ? `<form class="circle-edit" data-k="rename"><input name="v" maxlength="12" value="${esc(c.name)}" aria-label="모임 이름"><button class="btn small">이름 바꾸기</button></form>` : ''}` : ''}
      <div class="btn-row circle-end">
        ${lead ? `<button class="btn small danger" data-end="disband">${icon('close', 14)}<span>모임 해산</span></button>` : ''}
        ${!lead || c.member_count <= 1 ? `<button class="btn small" data-end="leave">${icon('back', 14)}<span>${lead ? '닫고 나가기' : '모임 나가기'}</span></button>` : ''}
      </div>
      <p class="muted small">총무는 3명까지, 모임장은 모임원을 총무로 올리거나 모임장을 넘길 수 있습니다. 모임장은 모임장을 넘긴 뒤에 나갈 수 있습니다.</p>`;
    const manage = (b, action, target, text) => guard(b, async () => { const r = await act('world_circle_manage', { p_circle: id, p_action: action, p_target: target || null, p_text: text ?? null }); await refresh(); if (circles().some(x => x.circle_id === id)) draw(); else closeModal(); return r; });
    $$('[data-color]', box).forEach(b => b.onclick = () => setColor(b, id, b.dataset.color, draw));
    const ci = $('.cc-custom input', box); ci.onchange = () => setColor(ci, id, ci.value, draw);
    $$('[data-m]', box).forEach(b => b.onclick = async () => {
      const k = b.dataset.m, n = b.dataset.n;
      if (k === 'kick' && !(await ask(`${n}님을 모임에서 내보낼까요?`, { title: '내보내기', ok: '내보내기', danger: true }))) return;
      if (k === 'transfer' && !(await ask(`${n}님에게 모임장을 넘길까요? 나는 총무가 됩니다.`, { title: '모임장 넘기기', ok: '넘기기' }))) return;
      manage(b, k, b.dataset.t);
    });
    $$('[data-cancel]', box).forEach(b => b.onclick = () => manage(b, 'cancel_invite', null, b.dataset.cancel));
    $$('.circle-edit', box).forEach(f => f.onsubmit = e => { e.preventDefault(); manage(f.querySelector('button'), f.dataset.k, null, f.v.value.trim()); });
    $$('[data-end]', box).forEach(b => b.onclick = async () => {
      const dis = b.dataset.end === 'disband';
      if (!(await ask(dis ? `모임 「${c.name}」을(를) 해산할까요? 대화도 모두 사라지고 되돌릴 수 없습니다.` : `모임 「${c.name}」에서 나갈까요?`, { title: dis ? '모임 해산' : '모임 나가기', ok: dis ? '해산' : '나가기', danger: dis }))) return;
      manage(b, b.dataset.end);
    });
  };
  await loadCircles(); draw();
}
async function setColor(b, id, color, then) {
  try { await rpc('world_circle_set_color', { p_circle: id, p_color: color }); const c = circles().find(x => x.circle_id === id); if (c) c.color = color.toLowerCase();
    window.dispatchEvent(new CustomEvent('yh-circles', { detail: snap })); then?.(); }
  catch (e) { toast(e.message, 'error'); }
}

/* ── 조사원 카드의 [모임에 초대] ─────────────────────── */
export async function canInviteSomewhere() { await loadCircles(); return circles().some(c => c.role === 'leader' || c.role === 'manager'); }
export async function inviteToCircle(targetId, targetName) {
  await loadCircles();
  const mine = circles().filter(c => (c.role === 'leader' || c.role === 'manager') && !c.members.some(x => x.owner_id === targetId));
  if (!mine.length) return toast('초대할 수 있는 모임이 없습니다. (모임장·총무만 초대할 수 있습니다)', 'info');
  const send = (b, id) => guard(b, async () => { const r = await act('world_circle_invite', { p_circle: id, p_target: targetId }); closeLayers(); await refresh(); return r; });
  const l = openLayer({ title: `${targetName}님을 모임에 초대`, body: `<ul class="circle-list">${mine.map(c => `<li style="--cc:${esc(c.color)}"><span class="cc-dot"></span><div><b>${esc(c.name)}</b><small>${c.member_count}/20명</small></div>
    <button class="btn small primary" data-pick="${esc(c.circle_id)}">초대</button></li>`).join('')}</ul>` });
  $$('[data-pick]', l).forEach(b => b.onclick = () => send(b, b.dataset.pick));
}
