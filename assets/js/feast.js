import { rpc, esc, icon, guard, $, $$, fmt, effectText, kstDate, KST_MS } from './core.js';
import { GAMEDATA } from './gamedata.js';
import { openLiveEvent, eventLogHtml } from './liveevent.js';

const FEAST = GAMEDATA.feast;
export function feastToday(now = Date.now()) {
  const k = kstDate(now), dow = k.getUTCDay() || 7;
  const f = (FEAST.feasts || []).find(x => x.dow === dow); if (!f) return null;
  const [h, m] = String(FEAST.start).split(':').map(Number);
  const startsAt = Date.UTC(k.getUTCFullYear(), k.getUTCMonth(), k.getUTCDate(), h, m) - KST_MS;
  return { ...f, startsAt, endsAt: startsAt + FEAST.min * 60e3 };
}
export function feastBandRow() {
  const f = feastToday(), now = Date.now();
  if (!f || now < f.startsAt - 3600e3 || now >= f.endsAt) return '';
  const live = now >= f.startsAt;
  return `<a class="raid-band-row${live ? ' hot' : ''}" href="#" data-feast-band>${icon('flame', 14)}<span><b>${esc(f.name)}</b> · ${esc(f.place || '')} · ${live ? `${fmt.remain(f.endsAt - now)} 남음` : `${fmt.remain(f.startsAt - now)} 뒤 시작`}</span><small>행사 보기</small></a>`;
}
export function bindFeastBand(box) {
  const b = $('[data-feast-band]', box);
  if (b) b.onclick = e => { e.preventDefault(); openFeast(); };
}
export function openFeast() {
  return openLiveEvent({
    title: '세력 행사', cls: 'feast-box', every: 5000, scene: v => v.key,
    read: () => rpc('world_feast_view'), over: v => !v || v.status === 'done',
    draw: (ctx, v) => {
      const box = ctx.box;
      if (!v) { box.innerHTML = '<p class="muted">오늘은 열리는 행사가 없습니다.</p>'; return; }
      const now = ctx.now(), ru = v.rules || FEAST, me = v.me || {};
      const startIn = new Date(v.starts_at) - now, endIn = new Date(v.ends_at) - now;
      const when = v.status === 'done' ? '끝남' : startIn > 0 ? `${fmt.remain(startIn)} 뒤 시작` : `${fmt.remain(endIn)} 남음`;
      const fx = effectText(v.effects).map(esc).join(' · ');
      const readyAt = me.last_at ? new Date(me.last_at).getTime() + ru.gap_s * 1000 : 0, wait = readyAt > now;
      let acts = '';
      if (v.status === 'live') {
        if (!v.here) acts = `<p class="hint">${icon('pin', 14)} ${esc(v.place)}에 가면 함께할 수 있습니다.</p>`;
        else if (!me.joined) acts = `<div class="btn-row"><button class="btn primary" data-feast="join">${icon('flame', 16)}<span>함께하기</span></button></div>`;
        else acts = `<div class="btn-row">${v.pet ? `<button class="btn small" data-feast="pet" data-cap="${me.pets >= ru.pet_max ? 1 : ''}" ${me.pets >= ru.pet_max || wait ? 'disabled' : ''}>동무 나서기 · ${esc(v.pet.name)} ${me.pets}/${ru.pet_max}</button>` : '<span class="muted small">데리고 다니는 꼬마 동무가 있으면 「동무 나서기」를 할 수 있습니다.</span>'}</div>
        <p class="muted small">함께하는 중 · 끝날 때 ${esc(v.place)}에 있으면 「${esc(v.buff)}」 기운을 ${ru.buff_h}시간 받습니다.<span data-feast-wait></span></p>`;
      }
      box.innerHTML = `<p class="desc"><b>${esc(v.name)}(${esc(v.hanja || '')})</b> · ${esc(v.place)} · ${when} · 함께하는 이 ${fmt.num(v.count || 0)}명</p>
      <p class="muted small">${esc(v.desc || '')} · 끝날 때 그곳에 있는 참여자는 「${esc(v.buff)}」(${fx}) ${ru.buff_h}시간</p>
      <ol class="raid-log wed-log">${eventLogHtml(v, `<li class="muted">${esc(v.desc || '')}</li>`)}</ol>${acts}${v.full && v.status !== 'done' ? `<p class="hint">${icon('flame', 14)} 상태 칸 ${v.cap}칸이 모두 차 있어 이대로 끝나면 「${esc(v.buff)}」 기운을 받지 못합니다. 길한 상태를 상태 창에서 끄면 받을 수 있습니다.</p>` : ''}`;
      const log = $('.wed-log', box); if (log) log.scrollTop = log.scrollHeight;
      $$('[data-feast]', box).forEach(b => b.onclick = () => guard(b, async () => { ctx.set(await rpc('world_feast_act', { p_kind: b.dataset.feast })); return null; }));
      ctx.wait(readyAt, '[data-feast-wait]', '[data-feast]');
    },
  });
}
