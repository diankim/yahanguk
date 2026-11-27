lock table public.world_characters, public.world_storage, public.world_gw_records in share row exclusive mode;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

do $$
declare r jsonb := public.world_boss_rules(); k text;
begin
  foreach k in array array['gwiheo', 'mukjeok', 'gapgwi', 'baekya'] loop
    r := jsonb_set(r, array[k], (r -> k) - 'item' - 'item_name' - 'item_where' - 'shop_name');
    r := jsonb_set(r, array[k, 'fail'], (r -> k -> 'fail') - 'cd');
  end loop;
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$', r);
end $$;

select pg_temp.yh_fix('world_gw_ready_check', array[
$a$  select * into rec from public.world_gw_records where owner_id = p_uid and boss_id = p_boss;
  if rec.last_kill_day = (now() at time zone 'Asia/Seoul')::date then
    raise exception '오늘은 이미 %. 내일(한국 시각 0시 뒤) 다시 도전할 수 있습니다.', case when p_boss = 'mukjeok' then '먹그림자를 보냈습니다' when p_boss = 'baekya' then '흰 밤을 걷어 냈습니다' when p_boss = 'gapgwi' then '값귀를 쓰러뜨렸습니다' else '귀허의 주인을 쓰러뜨렸습니다' end;
  end if;
  if rec.last_fail_at > now() - make_interval(mins => (br -> 'fail' ->> 'cd')::int) then
    raise exception '%. %분 뒤 다시 도전할 수 있습니다.', case when p_boss = 'mukjeok' then '명부의 먹이 아직 마르지 않았습니다' when p_boss = 'baekya' then '맹약 마당이 아직 하얗게 바래 있습니다' when p_boss = 'gapgwi' then '값귀의 장부가 아직 젖어 있습니다' else '귀허의 소용돌이가 아직 가라앉지 않았습니다' end,
      ceil(extract(epoch from rec.last_fail_at + make_interval(mins => (br -> 'fail' ->> 'cd')::int) - now()) / 60);
  end if;
  if coalesce((c.inventory ->> (br ->> 'item'))::int, 0) < 1 then raise exception '%이(가) 필요합니다. %', br ->> 'item_name', coalesce(br ->> 'item_where', br ->> 'shop_name' || '에서 팝니다.'); end if;
$a$, '']);

select pg_temp.yh_fix('world_gw_start', array[
  $a$if (f.mode = 'hard' and coalesce((x.inventory ->> v_item)::int, 0) < 1) or x.health <= 0 then$a$, $a$if x.health <= 0 then$a$,
  $a$    if f.mode = 'hard' then
      update public.world_characters set inventory = public.world_inv_add(inventory, v_item, -1), updated_at = now() where owner_id = x.owner_id;
    end if;
$a$, '']);

select pg_temp.yh_fix('world_gw_open', array[
  $a$'이(가) 맹약 마당에서 백야 앞에 섰습니다. 60초 안에 합류하세요' || case when md = 'story' then '.' else '(' || (br ->> 'item_name') || ' 1개).' end$a$, $a$'이(가) 맹약 마당에서 백야 앞에 섰습니다. 60초 안에 합류하세요.'$a$,
  $a$'이(가) 붉은 사당 골목에서 값귀 앞에 섰습니다. 60초 안에 합류하세요' || case when md = 'story' then '.' else '(' || (br ->> 'item_name') || ' 1개).' end$a$, $a$'이(가) 붉은 사당 골목에서 값귀 앞에 섰습니다. 60초 안에 합류하세요.'$a$,
  $a$'이(가) 아홉 칸 명부 앞에 섰습니다. 60초 안에 합류하세요' || case when md = 'story' then '.' else '(' || (br ->> 'item_name') || ' 1개).' end$a$, $a$'이(가) 아홉 칸 명부 앞에 섰습니다. 60초 안에 합류하세요.'$a$,
  $a$'이(가) 귀허의 주인 앞에 섰습니다. 60초 안에 합류하세요' || case when md = 'story' then '.' else '(귀허 부적 1개).' end$a$, $a$'이(가) 귀허의 주인 앞에 섰습니다. 60초 안에 합류하세요.'$a$]);

select pg_temp.yh_fix('world_gw_settle', array[
  $a$'오늘은 이미 처치를 인정받아 보상은 없습니다.'$a$, $a$'오늘은 이미 처치를 인정받아 보상은 없습니다. 연습 삼아 몇 번이든 다시 설 수 있습니다.'$a$,
  $a$침식이 10 올랐습니다. 30분 뒤 다시 도전할 수 있습니다.'$a$, $a$침식이 10 올랐습니다. 바로 다시 도전할 수 있습니다.'$a$]);
select pg_temp.yh_fix('world_mk_settle', array[
  $a$'오늘은 이미 처치를 인정받아 보상은 없습니다.'$a$, $a$'오늘은 이미 처치를 인정받아 보상은 없습니다. 연습 삼아 몇 번이든 다시 설 수 있습니다.'$a$,
  $a$|| (r -> 'fail' ->> 'cd') || '분 뒤 다시 도전할 수 있습니다.'$a$, $a$|| '바로 다시 도전할 수 있습니다.'$a$]);
select pg_temp.yh_fix('world_gg_settle', array[
  $a$'오늘은 이미 처치를 인정받아 보상은 없습니다.'$a$, $a$'오늘은 이미 처치를 인정받아 보상은 없습니다. 연습 삼아 몇 번이든 다시 설 수 있습니다.'$a$,
  $a$|| (r -> 'fail' ->> 'cd') || '분 뒤 다시 도전할 수 있습니다.'$a$, $a$|| '바로 다시 도전할 수 있습니다.'$a$]);
select pg_temp.yh_fix('world_by_settle', array[
  $a$'오늘은 이미 처치를 인정받아 보상은 없습니다.'$a$, $a$'오늘은 이미 처치를 인정받아 보상은 없습니다. 연습 삼아 몇 번이든 다시 설 수 있습니다.'$a$,
  $a$|| (r -> 'fail' ->> 'cd') || '분 뒤 다시 도전할 수 있습니다.'$a$, $a$|| '바로 다시 도전할 수 있습니다.'$a$]);

do $$
declare x record; n int := 0; total int := 0;
begin
  for x in
    select o, sum(q)::int q from (
      select c.owner_id o, coalesce((c.inventory ->> 'gwiheo_charm')::int, 0) + coalesce((c.inventory ->> 'seal_inkline')::int, 0) q from public.world_characters c where c.inventory ?| array['gwiheo_charm', 'seal_inkline']
      union all select s.owner_id, coalesce((s.items ->> 'gwiheo_charm')::int, 0) + coalesce((s.items ->> 'seal_inkline')::int, 0) from public.world_storage s where s.items ?| array['gwiheo_charm', 'seal_inkline']
      union all select v.owner_id, v.qty from public.world_overflow_items v where v.item_id in ('gwiheo_charm', 'seal_inkline')
    ) y where q > 0 group by o
  loop
    update public.world_characters set inventory = inventory - 'gwiheo_charm' - 'seal_inkline', gil = gil + 800 * x.q, updated_at = now() where owner_id = x.o;
    update public.world_storage set items = items - 'gwiheo_charm' - 'seal_inkline' where owner_id = x.o;
    delete from public.world_overflow_items where owner_id = x.o and item_id in ('gwiheo_charm', 'seal_inkline');
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (x.o, 'reward', '입장 물품을 돌려받았습니다', '깊은 판에 입장 물품이 필요 없어져, 가지고 있던 귀허 부적·봉인 먹줄 ' || x.q || '개를 거두고 하나에 800전씩 ' || to_char(800 * x.q, 'FM999,999') || '전으로 돌려드렸습니다.', jsonb_build_object('refund', 800 * x.q));
    n := n + 1; total := total + x.q;
  end loop;
  raise notice '입장 물품 거둠: %명 %개', n, total;
end $$;

delete from public.world_shop_stock where item_id in ('gwiheo_charm', 'seal_inkline');
delete from public.world_shop_catalog where item_id in ('gwiheo_charm', 'seal_inkline');
update public.world_item_catalog set description = description || ' 지금은 깊은 판에 입장 물품이 필요 없어 쓰이지 않는다.' where item_id in ('gwiheo_charm', 'seal_inkline') and position('쓰이지 않는다' in description) = 0;

update public.world_patch_notes set body = body || E'\n- [우두머리] 깊은 판(깊은 귀허·깊은 명부·깊은 장부·깊은 흰 밤)에 입장 물품이 필요 없습니다. 지고 나서 30분 기다리지 않고 바로 다시 도전할 수 있습니다(장비 내구도·침식 벌칙은 그대로). 처치 인정·보상은 하루 한 번 그대로이고, 그 뒤에는 보상 없이 몇 번이든 다시 설 수 있습니다. 가지고 있던 귀허 부적·봉인 먹줄은 하나에 800전으로 돌려드렸습니다. 붉은 사당 옻·맹약 돌가루는 제작 재료로 그대로 쓰입니다.'
where note_id = '3.8.0' and position('[우두머리] 깊은 판(깊은 귀허' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127210000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
