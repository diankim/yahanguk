// 성장 알림: 레벨·기능 숙련 단계·가방 칸처럼 캐릭터가 자랄 때마다 화면 위에 잠깐 떴다 사라지는 알림을 띄운다.
// 서버에서 다시 읽은 캐릭터(world_characters)를 지난 값과 비교한다. 지난 값은 이 기기에 캐릭터별로 남겨,
// 접속하지 않은 사이(원정·자율 활동 보상 등) 자란 것도 다음 접속 때 알린다.
import { on, store, esc, icon, fmt, xpNeed, LEVEL_CAP } from './core.js';

const RANKS = [['combat_rank', '전투 숙련'], ['investigation_rank', '조사 숙련'], ['gathering_rank', '채집 숙련'], ['crafting_rank', '제작 숙련']];
const keyOf = id => `yh-growth:${id}`;
let last = null, lastId = null, queue = [], showing = false;

const pick = c => ({ level: c.level || 1, stat_points: c.stat_points || 0, bag: c.bag_capacity || 0, ...Object.fromEntries(RANKS.map(([k]) => [k, c[k] || 1])) });

export function mountGrowth() {
  on('character', c => {
    if (!c?.owner_id || c.is_dead) return;
    if (lastId !== c.owner_id) {
      lastId = c.owner_id; last = null;
      try { last = JSON.parse(localStorage.getItem(keyOf(c.owner_id)) || 'null'); } catch {}
      // 처음 보는 캐릭터(새 기기)는 지금 값을 기준으로 삼는다
      if (!last) { save(c); return; }
    }
    const now = pick(c), was = last;
    if (now.level > was.level) {
      const pts = Math.max(0, now.stat_points - was.stat_points);
      notify('level', `레벨 업! Lv.${now.level}`, [pts ? `능력치 포인트 +${pts}` : '', (now.level >= LEVEL_CAP ? '최고 레벨에 이르렀습니다' : `다음 레벨까지 ${fmt.num(Math.max(0, xpNeed(now.level) - (c.experience || 0)))} 경험`)].filter(Boolean).join(' · '), '#/char/growth');
    }
    for (const [k, label] of RANKS) if (now[k] > was[k]) notify('rank', `${label} ${now[k]}단계`, '해당 활동의 효율이 좋아졌습니다.', '#/char/growth');
    if (now.bag > was.bag && was.bag) notify('bag', `가방이 넓어졌습니다`, `${fmt.num(was.bag)}칸 → ${fmt.num(now.bag)}칸`, '#/bag/items');
    save(c);
  });
}
function save(c) { last = pick(c); try { localStorage.setItem(keyOf(c.owner_id), JSON.stringify(last)); } catch {} }

function notify(kind, title, text, href) {
  queue.push({ kind, title, text, href });
  if (!showing) next();
}
function next() {
  const n = queue.shift(); if (!n) { showing = false; return; }
  showing = true;
  const el = document.createElement('a');
  el.className = `growth-pop g-${n.kind}`; el.href = n.href; el.setAttribute('role', 'status');
  el.innerHTML = `${icon(n.kind === 'level' ? 'spark' : n.kind === 'bag' ? 'bag' : 'target', 22)}<div><b>${esc(n.title)}</b><span>${esc(n.text)}</span></div>`;
  document.body.append(el);
  window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'reward' }));
  requestAnimationFrame(() => el.classList.add('in'));
  const close = () => { el.classList.remove('in'); setTimeout(() => { el.remove(); next(); }, 260); };
  const t = setTimeout(close, n.kind === 'level' ? 4500 : 3200);
  el.addEventListener('click', () => { clearTimeout(t); close(); });
}
