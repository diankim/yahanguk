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
