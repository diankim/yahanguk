const KEY = 'yh-input-h', AUTO = 160;

export function growInput(form) {
  const ta = form.querySelector('textarea'); if (!ta || form.querySelector('.input-grip')) return () => {};
  const grip = document.createElement('div');
  grip.className = 'input-grip'; grip.setAttribute('role', 'separator'); grip.setAttribute('aria-label', '입력칸 크기 조절 (위로 끌기)'); grip.tabIndex = 0;
  grip.innerHTML = '<i></i>';
  form.prepend(grip);
  const cap = () => Math.round((window.visualViewport?.height || innerHeight) * 0.45);
  let MIN = 34; const readMin = () => { MIN = Math.max(28, parseFloat(getComputedStyle(ta).minHeight) || 34); };
  let manual = 0; try { manual = Number(localStorage.getItem(KEY)) || 0; } catch {}
  const fit = () => {
    readMin();
    ta.style.height = 'auto';
    const need = ta.scrollHeight + 2;
    ta.style.height = `${Math.max(MIN, Math.min(cap(), Math.max(manual, Math.min(need, AUTO))))}px`;
    const cs = getComputedStyle(ta), one = Math.max(MIN, (parseFloat(cs.lineHeight) || 20) + (parseFloat(cs.paddingTop) || 0) + (parseFloat(cs.paddingBottom) || 0) + 2);
    form.style.setProperty('--ta-one', `${Math.round(one)}px`);
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

export function keepKeyboard(form) {
  const b = form.querySelector('button[type=submit]'); if (!b) return;
  let had = false;
  b.addEventListener('pointerdown', () => { had = document.activeElement === form.text; });
  b.addEventListener('mousedown', e => e.preventDefault());
  b.addEventListener('touchend', e => {
    if (document.activeElement !== form.text || b.disabled) return;
    e.preventDefault(); had = true;
    if (form.requestSubmit) form.requestSubmit(b); else form.dispatchEvent(new Event('submit', { cancelable: true, bubbles: true }));
  }, { passive: false });
  form.addEventListener('submit', () => { if (had) form.text.focus({ preventScroll: true }); had = false; }, true);
}
