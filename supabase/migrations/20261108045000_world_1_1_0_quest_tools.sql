lock table public.world_characters in access exclusive mode;

create or replace function public.world_name_rules()
 returns jsonb
 language sql
 immutable
as $$
  select jsonb_build_object(
    'gather', jsonb_build_object('herbs', '약초', 'wood', '목재', 'supplies', '보급품', 'water', '물가', 'spirit', '영기', 'ore', '광맥', 'relics', '유물'),
    'field', jsonb_build_object('smithing', '단조', 'carpentry', '목공', 'artifice', '법구 공예', 'sealing', '봉인 공예', 'weaving', '직조', 'leatherwork', '가죽 공예', 'alchemy', '연금', 'cooking', '요리'))
$$;
revoke all on function public.world_name_rules() from public, anon, authenticated;
grant execute on function public.world_name_rules() to fn_owner_field, service_role;

create or replace function public.world_quest_task_label(p_task jsonb)
 returns text
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
#variable_conflict use_column
declare nm jsonb := public.world_name_rules();
begin
  return coalesce((select l.label from public.world_quest_label_cache l where l.k = md5(p_task::text)), (select * from (select case
    when p_task ->> 't' = 'raid' then case when p_task ->> 'kind' = 'world' then '봉연의 그림자 토벌 성공' else '구중 봉주와의 결전에서 이기기' end
    when p_task ->> 't' = 'win' and p_task ? 'm' then
      (select string_agg(distinct m.monster_name, '·') from public.world_region_monsters m where m.monster_id in (select jsonb_array_elements_text(p_task -> 'm'))) || ' 쓰러뜨리기'
    when p_task ->> 't' = 'gather' then
      coalesce((select string_agg(x.region_name, '·') || '에서 ' from public.world_map_regions x where x.region_id in (select jsonb_array_elements_text(p_task -> 'r'))), '')
      || coalesce((select string_agg(i.item_name, '·') from public.world_item_catalog i where i.item_id in (select jsonb_array_elements_text(p_task -> 'items'))) || ' 모으기', '채집하기')
      || case when p_task ? 'items' and p_task ? 'r' then coalesce(' (' || (select string_agg(z.k || ' 채집터 Lv' || z.mn || '~', '·' order by z.mn) from (
           select coalesce(nm -> 'gather' ->> sp.category, sp.category) k, min(sp.min_level) mn
             from public.world_gathering_spots sp join public.world_exploration_nodes n on n.node_id = sp.node_id
            where sp.active and n.region_id in (select jsonb_array_elements_text(p_task -> 'r'))
              and sp.loot_items && array(select jsonb_array_elements_text(p_task -> 'items'))
            group by 1) z) || ')', '') else '' end
    when p_task ->> 't' = 'craft' then
      coalesce((select string_agg(i.item_name, '·') from public.world_item_catalog i where i.item_id in (select jsonb_array_elements_text(p_task -> 'items'))) || ' 만들기',
               coalesce(nm -> 'field' ->> (p_task ->> 'field'), '') || ' 제작')
    when p_task ->> 't' = 'fish' then
      coalesce((select string_agg(x.region_name, '·') || '에서 ' from public.world_map_regions x where x.region_id in (select jsonb_array_elements_text(p_task -> 'r'))), '') || '물고기 낚아 올리기'
    else public.world_faction_task_label(p_task) end
) yhq limit 1));
end
$function$;

create or replace function public.world_faction_task_label(p_task jsonb)
 returns text
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
#variable_conflict use_column
begin
  return (select * from (select coalesce((select string_agg(m.region_name, '·') || '에서 ' from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(p_task -> 'r'))), '')
    || coalesce((select string_agg(e.env_name, '·' order by e.sort, e.env_key) || '에 ' from public.world_environment_catalog e
                  where e.kind = 'phase' and e.env_key in (select jsonb_array_elements_text(p_task -> 'phase'))), '')
    || coalesce((select string_agg(e.env_name, '·' order by e.sort, e.env_key) || ' 날씨에 ' from public.world_environment_catalog e
                  where e.kind = 'weather' and e.env_key in (select jsonb_array_elements_text(p_task -> 'weather'))), '')
    || case p_task ->> 't'
         when 'search' then case when coalesce((p_task ->> 'distinct')::boolean, false) then '서로 다른 곳에서 탐색' else '탐색' end
         when 'clue' then '탐색에서 단서 발견' when 'win' then case when p_task ->> 'rank' = 'guardian' then '우두머리 쓰러뜨리기' else '토벌 승리' end
         when 'gather' then '채집' when 'travel' then case when coalesce((p_task ->> 'safe')::boolean, false) then '서로 다른 안전지대 들르기' when p_task ? 'r' then '도착' else '다른 지역으로 이동' end
         when 'expedition' then '원정 완주' when 'sell' then '상점에서 팔기' when 'trade' then '거래소에서 사거나 팔기' when 'craft' then '제작' else '' end
) yhq limit 1);
end
$function$;

do $$
declare src text; old text; new text;
begin
  src := pg_get_functiondef('public.world_quest_task_count(uuid, jsonb, timestamptz)'::regprocedure);
  old := $o$select case when p_task ->> 't' = 'gw' then$o$;
  new := $n$select case when p_task ?| array['phase', 'weather', 'safe', 'distinct'] or p_task ->> 't' not in ('gw', 'raid', 'win', 'gather', 'craft', 'fish') then public.world_faction_task_count(p_uid, p_task, p_since)
    when p_task ->> 't' = 'gw' then$n$;
  if position(old in src) = 0 then raise exception 'world_quest_task_count: 바꿀 곳 없음'; end if;
  execute replace(src, old, new);
end $$;

create or replace function public.world_task_row(p_uid uuid, p_task jsonb, p_since timestamptz, p_loc text, p_live boolean)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare n int; it jsonb := case when jsonb_typeof(p_task -> 'items') = 'array' then p_task -> 'items' else '[]'::jsonb end;
begin
  n := case when not p_live then 0
            when p_task ->> 't' = 'travel' and p_task ? 'r' and exists (select 1 from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(p_task -> 'r')) and m.region_name = p_loc) then (p_task ->> 'n')::int
            else least((p_task ->> 'n')::int, public.world_quest_task_count(p_uid, p_task, p_since)) end;
  return jsonb_build_object('label', public.world_quest_task_label(p_task), 'cur', n, 'n', (p_task ->> 'n')::int, 't', p_task ->> 't',
    'regions', coalesce(p_task -> 'r', case when p_task ->> 't' = 'win' and p_task ? 'm' then (select jsonb_agg(distinct rm.region_id) from public.world_region_monsters rm where rm.monster_id in (select jsonb_array_elements_text(p_task -> 'm'))) end, '[]'::jsonb),
    'items', p_task -> 'items',
    'unit', case when p_task ->> 't' = 'gather' then case when jsonb_array_length(it) > 0 then '개' else '회' end when p_task ->> 't' = 'craft' and jsonb_array_length(it) > 0 then '개' else '' end);
end
$function$;
revoke all on function public.world_task_row(uuid, jsonb, timestamptz, text, boolean) from public, anon, authenticated;
grant execute on function public.world_task_row(uuid, jsonb, timestamptz, text, boolean) to fn_owner_field, service_role;

do $$
declare src text; old text; new text; fn regprocedure; o regrole;
begin
  fn := 'public.world_quest_step_state(uuid, text)'::regprocedure;
  src := pg_get_functiondef(fn);
  old := substring(src from '(  for t in select \* from jsonb_array_elements\(coalesce\(s\.need -> ''tasks'', ''\[\]''::jsonb\)\) loop.*?  end loop;\n)');
  if old is null or position('world_quest_task_count' in old) = 0 then raise exception 'world_quest_step_state: 바꿀 곳 없음'; end if;
  new := $n$  for t in select * from jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) loop
    t := public.world_task_row(p_uid, t, since, c.location, g.owner_id is not null);
    if (t ->> 'cur')::int < (t ->> 'n')::int then ready := false; end if;
    tasks := tasks || t;
  end loop;
$n$;
  execute replace(src, old, new);

  fn := 'public.world_faction_current(uuid, boolean)'::regprocedure;
  src := pg_get_functiondef(fn);
  old := substring(src from '(  for t in select \* from jsonb_array_elements\(coalesce\(s\.need -> ''tasks'', ''\[\]''::jsonb\)\) loop.*?  end loop;\n)');
  if old is null or position('world_faction_task_count' in old) = 0 then raise exception 'world_faction_current: 바꿀 곳 없음'; end if;
  new := $n$  for t in select * from jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) loop
    t := public.world_task_row(p_uid, t, p.step_started_at, c.location, locked is null);
    if (t ->> 'cur')::int < (t ->> 'n')::int then ready := false; end if;
    tasks := tasks || t;
  end loop;
$n$;
  execute replace(src, old, new);
end $$;

create or replace function public.world_pending_clue_task(p_uid uuid, p_region text)
 returns boolean
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare fc jsonb;
begin
  if exists (
      select 1 from public.world_quest_progress p
        join public.world_quest_steps s on s.quest_id = p.quest_id and s.step = p.step + 1
        cross join lateral jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) t
       where p.owner_id = p_uid and p.done_at is null and t ->> 't' = 'clue'
         and (not t ? 'r' or t -> 'r' ? p_region)
         and public.world_quest_task_count(p_uid, t, coalesce(p.step_started_at, p.started_at)) < coalesce((t ->> 'n')::int, 1)) then
    return true;
  end if;
  if not exists (select 1 from public.world_faction_progress fp join public.world_characters c on c.owner_id = fp.owner_id and c.major_faction_id = fp.faction_id
                  where fp.owner_id = p_uid and not fp.rejoin_pending) then
    return false;
  end if;
  fc := public.world_faction_current(p_uid, false);
  return fc is not null and fc ->> 'locked' is null and exists (
    select 1 from jsonb_array_elements(coalesce(fc -> 'tasks', '[]'::jsonb)) x
     where x ->> 't' = 'clue' and (x ->> 'cur')::int < (x ->> 'n')::int
       and (jsonb_array_length(coalesce(x -> 'regions', '[]'::jsonb)) = 0 or x -> 'regions' ? p_region));
end
$function$;

create or replace function public.world_quest_fee(p_uid uuid, p_gil bigint, p_have bigint, p_details jsonb)
 returns void
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
begin
  if coalesce(p_gil, 0) <= 0 then return; end if;
  if coalesce(p_have, 0) < p_gil then raise exception '%전이 필요합니다. (가진 전 %)', p_gil, coalesce(p_have, 0); end if;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (p_uid, 'quest_fee', -p_gil, true, p_details);
end
$function$;
revoke all on function public.world_quest_fee(uuid, bigint, bigint, jsonb) from public, anon, authenticated;
grant execute on function public.world_quest_fee(uuid, bigint, bigint, jsonb) to fn_owner_field, service_role;

create or replace function public.world_task_short(p_state jsonb)
 returns text
 language sql
 immutable
as $$
  select coalesce(
    (select '넘길 물품이 모자랍니다: ' || string_agg((x ->> 'name') || ' ' || (x ->> 'have') || '/' || (x ->> 'n'), '·')
       from jsonb_array_elements(coalesce(p_state -> 'give', '[]'::jsonb)) x where (x ->> 'have')::int < (x ->> 'n')::int
     having not exists (select 1 from jsonb_array_elements(coalesce(p_state -> 'tasks', '[]'::jsonb)) t where (t ->> 'cur')::int < (t ->> 'n')::int)),
    '아직 할 일이 남았습니다.')
$$;
revoke all on function public.world_task_short(jsonb) from public, anon, authenticated;
grant execute on function public.world_task_short(jsonb) to fn_owner_field, service_role;

do $$
declare src text; o1 text; n1 text; o2 text; n2 text;
begin
  src := pg_get_functiondef('public.world_quest_report(text)'::regprocedure);
  o1 := $o$  if not (st ->> 'ready')::boolean then raise exception '아직 할 일이 남았습니다.'; end if;$o$;
  n1 := $n$  if not (st ->> 'ready')::boolean then raise exception '%', public.world_task_short(st); end if;$n$;
  o2 := $o$    if c.gil < (s.need ->> 'gil')::int then raise exception '%전이 필요합니다. (가진 전 %)', (s.need ->> 'gil')::int, c.gil; end if;
    rw_gil := rw_gil - (s.need ->> 'gil')::int; msg := msg || '치른 값: ' || (s.need ->> 'gil') || '전 · ';
    insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (uid, 'quest_fee', -(s.need ->> 'gil')::int, true, jsonb_build_object('quest', p_quest));$o$;
  n2 := $n$    perform public.world_quest_fee(uid, (s.need ->> 'gil')::int, c.gil, jsonb_build_object('quest', p_quest));
    rw_gil := rw_gil - (s.need ->> 'gil')::int; msg := msg || '치른 값: ' || (s.need ->> 'gil') || '전 · ';$n$;
  if position(o1 in src) = 0 or position(o2 in src) = 0 then raise exception 'world_quest_report: 바꿀 곳 없음'; end if;
  src := replace(replace(src, o1, n1), o2, n2);
  src := regexp_replace(src, '\n *--[^\n]*', '', 'g');
  execute src;
end $$;

create or replace function public.world_faction_report()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; p public.world_faction_progress%rowtype; s public.world_faction_scenes%rowtype;
  cur jsonb; inv jsonb; it record; lim int; spk text[]; msg text := ''; fee int := 0;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = uid for update;
  if c.major_faction_id is null then raise exception '대세력에 들어야 합니다.'; end if;
  if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 보고할 수 없습니다.'; end if;
  perform public.world_travel_guard('세력 퀘스트 보고');
  p := public.world_faction_sync(uid);
  if p.rejoin_pending then
    select * into s from public.world_faction_scenes where scene_key = c.major_faction_id || ':rejoin:1';
    update public.world_faction_progress set rejoin_pending = false, updated_at = now() where owner_id = uid and faction_id = p.faction_id;
  else
    cur := public.world_faction_current(uid);
    if cur is null then raise exception '지금 이어 갈 세력 퀘스트가 없습니다.'; end if;
    if cur ->> 'locked' is not null then raise exception '%', cur ->> 'locked'; end if;
    if not (cur ->> 'here_ok')::boolean then raise exception '%에서 보고할 수 있습니다.', array_to_string(array(select jsonb_array_elements_text(cur -> 'at_names')), '·'); end if;
    if not (cur ->> 'ready')::boolean then raise exception '%', public.world_task_short(cur); end if;
    select * into s from public.world_faction_scenes where scene_key = cur ->> 'scene_key';
    fee := coalesce((cur ->> 'cost')::int, 0);
    perform public.world_quest_fee(uid, fee, c.gil, jsonb_build_object('faction_scene', s.scene_key));
    if fee > 0 then msg := msg || fee || '전을 냈습니다. '; end if;
    inv := coalesce(c.inventory, '{}'::jsonb); lim := public.world_bag_limit(uid);
    for it in select key, value::int q from jsonb_each_text(coalesce(s.reward -> 'items', '{}'::jsonb)) loop
      if public.world_bag_room(inv, it.key, lim) < it.q then raise exception '가방 자리가 모자랍니다. 보상을 받을 자리를 비운 뒤 다시 보고하세요.'; end if;
      inv := public.world_inv_add(inv, it.key, it.q);
      msg := msg || (select item_name from public.world_item_catalog where item_id = it.key) || ' ×' || it.q || ' ';
    end loop;
    if fee > 0 or inv is distinct from coalesce(c.inventory, '{}'::jsonb) then
      update public.world_characters set inventory = inv, gil = gil - fee, updated_at = now() where owner_id = uid;
    end if;
    if coalesce((s.reward ->> 'merit')::int, 0) > 0 then msg := msg || '공훈 +' || (s.reward ->> 'merit') || ' '; end if;
    update public.world_faction_progress
       set join_step = case when s.kind = 'join' then s.step else join_step end,
           join_done_at = case when s.kind = 'join' and s.step = 3 then now() else join_done_at end,
           rank = case when s.kind = 'rank' then s.step else rank end,
           merit = merit + coalesce((s.reward ->> 'merit')::int, 0), open_step = null, step_started_at = now(), updated_at = now()
     where owner_id = uid and faction_id = p.faction_id;
  end if;
  select array_agg(distinct x ->> 's') into spk from jsonb_array_elements(s.lines) x where x ->> 's' is not null;
  update public.world_faction_progress set npcs_met = array(select distinct unnest(npcs_met || coalesce(spk, '{}'))) where owner_id = uid and faction_id = p.faction_id;
  return jsonb_build_object('title', s.title, 'kind', s.kind, 'step', s.step, 'lines', s.lines, 'reward', nullif(trim(msg), ''),
    'cast', (select coalesce(jsonb_object_agg(z.npc_key, jsonb_build_object('name', z.npc_name, 'bio', z.bio)), '{}'::jsonb) from public.world_faction_npcs z where z.npc_key = any (spk)),
    'rank_name', (select r.rank_name from public.world_faction_ranks r join public.world_faction_progress q on q.faction_id = r.faction_id and q.rank = r.rank where q.owner_id = uid and q.faction_id = p.faction_id));
end $function$;

select public.world_quest_label_refresh();

update public.world_app_meta set value = '20261108045000' where key = 'db_version';
