import { petImage } from '../housing/petsprite.js';
import { rpc, act, ask, guard, store, nameOf, esc, icon, emblem, profileOf, JOBS, fmt, openLayer, openModal, closeModal, closeLayers, $ } from '../core.js';
import { circles, inviteToCircle } from '../circles.js';
import { bond, bondSnap, loadBond, openPropose, tokenSvg } from '../bond.js';
import { chip, invalidate } from './common.js';
import { factionColor } from '../geo.js';
import { nameStyle } from '../chat.js';
import { patternLayer, sealMark } from '../cosmetics.js';
import { nickTag, noteOf, setNote } from '../people.js';

const RANKS = [['combat', '전투'], ['gathering', '채집'], ['crafting', '제작'], ['investigation', '조사']];

export async function openCharacterCard(id) {
  if (!id) return;
  const opts = { title: '조사원 정보', body: '<div class="char-card"><div class="loading"><span class="spinner"></span>불러오는 중…</div></div>' };
  const m = document.getElementById('modal') ? openLayer(opts) : openModal(opts);
  await draw($('.char-card', m), id);
}

const ago = t => { const s = Math.max(0, (Date.now() - new Date(t)) / 1000); return s < 120 ? '방금' : s < 3600 ? `${Math.floor(s / 60)}분 전` : s < 86400 ? `${Math.floor(s / 3600)}시간 전` : `${Math.floor(s / 86400)}일 전`; };

async function draw(box, id) {
  try {
    const [c, pub] = await Promise.all([rpc('world_character_card', { p_owner: id }), rpc('world_bond_public', { p_owner: id }).catch(() => null), loadBond()]);
    const mine = bond(), isPartner = mine?.partner_id === id;
    const canBond = !c.mine && !c.is_dead && c.relation === 'friends' && !mine && !bondSnap()?.outgoing && !pub;
    const p = profileOf(c.owner_id, c.profile);
    const state = c.is_dead ? chip('숨을 거둠', 'bad') : c.downed ? chip('전투불능', 'bad') : c.in_combat ? chip('전투 중', 'warn')
      : c.away ? chip('원정 중', 'accent') : c.traveling ? chip('이동 중', 'accent') : chip('활동 중', 'ok');
    const yoChip = c.yohwa === 'frenzy' ? chip('요괴화', 'bad') : c.yohwa === '3' ? chip('반요 · 요화 3단계', 'warn') : '';
    const rel = c.relation || 'none';
    const me = store.character || {};
    const sparWhy = !c.same_place ? '같은 곳에 있어야 함' : c.downed ? '상대 전투불능' : c.away ? '상대 원정 중' : c.traveling ? '상대 이동 중' : c.in_combat ? '상대 전투 중'
      : me.downed_at ? '내가 전투불능' : me.travel_destination ? '내가 이동 중' : '';
    const canInvite = !c.mine && !c.in_party && !c.is_dead && (!c.my_party_role || c.my_party_role === 'leader');
    const acts = c.mine ? `<a class="btn small" href="#/settings/profile" data-close>${icon('gear', 14)}<span>내 프로필 수정</span></a>` : c.blocked ? '' : `
      ${rel === 'friends' ? `<button class="btn small" data-do="unfriend">${icon('users', 14)}<span>친구 끊기</span></button>`
        : rel === 'outgoing' ? `<button class="btn small" data-do="unfriend">${icon('close', 14)}<span>친구 신청 취소</span></button>`
        : rel === 'incoming' ? `<button class="btn small primary" data-do="accept">${icon('check', 14)}<span>친구 수락</span></button><button class="btn small" data-do="decline">거절</button>`
        : `<button class="btn small primary" data-do="friend">${icon('plus', 14)}<span>친구 신청</span></button>`}
      ${c.is_dead ? '' : `<button class="btn small" data-do="whisper">${icon('chat', 14)}<span>귓속말</span></button>`}
      ${rel === 'friends' ? `<button class="btn small" data-do="note">${icon('scroll', 14)}<span>별명·메모</span></button>` : ''}
      ${rel === 'friends' && !c.is_dead ? `<button class="btn small" data-do="letter">${icon('letter', 14)}<span>서신 보내기</span></button>` : ''}
      ${c.is_dead ? '' : sparWhy ? `<button class="btn small" disabled title="${esc(sparWhy)}">${icon('sword', 14)}<span>비무 · ${esc(sparWhy)}</span></button>` : `<button class="btn small" data-do="spar" title="목숨을 걸지 않는 겨루기(체력·물품은 줄지 않음)">${icon('sword', 14)}<span>비무 신청</span></button>`}
      ${canInvite ? `<button class="btn small" data-do="invite">${icon('users', 14)}<span>파티 초대</span></button>` : ''}
      ${!c.is_dead && circles().some(x => (x.role === 'leader' || x.role === 'manager') && !x.members.some(mm => mm.owner_id === c.owner_id)) ? `<button class="btn small" data-do="circle">${icon('chat', 14)}<span>모임에 초대</span></button>` : ''}
      ${c.housing ? `<button class="btn small" data-do="house">${icon('home', 14)}<span>${c.mine ? '내 별채' : '별채 구경'}</span></button>` : ''}
      ${c.same_party ? chip('같은 파티', 'accent') : ''}
      ${isPartner ? chip('정인', 'accent') : canBond ? `<button class="btn small" data-do="bond">${tokenSvg('heart', 14)}<span>연리 맺기</span></button>` : ''}
      ${c.same_place && !c.is_dead ? `<button class="btn small" data-do="trade">${icon('coin', 14)}<span>거래 제안</span></button>` : ''}
      ${c.same_place && c.downed && !c.is_dead ? `<button class="btn small primary" data-do="rescue" data-here="구조">${icon('heart', 14)}<span>구조</span></button>` : ''}`;
    box.innerHTML = `
      <div class="profile-card">${patternLayer(c.profile?.pattern)}<div class="pc-emblem">${emblem(c.owner_id, c.profile, 72)}</div>
        <div><h3><span class="card-name${nameStyle(c.profile?.chat_hue, c.owner_id).cls}" style="--hu:${nameStyle(c.profile?.chat_hue, c.owner_id).hu}">${esc(c.character_name)}</span>${sealMark(c.profile?.seal)}${c.gm ? '<span class="gm-badge" title="운영진(GM)">GM</span>' : ''}${c.yohwa === 'frenzy' ? '<em class="yohwa-mark" title="요괴화 — 요괴의 힘이 몸을 차지한 채 한 시간을 버티는 중입니다">요괴화</em>' : ''}</h3>
          ${c.display_title ? `<p class="title-badge">「${esc(c.display_title)}」</p>` : ''}
          <p>Lv.${c.level || 1} · ${esc(nameOf(c.job_key))} · ${esc(nameOf(c.faction_key))}</p>${c.major_faction_id ? `<p><span class="fchip" style="--fc:${factionColor(c.major_faction_id)}">${esc(nameOf(c.major_faction_id))}${c.faction_rank ? ` · ${esc(c.faction_rank)}` : ''}</span></p>` : ''}${c.tn_champ ? `<p><span class="chip tn-badge">${c.tn_champ === 'team' ? '비무 장원 · 팀전' : '비무 장원'}</span></p>` : ''}
          <p class="muted small">${esc(JOBS[c.job_key]?.trait || '')}${rel === 'friends' ? ' · 친구' : ''}</p></div>
        ${c.pet ? `<div class="pc-pet" title="함께 다니는 꼬마 동무"><img src="${petImage(c.pet.id, c.pet.adult, { scale: 3 })}" alt=""><small>${esc(c.pet.nick || c.pet.name || '')}</small></div>` : ''}</div>
      <p class="bio">${p.bio ? esc(p.bio) : '<span class="muted">한 줄 소개가 없습니다.</span>'}</p>
      ${rel === 'friends' && noteOf(c.owner_id) ? `<p class="f-memo">${noteOf(c.owner_id).nick ? `<b>내가 붙인 별명</b> ${esc(noteOf(c.owner_id).nick)}` : ''}${noteOf(c.owner_id).nick && noteOf(c.owner_id).memo ? '<br>' : ''}${esc(noteOf(c.owner_id).memo || '')}</p>` : ''}
      <dl class="kv info">
        <div><dt>지금</dt><dd class="chips">${state}${yoChip}</dd></div>
        <div><dt>있는 곳</dt><dd>${esc(c.location || '알 수 없음')}${c.same_place && !c.mine ? ' <span class="muted small">(같은 곳)</span>' : ''}</dd></div>
        ${c.last_active && !c.mine ? `<div><dt>최근 활동</dt><dd>${ago(c.last_active)}</dd></div>` : ''}
        <div><dt>숙련</dt><dd title="갈래마다 가장 높은 기술 단계(최고 50)">${RANKS.map(([k, n]) => `${n} ${c.ranks?.[k] || 1}`).join(' · ')} <span class="muted small">/ 50</span></dd></div>
        <div><dt>얻은 칭호</dt><dd>${fmt.num(c.title_count || 0)}개</dd></div>
        ${pub ? `<div><dt>정인</dt><dd class="bond-pub">${pub.wear ? tokenSvg(pub.token_key, 16) : ''}${esc(pub.partner_name || '')} <span class="muted small">· ${esc(pub.token_name)} · ${esc(pub.stage_name)}</span></dd></div>` : ''}
      </dl>
      ${(c.titles || []).length ? `<h3 class="sub-h">장착한 칭호</h3><div class="chips card-titles">${c.titles.map(t => `<span class="chip ${t.hidden ? '' : 'accent'}" title="${esc(t.description || '')}">${esc(t.name)}</span>`).join('')}</div>` : ''}
      ${acts.trim() ? `<div class="card-acts">${acts}</div>` : ''}
      ${c.mine ? '' : `<div class="card-foot">${c.blocked ? '<span class="muted small">차단한 조사원입니다. 귓속말·신청·초대·거래 제안을 받지 않고 채팅에서도 숨깁니다.</span>' : ''}
        <button class="btn small ghost ${c.blocked ? '' : 'danger-text'}" data-do="${c.blocked ? 'unblock' : 'block'}">${c.blocked ? '차단 풀기' : '차단하기'}</button></div>`}`;
    box.onclick = e => { const b = e.target.closest('[data-do]'); if (b) run(b, c, box); };
  } catch (e) { box.innerHTML = `<p class="bad">${esc(e.message)}</p>`; }
}

async function run(b, c, box) {
  const k = b.dataset.do, id = c.owner_id, again = () => box.isConnected && draw(box, id);
  const close = () => { closeLayers(); closeModal(); };
  if (k === 'friend') return guard(b, async () => { const r = await act('world_friend_request', { p_target: id }); again(); return r; });
  if (k === 'accept' || k === 'decline') return guard(b, async () => { const r = await act('world_friend_respond', { p_from: id, p_accept: k === 'accept' }); again(); return r; });
  if (k === 'unfriend') {
    if (c.relation === 'friends' && !(await ask(`${c.character_name}님과 친구를 끊을까요?`, { title: '친구 끊기', ok: '끊기', danger: true }))) return;
    return guard(b, async () => { const r = await act('world_friend_remove', { p_target: id }); again(); return r; });
  }
  if (k === 'note') return openFriendNote(id, c.character_name, again);
  if (k === 'letter') { close(); const { openCompose } = await import('../letters.js'); return openCompose(c.owner_id, c.character_name); }
  if (k === 'whisper') { close(); const { openWhisper } = await import('../chat.js'); return openWhisper(c.character_name, c.owner_id); }
  if (k === 'invite') return guard(b, async () => {
    if (!c.my_party_role) await act('world_party_create', { p_party_name: `${store.character?.character_name || '조사원'}의 동료`.slice(0, 20) });
    const r = await act('world_party_invite', { p_invitee_id: id }); again(); return r;
  });
  if (k === 'circle') return inviteToCircle(id, c.character_name);
  if (k === 'bond') return openPropose(id, c.character_name);
  if (k === 'trade') { close(); const { openDirectTrade } = await import('./services.js'); return openDirectTrade(id); }
  if (k === 'spar') return guard(b, () => act('world_spar_challenge', { p_target: id }));
  if (k === 'house') {
    if (c.mine) { close(); return window.yahangGo?.('house', ''); }
    return guard(b, async () => {
      const snap = await rpc('world_housing_snapshot', { p_owner: id });
      store.houseSnap = { owner: id, snap, at: Date.now() };
      close(); window.yahangGo?.('house', id);
    });
  }
  if (k === 'rescue') return guard(b, async () => { const r = await act('world_rescue_character', { p_target: id }); again(); return r; });
  if (k === 'block') {
    if (!(await ask(`${c.character_name}님을 차단할까요?\n친구 관계가 끊기고, 귓속말·친구 신청·파티 초대·거래 제안을 받지 않으며 채팅에서도 보이지 않습니다.`, { title: '차단하기', ok: '차단', danger: true }))) return;
    return guard(b, async () => { const r = await act('world_block_set', { p_target: id, p_blocked: true }); again(); return r; });
  }
  if (k === 'unblock') return guard(b, async () => { const r = await act('world_block_set', { p_target: id, p_blocked: false }); again(); return r; });
}

export function openFriendNote(id, name, done) {
  const cur = noteOf(id) || {};
  const m = openLayer({ title: `${name} · 별명과 메모`, body: `<form class="form-grid f-note-form">
    <label class="field"><span>별명 <small class="muted">12자까지 · 나만 보입니다</small></span><input name="nick" maxlength="12" value="${esc(cur.nick || '')}" autocomplete="off"></label>
    <label class="field"><span>메모 <small class="muted">200자까지 · 나만 보입니다</small></span><textarea name="memo" maxlength="200" rows="4">${esc(cur.memo || '')}</textarea></label>
    <div class="btn-row"><button class="btn primary" type="submit">저장</button><button class="btn ghost" type="button" data-clear>지우기</button></div></form>` });
  const f = m.querySelector('.f-note-form');
  const save = (nick, memo) => guard(f.querySelector('[type=submit]'), async () => {
    const r = await rpc('world_friend_note_set', { p_target: id, p_nick: nick, p_memo: memo });
    setNote(id, r?.nick, r?.memo); invalidate('world_friend_overview'); m.close(); done?.();
    return { content: r?.nick || r?.memo ? '별명과 메모를 저장했습니다.' : '별명과 메모를 지웠습니다.' };
  });
  f.onsubmit = e => { e.preventDefault(); save(f.nick.value, f.memo.value); };
  f.querySelector('[data-clear]').onclick = () => save('', '');
}
export const cardName = (id, name) => id ? `<button type="button" class="name-link" data-card="${esc(id)}">${esc(name || '조사원')}</button>${nickTag(id)}` : esc(name || '조사원');

export function mountCards() {
  document.addEventListener('click', e => {
    const b = e.target.closest('[data-card]'); if (!b) return;
    e.preventDefault(); e.stopPropagation();
    openCharacterCard(b.dataset.card);
  });
}
