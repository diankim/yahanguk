create or replace function pg_temp.yh_fix2(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); n int;
begin
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'yh_fix2 %: 조각이 % 번 있음', p_fn, n; end if;
  execute replace(src, p_old, p_new);
end $f$;

select pg_temp.yh_fix2('public.world_ucomm_post(text,integer,integer)'::regprocedure,
  $o$  if public.world_market_only(it.item_id) then$o$,
  $n$  if it.item_id = 'gwiryeong_cho' then raise exception '귀령초는 조사원 의뢰로 구할 수 없습니다.'; end if;
  if public.world_market_only(it.item_id) then$n$);

select pg_temp.yh_fix2('public.world_ucomm_collect(bigint)'::regprocedure,
  $o$  select item_name into nm from public.world_item_catalog where item_id = u.item_id;
  return jsonb_build_object('ok', true, 'content', '의뢰한 ' || nm || ' ×' || u.qty || '을(를) 받았습니다.');$o$,
  $n$  select string_agg(coalesce(i.item_name, e.key) || ' ×' || e.value::text, ', ' order by i.item_name) into nm
    from jsonb_each(u.delivered) e left join public.world_item_catalog i on i.item_id = e.key;
  return jsonb_build_object('ok', true, 'content', '의뢰한 ' || coalesce(nm, '') || '을(를) 받았습니다.');$n$);

update public.world_crafting_recipes set required_location = '야행국 본부 정청' where recipe_id = 'make_oil_lamp' and required_location = '본부 정청';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118020000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
