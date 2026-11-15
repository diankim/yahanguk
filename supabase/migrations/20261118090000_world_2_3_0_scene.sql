create or replace function pg_temp.yh_fix2(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); n int;
begin
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'yh_fix2 %: 조각이 % 번 있음', p_fn, n; end if;
  execute replace(src, p_old, p_new);
end $f$;

create or replace function public.world_scene_rules()
 returns jsonb language sql immutable
as $f$ select '{"cap": 12}'::jsonb $f$;
revoke all on function public.world_scene_rules() from public, anon, authenticated;
grant execute on function public.world_scene_rules() to fn_owner_field;

create or replace function public.world_scene_folks(p_rows jsonb)
 returns jsonb language plpgsql stable security definer set search_path to ''
as $f$
declare viewer uuid := public.fn_owner_auth_uid(); cap int := (public.world_scene_rules() ->> 'cap')::int;
  res jsonb := '[]'::jsonb; seen uuid[] := '{}'; r jsonb; pid uuid; nm text; jb text; lk jsonb; ids bigint[] := '{}'; total int := 0; pet jsonb;
begin
  for r in select x from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) x loop
    pid := case when r ->> 'id' ~ '^[0-9a-f-]{36}$' then (r ->> 'id')::uuid end;
    if pid is null or pid = any (seen) then continue; end if;
    seen := seen || pid;
    nm := null;
    select ch.character_name, ch.job_key into nm, jb from public.world_characters ch where ch.owner_id = pid;
    if nm is null then continue; end if;
    total := total + 1;
    if jsonb_array_length(res) >= cap then continue; end if;
    lk := coalesce(public.world_avatar_look_of(pid), '{}'::jsonb);
    ids := ids || public.world_avatar_design_ids(lk);
    pet := null;
    select jsonb_build_object('id', f.pet_id, 'adult', public.world_pet_look_adult(p.affinity, p.baby_look)) into pet
      from public.world_pet_profile f join public.world_pets p on p.owner_id = f.owner_id and p.pet_id = f.pet_id where f.owner_id = pid;
    res := res || jsonb_build_array(r || jsonb_build_object('id', pid, 'name', nm, 'job', jb, 'look', lk, 'pet', pet, 'me', pid = viewer));
  end loop;
  return jsonb_build_object('list', res, 'more', greatest(0, total - jsonb_array_length(res)),
    'designs', case when cardinality(ids) > 0 then public.world_outfit_design_map(viewer, ids) else '{}'::jsonb end);
end $f$;
revoke all on function public.world_scene_folks(jsonb) from public, anon, authenticated;
grant execute on function public.world_scene_folks(jsonb) to fn_owner_field;

select pg_temp.yh_fix2('public.world_feast_view()'::regprocedure,
  $o$from public.world_feast_lines l where l.feast_id = f.feast_id));$o$,
  $n$from public.world_feast_lines l where l.feast_id = f.feast_id),
    'folks', public.world_scene_folks(
      (case when c.location = t ->> 'place' and me.owner_id is null then jsonb_build_array(jsonb_build_object('id', uid, 'role', 'watch')) else '[]'::jsonb end)
      || coalesce((select jsonb_agg(jsonb_build_object('id', m.owner_id, 'n', jsonb_build_object('joined', 1, 'pets', m.pets)) order by (m.owner_id = uid) desc, m.last_at desc nulls last, m.joined_at desc)
                     from public.world_feast_members m where m.feast_id = f.feast_id), '[]'::jsonb)));$n$);

select pg_temp.yh_fix2('public.world_wedding_view(uuid)'::regprocedure,
  $o$    'guests', (select count(*) from public.world_wedding_guests where wed_id = p_wed and owner_id not in (w.a_id, w.b_id)));$o$,
  $n$    'guests', (select count(*) from public.world_wedding_guests where wed_id = p_wed and owner_id not in (w.a_id, w.b_id)),
    'folks', public.world_scene_folks(
      (select jsonb_agg(jsonb_build_object('id', x.id, 'role', 'couple', 'side', x.o,
          'n', coalesce((select jsonb_build_object('bows', g.bows, 'cakes', g.cakes, 'pets', g.pets) from public.world_wedding_guests g where g.wed_id = p_wed and g.owner_id = x.id), '{}'::jsonb)) order by x.o)
         from (values (w.a_id, 1), (w.b_id, 2)) x(id, o))
      || (case when c.location = place and me.owner_id is null and uid not in (w.a_id, w.b_id) then jsonb_build_array(jsonb_build_object('id', uid, 'role', 'watch')) else '[]'::jsonb end)
      || coalesce((select jsonb_agg(jsonb_build_object('id', g.owner_id, 'n', jsonb_build_object('claps', g.claps, 'petals', g.petals, 'cups', g.cups, 'pets', g.pets, 'wished', case when g.wished then 1 else 0 end))
                      order by (g.owner_id = uid) desc, g.last_at desc nulls last)
                     from public.world_wedding_guests g where g.wed_id = p_wed and g.owner_id not in (w.a_id, w.b_id)), '[]'::jsonb)));$n$);

select pg_temp.yh_fix2('public.world_tourney_view(uuid)'::regprocedure,
  $o$from public.world_tourney_matches m where m.t_id = p_t));$o$,
  $n$from public.world_tourney_matches m where m.t_id = p_t),
    'folks', public.world_scene_folks(
      coalesce((select jsonb_agg(jsonb_build_object('id', z.u, 'role', 'fighter', 'side', z.s) order by z.s)
                  from (select unnest(e.members) u, case when e.entry_id = lm.a then 1 else 2 end s
                          from (select m.a, m.b from public.world_tourney_matches m where m.t_id = p_t and m.starts_at <= now() and m.ends_at > now() order by m.starts_at desc limit 1) lm
                          join public.world_tourney_entries e on e.entry_id in (lm.a, lm.b)) z), '[]'::jsonb)
      || (case when c.location = (select region_name from public.world_map_regions where region_id = t.venue_region) then jsonb_build_array(jsonb_build_object('id', uid, 'role', 'watch')) else '[]'::jsonb end)
      || coalesce((select jsonb_agg(jsonb_build_object('id', x.owner_id)) from public.world_tourney_entrants x where x.t_id = p_t), '[]'::jsonb)));$n$);

select pg_temp.yh_fix2('public.world_raid_snapshot(uuid)'::regprocedure,
  $o$  rid := nullif(s #>> '{raid,id}', '')::uuid;
$o$,
  $n$  rid := nullif(s #>> '{raid,id}', '')::uuid;
  if rid is not null and (s #>> '{raid,status}') = 'signup' then
    s := s || jsonb_build_object('folks', public.world_scene_folks(coalesce((select jsonb_agg(jsonb_build_object('id', m.owner_id, 'n', jsonb_build_object('join', 1)) order by (m.owner_id = auth.uid()) desc, m.joined_at)
      from public.world_raid_members m where m.raid_id = rid and m.left_at is null), '[]'::jsonb)));
  end if;
$n$);

insert into public.world_patch_notes (note_id, title, body)
values ('2.3.0', '2.3.0 · 함께 서는 자리',
'## 2.3.0
- 세력 행사·혼례·비무회·봉연의 그림자 모집 창 맨 위에 그 자리 장면이 생겼습니다. 함께하는 조사원들이 내 모습 그대로 서 있고, 나는 앞줄에 섭니다.
- 장면은 장소마다 다릅니다. 행사 일곱은 거점마다 소품이 다르고, 혼례는 초례상과 병풍, 비무회는 연무장, 봉연의 그림자는 봉인 말뚝이 선 출현지입니다. 하늘은 한국 시각의 시간대를 따릅니다.
- 박수·꽃잎·술잔 올리기·절하기·떡 돌리기·축사·함께하기·신청을 누르면 그 사람 머리 위에 짧게 말풍선과 효과가 뜹니다. 「동무 나서기」를 하면 데리고 다니는 동무가 옆에 나옵니다.
- 이름은 나와 주인공(혼례의 두 사람, 비무를 겨루는 두 편), 방금 무언가 한 사람에게만 붙고, 다른 사람은 누르면 이름이 잠깐 보입니다. 사람이 많으면 12명까지 보이고 나머지는 「외 n명」으로 적습니다.
')
on conflict (note_id) do nothing;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118090000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
