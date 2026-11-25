do $$
declare d text := pg_get_functiondef('public.world_project_view(text)'::regprocedure); o text;
  a1 text := 'if public.world_project_st_ok(uid) then select s.items into st from public.world_storage s where s.owner_id = uid; st := coalesce(st, ''{}''::jsonb); end if;';
  b1 text := 'if public.world_project_st_ok(uid) then select s.items into st from public.world_storage s where s.owner_id = uid; st := coalesce(st, ''{}''::jsonb); end if;
  select s.items into sa from public.world_storage s where s.owner_id = uid;';
  a2 text := '|| public.world_project_have(uid, c.inventory, st, x.id) order by x.o)';
  b2 text := '|| public.world_project_have(uid, c.inventory, st, x.id) || jsonb_build_object(''see_st'', coalesce((sa ->> x.id)::int, 0) + coalesce((sa ->> (x.id || ''_hq''))::int, 0)) order by x.o)';
  a3 text := 'st jsonb; items jsonb;';
  b3 text := 'st jsonb; sa jsonb; items jsonb;';
begin
  if position('see_st' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a1, ''))) / length(a1) <> 1 or (length(d) - length(replace(d, a2, ''))) / length(a2) <> 1 or (length(d) - length(replace(d, a3, ''))) / length(a3) <> 1 then
    raise exception 'world_project_view 고칠 자리 수가 다름';
  end if;
  select pg_get_userbyid(proowner) into o from pg_proc where oid = 'public.world_project_view(text)'::regprocedure;
  execute replace(replace(replace(d, a1, b1), a2, b2), a3, b3);
  execute format('alter function public.world_project_view(text) owner to %I', o);
end $$;

update public.world_patch_notes set body = body || E'\n- [사업] 빈약한 안전지대(반요촌·묵창 나루·남문 수로 선착·등지기 쉼막)의 사업 창에서도 품목마다 창고에 든 수가 보입니다. 그곳에서는 창고에서 꺼내 넘길 수 없어 「여기선 못 꺼냄」이 함께 붙습니다.'
where note_id = '3.8.0' and position('「여기선 못 꺼냄」' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127140000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
