export const SUPABASE_URL = 'https://wphhqfkxrqjxxmfyozff.supabase.co';
export const SUPABASE_KEY = 'sb_publishable_2lhPYPuKIbf4sUzN4rfn5w_4ZhL34ls';

export const ID_DOMAIN = 'yahanguk.invalid';
export const ID_RULE = /^[a-z0-9]{4,16}$/;
export const idToEmail = id => `${String(id || '').trim().toLowerCase()}@${ID_DOMAIN}`;
export const emailToId = email => { const [l, d] = String(email || '').split('@'); return d === ID_DOMAIN ? l : String(email || ''); };
export const isMaintenanceError = msg => /permission denied for schema public/i.test(String(msg || ''));
export function goMaintenance() {
  if (/maintenance\.html$/.test(location.pathname)) return;
  try { sessionStorage.setItem('yh-return', location.hash || ''); } catch {}
  location.replace('maintenance.html');
}

export async function serverState() {
  let info = null;
  const probe = fetch(`${SUPABASE_URL}/rest/v1/world_story_chapters?select=chapter_id&limit=1`, { headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` }, cache: 'no-store' });
  probe.catch(() => {});
  try {
    const f = await fetch('maintenance.json', { cache: 'no-store' });
    if (f.ok) { info = await f.json().catch(() => null); if (info?.active) return { state: 'maintenance', info }; }
  } catch {}
  try {
    const r = await Promise.race([probe, new Promise(res => setTimeout(() => res(null), 1500))]);
    if (!r) return { state: 'open', info };
    if (r.ok) return { state: 'open', info };
    const body = await r.text();
    return isMaintenanceError(body) ? { state: 'maintenance', info } : { state: 'open', info };
  } catch { return { state: 'offline', info }; }
}
