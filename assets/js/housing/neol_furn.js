const K = {
  clay: '#5a3a26', clayD: '#3e2818', clayL: '#7a5236', teal: '#2f8a86', tealD: '#1f5e5c', tealL: '#5fb8b0', glow: '#9fe0d6', foam: '#e4f4f0',
  lac: '#2a2a30', lacL: '#44444c', gold: '#c8a454', paper: '#eef0e6', ink: '#2c4a5a', inkL: '#4f7f8c', bamboo: '#b8a45a', bambooD: '#8a7a3a', rope: '#c8ae78',
};

export const NL_FUR = {
  neol_jar: { name: '고인 빛 항아리', grade: 4, W: 1, D: 1, layer: 'floor', cat: '도자', parts: [
    { x: .2, y: .2, w: .6, d: .6, h: .08, c: K.clayD },
    { x: .14, y: .14, w: .72, d: .72, h: .5, z: .08, c: K.clay },
    { x: .14, y: .82, w: .72, d: .04, h: .5, z: .08, c: K.clayD }, { x: .82, y: .14, w: .04, d: .72, h: .5, z: .08, c: K.clayD },
    { x: .22, y: .22, w: .56, d: .56, h: .12, z: .58, c: K.clayL },
    { x: .28, y: .28, w: .44, d: .44, h: .03, z: .7, c: K.tealD },
    { x: .32, y: .32, w: .36, d: .36, h: .02, z: .72, c: K.teal },
    { t: 'ell', x: .5, y: .5, z: .75, rx: 4, ry: 2, c: K.glow }, { t: 'ell', x: .42, y: .44, z: .76, rx: 1.5, ry: 1, c: K.foam },
    { x: .14, y: .5, w: .72, d: .03, h: .04, z: .36, c: K.teal }, { x: .3, y: .5, w: .08, d: .03, h: .04, z: .4, c: K.tealL }, { x: .6, y: .5, w: .08, d: .03, h: .04, z: .32, c: K.tealL }] },
  neol_screen: { name: '너울 물그림 병풍', grade: 4, W: 3, D: 1, layer: 'floor', cat: '병풍', parts: [
    { x: .05, y: .1, w: 2.9, d: .3, h: .14, c: K.lac },
    { x: .1, y: .16, w: .95, d: .1, h: 1.7, z: .14, c: K.paper }, { x: 1.05, y: .16, w: .9, d: .1, h: 1.7, z: .14, c: K.paper }, { x: 1.95, y: .16, w: .95, d: .1, h: 1.7, z: .14, c: K.paper },
    { x: 1.04, y: .15, w: .02, d: .12, h: 1.7, z: .14, c: K.lacL }, { x: 1.94, y: .15, w: .02, d: .12, h: 1.7, z: .14, c: K.lacL },
    { t: 'ell', x: .45, y: .5, z: .5, rx: 9, ry: 3, c: K.inkL }, { t: 'ell', x: .7, y: .5, z: .62, rx: 7, ry: 2.5, c: K.teal },
    { t: 'ell', x: 1.3, y: .5, z: .72, rx: 10, ry: 4, c: K.ink }, { t: 'ell', x: 1.62, y: .5, z: .9, rx: 7, ry: 3, c: K.teal }, { t: 'ell', x: 1.5, y: .5, z: 1.1, rx: 4, ry: 2, c: K.tealL },
    { t: 'ell', x: 2.25, y: .5, z: .56, rx: 9, ry: 3, c: K.inkL }, { t: 'ell', x: 2.55, y: .5, z: .7, rx: 6, ry: 2.5, c: K.teal },
    { t: 'ell', x: 1.42, y: .5, z: 1.22, rx: 2, ry: 1.2, c: K.foam }, { t: 'ell', x: .6, y: .5, z: .72, rx: 1.6, ry: 1, c: K.foam }, { t: 'ell', x: 2.4, y: .5, z: .8, rx: 1.6, ry: 1, c: K.foam },
    { x: .05, y: .12, w: 2.9, d: .2, h: .06, z: 1.84, c: K.gold }] },
};

export const NL_WALL = {
  neol_blind: { name: '흩은 물빛 발', grade: 4, kind: 'deco', cat: '장식', w: 1.6, h: 32, rects: [
    [0, 1, 1.6, 1.6, K.bambooD], [.1, 2.6, .06, 26, K.bamboo], [.3, 2.6, .06, 26, K.bamboo], [.5, 2.6, .06, 26, K.bamboo], [.7, 2.6, .06, 26, K.bamboo],
    [.9, 2.6, .06, 26, K.bamboo], [1.1, 2.6, .06, 26, K.bamboo], [1.3, 2.6, .06, 26, K.bamboo], [1.5, 2.6, .06, 26, K.bamboo],
    [.04, 8, 1.52, .5, K.rope], [.04, 18, 1.52, .5, K.rope],
    [.2, 5, .1, 1.4, K.tealL], [.62, 11, .1, 1.4, K.glow], [1.02, 6, .1, 1.4, K.teal], [1.36, 13, .1, 1.4, K.tealL],
    [.42, 21, .1, 1.4, K.teal], [.84, 24, .1, 1.4, K.glow], [1.22, 20, .1, 1.4, K.tealL], [.16, 26, .1, 1.4, K.glow],
    [0, 28.6, 1.6, 1.2, K.bambooD]] },
};
