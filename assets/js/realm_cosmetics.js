const svg = (body, top = '') => `<svg class="pt-layer pt-scene" viewBox="0 0 400 200" preserveAspectRatio="xMidYMid slice" aria-hidden="true" focusable="false"><g transform="translate(0 42) scale(1 .58)">${body.replace(/<(path|circle)(?![^>]*sc-moon)/g, '<$1 vector-effect="non-scaling-stroke"')}</g>${top}</svg>`;

export const RB_SCENE = {
  pt_rb_pado: svg(`
    <path d="M-10 150C20 144 40 156 70 150S120 144 150 150S200 156 230 150S280 144 310 150S360 156 410 150M-10 172C30 166 60 178 100 172S170 166 210 172S280 178 320 172S380 166 410 172"/>
    <path d="M40 150V112M64 150V112M88 150V112M34 112h60l-30-22zM50 112v-10h28v10"/>
    <path d="M150 150V100M182 150V100M144 100h44l-22-18zM158 100V92h16v8"/>
    <path d="M300 150V118M330 150V118M354 150V118M294 118h66l-33-24zM320 118v-10h18v10"/>
    <path d="M94 128H144M188 124H294"/>
    <path d="M210 166c10 6 40 6 50 0M222 166l6-14h6l6 14"/><path d="M226 152v-16l14 10z"/>
    <path d="M110 184c8 5 30 5 38 0M366 186c6 4 22 4 28 0"/>`, `<path class="sc-moon" d="M340 62a11 11 0 1 0 0.1 0z"/>`),
  pt_rb_bulssi: svg(`
    <path d="M-10 160L60 150 110 96 140 78 160 82 190 100 250 150 410 160"/>
    <path d="M140 78c-6-14 4-22 0-34M160 82c8-14-2-24 4-38M150 46c10-6 18 4 28-2"/>
    <path d="M130 92l8 16-6 18M170 96l-6 18 10 20"/>
    <path d="M290 172h60l-6-10h-48zM306 162v-16h28v16M300 146h40l10-6H290z"/>
    <path d="M250 120l30 30M276 128l4-14 10 2"/>
    <path d="M30 184h120M-10 194h420"/>
    <g class="sc-ember"><circle cx="150" cy="30" r="1.8"/><circle cx="170" cy="20" r="1.2"/><circle cx="134" cy="24" r="1"/><circle cx="318" cy="128" r="1.6"/><circle cx="330" cy="116" r="1.2"/><circle cx="306" cy="120" r="1"/><circle cx="342" cy="132" r=".9"/></g>`),
  pt_rb_jaebit: svg(`
    <path d="M30 190V60M24 60c0-30 12-40 6-56M30 90l-20-14M30 120l22-16M372 190V40M372 70l-24-18M372 110l20-14"/>
    <path d="M90 40l-4 10M130 20l-4 10M170 52l-4 10M210 26l-4 10M250 48l-4 10M290 18l-4 10M330 60l-4 10M110 90l-4 10M190 96l-4 10M270 92l-4 10M150 130l-4 10M230 134l-4 10M310 124l-4 10M70 120l-4 10"/>
    <path d="M140 168c0-22 40-22 40 0zM160 146v34M160 180q-4 6-8 2"/>
    <path d="M220 172c0-16 30-16 30 0zM235 156v26"/>
    <path d="M-10 190C60 184 120 192 200 188S330 184 410 190"/>
    <path d="M80 176c6-8 14-8 18 0M96 176v12M300 178c5-7 12-7 16 0M308 178v10"/>`),
  pt_rb_nunmaru: svg(`
    <path d="M-10 170L60 96 96 124 150 54 196 100 240 70 300 132 340 104 410 160"/>
    <path d="M138 70l12-16 12 14M230 82l10-12 10 10M52 104l8-8 8 8"/>
    <path d="M10 60C80 80 150 84 220 74S340 50 400 64"/>
    <path d="M36 66v10l8-2zM66 73v10l8-2zM96 78v10l8-2zM126 80v10l8-2zM156 80v10l8-2zM186 78v10l8-2zM216 75v10l8-2zM246 70v10l8-2zM276 64v10l8-2zM306 59v10l8-2zM336 56v10l8-2zM366 57v10l8-2z"/>
    <path d="M40 190h60v-22H40zM46 168l24-14 24 14M64 190v-12h12v12"/>
    <path d="M300 190h56v-18h-56zM304 172l24-12 24 12"/>`, `<path class="sc-moon" d="M372 60a8 8 0 1 0 0.1 0z"/>`),
  pt_rb_dalmaji: svg(`
    <path d="M40 140v-30c0-22 40-22 40 0v30M60 88v-8M30 140h60"/>
    <path d="M150 140v-40c0-34 100-34 100 0v40M200 62v-10M140 140h120M176 140v-22c0-12 48-12 48 0v22"/>
    <path d="M320 140v-26c0-18 34-18 34 0v26M337 96v-6M312 140h50"/>
    <path d="M-10 140h420"/>
    <path d="M90 150h220M106 160h188M122 170h156M138 180h124M154 190h92"/>
    <path d="M196 190v-6h8v6"/>
    <circle cx="104" cy="126" r="1.2"/><circle cx="296" cy="126" r="1.2"/><circle cx="20" cy="30" r=".9"/><circle cx="380" cy="40" r=".9"/><circle cx="300" cy="22" r=".8"/>`, `<path class="sc-moon" d="M200 50a14 14 0 1 0 0.1 0z"/>`),
  pt_rb_haeoreum: svg(`
    <path d="M140 150h120M150 132h-24M250 132h24M160 112l-14-12M240 112l14-12M200 102V84"/>
    <path d="M40 150V96l12-14 12 14v54M52 82V60M34 120h36M30 150h44"/>
    <path d="M330 150v-70l16-20 16 20v70M346 60V30M322 104h48M318 150h56M334 126h24"/>
    <path d="M-10 150h420"/>
    <path d="M-10 166c30-4 60 4 90 0s60-4 90 0M230 168c30-4 60 4 90 0s60-4 90 0"/>
    <path d="M100 184c-8 0-12-6-12-10 6 0 10 4 12 8 2-4 6-8 12-8 0 4-4 10-12 10zM100 182v-10"/>
    <path d="M290 186c-8 0-12-6-12-10 6 0 10 4 12 8 2-4 6-8 12-8 0 4-4 10-12 10z"/>
    <path d="M150 182c8 4 24 4 32 0M240 184c8 4 20 4 26 0"/>`, `<path class="sc-moon" d="M178 129a22 22 0 0 1 44 0z"/>`),
};

export const RB_SEALS = { sl_rb_pado: '濤', sl_rb_bulssi: '鍛', sl_rb_jaebit: '蔭', sl_rb_nunmaru: '雪', sl_rb_dalmaji: '望', sl_rb_haeoreum: '旭' };
export const RB_SEAL_TIER = { sl_rb_pado: 'legend', sl_rb_bulssi: 'legend', sl_rb_jaebit: 'legend', sl_rb_nunmaru: 'legend', sl_rb_dalmaji: 'legend', sl_rb_haeoreum: 'legend' };
export const RB_NAME_STYLES = {
  1038: ['너울 비취', '파도너울성 권역 인연 비고에서 받으면'],
  1039: ['쇳물빛', '불씨들녘 권역 인연 비고에서 받으면'],
  1040: ['먹이끼', '잿빛그늘숲 권역 인연 비고에서 받으면'],
  1041: ['서릿마루', '눈마루 권역 인연 비고에서 받으면'],
  1042: ['보름 분홍', '달맞이성 권역 인연 비고에서 받으면'],
  1043: ['해오름빛', '해오름성 권역 인연 비고에서 받으면'],
};
