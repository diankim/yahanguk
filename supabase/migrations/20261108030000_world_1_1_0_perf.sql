create index if not exists world_map_regions_control_faction_idx on public.world_map_regions (control_faction_id);
create index if not exists world_blocks_blocked_idx on public.world_blocks (blocked_id);
create index if not exists world_character_cosmetics_key_idx on public.world_character_cosmetics (cosmetic_key);
create index if not exists world_circle_invites_invitee_idx on public.world_circle_invites (invitee_id);
create index if not exists world_circles_leader_idx on public.world_circles (leader_id);
create index if not exists world_expeditions_ground_idx on public.world_expeditions (ground_id);
create index if not exists world_expeditions_node_idx on public.world_expeditions (node_id);
create index if not exists world_fish_log_fish_idx on public.world_fish_log (fish_id);
create index if not exists world_item_durability_item_idx on public.world_item_durability (item_id);
create index if not exists world_region_monsters_kind_idx on public.world_region_monsters (kind);
create index if not exists world_region_progress_region_idx on public.world_region_progress (region_id);
create index if not exists world_story_clues_region_idx on public.world_story_clues (region_id);
create index if not exists world_story_clues_chapter_idx on public.world_story_clues (chapter_id);
create index if not exists world_story_combos_chapter_idx on public.world_story_combos (chapter_id);
create index if not exists world_hidden_trails_owner_idx on public.world_hidden_trails (owner_id);
create index if not exists world_region_influence_faction_idx on public.world_region_influence (faction_id);
create index if not exists world_faction_relations_b_idx on public.world_faction_relations (faction_b);
create index if not exists world_monster_gimmicks_kind_idx on public.world_monster_gimmicks (kind_key);
create index if not exists world_monster_codex_monster_idx on public.world_monster_codex (monster_id);
create index if not exists world_tourney_entrants_entry_idx on public.world_tourney_entrants (entry_id);
create index if not exists world_letters_sender_idx on public.world_letters (sender_id);
create index if not exists world_craft_favorites_recipe_idx on public.world_craft_favorites (recipe_id);

do $w$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.world_title_seen_migrated'::regclass and contype = 'p') then
    alter table public.world_title_seen_migrated add primary key (done_at);
  end if;
end $w$;

create or replace function public.world_title_progress_all(p_owner uuid)
returns jsonb language plpgsql stable security definer set search_path to '' as $f$
declare out jsonb := '{}'::jsonb; g record; p jsonb; t record;
begin
  for g in
    select tc.rule - 'n' as base, max(coalesce((tc.rule ->> 'n')::numeric, 1)) as top, array_agg(tc.title_key) keys, array_agg(coalesce((tc.rule ->> 'n')::numeric, 1)) ns
      from public.world_title_catalog tc
     where tc.active and not tc.hidden and tc.rule is not null and (tc.rule ? 'ev' or tc.rule ? 'distinct')
       and not exists (select 1 from public.world_character_titles ct where ct.owner_id = p_owner and ct.title_key = tc.title_key)
     group by 1
  loop
    p := public.world_title_rule_progress(p_owner, g.base || jsonb_build_object('n', g.top));
    for i in 1 .. array_length(g.keys, 1) loop
      out := out || jsonb_build_object(g.keys[i], jsonb_build_object('cur', least(coalesce((p ->> 'cur')::numeric, 0), g.ns[i]), 'need', g.ns[i]));
    end loop;
  end loop;
  for t in
    select tc.title_key, tc.rule from public.world_title_catalog tc
     where tc.active and not tc.hidden and tc.rule is not null and not (tc.rule ? 'ev' or tc.rule ? 'distinct')
       and not exists (select 1 from public.world_character_titles ct where ct.owner_id = p_owner and ct.title_key = tc.title_key)
  loop
    out := out || jsonb_build_object(t.title_key, public.world_title_rule_progress(p_owner, t.rule));
  end loop;
  return out;
end $f$;
revoke all on function public.world_title_progress_all(uuid) from public, anon, authenticated;
grant execute on function public.world_title_progress_all(uuid) to fn_owner_field, service_role;

do $w$
declare d text; own text; a text;
begin
  select pg_get_userbyid(proowner) into own from pg_proc where oid = 'public.world_title_snapshot'::regproc;
  execute format('grant execute on function public.world_title_progress_all(uuid) to %I', own);
  d := replace(pg_get_functiondef('public.world_title_snapshot'::regproc), E'\r\n', E'\n');
  if position('world_title_progress_all' in d) = 0 then
    a := $a$'progress', case when ct.owner_id is null and not tc.hidden then public.world_title_rule_progress(uid, tc.rule) end,$a$;
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.1.0 world_title_snapshot 기준 문구가 없습니다'; end if;
    d := replace(d, a, $x$'progress', case when ct.owner_id is null and not tc.hidden then prog -> tc.title_key end,$x$);
    a := $a$declare uid uuid := public.fn_owner_auth_uid(); out jsonb; disp text;$a$;
    if position(a in d) = 0 then raise exception '1.1.0 world_title_snapshot 선언 문구가 없습니다'; end if;
    d := replace(d, a, a || ' prog jsonb;');
    a := $a$select profile ->> 'title' into disp from public.world_characters where owner_id = uid;$a$;
    if position(a in d) = 0 then raise exception '1.1.0 world_title_snapshot 대표 문구가 없습니다'; end if;
    d := replace(d, a, a || E'\n  prog := public.world_title_progress_all(uid);');
    execute d;
  end if;
end $w$;

update public.world_app_meta set value = '20261108030000' where key = 'db_version';
