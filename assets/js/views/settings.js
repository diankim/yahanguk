// 게임 설정: 프로필(사진·문장·색·소개·대표 칭호) · 테마 · 소리 · 계정. 프로필과 테마는 한 번에 저장한다.
import { store, act, esc, icon, $, $$, toast, guard, emblem, profileOf, EMBLEMS, EMBLEM_COLORS, loadCharacter, nameOf, segmented, bindSegmented } from '../core.js';
import { THEMES, themeCard, applyTheme, savedThemeId, readCustom, bindCrop } from '../settings.js';
import { sound, setEnabled, setVolume, playSfx, SFX_SAMPLES } from '../sound.js';
import { load, panel } from './common.js';

const SUBS = [['profile', '프로필'], ['theme', '테마'], ['sound', '소리'], ['account', '계정']];
let el, dirty = false, draft = null, kept = null; // kept: 저장하지 않고 나간 내용(다시 들어오면 이어서 고친다)

export async function render(root, sub) {
  if (!store.character) return;
  el = root;
  const c = store.character, cur = profileOf(c.owner_id, c.profile);
  const custom = readCustom() || { bg: '#101014', accent: '#c8432d', gold: '#d1a65a', r: 10, font: 'sans' };
  draft = { emblem: cur.emblem, color: cur.color, bio: cur.bio, avatar: undefined, theme: savedThemeId(), custom: { ...custom }, title: c.profile?.title || '' };
  dirty = false;
  const resumed = kept && kept.owner === c.owner_id;
  if (resumed) { Object.assign(draft, kept.draft); dirty = true; if (draft.theme !== savedThemeId()) applyTheme(draft.theme, false, draft.theme === 'custom' ? draft.custom : undefined); }
  kept = null;
  const titles = await load('world_title_snapshot').catch(() => null);
  const earned = (titles?.titles || []).filter(t => t.earned);
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('gear', 14)} 이 기기와 캐릭터의 설정</p><h1>게임 설정</h1></div>
      <div class="head-actions"><button class="btn primary" id="set-save" disabled>${icon('check', 16)}<span>변경 사항 저장</span></button></div></div>
    ${segmented('set-sub', SUBS, SUBS.some(x => x[0] === sub) ? sub : 'profile')}
    <section id="sec-profile" class="set-sec">
      ${panel('프로필', `<div class="profile-edit">
        <div class="profile-card"><div class="pc-emblem" id="pf-preview">${emblem(c.owner_id, c.profile, 72)}</div>
          <div><h3>${esc(c.character_name)}</h3><p>${esc(nameOf(c.job_key))} · ${esc(nameOf(c.faction_key))}</p><p class="muted small">이름·직업·소속은 바꿀 수 없습니다.</p></div></div>
        <h3 class="sub-h">사진</h3>
        <div class="avatar-edit">
          <div class="crop"><canvas width="240" height="240" id="crop-cv"></canvas></div>
          <div class="crop-tools">
            <label class="btn small"><input type="file" accept="image/*" id="av-file" hidden>${icon('plus', 14)}<span>사진 고르기</span></label>
            <label class="range-row"><span>확대</span><input type="range" id="av-zoom" min="1" max="4" step="0.01" value="1" disabled></label>
            ${c.profile?.avatar ? `<label class="toggle-row"><span><b>사진 지우기</b><small>저장하면 문장으로 돌아갑니다</small></span><input type="checkbox" id="av-clear"></label>` : ''}
            <p class="muted small">끌어서 위치를, 막대로 크기를 맞춥니다. 128×128로 줄여 저장합니다.</p>
          </div>
        </div>
        <h3 class="sub-h">문장</h3><div class="emblem-grid">${Object.entries(EMBLEMS).map(([k, [n]]) => `<button class="em-pick" data-em="${k}" aria-label="${n}">${emblem('x', { emblem: k, color: draft.color }, 40)}<small>${n}</small></button>`).join('')}</div>
        <h3 class="sub-h">색</h3><div class="color-grid">${Object.entries(EMBLEM_COLORS).map(([k, [n, col]]) => `<button class="col-pick" data-col="${k}" style="--c:${col}" aria-label="${n}"><i></i><small>${n}</small></button>`).join('')}</div>
        <label class="field"><span>한 줄 소개 (60자)</span><input id="pf-bio" maxlength="60" value="${esc(draft.bio)}" placeholder="예: 밤길을 걷는 조사원"></label>
        <label class="field"><span>대표 칭호 (채팅과 프로필에 보입니다)</span><select id="pf-title"><option value="">걸지 않음</option>${earned.map(t => `<option value="${esc(t.key)}" ${t.key === draft.title ? 'selected' : ''}>${esc(t.name)}</option>`).join('')}</select></label>
      </div>`, { ico: 'idcard' })}
    </section>
    <section id="sec-theme" class="set-sec">
      ${panel('테마', `<p class="muted small">고르면 바로 미리 보입니다. 저장해야 다음 접속에도 남습니다.</p>
        <div class="theme-grid">${THEMES.map(t => themeCard(t, t.id === draft.theme)).join('')}</div>
        <h3 class="sub-h">직접 설정</h3>
        <div class="custom-theme ${draft.theme === 'custom' ? 'on' : ''}">
          <label class="color-row"><span>바탕</span><input type="color" data-cu="bg" value="${custom.bg}"></label>
          <label class="color-row"><span>강조</span><input type="color" data-cu="accent" value="${custom.accent}"></label>
          <label class="color-row"><span>포인트</span><input type="color" data-cu="gold" value="${custom.gold}"></label>
          <label class="range-row"><span>모서리</span><input type="range" data-cu="r" min="0" max="20" step="1" value="${custom.r ?? 10}"></label>
          <label class="field"><span>글꼴</span><select data-cu="font"><option value="sans" ${custom.font === 'sans' ? 'selected' : ''}>고딕</option><option value="serif" ${custom.font === 'serif' ? 'selected' : ''}>명조</option><option value="mixed" ${custom.font === 'mixed' ? 'selected' : ''}>제목만 명조</option></select></label>
          <p class="muted small">바탕이 밝으면 글자가 자동으로 어두워집니다.</p>
        </div>`, { ico: 'palette' })}
    </section>
    <section id="sec-sound" class="set-sec">
      ${panel('소리', `
        <label class="toggle-row"><span><b>배경음악</b><small>가야금·대금 느낌의 곡조가 영역마다 다르게 흐릅니다</small></span><input type="checkbox" data-sw="bgmOn" ${sound.bgmOn ? 'checked' : ''}></label>
        <label class="range-row"><span>배경음악 음량</span><input type="range" data-vol="bgm" min="0" max="1" step="0.05" value="${sound.bgm}"></label>
        <label class="toggle-row"><span><b>환경음</b><small>날씨와 시간대에 따라 빗소리·바람·풀벌레·새소리가 작게 깔립니다</small></span><input type="checkbox" data-sw="ambOn" ${sound.ambOn ? 'checked' : ''}></label>
        <label class="range-row"><span>환경음 음량</span><input type="range" data-vol="amb" min="0" max="1" step="0.05" value="${sound.amb}"></label>
        <label class="toggle-row"><span><b>효과음</b><small>이동·전투·거래·제작·보상마다 다른 짧은 소리</small></span><input type="checkbox" data-sw="sfxOn" ${sound.sfxOn ? 'checked' : ''}></label>
        <label class="range-row"><span>효과음 음량</span><input type="range" data-vol="sfx" min="0" max="1" step="0.05" value="${sound.sfx}"></label>
        <div class="sfx-preview">${SFX_SAMPLES.map(([k, n]) => `<button class="btn small" data-try="${k}">${n}</button>`).join('')}</div>
        <p class="muted small">소리 설정은 바로 적용되고 이 기기에 저장됩니다. 음악은 브라우저에서 직접 연주하므로 따로 내려받는 파일이 없습니다.</p>`, { ico: 'volume' })}
    </section>
    <section id="sec-account" class="set-sec">
      ${panel('계정', `<p class="desc">로그인 이메일·비밀번호 변경, 로그아웃, 캐릭터 정리는 계정 화면에서 합니다.</p>
        <a class="btn" href="#/account">${icon('idcard', 16)}<span>계정 관리 열기</span></a>`, { ico: 'shield' })}
    </section>`;

  const save = $('#set-save', el);
  const touch = () => { dirty = true; save.disabled = false; };
  if (resumed) { save.disabled = false; toast('저장하지 않은 설정을 이어서 고칩니다.', 'info'); }
  const showSub = k => { $$('.set-sec', el).forEach(s => s.classList.toggle('on', s.id === `sec-${k}`)); };
  bindSegmented(el, 'set-sub', k => { history.replaceState(null, '', `#/settings/${k}`); window.dispatchEvent(new Event('yh-subpage')); showSub(k); });
  showSub(SUBS.some(x => x[0] === sub) ? sub : 'profile');

  // 프로필
  const drawProfile = () => {
    $('#pf-preview', el).innerHTML = emblem(c.owner_id, { ...c.profile, emblem: draft.emblem, color: draft.color, avatar: $('#av-clear', el)?.checked ? null : c.profile?.avatar }, 72);
    $$('.em-pick', el).forEach(b => { b.classList.toggle('on', b.dataset.em === draft.emblem); b.querySelector('.emblem').style.setProperty('--em', EMBLEM_COLORS[draft.color][1]); });
    $$('.col-pick', el).forEach(b => b.classList.toggle('on', b.dataset.col === draft.color));
  };
  el.addEventListener('click', e => {
    const em = e.target.closest('[data-em]'), col = e.target.closest('[data-col]'), th = e.target.closest('[data-theme-id]'), tr = e.target.closest('[data-try]');
    if (em) { draft.emblem = em.dataset.em; touch(); drawProfile(); }
    if (col) { draft.color = col.dataset.col; touch(); drawProfile(); }
    if (th) { draft.theme = th.dataset.themeId; applyTheme(draft.theme, false); markTheme(); touch(); }
    if (tr) playSfx(tr.dataset.try);
  });
  $('#pf-bio', el).oninput = () => { draft.bio = $('#pf-bio', el).value; touch(); };
  $('#pf-title', el).onchange = () => { draft.title = $('#pf-title', el).value; touch(); };
  $('#av-clear', el)?.addEventListener('change', () => { touch(); drawProfile(); });
  const crop = bindCrop(el, () => { draft.avatar = 'pending'; touch(); });
  drawProfile();

  // 테마
  const markTheme = () => { $$('.theme-card', el).forEach(x => x.classList.toggle('on', x.dataset.themeId === draft.theme)); $('.custom-theme', el).classList.toggle('on', draft.theme === 'custom'); };
  $$('[data-cu]', el).forEach(i => i.oninput = () => {
    const k = i.dataset.cu; draft.custom[k] = k === 'r' ? Number(i.value) : i.value; draft.theme = 'custom';
    applyTheme('custom', false, draft.custom); markTheme(); touch();
  });

  // 소리(바로 적용)
  $$('[data-sw]', el).forEach(i => i.onchange = () => setEnabled(i.dataset.sw, i.checked));
  $$('[data-vol]', el).forEach(i => i.oninput = () => { setVolume(i.dataset.vol, Number(i.value)); if (i.dataset.vol === 'sfx') playSfx('tap'); });

  save.onclick = () => guard(save, async () => {
    const tasks = [];
    const p = profileOf(c.owner_id, c.profile);
    if (draft.emblem !== p.emblem || draft.color !== p.color || draft.bio !== p.bio) tasks.push(act('world_set_profile_v2', { p_emblem: draft.emblem, p_color: draft.color, p_bio: draft.bio }));
    if (crop.has() && draft.avatar === 'pending') tasks.push(act('world_set_avatar', { p_image: crop.dataUrl() }));
    else if ($('#av-clear', el)?.checked) tasks.push(act('world_set_avatar', { p_image: null }));
    if (draft.title !== (c.profile?.title || '')) tasks.push(act('world_title_set_display', { p_title_key: draft.title || null }));
    for (const t of tasks) await t;
    applyTheme(draft.theme, true, draft.theme === 'custom' ? draft.custom : undefined);
    await loadCharacter();
    dirty = false; save.disabled = true;
    return { content: '설정을 저장했습니다.' };
  });
}
// 저장하지 않고 나가면 테마 미리보기는 되돌리되, 고치던 내용은 기억해 두었다가 다시 들어오면 이어서 고친다.
export function destroy() {
  if (dirty && draft) {
    kept = { owner: store.character?.owner_id, draft: { emblem: draft.emblem, color: draft.color, bio: draft.bio, title: draft.title, theme: draft.theme, custom: { ...draft.custom } } };
    applyTheme(savedThemeId(), false);
    toast('아직 저장하지 않았습니다. 설정으로 돌아오면 이어서 고칠 수 있습니다.', 'info');
  }
  dirty = false;
}
