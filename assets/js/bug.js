import { store, rpc, act, esc, icon, guard, $, $$, fmt, openModal, isGM, ask } from './core.js';
import { picURL } from './housing/drawing.js';
import { designPic, fmtDesign } from './views/outfitdesign.js';

const CATS = [['bug', '오류'], ['screen', '화면'], ['balance', '밸런스'], ['idea', '제안'], ['review', '소감 및 기타'], ['other', '기타'], ['drawing', '그림 제보'], ['outfit', '도안 제보']];
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
    const mine = (r?.reports || []).filter(x => x.owner_id === store.user?.id && !x.hidden);
    if (r && r.reward_done === false && !r.is_gm) $('#bug-reward', body).hidden = false;
    $('.bug-mine', body).innerHTML = mine.length ? `<ul class="bug-list">${mine.map(x => `<li><div class="bug-top"><span class="chip">${esc(CATS.find(c => c[0] === x.category)?.[1] || '')}</span><b>${esc(x.title)}</b>
        <span class="chip ${x.status === 'fixed' ? 'ok' : x.status === 'checking' ? 'accent' : ''}">${esc(STATUS[x.status] || '')}</span><time>${fmt.time(x.created_at)}</time></div>
        <p class="bug-text">${esc(x.body)}</p>${x.reply ? `<p class="bug-reply"><b>운영진 답</b> ${esc(x.reply)}</p>` : ''}
        <div class="btn-row bug-del-row"><button class="btn small ghost" data-del="${x.report_id}" type="button">지우기</button></div></li>`).join('')}</ul>`
      : '<p class="muted small">아직 보낸 제보가 없습니다.</p>';
    $$('[data-del]', body).forEach(b => b.onclick = async () => {
      if (!await ask('이 제보를 내 목록에서 지울까요? 운영진에게 이미 전달된 내용은 처리 기록으로 남습니다.', { ok: '지우기' })) return;
      guard(b, async () => { const res = await act('world_bug_report_hide', { p_report: Number(b.dataset.del) }); send(body); return res; });
    });
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
    ${list.length ? `<ul class="bug-list">${list.map(x => `<li data-id="${x.report_id}"><div class="bug-top"><span class="chip">${esc(CATS.find(c => c[0] === x.category)?.[1] || '')}</span><b>${esc(x.title)}</b>${x.hidden ? '<span class="chip">보낸 이가 지움</span>' : ''}
        <span class="chip ${x.status === 'fixed' ? 'ok' : x.status === 'checking' ? 'accent' : x.status === 'open' ? 'warn' : ''}">${esc(STATUS[x.status])}</span><time>${fmt.time(x.created_at)}</time></div>
        <p class="muted small">${esc(x.character_name || '조사원')}${x.context?.hash ? ` · ${esc(x.context.hash)}` : ''}${x.context?.screen ? ` · ${esc(x.context.screen)}` : ''}${x.context?.location ? ` · ${esc(x.context.location)}` : ''}</p>
        <p class="bug-text">${esc(x.body)}</p>
        ${x.drawing ? `<div class="bug-drawing"><img class="dr-pic s${x.drawing.s}" src="${picURL(x.drawing, 4)}" alt=""><span>${esc(x.drawing.a)}${x.drawing.t ? ` 「${esc(x.drawing.t)}」` : ''} · 사본 ${x.drawing.copies}장${x.drawing.removed ? ' · <b>내림</b>' : ''}</span>${x.drawing.removed ? '' : `<button class="btn small danger" type="button" data-drop="${x.drawing.o}">그림 내리기</button>`}${x.context?.house ? `<a class="btn small ghost" href="#/house/${esc(x.context.house)}">별채 가 보기</a>` : ''}</div>` : ''}
        ${x.outfit ? `<div class="bug-drawing"><img class="od-pic" src="${designPic(x.outfit)}" alt=""><span>${esc(x.outfit.a)}${x.outfit.t ? ` 「${esc(x.outfit.t)}」` : ''} · ${fmtDesign(x.outfit)}${x.outfit.removed ? ' · <b>내림</b>' : ''}</span>${x.outfit.removed ? '' : `<button class="btn small danger" type="button" data-odrop="${x.outfit.o}">도안 내리기</button>`}</div>` : ''}
        ${x.context && Object.keys(x.context).length ? `<details class="fold"><summary>기기·오류 기록</summary><pre class="bug-ctx">${esc(JSON.stringify(x.context, null, 2))}</pre></details>` : ''}
        ${x.reply ? `<p class="bug-reply"><b>보낸 답</b> ${esc(x.reply)}</p>` : ''}
        <form class="bug-answer"><textarea name="reply" rows="2" maxlength="2000" placeholder="답 (비워 두면 상태만 바꿉니다)"></textarea>
          <div class="btn-row"><select name="status" aria-label="처리 상태">${Object.entries(STATUS).map(([k, l]) => `<option value="${k}" ${k === (x.status === 'open' ? 'checking' : x.status) ? 'selected' : ''}>${l}</option>`).join('')}</select>
          <button class="btn small primary" type="submit">처리</button></div></form></li>`).join('')}</ul>` : '<p class="muted">해당하는 제보가 없습니다.</p>'}`;
  $$('[data-f]', body).forEach(b => b.onclick = () => { filter = b.dataset.f; inbox(body); });
  $$('[data-drop]', body).forEach(b => b.onclick = async () => {
    const f = b.closest('[data-id]').querySelector('.bug-answer');
    if (!await ask('이 그림과 모든 사본을 내릴까요? 그린 사람에게 알림이 가고, 아래 답 칸에 적은 글이 까닭으로 함께 갑니다.', { title: '그림 내리기', ok: '내리기', danger: true })) return;
    guard(b, async () => { const r = await rpc('world_drawing_remove', { p_origin: Number(b.dataset.drop), p_reason: f?.reply.value.trim() || '' }); inbox(body); return r; });
  });
  $$('[data-odrop]', body).forEach(b => b.onclick = async () => {
    const f = b.closest('[data-id]').querySelector('.bug-answer');
    if (!await ask('이 도안과 모든 사본을 내릴까요? 그 도안으로 지은 옷은 모두 원래 옷으로 보이고, 그린 사람에게 알림이 갑니다. 아래 답 칸에 적은 글이 까닭으로 함께 갑니다.', { title: '도안 내리기', ok: '내리기', danger: true })) return;
    guard(b, async () => { const r = await rpc('world_outfit_design_remove', { p_grp: Number(b.dataset.odrop), p_reason: f?.reply.value.trim() || '' }); inbox(body); return r; });
  });
  $$('.bug-answer', body).forEach(f => f.onsubmit = e => {
    e.preventDefault();
    const id = Number(f.closest('[data-id]').dataset.id);
    guard(f.querySelector('button'), async () => { const res = await act('world_bug_report_reply', { p_report: id, p_reply: f.reply.value.trim(), p_status: f.status.value }); inbox(body); return res; });
  });
}
