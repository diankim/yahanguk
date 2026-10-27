// 현장 머리 배경: 장소(테마)마다 다른 전경 실루엣 + 시간대의 해·달 + 날씨 덧그림.
// 모두 평면 도형(그라데이션·그림자·흐림 없음)이고, 색은 장소 색(--sc)을 바탕에 옅게 섞어 글자 가독성을 해치지 않는다.
const VB = '0 0 400 140';

// 먼 층(far)·가까운 층(near) 실루엣. 좌표는 400×140 기준, 아래쪽에 붙는다.
const LAND = {
  city: {
    far: 'M0 140V96h18v-8h10v8h22V82l14-10 14 10v14h20V90h30v6h16V78l8-6 8 6v18h26V86h22v10h18V74l12-9 12 9v22h24V88h26v8h16v-6h22v50z',
    near: 'M0 140v-22c22-1 34-9 48-18 14 9 26 17 48 18v22zM120 140v-26c26-1 40-11 56-21 16 10 30 20 56 21v26zM256 140v-20c20-1 32-8 44-16 12 8 24 15 44 16v20zM352 140v-24c18 0 28-8 40-15l8 4v35z',
    extra: '<g class="ln-accent"><rect x="70" y="104" width="4" height="8" rx="2"/><rect x="186" y="100" width="4" height="8" rx="2"/><rect x="300" y="108" width="4" height="8" rx="2"/></g>',
  },
  wild: {
    far: 'M0 140v-40c40-14 70-16 110-6s74 8 110-4 80-14 110-2 50 8 70 2v50z',
    near: 'M0 140v-18c30-8 60-10 96-4s70 2 100-6 70-6 104 2 70 4 100-2v28zM300 118l14-34 14 34zM318 118l10-26 10 26zM60 124l12-30 12 30zM78 124l9-22 9 22z',
  },
  shrine: {
    far: 'M0 140v-34c50-10 90-12 140-4s100 6 150-4 80-8 110 0v42z',
    near: 'M228 140v-46h6v46zM300 140v-46h6v46zM218 96h98v-6h-98zM224 104h86v-4h-86zM248 140v-22h30v22zM240 118l23-14 23 14z',
    extra: '<g class="ln-accent"><path d="M218 90h98v4h-98z"/></g>',
  },
  water: {
    far: 'M0 108l40-20 30 12 40-26 50 30 40-14 40 18 46-24 44 22 30-8 40 14v6z',
    near: 'M0 140v-28h400v28z',
    extra: '<g class="ln-water"><path d="M20 120h40M120 126h56M230 118h44M320 128h50" /></g><g class="ln-near"><path d="M330 112l2-24 2 24zM338 112l3-30 3 30zM348 112l2-20 2 20zM262 116h40l-6 6h-28z"/></g>',
  },
  mountain: {
    far: 'M0 140v-30l50-40 40 30 50-56 60 48 40-26 60 44 50-36 50 30v36z',
    near: 'M0 140v-14l70-34 60 28 70-40 80 36 60-22 60 28v18z',
  },
  desert: {
    far: 'M0 140v-24c60-18 120-20 180-8s120 10 220-6v38z',
    near: 'M0 140v-10c80-14 150-14 230-4s120 6 170-2v16zM300 118v-30h3v30zM301 96l-14-10 2-2 12 8zM302 100l12-12 2 2-14 12z',
  },
  deep: {
    far: 'M0 0h400v14l-16 22-10-20-14 30-12-24-18 18-14-26-20 34-12-24-16 16-14-22-18 30-12-24-20 20-10-26-18 22-12-18-16 26-14-24-20 18-12-20-16 26-12-20-18 18-10-14-14 20-12-16-16 22-10-18-14 14z',
    near: 'M0 140v-20l20-14 16 10 20-22 22 18 18-8 24 16h40l18-14 22 12 26-20 20 16 30-10 24 14 30-18 22 14 28-10 20 16v20z',
  },
  sky: {
    far: 'M0 140v-24c40-6 80-8 120-2s70 4 100-4l60-20 60 14 60-6v42z',
    near: 'M268 112v-28h28v28zM262 86h40l-20-18zM279 66v-10h6v10zM250 140v-28h64v28z',
  },
};
LAND.default = LAND.wild;

// 해·달: 오른쪽 위(글자는 왼쪽 위에 있다)
function sky(phase, weather) {
  const dim = ['cloudy', 'rain', 'fog', 'snow', 'bloodmist'].includes(weather);
  if (phase === 'night') return `<g class="sk-moon ${dim ? 'dim' : ''}"><circle cx="350" cy="44" r="13"/><circle cx="356" cy="40" r="11" class="sk-cut"/></g>`;
  if (dim) return '';
  if (phase === 'noon') return '<circle class="sk-sun" cx="340" cy="40" r="10"/>';
  if (phase === 'dawn' || phase === 'dusk') return `<circle class="sk-sun low" cx="${phase === 'dawn' ? 330 : 360}" cy="78" r="16"/>`;
  return '';
}

export function sceneArt(theme, phase, weather) {
  const L = LAND[theme] || LAND.default;
  return `<svg class="scene-art" viewBox="${VB}" preserveAspectRatio="xMaxYMax slice" aria-hidden="true" focusable="false">
    ${sky(phase, weather)}
    <path class="ln-far" d="${L.far}"/>
    ${L.near ? `<path class="ln-near" d="${L.near}"/>` : ''}
    ${L.extra || ''}
  </svg>`;
}
