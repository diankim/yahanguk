// 공용 설정: 다른 모듈에 기대지 않는다(점검 확인·점검 페이지에서도 쓴다).
export const SUPABASE_URL = 'https://bqywnmeryddwccrbomfe.supabase.co';
export const SUPABASE_KEY = 'sb_publishable_G2l1gY8W6ZYtSsFSx4LH6Q_YGdvnwe6';

// 점검 중에는 서버가 anon·authenticated의 public 스키마 사용 권한을 거둔다(supabase/maintenance/start.sql).
export const isMaintenanceError = msg => /permission denied for schema public/i.test(String(msg || ''));
export function goMaintenance() {
  if (/maintenance\.html$/.test(location.pathname)) return;
  try { sessionStorage.setItem('yh-return', location.hash || ''); } catch {}
  location.replace('maintenance.html');
}

// 서버가 열려 있는지 확인한다: 'open' | 'maintenance' | 'offline'.
// 1) 배포에 함께 올리는 maintenance.json의 active가 true면 점검(계획 점검 안내용)
// 2) 공개 읽기 표를 하나 읽어 '스키마 권한 거부'가 오면 점검(서버 쪽 실제 차단)
// maintenance.json의 안내(message·until·notes)는 서버 차단으로 점검에 들어간 경우에도 점검 페이지에 보여 준다.
export async function serverState() {
  let info = null;
  try {
    const f = await fetch('maintenance.json', { cache: 'no-store' });
    if (f.ok) { info = await f.json().catch(() => null); if (info?.active) return { state: 'maintenance', info }; }
  } catch {}
  try {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/world_map_regions?select=region_id&limit=1`, { headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` }, cache: 'no-store' });
    if (r.ok) return { state: 'open', info };
    const body = await r.text();
    return isMaintenanceError(body) ? { state: 'maintenance', info } : { state: 'open', info };
  } catch { return { state: 'offline', info }; }
}
