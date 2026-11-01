-- 7.7.7j — 파티 전투 서버 공용 함수 ①: 받는 피해 계산(사용자 결정 2026-11-01 「공용으로 뽑을 수 있는 건 공용으로」).
-- 봉연(world_raid_hit)과 귀허(world_gw_hit)가 따로 짜 둔 같은 규칙(능력치 감소·증가 → 방어/버티기 → 진언 → 결계 → 호법 → 보호막,
-- 막아 준 몫은 건 사람 기여도로)을 world_cb_mitigate 하나로 모은다. 두 함수는 표적 고르기(대신 막기)·체력 반영·기록 줄만 남는다.
-- 맞춘 규칙(한쪽만 바뀜):
--  · 순서: 내 태세(방어·버티기)를 먼저, 동료가 걸어 준 효과(진언·결계·호법)를 뒤에 — 귀허 순서. 봉연은 방어 중일 때 결계·진언·호법을
--    건 사람의 기여도(막아 준 피해)가 「방어로 줄어든 뒤의 피해」 기준이 되어 조금 줄어든다. 받는 피해 자체는 곱셈이라 같다.
--  · 진언(gward): 봉연은 {by, pct}, 귀허는 건 사람 id(50%) — 둘 다 받는다. 피하기(evade)는 봉연 한 사람 공격만(지금과 같음).
create or replace function public.world_cb_mitigate(p_raw numeric, p_stats jsonb, p_fx jsonb, p_self uuid,
  p_aoe boolean default false, p_burst boolean default false, p_stance text default null, p_evade boolean default false)
returns jsonb language plpgsql set search_path to 'pg_catalog', 'public' as $function$
declare f jsonb := coalesce(p_fx, '{}'::jsonb); d numeric := greatest(0, coalesce(p_raw, 0)); cr jsonb := '[]'::jsonb;
  red numeric := least(80, coalesce((p_stats ->> 'red')::numeric, 0)); eva numeric := coalesce((p_stats ->> 'eva')::numeric, 0);
  st text := p_stance; n int; pct numeric; vby text; ab int := 0; sh int; taunt boolean := false;
begin
  -- 피하기(봉연 한 사람 공격만): 피할 길을 걸어 준 동료는 그 몫만큼 막아 준 것으로
  if p_evade and random() * 100 < eva + coalesce((f -> 'evade' ->> 'pct')::numeric, 0) then
    vby := f -> 'evade' ->> 'by';
    if vby is not null and vby <> p_self::text then
      cr := cr || jsonb_build_array(jsonb_build_array(vby, d * (1 - red / 100.0) * (f -> 'evade' ->> 'pct')::numeric / greatest(1, eva + (f -> 'evade' ->> 'pct')::numeric), 'guard')); end if;
    if f ? 'evade' then f := case when (f -> 'evade' ->> 'n')::int <= 1 then f - 'evade' else jsonb_set(f, '{evade,n}', to_jsonb((f -> 'evade' ->> 'n')::int - 1)) end; end if;
    return jsonb_build_object('d', 0, 'fx', f, 'credits', cr, 'absorb', 0, 'evaded', true, 'taunt', false);
  end if;
  d := d * (1 - red / 100.0) * (1 + coalesce((p_stats ->> 'inc')::numeric, 0) / 100.0);
  -- 내 태세: 봉연은 fx.guard(방어 행동), 귀허는 이번 라운드 행동(방어·버티기)
  if st is null and coalesce((f ->> 'guard')::int, 0) > 0 then st := 'guard'; end if;
  if f ? 'guard' then f := f - 'guard'; end if;
  if st = 'guard' then d := d * case when p_burst then 0.25 else 0.4 end;
  elsif st = 'brace' then d := d * case when p_aoe then 0.2 else 0.3 end; end if;
  -- 진언: 큰 공격(광역·터뜨림)만
  if p_aoe and f ? 'gward' then
    if jsonb_typeof(f -> 'gward') = 'object' then vby := f -> 'gward' ->> 'by'; pct := coalesce((f -> 'gward' ->> 'pct')::numeric, 50);
    else vby := nullif(f ->> 'gward', 'true'); pct := 50; end if;
    if vby is not null and vby <> p_self::text then cr := cr || jsonb_build_array(jsonb_build_array(vby, d * pct / 100.0, 'guard')); end if;
    d := d * (1 - pct / 100.0); f := f - 'gward';
  end if;
  -- 결계
  n := coalesce((f -> 'ward' ->> 'n')::int, 0);
  if n > 0 then
    pct := coalesce((f -> 'ward' ->> 'pct')::numeric, 0); vby := f -> 'ward' ->> 'by';
    if vby is not null and vby <> p_self::text then cr := cr || jsonb_build_array(jsonb_build_array(vby, d * pct / 100.0, 'guard')); end if;
    d := d * (1 - pct / 100.0);
    f := case when n <= 1 then f - 'ward' else jsonb_set(f, '{ward,n}', to_jsonb(n - 1)) end;
  end if;
  -- 호법(도발): 끌어온 사람이 받아 낸 피해는 막아 준 피해로
  n := coalesce((f -> 'taunt' ->> 'n')::int, 0);
  if n > 0 then
    pct := coalesce((f -> 'taunt' ->> 'pct')::numeric, 0); taunt := true;
    cr := cr || jsonb_build_array(jsonb_build_array(p_self::text, d * pct / 100.0, 'guard'));
    d := d * (1 - pct / 100.0);
    f := case when n <= 1 then f - 'taunt' else jsonb_set(f, '{taunt,n}', to_jsonb(n - 1)) end;
  end if;
  -- 보호막(먼저 받아 냄)
  sh := coalesce((f ->> 'shield')::int, 0);
  if sh > 0 and d > 0 then
    ab := least(sh, round(d)::int); d := d - ab;
    vby := f ->> 'shield_by';
    if vby is not null and vby <> p_self::text then cr := cr || jsonb_build_array(jsonb_build_array(vby, ab, 'guard')); end if;
    f := case when sh - ab > 0 then jsonb_set(f, '{shield}', to_jsonb(sh - ab)) else f - 'shield' end;
  end if;
  return jsonb_build_object('d', greatest(0, round(d))::int, 'fx', f, 'credits', cr, 'absorb', ab, 'evaded', false, 'taunt', taunt);
end $function$;
revoke all on function public.world_cb_mitigate(numeric, jsonb, jsonb, uuid, boolean, boolean, text, boolean) from public, anon, authenticated;
grant execute on function public.world_cb_mitigate(numeric, jsonb, jsonb, uuid, boolean, boolean, text, boolean) to fn_owner_field;

-- 봉연: 대신 막기(표적 바꾸기)·체력 반영·물러남·기록만 남긴다
create or replace function public.world_raid_hit(p_raid uuid, p_target uuid, p_raw numeric, p_kind text)
returns integer language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare m public.world_raid_members%rowtype; pm public.world_raid_members%rowtype; f jsonb; r jsonb; c jsonb; d int; hp int; who uuid := p_target; nm text; absorb int;
begin
  select * into m from public.world_raid_members where raid_id = p_raid and owner_id = p_target for update;
  if not found then return 0; end if;
  f := m.fx;
  -- 퇴마관의 대신 막기: 그 동료를 노린 공격을 지킨 사람이 절반만 받는다
  if f ? 'cover' and (f -> 'cover' ->> 'until')::timestamptz > now() then
    select * into pm from public.world_raid_members where raid_id = p_raid and owner_id = (f -> 'cover' ->> 'by')::uuid for update;
    if found and pm.out_until is null then
      perform public.world_raid_say(p_raid, 'coop', pm.name || ' — ' || m.name || '을(를) 노린 공격을 대신 막았습니다.');
      perform public.world_raid_credit(p_raid, pm.owner_id, p_raw * 0.5 * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0), 'guard');
      m := pm; who := pm.owner_id; p_raw := p_raw * 0.5;
    end if;
  end if;
  nm := m.name;
  r := public.world_cb_mitigate(p_raw, m.stats, m.fx, who, p_kind in ('slam', 'burst'), p_kind = 'burst', null, p_kind = 'single');
  for c in select * from jsonb_array_elements(r -> 'credits') loop
    perform public.world_raid_credit(p_raid, (c ->> 0)::uuid, (c ->> 1)::numeric, c ->> 2);
  end loop;
  f := r -> 'fx'; d := (r ->> 'd')::int; absorb := (r ->> 'absorb')::int;
  if (r ->> 'evaded')::boolean then
    update public.world_raid_members set fx = f where raid_id = p_raid and owner_id = who;
    perform public.world_raid_say(p_raid, 'miss', nm || ' — 공격을 피했습니다.');
    return 0;
  end if;
  perform public.world_raid_credit(p_raid, who, d, case when (r ->> 'taunt')::boolean then 'guard' else 'taken' end);
  update public.world_characters set health = greatest(1, health - d), updated_at = now() where owner_id = who returning health into hp;
  if hp <= 1 and d > 0 then
    update public.world_raid_members set taken = taken + d, fx = f - 'bound', out_until = now() + interval '60 seconds', falls = falls + 1 where raid_id = p_raid and owner_id = who;
    perform public.world_raid_say(p_raid, 'fall', nm || ' — ' || d || '의 피해를 입고 물러났습니다(1분 쉰 뒤 행동하면 돌아옴).');
  else
    update public.world_raid_members set taken = taken + d, fx = f where raid_id = p_raid and owner_id = who;
    perform public.world_raid_say(p_raid, 'hit', nm || ' — ' || d || '의 피해' || case when absorb > 0 then '(보호막이 ' || absorb || ' 받아 냄)' else '' end || '.');
  end if;
  return d;
end $function$;

-- 귀허: 태세는 이번 라운드 행동(고르지 않으면 방어), 보호막 줄·체력 반영(world_gw_hurt)만 남긴다
create or replace function public.world_gw_hit(p_fight uuid, p_uid uuid, p_raw numeric, p_round integer, p_why text, p_aoe boolean)
returns integer language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare m public.world_gw_members%rowtype; r jsonb; c jsonb; av text;
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid for update;
  if not found or m.out_rounds > 0 or m.rest then return 0; end if;
  av := coalesce(m.act ->> 'a', 'guard');
  r := public.world_cb_mitigate(p_raw, m.stats, m.fx, p_uid, p_aoe, false, case when av in ('guard', 'brace') then av end, false);
  for c in select * from jsonb_array_elements(r -> 'credits') loop
    perform public.world_gw_credit(p_fight, (c ->> 0)::uuid, (c ->> 1)::numeric, c ->> 2);
  end loop;
  if (r ->> 'absorb')::int > 0 then perform public.world_gw_say(p_fight, p_round, 'good', m.name || ' — 방호 법구가 ' || (r ->> 'absorb') || '을(를) 먼저 받아 냈습니다.'); end if;
  update public.world_gw_members set fx = r -> 'fx' where fight_id = p_fight and owner_id = p_uid;
  perform public.world_gw_credit(p_fight, p_uid, (r ->> 'd')::numeric, case when (r ->> 'taunt')::boolean then 'guard' else 'taken' end);
  return public.world_gw_hurt(p_fight, p_uid, (r ->> 'd')::int, p_round, p_why);
end $function$;

update public.world_patch_notes set body = body || $N$
## 7.7.7j
- 봉연 토벌과 귀허의 주인이 받는 피해를 같은 계산으로 맞췄습니다(능력치 → 내 방어·버티기 → 진언 → 결계 → 호법 → 보호막). 받는 피해는 그대로이고, 봉연에서 방어 중인 동료에게 결계·진언·호법을 걸어 준 사람의 「막아 준 피해」 기여가 방어로 줄어든 뒤의 피해 기준이 됩니다(귀허와 같게).
$N$ where note_id = '7.7.0' and position('## 7.7.7j' in body) = 0;

update public.world_app_meta set value = '20261104203700' where key = 'db_version';
