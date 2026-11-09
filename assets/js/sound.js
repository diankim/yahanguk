import { on, toast } from './core.js';
import { SFX_ACTS } from './changes.js';
import { LAYERS as AMB, bird, cricket, owl, drip } from './ambience.js';

export const sound = { vol: 1, bgm: 0.4, sfx: 0.55, amb: 0.35, bgmOn: true, sfxOn: true, ambOn: true };
let ctx, master, bgmBus, ambBus, sfxBus, reverb, noiseBuf, brownBuf;
const scene = { territory: 'capital', safe: false, battle: false, exp: false };
const inBattle = () => scene.exp;
const MOBILE = (() => { try { return matchMedia('(pointer: coarse)').matches || /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent); } catch { return false; } })();
let away = false;
const POPWIN = (() => { try { return !!new URLSearchParams(location.search).get('pop'); } catch { return false; } })();
let yielded = POPWIN;
const musicOk = () => sound.bgmOn && !yielded;
let env = { weather: 'clear', phase: 'noon' };

export function loadSound() { try { Object.assign(sound, JSON.parse(localStorage.getItem('yh-sound') || '{}')); } catch {} }
export function saveSound() { try { localStorage.setItem('yh-sound', JSON.stringify(sound)); } catch {} if (!POPWIN) window.dispatchEvent(new Event('yh-prefs-changed')); }
const masterLevel = () => 0.9 * Math.max(0, Math.min(1, sound.vol ?? 1));
export function applyVolumes() {
  if (!ctx) return;
  const t = ctx.currentTime;
  if (!away) master.gain.setTargetAtTime(masterLevel(), t, 0.1);
  bgmBus.gain.setTargetAtTime(musicOk() ? sound.bgm * 0.8 : 0, t, 0.3);
  ambBus.gain.setTargetAtTime(sound.ambOn && !yielded && !held ? sound.amb * 0.5 : 0, t, 0.4);
  sfxBus.gain.setTargetAtTime(sound.sfxOn ? sound.sfx * 0.95 : 0, t, 0.05);
}

function ensureCtx() {
  if (ctx) return ctx;
  const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return null;
  try { ctx = new AC({ sampleRate: 32000 }); } catch { ctx = new AC(); }
  master = ctx.createGain(); master.gain.value = masterLevel(); master.connect(ctx.destination);
  bgmBus = ctx.createGain(); ambBus = ctx.createGain(); sfxBus = ctx.createGain();
  [bgmBus, ambBus, sfxBus].forEach(g => { g.gain.value = 0; g.connect(master); });
  reverb = ctx.createConvolver();
  const len = ctx.sampleRate * 3.4, ir = ctx.createBuffer(2, len, ctx.sampleRate);
  for (let ch = 0; ch < 2; ch++) {
    const d = ir.getChannelData(ch); let lp = 0;
    for (let i = 0; i < len; i++) { const x = i / len; lp += ((Math.random() * 2 - 1) - lp) * (0.3 - 0.26 * x); d[i] = lp * Math.pow(1 - x, 2.2) * 2.4; }
  }
  reverb.buffer = ir;
  const rlp = ctx.createBiquadFilter(); rlp.type = 'lowpass'; rlp.frequency.value = 3200;
  const wet = ctx.createGain(); wet.gain.value = 0.3; reverb.connect(rlp); rlp.connect(wet); wet.connect(bgmBus);
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

const SLOT = 3.2;
const INS = {
  piano:      { notes: [33, 37, 41, 45, 49, 53, 57, 61, 65, 69, 73, 77, 81, 85], len: 3.1, sus: false, gain: 0.45, att: 0.004, rel: 0.7, pan: 0.08, send: 0.5 },
  koto:       { notes: [45, 48, 51, 54, 57, 60, 63, 66, 69, 72, 75, 78, 81, 84], len: 2.8, sus: false, gain: 0.5, att: 0.004, rel: 0.5, pan: -0.28, send: 0.45 },
  harp:       { notes: [43, 47, 51, 55, 59, 63, 67, 71, 75, 79, 83, 87], len: 2.6, sus: false, gain: 0.42, att: 0.004, rel: 0.6, pan: 0.3, send: 0.5 },
  shakuhachi: { notes: [57, 60, 63, 66, 69, 72, 75, 78, 81, 84, 87, 90], len: 3.1, sus: true, gain: 0.5, att: 0.07, rel: 0.45, pan: 0.05, send: 0.55 },
  flute:      { notes: [60, 63, 66, 69, 72, 75, 78, 81, 84, 87, 90, 93], len: 3.1, sus: true, gain: 0.42, att: 0.06, rel: 0.4, pan: 0.05, send: 0.55 },
  fiddle:     { notes: [55, 58, 61, 64, 67, 70, 73, 76, 79, 82, 85, 88], len: 3.1, sus: true, gain: 0.4, att: 0.1, rel: 0.45, pan: 0, send: 0.5 },
  strings:    { notes: [36, 40, 44, 48, 52, 56, 60, 64, 68, 72], len: 3.1, sus: true, gain: 0.3, att: 0.5, rel: 0.9, pan: 0.15, send: 0.6 },
  cello:      { notes: [33, 37, 41, 45, 49, 53, 57], len: 3.1, sus: true, gain: 0.6, att: 0.12, rel: 0.7, pan: -0.12, send: 0.4 },
  bell:       { notes: [60, 66, 72, 78, 84], len: 3.1, sus: false, gain: 0.16, att: 0.003, rel: 1.2, pan: 0.2, send: 0.7 },
  taiko:      { notes: [36], len: 2.0, sus: false, gain: 0.45, att: 0.003, rel: 0.4, pan: 0, send: 0.3 },
};
const buffers = {}, loadingIns = {};
function loadIns(k) {
  if (buffers[k]) return Promise.resolve(buffers[k]);
  if (loadingIns[k]) return loadingIns[k];
  loadingIns[k] = fetch(`assets/audio/${k}.mp3`).then(r => { if (!r.ok) throw new Error(r.status); return r.arrayBuffer(); })
    .then(b => new Promise((res, rej) => ctx.decodeAudioData(b, res, rej)))
    .then(buf => { buffers[k] = buf; return buf; })
    .catch(() => { loadingIns[k] = null; return null; });
  return loadingIns[k];
}
function keepOnly(keys) { Object.keys(buffers).forEach(k => { if (!keys.includes(k)) { delete buffers[k]; loadingIns[k] = null; } }); }

let soft = 0;
function playNote(k, midi, t, dur, vel, o = {}) {
  const I = INS[k], buf = buffers[k]; if (!I || !buf || vel <= 0) return;
  if (k === 'piano' && soft) { vel *= soft; o = { ...o, lp: o.lp || 1800, att: Math.max(o.att ?? I.att, 0.02) }; }
  let idx = 0, best = 99; I.notes.forEach((n, i) => { const d = Math.abs(midi - n); if (d < best) { best = d; idx = i; } });
  const rate = Math.pow(2, (midi - I.notes[idx]) / 12), off = idx * SLOT;
  const g = ctx.createGain(), pan = ctx.createStereoPanner ? ctx.createStereoPanner() : null;
  let head = g;
  if (o.lp) { const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = o.lp; f.Q.value = 0.4; g.connect(f); head = f; }
  if (pan) { pan.pan.value = I.pan + (Math.random() - 0.5) * 0.1; head.connect(pan); toBgm(pan, I.send); } else toBgm(head, I.send);
  const peak = Math.max(0.0002, vel * I.gain);
  const ring = I.sus ? dur : Math.max(dur, Math.min(I.len, dur + 1.6));
  const end = t + ring + I.rel;
  const att = o.att ?? I.att;
  g.gain.setValueAtTime(0.0001, t);
  if (I.sus && (o.expr || o.swell) && ring > 0.5) {
    const a2 = o.swell ? Math.min(ring * 0.45, Math.max(att, 0.4)) : Math.min(att, ring * 0.3);
    g.gain.exponentialRampToValueAtTime(peak * (o.swell ? 0.55 : 0.72), t + a2);
    g.gain.linearRampToValueAtTime(peak, t + ring * (o.swell ? 0.55 : 0.4));
    g.gain.linearRampToValueAtTime(peak * (o.swell ? 0.6 : 0.55), t + ring - 0.02);
  } else {
    g.gain.exponentialRampToValueAtTime(peak, t + att);
    g.gain.setValueAtTime(peak, Math.max(t + att, t + ring - 0.02));
  }
  g.gain.exponentialRampToValueAtTime(0.0001, end);
  const srcs = [];
  const seg = (start, offset, length, fadeIn, fadeOut, first) => {
    const s = ctx.createBufferSource(), sg = ctx.createGain();
    s.buffer = buf; s.playbackRate.setValueAtTime(rate, start);
    if (first && o.slide) { s.playbackRate.setValueAtTime(rate * Math.pow(2, -o.slide / 12), start); s.playbackRate.linearRampToValueAtTime(rate, start + 0.14); }
    sg.gain.setValueAtTime(fadeIn ? 0.0001 : 1, start); if (fadeIn) sg.gain.linearRampToValueAtTime(1, start + fadeIn);
    if (fadeOut) { sg.gain.setValueAtTime(1, start + length - fadeOut); sg.gain.linearRampToValueAtTime(0.0001, start + length); }
    s.connect(sg); sg.connect(g); s.start(start, offset, length * rate + 0.02); s.stop(start + length + 0.05); srcs.push(s);
  };
  const need = end - t, first = Math.min(need, (I.len - 0.15) / rate);
  if (!I.sus || need <= first) seg(t, off, Math.min(need, I.len / rate), 0, 0, true);
  else {
    const L = 2.0 / rate, X = 0.35;
    seg(t, off, first, 0, X, true);
    for (let at = t + first - X; at < end; at += L - X) seg(at, off + 0.9, Math.min(L, end - at + 0.05), X, X, false);
  }
  if (o.vib && I.sus && ring > 0.8 && srcs[0]?.detune) {
    const lfo = ctx.createOscillator(), dep = ctx.createGain();
    lfo.frequency.value = 4.8 + Math.random() * 0.8; dep.gain.setValueAtTime(0, t); dep.gain.setValueAtTime(0, t + 0.35); dep.gain.linearRampToValueAtTime(12, t + Math.min(ring, 1.1));
    lfo.connect(dep); srcs.forEach(x => dep.connect(x.detune)); lfo.start(t); lfo.stop(end + 0.05);
  }
  if (o.grace) playNote(k, midi + o.grace, t - 0.09, 0.08, vel * 0.7);
}

const DRUM_KIND = { big: { f0: 92, f1: 40, dec: 1.1, g: 1.0, hit: 0.5, smp: 0.5 }, mid: { f0: 135, f1: 68, dec: 0.55, g: 0.7, hit: 0.45, smp: 0.55 }, small: { f0: 230, f1: 140, dec: 0.22, g: 0.35, hit: 0.6, smp: 0.6 } };
function playDrum(t, vel, kind = 'big') {
  const K = DRUM_KIND[kind] || DRUM_KIND.big; if (vel <= 0) return;
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.type = 'sine'; o.frequency.setValueAtTime(K.f0, t); o.frequency.exponentialRampToValueAtTime(K.f1, t + Math.min(0.25, K.dec * 0.5));
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(Math.max(0.0002, 0.34 * K.g * vel), t + 0.006); g.gain.exponentialRampToValueAtTime(0.0001, t + K.dec);
  o.connect(g); toBgm(g, 0.22); o.start(t); o.stop(t + K.dec + 0.05);
  if (noiseBuf) {
    const n = ctx.createBufferSource(), lp = ctx.createBiquadFilter(), ng = ctx.createGain();
    n.buffer = noiseBuf; lp.type = 'lowpass'; lp.frequency.value = kind === 'small' ? 2200 : 900;
    ng.gain.setValueAtTime(0.0001, t); ng.gain.exponentialRampToValueAtTime(Math.max(0.0002, 0.12 * K.hit * vel), t + 0.003); ng.gain.exponentialRampToValueAtTime(0.0001, t + 0.07);
    n.connect(lp); lp.connect(ng); toBgm(ng, 0.15); n.start(t, Math.random()); n.stop(t + 0.1);
  }
  if (buffers.taiko) playNote('taiko', kind === 'small' ? 43 : kind === 'mid' ? 38 : 34, t, 0.5, vel * K.smp);
}

const MODES = { minor: [0, 2, 3, 5, 7, 8, 10], major: [0, 2, 4, 5, 7, 9, 11], phryg: [0, 1, 3, 5, 7, 8, 10] };
const PROG = {
  minor: { ante: [[0, 5, 3, 4], [0, 3, 5, 6], [0, 6, 5, 4], [5, 6, 0, 4], [0, 2, 3, 6]], cons: [[5, 6, 0, 0], [3, 4, 0, 0], [0, 5, 6, 0], [5, 3, 4, 0], [2, 5, 6, 0]],
           bA: [[5, 6, 2, 5], [3, 4, 5, 6], [5, 3, 6, 2]], bC: [[3, 6, 2, 4], [5, 3, 4, 4], [3, 5, 6, 6]] },
  major: { ante: [[0, 3, 4, 4], [0, 5, 3, 4], [0, 2, 3, 4], [5, 3, 1, 4]], cons: [[0, 3, 4, 0], [5, 3, 4, 0], [3, 4, 0, 0], [1, 4, 0, 0]],
           bA: [[5, 2, 3, 0], [3, 4, 2, 5], [5, 3, 0, 4]], bC: [[1, 4, 2, 5], [3, 1, 4, 4], [5, 1, 4, 4]] },
  tango: { ante: [[0, 6, 5, 4], [0, 3, 6, 2], [0, 5, 1, 4], [3, 6, 2, 5]], cons: [[5, 1, 4, 0], [3, 4, 0, 0], [5, 6, 4, 0], [3, 1, 4, 0]],
           bA: [[5, 2, 3, 4], [3, 6, 2, 5], [5, 6, 4, 4]], bC: [[3, 4, 5, 4], [1, 4, 0, 0], [5, 3, 4, 4]] },
};
const RHY = {
  calm: { move: [[2, 1, 1], [1.5, 0.5, 2], [1, 1, 2], [1, 0.5, 0.5, 2], [0.5, 0.5, 1, 2], [2.5, 0.5, 1], [1, 1, 1, 1], ['r1', 1, 1, 1], ['r0.5', 0.5, 1, 2]],
          mid: [[3, 1], [2, 2], [2, 1, 1], [1.5, 0.5, 2], [2.5, 0.5, 1]], end: [[4], [3, 1], [2, 2], [1, 3]] },
  fast: { move: [[0.5, 0.5, 1, 0.5, 0.5, 1], [1, 0.5, 0.5, 1, 1], [0.5, 0.5, 0.5, 0.5, 1, 1], [1.5, 0.5, 1, 1], [0.5, 1, 0.5, 2]],
          mid: [[1, 1, 2], [2, 1, 1], [0.5, 0.5, 1, 2], [1, 0.5, 0.5, 2]], end: [[2, 2], [3, 1], [4], [1, 1, 2]] },
  lament: { move: [[3, 1], [2, 'r1', 1], ['r1', 2, 1], [2, 2], [1.5, 0.5, 2]], mid: [[4], [3, 1], [2, 2]], end: [[4], [4]] },
  battle: { move: [[1, 0.5, 0.5, 1, 1], [0.5, 0.5, 1, 2], [1, 1, 1, 1], [1.5, 0.5, 1, 1], [0.5, 0.5, 0.5, 0.5, 2], [1, 1, 2]],
            mid: [[1, 0.5, 0.5, 1, 1], [1, 1, 2], [2, 1, 1]], end: [[1, 1, 2], [2, 2], [4]] },
  dance3: { move: [[1, 1, 1], [2, 1], [1.5, 0.5, 1], [1, 0.5, 0.5, 1], [0.5, 0.5, 1, 1]], mid: [[2, 1], [1, 2], [1.5, 0.5, 1]], end: [[3], [2, 1]] },
  slow3: { move: [[2, 1], [1.5, 0.5, 1], ['r1', 1, 1], [3]], mid: [[3], [2, 1]], end: [[3], [3]] },
  oblivion: { move: [[3, 1], [1.5, 0.5, 2], [2, 1, 1], ['r0.5', 0.5, 1, 2], [2.5, 0.5, 1]], mid: [[4], [3, 1], [2, 2]], end: [[4], [3, 1]] },
  oblivion2: { move: [[1.5, 0.5, 1, 1], [1, 0.5, 0.5, 2], [2, 1, 1], [1.5, 0.5, 2], [0.5, 0.5, 1, 2]], mid: [[2, 2], [3, 1], [1.5, 0.5, 2]], end: [[4], [2, 2]] },
};
const ACC = {
  calm: [[0, 0, 1], [1, 4, .8], [2, 7, .85], [3, 4, .75]],
  flowing: [[0, 0, 1], [0.5, 4, .7], [1, 7, .8], [1.5, 9, .7], [2, 7, .8], [2.5, 4, .7], [3, 2, .75], [3.5, 4, .7]],
  sparse: [[0, 0, 1], [2, 4, .8], [2.5, 7, .7]],
  fast: Array.from({ length: 16 }, (_, k) => [k / 4, [0, 4, 2, 4][k % 4] + (k % 8 >= 4 ? 7 : 0), k % 4 ? .5 : .9]),
  shimmer: [[0, 0, .9], [0.5, 2, .6], [1, 4, .7], [1.5, 7, .6], [2, 9, .75], [2.5, 11, .6], [3, 14, .7], [3.5, 11, .55]],
  eerie: [[0, 0, .9], [1.5, 4, .55], [2.5, 9, .5], [3.25, 7, .45]],
  ostinato: Array.from({ length: 8 }, (_, k) => [k / 2, k % 2 ? 4 : 0, k % 2 ? .6 : .95]),
  waltz: [[1, 2, .7], [1, 4, .7], [2, 2, .6], [2, 4, .6]],
  dance3: [[0, 0, 1], [0.5, 4, .65], [1, 7, .8], [1.5, 9, .6], [2, 7, .75], [2.5, 4, .6]],
  slow3: [[0, 0, 1], [1, 4, .7], [2, 7, .75]],
  battle: [[0, 0, 1], [0.5, 0, .7], [1, 2, .8], [1.5, 0, .7], [2, 4, .85], [2.5, 0, .7], [3, 2, .8], [3.5, 4, .75]],
  tango: [[0, 2, .6], [0, 4, .55], [1.5, 2, .5], [1.5, 4, .45], [3, 2, .55], [3, 4, .5]],
  inkrain: [[0, 0, .75], [1.25, 7, .4], [2, 4, .5], [2.75, 9, .35], [3.5, 11, .3]],
  inkrain16: Array.from({ length: 16 }, (_, k) => [k / 4, [0, 4, 7, 9, 7, 4, 2, 4][k % 8] + (k >= 8 ? 2 : 0), k % 4 ? .32 + (k % 2 ? 0 : .08) : .6]),
  inkrain8: [[0, 0, .8], [0.5, 7, .4], [1.25, 4, .5], [1.75, 9, .35], [2.5, 7, .45], [3, 11, .35], [3.5, 9, .3]],
  tango8: [[0, 2, .7], [0, 4, .6], [0.5, 7, .35], [1, 4, .4], [1.5, 2, .65], [1.5, 4, .55], [2, 7, .35], [2.5, 4, .4], [3, 2, .7], [3, 4, .6], [3.5, 7, .4]],
};
const roll = (from, to, step, v0, v1, k = 'small') => { const o = []; for (let x = from, i = 0, n = Math.round((to - from) / step); x < to - 1e-6; x += step, i++) o.push([x, v0 + (v1 - v0) * i / Math.max(1, n - 1), k]); return o; };
const DRUM = {
  pulse: { main: [[0, 0.65, 'big']], alt: [[0, 0.5, 'big'], [2, 0.3, 'mid']], fill: [[0, 0.6, 'big'], [2, 0.4, 'mid'], [3, 0.45, 'mid']] },
  tap3: { main: [[0, 0.5, 'mid']], alt: [[0, 0.45, 'mid'], [2, 0.3, 'small']], fill: [[0, 0.5, 'mid'], [1.5, 0.3, 'small'], [2, 0.4, 'small'], [2.5, 0.45, 'small']] },
  groove: { main: [[0, 0.9, 'big'], [0.75, 0.35, 'small'], [1.5, 0.6, 'mid'], [2, 0.8, 'big'], [2.75, 0.35, 'small'], [3.5, 0.55, 'mid']],
            alt: [[0, 0.9, 'big'], [1, 0.4, 'small'], [1.5, 0.6, 'mid'], [2.5, 0.7, 'mid'], [3, 0.45, 'small'], [3.5, 0.6, 'mid']],
            fill: [[0, 0.9, 'big'], [1, 0.5, 'mid'], [1.5, 0.6, 'mid'], [2, 0.8, 'big'], ...roll(2.5, 4, 0.25, 0.35, 0.8, 'mid')] },
  march: { main: [[0, 1, 'big'], [1, 0.4, 'mid'], [2, 0.85, 'big'], [3, 0.4, 'mid'], [3.5, 0.5, 'mid']],
           alt: [[0, 1, 'big'], [0.5, 0.35, 'small'], [1, 0.45, 'mid'], [2, 0.85, 'big'], [3, 0.55, 'mid']],
           fill: [[0, 1, 'big'], [1, 0.6, 'mid'], [2, 0.7, 'mid'], [2.5, 0.7, 'mid'], [3, 0.85, 'big'], [3.5, 0.95, 'big']] },
  heavy: { main: [[0, 1, 'big'], [0.5, 0.45, 'mid'], [2, 1, 'big'], [3, 0.55, 'mid'], [3.5, 0.7, 'mid']],
           alt: [[0, 1, 'big'], [1.5, 0.55, 'mid'], [2, 0.9, 'big'], [2.75, 0.45, 'small'], [3.5, 0.8, 'big']],
           fill: [[0, 1, 'big'], [1, 0.7, 'big'], ...roll(2, 4, 0.25, 0.45, 1, 'mid')] },
  heart: { main: [[0, 0.8, 'big'], [0.4, 0.55, 'big']], alt: [], fill: [[0, 0.8, 'big'], [0.4, 0.55, 'big'], [2, 0.55, 'big'], [2.4, 0.4, 'big']] },
  b_capital: { main: [[0, 1, 'big'], [1.5, 0.55, 'mid'], [2, 0.9, 'big'], [3, 0.45, 'mid'], [3.5, 0.6, 'mid']],
               alt: [[0, 1, 'big'], [1, 0.45, 'mid'], [2, 0.9, 'big'], [2.5, 0.45, 'small'], [3.5, 0.7, 'mid']],
               fill: [[0, 1, 'big'], [1, 0.7, 'mid'], [2, 0.8, 'big'], [2.5, 0.8, 'mid'], [3, 0.9, 'big'], [3.5, 1, 'big']] },
  b_east: { main: [[0, 0.9, 'big'], [1.5, 0.6, 'mid'], [3, 0.7, 'mid']], alt: [[0, 0.9, 'big'], [1.5, 0.6, 'mid'], [2.5, 0.35, 'small'], [3, 0.7, 'mid'], [3.5, 0.4, 'small']],
            fill: [[0, 0.9, 'big'], [1.5, 0.6, 'mid'], [3, 0.7, 'mid'], ...roll(3.25, 4, 0.25, 0.45, 0.75)] },
  b_north: { main: [[0, 1, 'big']], alt: [[0, 0.9, 'big'], [2, 0.55, 'big']], fill: [[0, 1, 'big'], [2, 0.7, 'big'], [3, 0.5, 'mid'], [3.5, 0.65, 'mid']] },
  b_south: { main: [[0, 1, 'big'], [0.75, 0.4, 'small'], [1.5, 0.7, 'mid'], [2, 0.9, 'big'], [2.5, 0.45, 'small'], [2.75, 0.45, 'small'], [3.5, 0.7, 'mid']],
             alt: [[0, 1, 'big'], [0.5, 0.4, 'small'], [1, 0.6, 'mid'], [1.75, 0.5, 'mid'], [2.5, 0.85, 'big'], [3.25, 0.45, 'small'], [3.5, 0.6, 'mid']],
             fill: [[0, 1, 'big'], [1, 0.7, 'mid'], ...roll(1.5, 4, 0.25, 0.4, 1, 'mid')] },
  b_frontier: { main: [[0, 1, 'big'], [0.5, 0.4, 'small'], [1, 0.6, 'mid'], [2, 0.95, 'big'], [2.5, 0.4, 'small'], [3, 0.6, 'mid'], [3.5, 0.5, 'small']],
                alt: [[0, 1, 'big'], [1, 0.6, 'mid'], [1.5, 0.5, 'mid'], [2, 0.95, 'big'], [3, 0.7, 'big'], [3.5, 0.6, 'mid']],
                fill: [[0, 1, 'big'], [0.5, 0.6, 'mid'], [1, 0.7, 'mid'], [1.5, 0.7, 'mid'], [2, 0.9, 'big'], [2.5, 0.9, 'big'], [3, 1, 'big'], [3.5, 1, 'big']] },
  b_underworld: { main: [[0, 0.9, 'big'], [0.35, 0.6, 'big'], [2.5, 0.55, 'mid']], alt: [[0, 0.9, 'big'], [1.5, 0.5, 'mid'], [1.85, 0.5, 'mid']],
                  fill: [[0, 0.9, 'big'], [1, 0.6, 'mid'], [2, 0.7, 'big'], [3, 0.8, 'big'], [3.5, 0.65, 'mid']] },
  b_heaven: { main: [[0, 1, 'big'], [2.5, 0.55, 'mid']], alt: [[0, 0.9, 'big'], [1.5, 0.45, 'mid'], [3, 0.55, 'mid']], fill: [[0, 1, 'big'], [2, 0.8, 'big'], [3, 0.85, 'big'], [3.5, 0.95, 'big']] },
  b_abyss: { main: [[0, 1, 'big'], [0.5, 0.45, 'mid'], [1, 0.7, 'big'], [1.5, 0.45, 'mid'], [2, 1, 'big'], [2.5, 0.45, 'mid'], [3, 0.7, 'big'], [3.5, 0.55, 'mid']],
             alt: [[0, 1, 'big'], [0.75, 0.5, 'mid'], [1.5, 0.8, 'big'], [2, 0.9, 'big'], [3, 0.55, 'mid'], [3.25, 0.55, 'mid'], [3.5, 0.8, 'big']],
             fill: [[0, 1, 'big'], ...roll(1, 4, 0.25, 0.4, 1, 'mid')] },
  b_mukjeok: { main: [[0, 0.9, 'big'], [2.5, 0.5, 'mid']], alt: [[0, 0.9, 'big'], [1.5, 0.4, 'small'], [3, 0.6, 'mid']], fill: [[0, 0.9, 'big'], [1.5, 0.5, 'mid'], [2.5, 0.65, 'mid'], [3, 0.8, 'big'], [3.5, 0.85, 'big']] },
  b_mukjeok2: { main: [[0, 0.9, 'big'], [1, 0.4, 'small'], [1.5, 0.5, 'mid'], [2.5, 0.6, 'mid'], [3, 0.45, 'small'], [3.5, 0.55, 'mid']],
    alt: [[0, 0.9, 'big'], [0.75, 0.35, 'small'], [1.5, 0.55, 'mid'], [2, 0.75, 'big'], [3, 0.5, 'mid'], [3.5, 0.6, 'mid']],
    fill: [[0, 0.9, 'big'], [1, 0.55, 'mid'], [1.5, 0.6, 'mid'], [2, 0.8, 'big'], ...roll(2.5, 4, 0.25, 0.4, 0.85, 'mid')] },
  b_gwiheo: { main: [[0, 1, 'big'], [1.5, 0.5, 'mid'], [3, 0.7, 'big']], alt: [[0, 1, 'big'], [2, 0.6, 'big']], fill: [[0, 1, 'big'], [1, 0.6, 'mid'], [2, 0.8, 'big'], [2.5, 0.6, 'mid'], [3, 0.9, 'big'], [3.5, 0.9, 'big']] },
};
const F = (s, ins, v, o = {}) => ({ s, ins, v, ...o });
const PROFILES = {
  capital: { tonic: 62, mode: 'minor', bpm: 72, meter: 4, rhy: 'calm', lead: 'shakuhachi', lead2: 'koto', counter: 'koto', arp: 'harp', acc: 'calm', bass: 'half', drum: 'pulse', drumIn: ['B', 'A3'], pad: 'light', bell: 0.25,
    bt: { bpm: 104, lead: 'shakuhachi', lead2: 'flute', acc: 'battle', arp: 'koto', bass: 'battle', drum: 'b_capital', form: [F('A', 'lead', 0.85), F('B', 'lead2', 0.95, { duet: 'shakuhachi', trem: true })] },
    form: [F('intro', 0, 0.35, { n: 2 }), F('A', 'lead', 0.5), F('A2', 'lead', 0.66, { echo: 'koto' }), F('B', 'lead2', 0.85, { duet: 'shakuhachi' }), F('A3', 'lead', 0.58), F('bridge', 0, 0.3, { n: 2 })] },
  east: { tonic: 64, mode: 'major', bpm: 108, meter: 3, rhy: 'dance3', lead: 'flute', lead2: 'koto', counter: 'harp', arp: 'koto', acc: 'waltz', bass: 'waltz', drum: 'tap3', drumIn: ['A2', 'B', 'C'], pad: 'light', bell: 0.15,
    bt: { bpm: 120, lead: 'flute', lead2: 'koto', acc: 'flowing', arp: 'harp', bass: 'drive', drum: 'b_east', form: [F('A', 'lead', 0.85, { echo: 'koto' }), F('B', 'lead2', 0.9, { duet: 'flute' })] },
    form: [F('intro', 0, 0.4, { n: 2 }), F('A', 'lead', 0.6), F('B', 'lead2', 0.7, { echo: 'harp' }), F('A2', 'lead', 0.75, { duet: 'shakuhachi' }), F('C', 'shakuhachi', 0.6), F('A', 'lead', 0.7)] },
  north: { tonic: 57, mode: 'minor', bpm: 54, meter: 4, rhy: 'lament', lead: 'piano', lead2: 'cello', counter: 'shakuhachi', arp: 'piano', acc: 'sparse', bass: 'long', drum: null, pad: 'light', bell: 0.12,
    bt: { bpm: 72, mode: 'minor', lead: 'piano', lead2: 'cello', counter: 'shakuhachi', arp: 'piano', acc: 'sparse', bass: 'long', drum: 'b_north', pad: 'swell', bell: 0.7, rhy: 'lament', form: [F('A', 'lead', 0.9, { oct: -7 }), F('B', 'lead2', 0.95, { oct: -14, duet: 'shakuhachi' })] },
    form: [F('intro', 0, 0.3, { n: 3 }), F('A', 'lead', 0.55), F('A2', 'lead2', 0.6, { oct: -14 }), F('B', 'lead', 0.78, { duet: 'shakuhachi' }), F('A3', 'lead', 0.5), F('bridge', 0, 0.25, { n: 2 })] },
  south: { tonic: 60, mode: 'major', bpm: 124, meter: 4, rhy: 'fast', lead: 'shakuhachi', lead2: 'koto', counter: 'koto', arp: 'koto', acc: 'fast', bass: 'drive', drum: 'groove', pad: 'light', bell: 0.08,
    bt: { bpm: 136, lead: 'shakuhachi', lead2: 'flute', acc: 'fast', arp: 'koto', bass: 'drive', drum: 'b_south', form: [F('A', 'lead', 0.85), F('B', 'lead2', 0.95, { duet: 'shakuhachi' })] },
    form: [F('drop', 0, 0.55, { n: 2 }), F('A', 'lead', 0.7, { duet: 'flute' }), F('A2', 'lead', 0.78, { echo: 'koto' }), F('B', 'lead2', 0.85, { duet: 'flute' }), F('drop', 0, 0.6, { n: 2 }), F('A', 'flute', 0.8, { duet: 'shakuhachi' })] },
  frontier: { tonic: 64, mode: 'minor', bpm: 88, meter: 4, rhy: 'calm', lead: 'fiddle', lead2: 'flute', counter: 'shakuhachi', arp: 'harp', acc: 'ostinato', accIns: 'strings', bass: 'march', drum: 'march', pad: 'swell', bell: 0.05,
    bt: { bpm: 112, lead: 'fiddle', lead2: 'strings', acc: 'ostinato', accIns: 'strings', bass: 'march', drum: 'b_frontier', pad: 'swell', form: [F('A', 'lead', 0.85), F('B', 'lead2', 0.95, { oct: -7, trem: true })] },
    form: [F('drop', 0, 0.5, { n: 2 }), F('A', 'lead', 0.65), F('A2', 'lead', 0.78, { duet: 'shakuhachi' }), F('B', 'lead2', 0.92, { duet: 'fiddle', trem: true }), F('A3', 'lead', 0.7), F('bridge', 0, 0.4, { n: 1 })] },
  underworld: { tonic: 61, mode: 'phryg', bpm: 48, meter: 4, rhy: 'lament', lead: 'shakuhachi', lead2: 'piano', counter: 'harp', arp: 'piano', acc: 'eerie', bass: 'pedal', drum: 'heart', pad: 'open', bell: 0.4,
    bt: { bpm: 96, lead: 'shakuhachi', lead2: 'piano', acc: 'eerie', arp: 'piano', bass: 'drive', drum: 'b_underworld', pad: 'open', form: [F('A', 'lead', 0.85), F('B', 'lead2', 0.95, { oct: -7 })] },
    form: [F('intro', 0, 0.3, { n: 2 }), F('A', 'lead', 0.5), F('drop', 0, 0.35, { n: 2 }), F('A2', 'lead', 0.55, { echo: 'harp' }), F('B', 'lead2', 0.65, { oct: -7 }), F('A3', 'lead', 0.45)] },
  heavenward: { tonic: 65, mode: 'major', bpm: 66, meter: 4, rhy: 'calm', lead: 'piano', lead2: 'flute', counter: 'harp', arp: 'harp', acc: 'shimmer', bass: 'long', drum: null, pad: 'light', bell: 0.55,
    bt: { bpm: 104, lead: 'piano', lead2: 'flute', acc: 'shimmer', arp: 'harp', bass: 'half', drum: 'b_heaven', bell: 0.6, form: [F('A', 'lead', 0.85), F('B', 'lead2', 0.95, { echo: 'bell' })] },
    form: [F('intro', 0, 0.35, { n: 2 }), F('A', 'lead', 0.5), F('A2', 'lead', 0.62, { echo: 'bell' }), F('B', 'lead2', 0.7, { duet: 'shakuhachi' }), F('A3', 'lead', 0.5)] },
  abyss: { tonic: 59, mode: 'minor', prog: 'tango', bpm: 56, meter: 4, rhy: 'oblivion', lead: 'piano', lead2: 'piano', counter: 'piano', arp: 'piano', acc: 'tango', bass: 'tango', bassIns: 'piano', drum: null, pad: 'none', bell: 0, soft: 0.8,
    bt: { bpm: 72, soft: 0.85, rhy: 'oblivion2', lead: 'piano', lead2: 'piano', counter: 'piano', arp: 'piano', acc: 'tango8', bass: 'tango', bassIns: 'piano', pad: 'none', bell: 0,
      form: [F('A', 'lead', 0.8), F('B', 'lead2', 0.92, { duet: 'piano' }), F('A2', 'lead', 0.85, { oct: -7 })] },
    form: [F('intro', 0, 0.4, { n: 2 }), F('A', 'lead', 0.55), F('A2', 'lead', 0.62, { echo: 'piano' }), F('B', 'lead2', 0.78, { duet: 'piano' }), F('A3', 'lead', 0.5, { oct: -7 }), F('bridge', 0, 0.35, { n: 1 })] },
  gwiheo: { tonic: 50, mode: 'minor', prog: 'tango', bpm: 54, meter: 4, rhy: 'oblivion', lead: 'cello', lead2: 'strings', counter: 'cello', arp: 'harp', accIns: 'harp', acc: 'tango', bass: 'tango', drum: null, pad: 'sustain', bell: 0,
    bt: { bpm: 70, rhy: 'oblivion2', lead: 'cello', lead2: 'strings', counter: 'cello', arp: 'harp', accIns: 'harp', acc: 'tango8', bass: 'tango', pad: 'sustain', bell: 0,
      form: [F('A', 'lead', 0.85, { oct: -7 }), F('B', 'lead2', 0.95, { duet: 'cello' }), F('A2', 'lead', 0.88, { oct: -7, echo: 'strings' })] },
    form: [F('intro', 0, 0.35, { n: 2 }), F('A', 'lead', 0.6, { oct: -7 }), F('A2', 'lead', 0.66, { oct: -7, echo: 'strings' }), F('B', 'lead2', 0.8, { duet: 'cello' }), F('A3', 'lead', 0.55, { oct: -7 }), F('bridge', 0, 0.35, { n: 1 })] },
  mukjeok: { tonic: 55, mode: 'minor', bpm: 76, meter: 4, rhy: 'oblivion2', lead: 'shakuhachi', lead2: 'piano', counter: 'harp', arp: 'piano', accIns: 'harp', acc: 'inkrain8', bass: 'half', drum: 'b_mukjeok', drumIn: null, pad: 'swell', bell: 0.1, soft: 0.9, bshape: true,
    bt: { bpm: 90, rhy: 'oblivion2', lead: 'shakuhachi', lead2: 'piano', counter: 'harp', arp: 'piano', accIns: 'piano', acc: 'inkrain16', bass: 'half', drum: 'b_mukjeok2', pad: 'swell', bell: 0.1,
      form: [F('A', 'lead', 0.88, { oct: -7 }), F('B', 'lead2', 0.95, { duet: 'shakuhachi' }), F('A2', 'lead', 0.9, { oct: -7, echo: 'harp' })] },
    form: [F('A', 'lead', 0.85, { oct: -7 }), F('B', 'lead2', 0.92, { duet: 'shakuhachi' }), F('A2', 'lead', 0.88, { oct: -7, echo: 'harp' })] },
};
let playing = false, phraseTimer = null, song = null, songKey = '', barNo = 0, nextAt = 0, loopNo = 0, held = false;
let droneKey = '';

const bshape = p => !!(p.battle || p.bshape);
function battleOf(p) {
  const b = p.bt || {};
  return { ...p, battle: true, meter: 4, rhy: 'battle', acc: 'battle', bass: 'battle', drumIn: null, pad: 'light', accIns: null, counter: p.counter, ...b,
    bpm: Math.min(140, b.bpm || Math.max(Math.round(p.bpm * 1.4), 100)), form: b.form || [F('A', 'lead', 0.85), F('B', 'lead2', 0.95)] };
}
function profile(battle = inBattle()) {
  let p = { ...(PROFILES[scene.territory] || PROFILES.capital) };
  if (battle) p = battleOf(p);
  if (scene.safe && !battle) { p.bpm *= 0.94; p.drum = null; p.safe = true; }
  if (env.phase === 'night') p.bpm *= 0.96;
  return p;
}
const insOf = p => [...new Set([p.lead, p.lead2, p.counter, p.arp, p.accIns, p.bassIns || 'cello', p.pad === 'none' ? null : 'strings', p.bell > 0 ? 'bell' : null, p.drum ? 'taiko' : null,
  ...p.form.flatMap(f => [f.ins && INS[f.ins] ? f.ins : null, f.echo, f.duet, f.trem ? 'koto' : null])].filter(k => k && INS[k]))];

function seeded(str) { let h = 2166136261; for (const ch of str) h = Math.imul(h ^ ch.charCodeAt(0), 16777619); return () => { h = Math.imul(h ^ (h >>> 15), 2246822507) ^ Math.imul(h ^ (h >>> 13), 3266489909); h >>>= 0; return h / 4294967296; }; }

function makeSong(p, key, loop) {
  const M = MODES[p.mode], prog0 = PROG[p.prog || (p.mode === 'major' ? 'major' : 'minor')];
  const prog = p.mode === 'phryg' ? Object.fromEntries(Object.entries(prog0).map(([k, v]) => [k, v.map(c => c.map(x => (x === 4 ? 1 : x)))])) : prog0;
  const theme = seeded(key), vary = seeded(`${key}:${loop}`);
  const pick = (r, a) => a[Math.floor(r() * a.length)];
  const mod7 = d => ((d % 7) + 7) % 7;
  const midi = (d, base = p.tonic) => base + 12 * Math.floor(d / 7) + M[mod7(d)];
  const chordTones = c => [mod7(c), mod7(c + 2), mod7(c + 4)];
  const LO = 2, HI = 13, RS = RHY[p.rhy] || RHY.calm, beats = p.meter;
  const phrase = (r, chords, o = {}) => {
    const R = k => pick(r, RS[k]);
    const rh = o.rhythm || [R('move'), R('mid'), R('move'), R('end')];
    const slots = []; rh.forEach((bar, bi) => { let pos = 0; bar.forEach(x => { if (typeof x === 'string') { pos += Number(x.slice(1)); return; } slots.push({ bi, pos, len: x }); pos += x; }); });
    const N = slots.length, start = o.start ?? pick(r, [5, 6, 7, 7, 8, 9]), peak = o.peak ?? (2 + Math.floor(r() * 3));
    let cur = start;
    const bars = [[], [], [], []];
    slots.forEach((s, i) => {
      const target = start + Math.round(peak * Math.sin(Math.PI * Math.min(1, i / Math.max(1, N - 1)) * 0.95));
      if (i > 0) {
        const dir = Math.sign(target - cur) || (r() < 0.5 ? 1 : -1), x = r();
        const size = x < 0.1 ? 0 : x < 0.55 ? 1 : x < 0.8 ? 2 : x < 0.93 ? 3 + Math.floor(r() * 2) : 5;
        cur += (r() < 0.82 ? dir : -dir) * size;
      }
      const chord = chords[s.bi];
      const strong = s.pos === 0 || (beats === 4 && s.pos === 2);
      if ((s.len >= 1 || (strong && r() < 0.7)) && !chordTones(chord).includes(mod7(cur))) {
        const up = target >= cur ? 1 : -1, c = [up, -up, 2 * up, -2 * up].map(x => cur + x).find(d => chordTones(chord).includes(mod7(d)));
        if (c != null) cur = c;
      }
      if (i === N - 1 && o.end != null) { const e = o.end; cur = [e - 7, e, e + 7].reduce((a, b) => Math.abs(b - cur) < Math.abs(a - cur) ? b : a); }
      cur = Math.max(LO, Math.min(HI, cur));
      const orn = s.len >= 1.5 && i < N - 1 ? (r() < 0.35 ? 'slide' : r() < 0.25 ? 'grace' : '') : '';
      bars[s.bi].push([s.pos, cur, s.len, orn]);
    });
    return { bars, rhythm: rh, chords };
  };
  const variant = (ph, r) => {
    const bars = ph.bars.map(b => b.map(n => [...n]));
    const flat = bars.flatMap((b, bi) => b.map((n, ni) => [bi, ni])).slice(0, -1);
    for (let k = 0; k < 2 && flat.length; k++) { const [bi, ni] = pick(r, flat); const n = bars[bi][ni]; if (n[2] < 1) n[1] = Math.max(LO, Math.min(HI, n[1] + (r() < 0.5 ? 1 : -1))); }
    const longs = flat.filter(([bi, ni]) => bars[bi][ni][2] >= 2);
    if (longs.length && r() < 0.6) { const [bi, ni] = pick(r, longs); const n = bars[bi][ni]; const nb = [n[0] + n[2] - 0.5, n[1] + (r() < 0.5 ? 1 : -1), 0.5, '']; n[2] -= 0.5; bars[bi].splice(ni + 1, 0, nb); }
    bars.forEach(b => b.forEach(n => { if (n[2] >= 1.5) n[3] = r() < 0.3 ? 'slide' : r() < 0.2 ? 'grace' : ''; }));
    return { ...ph, bars };
  };
  const period = (r, o = {}) => {
    const c1 = o.c1 || pick(r, prog.ante), c2 = o.c2 || pick(r, prog.cons);
    const a = phrase(r, c1, { start: o.start, end: o.end1 ?? pick(r, [4, 2, 1]), peak: o.peak });
    const b = phrase(r, c2, { start: o.start2 ?? a.bars[0][0]?.[1], end: o.end2 ?? 7, peak: o.peak, rhythm: [a.rhythm[0], pick(r, RS.mid), pick(r, RS.move), pick(r, RS.end)] });
    return [a, b];
  };

  const A = period(theme);
  const src = {
    A, A2: A.map(ph => variant(ph, vary)),
    B: bshape(p) ? period(vary, { start: 9, peak: 3 }) : period(vary, { c1: pick(vary, prog.bA), c2: pick(vary, prog.bC), start: 9 + Math.floor(vary() * 2), peak: 3, end1: 6, end2: 4 }),
    C: period(vary, { c1: pick(vary, prog.bA), start: 3, peak: 2, end1: 4 }),
    A3: [A[0], variant(A[1], vary)],
  };
  const bars = [];
  let loopStart = 0, seenMain = false;
  p.form.forEach(f => {
    if (f.n) {
      for (let i = 0; i < f.n; i++) bars.push({ pi: i, last: i === f.n - 1, sec: f.s, chord: f.s === 'bridge' && i === f.n - 1 ? (p.mode === 'major' ? 4 : 6) : A[0].chords[f.s === 'bridge' ? 3 : i % 4], mel: [], inten: f.v + i * 0.04, hint: f.s === 'intro' && i === f.n - 1 ? A[0].bars[0] : null });
      if (!seenMain) loopStart = bars.length;
      return;
    }
    seenMain = true;
    const lead = p[f.ins] || f.ins;
    src[f.s].forEach((ph, pj) => ph.bars.forEach((b, i) => bars.push({ sec: f.s, chord: ph.chords[i], mel: b, lead, oct: f.oct || 0, inten: f.v, echo: f.echo, duet: f.duet, trem: f.trem, last: i === 3, pi: i, pj })));
  });
  if (loopStart === bars.length) loopStart = 0;
  return { bars, loopStart: bshape(p) ? 0 : loopStart, midi, mod7, chordTones };
}

const DYN = [0.84, 0.95, 1.08, 0.86];
const LEAD_GAIN = { strings: 1.9, cello: 1.05, piano: 1.1 };
function playBar(p, S, bar, t, beat) {
  const { midi, mod7, chordTones } = S, mb = p.meter;
  soft = p.soft || 0;
  const dyn = (DYN[bar.pi ?? 0] ?? 1) * (bar.pj ? 1.04 : 1);
  const inten = bar.inten * (p.safe ? 0.85 : 1) * dyn;
  const human = () => (Math.random() - 0.5) * 0.02, hv = v => v * (0.9 + Math.random() * 0.2);
  const root = bar.chord, tones = chordTones(root), tri = [root, root + 2, root + 4];
  const lead7 = p.mode === 'minor' && mod7(root) === 4;
  const hm = (d, base) => midi(d, base) + (lead7 && mod7(d) === 6 ? 1 : 0);
  const near = d => [d, d - 1, d + 1, d - 2, d + 2].find(x => tones.includes(mod7(x))) ?? d;
  const melEnd = bar.mel.length ? bar.mel[bar.mel.length - 1] : null;
  const oct = bar.oct || 0, lg = LEAD_GAIN[bar.lead] || 1;
  const sus = INS[bar.lead]?.sus;
  bar.mel.forEach(([pos, d, len, orn], i) => {
    const m = hm(d + oct), prev = bar.mel[i - 1], at = t + pos * beat + human();
    const acc = pos === 0 ? 1.08 : pos % 1 ? 0.88 : 1;
    playNote(bar.lead, m, at, len * beat * 0.98, hv((0.95 * inten + 0.05) * acc * lg),
      { slide: orn === 'slide' ? (bar.lead === 'fiddle' ? 2 : 1) : (bar.lead === 'fiddle' && prev && Math.abs(prev[1] - d) === 1 && Math.random() < 0.3 ? 1 : 0), grace: orn === 'grace' ? 2 : 0,
        att: bar.lead === 'strings' ? 0.12 : undefined, expr: sus && len * beat > 0.45, vib: sus && len * beat > 0.9 && bar.lead !== 'strings' });
    if (bar.duet && bar.duet !== bar.lead && len >= 0.5) {
      const dd = [2, 3, 4, 5].map(x => d - x).find(x => tones.includes(mod7(x)));
      if (dd != null) playNote(bar.duet, hm(dd + oct + (bar.duet === 'strings' && oct === 0 ? -7 : 0)), at + 0.012, len * beat * 0.98, hv(0.5 * inten * (LEAD_GAIN[bar.duet] || 1)), { expr: true, att: bar.duet === 'strings' ? 0.15 : undefined });
    }
    if (bar.echo && pos + 1 < mb && tones.includes(mod7(d))) playNote(bar.echo, hm(d - 7), t + (pos + 1) * beat + human(), Math.min(len, 1.5) * beat, hv(0.36 * inten), { expr: true });
  });
  const answer = !bar.echo && !bshape(p) && melEnd && melEnd[2] >= 1.5 && melEnd[0] <= mb - 1.5 && (bar.sec !== 'A' || (bar.last && Math.random() < 0.5));
  if (answer) {
    const src = (S.bars.find(b => b.sec === 'A')?.mel || []).slice(0, 3);
    let at = melEnd[0] + 0.5;
    src.forEach(([, d], i) => { if (at < mb) { const dn = i === src.length - 1 ? near(d) : d; playNote(p.counter, hm(dn - 7), t + at * beat + human(), (i === src.length - 1 ? 1.5 : 0.5) * beat, hv(0.48 * inten), { expr: true }); at += i === src.length - 1 ? 1.5 : 0.5; } });
  }
  if (bar.hint) bar.hint.forEach(([pos, d, len]) => playNote(p.counter, hm(near(d) - 7), t + pos * beat, len * beat, 0.4, { expr: true }));
  const accIns = p.accIns || p.arp, accBase = d => hm(d - (accIns === 'strings' ? 14 : 7), p.tonic);
  const pat = (ACC[p.acc] || ACC.calm).filter(([pos]) => pos < mb);
  const accVol = (answer ? 0.5 : 1) * (['intro', 'bridge', 'drop'].includes(bar.sec) ? 0.55 : 0.4) * inten * (accIns === 'strings' ? 0.9 : 1);
  const accLen = p.acc === 'tango' ? 1.3 : p.acc === 'tango8' ? 0.7 : p.acc === 'sparse' || p.acc === 'eerie' || p.acc === 'slow3' ? 2 : p.acc === 'fast' ? 0.3 : p.acc === 'ostinato' || p.acc === 'battle' || p.acc === 'flowing' || p.acc === 'shimmer' || p.acc === 'dance3' ? 0.6 : 1;
  pat.forEach(([pos, step, v], i) => playNote(accIns, accBase(root + step), t + pos * beat + human(), accLen * beat, hv(accVol * v * (1 - 0.15 * (i / Math.max(1, pat.length - 1))))));
  if (bar.trem) { const n = mb * 4; for (let k = 0; k < n; k++) playNote('koto', hm(tri[k % 3]), t + k * beat / 4, beat / 2, hv((k % 4 ? 0.16 : 0.28) * inten * (0.7 + 0.5 * Math.sin(Math.PI * k / n)))); }
  const bI = p.bassIns || 'cello', bO = p.tonic < 53 ? -7 : -14, bass = midi(root + bO, p.tonic), five = midi(root + 4 + bO, p.tonic), bv = 0.75 * inten + 0.05;
  if (bar.sec !== 'intro' || p.bass === 'pedal' || p.bass === 'long' || p.bass === 'tango') {
    switch (p.bass) {
      case 'battle': [[0, 1], [1.5, .7], [2, .9], [3, .7]].forEach(([pos, v]) => playNote(bI, bass, t + pos * beat, 0.45 * beat, hv(0.6 * v))); break;
      case 'drive': for (let k = 0; k < mb * 2; k++) playNote(bI, k === 4 ? five : bass, t + k * beat / 2, 0.42 * beat, hv((k % 2 ? 0.42 : 0.68) * (0.6 + inten * 0.5))); break;
      case 'march': [[0, bass, 1], [1.5, bass, .6], [2, five, .85], [3, bass, .6]].forEach(([pos, m, v]) => playNote(bI, m, t + pos * beat, 0.8 * beat, hv(v * bv))); break;
      case 'tango': [[0, bass, 1], [1.5, five, .72], [3, bass, .85]].forEach(([pos, m, v]) => playNote(bI, m, t + pos * beat, (pos === 3 ? 0.9 : 1.4) * beat, hv(v * bv), { expr: true })); if (!bar.last && p.battle) playNote(bI, bass - 1, t + 3.5 * beat, 0.45 * beat, hv(0.5 * bv)); break;
      case 'waltz': playNote(bI, bass, t, 0.9 * beat, hv(bv)); break;
      case 'pedal': playNote(bI, midi(-14, p.tonic), t, mb * beat, hv(0.6 * inten + 0.1), { swell: true }); break;
      case 'half': playNote(bI, bass, t, 2 * beat, hv(bv), { expr: true }); playNote(bI, five, t + 2 * beat, (mb - 2) * beat, hv(0.85 * bv), { expr: true }); break;
      default: playNote(bI, bass, t, mb * beat, hv(bv), { swell: true });
    }
  }
  const padOn = p.pad === 'none' ? false : p.pad === 'sustain' || p.pad === 'open' || bshape(p) ? true
    : p.pad === 'light' ? bar.sec === 'B' || bar.sec === 'C'
    : ['A2', 'B', 'C'].includes(bar.sec) || (bar.sec === 'A3' && !bar.last);
  if (padOn && bar.sec !== 'drop' && !(bar.lead === 'strings' && bar.mel.length)) {
    const pv = (bar.sec === 'B' ? 0.6 : p.pad === 'sustain' ? 0.32 : 0.44) * inten;
    const notes = p.pad === 'open' ? [root, root + 4, root + 7] : tri;
    notes.forEach(d => playNote('strings', hm(d - 7, p.tonic), t + 0.05, mb * beat, hv(pv), { swell: true }));
  }
  if (p.bell > 0 && (bar.mel.length || bar.sec === 'intro') && Math.random() < p.bell * (bar.sec === 'B' ? 1.4 : 0.6) && (bar.sec === 'intro' || barNo % (bshape(p) ? 2 : 4) === 0)) playNote('bell', hm(root + 7, p.tonic), t + (bshape(p) ? 0 : Math.min(2, mb - 1) * beat), 2 * beat, 0.55);
  if (p.drum && (!p.drumIn || p.drumIn.includes(bar.sec) || bar.sec === 'drop')) {
    const set = DRUM[p.drum]; if (set) {
      const hits = (bar.last ? set.fill : barNo % 2 ? set.alt : set.main).filter(([pos]) => pos < mb);
      const dv = bshape(p) ? 0.95 : 0.6 + 0.35 * inten;
      if (p.drum !== 'pulse' || barNo % 2 === 0 || bar.last) hits.forEach(([pos, v, k]) => playDrum(t + pos * beat + human() * 0.5, hv(v * dv), k));
    }
  }
}

function phrase() {
  if (!playing || !ctx || away) return;
  if (held) { phraseTimer = setTimeout(phrase, 1000); return; }
  const p = profile(), need = insOf(p), key = `${scene.territory || 'capital'}:${p.mode}:${p.battle ? 'battle' : 'field'}`;
  if (need.some(k => !buffers[k])) { need.forEach(loadIns); phraseTimer = setTimeout(phrase, 400); return; }
  if (key !== songKey || !song) { song = makeSong(p, key, 0); songKey = key; barNo = 0; loopNo = 0; }
  if (barNo >= song.bars.length) { loopNo++; const s2 = makeSong(p, key, loopNo); song = s2; barNo = s2.loopStart; }
  const beat = 60 / p.bpm, barDur = p.meter * beat;
  if (nextAt < now() + 0.05) nextAt = now() + 0.15;
  const t = nextAt;
  playBar(p, song, song.bars[barNo], t, beat);
  barNo++; nextAt = t + barDur;
  phraseTimer = setTimeout(phrase, Math.max(50, (nextAt - now() - 0.35) * 1000));
}
function updateDrone() {
  if (!ctx) return;
  const key = `${scene.territory}:${inBattle()}`;
  if (droneKey === key) return;
  droneKey = key;
  if (!playing) return;
  const both = [...new Set([...insOf(profile(false)), ...insOf(profile(true))])];
  keepOnly(both); both.forEach(loadIns);
}
function startMusic() { if (playing || !ensureCtx()) return; playing = true; ctx.resume?.(); droneKey = ''; updateDrone(); nextAt = 0; phraseTimer = setTimeout(phrase, 300); }
function stopMusic() { playing = false; clearTimeout(phraseTimer); droneKey = ''; }

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
const ambMat = {};
const BUILD = Object.fromEntries(Object.keys(AMB).map(k => [k, g => { ambMat.noise = noiseBuf; ambMat.brown = brownBuf; return AMB[k](ctx, g, ambMat); }]));
let critterTimer = null;
function critters() {
  clearTimeout(critterTimer);
  if (away || yielded) return;
  if (!ctx || !sound.ambOn || held) { critterTimer = setTimeout(critters, 4000); return; }
  const under = scene.territory === 'underworld' || scene.territory === 'abyss' || scene.territory === 'gwiheo';
  const t = now() + 0.05, ph = env.phase, w = env.weather;
  const quiet = w === 'rain' || w === 'drizzle' || w === 'snow' || w === 'wind';
  if (!under && (ph === 'dawn' || ph === 'noon') && !quiet && Math.random() < (ph === 'dawn' ? 0.6 : 0.3)) {
    bird(ctx, ambBus, t); if (ph === 'dawn' && Math.random() < 0.35) bird(ctx, ambBus, t + 0.4 + Math.random() * 0.6, 0.55);
  }
  if (!under && (ph === 'dusk' || ph === 'night') && w !== 'snow' && w !== 'rain') {
    const v = (ph === 'night' ? 1 : 0.65) * (w === 'drizzle' ? 0.5 : 1);
    cricket(ctx, ambBus, t, v); if (Math.random() < 0.5) cricket(ctx, ambBus, t + 0.12 + Math.random() * 0.2, v * 0.55);
    if (ph === 'night' && Math.random() < 0.04) owl(ctx, ambBus, t + 1);
  }
  if ((w === 'fog' || under) && Math.random() < 0.3) drip(ctx, ambBus, t);
  const gap = ph === 'dusk' || ph === 'night' ? 450 + Math.random() * 800 : 1500 + Math.random() * 3500;
  critterTimer = setTimeout(critters, gap);
}
function updateAmbience() {
  if (!ctx) return;
  const w = env.weather, under = scene.territory === 'underworld' || scene.territory === 'abyss' || scene.territory === 'gwiheo';
  setLayer('rain', w === 'rain' ? 0.38 : 0, BUILD.rain);
  setLayer('drizzle', w === 'drizzle' ? (under ? 0.3 : 0.55) : 0, BUILD.drizzle);
  setLayer('wind', w === 'wind' ? 0.5 * (under ? 0.4 : 1) : 0, BUILD.wind);
  setLayer('water', w === 'fog' || under ? 0.14 : w === 'rain' ? 0.06 : w === 'drizzle' ? 0.01 : 0, BUILD.water);
  setLayer('hiss', w === 'snow' ? 0.006 : 0, BUILD.hiss);
  setLayer('mist', w === 'bloodmist' ? 0.05 : 0, BUILD.mist);
}

let toBus = null, alarmBus = null;
function tone(freq, dur, vol = 0.1, type = 'sine', at = 0, glide) {
  const t0 = now() + at, o = ctx.createOscillator(), g = ctx.createGain(); o.type = type; o.frequency.setValueAtTime(freq, t0);
  if (glide) o.frequency.exponentialRampToValueAtTime(glide, t0 + dur);
  envGain(g, t0, vol, Math.min(0.012, dur / 4), dur); o.connect(g); g.connect(toBus || sfxBus); o.start(t0); o.stop(t0 + dur + 0.05);
}
const seq = (notes, step, dur, vol, type = 'sine') => notes.forEach((f, i) => tone(f, dur, vol, type, i * step));
const SFX = {
  tap: () => { tone(880, 0.045, 0.07, 'sine', 0, 660); tone(1760, 0.02, 0.012, 'triangle'); }, tick: () => tone(980, 0.03, 0.05), nav: () => { tone(620, 0.07, 0.07, 'sine', 0, 720); tone(1240, 0.03, 0.01, 'triangle'); },
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
  ding: () => { seq([1047, 1319, 1568], 0.1, 0.4, 0.08); tone(2093, 0.5, 0.025, 'sine', 0.2); },
  chime: () => tone(660, 0.2, 0.05), error: () => seq([240, 200], 0.1, 0.1, 0.06), repair: () => { tone(900, 0.04, 0.05); tone(700, 0.05, 0.05, 'sine', 0.07); },
};
export function playSfx(kind) {
  if (POPWIN || !sound.sfxOn || away || !ensureCtx()) return;
  try { (SFX[kind] || SFX.tap)(); } catch {}
}
export const ALARMS = [['whisper', '귓속말', '귓속말이 오면'], ['mention', '내 이름 부르기', '채팅에서 누가 @내 이름을 쓰면'], ['stamina', '탐색력 가득', '탐색력이 가득 차면'],
  ['rest_short', '잠깐 쉬기 가능', '잠깐 쉬기를 다시 할 수 있게 되면(10분)'], ['rest_full', '푹 쉬기 가능', '푹 쉬기를 다시 할 수 있게 되면(30분)'], ['exp', '원정 귀환', '원정대가 돌아오면'], ['idle', '자율 활동 끝', '자율 활동이 끝나 보상을 받을 수 있으면']];
let alarmReady = false;
const ALARM_TEXT = { stamina: '탐색력이 가득 찼습니다.', rest_short: '잠깐 쉬기를 다시 할 수 있습니다.', rest_full: '푹 쉬기를 다시 할 수 있습니다.', idle: '자율 활동이 끝났습니다. 캐릭터 › 자율에서 보상을 받으세요.' };
export const alarmOn = kind => sound.alarm?.[kind] !== false;
export function setAlarm(kind, on) { sound.alarm = { ...(sound.alarm || {}), [kind]: !!on }; saveSound(); }
export function playAlarm(kind, key) {
  if (POPWIN && !alarmReady) { alarmReady = true; loadSound(); }
  if (kind && !alarmOn(kind)) return;
  if (/^rest_/.test(kind || '')) { let l = 0; try { l = Number(localStorage.getItem('yh-alarm:rest-any') || 0); } catch {} if (Date.now() - l < 10000) return; try { localStorage.setItem('yh-alarm:rest-any', String(Date.now())); } catch {} }
  if (key) try { const k = 'yh-alarm:' + key; if (localStorage.getItem(k)) return; localStorage.setItem(k, String(Date.now())); setTimeout(() => { try { localStorage.removeItem(k); } catch {} }, 60000); } catch {}
  if (ALARM_TEXT[kind] && !POPWIN) toast(ALARM_TEXT[kind], 'ok');
  if (away || !ensureCtx()) return;
  try {
    ctx.resume?.();
    if (!alarmBus) { alarmBus = ctx.createGain(); alarmBus.connect(master); }
    alarmBus.gain.value = Math.max(0.25, sound.sfx ?? 0.55) * 0.5;
    toBus = alarmBus; SFX.ding();
  } catch {} finally { toBus = null; }
}
const armed = new Map();
export function armAlarm(kind, name, at) {
  const id = kind + ':' + name, t = at ? new Date(at).getTime() : 0, old = armed.get(id);
  if (old?.at === t) return;
  if (old) clearTimeout(old.timer);
  armed.delete(id);
  const left = t - Date.now();
  if (!t || left <= 0 || left > 2 ** 31 - 1) return;
  armed.set(id, { at: t, timer: setTimeout(() => { armed.delete(id); playAlarm(kind, id + ':' + t); }, left + 300) });
}
export const SFX_SAMPLES = [['confirm', '확인'], ['find', '발견'], ['hit', '전투'], ['coin', '거래'], ['craft', '제작'], ['travel', '출발'], ['reward', '보상'], ['error', '오류']];

export function setScene(part) {
  const before = `${scene.territory}:${scene.safe}:${inBattle()}`;
  Object.assign(scene, part);
  if (before === `${scene.territory}:${scene.safe}:${inBattle()}`) return;
  updateDrone(); updateAmbience();
}
export function setEnabled(key, value) {
  sound[key] = value; saveSound();
  if (!ensureCtx()) return;
  ctx.resume?.();
  if (key === 'bgmOn') musicOk() ? startMusic() : stopMusic();
  applyVolumes(); updateAmbience();
}
export function setVolume(key, value) { sound[key] = value; saveSound(); ensureCtx(); applyVolumes(); }

function soundLink() {
  if (POPWIN || !('BroadcastChannel' in window)) return;
  const id = Math.random().toString(36).slice(2), bc = new BroadcastChannel('yh-sound');
  let last = 0;
  const claim = () => {
    if (Date.now() - last < 3000 && !yielded) return; last = Date.now();
    try { bc.postMessage({ t: 'claim', id }); } catch {}
    if (yielded) { yielded = false; if (ctx) { applyVolumes(); if (musicOk()) startMusic(); updateAmbience(); critters(); } }
  };
  bc.onmessage = e => {
    if (e.data?.t !== 'claim' || e.data.id === id || yielded) return;
    yielded = true; stopMusic(); clearTimeout(critterTimer); applyVolumes();
  };
  claim();
  document.addEventListener('pointerdown', claim, { capture: true });
  document.addEventListener('keydown', claim, { capture: true });
  window.addEventListener('focus', claim);
}
export function initSound() {
  if (POPWIN) { document.addEventListener('pointerdown', () => { if (!alarmReady) { alarmReady = true; loadSound(); } if (ensureCtx()) { ctx.resume?.(); applyVolumes(); } }, { once: true }); return; }
  loadSound();
  on('changed', ({ name }) => { const m = SFX_ACTS.find(([re]) => re.test(name)); const k = m ? m[1] : 'confirm'; if (k) playSfx(k); });
  let expTimer = null;
  const setExp = e => { clearTimeout(expTimer); const left = e?.ends_at ? new Date(e.ends_at) - Date.now() : 0; if (left > 0) expTimer = setTimeout(() => setExp(null), Math.min(left + 500, 2 ** 31 - 1)); setScene({ exp: left > 0 }); };
  on('expedition', setExp);
  on('env', e => { if (!e) return; env = { weather: e.weather?.key || 'clear', phase: e.phase?.key || 'noon' }; if (e.territory_id) scene.territory = e.territory_id; updateDrone(); updateAmbience(); });
  window.addEventListener('yh-sfx', e => playSfx(e.detail));
  window.addEventListener('yh-cutscene', e => { held = !!e.detail; applyVolumes(); });
  document.addEventListener('click', e => {
    const b = e.target.closest('button, [role="button"], a[href], summary, .chip, .facility, .path, .act, input[type="checkbox"], input[type="radio"]');
    if (!b || b.disabled || b.closest('[data-nosfx]')) return;
    if (b.closest('.battle') || b.id === 'search') return;
    playSfx(b.closest('.tabbar, .topnav') ? 'nav' : 'tap');
  }, { capture: true });
  const unlock = () => { if (!ensureCtx()) return; ctx.resume?.(); applyVolumes(); if (musicOk()) startMusic(); if (!yielded) { updateAmbience(); critters(); } };
  soundLink();
  document.addEventListener('pointerdown', unlock, { once: true });
  document.addEventListener('keydown', unlock, { once: true });
  if (MOBILE) {
    const leave = () => {
      if (away) return; away = true;
      clearTimeout(phraseTimer); clearTimeout(critterTimer);
      keepOnly([]);
      if (ctx) { master.gain.setValueAtTime(0, ctx.currentTime); ctx.suspend?.().catch(() => {}); }
    };
    const back = () => {
      if (!away || document.hidden) return; away = false;
      if (!ctx) return;
      const wake = () => { master.gain.setTargetAtTime(masterLevel(), ctx.currentTime, 0.2); if (playing) { clearTimeout(phraseTimer); phraseTimer = setTimeout(phrase, 400); } critters(); };
      Promise.resolve(ctx.resume?.()).then(wake, wake);
    };
    document.addEventListener('visibilitychange', () => (document.hidden ? leave() : back()));
    window.addEventListener('pagehide', leave);
    window.addEventListener('pageshow', back);
    document.addEventListener('pointerdown', () => { if (ctx && !away && ctx.state !== 'running') ctx.resume?.(); });
  }
}
