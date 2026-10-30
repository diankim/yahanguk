-- 7.4.3 귀허도 요기 순응: 섬에서는 침식으로 공격력이 줄지 않는다(사용자 요청).
-- 7.4.1은 공격력 불이익(world_combat_stats의 mind)을 절반으로만 줄여, 위험 단계에서 공격력 −10%·주는 피해 +4%로 오히려 손해였다.
-- 정신 40·20 아래 공격력 불이익은 섬에서도 그대로.
do $do$
declare d text; o text; old text := 'IF c.erosion >= 30 AND public.world_on_island(p_owner) THEN mind := mind * (CASE WHEN c.erosion >= 80 THEN 0.85 WHEN c.erosion >= 55 THEN 0.9 ELSE 0.95 END); -- 귀허도 요기 순응(7.4.1)';
  new text := 'IF c.erosion >= 30 AND public.world_on_island(p_owner) THEN NULL; -- 귀허도 요기 순응: 섬에서는 침식으로 공격력이 줄지 않음(7.4.3)';
begin
  d := pg_get_functiondef('public.world_combat_stats(uuid,jsonb)'::regprocedure);
  if position(new in d) > 0 then return; end if;
  if position(old in d) = 0 then raise exception '7.4.1 섬 공격력 줄을 찾지 못함'; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = 'public.world_combat_stats(uuid,jsonb)'::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
  execute replace(d, old, new);
end $do$;

update public.world_patch_notes set body = body || $N$
## 7.4.3
- **귀허도 요기 순응 보강**: 섬에서는 침식이 높아도 **공격력이 줄지 않습니다**(7.4.1에서는 절반만 줄여 위험 단계에서 공격력 −10%·주는 피해 +4%로 오히려 손해였습니다). 이제 섬에서는 위험(55) 주는 피해 +4%, 붕괴 직전(80) +8%가 그대로 힘이 됩니다. 정신이 40·20 아래로 떨어졌을 때의 공격력 감소는 섬에서도 같습니다.
$N$ where note_id = '7.4.0' and position('## 7.4.3' in body) = 0;

update public.world_app_meta set value = '20261103231000' where key = 'db_version';
