create or replace function public.world_hw_task_count(p_uid uuid, p_task jsonb, p_since timestamptz)
 returns int language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare tt text := p_task ->> 't'; rs text[] := case when jsonb_typeof(p_task -> 'r') = 'array' then array(select jsonb_array_elements_text(p_task -> 'r')) end;
  its text[] := case when jsonb_typeof(p_task -> 'items') = 'array' then array(select jsonb_array_elements_text(p_task -> 'items')) end;
begin
  if tt = 'hfeast' then
    return (select count(*)::int from public.world_hfeast_bowls b join public.world_hfeast_tables t on t.table_id = b.table_id
             where b.owner_id = p_uid and b.at >= p_since
               and (rs is null or exists (select 1 from public.world_hfeast_ports() p where p.port_id = t.port_id and (p.region_id = any (rs) or p.port_id = any (rs)))));
  end if;
  if tt = 'tradesale' then
    return coalesce((select sum((s ->> 'qty')::int * case when p_task ->> 'by' = 'gil' then coalesce((public.world_trade_good(s ->> 'good') ->> 'base')::int, 0) else 1 end)
      from public.world_economy_ledger l, jsonb_array_elements(l.details -> 'sold') s
     where l.owner_id = p_uid and l.action = 'trade_goods_sale' and l.created_at >= p_since
       and (rs is null or l.details ->> 'port' = any (rs))
       and (its is null or s ->> 'good' = any (its))), 0)::int;
  end if;
  if tt = 'lantern' then
    return (select count(*)::int from public.world_lanterns x
             where x.author_id = p_uid and x.created_at >= p_since and (rs is null or x.port = any (rs)));
  end if;
  return 0;
end $f$;
revoke all on function public.world_hw_task_count(uuid, jsonb, timestamptz) from public, anon, authenticated;
grant execute on function public.world_hw_task_count(uuid, jsonb, timestamptz) to service_role, postgres;
do $$ declare x text; begin
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' loop
    execute format('grant execute on function public.world_hw_task_count(uuid, jsonb, timestamptz) to %I', x);
  end loop;
end $$;

select pg_temp.yh_fix('world_faction_task_count', array[
  $a$begin
  return (select * from (with ev as ($a$,
  $a$begin
  if p_task ->> 't' in ('hfeast', 'tradesale', 'lantern') then return public.world_hw_task_count(p_uid, p_task, p_since); end if;
  return (select * from (with ev as ($a$])
 where position('world_hw_task_count' in pg_get_functiondef('public.world_faction_task_count(uuid,jsonb,timestamptz)'::regprocedure)) = 0;

select pg_temp.yh_fix('world_faction_task_label', array[
  $a$when 'expedition' then '원정 완주'$a$,
  $a$when 'hfeast' then '잔칫상에 요리 올리기'
         when 'tradesale' then coalesce((select string_agg(i.item_name, '·') from public.world_item_catalog i where i.item_id in (select jsonb_array_elements_text(p_task -> 'items'))) || ' ', '')
           || case when p_task ->> 'by' = 'gil' then '교역품 팔기(정가 합)' else '교역품 팔기' end
         when 'lantern' then '등불 편지 띄우기'
         when 'expedition' then '원정 완주'$a$])
 where position('''hfeast''' in pg_get_functiondef('public.world_faction_task_label(jsonb)'::regprocedure)) = 0;

select pg_temp.yh_fix('world_task_row', array[
  $a$when p_task ->> 't' = 'craft' and jsonb_array_length(it) > 0 then '개' else '' end);$a$,
  $a$when p_task ->> 't' = 'craft' and jsonb_array_length(it) > 0 then '개'
      when p_task ->> 't' = 'tradesale' then case when p_task ->> 'by' = 'gil' then '전' else '개' end when p_task ->> 't' = 'hfeast' then '그릇' else '' end);$a$])
 where position('''hfeast''' in pg_get_functiondef('public.world_task_row(uuid,jsonb,timestamptz,text,boolean)'::regprocedure)) = 0;
