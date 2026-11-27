const K = {
  bamboo: '#b8a45a', bambooD: '#8a7a3a', bambooL: '#d8c87a', rope: '#c8ae78', ropeD: '#8a7450',
  teal: '#2f8a86', tealD: '#1f5e5c', tealL: '#5fb8b0', coco: '#7a5232', cocoL: '#a8784a', leaf: '#5a9a3a', leafL: '#8ac05a',
  glass: '#2a2e3a', glassL: '#4a5468', glassG: '#6a7a9a', iron: '#4a4e58', ironL: '#7a808e', ironD: '#2e3038', ember: '#f08a3a', emberL: '#ffd070',
  ebony: '#3a3430', ebonyL: '#5a524a', bark: '#6e4a30', barkL: '#9a6e48', ink: '#2a2a3a', inkL: '#4a4a62', clay: '#8a6a5a', clayL: '#a88a78',
  yak: '#d8cfc0', yakD: '#a89a88', yakL: '#efe8dc', fRed: '#c8382e', fBlue: '#3f6fb5', fGreen: '#3f8a5a', fYellow: '#e0b43a',
  indigo: '#2c3466', indigoL: '#4a5494', gold: '#d8b25a', goldL: '#f0d488', light: '#bfe8ff', lightL: '#eaf8ff',
  lac: '#a8452a', lacD: '#7a2e1c', lotus: '#e898a8', lotusL: '#f6c8d0', pad: '#4f8a4a', padL: '#7ab06a', cream: '#f1e8d4',
};

export const HW_FUR = {
  hw_pado_bench: { name: '물너울 대 평상', grade: 1, W: 2, D: 1, layer: 'floor', cat: '좌석·탁자', top: .34, parts: [
    { x: .08, y: .14, w: .1, d: .1, h: .3, c: K.bambooD }, { x: 1.82, y: .14, w: .1, d: .1, h: .3, c: K.bambooD },
    { x: .08, y: .76, w: .1, d: .1, h: .3, c: K.bambooD }, { x: 1.82, y: .76, w: .1, d: .1, h: .3, c: K.bambooD },
    { x: .04, y: .1, w: 1.92, d: .8, h: .04, z: .3, c: K.bamboo },
    { x: .04, y: .22, w: 1.92, d: .03, h: .01, z: .34, c: K.bambooD }, { x: .04, y: .42, w: 1.92, d: .03, h: .01, z: .34, c: K.bambooD },
    { x: .04, y: .62, w: 1.92, d: .03, h: .01, z: .34, c: K.bambooD }, { x: .04, y: .82, w: 1.92, d: .03, h: .01, z: .34, c: K.bambooD },
    { x: .04, y: .1, w: 1.92, d: .04, h: .04, z: .3, c: K.bambooL },
    { x: .3, y: .1, w: .06, d: .8, h: .02, z: .34, c: K.rope }, { x: 1.64, y: .1, w: .06, d: .8, h: .02, z: .34, c: K.rope },
    { x: .5, y: .3, w: .7, d: .4, h: .02, z: .35, c: K.tealD }, { x: .54, y: .34, w: .62, d: .32, h: .01, z: .37, c: K.teal },
    { x: .58, y: .38, w: .54, d: .03, h: .01, z: .38, c: K.tealL }, { x: .58, y: .58, w: .54, d: .03, h: .01, z: .38, c: K.tealL },
    { t: 'ell', x: 1.44, y: .5, z: .42, rx: 4, ry: 3, c: K.coco }, { t: 'ell', x: 1.44, y: .48, z: .46, rx: 2, ry: 1.5, c: K.cocoL }] },
  hw_bulssi_lamp: { name: '화산 유리 등잔대', grade: 2, W: 1, D: 1, layer: 'floor', cat: '조명', parts: [
    { x: .3, y: .3, w: .4, d: .4, h: .06, c: K.ironD }, { x: .34, y: .34, w: .32, d: .32, h: .02, z: .06, c: K.iron },
    { x: .46, y: .46, w: .08, d: .08, h: .56, z: .08, c: K.iron }, { x: .47, y: .47, w: .03, d: .03, h: .56, z: .08, c: K.ironL },
    { x: .4, y: .4, w: .2, d: .2, h: .04, z: .62, c: K.ironD },
    { x: .3, y: .3, w: .4, d: .4, h: .16, z: .66, c: K.glass }, { x: .3, y: .3, w: .4, d: .04, h: .16, z: .66, c: K.glassG },
    { x: .3, y: .3, w: .04, d: .4, h: .16, z: .66, c: K.glassL }, { x: .3, y: .3, w: .4, d: .4, h: .02, z: .82, c: K.glassG },
    { x: .38, y: .38, w: .24, d: .24, h: .02, z: .84, c: K.ironD },
    { x: .42, y: .42, w: .16, d: .16, h: .1, z: .86, c: K.ember }, { x: .46, y: .46, w: .08, d: .08, h: .12, z: .9, c: K.emberL }] },
  hw_nunmaru_rug: { name: '털소 털 오색 깔개', grade: 2, W: 2, D: 2, layer: 'rug', cat: '깔개', parts: [
    { x: .1, y: .1, w: 1.8, d: 1.8, h: .02, c: K.yakD }, { x: .16, y: .16, w: 1.68, d: 1.68, h: .02, z: .01, c: K.yak },
    { x: .3, y: .3, w: 1.4, d: 1.4, h: .01, z: .03, c: K.yakL },
    { x: .16, y: .3, w: 1.68, d: .1, h: .01, z: .04, c: K.fBlue }, { x: .16, y: .5, w: 1.68, d: .1, h: .01, z: .04, c: K.fRed },
    { x: .16, y: 1.4, w: 1.68, d: .1, h: .01, z: .04, c: K.fGreen }, { x: .16, y: 1.6, w: 1.68, d: .1, h: .01, z: .04, c: K.fYellow },
    { x: .8, y: .8, w: .4, d: .4, h: .01, z: .04, c: K.fRed }, { x: .9, y: .9, w: .2, d: .2, h: .01, z: .05, c: K.yakL },
    { x: .04, y: .2, w: .06, d: 1.6, h: .01, c: K.yakD }, { x: 1.9, y: .2, w: .06, d: 1.6, h: .01, c: K.yakD }] },
  hw_haeoreum_table: { name: '연꽃 등잔 낮은 상', grade: 3, W: 1, D: 1, layer: 'floor', cat: '좌석·탁자', top: .3, parts: [
    { x: .12, y: .12, w: .08, d: .08, h: .26, c: K.lacD }, { x: .8, y: .12, w: .08, d: .08, h: .26, c: K.lacD },
    { x: .12, y: .8, w: .08, d: .08, h: .26, c: K.lacD }, { x: .8, y: .8, w: .08, d: .08, h: .26, c: K.lacD },
    { x: .06, y: .06, w: .88, d: .88, h: .06, z: .24, c: K.lac }, { x: .06, y: .06, w: .88, d: .88, h: .01, z: .3, c: K.lacD },
    { x: .06, y: .06, w: .88, d: .03, h: .06, z: .24, c: K.gold }, { x: .06, y: .91, w: .88, d: .03, h: .06, z: .24, c: K.gold },
    { t: 'ell', x: .5, y: .5, z: .32, rx: 8, ry: 4, c: K.pad }, { t: 'ell', x: .5, y: .5, z: .33, rx: 5, ry: 2.5, c: K.padL },
    { t: 'ell', x: .44, y: .48, z: .36, rx: 2.4, ry: 1.6, c: K.lotus }, { t: 'ell', x: .56, y: .48, z: .36, rx: 2.4, ry: 1.6, c: K.lotus },
    { t: 'ell', x: .5, y: .44, z: .38, rx: 2.4, ry: 1.6, c: K.lotusL }, { t: 'ell', x: .5, y: .54, z: .36, rx: 2.4, ry: 1.6, c: K.lotus },
    { x: .47, y: .47, w: .06, d: .06, h: .08, z: .38, c: K.cream }, { x: .48, y: .48, w: .04, d: .04, h: .05, z: .46, c: K.emberL }] },
};

export const HW_WALL = {
  hw_jaebit_shelf: { name: '먹비 사발 선반', grade: 1, kind: 'deco', cat: '수납', w: 1.6, h: 26, rects: [
    [.5, 17, .04, 9, K.rope], [1.06, 17, .04, 9, K.rope], [.42, 25, .2, 1, K.ropeD], [.98, 25, .2, 1, K.ropeD],
    [0, 15.4, 1.6, 1.6, K.ebony], [0, 16.4, 1.6, .6, K.ebonyL], [.1, 5.6, .1, 9.8, K.bark], [1.4, 5.6, .1, 9.8, K.bark],
    [0, 4, 1.6, 1.6, K.ebony], [0, 5, 1.6, .6, K.ebonyL], [.1, 1, .1, 3, K.bark], [1.4, 1, .1, 3, K.bark],
    [.2, 17, .44, 3.6, K.clay], [.2, 20, .44, .6, K.clayL], [.28, 19.2, .28, .8, K.ink],
    [.78, 17, .36, 3, K.clay], [.78, 19.4, .36, .6, K.clayL], [.84, 18.8, .24, .6, K.inkL],
    [1.2, 17, .16, 5, K.leaf], [1.3, 17, .12, 6.4, K.leafL],
    [.22, 5.6, .52, 3.8, K.clay], [.22, 8.8, .52, .6, K.clayL], [.3, 8, .36, .8, K.ink], [.36, 8.2, .12, .4, K.inkL],
    [.9, 5.6, .4, 2.4, K.bark], [.9, 7.6, .4, .4, K.barkL]] },
  hw_dalmaji_lamp: { name: '고인 빛 달등', grade: 3, kind: 'deco', cat: '조명', w: .9, h: 30, rects: [
    [.43, 24, .04, 6, K.gold], [.3, 28.6, .3, .6, K.goldL],
    [.12, 21.6, .66, 2.4, K.indigo], [.12, 23.4, .66, .6, K.gold],
    [.06, 8, .78, 13.6, K.indigoL], [.12, 9, .66, 11.6, K.light], [.2, 10, .5, 9.6, K.lightL],
    [.06, 8, .08, 13.6, K.indigo], [.76, 8, .08, 13.6, K.indigo], [.06, 14.4, .78, .5, K.gold],
    [.34, 12, .22, 5, K.goldL], [.4, 13, .1, 3, '#ffffff'],
    [.12, 5.6, .66, 2.4, K.indigo], [.12, 5.6, .66, .6, K.gold],
    [.4, 2, .1, 3.6, K.gold], [.32, 0, .26, 2, K.lotus], [.38, .4, .14, 1, K.lotusL]] },
};
