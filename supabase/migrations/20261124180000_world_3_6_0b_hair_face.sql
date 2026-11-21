do $m$
declare
  d text := pg_get_functiondef('public.world_design_clean(text,text,text,text,text,text)'::regprocedure);
  o text := $o$    if p_slot = 'hair' and exists (select 1 from generate_series(0, (m ->> 'bh')::int - 1) j, generate_series(0, (m ->> 'bw')::int - 1) i
        where substr(px, ((m ->> 'by')::int + j) * (m ->> 'w')::int + (m ->> 'bx')::int + i + 1, 1) <> '.') then
      raise exception '눈·입 자리는 칠할 수 없습니다.'; end if;
$o$;
begin
  if position(o in d) = 0 then raise exception 'world_design_clean: 눈·입 칸 검사 조각을 찾지 못함'; end if;
  execute replace(d, o, '');
end $m$;

do $m$
declare
  fn regprocedure := 'public.world_avatar_parts()'::regprocedure;
  j jsonb := public.world_avatar_parts();
  src text := pg_get_functiondef(fn);
  body text := (select prosrc from pg_proc where oid = fn);
begin
  if not (j -> 'free' -> 'hair') ? 'drape' then
    j := jsonb_set(j, '{free,hair}', (select jsonb_agg(v order by v) from jsonb_array_elements_text((j -> 'free' -> 'hair') || '"drape"') v));
  end if;
  if position(body in src) = 0 then raise exception 'world_avatar_parts: 본문을 못 찾음'; end if;
  execute replace(src, body, ' select ' || quote_literal(j::text) || '::jsonb ');
end $m$;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124180000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
