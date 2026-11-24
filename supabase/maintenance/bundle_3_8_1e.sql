-- 배포 앞(운영 전용): 운영의 postgres는 슈퍼유저가 아니라 inherit 없는 함수 주인 역할(fn_owner_*)의 함수를 create or replace 할 수 없다.
-- 이 트랜잭션 동안만 inherit을 켜고, owner_inherit_end.sql이 같은 목록을 원래대로(inherit false) 되돌린다.
create temp table yh_inh on commit drop as
select distinct r.rolname::text as r from pg_proc p join pg_roles r on r.oid = p.proowner
 where p.pronamespace = 'public'::regnamespace and r.rolname like 'fn\_owner%' and not pg_has_role('postgres', r.oid, 'USAGE');
do $i$ declare x text; begin for x in select r from yh_inh loop execute format('grant %I to postgres with inherit true', x); end loop; end $i$;

lock table public.world_app_meta, public.world_patch_notes in access exclusive mode;
create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_fish_rules()', array[
$q$"named": {"weight": 0.3, "boost": 0.5, "bait": 1}$q$, $q$"named": {"weight": 0.3, "boost": 0.5, "bait": 1, "floor": 0.1}$q$]);

select pg_temp.yh_fix('world_fish()', array[
$q$more int := 0; nmore int := 0;$q$,
$q$more int := 0; nmore int := 0; pid text; nfl numeric;$q$,
$q$  select * into sp from public.world_fish_species s
   where s.habitat = g.habitat and s.active and s.min_level <= c.level + 2 and (s.grounds is null or r.region_id = any(s.grounds))
     and (not s.named or (bait is not null and s.fish_id = any (bsp.bait_for) and s.phase = ph and s.weather = wk))
   order by -ln(greatest(random(), 1e-9)) / (
       (case when s.named then ((public.world_fish_rules() -> 'named' ->> 'weight')::numeric + nwt) * (1 + boost * (public.world_fish_rules() -> 'named' ->> 'boost')::numeric / 100.0)
        else coalesce((public.world_fish_rules() -> 'weight' ->> s.rarity)::numeric, (public.world_fish_rules() -> 'weight' ->> 'legendary')::numeric) * case when (public.world_fish_rules() -> 'boosted') ? s.rarity then 1 + boost / 100.0 else 1 end end)
     * (case when s.rarity in ('epic', 'legendary') and 'fishing_c43a' = any (sk) then 1.5 else 1 end)
     * (case when s.phase is null or s.named then 1 when s.phase = ph then (public.world_fish_rules() ->> 'match')::numeric when 'fishing_x30' = any (sk) then (public.world_fish_rules() ->> 'miss_skill')::numeric else (public.world_fish_rules() ->> 'miss')::numeric end)
     * (case when s.weather is null or s.named then 1 when s.weather = wk then (public.world_fish_rules() ->> 'match')::numeric when 'fishing_x30' = any (sk) then (public.world_fish_rules() ->> 'miss_skill')::numeric else (public.world_fish_rules() ->> 'miss')::numeric end)) limit 1;
$q$,
$q$  nfl := coalesce((public.world_fish_rules() -> 'named' ->> 'floor')::numeric, 0) / 100.0;
  with p as (select s.fish_id, s.named, (
       (case when s.named then ((public.world_fish_rules() -> 'named' ->> 'weight')::numeric + nwt) * (1 + boost * (public.world_fish_rules() -> 'named' ->> 'boost')::numeric / 100.0)
        else coalesce((public.world_fish_rules() -> 'weight' ->> s.rarity)::numeric, (public.world_fish_rules() -> 'weight' ->> 'legendary')::numeric) * case when (public.world_fish_rules() -> 'boosted') ? s.rarity then 1 + boost / 100.0 else 1 end end)
     * (case when s.rarity in ('epic', 'legendary') and 'fishing_c43a' = any (sk) then 1.5 else 1 end)
     * (case when s.phase is null or s.named then 1 when s.phase = ph then (public.world_fish_rules() ->> 'match')::numeric when 'fishing_x30' = any (sk) then (public.world_fish_rules() ->> 'miss_skill')::numeric else (public.world_fish_rules() ->> 'miss')::numeric end)
     * (case when s.weather is null or s.named then 1 when s.weather = wk then (public.world_fish_rules() ->> 'match')::numeric when 'fishing_x30' = any (sk) then (public.world_fish_rules() ->> 'miss_skill')::numeric else (public.world_fish_rules() ->> 'miss')::numeric end)) as wt from public.world_fish_species s
   where s.habitat = g.habitat and s.active and s.min_level <= c.level + 2 and (s.grounds is null or r.region_id = any(s.grounds))
     and (not s.named or (bait is not null and s.fish_id = any (bsp.bait_for) and s.phase = ph and s.weather = wk))
  ), t as (select coalesce(sum(p.wt) filter (where not p.named), 0) as w from p)
  select p.fish_id into pid from p cross join t
   order by -ln(greatest(random(), 1e-9)) / (case when p.named and nfl > 0 and nfl < 1 then greatest(p.wt, t.w * nfl / (1 - nfl)) else p.wt end) limit 1;
  select * into sp from public.world_fish_species s where s.fish_id = pid;
$q$]);

update public.world_patch_notes set body = body || $pn$
- [낚시] 바다·수로처럼 어종이 많은 낚시터에서 명어가 다른 낚시터보다 지나치게 드물게 물던 것을 조금 고쳤습니다. 명어가 무는 조건(시간대·날씨·미끼)은 그대로입니다.$pn$ where note_id = '3.8.0';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127050000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_ux_mech(uuid,integer,numeric)', array[
$q$  pillars int[]; kk text;$q$, $q$  pillars int[]; kk text; cname jsonb := '{}'::jsonb;$q$,
$q$  chainers := array(select y.pos from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'chain' and y.pos = any (pillars));$q$, $q$  chainers := array(select y.pos from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'chain' and y.pos = any (pillars));
  cname := coalesce((select jsonb_object_agg(y.pos::text, y.name) from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'chain' and y.pos = any (pillars)), '{}'::jsonb);$q$,
$q$          select string_agg(y.name, '·') into nm from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'chain'
            and y.pos in ((h ->> 'a')::int, (h ->> 'b')::int);$q$, $q$          nm := coalesce(nullif(concat_ws('·', cname ->> (h ->> 'a'), cname ->> (h ->> 'b')), ''), '함께한 조사원');$q$,
$q$          select string_agg(y.name, '·') into nm from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'chain' and y.pos = any (pillars)
            and not (y.pos = any (used));$q$, $q$          nm := coalesce((select string_agg(cname ->> z::text, '·') from unnest(chainers) z where not (z = any (used))), '함께한 조사원');$q$]);

update public.world_patch_notes set body = body || $pn$
- [싸움] 무용담 · 귀허의 주인에서 소용돌이에 끌려간 라운드에 사슬을 끊으면 싸움이 멈추던 것을 고쳤습니다.
- [이동] 지도에서 같은 곳에 함께 탈 파티원이 없으면 동승 칸 자리에 그 까닭을 한 줄로 알려 줍니다.$pn$ where note_id = '3.8.0';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127060000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;


-- 배포 끝: 앞에서 켠 inherit을 원래대로
do $i$ declare x text; begin for x in select r from yh_inh loop execute format('grant %I to postgres with inherit false', x); end loop; end $i$;
drop table yh_inh;
