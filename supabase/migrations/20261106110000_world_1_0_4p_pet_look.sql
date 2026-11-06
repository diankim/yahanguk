alter table public.world_pets add column if not exists baby_look boolean not null default false;

create or replace function public.world_pet_look_adult(p_affinity integer, p_baby boolean)
 returns boolean language sql immutable
as $f$ select coalesce(p_affinity, 0) >= 100 and not coalesce(p_baby, false) $f$;
revoke all on function public.world_pet_look_adult(integer, boolean) from public, anon, authenticated;
grant execute on function public.world_pet_look_adult(integer, boolean) to fn_owner_field, service_role;

do $w$
declare d text; a text; b text; f text; r record;
begin
  for r in select * from (values
    ('public.world_pet_act(uuid,text,text)', $a$'adult', pt.affinity >= 100,$a$, $b$'adult', public.world_pet_look_adult(pt.affinity, pt.baby_look), 'grown', pt.affinity >= 100,$b$),
    ('public.world_pet_profile_of(uuid)', $a$'adult', p.affinity >= 100,$a$, $b$'adult', public.world_pet_look_adult(p.affinity, p.baby_look),$b$),
    ('public.world_pet_room(uuid)', $a$'adult', coalesce(p.affinity, 0) >= 100,$a$, $b$'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'grown', coalesce(p.affinity, 0) >= 100,$b$),
    ('public.world_pet_snapshot()', $a$'adult', p.affinity >= 100,$a$, $b$'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'grown', p.affinity >= 100, 'baby', p.baby_look,$b$)
  ) v(fn, oldp, newp) loop
    d := replace(pg_get_functiondef(r.fn::regprocedure), E'\r\n', E'\n');
    if position('world_pet_look_adult' in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, r.oldp, ''))) / length(r.oldp) <> 1 then raise exception '1.0.4p % 기준 문구가 없습니다', r.fn; end if;
    execute replace(d, r.oldp, r.newp);
  end loop;
end $w$;

create or replace function public.world_pet_look(p_pet text, p_baby boolean)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); af int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select affinity into af from public.world_pets where owner_id = uid and pet_id = p_pet for update;
  if not found then raise exception '함께하는 동무가 아닙니다.'; end if;
  if af < 100 then raise exception '다 자란 동무만 모습을 고를 수 있습니다.'; end if;
  update public.world_pets set baby_look = coalesce(p_baby, false) where owner_id = uid and pet_id = p_pet;
  return jsonb_build_object('ok', true, 'baby', coalesce(p_baby, false), 'content', case when p_baby then '아기 모습으로 보입니다.' else '자란 모습으로 보입니다.' end);
end $function$;
revoke all on function public.world_pet_look(text, boolean) from public, anon, authenticated;
grant execute on function public.world_pet_look(text, boolean) to authenticated, service_role;
grant create on schema public to fn_owner_field;
alter function public.world_pet_look(text, boolean) owner to fn_owner_field;
revoke create on schema public from fn_owner_field;

update public.world_patch_notes set body = body ||
  E'\n### 꼬마 동무 모습 고르기\n- 다 자란 꼬마 동무는 아기 모습으로 둘 수 있습니다. 꼬마 동무 창의 도감에서 「아기 모습으로」를 누르면 조사원 카드와 별채에 아기 모습으로 보입니다(친밀도·다 자람은 그대로).\n'
where note_id = '1.0.0' and position('아기 모습으로 둘 수' in body) = 0;

update public.world_app_meta set value = '20261106110000' where key = 'db_version';
