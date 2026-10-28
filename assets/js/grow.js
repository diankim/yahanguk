// 채팅·귓속말 입력칸: 글이 길어지면 저절로 늘어나고, 입력칸 위 손잡이를 위로 끌면 더 크게 쓸 수 있다.
// 끌어 정한 높이는 이 기기에 남긴다(두 번 누르면 처음 크기로).
const KEY = 'yh-input-h', AUTO = 160;

export function growInput(form) {
  const ta = form.querySelector('textarea'); if (!ta || form.querySelector('.input-grip')) return () => {};
  const grip = document.createElement('div');
  grip.className = 'input-grip'; grip.setAttribute('role', 'separator'); grip.setAttribute('aria-label', '입력칸 크기 조절 (위로 끌기)'); grip.tabIndex = 0;
  grip.innerHTML = '<i></i>';
  form.prepend(grip);
  const cap = () => Math.round((window.visualViewport?.height || innerHeight) * 0.45);
  // 가장 낮은 높이는 입력칸 CSS의 min-height(한 줄 높이)를 따른다. 더 크게 잡으면 한 줄 글이 위로 치우쳐 보인다.
  let MIN = 34; const readMin = () => { MIN = Math.max(28, parseFloat(getComputedStyle(ta).minHeight) || 34); };
  let manual = 0; try { manual = Number(localStorage.getItem(KEY)) || 0; } catch {}
  const fit = () => {
    readMin();
    ta.style.height = 'auto';
    const need = ta.scrollHeight + 2;
    ta.style.height = `${Math.max(MIN, Math.min(cap(), Math.max(manual, Math.min(need, AUTO))))}px`;
  };
  const save = h => { manual = h; try { h ? localStorage.setItem(KEY, String(Math.round(h))) : localStorage.removeItem(KEY); } catch {} fit(); };
  let y0 = 0, h0 = 0;
  const move = e => { manual = Math.max(MIN, Math.min(cap(), h0 + (y0 - e.clientY))); ta.style.height = `${manual}px`; };
  grip.addEventListener('pointerdown', e => {
    e.preventDefault(); y0 = e.clientY; h0 = ta.getBoundingClientRect().height;
    grip.setPointerCapture?.(e.pointerId); grip.classList.add('drag');
    grip.addEventListener('pointermove', move);
    const up = () => { grip.removeEventListener('pointermove', move); grip.classList.remove('drag'); save(manual <= MIN + 4 ? 0 : manual); };
    grip.addEventListener('pointerup', up, { once: true }); grip.addEventListener('pointercancel', up, { once: true });
  });
  grip.addEventListener('dblclick', () => save(0));
  grip.addEventListener('keydown', e => { if (e.key !== 'ArrowUp' && e.key !== 'ArrowDown') return; e.preventDefault(); save(Math.max(MIN, Math.min(cap(), ta.getBoundingClientRect().height + (e.key === 'ArrowUp' ? 40 : -40)))); });
  ta.addEventListener('input', fit);
  requestAnimationFrame(fit);
  return fit;
}
