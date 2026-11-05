import { rpc } from './core.js';
import { applyTheme, savedThemeId, readCustom, savedFontSize, applyFontSize } from './theme.js';
import { sound, saveSound, applyVolumes } from './sound.js';

const STAMP = 'yh-ui-at', MODE = 'yh-ui-mode';
const SOUND_KEYS = ['vol', 'bgm', 'sfx', 'amb', 'bgmOn', 'sfxOn', 'ambOn', 'alarm'];
export const PREF_GROUPS = { look: ['theme', 'custom', 'fz'], sound: ['sound'] };
let timer = null, ready = false, applying = false, acct = {};

const lsGet = k => { try { return localStorage.getItem(k); } catch { return null; } };
const lsSet = (k, v) => { try { localStorage.setItem(k, v); } catch {} };
const modes = () => { try { return JSON.parse(lsGet(MODE) || '{}') || {}; } catch { return {}; } };
export const prefMode = g => modes()[g] === 'device' ? 'device' : 'account';
const setMode = (g, m) => lsSet(MODE, JSON.stringify({ ...modes(), [g]: m }));
const follows = g => prefMode(g) === 'account';

function local() {
  const s = {}; SOUND_KEYS.forEach(k => { if (sound[k] !== undefined) s[k] = sound[k]; });
  const theme = savedThemeId();
  return { theme, custom: theme === 'custom' ? readCustom() : null, fz: savedFontSize(), sound: s };
}
function collect() {
  const mine = local(), out = {};
  for (const [g, keys] of Object.entries(PREF_GROUPS)) keys.forEach(k => { const v = follows(g) ? mine[k] : acct[k]; if (v !== undefined) out[k] = v; });
  return out;
}

function apply(p, groups = Object.keys(PREF_GROUPS)) {
  applying = true;
  try {
    if (groups.includes('look')) {
      if (p.theme) applyTheme(p.theme, true, p.theme === 'custom' ? p.custom || undefined : undefined);
      if (p.fz) applyFontSize(p.fz, true);
    }
    if (groups.includes('sound') && p.sound && typeof p.sound === 'object') {
      SOUND_KEYS.forEach(k => { if (p.sound[k] !== undefined) sound[k] = p.sound[k]; });
      saveSound(); try { applyVolumes(); } catch {}
    }
  } finally { applying = false; }
}

export function syncPrefs(ui) {
  ready = true;
  acct = ui?.prefs && typeof ui.prefs === 'object' ? { ...ui.prefs } : {};
  const at = ui?.at || null, mine = lsGet(STAMP), live = Object.keys(PREF_GROUPS).filter(follows);
  if (at && Object.keys(acct).length && (!mine || new Date(at) > new Date(mine))) { if (live.length) apply(acct, live); lsSet(STAMP, at); return; }
  if ((!at || !mine) && live.length) push(0);
}

async function upload() {
  const p = collect();
  const r = await rpc('world_ui_prefs_set', { p_prefs: p });
  acct = p; if (r?.at) lsSet(STAMP, r.at);
  return r;
}
function push(delay = 3000) {
  clearTimeout(timer);
  timer = setTimeout(() => upload().catch(() => {}), delay);
}

export function savePrefsDevice(g) { setMode(g, 'device'); }
export async function savePrefsAccount(g) { setMode(g, 'account'); clearTimeout(timer); return upload(); }
export async function loadPrefsAccount(g) {
  const r = await rpc('world_tutorial_snapshot');
  const p = r?.ui?.prefs;
  if (!p || !PREF_GROUPS[g].some(k => p[k] != null)) return false;
  acct = { ...p };
  apply(p, [g]);
  return true;
}

window.addEventListener('yh-prefs-changed', () => { if (ready && !applying && Object.keys(PREF_GROUPS).some(follows)) push(); });
