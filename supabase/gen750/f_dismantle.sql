-- ── 분해(7.5.0): 언제나 할 수 있고 그 장비 계열 경험 12, 계열 단계가 모자라면 재료 없이 경험만 ──
create or replace function public.world_dismantle_need(p_tier integer)
returns integer language plpgsql immutable set search_path = pg_catalog as $f$
begin
  return case coalesce(p_tier, 1) when 1 then 1 when 2 then 3 when 3 then 6 when 4 then 9 when 5 then 12 else 15 end;
end $f$;

create or replace function public.world_dismantle_yield(p_item text)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $function$
declare it public.world_item_catalog%rowtype; ing jsonb; out jsonb := '{}'::jsonb; k text; v int; b text;
begin
  select * into it from public.world_item_catalog where item_id = p_item;
  if not found then return '{}'::jsonb; end if;
  b := coalesce(it.base_item_id, it.item_id); -- 우수품은 기본 물품의 제작법으로(더 주지 않음)
  select r.ingredients into ing from public.world_crafting_recipes r where r.output_item = b order by r.recipe_id limit 1;
  if ing is null then
    select r.ingredients into ing from public.world_crafting_recipes r join public.world_item_catalog o on o.item_id = r.output_item
     where o.category = it.category and o.tier between greatest(1, it.tier - 1) and it.tier and r.ingredients <> '{}'::jsonb
     order by o.tier desc, r.recipe_id limit 1;
  end if;
  if ing is null or ing = '{}'::jsonb then return jsonb_build_object('spirit_dust', greatest(1, coalesce(it.tier, 1))); end if;
  for k, v in select key, (value)::text::int from jsonb_each(ing) loop
    if floor(v * 0.5) >= 1 then out := out || jsonb_build_object(k, floor(v * 0.5)::int); end if;
  end loop;
  if out = '{}'::jsonb then
    select key into k from jsonb_each(ing) order by (value)::text::int desc, key limit 1;
    out := jsonb_build_object(k, 1);
  end if;
  return out;
end $function$;

create or replace function public.world_dismantle_item(p_item_id text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; it public.world_item_catalog%rowtype; have int; y jsonb := '{}'::jsonb; inv jsonb;
  k text; v int; need int; rk int; gain int; sxp int; nm text := ''; line text; lname text; no_y boolean; sk text[]; extra_k text; msg text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if; perform set_config('yh.wear_leaves', 'on', true);
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 분해할 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then raise exception '전투 중에는 분해할 수 없습니다.'; end if;
  select * into it from public.world_item_catalog where item_id = p_item_id;
  if not found or it.category not in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool') then raise exception '분해할 수 있는 장비가 아닙니다.'; end if;
  inv := coalesce(c.inventory, '{}'::jsonb); have := coalesce((inv ->> p_item_id)::int, 0);
  if have < 1 then raise exception '가방에 그 장비가 없습니다.'; end if;
  perform public.world_item_give_guard(uid, p_item_id, have, 1);
  line := public.world_gear_line(p_item_id); lname := public.world_line_name(line);
  need := public.world_dismantle_need(it.tier);
  rk := coalesce((c.skill_progress -> line ->> 'rank')::int, 1);
  no_y := rk < need;
  if not no_y then
    y := public.world_dismantle_yield(p_item_id);
    -- 법기 해체·올 풀기·짐틀 장인·부적 해체(43b): 그 계열 장비면 돌려받는 재료 하나를 하나 더
    sk := public.world_skill_procs(uid);
    if line in ('artifice', 'weaving', 'leatherwork', 'wardcraft') and (line || '_c43b') = any (sk) and y <> '{}'::jsonb then
      select key into extra_k from jsonb_each(y) order by random() limit 1;
      y := jsonb_set(y, array[extra_k], to_jsonb((y ->> extra_k)::int + 1));
    end if;
  end if;
  inv := case when have - 1 <= 0 then inv - p_item_id else jsonb_set(inv, array[p_item_id], to_jsonb(have - 1)) end;
  for k, v in select key, (value)::text::int from jsonb_each(y) loop
    inv := jsonb_set(inv, array[k], to_jsonb(coalesce((inv ->> k)::int, 0) + v), true);
    nm := nm || case when nm = '' then '' else ', ' end || coalesce((select item_name from public.world_item_catalog where item_id = k), k) || ' ×' || v;
  end loop;
  gain := 6 * coalesce(it.tier, 1);
  sxp := round(12 * greatest(0.5, 1 + public.world_status_self(uid, 'training_xp_pct') / 100.0))::int;
  -- 기술 경험은 같은 UPDATE에서(단계는 trg_world_skill_sync가 다시 매김)
  update public.world_characters set inventory = inv, crafting_xp = coalesce(crafting_xp, 0) + gain,
    skill_progress = public.world_skill_add(skill_progress, line, sxp), updated_at = now()
   where owner_id = uid;
  msg := case when no_y then it.item_name || '을(를) 분해했습니다 · 재료는 돌려받지 못했습니다(' || lname || ' ' || need || '단계부터) · ' || lname || ' 경험 +' || sxp
    else it.item_name || '을(를) 분해해 ' || nm || '을(를) 얻었습니다 · ' || lname || ' 경험 +' || sxp end;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'dismantle', case when no_y then it.item_name || ' 분해(재료 없음)' else it.item_name || ' 분해 → ' || nm end,
    jsonb_build_object('item', p_item_id, 'yield', y, 'xp', gain, 'line', line, 'need', need, 'rank', rk, 'no_yield', no_y, 'skill_xp', sxp));
  return jsonb_build_object('ok', true, 'content', msg, 'yield', y, 'no_yield', no_y, 'need', need, 'rank', rk, 'line', line, 'line_name', lname, 'skill_xp', sxp);
end $function$;

-- 분해 창·물품 정보 창이 열릴 때만 부른다: 가방의 장비마다 맡는 계열·재료가 나오는 단계·지금 단계
create or replace function public.world_dismantle_info()
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; out jsonb := '{}'::jsonb; r record; ln text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then return out; end if;
  for r in select i.item_id, i.tier from jsonb_each_text(coalesce(c.inventory, '{}'::jsonb)) e join public.world_item_catalog i on i.item_id = e.key
            where e.value::numeric > 0 and i.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool') loop
    ln := public.world_gear_line(r.item_id);
    out := out || jsonb_build_object(r.item_id, jsonb_build_object('line', ln, 'line_name', public.world_line_name(ln),
      'need', public.world_dismantle_need(r.tier), 'rank', coalesce((c.skill_progress -> ln ->> 'rank')::int, 1),
      'yield', case when coalesce((c.skill_progress -> ln ->> 'rank')::int, 1) >= public.world_dismantle_need(r.tier) then public.world_dismantle_yield(r.item_id) else '{}'::jsonb end));
  end loop;
  return out;
end $function$;
revoke all on function public.world_dismantle_info() from public, anon;
grant execute on function public.world_dismantle_info() to authenticated;
