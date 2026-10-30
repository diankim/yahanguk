// 컷씬: 롤백 순간(점검 페이지, maintenance.json scene 'rollback')과 다시 연 뒤 첫 접속의 「아침」(캐릭터 만들기 앞).
// 다른 모듈에 기대지 않는다(점검 중에도 돈다). 평면 도형을 쓰되 붉은 안개만 흐림 필터로 번지게 하고(사용자 요청), 글은 저절로 넘어가며 누르면 다음 줄, 「건너뛰기」로 끝낸다.
// 움직임 줄이기 설정이면 도형 움직임 없이 글만 넘긴다.

const ZONES = ['반요촌', '무극 관성대', '십삼문 암시장', '철벽 고찰', '잔불촌', '백골 장터', '구름나루', '백등 야시장', '본부 객사', '본부 정청'];

const CSS = `
.cs { position: fixed; inset: 0; z-index: 9000; background: #07060a; color: #e9e2d4; display: grid; grid-template-rows: 1fr auto; font-family: var(--font-serif, serif); }
.cs svg { width: 100%; height: 100%; display: block; }
.cs .cs-sky { fill: #0b0a10; transition: fill 3s linear; }
.cs.dawn .cs-sky { fill: #2b2a3a; } .cs.dawn2 .cs-sky { fill: #6f6a78; } .cs.dawn3 .cs-sky { fill: #c9b79a; }
.cs .cs-roof { fill: #030305; }
.cs .cs-lamp { fill: #e0a64a; transition: fill .6s, opacity .6s; }
.cs .cs-lamp.out { fill: #2a2622; }
.cs .cs-glow { fill: #e0a64a; opacity: .14; transition: opacity .6s; }
.cs .cs-glow.out { opacity: 0; }
.cs .cs-mist { opacity: 0; transform: translateY(30px); transition: opacity 3s linear, transform 8s ease-out; }
.cs.mist .cs-mist { opacity: .55; transform: translateY(-20px); }
.cs.mist2 .cs-mist { opacity: .85; transform: translateY(-70px); }
.cs .cs-wisp rect { animation: cs-wisp 60s linear infinite; }
@keyframes cs-wisp { from { transform: translateX(0); } to { transform: translateX(480px); } }
.cs .cs-mist ellipse { fill: #8e1f2a; animation: cs-drift 14s ease-in-out infinite alternate; }
.cs .cs-mist ellipse:nth-child(2n) { fill: #6d1620; animation-duration: 19s; animation-direction: alternate-reverse; }
.cs .cs-mist ellipse:nth-child(3n) { animation-duration: 23s; }
@keyframes cs-drift { from { transform: translateX(-30px); } to { transform: translateX(30px); } }
.cs .cs-sun { fill: #f2d8a0; opacity: 0; transform: translateY(40px); transition: opacity 3s, transform 5s linear; }
.cs.dawn3 .cs-sun { opacity: 1; transform: none; }
.cs .cs-ledger { opacity: 0; transition: opacity 1.2s; }
.cs.ledger .cs-ledger { opacity: 1; }
.cs .cs-page { fill: #d9cfb8; } .cs .cs-line { stroke: #4a4236; stroke-width: 2; }
.cs .cs-seal-t { fill: #e9dcc2 !important; }
.cs .cs-seal { fill: #b3242e; opacity: 0; transform-origin: 300px 120px; transform: scale(1.8); transition: opacity .25s, transform .25s cubic-bezier(.3,1.6,.6,1); }
.cs.seal .cs-seal { opacity: 1; transform: scale(1); }
.cs .cs-ink { fill: #07060a; transform-origin: 300px 120px; transform: scale(0); transition: transform 5s ease-in; }
.cs.ink .cs-ink { transform: scale(9); }
.cs .cs-title { opacity: 0; transition: opacity 2s; fill: #e9e2d4; font-size: 26px; letter-spacing: .4em; text-anchor: middle; }
.cs.fin .cs-title { opacity: 1; }
.cs .cs-zone { fill: #8f877a; font-size: 10px; text-anchor: middle; font-family: var(--font-sans, sans-serif); }
.cs-box { min-height: 128px; padding: 16px max(16px, env(safe-area-inset-left)) max(18px, env(safe-area-inset-bottom)); border-top: 1px solid #2a2530; background: #0b0a10; display: grid; gap: 6px; align-content: start; cursor: pointer; }
.cs-who { font-size: 13px; color: #e0a64a; letter-spacing: .06em; min-height: 18px; }
.cs-text { font-size: 17px; line-height: 1.7; white-space: pre-line; }
.cs-text.nar { color: #b9b0a2; font-style: normal; }
.cs-skip { position: absolute; top: max(12px, env(safe-area-inset-top)); right: 12px; padding: 6px 12px; border: 1px solid #3a3440; border-radius: 999px; background: #0b0a10; color: #b9b0a2; font-size: 13px; cursor: pointer; z-index: 2; }
.cs-hint { font-size: 11px; color: #6e6676; justify-self: end; }
@media (prefers-reduced-motion: reduce) { .cs *, .cs { transition: none !important; } }
`;

function scene(kind) {
  const lamps = ZONES.map((z, i) => {
    // 바깥 안전지대(왼쪽)부터 꺼져 오른쪽 끝 정청 하나만 남는다
    // 이름은 위·아래로 번갈아 적어 좁은 화면에서도 겹치지 않게 한다
    const x = 40 + i * 44, y = 150 - Math.abs(4.5 - i) * 3;
    return `<g data-lamp="${i}"><circle class="cs-glow" cx="${x}" cy="${y}" r="16"/><rect class="cs-lamp" x="${x - 5}" y="${y - 8}" width="10" height="15" rx="4"/>
      <text class="cs-zone" x="${x}" y="${i % 2 ? y - 16 : y + 26}">${z}</text></g>`;
  }).join('');
  return `<svg viewBox="0 0 480 240" preserveAspectRatio="xMidYMid meet" overflow="visible" aria-hidden="true">
    <rect class="cs-sky" x="-2000" y="-2000" width="4480" height="4240"/>
    <circle class="cs-sun" cx="240" cy="120" r="34"/>
    <path class="cs-roof" d="M-2000 2000V170H30L58 154L86 170H120V180H150L190 150L230 180H250L290 156L330 180H350V172H380L410 154L440 172H2480V2000Z"/>
    <path d="M10 118Q120 150 240 124T470 128" fill="none" stroke="#2a2530" stroke-width="1.5"/>
    ${kind === 'rollback' ? lamps : `<g data-lamp="9"><circle class="cs-glow" cx="240" cy="150" r="18"/><rect class="cs-lamp" x="235" y="142" width="10" height="15" rx="4"/></g>`}
    <defs><filter id="cs-blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14"/></filter>
      <filter id="cs-turb" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency="0.012 0.04" numOctaves="3" seed="11"/>
        <feColorMatrix values="0 0 0 0 0.5  0 0 0 0 0.07  0 0 0 0 0.11  2.2 0 0 0 -0.75"/><feGaussianBlur stdDeviation="2"/></filter></defs>
    <g class="cs-mist" filter="url(#cs-blur)">${[[-40, 214, 150, 42], [120, 222, 170, 48], [300, 210, 160, 44], [470, 220, 150, 46], [40, 250, 220, 50], [260, 256, 240, 56], [480, 250, 200, 50], [200, 300, 600, 90]].map(([cx, cy, rx, ry]) => `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}"/>`).join('')}<rect x="-2000" y="290" width="4480" height="2000" fill="#6d1620"/></g>
    <g class="cs-mist cs-wisp"><g filter="url(#cs-blur)"><rect x="-480" y="160" width="1440" height="900" filter="url(#cs-turb)" opacity=".55"/></g></g>
    <g class="cs-ledger">
      <rect x="-2000" y="-2000" width="4480" height="4240" fill="#07060a" opacity=".86"/>
      <rect class="cs-page" x="170" y="50" width="260" height="150"/>
      ${Array.from({ length: 7 }, (_, i) => `<line class="cs-line" x1="190" x2="${330 + (i * 37) % 80}" y1="${72 + i * 18}" y2="${72 + i * 18}"/>`).join('')}
      <rect class="cs-seal" x="282" y="102" width="36" height="36" rx="3"/>
      <text x="300" y="128" text-anchor="middle" font-size="22" class="cs-seal cs-seal-t">印</text>
      <circle class="cs-ink" cx="300" cy="120" r="14"/>
    </g>
    <text class="cs-title" x="240" y="62">${kind === 'rollback' ? '第一夜 終' : '아 침'}</text>
    <text class="cs-title" x="240" y="90" style="font-size:13px;letter-spacing:.12em">${kind === 'rollback' ? '…그리고 두 번째 밤이 온다' : ''}</text>
  </svg>`;
}

// 장면 줄: [말하는 이(없으면 서술), 글, 화면에 줄 변화]
const lampsOut = from => root => { for (let i = 0; i < from; i++) root.querySelector(`[data-lamp="${i}"]`)?.querySelectorAll('rect,circle').forEach(e => e.classList.add('out')); };
const ROLLBACK = [
  [null, '끝나지 않는 밤, 사흘째 자정.'],
  [null, '봉연 쪽에서 붉은 안개가 번져 온다.', r => r.classList.add('mist')],
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
  [null, '긴 밤이 끝났다.'],
  [null, '정청의 등불 하나가 새벽까지 꺼지지 않았다.', r => r.classList.add('dawn')],
  [null, '닭이 운다. 먼 산마루가 희게 밝아 온다.', r => r.classList.add('dawn2')],
  [null, '당신은 이름 하나를 쥐고 정청 앞에 서 있다.\n지난 일은 꿈처럼 흐릿하다.', r => r.classList.add('dawn3')],
  [null, '', r => r.classList.add('fin')],
];

export function playCutscene(kind = 'rollback', { onEnd } = {}) {
  if (!document.getElementById('cs-style')) document.head.append(Object.assign(document.createElement('style'), { id: 'cs-style', textContent: CSS }));
  const lines = kind === 'rollback' ? ROLLBACK : MORNING;
  const root = document.createElement('div');
  root.className = 'cs'; root.setAttribute('role', 'dialog'); root.setAttribute('aria-label', kind === 'rollback' ? '첫째 밤의 끝' : '아침');
  root.innerHTML = `<div style="position:relative;overflow:hidden">${scene(kind)}<button type="button" class="cs-skip">건너뛰기</button></div>
    <div class="cs-box" aria-live="polite"><div class="cs-who"></div><div class="cs-text"></div><div class="cs-hint">누르면 다음</div></div>`;
  document.body.append(root);
  const who = root.querySelector('.cs-who'), text = root.querySelector('.cs-text');
  let i = -1, timer = 0, done = false;
  const finish = () => {
    if (done) return; done = true; clearTimeout(timer);
    root.style.transition = 'opacity .8s'; root.style.opacity = '0';
    setTimeout(() => { root.remove(); onEnd?.(); }, 800);
  };
  const step = () => {
    clearTimeout(timer);
    i++;
    if (i >= lines.length) { timer = setTimeout(finish, 3500); return; }
    const [s, t, fx] = lines[i];
    who.textContent = s || '';
    text.textContent = t;
    text.classList.toggle('nar', !s);
    fx?.(root);
    // 글 길이에 맞춰 저절로 넘긴다(마지막 제목은 길게 보인다)
    timer = setTimeout(step, t ? 1800 + t.length * 70 : 5200);
  };
  root.querySelector('.cs-box').addEventListener('click', step);
  root.querySelector('.cs-skip').addEventListener('click', e => { e.stopPropagation(); finish(); });
  setTimeout(step, 900);
  return finish;
}
