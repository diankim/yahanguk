// 정청 기록고(1.0.0): 첫째 밤(시험 기간)을 지난 조사원들의 기록을 명부 정리로 반쯤 지워진 장부 조각처럼 보인다.
// 서버 world_legacy_records(롤백 직전 world_legacy_marks에 찍어 둔 이름·레벨·직업·세력·있던 곳·마친 장·대표 칭호).
// 글자 깨짐은 이름마다 같은 모양(씨앗)으로 정해 열 때마다 바뀌지 않는다.
import { rpc, esc, icon, openModal } from '../core.js';

const BLOCK = '█▓▒░';
const JAMO = 'ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎㅏㅓㅗㅜㅡㅣ';
function seeded(seed) { let h = 2166136261; for (const ch of seed) { h ^= ch.codePointAt(0); h = Math.imul(h, 16777619); } return () => ((h = Math.imul(h ^ (h >>> 15), 2246822507) ^ Math.imul(h ^ (h >>> 13), 3266489909)) >>> 0) / 4294967296; }
// 글자 하나하나를 일정 확률로 깨뜨린다. 깨진 글자는 <i>로 감싸 화면이 아주 가끔 떨리게 한다
function rot(text, seed, rate) {
  const r = seeded(seed + text);
  return [...String(text ?? '')].map(ch => {
    if (ch === ' ' || r() >= rate) return esc(ch);
    const pool = r() < 0.6 ? BLOCK : JAMO;
    return `<i>${pool[Math.floor(r() * pool.length)]}</i>`;
  }).join('');
}
// 칸 하나가 통째로 지워진 줄
const gone = (seed, n = 4) => `<i>${'▒'.repeat(2 + Math.floor(seeded(seed)() * n))}</i>`;

export async function openLegacyRecords() {
  const m = openModal({ title: '정청 기록고', wide: true, body: `<div class="lr-body"><p class="muted small">장부를 펼치는 중…</p></div>` });
  const box = m.querySelector('.lr-body');
  let list = [];
  try { list = await rpc('world_legacy_records'); } catch (e) { box.innerHTML = `<p class="bad small">${esc(e.message || '기록고를 열지 못했습니다.')}</p>`; return; }
  if (!list.length) { box.innerHTML = '<p class="muted">남은 기록이 없습니다.</p>'; return; }
  box.innerHTML = `
    <p class="lr-lead">「명부 정리」로 먹을 거둔 뒤에 남은 장부 조각이다. 첫째 밤에 이 땅을 걸었던 이름들이 반쯤 지워진 채 묶여 있다.
      정청 서기는 이 묶음을 「끝나지 않은 밤의 기록」이라 부르고, 더 거두지 않았다.</p>
    <ol class="lr-list">${list.map((x, i) => {
      const s = x.name + i;
      const rate = x.mine ? 0.12 : 0.34; // 내 기록은 조금 덜 지워져 있다
      return `<li class="lr-row ${x.mine ? 'mine' : ''}">
        <b class="lr-name">${rot(x.name, s, rate)}</b>
        <span>${x.level ? `Lv.${rot(String(x.level), s + 'l', rate)}` : gone(s + 'l')} · ${x.job ? rot(x.job, s + 'j', rate) : gone(s + 'j')}${x.faction ? ` · ${rot(x.faction, s + 'f', rate)}` : ''}</span>
        <span class="muted">마지막으로 머문 곳 ${x.location ? rot(x.location, s + 'p', rate + 0.1) : gone(s + 'p', 6)} · 이야기 ${rot(String(x.chapters), s + 'c', rate)}장</span>
        ${x.title ? `<span class="lr-title">「${rot(x.title, s + 't', rate)}」</span>` : ''}
        ${x.mine ? `<small class="lr-mine">${icon('scroll', 12)} 이 글씨는 어딘가 낯이 익다.</small>` : ''}
      </li>`;
    }).join('')}</ol>
    <p class="muted small">장부 끝에는 붉은 인주 자국 하나가 남아 있다. 「이름이 장부에 남아 있으면, 아침은 다시 온다.」</p>`;
}
