// 계정: 게임 캐릭터와 별개인 로그인 계정 정보. 이메일·비밀번호 변경, 로그아웃.
import { db, store, rpc, esc, icon, $, toast, friendlyError, loadCharacter } from '../core.js';
import { panel } from './common.js';

export async function render(el) {
  const u = store.user || {};
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('idcard', 14)} 로그인 정보</p><h1>계정</h1></div></div>
    <p class="muted small">계정은 로그인에만 쓰이며 다른 조사원에게 보이지 않습니다. 캐릭터 문장·소개는 상단의 프로필에서 고칩니다.</p>
    <div class="grid-2">
      ${panel('계정 정보', `<dl class="kv"><div><dt>이메일</dt><dd>${esc(u.email || '')}</dd></div>
        <div><dt>가입일</dt><dd>${u.created_at ? new Date(u.created_at).toLocaleDateString('ko-KR') : '-'}</dd></div>
        <div><dt>최근 로그인</dt><dd>${u.last_sign_in_at ? new Date(u.last_sign_in_at).toLocaleString('ko-KR') : '-'}</dd></div></dl>
        <button class="btn danger" id="acc-logout">${icon('logout', 16)}<span>로그아웃</span></button>`, { ico: 'idcard' })}
      ${panel('비밀번호 변경', `<form class="stack-form" id="pw-form" novalidate>
        <label class="field"><span>새 비밀번호 (6자 이상)</span><input name="pw" type="password" autocomplete="new-password" minlength="6" required></label>
        <label class="field"><span>새 비밀번호 확인</span><input name="pw2" type="password" autocomplete="new-password" minlength="6" required></label>
        <button class="btn primary" type="submit">${icon('check', 16)}<span>비밀번호 바꾸기</span></button></form>`, { ico: 'shield' })}
      ${panel('이메일 변경', `<form class="stack-form" id="mail-form" novalidate>
        <label class="field"><span>새 이메일</span><input name="mail" type="email" autocomplete="email" required></label>
        <button class="btn" type="submit">${icon('check', 16)}<span>인증 메일 보내기</span></button>
        <p class="muted small">새 주소로 온 인증 메일을 확인해야 바뀝니다.</p></form>`, { ico: 'bell' })}
    </div>
    <details class="panel fold danger-zone"><summary class="panel-head"><h2>${icon('flame', 16)}캐릭터 정리</h2></summary><div class="panel-body">
      <p class="desc">지금 캐릭터를 정리하고 처음부터 새 조사원을 키웁니다. 계정은 그대로 남습니다.</p>
      <ul class="muted small"><li>레벨·소지품·장비·탈것·진행도가 모두 사라지며 되돌릴 수 없습니다.</li>
        <li>전투불능이나 사망 상태라면 그 자리에 시신이 남고, 다른 조사원이 유품을 수습할 수 있습니다.</li>
        <li>거래소에 올린 물품은 함께 사라집니다.</li></ul>
      <form class="stack-form" id="del-form" novalidate>
        <label class="field"><span>확인을 위해 캐릭터 이름 <b>${esc(store.character?.character_name || '')}</b>을(를) 그대로 적으세요</span><input name="confirm" autocomplete="off"></label>
        <button class="btn danger" type="submit">${icon('flame', 16)}<span>캐릭터 정리하고 새로 시작</span></button></form>
    </div></details>`;
  $('#acc-logout', el).onclick = () => db.auth.signOut();
  const submit = (form, fn) => form.onsubmit = async e => {
    e.preventDefault(); const btn = form.querySelector('button'); if (btn.disabled) return; btn.disabled = true;
    try { await fn(); } catch (err) { toast(friendlyError(err), 'error'); } finally { btn.disabled = false; }
  };
  const pw = $('#pw-form', el);
  submit(pw, async () => {
    if (pw.pw.value.length < 6) throw new Error('비밀번호는 6자 이상이어야 합니다.');
    if (pw.pw.value !== pw.pw2.value) throw new Error('비밀번호 확인이 일치하지 않습니다.');
    const { error } = await db.auth.updateUser({ password: pw.pw.value }); if (error) throw error;
    pw.reset(); toast('비밀번호를 바꿨습니다.', 'ok');
  });
  const del = $('#del-form', el);
  submit(del, async () => {
    const v = del.confirm.value.trim();
    if (v !== store.character?.character_name) throw new Error('캐릭터 이름이 일치하지 않습니다.');
    if (!confirm('정말 정리할까요? 되돌릴 수 없습니다.')) return;
    await rpc('world_character_delete', { p_confirm: v });
    toast('캐릭터를 정리했습니다. 새 조사원을 만드세요.', 'ok');
    await loadCharacter();
  });
  const mail = $('#mail-form', el);
  submit(mail, async () => {
    const v = mail.mail.value.trim(); if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v)) throw new Error('이메일 주소를 확인하세요.');
    const { error } = await db.auth.updateUser({ email: v }); if (error) throw error;
    mail.reset(); toast('인증 메일을 보냈습니다. 메일의 링크를 눌러야 변경이 끝납니다.', 'ok');
  });
}
