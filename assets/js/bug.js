// 버그·문의 제보: 헤더의 깃발 단추로 여는 창. 조사원은 GM에게 바로 보내고 자기 제보의 처리 상태·답을 보며,
// GM(world_staff)은 같은 창의 「받은 제보」에서 모든 제보를 보고 상태를 바꾸고 답한다(서버 world_bug_report_*).
// 보낼 때 지금 화면 위치·화면 크기·기기·최근 오류를 함께 붙일 수 있다(전·가방 같은 게임 값은 붙이지 않는다).
import { store, rpc, act, esc, icon, guard, $, $$, fmt, openModal, isGM } from './core.js';

const CATS = [['bug', '오류'], ['screen', '화면'], ['balance', '밸런스'], ['idea', '제안'], ['review', '소감 및 기타'], ['other', '기타']];
// 보낼 때 고르는 분류는 넷(모바일 한 줄). 화면·기타는 옛 제보 표시용으로만 남긴다(화면 오류는 「오류」, 그 밖은 「소감 및 기타」).
const PICK = [['bug', '오류'], ['balance', '밸런스'], ['idea', '제안'], ['review', '소감 및 기타']];
const STATUS = { open: '접수', checking: '확인 중', fixed: '고침', closed: '닫음' };
const errors = [];
const keep = msg => { errors.push({ at: new Date().toISOString(), msg: String(msg || '').slice(0, 300) }); if (errors.length > 5) errors.shift(); };
window.addEventListener('error', e => keep(e.message || e.error));
window.addEventListener('unhandledrejection', e => keep(e.reason?.message || e.reason));

function context() {
  return { hash: location.hash || '#/home', screen: `${innerWidth}×${innerHeight}`, dpr: devicePixelRatio, ua: navigator.userAgent.slice(0, 200),
    location: store.character?.location || '', level: store.character?.level || null, errors: [...errors], at: new Date().toISOString() };
}
const draftKey = 'yh-bug-draft';
const loadDraft = () => { try { return JSON.parse(sessionStorage.getItem(draftKey) || '{}') || {}; } catch { return {}; } };
const saveDraft = d => { try { sessionStorage.setItem(draftKey, JSON.stringify(d)); } catch {} };

export function mountBug(btn) { if (btn) btn.onclick = () => openBug(); }
window.addEventListener('yh-open-bug', e => openBug(e.detail?.tab));

export async function openBug(tab) {
  const gm = isGM(store.user?.id);
  const m = openModal({ title: '제보·소감', wide: true, body: `<div class="bug-box">
    ${gm ? `<div class="segmented bug-tabs" style="--n:2"><button data-bt="send">보내기</button><button data-bt="inbox">받은 제보</button></div>` : ''}
    <div class="bug-body"></div></div>` });
  const box = $('.bug-box', m), body = $('.bug-body', box);
  const show = t => { $$('[data-bt]', box).forEach(b => b.classList.toggle('on', b.dataset.bt === t)); (t === 'inbox' ? inbox : send)(body); };
  $$('[data-bt]', box).forEach(b => b.onclick = () => show(b.dataset.bt));
  show(gm && tab === 'inbox' ? 'inbox' : 'send');
}

async function send(body) {
  const d = loadDraft(), cat = PICK.some(c => c[0] === d.cat) ? d.cat : 'bug';
  body.innerHTML = `
    <p class="desc">게임을 하다 이상한 점·바라는 점은 물론, 오류가 아니어도 <b>게임을 하며 느낀 점(소감)</b>을 운영진(GM)에게 편하게 보내 주세요. 답이 오면 알림으로 알려 드립니다.</p>
    <p class="notice-line small" id="bug-reward" hidden>${icon('spark', 14)}<span>처음 보내 주시면 한 번 <b>노정 건량 2개·청심환 2개</b>를 드립니다.</span></p>
    <form class="bug-form" autocomplete="off">
      <div class="chip-pick bug-cat" role="radiogroup" aria-label="분류">${PICK.map(([k, l]) => `<button type="button" data-cat="${k}" class="${k === cat ? 'on' : ''}" role="radio" aria-checked="${k === cat}">${l}</button>`).join('')}</div>
      <label class="field"><span>제목 (2~60자)</span><input name="title" maxlength="60" value="${esc(d.title || '')}" placeholder="예: 모바일에서 지도 출발 단추가 눌리지 않아요"></label>
      <label class="field"><span>내용 (5~2000자)</span><textarea name="body" rows="6" maxlength="2000" placeholder="언제·어디서·무엇을 했을 때 어떻게 되었는지 적어 주시면 빨리 고칠 수 있습니다.">${esc(d.body || '')}</textarea></label>
      <label class="check"><input type="checkbox" name="ctx" ${d.ctx === false ? '' : 'checked'}><span>지금 화면 정보 함께 보내기 <small class="muted">(화면 위치·크기·기기·최근 오류 ${errors.length}건 · 전·가방 같은 게임 값은 보내지 않습니다)</small></span></label>
      <button class="btn primary" type="submit">${icon('flag', 16)}<span>GM에게 보내기</span></button>
    </form>
    <h3 class="sub-h">내 제보</h3><div class="bug-mine">${'<p class="muted small">불러오는 중…</p>'}</div>`;
  const f = $('.bug-form', body); let c = cat;
  const save = () => saveDraft({ cat: c, title: f.title.value, body: f.body.value, ctx: f.ctx.checked });
  $$('[data-cat]', f).forEach(b => b.onclick = () => { c = b.dataset.cat; $$('[data-cat]', f).forEach(x => { x.classList.toggle('on', x === b); x.setAttribute('aria-checked', x === b); }); save(); });
  f.addEventListener('input', save);
  f.onsubmit = e => {
    e.preventDefault();
    const b = f.querySelector('button[type=submit]');
    guard(b, async () => {
      const r = await act('world_bug_report_submit', { p_category: c, p_title: f.title.value.trim(), p_body: f.body.value.trim(), p_context: f.ctx.checked ? context() : {} });
      try { sessionStorage.removeItem(draftKey); } catch {}
      send(body); return r;
    });
  };
  try {
    const r = await rpc('world_bug_report_list', { p_status: null });
    const mine = (r?.reports || []).filter(x => x.owner_id === store.user?.id);
    if (r && r.reward_done === false && !r.is_gm) $('#bug-reward', body).hidden = false;
    $('.bug-mine', body).innerHTML = mine.length ? `<ul class="bug-list">${mine.map(x => `<li><div class="bug-top"><span class="chip">${esc(CATS.find(c => c[0] === x.category)?.[1] || '')}</span><b>${esc(x.title)}</b>
        <span class="chip ${x.status === 'fixed' ? 'ok' : x.status === 'checking' ? 'accent' : ''}">${esc(STATUS[x.status] || '')}</span><time>${fmt.time(x.created_at)}</time></div>
        <p class="bug-text">${esc(x.body)}</p>${x.reply ? `<p class="bug-reply"><b>운영진 답</b> ${esc(x.reply)}</p>` : ''}</li>`).join('')}</ul>`
      : '<p class="muted small">아직 보낸 제보가 없습니다.</p>';
  } catch (e) { $('.bug-mine', body).innerHTML = `<p class="bad small">${esc(e.message)}</p>`; }
}

let filter = 'active';
async function inbox(body) {
  body.innerHTML = '<p class="muted small">불러오는 중…</p>';
  let r; try { r = await rpc('world_bug_report_list', { p_status: null }); } catch (e) { body.innerHTML = `<p class="bad">${esc(e.message)}</p>`; return; }
  const all = r?.reports || [];
  const list = all.filter(x => filter === 'all' || (filter === 'active' ? ['open', 'checking'].includes(x.status) : x.status === filter));
  body.innerHTML = `
    <div class="chip-pick bug-filter">${[['active', `처리할 것 ${all.filter(x => ['open', 'checking'].includes(x.status)).length}`], ['fixed', '고침'], ['closed', '닫음'], ['all', '전체']].map(([k, l]) => `<button data-f="${k}" class="${k === filter ? 'on' : ''}">${l}</button>`).join('')}</div>
    ${list.length ? `<ul class="bug-list">${list.map(x => `<li data-id="${x.report_id}"><div class="bug-top"><span class="chip">${esc(CATS.find(c => c[0] === x.category)?.[1] || '')}</span><b>${esc(x.title)}</b>
        <span class="chip ${x.status === 'fixed' ? 'ok' : x.status === 'checking' ? 'accent' : x.status === 'open' ? 'warn' : ''}">${esc(STATUS[x.status])}</span><time>${fmt.time(x.created_at)}</time></div>
        <p class="muted small">${esc(x.character_name || '조사원')}${x.context?.hash ? ` · ${esc(x.context.hash)}` : ''}${x.context?.screen ? ` · ${esc(x.context.screen)}` : ''}${x.context?.location ? ` · ${esc(x.context.location)}` : ''}</p>
        <p class="bug-text">${esc(x.body)}</p>
        ${x.context && Object.keys(x.context).length ? `<details class="fold"><summary>기기·오류 기록</summary><pre class="bug-ctx">${esc(JSON.stringify(x.context, null, 2))}</pre></details>` : ''}
        ${x.reply ? `<p class="bug-reply"><b>보낸 답</b> ${esc(x.reply)}</p>` : ''}
        <form class="bug-answer"><textarea name="reply" rows="2" maxlength="2000" placeholder="답 (비워 두면 상태만 바꿉니다)"></textarea>
          <div class="btn-row"><select name="status" aria-label="처리 상태">${Object.entries(STATUS).map(([k, l]) => `<option value="${k}" ${k === (x.status === 'open' ? 'checking' : x.status) ? 'selected' : ''}>${l}</option>`).join('')}</select>
          <button class="btn small primary" type="submit">처리</button></div></form></li>`).join('')}</ul>` : '<p class="muted">해당하는 제보가 없습니다.</p>'}`;
  $$('[data-f]', body).forEach(b => b.onclick = () => { filter = b.dataset.f; inbox(body); });
  $$('.bug-answer', body).forEach(f => f.onsubmit = e => {
    e.preventDefault();
    const id = Number(f.closest('[data-id]').dataset.id);
    guard(f.querySelector('button'), async () => { const res = await act('world_bug_report_reply', { p_report: id, p_reply: f.reply.value.trim(), p_status: f.status.value }); inbox(body); return res; });
  });
}
