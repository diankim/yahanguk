// 게임 설정: 프로필(사진·문장·색·소개·대표 칭호) · 테마 · 소리 · 계정. 프로필과 테마는 한 번에 저장한다.
import { ask, db, store, act, rpc, esc, icon, $, $$, toast, guard, emblem, profileOf, EMBLEMS, EMBLEM_COLORS, loadCharacter, nameOf, segmented, bindSegmented } from '../core.js';
import { THEMES, themeCard, applyTheme, savedThemeId, readCustom, bindCrop, openProfile, FONT_SIZES, savedFontSize, applyFontSize } from '../settings.js';
import { sound, setEnabled, setVolume, playSfx, SFX_SAMPLES } from '../sound.js';
import { load, panel } from './common.js';
import { patternLayer, patternSwatch, sealMark } from '../cosmetics.js';
import { hue as autoHue, NAME_STYLES } from '../chat.js';
// 채팅 이름 색: 색상환 각도. 밝기는 테마(어두움·밝음)에 맞춰 화면이 정한다.
const CHAT_HUES = [0, 18, 36, 50, 85, 130, 160, 185, 205, 225, 255, 280, 305, 330];
import { logout } from '../session.js';

const SUBS = [['profile', '프로필', 'idcard'], ['theme', '테마', 'palette'], ['sound', '소리', 'volume'], ['notify', '알림', 'bell'], ['account', '계정', 'shield']];
// 알림 갈래(서버 world_notify_group과 같은 키). 끈 갈래는 들어올 때 읽음 처리되어 화면에 뜨지 않고 지난 알림에만 남는다.
const NOTIFY_GROUPS = [
  ['rescue', '같은 곳의 구조 요청', '같은 지역에서 누가 쓰러졌을 때'],
  ['friend_rescue', '친구 구조', '친구가 다른 곳에서 쓰러졌을 때'],
  ['party', '파티', '초대·파티 원정 제안·돌보기·탈퇴'],
  ['friend', '친구', '친구 신청·수락'],
  ['trade', '거래', '직접 거래 제안·결과'],
  ['raid', '토벌·결전', '합동 토벌 소식·귀허의 주인 초대'],
  ['title', '칭호·꾸미기', '새 칭호·꾸미기를 얻었을 때'],
  ['reward', '보상', '보상 수령·기술 단계 변경'],
  ['bag', '가방', '가방이 가득 차 버린 물품'],
  ['circle', '모임', '모임 초대'],
  ['spar', '비무', '비무 신청·결과'],
  ['bond', '연리', '정인 신청·선물·안부'],
  ['faction', '세력', '세력 소식'],
];
let el, onClick = null, dirty = false, draft = null, kept = null; // kept: 저장하지 않고 나간 내용(다시 들어오면 이어서 고친다)

export async function render(root, sub) {
  if (!store.character) return;
  el = root;
  const c = store.character, cur = profileOf(c.owner_id, c.profile);
  const custom = readCustom() || { bg: '#101014', accent: '#c8432d', gold: '#d1a65a', r: 10, font: 'sans' };
  draft = { emblem: cur.emblem, color: cur.color, bio: cur.bio, avatar: undefined, theme: savedThemeId(), custom: { ...custom }, title: c.profile?.title || '', frame: c.profile?.frame || '', pattern: c.profile?.pattern || '', seal: c.profile?.seal || '', chatHue: Number.isInteger(c.profile?.chat_hue) ? c.profile.chat_hue : null };
  dirty = false;
  const resumed = kept && kept.owner === c.owner_id;
  if (resumed) { Object.assign(draft, kept.draft); dirty = true; if (draft.theme !== savedThemeId()) applyTheme(draft.theme, false, draft.theme === 'custom' ? draft.custom : undefined); }
  kept = null;
  const [titles, cos, styles] = await Promise.all([load('world_title_snapshot').catch(() => null), load('world_cosmetic_snapshot').catch(() => null), rpc('world_name_styles').catch(() => ({}))]);
  const earned = (titles?.titles || []).filter(t => t.earned);
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('gear', 14)} 이 기기와 캐릭터의 설정</p><h1>게임 설정</h1></div>
      <div class="head-actions"><a class="btn ghost" href="#/patch">${icon('scroll', 16)}<span>패치노트</span></a><button class="btn primary" id="set-save" disabled>${icon('check', 16)}<span>변경 사항 저장</span></button></div></div>
    <div class="set-links"><button class="btn small" id="set-view-profile">${icon('idcard', 14)}<span>프로필 보기</span></button><button class="btn small" id="set-bug">${icon('flag', 14)}<span>제보·소감</span></button><button class="btn small ghost" id="set-logout-top">${icon('logout', 14)}<span>로그아웃</span></button></div>
    ${segmented('set-sub', SUBS, SUBS.some(x => x[0] === sub) ? sub : 'profile')}
    <section id="sec-profile" class="set-sec">
      ${panel('프로필', `<div class="profile-edit">
        <div class="profile-card" id="pf-card"><span id="pf-pattern"></span><div class="pc-emblem" id="pf-preview">${emblem(c.owner_id, c.profile, 72)}</div>
          <div><h3>${esc(c.character_name)}<span id="pf-seal"></span></h3><p>${esc(nameOf(c.job_key))} · ${esc(nameOf(c.faction_key))}</p><p class="muted small">이름·직업·소속은 바꿀 수 없습니다.</p></div></div>
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
        <h3 class="sub-h">채팅 이름 색</h3>
        <div class="hue-grid">${`<button class="hue-pick auto" data-hue="" aria-label="자동">자동</button>`}${CHAT_HUES.map(h => `<button class="hue-pick" data-hue="${h}" style="--hu:${h}" aria-label="색 ${h}">가</button>`).join('')}</div>
        <div class="hue-grid">${Object.entries(NAME_STYLES).map(([v, [n, how]]) => `<button class="hue-pick ns-${v}" data-hue="${v}" ${styles?.[v] ? '' : `data-locked="${esc(`${n}: ${how} 쓸 수 있습니다.`)}"`} title="${esc(styles?.[v] ? `칭호 보상 이름 색 · ${n}` : `${how} 쓸 수 있습니다`)}">${esc(n)}</button>`).join('')}</div>
        <p class="muted small">아래 15가지는 칭호로 여는 특별 이름 색입니다. 흐린 색은 아직 잠긴 것이고, 누르면 여는 조건이 보입니다. 채팅과 조사원 카드의 이름에 보입니다.</p>
        <p class="hue-preview muted" id="hue-preview"></p>
        <label class="field"><span>한 줄 소개 (60자)</span><input id="pf-bio" maxlength="60" value="${esc(draft.bio)}" placeholder="예: 밤길을 걷는 조사원"></label>
        <label class="field"><span>대표 칭호 (채팅과 프로필에 보입니다)</span><select id="pf-title"><option value="">걸지 않음</option>${earned.map(t => `<option value="${esc(t.key)}" ${t.key === draft.title ? 'selected' : ''}>${esc(t.name)}</option>`).join('')}</select></label>
        ${cosmeticsHtml(cos)}
      </div>`, { ico: 'idcard' })}
    </section>
    <section id="sec-theme" class="set-sec">
      ${panel('글자 크기', `<p class="muted small">이 기기에만 남고 바로 바뀝니다(저장 단추와 상관없음).</p>
        <div class="fz-row" role="radiogroup" aria-label="글자 크기">${FONT_SIZES.map(([k, n, z]) => `<button type="button" class="btn ${savedFontSize() === k ? 'primary' : ''}" data-fz="${k}" role="radio" aria-checked="${savedFontSize() === k}"><span style="font-size:${Math.round(14 * z * 10) / 10}px">가</span><small>${n}</small></button>`).join('')}</div>`, { ico: 'scroll' })}
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
    <section id="sec-notify" class="set-sec">
      ${panel('알림', `<p class="muted small">끈 알림은 화면 위에 뜨지 않고 알림 창의 「지난 알림」에만 남습니다. 운영 공지·제보 답장·원정 귀환·요화 같은 알림은 끌 수 없습니다. 바꾸면 바로 저장됩니다(어느 기기에서나 같음).</p>
        <div id="nt-list">${NOTIFY_GROUPS.map(([k, n, d]) => `<label class="toggle-row"><span><b>${n}</b><small>${d}</small></span><input type="checkbox" data-nt="${k}" checked disabled></label>`).join('')}</div>`, { ico: 'bell' })}
    </section>
    <section id="sec-account" class="set-sec">
      ${panel('계정', `<p class="desc">아이디 확인·비밀번호 변경, 로그아웃, 캐릭터 정리는 계정 화면에서 합니다.</p>
        <div class="btn-row"><a class="btn" href="#/account">${icon('idcard', 16)}<span>계정 관리 열기</span></a>
          <button class="btn ghost" id="set-logout">${icon('logout', 16)}<span>로그아웃</span></button></div>`, { ico: 'shield' })}
    </section>`;

  $('#set-logout', el).onclick = $('#set-logout-top', el).onclick = async () => { if (await ask('로그아웃할까요?', { title: '로그아웃', ok: '로그아웃' })) logout(); };
  $('#set-view-profile', el).onclick = () => openProfile();
  $('#set-bug', el).onclick = () => window.dispatchEvent(new CustomEvent('yh-open-bug'));
  const save = $('#set-save', el);
  const touch = () => { dirty = true; save.disabled = false; };
  if (resumed) { save.disabled = false; toast('저장하지 않은 설정을 이어서 고칩니다.', 'info'); }
  // 알림 칸: 처음 열 때 한 번만 읽고, 바꾸면 그 자리에서 저장한다
  let ntLoaded = false;
  const loadNotify = async () => {
    if (ntLoaded) return; ntLoaded = true;
    const boxes = $$('[data-nt]', el);
    try {
      const p = await rpc('world_notify_prefs_get');
      const off = new Set(p?.off || []);
      boxes.forEach(b => { b.checked = !off.has(b.dataset.nt); b.disabled = false; });
    } catch (e) { ntLoaded = false; toast(e.message, 'error'); return; }
    boxes.forEach(b => b.onchange = async () => {
      const off = boxes.filter(x => !x.checked).map(x => x.dataset.nt);
      boxes.forEach(x => x.disabled = true);
      try { await rpc('world_notify_prefs_set', { p_off: off }); toast('알림 설정을 저장했습니다.', 'ok'); }
      catch (e) { b.checked = !b.checked; toast(e.message, 'error'); }
      finally { boxes.forEach(x => x.disabled = false); }
    });
  };
  const showSub = k => { $$('.set-sec', el).forEach(s => s.classList.toggle('on', s.id === `sec-${k}`)); if (k === 'notify') loadNotify(); };
  bindSegmented(el, 'set-sub', k => { history.replaceState(null, '', `#/settings/${k}`); window.dispatchEvent(new Event('yh-subpage')); showSub(k); });
  showSub(SUBS.some(x => x[0] === sub) ? sub : 'profile');

  // 꾸미기를 누르면(모바일은 마우스를 올릴 수 없으므로) 그 아래 줄에 얻은 경로·얻는 방법을 보여 준다
  const cosInfo = b => {
    const kind = b.dataset.cosKind || b.dataset.cosLock, box = $(`[data-cos-info="${kind}"]`, el); if (!box) return;
    if (!b.dataset.cosName) { box.innerHTML = ''; return; }
    box.innerHTML = `<b>${esc(b.dataset.cosName)}</b> · ${b.dataset.cosLock ? '얻는 방법' : '얻은 경로'}: ${esc(b.dataset.cosHint || '-')}`;
  };
  // 프로필
  const drawProfile = () => {
    $('#pf-preview', el).innerHTML = emblem(c.owner_id, { ...c.profile, emblem: draft.emblem, color: draft.color, frame: draft.frame || null, avatar: $('#av-clear', el)?.checked ? null : c.profile?.avatar }, 72);
    $('#pf-pattern', el).innerHTML = patternLayer(draft.pattern);
    $('#pf-seal', el).innerHTML = sealMark(draft.seal);
    $$('[data-cos-kind]', el).forEach(b => b.classList.toggle('on', (draft[b.dataset.cosKind] || '') === b.dataset.cosKey));
    $$('.em-pick', el).forEach(b => { b.classList.toggle('on', b.dataset.em === draft.emblem); b.querySelector('.emblem').style.setProperty('--em', EMBLEM_COLORS[draft.color][1]); });
    $$('.col-pick', el).forEach(b => b.classList.toggle('on', b.dataset.col === draft.color));
    $$('.hue-pick', el).forEach(b => b.classList.toggle('on', b.dataset.hue === (draft.chatHue == null ? '' : String(draft.chatHue))));
    const pv = $('#hue-preview', el), sp = NAME_STYLES[draft.chatHue];
    pv.className = `hue-preview muted${sp ? ` ns-${draft.chatHue}` : ''}`; pv.style.setProperty('--hu', sp || draft.chatHue == null ? autoHue(c.owner_id) : draft.chatHue);
    pv.innerHTML = `<b>${esc(c.character_name)}</b> 채팅에 이렇게 보입니다.${draft.chatHue == null ? ' (자동: 이름마다 정해진 색)' : ''} 저장한 뒤 보내는 말부터 바뀝니다.`;
  };
  // 화면 틀(root)은 다른 화면과 같이 쓰므로 들어올 때마다 붙이면 처리가 겹친다(잠긴 이름 색 안내가 두 번 뜨던 문제). 하나만 붙이고 나갈 때 뗀다.
  if (onClick) el.removeEventListener('click', onClick);
  el.addEventListener('click', onClick = e => {
    const em = e.target.closest('[data-em]'), col = e.target.closest('[data-col]'), th = e.target.closest('[data-theme-id]'), tr = e.target.closest('[data-try]'), cs = e.target.closest('[data-cos-kind]');
    if (cs && !cs.disabled) { draft[cs.dataset.cosKind] = cs.dataset.cosKey; touch(); drawProfile(); cosInfo(cs); }
    const lk = e.target.closest('[data-cos-lock]'); if (lk) cosInfo(lk);
    const hp = e.target.closest('[data-hue]'); if (hp?.dataset.locked) { toast(hp.dataset.locked, 'info'); return; } if (hp) { draft.chatHue = hp.dataset.hue === '' ? null : Number(hp.dataset.hue); touch(); drawProfile(); }
    if (em) { draft.emblem = em.dataset.em; touch(); drawProfile(); }
    if (col) { draft.color = col.dataset.col; touch(); drawProfile(); }
    if (th) { draft.theme = th.dataset.themeId; applyTheme(draft.theme, false); markTheme(); touch(); }
    if (tr) playSfx(tr.dataset.try);
    const fz = e.target.closest('[data-fz]');
    if (fz) { applyFontSize(fz.dataset.fz); $$('[data-fz]', el).forEach(x => { const on = x === fz; x.classList.toggle('primary', on); x.setAttribute('aria-checked', String(on)); }); }
  });
  $('#pf-bio', el).oninput = () => { draft.bio = $('#pf-bio', el).value; touch(); };
  $('#pf-title', el).onchange = () => { draft.title = $('#pf-title', el).value; touch(); };
  $('#av-clear', el)?.addEventListener('change', () => { touch(); drawProfile(); });
  const crop = bindCrop(el, () => { draft.avatar = 'pending'; touch(); });
  drawProfile();
  $$('[data-cos-kind].on', el).forEach(cosInfo); // 지금 고른 것의 얻은 경로부터 보여 준다

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
    if (draft.chatHue !== (Number.isInteger(c.profile?.chat_hue) ? c.profile.chat_hue : null)) tasks.push(NAME_STYLES[draft.chatHue] ? act('world_set_name_style', { p_style: draft.chatHue }) : act('world_set_chat_hue', { p_hue: draft.chatHue }));
    if (draft.title !== (c.profile?.title || '')) tasks.push(act('world_title_set_display', { p_title_key: draft.title || null }));
    for (const k of ['frame', 'pattern', 'seal']) if ((draft[k] || '') !== (c.profile?.[k] || '')) tasks.push(act('world_cosmetic_equip', { p_kind: k, p_key: draft[k] || null }));
    for (const t of tasks) await t;
    applyTheme(draft.theme, true, draft.theme === 'custom' ? draft.custom : undefined);
    await loadCharacter();
    dirty = false; save.disabled = true;
    return { content: '설정을 저장했습니다.' };
  });
}
// 꾸미기: 테두리·바탕 무늬·낙관. 얻은 것만 고를 수 있고, 잠긴 것은 얻는 방법을 보여 준다(숨김은 서버가 가린다).
const KINDS = [['frame', '테두리'], ['pattern', '바탕 무늬'], ['seal', '낙관']];
const TIER = { common: '', rare: '희귀', legend: '전설', legacy: '흔적' };
function cosmeticsHtml(cos) {
  if (!cos) return `<h3 class="sub-h">꾸미기</h3><p class="muted small">꾸미기 목록을 불러오지 못했습니다.</p>`;
  const sample = (kind, key) => kind === 'frame' ? emblem(store.character.owner_id, { ...store.character.profile, frame: key || null }, 60)
    : kind === 'pattern' ? (key ? patternSwatch(key) : '<span class="pt-swatch"></span>') : (key ? sealMark(key) : '<span class="seal-mark none">없음</span>');
  return `<h3 class="sub-h">꾸미기</h3><p class="muted small">칭호·사건·탐사·제작·채집·낚시·교류·거래 등 여러 활동으로 얻습니다. 고른 뒤 저장해야 다른 조사원에게 보입니다(채팅에는 보이지 않습니다).</p>
    ${KINDS.map(([kind, label]) => {
      const list = (cos.items || []).filter(i => i.kind === kind), got = list.filter(i => i.owned).length;
      return `<h4 class="cos-h">${label} <small class="muted">${got}/${list.length}</small></h4><div class="cos-grid">
        <button type="button" class="cos-pick" data-cos-kind="${kind}" data-cos-key="">${sample(kind, '')}<b>없음</b></button>
        ${list.map(i => i.owned ? `<button type="button" class="cos-pick t-${i.tier}" data-cos-kind="${kind}" data-cos-key="${esc(i.key)}" data-cos-name="${esc(i.name)}" data-cos-hint="${esc(i.hint)}" title="${esc(i.hint)}">${sample(kind, i.key)}<b>${esc(i.name)}</b>${TIER[i.tier] ? `<small>${TIER[i.tier]}</small>` : ''}</button>`
          : `<button type="button" class="cos-pick locked" aria-disabled="true" data-cos-lock="${kind}" data-cos-name="${esc(i.name)}" data-cos-hint="${esc(i.hint)}" title="${esc(i.hint)}">${i.key ? sample(kind, i.key) : '<span class="cos-q">?</span>'}<b>${esc(i.name)}</b><small>${esc(i.hint)}</small></button>`).join('')}</div>
        <p class="cos-info" data-cos-info="${kind}" aria-live="polite"></p>`;
    }).join('')}`;
}
// 저장하지 않고 나가면 테마 미리보기는 되돌리되, 고치던 내용은 기억해 두었다가 다시 들어오면 이어서 고친다.
export function destroy() {
  if (onClick && el) el.removeEventListener('click', onClick);
  onClick = null;
  if (dirty && draft) {
    kept = { owner: store.character?.owner_id, draft: { emblem: draft.emblem, color: draft.color, bio: draft.bio, title: draft.title, frame: draft.frame, pattern: draft.pattern, seal: draft.seal, theme: draft.theme, custom: { ...draft.custom } } };
    applyTheme(savedThemeId(), false);
    toast('아직 저장하지 않았습니다. 설정으로 돌아오면 이어서 고칠 수 있습니다.', 'info');
  }
  dirty = false;
}
