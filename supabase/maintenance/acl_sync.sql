-- 서버 이사 뒤 권한 맞추기: 옛 DB의 public 함수·표·시퀀스 권한(ACL)을 새 DB에 똑같이 맞춘다.
-- 새 프로젝트는 기본 권한(default privileges) 때문에 복원으로 만든 객체에 anon·authenticated 권한이 붙는데,
-- pg_dump는 옛 DB에서 거둔 그 권한을 다시 거두는 줄을 남기지 않는다(기준이 Postgres 기본값이라서).
-- 사용: psql 새DB -v acl="<옛 DB의 {키: ACL} JSON>" -f acl_sync.sql   (.github/workflows/db-move.yml의 ACL 모드)
-- 키는 'f:<함수 시그니처>' 또는 'r:<표·시퀀스 이름>'. 새 DB에만 있는 권한은 거두고, 옛 DB에만 있던 권한은 준다(같은 권한 준 사람으로).
\set ON_ERROR_STOP 1
select set_config('yh.acl', :'acl', false) is not null as loaded;

do $r$ declare r text; begin
  for r in select rolname from pg_roles where rolname like 'fn\_owner%' loop
    execute format('grant %I to postgres with inherit true', r);
  end loop;
end $r$;

do $fix$
declare m jsonb := current_setting('yh.acl')::jsonb; k text; oldv text; oldacl aclitem[]; obj text; newacl aclitem[]; e record; nrev int := 0; ngr int := 0;
begin
  for k, oldv in select key, value from jsonb_each_text(m) loop
    oldacl := nullif(oldv, '')::aclitem[];
    obj := null;
    if k like 'f:%' then
      select 'function ' || p.oid::regprocedure::text, p.proacl into obj, newacl from pg_proc p where p.oid = to_regprocedure('public.' || substr(k, 3));
    else
      select case c.relkind when 'S' then 'sequence ' else 'table ' end || c.oid::regclass::text, c.relacl into obj, newacl from pg_class c where c.oid = to_regclass('public.' || quote_ident(substr(k, 3)));
    end if;
    if obj is null then raise notice '새 DB에 없음: %', k; continue; end if;
    for e in select * from aclexplode(coalesce(newacl, '{}')) x where not exists (select 1 from aclexplode(coalesce(oldacl, '{}')) y where y.grantee = x.grantee and y.privilege_type = x.privilege_type) loop
      execute format('revoke %s on %s from %s granted by %I', e.privilege_type, obj, case when e.grantee = 0 then 'public' else quote_ident(pg_get_userbyid(e.grantee)) end, pg_get_userbyid(e.grantor));
      nrev := nrev + 1;
    end loop;
    for e in select * from aclexplode(coalesce(oldacl, '{}')) y where not exists (select 1 from aclexplode(coalesce(newacl, '{}')) x where y.grantee = x.grantee and y.privilege_type = x.privilege_type) loop
      execute format('grant %s on %s to %s granted by %I', e.privilege_type, obj, case when e.grantee = 0 then 'public' else quote_ident(pg_get_userbyid(e.grantee)) end, pg_get_userbyid(e.grantor));
      ngr := ngr + 1;
    end loop;
  end loop;
  raise notice '거둔 권한 %, 준 권한 %', nrev, ngr;
end $fix$;

do $r$ declare r text; begin
  for r in select rolname from pg_roles where rolname like 'fn\_owner%' loop
    execute format('grant %I to postgres with inherit false, set false', r);
  end loop;
end $r$;
