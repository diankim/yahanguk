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
  bgmBus.gain.setTargetAtTime(sound.bgmOn ? sound.bgm * 0.8 : 0, t, 0.3);
  ambBus.gain.setTargetAtTime(sound.ambOn ? sound.amb * 0.5 : 0, t, 0.4);
  sfxBus.gain.setTargetAtTime(sound.sfxOn ? sound.sfx * 0.5 : 0, t, 0.05);
}

function ensureCtx() {
  if (ctx) return ctx;
  const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return null;
  // 32kHz로 열어 악기 샘플을 풀어 둘 메모리를 줄인다(지원하지 않으면 기본값)
  try { ctx = new AC({ sampleRate: 32000 }); } catch { ctx = new AC(); }
  master = ctx.createGain(); master.gain.value = 0.9; master.connect(ctx.destination);
  bgmBus = ctx.createGain(); ambBus = ctx.createGain(); sfxBus = ctx.createGain();
  [bgmBus, ambBus, sfxBus].forEach(g => { g.gain.value = 0; g.connect(master); });
  // 잔향: 넓은 전각처럼 길게 남되, 꼬리로 갈수록 고음을 걸러 「쉬—」 하는 잡음이 들리지 않게 한다
  reverb = ctx.createConvolver();
  const len = ctx.sampleRate * 3.4, ir = ctx.createBuffer(2, len, ctx.sampleRate);
  for (let ch = 0; ch < 2; ch++) {
    const d = ir.getChannelData(ch); let lp = 0;
    for (let i = 0; i < len; i++) { const x = i / len; lp += ((Math.random() * 2 - 1) - lp) * (0.3 - 0.26 * x); d[i] = lp * Math.pow(1 - x, 2.2) * 2.4; }
  }
  reverb.buffer = ir;
  const rlp = ctx.createBiquadFilter(); rlp.type = 'lowpass'; rlp.frequency.value = 3200;
  const wet = ctx.createGain(); wet.gain.value = 0.3; reverb.connect(rlp); rlp.connect(wet); wet.connect(bgmBus);
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

/* ── 악기(녹음 조각) ───────────────────────────────────── */
// FluidR3 GM 사운드폰트(CC BY 3.0)에서 악기마다 몇 음을 잘라 한 파일(assets/audio/*.mp3)에 3.2초 칸으로 이어 붙였다.
// 가장 가까운 음을 골라 빠르기를 바꿔 원하는 높이로 낸다(최대 1.5~2반음). 길게 끄는 악기는 가운데를 겹쳐 이어 늘린다.
// 가야금 → 고토, 대금 → 샤쿠하치·플루트, 해금 → 피들로 대신하고, 첼로·현악·하프·종·북을 받침으로 쓴다. 피아노(7.3.2)는 북령·지하·천문·심연에 쓴다(tools/bgm_samples/build.py).
const SLOT = 3.2;
const INS = {
  piano:      { notes: [33, 37, 41, 45, 49, 53, 57, 61, 65, 69, 73, 77, 81, 85], len: 3.1, sus: false, gain: 0.5, att: 0.004, rel: 0.7, pan: 0.08, send: 0.5 },
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
// 지금 곡에 쓰지 않는 악기는 메모리에서 내려놓는다(모바일)
function keepOnly(keys) { Object.keys(buffers).forEach(k => { if (!keys.includes(k)) { delete buffers[k]; loadingIns[k] = null; } }); }

// 한 음 내기: t초에 midi 높이로 dur초 동안. o.slide = 아래에서 미끄러져 올라올 반음 수, o.grace = 짧게 스칠 윗음(반음),
// o.att = 소리가 차오르는 시간(초), o.expr = 길게 끄는 음에 숨결(조금 여리게 시작해 부풀었다 가라앉음), o.swell = 바닥 화음처럼 천천히 부풀었다 잦아듦,
// o.vib = 떨림(길게 끄는 음의 뒤쪽에 살짝)
function playNote(k, midi, t, dur, vel, o = {}) {
  const I = INS[k], buf = buffers[k]; if (!I || !buf || vel <= 0) return;
  let idx = 0, best = 99; I.notes.forEach((n, i) => { const d = Math.abs(midi - n); if (d < best) { best = d; idx = i; } });
  const rate = Math.pow(2, (midi - I.notes[idx]) / 12), off = idx * SLOT;
  const g = ctx.createGain(), pan = ctx.createStereoPanner ? ctx.createStereoPanner() : null;
  if (pan) { pan.pan.value = I.pan + (Math.random() - 0.5) * 0.1; g.connect(pan); toBgm(pan, I.send); } else toBgm(g, I.send);
  const peak = Math.max(0.0002, vel * I.gain);
  // 뜯는 악기는 자연스럽게 울리게 두고(최대 샘플 길이), 부는·켜는 악기는 dur 동안 이어 낸다
  const ring = I.sus ? dur : Math.max(dur, Math.min(I.len, dur + 1.6));
  const end = t + ring + I.rel;
  const att = o.att ?? I.att;
  g.gain.setValueAtTime(0.0001, t);
  if (I.sus && (o.expr || o.swell) && ring > 0.5) {
    // 숨결: 한 음 안에서도 세기가 움직이게 — 숨결은 0.7배로 들어가 40% 자리에서 가장 크고 끝으로 갈수록 0.55배, 부풂은 더 천천히 들어가 가운데서 크고 0.6배로 잦아든다
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
    // length는 실제 시간(초), 샘플에서 쓰는 길이는 length × rate
    s.connect(sg); sg.connect(g); s.start(start, offset, length * rate + 0.02); s.stop(start + length + 0.05); srcs.push(s);
  };
  const need = end - t, first = Math.min(need, (I.len - 0.15) / rate);
  if (!I.sus || need <= first) seg(t, off, Math.min(need, I.len / rate), 0, 0, true);
  else {
    // 샘플 길이를 넘는 긴 음: 0.9~2.9초 구간을 겹쳐 이어 붙인다(0.35초 겹침)
    const L = 2.0 / rate, X = 0.35;
    seg(t, off, first, 0, X, true);
    for (let at = t + first - X; at < end; at += L - X) seg(at, off + 0.9, Math.min(L, end - at + 0.05), X, X, false);
  }
  // 떨림: 0.35초 뒤부터 5Hz로 ±12센트까지 천천히 깊어진다
  if (o.vib && I.sus && ring > 0.8 && srcs[0]?.detune) {
    const lfo = ctx.createOscillator(), dep = ctx.createGain();
    lfo.frequency.value = 4.8 + Math.random() * 0.8; dep.gain.setValueAtTime(0, t); dep.gain.setValueAtTime(0, t + 0.35); dep.gain.linearRampToValueAtTime(12, t + Math.min(ring, 1.1));
    lfo.connect(dep); srcs.forEach(x => dep.connect(x.detune)); lfo.start(t); lfo.stop(end + 0.05);
  }
  if (o.grace) playNote(k, midi + o.grace, t - 0.09, 0.08, vel * 0.7);
}

// 큰북: 녹음한 북 조각 위에 낮게 울리는 몸통(음높이가 떨어지는 사인파)과 가죽 치는 소리(걸러 낸 잡음)를 겹친다.
// kind: big(둥— 깊고 길게) · mid(둥) · small(딱, 짧게)
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

/* ── 곡조 ─────────────────────────────────────────────── */
// 7.3.0 편성 개편: 영역마다 선율만이 아니라 빠르기·박자(4박·3박)·쓰는 악기·반주 꼴·저음·북 장단·곡 구성(form)이 다르다.
// 곡은 form에 적은 단락을 차례로 연주하고 끝나면 도입 뒤로 돌아가 되풀이한다. 주제(A)는 영역마다 고정, 나머지(A2·B·C)는 되풀이마다 새로 짓는다.
// 단락에 echo(받는 악기가 한 박 늦게 주선율을 낮게 따라 부름)·duet(다른 악기가 화음 음으로 아래에서 겹침)·trem(가야금 떨림)을 붙여 소리를 풍성하게 한다.
// 7.3.0 다듬기(사용자 검토): ① 강약 — 프레이즈 안에서 마디마다 세기가 오르내리고(dynOf), 길게 끄는 관·현악은 한 음 안에서도 숨결·떨림이 있고, 바닥 화음은 천천히 부풀었다 잦아든다.
// ② 어울림 — 1박 넘는 선율 음과 겹침·메아리·받아치는 음은 그 마디 화음 음으로 맞추고, 단조의 딸림화음(V)은 이끎음을 올리며, 프리지안의 어두운 V는 ♭II로 바꾼다.
// 오음 고집을 풀고 3~6도 도약을 섞어 음 폭을 넓혔다. ③ 큰북(playDrum) — 영역마다 장단 셋(기본·변형·몰아치기)을 두어 마디마다 바꾸고 프레이즈 끝에서 몰아친다.
// ④ 전투는 영역마다 따로 편성한다(PROFILES[].bt: 북령은 현악·첼로·종의 진혼곡, 해금·가야금 잔걸음을 뺌).
const MODES = { minor: [0, 2, 3, 5, 7, 8, 10], major: [0, 2, 4, 5, 7, 9, 11], phryg: [0, 1, 3, 5, 7, 8, 10] };
const PENT = { minor: [0, 2, 3, 4, 6], major: [0, 1, 2, 4, 5], phryg: [0, 1, 3, 4, 5] }; // 오음(음계 칸 번호)
const PROG = {
  minor: { ante: [[0, 5, 3, 4], [0, 3, 5, 6], [0, 6, 5, 4], [5, 6, 0, 4], [0, 2, 3, 6]], cons: [[5, 6, 0, 0], [3, 4, 0, 0], [0, 5, 6, 0], [5, 3, 4, 0], [2, 5, 6, 0]],
           bA: [[5, 6, 2, 5], [3, 4, 5, 6], [5, 3, 6, 2]], bC: [[3, 6, 2, 4], [5, 3, 4, 4], [3, 5, 6, 6]] },
  major: { ante: [[0, 3, 4, 4], [0, 5, 3, 4], [0, 2, 3, 4], [5, 3, 1, 4]], cons: [[0, 3, 4, 0], [5, 3, 4, 0], [3, 4, 0, 0], [1, 4, 0, 0]],
           bA: [[5, 2, 3, 0], [3, 4, 2, 5], [5, 3, 0, 4]], bC: [[1, 4, 2, 5], [3, 1, 4, 4], [5, 1, 4, 4]] },
};
// 선율 리듬: 마디마다 박 길이 묶음('r1' = 1박 쉼). 4박·3박, 빠르기에 따라 고른다
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
};
// 반주(분산화음) 꼴: [박, 음계 칸(뿌리에서), 세기]. 박자(meter)에 맞는 것만 쓴다
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
};
// 큰북 장단: 이름마다 기본(main)·변형(alt, 짝수 마디)·몰아치기(fill, 프레이즈 끝 마디). [박, 세기, big|mid|small]
const roll = (from, to, step, v0, v1, k = 'small') => { const o = []; for (let x = from, i = 0, n = Math.round((to - from) / step); x < to - 1e-6; x += step, i++) o.push([x, v0 + (v1 - v0) * i / Math.max(1, n - 1), k]); return o; };
const DRUM = {
  // 평소
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
  // 전투
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
  b_gwiheo: { main: [[0, 1, 'big'], [1.5, 0.5, 'mid'], [3, 0.7, 'big']], alt: [[0, 1, 'big'], [2, 0.6, 'big']], fill: [[0, 1, 'big'], [1, 0.6, 'mid'], [2, 0.8, 'big'], [2.5, 0.6, 'mid'], [3, 0.9, 'big'], [3.5, 0.9, 'big']] },
};
// 영역마다 조성·빠르기·악기·짜임. tonic = 주선율 으뜸음(MIDI). form의 ins는 lead·lead2·counter 또는 악기 이름, oct는 음계 칸 옮김(-7 = 한 옥타브 아래)
const F = (s, ins, v, o = {}) => ({ s, ins, v, ...o });
const PROFILES = {
  // 직할령: 도성의 위엄 — 대금이 주제를 부르고 가야금이 따라 부르며, B에서는 가야금이 선율을 받고 대금이 아래에서 겹친다
  capital: { tonic: 62, mode: 'minor', bpm: 72, meter: 4, rhy: 'calm', lead: 'shakuhachi', lead2: 'koto', counter: 'koto', arp: 'harp', acc: 'calm', bass: 'half', drum: 'pulse', drumIn: ['B', 'A3'], pad: 'light', bell: 0.25,
    bt: { bpm: 104, lead: 'shakuhachi', lead2: 'flute', acc: 'battle', arp: 'koto', bass: 'battle', drum: 'b_capital', form: [F('A', 'lead', 0.85), F('B', 'lead2', 0.95, { duet: 'shakuhachi', trem: true })] },
    form: [F('intro', 0, 0.35, { n: 2 }), F('A', 'lead', 0.5), F('A2', 'lead', 0.66, { echo: 'koto' }), F('B', 'lead2', 0.85, { duet: 'shakuhachi' }), F('A3', 'lead', 0.58), F('bridge', 0, 0.3, { n: 2 })] },
  // 수향: 물 위의 장터 — 3박 춤곡, 플루트와 가야금이 선율을 주고받고 하프가 쿵·짝·짝
  east: { tonic: 64, mode: 'major', bpm: 108, meter: 3, rhy: 'dance3', lead: 'flute', lead2: 'koto', counter: 'harp', arp: 'koto', acc: 'waltz', bass: 'waltz', drum: 'tap3', drumIn: ['A2', 'B', 'C'], pad: 'light', bell: 0.15,
    bt: { bpm: 120, lead: 'flute', lead2: 'koto', acc: 'flowing', arp: 'harp', bass: 'drive', drum: 'b_east', form: [F('A', 'lead', 0.85, { echo: 'koto' }), F('B', 'lead2', 0.9, { duet: 'flute' })] },
    form: [F('intro', 0, 0.4, { n: 2 }), F('A', 'lead', 0.6), F('B', 'lead2', 0.7, { echo: 'harp' }), F('A2', 'lead', 0.75, { duet: 'shakuhachi' }), F('C', 'shakuhachi', 0.6), F('A', 'lead', 0.7)] },
  // 북령: 눈 덮인 고개의 애가 — 느린 피아노 독주, 첼로가 낮게 받아 부르고, 대금이 멀리서 겹친다
  north: { tonic: 57, mode: 'minor', bpm: 54, meter: 4, rhy: 'lament', lead: 'piano', lead2: 'cello', counter: 'shakuhachi', arp: 'piano', acc: 'sparse', bass: 'long', drum: null, pad: 'light', bell: 0.12,
    bt: { bpm: 72, mode: 'minor', lead: 'piano', lead2: 'cello', counter: 'shakuhachi', arp: 'piano', acc: 'sparse', bass: 'long', drum: 'b_north', pad: 'swell', bell: 0.7, rhy: 'lament', form: [F('A', 'lead', 0.9, { oct: -7 }), F('B', 'lead2', 0.95, { oct: -14, duet: 'shakuhachi' })] },
    form: [F('intro', 0, 0.3, { n: 3 }), F('A', 'lead', 0.55), F('A2', 'lead2', 0.6, { oct: -14 }), F('B', 'lead', 0.78, { duet: 'shakuhachi' }), F('A3', 'lead', 0.5), F('bridge', 0, 0.25, { n: 2 })] },
  // 남명: 불씨 고개의 신명 — 빠른 장단, 대금·플루트가 겹쳐 내달리고 가야금이 16분음으로 굴린다
  south: { tonic: 60, mode: 'major', bpm: 124, meter: 4, rhy: 'fast', lead: 'shakuhachi', lead2: 'koto', counter: 'koto', arp: 'koto', acc: 'fast', bass: 'drive', drum: 'groove', pad: 'light', bell: 0.08,
    bt: { bpm: 136, lead: 'shakuhachi', lead2: 'flute', acc: 'fast', arp: 'koto', bass: 'drive', drum: 'b_south', form: [F('A', 'lead', 0.85), F('B', 'lead2', 0.95, { duet: 'shakuhachi' })] },
    form: [F('drop', 0, 0.55, { n: 2 }), F('A', 'lead', 0.7, { duet: 'flute' }), F('A2', 'lead', 0.78, { echo: 'koto' }), F('B', 'lead2', 0.85, { duet: 'flute' }), F('drop', 0, 0.6, { n: 2 }), F('A', 'flute', 0.8, { duet: 'shakuhachi' })] },
  // 변경: 성벽 너머의 행군 — 현악 8분음 받침과 북 행진, 해금 주제 위로 플루트가 겹친다(해금을 주로 쓰는 곳)
  frontier: { tonic: 64, mode: 'minor', bpm: 88, meter: 4, rhy: 'calm', lead: 'fiddle', lead2: 'flute', counter: 'shakuhachi', arp: 'harp', acc: 'ostinato', accIns: 'strings', bass: 'march', drum: 'march', pad: 'swell', bell: 0.05,
    bt: { bpm: 112, lead: 'fiddle', lead2: 'strings', acc: 'ostinato', accIns: 'strings', bass: 'march', drum: 'b_frontier', pad: 'swell', form: [F('A', 'lead', 0.85), F('B', 'lead2', 0.95, { oct: -7, trem: true })] },
    form: [F('drop', 0, 0.5, { n: 2 }), F('A', 'lead', 0.65), F('A2', 'lead', 0.78, { duet: 'shakuhachi' }), F('B', 'lead2', 0.92, { duet: 'fiddle', trem: true }), F('A3', 'lead', 0.7), F('bridge', 0, 0.4, { n: 1 })] },
  // 지하: 무너진 굴의 음산함 — 아주 느리게, 대금 위로 낮은 피아노가 드문드문 어긋난 음을 짚고 심장 박동 같은 북
  underworld: { tonic: 61, mode: 'phryg', bpm: 48, meter: 4, rhy: 'lament', lead: 'shakuhachi', lead2: 'piano', counter: 'harp', arp: 'piano', acc: 'eerie', bass: 'pedal', drum: 'heart', pad: 'open', bell: 0.4,
    bt: { bpm: 96, lead: 'shakuhachi', lead2: 'piano', acc: 'eerie', arp: 'piano', bass: 'drive', drum: 'b_underworld', pad: 'open', form: [F('A', 'lead', 0.85), F('B', 'lead2', 0.95, { oct: -7 })] },
    form: [F('intro', 0, 0.3, { n: 2 }), F('A', 'lead', 0.5), F('drop', 0, 0.35, { n: 2 }), F('A2', 'lead', 0.55, { echo: 'harp' }), F('B', 'lead2', 0.65, { oct: -7 }), F('A3', 'lead', 0.45)] },
  // 천문: 별을 보는 높은 대 — 피아노 주제 위로 하프가 두 옥타브를 넘나들며 반짝이고, 플루트와 종, 북 없이 맑게
  heavenward: { tonic: 65, mode: 'major', bpm: 66, meter: 4, rhy: 'calm', lead: 'piano', lead2: 'flute', counter: 'harp', arp: 'harp', acc: 'shimmer', bass: 'long', drum: null, pad: 'light', bell: 0.55,
    bt: { bpm: 104, lead: 'piano', lead2: 'flute', acc: 'shimmer', arp: 'harp', bass: 'half', drum: 'b_heaven', bell: 0.6, form: [F('A', 'lead', 0.85), F('B', 'lead2', 0.95, { echo: 'bell' })] },
    form: [F('intro', 0, 0.35, { n: 2 }), F('A', 'lead', 0.5), F('A2', 'lead', 0.62, { echo: 'bell' }), F('B', 'lead2', 0.7, { duet: 'shakuhachi' }), F('A3', 'lead', 0.5)] },
  // 심연: 검은 물이 휘도는 곳 — 무거운 북과 몰아치는 첼로 8분음, 낮은 피아노가 주제를 두드리고 절정에서 해금이 울부짖는다
  abyss: { tonic: 59, mode: 'phryg', bpm: 84, meter: 4, rhy: 'calm', lead: 'piano', lead2: 'fiddle', counter: 'koto', arp: 'koto', acc: 'ostinato', bass: 'drive', drum: 'heavy', drumIn: ['drop', 'A2', 'B', 'A3'], pad: 'open', bell: 0.15,
    bt: { bpm: 118, lead: 'piano', lead2: 'cello', acc: 'ostinato', arp: 'koto', bass: 'drive', drum: 'b_abyss', pad: 'open', form: [F('A', 'lead', 0.9, { oct: -7 }), F('B', 'lead2', 0.95, { oct: -14, trem: true })] },
    form: [F('intro', 0, 0.4, { n: 2 }), F('A', 'lead', 0.65, { oct: -7 }), F('drop', 0, 0.6, { n: 2 }), F('B', 'lead2', 0.8, { duet: 'shakuhachi', trem: true }), F('A2', 'lead', 0.75, { oct: -7, echo: 'koto' }), F('A3', 'lead', 0.6, { oct: -7 })] },
  // 귀허도: 망자를 배웅하는 느린 3박 노래 — 낮은 대금이 이끌고 첼로가 받으며, 쨍한 고음 악기 없이 하프는 낮게, 종은 드물게
  gwiheo: { tonic: 55, mode: 'phryg', bpm: 50, meter: 3, rhy: 'slow3', lead: 'shakuhachi', lead2: 'cello', counter: 'cello', arp: 'harp', acc: 'slow3', bass: 'waltz', drum: 'heart', drumIn: ['B', 'A3'], pad: 'light', bell: 0.15,
    bt: { bpm: 92, lead: 'shakuhachi', lead2: 'cello', counter: 'cello', acc: 'battle', arp: 'harp', bass: 'battle', drum: 'b_gwiheo', bell: 0.15, form: [F('A', 'lead', 0.9, { duet: 'cello' }), F('B', 'lead2', 0.95, { oct: -14, duet: 'shakuhachi' })] },
    form: [F('intro', 0, 0.3, { n: 2 }), F('A', 'lead', 0.55), F('A2', 'lead2', 0.6, { oct: -14, echo: 'shakuhachi' }), F('B', 'lead', 0.7, { duet: 'cello' }), F('A3', 'lead', 0.5)] },
};
let playing = false, phraseTimer = null, song = null, songKey = '', barNo = 0, nextAt = 0, loopNo = 0, held = false;
let droneKey = ''; // 지역이 바뀌었는지 보는 열쇠(예전 이름을 그대로 쓴다)

// 전투: 그 영역의 조성을 두고 영역마다 정한 편성(battle)으로 4박 장단을 몰아친다
function battleOf(p) {
  const b = p.bt || {};
  return { ...p, battle: true, meter: 4, rhy: 'battle', acc: 'battle', bass: 'battle', drumIn: null, pad: 'light', accIns: null, counter: p.counter, ...b,
    bpm: Math.min(140, b.bpm || Math.max(Math.round(p.bpm * 1.4), 100)), form: b.form || [F('A', 'lead', 0.85), F('B', 'lead2', 0.95)] };
}
function profile(battle = scene.battle) {
  let p = { ...(PROFILES[scene.territory] || PROFILES.capital) };
  if (battle) p = battleOf(p);
  if (scene.safe && !battle) { p.bpm *= 0.94; p.drum = null; p.safe = true; }
  if (env.phase === 'night') p.bpm *= 0.96;
  return p;
}
const insOf = p => [...new Set([p.lead, p.lead2, p.counter, p.arp, p.accIns, 'cello', 'strings', 'bell', p.drum ? 'taiko' : null,
  ...p.form.flatMap(f => [f.ins && INS[f.ins] ? f.ins : null, f.echo, f.duet, f.trem ? 'koto' : null])].filter(k => k && INS[k]))];

// 정해진 씨앗으로 늘 같은 결과를 낸다
function seeded(str) { let h = 2166136261; for (const ch of str) h = Math.imul(h ^ ch.charCodeAt(0), 16777619); return () => { h = Math.imul(h ^ (h >>> 15), 2246822507) ^ Math.imul(h ^ (h >>> 13), 3266489909); h >>>= 0; return h / 4294967296; }; }

function makeSong(p, key, loop) {
  const M = MODES[p.mode], pent = PENT[p.mode], prog0 = PROG[p.mode === 'major' ? 'major' : 'minor'];
  // 프리지안의 V(감화음)는 거칠어 ♭II(프리지안 맺음)로 바꾼다
  const prog = p.mode === 'phryg' ? Object.fromEntries(Object.entries(prog0).map(([k, v]) => [k, v.map(c => c.map(x => (x === 4 ? 1 : x)))])) : prog0;
  const theme = seeded(key), vary = seeded(`${key}:${loop}`);
  const pick = (r, a) => a[Math.floor(r() * a.length)];
  const mod7 = d => ((d % 7) + 7) % 7;
  const midi = (d, base = p.tonic) => base + 12 * Math.floor(d / 7) + M[mod7(d)];
  const isPent = d => pent.includes(mod7(d));
  const chordTones = c => [mod7(c), mod7(c + 2), mod7(c + 4)];
  const LO = 2, HI = 13, RS = RHY[p.rhy] || RHY.calm, beats = p.meter;
  // 프레이즈(4마디): 마디마다 [[박, 음계 칸, 길이, 꾸밈]]
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
      // 1박 넘게 머무는 음과 센박 음은 화음 음으로(짧은 경과음만 화음 밖), 오음은 고집하지 않는다
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
  // 변주: 마지막 음이 아닌 음 한두 개를 한 칸 옮기고, 긴 음 하나를 둘로 나누고, 꾸밈을 바꾼다
  const variant = (ph, r) => {
    const bars = ph.bars.map(b => b.map(n => [...n]));
    const flat = bars.flatMap((b, bi) => b.map((n, ni) => [bi, ni])).slice(0, -1);
    // 짧은 음만 옮겨(긴 음은 화음 음이라 그대로) 어울림을 지킨다
    for (let k = 0; k < 2 && flat.length; k++) { const [bi, ni] = pick(r, flat); const n = bars[bi][ni]; if (n[2] < 1) n[1] = Math.max(LO, Math.min(HI, n[1] + (r() < 0.5 ? 1 : -1))); }
    const longs = flat.filter(([bi, ni]) => bars[bi][ni][2] >= 2);
    if (longs.length && r() < 0.6) { const [bi, ni] = pick(r, longs); const n = bars[bi][ni]; const nb = [n[0] + n[2] - 0.5, n[1] + (r() < 0.5 ? 1 : -1), 0.5, '']; n[2] -= 0.5; bars[bi].splice(ni + 1, 0, nb); }
    bars.forEach(b => b.forEach(n => { if (n[2] >= 1.5) n[3] = r() < 0.3 ? 'slide' : r() < 0.2 ? 'grace' : ''; }));
    return { ...ph, bars };
  };
  const period = (r, o = {}) => {
    const c1 = o.c1 || pick(r, prog.ante), c2 = o.c2 || pick(r, prog.cons);
    const a = phrase(r, c1, { start: o.start, end: o.end1 ?? pick(r, [4, 2, 1]), peak: o.peak });
    // 뒷 프레이즈는 앞 프레이즈의 첫 마디 리듬을 이어받아(대구) 기억에 남게 하고, 으뜸음으로 맺는다
    const b = phrase(r, c2, { start: o.start2 ?? a.bars[0][0]?.[1], end: o.end2 ?? 7, peak: o.peak, rhythm: [a.rhythm[0], pick(r, RS.mid), pick(r, RS.move), pick(r, RS.end)] });
    return [a, b];
  };

  const A = period(theme);
  const src = {
    A, A2: A.map(ph => variant(ph, vary)),
    B: p.battle ? period(vary, { start: 9, peak: 3 }) : period(vary, { c1: pick(vary, prog.bA), c2: pick(vary, prog.bC), start: 9 + Math.floor(vary() * 2), peak: 3, end1: 6, end2: 4 }),
    // C: 낮은 음역에서 다른 빛깔로(받는 악기가 부름)
    C: period(vary, { c1: pick(vary, prog.bA), start: 3, peak: 2, end1: 4 }),
    A3: [A[0], variant(A[1], vary)],
  };
  const bars = [];
  let loopStart = 0, seenMain = false;
  p.form.forEach(f => {
    if (f.n) {
      // 도입·잇는 마디·북 마디: 선율 없이 반주만(도입 끝 마디에 가야금이 주제를 살짝 비춤)
      for (let i = 0; i < f.n; i++) bars.push({ pi: i, last: i === f.n - 1, sec: f.s, chord: f.s === 'bridge' && i === f.n - 1 ? (p.mode === 'major' ? 4 : 6) : A[0].chords[f.s === 'bridge' ? 3 : i % 4], mel: [], inten: f.v + i * 0.04, hint: f.s === 'intro' && i === f.n - 1 ? A[0].bars[0] : null });
      if (!seenMain) loopStart = bars.length;
      return;
    }
    seenMain = true;
    const lead = p[f.ins] || f.ins;
    src[f.s].forEach((ph, pj) => ph.bars.forEach((b, i) => bars.push({ sec: f.s, chord: ph.chords[i], mel: b, lead, oct: f.oct || 0, inten: f.v, echo: f.echo, duet: f.duet, trem: f.trem, last: i === 3, pi: i, pj })));
  });
  // 처음 도입은 한 번만, 되풀이는 첫 선율 단락부터
  if (loopStart === bars.length) loopStart = 0;
  return { bars, loopStart: p.battle ? 0 : loopStart, midi, mod7, chordTones };
}

// 프레이즈 안 마디 자리(0~3)마다 세기: 오르다 셋째 마디에서 가장 크고 맺는 마디에서 가라앉는다. 대구(뒷 프레이즈)는 조금 더 크게
const DYN = [0.84, 0.95, 1.08, 0.86];
const LEAD_GAIN = { strings: 1.9, cello: 1.05, piano: 1.1 };
// 마디 하나를 연주한다
function playBar(p, S, bar, t, beat) {
  const { midi, mod7, chordTones } = S, mb = p.meter;
  const dyn = (DYN[bar.pi ?? 0] ?? 1) * (bar.pj ? 1.04 : 1);
  const inten = bar.inten * (p.safe ? 0.85 : 1) * dyn;
  const human = () => (Math.random() - 0.5) * 0.02, hv = v => v * (0.9 + Math.random() * 0.2);
  const root = bar.chord, tones = chordTones(root), tri = [root, root + 2, root + 4];
  // 화음 음 높이: 단조의 딸림화음(V)에서는 셋째 음(이끎음)을 반음 올린다
  const lead7 = p.mode === 'minor' && mod7(root) === 4;
  const hm = (d, base) => midi(d, base) + (lead7 && mod7(d) === 6 ? 1 : 0);
  const near = d => [d, d - 1, d + 1, d - 2, d + 2].find(x => tones.includes(mod7(x))) ?? d;
  const melEnd = bar.mel.length ? bar.mel[bar.mel.length - 1] : null;
  const oct = bar.oct || 0, lg = LEAD_GAIN[bar.lead] || 1;
  const sus = INS[bar.lead]?.sus;
  // 주선율(+ 화음 음으로 아래에서 겹치는 duet, 한 박 늦은 메아리 echo)
  bar.mel.forEach(([pos, d, len, orn], i) => {
    const m = hm(d + oct), prev = bar.mel[i - 1], at = t + pos * beat + human();
    // 마디 첫 박은 조금 세게, 여린박은 조금 여리게
    const acc = pos === 0 ? 1.08 : pos % 1 ? 0.88 : 1;
    playNote(bar.lead, m, at, len * beat * 0.98, hv((0.95 * inten + 0.05) * acc * lg),
      { slide: orn === 'slide' ? (bar.lead === 'fiddle' ? 2 : 1) : (bar.lead === 'fiddle' && prev && Math.abs(prev[1] - d) === 1 && Math.random() < 0.3 ? 1 : 0), grace: orn === 'grace' ? 2 : 0,
        att: bar.lead === 'strings' ? 0.12 : undefined, expr: sus && len * beat > 0.45, vib: sus && len * beat > 0.9 && bar.lead !== 'strings' });
    if (bar.duet && bar.duet !== bar.lead && len >= 0.5) {
      // 화음 음 가운데 3~6도 아래 것으로(늘 어울린다)
      const dd = [2, 3, 4, 5].map(x => d - x).find(x => tones.includes(mod7(x)));
      if (dd != null) playNote(bar.duet, hm(dd + oct + (bar.duet === 'strings' && oct === 0 ? -7 : 0)), at + 0.012, len * beat * 0.98, hv(0.5 * inten * (LEAD_GAIN[bar.duet] || 1)), { expr: true, att: bar.duet === 'strings' ? 0.15 : undefined });
    }
    if (bar.echo && pos + 1 < mb && tones.includes(mod7(d))) playNote(bar.echo, hm(d - 7), t + (pos + 1) * beat + human(), Math.min(len, 1.5) * beat, hv(0.36 * inten), { expr: true });
  });
  // 받아치는 선율: 주선율이 길게 머무는 동안 받는 악기가 주제 조각을 낮게(이 마디 화음에 맞춰) 받아 부른다
  const answer = !bar.echo && !p.battle && melEnd && melEnd[2] >= 1.5 && melEnd[0] <= mb - 1.5 && (bar.sec !== 'A' || (bar.last && Math.random() < 0.5));
  if (answer) {
    const src = (S.bars.find(b => b.sec === 'A')?.mel || []).slice(0, 3);
    let at = melEnd[0] + 0.5;
    src.forEach(([, d], i) => { if (at < mb) { const dn = i === src.length - 1 ? near(d) : d; playNote(p.counter, hm(dn - 7), t + at * beat + human(), (i === src.length - 1 ? 1.5 : 0.5) * beat, hv(0.48 * inten), { expr: true }); at += i === src.length - 1 ? 1.5 : 0.5; } });
  }
  // 도입의 가야금 암시
  if (bar.hint) bar.hint.forEach(([pos, d, len]) => playNote(p.counter, hm(near(d) - 7), t + pos * beat, len * beat, 0.4, { expr: true }));
  // 반주
  const accIns = p.accIns || p.arp, accBase = d => hm(d - (accIns === 'strings' ? 14 : 7), p.tonic);
  const pat = (ACC[p.acc] || ACC.calm).filter(([pos]) => pos < mb);
  const accVol = (answer ? 0.5 : 1) * (['intro', 'bridge', 'drop'].includes(bar.sec) ? 0.55 : 0.4) * inten * (accIns === 'strings' ? 0.9 : 1);
  const accLen = p.acc === 'sparse' || p.acc === 'eerie' || p.acc === 'slow3' ? 2 : p.acc === 'fast' ? 0.3 : p.acc === 'ostinato' || p.acc === 'battle' || p.acc === 'flowing' || p.acc === 'shimmer' || p.acc === 'dance3' ? 0.6 : 1;
  pat.forEach(([pos, step, v], i) => playNote(accIns, accBase(root + step), t + pos * beat + human(), accLen * beat, hv(accVol * v * (1 - 0.15 * (i / Math.max(1, pat.length - 1))))));
  // 가야금 떨림(절정 단락): 마디 안에서 부풀었다 잦아든다
  if (bar.trem) { const n = mb * 4; for (let k = 0; k < n; k++) playNote('koto', hm(tri[k % 3]), t + k * beat / 4, beat / 2, hv((k % 4 ? 0.16 : 0.28) * inten * (0.7 + 0.5 * Math.sin(Math.PI * k / n)))); }
  // 저음(첼로)
  const bass = midi(root - 14, p.tonic), five = midi(root + 4 - 14, p.tonic), bv = 0.75 * inten + 0.05;
  if (bar.sec !== 'intro' || p.bass === 'pedal') {
    switch (p.bass) {
      case 'battle': [[0, 1], [1.5, .7], [2, .9], [3, .7]].forEach(([pos, v]) => playNote('cello', bass, t + pos * beat, 0.45 * beat, hv(0.6 * v))); break;
      case 'drive': for (let k = 0; k < mb * 2; k++) playNote('cello', k === 4 ? five : bass, t + k * beat / 2, 0.42 * beat, hv((k % 2 ? 0.42 : 0.68) * (0.6 + inten * 0.5))); break;
      case 'march': [[0, bass, 1], [1.5, bass, .6], [2, five, .85], [3, bass, .6]].forEach(([pos, m, v]) => playNote('cello', m, t + pos * beat, 0.8 * beat, hv(v * bv))); break;
      case 'waltz': playNote('cello', bass, t, 0.9 * beat, hv(bv)); break;
      case 'pedal': playNote('cello', midi(-14, p.tonic), t, mb * beat, hv(0.6 * inten + 0.1), { swell: true }); break;
      case 'half': playNote('cello', bass, t, 2 * beat, hv(bv), { expr: true }); playNote('cello', five, t + 2 * beat, (mb - 2) * beat, hv(0.85 * bv), { expr: true }); break;
      default: playNote('cello', bass, t, mb * beat, hv(bv), { swell: true });
    }
  }
  // 바닥 화음(현악): 마디 안에서 천천히 부풀었다 잦아든다. open = 뿌리·5도·옥타브(어두운 곳)
  const padOn = p.pad === 'sustain' || p.pad === 'open' || p.battle ? true
    : p.pad === 'light' ? bar.sec === 'B' || bar.sec === 'C'
    : ['A2', 'B', 'C'].includes(bar.sec) || (bar.sec === 'A3' && !bar.last);
  if (padOn && bar.sec !== 'drop' && !(bar.lead === 'strings' && bar.mel.length)) {
    const pv = (bar.sec === 'B' ? 0.6 : p.pad === 'sustain' ? 0.32 : 0.44) * inten;
    const notes = p.pad === 'open' ? [root, root + 4, root + 7] : tri;
    notes.forEach(d => playNote('strings', hm(d - 7, p.tonic), t + 0.05, mb * beat, hv(pv), { swell: true }));
  }
  // 종: 단락 첫머리에 가끔(전투의 진혼곡은 마디 첫 박마다 낮게 울린다)
  if (p.bell > 0 && (bar.mel.length || bar.sec === 'intro') && Math.random() < p.bell * (bar.sec === 'B' ? 1.4 : 0.6) && (bar.sec === 'intro' || barNo % (p.battle ? 2 : 4) === 0)) playNote('bell', hm(root + 7, p.tonic), t + (p.battle ? 0 : Math.min(2, mb - 1) * beat), 2 * beat, 0.55);
  // 큰북: 기본·변형(짝수 마디)·몰아치기(프레이즈 끝)
  if (p.drum && (!p.drumIn || p.drumIn.includes(bar.sec) || bar.sec === 'drop')) {
    const set = DRUM[p.drum]; if (set) {
      const hits = (bar.last ? set.fill : barNo % 2 ? set.alt : set.main).filter(([pos]) => pos < mb);
      const dv = p.battle ? 0.95 : 0.6 + 0.35 * inten;
      if (p.drum !== 'pulse' || barNo % 2 === 0 || bar.last) hits.forEach(([pos, v, k]) => playDrum(t + pos * beat + human() * 0.5, hv(v * dv), k));
    }
  }
}

function phrase() {
  if (!playing || !ctx || away) return;
  // 컷씬이 제 곡을 트는 동안은 쉬고 기다린다
  if (held) { phraseTimer = setTimeout(phrase, 1000); return; }
  const p = profile(), need = insOf(p), key = `${scene.territory || 'capital'}:${p.mode}:${p.battle ? 'battle' : 'field'}`;
  // 악기를 다 받기 전에는 기다린다
  if (need.some(k => !buffers[k])) { need.forEach(loadIns); phraseTimer = setTimeout(phrase, 400); return; }
  if (key !== songKey || !song) { song = makeSong(p, key, 0); songKey = key; barNo = 0; loopNo = 0; }
  if (barNo >= song.bars.length) { loopNo++; const s2 = makeSong(p, key, loopNo); song = s2; barNo = s2.loopStart; }
  const beat = 60 / p.bpm, barDur = p.meter * beat;
  if (nextAt < now() + 0.05) nextAt = now() + 0.15;
  const t = nextAt;
  playBar(p, song, song.bars[barNo], t, beat);
  barNo++; nextAt = t + barDur;
  // 다음 마디를 미리(0.35초 앞서) 예약해 마디 사이가 끊기지 않게 한다
  phraseTimer = setTimeout(phrase, Math.max(50, (nextAt - now() - 0.35) * 1000));
}
// 지역·전투가 바뀌면 필요한 악기를 미리 받고 쓰지 않는 악기는 내려놓는다(이름은 예전 지속음 함수 그대로)
function updateDrone() {
  if (!ctx) return;
  const key = `${scene.territory}:${scene.battle}`;
  if (droneKey === key) return;
  droneKey = key;
  if (!playing) return;
  // 전투에 들어가고 나올 때도 쓸 악기를 함께 남겨 둔다
  const both = [...new Set([...insOf(profile(false)), ...insOf(profile(true))])];
  keepOnly(both); both.forEach(loadIns);
}
function startMusic() { if (playing || !ensureCtx()) return; playing = true; ctx.resume?.(); droneKey = ''; updateDrone(); nextAt = 0; phraseTimer = setTimeout(phrase, 300); }
function stopMusic() { playing = false; clearTimeout(phraseTimer); droneKey = ''; }

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
  const under = scene.territory === 'underworld' || scene.territory === 'abyss' || scene.territory === 'gwiheo';
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
  const w = env.weather, under = scene.territory === 'underworld' || scene.territory === 'abyss' || scene.territory === 'gwiheo';
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
  // 컷씬이 제 곡을 트는 동안 배경음악을 쉰다(cutscene.js가 알림)
  window.addEventListener('yh-cutscene', e => { held = !!e.detail; });
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
