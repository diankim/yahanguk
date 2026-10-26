// 계정: 게임 캐릭터와 별개인 로그인 계정 정보. 이메일·비밀번호 변경, 로그아웃.
import { db, store, esc, icon, $, toast, friendlyError } from '../core.js';
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
    </div>`;
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
  const mail = $('#mail-form', el);
  submit(mail, async () => {
    const v = mail.mail.value.trim(); if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v)) throw new Error('이메일 주소를 확인하세요.');
    const { error } = await db.auth.updateUser({ email: v }); if (error) throw error;
    mail.reset(); toast('인증 메일을 보냈습니다. 메일의 링크를 눌러야 변경이 끝납니다.', 'ok');
  });
}
