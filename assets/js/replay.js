export function replayLog(list, items, row, { step = 550, skipBtn, onDone } = {}) {
  let i = 0, timer = null, done = false;
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
  if (!items.length) finish(); else { tick(); timer = setInterval(tick, step); }
  return { skip: finish };
}
