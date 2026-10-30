// 패치노트: 서버 world_patch_notes(읽기 전용)를 최신순으로 보인다. #/patch/날짜 로 열면 그 노트를 펼치고 그 자리로 간다.
// 채팅에 「#패치노트」나 「#패치노트:4.0.0」라고 쓰면 이 화면으로 가는 링크가 된다(chat.js richText).
import { db, icon, esc, $, store, isGM, act, guard, openModal, closeModal } from '../core.js';
import { loading, errorBox } from './common.js';

let cache = null, cacheAt = 0;
const NOTICE = '0.0.0';
async function notes() {
  if (cache && Date.now() - cacheAt < 300000) return cache;
  const { data, error } = await db.from('world_patch_notes').select('note_id,title,body,created_at').order('created_at', { ascending: false }).limit(60);
  if (error) throw error;
  cache = data || []; cacheAt = Date.now(); return cache;
}
// 본문: 「## 」 제목, 「### 」 소제목, 「1. 」 번호 항목(묶음 안에서 이어지는 번호), 「· 」 항목, 빈 줄은 문단 나눔, 「**굵게**」
const inl = s => esc(s).replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
function bodyHtml(t) {
  const out = []; let list = null, kind = 'ul', start = 1;
  const flush = () => { if (list) { out.push(kind === 'ol' ? `<ol start="${start}">${list.join('')}</ol>` : `<ul>${list.join('')}</ul>`); list = null; } };
  String(t || '').split('\n').forEach(line => {
    const l = line.trim();
    if (!l) { flush(); return; }
    if (l.startsWith('### ')) { flush(); out.push(`<h4>${inl(l.slice(4))}</h4>`); return; }
    if (l.startsWith('## ')) { flush(); out.push(`<h3>${inl(l.slice(3))}</h3>`); return; }
    const num = l.match(/^(\d+)\.\s+(.*)$/);
    if (num) { if (!list || kind !== 'ol') { flush(); kind = 'ol'; start = Number(num[1]); list = []; } list.push(`<li>${inl(num[2])}</li>`); return; }
    if (/^[·\-]\s?/.test(l)) { if (list && kind !== 'ul') flush(); if (!list) { kind = 'ul'; list = []; } list.push(`<li>${inl(l.replace(/^[·\-]\s?/, ''))}</li>`); return; }
    flush(); out.push(`<p>${inl(l)}</p>`);
  });
  flush(); return out.join('');
}
export async function render(el, sub) {
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('scroll', 14)} 야행국 소식</p><h1>패치노트</h1></div>
    <div class="head-actions"><a class="btn small ghost" href="#/guide">${icon('help', 15)}<span>도움말</span></a></div></div><div id="patch-body">${loading()}</div>`;
  const box = $('#patch-body', el);
  try {
    const list = await notes();
    if (!list.length) { box.innerHTML = '<p class="muted">아직 올라온 패치노트가 없습니다.</p>'; return; }
    // 공지(note_id 0.0.0)는 늘 맨 위에 펼쳐 둔다. 내용은 그 한 줄만 고쳐 바꾼다
    const notice = list.find(n => n.note_id === NOTICE), rest = list.filter(n => n.note_id !== NOTICE);
    const gm = isGM(store.character?.owner_id);
    const open = sub && list.some(n => n.note_id === sub) ? sub : rest[0]?.note_id;
    box.innerHTML = `<div class="patch-list">${notice ? `
      <details class="panel patch notice-pin" id="pn-${NOTICE}" open>
        <summary><b>${esc(notice.title)}</b><small class="muted">공지</small></summary>
        <div class="patch-body">${bodyHtml(notice.body)}</div>
        ${gm ? `<div class="btn-row"><button class="btn small" id="notice-edit">${icon('scroll', 14)}<span>공지 고치기</span></button></div>` : ''}
      </details>` : gm ? `<div class="btn-row"><button class="btn small" id="notice-edit">${icon('scroll', 14)}<span>공지 쓰기</span></button></div>` : ''}${rest.map(n => `
      <details class="panel patch" id="pn-${esc(n.note_id)}" ${n.note_id === open ? 'open' : ''}>
        <summary><b>${esc(n.title)}</b><small class="muted">${esc(n.note_id)} · ${new Date(n.created_at).toLocaleDateString('ko-KR')}</small></summary>
        <div class="patch-body">${bodyHtml(n.body)}</div>
      </details>`).join('')}</div>`;
    if (sub) $(`#pn-${CSS.escape(open)}`, box)?.scrollIntoView({ block: 'start' });
    $('#notice-edit', box)?.addEventListener('click', () => editNotice(notice, () => render(el, sub)));
  } catch (e) { box.innerHTML = errorBox(e.message || '패치노트를 읽지 못했습니다.'); }
}
// 운영진만: 공지(0.0.0) 제목·본문 고치기. 서버 world_patch_notice_save가 world_staff인지 다시 검사한다
function editNotice(n, done) {
  const m = openModal({ title: '공지 고치기', wide: true, body: `<form class="form-grid" id="notice-form">
      <label class="field"><span>제목 (80자)</span><input name="title" maxlength="80" required value="${esc(n?.title || '[공지] ')}"></label>
      <label class="field"><span>본문 (6,000자) · 「## 」 제목 · 「· 」 항목 · 「**굵게**」 · 빈 줄로 문단</span><textarea name="body" rows="14" maxlength="6000" required>${esc(n?.body?.trim() || '')}</textarea></label>
      <p class="muted small">저장하면 모든 조사원의 패치노트 맨 위 공지가 바로 바뀝니다(이미 열어 둔 화면은 5분 안에).</p>
      <button class="btn primary" type="submit">${icon('check', 15)}<span>저장</span></button></form>` });
  const f = $('#notice-form', m);
  f.onsubmit = e => {
    e.preventDefault();
    guard(f.querySelector('[type=submit]'), async () => {
      const r = await act('world_patch_notice_save', { p_title: f.title.value, p_body: f.body.value });
      cache = null; closeModal(); done(); return r;
    });
  };
}
export function destroy() {}
