// 롤백 컷씬 「첫째 밤의 끝」 전용 곡: 게임 배경음악과 같은 녹음 악기 조각(assets/audio/*.mp3, FluidR3 GM)으로
// OfflineAudioContext에서 한 번 연주해 음원 하나로 굽는다(render.js가 헤드리스 브라우저에서 부르고 ffmpeg로 mp3를 만든다).
// D단조 72 BPM, 약 1분 47초(컷씬 75초에 맞춤): 도입 → 대금 주제 → 해금 변주 → 북이 몰아치는 고조 → 모든 악기가 겹치는 절정 → 가야금만 남는 끝.
// 마지막 「끝」 부분(OUTRO_AT초부터 곡 끝(end)까지)은 컷씬이 마지막 장면에 머무는 동안 조용히 되풀이한다.
window.composeCutscene = async function (sr = 32000) {
  const BPM = 72, B = 60 / BPM, BAR = 4 * B;
  const SLOT = 3.2;
  const INS = {
    koto: { notes: [45, 48, 51, 54, 57, 60, 63, 66, 69, 72, 75, 78, 81, 84], sus: false, gain: 0.5, pan: -0.3 },
    harp: { notes: [43, 47, 51, 55, 59, 63, 67, 71, 75, 79, 83, 87], sus: false, gain: 0.42, pan: 0.35 },
    shakuhachi: { notes: [57, 60, 63, 66, 69, 72, 75, 78, 81, 84, 87, 90], sus: true, gain: 0.55, pan: 0.05 },
    flute: { notes: [60, 63, 66, 69, 72, 75, 78, 81, 84, 87, 90, 93], sus: true, gain: 0.42, pan: -0.08 },
    fiddle: { notes: [55, 58, 61, 64, 67, 70, 73, 76, 79, 82, 85, 88], sus: true, gain: 0.45, pan: 0.12 },
    strings: { notes: [36, 40, 44, 48, 52, 56, 60, 64, 68, 72], sus: true, gain: 0.32, pan: 0 },
    cello: { notes: [33, 37, 41, 45, 49, 53, 57], sus: true, gain: 0.62, pan: -0.15 },
    bell: { notes: [60, 66, 72, 78, 84], sus: false, gain: 0.2, pan: 0.25 },
    taiko: { notes: [36], sus: false, gain: 0.7, pan: 0 },
  };
  const TOTAL_BARS = 32, DUR = TOTAL_BARS * BAR + 6;
  const ctx = new OfflineAudioContext(2, Math.ceil(DUR * sr), sr);
  const buf = {};
  await Promise.all(Object.keys(INS).map(async k => { const r = await fetch(`assets/audio/${k}.mp3`); buf[k] = await ctx.decodeAudioData(await r.arrayBuffer()); }));

  // 버스: 마른 소리 + 넓은 잔향(전각) + 마지막 압축
  const comp = ctx.createDynamicsCompressor(); comp.threshold.value = -16; comp.ratio.value = 3; comp.attack.value = 0.01; comp.release.value = 0.3;
  const master = ctx.createGain(); master.gain.value = 0.85; master.connect(comp); comp.connect(ctx.destination);
  const rev = ctx.createConvolver();
  const rl = sr * 4.2, ir = ctx.createBuffer(2, rl, sr);
  for (let ch = 0; ch < 2; ch++) { const d = ir.getChannelData(ch); let lp = 0; for (let i = 0; i < rl; i++) { const x = i / rl; lp += ((Math.random() * 2 - 1) - lp) * (0.28 - 0.24 * x); d[i] = lp * Math.pow(1 - x, 2) * 2.2; } }
  rev.buffer = ir; const rlp = ctx.createBiquadFilter(); rlp.type = 'lowpass'; rlp.frequency.value = 3600;
  const wet = ctx.createGain(); wet.gain.value = 0.42; rev.connect(rlp); rlp.connect(wet); wet.connect(master);

  // 음 하나: 가장 가까운 녹음 음을 골라 빠르기로 높이를 맞추고, 길게 끄는 악기는 가운데를 되풀이해 늘인다
  function note(ins, midi, t, dur, vel = 1, opt = {}) {
    const I = INS[ins]; if (!I) return;
    let idx = 0, best = 99; I.notes.forEach((n, i) => { const d = Math.abs(n - midi); if (d < best) { best = d; idx = i; } });
    const src = ctx.createBufferSource(); src.buffer = buf[ins];
    src.playbackRate.value = Math.pow(2, (midi - I.notes[idx]) / 12);
    const start = idx * SLOT;
    if (I.sus && dur > 2.4) { src.loop = true; src.loopStart = start + 0.9; src.loopEnd = start + 2.7; }
    const g = ctx.createGain(); const p = ctx.createStereoPanner(); p.pan.value = Math.max(-1, Math.min(1, (opt.pan ?? I.pan)));
    const peak = I.gain * vel, att = opt.att ?? (I.sus ? 0.12 : 0.004), rel = opt.rel ?? (I.sus ? 0.7 : 1.2);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(Math.max(0.0002, peak), t + att);
    if (opt.swell) g.gain.exponentialRampToValueAtTime(Math.max(0.0002, peak * opt.swell), t + dur * 0.8);
    const end = t + (I.sus ? dur : Math.min(dur, 2.8));
    g.gain.setValueAtTime(Math.max(0.0002, opt.swell ? peak * opt.swell : peak), Math.max(t + att, end - 0.05));
    g.gain.exponentialRampToValueAtTime(0.0001, end + rel);
    src.connect(g); g.connect(p); p.connect(master);
    const s = ctx.createGain(); s.gain.value = opt.send ?? 0.55; p.connect(s); s.connect(rev);
    src.start(t, start + (I.sus ? 0.02 : 0)); src.stop(end + rel + 0.05);
  }
  const bar = n => n * BAR; // 0부터
  // 화음(D단조): 마디마다
  const CH = { Dm: [50, 53, 57], Bb: [46, 50, 53], F: [53, 57, 60], C: [48, 52, 55], Gm: [55, 58, 62], Am: [57, 60, 64], A: [57, 61, 64], Eb: [51, 55, 58] };
  const ROOT = { Dm: 38, Bb: 34, F: 41, C: 36, Gm: 43, Am: 45, A: 45, Eb: 39 };
  const PROG = ['Dm', 'Bb', 'F', 'C', 'Gm', 'C', 'Am', 'Dm'];
  // 주제(8마디): [음, 박]
  const THEME = [
    [[69, 1.5], [67, .5], [65, 1], [64, 1]], [[62, 2], [57, 1], [62, 1]], [[65, 1.5], [67, .5], [69, 1], [72, 1]], [[69, 3], [0, 1]],
    [[70, 1.5], [69, .5], [67, 1], [65, 1]], [[64, 1.5], [65, .5], [67, 2]], [[69, 1], [65, 1], [64, 1], [60, 1]], [[62, 4]],
  ];
  function melody(ins, startBar, shift = 0, vel = 1, opt = {}, from = 0, count = 8) {
    THEME.slice(from, from + count).forEach((m, bi) => { let b = 0; m.forEach(([n, d]) => { if (n) note(ins, n + shift, bar(startBar + bi) + b * B, d * B * 0.98, vel, opt); b += d; }); });
  }
  function pad(startBar, bars, vel, octs = [0]) {
    for (let i = 0; i < bars; i++) { const c = CH[PROG[i % 8]]; for (const o of octs) c.forEach(n => note('strings', n + o, bar(startBar + i), BAR * 1.02, vel, { att: 0.6, rel: 1.2 })); }
  }
  function bass(startBar, bars, vel, pattern = 'half') {
    for (let i = 0; i < bars; i++) { const r = ROOT[PROG[i % 8]];
      if (pattern === 'whole') note('cello', r, bar(startBar + i), BAR, vel);
      else { note('cello', r, bar(startBar + i), 2 * B, vel); note('cello', r + (i % 2 ? 7 : 12), bar(startBar + i) + 2 * B, 2 * B, vel * 0.85); }
    }
  }
  function harpArp(startBar, bars, vel) {
    for (let i = 0; i < bars; i++) { const c = CH[PROG[i % 8]]; const seq = [c[0] + 12, c[1] + 12, c[2] + 12, c[1] + 24, c[2] + 12, c[1] + 12, c[0] + 24, c[2] + 12];
      seq.forEach((n, k) => note('harp', n, bar(startBar + i) + k * B / 2, B, vel * (k % 2 ? 0.75 : 1))); }
  }
  function kotoTrem(startBar, bars, vel) {
    for (let i = 0; i < bars; i++) { const c = CH[PROG[i % 8]]; for (let k = 0; k < 16; k++) note('koto', c[k % 3] + 24, bar(startBar + i) + k * B / 4, B / 2, vel * (k % 4 ? 0.6 : 1), { pan: -0.4 }); }
  }
  function drums(startBar, bars, vel, kind) {
    for (let i = 0; i < bars; i++) { const t0 = bar(startBar + i);
      if (kind === 'soft') { note('taiko', 36, t0, 1, vel); note('taiko', 36, t0 + 2 * B, 1, vel * 0.7); }
      else if (kind === 'epic') { [[0, 1], [1.5, .7], [2, .9], [3, .6], [3.5, .8]].forEach(([b, v]) => note('taiko', 36, t0 + b * B, 1, vel * v)); }
      else if (kind === 'roll') { const n = 8 + i * 4; for (let k = 0; k < n; k++) note('taiko', 36, t0 + k * BAR / n, 1, vel * (0.45 + 0.55 * (k / n))); }
    }
  }
  const bells = (startBar, bars, vel, every = 2) => { for (let i = 0; i < bars; i += every) note('bell', CH[PROG[i % 8]][0] + 24, bar(startBar + i), 3, vel); };

  // 컷씬(약 75초)에 맞춘 마디(1마디 3.33초): 등불이 꺼져 가는 동안 주제, 장부가 펼쳐질 때 고조,
  // 인장이 찍히는 59초 무렵 절정(18마디 = 60초), 제목이 뜨는 73초(22마디)에 길게 버티는 화음, 26마디부터 끝(되풀이).
  // ── 도입(1~4마디, 0~13초): 현악 바닥이 부풀고 종이 울린다
  pad(0, 4, 0.5, [0]); note('cello', 38, 0, BAR * 4, 0.65, { att: 2, rel: 2 });
  note('bell', 74, 0.4, 3, 0.9); note('bell', 69, bar(2), 3, 0.7); note('taiko', 36, bar(3) + 2 * B, 1, 0.45);
  // ── 주제(5~12, 13~40초): 대금이 홀로 주제, 하프 분산화음, 첼로. 뒤 네 마디는 해금이 위에서 겹친다
  melody('shakuhachi', 4, 0, 0.95);
  melody('fiddle', 8, 12, 0.55, { swell: 1.15 }, 4, 4);
  pad(4, 8, 0.45); bass(4, 4, 0.55, 'whole'); bass(8, 4, 0.6); harpArp(4, 8, 0.42); bells(4, 8, 0.5, 4);
  drums(8, 4, 0.45, 'soft');
  // ── 변주(13~16, 40~53초): 해금이 주제 앞 네 마디를 받고 가야금이 받아친다, 북이 걸음을 뗀다
  melody('fiddle', 12, 12, 0.85, { swell: 1.15 }, 0, 4);
  for (let bi = 0; bi < 4; bi++) { note('koto', CH[PROG[bi]][2] + 12, bar(12 + bi) + 3 * B, B, 0.8); note('koto', CH[PROG[bi]][0] + 24, bar(12 + bi) + 3.5 * B, B, 0.6); }
  pad(12, 4, 0.5, [0, 12]); bass(12, 4, 0.65); harpArp(12, 4, 0.4); drums(12, 4, 0.55, 'soft'); bells(12, 4, 0.6, 2);
  // ── 고조(17~18, 53~60초): 장부가 펼쳐진 뒤, 현악이 올라가고 북이 몰아친다
  for (let i = 0; i < 2; i++) { const k = ['Gm', 'A'][i]; CH[k].forEach(n => { note('strings', n + 12, bar(16 + i), BAR, 0.6 + i * 0.15, { att: 0.3 }); note('strings', n, bar(16 + i), BAR, 0.55 + i * 0.15, { att: 0.3 }); }); note('cello', ROOT[k], bar(16 + i), BAR, 0.8); }
  drums(16, 2, 0.8, 'roll'); kotoTrem(17, 1, 0.5);
  [69, 70, 72, 73, 74].forEach((n, k) => note('flute', n, bar(17) + k * B * 0.8, B * 0.9, 0.75));
  // ── 절정(19~22, 60~73초): 인장이 찍히고 먹이 번지는 동안 — 대금·플루트·해금이 겹쳐 주제 끝 네 마디, 세 옥타브 현악, 북 장단, 가야금 트레몰로, 종
  note('taiko', 36, bar(18), 1, 1.1); note('bell', 74, bar(18), 3, 1);
  melody('flute', 18, 12, 1.0, {}, 4, 4); melody('fiddle', 18, 12, 0.9, {}, 4, 4); melody('shakuhachi', 18, 0, 0.9, {}, 4, 4);
  for (let i = 0; i < 4; i++) { const k = PROG[4 + i]; CH[k].forEach(n => [-12, 0, 12].forEach(o => note('strings', n + o, bar(18 + i), BAR * 1.02, 0.6, { att: 0.2, rel: 1.2 }))); note('cello', ROOT[k], bar(18 + i), 2 * B, 0.9); note('cello', ROOT[k] + 12, bar(18 + i) + 2 * B, 2 * B, 0.75); }
  drums(18, 3, 1.0, 'epic'); drums(21, 1, 0.95, 'roll'); kotoTrem(18, 4, 0.42); bells(18, 4, 0.85, 1); harpArp(18, 4, 0.35);
  // ── 절정의 끝(23~26, 73~87초): 제목이 뜬다. 길게 버티는 화음, 북 한 번씩, 위에서 해금이 울부짖는다
  window.RESOLVE_AT = bar(22);
  [['Bb', 22], ['C', 23], ['A', 24], ['Dm', 25]].forEach(([c, b]) => {
    CH[c].forEach(n => [-12, 0, 12].forEach(o => note('strings', n + o, bar(b), BAR * 1.05, 0.62 - (b - 22) * 0.06, { att: 0.15 })));
    note('cello', ROOT[c], bar(b), BAR, 0.9 - (b - 22) * 0.1); note('taiko', 36, bar(b), 1, 1 - (b - 22) * 0.18); note('bell', CH[c][0] + 24, bar(b), 3, 0.9 - (b - 22) * 0.12);
  });
  [[74, 2], [72, 1], [70, 1], [69, 2], [67, 1], [69, 1], [73, 3], [74, 5]].reduce((t, [n, d]) => { note('fiddle', n + 12, t, d * B, 0.95, { swell: 1.1 }); note('flute', n, t, d * B, 0.7); return t + d * B; }, bar(22));
  // ── 끝(27~32, 87~107초): 모두 빠지고 가야금이 주제 조각을 짚는다, 마지막은 D·A 빈 오도. 마지막 장면에 머무는 동안 여기를 되풀이한다
  window.OUTRO_AT = bar(26);
  pad(26, 6, 0.3); note('cello', 38, bar(26), BAR * 6, 0.42, { att: 1.5, rel: 3 });
  [[69, 0], [67, 1.5], [65, 2], [64, 3], [62, 4], [57, 6], [62, 7]].forEach(([n, b]) => note('koto', n, bar(27) + b * B, 2, 0.75));
  [[65, 0], [67, 1.5], [69, 2], [72, 3], [69, 4]].forEach(([n, b]) => note('koto', n, bar(29) + b * B, 2, 0.6));
  note('bell', 74, bar(31), 3, 0.6); note('strings', 50, bar(31), BAR * 1.2, 0.38, { att: 0.5, rel: 2.5 }); note('strings', 57, bar(31), BAR * 1.2, 0.33, { att: 0.5, rel: 2.5 });

  const out = await ctx.startRendering();
  // 16비트 WAV
  const n = out.length, ch0 = out.getChannelData(0), ch1 = out.getChannelData(1);
  let peak = 0; for (let i = 0; i < n; i++) peak = Math.max(peak, Math.abs(ch0[i]), Math.abs(ch1[i]));
  const norm = peak > 0 ? 0.92 / peak : 1;
  const ab = new ArrayBuffer(44 + n * 4), v = new DataView(ab);
  const w = (o, s) => [...s].forEach((c, i) => v.setUint8(o + i, c.charCodeAt(0)));
  w(0, 'RIFF'); v.setUint32(4, 36 + n * 4, true); w(8, 'WAVE'); w(12, 'fmt '); v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 2, true);
  v.setUint32(24, sr, true); v.setUint32(28, sr * 4, true); v.setUint16(32, 4, true); v.setUint16(34, 16, true); w(36, 'data'); v.setUint32(40, n * 4, true);
  for (let i = 0, o = 44; i < n; i++, o += 4) { v.setInt16(o, Math.max(-1, Math.min(1, ch0[i] * norm)) * 32767, true); v.setInt16(o + 2, Math.max(-1, Math.min(1, ch1[i] * norm)) * 32767, true); }
  let bin = ''; const u8 = new Uint8Array(ab); for (let i = 0; i < u8.length; i += 0x8000) bin += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
  return { wav: btoa(bin), outro: window.OUTRO_AT, resolve: window.RESOLVE_AT, end: TOTAL_BARS * BAR, dur: DUR };
};
