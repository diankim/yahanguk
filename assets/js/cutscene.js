// 컷씬: 롤백 순간(점검 페이지, maintenance.json scene 'rollback')과 다시 연 뒤 첫 접속의 「아침」(캐릭터 만들기 앞).
// 다른 모듈에 기대지 않는다(점검 중에도 돈다). 글은 저절로 흘러가고, 「건너뛰기」는 마지막 장면으로 보내며, 마지막 장면의 [닫기]로만 닫는다(롤백 점검 중에는 닫기 없음).
// 게임 화면은 평면이 원칙이지만 컷씬만은 사용자 요청으로 흐림·질감(SVG 잡음 필터)을 써 실감 나게 그린다.
// 움직임 줄이기 설정이면 흔들림·흐름은 멈추고 장면 전환만 남는다.

const ZONES = ['반요촌', '무극 관성대', '십삼문 암시장', '철벽 고찰', '잔불촌', '백골 장터', '구름나루', '백등 야시장', '본부 객사', '본부 정청'];
// 장부 세로줄에 적힌 이름 자리(읽히지 않게 한자 낱자를 섞는다)
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
/* 불티: 안개에서 붉은 재가 떠오른다 */
.cs-embers { position: absolute; inset: 0; pointer-events: none; opacity: 0; transition: opacity 3s; }
.cs.mist .cs-embers { opacity: 1; }
.cs.ledger .cs-embers { opacity: .25; }
.cs-embers i { position: absolute; bottom: -10px; border-radius: 50%; background: #ff7a4a; box-shadow: 0 0 6px 2px rgb(255 90 50 / .5); animation: cs-rise linear infinite; opacity: 0; }
@keyframes cs-rise { 0% { transform: translate(0, 0); opacity: 0; } 10% { opacity: .9; } 70% { opacity: .55; } 100% { transform: translate(var(--dx), -70vh); opacity: 0; } }
/* 장부: 한지 위 세로 글씨, 낙관, 번지는 먹 */
.cs .cs-ledger { opacity: 0; transition: opacity 1.6s; pointer-events: none; }
.cs.ledger .cs-ledger { opacity: 1; }
.cs .cs-paper { transform-box: fill-box; transform-origin: center; transform: translateY(14px) scale(.97); transition: transform 2.4s cubic-bezier(.2,.7,.2,1); }
.cs.ledger .cs-paper { transform: none; }
.cs .cs-writing { transition: filter 6s ease-in, opacity 7s ease-in; }
.cs.ink .cs-writing { filter: blur(2.5px); opacity: .15; }
.cs .cs-seal { opacity: 0; transform-box: fill-box; transform-origin: center; }
.cs.seal .cs-seal { animation: cs-stamp .9s cubic-bezier(.3,0,.4,1) forwards; }
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
.cs-skip { position: absolute; top: max(12px, env(safe-area-inset-top)); right: max(12px, env(safe-area-inset-right)); padding: 6px 14px; border: 1px solid #3a3440; border-radius: 999px; background: rgb(11 10 16 / .8); color: #b9b0a2; font: 13px "Noto Sans KR", sans-serif; cursor: pointer; z-index: 2; }
.cs-skip:focus-visible { outline: 2px solid #e0a64a; }
.cs-snd { position: absolute; top: max(12px, env(safe-area-inset-top)); left: max(12px, env(safe-area-inset-left)); padding: 6px 14px; border: 1px solid #3a3440; border-radius: 999px; background: rgb(11 10 16 / .8); color: #b9b0a2; font: 13px "Noto Sans KR", sans-serif; cursor: pointer; z-index: 2; }
.cs-snd.on { color: #e0a64a; border-color: #5a4a30; }
.cs-snd:focus-visible { outline: 2px solid #e0a64a; }
.cs-end { display: flex; gap: 8px; justify-content: flex-end; animation: cs-line .9s cubic-bezier(.2,.7,.2,1) both; }
.cs-btn { min-height: 40px; padding: 8px 18px; border-radius: 999px; border: 1px solid #3a3440; background: transparent; color: #d8d0c2; font: 600 14px "Noto Sans KR", sans-serif; cursor: pointer; }
.cs-btn.main { border-color: #e0a64a; color: #f2e6cc; }
.cs-btn:focus-visible { outline: 2px solid #e0a64a; outline-offset: 2px; }
@media (prefers-reduced-motion: reduce) {
  .cs .cs-lantern, .cs .cs-flame, .cs .cs-glow, .cs .cs-star, .cs .cs-flow-a, .cs .cs-flow-b { animation: none !important; }
  .cs-embers { display: none; }
}
`;

let seed = 7;
const rnd = () => (seed = (seed * 9301 + 49297) % 233280) / 233280;

// 매단 등불 하나: 줄 → 몸통 → 불꽃 → 번지는 빛. 흔들림은 매단 자리(위)를 축으로.
const lantern = (x, y, i, label) => `<g data-lamp="${i}">
  <g class="cs-lantern"><line x1="${x}" y1="${y - 14}" x2="${x}" y2="${y - 8}" stroke="#2a2530" stroke-width="1"/>
    <circle class="cs-glow" cx="${x}" cy="${y}" r="17"/>
    <rect class="cs-body" x="${x - 5}" y="${y - 8}" width="10" height="15" rx="4"/>
    <rect x="${x - 5}" y="${y - 9}" width="10" height="2" fill="#3a2a1c"/><rect x="${x - 5}" y="${y + 6}" width="10" height="2" fill="#3a2a1c"/>
    <ellipse class="cs-flame" cx="${x}" cy="${y}" rx="2.6" ry="4"/></g>
  ${label ? `<text class="cs-zone" x="${x}" y="${i % 2 ? y - 20 : y + 28}">${label}</text>` : ''}</g>`;

// 한지: 미색 바탕에 섬유 결(가는 잡음)과 얼룩(굵은 잡음), 찢긴 듯 울퉁불퉁한 가장자리 / 붓글씨 번짐 / 낙관의 닳은 자국 / 번지는 먹
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

function ledger() {
  seed = 7;
  // 가운데 놓인 장부 한 장(240×172). 오른쪽에서 왼쪽으로 세로줄, 첫 줄은 제목
  const px = 120, py = 34, pw = 240, ph = 172;
  const cols = [];
  for (let c = 0; c < 9; c++) {
    const x = px + pw - 22 - c * 22, n = c === 0 ? 5 : 4 + Math.floor(rnd() * 4);
    const chars = c === 0 ? '夜行局名簿' : Array.from({ length: n }, () => LEDGER_CH[Math.floor(rnd() * LEDGER_CH.length)]).join('');
    cols.push(`<text x="${x}" y="${py + 20}" font-size="${c === 0 ? 14 : 13}" fill="#1c1714" font-family="'Noto Serif KR', serif" style="writing-mode: vertical-rl; letter-spacing: 4px" opacity="${(c === 0 ? .95 : .9 - rnd() * .25).toFixed(2)}">${chars}</text>`);
  }
  // 낙관: 붉은 테 안에 네 글자(오른쪽 위부터 夜行·局印), 닳은 자국과 번진 가장자리, 조금 기울게 찍힌다
  const sx = px + 50, sy = py + 104;
  const ch = (t, x, y) => `<text x="${x}" y="${y}" font-size="15" font-weight="700" fill="#b0222c" text-anchor="middle" font-family="'Noto Serif KR', serif">${t}</text>`;
  const seal = `<g class="cs-seal"><g filter="url(#cs-sealtex)">
    <rect x="${sx}" y="${sy}" width="44" height="44" rx="3" fill="none" stroke="#b0222c" stroke-width="3.2"/>
    <rect x="${sx + 4}" y="${sy + 4}" width="36" height="36" fill="none" stroke="#b0222c" stroke-width=".8"/>
    ${ch('夜', sx + 31, sy + 20)}${ch('行', sx + 31, sy + 37)}${ch('局', sx + 13, sy + 20)}${ch('印', sx + 13, sy + 37)}</g></g>`;
  // 먹: 낙관 언저리에서 세 덩이가 차례로 번져 장부를 덮는다(가장자리는 잡음으로 일그러지고 결이 남는다)
  const ink = [[sx + 22, sy + 10, 120, ''], [px + 190, py + 56, 100, 'b'], [px + 36, py + 36, 110, 'c']]
    .map(([cx, cy, r, k]) => `<circle class="cs-ink ${k}" cx="${cx}" cy="${cy}" r="${r}" fill="#060505" filter="url(#cs-inkf)"/>`).join('');
  // 먹은 종이 안에서만 번진다(종이 밖은 어둠이라 먹이 보이지 않아야 한다)
  return `<g class="cs-ledger"><clipPath id="cs-paperclip"><rect x="${px + 2}" y="${py + 2}" width="${pw - 4}" height="${ph - 4}"/></clipPath>
    <rect x="-2000" y="-2000" width="4480" height="4240" fill="#07060a" opacity=".9"/>
    <g class="cs-paper">
      <rect x="${px}" y="${py}" width="${pw}" height="${ph}" fill="#e6dcc3" filter="url(#cs-hanji)"/>
      <line x1="${px + pw - 34}" y1="${py + 10}" x2="${px + pw - 34}" y2="${py + ph - 10}" stroke="#8a2a24" stroke-width=".5" opacity=".5"/>
      <g class="cs-writing" filter="url(#cs-brush)">${cols.join('')}</g>
      ${seal}
      <g clip-path="url(#cs-paperclip)">${ink}</g>
    </g></g>`;
}

function scene(kind) {
  seed = 3;
  const stars = Array.from({ length: 34 }, () => `<circle class="cs-star" cx="${(rnd() * 520 - 20).toFixed(1)}" cy="${(rnd() * 110).toFixed(1)}" r="${(0.4 + rnd() * 0.9).toFixed(2)}"/>`).join('');
  const lamps = kind === 'rollback'
    ? ZONES.map((z, i) => lantern(40 + i * 44, 150 - Math.abs(4.5 - i) * 3, i, z)).join('')
    : lantern(240, 150, 9, '');
  const mist = (cls, y, op) => `<g class="${cls}"><g filter="url(#cs-blur)"><rect x="-480" y="${y}" width="2400" height="900" filter="url(#cs-turb)" opacity="${op}"/></g></g>`;
  return `<svg class="cs-stage" viewBox="0 0 480 240" preserveAspectRatio="xMidYMid meet" overflow="visible" aria-hidden="true">${DEFS}
    <rect class="cs-sky" x="-2000" y="-2000" width="4480" height="4240"/>
    <g class="cs-stars">${kind === 'rollback' ? stars : ''}</g>
    <circle class="cs-sun" cx="240" cy="120" r="36"/>
    <path class="cs-roof" d="M-2000 2000V170H30L58 154L86 170H120V180H150L190 150L230 180H250L290 156L330 180H350V172H380L410 154L440 172H2480V2000Z"/>
    <path class="cs-rope" d="M10 118Q120 150 240 124T470 128"/>
    ${lamps}
    <g class="cs-mist" mask="url(#cs-mist-mask)">${mist('cs-flow-a', 150, .85)}${mist('cs-flow-b', 190, .7)}<rect x="-2000" y="300" width="4480" height="2000" fill="#5c121b" filter="url(#cs-blur)"/></g>
    ${kind === 'rollback' ? ledger() : ''}
    <text class="cs-title" x="240" y="62">${kind === 'rollback' ? '第一夜 終' : '아 침'}</text>
    <text class="cs-title" x="240" y="90" style="font-size:13px;letter-spacing:.12em">${kind === 'rollback' ? '…그리고 두 번째 밤이 온다' : ''}</text>
  </svg>`;
}

// 등불 n개째까지 꺼진 상태로: 새로 꺼지는 것만 깜빡이다 꺼진다
const lampsOut = n => root => {
  for (let i = 0; i < n; i++) {
    const g = root.querySelector(`[data-lamp="${i}"]`);
    if (!g || g.dataset.state) continue;
    g.dataset.state = 'out';
    const l = g.querySelector('.cs-lantern');
    if (root.dataset.fast) { l.classList.add('out'); g.querySelector('.cs-zone')?.classList.add('off'); continue; }
    l.classList.add('dying');
    setTimeout(() => { l.classList.remove('dying'); l.classList.add('out'); g.querySelector('.cs-zone')?.classList.add('off'); }, 1400);
  }
};
const wake = root => { const l = root.querySelector('[data-lamp="9"] .cs-lantern'); l?.classList.remove('out'); l?.classList.add('waking'); };

const ROLLBACK = [
  [null, '끝나지 않는 밤, 사흘째 자정.'],
  [null, '봉연 쪽에서 붉은 안개가 번져 온다. 별이 하나씩 묻힌다.', r => r.classList.add('mist')],
  [null, '반요촌의 등불이 꺼졌다.', lampsOut(1)],
  ['태사령 하후정', '별이 하나도 보이지 않는다. …이런 밤은 어느 기록에도 없다.', lampsOut(2)],
  ['회주 무명(無名)', '장부에 없는 밤이로군. 값을 매길 수가 없어.', lampsOut(3)],
  ['맹주 석진악', '얼음 인장이 녹는다. 버텨라. 아직, 아직은 버틸 수 있다.', lampsOut(4)],
  ['노장 장무현', '나라를 한 번 잃어 봤지. 두 번째가… 이런 식일 줄은 몰랐다.', lampsOut(5)],
  ['교주 월화(月華)', '달 없는 밤이구나. 우리 맹세도 이 어둠 앞에서는 숨을 죽인다.', lampsOut(6)],
  ['도방 진소랑', '물길이 모두 끊겼소. 배를 띄울 곳이 없어.', r => { lampsOut(8)(r); r.classList.add('mist2'); }],
  [null, '본부 객사의 등불마저 꺼졌다. 남은 것은 정청의 등불 하나.', lampsOut(9)],
  ['도제조 백운서', '…정청 문을 닫지 마라. 마지막 하나는 여기서 지킨다.'],
  [null, '정청 깊은 곳, 마지막 등불 아래. 사건 서기관 연서희가 장부를 펼친다.', r => r.classList.add('ledger')],
  ['사건 서기관 연서희', '이름을 적어 둘게요. 이 밤을 걸었던 사람들의 이름을, 하나도 빠짐없이.'],
  [null, '붉은 인장이 장부 위에 내려앉는다.', r => r.classList.add('seal')],
  [null, '먹이 번진다. 글자가 흐려지고, 지난 밤의 모든 것이 지워져 간다.', r => r.classList.add('ink')],
  ['사건 서기관 연서희', '괜찮아요. 이름만 남아 있으면… 아침은 다시 와요.'],
  [null, '', r => { r.classList.remove('ledger', 'seal', 'ink', 'mist', 'mist2'); r.classList.add('fin'); }],
];
const MORNING = [
  [null, '긴 밤이 끝났다.', r => r.querySelector('[data-lamp="9"] .cs-lantern')?.classList.add('out')],
  [null, '정청의 등불 하나가 깜빡이며 다시 살아난다.', r => { wake(r); r.classList.add('dawn'); }],
  [null, '닭이 운다. 먼 산마루가 희게 밝아 온다.', r => r.classList.add('dawn2')],
  [null, '당신은 이름 하나를 쥐고 정청 앞에 서 있다.\n지난 일은 꿈처럼 흐릿하다.', r => r.classList.add('dawn3')],
  [null, '', r => r.classList.add('fin')],
];

function embers(root) {
  const box = root.querySelector('.cs-embers');
  for (let i = 0; i < 22; i++) {
    const e = document.createElement('i');
    e.style.left = `${(i * 4.6 + Math.random() * 4) % 100}%`;
    e.style.setProperty('--dx', `${Math.round(Math.random() * 80 - 40)}px`);
    e.style.animationDuration = `${7 + Math.random() * 7}s`;
    e.style.animationDelay = `${-Math.random() * 12}s`;
    const s = 2 + Math.random() * 2.5; e.style.width = e.style.height = `${s}px`;
    box.append(e);
  }
}


// 롤백 컷씬 전용 곡(tools/cutscene_music: 게임 악기 조각으로 구운 음원). 컷씬 시간에 맞춰 있다:
// 73초 무렵(resolve) 제목과 함께 버티는 화음, 87초(outro)부터 끝(end)까지는 마지막 장면에 머무는 동안 되풀이한다.
// 소리는 사용자가 한 번 누른 뒤에야 나므로(브라우저 규칙) 저절로 안 나면 [소리 켜기] 단추를 보이고, 화면 어디든 처음 누를 때도 켠다.
const MUSIC = { url: new URL('../audio/cutscene.mp3', import.meta.url).href, resolve: 73.33, outro: 86.67, end: 109.5 };
let musicBuf = null;
function cutsceneMusic(onState) {
  let ac = null, gain = null, src = null, want = true, vol = 0.6, dead = false, at0 = 0, off0 = 0;
  try { const s = JSON.parse(localStorage.getItem('yh-sound') || '{}'); if (s.bgmOn === false) want = false; if (typeof s.bgm === 'number') vol = Math.min(1, s.bgm * 1.5); } catch {}
  try { if (localStorage.getItem('yh-cs-sound') === 'off') want = false; else if (localStorage.getItem('yh-cs-sound') === 'on') want = true; } catch {}
  const MOBILE = (() => { try { return matchMedia('(pointer: coarse)').matches; } catch { return false; } })();
  const load = musicBuf ? Promise.resolve(musicBuf) : fetch(MUSIC.url).then(r => { if (!r.ok) throw 0; return r.arrayBuffer(); });
  const ensure = () => {
    if (ac) return ac;
    const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return null;
    ac = new AC(); gain = ac.createGain(); gain.gain.value = 0; gain.connect(ac.destination);
    return ac;
  };
  const playing = () => !!src && ac?.state === 'running';
  function startAt(offset) {
    if (dead || !ac || !musicBuf) return;
    if (src) { try { src.stop(); } catch {} src = null; }
    src = ac.createBufferSource(); src.buffer = musicBuf;
    src.loop = true; src.loopStart = MUSIC.outro; src.loopEnd = Math.min(MUSIC.end, musicBuf.duration);
    src.connect(gain);
    const t = ac.currentTime;
    gain.gain.cancelScheduledValues(t); gain.gain.setValueAtTime(0.0001, t); gain.gain.linearRampToValueAtTime(vol, t + (offset > 1 ? 1.6 : 0.4));
    src.start(t, Math.min(offset, musicBuf.duration - 0.1)); at0 = t; off0 = offset;
  }
  const api = {
    // 컷씬이 시작된 때부터 지난 초(마지막 장면이면 되풀이 부분)
    sceneTime: () => 0,
    get on() { return want && playing(); },
    async toggle() {
      want = !want; try { localStorage.setItem('yh-cs-sound', want ? 'on' : 'off'); } catch {}
      if (want) await api.resume(); else { if (ac) { const t = ac.currentTime; gain.gain.cancelScheduledValues(t); gain.gain.setTargetAtTime(0, t, 0.25); setTimeout(() => { if (!want && src) { try { src.stop(); } catch {} src = null; } }, 900); } }
      onState(api.on);
    },
    async resume() {
      if (dead || !want || !ensure()) return;
      try { if (ac.state !== 'running') await ac.resume(); } catch {}
      if (!musicBuf) { try { const b = await load; musicBuf = b instanceof AudioBuffer ? b : await ac.decodeAudioData(b); } catch { onState(null); return; } }
      if (ac.state === 'running' && !src && want) startAt(api.sceneTime());
      onState(api.on);
    },
    // 건너뛰기: 버티는 화음 자리로 옮긴다(이미 지났으면 그대로)
    jumpToResolve() {
      if (!playing()) return;
      const pos = off0 + (ac.currentTime - at0);
      if (pos >= MUSIC.resolve - 1) return;
      const t = ac.currentTime; gain.gain.cancelScheduledValues(t); gain.gain.setTargetAtTime(0, t, 0.12);
      setTimeout(() => { if (want && !dead) startAt(MUSIC.resolve); }, 450);
    },
    stop(fade = 1) {
      dead = true; document.removeEventListener('visibilitychange', vis);
      if (!ac) return;
      const t = ac.currentTime; gain.gain.cancelScheduledValues(t); gain.gain.setTargetAtTime(0, t, fade / 3);
      setTimeout(() => { try { src?.stop(); } catch {} ac.close?.().catch(() => {}); }, fade * 1000 + 200);
    },
  };
  // 모바일은 화면을 내리면 멈추고 돌아오면 다시 낸다(게임 배경음악과 같은 규칙)
  const vis = () => { if (!ac || !MOBILE) return; if (document.hidden) ac.suspend().catch(() => {}); else if (want) ac.resume().catch(() => {}); };
  document.addEventListener('visibilitychange', vis);
  load.catch(() => onState(null));
  return api;
}

// 옵션: stay — 마지막 장면에서 닫지 못하게(롤백 점검 페이지: 이 화면만 남는다), note — 마지막 장면 아래 글 칸에 둘 안내,
//       atEnd — 처음부터 틀지 않고 마지막 장면으로 바로 연다(점검 페이지가 다시 읽힐 때)
export function playCutscene(kind = 'rollback', { onEnd, stay = false, note = '', atEnd = false } = {}) {
  if (!document.getElementById('cs-style')) document.head.append(Object.assign(document.createElement('style'), { id: 'cs-style', textContent: CSS }));
  const lines = kind === 'rollback' ? ROLLBACK : MORNING;
  const root = document.createElement('div');
  root.className = 'cs'; root.setAttribute('role', 'dialog'); root.setAttribute('aria-label', kind === 'rollback' ? '첫째 밤의 끝' : '아침');
  root.innerHTML = `<div style="position:relative;overflow:hidden">${scene(kind)}${kind === 'rollback' ? '<div class="cs-embers"></div><button type="button" class="cs-snd" hidden>소리 켜기</button>' : ''}<button type="button" class="cs-skip">건너뛰기</button></div>
    <div class="cs-box" aria-live="polite"><div class="cs-who"></div><div class="cs-text"></div></div>`;
  document.body.append(root);
  if (kind === 'rollback') embers(root);
  const who = root.querySelector('.cs-who'), text = root.querySelector('.cs-text');
  let i = -1, timer = 0, done = false;
  const t0 = performance.now();
  let ended = false, endedAt = 0, music = null;
  if (kind === 'rollback') {
    const btn = root.querySelector('.cs-snd');
    music = cutsceneMusic(on => { if (on === null) { btn.hidden = true; return; } btn.hidden = false; btn.classList.toggle('on', on); btn.textContent = on ? '소리 끄기' : '소리 켜기'; });
    // 마지막 장면에 막 닿았으면(건너뛰기 포함) 버티는 화음부터, 오래 머문 뒤 켜면 되풀이 부분부터
    music.sceneTime = () => ended ? (performance.now() - endedAt < 15000 && !atEnd ? MUSIC.resolve : MUSIC.outro) : Math.min((performance.now() - t0) / 1000, MUSIC.resolve);
    btn.addEventListener('click', e => { e.stopPropagation(); music.toggle(); });
    root.addEventListener('pointerdown', () => { if (!music.on) music.resume(); }, { once: true });
    music.resume();
  }
  const finish = () => {
    if (done) return; done = true; clearTimeout(timer); music?.stop(1);
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
    // 마지막 장면(제목)에 닿으면 저절로 닫지 않고 [닫기]·[다시 보기]를 띄운다
    if (i === lines.length - 1) { timer = setTimeout(showEnd, 2600); return; }
    // 글 길이에 맞춰 저절로 넘긴다
    timer = setTimeout(step, t ? 2200 + t.length * 75 : 6000);
  };
  const skip = root.querySelector('.cs-skip');
  // 건너뛰기: 남은 장면 변화를 한꺼번에 적용해 마지막 장면으로 간다(닫기는 마지막 장면의 [닫기]로만)
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
    bar.innerHTML = '<button type="button" class="cs-btn" data-again>다시 보기</button>' + (stay ? '' : '<button type="button" class="cs-btn main" data-close>닫기</button>');
    root.querySelector('.cs-box').append(bar);
    bar.querySelector('[data-close]')?.addEventListener('click', finish);
    bar.querySelector('[data-again]').addEventListener('click', () => { if (done) return; done = true; clearTimeout(timer); music?.stop(0.3); root.remove(); playCutscene(kind, { onEnd, stay, note }); });
  }
  if (atEnd) { i = -1; jumpToEnd(); return finish; }
  setTimeout(step, 1200);
  return finish;
}
