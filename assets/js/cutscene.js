const LEDGER_CH = '夜行局調査員名簿金李朴崔鄭姜趙尹張林韓吳徐申權黃安宋柳洪全高文孫梁裵白許南沈盧河';

const CSS = `
.cs { position: fixed; inset: 0; z-index: 9000; background: #07060a; color: #e9e2d4; display: grid; grid-template-rows: 1fr auto; font-family: "Noto Serif KR", var(--font-serif, serif); overflow: hidden; }
.cs svg.cs-stage { width: 100%; height: 100%; display: block; }
.cs .cs-sky { fill: #0b0a10; transition: fill 4s linear; }
.cs.dawn .cs-sky { fill: #23222f; } .cs.dawn2 .cs-sky { fill: #5c5866; } .cs.dawn3 .cs-sky { fill: #b9a68a; }
.cs .cs-star { fill: #d8d2c4; animation: cs-twinkle 3.6s ease-in-out infinite; }
.cs .cs-star:nth-child(3n) { animation-duration: 5.2s; } .cs .cs-star:nth-child(4n) { animation-delay: -2s; }
.cs .cs-stars { transition: opacity 5s; }
.cs.mist .cs-stars { opacity: 0; }
@keyframes cs-twinkle { 0%, 100% { opacity: .9; } 50% { opacity: .25; } }
.cs .cs-roof { fill: #030305; }
.cs .cs-rope { fill: none; stroke: #2a2530; stroke-width: 1.5; }
/* 등불: 매단 자리에서 흔들리고 불빛이 일렁인다. dying = 깜빡이다 꺼짐, waking = 깜빡이며 켜짐 */
.cs .cs-lantern { transform-box: fill-box; transform-origin: 50% 0; animation: cs-sway 4.2s ease-in-out infinite alternate; }
.cs [data-lamp]:nth-of-type(2n) .cs-lantern { animation-duration: 5.1s; animation-delay: -1.3s; }
.cs [data-lamp]:nth-of-type(3n) .cs-lantern { animation-duration: 3.7s; animation-delay: -2.2s; }
@keyframes cs-sway { from { transform: rotate(-4deg); } to { transform: rotate(4deg); } }
.cs .cs-body { fill: #d9963c; }
.cs .cs-flame { fill: #ffd27a; animation: cs-flick 1.7s ease-in-out infinite; }
.cs .cs-glow { fill: #e0a64a; filter: url(#cs-soft); opacity: .32; animation: cs-glow 2.3s ease-in-out infinite; }
@keyframes cs-flick { 0%, 100% { opacity: 1; } 30% { opacity: .78; } 55% { opacity: .95; } 70% { opacity: .7; } }
@keyframes cs-glow { 0%, 100% { opacity: .32; } 40% { opacity: .2; } 65% { opacity: .36; } }
.cs .dying .cs-flame, .cs .dying .cs-glow, .cs .dying .cs-body { animation: cs-die 1.4s steps(1, end) forwards; }
@keyframes cs-die { 0% { opacity: 1; } 12% { opacity: .15; } 22% { opacity: .9; } 34% { opacity: .1; } 48% { opacity: .7; } 60% { opacity: .05; } 72% { opacity: .35; } 84%, 100% { opacity: 0; } }
.cs .out .cs-flame, .cs .out .cs-glow { opacity: 0; animation: none; }
.cs .out .cs-body { fill: #2a2420; animation: none; opacity: 1; }
.cs .waking .cs-flame, .cs .waking .cs-glow { animation: cs-wake 2.2s steps(1, end) forwards; }
@keyframes cs-wake { 0% { opacity: 0; } 15% { opacity: .5; } 25% { opacity: 0; } 40% { opacity: .8; } 50% { opacity: .1; } 66% { opacity: 1; } 75% { opacity: .4; } 100% { opacity: 1; } }
.cs .cs-zone { fill: #8f877a; font-size: 10px; text-anchor: middle; font-family: "Noto Sans KR", var(--font-sans, sans-serif); transition: fill 1.2s; }
.cs .cs-zone.off { fill: #4a443e; }
/* 붉은 안개: 잡음 결을 흐리게 번진 두 겹이 서로 다른 빠르기로 흐르고, 위로 갈수록 옅다 */
.cs .cs-mist { opacity: 0; transform: translateY(40px); transition: opacity 4s linear, transform 9s ease-out; }
.cs.mist .cs-mist { opacity: .7; transform: translateY(-10px); }
.cs.mist2 .cs-mist { opacity: .95; transform: translateY(-60px); }
.cs .cs-flow-a { animation: cs-flow 70s linear infinite; }
.cs .cs-flow-b { animation: cs-flow 46s linear infinite reverse; }
@keyframes cs-flow { from { transform: translateX(0); } to { transform: translateX(-960px); } }
/* 장부: 한지 위 세로 글씨, 낙관, 번지는 먹 */
.cs .cs-ledger { opacity: 0; transition: opacity 1.6s; pointer-events: none; }
.cs.ledger .cs-ledger { opacity: 1; }
.cs .cs-paper { transform-box: fill-box; transform-origin: center; transform: translateY(14px) scale(.97); transition: transform 2.4s cubic-bezier(.2,.7,.2,1); }
.cs.ledger .cs-paper { transform: none; }
.cs .cs-writing { transition: filter 6s ease-in, opacity 7s ease-in; }
.cs.ink .cs-writing { filter: blur(2.5px); opacity: .15; }
.cs .cs-seal { opacity: 0; transform-box: fill-box; transform-origin: center; }
.cs.cs-stamped .cs-seal { animation: cs-stamp .9s cubic-bezier(.3,0,.4,1) forwards; }
@keyframes cs-stamp { 0% { opacity: 0; transform: translate(-6px, -26px) scale(1.5) rotate(-9deg); } 55% { opacity: 1; transform: translate(0, 0) scale(.96) rotate(-3deg); } 70% { opacity: 1; transform: scale(1.02) rotate(-3deg); } 100% { opacity: 1; transform: scale(1) rotate(-3deg); } }
.cs .cs-ink { transform-box: fill-box; transform-origin: center; transform: scale(0); }
.cs.ink .cs-ink { animation: cs-bleed 8s cubic-bezier(.3,.1,.3,1) forwards; }
.cs.ink .cs-ink.b { animation-delay: 1.6s; } .cs.ink .cs-ink.c { animation-delay: 3s; }
@keyframes cs-bleed { from { transform: scale(0); } to { transform: scale(1.1); } }
.cs .cs-sun { fill: #f4dca6; filter: url(#cs-soft); opacity: 0; transform: translateY(60px); transition: opacity 4s, transform 8s cubic-bezier(.2,.6,.2,1); }
.cs.dawn2 .cs-sun { opacity: .6; transform: translateY(24px); }
.cs.dawn3 .cs-sun { opacity: 1; transform: none; }
.cs .cs-title { opacity: 0; transition: opacity 3s; fill: #e9e2d4; font-size: 26px; letter-spacing: .4em; text-anchor: middle; }
.cs.fin .cs-title { opacity: 1; }
.cs.dawn3 .cs-title { fill: #3a2a1c; }
.cs-box { min-height: 128px; padding: 18px max(16px, env(safe-area-inset-left)) max(22px, env(safe-area-inset-bottom)); border-top: 1px solid #2a2530; background: #0b0a10; display: grid; gap: 6px; align-content: start; }
.cs-who { font-size: 13px; color: #e0a64a; letter-spacing: .06em; min-height: 18px; }
.cs-text { font-size: 17px; line-height: 1.75; white-space: pre-line; }
.cs-text.nar { color: #b9b0a2; }
.cs-text.note { font-size: 14.5px; line-height: 1.7; }
.cs-line-in { animation: cs-line .9s cubic-bezier(.2,.7,.2,1) both; }
@keyframes cs-line { from { opacity: 0; transform: translateY(8px); filter: blur(3px); } to { opacity: 1; transform: none; filter: none; } }
.cs-tr { position: absolute; top: max(12px, env(safe-area-inset-top)); right: max(12px, env(safe-area-inset-right)); display: flex; gap: 8px; z-index: 2; }
.cs-help { padding: 6px 14px; border: 1px solid #e0a64a; border-radius: 999px; background: rgb(11 10 16 / .8); color: #f2e6cc; font: 600 13px "Noto Sans KR", sans-serif; text-decoration: none; }
.cs-help:focus-visible { outline: 2px solid #e0a64a; }
.cs-skip { padding: 6px 14px; border: 1px solid #3a3440; border-radius: 999px; background: rgb(11 10 16 / .8); color: #b9b0a2; font: 13px "Noto Sans KR", sans-serif; cursor: pointer; z-index: 2; }
.cs-skip:focus-visible { outline: 2px solid #e0a64a; }
.cs-snd { position: absolute; top: max(12px, env(safe-area-inset-top)); left: max(12px, env(safe-area-inset-left)); padding: 6px 14px; border: 1px solid #3a3440; border-radius: 999px; background: rgb(11 10 16 / .8); color: #b9b0a2; font: 13px "Noto Sans KR", sans-serif; cursor: pointer; z-index: 2; }
.cs-snd.on { color: #e0a64a; border-color: #5a4a30; }
.cs-snd.ask { color: #f2e6cc; border-color: #e0a64a; animation: cs-ask 1.6s ease-in-out infinite; }
@keyframes cs-ask { 50% { border-color: #5a4a30; color: #b9b0a2; } }
.cs-snd:focus-visible { outline: 2px solid #e0a64a; }
.cs-end { display: flex; gap: 8px; justify-content: flex-end; animation: cs-line .9s cubic-bezier(.2,.7,.2,1) both; }
.cs-btn { min-height: 40px; padding: 8px 18px; border-radius: 999px; border: 1px solid #3a3440; background: transparent; color: #d8d0c2; font: 600 14px "Noto Sans KR", sans-serif; cursor: pointer; }
.cs-btn.main { border-color: #e0a64a; color: #f2e6cc; }
.cs-btn:focus-visible { outline: 2px solid #e0a64a; outline-offset: 2px; }
/* 로그인 배경(loginBackdrop): 화면 뒤에 깔고 글 상자·제목은 없다. 빠르게(fast) 그릴 때는 바뀜 효과 없이 */
.cs.cs-bg { z-index: 0; grid-template-rows: 1fr; pointer-events: none; }
.cs.cs-bg .cs-bg-in { position: relative; overflow: hidden; height: 100%; }
.cs.cs-bg svg.cs-stage { position: absolute; inset: 0; }
.cs.cs-bg .cs-title { display: none; }
.cs.cs-bg .cs-rope { display: none; }
/* 휴대폰: 로그인 창이 떠오를 때 해·등불도 함께 올라와 머리글과 창 사이에 걸린다 */
.cs.cs-bg svg.cs-stage { transition: transform 1.4s cubic-bezier(.2,.7,.2,1); }
.cs.cs-bg[data-fast] svg.cs-stage { transition: none; }
@media (max-width: 640px) { .cs.cs-bg.lift svg.cs-stage { transform: translateY(calc(-12.5svh - 38px)); } }
.cs.cs-bg .cs-sky { transition-duration: 1.6s; }
.cs.cs-bg .cs-sun { transition-duration: 2s, 3.2s; }
.cs.cs-bg[data-fast] .cs-sky, .cs.cs-bg[data-fast] .cs-sun { transition: none; }
.cs.cs-bg[data-quick] svg.cs-stage { transition-duration: .8s; }
.cs.cs-bg[data-quick] .cs-sky { transition-duration: .8s; }
.cs.cs-bg[data-quick] .cs-sun { transition-duration: 1s, 1.6s; }
.cs.cs-bg[data-quick] .waking .cs-flame, .cs.cs-bg[data-quick] .waking .cs-glow { animation-duration: 1.1s; }
@media (prefers-reduced-motion: reduce) {
  .cs .cs-lantern, .cs .cs-flame, .cs .cs-glow, .cs .cs-star, .cs .cs-flow-a, .cs .cs-flow-b { animation: none !important; }
}
`;

let seed = 7;
const rnd = () => (seed = (seed * 9301 + 49297) % 233280) / 233280;

const lantern = (x, y, i, label) => `<g data-lamp="${i}">
  <g class="cs-lantern"><line x1="${x}" y1="${y - 14}" x2="${x}" y2="${y - 8}" stroke="#2a2530" stroke-width="1"/>
    <circle class="cs-glow" cx="${x}" cy="${y}" r="17"/>
    <rect class="cs-body" x="${x - 5}" y="${y - 8}" width="10" height="15" rx="4"/>
    <rect x="${x - 5}" y="${y - 9}" width="10" height="2" fill="#3a2a1c"/><rect x="${x - 5}" y="${y + 6}" width="10" height="2" fill="#3a2a1c"/>
    <ellipse class="cs-flame" cx="${x}" cy="${y}" rx="2.6" ry="4"/></g>
  ${label ? `<text class="cs-zone" x="${x}" y="${i % 2 ? y - 20 : y + 28}">${label}</text>` : ''}</g>`;

const DEFS = `<defs>
  <filter id="cs-soft" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="6"/></filter>
  <filter id="cs-blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14"/></filter>
  <filter id="cs-turb" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency="0.012 0.04" numOctaves="3" seed="11"/>
    <feColorMatrix values="0 0 0 0 0.52  0 0 0 0 0.07  0 0 0 0 0.11  2.2 0 0 0 -0.72"/><feGaussianBlur stdDeviation="2"/></filter>
  <linearGradient id="cs-fade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".22" stop-color="#fff" stop-opacity=".3"/><stop offset=".5" stop-color="#fff" stop-opacity=".75"/><stop offset=".8" stop-color="#fff"/></linearGradient>
  <mask id="cs-mist-mask" maskUnits="userSpaceOnUse" x="-2000" y="120" width="4480" height="2200"><rect x="-2000" y="120" width="4480" height="280" fill="url(#cs-fade)"/><rect x="-2000" y="400" width="4480" height="2000" fill="#fff"/></mask>
  <filter id="cs-hanji" x="-5%" y="-5%" width="110%" height="110%">
    <feTurbulence type="turbulence" baseFrequency="0.06" numOctaves="2" seed="2" result="edge"/>
    <feDisplacementMap in="SourceGraphic" in2="edge" scale="5" result="torn"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.9 0.06" numOctaves="2" seed="4" result="fiber"/>
    <feColorMatrix in="fiber" values="0 0 0 0 0.42  0 0 0 0 0.35  0 0 0 0 0.25  0 0 0 0.28 0" result="fiberC"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.018" numOctaves="3" seed="8" result="blot"/>
    <feColorMatrix in="blot" values="0 0 0 0 0.55  0 0 0 0 0.44  0 0 0 0 0.28  0 0 0 0.45 -0.12" result="blotC"/>
    <feComposite in="fiberC" in2="torn" operator="in" result="f1"/><feComposite in="blotC" in2="torn" operator="in" result="b1"/>
    <feMerge><feMergeNode in="torn"/><feMergeNode in="b1"/><feMergeNode in="f1"/></feMerge></filter>
  <filter id="cs-brush" x="-10%" y="-10%" width="120%" height="120%"><feTurbulence type="fractalNoise" baseFrequency="0.8" numOctaves="1" seed="3" result="n"/>
    <feDisplacementMap in="SourceGraphic" in2="n" scale="1.4"/></filter>
  <filter id="cs-sealtex" x="-10%" y="-10%" width="120%" height="120%">
    <feTurbulence type="fractalNoise" baseFrequency="0.55" numOctaves="2" seed="9" result="n"/>
    <feColorMatrix in="n" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -2.6 1.75" result="holes"/>
    <feComposite in="SourceGraphic" in2="holes" operator="in" result="worn"/>
    <feTurbulence type="turbulence" baseFrequency="0.09" numOctaves="2" seed="5" result="e"/>
    <feDisplacementMap in="worn" in2="e" scale="1.6"/></filter>
  <filter id="cs-inkf" x="-60%" y="-60%" width="220%" height="220%">
    <feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="4" seed="21" result="n"/>
    <feDisplacementMap in="SourceGraphic" in2="n" scale="34" result="d"/>
    <feGaussianBlur in="d" stdDeviation="1.4" result="soft"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.5" numOctaves="1" seed="6" result="g"/>
    <feColorMatrix in="g" values="0 0 0 0 0.1  0 0 0 0 0.085  0 0 0 0 0.085  0 0 0 0.12 0" result="gc"/>
    <feComposite in="gc" in2="soft" operator="in" result="grain"/>
    <feMerge><feMergeNode in="soft"/><feMergeNode in="grain"/></feMerge></filter>
</defs>`;

function scene(kind) {
  seed = 3;
  const lamps = lantern(240, 150, 9, '');
  const mist = (cls, y, op) => `<g class="${cls}"><g filter="url(#cs-blur)"><rect x="-480" y="${y}" width="2400" height="900" filter="url(#cs-turb)" opacity="${op}"/></g></g>`;
  return `<svg class="cs-stage" viewBox="0 0 480 240" preserveAspectRatio="xMidYMid meet" overflow="visible" aria-hidden="true">${DEFS}
    <rect class="cs-sky" x="-2000" y="-2000" width="4480" height="4240"/>
    <circle class="cs-sun" cx="240" cy="120" r="36"/>
    <path class="cs-roof" d="M-2000 2000V170H30L58 154L86 170H120V180H150L190 150L230 180H250L290 156L330 180H350V172H380L410 154L440 172H2480V2000Z"/>
    <path class="cs-rope" d="M10 118Q120 150 240 124T470 128"/>
    ${lamps}
    <g class="cs-mist" mask="url(#cs-mist-mask)">${mist('cs-flow-a', 150, .85)}${mist('cs-flow-b', 190, .7)}<rect x="-2000" y="300" width="4480" height="2000" fill="#5c121b" filter="url(#cs-blur)"/></g>
    <text class="cs-title" x="240" y="62">아 침</text>
    <text class="cs-title" x="240" y="90" style="font-size:13px;letter-spacing:.12em"></text>
  </svg>`;
}

const wake = root => { const l = root.querySelector('[data-lamp="9"] .cs-lantern'); l?.classList.remove('out'); l?.classList.add('waking'); };

const MORNING = [
  [null, '긴 밤이 끝났다.', r => r.querySelector('[data-lamp="9"] .cs-lantern')?.classList.add('out')],
  [null, '정청의 등불 하나가 깜빡이며 다시 살아난다.', r => { wake(r); r.classList.add('dawn'); }],
  [null, '닭이 운다. 먼 산마루가 희게 밝아 온다.', r => r.classList.add('dawn2')],
  [null, '당신은 이름 하나를 쥐고 정청 앞에 서 있다.\n지난 일은 꿈처럼 흐릿하다.', r => r.classList.add('dawn3')],
  [null, '', r => r.classList.add('fin')],
];

const MUSIC = {
  morning: { url: new URL('../audio/cutscene_morning.mp3', import.meta.url).href, resolve: 12.6316, clamp: 20, outro: 28.4212, loopStart: 53.6844063, loopEnd: 78.9476563 },
};
const musicBufs = {};
function cutsceneMusic(M, onState) {
  let musicBuf = musicBufs[M.url] || null;
  let ac = null, gain = null, src = null, since = 0, want = true, vol = 0.6, dead = false, at0 = 0, off0 = 0;
  try { const s = JSON.parse(localStorage.getItem('yh-sound') || '{}'); if (s.bgmOn === false) want = false; if (typeof s.bgm === 'number') vol = Math.min(1, s.bgm * 1.5); if (typeof s.vol === 'number') vol *= Math.max(0, Math.min(1, s.vol)); } catch {}
  vol *= M.vol ?? 1;
  try { if (localStorage.getItem('yh-cs-sound') === 'off') want = false; else if (localStorage.getItem('yh-cs-sound') === 'on') want = true; } catch {}
  const MOBILE = (() => { try { return matchMedia('(pointer: coarse)').matches; } catch { return false; } })();
  const load = musicBuf ? Promise.resolve(musicBuf) : fetch(M.url).then(r => { if (!r.ok) throw 0; return r.arrayBuffer(); });
  const ensure = () => {
    if (ac) return ac;
    const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return null;
    ac = new AC(); gain = ac.createGain(); gain.gain.value = 0; gain.connect(ac.destination);
    ac.onstatechange = () => { if (ac.state === 'running' && want && !src && musicBuf && !dead) startAt(api.sceneTime()); onState(api.on, want); };
    return ac;
  };
  const playing = () => !!src && ac?.state === 'running';
  function startAt(offset) {
    if (dead || !ac || !musicBuf) return;
    if (src) { try { src.stop(); } catch {} src = null; }
    src = ac.createBufferSource(); src.buffer = musicBuf;
    src.loop = true; src.loopStart = M.loopStart; src.loopEnd = Math.min(M.loopEnd, musicBuf.duration);
    src.connect(gain);
    const t = ac.currentTime;
    gain.gain.cancelScheduledValues(t); gain.gain.setValueAtTime(0.0001, t); gain.gain.linearRampToValueAtTime(vol, t + (offset > 1 ? 1.6 : 0.4));
    src.start(t, Math.min(offset, musicBuf.duration - 0.1)); at0 = t; off0 = offset; since = performance.now();
  }
  const api = {
    sceneTime: () => 0,
    get on() { return want && playing(); },
    get heard() { return api.on && performance.now() - since > 500; },
    async toggle(wasOn) {
      if (!wasOn && want) { await api.resume(); return; }
      want = !wasOn; try { localStorage.setItem('yh-cs-sound', want ? 'on' : 'off'); } catch {}
      if (want) await api.resume(); else { if (ac) { const t = ac.currentTime; gain.gain.cancelScheduledValues(t); gain.gain.setTargetAtTime(0, t, 0.25); setTimeout(() => { if (!want && src) { try { src.stop(); } catch {} src = null; } }, 900); } }
      onState(api.on, want);
    },
    async resume() {
      if (!dead && !want) { onState(false, false); return; }
      if (dead || !ensure()) return;
      try { if (ac.state !== 'running') await Promise.race([ac.resume(), new Promise(r => setTimeout(r, 400))]); } catch {}
      if (!musicBuf) { try { const b = await load; musicBuf = musicBufs[M.url] = b instanceof AudioBuffer ? b : await ac.decodeAudioData(b); } catch { onState(null); return; } }
      if (ac.state === 'running' && !src && want) startAt(api.sceneTime());
      onState(api.on, want);
    },
    jumpToResolve() {
      if (!playing()) return;
      const pos = off0 + (ac.currentTime - at0);
      if (pos >= M.resolve - 1) return;
      const t = ac.currentTime; gain.gain.cancelScheduledValues(t); gain.gain.setTargetAtTime(0, t, 0.12);
      setTimeout(() => { if (want && !dead) startAt(M.resolve); }, 450);
    },
    stop(fade = 1) {
      dead = true; document.removeEventListener('visibilitychange', vis);
      if (!ac) return;
      const t = ac.currentTime; gain.gain.cancelScheduledValues(t); gain.gain.setTargetAtTime(0, t, fade / 3);
      setTimeout(() => { try { src?.stop(); } catch {} ac.close?.().catch(() => {}); }, fade * 1000 + 200);
    },
  };
  const vis = () => { if (!ac || !MOBILE) return; if (document.hidden) ac.suspend().catch(() => {}); else if (want) ac.resume().catch(() => {}); };
  document.addEventListener('visibilitychange', vis);
  load.catch(() => onState(null));
  return api;
}

let activeLogin = null;
export function loginMusic() {
  if (activeCs) return () => {};
  activeLogin?.(0.2);
  const M = { ...MUSIC.morning, vol: 0.7 };
  window.dispatchEvent(new CustomEvent('yh-cutscene', { detail: true }));
  const music = cutsceneMusic(M, () => {});
  music.sceneTime = () => M.loopStart;
  const kick = () => { if (!music.on) music.resume(); };
  document.addEventListener('pointerdown', kick);
  music.resume();
  let done = false;
  const stop = (fade = 1.5) => { if (done) return; done = true; if (activeLogin === stop) activeLogin = null; document.removeEventListener('pointerdown', kick); music.stop(fade); if (!activeCs) window.dispatchEvent(new CustomEvent('yh-cutscene', { detail: false })); };
  activeLogin = stop;
  return () => stop();
}

let bgSeen = false;
export function loginBackdrop(host, { onReady, quick = false } = {}) {
  if (!document.getElementById('cs-style')) document.head.append(Object.assign(document.createElement('style'), { id: 'cs-style', textContent: CSS }));
  const root = document.createElement('div');
  root.className = 'cs cs-bg'; root.setAttribute('aria-hidden', 'true');
  root.innerHTML = `<div class="cs-bg-in">${scene('morning').replace('preserveAspectRatio="xMidYMid meet"', 'preserveAspectRatio="xMidYMax slice"')}</div>`;
  host.prepend(root);
  const fast = bgSeen || matchMedia('(prefers-reduced-motion: reduce)').matches;
  bgSeen = true;
  const lamp = root.querySelector('[data-lamp="9"] .cs-lantern');
  const timers = [];
  const at = (ms, f) => timers.push(setTimeout(f, ms));
  if (fast) {
    root.dataset.fast = '1';
    root.classList.add('dawn', 'dawn2', 'dawn3', 'lift');
    onReady?.();
  } else {
    const k = quick ? 0.5 : 1;
    if (quick) root.dataset.quick = '1';
    lamp?.classList.add('out');
    at(700 * k, () => { lamp?.classList.remove('out'); lamp?.classList.add('waking'); root.classList.add('dawn'); });
    at(2300 * k, () => root.classList.add('dawn2'));
    at(3600 * k, () => root.classList.add('dawn3'));
    at(4300 * k, () => { root.classList.add('lift'); onReady?.(); });
  }
  return () => { timers.forEach(clearTimeout); root.remove(); };
}

let activeCs = null;
export function playCutscene(kind = 'morning', { onEnd, stay = false, note = '', atEnd = false, fixed = false, logout = null } = {}) {
  activeCs?.(); activeCs = null;
  activeLogin?.(0.2);
  if (!document.getElementById('cs-style')) document.head.append(Object.assign(document.createElement('style'), { id: 'cs-style', textContent: CSS }));
  const lines = MORNING;
  const root = document.createElement('div');
  root.className = 'cs'; root.setAttribute('role', 'dialog'); root.setAttribute('aria-label', '아침');
  root.innerHTML = `<div style="position:relative;overflow:hidden">${scene(kind)}<button type="button" class="cs-snd" hidden>소리 켜기</button><div class="cs-tr"><button type="button" class="cs-skip">건너뛰기</button>${stay ? '<a class="cs-help" href="help.html">도움말</a>' : ''}</div></div>
    <div class="cs-box" aria-live="polite"><div class="cs-who"></div><div class="cs-text"></div></div>`;
  document.body.append(root);
  const who = root.querySelector('.cs-who'), text = root.querySelector('.cs-text');
  let i = -1, timer = 0, done = false;
  const t0 = performance.now();
  window.dispatchEvent(new CustomEvent('yh-cutscene', { detail: true }));
  let ended = false, endedAt = 0, music = null;
  {
    const M = MUSIC.morning;
    const btn = root.querySelector('.cs-snd');
    music = cutsceneMusic(M, (on, want) => { if (on === null) { btn.hidden = true; return; } btn.hidden = false; btn.classList.toggle('on', !!on); btn.classList.toggle('ask', !on && !!want); btn.textContent = on ? '소리 끄기' : '소리 켜기'; });
    music.sceneTime = () => ended ? (performance.now() - endedAt < 15000 && !atEnd ? Math.max(M.resolve, Math.min((performance.now() - t0) / 1000, M.clamp)) : M.outro) : Math.min((performance.now() - t0) / 1000, M.clamp);
    let wasOn = null;
    btn.addEventListener('pointerdown', e => { e.stopPropagation(); wasOn = music.heard; });
    btn.addEventListener('click', e => { e.stopPropagation(); music.toggle(wasOn ?? music.heard); wasOn = null; });
    root.addEventListener('pointerdown', () => { if (!music.on) music.resume(); }, { once: true });
    btn.hidden = false; btn.classList.add('ask');
    music.resume();
  }
  activeCs = () => { if (done) return; done = true; clearTimeout(timer); music?.stop(0.2); root.remove(); };
  const finish = () => {
    if (done) return; done = true; if (activeCs) activeCs = null; clearTimeout(timer); music?.stop(1); window.dispatchEvent(new CustomEvent('yh-cutscene', { detail: false }));
    root.style.transition = 'opacity 1s'; root.style.opacity = '0';
    setTimeout(() => { root.remove(); onEnd?.(); }, 1000);
  };
  const step = () => {
    if (ended) return;
    clearTimeout(timer);
    i++;
    const [s, t, fx] = lines[i];
    who.textContent = s || '';
    text.textContent = t;
    text.classList.toggle('nar', !s);
    for (const el of [who, text]) { el.classList.remove('cs-line-in'); void el.offsetWidth; el.classList.add('cs-line-in'); }
    fx?.(root);
    if (i === lines.length - 1) { timer = setTimeout(showEnd, 2600); return; }
    timer = setTimeout(step, t ? 2200 + t.length * 75 : 6000);
  };
  const skip = root.querySelector('.cs-skip');
  const jumpToEnd = () => {
    if (done || ended) return;
    clearTimeout(timer);
    root.dataset.fast = '1';
    for (let k = Math.max(0, i + 1); k < lines.length; k++) lines[k][2]?.(root);
    music?.jumpToResolve();
    i = lines.length - 1;
    who.textContent = ''; text.textContent = '';
    showEnd();
  };
  skip.addEventListener('click', jumpToEnd);
  function showEnd() {
    if (done || ended) return;
    ended = true; endedAt = performance.now(); skip.hidden = true;
    if (note) { who.textContent = ''; text.textContent = note; text.classList.add('nar', 'note'); text.classList.remove('cs-line-in'); void text.offsetWidth; text.classList.add('cs-line-in'); }
    const bar = document.createElement('div'); bar.className = 'cs-end';
    bar.innerHTML = (fixed ? '' : '<button type="button" class="cs-btn" data-again>다시 보기</button>') + (stay ? '' : '<button type="button" class="cs-btn main" data-close>닫기</button>') + (logout ? '<button type="button" class="cs-btn" data-logout>로그아웃</button>' : '');
    root.querySelector('.cs-box').append(bar);
    bar.querySelector('[data-close]')?.addEventListener('click', finish);
    bar.querySelector('[data-logout]')?.addEventListener('click', () => { music?.stop(0.3); root.remove(); logout(); });
    bar.querySelector('[data-again]')?.addEventListener('click', () => { if (done) return; done = true; clearTimeout(timer); music?.stop(0.3); root.remove(); playCutscene(kind, { onEnd, stay, note }); });
  }
  if (atEnd) { i = -1; jumpToEnd(); return finish; }
  setTimeout(step, 1200);
  return finish;
}
