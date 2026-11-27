const K = {
  stone: '#6e6a62', stoneD: '#4a4740', stoneL: '#8e897e', moss: '#5a6e48', vein: '#2f8a86', veinL: '#6fd0c4', glow: '#bff4ea', core: '#f4fff8',
  wood: '#6a4a2e', woodD: '#4a321e', woodL: '#8a6440', paper: '#e8e2cc', ink: '#24384a', sea: '#2f6f8f', seaL: '#5fa6c4', scale: '#9fd6d2', scaleD: '#3f8a92', red: '#b8423a', gold: '#c8a454', rope: '#c8ae78',
};

export const DH_FUR = {
  du_vein_lamp: { name: '돌홈 지맥 등잔', grade: 5, W: 1, D: 1, layer: 'floor', cat: '조명', glow: true, parts: [
    { x: .12, y: .12, w: .76, d: .76, h: .1, c: K.stoneD },
    { x: .2, y: .2, w: .6, d: .6, h: .14, z: .1, c: K.stone },
    { x: .2, y: .48, w: .6, d: .04, h: .02, z: .24, c: K.vein }, { x: .48, y: .2, w: .04, d: .6, h: .02, z: .24, c: K.vein },
    { x: .34, y: .34, w: .32, d: .32, h: .6, z: .24, c: K.stone },
    { x: .34, y: .64, w: .32, d: .02, h: .6, z: .24, c: K.stoneD }, { x: .64, y: .34, w: .02, d: .32, h: .6, z: .24, c: K.stoneD },
    { x: .36, y: .5, w: .02, d: .04, h: .44, z: .3, c: K.veinL }, { x: .5, y: .36, w: .04, d: .02, h: .36, z: .38, c: K.vein },
    { x: .22, y: .22, w: .56, d: .56, h: .12, z: .84, c: K.stoneL },
    { x: .26, y: .26, w: .48, d: .48, h: .04, z: .96, c: K.stoneD },
    { x: .3, y: .3, w: .4, d: .4, h: .02, z: .99, c: K.vein },
    { t: 'ell', x: .5, y: .5, z: 1.02, rx: 7, ry: 3.5, c: K.veinL }, { t: 'ell', x: .5, y: .5, z: 1.04, rx: 4, ry: 2, c: K.glow },
    { t: 'ell', x: .5, y: .5, z: 1.14, rx: 2.4, ry: 2.4, c: K.glow }, { t: 'ell', x: .5, y: .5, z: 1.2, rx: 1.2, ry: 1.2, c: K.core },
    { x: .14, y: .7, w: .18, d: .16, h: .06, z: .1, c: K.moss }, { x: .7, y: .16, w: .14, d: .12, h: .05, z: .1, c: K.moss }] },
};

DH_FUR.ug_tide_basin = { name: '물목 거울 수반', grade: 4, W: 1, D: 1, layer: 'floor', cat: '소품', parts: [
  { x: .2, y: .2, w: .6, d: .6, h: .16, c: K.stoneD },
  { x: .14, y: .14, w: .72, d: .72, h: .22, z: .16, c: K.stone },
  { x: .14, y: .82, w: .72, d: .04, h: .22, z: .16, c: K.stoneD }, { x: .82, y: .14, w: .04, d: .72, h: .22, z: .16, c: K.stoneD },
  { x: .2, y: .2, w: .6, d: .6, h: .03, z: .38, c: K.sea },
  { t: 'ell', x: .5, y: .5, z: .42, rx: 7, ry: 3.5, c: K.seaL }, { t: 'ell', x: .42, y: .44, z: .43, rx: 3, ry: 1.4, c: K.glow },
  { t: 'ell', x: .6, y: .58, z: .43, rx: 1.6, ry: .8, c: K.core },
  { x: .14, y: .48, w: .72, d: .04, h: .04, z: .26, c: K.scaleD }, { x: .3, y: .48, w: .08, d: .04, h: .04, z: .3, c: K.scale }, { x: .62, y: .48, w: .08, d: .04, h: .04, z: .22, c: K.scale }] };
DH_FUR.ug_stone_drum = { name: '땅울림 돌북', grade: 4, W: 1, D: 1, layer: 'floor', cat: '장식', parts: [
  { x: .18, y: .18, w: .64, d: .64, h: .08, c: K.woodD },
  { x: .22, y: .22, w: .56, d: .56, h: .42, z: .08, c: K.stoneD },
  { x: .22, y: .76, w: .56, d: .02, h: .42, z: .08, c: K.stone }, { x: .76, y: .22, w: .02, d: .56, h: .42, z: .08, c: K.stone },
  { x: .2, y: .2, w: .6, d: .6, h: .04, z: .5, c: K.stoneL },
  { x: .26, y: .26, w: .48, d: .48, h: .02, z: .54, c: K.moss },
  { x: .32, y: .48, w: .36, d: .04, h: .02, z: .56, c: K.vein }, { x: .48, y: .32, w: .04, d: .36, h: .02, z: .56, c: K.vein },
  { t: 'ell', x: .5, y: .5, z: .58, rx: 2.4, ry: 1.2, c: K.veinL },
  { x: .12, y: .5, w: .1, d: .06, h: .06, z: .3, c: K.rope }, { x: .78, y: .5, w: .1, d: .06, h: .06, z: .3, c: K.rope },
  { x: .7, y: .14, w: .06, d: .06, h: .7, z: .08, c: K.wood }, { t: 'ell', x: .73, y: .17, z: .8, rx: 2.4, ry: 2.4, c: K.woodD }] };
DH_FUR.ug_skiff_bed = { name: '쪽배 침상', grade: 5, W: 2, D: 1, layer: 'floor', cat: '침구', pet: 'bed', parts: [
  { x: .06, y: .14, w: 1.88, d: .72, h: .2, c: K.woodD },
  { x: .02, y: .2, w: .1, d: .6, h: .32, z: .04, c: K.wood }, { x: 1.88, y: .2, w: .1, d: .6, h: .32, z: .04, c: K.wood },
  { x: .1, y: .12, w: 1.8, d: .08, h: .16, z: .2, c: K.wood }, { x: .1, y: .8, w: 1.8, d: .08, h: .16, z: .2, c: K.wood },
  { x: .16, y: .2, w: 1.68, d: .6, h: .1, z: .2, c: K.paper },
  { x: .6, y: .2, w: 1.24, d: .6, h: .06, z: .3, c: K.sea }, { x: .6, y: .2, w: .1, d: .6, h: .06, z: .3, c: K.seaL },
  { x: 1.0, y: .36, w: .5, d: .3, h: .01, z: .36, c: K.scale },
  { x: .2, y: .28, w: .32, d: .44, h: .12, z: .3, c: K.paper }, { x: .2, y: .28, w: .32, d: .04, h: .12, z: .3, c: K.scaleD },
  { x: .96, y: .46, w: .04, d: .04, h: .9, z: .36, c: K.woodL }, { x: 1.0, y: .46, w: .4, d: .02, h: .4, z: .76, c: K.paper }] };
DH_FUR.ug_kelp_screen = { name: '해초 비늘 병풍', grade: 4, W: 3, D: 1, layer: 'floor', cat: '병풍', parts: [
  { x: .05, y: .1, w: 2.9, d: .3, h: .14, c: K.woodD },
  { x: .1, y: .16, w: .95, d: .1, h: 1.7, z: .14, c: K.paper }, { x: 1.05, y: .16, w: .9, d: .1, h: 1.7, z: .14, c: K.paper }, { x: 1.95, y: .16, w: .95, d: .1, h: 1.7, z: .14, c: K.paper },
  { x: 1.04, y: .15, w: .02, d: .12, h: 1.7, z: .14, c: K.woodL }, { x: 1.94, y: .15, w: .02, d: .12, h: 1.7, z: .14, c: K.woodL },
  { x: .3, y: .14, w: .05, d: .1, h: 1.3, z: .2, c: K.moss }, { x: .6, y: .14, w: .05, d: .1, h: 1.0, z: .2, c: K.vein },
  { x: 1.3, y: .14, w: .05, d: .1, h: 1.4, z: .2, c: K.moss }, { x: 1.6, y: .14, w: .05, d: .1, h: 1.1, z: .2, c: K.vein },
  { x: 2.25, y: .14, w: .05, d: .1, h: 1.25, z: .2, c: K.moss }, { x: 2.55, y: .14, w: .05, d: .1, h: 0.9, z: .2, c: K.vein },
  { t: 'ell', x: .5, y: .5, z: 1.4, rx: 3, ry: 2, c: K.scale }, { t: 'ell', x: 1.45, y: .5, z: 1.55, rx: 3, ry: 2, c: K.scaleD },
  { t: 'ell', x: 2.4, y: .5, z: 1.3, rx: 3, ry: 2, c: K.scale }, { t: 'ell', x: .9, y: .5, z: .7, rx: 2, ry: 1.4, c: K.seaL }, { t: 'ell', x: 2.0, y: .5, z: .8, rx: 2, ry: 1.4, c: K.seaL },
  { x: .05, y: .12, w: 2.9, d: .2, h: .06, z: 1.84, c: K.gold }] };

export const DH_PAPER = { ug_tide: { name: '물때 너울 벽지', grade: 4, c: '#1d3c4c', l: '#3f8aa0', pat: 'wave' } };
export const DH_GROUND = { ug_pool: { name: '고임 돌 바닥', grade: 4, a: '#4e5a5c', b: '#444f51', pat: 'cobble' } };

export const DH_WALL = {
  dh_tide_chart: { name: '도해수 비늘 물때표', grade: 5, kind: 'deco', cat: '장식', w: 1.4, h: 34, rects: [
    [-.06, 0, 1.52, 2, K.woodD], [-.06, 32, 1.52, 2, K.woodD], [0, 2, 1.4, 30, K.wood], [.08, 3, 1.24, 28, K.paper],
    [.16, 4.5, 1.08, 1.4, K.sea], [.3, 4.8, .8, .6, K.seaL],
    [.18, 8, .26, 3, K.scaleD], [.2, 8.6, .22, 2, K.scale], [.58, 8, .26, 3, K.scaleD], [.6, 8.6, .22, 2, K.scale], [.98, 8, .26, 3, K.scaleD], [1, 8.6, .22, 2, K.scale],
    [.38, 12, .26, 3, K.scaleD], [.4, 12.6, .22, 2, K.scale], [.78, 12, .26, 3, K.scaleD], [.8, 12.6, .22, 2, K.scale],
    [.18, 16, .26, 3, K.scaleD], [.2, 16.6, .22, 2, K.scale], [.58, 16, .26, 3, K.scaleD], [.6, 16.6, .22, 2, K.scale], [.98, 16, .26, 3, K.scaleD], [1, 16.6, .22, 2, K.scale],
    [.38, 20, .26, 3, K.scaleD], [.4, 20.6, .22, 2, K.scale], [.78, 20, .26, 3, K.scaleD], [.8, 20.6, .22, 2, K.scale],
    [.16, 25, .04, 4, K.ink], [.3, 26, .04, 3, K.ink], [.44, 25.5, .04, 3.5, K.ink], [.58, 26.5, .04, 2.5, K.ink], [.72, 25, .04, 4, K.ink], [.86, 26, .04, 3, K.ink], [1, 25.5, .04, 3.5, K.ink],
    [1.1, 25, .22, 4.5, K.red], [1.13, 25.6, .16, 3.3, K.paper], [1.17, 26.6, .08, .5, K.red],
    [.66, 34, .08, 2, K.gold]] },
};
