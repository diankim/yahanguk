// 날씨·시간대: 서버가 정한 값을 받아 두고, 바뀌는 시각에만 다시 묻는다(반복 폴링 없음).
import { store, on, emit, rpc, esc, icon, fmt, effectText, effectGood, ENV_ICON, openModal } from './core.js';

let timer = null, loading = null;

export function loadEnv() {
  if (loading) return loading;
  loading = rpc('world_environment_snapshot').then(e => {
    store.env = e;
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
  return `<button class="env-chip w-${esc(e.weather.key)} p-${esc(e.phase.key)}" data-env-open title="날씨와 시간대 효과 보기">
    ${icon(ENV_ICON[e.phase.key] || 'moon', 14)}<span>${esc(e.phase.name)}</span><i></i>${icon(ENV_ICON[e.weather.key] || 'cloud', 14)}<span>${esc(e.weather.name)}</span>
    ${compact ? '' : `<small data-env-left="${new Date(e.weather.ends_at).getTime()}">${fmt.remain(new Date(e.weather.ends_at) - Date.now())}</small>`}</button>`;
}
function fxList(effects) {
  return `<ul class="fx-list">${Object.entries(effects || {}).map(([k, v]) => `<li class="${effectGood(k, v) ? 'good' : 'bad'}">${esc(effectText({ [k]: v })[0] || '')}</li>`).join('')}</ul>`;
}
export function openEnv(e = store.env) {
  if (!e) return;
  const left = t => fmt.remain(new Date(t) - Date.now());
  openModal({ title: '날씨와 시간대', body: `<div class="env-detail">
    <section><h3>${icon(ENV_ICON[e.phase.key], 16)} ${esc(e.phase.name)} <small>${left(e.phase.ends_at)} 뒤 바뀜</small></h3><p>${esc(e.phase.description)}</p>${fxList(e.phase.effects)}</section>
    <section><h3>${icon(ENV_ICON[e.weather.key], 16)} ${esc(e.weather.name)} <small>${left(e.weather.ends_at)} 뒤 ${esc((e.next_weather?.name || '') + '(으)로')}</small></h3><p>${esc(e.weather.description)}</p>${fxList(e.weather.effects)}</section>
    <p class="muted small">시간대는 한국 시각으로 6시간마다(해돋이 6시·한낮 12시·땅거미 18시·삼경 0시), 날씨는 12시간마다(0시·12시) 바뀝니다. 날씨는 영역마다 다르며, 효과는 탐색·채집·제작·이동·회복·전투에 모두 적용됩니다.</p>
  </div>` });
}
document.addEventListener('click', ev => { if (ev.target.closest('[data-env-open]')) openEnv(); });
setInterval(() => document.querySelectorAll('[data-env-left]').forEach(x => { x.textContent = fmt.remain(Number(x.dataset.envLeft) - Date.now()); }), 30000);
