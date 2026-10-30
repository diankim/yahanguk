// 헤더 기능: 테마(프리셋·흑백·직접 설정) · 프로필 보기 · 알림. 고치는 화면은 설정 페이지(views/settings.js)에 있다.
import { gmBadge, ask, db, store, rpc, act, esc, icon, h, $, $$, openModal, closeModal, toast, guard, fmt, emblem, profileOf, loadCharacter, nameOf, JOBS, on, emit, midBattle, throttle } from './core.js';
import { patternLayer, sealMark } from './cosmetics.js';
import { logout } from './session.js';
export { initSound, playSfx } from './sound.js';

// 테마는 의존성 없는 theme.js에 있다(점검 페이지도 같은 테마를 쓴다).
export { THEMES, deriveCustom, readCustom, themeOf, applyTheme, savedThemeId, applySavedTheme, themeCard, FONT_SIZES, savedFontSize, applyFontSize } from './theme.js';

/* ── 프로필 보기(고치기는 설정 페이지에서) ─────────────────── */
export function openProfile() {
  const c = store.character || {}, p = profileOf(c.owner_id, c.profile);
  openModal({ title: '프로필', body: `<div class="profile-view">
    <div class="profile-card">${patternLayer(c.profile?.pattern)}<div class="pc-emblem">${emblem(c.owner_id, c.profile, 80)}</div>
      <div><h3>${esc(c.character_name || '')}${sealMark(c.profile?.seal)}${gmBadge(c.owner_id)}</h3>${c.profile?.title_name ? `<p class="title-badge">「${esc(c.profile.title_name)}」</p>` : ''}
        <p>${esc(nameOf(c.job_key))} · ${esc(nameOf(c.faction_key))}${c.major_faction_id ? ' · ' + esc(nameOf(c.major_faction_id)) : ''}</p>
        <p class="muted small">Lv.${c.level || 1} · ${esc(JOBS[c.job_key]?.trait || '')} · ${esc(c.location || '')}</p></div></div>
    <p class="bio">${p.bio ? esc(p.bio) : '<span class="muted">한 줄 소개가 없습니다.</span>'}</p>
    <div class="btn-row"><a class="btn primary" href="#/settings/profile" data-close>${icon('gear', 16)}<span>프로필 수정</span></a>
      <a class="btn" href="#/char/titles" data-close>${icon('spark', 16)}<span>칭호 보기</span></a>
      <button class="btn ghost" id="pf-logout">${icon('logout', 16)}<span>로그아웃</span></button></div>
    <p class="muted small">이름·직업·소속은 캐릭터를 만들 때 정해지며 바꿀 수 없습니다.</p></div>` });
  document.getElementById('pf-logout').onclick = async () => { if (await ask('로그아웃할까요?', { title: '로그아웃', ok: '로그아웃' })) { closeModal(); logout(); } };
}

// 사진 자르기: 정사각형 안에서 끌어 옮기고 확대해 128px WebP로 만든다. 저장은 부르는 쪽이 한다.
export function bindCrop(root, onReady) {
  const cv = $('#crop-cv', root), g = cv.getContext('2d'), zoom = $('#av-zoom', root);
  let img = null, k = 1, ox = 0, oy = 0, drag = null;
  const S = cv.width;
  const paint = () => {
    g.fillStyle = '#111'; g.fillRect(0, 0, S, S);
    if (!img) return;
    const base = S / Math.min(img.width, img.height), w = img.width * base * k, hgt = img.height * base * k;
    ox = Math.min(0, Math.max(S - w, ox)); oy = Math.min(0, Math.max(S - hgt, oy));
    g.drawImage(img, ox, oy, w, hgt);
  };
  $('#av-file', root).onchange = e => {
    const f = e.target.files?.[0]; if (!f) return;
    if (f.size > 15 * 1024 * 1024) return toast('15MB 이하의 사진을 고르세요.', 'error');
    const url = URL.createObjectURL(f), im = new Image();
    im.onload = () => { img = im; k = 1; zoom.value = 1; zoom.disabled = false;
      const base = S / Math.min(im.width, im.height); ox = (S - im.width * base) / 2; oy = (S - im.height * base) / 2; paint(); URL.revokeObjectURL(url); onReady?.(); };
    im.onerror = () => toast('사진을 읽지 못했습니다.', 'error');
    im.src = url;
  };
  zoom.oninput = () => { const c0 = (S / 2 - ox) / k, c1 = (S / 2 - oy) / k; k = Number(zoom.value); ox = S / 2 - c0 * k; oy = S / 2 - c1 * k; paint(); };
  cv.onpointerdown = e => { if (!img) return; cv.setPointerCapture(e.pointerId); drag = { x: e.clientX, y: e.clientY }; };
  cv.onpointermove = e => { if (!drag) return; const r = S / cv.getBoundingClientRect().width; ox += (e.clientX - drag.x) * r; oy += (e.clientY - drag.y) * r; drag = { x: e.clientX, y: e.clientY }; paint(); };
  cv.onpointerup = cv.onpointercancel = () => { drag = null; };
  paint();
  return {
    has: () => !!img,
    dataUrl() {
      const out = document.createElement('canvas'); out.width = out.height = 128;
      out.getContext('2d').drawImage(cv, 0, 0, 128, 128);
      const d = out.toDataURL('image/webp', 0.82);
      return d.startsWith('data:image/webp') ? d : out.toDataURL('image/jpeg', 0.82);
    },
  };
}

/* ── 알림 ────────────────────────────────────────────────── */
// 목록 단추는 알림 id로 찾는다(확인해 빠진 뒤 순번이 밀려 엉뚱한 알림을 찾던 문제).
let notes = [], bell, notesLive = false;
const shown = new Set(); // 이미 띄운 알림(실시간과 다시 읽기에서 두 번 띄우지 않게)
const POP_KINDS = new Set(['party_exp_offer', 'party_expedition', 'party_invite', 'expedition_done', 'bag_overflow', 'trade_offer', 'friend_request', 'circle_invite', 'bond_request', 'bond_broken', 'bond_accepted', 'spar_request', 'spar_result', 'raid_invite', 'gw_invite', 'pfight_invite', 'tourney_partner', 'bond_wedding_ask', 'wedding_invite']);
export function mountNotifications(btn) {
  bell = btn;
  bell.onclick = openNotifications;
  loadNotes(true);
  try {
    db.channel('yh-notes').on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'world_notifications' }, p => {
      const n = p.new; if (!n?.id || n.user_id !== store.user?.id || notes.some(x => x.id === n.id)) return;
      shown.add(n.id); notes.unshift(n); drawDot();
      if (/^party_exp_(departed|result)$/.test(n.kind)) loadCharacter().catch(() => {}).then(() => emit('changed', { name: 'world_party_expedition_notice' }));
      if (POP_KINDS.has(n.kind)) notePop(n); else toast(n.title || '새 알림', 'info');
    }).subscribe(status => {
      const was = notesLive; notesLive = status === 'SUBSCRIBED';
      if (notesLive && !was && !first) loadNotes(); // 끊겼다 다시 붙으면 그 사이 알림을 채운다
      first = false;
    });
  } catch {}
  // 실시간 연결이 놓쳐도 늦지 않게 다시 읽는다. 실시간이 살아 있으면 예비로만(행동 뒤는 건너뛰고, 화면 복귀는 1분 넘게 비웠을 때, 주기는 5분),
  // 끊겼으면 지금처럼(행동 뒤 15초에 한 번까지·화면 복귀·1분마다).
  let first = true, hiddenAt = 0, lastRead = Date.now();
  const read = () => { lastRead = Date.now(); return loadNotes(); };
  const soon = throttle(read, 15000);
  on('changed', ev => { if (!midBattle(ev) && !notesLive) setTimeout(soon, 600); });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) { hiddenAt = Date.now(); return; }
    if (!notesLive || Date.now() - hiddenAt > 60000) read();
  });
  setInterval(() => { if (!document.hidden && (!notesLive || Date.now() - lastRead > 300000)) read(); }, 60000);
  // 서버 알림이 아닌 화면 안 알림(원정 귀환 등)
  window.addEventListener('yh-local-note', e => { if (e.detail) notePop(e.detail); });
}
async function loadNotes(first) {
  try {
    const { data, error } = await db.from('world_notifications').select('*').is('read_at', null).order('created_at', { ascending: false }).limit(30);
    if (error) throw error;
    const seen = new Set(notes.map(n => n.id));
    const fresh = (data || []).filter(n => n?.id != null);
    // 실시간으로 받지 못한 새 알림은 지금 알린다(처음 읽을 때는 아래에서 따로)
    if (!first) fresh.filter(n => !seen.has(n.id) && !shown.has(n.id)).slice(0, 3).forEach(n => { shown.add(n.id); if (POP_KINDS.has(n.kind)) notePop(n); else toast(n.title || '새 알림', 'info'); });
    fresh.forEach(n => shown.add(n.id));
    notes = fresh; drawDot();
    // 접속하지 않은 사이 온 초대·원정 완료도 들어오면 바로 띄운다.
    if (first) notes.filter(n => POP_KINDS.has(n.kind)).slice(0, 2).forEach(notePop);
  } catch {}
}
function drawDot() { const d = bell?.querySelector('.dot'); if (d) { d.hidden = !notes.length; d.textContent = notes.length > 9 ? '9+' : String(notes.length || ''); } }
const byId = id => notes.find(n => String(n.id) === String(id));
async function markRead(n) {
  if (!n) return;
  try { await rpc('world_mark_notification_read', { p_id: n.id }); } catch {}
  notes = notes.filter(x => x.id !== n.id); drawDot();
}
// 알림 하나에 붙는 행동 단추
function noteActs(n) {
  if (n.kind === 'rescue_request' && n.payload?.target_id) return `<button class="btn primary small" data-rescue="${esc(n.id)}">구조</button>`;
  if (n.kind === 'party_invite' && n.payload?.invite_id) return `<button class="btn primary small" data-invite="${esc(n.id)}" data-acc="1">수락</button><button class="btn small" data-invite="${esc(n.id)}" data-acc="0">거절</button>`;
  if (n.kind === 'trade_offer' && n.payload?.trade_id) return `<button class="btn primary small" data-trade="${esc(n.id)}" data-acc="1">수락</button><button class="btn small" data-trade="${esc(n.id)}" data-acc="0">거절</button>`;
  if (n.kind === 'friend_request' && n.payload?.from_id) return `<button class="btn primary small" data-friend="${esc(n.id)}" data-acc="1">수락</button><button class="btn small" data-friend="${esc(n.id)}" data-acc="0">거절</button>`;
  if (n.kind === 'circle_invite' && n.payload?.invite_id) return `<button class="btn primary small" data-circle="${esc(n.id)}" data-acc="1">수락</button><button class="btn small" data-circle="${esc(n.id)}" data-acc="0">거절</button>`;
  if (n.kind === 'bond_request' && n.payload?.request_id) return `<button class="btn primary small" data-bondn="${esc(n.id)}" data-acc="1">받기</button><button class="btn small" data-bondn="${esc(n.id)}" data-acc="0">돌려보내기</button>`;
  if (n.kind === 'spar_request' && n.payload?.spar_id) return `<button class="btn primary small" data-spar="${esc(n.id)}" data-acc="1">겨루기</button><button class="btn small" data-spar="${esc(n.id)}" data-acc="0">사양</button>`;
  if (n.kind === 'spar_result' && n.payload?.spar_id && /비무에서/.test(n.title || '')) return `<button class="btn primary small" data-sparv="${esc(n.id)}">결과 보기</button>`;
  if (n.kind === 'bug_report' || n.kind === 'bug_reply') return `<button class="btn primary small" data-bug="${esc(n.id)}">보기</button>`;
  if (n.kind === 'bag_overflow') return `<button class="btn primary small" data-ov="${esc(n.id)}">정리하기</button>`;
  if (n.kind === 'party_exp_offer' && n.payload?.offer_id) return `<button class="btn primary small" data-pexo="${esc(n.id)}" data-acc="1">함께 가기</button><button class="btn small" data-pexo="${esc(n.id)}" data-acc="0">빠지기</button>`;
  if (n.kind === 'party_expedition' && n.payload?.node_id) return `<button class="btn primary small" data-pexp="${esc(n.id)}">함께 가기</button>`;
  if (n.kind === 'gw_invite' && n.payload?.fight_id) return `<button class="btn primary small" data-gw="${esc(n.id)}">합류</button>`;
  if (n.kind === 'bond_wedding_ask' && n.payload?.wed_id) return `<button class="btn primary small" data-wed="${esc(n.id)}" data-acc="1">혼례 받기</button><button class="btn small" data-wed="${esc(n.id)}" data-acc="0">다음에</button>`;
  if ((n.kind === 'wedding_invite' || n.kind === 'bond_wedding') && n.payload?.wed_id) return `<button class="btn primary small" data-wedv="${esc(n.id)}">혼례 보기</button>`;
  if (n.kind.startsWith('tourney_') && n.payload?.t_id) return `<button class="btn primary small" data-tn="${esc(n.id)}">비무 방</button>`;
  if ((n.kind === 'pfight_invite' || n.kind === 'pfight_join') && n.payload?.fight_id) return `<button class="btn primary small" data-pfight="${esc(n.id)}" data-join="${n.kind === 'pfight_invite' ? 1 : ''}">${n.kind === 'pfight_invite' ? '합류 · 탐색력 1' : '보기'}</button>`;
  if (n.kind === 'housing_item') return `<button class="btn primary small" data-house="${esc(n.id)}">별채 보기</button>`;
  if (n.kind === 'letter' && n.payload?.letter_id) return `<button class="btn primary small" data-letter="${esc(n.id)}">서신함</button>`;
  if (n.kind === 'friend_down' && n.payload?.location) return `<button class="btn primary small" data-fdown="${esc(n.id)}">지도에서 보기</button>`;
  if (n.kind === 'raid_invite' && n.payload?.raid_id) return `<button class="btn primary small" data-raid="${esc(n.id)}">합류</button>`;
  if ((n.kind === 'raid_notice' || n.kind === 'raid_result') && n.payload?.raid_id) return `<button class="btn primary small" data-raid="${esc(n.id)}">보기</button>`;
  if (n.kind === 'expedition_done') return `<a class="btn primary small" href="#/home" data-go-exp="${esc(n.id)}">결과 보기</a>`;
  return '';
}
async function runAct(btn) {
  if (btn.dataset.ov) { const o = byId(btn.dataset.ov); if (o) await markRead(o); closeModal(); (await import('./overflow.js')).openOverflow(); return true; }
  const n = byId(btn.dataset.rescue || btn.dataset.invite || btn.dataset.trade || btn.dataset.friend || btn.dataset.circle || btn.dataset.bondn || btn.dataset.bug || btn.dataset.goExp || btn.dataset.spar || btn.dataset.sparv || btn.dataset.pexp || btn.dataset.pexo || btn.dataset.raid || btn.dataset.gw || btn.dataset.pfight || btn.dataset.tn || btn.dataset.wed || btn.dataset.wedv || btn.dataset.fdown || btn.dataset.letter || btn.dataset.house);
  if (!n) { if (btn.dataset.goExp) { window.dispatchEvent(new CustomEvent('yh-open-expedition')); return true; } return false; }
  if (btn.dataset.rescue) { await guard(btn, () => act('world_rescue_character', { p_target: n.payload.target_id })); return true; }
  if (btn.dataset.invite) {
    await guard(btn, async () => { try { return await act('world_party_respond', { p_invite_id: n.payload.invite_id, p_accept: btn.dataset.acc === '1' }); } finally { await markRead(n); } });
    return true;
  }
  if (btn.dataset.trade) {
    if (btn.dataset.acc === '1' && !(await ask('이 거래를 받아들일까요? 바로 맞바꿉니다.', { title: '거래 수락', ok: '받아들이기' }))) return false;
    await guard(btn, async () => { try { return await act('world_trade_direct_respond', { p_trade_id: n.payload.trade_id, p_accept: btn.dataset.acc === '1' }); } finally { await markRead(n); } });
    return true;
  }
  if (btn.dataset.friend) {
    await guard(btn, async () => { try { return await act('world_friend_respond', { p_from: n.payload.from_id, p_accept: btn.dataset.acc === '1' }); } finally { await markRead(n); } });
    return true;
  }
  if (btn.dataset.circle) {
    await guard(btn, async () => { try { return await act('world_circle_respond', { p_invite: n.payload.invite_id, p_accept: btn.dataset.acc === '1' }); } finally { await markRead(n); (await import('./circles.js')).loadCircles(true); } });
    return true;
  }
  if (btn.dataset.bondn) {
    await guard(btn, async () => { try { return await act('world_bond_respond', { p_request: n.payload.request_id, p_accept: btn.dataset.acc === '1' }); } finally { await markRead(n); (await import('./bond.js')).loadBond(true); } });
    return true;
  }
  if (btn.dataset.spar) {
    let r = null;
    await guard(btn, async () => { try { r = await act('world_spar_respond', { p_spar: n.payload.spar_id, p_accept: btn.dataset.acc === '1' }); return r?.result ? null : r; } finally { await markRead(n); } });
    if (r?.result) (await import('./spar.js')).openSparResult(r.result);
    return true;
  }
  if (btn.dataset.sparv) { await markRead(n); await guard(btn, async () => { await (await import('./spar.js')).viewSpar(n.payload.spar_id); return null; }); return true; }
  if (btn.dataset.bug) { await markRead(n); closeModal(); window.dispatchEvent(new CustomEvent('yh-open-bug', { detail: { tab: n.kind === 'bug_report' ? 'inbox' : 'send' } })); return true; }
  if (btn.dataset.pexo) { await guard(btn, async () => { try { return await act('world_party_expedition_respond', { p_offer: n.payload.offer_id, p_accept: btn.dataset.acc === '1' }); } finally { await markRead(n); } }); return true; }
  if (btn.dataset.pexp) { await markRead(n); const p = n.payload || {};
    if (store.character?.location !== p.location) { toast(`${p.location || '그곳'}에 있어야 같은 곳으로 원정을 보낼 수 있습니다.`, 'warn'); return true; }
    window.dispatchEvent(new CustomEvent('yh-open-expedition', { detail: { node: p.node_id, minutes: p.minutes, stance: p.stance } })); return true; }
  if (btn.dataset.raid) { await markRead(n); closeModal(); btn.closest('.note-pop')?.remove(); window.yahangGo('raid', n.payload.raid_id); return true; }
  if (btn.dataset.gw) { await markRead(n); closeModal(); btn.closest('.note-pop')?.remove(); window.yahangGo('gw', n.payload.fight_id); return true; }
  if (btn.dataset.wed) {
    let ok = false;
    await guard(btn, async () => { try { const r = await act('world_wedding_respond', { p_wed: n.payload.wed_id, p_accept: btn.dataset.acc === '1' }); ok = btn.dataset.acc === '1'; return r; } finally { await markRead(n); } });
    if (ok) (await import('./bond.js')).openWedding(n.payload.wed_id);
    return true;
  }
  if (btn.dataset.wedv) { await markRead(n); closeModal(); btn.closest('.note-pop')?.remove(); (await import('./bond.js')).openWedding(n.payload.wed_id); return true; }
  if (btn.dataset.tn) { await markRead(n); closeModal(); btn.closest('.note-pop')?.remove(); window.yahangGo('tourney', n.kind === 'tourney_result' ? n.payload.t_id : ''); return true; }
  if (btn.dataset.pfight) {
    let ok = true;
    if (btn.dataset.join) await guard(btn, async () => { try { return await act('world_pfight_join', { p_fight: n.payload.fight_id }); } catch (e) { ok = false; throw e; } finally { await markRead(n); } });
    else await markRead(n);
    if (ok) { closeModal(); btn.closest('.note-pop')?.remove(); window.yahangGo('pfight', n.payload.fight_id); }
    return true;
  }
  if (btn.dataset.house) { await markRead(n); closeModal(); btn.closest('.note-pop')?.remove(); window.yahangGo('house'); return true; }
  if (btn.dataset.letter) { await markRead(n); closeModal(); btn.closest('.note-pop')?.remove(); window.yahangGo('party'); return true; }
  if (btn.dataset.fdown) { await markRead(n); closeModal(); btn.closest('.note-pop')?.remove(); window.yahangGo('map'); return true; }
  if (btn.dataset.goExp) { await markRead(n); window.dispatchEvent(new CustomEvent('yh-open-expedition')); return true; }
  return false;
}
// 초대·원정 완료처럼 바로 답해야 하는 알림은 화면 위에 띄운다(다른 창을 덮지 않는다).
function notePop(n) {
  if (document.querySelector(`.note-pop[data-id="${n.id}"]`)) return;
  let stack = document.querySelector('.note-pops');
  if (!stack) { stack = document.createElement('div'); stack.className = 'note-pops'; stack.setAttribute('aria-live', 'polite'); document.body.append(stack); }
  const card = h(`<div class="note-pop" data-id="${esc(n.id)}" role="alertdialog" aria-label="${esc(n.title || '알림')}">
    ${icon(/^bond_/.test(n.kind) ? 'heart' : n.kind === 'circle_invite' ? 'chat' : /^party_/.test(n.kind) ? 'users' : n.kind === 'friend_request' ? 'heart' : n.kind === 'trade_offer' ? 'coin' : n.kind === 'letter' ? 'letter' : /^spar_|^raid_/.test(n.kind) ? 'sword' : 'flame', 20)}<div><b>${esc(n.title || '알림')}</b><span>${esc(n.content || '')}</span></div>
    <div class="note-actions">${noteActs(n)}<button class="btn ghost small" data-pop-close aria-label="나중에">나중에</button></div></div>`);
  card.addEventListener('click', async e => {
    const b = e.target.closest('[data-invite],[data-trade],[data-friend],[data-circle],[data-bondn],[data-rescue],[data-go-exp],[data-ov],[data-spar],[data-sparv],[data-pexp],[data-pexo]');
    if (b) { if (await runAct(b)) card.remove(); return; }
    if (e.target.closest('[data-pop-close]')) card.remove();
  });
  stack.append(card);
  window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'reward' }));
}
// 지난 알림: 확인한 알림 중 아직 지워지지 않은 것(14일 보관)을 열 때만 읽는다.
async function drawPastNotes(box) {
  box.innerHTML = '<p class="muted small">불러오는 중…</p>';
  try {
    const { data, error } = await db.from('world_notifications').select('id,title,content,created_at,read_at').not('read_at', 'is', null).order('created_at', { ascending: false }).limit(60);
    if (error) throw error;
    box.innerHTML = (data || []).length ? data.map(n => `<article class="note-item past"><div><b>${esc(n.title || '알림')}</b><p>${esc(n.content || '')}</p><time>${fmt.time(n.created_at)}</time></div></article>`).join('')
      + '<p class="muted small note-keep">확인한 알림은 14일 동안 남습니다.</p>' : '<p class="muted">지난 알림이 없습니다.</p>';
  } catch { box.innerHTML = '<p class="muted">지난 알림을 불러오지 못했습니다.</p>'; }
}
function openNotifications() {
  const wrap = h(`<div class="notes-wrap"><div class="seg-mini" role="tablist"><button class="on" data-nt="new">새 알림${notes.length ? ` ${notes.length}` : ''}</button><button data-nt="past">지난 알림</button></div><div class="notes-past notes" hidden></div></div>`);
  const body = h(`<div class="notes">${notes.length ? notes.map(n => `<article class="note-item" data-note="${esc(n.id)}">
      <div><b>${esc(n.title || '알림')}</b><p>${esc(n.content || '')}</p><time>${fmt.time(n.created_at)}</time></div>
      <div class="note-actions">${noteActs(n)}<button class="btn ghost small" data-read="${esc(n.id)}">확인</button></div></article>`).join('') : '<p class="muted">새 알림이 없습니다.</p>'}
      ${notes.length > 1 ? '<button class="btn block" data-read-all>모두 확인</button>' : ''}</div>`);
  body.addEventListener('click', async e => {
    const r = e.target.closest('[data-read]'), a = e.target.closest('[data-invite],[data-trade],[data-friend],[data-circle],[data-bondn],[data-bug],[data-rescue],[data-go-exp],[data-ov],[data-spar],[data-sparv],[data-pexp],[data-pexo]'), all = e.target.closest('[data-read-all]');
    if (a) { const row = a.closest('.note-item'); if (await runAct(a) && (a.dataset.invite || a.dataset.trade || a.dataset.friend || a.dataset.circle || a.dataset.bondn || a.dataset.spar || a.dataset.sparv || a.dataset.pexo)) row?.remove(); if (a.dataset.goExp) closeModal(); return; }
    if (r) { const n = byId(r.dataset.read); r.closest('.note-item')?.remove(); if (n) await guard(r, () => markRead(n), { success: '' }); emptyNew(); }
    if (all) { await guard(all, async () => { for (const n of [...notes]) await markRead(n); body.innerHTML = '<p class="muted">새 알림이 없습니다.</p>'; emptyNew(); }, { success: '알림을 모두 확인했습니다.' }); }
  });
  wrap.insertBefore(body, wrap.querySelector('.notes-past'));
  // 확인한 알림은 지난 알림으로 옮겨 가므로 다음에 열 때 다시 읽는다
  function emptyNew() {
    const t = wrap.querySelector('[data-nt="new"]'); if (t) t.textContent = `새 알림${notes.length ? ` ${notes.length}` : ''}`;
    delete past.dataset.loaded;
    if (!notes.length && !body.querySelector('.note-item')) body.innerHTML = '<p class="muted">새 알림이 없습니다.</p>';
  }
  const past = wrap.querySelector('.notes-past');
  wrap.querySelector('.seg-mini').addEventListener('click', e => {
    const t = e.target.closest('[data-nt]'); if (!t) return;
    wrap.querySelectorAll('[data-nt]').forEach(x => x.classList.toggle('on', x === t));
    const isPast = t.dataset.nt === 'past'; body.hidden = isPast; past.hidden = !isPast;
    if (isPast && !past.dataset.loaded) { past.dataset.loaded = '1'; drawPastNotes(past); }
  });
  openModal({ title: '알림', body: wrap });
}
export { loadCharacter };
