// 헤더 기능: 테마(프리셋·흑백·직접 설정) · 프로필 보기 · 알림. 고치는 화면은 설정 페이지(views/settings.js)에 있다.
import { db, store, rpc, act, esc, icon, h, $, $$, openModal, closeModal, toast, guard, fmt, emblem, profileOf, loadCharacter, nameOf, JOBS } from './core.js';
export { initSound, playSfx } from './sound.js';

// 테마는 의존성 없는 theme.js에 있다(점검 페이지도 같은 테마를 쓴다).
export { THEMES, deriveCustom, readCustom, themeOf, applyTheme, savedThemeId, applySavedTheme, themeCard } from './theme.js';

/* ── 프로필 보기(고치기는 설정 페이지에서) ─────────────────── */
export function openProfile() {
  const c = store.character || {}, p = profileOf(c.owner_id, c.profile);
  openModal({ title: '프로필', body: `<div class="profile-view">
    <div class="profile-card"><div class="pc-emblem">${emblem(c.owner_id, c.profile, 80)}</div>
      <div><h3>${esc(c.character_name || '')}</h3>${c.profile?.title_name ? `<p class="title-badge">「${esc(c.profile.title_name)}」</p>` : ''}
        <p>${esc(nameOf(c.job_key))} · ${esc(nameOf(c.faction_key))}${c.major_faction_id ? ' · ' + esc(nameOf(c.major_faction_id)) : ''}</p>
        <p class="muted small">Lv.${c.level || 1} · ${esc(JOBS[c.job_key]?.trait || '')} · ${esc(c.location || '')}</p></div></div>
    <p class="bio">${p.bio ? esc(p.bio) : '<span class="muted">한 줄 소개가 없습니다.</span>'}</p>
    <div class="btn-row"><a class="btn primary" href="#/settings/profile" data-close>${icon('gear', 16)}<span>프로필 수정</span></a>
      <a class="btn" href="#/char/titles" data-close>${icon('spark', 16)}<span>칭호 보기</span></a></div>
    <p class="muted small">이름·직업·소속은 캐릭터를 만들 때 정해지며 바꿀 수 없습니다.</p></div>` });
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
let notes = [], bell;
export function mountNotifications(btn) {
  bell = btn;
  bell.onclick = openNotifications;
  loadNotes();
  try {
    db.channel('yh-notes').on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'world_notifications' }, p => {
      if (p.new?.user_id !== store.user?.id) return;
      notes.unshift(p.new); drawDot(); toast(p.new.title || '새 알림', 'info');
    }).subscribe();
  } catch {}
  setInterval(() => { if (!document.hidden) loadNotes(); }, 120000);
}
async function loadNotes() {
  try {
    const { data, error } = await db.from('world_notifications').select('*').is('read_at', null).order('created_at', { ascending: false }).limit(30);
    if (error) throw error; notes = data || []; drawDot();
  } catch {}
}
function drawDot() { const d = bell?.querySelector('.dot'); if (d) { d.hidden = !notes.length; d.textContent = notes.length > 9 ? '9+' : String(notes.length || ''); } }
function openNotifications() {
  const body = h(`<div class="notes">${notes.length ? notes.map((n, i) => `<article class="note-item">
      <div><b>${esc(n.title || '알림')}</b><p>${esc(n.content || '')}</p><time>${fmt.time(n.created_at)}</time></div>
      <div class="note-actions">${n.kind === 'rescue_request' && n.payload?.target_id ? `<button class="btn primary small" data-rescue="${i}">구조</button>` : ''}
        <button class="btn ghost small" data-read="${i}">확인</button></div></article>`).join('') : '<p class="muted">새 알림이 없습니다.</p>'}
      ${notes.length > 1 ? '<button class="btn block" data-read-all>모두 확인</button>' : ''}</div>`);
  body.addEventListener('click', async e => {
    const r = e.target.closest('[data-read]'), s = e.target.closest('[data-rescue]'), all = e.target.closest('[data-read-all]');
    if (r) { const n = notes[Number(r.dataset.read)]; await guard(r, () => rpc('world_mark_notification_read', { p_id: n.id }), { success: '' }); notes = notes.filter(x => x !== n); drawDot(); r.closest('.note-item').remove(); }
    if (s) { const n = notes[Number(s.dataset.rescue)]; await guard(s, () => act('world_rescue_character', { p_target: n.payload.target_id })); }
    if (all) { await guard(all, async () => { for (const n of [...notes]) await rpc('world_mark_notification_read', { p_id: n.id }); notes = []; drawDot(); closeModal(); }, { success: '알림을 모두 확인했습니다.' }); }
  });
  openModal({ title: '알림', body });
}
export { loadCharacter };
