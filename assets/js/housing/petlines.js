const GROUP = { ward: 'guard', shell: 'guard', giant: 'guard', shadow: 'bite', breaker: 'bite', wood: 'bite', bird: 'peck', sky: 'peck', ghost: 'charm', water: 'charm', venom: 'charm', swarm: 'charm', mirror: 'charm' };
export const CAPS = { pat: 5, play: 3, feed: 3 };
const BODY = {
  ash_longhair: 'ear fur soft warm land mouth beast paw claw tail',
  baby_baektaek: 'ear fur soft warm land mouth beast paw claw tail',
  baby_boar: 'ear fur soft warm land mouth beast tail',
  baby_bulgasari: 'ear fur soft warm land mouth beast paw claw tail',
  baby_crab: 'land',
  baby_crane: 'soft warm land beak wing fly tail',
  baby_croc: 'land mouth tail',
  baby_crow: 'soft warm land beak wing fly tail',
  baby_elephant: 'ear soft warm land mouth beast tail',
  baby_girin: 'ear soft warm land mouth beast tail',
  baby_gumiho: 'ear fur soft warm land mouth beast paw claw tail fade',
  baby_haetae: 'ear fur soft warm land mouth beast paw claw tail',
  baby_jangsanbeom: 'ear fur soft warm land mouth beast paw claw tail',
  baby_otter: 'ear fur soft warm land mouth beast paw claw tail',
  baby_owl: 'soft warm land beak wing fly tail',
  baby_pangolin: 'land mouth beast claw tail curl',
  baby_salamander: 'land tail curl',
  baby_sangun: 'ear fur soft warm land mouth beast paw claw tail',
  baby_scorpion: 'land tail',
  baby_tapir: 'ear fur soft warm land mouth beast tail',
  baby_turtle: 'land mouth tail',
  baby_whale: 'soft warm mouth',
  baby_white_bear: 'ear fur soft warm land mouth beast paw claw tail',
  bead_imugi: 'mouth tail curl float glow',
  bee_trio: 'fly float',
  cheese_cat: 'ear fur soft warm land mouth beast paw claw tail',
  cracked_jar: '',
  ddonggae: 'ear fur soft warm land mouth beast paw claw tail bark',
  dokkaebi_fire: 'float glow warm fade',
  dragonfly: 'fly float',
  egg_ghost: 'float fade',
  empty_helm: '',
  firefly_spirit: 'fly float glow fade',
  golden_wingwolf: 'ear fur soft warm land mouth beast paw claw tail',
  goldfish: 'float',
  gwiheo_butterfly: 'fly float glow',
  hare: 'ear fur soft warm land mouth beast paw claw tail',
  hermit_crab: 'land',
  ink_cat: 'ear fur soft warm land mouth beast paw claw tail',
  ladybug: 'land fly',
  lantern_spirit: 'float glow warm',
  little_cheongryong: 'mouth paw claw tail curl float',
  little_dokkaebi: 'warm land mouth fade',
  little_ferret: 'ear fur soft warm land mouth beast paw claw tail',
  little_hawk: 'soft warm land beak wing fly tail',
  little_hongryong: 'warm land mouth paw claw tail',
  little_jangseung: 'land',
  little_raccoon: 'ear fur soft warm land mouth beast paw claw tail fade',
  little_toad: 'land mouth',
  magpie: 'soft warm land beak wing fly tail',
  mantis: 'land',
  mask_spirit: 'float fade',
  moon_rabbit: 'ear fur soft warm land mouth beast paw tail glow',
  neun_puppy: 'ear fur soft warm land mouth beast paw claw tail bark',
  nureong_puppy: 'ear fur soft warm land mouth beast paw claw tail bark',
  onehorn_goat: 'ear fur soft warm land mouth beast tail',
  ox_calf: 'ear fur soft warm land mouth beast tail',
  paper_doll: 'float',
  pill_bug: 'land curl',
  pink_pomeranian: 'ear fur soft warm land mouth beast paw claw tail bark',
  platypus: 'fur soft warm land mouth paw claw tail',
  poison_mushroom: '',
  rhino_beetle: 'land',
  roe_fawn: 'ear fur soft warm land mouth beast tail',
  samjogo_chick: 'soft warm land beak wing fly glow',
  silver_afghan: 'ear fur soft warm land mouth beast paw claw tail bark',
  snow_tit: 'soft warm land beak wing fly tail',
  sparrow: 'soft warm land beak wing fly tail',
  spotted_cat: 'ear fur soft warm land mouth beast paw claw tail',
  spotted_glider: 'ear fur soft warm land mouth beast paw claw tail',
  spotted_seal: 'soft warm land mouth beast curl',
  squirrel: 'ear fur soft warm land mouth beast paw claw tail',
  thunder_cloud: 'float fade',
  tree_frog: 'land',
  tuxedo_cat: 'ear fur soft warm land mouth beast paw claw tail',
  white_puppy: 'ear fur soft warm land mouth beast paw claw tail bark',
  white_rabbit: 'ear fur soft warm land mouth beast paw claw tail',
  wooden_doll: 'land'
};

const L = {
  pat: {
    any: [
      '{n}의 머리를 살살 쓰다듬어 주었습니다. 눈이 가늘게 감깁니다.',
      '{n}이(가) 손바닥에 이마를 꾹 밀어붙입니다.',
      ['{n}의 등을 쓸어 주자 몸이 녹아내리듯 늘어집니다.', 'soft'],
      ['귀 뒤를 긁어 주었더니 {n}이(가) 고개를 갸웃 기울여 더 내밉니다.', 'ear'],
      '{n}이(가) 쓰다듬는 손을 따라 몸을 빙그르르 돌립니다.',
      ['턱 밑을 간질여 주자 {n}이(가) 조그맣게 재채기를 했습니다.', 'beast'],
      ['{n}이(가) 손가락 하나를 꼭 붙들고 놓아주지 않습니다.', 'paw'],
      ['{n}의 몸이 따뜻합니다. 방금까지 햇볕 드는 자리에 있었나 봅니다.', 'warm'],
      '쓰다듬는 손이 멈추자 {n}이(가) 아쉽다는 듯 올려다봅니다.',
      ['{n}이(가) 기분 좋은 소리를 내며 무릎 위로 기어오릅니다.', 'land'],
      '정수리를 톡톡 두드려 주자 {n}이(가) 의젓하게 가슴을 폅니다.',
      ['{n}의 털끝에 먼지가 하나 붙어 있어 떼어 주었습니다.', 'fur']
    ],
    guard: [
      ['{n}이(가) 쓰다듬는 사이에도 문 쪽에 한쪽 귀를 세워 둡니다.', 'ear'],
      '{n}이(가) 발치에 철퍼덕 앉아 든든하게 기댑니다.',
      '등을 쓸어 주자 {n}이(가) 꼬리인지 몸통인지 모를 것을 마구 흔듭니다.',
      '{n}이(가) 배를 드러내고 눕습니다. 지킬 것은 다 지켰다는 얼굴입니다.',
      '단단한 등을 두드려 주자 {n}이(가) 묵직하게 몸을 기울여 옵니다.'
    ],
    bite: [
      ['{n}이(가) 쓰다듬는 손가락을 앙 물었다가, 아프지 않게 놓아줍니다.', 'mouth'],
      ['{n}이(가) 손등에 볼을 비비며 냄새를 묻혀 둡니다.', 'beast'],
      ['쓰다듬자 {n}이(가) 기지개를 길게 켜고 발톱을 쫙 폈다 오므립니다.', 'claw'],
      '{n}이(가) 손 밑으로 고개를 쏙 집어넣습니다. 더 하라는 뜻입니다.',
      ['{n}이(가) 코를 킁킁대며 소매 안쪽 냄새까지 확인합니다.', 'beast']
    ],
    peck: [
      ['{n}이(가) 손가락을 콕콕 쪼더니 그 위에 폴짝 올라앉습니다.', 'beak'],
      ['깃털을 결대로 쓸어 주자 {n}이(가) 날개를 반쯤 펴고 부풀립니다.', 'wing'],
      '{n}이(가) 목덜미를 쓰다듬는 손에 고개를 파묻습니다.',
      '{n}이(가) 고개를 갸웃갸웃 기울이며 한쪽 눈으로 이쪽을 봅니다.',
      ['{n}이(가) 기분이 좋은지 짧게 지저귀었습니다.', 'beak']
    ],
    charm: [
      '{n}을(를) 쓰다듬은 손바닥에 서늘한 기운이 잠깐 남습니다.',
      ['{n}이(가) 손 아래에서 살짝 흐려졌다가 다시 또렷해집니다.', 'fade'],
      ['쓰다듬자 {n}의 둘레가 은은하게 빛납니다.', 'glow'],
      ['{n}이(가) 손가락 끝을 감싸듯 둥글게 몸을 맙니다.', 'curl'],
      '{n}이(가) 이쪽 손 그림자 속으로 쏙 숨어 버립니다.'
    ]
  },
  play: {
    any: [
      ['{n}와(과) 방 안을 한 바퀴 뛰어다녔습니다. 둘 다 숨이 찹니다.', 'land'],
      ['실 뭉치를 굴려 주자 {n}이(가) 정신없이 쫓아갑니다.', 'land'],
      '{n}와(과) 숨바꼭질을 했습니다. 늘 같은 자리에 숨습니다.',
      ['{n}이(가) 놀잇감을 물어다 발 앞에 툭 떨어뜨립니다. 한 번 더, 라는 뜻입니다.', 'mouth'],
      '{n}이(가) 제 꼬리, 아니면 그 비슷한 것을 쫓아 빙빙 돕니다.',
      ['방석을 들췄다 놓았다 하자 {n}이(가) 그 밑으로 뛰어들었습니다.', 'land'],
      '{n}와(과) 굴러다니다 보니 머리에 지푸라기가 붙었습니다.',
      ['{n}이(가) 신이 나서 방 끝까지 달려갔다가 혼자 놀라 돌아옵니다.', 'land'],
      ['{n}이(가) 놀다 말고 갑자기 멈추더니, 다시 아무 일 없다는 듯 뜁니다.', 'land'],
      '공을 던지자 {n}이(가) 공보다 먼저 굴러갔습니다.',
      '{n}와(과) 눈싸움을 했습니다. 먼저 하품한 쪽이 졌습니다.',
      '{n}이(가) 놀잇감을 품에 안고 데굴데굴 구릅니다.'
    ],
    guard: [
      '{n}이(가) 놀잇감을 지키겠다는 듯 그 위에 턱 엎드립니다.',
      ['줄다리기를 했더니 {n}이(가) 끝까지 버텨 이겼습니다.', 'mouth'],
      ['{n}이(가) 방 귀퉁이마다 들러 냄새를 맡고, 다 괜찮다며 돌아옵니다.', 'beast'],
      ['{n}이(가) 놀다가 문밖 소리에 벌떡 일어나 한 번 짖고 다시 놉니다.', 'bark'],
      ['{n}이(가) 묵직하게 뛰어오를 때마다 바닥이 쿵 울립니다.', 'land']
    ],
    bite: [
      ['{n}이(가) 몸을 낮추고 엉덩이를 씰룩이더니 놀잇감에 덮칩니다.', 'paw'],
      ['{n}이(가) 흔드는 끈을 앞발로 쳐서 낚아챘습니다.', 'paw'],
      ['{n}이(가) 놀잇감을 물고 흔들다가 저 멀리 던져 버렸습니다.', 'mouth'],
      '{n}이(가) 그림자를 사냥감으로 여기고 한참을 노려봅니다.',
      '{n}이(가) 높은 곳에 올라가 내려다보며 다음 놀이를 고릅니다.'
    ],
    peck: [
      ['{n}이(가) 팔랑 날아올라 머리 위를 두 바퀴 돌고 내려앉습니다.', 'fly'],
      ['{n}이(가) 반짝이는 단추를 쪼아 굴리며 놉니다.', 'beak'],
      ['휘파람을 불자 {n}이(가) 똑같은 가락으로 따라 붑니다.', 'beak'],
      ['{n}이(가) 날개를 퍼덕이며 횃대와 어깨 사이를 오갑니다.', 'wing'],
      '{n}이(가) 놀잇감을 높은 데 숨겨 두고 자랑스러워합니다.'
    ],
    charm: [
      '{n}이(가) 방 안 불빛을 하나씩 건드리며 노닙니다.',
      ['{n}이(가) 손뼉 소리에 맞춰 둥실 떠올랐다 내려옵니다.', 'float'],
      '{n}이(가) 손가락으로 그린 동그라미를 따라 빙글 돕니다.',
      '{n}이(가) 보이지 않는 무언가와 술래잡기를 합니다. 즐거워 보입니다.',
      '{n}이(가) 방 안에 작은 물결 같은 흔들림을 남기며 오갑니다.'
    ]
  },
  feed: {
    any: [
      '{n}이(가) 먹이를 오물오물 먹습니다.',
      '{n}이(가) 그릇에 코를 박고 열심히 먹습니다.',
      '{n}이(가) 한 입 먹을 때마다 이쪽을 한 번씩 봅니다.',
      '{n}이(가) 먹이를 조금 남겨 두었다가 나중에 먹으려고 숨깁니다.',
      ['{n}이(가) 그릇을 깨끗이 핥아 비웠습니다.', 'beast'],
      '{n}이(가) 먹이 냄새를 먼저 오래 맡고 나서야 먹기 시작합니다.',
      '배가 부른지 {n}이(가) 먹다 말고 꾸벅 졸았습니다.',
      '{n}이(가) 먹이 부스러기를 바닥에서 하나하나 주워 먹습니다.'
    ],
    guard: [['{n}이(가) 그릇을 앞발로 꼭 붙들고 먹습니다. 아무도 안 뺏는데도요.', 'paw'], '{n}이(가) 먹이를 한입에 넣고 우물우물 오래 씹습니다.', '{n}이(가) 다 먹고 나서 그릇 옆에 든든하게 엎드립니다.'],
    bite: [['{n}이(가) 먹이를 물고 구석으로 가서 몰래 먹습니다.', 'mouth'], ['{n}이(가) 먹이를 앞발로 툭 쳐서 굴려 본 뒤 먹습니다.', 'paw'], '{n}이(가) 먹고 나서 입가를 꼼꼼히 닦습니다.'],
    peck: [['{n}이(가) 먹이를 콕콕 쪼아 작게 나눠 먹습니다.', 'beak'], ['{n}이(가) 한 알씩 물고 고개를 젖혀 꿀꺽 삼킵니다.', 'beak'], ['{n}이(가) 먹이를 물고 횃대로 날아가 먹습니다.', 'fly']],
    charm: ['먹이가 {n}의 둘레에서 스르르 사라졌습니다. 맛있게 먹은 모양입니다.', '{n}이(가) 먹이를 먹자 몸빛이 조금 밝아졌습니다.', '{n}이(가) 먹이를 먹는 동안 방 안 공기가 살짝 따뜻해졌습니다.']
  }
};
const LIKED = [
  '{n}이(가) 좋아하는 별미입니다! 눈이 동그래지더니 단숨에 먹어 치웠습니다.',
  ['{n}이(가) 별미 냄새만 맡고도 제자리에서 폴짝 뛰었습니다.', 'land'],
  ['{n}이(가) 좋아하는 맛을 기억했습니다. 다 먹고 손을 한참 핥습니다.', 'beast'],
  '{n}이(가) 별미를 아껴 먹느라 아주 천천히 씹습니다.',
  '{n}이(가) 좋아하는 별미에 꼬리 같은 것을 쉴 새 없이 흔듭니다.',
  '{n}이(가) 별미를 다 먹고 빈 그릇을 이쪽으로 밀어 옵니다.'
];
const STAGE = {
  baby: ['아직 낯을 조금 가리는 {n}이(가) 살금살금 다가옵니다.', '{n}이(가) 작은 몸으로 있는 힘껏 반가워합니다.', ['{n}이(가) 아직 서툰 걸음으로 뒤뚱뒤뚱 따라옵니다.', 'land']],
  adult: ['다 자란 {n}이(가) 이제는 먼저 다가와 기다립니다.', '{n}이(가) 익숙한 손길을 알아보고 편하게 몸을 맡깁니다.', '{n}이(가) 의젓하게 앉아 차례를 기다립니다.'],
  full: ['{n}이(가) 어디를 가든 졸졸 따라다닙니다. 둘도 없는 사이가 되었습니다.', '{n}이(가) 눈빛만으로도 무엇을 원하는지 알아듣는 것 같습니다.', '{n}이(가) 곁에 있으면 마음이 놓이는지 금세 잠이 듭니다.']
};
const GUEST = [
  '{n}이(가) 낯선 손님을 잠깐 살피더니 이내 몸을 맡깁니다.',
  ['{n}이(가) 손님 냄새를 한참 맡고 나서야 꼬리를 흔듭니다.', 'tail'],
  '주인이 아닌 손길에도 {n}이(가) 의젓하게 굽니다.',
  ['{n}이(가) 손님 소매 끝을 살짝 물고 놀자고 조릅니다.', 'mouth'],
  '{n}이(가) 손님을 문 앞까지 배웅하려는 듯 따라 나섭니다.'
];
const LAST = {
  pat: ['오늘은 실컷 쓰다듬어 주었습니다. {n}이(가) 아주 만족한 얼굴입니다.', '{n}이(가) 오늘 받을 사랑은 다 받았다는 듯 배를 깔고 눕습니다.'],
  play: ['오늘은 실컷 놀았습니다. {n}이(가) 놀잇감을 품고 쉬러 갑니다.', '{n}이(가) 놀다 지쳐 그 자리에서 잠들어 버렸습니다.'],
  feed: ['오늘 먹이는 이걸로 넉넉합니다. {n}의 배가 동그랗습니다.', '{n}이(가) 배를 두드리며 더는 못 먹겠다는 얼굴입니다.']
};
const OVER = {
  pat: ['{n}이(가) 이미 실컷 쓰다듬어 받아서 졸린 눈을 끔뻑입니다.', ['{n}이(가) 고맙다는 듯 손끝을 한 번 핥고 다시 쉽니다.', 'beast']],
  play: [['{n}이(가) 오늘은 너무 놀아서 귀만 살짝 움직입니다.', 'ear'], '{n}이(가) 놀잇감을 슬쩍 보고는 내일 하자는 듯 고개를 돌립니다.'],
  feed: ['{n}이(가) 냄새만 맡고 고개를 젓습니다. 오늘은 배가 부릅니다.', '{n}이(가) 먹이를 아껴 둘 셈인지 그릇 옆에 숨겨 둡니다.']
};

let lastLine = '';
const fits = (x, has) => typeof x === 'string' || has.includes(x[1]);
const textOf = x => typeof x === 'string' ? x : x[0];
const pick = (arr, has) => {
  const ok = arr.filter(x => fits(x, has)).map(textOf), base = ok.length ? ok : arr.filter(x => typeof x === 'string');
  const pool = base.filter(x => x !== lastLine);
  const s = (pool.length ? pool : base)[Math.floor(Math.random() * (pool.length || base.length))];
  lastLine = s; return s;
};

export function petLine(act, { id, name, kind, affinity = 0, liked = false, guest = false, gain = 1, count = 0 } = {}) {
  const lines = L[act] || L.pat, g = GROUP[kind], has = (BODY[id] ?? 'ear fur soft warm land mouth beast paw claw tail').split(' ');
  let pool;
  if (gain <= 0) pool = OVER[act] || OVER.pat;
  else if (count && count >= (CAPS[act] || 99) && Math.random() < 0.6) pool = LAST[act] || LAST.pat;
  else if (act === 'feed' && liked && Math.random() < 0.7) pool = LIKED;
  else if (guest && Math.random() < 0.35) pool = GUEST;
  else if (Math.random() < 0.15) pool = STAGE[affinity >= 300 ? 'full' : affinity >= 100 ? 'adult' : 'baby'];
  else pool = [...lines.any, ...((g && lines[g]) || []), ...((g && lines[g]) || [])];
  return pick(pool, has).replaceAll('{n}', name || '꼬마 동무');
}
