import { drawAvatar, AV, registerDesigns } from './housing/avatarsprite.js';
import { drawPet, drawEffect } from './housing/petsprite.js';
import { P } from './housing/render.js';
import { esc } from './core.js';
import { SCENE_ACTS } from './rules.js';

const W = 384, H = 144, K = 1.5;
export const scenePhase = (now = Date.now()) => { const h = new Date(now + 9 * 3600e3).getUTCHours(); return h < 6 ? 'night' : h < 12 ? 'dawn' : h < 18 ? 'day' : 'dusk'; };
const SKY = {
  dawn: ['#5a6e8e', '#8a98b4', '#d8b8a8'], day: ['#7fb0d6', '#a8c8e0', '#c8dcea'],
  dusk: ['#3b2f4f', '#57405e', '#6e4a5e'], night: ['#121a2c', '#1a2338', '#202a40'],
};

function painter(buf, seed) {
  let s = seed;
  const rnd = () => (s = (s * 9301 + 49297) % 233280) / 233280;
  const put = (x, y, c) => { if (x >= 0 && y >= 0 && x < W && y < H) buf[y * W + x] = c; };
  const rect = (x, y, w, h, hex) => { const c = P(hex), x0 = Math.round(x * K), y0 = Math.round(y * K), x1 = Math.round((x + w) * K), y1 = Math.round((y + h) * K); for (let j = y0; j < y1; j++) for (let i = x0; i < x1; i++) put(i, j, c); };
  const dot = (x, y, hex) => rect(x, y, 1, 1, hex);
  const disc = (cx, cy, r, hex, rim) => { for (let y = -r; y <= r; y++) for (let x = -r; x <= r; x++) { const d = x * x + y * y; if (d <= r * r) dot(cx + x, cy + y, rim && d > (r - 1) * (r - 1) ? rim : hex); } };
  const ring = (cx, cy, rx, ry, hex) => { for (let a = 0; a < 360; a += 3) { const t = a * Math.PI / 180; dot(Math.round(cx + rx * Math.cos(t)), Math.round(cy + ry * Math.sin(t)), hex); } };
  const stars = (n, y1, c1 = '#d8d2e6', c2 = '#ffffff') => { for (let i = 0; i < n; i++) dot(Math.floor(rnd() * 256), Math.floor(rnd() * y1), rnd() < .3 ? c2 : c1); };
  const hills = (base, amp, hex, f1 = 19, f2 = 7) => { for (let x = 0; x < 256; x++) { const h = Math.round(amp * (1 + Math.sin(x / f1)) / 2 + amp * 0.4 * Math.sin(x / f2)); rect(x, base - h, 1, h + 2, hex); } };
  const sky = (ph, bands = [30, 16, 10], o = {}) => {
    const c = o.colors || SKY[ph]; let y = 0;
    bands.forEach((h, i) => { rect(0, y, 256, h, c[i]); y += h; });
    if (ph === 'night' || ph === 'dusk') stars(ph === 'night' ? 40 : 16, bands[0] - 2, o.star || '#d8d2e6');
    if (o.orb !== false) {
      const [ox, oy] = o.at || [214, 14];
      if (ph === 'night' || ph === 'dusk') disc(ox, oy, 6, o.moon || '#f2edd2', o.moonRim || '#d8d2b0');
      else disc(ox, oy + (ph === 'dawn' ? 22 : 0), 6, '#ffe0a0', '#ffc878');
    }
  };
  return { rnd, put, rect, dot, disc, ring, stars, hills, sky };
}

const MID = [[150, 234]];
const BACK = [40, 72, 104, 136, 248, 280, 312, 344];
const FRONT = [28, 76, 124, 260, 308, 356];
const crowdSlots = (gap = MID[0]) => ({
  back: BACK.filter(x => x < gap[0] || x > gap[1]).map((x, i) => [x, 114 + (i % 3)]),
  front: FRONT.map((x, i) => [x, 133 + (i % 2)]),
});

const SCENES = {
  feast_lamp(p, ph) {
    p.sky(ph, [50, 10, 0], { colors: ph === 'day' || ph === 'dawn' ? SKY[ph] : ['#121a2c', '#1a2338', '#202a40'] });
    p.rect(40, 30, 176, 6, '#20202a'); for (let x = 40; x < 216; x += 3) p.rect(x, 28, 2, 2, '#2c2c38');
    p.rect(32, 33, 8, 3, '#20202a'); p.rect(216, 33, 8, 3, '#20202a');
    p.rect(48, 36, 160, 24, '#7a2a24'); for (let x = 48; x < 208; x += 20) p.rect(x, 36, 3, 24, '#4a1a16');
    p.rect(48, 36, 160, 3, '#2f6b5a'); p.rect(48, 39, 160, 1, '#c9a24a');
    for (let x = 108; x < 148; x++) p.rect(x, 44, 1, 16, '#3a1410');
    p.rect(116, 40, 24, 5, '#1c2c26'); p.rect(118, 41, 20, 3, '#c9a24a');
    p.rect(0, 60, 256, 36, '#59606a'); for (let y = 62; y < 96; y += 6) p.rect(0, y, 256, 1, '#4c525b');
    for (let y = 60; y < 96; y += 6) for (let x = (y / 6) % 2 ? 0 : 8; x < 256; x += 16) p.rect(x, y, 1, 6, '#4c525b');
    const str = (y0, sag) => { for (let x = 0; x < 256; x++) p.dot(x, y0 + Math.round(sag * Math.sin(Math.PI * ((x % 64) / 64))), '#3a3028'); };
    str(6, 5); str(18, 4);
    const lamp = (x, y, c, c2) => { p.rect(x - 2, y, 5, 6, c); p.rect(x - 1, y - 1, 3, 1, '#3a3028'); p.rect(x - 1, y + 6, 3, 1, '#3a3028'); p.dot(x, y + 2, c2); p.dot(x, y + 3, c2); };
    for (let x = 8; x < 256; x += 16) lamp(x, 7 + Math.round(5 * Math.sin(Math.PI * ((x % 64) / 64))), (x / 16) % 2 ? '#c8452f' : '#d9a23a', '#ffe6a0');
    for (let x = 16; x < 256; x += 16) lamp(x, 19 + Math.round(4 * Math.sin(Math.PI * ((x % 64) / 64))), '#e8dcc0', '#ffd36a');
    const stone = x => { p.rect(x - 4, 82, 9, 3, '#8a8f96'); p.rect(x - 2, 70, 5, 12, '#7a7f86'); p.rect(x - 5, 62, 11, 8, '#8a8f96'); p.rect(x - 3, 64, 7, 4, '#ffd36a'); p.rect(x - 6, 60, 13, 2, '#6a6f76'); };
    stone(28); stone(228);
    p.rect(116, 66, 24, 12, '#5a3a24'); p.rect(114, 64, 28, 3, '#3b2618');
    p.rect(122, 50, 12, 14, '#c8452f'); p.rect(124, 52, 8, 10, '#ffcf6a'); p.rect(126, 54, 4, 6, '#fff2c4'); p.rect(121, 49, 14, 2, '#3a3028'); p.rect(121, 63, 14, 1, '#3a3028');
    return crowdSlots();
  },
  feast_redmoon(p, ph) {
    p.sky(ph, [30, 16, 10], { colors: ['#3a1820', '#5a2228', '#7a3328'], orb: false, star: '#e8b8b8' });
    p.disc(52, 22, 13, '#c8302c', '#e05a48'); p.disc(48, 18, 3, '#a82420'); p.disc(57, 26, 2, '#a82420');
    p.hills(60, 10, '#3a1a18', 23, 9);
    for (let x = 0; x < 256; x++) p.rect(x, 58, 1, 38, x % 9 < 1 ? '#7a4a30' : '#8a5a38');
    for (let y = 62; y < 96; y += 4) for (let x = (y / 4) % 2 ? 2 : 8; x < 256; x += 12) p.rect(x, y, 3, 1, '#9a6a44');
    for (let k = 0; k < 4; k++) { const r = 16 - k * 3; for (let a = 200; a <= 340; a += 4) { const t = a * Math.PI / 180; p.dot(Math.round(128 + r * Math.cos(t)), Math.round(58 + r * Math.sin(t) * 1.3), '#e8dcc4'); } }
    p.rect(126, 22, 4, 36, '#e8dcc4'); p.rect(122, 22, 12, 3, '#e8dcc4'); p.disc(128, 18, 3, '#e8dcc4', '#b8ac94'); p.dot(127, 18, '#3a1820'); p.dot(129, 18, '#3a1820');
    const banner = x => { p.rect(x, 20, 2, 40, '#4a2a1c'); p.rect(x + 2, 22, 9, 16, '#a82420'); p.rect(x + 2, 38, 3, 3, '#a82420'); p.rect(x + 8, 38, 3, 3, '#a82420'); p.disc(x + 6, 29, 2, '#e8b04a'); };
    banner(30); banner(70); banner(176); banner(216);
    p.rect(118, 60, 20, 8, '#3a2018'); p.rect(116, 58, 24, 3, '#a82420');
    p.rect(124, 52, 8, 6, '#5a3020'); [[126, 48, '#ff9a3a'], [128, 46, '#ffd36a'], [130, 48, '#ff9a3a'], [127, 44, '#ffd36a'], [129, 42, '#ff6a3a']].forEach(([x, y, c]) => p.rect(x, y, 2, 4, c));
    return crowdSlots();
  },
  feast_ledger(p, ph) {
    p.rect(0, 0, 256, 96, '#0e0d14'); p.rect(0, 0, 256, 18, ph === 'day' ? '#2a3044' : '#141320');
    p.stars(10, 14, '#6a6880', '#9a98b0');
    const stall = (x, w, roof) => { p.rect(x, 22, w, 4, roof); for (let i = 0; i < w; i += 4) p.rect(x + i, 26, 2, 2, roof); p.rect(x + 1, 26, 2, 30, '#2a2018'); p.rect(x + w - 3, 26, 2, 30, '#2a2018'); p.rect(x, 46, w, 10, '#3a2a1c'); p.rect(x, 46, w, 1, '#5a4430');
      for (let i = 4; i < w - 4; i += 5) p.rect(x + i, 42, 3, 4, ['#7a5a3a', '#4a6a6a', '#8a3a3a', '#c8b48a'][Math.floor(p.rnd() * 4)]); };
    stall(4, 44, '#1e2a3a'); stall(56, 40, '#2a1e30'); stall(160, 40, '#1e2a3a'); stall(208, 44, '#2a1e30');
    [20, 76, 180, 230].forEach(x => { p.rect(x, 14, 1, 4, '#3a3028'); p.rect(x - 2, 18, 5, 6, '#c89a3a'); p.rect(x - 1, 19, 3, 4, '#ffd88a'); });
    p.rect(0, 56, 256, 40, '#2e2c36'); for (let y = 58; y < 96; y += 5) for (let x = (y / 5) % 2 ? 0 : 6; x < 256; x += 12) p.rect(x, y, 10, 1, '#383644');
    p.rect(108, 46, 40, 14, '#3a2414'); p.rect(106, 44, 44, 3, '#5a3a22');
    p.rect(112, 38, 10, 6, '#e8dcc0'); p.rect(112, 37, 10, 1, '#8a2a24'); p.rect(124, 36, 10, 8, '#d8cbb0'); p.rect(124, 35, 10, 1, '#1e2a3a');
    p.rect(136, 39, 10, 5, '#4a2a1c'); for (let i = 0; i < 4; i++) for (let j = 0; j < 2; j++) p.dot(137 + i * 2, 40 + j * 2, '#c8a46a');
    p.rect(126, 18, 4, 4, '#ffd88a'); p.rect(124, 16, 8, 2, '#3a3028');
    return crowdSlots();
  },
  feast_snowlamp(p, ph) {
    p.sky(ph, [20, 14, 10], { at: [200, 18] });
    p.hills(46, 16, '#9aa8c0', 27, 11); p.hills(52, 8, '#c8d4e4', 17, 6);
    p.rect(60, 38, 136, 4, '#e8eef6'); for (let x = 60; x < 196; x += 3) p.rect(x, 36, 2, 2, '#f4f8fc'); p.rect(52, 40, 8, 3, '#e8eef6'); p.rect(196, 40, 8, 3, '#e8eef6');
    p.rect(64, 42, 128, 16, '#6a4a3a'); for (let x = 64; x < 192; x += 16) p.rect(x, 42, 2, 16, '#3a2a20'); p.rect(64, 42, 128, 2, '#2f5a6a');
    const pine = (x, y) => { p.rect(x, y, 2, 10, '#3a2a20'); for (let k = 0; k < 4; k++) { const w = 12 - k * 3; p.rect(x + 1 - w / 2, y - 3 - k * 4, w, 3, '#2f4a3a'); p.rect(x + 1 - w / 2, y - 3 - k * 4, w, 1, '#f4f8fc'); } };
    pine(20, 50); pine(36, 54); pine(222, 52); pine(238, 48);
    p.rect(0, 58, 256, 38, '#e8eef6'); for (let y = 60; y < 96; y += 4) for (let x = (y / 4) % 2 ? 0 : 5; x < 256; x += 10) p.rect(x, y, 4, 1, '#d4dce8');
    const lamp = (x, y, r) => { for (let j = 0; j <= r; j++) { const w = Math.round(Math.sqrt(r * r - (r - j) * (r - j))); p.rect(x - w, y - r + j, w * 2 + 1, 1, '#f8fbff'); } p.rect(x - 1, y - Math.ceil(r / 2), 3, 2, '#ffcf6a'); p.dot(x, y - Math.ceil(r / 2) - 1, '#fff2c4'); p.rect(x - r, y, r * 2 + 1, 1, '#c8d0dc'); };
    [[40, 70], [64, 66], [88, 70], [168, 70], [192, 66], [216, 70]].forEach(([x, y]) => lamp(x, y, 5));
    lamp(128, 66, 9);
    for (let i = 0; i < 60; i++) p.dot(Math.floor(p.rnd() * 256), Math.floor(p.rnd() * 90), '#ffffff');
    return crowdSlots();
  },
  feast_flowlamp(p, ph) {
    p.sky(ph, [16, 12, 8], { colors: ph === 'dusk' ? ['#3a2c4a', '#7a4a5a', '#c87a5a'] : SKY[ph], at: [210, 16] });
    p.rect(0, 36, 256, 4, ph === 'night' ? '#202a40' : '#e8a86a');
    p.hills(40, 8, '#4a3a4a', 31, 13);
    p.rect(0, 40, 256, 26, '#2a3a5a'); for (let y = 42; y < 66; y += 3) for (let x = (y % 2) * 6; x < 256; x += 14) p.rect(x, y, 6, 1, '#3a4e72');
    const lotus = (x, y) => { p.rect(x - 2, y, 5, 2, '#e88aa0'); p.rect(x - 1, y - 1, 3, 1, '#f3b6c3'); p.dot(x, y - 2, '#ffd36a'); for (let k = 1; k < 4; k++) p.dot(x, y + 2 + k * 2, k % 2 ? '#ffd36a' : '#c89a3a'); };
    [[20, 48], [46, 54], [70, 46], [96, 58], [118, 50], [142, 56], [166, 47], [190, 53], [214, 49], [238, 57], [84, 44], [228, 44]].forEach(([x, y]) => lotus(x, y));
    const boat = (x, y) => { p.rect(x, y, 22, 3, '#5a3a24'); p.rect(x + 2, y + 3, 18, 1, '#3a2418'); p.rect(x + 10, y - 10, 1, 10, '#3a2418'); p.rect(x + 11, y - 9, 7, 6, '#e8dcc0'); };
    boat(150, 40); boat(30, 41);
    p.rect(0, 66, 256, 30, '#7a5a3a'); for (let x = 0; x < 256; x += 8) p.rect(x, 66, 1, 30, '#5a4028'); p.rect(0, 66, 256, 2, '#4a3220');
    for (let x = 4; x < 256; x += 32) p.rect(x, 62, 3, 6, '#4a3220');
    p.rect(122, 60, 12, 8, '#5a3a24'); p.rect(124, 54, 8, 6, '#e8dcc0'); p.rect(126, 56, 4, 3, '#ffcf6a');
    return crowdSlots();
  },
  feast_ember(p, ph) {
    p.sky(ph, [30, 20, 0], { colors: ph === 'day' || ph === 'dawn' ? ['#6a4a48', '#8a5a4a', '#8a5a4a'] : ['#160e10', '#2a1410', '#2a1410'], star: '#a87868' });
    p.hills(52, 18, '#3a1612', 29, 9); for (let x = 0; x < 256; x++) if (x % 37 < 2) p.rect(x, 40, 1, 12, '#c8452f');
    const hut = x => { p.rect(x, 44, 22, 12, '#3a2418'); p.rect(x - 3, 40, 28, 4, '#5a3a24'); p.rect(x + 8, 48, 6, 8, '#ff9a3a'); };
    hut(14); hut(56); hut(178); hut(220);
    p.rect(0, 56, 256, 40, '#3a2a24'); for (let y = 58; y < 96; y += 4) for (let x = (y / 4) % 2 ? 0 : 7; x < 256; x += 14) p.rect(x, y, 5, 1, '#4a3428');
    p.rect(110, 64, 36, 6, '#2a1a12'); for (let i = 0; i < 6; i++) p.rect(112 + i * 6, 60 + (i % 2) * 2, 4, 6, '#4a2a18');
    [[118, 48, 6, 14, '#c8302c'], [124, 38, 8, 24, '#ff6a3a'], [134, 44, 6, 18, '#c8302c'], [126, 44, 4, 16, '#ffd36a'], [128, 34, 2, 6, '#ff9a3a']].forEach(([x, y, w, h, c]) => p.rect(x, y, w, h, c));
    p.rect(126, 52, 6, 8, '#fff2c4');
    for (let i = 0; i < 30; i++) p.dot(100 + Math.floor(p.rnd() * 56), 4 + Math.floor(p.rnd() * 34), p.rnd() < .5 ? '#ffb04a' : '#ff6a3a');
    [60, 92, 164, 196].forEach(x => { p.rect(x, 50, 2, 14, '#4a2a18'); p.rect(x - 1, 46, 4, 4, '#ff9a3a'); p.dot(x, 44, '#ffd36a'); });
    return crowdSlots();
  },
  feast_star(p, ph) {
    p.sky(ph, [40, 20, 0], { colors: ph === 'day' || ph === 'dawn' ? SKY[ph] : ['#0a0f22', '#121a34', '#121a34'], orb: ph === 'day' || ph === 'dawn' });
    if (ph === 'night' || ph === 'dusk') {
      p.stars(50, 56, '#8a98c0', '#ffffff');
      [[[30, 10], [44, 6], [58, 12], [70, 8], [84, 16]], [[176, 8], [190, 14], [204, 10], [214, 20], [230, 12]]].forEach(cs => {
        for (let i = 0; i < cs.length - 1; i++) { const [x0, y0] = cs[i], [x1, y1] = cs[i + 1], n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0)); for (let t = 0; t <= n; t++) p.dot(Math.round(x0 + (x1 - x0) * t / n), Math.round(y0 + (y1 - y0) * t / n), '#3a4a7a'); }
        cs.forEach(([x, y]) => p.rect(x, y, 2, 2, '#ffe9a0'));
      });
    }
    p.hills(60, 6, '#141a30', 21, 8);
    for (let j = 0; j < 30; j++) { const w = 22 - Math.round(j * 0.25) + (j > 24 ? 4 : 0); p.rect(128 - w / 2, 58 - j, w, 1, j % 3 ? '#8a8478' : '#7a7468'); }
    p.rect(124, 40, 8, 6, '#2a2620'); p.rect(118, 27, 20, 3, '#9a9488');
    p.ring(128, 18, 9, 9, '#c9a24a'); p.ring(128, 18, 9, 3, '#c9a24a'); p.ring(128, 18, 3, 9, '#a8843a'); p.disc(128, 18, 1, '#ffe9a0'); p.rect(127, 27, 2, 3, '#a8843a');
    p.rect(0, 60, 256, 36, '#4a4c58'); for (let y = 62; y < 96; y += 6) p.rect(0, y, 256, 1, '#3e404c'); for (let y = 60; y < 96; y += 6) for (let x = (y / 6) % 2 ? 0 : 9; x < 256; x += 18) p.rect(x, y, 1, 6, '#3e404c');
    for (let a = 0; a < 360; a += 30) { const t = a * Math.PI / 180; p.rect(Math.round(128 + 70 * Math.cos(t)), Math.round(76 + 10 * Math.sin(t)), 2, 1, '#c9a24a'); }
    return crowdSlots();
  },
  wedding(p, ph) {
    p.sky(ph, [26, 14, 8], { colors: ph === 'day' ? SKY.day : ph === 'dawn' ? SKY.dawn : ['#3b2f4f', '#57405e', '#6e4a5e'], orb: false });
    for (let x = 0; x < 256; x++) { const h = 6 + Math.round(4 * Math.sin(x / 19) + 3 * Math.sin(x / 7)); p.rect(x, 48 - h, 1, h, '#2e2638'); }
    p.rect(10, 44, 236, 4, '#2a2630'); for (let x = 10; x < 246; x += 3) p.rect(x, 42, 2, 2, '#34303c');
    p.rect(4, 42, 6, 3, '#2a2630'); p.rect(246, 42, 6, 3, '#2a2630');
    p.rect(10, 48, 236, 26, '#d8cbb0'); for (let x = 10; x < 246; x += 26) p.rect(x, 48, 3, 26, '#6b3f2a'); p.rect(10, 48, 236, 2, '#6b3f2a');
    for (let x = 24; x < 232; x++) { const k = Math.floor((x - 24) / 13) % 2, d = Math.round(2.5 * Math.sin(Math.PI * ((x - 24) % 13) / 13)); p.rect(x, 0, 1, 7 + d, k ? '#9a2f36' : '#2f4f8a'); }
    p.rect(24, 7, 2, 74, '#5a3a24'); p.rect(230, 7, 2, 74, '#5a3a24');
    p.rect(86, 46, 84, 34, '#3b2618');
    for (let i = 0; i < 8; i++) p.rect(88 + i * 10, 48, 9, 30, '#ece2c8');
    [[94, 70], [104, 64], [124, 60], [140, 66], [158, 62]].forEach(([x, y]) => { p.rect(x, y, 1, 78 - y, '#4a3a2a'); p.rect(x - 3, y, 7, 2, '#3f6b4a'); p.rect(x - 2, y + 4, 5, 2, '#4f7d55'); });
    p.rect(0, 80, 256, 16, '#a8895a'); for (let y = 82; y < 96; y += 3) p.rect(0, y, 256, 1, '#977a4c'); for (let x = 6; x < 256; x += 14) p.rect(x, 80, 1, 16, '#9b7f51');
    p.rect(108, 76, 40, 4, '#a8323a'); p.rect(106, 80, 44, 8, '#c03c45'); p.rect(110, 88, 3, 8, '#4a2c1c'); p.rect(143, 88, 3, 8, '#4a2c1c');
    p.rect(114, 67, 2, 9, '#2f4f8a'); p.rect(140, 67, 2, 9, '#a8323a'); p.dot(114, 65, '#ffd36a'); p.dot(114, 66, '#ff9a3a'); p.dot(141, 65, '#ffd36a'); p.dot(141, 66, '#ff9a3a');
    p.rect(122, 72, 4, 4, '#e8e0d0'); p.rect(130, 72, 4, 4, '#e8e0d0'); p.rect(121, 68, 2, 4, '#3f6b4a'); p.rect(124, 66, 2, 6, '#4f7d55'); p.rect(131, 66, 2, 6, '#5a8a3a'); p.rect(133, 69, 2, 3, '#6aa04a');
    for (let x = 116; x < 140; x++) p.dot(x, 74 + (x % 2), x % 4 < 2 ? '#2f4f8a' : '#c03c45');
    return { back: [[52, 116], [80, 114], [108, 117], [276, 117], [304, 114], [332, 116]], front: [[30, 133], [64, 134], [320, 134], [356, 133]], couple: [[146, 132, false], [238, 132, true]] };
  },
  tourney(p, ph) {
    p.sky(ph, [30, 10, 0], { at: [180, 10] });
    p.hills(42, 10, '#7a9a7a', 25, 9);
    p.rect(20, 34, 216, 4, '#3a3a44'); for (let x = 20; x < 236; x += 3) p.rect(x, 32, 2, 2, '#4a4a54');
    p.rect(28, 38, 200, 14, '#c8b48a'); for (let x = 28; x < 228; x += 20) p.rect(x, 38, 2, 14, '#7a4a2a');
    const flag = (x, c) => { p.rect(x, 14, 1, 40, '#4a2a18'); p.rect(x + 1, 15, 8, 12, c); p.rect(x + 1, 27, 3, 2, c); p.rect(x + 6, 27, 3, 2, c); };
    flag(16, '#2f4f8a'); flag(60, '#a8323a'); flag(190, '#2f4f8a'); flag(232, '#a8323a');
    p.rect(0, 52, 256, 44, '#c8a87a'); for (let y = 54; y < 96; y += 4) for (let x = (y / 4) % 2 ? 0 : 6; x < 256; x += 12) p.rect(x, y, 6, 1, '#b8986a');
    p.rect(76, 58, 104, 22, '#9a6a3a'); p.rect(76, 58, 104, 2, '#b88a54'); p.rect(76, 78, 104, 3, '#6a4426');
    p.rect(76, 54, 2, 8, '#4a2a18'); p.rect(178, 54, 2, 8, '#4a2a18');
    for (let x = 78; x < 178; x += 2) p.dot(x, 55, x % 4 ? '#a8323a' : '#2f4f8a');
    const drum = x => { p.rect(x - 1, 60, 2, 16, '#4a2a18'); p.disc(x, 56, 5, '#a8323a', '#e8c070'); p.rect(x - 2, 55, 5, 2, '#e8dcc0'); };
    drum(64); drum(192);
    const bench = (x, y, w) => { p.rect(x, y, w, 2, '#6a4426'); p.rect(x + 1, y + 2, 1, 3, '#4a2a18'); p.rect(x + w - 2, y + 2, 1, 3, '#4a2a18'); };
    bench(6, 70, 56); bench(194, 70, 56);
    return { back: [[20, 120], [44, 122], [68, 121], [316, 121], [340, 122], [364, 120]], front: [[28, 138], [76, 139], [124, 140], [260, 140], [308, 139], [356, 138]], fighter: [[168, 112, false], [216, 112, true]] };
  },
  raid(p, ph) {
    p.sky(ph, [24, 16, 10], { colors: ['#24162e', '#3a2040', '#4a2a4a'], orb: false, star: '#a890c0' });
    p.hills(52, 14, '#1e1424', 21, 8);
    for (let j = 0; j < 40; j++) { const w = Math.round(30 + 26 * Math.sin(Math.PI * j / 40)); p.rect(128 - w / 2, 54 - j, w, 1, j > 34 ? '#2a1a34' : '#1a1020'); }
    p.rect(112, 26, 5, 2, '#c060ff'); p.rect(139, 26, 5, 2, '#c060ff'); p.dot(114, 25, '#f0c0ff'); p.dot(141, 25, '#f0c0ff');
    p.rect(0, 54, 256, 42, '#3a3040'); for (let y = 56; y < 96; y += 4) for (let x = (y / 4) % 2 ? 0 : 7; x < 256; x += 14) p.rect(x, y, 6, 1, '#463a4e');
    const crack = (x, y) => { for (let i = 0; i < 12; i++) p.dot(x + i, y + Math.round(Math.sin(i * 1.3) * 1.5), '#9a50d0'); };
    crack(60, 66); crack(170, 70); crack(110, 84);
    const post = x => { p.rect(x, 40, 3, 24, '#4a2a18'); p.rect(x - 2, 44, 7, 10, '#e8dcc0'); p.rect(x - 1, 46, 5, 1, '#a8323a'); p.rect(x, 48, 3, 4, '#a8323a'); };
    post(40); post(84); post(170); post(214);
    for (let i = 0; i < 40; i++) p.dot(Math.floor(p.rnd() * 256), 50 + Math.floor(p.rnd() * 20), p.rnd() < .5 ? '#6a4a80' : '#5a3a6a');
    return crowdSlots();
  },
};
const SEEDS = { feast_lamp: 31, feast_redmoon: 5, feast_ledger: 17, feast_snowlamp: 23, feast_flowlamp: 41, feast_ember: 53, feast_star: 67, wedding: 7, tourney: 77, raid: 91 };

const bgCache = new Map();
function background(key, ph) {
  const k = `${key}|${ph}`;
  if (!bgCache.has(k)) {
    const buf = new Uint32Array(W * H), p = painter(buf, SEEDS[key] || 3);
    const lay = (SCENES[key] || SCENES.feast_lamp)(p, ph);
    bgCache.set(k, { buf, lay });
  }
  return bgCache.get(k);
}

function place(lay, list) {
  const out = [], spots = { couple: [...(lay.couple || [])], fighter: [...(lay.fighter || [])] };
  const front = [...lay.front], back = [...lay.back];
  const meIdx = Math.min(1, front.length - 1);
  for (const f of list) {
    let s = null;
    if (f.role === 'couple' && spots.couple.length) s = spots.couple.shift();
    else if (f.role === 'fighter' && spots.fighter.length) s = spots.fighter.shift();
    else if (f.me && front[meIdx]) s = front.splice(meIdx, 1)[0];
    if (s) out.push({ f, x: s[0], y: s[1], flip: s[2] ?? s[0] > W / 2 });
  }
  for (const f of list) {
    if (out.some(o => o.f === f)) continue;
    const s = front.shift() || back.shift(); if (!s) break;
    out.push({ f, x: s[0], y: s[1], flip: s[0] > W / 2 });
  }
  return out.sort((a, b) => a.y - b.y);
}

export function sceneHtml() {
  return '<div class="scene-box"><canvas class="scene-cv" width="384" height="144" aria-label="함께하는 이들"></canvas><div class="scene-tags"></div></div>';
}

export function mountScene(box, key) {
  const cv = box.querySelector('.scene-cv'), tags = box.querySelector('.scene-tags'), g = cv.getContext('2d');
  const img = g.createImageData(W, H), buf = new Uint32Array(img.data.buffer);
  let spots = [], more = 0, prev = null, fx = [], peek = null, timer = null, state = new Map();
  const put = (x, y, c) => { if (x >= 0 && y >= 0 && x < W && y < H) buf[y * W + x] = c; };
  const paint = () => {
    if (!box.isConnected) { clearInterval(timer); return; }
    if (document.hidden) return;
    const now = Date.now(), bg = background(key, scenePhase());
    buf.set(bg.buf);
    fx = fx.filter(e => e.until > now);
    for (const s of spots) {
      const st = state.get(s.f.id) || {};
      const frame = st.until > now ? st.frame : 'stand';
      drawAvatar(put, s.f.look, frame, s.x, s.y, s.flip, s.f.job);
      const e = fx.find(x => x.id === s.f.id);
      if (e) {
        const a = SCENE_ACTS[e.act] || {};
        if (a.fx === 'pet' && s.f.pet) { drawPet(put, s.f.pet.id, !!s.f.pet.adult, 'step', s.x + (s.flip ? -18 : 18), s.y, !s.flip); drawEffect(put, 'heart', s.x + (s.flip ? -18 : 18), s.y - 18); }
        else if (a.fx === 'petal') for (let i = 0; i < 8; i++) { const px = s.x - 12 + ((i * 7 + Math.floor(now / 200)) % 24), py = s.y - 44 + ((i * 11 + Math.floor(now / 120)) % 30); put(px, py, P(i % 2 ? '#f3b6c3' : '#fbe3e8')); put(px + 1, py, P('#e88aa0')); }
        else if (a.fx) drawEffect(put, a.fx, s.x, s.y - 38);
      }
    }
    g.putImageData(img, 0, 0);
    const shown = new Set([...fx.map(e => e.id), ...(peek && peek.until > now ? [peek.id] : [])]);
    tags.innerHTML = spots.filter(s => s.f.me || s.f.role === 'couple' || s.f.role === 'fighter' || shown.has(s.f.id)).map(s => {
      const e = fx.find(x => x.id === s.f.id), a = e && SCENE_ACTS[e.act];
      const cls = s.f.me ? ' me' : s.f.role === 'couple' || s.f.role === 'fighter' ? ' cp' : '';
      return `<span class="scene-nm${cls}" style="left:${(s.x / W * 100).toFixed(2)}%;top:${(s.y / H * 100).toFixed(2)}%">${s.f.me ? `나 · ${esc(s.f.name)}` : esc(s.f.name)}</span>`
        + (a ? `<span class="scene-bub" style="left:${(s.x / W * 100).toFixed(2)}%;top:${((s.y - 46) / H * 100).toFixed(2)}%">${esc(a.label)}</span>` : '');
    }).join('') + (more > 0 ? `<span class="scene-more">외 ${more}명</span>` : '');
  };
  const tick = () => {
    const now = Date.now();
    for (const s of spots) {
      const st = state.get(s.f.id);
      if (st && st.until > now) continue;
      const r = Math.random();
      if (r < 0.06) state.set(s.f.id, { frame: 'blink', until: now + 300 });
      else if (r < 0.09) state.set(s.f.id, { frame: 'walk', until: now + 900 });
    }
    paint();
  };
  cv.addEventListener('click', e => {
    const r = cv.getBoundingClientRect(), x = (e.clientX - r.left) / r.width * W, y = (e.clientY - r.top) / r.height * H;
    let best = null, bd = 1e9;
    for (const s of spots) { const d = Math.abs(s.x - x) + Math.abs(s.y - 18 - y) * 0.6; if (d < bd) { bd = d; best = s; } }
    if (best && bd < 30) { peek = { id: best.f.id, until: Date.now() + 2500 }; paint(); }
  });
  const update = folks => {
    if (!folks) return;
    registerDesigns(folks.designs || {});
    const list = folks.list || [];
    more = folks.more || 0;
    if (prev) {
      const now = Date.now();
      for (const f of list) {
        const o = prev.get(f.id), n = f.n || {};
        if (!o) { const first = Object.keys(n)[0]; if (first && SCENE_ACTS[first] && first !== 'pets') fx.push({ id: f.id, act: first, until: now + 2800 }); continue; }
        for (const k of Object.keys(n)) if ((n[k] || 0) > (o[k] || 0) && SCENE_ACTS[k]) { fx = fx.filter(x => x.id !== f.id); fx.push({ id: f.id, act: k, until: now + (k === 'pets' ? 6000 : 2800) }); }
      }
    }
    prev = new Map(list.map(f => [f.id, { ...(f.n || {}) }]));
    spots = place(background(key, scenePhase()).lay, list);
    paint();
  };
  timer = setInterval(tick, 700);
  return { update, stop: () => clearInterval(timer) };
}
