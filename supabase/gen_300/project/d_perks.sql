create or replace function public.world_project_area_fx(p_uid uuid, p_key text)
 returns numeric language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare fac text; rid text; p jsonb;
begin
  select c.major_faction_id, (public.world_region_at(c.location)).region_id into fac, rid from public.world_characters c where c.owner_id = p_uid;
  if fac is null or rid is null then return 0; end if;
  p := public.world_project_rule('f:' || fac);
  if p is null or not (p -> 'area' ? rid) or not (p -> 'area_fx' ? p_key) then return 0; end if;
  if public.world_project_stage('f:' || fac) < 2 or not public.world_project_member(p_uid, 'f:' || fac) then return 0; end if;
  return (p -> 'area_fx' ->> p_key)::numeric;
end $f$;

create or replace function public.world_project_route(p_uid uuid, p_from text, p_to text)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare fac text; k text; p jsonb; far text; r jsonb := public.world_project_rules();
begin
  select c.major_faction_id into fac from public.world_characters c where c.owner_id = p_uid;
  if fac is not null then
    p := public.world_project_rule('f:' || fac);
    if p is not null and ((p -> 'hubs' ? p_from and p -> 'route' ? p_to) or (p -> 'hubs' ? p_to and p -> 'route' ? p_from))
       and public.world_project_stage('f:' || fac) >= 3 and public.world_project_member(p_uid, 'f:' || fac) then
      return jsonb_build_object('cut', (p -> 'route' ->> case when p -> 'hubs' ? p_from then p_to else p_from end)::numeric, 'free', true, 'key', 'f:' || fac);
    end if;
  end if;
  for k, p in select key, value from jsonb_each(r -> 'projects') where value ->> 'kind' = 'common' loop
    far := case when p -> 'hubs' ->> 0 = p_from then p_to when p -> 'hubs' ->> 0 = p_to then p_from end;
    if far is not null and p -> 'route' ? far and public.world_project_stage(k) >= (r -> 'lift' ->> 'route')::int and public.world_project_story(p_uid, k) then
      return jsonb_build_object('cut', (p -> 'route' ->> far)::numeric, 'free', true, 'key', k);
    end if;
  end loop;
  return null;
end $f$;

do $g$
declare f text;
begin
  foreach f in array array['world_project_area_fx(uuid, text)', 'world_project_route(uuid, text, text)'] loop
    perform pg_temp.pj_share('public.' || f);
    perform pg_temp.pj_own('public.' || f, 'fn_owner_field');
  end loop;
end $g$;

select pg_temp.pj_fix('world_social_effect', array[
$q$  return v;$q$, $q$  return v + public.world_project_area_fx(uid, p_key);$q$]);

select pg_temp.pj_fix('world_travel_plan', array[
$q$swap boolean;$q$, $q$swap boolean; pr jsonb;$q$,
$q$  need := fare;$q$, $q$  pr := public.world_project_route(p_uid, here.region_id, dest.region_id);
  IF coalesce((pr ->> 'free')::boolean, false) THEN fare := 0; n_free := 0; END IF;
  need := fare;$q$,
$q$  secs := greatest(12, least(10800, secs));$q$, $q$  secs := secs * (1 - coalesce((pr ->> 'cut')::numeric, 0));
  secs := greatest(12, least(10800, secs));$q$,
$q$'n_free', n_free, 'walked', walked,$q$, $q$'n_free', n_free, 'walked', walked, 'project', pr ->> 'key',$q$]);

select pg_temp.pj_fix('world_faction_snapshot', array[
$q$from public.world_faction_vault v where v.faction_id = c.major_faction_id$q$,
$q$from public.world_faction_vault v where v.faction_id = c.major_faction_id and v.stage_need <= public.world_project_stage('f:' || c.major_faction_id)$q$]);
select pg_temp.pj_fix('world_faction_vault_buy', array[
$q$if v.item_id is null then raise exception '비고에 없는 물품입니다.'; end if;$q$,
$q$if v.item_id is null then raise exception '비고에 없는 물품입니다.'; end if;
  if v.stage_need > public.world_project_stage('f:' || c.major_faction_id) then raise exception '거점 사업 %단계를 마치면 열리는 물품입니다.', v.stage_need; end if;$q$]);

select pg_temp.pj_fix('world_use_item(text)', array[
$q$  IF v_base = 'revival_charm' THEN RAISE EXCEPTION '회생 부적은 쓰러졌을 때 씁니다.'; END IF;$q$,
$q$  IF v_base = 'revival_charm' THEN RAISE EXCEPTION '회생 부적은 쓰러졌을 때 씁니다.'; END IF;
  IF coalesce((SELECT (ic.use_fx ->> 'tokens')::int FROM public.world_item_catalog ic WHERE ic.item_id = v_base), 0) > 0 THEN
    qty2 := (SELECT (ic.use_fx ->> 'tokens')::int FROM public.world_item_catalog ic WHERE ic.item_id = v_base);
    UPDATE public.world_characters SET inventory = public.world_inv_add(inv, p_item_id, -1), mount_tokens = mount_tokens + qty2, updated_at = now() WHERE owner_id = uid;
    RETURN jsonb_build_object('ok', true, 'content', nm || '을(를) 풀어 노정패 ' || qty2 || '개를 얻었습니다.', 'tokens', qty2);
  END IF;$q$]);

select pg_temp.pj_fix('world_pet_care_gain', array[
$q$when p_item = p_likes then 12$q$, $q$when p_item = p_likes or p_item = 'treat_box' then 12$q$]);
select pg_temp.pj_fix('world_pet_act', array[
$q$react := case when p_item = sp.likes then 'star'$q$, $q$react := case when p_item = sp.likes or p_item = 'treat_box' then 'star'$q$]);
