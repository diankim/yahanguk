import { rpc, act, esc, icon, guard, ask, $, $$, fmt, openModal, openLayer, toast } from './core.js';
import { LANTERN } from './rules.js';
import { helpQ } from './tips.js';
import { reportFlag } from './reportflag.js';
import { lanternSvg } from './lanternart.js';
import { foldOpen } from './views/common.js';

const TAB_KEY = 'yh-lantern-tab';
const TABS = [['water', '물가'], ['caught', '건진 등불'], ['sent', '띄운 등불'], ['book', '등불첩']];
const looks = () => LANTERN.shapes.flatMap(s => LANTERN.colors.map(c => [s.key, c.key]));
const lookKey = (s, c) => `${s}:${c}`;
const art = (x, size, o = {}) => lanternSvg(x.shape, x.color, { size, label: LANTERN.lookName(x.shape, x.color), delay: (Number(x.id) || 0) % 7 * 0.45, ...o });

export async function openLantern() {
  let tab = 'water';
  try { tab = sessionStorage.getItem(TAB_KEY) || 'water'; } catch {}
  if (!TABS.some(t => t[0] === tab)) tab = 'water';
  const m = openModal({ title: '등불 편지', wide: true, body: '<div class="lt-box"><p class="muted">물가를 살피는 중…</p></div>' });
  const box = $('.lt-box', m);
  const st = { v: null, tab, pick: null, draft: '' };
  const read = async () => {
    try { st.v = await rpc('world_lantern_view'); } catch (e) { box.innerHTML = `<p class="bad">${esc(e.message)}</p>`; return; }
    draw();
  };
  const setTab = t => { st.tab = t; try { sessionStorage.setItem(TAB_KEY, t); } catch {} draw(); };
  function draw() {
    if (!box.isConnected || !st.v) return;
    const v = st.v, open = new Set(v.book?.open || []);
    if (!st.pick || !open.has(lookKey(...st.pick))) { const s = LANTERN.start; st.pick = open.has(lookKey(s.shape, s.color)) ? [s.shape, s.color] : (v.book?.open?.[0] || 'round:red').split(':'); }
    const keep = $('.lt-body', box)?.scrollTop || 0, ta = $('[data-lt-text]', box);
    if (ta) st.draft = ta.value;
    box.innerHTML = `${headHtml(v)}
      <div class="segmented lt-tabs" style="--n:${TABS.length}">${TABS.map(([k, n]) => `<button type="button" data-lt-tab="${k}" class="${st.tab === k ? 'on' : ''}">${esc(n)}</button>`).join('')}</div>
      <div class="lt-body">${st.tab === 'caught' ? caughtTab(v) : st.tab === 'sent' ? sentTab(v) : st.tab === 'book' ? bookTab(v) : waterTab(v, st)}</div>`;
    $('.lt-body', box).scrollTop = keep;
    bind();
  }
  function bind() {
    const v = st.v;
    $$('[data-lt-tab]', box).forEach(b => b.onclick = () => setTab(b.dataset.ltTab));
    const ta = $('[data-lt-text]', box);
    if (ta) {
      ta.value = st.draft;
      const cnt = $('[data-lt-count]', box), sendB = $('[data-lt-send]', box);
      const upd = () => { st.draft = ta.value; const n = [...ta.value.trim()].length; cnt.textContent = `${n}/${LANTERN.body_max}`; cnt.classList.toggle('bad', n > LANTERN.body_max); if (sendB) sendB.dataset.empty = n ? '' : '1'; };
      ta.addEventListener('input', upd); upd();
    }
    $$('[data-lt-look]', box).forEach(b => b.onclick = () => { st.pick = b.dataset.ltLook.split(':'); draw(); });
    $$('[data-lt-cell]', box).forEach(b => b.onclick = () => { st.pick = b.dataset.ltCell.split(':'); setTab('water'); });
    const sendB = $('[data-lt-send]', box);
    if (sendB) sendB.onclick = () => {
      const body = st.draft.trim();
      if (!body) { toast('등불에 적을 글을 써 주세요.', 'error'); $('[data-lt-text]', box)?.focus(); return; }
      if ([...body].length > LANTERN.body_max) { toast(`등불에는 ${LANTERN.body_max}자까지 적을 수 있습니다.`, 'error'); return; }
      guard(sendB, async () => { const r = await rpc('world_lantern_send', { p_body: body, p_shape: st.pick[0], p_color: st.pick[1] }); st.draft = ''; await read(); return r; });
    };
    const catchB = $('[data-lt-catch]', box);
    if (catchB) catchB.onclick = () => guard(catchB, async () => {
      const r = await act('world_lantern_catch');
      await read();
      if (r?.lantern) showCaught(r);
      return null;
    });
    $$('[data-lt-reply]', box).forEach(b => b.onclick = () => { const x = (v.caught || []).find(c => String(c.id) === b.dataset.ltReply); if (x) openReply(x, v, read); });
    $$('[data-lt-hide]', box).forEach(b => b.onclick = async () => {
      if (!(await ask(LANTERN.hideAsk, { title: '등불 숨기기', ok: '숨기기' }))) return;
      guard(b, async () => { const r = await rpc('world_lantern_hide', { p_id: Number(b.dataset.ltHide) }); await read(); return r; });
    });
    $$('[data-lt-report]', box).forEach(b => b.onclick = () => openReport(Number(b.dataset.ltReport), read));
  }
  function showCaught(r) {
    const x = r.lantern;
    const l = openLayer({ title: '건진 등불', body: `<div class="lt-caught">
      <div class="lt-pond big">${art(x, 120)}</div>
      ${r.opened ? `<p class="lt-new">${icon('spark', 14)} 등불첩에 새 등이 열렸습니다 · ${esc(LANTERN.lookName(x.shape, x.color))}</p>` : ''}
      <p class="lt-text">${esc(x.body || '')}</p>
      <p class="muted small">${esc(x.from)}에서 띄운 등불 · ${esc(fmt.ago(x.at))}</p>
      <div class="btn-row"><button class="btn small" data-lt-go="caught">건진 등불 보기</button><button class="btn primary" data-close>닫기</button></div></div>` });
    $('[data-lt-go]', l).onclick = () => { l.close(); setTab('caught'); };
  }
  await read();
  return m;
}

function headHtml(v) {
  const d = v.day || {}, sendLeft = Math.max(0, (d.send_cap ?? LANTERN.day.send) - (d.sent || 0)), catchLeft = Math.max(0, (d.catch_cap ?? LANTERN.day.catch) - (d.caught || 0));
  return `<div class="lt-head">
    <div class="lt-where">${v.here ? `${icon('pin', 15)}<b>${esc(v.here.name)} 물가</b>` : `${icon('pin', 15)}<b class="muted">항구 물가가 아님</b>`}${helpQ(LANTERN.help, '등불 편지')}</div>
    <div class="lt-stats">
      <span class="chip" title="오늘 띄울 수 있는 남은 수 (한국 시각 0시에 다시 참)">띄우기 ${sendLeft}/${d.send_cap ?? LANTERN.day.send}</span>
      <span class="chip" title="오늘 건질 수 있는 남은 수 (한국 시각 0시에 다시 참)">건지기 ${catchLeft}/${d.catch_cap ?? LANTERN.day.catch}</span>
      <span class="chip">등불첩 ${v.book?.n || 0}/${v.book?.total || LANTERN.total()}</span>
    </div></div>`;
}

function lookPicker(v, pick) {
  const open = new Set(v.book?.open || []);
  return `<div class="lt-looks" role="radiogroup" aria-label="등 고르기">${looks().filter(([s, c]) => open.has(lookKey(s, c))).map(([s, c]) => `<button type="button" class="lt-look${pick[0] === s && pick[1] === c ? ' on' : ''}" data-lt-look="${s}:${c}" role="radio" aria-checked="${pick[0] === s && pick[1] === c}" title="${esc(LANTERN.lookName(s, c))}">${lanternSvg(s, c, { size: 30, water: false, still: true })}</button>`).join('')}</div>`;
}

function waterTab(v, st) {
  const d = v.day || {}, sendLeft = Math.max(0, (d.send_cap ?? 3) - (d.sent || 0)), catchLeft = Math.max(0, (d.catch_cap ?? 1) - (d.caught || 0));
  const here = !!v.here, [ps, pc] = st.pick;
  const pool = Math.min(5, Number(v.pool) || 0);
  const mo = window.matchMedia('(max-width: 640px)').matches, sk = mo ? `lt-send-m${catchLeft > 0 ? 1 : 0}` : 'lt-send', ck = mo ? `lt-catch-m${catchLeft > 0 ? 1 : 0}` : 'lt-catch';
  const sOpen = foldOpen(sk, !mo || catchLeft <= 0), cOpen = foldOpen(ck, !mo || catchLeft > 0);
  const send = `<details class="lt-card lt-fold" data-fold="${sk}" ${sOpen ? 'open' : ''}>
    <summary><h3>${icon('lantern', 16)} 등불 띄우기</h3><small class="muted">오늘 ${sendLeft}/${d.send_cap ?? 3}</small></summary>
    <div class="lt-pond">${lanternSvg(ps, pc, { size: 64, label: LANTERN.lookName(ps, pc) })}<small>${esc(LANTERN.lookName(ps, pc))}</small></div>
    ${lookPicker(v, st.pick)}
    <label class="field lt-write"><span>등불에 적을 글 <em class="lt-count" data-lt-count>0/${LANTERN.body_max}</em></span>
      <textarea data-lt-text rows="3" maxlength="${LANTERN.body_max}" placeholder="이름 모를 누군가에게 남길 말"></textarea></label>
    <p class="muted small">띄운 이의 이름은 끝까지 밝혀지지 않습니다. 등불은 다른 항구로 흘러갑니다.</p>
    <div class="btn-row"><button type="button" class="btn primary" data-lt-send data-here="등불 띄우기" ${!here || sendLeft <= 0 ? 'disabled' : ''}>${icon('lantern', 16)}<span>띄우기 · 오늘 ${sendLeft}번 남음</span></button></div>
    ${!here ? '' : sendLeft <= 0 ? '<p class="hint">오늘은 모두 띄웠습니다. 한국 시각 0시에 다시 띄울 수 있습니다.</p>' : ''}
  </details>`;
  const fish = `<details class="lt-card lt-fold" data-fold="${ck}" ${cOpen ? 'open' : ''}>
    <summary><h3>${icon('search', 16)} 등불 건지기</h3><small class="muted">오늘 ${catchLeft}/${d.catch_cap ?? 1}</small></summary>
    <div class="lt-pond wide">${pool ? Array.from({ length: pool }, (_, i) => `<span class="lt-far" style="--lt-d:${-i * 0.9}s;--lt-x:${8 + i * 18}%"></span>`).join('') : ''}<small>${here ? (v.pool ? `흘러온 등불 ${fmt.num(v.pool)}개가 떠 있습니다` : '흘러온 등불이 보이지 않습니다') : '—'}</small></div>
    <div class="btn-row"><button type="button" class="btn primary" data-lt-catch data-here="등불 건지기" ${!here || catchLeft <= 0 || !v.pool ? 'disabled' : ''}>${icon('search', 16)}<span>건지기 · 오늘 ${catchLeft}번 남음</span></button></div>
    ${!here ? '' : catchLeft <= 0 ? '<p class="hint">오늘은 이미 건졌습니다. 한국 시각 0시에 다시 건질 수 있습니다.</p>' : !v.pool ? `<p class="hint">${esc(LANTERN.noPool)}</p>` : ''}
  </details>`;
  return `${here ? '' : `<p class="notice-line">${icon('pin', 14)} ${esc(LANTERN.away)} <span class="muted small">항구: ${esc(LANTERN.portNames())}</span></p>`}<div class="lt-cols">${send}${fish}</div>`;
}

function caughtCard(x, v) {
  const here = !!v.here, d = v.day || {}, sendLeft = Math.max(0, (d.send_cap ?? 3) - (d.sent || 0));
  const full = (v.caught || []).find(c => c.id === x.id) || x;
  return `<article class="lt-item">
    ${full.removed ? '' : reportFlag(`data-lt-report="${full.id}"`, '등불 제보')}
    <div class="lt-item-art">${art(full, 44)}</div>
    <div class="lt-item-main">
      <p class="lt-text${full.removed ? ' muted' : ''}">${esc(full.removed ? LANTERN.removed : full.body || '')}</p>
      <p class="muted small">${esc(full.from || '')}에서 띄움${full.where ? ` · ${esc(full.where)}에서 건짐` : ''} · ${esc(fmt.ago(full.caught_at || full.at))}</p>
      ${full.my_reply ? `<div class="lt-reply mine">${lanternSvg(full.my_reply.shape, full.my_reply.color, { size: 22, water: false, still: true })}<span><b>내 답등</b> ${esc(full.my_reply.removed ? LANTERN.removed : full.my_reply.body || '')}</span></div>` : ''}
      ${`<div class="lt-acts">${full.can_reply ? `<button type="button" class="btn small" data-lt-reply="${full.id}" data-here="답등 띄우기" ${!here || sendLeft <= 0 ? 'disabled' : ''} title="${esc(!here ? '항구 물가에서 띄울 수 있습니다' : sendLeft <= 0 ? '오늘은 모두 띄웠습니다' : LANTERN.replyNote)}">${icon('lantern', 14)}<span>답등 띄우기</span></button>` : ''}<button type="button" class="btn small ghost" data-lt-hide="${full.id}">숨기기</button></div>`}
    </div></article>`;
}

function caughtTab(v) {
  const list = v.caught || [];
  return `<p class="muted small">${esc(`건진 등불 ${fmt.num(v.caught_n || 0)}개`)}${list.length < (v.caught_n || 0) ? ` · 최근 ${list.length}개를 보입니다` : ''} ${helpQ(LANTERN.reportTip, '제보와 숨기기')}</p>
    ${list.length ? `<div class="lt-list">${list.map(x => caughtCard(x, v)).join('')}</div>` : `<p class="muted">아직 건진 등불이 없습니다. 항구 물가에서 「건지기」를 눌러 보세요.</p>`}`;
}

function replyCard(r) {
  return `<article class="lt-item reply">
    ${r.removed ? '' : reportFlag(`data-lt-report="${r.id}"`, '답등 제보')}
    <div class="lt-item-art">${art(r, 36)}</div>
    <div class="lt-item-main">
      <p class="lt-text${r.removed ? ' muted' : ''}"><b class="lt-tag">답등</b> ${esc(r.removed ? LANTERN.removed : r.body || '')}</p>
      <p class="muted small">${esc(r.from || '')}에서 띄움 · ${esc(fmt.ago(r.at))}${r.to ? ` · 「${esc(r.to)}」에 닿음` : ''}</p>
      <div class="lt-acts"><button type="button" class="btn small ghost" data-lt-hide="${r.id}">숨기기</button></div>
    </div></article>`;
}

function sentTab(v) {
  const list = v.sent || [], reps = v.replies || [], used = new Set();
  const rows = list.map(x => {
    const rep = reps.find(r => r.to_id === x.id); if (rep) used.add(rep.id);
    const left = new Date(x.out_at) - Date.now();
    const tag = x.status === 'float' ? `<span class="chip accent">${esc(LANTERN.status.float)} · ${esc(LANTERN.left(left))}</span>` : `<span class="chip${x.status === 'caught' ? ' ok' : ''}">${esc(LANTERN.status[x.status] || '')}</span>`;
    return `<article class="lt-item${x.status === 'out' || x.status === 'removed' ? ' dim' : ''}">
      <div class="lt-item-art">${art(x, 44, { locked: x.status === 'removed', still: x.status !== 'float' })}</div>
      <div class="lt-item-main">
        <p class="lt-text${x.removed ? ' muted' : ''}">${esc(x.removed ? LANTERN.removed : x.body || '')}</p>
        <p class="muted small">${esc(x.from)}에서 띄움 · ${esc(fmt.ago(x.at))} ${tag}</p>
        ${rep ? replyCard(rep) : ''}
      </div></article>`;
  }).join('');
  const orphan = reps.filter(r => !used.has(r.id));
  return `<p class="muted small">최근 띄운 등불입니다. 아무도 건지지 않은 등불은 ${LANTERN.days}일 뒤 꺼집니다. 누가 건졌는지는 알 수 없습니다.</p>
    ${rows ? `<div class="lt-list">${rows}</div>` : '<p class="muted">아직 띄운 등불이 없습니다.</p>'}
    ${orphan.length ? `<h3 class="lt-sub">닿은 답등</h3><div class="lt-list">${orphan.map(replyCard).join('')}</div>` : ''}`;
}

function bookTab(v) {
  const open = new Set(v.book?.open || []), n = v.book?.n || 0, total = v.book?.total || LANTERN.total();
  const caught = v.caught_n || 0;
  const titles = (LANTERN.titles || []).map(t => { const cur = t.by === 'book' ? n : caught, done = cur >= t.n;
    return `<li class="${done ? 'done' : ''}"><span class="lt-t-name">${done ? icon('check', 14) : ''}「${esc(t.name)}」</span><span class="lt-t-bar"><i style="width:${Math.min(100, Math.round(cur / t.n * 100))}%"></i></span><small>${esc(t.by === 'book' ? '등불첩' : '건진 등불')} ${Math.min(cur, t.n)}/${t.n}</small></li>`; }).join('');
  return `<p class="muted small">등불첩 ${n}/${total} ${helpQ(LANTERN.bookHelp, '등불첩')}</p>
    <div class="lt-book" style="--cols:${LANTERN.colors.length}">
      <span></span>${LANTERN.colors.map(c => `<b class="lt-bh">${esc(c.name)}</b>`).join('')}
      ${LANTERN.shapes.map(s => `<b class="lt-bh row">${esc(s.name)}</b>${LANTERN.colors.map(c => { const k = lookKey(s.key, c.key), on = open.has(k);
        return on ? `<button type="button" class="lt-cell" data-lt-cell="${k}" title="${esc(`${LANTERN.lookName(s.key, c.key)} · 눌러서 띄울 등으로 고르기`)}">${lanternSvg(s.key, c.key, { size: 40, label: LANTERN.lookName(s.key, c.key), delay: (s.key.length + c.key.length) * 0.37 })}</button>`
          : `<span class="lt-cell locked" title="${esc(LANTERN.locked)}">${lanternSvg(s.key, c.key, { size: 40, locked: true, water: true })}<em>?</em></span>`; }).join('')}`).join('')}
    </div>
    <h3 class="lt-sub">칭호와 걸개</h3>
    <ul class="lt-titles">${titles}<li class="${v.hanger?.got ? 'done' : ''}"><span class="lt-t-name">${v.hanger?.got ? icon('check', 14) : ''}${esc(LANTERN.hangerLine(caught, v.hanger?.got))}</span></li></ul>`;
}

function openReply(x, v, after) {
  const open = new Set(v.book?.open || []);
  let pick = open.has(lookKey(x.shape, x.color)) ? [x.shape, x.color] : (v.book?.open?.[0] || 'round:red').split(':');
  const l = openLayer({ title: '답등 띄우기', body: `<div class="lt-replyform">
    <div class="lt-reply to">${lanternSvg(x.shape, x.color, { size: 26, water: false, still: true })}<span>${esc(x.body || '')}</span></div>
    <div class="lt-pond"><span data-lt-rp></span></div>
    <div data-lt-rlooks></div>
    <label class="field lt-write"><span>답등에 적을 글 <em class="lt-count" data-lt-rc>0/${LANTERN.body_max}</em></span><textarea rows="3" maxlength="${LANTERN.body_max}" data-lt-rt></textarea></label>
    <p class="muted small">${esc(LANTERN.replyNote)}</p>
    <div class="btn-row"><button type="button" class="btn primary" data-lt-rsend data-here="답등 띄우기">${icon('lantern', 16)}<span>답등 띄우기</span></button></div></div>` });
  const paint = () => {
    $('[data-lt-rp]', l).innerHTML = lanternSvg(pick[0], pick[1], { size: 56 });
    $('[data-lt-rlooks]', l).innerHTML = lookPicker(v, pick);
    $$('[data-lt-look]', l).forEach(b => b.onclick = () => { pick = b.dataset.ltLook.split(':'); paint(); });
  };
  paint();
  const ta = $('[data-lt-rt]', l), cnt = $('[data-lt-rc]', l);
  ta.addEventListener('input', () => { const n = [...ta.value.trim()].length; cnt.textContent = `${n}/${LANTERN.body_max}`; cnt.classList.toggle('bad', n > LANTERN.body_max); });
  const b = $('[data-lt-rsend]', l);
  b.onclick = () => {
    const body = ta.value.trim();
    if (!body) { toast('답등에 적을 글을 써 주세요.', 'error'); ta.focus(); return; }
    guard(b, async () => { const r = await rpc('world_lantern_reply', { p_id: x.id, p_body: body, p_shape: pick[0], p_color: pick[1] }); l.close(); await after(); return r; });
  };
}

function openReport(id, after) {
  const f = openLayer({ title: '등불 제보', body: `<form class="dr-rep"><label class="field"><span>까닭 (적지 않아도 됩니다, 200자)</span><textarea name="why" rows="3" maxlength="200"></textarea></label><p class="muted small">제보한 등불은 내 화면에서 숨겨집니다.</p><div class="btn-row"><button class="btn primary">보내기</button></div></form>` });
  $('form', f).onsubmit = ev => { ev.preventDefault(); guard($('button', f), async () => { const r = await rpc('world_lantern_report', { p_id: id, p_reason: $('textarea', f).value }); f.close(); await after(); return r; }); };
}
