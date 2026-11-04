import { rpc } from './core.js';
import { applyTheme, savedThemeId, readCustom, savedFontSize, applyFontSize } from './theme.js';
import { sound, saveSound, applyVolumes } from './sound.js';

const STAMP = 'yh-ui-at';
const SOUND_KEYS = ['vol', 'bgm', 'sfx', 'amb', 'bgmOn', 'sfxOn', 'ambOn', 'alarm'];
let timer = null, ready = false, applying = false;

const lsGet = k => { try { return localStorage.getItem(k); } catch { return null; } };
const lsSet = (k, v) => { try { localStorage.setItem(k, v); } catch {} };

function collect() {
  const s = {}; SOUND_KEYS.forEach(k => { if (sound[k] !== undefined) s[k] = sound[k]; });
  const theme = savedThemeId();
  return { theme, custom: theme === 'custom' ? readCustom() : null, fz: savedFontSize(), sound: s };
}

function apply(p) {
  applying = true;
  try {
    if (p.theme) applyTheme(p.theme, true, p.theme === 'custom' ? p.custom || undefined : undefined);
    if (p.fz) applyFontSize(p.fz, true);
    if (p.sound && typeof p.sound === 'object') {
      SOUND_KEYS.forEach(k => { if (p.sound[k] !== undefined) sound[k] = p.sound[k]; });
      saveSound(); try { applyVolumes(); } catch {}
    }
  } finally { applying = false; }
}

export function syncPrefs(ui) {
  ready = true;
  const at = ui?.at || null, mine = lsGet(STAMP);
  if (at && ui?.prefs && Object.keys(ui.prefs).length && (!mine || new Date(at) > new Date(mine))) { apply(ui.prefs); lsSet(STAMP, at); return; }
  if (!at || !mine) push(0);
}

function push(delay = 3000) {
  clearTimeout(timer);
  timer = setTimeout(async () => {
    try { const r = await rpc('world_ui_prefs_set', { p_prefs: collect() }); if (r?.at) lsSet(STAMP, r.at); } catch {}
  }, delay);
}

window.addEventListener('yh-prefs-changed', () => { if (ready && !applying) push(); });
