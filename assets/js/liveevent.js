import { esc, $, $$, openLayer } from './core.js';
import { sceneHtml, mountScene } from './scene.js';

export const eventLogHtml = (v, empty) => [...(v?.script || []), ...(v?.lines || [])].sort((a, b) => new Date(a.at) - new Date(b.at))
  .map(x => `<li class="k-${esc(x.k)}"><span>${esc(x.t)}</span></li>`).join('') || empty;

export async function openLiveEvent({ title, cls = '', scene, read, every, over, draw }) {
  const l = openLayer({ title, body: `${sceneHtml()}<div class="wed-box ${cls}"><p class="muted">불러오는 중…</p></div>` });
  const box = $('.wed-box', l), sbox = $('.scene-box', l);
  const ctx = { box, v: null, skew: 0, scene: null, t: null, cd: null };
  ctx.now = () => Date.now() + ctx.skew;
  const alive = () => {
    if (box.isConnected) return true;
    clearInterval(ctx.t); clearInterval(ctx.cd); ctx.scene?.stop();
    return false;
  };
  const redraw = () => {
    if (!alive()) return;
    const v = ctx.v;
    if (v) { if (!ctx.scene) ctx.scene = mountScene(sbox, scene(v)); sbox.hidden = false; ctx.scene.update(v.folks); }
    else sbox.hidden = true;
    draw(ctx, v);
  };
  ctx.set = v => { ctx.v = v; if (v?.now) ctx.skew = new Date(v.now) - Date.now(); redraw(); };
  ctx.wait = (readyAt, slot, btns) => {
    clearInterval(ctx.cd);
    if (!(readyAt > ctx.now())) return;
    const paint = () => {
      if (!alive()) return;
      const left = Math.ceil((readyAt - ctx.now()) / 1000), s = $(slot, box);
      if (s) s.textContent = left > 0 ? ` · ${left}초 뒤 다시` : '';
      if (left <= 0) { clearInterval(ctx.cd); $$(btns, box).forEach(b => { if (!b.dataset.cap) b.disabled = false; }); }
    };
    paint(); ctx.cd = setInterval(paint, 500);
  };
  const pull = async () => {
    try { ctx.set(await read()); if (over(ctx.v)) clearInterval(ctx.t); }
    catch (e) { if (alive()) box.innerHTML = `<p class="bad">${esc(e.message)}</p>`; clearInterval(ctx.t); }
  };
  await pull();
  if (!over(ctx.v)) ctx.t = setInterval(() => { if (alive() && !document.hidden) pull(); }, every);
  return ctx;
}
