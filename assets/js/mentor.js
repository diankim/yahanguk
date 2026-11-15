import { store, rpc, act, ask, esc, icon, guard, $, $$, fmt, openModal, closeModal, nameOf, empty } from './core.js';
import { cardName } from './views/card.js';
import { face } from './people.js';
import { openWhisper } from './chat.js';
import { MENTOR } from './rules.js';

let snap = null, at = 0, loading = null;

export async function loadMentor(force) {
  if (snap && !force && Date.now() - at < 60000) return snap;
  if (loading) return loading;
  loading = rpc('world_mentor_board').then(s => { snap = s || null; at = Date.now(); return snap; })
    .catch(() => snap).finally(() => { loading = null; });
  return loading;
}

const ago = t => fmt.ago(t);
const wantChips = w => (w || []).map(k => `<span class="mt-want">${esc(MENTOR.post?.wants?.[k] || k)}</span>`).join('');
const KIND = { seek: '선배를 찾아요', offer: '같이 가요' };

export function mentorSummary(s) {
  const me = s?.me; if (!me) return '';
  return me.merit || me.total ? `챙김 ${fmt.num(me.merit)}` : (s.posts || []).length ? `글 ${(s.posts || []).length}` : '';
}

export function mentorPanelHtml(s, { canInvite = true } = {}) {
  if (!s?.me) return empty('불러오지 못했습니다.', 'users');
  const me = s.me, lv = me.level || store.character?.level || 1;
  if (me.staff) return `<p class="muted small">운영진은 선배·새내기로 셈하지 않습니다.</p>`;
  const seekOk = MENTOR.canSeek(lv), offerOk = MENTOR.canOffer(lv);
  const kind0 = me.post?.kind || (seekOk && (!offerOk || lv < 25) ? 'seek' : 'offer');
  const kids = (s.people || []).filter(p => p.role === 'mentee'), seniors = (s.people || []).filter(p => p.role === 'mentor');
  const asSenior = offerOk && (me.total > 0 || kids.length > 0 || lv >= 2 * MENTOR.gap);
  const stats = [
    asSenior || me.merit ? `<div class="mt-stat"><small>챙김</small><b>${fmt.num(me.merit)}</b><em>누계 ${fmt.num(me.total)} · <button class="linkish" id="mt-shop" type="button">쓰기</button></em></div>` : '',
    asSenior ? `<div class="mt-stat"><small>오늘 챙김</small><b>${fmt.num(me.today_merit)}<i>/${MENTOR.day_cap}</i></b><em>새내기 ${kids.length}명</em></div>` : '',
    seekOk && me.xp_day_cap ? `<div class="mt-stat"><small>오늘 선배 덤</small><b>${fmt.num(me.today_xp)}<i>/${fmt.num(me.xp_day_cap)}</i></b><em>선배 ${seniors.length}명</em></div>` : '',
  ].join('');
  const post = me.post
    ? `<div class="mt-mine"><div><span class="chip ${me.post.kind === 'seek' ? 'accent' : 'ok'}">${KIND[me.post.kind]}</span> ${wantChips(me.post.wants)}
        ${me.post.note ? `<p>${esc(me.post.note)}</p>` : ''}<small class="muted">${fmt.remain(new Date(me.post.until) - Date.now())} 동안 보입니다</small></div>
        <button class="btn small ghost" id="mt-unpost">내리기</button></div>`
    : `<form class="mt-form" id="mt-form">
        <div class="mt-kinds">${['seek', 'offer'].map(k => `<label class="mt-kind ${(k === 'seek' ? seekOk : offerOk) ? '' : 'off'}"><input type="radio" name="kind" value="${k}" ${k === kind0 ? 'checked' : ''} ${(k === 'seek' ? seekOk : offerOk) ? '' : 'disabled'}><span>${KIND[k]}</span></label>`).join('')}</div>
        <div class="mt-wants">${Object.entries(MENTOR.post?.wants || {}).map(([k, n]) => `<label class="mt-wantpick"><input type="checkbox" name="w" value="${k}"><span>${esc(n)}</span></label>`).join('')}</div>
        <div class="mt-row"><input name="note" maxlength="${MENTOR.post?.note || 30}" placeholder="한 줄 남기기 (예: 저녁에 원정 같이 가요)" autocomplete="off"><button class="btn small primary" type="submit">${icon('plus', 14)}<span>올리기</span></button></div>
        <small class="muted">${MENTOR.post?.hours || 2}시간 동안 보이고, 하루 처음 올릴 때 전체 채팅 「선배 소식」에 한 줄 알립니다.</small>
      </form>`;
  const card = p => `<li class="mt-post ${p.kind}">${face(p.owner_id, p.profile, 34, p.name)}
      <div><b>${cardName(p.owner_id, p.name)} <span class="chip ${p.kind === 'seek' ? 'accent' : 'ok'}">${KIND[p.kind]}</span></b>
        <small>Lv.${p.level} · ${esc(nameOf(p.job_key))} · ${esc(p.location || '')}${p.last_active ? ' · ' + esc(ago(p.last_active)) : ''}</small>
        ${(p.wants || []).length ? `<span class="mt-wants-row">${wantChips(p.wants)}</span>` : ''}
        ${p.note ? `<q>${esc(p.note)}</q>` : ''}</div>
      <div class="btn-row">${canInvite ? `<button class="btn small primary" data-mt-inv="${esc(p.owner_id)}">${icon('plus', 14)}<span>파티 초대</span></button>` : ''}
        <button class="btn small" data-whisper="${esc(p.name)}" data-whisper-id="${esc(p.owner_id)}">귓속말</button></div></li>`;
  const people = (s.people || []).length ? `<div class="mt-people">${(s.people || []).map(p => `<span class="mt-pp ${p.role}">${cardName(p.owner_id, p.name)}<small>Lv.${p.level} · ${p.role === 'mentee' ? '새내기' : '선배'} · ${fmt.num(p.n)}번</small></span>`).join('')}</div>` : '';
  return `${stats ? `<div class="mt-stats">${stats}</div>` : ''}
    <h3 class="sub-h">${icon('search', 14)} 선배 찾기</h3>
    ${post}
    ${(s.posts || []).length ? `<ul class="people cards mt-posts">${s.posts.map(card).join('')}</ul>` : `<p class="muted small mt-none">지금은 나와 레벨이 ${MENTOR.gap} 이상 차이 나는 글이 없습니다.</p>`}
    ${people ? `<h3 class="sub-h">함께한 이</h3>${people}` : ''}`;
}

function openShop(s, redraw) {
  const owned = new Set(s?.owned || []), merit = s?.me?.merit || 0;
  const m = openModal({ title: '챙김 쓰기', body: `<p class="muted small">남은 챙김 <b>${fmt.num(merit)}</b> · 모두 거래할 수 없고 능력치 효과는 없습니다.</p>
    <ul class="mt-shop">${(MENTOR.shop || []).map(x => {
      const have = x.kind !== 'item' && owned.has(x.key);
      return `<li class="${have ? 'have' : ''}"><div><b>${esc(x.name)}</b><small>${esc(x.desc || '')}</small></div>
        <span class="mt-price">${fmt.num(x.price)}</span>
        ${have ? '<span class="chip ok">가짐</span>' : `<button class="btn small ${merit >= x.price ? 'primary' : ''}" data-here="챙김 쓰기" data-mt-buy="${esc(x.key)}" ${merit >= x.price ? '' : 'disabled'}>바꾸기</button>`}</li>`;
    }).join('')}</ul>` });
  $$('[data-mt-buy]', m).forEach(b => b.onclick = () => guard(b, async () => {
    const x = (MENTOR.shop || []).find(v => v.key === b.dataset.mtBuy);
    if (!await ask(`${x.name}을(를) 챙김 ${x.price}으로 바꿀까요?`, { title: '챙김 쓰기', ok: '바꾸기' })) return;
    const r = await act('world_mentor_shop_buy', { p_key: x.key });
    closeModal(); await loadMentor(true); redraw?.(); return r;
  }));
}

export function bindMentorPanel(root, { pt, redraw } = {}) {
  const f = $('#mt-form', root);
  if (f) f.onsubmit = e => { e.preventDefault(); guard(f.querySelector('button[type=submit]'), async () => {
    const r = await act('world_mentor_post', { p_kind: f.kind.value, p_note: f.note.value, p_wants: $$('input[name=w]:checked', f).map(i => i.value) });
    await loadMentor(true); redraw?.(); return r;
  }, { success: '선배 찾기에 올렸습니다.' }); };
  const un = $('#mt-unpost', root);
  if (un) un.onclick = () => guard(un, async () => { const r = await act('world_mentor_unpost'); await loadMentor(true); redraw?.(); return r; }, { success: '' });
  $$('[data-mt-inv]', root).forEach(b => b.onclick = () => guard(b, async () => {
    if (!pt) await act('world_party_create', { p_party_name: `${store.character.character_name}의 동료`.slice(0, 20) });
    return act('world_party_invite', { p_invitee_id: b.dataset.mtInv });
  }));
  $$('.mt-posts [data-whisper]', root).forEach(b => b.onclick = () => openWhisper(b.dataset.whisper, b.dataset.whisperId));
  const sh = $('#mt-shop', root);
  if (sh) sh.onclick = () => openShop(snap, redraw);
}
