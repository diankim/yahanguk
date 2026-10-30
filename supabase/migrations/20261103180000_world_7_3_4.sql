-- 7.3.4 묶음
-- ① 퀘스트 「○○ 만들기」(craft, 물품 지정)를 만든 횟수가 아니라 만든 개수로 센다(제보 35).
--    노정 건량은 한 번에 3개(고품질이면 더) 나오는데 「3개 만들기」가 제작 3번으로 세어져 9개 넘게 만들어야 했다.
--    물품을 정한 채집(6.1.1)과 같은 방식. 물품을 정하지 않은 제작(분야만)은 지금처럼 횟수.

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

select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  '    when p_task ->> ''t'' = ''win'' then (select count(*)::int from public.world_events e',
  '    -- 제작(물품 지정): 만든 개수(7.3.4, 제보 35)
    when p_task ->> ''t'' = ''craft'' and p_task ? ''items'' then (
    select coalesce(sum(greatest(1, coalesce((e.payload ->> ''qty'')::int, 1))), 0)::int from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = ''craft''
       and e.payload ->> ''output'' in (select jsonb_array_elements_text(p_task -> ''items''))
       and (not p_task ? ''field'' or exists (select 1 from public.world_crafting_recipes cr where cr.recipe_id = e.payload ->> ''recipe'' and cr.craft_field = p_task ->> ''field'')))
    when p_task ->> ''t'' = ''win'' then (select count(*)::int from public.world_events e');

-- ② 개인 창고에서 바로 버리기(별채 곳간처럼 어디서나). 꺼내서 버리던 수고를 던다.
--    잠근 물품·귀속 소모품(환골탈태 서첩·세심단)은 버리지 않는다. 창고처럼 행동 기록을 남기지 않는다.
set role fn_owner_field;
create or replace function public.world_storage_discard(p_item text, p_qty integer default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); s public.world_storage%rowtype; have int; n int; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if exists (select 1 from public.world_characters where owner_id = uid and coalesce(is_dead, false)) then raise exception '현재 상태에서는 버릴 수 없습니다.'; end if;
  if p_qty is not null and p_qty < 0 then raise exception '수량이 올바르지 않습니다.'; end if;
  select * into s from public.world_storage where owner_id = uid for update;
  have := coalesce((s.items ->> p_item)::int, 0);
  if have <= 0 then raise exception '창고에 그 물품이 없습니다.'; end if;
  nm := coalesce((select item_name from public.world_item_catalog where item_id = p_item), '물품');
  if p_item in ('reset_identity', 'reset_stats') then raise exception '귀속 물품입니다: %. 버릴 수 없습니다.', nm; end if;
  if exists (select 1 from public.world_item_locks where owner_id = uid and item_id = p_item) then
    raise exception '잠근 물품입니다: %. 가방에서 잠금을 풀어야 버릴 수 있습니다.', nm;
  end if;
  n := least(have, coalesce(nullif(p_qty, 0), have));
  update public.world_storage
     set items = case when have - n <= 0 then items - p_item else jsonb_set(items, array[p_item], to_jsonb(have - n)) end, updated_at = now()
   where owner_id = uid;
  return jsonb_build_object('ok', true, 'discarded', n, 'content', nm || ' ×' || n || '을(를) 창고에서 버렸습니다.');
end $function$;
revoke all on function public.world_storage_discard(text, integer) from public, anon;
grant execute on function public.world_storage_discard(text, integer) to authenticated;
reset role;

update public.world_patch_notes set body = body || $n$
## 7.3.4
- 퀘스트의 「○○ 만들기」가 만든 횟수로 세어지던 것을 만든 개수로 세게 고쳤습니다. 노정 건량처럼 한 번에 여러 개 나오는 물품은 이제 필요한 개수만큼만 만들면 됩니다. (제보 고맙습니다)
- 설정 › 소리 맨 위에 「전체 음량」을 더했습니다. 배경음악·환경음·효과음(컷씬 음악 포함)을 한꺼번에 올리고 내립니다.
- 개인 창고의 꺼내기 칸에 「버리기」를 더했습니다. 꺼내지 않고 창고에서 바로 버리며, 별채 곳간처럼 안전지대 밖에서도 됩니다(잠근 물품은 버리지 않습니다). (제보 고맙습니다)
- 휴대폰에서 채팅의 #패치노트 링크나 조사원 카드의 「별채 구경」처럼 다른 화면으로 가는 단추를 누르면 채팅 창이 저절로 닫힙니다. (제보 고맙습니다)
- 세계 지도에 물길을 그렸습니다. 천경호에서 시작한 큰 강이 설피골·백지교·구름나루·천엽 연화늪·용잠 수궁을 지나 만조의 갑문에서 바다로 나가고, 수경루 호수·구룡 폐수로(땅 밑은 점선)·침수된 구시가지 웅덩이·연화원 연못·흑조 균열·구중 봉연의 검은 못·해안의 얕은 물과 구등대 군도의 작은 섬이 보입니다. 가까이 확대하면 갈대·연꽃 같은 잔 물줄기까지 나옵니다.
$n$ where note_id = '7.2.0' and position('## 7.3.4' in body) = 0;
update public.world_app_meta set value = '20261103180000' where key = 'db_version';
