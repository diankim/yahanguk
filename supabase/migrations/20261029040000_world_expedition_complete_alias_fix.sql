-- 원정 귀환 오류 고침(2026-10-29): 20261029030000에서 장착 수를 세려고 넣은 표 별칭 e가
--   world_expedition_complete의 변수 e(원정 행)와 겹쳐 「column reference "e.owner_id" is ambiguous」로 귀환이 막혔다. 별칭을 ce로 바꾼다.
grant fn_owner_field to postgres with inherit true, set true;

do $$
declare d text := pg_get_functiondef('public.world_expedition_complete(boolean)'::regprocedure);
  a text := '(select count(*)::int from public.world_character_equipment e where e.owner_id = c.owner_id and coalesce((inv ->> e.item_id)::numeric, 0) > 0)';
  b text := '(select count(*)::int from public.world_character_equipment ce where ce.owner_id = c.owner_id and coalesce((inv ->> ce.item_id)::numeric, 0) > 0)';
begin
  if position(b in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '원정 귀환 고칠 자리가 하나가 아닙니다'; end if;
  execute replace(d, a, b);
end $$;

grant fn_owner_field to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261029040000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
