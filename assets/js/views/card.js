// 조사원 카드: 채팅·여기 있는 이들·동료에서 이름을 누르면 공개 정보를 보여 준다(서버 world_character_card).
// 화면 어디서든 data-card="owner_id"가 붙은 요소를 누르면 열린다. 다른 창 위에 겹쳐 떠서 닫아도 아래 창은 남는다.
import { rpc, nameOf, esc, icon, emblem, profileOf, JOBS, openLayer, openModal, $ } from '../core.js';
import { chip } from './common.js';

const RANKS = [['combat', '전투'], ['gathering', '채집'], ['crafting', '제작'], ['investigation', '조사']];

export async function openCharacterCard(id) {
  if (!id) return;
  const opts = { title: '조사원 정보', body: '<div class="char-card"><div class="loading"><span class="spinner"></span>불러오는 중…</div></div>' };
  const m = document.getElementById('modal') ? openLayer(opts) : openModal(opts);
  const box = $('.char-card', m);
  try {
    const c = await rpc('world_character_card', { p_owner: id });
    const p = profileOf(c.owner_id, c.profile);
    const state = c.is_dead ? chip('숨을 거둠', 'bad') : c.downed ? chip('전투불능', 'bad') : c.in_combat ? chip('전투 중', 'warn')
      : c.away ? chip('원정 중', 'accent') : c.traveling ? chip('이동 중', 'accent') : chip('활동 중', 'ok');
    box.innerHTML = `
      <div class="profile-card"><div class="pc-emblem">${emblem(c.owner_id, c.profile, 72)}</div>
        <div><h3>${esc(c.character_name)}${c.gm ? '<span class="gm-badge" title="운영진(GM)">GM</span>' : ''}</h3>
          ${c.display_title ? `<p class="title-badge">「${esc(c.display_title)}」</p>` : ''}
          <p>Lv.${c.level || 1} · ${esc(nameOf(c.job_key))} · ${esc(nameOf(c.faction_key))}${c.major_faction_id ? ' · ' + esc(nameOf(c.major_faction_id)) : ''}</p>
          <p class="muted small">${esc(JOBS[c.job_key]?.trait || '')}</p></div></div>
      <p class="bio">${p.bio ? esc(p.bio) : '<span class="muted">한 줄 소개가 없습니다.</span>'}</p>
      <dl class="kv info">
        <div><dt>지금</dt><dd>${state}</dd></div>
        <div><dt>있는 곳</dt><dd>${esc(c.location || '알 수 없음')}</dd></div>
        <div><dt>숙련</dt><dd>${RANKS.map(([k, n]) => `${n} ${c.ranks?.[k] || 1}`).join(' · ')}</dd></div>
        <div><dt>얻은 칭호</dt><dd>${c.title_count || 0}개</dd></div>
      </dl>
      ${(c.titles || []).length ? `<h3 class="sub-h">장착한 칭호</h3><div class="chips">${c.titles.map(t => `<span class="chip ${t.hidden ? '' : 'accent'}" title="${esc(t.description || '')}">${esc(t.name)}</span>`).join('')}</div>` : ''}
      ${c.mine ? `<div class="btn-row"><a class="btn small" href="#/settings/profile" data-close>${icon('gear', 14)}<span>내 프로필 수정</span></a></div>` : ''}`;
  } catch (e) { box.innerHTML = `<p class="bad">${esc(e.message)}</p>`; }
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
