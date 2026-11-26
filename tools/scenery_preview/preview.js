const q = new URLSearchParams(location.search);
const src = (await (await fetch('/assets/js/scenery.js')).text()).replace(/^import \{ store \} from .*$/m, 'const store = {};');
const { sceneArt } = await import(URL.createObjectURL(new Blob([src], { type: 'text/javascript' })));
const NAME = { pado: '파도너울성', bulssi: '불씨들녘', jaebit: '잿빛그늘숲', nunmaru: '눈마루', dalmaji: '달맞이성', goimteo: '고임터', haeoreum: '해오름성' };
const realm = q.get('realm') || 'pado', themes = (q.get('themes') || 'water').split(','), phase = q.get('phase') || 'noon', weather = q.get('w') || 'clear';
document.getElementById('out').innerHTML = themes.map(t => `<div class="row"><h2>${NAME[realm] || realm} · ${t}</h2>
  <div class="scene theme-${t}"><div class="scene-fx" aria-hidden="true" data-w="${weather}" data-p="${phase}" data-t="${t}">${sceneArt(t, phase, weather, null, realm)}<i class="fx-veil"></i><i class="fx-a"></i><i class="fx-b"></i><i class="fx-c"></i></div>
  <span class="frame-c" aria-hidden="true"><i></i><i></i><i></i><i></i></span>
  <div class="scene-top"><p class="eyebrow">${NAME[realm] || realm}</p><h1>현장 머리 그림</h1><div class="env-slot"><span class="chip">한낮 · 청명</span></div><div class="chips"><span class="chip">위험 10</span><span class="chip">${t}</span></div></div><nav class="crumbs"><button>들머리</button><b>안쪽</b></nav></div></div>`).join('');
document.body.dataset.ready = '1';
