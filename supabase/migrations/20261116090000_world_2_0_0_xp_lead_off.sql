create or replace function public.world_xp_lead_rules()
 returns jsonb
 language sql
 immutable
as $function$
  select jsonb_build_object('lead', 3, 'active_days', 2, 'active_min', 60, 'steps', '[]'::jsonb)
$function$;

do $c$ begin
  if not exists (select 1 from public.world_patch_notes where note_id = '2.0.0') then
    raise exception '2.0.0 패치노트가 없습니다';
  end if;
end $c$;
update public.world_patch_notes set body = body || $N$

### 성장
- 앞서 가는 조사원의 경험치를 줄이던 성장 조절을 없앴습니다. 이제 레벨과 상관없이 얻는 경험치를 그대로 받습니다.
$N$ where note_id = '2.0.0';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261116090000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
