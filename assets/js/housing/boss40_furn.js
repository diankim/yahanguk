const K = {
  stone: '#6e6a62', stoneD: '#4a4740', stoneL: '#8e897e', moss: '#5a6e48', vein: '#2f8a86', veinL: '#6fd0c4', glow: '#bff4ea', core: '#f4fff8',
  wood: '#6a4a2e', woodD: '#4a321e', woodL: '#8a6440', paper: '#e8e2cc', ink: '#24384a', sea: '#2f6f8f', seaL: '#5fa6c4', scale: '#9fd6d2', scaleD: '#3f8a92', red: '#b8423a', gold: '#c8a454',
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
