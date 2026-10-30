-- 7.4.1 고쳐 쓰기(파일 번호만 7.4.3) 귀허도 요기 순응: 섬에서는 침식으로 공격력이 줄지 않는다(사용자 요청).
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

-- 패치노트: 따로 7.4.3 항목을 두지 않고 7.4.1의 「귀허도 요기 순응」 줄을 고쳐 쓴다(사용자 요청)
update public.world_patch_notes set body = replace(body,
 '- **귀허도 요기 순응**: 섬에서는 침식이 늘 높을 수밖에 없어 침식 불이익을 절반으로 줄였습니다(회복량·받는 피해·요괴 조우·공격력). 위험(55)부터는 요기가 오히려 힘이 되어 주는 피해 +4%, 붕괴 직전(80)은 +8%입니다(바깥에서는 −10%). 희귀품·단서 덤과 100에 닿으면 정신 0이 되는 것은 그대로입니다.',
 '- **귀허도 요기 순응**: 섬에서는 침식이 늘 높을 수밖에 없어, 섬에 있는 동안은 **침식으로 공격력이 줄지 않고** 나머지 침식 불이익(회복량·받는 피해·요괴 조우)도 절반으로 줄였습니다. 위험(55)부터는 요기가 오히려 힘이 되어 주는 피해 +4%, 붕괴 직전(80)은 +8%입니다(바깥에서는 −10%). 희귀품·단서 덤, 정신이 40·20 아래일 때의 공격력 감소, 100에 닿으면 정신 0이 되는 것은 그대로입니다.')
where note_id = '7.4.0';

update public.world_app_meta set value = '20261103231000' where key = 'db_version';
