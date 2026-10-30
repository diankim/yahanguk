// 지역 배경음악 미리듣기용: sound.js를 그대로 읽어 OfflineAudioContext에서 영역 하나를 몇십 초 굽는다(render.js가 부름)
window.renderRegion = async (territory, battle, seconds, sr = 32000) => {
  let code = await (await fetch('assets/js/sound.js')).text();
  code = code.replace(/^import .*$/m, 'const on = () => {};').replace(/^export /gm, '');
  code += `
;window.__render = async (territory, battle, seconds, sr) => {
  const off = new OfflineAudioContext(2, Math.ceil(seconds * sr), sr);
  window.AudioContext = function () { return off; };
  ctx = null; ensureCtx(); sound.bgm = 0.4; sound.bgmOn = true; applyVolumes(); bgmBus.gain.value = 0.32;
  scene.territory = territory; scene.battle = battle; scene.safe = false; env.phase = 'noon';
  const p = profile(), key = territory + ':' + p.mode + ':' + (battle ? 'battle' : 'field');
  await Promise.all(insOf(p).map(loadIns));
  song = makeSong(p, key, 0); barNo = 0; loopNo = 0;
  const beat = 60 / p.bpm, barDur = p.meter * beat; let t = 0.2;
  while (t < seconds - 3) { if (barNo >= song.bars.length) { loopNo++; song = makeSong(p, key, loopNo); barNo = song.loopStart; } playBar(p, song, song.bars[barNo], t, beat); barNo++; t += barDur; }
  const out = await off.startRendering();
  const n = out.length, L = out.getChannelData(0), R = out.getChannelData(1);
  let peak = 0; for (let i = 0; i < n; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
  const ab = new ArrayBuffer(44 + n * 4), v = new DataView(ab), w = (o, s) => [...s].forEach((c, i) => v.setUint8(o + i, c.charCodeAt(0)));
  w(0, 'RIFF'); v.setUint32(4, 36 + n * 4, true); w(8, 'WAVE'); w(12, 'fmt '); v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 2, true);
  v.setUint32(24, sr, true); v.setUint32(28, sr * 4, true); v.setUint16(32, 4, true); v.setUint16(34, 16, true); w(36, 'data'); v.setUint32(40, n * 4, true);
  const fade = 3 * sr, gn = 0.85 / Math.max(peak, 1e-4);
  for (let i = 0, o = 44; i < n; i++, o += 4) { const g = i > n - fade ? (n - i) / fade : 1; v.setInt16(o, Math.max(-1, Math.min(1, L[i] * g * gn)) * 32767, true); v.setInt16(o + 2, Math.max(-1, Math.min(1, R[i] * g * gn)) * 32767, true); }
  let bin = ''; const u8 = new Uint8Array(ab); for (let i = 0; i < u8.length; i += 0x8000) bin += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
  return { wav: btoa(bin), peak, bpm: Math.round(p.bpm), meter: p.meter, ins: insOf(p), form: p.form.map(f => f.s).join(' ') };
};`;
  const s = document.createElement('script'); s.textContent = code; document.head.append(s);
  return window.__render(territory, battle, seconds, sr);
};
