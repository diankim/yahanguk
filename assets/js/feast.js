import { rpc, esc, icon, guard, $, $$, fmt, openLayer, effectText } from './core.js';
import { GAMEDATA } from './gamedata.js';

const FEAST = GAMEDATA.feast || { start: '12:30', min: 30, feasts: [] };
export function feastToday(now = Date.now()) {
  const k = new Date(now + 9 * 3600e3), dow = k.getUTCDay() || 7;
  const f = (FEAST.feasts || []).find(x => x.dow === dow); if (!f) return null;
  const [h, m] = String(FEAST.start).split(':').map(Number);
  const startsAt = Date.UTC(k.getUTCFullYear(), k.getUTCMonth(), k.getUTCDate(), h, m) - 9 * 3600e3;
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
export async function openFeast() {
  let v = null, t = null, cd = null, skew = 0;
  const l = openLayer({ title: '세력 행사', body: '<div class="wed-box feast-box"><p class="muted">불러오는 중…</p></div>' });
  const box = $('.feast-box', l);
  const draw = () => {
    if (!box.isConnected) { clearInterval(t); clearInterval(cd); return; }
    if (!v) { box.innerHTML = '<p class="muted">오늘은 열리는 행사가 없습니다.</p>'; return; }
    const now = Date.now() + skew, ru = v.rules || FEAST, me = v.me || {};
    const startIn = new Date(v.starts_at) - now, endIn = new Date(v.ends_at) - now;
    const when = v.status === 'done' ? '끝남' : startIn > 0 ? `${fmt.remain(startIn)} 뒤 시작` : `${fmt.remain(endIn)} 남음`;
    const lines = [...(v.script || []), ...(v.lines || [])].sort((a, b) => new Date(a.at) - new Date(b.at));
    const logHtml = lines.map(x => `<li class="k-${esc(x.k)}"><span>${esc(x.t)}</span></li>`).join('') || `<li class="muted">${esc(v.desc || '')}</li>`;
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
      <ol class="raid-log wed-log">${logHtml}</ol>${acts}`;
    const log = $('.wed-log', box); if (log) log.scrollTop = log.scrollHeight;
    $$('[data-feast]', box).forEach(b => b.onclick = () => guard(b, async () => { v = await rpc('world_feast_act', { p_kind: b.dataset.feast }); draw(); return null; }));
    clearInterval(cd);
    if (wait) {
      const paint = () => {
        if (!box.isConnected) return clearInterval(cd);
        const left = Math.ceil((readyAt - (Date.now() + skew)) / 1000), s = $('[data-feast-wait]', box);
        if (s) s.textContent = left > 0 ? ` · ${left}초 뒤 다시` : '';
        if (left <= 0) { clearInterval(cd); $$('[data-feast]', box).forEach(b => { if (!b.dataset.cap) b.disabled = false; }); }
      };
      paint(); cd = setInterval(paint, 500);
    }
  };
  const read = async () => {
    try { v = await rpc('world_feast_view'); if (v?.now) skew = new Date(v.now) - Date.now(); draw(); if (!v || v.status === 'done') clearInterval(t); }
    catch (e) { box.innerHTML = `<p class="bad">${esc(e.message)}</p>`; clearInterval(t); }
  };
  await read();
  if (v && v.status !== 'done') t = setInterval(() => { if (!box.isConnected) return clearInterval(t); if (!document.hidden) read(); }, 5000);
}
