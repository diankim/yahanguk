// 공용 설정: 다른 모듈에 기대지 않는다(점검 확인·점검 페이지에서도 쓴다).
export const SUPABASE_URL = 'https://bqywnmeryddwccrbomfe.supabase.co';
export const SUPABASE_KEY = 'sb_publishable_G2l1gY8W6ZYtSsFSx4LH6Q_YGdvnwe6';

// 아이디 가입: 아이디를 내부 주소로 바꿔 Supabase Auth에 넘긴다(메일은 보내지 않는다).
// 서버 훅(world_hook_before_user_created)이 같은 형식만 받아 준다. 바꾸면 훅의 도메인도 함께 바꾼다.
export const ID_DOMAIN = 'yahanguk.invalid';
export const ID_RULE = /^[a-z0-9]{4,16}$/;
export const idToEmail = id => `${String(id || '').trim().toLowerCase()}@${ID_DOMAIN}`;
export const emailToId = email => { const [l, d] = String(email || '').split('@'); return d === ID_DOMAIN ? l : String(email || ''); };
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
  // 두 확인을 동시에 보낸다(차례로 기다리면 접속이 한 번 왕복만큼 늦어진다)
  const probe = fetch(`${SUPABASE_URL}/rest/v1/world_map_regions?select=region_id&limit=1`, { headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` }, cache: 'no-store' });
  probe.catch(() => {});
  try {
    const f = await fetch('maintenance.json', { cache: 'no-store' });
    if (f.ok) { info = await f.json().catch(() => null); if (info?.active) return { state: 'maintenance', info }; }
  } catch {}
  try {
    // 서버가 바쁠 때 이 확인이 몇 초씩 걸려 「접속 중」 화면이 길어진다. 1.5초 안에 답이 없으면 열려 있다고 보고 게임을 띄운다
    // (실제 점검 중이면 게임 화면의 첫 요청이 실패해 오류 안내가 뜬다).
    const r = await Promise.race([probe, new Promise(res => setTimeout(() => res(null), 1500))]);
    if (!r) return { state: 'open', info };
    if (r.ok) return { state: 'open', info };
    const body = await r.text();
    return isMaintenanceError(body) ? { state: 'maintenance', info } : { state: 'open', info };
  } catch { return { state: 'offline', info }; }
}
