// 이동 알림 띠: 출발하면 화면 위에 계속 떠서 남은 시간을 보여 주고, 도착하면 도착을 알린 뒤 사라진다.
import { store, on, nameOf, esc, icon, fmt, $ } from './core.js';

let el, timer, arrivedTimer;
export function mountTravelBanner(node) {
  el = node;
  on('character', draw);
  window.addEventListener('yahang:arrived', e => showArrived(e.detail?.location));
  clearInterval(timer); timer = setInterval(tick, 1000);
  draw();
}

function draw() {
  const c = store.character; if (!el || !c) return;
  const t = c.travel_arrives_at ? new Date(c.travel_arrives_at).getTime() : 0;
  if (t && t > Date.now()) {
    clearTimeout(arrivedTimer);
    el.hidden = false; el.className = 'travel-banner moving';
    el.dataset.until = t;
    el.innerHTML = `${icon('route', 18)}<div><b>${esc((nameOf(c.travel_destination) || '목적지') + '(으)로')} 이동 중</b><span id="tb-left">${fmt.remain(t - Date.now())} 후 도착</span></div>
      <div class="tb-bar"><i style="width:0%"></i></div><a class="btn small ghost" href="#/map/travel">자세히</a>`;
    el.dataset.start = el.dataset.start && Number(el.dataset.until) === t ? el.dataset.start : Date.now();
    document.body.classList.add('has-banner');
  } else if (el.classList.contains('moving')) {
    // 도착 처리는 상태판(hud)이 서버에 확인한 뒤 yahang:arrived로 알려 준다.
    $('#tb-left', el) && ($('#tb-left', el).textContent = '도착 처리 중…');
  }
}

function tick() {
  if (!el || el.hidden || !el.classList.contains('moving')) return;
  const until = Number(el.dataset.until), start = Number(el.dataset.start) || Date.now();
  const left = until - Date.now();
  const span = $('#tb-left', el); if (span) span.textContent = left > 0 ? `${fmt.remain(left)} 후 도착` : '도착 처리 중…';
  const bar = el.querySelector('.tb-bar i'); if (bar) bar.style.width = `${Math.min(100, Math.max(0, (Date.now() - start) / Math.max(1, until - start) * 100))}%`;
}

function showArrived(location) {
  if (!el) return;
  const c = store.character;
  if (c?.travel_arrives_at && new Date(c.travel_arrives_at) > new Date()) return;
  el.hidden = false; el.className = 'travel-banner arrived';
  el.innerHTML = `${icon('pin', 18)}<div><b>${esc(location || c?.location || '목적지')}에 도착했습니다</b><span>현장에서 이 지역을 둘러보세요.</span></div><a class="btn small primary" href="#/home">현장으로</a>`;
  document.body.classList.add('has-banner');
  window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'arrive' }));
  clearTimeout(arrivedTimer);
  arrivedTimer = setTimeout(() => { el.hidden = true; el.className = 'travel-banner'; delete el.dataset.start; document.body.classList.remove('has-banner'); }, 9000);
}
