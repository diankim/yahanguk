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

select pg_temp.yh_fix('world_bijang_rules()', array[
$q${"hi": 37, "id": "bj_map_1", "lo": 30,$q$, $q${"hi": 37, "id": "bj_map_1", "lo": 16,$q$,
$q${"hi": 43, "id": "bj_map_2", "lo": 38,$q$, $q${"hi": 43, "id": "bj_map_2", "lo": 21,$q$,
$q${"hi": 46, "id": "bj_map_3", "lo": 44,$q$, $q${"hi": 50, "id": "bj_map_3", "lo": 21,$q$,
$q$"guard": {"lv_up": 3, "hp_mul": 1.2, "atk_mul": 1.0,$q$, $q$"guard": {"lv_up": 3, "own_up": 1, "hp_mul": 1.6, "atk_mul": 1.2,$q$]);

select pg_temp.yh_fix('world_bijang_encounter(uuid,text,integer,text)', array[
$q$hpm numeric; atm numeric; v_intent text; rg int;$q$,
$q$hpm numeric; atm numeric; v_intent text; rg int; ol int;$q$,
$q$  lv := least(public.world_level_cap() + 1, greatest(coalesce(rg, 1), (public.world_bijang_map_rule(p_tier) ->> 'lv')::int) + (g ->> 'lv_up')::int);
  lv := greatest(1, least(lv, c.level + 6));$q$,
$q$  select level into ol from public.world_characters where owner_id = nullif(current_setting('yh.bj_owner', true), '')::uuid;
  lv := least(public.world_level_cap() + 1, greatest((public.world_bijang_map_rule(p_tier) ->> 'lv')::int + (g ->> 'lv_up')::int, coalesce(ol, c.level) + coalesce((g ->> 'own_up')::int, 1)));$q$]);

select pg_temp.yh_fix('world_bijang_spawn(uuid,integer,uuid,uuid[],boolean)', array[
$q$  e := public.world_bijang_encounter($q$,
$q$  perform set_config('yh.bj_owner', coalesce((select mp.owner_id from public.world_bijang_maps mp where mp.map_id = r.map_id), r.leader_id)::text, true);
  e := public.world_bijang_encounter($q$]);

update public.world_patch_notes set body = body || $n$

## 3.6.3
- 비장도가 가리키는 지역이 넓어졌습니다. 낡은 비장도는 Lv16~37, 귀한 비장도는 Lv21~43, 봉인된 비장도는 Lv21~50의 바깥 지역에서 고르며, 일곱 세력의 땅도 모두 들어갑니다.
- 비장고 파수꾼의 레벨은 지역이 아니라 비장도와 지도 주인에 맞춥니다. 비장도 레벨 + 3(낡은 33·귀한 41·봉인된 47)과 지도 주인 레벨 + 1 가운데 높은 쪽이며, 방마다 나오는 파수꾼도 같습니다.
- 비장고 파수꾼이 조금 더 단단하고 세졌습니다.
- 가방 줄의 창고 수량이 이름 옆 작은 칩으로 옮겨졌고, 누르면 창고가 열립니다. 긴 물품 이름은 잘리지 않고 줄을 바꿉니다.
- 세력 기부 물품을 고르는 창에서 받을 공훈이 바로 보입니다.
$n$
 where note_id = '3.5.0' and body not like '%## 3.6.3%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261125050000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
