// 전투 기록을 한 줄씩 보여 준다(비무·수련장 시련). 「건너뛰기」를 누르면 남은 줄을 한꺼번에 펼친다.
// 결과는 서버가 이미 정했고, 화면은 그 기록을 차례로 보일 뿐이다.
export function replayLog(list, items, row, { step = 650, skipBtn, onDone } = {}) {
  let i = 0, timer = null, done = false;
  const reduce = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
  const finish = () => {
    if (done) return; done = true; clearInterval(timer);
    while (i < items.length) list.insertAdjacentHTML('beforeend', row(items[i++], true));
    list.scrollTop = list.scrollHeight;
    if (skipBtn) skipBtn.hidden = true;
    onDone?.();
  };
  const tick = () => {
    if (i >= items.length) return finish();
    list.insertAdjacentHTML('beforeend', row(items[i++], false));
    list.scrollTop = list.scrollHeight;
    if (i >= items.length) finish();
  };
  list.innerHTML = '';
  if (skipBtn) { skipBtn.hidden = false; skipBtn.onclick = finish; }
  if (reduce || !items.length) finish(); else { tick(); timer = setInterval(tick, step); }
  return { skip: finish };
}
