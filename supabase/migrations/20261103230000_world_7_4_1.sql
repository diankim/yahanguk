-- 7.4.1 ① 귀허도 요기 순응: 섬에서는 침식이 +60% 더 오르므로 침식 불이익을 절반으로 줄이고, 위험(55)부터는 요기가 오히려 힘이 된다.
--   섬 밖과 같은 것: 희귀품·단서 덤, 위험 단계부터 행동마다 정신 −1, 100에 닿으면 정신 0, 요화 판정.
--   섬에서: 회복량 −8/−12/−18% · 받는 피해 +5/+10%(위험·붕괴 직전) · 요괴 조우 +10%(붕괴 직전) · 공격력 −5/−10/−15%
--          · 주는 피해 +4%(위험) · +8%(붕괴 직전, 밖에서는 −10%).
-- 7.4.1 ② 제작법 즐겨찾기(사람마다 30개까지): world_craft_favorites, world_craft_favs(), world_craft_fav_toggle(p_recipe).

-- ① 침식 단계 효과
do $do$
declare o text := pg_get_userbyid((select proowner from pg_proc where oid = 'public.world_erosion_effect(text)'::regprocedure));
begin
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
end $do$;

create or replace function public.world_erosion_effect(p_effect_key text)
 returns numeric
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
#variable_conflict use_column
begin
  -- 섬 판정은 침식 30 이상일 때만 한다(효과 합계가 키마다 불러서 가볍게)
  return (select * from (select coalesce((select case p_effect_key
        when 'healing_pct' then case when e >= 80 then case when isl then -18 else -35 end when e >= 55 then case when isl then -12 else -25 end when e >= 30 then case when isl then -8 else -15 end else 0 end
        when 'incoming_damage_pct' then case when e >= 80 then case when isl then 10 else 20 end when e >= 55 then case when isl then 5 else 10 end else 0 end
        when 'combat_damage_pct' then case when e >= 80 then case when isl then 8 else -10 end when e >= 55 and isl then 4 else 0 end
        when 'encounter_pct' then case when e >= 80 then case when isl then 10 else 20 end else 0 end
        when 'rare_loot_pct' then case when e >= 80 then 15 when e >= 55 then 10 when e >= 30 then 5 else 0 end
        when 'clue_bonus_pct' then case when e >= 80 then 15 when e >= 55 then 10 when e >= 30 then 5 else 0 end
        else 0 end
      from (select e, e >= 30 and coalesce((public.world_region_at(loc)).territory_id = 'gwiheo', false) as isl
            from (select coalesce(erosion, 0) as e, location as loc from public.world_characters where owner_id = public.fn_owner_auth_uid()) y) x), 0)::numeric
) yhq limit 1);
end
$function$;

-- 공격력 불이익(world_combat_stats의 mind, 무기 갈래와 상관없이 공격력에 곱함): 섬에서는 절반
create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $f$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
  execute replace(d, p_old, p_new);
end $f$;
select pg_temp.yh_patch('public.world_combat_stats(uuid,jsonb)',
  'IF c.erosion >= 80 THEN mind := mind * 0.7; ELSIF c.erosion >= 55 THEN mind := mind * 0.8; ELSIF c.erosion >= 30 THEN mind := mind * 0.9; END IF;',
  'IF c.erosion >= 30 AND public.world_on_island(p_owner) THEN mind := mind * (CASE WHEN c.erosion >= 80 THEN 0.85 WHEN c.erosion >= 55 THEN 0.9 ELSE 0.95 END); -- 귀허도 요기 순응(7.4.1)
  ELSIF c.erosion >= 80 THEN mind := mind * 0.7; ELSIF c.erosion >= 55 THEN mind := mind * 0.8; ELSIF c.erosion >= 30 THEN mind := mind * 0.9; END IF;');

-- ② 제작법 즐겨찾기
create table if not exists public.world_craft_favorites (
  owner_id uuid not null references auth.users(id) on delete cascade,
  recipe_id text not null references public.world_crafting_recipes(recipe_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, recipe_id)
);
alter table public.world_craft_favorites enable row level security;
revoke all on public.world_craft_favorites from public, anon, authenticated;

create or replace function public.world_craft_favs()
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
begin
  if auth.uid() is null then raise exception '로그인이 필요합니다.'; end if;
  return coalesce((select jsonb_agg(recipe_id order by created_at) from public.world_craft_favorites where owner_id = auth.uid()), '[]'::jsonb);
end
$function$;

create or replace function public.world_craft_fav_toggle(p_recipe text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := auth.uid(); n int; added boolean := false;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform pg_advisory_xact_lock(hashtext('yh-craft-fav'), hashtext(uid::text));
  if exists (select 1 from public.world_craft_favorites where owner_id = uid and recipe_id = p_recipe) then
    delete from public.world_craft_favorites where owner_id = uid and recipe_id = p_recipe;
  else
    if not exists (select 1 from public.world_crafting_recipes where recipe_id = p_recipe) then raise exception '없는 제작법입니다.'; end if;
    select count(*) into n from public.world_craft_favorites where owner_id = uid;
    if n >= 30 then raise exception '즐겨찾기는 30개까지입니다. 쓰지 않는 제작법을 먼저 빼 주세요.'; end if;
    insert into public.world_craft_favorites(owner_id, recipe_id) values (uid, p_recipe);
    added := true;
  end if;
  return jsonb_build_object('on', added, 'favs', public.world_craft_favs());
end
$function$;

revoke all on function public.world_craft_favs() from public, anon;
revoke all on function public.world_craft_fav_toggle(text) from public, anon;
grant execute on function public.world_craft_favs() to authenticated;
grant execute on function public.world_craft_fav_toggle(text) to authenticated;

-- ③ 패치노트: 7.4.0 본문 아래에 7.4.1
update public.world_patch_notes set body = body || $N$
## 7.4.1
- **제작법 즐겨찾기**: 가방 › 제작에서 제작법 이름 앞의 별을 누르면 즐겨찾기에 들어갑니다(30개까지). 「즐겨찾기」 칸에서 모아 보고, 다른 칸에서도 즐겨찾는 제작법이 먼저 나옵니다. 어느 기기에서든 같습니다.
- **귀허도 요기 순응**: 섬에서는 침식이 늘 높을 수밖에 없어 침식 불이익을 절반으로 줄였습니다(회복량·받는 피해·요괴 조우·공격력). 위험(55)부터는 요기가 오히려 힘이 되어 주는 피해 +4%, 붕괴 직전(80)은 +8%입니다(바깥에서는 −10%). 희귀품·단서 덤과 100에 닿으면 정신 0이 되는 것은 그대로입니다.
- **채팅 지난 말 읽기**: 채팅을 위로 올리면 그 탭의 더 이전 말을 이어서 불러옵니다(전체·지역·세력·모임, 채팅은 2일 보관). 전에는 처음 받은 몇 줄밖에 볼 수 없었습니다.
- 캐릭터 › 상태·도움말에 침식 불이익이 「술법」으로 적혀 있었지만 실제로는 무기와 상관없이 공격력 전체에 붙습니다. 글을 「공격력」으로 고쳤습니다(수치는 그대로).
- **원정 보급품**: 고르는 칸을 두 줄 격자로 바꿔 세로로 길어지지 않게 했습니다.
- **원정 중 배경음악**: 원정대가 나가 있는 동안은 전투 음악이 흐르고, 돌아오면 평소 음악으로 돌아갑니다.
$N$ where note_id = '7.4.0' and position('## 7.4.1' in body) = 0;

update public.world_app_meta set value = '20261103230000' where key = 'db_version';
