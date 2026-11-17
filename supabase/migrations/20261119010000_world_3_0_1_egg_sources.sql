create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;

create or replace function public.world_pet_egg_rules() returns jsonb
language sql immutable as $$
  select '{"eggs": {"pet_egg_3": 0.0006, "pet_egg_2": 0.005}, "token": {"egg": "pet_egg_3", "item": "pet_token", "n": 5}}'::jsonb
$$;
revoke all on function public.world_pet_egg_rules() from public, anon, authenticated;
grant execute on function public.world_pet_egg_rules() to fn_owner_field;

select pg_temp.yh_patch('public.world_event_char_apply()',
  $q$rare := case when random() < 0.0006 then 'pet_egg_3' when random() < 0.005 then 'pet_egg_2' end;$q$,
  $q$rare := case when random() < (public.world_pet_egg_rules() #>> '{eggs,pet_egg_3}')::numeric then 'pet_egg_3' when random() < (public.world_pet_egg_rules() #>> '{eggs,pet_egg_2}')::numeric then 'pet_egg_2' end;$q$);

select pg_temp.yh_patch('public.world_pet_token_trade()',
  $q$have int;
begin$q$,
  $q$have int; n int := (public.world_pet_egg_rules() #>> '{token,n}')::int;
begin$q$);
select pg_temp.yh_patch('public.world_pet_token_trade()',
  $q$if have < 5 then raise exception '동무 정표가 %개 있습니다. 다섯 개가 있어야 빛나는 알로 바꿀 수 있습니다.', have; end if;$q$,
  $q$if have < n then raise exception '동무 정표가 %개 있습니다. %개가 있어야 빛나는 알로 바꿀 수 있습니다.', have, n; end if;$q$);
select pg_temp.yh_patch('public.world_pet_token_trade()', $q$'pet_token', -5)$q$, $q$'pet_token', -n)$q$);
select pg_temp.yh_patch('public.world_pet_token_trade()',
  $q$'동무 정표 다섯 개를 엮어 「빛나는 알」 하나로 바꿨습니다.', 'left', have - 5)$q$,
  $q$format('동무 정표 %s개를 엮어 「빛나는 알」 하나로 바꿨습니다.', n), 'left', have - n)$q$);

select pg_temp.yh_patch('public.world_item_sources_all(text)',
  $q$'vault', exists (select 1 from public.world_faction_vault where item_id = p_item),$q$,
  $q$'vault', exists (select 1 from public.world_faction_vault where item_id = p_item),
    'luck', public.world_pet_egg_rules() -> 'eggs' ? p_item,
    'token', case when public.world_pet_egg_rules() #>> '{token,egg}' = p_item then (public.world_pet_egg_rules() #>> '{token,n}')::int end,$q$);

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261119010000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
