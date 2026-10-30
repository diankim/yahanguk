// 날씨·시간대: 서버가 정한 값을 받아 두고, 바뀌는 시각에만 다시 묻는다(반복 폴링 없음).
import { store, on, emit, rpc, esc, icon, fmt, effectText, effectGood, ENV_ICON, openModal } from './core.js';

let timer = null, loading = null;

export function loadEnv() {
  if (loading) return loading;
  loading = rpc('world_environment_snapshot').then(e => {
    store.env = e;
    fog(e?.long_night?.stage || 0);
    emit('env', e);
    schedule(e);
    return e;
  }).catch(err => { console.warn('날씨 정보를 받지 못했습니다', err); return null; }).finally(() => { loading = null; });
  return loading;
}
function schedule(e) {
  clearTimeout(timer);
  const next = Math.min(...[e?.phase?.ends_at, e?.weather?.ends_at].filter(Boolean).map(t => new Date(t).getTime()));
  if (!Number.isFinite(next)) return;
  timer = setTimeout(loadEnv, Math.max(5000, next - Date.now() + 3000));
}
export function mountEnv() {
  loadEnv();
  // 다른 영역으로 옮기면 날씨가 달라진다.
  window.addEventListener('yahang:arrived', () => loadEnv());
  on('changed', ({ name }) => { if (/travel|rescue|character_delete/.test(name)) setTimeout(loadEnv, 400); });
}

// 상태판·현장 머리에 붙는 작은 표시
export function envChip(e = store.env, { compact = false } = {}) {
  if (!e?.phase || !e?.weather) return '';
  return `<button class="env-chip w-${esc(e.weather.key)} p-${esc(e.phase.key)}${e.long_night?.stage ? ' long-night' : ''}" data-env-open title="날씨와 시간대 효과 보기">
    ${icon(ENV_ICON[e.phase.key] || 'moon', 14)}<span>${esc(e.phase.name)}</span><i></i>${icon(ENV_ICON[e.weather.key] || 'cloud', 14)}<span>${esc(e.weather.name)}</span>
    ${compact ? '' : `<small data-env-left="${new Date(e.weather.ends_at).getTime()}">${fmt.remain(new Date(e.weather.ends_at) - Date.now())}</small>`}</button>`;
}
// 장야(롤백 전 사흘): 밤이 길어지고 2단계부터 요괴가 늘어난다(서버 world_long_night_fx)
const LN_FX = { 2: '요괴 조우 +15% · 침식 +20% · 희귀품·단서 +5%', 3: '요괴 조우 +50% · 침식 +30% · 정신 손실 +10% · 희귀품·단서 +10%' };
function longNight(e) {
  const l = e.long_night; if (!l?.stage) return '';
  return `<section class="long-night"><h3>${icon('moon', 16)} 장야(長夜) · ${esc(l.name || '')}</h3><p>${esc(l.text || '')}</p>${LN_FX[Math.min(3, l.stage)] ? `<p class="bad small">${esc(LN_FX[Math.min(3, l.stage)])}</p>` : ''}</section>`;
}
// 장야의 붉은 안개: 단계가 오를수록 화면 아래에서 짙게 차오른다(누르는 데 방해되지 않게 pointer-events 없음).
// 안개 결은 SVG 잡음(feTurbulence)을 붉게 물들이고 흐리게 번진 두 겹을 서로 다른 빠르기로 흘린다.
// 눈이 피로하지 않게 옅게 두고, 날씨 창에서 끌 수 있다(기기 yh-fog-off). 움직임 줄이기면 흐르지 않는다.
const FOG_KEY = 'yh-fog-off';
const fogOff = () => { try { return localStorage.getItem(FOG_KEY) === '1'; } catch { return false; } };
const fogLayer = (seed, fx, fy) => `<svg class="fog-l" viewBox="0 0 1600 400" preserveAspectRatio="none" aria-hidden="true">
  <filter id="ln-fog-${seed}" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency="${fx} ${fy}" numOctaves="3" seed="${seed}" stitchTiles="stitch"/>
  <feColorMatrix values="0 0 0 0 0.62  0 0 0 0 0.1  0 0 0 0 0.14  2.2 0 0 0 -0.72"/></filter>
  <rect width="1600" height="400" filter="url(#ln-fog-${seed})"/></svg>`;
function fog(stage) {
  let el = document.getElementById('ln-fog');
  if (!(stage >= 2) || fogOff()) { el?.remove(); return; }
  if (!el) {
    el = document.createElement('div'); el.id = 'ln-fog'; el.setAttribute('aria-hidden', 'true');
    el.innerHTML = `<div class="fog-a">${fogLayer(7, 0.0035, 0.012)}${fogLayer(7, 0.0035, 0.012)}</div><div class="fog-b">${fogLayer(23, 0.006, 0.02)}${fogLayer(23, 0.006, 0.02)}</div>`;
    document.body.append(el);
  }
  el.dataset.stage = String(Math.min(3, stage));
}
function fxList(effects) {
  return `<ul class="fx-list">${Object.entries(effects || {}).map(([k, v]) => `<li class="${effectGood(k, v) ? 'good' : 'bad'}">${esc(effectText({ [k]: v })[0] || '')}</li>`).join('')}</ul>`;
}
export function openEnv(e = store.env) {
  if (!e) return;
  const left = t => fmt.remain(new Date(t) - Date.now());
  openModal({ title: '날씨와 시간대', body: `<div class="env-detail">${longNight(e)}
    <section><h3>${icon(ENV_ICON[e.phase.key], 16)} ${esc(e.phase.name)} <small>${left(e.phase.ends_at)} 뒤 바뀜</small></h3><p>${esc(e.phase.description)}</p>${fxList(e.phase.effects)}</section>
    <section><h3>${icon(ENV_ICON[e.weather.key], 16)} ${esc(e.weather.name)} <small>${left(e.weather.ends_at)} 뒤 ${esc((e.next_weather?.name || '') + '(으)로')}</small></h3><p>${esc(e.weather.description)}</p>${fxList(e.weather.effects)}</section>
    ${(e.long_night?.stage || 0) >= 2 ? `<label class="check"><input type="checkbox" data-fog-toggle ${fogOff() ? '' : 'checked'}><span>화면에 붉은 안개 연출 보기</span></label>` : ''}
    <p class="muted small">${e.long_night?.stage ? '장야 동안에는 시간대가 평소와 다르게 흐릅니다. 평소에는 ' : ''}시간대는 한국 시각으로 6시간마다(해돋이 6시·한낮 12시·땅거미 18시·삼경 0시), 날씨는 12시간마다(0시·12시) 바뀝니다. 날씨는 영역마다 다르며, 효과는 탐색·채집·제작·이동·회복·전투에 모두 적용됩니다.</p>
  </div>` });
}
document.addEventListener('click', ev => { if (ev.target.closest('[data-env-open]')) openEnv(); });
document.addEventListener('change', ev => {
  if (!ev.target.matches?.('[data-fog-toggle]')) return;
  try { localStorage.setItem(FOG_KEY, ev.target.checked ? '0' : '1'); } catch {}
  fog(store.env?.long_night?.stage || 0);
});
setInterval(() => document.querySelectorAll('[data-env-left]').forEach(x => { x.textContent = fmt.remain(Number(x.dataset.envLeft) - Date.now()); }), 30000);
