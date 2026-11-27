create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function public.world_token_rules() returns jsonb language sql immutable as $f$ select '{"cap": 1000}'::jsonb $f$;

create or replace function public.world_token_cap() returns trigger language plpgsql set search_path to 'pg_catalog', 'public' as $f$
declare cap int := (public.world_token_rules() ->> 'cap')::int;
begin
  if new.mount_tokens > old.mount_tokens and new.mount_tokens > cap then
    new.mount_tokens := greatest(old.mount_tokens, cap);
  end if;
  return new;
end $f$;
revoke all on function public.world_token_cap() from public, anon, authenticated;

drop trigger if exists trg_world_token_cap on public.world_characters;
create trigger trg_world_token_cap before update of mount_tokens on public.world_characters
  for each row when (new.mount_tokens > old.mount_tokens) execute function public.world_token_cap();

select pg_temp.yh_fix('world_use_item', array[
$a$    qty2 := (SELECT (ic.use_fx ->> 'tokens')::int FROM public.world_item_catalog ic WHERE ic.item_id = v_base);$a$,
$a$    qty2 := (SELECT (ic.use_fx ->> 'tokens')::int FROM public.world_item_catalog ic WHERE ic.item_id = v_base);
    IF (SELECT mount_tokens FROM public.world_characters WHERE owner_id = uid) >= (public.world_token_rules() ->> 'cap')::int THEN
      RAISE EXCEPTION '노정패가 이미 상한(%개)이라 더 받을 수 없습니다.', (public.world_token_rules() ->> 'cap')::int USING HINT = 'tokens_full';
    END IF;$a$
]);

update public.world_patch_notes set body = body || E'\n- [노정패] 지닐 수 있는 노정패가 1,000개까지로 정해졌습니다. 1,000개가 차면 그 뒤로 얻는 노정패는 쌓이지 않습니다. 이미 1,000개보다 많이 가진 분은 그대로 두며, 쓰다가 1,000개 아래로 내려가면 다시 쌓입니다.'
where note_id = '3.8.0' and position('[노정패] 지닐 수 있는' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261128020000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
