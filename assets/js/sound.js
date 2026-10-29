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
// 가야금 → 고토, 대금 → 샤쿠하치·플루트, 해금 → 피들로 대신하고, 첼로·현악·하프·종·북을 받침으로 쓴다.
const SLOT = 3.2;
const INS = {
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

// 한 음 내기: t초에 midi 높이로 dur초 동안. o.slide = 아래에서 미끄러져 올라올 반음 수, o.grace = 짧게 스칠 윗음(반음)
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
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(peak, t + I.att);
  g.gain.setValueAtTime(peak, Math.max(t + I.att, t + ring - 0.02)); g.gain.exponentialRampToValueAtTime(0.0001, end);
  const seg = (start, offset, length, fadeIn, fadeOut, first) => {
    const s = ctx.createBufferSource(), sg = ctx.createGain();
    s.buffer = buf; s.playbackRate.setValueAtTime(rate, start);
    if (first && o.slide) { s.playbackRate.setValueAtTime(rate * Math.pow(2, -o.slide / 12), start); s.playbackRate.linearRampToValueAtTime(rate, start + 0.14); }
    sg.gain.setValueAtTime(fadeIn ? 0.0001 : 1, start); if (fadeIn) sg.gain.linearRampToValueAtTime(1, start + fadeIn);
    if (fadeOut) { sg.gain.setValueAtTime(1, start + length - fadeOut); sg.gain.linearRampToValueAtTime(0.0001, start + length); }
    // length는 실제 시간(초), 샘플에서 쓰는 길이는 length × rate
    s.connect(sg); sg.connect(g); s.start(start, offset, length * rate + 0.02); s.stop(start + length + 0.05);
  };
  const need = end - t, first = Math.min(need, (I.len - 0.15) / rate);
  if (!I.sus || need <= first) seg(t, off, Math.min(need, I.len / rate), 0, 0, true);
  else {
    // 샘플 길이를 넘는 긴 음: 0.9~2.9초 구간을 겹쳐 이어 붙인다(0.35초 겹침)
    const L = 2.0 / rate, X = 0.35;
    seg(t, off, first, 0, X, true);
    for (let at = t + first - X; at < end; at += L - X) seg(at, off + 0.9, Math.min(L, end - at + 0.05), X, X, false);
  }
  if (o.grace) playNote(k, midi + o.grace, t - 0.09, 0.08, vel * 0.7);
}

/* ── 곡조 ─────────────────────────────────────────────── */
// 방향(2026-10-28 사용자 레퍼런스 분석): 서정적이고 고전적인 동양풍 연주곡. 단조(계면) 위주, 타악 거의 없음(전체의 4~6%),
// 따뜻하고 어두운 음색(5kHz 위 거의 없음), 낮은 받침이 단단하고, 선율은 1~2음 이동 위주에 가끔 도약, 조용히 시작해 부풀었다 가라앉는다.
// 곡: 도입 2마디 → A(주제 8마디) → A′(주제 변주, 가야금이 받아침) → B(높은 음역·현악이 부푸는 절정) → A″(주제 회귀, 잦아듦) → 잇는 2마디 → A로 돌아가 루프.
// 되풀이할 때마다 A′·B·잇는 마디를 새로 짓고 꾸밈을 바꿔 같은 곡이 기계적으로 반복되지 않게 하고, 주제(A)는 지켜 기억에 남게 한다.
// 악기 역할: 주선율(대금·해금 대용) · 받아치는 선율(가야금) · 분산화음(하프·가야금, 절제) · 저음(첼로) · 바닥 화음(현악) · 빛깔(종) · 북(변경·심연·전투만).
const MODES = { minor: [0, 2, 3, 5, 7, 8, 10], major: [0, 2, 4, 5, 7, 9, 11], phryg: [0, 1, 3, 5, 7, 8, 10] };
const PENT = { minor: [0, 2, 3, 4, 6], major: [0, 1, 2, 4, 5], phryg: [0, 1, 3, 4, 5] }; // 오음(음계 칸 번호)
const PROG = {
  minor: { ante: [[0, 5, 3, 4], [0, 3, 5, 6], [0, 6, 5, 4], [5, 6, 0, 4], [0, 2, 3, 6]], cons: [[5, 6, 0, 0], [3, 4, 0, 0], [0, 5, 6, 0], [5, 3, 4, 0], [2, 5, 6, 0]],
           bA: [[5, 6, 2, 5], [3, 4, 5, 6], [5, 3, 6, 2]], bC: [[3, 6, 2, 4], [5, 3, 4, 4], [3, 5, 6, 6]] },
  major: { ante: [[0, 3, 4, 4], [0, 5, 3, 4], [0, 2, 3, 4], [5, 3, 1, 4]], cons: [[0, 3, 4, 0], [5, 3, 4, 0], [3, 4, 0, 0], [1, 4, 0, 0]],
           bA: [[5, 2, 3, 0], [3, 4, 2, 5], [5, 3, 0, 4]], bC: [[1, 4, 2, 5], [3, 1, 4, 4], [5, 1, 4, 4]] },
};
const RHY = {
  move: [[2, 1, 1], [1.5, 0.5, 2], [1, 1, 2], [1, 0.5, 0.5, 2], [0.5, 0.5, 1, 2], [2.5, 0.5, 1], [1, 1, 1, 1], ['r1', 1, 1, 1], ['r0.5', 0.5, 1, 2]],
  mid: [[3, 1], [2, 2], [2, 1, 1], [1.5, 0.5, 2], [2.5, 0.5, 1]],
  end: [[4], [3, 1], [2, 2], [1, 3]],
  battle: [[1, 0.5, 0.5, 1, 1], [0.5, 0.5, 1, 2], [1, 1, 1, 1], [1.5, 0.5, 1, 1], [0.5, 0.5, 0.5, 0.5, 2], [1, 1, 2]],
};
// 영역마다 조성·빠르기·악기 짜임. tonic = 주선율 으뜸음(MIDI)
const PROFILES = {
  capital:    { tonic: 62, mode: 'minor', bpm: 70, lead: 'shakuhachi', lead2: 'fiddle', counter: 'koto', arp: 'harp', style: 'calm', bell: 0.2, taiko: 0 },
  east:       { tonic: 64, mode: 'major', bpm: 66, lead: 'flute', lead2: 'shakuhachi', counter: 'harp', arp: 'koto', style: 'calm', bell: 0.25, taiko: 0 },
  north:      { tonic: 57, mode: 'minor', bpm: 62, lead: 'fiddle', lead2: 'shakuhachi', counter: 'koto', arp: 'harp', style: 'calm', bell: 0.1, taiko: 0 },
  south:      { tonic: 60, mode: 'major', bpm: 78, lead: 'shakuhachi', lead2: 'flute', counter: 'koto', arp: 'koto', style: 'flowing', bell: 0.1, taiko: 0 },
  frontier:   { tonic: 64, mode: 'minor', bpm: 74, lead: 'fiddle', lead2: 'shakuhachi', counter: 'koto', arp: 'harp', style: 'epic', bell: 0, taiko: 0.5 },
  underworld: { tonic: 61, mode: 'phryg', bpm: 56, lead: 'shakuhachi', lead2: 'fiddle', counter: 'harp', arp: 'harp', style: 'sparse', bell: 0.35, taiko: 0 },
  heavenward: { tonic: 65, mode: 'major', bpm: 60, lead: 'flute', lead2: 'shakuhachi', counter: 'harp', arp: 'harp', style: 'sparse', bell: 0.5, taiko: 0 },
  abyss:      { tonic: 59, mode: 'phryg', bpm: 64, lead: 'fiddle', lead2: 'shakuhachi', counter: 'koto', arp: 'koto', style: 'sparse', bell: 0.15, taiko: 0.35 },
  // 귀허도: 느리고 낮은 해금·대금, 종을 많이 쓰는 배웅 노래 느낌(G 프리지안)
  gwiheo:     { tonic: 55, mode: 'phryg', bpm: 52, lead: 'fiddle', lead2: 'shakuhachi', counter: 'harp', arp: 'koto', style: 'sparse', bell: 0.45, taiko: 0.2 },
};
let playing = false, phraseTimer = null, song = null, songKey = '', barNo = 0, nextAt = 0, loopNo = 0;
let droneKey = ''; // 지역이 바뀌었는지 보는 열쇠(예전 이름을 그대로 쓴다)

function profile() {
  const p = { ...(PROFILES[scene.territory] || PROFILES.capital) };
  if (scene.safe) { p.bpm *= 0.94; p.taiko = 0; p.safe = true; }
  if (scene.battle) { p.battle = true; p.bpm = Math.max(Math.round(p.bpm * 1.45), 96); p.taiko = Math.max(p.taiko, 0.7); p.lead = p.mode === 'major' ? 'shakuhachi' : 'fiddle'; p.arp = 'koto'; }
  if (env.phase === 'night') p.bpm *= 0.96;
  return p;
}
const insOf = p => [...new Set([p.lead, p.lead2, p.counter, p.arp, 'cello', 'strings', p.bell > 0 ? 'bell' : null, p.taiko > 0 ? 'taiko' : null].filter(Boolean))];

// 정해진 씨앗으로 늘 같은 결과를 낸다
function seeded(str) { let h = 2166136261; for (const ch of str) h = Math.imul(h ^ ch.charCodeAt(0), 16777619); return () => { h = Math.imul(h ^ (h >>> 15), 2246822507) ^ Math.imul(h ^ (h >>> 13), 3266489909); h >>>= 0; return h / 4294967296; }; }

function makeSong(p, key, loop) {
  const M = MODES[p.mode], pent = PENT[p.mode], prog = PROG[p.mode === 'major' ? 'major' : 'minor'];
  const theme = seeded(key), vary = seeded(`${key}:${loop}`);
  const pick = (r, a) => a[Math.floor(r() * a.length)];
  const mod7 = d => ((d % 7) + 7) % 7;
  const midi = (d, base = p.tonic) => base + 12 * Math.floor(d / 7) + M[mod7(d)];
  const isPent = d => pent.includes(mod7(d));
  const chordTones = c => [mod7(c), mod7(c + 2), mod7(c + 4)];
  const LO = 2, HI = 13;
  // 프레이즈(4마디): 마디마다 [[박, 음계 칸|null(쉼), 길이, 꾸밈]]
  const phrase = (r, chords, o = {}) => {
    const R = k => pick(r, p.battle ? RHY.battle : RHY[k]);
    const rh = o.rhythm || [R('move'), R('mid'), R('move'), R('end')];
    const slots = []; rh.forEach((bar, bi) => { let pos = 0; bar.forEach(x => { if (typeof x === 'string') { pos += Number(x.slice(1)); return; } slots.push({ bi, pos, len: x }); pos += x; }); });
    const N = slots.length, start = o.start ?? pick(r, [5, 6, 7, 7, 8, 9]), peak = o.peak ?? (2 + Math.floor(r() * 3));
    let cur = start;
    const bars = [[], [], [], []];
    slots.forEach((s, i) => {
      const target = start + Math.round(peak * Math.sin(Math.PI * Math.min(1, i / Math.max(1, N - 1)) * 0.95));
      if (i > 0) {
        const dir = Math.sign(target - cur) || (r() < 0.5 ? 1 : -1), x = r();
        const size = x < 0.12 ? 0 : x < 0.68 ? 1 : x < 0.9 ? 2 : 3 + Math.floor(r() * 2);
        cur += (r() < 0.82 ? dir : -dir) * size;
      }
      const chord = chords[s.bi];
      // 센박의 긴 음은 화음 음으로, 긴 음은 오음으로
      if ((s.pos === 0 || s.pos === 2) && s.len >= 1 && !chordTones(chord).includes(mod7(cur)) && r() < 0.75) {
        const up = target >= cur ? 1 : -1, c = [up, -up, 2 * up, -2 * up].map(x => cur + x).find(d => chordTones(chord).includes(mod7(d)));
        if (c != null) cur = c;
      }
      if (s.len >= 1.5 && !isPent(cur)) cur += isPent(cur + 1) ? 1 : -1;
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
    for (let k = 0; k < 2; k++) { const [bi, ni] = pick(r, flat); const n = bars[bi][ni]; n[1] = Math.max(LO, Math.min(HI, n[1] + (r() < 0.5 ? 1 : -1))); if (!isPent(n[1])) n[1] += 1; }
    const longs = flat.filter(([bi, ni]) => bars[bi][ni][2] >= 2);
    if (longs.length && r() < 0.6) { const [bi, ni] = pick(r, longs); const n = bars[bi][ni]; const nb = [n[0] + n[2] - 0.5, n[1] + (r() < 0.5 ? 1 : -1), 0.5, '']; n[2] -= 0.5; bars[bi].splice(ni + 1, 0, nb); }
    bars.forEach(b => b.forEach(n => { if (n[2] >= 1.5) n[3] = r() < 0.3 ? 'slide' : r() < 0.2 ? 'grace' : ''; }));
    return { ...ph, bars };
  };
  const period = (r, o = {}) => {
    const c1 = o.c1 || pick(r, prog.ante), c2 = o.c2 || pick(r, prog.cons);
    const a = phrase(r, c1, { start: o.start, end: o.end1 ?? pick(r, [4, 2, 1]), peak: o.peak });
    // 뒷 프레이즈는 앞 프레이즈의 첫 마디 리듬을 이어받아(대구) 기억에 남게 하고, 으뜸음으로 맺는다
    const R = k => pick(r, p.battle ? RHY.battle : RHY[k]);
    const b = phrase(r, c2, { start: o.start2 ?? a.bars[0][0]?.[1], end: o.end2 ?? 7, peak: o.peak, rhythm: [a.rhythm[0], R('mid'), R('move'), R('end')] });
    return [a, b];
  };

  // 주제(A)는 지역마다 고정, 나머지는 되풀이마다 새로
  const A = period(theme);
  const A2 = A.map(ph => variant(ph, vary));
  const B = p.battle ? period(vary, { start: 9, peak: 3 }) : period(vary, { c1: pick(vary, prog.bA), c2: pick(vary, prog.bC), start: 9 + Math.floor(vary() * 2), peak: 3, end1: 6, end2: 4 });
  const A3 = [A[0], variant(A[1], vary)];
  const bars = [];
  const sec = (name, phs, lead, inten) => phs.forEach(ph => ph.bars.forEach((b, i) => bars.push({ sec: name, chord: ph.chords[i], mel: b, lead, inten: typeof inten === 'function' ? inten(bars.length) : inten, last: i === 3 })));
  if (p.battle) {
    sec('A', A, p.lead, 0.85); sec('B', B, p.lead2, 0.95);
    return { bars, loopStart: 0, midi, mod7 };
  }
  bars.push({ sec: 'intro', chord: A[0].chords[0], mel: [], inten: 0.3 }, { sec: 'intro', chord: A[0].chords[0], mel: [], inten: 0.38, hint: A[0].bars[0] });
  sec('A', A, p.lead, 0.5);
  sec('A2', A2, p.lead, 0.68);
  const b0 = bars.length; sec('B', B, p.lead2, () => 0.72 + 0.28 * Math.sin(Math.PI * Math.min(1, (bars.length - b0) / 7)));
  sec('A3', A3, p.lead, () => 0.55 - 0.03 * (bars.length - b0 - 16));
  bars.push({ sec: 'bridge', chord: A[1].chords[3], mel: [], inten: 0.32 }, { sec: 'bridge', chord: p.mode === 'major' ? 4 : 6, mel: [], inten: 0.28 });
  return { bars, loopStart: 2, midi, mod7 };
}

// 마디 하나를 연주한다
function playBar(p, S, bar, t, beat) {
  const { midi, mod7 } = S, inten = bar.inten * (p.safe ? 0.85 : 1);
  const human = () => (Math.random() - 0.5) * 0.02, hv = v => v * (0.9 + Math.random() * 0.2);
  const root = bar.chord, tri = [root, root + 2, root + 4];
  const melEnd = bar.mel.length ? bar.mel[bar.mel.length - 1] : null;
  // 주선율
  bar.mel.forEach(([pos, d, len, orn], i) => {
    const m = midi(d), prev = bar.mel[i - 1];
    playNote(bar.lead, m, t + pos * beat + human(), len * beat * 0.98, hv(0.95 * inten + 0.05),
      { slide: orn === 'slide' ? (bar.lead === 'fiddle' ? 2 : 1) : (bar.lead === 'fiddle' && prev && Math.abs(prev[1] - d) === 1 && Math.random() < 0.3 ? 1 : 0), grace: orn === 'grace' ? 2 : 0 });
  });
  // 받아치는 선율: 주선율이 길게 머무는 동안 가야금이 주제 조각을 낮게 받아 부른다
  const answer = melEnd && melEnd[2] >= 1.5 && melEnd[0] <= 2.5 && bar.sec !== 'A' && !p.battle ? true : (melEnd && melEnd[2] >= 2 && bar.sec === 'A' && bar.last && Math.random() < 0.5);
  if (answer) {
    const src = (S.bars.find(b => b.sec === 'A')?.mel || []).slice(0, 3);
    let at = melEnd[0] + 0.5;
    src.forEach(([, d], i) => { if (at < 4) { playNote(p.counter, midi(d - 7), t + at * beat + human(), (i === src.length - 1 ? 1.5 : 0.5) * beat, hv(0.5 * inten)); at += i === src.length - 1 ? 1.5 : 0.5; } });
  }
  // 도입의 가야금 암시
  if (bar.hint) bar.hint.forEach(([pos, d, len]) => playNote(p.counter, midi(d - 7), t + pos * beat, len * beat, 0.4));
  // 분산화음(절제): 차분 = 4분음, 흐름 = 8분음, 성김 = 1·3박, 전투 = 8분음 받침
  const arpBase = d => midi(d - 7, p.tonic);
  const pat = p.battle ? [[0, 0], [0.5, 0], [1, 2], [1.5, 0], [2, 4], [2.5, 0], [3, 2], [3.5, 4]]
    : p.style === 'flowing' ? [[0, 0], [0.5, 4], [1, 7], [1.5, 9], [2, 7], [2.5, 4], [3, 2], [3.5, 4]]
    : p.style === 'sparse' ? [[0, 0], [2, 4], [2.5, 7]]
    : p.style === 'epic' ? [[0, 0], [1, 4], [1.5, 7], [2, 9], [3, 7]]
    : [[0, 0], [1, 4], [2, 7], [3, 4]];
  const arpVol = (answer ? 0.5 : 1) * (bar.sec === 'intro' || bar.sec === 'bridge' ? 0.55 : 0.4) * inten;
  pat.forEach(([pos, step], i) => {
    playNote(p.arp, arpBase(root + step), t + pos * beat + human(), (p.style === 'sparse' ? 2 : 1) * beat, hv(arpVol * (i === 0 ? 1.15 : 0.85)));
  });
  // 저음: 첼로가 뿌리음을 길게(웅장·흐름은 3박째 5도)
  if (bar.sec !== 'intro' || p.battle) {
    const bass = midi(root - 14, p.tonic);
    if (p.battle) [0, 1.5, 2, 3].forEach(pos => playNote('cello', bass, t + pos * beat, 0.45 * beat, hv(0.55)));
    else if (p.style === 'epic' || p.style === 'flowing') { playNote('cello', bass, t, 2 * beat, hv(0.8 * inten + 0.05)); playNote('cello', midi(root + 4 - 14, p.tonic), t + 2 * beat, 2 * beat, hv(0.65 * inten + 0.05)); }
    else playNote('cello', bass, t, 4 * beat, hv(0.75 * inten + 0.05));
  }
  // 바닥 화음: 현악이 A′·B·A″ 앞부분에서 부풀었다 가라앉는다
  if (['A2', 'B'].includes(bar.sec) || (bar.sec === 'A3' && !bar.last) || p.battle) {
    tri.forEach(d => playNote('strings', midi(d - 7, p.tonic), t + 0.05, 4 * beat, hv((bar.sec === 'B' ? 0.6 : 0.42) * inten)));
  }
  // 종: 단락 첫머리에 가끔
  if (p.bell > 0 && bar.mel.length && Math.random() < p.bell * (bar.sec === 'B' ? 1.4 : 0.6) && (bar.sec === 'intro' || barNo % 4 === 0)) playNote('bell', midi(root + 2 + 7, p.tonic), t + 2 * beat, 2 * beat, 0.55);
  // 북: 변경·심연은 마디 첫 박에 낮게, 전투는 장단
  if (p.taiko > 0) {
    const hits = p.battle ? [[0, 1], [1.5, 0.5], [2, 0.8], [3.5, 0.45]] : bar.sec === 'B' ? [[0, 1], [2, 0.5]] : barNo % 2 === 0 ? [[0, 0.8]] : [];
    hits.forEach(([pos, v]) => playNote('taiko', 36, t + pos * beat, 0.5, v * p.taiko * (p.battle ? 1 : inten)));
  }
}

function phrase() {
  if (!playing || !ctx || away) return;
  const p = profile(), need = insOf(p), key = `${scene.territory || 'capital'}:${p.mode}:${p.battle ? 'battle' : 'field'}`;
  // 악기를 다 받기 전에는 기다린다
  if (need.some(k => !buffers[k])) { need.forEach(loadIns); phraseTimer = setTimeout(phrase, 400); return; }
  if (key !== songKey || !song) { song = makeSong(p, key, 0); songKey = key; barNo = 0; loopNo = 0; }
  if (barNo >= song.bars.length) { loopNo++; const s2 = makeSong(p, key, loopNo); song = s2; barNo = s2.loopStart; }
  const beat = 60 / p.bpm, barDur = 4 * beat;
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
  const p = profile(), key = `${scene.territory}:${scene.battle}`;
  if (droneKey === key) return;
  droneKey = key;
  if (!playing) return;
  // 전투에 들어가고 나올 때도 쓸 악기를 함께 남겨 둔다
  const both = [...new Set([...insOf(p), ...insOf({ ...p, battle: !p.battle, lead: p.mode === 'major' ? 'shakuhachi' : 'fiddle', arp: 'koto', taiko: 0.7 })])];
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
