import { on, esc, icon, fmt, xpNeed, LEVEL_CAP } from './core.js';

const RANKS = [['combat_rank', '전투 숙련'], ['investigation_rank', '조사 숙련'], ['gathering_rank', '채집 숙련'], ['crafting_rank', '제작 숙련']];
const keyOf = id => `yh-growth:${id}`;
let last = null, lastId = null, queue = [], showing = false;

const pick = c => ({ level: c.level || 1, stat_points: c.stat_points || 0, bag: c.bag_capacity || 0, er: c.erosion || 0, ...Object.fromEntries(RANKS.map(([k]) => [k, c[k] || 1])) });

export function mountGrowth() {
  on('character', c => {
    if (!c?.owner_id || c.is_dead) return;
    if (lastId !== c.owner_id) {
      lastId = c.owner_id; last = null;
      try { last = JSON.parse(localStorage.getItem(keyOf(c.owner_id)) || 'null'); } catch {}
      if (!last) { save(c); return; }
    }
    const now = pick(c), was = last;
    if (now.level > was.level) {
      const pts = Math.max(0, now.stat_points - was.stat_points);
      notify('level', `레벨 업! Lv.${now.level}`, [pts ? `능력치 포인트 +${pts}` : '', (now.level >= LEVEL_CAP ? '최고 레벨에 이르렀습니다' : `다음 레벨까지 ${fmt.num(Math.max(0, xpNeed(now.level) - (c.experience || 0)))} 경험`)].filter(Boolean).join(' · '), '#/char/growth');
    }
    for (const [k, label] of RANKS) if (now[k] > was[k]) notify('rank', `${label} ${now[k]}단계`, '해당 활동의 효율이 좋아졌습니다.', '#/char/growth');
    if (now.bag > was.bag && was.bag) notify('bag', `가방이 넓어졌습니다`, `${fmt.num(was.bag)}칸 → ${fmt.num(now.bag)}칸`, '#/bag/items');
    if (now.er >= 90 && (was.er ?? now.er) < 90) window.dispatchEvent(new CustomEvent('yh-local-note', { detail: { id: `er90-${Date.now()}`, kind: 'erosion_warn', title: `침식 ${now.er}`,
      content: '침식이 90을 넘었습니다. 100이 되면 정신이 0이 되고, 그 위로 넘치는 침식마다 요화에 걸릴 수 있습니다. 정화 부적이나 안전지대에서 마음 다잡기로 낮추세요.' } }));
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
