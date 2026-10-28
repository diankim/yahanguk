// 패치노트: 서버 world_patch_notes(읽기 전용)를 최신순으로 보인다. #/patch/날짜 로 열면 그 노트를 펼치고 그 자리로 간다.
// 채팅에 「#패치노트」나 「#패치노트:4.0.0」라고 쓰면 이 화면으로 가는 링크가 된다(chat.js richText).
import { db, icon, esc, $ } from '../core.js';
import { loading, errorBox } from './common.js';

let cache = null, cacheAt = 0;
async function notes() {
  if (cache && Date.now() - cacheAt < 300000) return cache;
  const { data, error } = await db.from('world_patch_notes').select('note_id,title,body,created_at').order('created_at', { ascending: false }).limit(60);
  if (error) throw error;
  cache = data || []; cacheAt = Date.now(); return cache;
}
// 본문: 「## 」 제목, 「### 」 소제목, 「1. 」 번호 항목(묶음 안에서 이어지는 번호), 「· 」 항목, 빈 줄은 문단 나눔
function bodyHtml(t) {
  const out = []; let list = null, kind = 'ul', start = 1;
  const flush = () => { if (list) { out.push(kind === 'ol' ? `<ol start="${start}">${list.join('')}</ol>` : `<ul>${list.join('')}</ul>`); list = null; } };
  String(t || '').split('\n').forEach(line => {
    const l = line.trim();
    if (!l) { flush(); return; }
    if (l.startsWith('### ')) { flush(); out.push(`<h4>${esc(l.slice(4))}</h4>`); return; }
    if (l.startsWith('## ')) { flush(); out.push(`<h3>${esc(l.slice(3))}</h3>`); return; }
    const num = l.match(/^(\d+)\.\s+(.*)$/);
    if (num) { if (!list || kind !== 'ol') { flush(); kind = 'ol'; start = Number(num[1]); list = []; } list.push(`<li>${esc(num[2])}</li>`); return; }
    if (/^[·\-]\s?/.test(l)) { if (list && kind !== 'ul') flush(); if (!list) { kind = 'ul'; list = []; } list.push(`<li>${esc(l.replace(/^[·\-]\s?/, ''))}</li>`); return; }
    flush(); out.push(`<p>${esc(l)}</p>`);
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
    const open = sub && list.some(n => n.note_id === sub) ? sub : list[0].note_id;
    box.innerHTML = `<div class="patch-list">${list.map(n => `
      <details class="panel patch" id="pn-${esc(n.note_id)}" ${n.note_id === open ? 'open' : ''}>
        <summary><b>${esc(n.title)}</b><small class="muted">${esc(n.note_id)} · ${new Date(n.created_at).toLocaleDateString('ko-KR')}</small></summary>
        <div class="patch-body">${bodyHtml(n.body)}</div>
      </details>`).join('')}</div>`;
    if (sub) $(`#pn-${CSS.escape(open)}`, box)?.scrollIntoView({ block: 'start' });
  } catch (e) { box.innerHTML = errorBox(e.message || '패치노트를 읽지 못했습니다.'); }
}
export function destroy() {}
