-- 7.7.2 — 조사원 의뢰(사용자 요청 2026-11-01): 의뢰 게시판에 조사원이 「이 물품을 구한다」 의뢰를 올린다.
-- · 올리기: 안전지대(반요촌 제외)에서 물품(거래 가능·거래소 전용 아님·보통 물품)·수량(1~999)·보수(전)를 정해 올린다. 보수는 그 자리에서 맡긴다(가방 → 게시판).
--   보수는 기준 시세 × 수량 × 0.5 이상·10전 이상, 한 사람 동시에 5건, 3일 뒤 마감.
-- · 수행: 다른 조사원이 안전지대(반요촌 제외)에서 그 물품을 넘기면(보통 먼저, 모자라면 우수품) 보수에서 수수료를 뗀 몫과
--   상시 납품 의뢰와 같은 경험치(20 + 레벨×3)를 받는다. 수수료 10%(수향연맹 세금 감면 world_trade_tax_mult 그대로)는 의뢰를 올린 안전지대의
--   지배 세력(등록처)이 떼 간다 — 지금은 세력 금고가 없어 전은 사라지고(전 소모처) 기록에만 남는다.
--   경험치·행동 기록은 한 사람 하루(한국 시각) 세 번까지(서로 의뢰를 주고받아 경험치·칭호를 쌓지 못하게), 그 뒤로도 보수는 받는다.
-- · 받기: 올린 사람은 안전지대에서 게시판의 「물품 받기」로 넘겨받은 물품을 가방에 넣는다(가방에 다 들어가야 함). 완료되면 알림(ucomm_done → 갈래 trade).
-- · 거두기: 아무도 맡지 않은 의뢰는 언제든 거둘 수 있고, 마감이 지난 의뢰는 「보수 돌려받기」로 맡긴 보수를 그대로 돌려받는다(수수료 없음).
-- 자기 의뢰는 수행할 수 없고, 서로 차단한 사이도 안 된다. 표는 RLS만 켜고 함수로만 읽는다.
lock table public.world_characters in access exclusive mode;

create table if not exists public.world_user_commissions (
  id bigserial primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  owner_name text not null,
  item_id text not null,
  qty int not null check (qty between 1 and 999),
  reward int not null check (reward >= 1),
  region_id text,
  fee_faction text,
  status text not null default 'open' check (status in ('open', 'done', 'cancelled', 'expired')),
  fulfiller_id uuid,
  fulfiller_name text,
  fee int not null default 0,
  delivered jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '3 days',
  done_at timestamptz,
  settled_at timestamptz   -- 올린 사람이 물품(완료) 또는 보수(마감·거둠)를 받아 간 때
);
create index if not exists world_user_commissions_open on public.world_user_commissions (status, expires_at);
create index if not exists world_user_commissions_owner on public.world_user_commissions (owner_id, created_at desc);
alter table public.world_user_commissions enable row level security;
revoke all on public.world_user_commissions from anon, authenticated;

-- 안전지대 행동 확인(서신 물품과 같은 조건, 문구만 의뢰용)
create or replace function public.world_ucomm_place_check(p_uid uuid)
returns void language plpgsql security definer set search_path to '' as $f$
declare c public.world_characters%rowtype;
begin
  perform public.world_travel_guard('조사원 의뢰');
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = p_uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null then raise exception '전투불능 상태에서는 의뢰를 다룰 수 없습니다.'; end if;
  if c.travel_arrives_at is not null then raise exception '이동 중에는 의뢰를 다룰 수 없습니다.'; end if;
  if not exists (select 1 from public.world_current_shop(p_uid)) then raise exception '조사원 의뢰는 안전지대의 의뢰 게시판에서 올리고, 넘기고, 받습니다.'; end if;
  if public.world_banyo_here(p_uid) then raise exception '반요촌에는 의뢰 게시판이 없습니다. 바깥 안전지대에서 하세요.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = 'active') then raise exception '원정 중에는 의뢰를 다룰 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities a where a.owner_id = p_uid and a.status = 'active') then raise exception '자율 활동 중에는 의뢰를 다룰 수 없습니다.'; end if;
end $f$;
revoke all on function public.world_ucomm_place_check(uuid) from public, anon, authenticated;

-- 게시판: 다른 조사원의 열린 의뢰 + 내 의뢰
create or replace function public.world_ucomm_board()
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; today date := (now() at time zone 'Asia/Seoul')::date; xp_used int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  -- 마감이 지난 열린 의뢰는 마감으로 바꾼다(보수는 올린 사람이 「돌려받기」로 받음)
  update public.world_user_commissions set status = 'expired' where status = 'open' and expires_at <= now();
  r := public.world_field_region(c.location);
  select count(*) into xp_used from public.world_events e where e.actor_id = uid and e.event_type = 'commission' and e.payload ? 'ucomm'
    and e.created_at >= (today::timestamp at time zone 'Asia/Seoul');
  return jsonb_build_object(
    'fee_pct', 10, 'xp_left', greatest(0, 3 - xp_used), 'xp', 20 + c.level * 3, 'max_open', 5,
    'here', jsonb_build_object('safe', coalesce(r.is_safe_zone, false) and r.region_id <> 'banyo_village', 'region', r.region_name,
      'faction', (select mf.faction_name from public.world_major_factions mf where mf.faction_id = coalesce(r.control_faction_id, r.home_faction_id))),
    'open', (select coalesce(jsonb_agg(jsonb_build_object('id', u.id, 'owner', u.owner_name, 'item', u.item_id, 'qty', u.qty, 'reward', u.reward,
        'region', (select region_name from public.world_map_regions where region_id = u.region_id), 'faction', (select mf.faction_name from public.world_major_factions mf where mf.faction_id = u.fee_faction),
        'expires_at', u.expires_at,
        'have', coalesce((c.inventory ->> u.item_id)::int, 0) + coalesce((c.inventory ->> (u.item_id || '_hq'))::int, 0)) order by u.created_at desc), '[]'::jsonb)
      from public.world_user_commissions u
      where u.status = 'open' and u.owner_id <> uid
        and not exists (select 1 from public.world_blocks b where (b.owner_id = uid and b.blocked_id = u.owner_id) or (b.owner_id = u.owner_id and b.blocked_id = uid))),
    'mine', (select coalesce(jsonb_agg(jsonb_build_object('id', u.id, 'item', u.item_id, 'qty', u.qty, 'reward', u.reward, 'status', u.status,
        'region', (select region_name from public.world_map_regions where region_id = u.region_id), 'faction', (select mf.faction_name from public.world_major_factions mf where mf.faction_id = u.fee_faction),
        'fulfiller', u.fulfiller_name, 'delivered', u.delivered, 'expires_at', u.expires_at, 'done_at', u.done_at, 'settled', u.settled_at is not null) order by u.created_at desc), '[]'::jsonb)
      from public.world_user_commissions u
      where u.owner_id = uid and (u.settled_at is null or u.settled_at > now() - interval '3 days')));
end $f$;

-- 의뢰 올리기
create or replace function public.world_ucomm_post(p_item text, p_qty int, p_reward int)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; it public.world_item_catalog%rowtype; r public.world_map_regions%rowtype; minr int; new_id bigint;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_ucomm_place_check(uid);
  select * into c from public.world_characters where owner_id = uid for update;
  select * into it from public.world_item_catalog where item_id = p_item;
  if it.item_id is null then raise exception '알 수 없는 물품입니다.'; end if;
  if it.base_item_id is not null then raise exception '우수품은 따로 구할 수 없습니다. 보통 물품으로 올리면 우수품도 함께 받습니다.'; end if;
  if not coalesce(it.tradeable, false) or it.category = 'quest' then raise exception '%은(는) 주고받을 수 없는 물품이라 의뢰로 구할 수 없습니다.', it.item_name; end if;
  if public.world_market_only(it.item_id) then raise exception '%은(는) 거래소에서만 사고파는 희귀 재료입니다. 거래소를 이용하세요.', it.item_name; end if;
  if p_qty is null or p_qty < 1 or p_qty > 999 then raise exception '수량은 1~999개입니다.'; end if;
  minr := greatest(10, ceil(coalesce(it.reference_price, 0) * p_qty * 0.5)::int);
  if p_reward is null or p_reward < minr then raise exception '보수는 적어도 %전이어야 합니다(기준 시세의 절반 이상).', minr; end if;
  if p_reward > 1000000 then raise exception '보수는 1,000,000전까지 걸 수 있습니다.'; end if;
  if coalesce(c.gil, 0) < p_reward then raise exception '보수로 맡길 전이 모자랍니다. (가진 전 %)', c.gil; end if;
  if (select count(*) from public.world_user_commissions where owner_id = uid and status = 'open' and expires_at > now()) >= 5 then
    raise exception '의뢰는 한 번에 다섯 건까지 올릴 수 있습니다. 끝나거나 거둔 뒤 다시 올리세요.';
  end if;
  r := public.world_field_region(c.location);
  update public.world_characters set gil = gil - p_reward, updated_at = now() where owner_id = uid;
  insert into public.world_user_commissions(owner_id, owner_name, item_id, qty, reward, region_id, fee_faction)
    values (uid, c.character_name, it.item_id, p_qty, p_reward, r.region_id, coalesce(r.control_faction_id, r.home_faction_id))
    returning id into new_id;
  return jsonb_build_object('ok', true, 'id', new_id,
    'content', '의뢰를 올렸습니다: ' || it.item_name || ' ×' || p_qty || ' · 보수 ' || p_reward || '전을 게시판에 맡겼습니다. 3일 안에 아무도 맡지 않으면 돌려받습니다.');
end $f$;

-- 의뢰 수행(물품 넘기기)
create or replace function public.world_ucomm_fulfill(p_id bigint)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; u public.world_user_commissions%rowtype; inv jsonb;
  base_have int; hq_have int; from_base int; from_hq int; give jsonb; v_fee int; v_pay int; xp int := 0; today date := (now() at time zone 'Asia/Seoul')::date; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_ucomm_place_check(uid);
  select * into u from public.world_user_commissions where id = p_id for update;
  if not found then raise exception '없는 의뢰입니다.'; end if;
  if u.status <> 'open' or u.expires_at <= now() then raise exception '이미 끝났거나 마감된 의뢰입니다.'; end if;
  if u.owner_id = uid then raise exception '자기 의뢰는 맡을 수 없습니다.'; end if;
  if exists (select 1 from public.world_blocks b where (b.owner_id = uid and b.blocked_id = u.owner_id) or (b.owner_id = u.owner_id and b.blocked_id = uid)) then
    raise exception '이 조사원의 의뢰는 맡을 수 없습니다.';
  end if;
  select * into c from public.world_characters where owner_id = uid for update;
  inv := coalesce(c.inventory, '{}'::jsonb);
  base_have := coalesce((inv ->> u.item_id)::int, 0); hq_have := coalesce((inv ->> (u.item_id || '_hq'))::int, 0);
  if base_have + hq_have < u.qty then raise exception '넘길 물품이 모자랍니다. (가진 수량 %)', base_have + hq_have; end if;
  from_base := least(base_have, u.qty); from_hq := u.qty - from_base;
  give := jsonb_strip_nulls(jsonb_build_object(u.item_id, nullif(from_base, 0), u.item_id || '_hq', nullif(from_hq, 0)));
  -- 거래 가능·잠금·장착 마지막 하나 등은 직접 거래와 같은 검사
  perform public.world_trade_bundle_check(uid, give, inv);
  if from_base > 0 then inv := public.world_inv_add(inv, u.item_id, -from_base); end if;
  if from_hq > 0 then inv := public.world_inv_add(inv, u.item_id || '_hq', -from_hq); end if;
  v_fee := greatest(1, floor(u.reward * 0.10 * coalesce(public.world_trade_tax_mult(uid), 1))::int);
  v_fee := least(v_fee, u.reward);
  v_pay := u.reward - v_fee;
  -- 경험치·행동 기록은 하루 세 번까지
  if (select count(*) from public.world_events e where e.actor_id = uid and e.event_type = 'commission' and e.payload ? 'ucomm'
        and e.created_at >= (today::timestamp at time zone 'Asia/Seoul')) < 3 then
    xp := 20 + c.level * 3;
  end if;
  update public.world_characters set inventory = inv, gil = gil + v_pay, updated_at = now() where owner_id = uid;
  update public.world_user_commissions set status = 'done', fulfiller_id = uid, fulfiller_name = c.character_name, fee = v_fee, delivered = give, done_at = now() where id = u.id;
  select item_name into nm from public.world_item_catalog where item_id = u.item_id;
  if xp > 0 then
    perform public.world_grant_xp(uid, xp);
    insert into public.world_events(actor_id, actor_name, event_type, content, payload)
      values (uid, c.character_name, 'commission', '조사원 의뢰 완료: ' || nm || ' ×' || u.qty, jsonb_build_object('ucomm', u.id, 'gil', v_pay, 'xp', xp, 'fee', v_fee));
  end if;
  insert into public.world_notifications(user_id, kind, title, content, payload)
    values (u.owner_id, 'ucomm_done', '의뢰 완료: ' || nm || ' ×' || u.qty,
            c.character_name || '이(가) 의뢰한 물품을 넘겼습니다. 안전지대의 의뢰 게시판(일지 › 의뢰)에서 물품을 받으세요.',
            jsonb_build_object('ucomm', u.id, 'item', u.item_id, 'qty', u.qty));
  return jsonb_build_object('ok', true, 'gil', v_pay, 'fee', v_fee, 'xp', xp,
    'content', '의뢰 완료: ' || nm || ' ×' || u.qty || ' · ' || v_pay || '전(등록처 수수료 ' || v_fee || '전 뗌)' || case when xp > 0 then ' · 경험치 ' || xp else ' · 오늘 경험치는 다 받았습니다' end);
end $f$;

-- 의뢰 거두기(아무도 맡지 않은 것만, 보수 그대로 돌려받음)
create or replace function public.world_ucomm_cancel(p_id bigint)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); u public.world_user_commissions%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_travel_guard('의뢰 거두기');
  perform public.world_seal_guard();
  select * into u from public.world_user_commissions where id = p_id and owner_id = uid for update;
  if not found then raise exception '내 의뢰가 아닙니다.'; end if;
  if u.status not in ('open', 'expired') or u.settled_at is not null then raise exception '이미 끝났거나 거둔 의뢰입니다.'; end if;
  update public.world_user_commissions set status = case when status = 'open' and expires_at > now() then 'cancelled' else 'expired' end, settled_at = now() where id = u.id;
  update public.world_characters set gil = gil + u.reward, updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'content', '의뢰를 거두고 보수 ' || u.reward || '전을 돌려받았습니다.');
end $f$;

-- 끝난 의뢰의 물품 받기(안전지대, 가방에 다 들어가야 함)
create or replace function public.world_ucomm_collect(p_id bigint)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; u public.world_user_commissions%rowtype; inv jsonb; k text; v text; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_ucomm_place_check(uid);
  select * into u from public.world_user_commissions where id = p_id and owner_id = uid for update;
  if not found then raise exception '내 의뢰가 아닙니다.'; end if;
  if u.status <> 'done' or u.settled_at is not null then raise exception '받을 물품이 없습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  inv := coalesce(c.inventory, '{}'::jsonb);
  for k, v in select key, value::text from jsonb_each(u.delivered) loop inv := public.world_inv_add(inv, k, v::int); end loop;
  if public.world_bag_count(inv) > public.world_bag_limit(uid) then raise exception '가방에 자리가 없습니다. 칸을 비우거나 창고에 맡긴 뒤 받으세요.'; end if;
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  update public.world_user_commissions set settled_at = now() where id = u.id;
  select item_name into nm from public.world_item_catalog where item_id = u.item_id;
  return jsonb_build_object('ok', true, 'content', '의뢰한 ' || nm || ' ×' || u.qty || '을(를) 받았습니다.');
end $f$;

do $g$
declare f text;
begin
  foreach f in array array['world_ucomm_board()', 'world_ucomm_post(text,integer,integer)', 'world_ucomm_fulfill(bigint)', 'world_ucomm_cancel(bigint)', 'world_ucomm_collect(bigint)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $g$;

-- 알림 갈래: 의뢰 완료는 거래 갈래(끌 수 있음)
do $p$
declare d text; a text; b text; n int; own text; inh boolean;
begin
  d := replace(pg_get_functiondef('public.world_notify_group(text)'::regprocedure), E'\r\n', E'\n');
  if position('ucomm_done' in d) > 0 then return; end if;
  a := $a$when p_kind in ('trade_offer', 'trade_result') then 'trade'$a$;
  b := $b$when p_kind in ('trade_offer', 'trade_result', 'ucomm_done') then 'trade'$b$;
  n := (length(d) - length(replace(d, a, ''))) / length(a);
  if n <> 1 then raise exception '7.7.2 notify anchor (% of 1)', n; end if;
  select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_notify_group(text)'::regprocedure;
  select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
  if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
  execute replace(d, a, b);
  if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
end $p$;

update public.world_patch_notes set body = rtrim(body, E'\n') || $N$

## 7.7.2
- 조사원 의뢰: 일지 › 의뢰에 조사원이 직접 올리는 의뢰가 생겼습니다. 안전지대에서 「의뢰 올리기」로 구할 물품(분류·이름으로 찾기)·수량·보수를 정해 올리면 보수가 게시판에 맡겨집니다. 다른 조사원이 그 물품을 넘기면 보수와 경험치(상시 납품 의뢰와 같음, 하루 세 번까지)를 받고, 의뢰를 올린 안전지대의 세력이 보수의 10%를 수수료로 뗍니다. 의뢰가 끝나면 알림이 가고, 안전지대의 게시판에서 물품을 받습니다. 아무도 맡지 않은 의뢰는 거둘 수 있고, 3일이 지나면 보수를 그대로 돌려받습니다.
- 제작법을 검색한 뒤 물품 정보 창에서 다른 제작법으로 넘어가면 처음 검색어가 남아 그 제작법이 가려지던 것을 고쳤습니다(제보 74).
- 물품 정보 창에서 분해하거나 버리면 창이 닫히고 가방으로 돌아갑니다(버리기는 닫히게 되어 있었지만 실제로는 남아 있었습니다).
$N$
 where note_id = '7.7.0' and position('## 7.7.2' in body) = 0;

update public.world_app_meta set value = '20261104200700' where key = 'db_version';
