// 환경음 재료(7.5.9i 다듬기, 사용자 요청): 비·바람·물·새·풀벌레·부엉이·물방울.
// sound.js가 실제 소리 장치(ctx)와 환경음 길(dest)을 넘겨 부르고, tools/ambience_preview가 같은 함수로 미리듣기를 굽는다.
// 화면·서버와 상관없는 순수 함수만 둔다(다른 파일을 불러오지 않음).

// 빗소리 바탕: 아주 짧은 빗방울 수천 개를 버퍼에 직접 흩뿌려 만든다(흰 잡음을 거르면 「촤아」 하는 쇳소리가 나서).
// 버퍼 끝과 처음을 이어 붙이도록 방울을 길이로 감아 넣어 되풀이 이음매가 없다.
// rate: 1초에 떨어지는 작은 방울 수, big: 1초에 떨어지는 굵은 「톡」 수, tone: 방울 울림(높을수록 잎·처마, 낮을수록 땅)
export function rainBuffer(ctx, { seconds = 12, rate = 160, big = 6, tone = 1 } = {}) {
  const sr = ctx.sampleRate, len = Math.floor(sr * seconds), buf = ctx.createBuffer(2, len, sr);
  for (let ch = 0; ch < 2; ch++) {
    const d = buf.getChannelData(ch);
    const put = (at, n, amp, decay, f, ring) => {
      // 날카로운 첫소리(잡음 몇 표본) + 짧게 사그라드는 울림. 울림 주파수가 살짝 올라가며(물방울 거품) 「톡」이 된다
      let ph = Math.random() * 6.28, lp = 0;
      for (let i = 0; i < n; i++) {
        const e = Math.exp(-i / decay), k = (at + i) % len;
        lp += ((Math.random() * 2 - 1) - lp) * 0.45; // 잡음을 조금 눌러 쇳소리를 덜어 냄
        ph += 6.2832 * f * (1 + 0.35 * i / n) / sr;
        d[k] += amp * e * (lp * (1 - ring) + Math.sin(ph) * ring) * (i < 6 ? i / 6 : 1);
      }
    };
    const small = Math.floor(rate * seconds), large = Math.floor(big * seconds);
    for (let j = 0; j < small; j++) {
      const a = 0.05 + Math.pow(Math.random(), 3) * 0.22, n = Math.floor(sr * (0.004 + Math.random() * 0.012));
      put(Math.floor(Math.random() * len), n, a, n / 4, (1900 + Math.random() * 2600) * tone, 0.35);
    }
    for (let j = 0; j < large; j++) {
      // 굵은 방울은 2~4개가 짧게 이어 떨어지기도 한다(또도독)
      let at = Math.floor(Math.random() * len); const cnt = Math.random() < 0.45 ? 2 + Math.floor(Math.random() * 3) : 1;
      for (let c = 0; c < cnt; c++) {
        const a = 0.22 + Math.random() * 0.3, n = Math.floor(sr * (0.018 + Math.random() * 0.02));
        put(at, n, a, n / 5, (900 + Math.random() * 1300) * tone, 0.6);
        at += Math.floor(sr * (0.05 + Math.random() * 0.07));
      }
    }
    let mx = 0; for (let i = 0; i < len; i++) mx = Math.max(mx, Math.abs(d[i]));
    if (mx > 0) for (let i = 0; i < len; i++) d[i] *= 0.9 / mx;
  }
  return buf;
}
// 낮고 부드러운 바탕(멀리서 비가 땅을 적시는 소리) — 갈색 잡음을 아래로만 남긴다
function bed(ctx, dest, brown, f) {
  const n = ctx.createBufferSource(), lp = ctx.createBiquadFilter(); n.buffer = brown; n.loop = true;
  lp.type = 'lowpass'; lp.frequency.value = f; n.connect(lp); lp.connect(dest); n.start(); return n;
}
function loopBuf(ctx, dest, b, hp, lp) {
  const n = ctx.createBufferSource(), h = ctx.createBiquadFilter(), l = ctx.createBiquadFilter(); n.buffer = b; n.loop = true;
  h.type = 'highpass'; h.frequency.value = hp; l.type = 'lowpass'; l.frequency.value = lp; n.connect(h); h.connect(l); l.connect(dest); n.start(Math.random() * 0.1, Math.random() * b.duration); return n;
}
// 층마다 (ctx, dest, 재료) → 멈출 소리 목록
export const LAYERS = {
  // 세우: 성긴 잔방울 + 가끔 또도독, 높은 결은 4.5kHz에서 접고 바탕은 아주 옅게
  drizzle: (ctx, dest, m) => {
    const b = m.drizzleBuf || (m.drizzleBuf = rainBuffer(ctx, { seconds: 14, rate: 110, big: 5, tone: 1 }));
    const g = ctx.createGain(); g.gain.value = 0.18; g.connect(dest);
    const lo = ctx.createGain(); lo.gain.value = 0.25; lo.connect(dest);
    return [loopBuf(ctx, g, b, 250, 4500), bed(ctx, lo, m.brown, 300)];
  },
  // 장우: 촘촘한 방울 두 겹(가까운 것·먼 것) + 낮은 바탕 — 같은 방울 결이라 세우보다 굵고 빽빽할 뿐 쇳소리가 없다
  rain: (ctx, dest, m) => {
    const b = m.rainBuf || (m.rainBuf = rainBuffer(ctx, { seconds: 12, rate: 900, big: 14, tone: 0.85 }));
    const g = ctx.createGain(); g.gain.value = 0.2; g.connect(dest);
    const far = ctx.createGain(); far.gain.value = 0.12; far.connect(dest);
    const lo = ctx.createGain(); lo.gain.value = 0.5; lo.connect(dest);
    return [loopBuf(ctx, g, b, 200, 5200), loopBuf(ctx, far, b, 150, 1600), bed(ctx, lo, m.brown, 420)];
  },
  // 바람: 갈색 잡음의 띠를 천천히 오르내리게 하고 세기를 숨 쉬듯 바꾼다(휘파람 같은 공명은 낮춤)
  wind: (ctx, dest, m) => {
    const n = ctx.createBufferSource(), bp = ctx.createBiquadFilter(), lp = ctx.createBiquadFilter(), sw = ctx.createGain();
    n.buffer = m.brown; n.loop = true; bp.type = 'bandpass'; bp.frequency.value = 420; bp.Q.value = 0.9; lp.type = 'lowpass'; lp.frequency.value = 1400;
    const l1 = ctx.createOscillator(), g1 = ctx.createGain(); l1.frequency.value = 0.05; g1.gain.value = 220; l1.connect(g1); g1.connect(bp.frequency);
    const l2 = ctx.createOscillator(), g2 = ctx.createGain(); l2.frequency.value = 0.031; g2.gain.value = 0.35; sw.gain.value = 0.65; l2.connect(g2); g2.connect(sw.gain);
    n.connect(bp); bp.connect(lp); lp.connect(sw); sw.connect(dest); n.start(); l1.start(); l2.start(); return [n, l1, l2];
  },
  // 물: 낮게 흐르는 소리 + 잔잔하게 일렁이는 물결(가운데 띠를 느리게 흔듦)
  water: (ctx, dest, m) => {
    const a = bed(ctx, dest, m.brown, 300);
    const n = ctx.createBufferSource(), bp = ctx.createBiquadFilter(), g = ctx.createGain(); n.buffer = m.brown; n.loop = true;
    bp.type = 'bandpass'; bp.frequency.value = 900; bp.Q.value = 1.4; g.gain.value = 0.35;
    const l = ctx.createOscillator(), lg = ctx.createGain(); l.frequency.value = 0.21; lg.gain.value = 300; l.connect(lg); lg.connect(bp.frequency);
    n.connect(bp); bp.connect(g); g.connect(dest); n.start(0, 1.3); l.start(); return [a, n, l];
  },
  // 눈: 소리를 먹는 고요 — 아주 옅은 높은 결
  hiss: (ctx, dest, m) => {
    const n = ctx.createBufferSource(), hp = ctx.createBiquadFilter(), lp = ctx.createBiquadFilter(); n.buffer = m.noise; n.loop = true;
    hp.type = 'highpass'; hp.frequency.value = 3000; lp.type = 'lowpass'; lp.frequency.value = 7000; n.connect(hp); hp.connect(lp); lp.connect(dest); n.start(); return [n];
  },
  // 혈무: 낮은 두 음이 맞부딪혀 일렁이는 웅웅거림
  mist: (ctx, dest) => {
    const o = ctx.createOscillator(), o2 = ctx.createOscillator(), t = ctx.createGain(), lfo = ctx.createOscillator(), lg = ctx.createGain();
    o.frequency.value = 55; o2.frequency.value = 58.3; o.type = o2.type = 'sine'; t.gain.value = 0.6; lfo.frequency.value = 0.3; lg.gain.value = 0.4; lfo.connect(lg); lg.connect(t.gain);
    o.connect(t); o2.connect(t); t.connect(dest); o.start(); o2.start(); lfo.start(); return [o, o2, lfo];
  },
};

const env = (g, t, peak, a, d) => { g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(Math.max(0.0002, peak), t + a); g.gain.exponentialRampToValueAtTime(0.0001, t + a + d); };
// 새 한 마리의 짧은 노래: 음 높이가 휘는 짧은 소리 2~6개(곡선 모양을 몇 가지에서 고름), 두 번째 배음을 살짝 얹어 맑게
export function bird(ctx, dest, t, vol = 1) {
  const kinds = [[1, 1.35], [1.3, 1], [1, 1.2, 0.95], [1.15, 0.9, 1.25]], shape = kinds[Math.floor(Math.random() * kinds.length)];
  const base = 2400 + Math.random() * 1600, n = 2 + Math.floor(Math.random() * 5), step = 0.09 + Math.random() * 0.06, dur = 0.06 + Math.random() * 0.05;
  for (let i = 0; i < n; i++) {
    const s = t + i * step * (0.85 + Math.random() * 0.3), o = ctx.createOscillator(), o2 = ctx.createOscillator(), g = ctx.createGain(), g2 = ctx.createGain(), f = base * (1 + (i % 2) * 0.06);
    o.type = o2.type = 'sine';
    shape.forEach((k, j) => { const at = s + dur * j / (shape.length - 1); o.frequency[j ? 'exponentialRampToValueAtTime' : 'setValueAtTime'](f * k, at); o2.frequency[j ? 'exponentialRampToValueAtTime' : 'setValueAtTime'](f * k * 2, at); });
    env(g, s, 0.075 * vol, 0.008, dur); env(g2, s, 0.012 * vol, 0.008, dur * 0.8);
    o.connect(g); o2.connect(g2); g.connect(dest); g2.connect(dest); o.start(s); o2.start(s); o.stop(s + dur + 0.05); o2.stop(s + dur + 0.05);
  }
}
// 귀뚜라미 한 번 울음: 높은 음을 1초에 30번쯤 끊어 「찌르르르」 3~5마디
export function cricket(ctx, dest, t, vol = 1) {
  const f = 4300 + Math.random() * 500, n = 3 + Math.floor(Math.random() * 3);
  for (let i = 0; i < n; i++) {
    const s = t + i * 0.034, o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'sine'; o.frequency.value = f;
    env(g, s, 0.03 * vol, 0.003, 0.02); o.connect(g); g.connect(dest); o.start(s); o.stop(s + 0.03);
  }
}
// 부엉이 「부우 부엉」: 낮은 두 음, 둥글게 부풀었다 사라짐
export function owl(ctx, dest, t) {
  [[0, 390, 0.32], [0.5, 350, 0.42]].forEach(([d, f, len]) => {
    const o = ctx.createOscillator(), g = ctx.createGain(), lp = ctx.createBiquadFilter(); o.type = 'triangle'; o.frequency.setValueAtTime(f * 1.04, t + d); o.frequency.exponentialRampToValueAtTime(f, t + d + len);
    lp.type = 'lowpass'; lp.frequency.value = 900; env(g, t + d, 0.03, 0.08, len); o.connect(lp); lp.connect(g); g.connect(dest); o.start(t + d); o.stop(t + d + len + 0.15);
  });
}
// 동굴·안개 속 물방울 하나: 「똑」 하고 울림이 위로 살짝 올라가며 사라짐
export function drip(ctx, dest, t, vol = 1) {
  const o = ctx.createOscillator(), g = ctx.createGain(), f = 900 + Math.random() * 900; o.type = 'sine';
  o.frequency.setValueAtTime(f, t); o.frequency.exponentialRampToValueAtTime(f * 1.6, t + 0.05); env(g, t, 0.03 * vol, 0.002, 0.09); o.connect(g); g.connect(dest); o.start(t); o.stop(t + 0.14);
}
