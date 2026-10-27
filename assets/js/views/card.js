// 조사원 카드: 채팅·여기 있는 이들·동료에서 이름을 누르면 공개 정보와 교류 단추를 보여 준다(서버 world_character_card).
// 화면 어디서든 data-card="owner_id"가 붙은 요소를 누르면 열린다. 다른 창 위에 겹쳐 떠서 닫아도 아래 창은 남는다.
// 친구·귓속말·파티 초대·거래 제안·구조·차단은 모두 서버가 다시 검사한다(단추는 길잡이일 뿐).
import { rpc, act, ask, guard, store, nameOf, esc, icon, emblem, profileOf, JOBS, fmt, openLayer, openModal, closeModal, closeLayers, $ } from '../core.js';
import { chip } from './common.js';
import { patternLayer, sealMark } from '../cosmetics.js';

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
    const c = await rpc('world_character_card', { p_owner: id });
    const p = profileOf(c.owner_id, c.profile);
    const state = c.is_dead ? chip('숨을 거둠', 'bad') : c.downed ? chip('전투불능', 'bad') : c.in_combat ? chip('전투 중', 'warn')
      : c.away ? chip('원정 중', 'accent') : c.traveling ? chip('이동 중', 'accent') : chip('활동 중', 'ok');
    const rel = c.relation || 'none', safe = !!(store.snaps?.['world_field_snapshotnull'] || store.snaps?.world_field_snapshot)?.region?.safe;
    // 파티 초대: 상대가 파티가 없고, 내가 파티장이거나 아직 파티가 없을 때(없으면 만들고 초대)
    const canInvite = !c.mine && !c.in_party && !c.is_dead && (!c.my_party_role || c.my_party_role === 'leader');
    const acts = c.mine ? `<a class="btn small" href="#/settings/profile" data-close>${icon('gear', 14)}<span>내 프로필 수정</span></a>` : c.blocked ? '' : `
      ${rel === 'friends' ? `<button class="btn small" data-do="unfriend">${icon('users', 14)}<span>친구 끊기</span></button>`
        : rel === 'outgoing' ? `<button class="btn small" data-do="unfriend">${icon('close', 14)}<span>친구 신청 취소</span></button>`
        : rel === 'incoming' ? `<button class="btn small primary" data-do="accept">${icon('check', 14)}<span>친구 수락</span></button><button class="btn small" data-do="decline">거절</button>`
        : `<button class="btn small primary" data-do="friend">${icon('plus', 14)}<span>친구 신청</span></button>`}
      ${c.is_dead ? '' : `<button class="btn small" data-do="whisper">${icon('chat', 14)}<span>귓속말</span></button>`}
      ${canInvite ? `<button class="btn small" data-do="invite">${icon('users', 14)}<span>파티 초대</span></button>` : ''}
      ${c.same_party ? chip('같은 파티', 'accent') : ''}
      ${c.same_place && safe && !c.is_dead ? `<button class="btn small" data-do="trade">${icon('coin', 14)}<span>거래 제안</span></button>` : ''}
      ${c.same_place && c.downed && !c.is_dead ? `<button class="btn small primary" data-do="rescue">${icon('heart', 14)}<span>구조</span></button>` : ''}`;
    box.innerHTML = `
      <div class="profile-card">${patternLayer(c.profile?.pattern)}<div class="pc-emblem">${emblem(c.owner_id, c.profile, 72)}</div>
        <div><h3>${esc(c.character_name)}${sealMark(c.profile?.seal)}${c.gm ? '<span class="gm-badge" title="운영진(GM)">GM</span>' : ''}</h3>
          ${c.display_title ? `<p class="title-badge">「${esc(c.display_title)}」</p>` : ''}
          <p>Lv.${c.level || 1} · ${esc(nameOf(c.job_key))} · ${esc(nameOf(c.faction_key))}${c.major_faction_id ? ' · ' + esc(nameOf(c.major_faction_id)) : ''}</p>
          <p class="muted small">${esc(JOBS[c.job_key]?.trait || '')}${rel === 'friends' ? ' · 친구' : ''}</p></div></div>
      <p class="bio">${p.bio ? esc(p.bio) : '<span class="muted">한 줄 소개가 없습니다.</span>'}</p>
      <dl class="kv info">
        <div><dt>지금</dt><dd>${state}</dd></div>
        <div><dt>있는 곳</dt><dd>${esc(c.location || '알 수 없음')}${c.same_place && !c.mine ? ' <span class="muted small">(같은 곳)</span>' : ''}</dd></div>
        ${c.last_active && !c.mine ? `<div><dt>최근 활동</dt><dd>${ago(c.last_active)}</dd></div>` : ''}
        <div><dt>숙련</dt><dd>${RANKS.map(([k, n]) => `${n} ${c.ranks?.[k] || 1}`).join(' · ')}</dd></div>
        <div><dt>얻은 칭호</dt><dd>${fmt.num(c.title_count || 0)}개</dd></div>
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
  if (k === 'whisper') { close(); const { openWhisper } = await import('../chat.js'); return openWhisper(c.character_name); }
  if (k === 'invite') return guard(b, async () => {
    if (!c.my_party_role) await act('world_party_create', { p_party_name: `${store.character?.character_name || '조사원'}의 동료`.slice(0, 20) });
    const r = await act('world_party_invite', { p_invitee_id: id }); again(); return r;
  });
  if (k === 'trade') { close(); const { openDirectTrade } = await import('./services.js'); return openDirectTrade(id); }
  if (k === 'rescue') return guard(b, async () => { const r = await act('world_rescue_character', { p_target: id }); again(); return r; });
  if (k === 'block') {
    if (!(await ask(`${c.character_name}님을 차단할까요?\n친구 관계가 끊기고, 귓속말·친구 신청·파티 초대·거래 제안을 받지 않으며 채팅에서도 보이지 않습니다.`, { title: '차단하기', ok: '차단', danger: true }))) return;
    return guard(b, async () => { const r = await act('world_block_set', { p_target: id, p_blocked: true }); again(); return r; });
  }
  if (k === 'unblock') return guard(b, async () => { const r = await act('world_block_set', { p_target: id, p_blocked: false }); again(); return r; });
}

// 이름 단추: 누르면 카드가 열린다
export const cardName = (id, name) => id ? `<button type="button" class="name-link" data-card="${esc(id)}">${esc(name || '조사원')}</button>` : esc(name || '조사원');

export function mountCards() {
  document.addEventListener('click', e => {
    const b = e.target.closest('[data-card]'); if (!b) return;
    e.preventDefault(); e.stopPropagation();
    openCharacterCard(b.dataset.card);
  });
}
