create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  if position(p_new in d) > 0 then return; end if;
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;

select pg_temp.yh_patch('public.world_use_item_batch(text,integer)',
  $q$      if coalesce(jsonb_array_length(fx -> 'buffs'), 0) > 0
        and not exists$q$,
  $q$      if not exists$q$);
select pg_temp.yh_patch('public.world_use_item_batch(text,integer)',
  $q$        why := '기운이 이미 두 번 몫까지 찼습니다'; exit;$q$,
  $q$        why := case when coalesce(jsonb_array_length(fx -> 'buffs'), 0) > 0 then '기운이 이미 두 번 몫까지 찼습니다' else '더 채울 것이 없습니다' end; exit;$q$);

update public.world_patch_notes set body = body || $N$
- 물품 여러 개 쓰기(「전부」)에서 어죽처럼 기운이 없는 물품은 탐색력·정신 등이 가득 차도 멈추지 않고 끝까지 쓰이던 것을 고쳤습니다. 이제 더 채울 것이 없으면 그 자리에서 멈춥니다.$N$
 where note_id = '3.0.0' and position('기운이 없는 물품은 탐색력' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261119070000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
