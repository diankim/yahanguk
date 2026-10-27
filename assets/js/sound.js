// 음향: 브라우저에서 직접 연주하는 동양풍 배경음악(영역마다 다른 곡조) · 날씨·시간대 환경음 · 행동별 효과음.
// 외부 음원을 쓰지 않으므로 저작권 걱정이 없고 내려받을 파일도 없다.
import { on } from './core.js';

export const sound = { bgm: 0.4, sfx: 0.55, amb: 0.35, bgmOn: true, sfxOn: true, ambOn: true };
let ctx, master, bgmBus, ambBus, sfxBus, reverb, noiseBuf, brownBuf;
const scene = { territory: 'capital', safe: false, battle: false };
// 모바일(터치 화면)에서는 화면을 내리거나 다른 앱·다른 탭으로 가면 소리를 멈춘다. PC는 계속 들린다.
const MOBILE = (() => { try { return matchMedia('(pointer: coarse)').matches || /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent); } catch { return false; } })();
let away = false;
let env = { weather: 'clear', phase: 'noon' };

export function loadSound() { try { Object.assign(sound, JSON.parse(localStorage.getItem('yh-sound') || '{}')); } catch {} }
export function saveSound() { try { localStorage.setItem('yh-sound', JSON.stringify(sound)); } catch {} }
export function applyVolumes() {
  if (!ctx) return;
  const t = ctx.currentTime;
  bgmBus.gain.setTargetAtTime(sound.bgmOn ? sound.bgm * 0.32 : 0, t, 0.3);
  ambBus.gain.setTargetAtTime(sound.ambOn ? sound.amb * 0.5 : 0, t, 0.4);
  sfxBus.gain.setTargetAtTime(sound.sfxOn ? sound.sfx * 0.5 : 0, t, 0.05);
}

function ensureCtx() {
  if (ctx) return ctx;
  const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return null;
  ctx = new AC();
  master = ctx.createGain(); master.gain.value = 0.9; master.connect(ctx.destination);
  bgmBus = ctx.createGain(); ambBus = ctx.createGain(); sfxBus = ctx.createGain();
  [bgmBus, ambBus, sfxBus].forEach(g => { g.gain.value = 0; g.connect(master); });
  // 잔향: 짧게 흩어지는 소음으로 만든 공간감
  reverb = ctx.createConvolver();
  const len = ctx.sampleRate * 2.6, ir = ctx.createBuffer(2, len, ctx.sampleRate);
  for (let ch = 0; ch < 2; ch++) { const d = ir.getChannelData(ch); for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 3.2); }
  reverb.buffer = ir;
  const wet = ctx.createGain(); wet.gain.value = 0.38; reverb.connect(wet); wet.connect(bgmBus);
  // 소음 재료
  noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
  const nd = noiseBuf.getChannelData(0); for (let i = 0; i < nd.length; i++) nd[i] = Math.random() * 2 - 1;
  brownBuf = ctx.createBuffer(1, ctx.sampleRate * 4, ctx.sampleRate);
  const bd = brownBuf.getChannelData(0); let last = 0;
  for (let i = 0; i < bd.length; i++) { last = (last + 0.02 * (Math.random() * 2 - 1)) / 1.02; bd[i] = last * 3.5; }
  applyVolumes();
  return ctx;
}
const now = () => ctx.currentTime;
function envGain(g, t, peak, a, d) { g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(Math.max(0.0002, peak), t + a); g.gain.exponentialRampToValueAtTime(0.0001, t + a + d); }
function toBgm(node, send = 0.5) { node.connect(bgmBus); if (send > 0) { const s = ctx.createGain(); s.gain.value = send; node.connect(s); s.connect(reverb); } }

/* ── 악기 ─────────────────────────────────────────────── */
// 가야금처럼 뜯는 소리: 빠르게 열렸다 닫히는 저역 통과와 짧은 농현(음 떨림)
function pluck(f, t, dur, vol, bend = false) {
  const o = ctx.createOscillator(), o2 = ctx.createOscillator(), lp = ctx.createBiquadFilter(), g = ctx.createGain(), g2 = ctx.createGain();
  o.type = 'triangle'; o.frequency.setValueAtTime(f, t); o2.type = 'sine'; o2.frequency.setValueAtTime(f * 2, t); g2.gain.value = 0.25;
  if (bend) { o.detune.setValueAtTime(0, t + 0.12); o.detune.linearRampToValueAtTime(45, t + 0.35); o.detune.linearRampToValueAtTime(-10, t + 0.6); o.detune.linearRampToValueAtTime(0, t + 0.8); }
  lp.type = 'lowpass'; lp.frequency.setValueAtTime(3800, t); lp.frequency.exponentialRampToValueAtTime(700, t + 0.4); lp.Q.value = 2;
  envGain(g, t, vol, 0.004, Math.min(2.6, dur * 1.6 + 0.4));
  o.connect(lp); o2.connect(g2); g2.connect(lp); lp.connect(g); toBgm(g, 0.45);
  const end = t + Math.min(3.2, dur * 1.6 + 0.6); o.start(t); o2.start(t); o.stop(end); o2.stop(end);
}
// 대금처럼 부는 소리: 사인파에 늦게 들어오는 떨림과 숨소리
function flute(f, t, dur, vol) {
  const o = ctx.createOscillator(), g = ctx.createGain(), lfo = ctx.createOscillator(), lg = ctx.createGain();
  o.type = 'sine'; o.frequency.setValueAtTime(f * 0.985, t); o.frequency.exponentialRampToValueAtTime(f, t + 0.12);
  lfo.frequency.value = 5.2; lg.gain.setValueAtTime(0, t); lg.gain.linearRampToValueAtTime(f * 0.006, t + Math.min(0.6, dur * 0.5));
  lfo.connect(lg); lg.connect(o.frequency);
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + 0.18);
  g.gain.setValueAtTime(vol, t + Math.max(0.2, dur - 0.25)); g.gain.exponentialRampToValueAtTime(0.0001, t + dur + 0.35);
  o.connect(g); toBgm(g, 0.6);
  const n = ctx.createBufferSource(), bp = ctx.createBiquadFilter(), ng = ctx.createGain();
  n.buffer = noiseBuf; bp.type = 'bandpass'; bp.frequency.value = f * 2.2; bp.Q.value = 1.4; envGain(ng, t, vol * 0.18, 0.08, dur);
  n.connect(bp); bp.connect(ng); toBgm(ng, 0.3);
  o.start(t); lfo.start(t); n.start(t); o.stop(t + dur + 0.4); lfo.stop(t + dur + 0.4); n.stop(t + dur + 0.4);
}
// 장구·북: 낮게 떨어지는 사인파와 짧은 소음
function drum(t, kind, vol) {
  if (kind === 'buk') {
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = 'sine'; o.frequency.setValueAtTime(95, t); o.frequency.exponentialRampToValueAtTime(48, t + 0.25);
    envGain(g, t, vol, 0.004, 0.35); o.connect(g); toBgm(g, 0.25); o.start(t); o.stop(t + 0.45);
  } else {
    const n = ctx.createBufferSource(), hp = ctx.createBiquadFilter(), g = ctx.createGain();
    n.buffer = noiseBuf; hp.type = 'bandpass'; hp.frequency.value = kind === 'deok' ? 900 : 2600; hp.Q.value = 0.8;
    envGain(g, t, vol, 0.002, kind === 'deok' ? 0.12 : 0.06); n.connect(hp); hp.connect(g); toBgm(g, 0.2); n.start(t); n.stop(t + 0.2);
  }
}
// 맑은 종: 배음이 어긋난 두 사인파
function bell(f, t, vol) {
  [[1, 1], [2.76, 0.35], [5.4, 0.12]].forEach(([m, v]) => {
    const o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'sine'; o.frequency.value = f * m;
    envGain(g, t, vol * v, 0.003, 3.2); o.connect(g); toBgm(g, 0.7); o.start(t); o.stop(t + 3.5);
  });
}

/* ── 곡조 ─────────────────────────────────────────────── */
// 지역마다 정해진 주제 선율을 A·A′·B·A 형식으로 되풀이한다(같은 지역에서는 같은 곡이 들려 기억에 남는다).
// 선율은 대금·해금처럼 음과 음을 미끄러지듯 이어 부르고, 아래에 가야금 분산화음과 은은한 화음을 깔아 빈틈 없이 흐르게 한다.
const PYEONG = [0, 2, 5, 7, 9], GYEMYEON = [0, 3, 5, 7, 10], DARK = [0, 1, 5, 7, 8];
const PROFILES = {
  capital:    { scale: PYEONG, root: 293.66, bpm: 76, lead: 'daegeum', drum: 0.45, bell: 0.05, drone: 0.2 },
  north:      { scale: GYEMYEON, root: 220.0, bpm: 66, lead: 'haegeum', drum: 0.3, bell: 0, drone: 0.3 },
  east:       { scale: PYEONG, root: 329.63, bpm: 84, lead: 'daegeum', drum: 0.3, bell: 0.08, drone: 0.15 },
  south:      { scale: GYEMYEON, root: 196.0, bpm: 72, lead: 'haegeum', drum: 0.3, bell: 0, drone: 0.25 },
  frontier:   { scale: GYEMYEON, root: 261.63, bpm: 92, lead: 'haegeum', drum: 0.7, bell: 0, drone: 0.35 },
  underworld: { scale: GYEMYEON, root: 174.61, bpm: 62, lead: 'daegeum', drum: 0.2, bell: 0.12, drone: 0.45 },
  heavenward: { scale: PYEONG, root: 440.0, bpm: 70, lead: 'daegeum', drum: 0.1, bell: 0.35, drone: 0.2 },
  abyss:      { scale: DARK, root: 146.83, bpm: 58, lead: 'haegeum', drum: 0.25, bell: 0.15, drone: 0.55 },
};
const noteOf = (p, deg) => { const s = p.scale, oct = Math.floor(deg / s.length), i = ((deg % s.length) + s.length) % s.length; return p.root * Math.pow(2, oct + s[i] / 12); };
let playing = false, phraseTimer = null, droneNodes = null, droneKey = '';
let song = null, songKey = '', barNo = 0, nextAt = 0;

function profile() {
  const base = PROFILES[scene.territory] || PROFILES.capital;
  const p = { ...base };
  if (scene.safe) { p.bpm *= 0.9; p.drum *= 0.2; }
  if (scene.battle) { p.bpm *= 1.3; p.drum = Math.min(1, p.drum + 0.45); }
  if (env.phase === 'night') { p.bpm *= 0.94; p.bell += 0.05; }
  return p;
}

// 정해진 씨앗으로 늘 같은 곡을 만든다
function seeded(str) { let h = 2166136261; for (const ch of str) h = Math.imul(h ^ ch.charCodeAt(0), 16777619); return () => { h = Math.imul(h ^ (h >>> 15), 2246822507) ^ Math.imul(h ^ (h >>> 13), 3266489909); h >>>= 0; return h / 4294967296; }; }
const RHYTHMS = [[2, 1, 1], [1, 1, 2], [1, 1, 1, 1], [1.5, 0.5, 2], [3, 1], [1, 0.5, 0.5, 2], [2, 2], [0.5, 0.5, 1, 2], [1, 2, 1]];
const BATTLE_RHYTHMS = [[1, 1, 1, 1], [0.5, 0.5, 1, 1, 1], [1, 0.5, 0.5, 1, 1], [0.5, 0.5, 0.5, 0.5, 2]];
// 화음 뿌리(음계 안 위치): A는 으뜸에서 떠나 돌아오고, B는 위쪽으로 넘어갔다 내려온다
const PROG_A = [[0, 3, 1, 0], [0, 1, 3, 0], [0, 3, 4, 0]], PROG_B = [[3, 1, 4, 3], [1, 3, 2, 4], [3, 4, 1, 3]];
function makeSong(key, battle) {
  const r = seeded(key), pick = a => a[Math.floor(r() * a.length)];
  const section = (prog, startDeg, endDeg) => {
    let d = startDeg;
    return prog.map((chord, bi) => {
      const rh = battle ? pick(BATTLE_RHYTHMS) : pick(RHYTHMS);
      const notes = rh.map((len, ni) => {
        // 첫 박은 화음 음(뿌리·3도·5도)에 붙이고, 나머지는 한두 칸씩 걸어간다
        if (ni === 0) { const tones = [chord, chord + 2, chord + 3, chord + 5, chord + 7]; d = tones.reduce((a, b) => Math.abs(b - d) < Math.abs(a - d) ? b : a); }
        else d += pick([-1, -1, 1, 1, -2, 2, 0, 1, -1]);
        d = Math.max(1, Math.min(9, d));
        // 단락 끝 음은 길게, 정해진 음으로 맺는다
        if (bi === prog.length - 1 && ni === rh.length - 1) d = endDeg;
        return [d, len];
      });
      return { chord, notes };
    });
  };
  const A = section(pick(PROG_A), 3 + Math.floor(r() * 3), 5), B = section(pick(PROG_B), 6 + Math.floor(r() * 2), 6);
  // A′: 마지막 두 마디만 살짝 바꿔 맺음을 다르게 한다
  const A2 = A.map((b, i) => i < 2 ? b : { chord: b.chord, notes: b.notes.map(([d, l], j) => [j === b.notes.length - 1 && i === 3 ? 3 : d + (j % 2 ? 1 : 0), l]) });
  return [...A, ...A2, ...B, ...A];
}

// 이어 부르는 선율: 마디 하나를 한 소리로 불며 음마다 미끄러지듯 옮겨 간다(대금은 맑게, 해금은 콧소리처럼)
function legato(p, notes, t, beat, vol) {
  const o = ctx.createOscillator(), o2 = ctx.createOscillator(), mix = ctx.createGain(), lp = ctx.createBiquadFilter(), g = ctx.createGain();
  const lfo = ctx.createOscillator(), lg = ctx.createGain();
  const hae = p.lead === 'haegeum';
  o.type = hae ? 'sawtooth' : 'sine'; o2.type = 'triangle'; mix.gain.value = hae ? 0.35 : 0.18;
  lp.type = 'lowpass'; lp.frequency.value = hae ? 1500 : 2600; lp.Q.value = hae ? 3 : 0.7;
  lfo.frequency.value = hae ? 5.6 : 4.8; lg.gain.value = 0;
  lfo.connect(lg); lg.connect(o.frequency); lg.connect(o2.frequency);
  o.connect(lp); o2.connect(mix); mix.connect(lp); lp.connect(g); toBgm(g, 0.55);
  const v = hae ? vol * 0.55 : vol;
  let at = t; g.gain.setValueAtTime(0.0001, t);
  notes.forEach(([d, len], i) => {
    const f = noteOf(p, d), dur = len * beat;
    if (i === 0) { o.frequency.setValueAtTime(f * 0.985, at); o2.frequency.setValueAtTime(f, at); }
    o.frequency.setTargetAtTime(f, at, 0.035); o2.frequency.setTargetAtTime(f, at, 0.035);
    // 음이 바뀔 때 숨을 살짝 고르듯 소리를 낮췄다 올린다
    g.gain.setTargetAtTime(v * (i === 0 ? 1 : 0.75), at, 0.02); g.gain.setTargetAtTime(v, at + 0.06, 0.08);
    // 긴 음에는 늦게 떨림(농음)을 건다
    lg.gain.setTargetAtTime(0, at, 0.05); if (dur > beat * 1.2) lg.gain.setTargetAtTime(f * (hae ? 0.012 : 0.007), at + dur * 0.4, 0.15);
    at += dur;
  });
  g.gain.setTargetAtTime(0.0001, at - 0.05, 0.12);
  // 대금의 숨소리
  if (!hae) {
    const n = ctx.createBufferSource(), bp = ctx.createBiquadFilter(), ng = ctx.createGain();
    n.buffer = noiseBuf; bp.type = 'bandpass'; bp.frequency.value = noteOf(p, notes[0][0]) * 2.2; bp.Q.value = 1.2;
    ng.gain.setValueAtTime(0.0001, t); ng.gain.setTargetAtTime(vol * 0.08, t, 0.1); ng.gain.setTargetAtTime(0.0001, at - 0.05, 0.12);
    n.connect(bp); bp.connect(ng); toBgm(ng, 0.3); n.start(t); n.stop(at + 0.6);
  }
  [o, o2, lfo].forEach(x => { x.start(t); x.stop(at + 0.7); });
}
// 은은한 화음: 마디 내내 뿌리·5도를 길게 깐다
function pad(p, chord, t, dur, vol) {
  [chord - 5, chord - 2].forEach((d, i) => {
    const o = ctx.createOscillator(), lp = ctx.createBiquadFilter(), g = ctx.createGain();
    o.type = 'triangle'; o.frequency.value = noteOf(p, d); o.detune.value = i ? 4 : -4;
    lp.type = 'lowpass'; lp.frequency.value = 900;
    g.gain.setValueAtTime(0.0001, t); g.gain.setTargetAtTime(vol, t, 0.35); g.gain.setTargetAtTime(0.0001, t + dur - 0.1, 0.4);
    o.connect(lp); lp.connect(g); toBgm(g, 0.6); o.start(t); o.stop(t + dur + 1.6);
  });
}
function phrase() {
  if (!playing || !ctx || away) return;
  const p = profile(), beat = 60 / p.bpm, key = `${scene.territory || 'capital'}:${scene.battle ? 'b' : 'n'}`;
  if (key !== songKey || !song) { song = makeSong(key, scene.battle); songKey = key; barNo = 0; }
  if (nextAt < now() + 0.05) nextAt = now() + 0.12;
  const t = nextAt, bar = song[barNo % song.length], barDur = 4 * beat;
  // 되풀이할 때마다 조금씩 다르게: 한 음을 한 칸 옮기거나 끝음을 한 옥타브 위에서 부른다
  const notes = bar.notes.map(([d, l]) => [d, l]);
  if (barNo >= song.length && Math.random() < 0.3) { const k = Math.floor(Math.random() * notes.length); notes[k][0] += Math.random() < 0.5 ? 1 : -1; }
  legato(p, notes, t, beat, 0.07);
  pad(p, bar.chord, t, barDur, 0.022);
  // 가야금 분산화음: 박마다(전투에서는 반 박마다) 화음 음을 아래에서 짚는다
  const arp = [bar.chord - 5, bar.chord - 3, bar.chord, bar.chord - 3], step = scene.battle ? 0.5 : 1;
  for (let b = 0, i = 0; b < 4; b += step, i++) pluck(noteOf(p, arp[i % arp.length]), t + b * beat, beat * step, i % 4 === 0 ? 0.06 : 0.04, false);
  if (Math.random() < p.bell) bell(noteOf(p, bar.chord + 5), t + 2 * beat, 0.025);
  // 장단: 첫 박 북, 셋째 박 덕, 사이사이 작은 소리
  if (p.drum > 0.05) for (let b = 0; b < 4; b++) {
    const bt = t + b * beat;
    if (b === 0) drum(bt, 'buk', 0.2 * p.drum);
    else if (b === 2) drum(bt, 'deok', 0.07 * p.drum);
    else if (Math.random() < p.drum * 0.6) drum(bt + (scene.battle ? beat / 2 : 0), 'tick', 0.05 * p.drum);
  }
  barNo++; nextAt = t + barDur;
  // 다음 마디를 미리(0.3초 앞서) 예약해 마디 사이가 끊기지 않게 한다
  phraseTimer = setTimeout(phrase, Math.max(50, (nextAt - now() - 0.3) * 1000));
}
function updateDrone() {
  if (!ctx) return;
  const p = profile(), key = `${scene.territory}:${scene.battle}`;
  if (droneKey === key && droneNodes) return;
  droneKey = key;
  if (droneNodes) { const old = droneNodes; old.g.gain.setTargetAtTime(0.0001, now(), 1.2); setTimeout(() => old.os.forEach(o => { try { o.stop(); } catch {} }), 4000); droneNodes = null; }
  if (!playing || p.drone <= 0) return;
  const g = ctx.createGain(), lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 600;
  g.gain.value = 0.0001; g.gain.setTargetAtTime(0.05 * p.drone, now(), 2);
  const os = [p.root / 2, p.root * 0.75].map((f, i) => { const o = ctx.createOscillator(); o.type = i ? 'sine' : 'triangle'; o.frequency.value = f; o.connect(lp); o.start(); return o; });
  const lfo = ctx.createOscillator(), lg = ctx.createGain(); lfo.frequency.value = 0.07; lg.gain.value = 0.02 * p.drone; lfo.connect(lg); lg.connect(g.gain); lfo.start(); os.push(lfo);
  lp.connect(g); toBgm(g, 0.5);
  droneNodes = { g, os };
}
function startMusic() { if (playing || !ensureCtx()) return; playing = true; ctx.resume?.(); updateDrone(); nextAt = 0; phraseTimer = setTimeout(phrase, 600); }
function stopMusic() { playing = false; clearTimeout(phraseTimer); updateDrone(); droneKey = ''; }

/* ── 환경음 ───────────────────────────────────────────── */
const layers = {};
function loopLayer(name, build) {
  if (layers[name]) return layers[name];
  const g = ctx.createGain(); g.gain.value = 0.0001; g.connect(ambBus);
  layers[name] = { g, nodes: build(g) };
  return layers[name];
}
function setLayer(name, level, build) {
  if (!ctx) return;
  if (level <= 0 && !layers[name]) return;
  const L = loopLayer(name, build);
  L.g.gain.setTargetAtTime(Math.max(0.0001, level), now(), 1.5);
}
const noiseSrc = (buf) => { const n = ctx.createBufferSource(); n.buffer = buf; n.loop = true; n.start(); return n; };
const BUILD = {
  rain: g => { const n = noiseSrc(noiseBuf), hp = ctx.createBiquadFilter(), lp = ctx.createBiquadFilter(); hp.type = 'highpass'; hp.frequency.value = 900; lp.type = 'lowpass'; lp.frequency.value = 6500; n.connect(hp); hp.connect(lp); lp.connect(g); return [n]; },
  wind: g => {
    const n = noiseSrc(brownBuf), lp = ctx.createBiquadFilter(), lfo = ctx.createOscillator(), lg = ctx.createGain(), gust = ctx.createGain(), glfo = ctx.createOscillator(), glg = ctx.createGain();
    lp.type = 'lowpass'; lp.frequency.value = 520; lp.Q.value = 3; lfo.frequency.value = 0.06; lg.gain.value = 320; lfo.connect(lg); lg.connect(lp.frequency);
    gust.gain.value = 0.7; glfo.frequency.value = 0.045; glg.gain.value = 0.3; glfo.connect(glg); glg.connect(gust.gain);
    n.connect(lp); lp.connect(gust); gust.connect(g); lfo.start(); glfo.start(); return [n, lfo, glfo];
  },
  water: g => { const n = noiseSrc(brownBuf), lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 260; n.connect(lp); lp.connect(g); return [n]; },
  hiss: g => { const n = noiseSrc(noiseBuf), hp = ctx.createBiquadFilter(); hp.type = 'highpass'; hp.frequency.value = 5200; n.connect(hp); hp.connect(g); return [n]; },
  mist: g => {
    const o = ctx.createOscillator(), o2 = ctx.createOscillator(), t = ctx.createGain(), lfo = ctx.createOscillator(), lg = ctx.createGain();
    o.frequency.value = 55; o2.frequency.value = 58.3; o.type = o2.type = 'sine'; t.gain.value = 0.6; lfo.frequency.value = 0.3; lg.gain.value = 0.4; lfo.connect(lg); lg.connect(t.gain);
    o.connect(t); o2.connect(t); t.connect(g); o.start(); o2.start(); lfo.start(); return [o, o2, lfo];
  },
};
let critterTimer = null;
// 짧게 끊어지는 소리들: 새·풀벌레·물방울·부엉이
function critters() {
  clearTimeout(critterTimer);
  if (away) return;
  if (!ctx || !sound.ambOn) { critterTimer = setTimeout(critters, 4000); return; }
  const under = scene.territory === 'underworld' || scene.territory === 'abyss';
  const t = now() + 0.05, ph = env.phase, w = env.weather;
  const quiet = w === 'rain' || w === 'snow' || w === 'wind';
  if (!under && (ph === 'dawn' || ph === 'noon') && !quiet && Math.random() < (ph === 'dawn' ? 0.55 : 0.3)) {
    const n = 2 + Math.floor(Math.random() * 4), base = 2600 + Math.random() * 1200;
    for (let i = 0; i < n; i++) { const o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'sine'; const s = t + i * (0.09 + Math.random() * 0.05);
      o.frequency.setValueAtTime(base, s); o.frequency.exponentialRampToValueAtTime(base * (1.25 + Math.random() * 0.3), s + 0.07); envGain(g, s, 0.05, 0.005, 0.08); o.connect(g); g.connect(ambBus); o.start(s); o.stop(s + 0.12); }
  }
  if (!under && (ph === 'dusk' || ph === 'night') && w !== 'snow' && w !== 'rain') {
    const n = 3 + Math.floor(Math.random() * 3);
    for (let i = 0; i < n; i++) { const o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'sine'; o.frequency.value = 4400 + Math.random() * 300; const s = t + i * 0.045;
      envGain(g, s, ph === 'night' ? 0.022 : 0.014, 0.004, 0.03); o.connect(g); g.connect(ambBus); o.start(s); o.stop(s + 0.05); }
    if (ph === 'night' && Math.random() < 0.05) { [0, 0.45].forEach((d, i) => { const o = ctx.createOscillator(), g = ctx.createGain(); o.frequency.value = i ? 340 : 390; envGain(g, t + 1 + d, 0.03, 0.06, 0.35); o.connect(g); g.connect(ambBus); o.start(t + 1 + d); o.stop(t + 1.6 + d); }); }
  }
  if (w === 'rain' || w === 'fog' || under) {
    if (Math.random() < (w === 'rain' ? 0.8 : 0.3)) { const o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'sine'; const f = 1800 + Math.random() * 2000;
      o.frequency.setValueAtTime(f, t); o.frequency.exponentialRampToValueAtTime(f * 0.6, t + 0.05); envGain(g, t, 0.025, 0.002, 0.06); o.connect(g); g.connect(ambBus); o.start(t); o.stop(t + 0.1); }
  }
  const gap = ph === 'dusk' || ph === 'night' ? 500 + Math.random() * 900 : 1800 + Math.random() * 4000;
  critterTimer = setTimeout(critters, gap);
}
function updateAmbience() {
  if (!ctx) return;
  const w = env.weather, under = scene.territory === 'underworld' || scene.territory === 'abyss';
  setLayer('rain', w === 'rain' ? 0.12 : 0, BUILD.rain);
  setLayer('wind', (({ wind: 0.5, snow: 0.28, cloudy: 0.12, clear: 0.07, bloodmist: 0.12, fog: 0.05, rain: 0.06 })[w] || 0) * (under ? 0.4 : 1), BUILD.wind);
  setLayer('water', w === 'fog' || under ? 0.35 : w === 'rain' ? 0.15 : 0, BUILD.water);
  setLayer('hiss', w === 'snow' ? 0.012 : 0, BUILD.hiss);
  setLayer('mist', w === 'bloodmist' ? 0.05 : 0, BUILD.mist);
}

/* ── 효과음(짧고 단순하게) ───────────────────────────── */
function tone(freq, dur, vol = 0.1, type = 'sine', at = 0, glide) {
  const t0 = now() + at, o = ctx.createOscillator(), g = ctx.createGain(); o.type = type; o.frequency.setValueAtTime(freq, t0);
  if (glide) o.frequency.exponentialRampToValueAtTime(glide, t0 + dur);
  envGain(g, t0, vol, Math.min(0.012, dur / 4), dur); o.connect(g); g.connect(sfxBus); o.start(t0); o.stop(t0 + dur + 0.05);
}
const seq = (notes, step, dur, vol, type = 'sine') => notes.forEach((f, i) => tone(f, dur, vol, type, i * step));
const SFX = {
  tap: () => tone(1050, 0.03, 0.035), tick: () => tone(980, 0.03, 0.04), nav: () => tone(620, 0.06, 0.05, 'sine', 0, 700),
  step: () => tone(420, 0.06, 0.06, 'sine', 0, 360), confirm: () => seq([660, 880], 0.06, 0.08, 0.06),
  coin: () => seq([1250, 1660], 0.06, 0.09, 0.05, 'triangle'),
  craft: () => { tone(330, 0.12, 0.09, 'sine', 0, 220); tone(990, 0.05, 0.04, 'sine', 0.1); },
  travel: () => tone(440, 0.18, 0.07, 'sine', 0, 560), depart: () => seq([392, 523], 0.09, 0.14, 0.07),
  arrive: () => seq([523, 659, 784], 0.07, 0.18, 0.06), reward: () => seq([659, 784, 988, 1319], 0.06, 0.12, 0.05, 'triangle'),
  equip: () => seq([1000, 1300], 0.04, 0.05, 0.05), heal: () => tone(520, 0.24, 0.06, 'sine', 0, 780),
  search: () => seq([880, 1040], 0.035, 0.03, 0.035), find: () => seq([880, 1320], 0.07, 0.12, 0.06),
  gather: () => tone(700, 0.08, 0.06, 'sine', 0, 920), encounter: () => { tone(220, 0.16, 0.08); tone(233, 0.16, 0.06, 'sine', 0.02); },
  hit: () => tone(200, 0.09, 0.1, 'sine', 0, 110), crit: () => { tone(200, 0.09, 0.1, 'sine', 0, 110); tone(1400, 0.07, 0.05, 'sine', 0.05); },
  hurt: () => tone(260, 0.14, 0.08, 'sine', 0, 170), guard: () => tone(500, 0.1, 0.06, 'triangle'),
  victory: () => seq([523, 659, 784, 1046], 0.08, 0.18, 0.06, 'triangle'), defeat: () => seq([392, 330, 262], 0.12, 0.22, 0.06),
  chime: () => tone(660, 0.2, 0.05), error: () => seq([240, 200], 0.1, 0.1, 0.06), repair: () => { tone(900, 0.04, 0.05); tone(700, 0.05, 0.05, 'sine', 0.07); },
};
export function playSfx(kind) {
  if (!sound.sfxOn || away || !ensureCtx()) return;
  try { (SFX[kind] || SFX.tap)(); } catch {}
}
export const SFX_SAMPLES = [['confirm', '확인'], ['find', '발견'], ['hit', '전투'], ['coin', '거래'], ['craft', '제작'], ['travel', '출발'], ['reward', '보상'], ['error', '오류']];

/* ── 바깥에서 부르는 것 ───────────────────────────────── */
export function setScene(part) {
  const before = `${scene.territory}:${scene.safe}:${scene.battle}`;
  Object.assign(scene, part);
  if (before === `${scene.territory}:${scene.safe}:${scene.battle}`) return;
  updateDrone(); updateAmbience();
}
export function setEnabled(key, value) {
  sound[key] = value; saveSound();
  if (!ensureCtx()) return;
  ctx.resume?.();
  if (key === 'bgmOn') value ? startMusic() : stopMusic();
  applyVolumes(); updateAmbience();
}
export function setVolume(key, value) { sound[key] = value; saveSound(); ensureCtx(); applyVolumes(); }

// 행동 RPC → 효과음 종류. 탐색·전투는 화면이 결과에 맞는 소리를 직접 낸다.
const SFX_OF = [
  [/field_search|battle_action|field_gather/, null], [/shop_buy|shop_sell|trade_offer|mount_acquire/, 'coin'], [/craft/, 'craft'], [/repair/, 'repair'],
  [/travel/, 'travel'], [/expedition_start/, 'depart'], [/expedition_complete|claim|story_combine|commission|mission_action|faction_supply/, 'reward'],
  [/equip|title_|allocate/, 'equip'], [/rest|survival|use_item|rescue/, 'heal'], [/field_move/, 'step'],
];
export function initSound() {
  loadSound();
  on('changed', ({ name }) => { const m = SFX_OF.find(([re]) => re.test(name)); const k = m ? m[1] : 'confirm'; if (k) playSfx(k); });
  on('env', e => { if (!e) return; env = { weather: e.weather?.key || 'clear', phase: e.phase?.key || 'noon' }; if (e.territory_id) scene.territory = e.territory_id; updateDrone(); updateAmbience(); });
  window.addEventListener('yh-sfx', e => playSfx(e.detail));
  document.addEventListener('click', e => {
    const b = e.target.closest('.btn, .segmented button, .tabbar a, .topnav a, .icon-btn, .facility, .path, .act'); if (!b || b.disabled) return;
    if (b.closest('.battle') || b.id === 'search') return;
    playSfx(b.closest('.tabbar, .topnav') ? 'nav' : 'tap');
  }, { capture: true });
  // 브라우저는 사용자가 한 번 누른 뒤에야 소리를 허락한다.
  const unlock = () => { if (!ensureCtx()) return; ctx.resume?.(); applyVolumes(); if (sound.bgmOn) startMusic(); updateAmbience(); critters(); };
  document.addEventListener('pointerdown', unlock, { once: true });
  document.addEventListener('keydown', unlock, { once: true });
  if (MOBILE) {
    const leave = () => {
      if (away) return; away = true;
      clearTimeout(phraseTimer); clearTimeout(critterTimer);
      if (ctx) { master.gain.setValueAtTime(0, ctx.currentTime); ctx.suspend?.().catch(() => {}); }
    };
    const back = () => {
      if (!away || document.hidden) return; away = false;
      if (!ctx) return;
      const wake = () => { master.gain.setTargetAtTime(0.9, ctx.currentTime, 0.2); if (playing) { clearTimeout(phraseTimer); phraseTimer = setTimeout(phrase, 400); } critters(); };
      Promise.resolve(ctx.resume?.()).then(wake, wake);
    };
    document.addEventListener('visibilitychange', () => (document.hidden ? leave() : back()));
    window.addEventListener('pagehide', leave);
    window.addEventListener('pageshow', back);
    // iOS는 돌아온 뒤 한 번 눌러야 다시 소리를 허락하기도 한다
    document.addEventListener('pointerdown', () => { if (ctx && !away && ctx.state !== 'running') ctx.resume?.(); });
  }
}
