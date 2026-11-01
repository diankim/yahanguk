-- 7.7.1 (2026-11-01, 사용자 요청)
-- ① 한 번에 여러 개 만들기: world_craft_batch(제작법, 횟수 1~50)가 한 요청 안에서 world_craft_item을 차례로 부른다.
--    한 번 한 번은 지금과 똑같이 검사·기록(world_events craft 한 줄씩)하고, 재료·가방 자리가 모자라 실패하면 그 한 번만 되돌리고 거기서 멈춘다.
--    한 번도 못 만들면 그 까닭을 그대로 오류로 낸다. 화면 bag.js 제작 카드의 [초기화] − n + [전부].
-- ② 귀허의 주인 싸움 화면에 우수 회복품이 보이지 않던 것: world_gw_snapshot.items가 보통 물품 수만 내주었다(world_gw_act·resolve는 우수품을 받는다).
lock table public.world_characters in access exclusive mode;

create or replace function public.world_craft_batch(p_recipe_id text, p_times integer)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); n int; i int; r jsonb; last jsonb; done int := 0; hq int := 0; qsum int := 0;
  outs jsonb := '{}'::jsonb; why text; nm text; parts text[] := '{}'; k text; v text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  n := coalesce(p_times, 1);
  if n < 1 then raise exception '한 번 이상 만들어야 합니다.'; end if;
  n := least(n, 50);
  for i in 1 .. n loop
    begin
      r := public.world_craft_item(p_recipe_id);
    exception when others then
      -- 그 한 번만 되돌리고(재료·완성품 모두 그대로) 멈춘 까닭을 남긴다. 한 번도 못 만들었으면 아래에서 그대로 낸다.
      why := sqlerrm; exit;
    end;
    done := done + 1; last := r;
    qsum := qsum + coalesce((r ->> 'qty')::int, 0);
    if coalesce((r ->> 'hq')::boolean, false) then hq := hq + 1; end if;
    outs := outs || jsonb_build_object(r ->> 'output', coalesce((outs ->> (r ->> 'output'))::int, 0) + coalesce((r ->> 'qty')::int, 0));
  end loop;
  if done = 0 then raise exception '%', coalesce(why, '제작하지 못했습니다.'); end if;
  for k, v in select key, value::text from jsonb_each(outs) loop
    select item_name into nm from public.world_item_catalog where item_id = k;
    parts := parts || (coalesce(nm, k) || ' ×' || v);
  end loop;
  return (last - 'content') || jsonb_build_object(
    'content', '제작 ' || done || '번: ' || array_to_string(parts, ' · ')
      || case when hq > 0 then ' · 우수품 ' || hq || '번' else '' end
      || case when done < n then ' · ' || n || '번 가운데 ' || done || '번에서 멈춤(' || coalesce(why, '') || ')' else '' end,
    'done', done, 'asked', n, 'hq_count', hq, 'outputs', outs, 'total_qty', qsum, 'stopped', why);
end $f$;
revoke all on function public.world_craft_batch(text, integer) from public, anon, authenticated;
grant execute on function public.world_craft_batch(text, integer) to authenticated;

do $p$
declare d text; a text; b text; n int; own text; inh boolean;
begin
  d := replace(pg_get_functiondef('public.world_gw_snapshot(uuid)'::regprocedure), E'\r\n', E'\n');
  if position('''banyo_salve_hq''' in d) > 0 then return; end if;
  a := $a$unnest(array['tonic', 'herbal_extract', 'rejuv_pill', 'grand_pill', 'banyo_salve', 'ward_talisman']) i$a$;
  b := $b$unnest(array['tonic', 'herbal_extract', 'rejuv_pill', 'grand_pill', 'banyo_salve', 'ward_talisman', 'tonic_hq', 'herbal_extract_hq', 'rejuv_pill_hq', 'grand_pill_hq', 'banyo_salve_hq']) i$b$;
  n := (length(d) - length(replace(d, a, ''))) / length(a);
  if n <> 1 then raise exception '7.7.1 gw anchor (% of 1)', n; end if;
  select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_gw_snapshot(uuid)'::regprocedure;
  select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
  if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
  execute replace(d, a, b);
  if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
end $p$;

update public.world_patch_notes set body = rtrim(body, E'\n') || $N$

## 7.7.1
- 가방 › 제작에서 한 번에 여러 개를 만들 수 있습니다. 제작법 카드의 [초기화] − 횟수 + [전부]로 정한 뒤 오른쪽 아래 「제작 ×n」을 누르면 차례로 만듭니다(한 번에 50번까지, 「전부」는 가진 재료로 만들 수 있는 만큼). 품질·우수품·덤은 한 번마다 따로 굴리고, 중간에 재료나 가방 자리가 모자라면 거기서 멈추고 만든 만큼만 알려 드립니다.
- 우수품만 가지고 있을 때 현장 토벌·파티 토벌·귀허의 주인 싸움의 물품 칸에 단추가 뜨지 않던 것을 고쳤습니다. 우수품은 「· 우수품 +15%」로 따로 보입니다.
- 가방 목록에서 꼬마 동무 바구니·알에도 「열기」 단추가 바로 보입니다(전에는 물품 정보 창을 열어야 했습니다).
- 세계 지도에서 바다낚시를 할 수 있는 지역의 해안을 밝은 물빛으로 따로 표시합니다(범례 「바다낚시」).
- 휴대폰 채팅·귓속말의 보내기 단추가 아래로 치우쳐 보이던 것을 입력칸 한 줄의 가운데에 맞췄습니다.
$N$
 where note_id = '7.7.0' and position('## 7.7.1' in body) = 0;

update public.world_app_meta set value = '20261104200500' where key = 'db_version';
