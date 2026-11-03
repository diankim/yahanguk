export function rainBuffer(ctx, { seconds = 12, rate = 160, big = 6, tone = 1, bigAmp = 1, soft = 0 } = {}) {
  const sr = ctx.sampleRate, len = Math.floor(sr * seconds), buf = ctx.createBuffer(2, len, sr);
  for (let ch = 0; ch < 2; ch++) {
    const d = buf.getChannelData(ch);
    const atk = 6 + Math.round(soft * 70);
    const put = (at, n, amp, decay, f, ring) => {
      let ph = Math.random() * 6.28, lp = 0;
      for (let i = 0; i < n; i++) {
        const e = Math.exp(-i / decay), k = (at + i) % len;
        lp += ((Math.random() * 2 - 1) - lp) * (0.45 - soft * 0.33);
        ph += 6.2832 * f * (1 + 0.35 * i / n) / sr;
        d[k] += amp * e * (lp * (1 - ring) + Math.sin(ph) * ring) * (i < atk ? i / atk : 1);
      }
    };
    const small = Math.floor(rate * seconds), large = Math.floor(big * seconds);
    for (let j = 0; j < small; j++) {
      const a = 0.05 + Math.pow(Math.random(), 3) * 0.22, n = Math.floor(sr * (0.004 + Math.random() * 0.012));
      put(Math.floor(Math.random() * len), soft ? n * 2 : n, a, (soft ? n * 2 : n) / 4, (1900 + Math.random() * 2600) * tone * (1 - soft * 0.35), 0.35 + soft * 0.5);
    }
    for (let j = 0; j < large; j++) {
      let at = Math.floor(Math.random() * len); const cnt = Math.random() < 0.45 ? 2 + Math.floor(Math.random() * 3) : 1;
      for (let c = 0; c < cnt; c++) {
        const a = (0.22 + Math.random() * 0.3) * bigAmp, n = Math.floor(sr * (0.018 + Math.random() * 0.02));
        put(at, n, a, n / 5, (900 + Math.random() * 1300) * tone, 0.6);
        at += Math.floor(sr * (0.05 + Math.random() * 0.07));
      }
    }
    let mx = 0; for (let i = 0; i < len; i++) mx = Math.max(mx, Math.abs(d[i]));
    if (mx > 0) for (let i = 0; i < len; i++) d[i] *= 0.9 / mx;
  }
  return buf;
}
function bed(ctx, dest, brown, f) {
  const n = ctx.createBufferSource(), lp = ctx.createBiquadFilter(); n.buffer = brown; n.loop = true;
  lp.type = 'lowpass'; lp.frequency.value = f; n.connect(lp); lp.connect(dest); n.start(); return n;
}
function loopBuf(ctx, dest, b, hp, lp) {
  const n = ctx.createBufferSource(), h = ctx.createBiquadFilter(), l = ctx.createBiquadFilter(); n.buffer = b; n.loop = true;
  h.type = 'highpass'; h.frequency.value = hp; l.type = 'lowpass'; l.frequency.value = lp; n.connect(h); h.connect(l); l.connect(dest); n.start(Math.random() * 0.1, Math.random() * b.duration); return n;
}
export const LAYERS = {
  drizzle: (ctx, dest, m) => {
    const drops = m.drizzleBuf || (m.drizzleBuf = rainBuffer(ctx, { seconds: 17, rate: 0, big: 1.6, tone: 1.25, bigAmp: 1 }));
    const rain = m.rainBuf || (m.rainBuf = rainBuffer(ctx, { seconds: 12, rate: 1500, big: 10, tone: 0.8, bigAmp: 0.6 }));
    const g = ctx.createGain(); g.gain.value = 0.21; g.connect(dest);
    const back = ctx.createGain(); back.gain.value = 0.035; back.connect(dest);
    return [loopBuf(ctx, g, drops, 400, 4200), loopBuf(ctx, back, rain, 200, 2600)];
  },
  rain: (ctx, dest, m) => {
    const b = m.rainBuf || (m.rainBuf = rainBuffer(ctx, { seconds: 12, rate: 1500, big: 10, tone: 0.8, bigAmp: 0.6 }));
    const g = ctx.createGain(); g.gain.value = 0.17; g.connect(dest);
    const far = ctx.createGain(); far.gain.value = 0.14; far.connect(dest);
    const lo = ctx.createGain(); lo.gain.value = 0.12; lo.connect(dest);
    return [loopBuf(ctx, g, b, 220, 4000), loopBuf(ctx, far, b, 160, 1500), bed(ctx, lo, m.brown, 380)];
  },
  wind: (ctx, dest, m) => {
    const curve = (seed, secs) => {
      const sr = ctx.sampleRate, len = Math.floor(sr * secs), b = ctx.createBuffer(1, len, sr), d = b.getChannelData(0);
      let r = seed; const rnd = () => (r = (r * 16807) % 2147483647) / 2147483647;
      d.fill(0.06);
      for (let t = rnd() * 1.5; t < secs - 1; ) {
        const dur = 2.5 + rnd() * 2.5, peak = 0.55 + rnd() * 0.45, up = dur * (0.3 + rnd() * 0.15);
        for (let i = 0; i < dur * sr; i++) {
          const x = i / sr, k = Math.floor((t * sr + i) % len);
          const v = x < up ? Math.sin(x / up * Math.PI / 2) ** 2 : Math.cos((x - up) / (dur - up) * Math.PI / 2) ** 1.6;
          d[k] = Math.max(d[k], 0.06 + peak * v);
        }
        t += dur * (0.75 + rnd() * 0.35) + rnd() * 1.6;
      }
      return b;
    };
    const out = [];
    [[560, 10, 1, 360, 7], [840, 13, 0.6, 480, 11], [700, 1.2, 0.3, 260, 23]].forEach(([f, q, v, sweep, seed], i) => {
      const n = ctx.createBufferSource(), bp = ctx.createBiquadFilter(), lp = ctx.createBiquadFilter(), g = ctx.createGain();
      n.buffer = m.noise; n.loop = true; bp.type = 'bandpass'; bp.frequency.value = f; bp.Q.value = q; lp.type = 'lowpass'; lp.frequency.value = 2600;
      const env = ctx.createBufferSource(); env.buffer = m['windCurve' + i] || (m['windCurve' + i] = curve(seed * 7919, 31 + i * 6)); env.loop = true;
      g.gain.value = 0; const ga = ctx.createGain(); ga.gain.value = v; env.connect(ga); ga.connect(g.gain);
      const fs = ctx.createGain(); fs.gain.value = sweep; env.connect(fs); fs.connect(bp.frequency);
      n.connect(bp); bp.connect(lp); lp.connect(g); g.connect(dest); n.start(0, Math.random() * 2); env.start(0, Math.random() * 20); out.push(n, env);
    });
    return out;
  },
  water: (ctx, dest, m) => {
    const a = bed(ctx, dest, m.brown, 300);
    const n = ctx.createBufferSource(), bp = ctx.createBiquadFilter(), g = ctx.createGain(); n.buffer = m.brown; n.loop = true;
    bp.type = 'bandpass'; bp.frequency.value = 900; bp.Q.value = 1.4; g.gain.value = 0.35;
    const l = ctx.createOscillator(), lg = ctx.createGain(); l.frequency.value = 0.21; lg.gain.value = 300; l.connect(lg); lg.connect(bp.frequency);
    n.connect(bp); bp.connect(g); g.connect(dest); n.start(0, 1.3); l.start(); return [a, n, l];
  },
  hiss: (ctx, dest, m) => {
    const n = ctx.createBufferSource(), hp = ctx.createBiquadFilter(), lp = ctx.createBiquadFilter(); n.buffer = m.noise; n.loop = true;
    hp.type = 'highpass'; hp.frequency.value = 3000; lp.type = 'lowpass'; lp.frequency.value = 7000; n.connect(hp); hp.connect(lp); lp.connect(dest); n.start(); return [n];
  },
  mist: (ctx, dest) => {
    const o = ctx.createOscillator(), o2 = ctx.createOscillator(), t = ctx.createGain(), lfo = ctx.createOscillator(), lg = ctx.createGain();
    o.frequency.value = 55; o2.frequency.value = 58.3; o.type = o2.type = 'sine'; t.gain.value = 0.6; lfo.frequency.value = 0.3; lg.gain.value = 0.4; lfo.connect(lg); lg.connect(t.gain);
    o.connect(t); o2.connect(t); t.connect(dest); o.start(); o2.start(); lfo.start(); return [o, o2, lfo];
  },
};

const env = (g, t, peak, a, d) => { g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(Math.max(0.0002, peak), t + a); g.gain.exponentialRampToValueAtTime(0.0001, t + a + d); };
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
export function cricket(ctx, dest, t, vol = 1) {
  const f = 4300 + Math.random() * 500, n = 3 + Math.floor(Math.random() * 3);
  for (let i = 0; i < n; i++) {
    const s = t + i * 0.034, o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'sine'; o.frequency.value = f;
    env(g, s, 0.03 * vol, 0.003, 0.02); o.connect(g); g.connect(dest); o.start(s); o.stop(s + 0.03);
  }
}
export function owl(ctx, dest, t) {
  [[0, 390, 0.32], [0.5, 350, 0.42]].forEach(([d, f, len]) => {
    const o = ctx.createOscillator(), g = ctx.createGain(), lp = ctx.createBiquadFilter(); o.type = 'triangle'; o.frequency.setValueAtTime(f * 1.04, t + d); o.frequency.exponentialRampToValueAtTime(f, t + d + len);
    lp.type = 'lowpass'; lp.frequency.value = 900; env(g, t + d, 0.03, 0.08, len); o.connect(lp); lp.connect(g); g.connect(dest); o.start(t + d); o.stop(t + d + len + 0.15);
  });
}
export function drip(ctx, dest, t, vol = 1) {
  const o = ctx.createOscillator(), g = ctx.createGain(), f = 900 + Math.random() * 900; o.type = 'sine';
  o.frequency.setValueAtTime(f, t); o.frequency.exponentialRampToValueAtTime(f * 1.6, t + 0.05); env(g, t, 0.03 * vol, 0.002, 0.09); o.connect(g); g.connect(dest); o.start(t); o.stop(t + 0.14);
}
