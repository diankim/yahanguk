-- 저녁 묶음 패치(2026-10-29): 한 번에 실행하는 파일이다.
--   ① 가방 가득 참 메시지를 화면과 같은 기준으로(장착 장비 제외) · 제작은 완성품 넣을 자리를 먼저 확인
--   ② 숫자 붙은 장소 이름 정리
--   ③ 창고: 어디서나 보기(넣고 꺼내기는 안전지대만) · 안전지대에서 제작하면 창고 재료도 쓴다
--   ④ 쓰러지면 전체 채팅에 구조 알림 · ⑤ 패치노트 표 · ⑥ 다시 시작하는 귀속 물품 2종(모두에게 하나씩) · ⑦ 물품 얻는 곳
--   ⑩ 조사 바로잡기(원정 일지 시간대·구조용 물품) · 부적 정화가 중독·심신 동요·사념 침식도 푼다
--   ⑪ 대세력 떠나기·옮기기(12시간) · 회복 완화(야영 ⅔·안전지대 자연 회복·구조대 비용)
--   ⑫ 상위 도구로 하위 도구 제작법 · 원정 전투 여러 합 묘사(막기·회피·치명타·직업 기술·요괴 기믹) · 파티 원정은 동료마다 요괴 하나 더
--   ⑬ 기술 단계 보상 개편(13·30 추가 · 24·43 택일 · 50 숙달 · 조합 7)
--   ⑧ 세력 판도(인원이 적은 세력 영향력 가산 포함)(지역 영향력·지배 변화·세력 관계·지배/분쟁/파티 효과, pg_cron yh-influence) · ⑨ 파티 칸·파티 원정 부르기·함께 다녀온 원정 보너스
grant fn_owner_social to postgres with inherit true, set true;
grant fn_owner_18666 to postgres with inherit true, set true;
grant fn_owner_18944 to postgres with inherit true, set true;
grant fn_owner_18989 to postgres with inherit true, set true;
grant fn_owner_field to postgres with inherit true, set true;
grant fn_owner_expedition to postgres with inherit true, set true;
grant fn_owner_18452 to postgres with inherit true, set true;
grant fn_owner_18987 to postgres with inherit true, set true;
grant fn_owner_18475 to postgres with inherit true, set true;

-- ① ─────────────────────────────────────────
-- 강산하 님 제보(제작 시 36/35): 화면은 장착 장비를 뺀 29/29칸인데, 메시지는 장착 장비를 더한 숫자였다.
do $$
declare d text := pg_get_functiondef('public.world_enforce_bag_capacity()'::regprocedure);
  a text := 'RAISE EXCEPTION ''가방이 가득 찼습니다 (%/%칸). 물품을 정리한 뒤 다시 시도하세요.'', new_total, cap USING errcode = ''P0001'';';
  b text := 'RAISE EXCEPTION ''가방이 가득 찼습니다 (%/%칸). 물품을 정리한 뒤 다시 시도하세요.'', new_total - cap + new.bag_capacity + CASE WHEN new.major_faction_id = ''river_alliance'' THEN 6 ELSE 0 END, new.bag_capacity + CASE WHEN new.major_faction_id = ''river_alliance'' THEN 6 ELSE 0 END USING errcode = ''P0001'';';
begin
  if position(b in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '가방 메시지 고칠 자리가 하나가 아닙니다'; end if;
  execute replace(d, a, b);
end $$;

-- ② ─────────────────────────────────────────
update public.world_region_sites s set site_name = v.n from (values
  ('field_herb_patch', '잿빛 들녘 · 들쑥 비탈'), ('field_outskirts_clinic', '잿빛 들녘 · 버려진 구호 천막'),
  ('field_outskirts_relic', '잿빛 들녘 · 이끼 낀 봉인비'), ('field_outskirts_storehouse', '잿빛 들녘 · 허물어진 곳간'),
  ('field_patrol_post', '잿빛 들녘 · 옛 순찰 초소'), ('hq_yard_clinic', '야행국 본부 정청 · 뒤뜰 약방'),
  ('lotus_marsh_clinic', '천엽 연화늪 · 물가 침술막'), ('old_canal_storehouse', '구룡 폐수로 · 수문 밑 창고'),
  ('shrine_ruins_clinic', '폐쇄 사당 · 무녀의 약방'), ('shrine_ruins_relic', '폐쇄 사당 · 금줄 두른 비석'),
  ('shrine_ruins_storehouse', '폐쇄 사당 · 공양미 곳간'), ('shrine_seal_chamber', '폐쇄 사당 · 봉인 석실')
) as v(id, n) where s.site_id = v.id;
update public.world_faction_missions set title = '잿빛 들녘 표본 확보' where mission_id = 'field_survey' and title = '제4구역 표본 확보';

-- ③ ─────────────────────────────────────────
-- 창고 보기는 어디서나(넣고 꺼내기·넓히기만 안전지대). can_move = 지금 넣고 꺼낼 수 있는지, reason = 못 하는 까닭.
create or replace function public.world_storage_snapshot()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; s public.world_storage%rowtype; cap int; sc jsonb; can boolean := true; why text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  begin perform public.world_seal_guard(); perform public.world_storage_check(uid, false);
  exception when others then can := false; why := sqlerrm; end;
  insert into public.world_storage(owner_id) values (uid) on conflict (owner_id) do nothing;
  select * into s from public.world_storage where owner_id = uid;
  cap := public.world_bag_limit(uid);
  sc := public.world_storage_capacity(uid);
  return jsonb_build_object('available', true, 'can_move', can, 'reason', why, 'in_safe', exists (select 1 from public.world_current_shop(uid)),
    'items', coalesce((select jsonb_agg(jsonb_build_object('item_id', x.key, 'name', coalesce(i.item_name, x.key), 'qty', x.value::int,
        'rarity', i.rarity, 'category', i.category, 'tier', i.tier, 'stack', public.world_item_stack(x.key),
        'room', public.world_bag_room(c.inventory, x.key, cap)) order by i.category, i.tier, i.item_name)
      from jsonb_each_text(s.items) x left join public.world_item_catalog i on i.item_id = x.key
      where x.value ~ '^[0-9]+$' and x.value::int > 0), '[]'::jsonb),
    'used', public.world_bag_count(s.items), 'capacity', (sc ->> 'total')::int, 'sources', sc, 'gil', c.gil,
    'bag', jsonb_build_object('used', public.world_bag_count(c.inventory), 'limit', cap));
end $$;
alter function public.world_storage_snapshot() owner to fn_owner_field;
revoke all on function public.world_storage_snapshot() from public, anon, authenticated;
grant execute on function public.world_storage_snapshot() to authenticated;

-- 제작: 안전지대에서는 가방에 모자란 재료를 창고에서 채운다(가방 먼저). 완성품이 가방에 들어가는지 먼저 확인하고,
-- 고품질 추가분은 들어가는 만큼만 받는다(창고 재료만 쓰면 가방이 줄지 않아 넘친 완성품이 버려지던 것을 막는다).
grant select, update on public.world_storage to fn_owner_18452;
grant execute on function public.world_current_shop(uuid) to fn_owner_18452;
grant execute on function public.world_bag_room(jsonb, text, integer) to fn_owner_18452;
grant execute on function public.world_bag_limit(uuid) to fn_owner_18452;
do $$
declare pat record; d text;
begin
  for pat in select * from (values
    ('loc_bonus int:=0;', 'loc_bonus int:=0; st jsonb; take int; from_st jsonb := ''{}''::jsonb; room int;'),
    (' inv:=coalesce(c.inventory,''{}''::jsonb);
', ' inv:=coalesce(c.inventory,''{}''::jsonb);
 if exists (select 1 from public.world_current_shop(uid)) then select items into st from public.world_storage where owner_id=uid for update; end if;
 st:=coalesce(st,''{}''::jsonb);
'),
    ('  have:=coalesce((inv->>k)::int,0); if have<need', '  have:=coalesce((inv->>k)::int,0)+coalesce((st->>k)::int,0); if have<need'),
    (' for k,need in select key,value::text::int from jsonb_each(r.ingredients) loop inv:=jsonb_set(inv,array[k],to_jsonb(coalesce((inv->>k)::int,0)-need),true); end loop;',
     ' for k,need in select key,value::text::int from jsonb_each(r.ingredients) loop
  take:=least(need,greatest(0,coalesce((inv->>k)::int,0)));
  inv:=jsonb_set(inv,array[k],to_jsonb(coalesce((inv->>k)::int,0)-take),true);
  if need-take>0 then st:=jsonb_set(st,array[k],to_jsonb(coalesce((st->>k)::int,0)-(need-take))); from_st:=from_st||jsonb_build_object(k,need-take); end if;
 end loop;
 if from_st<>''{}''::jsonb then
  update public.world_storage set items=(select coalesce(jsonb_object_agg(key,value),''{}''::jsonb) from jsonb_each(st) where jsonb_typeof(value)=''number'' and value::text::int>0),updated_at=now() where owner_id=uid;
 end if;
 room:=public.world_bag_room(inv,r.output_item,public.world_bag_limit(uid));
 if room<r.output_qty then raise exception ''가방에 완성품을 넣을 자리가 없습니다. 가방을 한 칸 비운 뒤 다시 제작하세요.''; end if;'),
    (' out_qty:=r.output_qty;
 if quality>=85 then out_qty:=out_qty+greatest(1,ceil(r.output_qty*0.5)::int); end if;',
     ' out_qty:=r.output_qty;
 if quality>=85 then out_qty:=least(room,out_qty+greatest(1,ceil(r.output_qty*0.5)::int)); end if;'),
    ('||case when quality>=85 then '' · 고품질 추가 생산!'' else '''' end;',
     '||case when quality>=85 and out_qty>r.output_qty then '' · 고품질 추가 생산!'' else '''' end||case when from_st<>''{}''::jsonb then '' · 창고 재료 사용'' else '''' end;'),
    ('''quality'',quality,''location_bonus'',loc_bonus);', '''quality'',quality,''location_bonus'',loc_bonus,''from_storage'',from_st);')
  ) as t(a, b) loop
    d := pg_get_functiondef('public.world_craft_item(text)'::regprocedure);
    if position(pat.b in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, pat.a, ''))) / length(pat.a) <> 1 then raise exception '제작 함수 고칠 자리가 하나가 아닙니다: %', left(pat.a, 60); end if;
    execute replace(d, pat.a, pat.b);
  end loop;
end $$;

-- ④ ─────────────────────────────────────────
-- 쓰러지면 전체 채팅에 상태 줄을 남긴다(보낸 이 = 쓰러진 사람, 이름 칸 「구조 알림」 → 화면이 시스템 줄로 그린다). 같은 곳 조사원에게 가는 구조 요청 알림은 그대로.
grant insert on public.world_chat_messages to fn_owner_18987;
grant usage, select on sequence public.world_chat_messages_id_seq to fn_owner_18987;
do $$
declare d text := pg_get_functiondef('public.world_notify_downed()'::regprocedure);
  a text := '  insert into public.world_events(actor_id,actor_name,event_type,content,payload) values(new.owner_id,new.character_name,''downed''';
  b text := '  insert into public.world_chat_messages(channel_type,sender_id,sender_name,content) values(''global'',new.owner_id,''구조 알림'',
    new.character_name||'' 조사원이 ''||coalesce(new.location,''어딘가'')||''에서 쓰러졌습니다. 근처에 있다면 구조를 도와주세요.'');
  insert into public.world_events(actor_id,actor_name,event_type,content,payload) values(new.owner_id,new.character_name,''downed''';
begin
  if position('구조 알림' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '쓰러짐 알림 고칠 자리가 하나가 아닙니다'; end if;
  execute replace(d, a, b);
end $$;

-- ⑤ ─────────────────────────────────────────
-- 패치노트: 채팅은 3일 뒤 지워지므로 따로 보관한다. 누구나 읽기만(화면 #/patch), 쓰기는 운영(SQL)만.
create table if not exists public.world_patch_notes (
  note_id text primary key check (note_id ~ '^[0-9][0-9.-]{2,11}$'),
  title text not null,
  body text not null,
  created_at timestamptz not null default now()
);
alter table public.world_patch_notes enable row level security;
revoke all on public.world_patch_notes from public, anon, authenticated;
grant select on public.world_patch_notes to authenticated;
drop policy if exists world_patch_notes_read on public.world_patch_notes;
create policy world_patch_notes_read on public.world_patch_notes for select to authenticated using (true);
-- 지금까지 채팅에 올린 공지를 옮겨 둔다(「[패치 n/m] 제목」 → 「## 제목」)
insert into public.world_patch_notes(note_id, title, body, created_at)
select v.id, v.title, string_agg(regexp_replace(m.content, '^\[패치[^\]]*\]\s*', '## '), E'\n\n' order by m.id), min(m.created_at)
  from (values ('2026-10-28-1', '원정 개편 · 화면 꾸미기', array[71, 73, 74, 75, 76]),
               ('2026-10-28-2', '숙련·기술 통합 · 요화 · 비무', array[90, 91, 92, 93, 94, 95, 96]),
               ('2026-10-28-3', '개인 창고 · 새 배경음악', array[97, 98, 99, 136])) v(id, title, ids)
  join public.world_chat_messages m on m.id = any (v.ids) and m.sender_name = 'GM'
 group by v.id, v.title
on conflict (note_id) do nothing;

-- ⑥ ─────────────────────────────────────────
-- 시험 운영 동안 캐릭터를 다시 키우고 싶은 조사원을 위한 귀속 소모품 2종(거래·판매 불가, 창고에는 넣을 수 있음).
--   환골탈태 서첩(reset_identity): 직업·소속을 다시 고르고 대세력에서 나오며 능력치 포인트를 모두 돌려받는다.
--   세심단(reset_stats): 능력치를 처음(각 5)으로 되돌리고 쓴 포인트를 모두 돌려받는다.
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, rarity, tradeable, reference_price, stack_size)
values ('reset_identity', '환골탈태 서첩', 'consumable', 4, '직업과 소속을 한 번 다시 고릅니다. 대세력에서 나오고(평판 0), 능력치는 처음으로 돌아가 쓴 포인트를 모두 돌려받습니다. 레벨·물품·전·칭호는 그대로입니다. 귀속 물품이라 거래·판매할 수 없습니다.', true, 'epic', false, 0, 3),
       ('reset_stats', '세심단', 'consumable', 3, '능력치를 처음(각 5)으로 되돌리고 쓴 포인트를 모두 돌려받습니다. 귀속 물품이라 거래·판매할 수 없습니다.', true, 'rare', false, 0, 3)
on conflict (item_id) do update set item_name = excluded.item_name, description = excluded.description, tradeable = false, reference_price = 0, stack_size = excluded.stack_size;

-- 귀속 물품은 상점에 팔거나 남에게 넘길 수 없다(판매·거래·직접 거래·선물이 모두 이 검사를 거친다)
do $$
declare d text := pg_get_functiondef('public.world_item_give_guard(uuid,text,integer,integer)'::regprocedure);
  a text := '  select item_name into nm from public.world_item_catalog where item_id = p_item_id;';
  b text := '  select item_name into nm from public.world_item_catalog where item_id = p_item_id;
  if p_item_id in (''reset_identity'', ''reset_stats'') then raise exception ''귀속 물품입니다: %. 팔거나 넘길 수 없습니다.'', coalesce(nm, ''물품''); end if;';
begin
  if position('reset_identity' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '내주기 검사 고칠 자리가 하나가 아닙니다'; end if;
  execute replace(d, a, b);
end $$;

create or replace function public.world_reset_points(p_uid uuid)
returns integer language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select greatest(0, strength - 5) + greatest(0, agility - 5) + greatest(0, vitality - 5) + greatest(0, perception - 5) + greatest(0, willpower - 5) + greatest(0, spirit_affinity - 5)
    from public.world_characters where owner_id = p_uid
$$;

create or replace function public.world_reset_stats()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; back int;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce((c.inventory ->> 'reset_stats')::int, 0) < 1 then raise exception '세심단이 없습니다.'; end if;
  back := public.world_reset_points(uid);
  update public.world_characters
     set strength = least(strength, 5), agility = least(agility, 5), vitality = least(vitality, 5), perception = least(perception, 5),
         willpower = least(willpower, 5), spirit_affinity = least(spirit_affinity, 5), stat_points = stat_points + back,
         inventory = case when (inventory ->> 'reset_stats')::int <= 1 then inventory - 'reset_stats' else jsonb_set(inventory, '{reset_stats}', to_jsonb((inventory ->> 'reset_stats')::int - 1)) end,
         updated_at = now()
   where owner_id = uid;
  return jsonb_build_object('ok', true, 'refunded', back, 'content', format('능력치를 처음으로 되돌렸습니다. 포인트 %s점을 돌려받았습니다(지금 %s점).', back, c.stat_points + back));
end $$;

create or replace function public.world_reset_identity(p_job text, p_faction text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; back int; job_label text; off_items text[];
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce((c.inventory ->> 'reset_identity')::int, 0) < 1 then raise exception '환골탈태 서첩이 없습니다.'; end if;
  if c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 쓸 수 없습니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = uid and e.status = 'active') then raise exception '원정 중에는 쓸 수 없습니다.'; end if;
  job_label := case p_job when 'exorcist' then '퇴마관' when 'scout' then '현장 조사원' when 'medic' then '의무관'
                 when 'sealmaster' then '봉인술사' when 'analyst' then '기록 분석관' when 'artificer' then '법구 제작사' end;
  if job_label is null then raise exception '직업을 고르세요.'; end if;
  if p_faction is null or p_faction not in ('headquarters', 'fieldbureau', 'archivebureau', 'sealbureau', 'medicalbureau', 'independent') then raise exception '소속을 고르세요.'; end if;
  back := public.world_reset_points(uid);
  -- 새 직업·소속으로 찰 수 없는 장비는 벗긴다(가방에 남는다)
  select array_agg(e.item_id) into off_items from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id
   where e.owner_id = uid and ((i.required_job is not null and i.required_job <> p_job) or (i.required_faction is not null and i.required_faction <> p_faction));
  delete from public.world_character_equipment e using public.world_item_catalog i
   where e.owner_id = uid and i.item_id = e.item_id and ((i.required_job is not null and i.required_job <> p_job) or (i.required_faction is not null and i.required_faction <> p_faction));
  update public.world_characters
     set job_key = p_job, occupation = job_label, faction_key = p_faction, major_faction_id = null, faction_reputation = 0,
         strength = least(strength, 5), agility = least(agility, 5), vitality = least(vitality, 5), perception = least(perception, 5),
         willpower = least(willpower, 5), spirit_affinity = least(spirit_affinity, 5), stat_points = stat_points + back,
         inventory = case when (inventory ->> 'reset_identity')::int <= 1 then inventory - 'reset_identity' else jsonb_set(inventory, '{reset_identity}', to_jsonb((inventory ->> 'reset_identity')::int - 1)) end,
         updated_at = now()
   where owner_id = uid;
  return jsonb_build_object('ok', true, 'refunded', back, 'unequipped', coalesce(to_jsonb(off_items), '[]'::jsonb),
    'content', format('%s(으)로 새 길을 걷습니다. 능력치 포인트 %s점을 돌려받았습니다.%s', job_label, back,
      case when off_items is not null then ' 새 직업·소속으로 찰 수 없는 장비는 벗었습니다.' else '' end));
end $$;

grant select, delete on public.world_character_equipment to fn_owner_18475;
grant select on public.world_item_catalog, public.world_expeditions to fn_owner_18475;
grant execute on function public.world_seal_guard() to fn_owner_18475;
-- 주인을 바꾸려면 새 주인이 스키마에 만들기 권한이 있어야 한다: 잠깐 주고 바로 거둔다
grant create on schema public to fn_owner_18475;
alter function public.world_reset_points(uuid) owner to fn_owner_18475;
alter function public.world_reset_stats() owner to fn_owner_18475;
alter function public.world_reset_identity(text, text) owner to fn_owner_18475;
revoke create on schema public from fn_owner_18475;
revoke all on function public.world_reset_points(uuid) from public, anon, authenticated;
revoke all on function public.world_reset_stats() from public, anon, authenticated;
revoke all on function public.world_reset_identity(text, text) from public, anon, authenticated;
grant execute on function public.world_reset_stats() to authenticated;
grant execute on function public.world_reset_identity(text, text) to authenticated;

-- 모든 캐릭터에게 하나씩: 가방에 자리가 있으면 가방, 없으면 창고(창고도 넘치면 그래도 창고에 둔다 — 꺼내기만 막힘)
do $$
declare r record; k text;
begin
  for r in select owner_id, inventory from public.world_characters where not coalesce(is_dead, false) loop
    foreach k in array array['reset_identity', 'reset_stats'] loop
      if coalesce((r.inventory ->> k)::int, 0) > 0 or exists (select 1 from public.world_storage s where s.owner_id = r.owner_id and s.items ? k) then continue; end if;
      if public.world_bag_room(r.inventory, k, public.world_bag_limit(r.owner_id)) >= 1 then
        update public.world_characters set inventory = public.world_inv_add(inventory, k, 1) where owner_id = r.owner_id returning inventory into r.inventory;
      else
        insert into public.world_storage(owner_id, items) values (r.owner_id, jsonb_build_object(k, 1))
        on conflict (owner_id) do update set items = public.world_inv_add(public.world_storage.items, k, 1), updated_at = now();
      end if;
    end loop;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (r.owner_id, 'reward', '다시 시작할 수 있는 물품', '시험 운영 기념으로 「환골탈태 서첩」(직업·소속 다시 고르기)과 「세심단」(능력치 다시 나누기)을 하나씩 드렸습니다. 가방에 자리가 없으면 창고에 넣어 두었습니다. 둘 다 귀속 물품입니다.', '{}'::jsonb);
  end loop;
end $$;

-- ⑦ ─────────────────────────────────────────
-- 물품 얻는 곳(물품 정보 창): 채집터·조사 지점·요괴·낚시터가 있는 지역 이름(낮은 레벨 지역부터, 갈래마다 6곳까지)
create or replace function public.world_item_sources(p_item text)
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  with g as (select distinct r.region_name, r.min_level from public.world_gathering_spots s join public.world_exploration_nodes n on n.node_id = s.node_id
               join public.world_map_regions r on r.region_id = n.region_id where s.active and p_item = any (s.loot_items)),
       t as (select distinct r.region_name, r.min_level from public.world_region_sites s join public.world_map_regions r using (region_id)
               where s.active and (s.loot_table ? p_item or s.bonus_item = p_item)),
       m as (select distinct r.region_name, r.min_level from public.world_region_monsters x join public.world_map_regions r using (region_id) where x.drops ? p_item),
       f as (select distinct r.region_name, r.min_level from public.world_fish_species sp join public.world_fish_grounds fg on fg.habitat = sp.habitat
               join public.world_map_regions r on r.region_id = fg.region_id where sp.fish_id = p_item and sp.active)
  select jsonb_build_object(
    'gather', (select coalesce(jsonb_agg(region_name order by min_level, region_name), '[]') from (select * from g order by min_level, region_name limit 6) x), 'gather_n', (select count(*) from g),
    'sites', (select coalesce(jsonb_agg(region_name order by min_level, region_name), '[]') from (select * from t order by min_level, region_name limit 6) x), 'sites_n', (select count(*) from t),
    'monsters', (select coalesce(jsonb_agg(region_name order by min_level, region_name), '[]') from (select * from m order by min_level, region_name limit 6) x), 'monsters_n', (select count(*) from m),
    'fish', (select coalesce(jsonb_agg(region_name order by min_level, region_name), '[]') from (select * from f order by min_level, region_name limit 6) x), 'fish_n', (select count(*) from f),
    'craft', exists (select 1 from public.world_crafting_recipes where output_item = p_item),
    'shop', exists (select 1 from public.world_shop_catalog where item_id = p_item))
$$;
grant select on public.world_gathering_spots, public.world_exploration_nodes, public.world_map_regions, public.world_region_sites,
  public.world_region_monsters, public.world_fish_species, public.world_fish_grounds, public.world_crafting_recipes, public.world_shop_catalog to fn_owner_field;
alter function public.world_item_sources(text) owner to fn_owner_field;
revoke all on function public.world_item_sources(text) from public, anon, authenticated;
grant execute on function public.world_item_sources(text) to authenticated;

-- ⑧ ─────────────────────────────────────────
-- 세력 판도: 대세력 조사원의 활동(토벌·탐색·채집·원정)이 그 지역에 세력 영향력을 쌓고, 한 시간마다 정산해
-- 안전지대가 아닌 지역의 지배 세력이 바뀐다. 세력 사이 관계(동맹~적대)는 함께 파티를 하면 오르고 같은 지역을 다투면 내려간다.
alter table public.world_map_regions add column if not exists home_faction_id text;
alter table public.world_map_regions add column if not exists contested boolean not null default false;
alter table public.world_map_regions add column if not exists control_changed_at timestamptz;
update public.world_map_regions set home_faction_id = control_faction_id where home_faction_id is null and control_faction_id is not null;

create table if not exists public.world_region_influence (
  region_id text not null references public.world_map_regions(region_id),
  faction_id text not null references public.world_major_factions(faction_id),
  points numeric not null default 0,
  last_actor uuid,
  updated_at timestamptz not null default now(),
  primary key (region_id, faction_id));
create table if not exists public.world_faction_relations (
  faction_a text not null references public.world_major_factions(faction_id),
  faction_b text not null references public.world_major_factions(faction_id),
  score numeric not null default 0 check (score between -100 and 100),
  base numeric not null default 0,
  updated_at timestamptz not null default now(),
  primary key (faction_a, faction_b), check (faction_a < faction_b));
create table if not exists public.world_faction_log (
  id bigserial primary key, kind text not null, region_id text, faction_id text, other_id text,
  content text not null, created_at timestamptz not null default now());
alter table public.world_region_influence enable row level security;
alter table public.world_faction_relations enable row level security;
alter table public.world_faction_log enable row level security;
revoke all on public.world_region_influence, public.world_faction_relations, public.world_faction_log from public, anon, authenticated;
revoke all on sequence public.world_faction_log_id_seq from public, anon, authenticated;

-- 처음 관계: 원래 적대 관계는 -60, 그 밖은 세계관에 맞춰 조금씩
insert into public.world_faction_relations(faction_a, faction_b, score, base)
select a.faction_id, b.faction_id, v, v from public.world_major_factions a join public.world_major_factions b on a.faction_id < b.faction_id,
lateral (select case
  when b.faction_id = any (coalesce(a.hostile_to, '{}')) or a.faction_id = any (coalesce(b.hostile_to, '{}')) then -60
  when (a.faction_id, b.faction_id) in (('night_office', 'north_league')) then 40
  when (a.faction_id, b.faction_id) in (('mandate_court', 'night_office')) then 25
  when (a.faction_id, b.faction_id) in (('mandate_court', 'north_league'), ('black_lotus', 'southern_remnant')) then 10
  when (a.faction_id, b.faction_id) in (('black_lotus', 'red_moon_cult')) then 15
  when 'river_alliance' in (a.faction_id, b.faction_id) then 10
  else 0 end v) x
on conflict do nothing;

create or replace function public.world_faction_rel(a text, b text)
returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case when a is null or b is null then 0 when a = b then 100
    else coalesce((select score from public.world_faction_relations where faction_a = least(a, b) and faction_b = greatest(a, b)), 0) end
$$;
-- 받침에 맞춘 조사: world_josa('적월교','이','가') → 적월교가
create or replace function public.world_josa(w text, a text, b text)
returns text language sql immutable set search_path to 'pg_catalog' as $$
  select w || case when w is not null and ascii(right(w, 1)) between 44032 and 55203
                     and ((ascii(right(w, 1)) - 44032) % 28 = 0 or (a = '으로' and (ascii(right(w, 1)) - 44032) % 28 = 8)) then b else a end
$$;
create or replace function public.world_mf_name(f text)
returns text language sql stable set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select faction_name from public.world_major_factions where faction_id = f), '무주 세력')
$$;
create or replace function public.world_faction_stance(s numeric)
returns text language sql immutable set search_path to 'pg_catalog' as $$
  select case when s >= 100 then '같은 세력' when s >= 40 then '동맹' when s >= 15 then '우호' when s > -15 then '중립' when s > -40 then '경계' else '적대' end
$$;

-- 지금 있는 곳의 지배 세력·분쟁, 같은 곳의 파티원이 주는 작은 효과(world_status_effect_total에 더함)
create or replace function public.world_social_effect(p_key text)
returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); me record; reg record; v numeric := 0; mates int := 0; ally boolean := false; foe boolean := false; rel numeric;
begin
  if p_key not in ('gather_qty_pct', 'rare_loot_pct', 'healing_pct', 'encounter_pct', 'mental_loss_pct', 'incoming_damage_pct', 'clue_bonus_pct') then return 0; end if;
  select c.location, c.major_faction_id into me from public.world_characters c where c.owner_id = uid;
  if not found then return 0; end if;
  select r.control_faction_id, r.contested, r.is_safe_zone into reg from public.world_map_regions r where r.region_id = (public.world_region_at(me.location)).region_id;
  if found then
    if reg.contested then v := v + case p_key when 'rare_loot_pct' then 3 when 'encounter_pct' then 5 else 0 end; end if;
    if me.major_faction_id is not null and reg.control_faction_id is not null then
      rel := public.world_faction_rel(me.major_faction_id, reg.control_faction_id);
      if rel >= 100 then v := v + case p_key when 'gather_qty_pct' then 8 when 'rare_loot_pct' then 3 when 'healing_pct' then 5 else 0 end;
      elsif rel >= 40 then v := v + case p_key when 'gather_qty_pct' then 4 when 'healing_pct' then 3 else 0 end;
      elsif rel <= -40 and not reg.is_safe_zone then v := v + case p_key when 'encounter_pct' then 8 when 'mental_loss_pct' then 5 else 0 end;
      end if;
    end if;
  end if;
  -- 같은 곳에 있는 파티원(전투불능 제외, 세 명까지)
  select count(*), bool_or(public.world_faction_rel(me.major_faction_id, o.major_faction_id) >= 40 and me.major_faction_id is not null and o.major_faction_id is not null),
         bool_or(public.world_faction_rel(me.major_faction_id, o.major_faction_id) <= -40)
    into mates, ally, foe
  from public.world_party_members pm join public.world_party_members om on om.party_id = pm.party_id and om.owner_id <> pm.owner_id
  join public.world_characters o on o.owner_id = om.owner_id
  where pm.owner_id = uid and o.location = me.location and o.downed_at is null and not coalesce(o.is_dead, false);
  mates := least(coalesce(mates, 0), 3);
  if mates > 0 then
    v := v + case p_key when 'incoming_damage_pct' then -3 * mates when 'healing_pct' then 4 else 0 end;
    if ally then v := v + case p_key when 'clue_bonus_pct' then 5 when 'rare_loot_pct' then 2 else 0 end; end if;
    if foe then v := v + case p_key when 'mental_loss_pct' then 5 else 0 end; end if;
  end if;
  return v;
end $$;
grant select on public.world_faction_relations, public.world_region_influence, public.world_faction_log, public.world_party_members, public.world_characters, public.world_map_regions, public.world_major_factions to fn_owner_field;
alter function public.world_faction_rel(text, text) owner to fn_owner_field;
alter function public.world_social_effect(text) owner to fn_owner_field;
revoke all on function public.world_faction_rel(text, text), public.world_social_effect(text) from public, anon, authenticated;
grant execute on function public.world_faction_rel(text, text), public.world_social_effect(text) to authenticated;
grant execute on function public.world_region_at(text) to fn_owner_field;
-- world_status_effect_total을 부르는 함수 주인 역할(fn_owner_*)들도 부를 수 있어야 한다(world_skill_effect와 같은 방식)
do $$ declare r text; begin
  for r in select rolname from pg_roles where rolname like 'fn\_owner\_%' loop
    execute format('grant execute on function public.world_social_effect(text) to %I', r);
  end loop;
end $$;

do $$ declare d text := pg_get_functiondef('public.world_status_effect_total(text)'::regprocedure);
  a text := '+ public.world_skill_effect(p_effect_key)';
begin
  if d like '%world_social_effect%' then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception 'status_effect_total anchor'; end if;
  execute replace(d, a, a || ' + public.world_social_effect(p_effect_key)');
end $$;

-- 인원이 적은 세력의 영향력 가산: √(가장 많은 세력 인원 ÷ 이 세력 인원), 1~2.5배. 가입 인원이 바뀌면 바로 달라진다.
create or replace function public.world_faction_boost(p text)
returns numeric language sql stable set search_path to 'pg_catalog', 'public' as $$
  with m as (select f.faction_id, (select count(*) from public.world_characters c where c.major_faction_id = f.faction_id and not coalesce(c.is_dead, false)) n
               from public.world_major_factions f where f.active)
  select coalesce((select case when m.n = 0 then 1 else least(2.5, greatest(1, sqrt((select max(n) from m)::numeric / m.n))) end from m where m.faction_id = p), 1)
$$;
revoke all on function public.world_faction_boost(text) from public, anon, authenticated;
grant execute on function public.world_faction_boost(text) to fn_owner_field;

-- 한 시간마다: 영향력 쇠퇴 → 지난 시간 활동을 더함 → 지배 세력·분쟁 판정 → 관계 변화
create or replace function public.world_influence_tick()
returns jsonb language plpgsql set search_path to 'pg_catalog', 'public' as $$
declare t0 timestamptz; t1 timestamptz := now(); r record; s record; flips int := 0; holder_score numeric; need numeric; old_stance text; new_stance text; who uuid;
begin
  select value::timestamptz into t0 from public.world_app_meta where key = 'influence_at';
  t0 := greatest(coalesce(t0, t1 - interval '1 hour'), t1 - interval '3 hours');
  update public.world_region_influence set points = round(points * 0.97, 2) where points > 0;

  -- 활동: 토벌 승리 1(정예 2·우두머리 4)·탐색 0.3·채집 0.3·원정 20분마다 1(최대 24). 한 사람·한 지역에 한 번 정산당 40까지
  with ev as (
    select e.actor_id, coalesce(e.payload ->> 'region_id', n.region_id) region_id,
      case e.event_type when 'combat' then case when (e.payload ->> 'defeated')::boolean then case e.payload ->> 'rank' when 'boss' then 4 when 'elite' then 2 else 1 end else 0 end
                        else 0.3 end pts
    from public.world_events e left join public.world_exploration_nodes n on e.event_type = 'gather' and n.node_id::text = e.payload ->> 'node_id'
    where e.created_at > t0 and e.created_at <= t1 and e.event_type in ('combat', 'explore', 'gather')
    union all
    select x.owner_id, x.region_id, least(24, least(x.minutes, extract(epoch from x.finished_at - x.started_at) / 60) / 20.0) from public.world_expeditions x
    where x.finished_at > t0 and x.finished_at <= t1 and x.status = 'done'),
  per as (select c.major_faction_id f, ev.region_id, ev.actor_id, least(40, sum(pts)) pts
          from ev join public.world_characters c on c.owner_id = ev.actor_id
          join public.world_map_regions mr on mr.region_id = ev.region_id
          where c.major_faction_id is not null and mr.active and not mr.is_safe_zone and mr.home_faction_id is not null
          group by 1, 2, 3 having sum(pts) > 0),
  agg as (select f, region_id, sum(pts) pts, (array_agg(actor_id order by pts desc))[1] top from per group by 1, 2)
  insert into public.world_region_influence(region_id, faction_id, points, last_actor, updated_at)
  select region_id, f, round(pts * public.world_faction_boost(f), 2), top, t1 from agg
  on conflict (region_id, faction_id) do update set points = public.world_region_influence.points + excluded.points, last_actor = excluded.last_actor, updated_at = t1;

  -- 지배 판정: 본거지 세력은 기본 150. 도전 세력이 max(150, 지배 세력 점수×1.25) 이상이면 넘어가고, 60% 이상이면 분쟁 중
  for r in select mr.region_id, mr.region_name, mr.home_faction_id, mr.control_faction_id from public.world_map_regions mr
           where mr.active and not mr.is_safe_zone and mr.home_faction_id is not null loop
    select coalesce((select points from public.world_region_influence where region_id = r.region_id and faction_id = r.control_faction_id), 0)
           + case when r.control_faction_id = r.home_faction_id then 150 else 0 end into holder_score;
    select f.faction_id, f.faction_name, coalesce(i.points, 0) + case when f.faction_id = r.home_faction_id then 150 else 0 end sc, i.last_actor into s
      from public.world_major_factions f left join public.world_region_influence i on i.region_id = r.region_id and i.faction_id = f.faction_id
      where f.active and f.faction_id is distinct from r.control_faction_id order by 3 desc limit 1;
    need := greatest(150, holder_score * 1.25);
    if s.faction_id is not null and s.sc >= need then
      update public.world_map_regions set control_faction_id = s.faction_id, faction_control = s.faction_name, control_changed_at = t1, contested = false where region_id = r.region_id;
      flips := flips + 1;
      insert into public.world_faction_log(kind, region_id, faction_id, other_id, content)
      values ('control', r.region_id, s.faction_id, r.control_faction_id, public.world_josa(s.faction_name, '이', '가') || ' ' || public.world_josa(r.region_name, '을', '를') || ' ' || public.world_mf_name(r.control_faction_id) || '에게서 차지했습니다.');
      insert into public.world_notifications(user_id, kind, title, content, payload)
      select c.owner_id, 'faction', '세력 판도 변화', public.world_josa(s.faction_name, '이', '가') || ' ' || public.world_josa(r.region_name, '을', '를') || ' 차지했습니다.', jsonb_build_object('region_id', r.region_id, 'faction_id', s.faction_id)
        from public.world_characters c where c.major_faction_id in (s.faction_id, r.control_faction_id) and not coalesce(c.is_dead, false);
      who := coalesce(s.last_actor, (select owner_id from public.world_characters where major_faction_id = s.faction_id limit 1));
      if who is not null then
        insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
        values ('global', who, '세력 소식', public.world_josa(s.faction_name, '이', '가') || ' ' || public.world_josa(r.region_name, '을', '를') || ' 차지했습니다. 지배 세력이 바뀐 지역은 채집·희귀품·위험이 달라집니다.');
      end if;
    else
      update public.world_map_regions set contested = (s.faction_id is not null and s.sc >= need * 0.6) where region_id = r.region_id and contested is distinct from (s.faction_id is not null and s.sc >= need * 0.6);
    end if;
  end loop;

  -- 관계: 두 세력 조사원이 한 파티에서 활동하면 +0.5(쌍마다 한 시간 +1까지), 같은 지역에서 둘 다 3 이상 쌓으면 −0.5(−1.5까지), 처음 값으로 1%씩 돌아감
  for r in select fr.faction_a, fr.faction_b, fr.score from public.world_faction_relations fr loop
    old_stance := public.world_faction_stance(r.score);
    update public.world_faction_relations fr set score = greatest(-100, least(100, round(fr.score + (fr.base - fr.score) * 0.01
      + least(1, 0.5 * (select count(distinct pm.party_id) from public.world_party_members pm
            join public.world_characters ca on ca.owner_id = pm.owner_id and ca.major_faction_id = r.faction_a
            join public.world_party_members pm2 on pm2.party_id = pm.party_id join public.world_characters cb on cb.owner_id = pm2.owner_id and cb.major_faction_id = r.faction_b
            where exists (select 1 from public.world_events e where e.actor_id = ca.owner_id and e.created_at > t0)
              and exists (select 1 from public.world_events e where e.actor_id = cb.owner_id and e.created_at > t0)))
      - least(1.5, 0.5 * (select count(*) from public.world_region_influence ia join public.world_region_influence ib on ib.region_id = ia.region_id and ib.faction_id = r.faction_b
            where ia.faction_id = r.faction_a and ia.updated_at = t1 and ib.updated_at = t1 and ia.points >= 3 and ib.points >= 3)), 2))), updated_at = t1
      where fr.faction_a = r.faction_a and fr.faction_b = r.faction_b returning score into holder_score;
    new_stance := public.world_faction_stance(holder_score);
    if new_stance <> old_stance then
      insert into public.world_faction_log(kind, faction_id, other_id, content)
      values ('relation', r.faction_a, r.faction_b, public.world_josa(public.world_mf_name(r.faction_a), '과', '와') || ' ' || public.world_mf_name(r.faction_b) || '의 관계가 ' || old_stance || '에서 ' || public.world_josa(new_stance, '으로', '로') || ' 바뀌었습니다.');
    end if;
  end loop;

  insert into public.world_app_meta(key, value, changed_at) values ('influence_at', t1::text, now())
  on conflict (key) do update set value = excluded.value, changed_at = now();
  return jsonb_build_object('from', t0, 'to', t1, 'flips', flips);
end $$;
revoke all on function public.world_influence_tick() from public, anon, authenticated;
do $$ begin
  if not exists (select 1 from cron.job where jobname = 'yh-influence') then
    perform cron.schedule('yh-influence', '7 * * * *', 'select public.world_influence_tick()');
  end if;
end $$;

-- 세력 판도 화면: 세력마다 조사원 수·지배 지역·영향력, 관계, 다투는 지역, 최근 소식
create or replace function public.world_faction_board()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); mine text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select major_faction_id into mine from public.world_characters where owner_id = uid;
  return jsonb_build_object('mine', mine,
    'factions', (select coalesce(jsonb_agg(jsonb_build_object('id', f.faction_id, 'name', f.faction_name,
        'members', (select count(*) from public.world_characters c where c.major_faction_id = f.faction_id and not coalesce(c.is_dead, false)),
        'regions', (select count(*) from public.world_map_regions r where r.active and r.control_faction_id = f.faction_id),
        'influence', (select coalesce(round(sum(points)), 0) from public.world_region_influence i where i.faction_id = f.faction_id),
        'boost', round(public.world_faction_boost(f.faction_id), 2)) order by f.faction_name), '[]') from public.world_major_factions f where f.active),
    'relations', (select coalesce(jsonb_agg(jsonb_build_object('a', faction_a, 'b', faction_b, 'score', round(score), 'stance', public.world_faction_stance(score))), '[]') from public.world_faction_relations),
    'regions', (select coalesce(jsonb_agg(jsonb_build_object('id', r.region_id, 'name', r.region_name, 'home', r.home_faction_id, 'control', r.control_faction_id, 'contested', r.contested,
        'top', (select coalesce(jsonb_agg(jsonb_build_object('f', i.faction_id, 'p', round(i.points))), '[]') from (select * from public.world_region_influence i where i.region_id = r.region_id and i.points >= 1 order by i.points desc limit 3) i))
        order by r.contested desc, r.min_level), '[]')
      from public.world_map_regions r where r.active and not r.is_safe_zone and r.home_faction_id is not null
        and (r.contested or r.control_faction_id is distinct from r.home_faction_id or exists (select 1 from public.world_region_influence i where i.region_id = r.region_id and i.points >= 1))),
    'log', (select coalesce(jsonb_agg(jsonb_build_object('at', created_at, 'text', content) order by created_at desc), '[]') from (select * from public.world_faction_log order by id desc limit 12) l));
end $$;
alter function public.world_faction_board() owner to fn_owner_field;
revoke all on function public.world_faction_board() from public, anon, authenticated;
grant execute on function public.world_faction_board() to authenticated;
grant execute on function public.world_faction_stance(numeric) to fn_owner_field;
revoke all on function public.world_josa(text, text, text), public.world_mf_name(text) from public, anon, authenticated;

-- ⑨ ─────────────────────────────────────────
-- 파티: 현장 화면의 파티 칸에 쓸 상태(정신·침식·세력·원정 중인 곳), 함께 원정 가자는 알림, 함께 다녀온 원정의 보너스
do $$ declare d text := pg_get_functiondef('public.world_party_overview()'::regprocedure);
  a text := '''level'', c.level, ''job_key'', c.job_key, ''location'', c.location, ''health'', c.health, ''profile'', c.profile,';
begin
  if d like '%''erosion'', c.erosion%' then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception 'party_overview anchor'; end if;
  execute replace(d, a, a || ' ''mental'', c.mental, ''erosion'', c.erosion, ''major_faction_id'', c.major_faction_id,
        ''expedition'', (SELECT jsonb_build_object(''region_id'', e.region_id, ''node_id'', e.node_id, ''ends_at'', e.ends_at, ''minutes'', e.minutes, ''stance'', e.stance) FROM public.world_expeditions e WHERE e.owner_id = m.owner_id AND e.status = ''active'' LIMIT 1),');
end $$;

grant select (mental, erosion, major_faction_id) on public.world_characters to fn_owner_social;
grant select (region_id, node_id, ends_at, minutes, stance) on public.world_expeditions to fn_owner_social;

-- 원정을 떠난 뒤 같은 곳의 파티원에게 「함께 가기」 알림(3분에 한 번)
create or replace function public.world_party_expedition_call()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); me record; x record; pid uuid; n int := 0; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select party_id into pid from public.world_party_members where owner_id = uid;
  if pid is null then raise exception '파티에 들어 있지 않습니다.'; end if;
  select c.character_name, c.location into me from public.world_characters c where c.owner_id = uid;
  select * into x from public.world_expeditions where owner_id = uid and status = 'active' order by started_at desc limit 1;
  if not found then raise exception '먼저 원정을 떠나야 동료를 부를 수 있습니다.'; end if;
  if exists (select 1 from public.world_notifications where kind = 'party_expedition' and (payload ->> 'from') = uid::text and created_at > now() - interval '3 minutes') then
    raise exception '방금 동료를 불렀습니다. 잠시 뒤에 다시 부를 수 있습니다.';
  end if;
  select node_name into nm from public.world_exploration_nodes where node_id = x.node_id;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select o.owner_id, 'party_expedition', '함께 원정 가기', me.character_name || ' 조사원이 ' || me.location || ' · ' || coalesce(nm, '원정지') || '(으)로 원정을 떠났습니다. 같은 곳으로 원정을 보내면 합동 전투를 하고 함께 다녀온 보너스를 받습니다.',
         jsonb_build_object('from', uid, 'name', me.character_name, 'location', me.location, 'region_id', x.region_id, 'node_id', x.node_id, 'minutes', x.minutes, 'stance', x.stance, 'ends_at', x.ends_at)
  from public.world_party_members pm join public.world_characters o on o.owner_id = pm.owner_id
  where pm.party_id = pid and pm.owner_id <> uid and o.location = me.location and o.downed_at is null and not coalesce(o.is_dead, false)
    and not exists (select 1 from public.world_expeditions e where e.owner_id = o.owner_id and e.status = 'active');
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'called', n, 'message', case when n > 0 then '같은 곳의 동료 ' || n || '명에게 함께 가자고 알렸습니다.' else '같은 곳에 부를 수 있는 동료가 없습니다.' end);
end $$;
grant select on public.world_exploration_nodes, public.world_expeditions to fn_owner_field;
grant select, insert on public.world_notifications to fn_owner_field;
alter function public.world_party_expedition_call() owner to fn_owner_field;
revoke all on function public.world_party_expedition_call() from public, anon, authenticated;
grant execute on function public.world_party_expedition_call() to authenticated;

-- 함께 다녀온 원정: 같은 지역 원정이 겹친 파티원 한 명마다 경험치·숙련 경험 +10%(세 명까지)
do $$ declare d text := pg_get_functiondef('public.world_expedition_complete(boolean)'::regprocedure);
  a text := '-- 긴 원정 완주 보상(20261029000000)';
begin
  if d like '%함께 간 동료(20261029050000)%' then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception 'expedition_complete anchor'; end if;
  execute replace(d, a, '-- 함께 간 동료(20261029050000)
  declare pa int; begin
    select count(distinct px.owner_id) into pa from public.world_party_members me_ join public.world_party_members om on om.party_id = me_.party_id and om.owner_id <> me_.owner_id
      join public.world_expeditions px on px.owner_id = om.owner_id and px.region_id = e.region_id and px.status in (''active'', ''done'')
     where me_.owner_id = e.owner_id and px.started_at < now() and coalesce(px.finished_at, px.ends_at) > e.started_at + interval ''10 minutes'';
    pa := least(coalesce(pa, 0), 3);
    if pa > 0 and e.settled_rounds > 0 then
      xp := round(xp * (1 + 0.1 * pa)); cxp := round(cxp * (1 + 0.1 * pa)); gxp := round(gxp * (1 + 0.1 * pa)); ixp := round(ixp * (1 + 0.1 * pa));
      lg := lg || jsonb_build_array(''동료 '' || pa || ''명과 함께 다녀온 원정 — 경험치·숙련 경험 +'' || (10 * pa) || ''%'');
    end if;
  end;
  ' || a);
end $$;

-- ⑩ ─────────────────────────────────────────
-- 조사 바로잡기: 원정 일지의 시간대 줄(「해돋이이 되었습니다」→「해돋이가 되었습니다」), 구조용 물품 문구(내부 코드 대신 물품 이름, 받침에 맞춘 조사)
do $$ declare d text := pg_get_functiondef('public.world_expedition_walk_lines'::regproc);
  a text := 'case ph when ''dawn'' then ''해돋이'' when ''noon'' then ''한낮'' when ''dusk'' then ''땅거미'' else ''삼경'' end || ''이 되었습니다.''';
  b text := 'case ph when ''dawn'' then ''해돋이가'' when ''noon'' then ''한낮이'' when ''dusk'' then ''땅거미가'' else ''삼경이'' end || '' 되었습니다.''';
begin
  if position(b in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '원정 일지 시간대 줄 고칠 자리가 하나가 아닙니다'; end if;
  execute replace(d, a, b);
end $$;
grant select on public.world_item_catalog to fn_owner_18989;
do $$ declare d text := pg_get_functiondef('public.world_use_recovery_item'::regproc);
  a text := '''구조용 아이템 사용: ''||p_item_id||''. 체력 ''||hp||''로 복귀했다.''';
  b text := '''구조용 물품 사용: ''||coalesce((select item_name from public.world_item_catalog where item_id=p_item_id),''물품'')||''. 체력 ''||hp||''(으)로 복귀했다.''';
begin
  if position(b in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '구조용 물품 문구 고칠 자리가 하나가 아닙니다'; end if;
  execute replace(d, a, b);
end $$;

-- 부적 정화(현장 생존 행동): 상태 설명대로 정화 부적으로 풀리는 상태이상(중독·심신 동요·사념 침식)도 함께 푼다.
--   침식이 없어도 그런 상태이상이 있으면 쓸 수 있다.
grant select on public.world_status_catalog to fn_owner_18944;
grant select, delete on public.world_character_statuses to fn_owner_18944;
do $$
declare pat record; d text;
begin
  for pat in select * from (values
    ('er int;', 'er int; cl int := 0;'),
    ('   if coalesce(c.erosion,0)<=0 then raise exception ''정화할 침식이 없습니다. 정화 부적은 그대로 남겨 두었습니다.''; end if;',
     '   select count(*) into cl from public.world_character_statuses cs join public.world_status_catalog sc on sc.status_key=cs.status_key
     where cs.owner_id=uid and cs.expires_at>now() and ''ward_talisman''=any(sc.cure_items);
   if coalesce(c.erosion,0)<=0 and cl=0 then raise exception ''정화할 침식이나 부적으로 풀 상태이상이 없습니다. 정화 부적은 그대로 남겨 두었습니다.''; end if;
   delete from public.world_character_statuses cs using public.world_status_catalog sc
     where sc.status_key=cs.status_key and cs.owner_id=uid and cs.expires_at>now() and ''ward_talisman''=any(sc.cure_items);'),
    ('   result_text:=''정화 부적을 태워 정화 의식을 마쳤다. 침식 -18, 정신 안정도 +6.'';',
     '   result_text:=''정화 부적을 태워 정화 의식을 마쳤다. 침식 -18, 정신 안정도 +6.''||case when cl>0 then '' 상태이상 ''||cl||''개가 풀렸다.'' else '''' end;')
  ) as t(a, b) loop
    d := pg_get_functiondef('public.world_survival_action(text)'::regprocedure);
    if position(pat.b in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, pat.a, ''))) / length(pat.a) <> 1 then raise exception '부적 정화 고칠 자리가 하나가 아닙니다: %', left(pat.a, 60); end if;
    execute replace(d, pat.a, pat.b);
  end loop;
end $$;

-- ⑪ ─────────────────────────────────────────
-- 대세력 떠나기·옮기기: 떠나면 평판 0, 세력 채팅(읽기 권한이 지금 소속을 따름)·거점·세력 효과가 사라지고, 12시간 뒤 다른 세력에 가입할 수 있다.
create or replace function public.world_leave_major_faction()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if c.major_faction_id is null then raise exception '대세력에 들어 있지 않습니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = uid and e.status = 'active') then raise exception '원정 중에는 세력을 떠날 수 없습니다.'; end if;
  select faction_name into nm from public.world_major_factions where faction_id = c.major_faction_id;
  update public.world_characters set major_faction_id = null, faction_reputation = 0, updated_at = now() where owner_id = uid;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'faction', c.character_name || ' 조사원이 ' || coalesce(nm, '세력') || '에서 나왔습니다.', jsonb_build_object('left', true, 'faction_id', c.major_faction_id));
  return jsonb_build_object('ok', true, 'content', coalesce(nm, '세력') || '에서 나왔습니다. 평판이 0이 되고 세력 채팅·거점·세력 효과가 사라집니다. 12시간 뒤 다른 세력에 가입할 수 있습니다.');
end $$;
grant select on public.world_expeditions, public.world_major_factions to fn_owner_18666;
grant select, insert on public.world_events to fn_owner_18666;
grant execute on function public.world_seal_guard() to fn_owner_18666;
grant create on schema public to fn_owner_18666;
alter function public.world_leave_major_faction() owner to fn_owner_18666;
revoke create on schema public from fn_owner_18666;
revoke all on function public.world_leave_major_faction() from public, anon, authenticated;
grant execute on function public.world_leave_major_faction() to authenticated;

do $$ declare d text := pg_get_functiondef('public.world_join_major_faction(text)'::regprocedure);
  a text := ' if c.major_faction_id is not null then raise exception ''현재 세력에서 탈퇴한 뒤에만 다른 세력에 가입할 수 있습니다.''; end if;';
  b text := ' if c.major_faction_id is not null then raise exception ''지금 세력을 떠난 뒤에 다른 세력에 가입할 수 있습니다(캐릭터 › 세력 › 세력 떠나기).''; end if;
 if exists (select 1 from public.world_events e where e.actor_id = uid and e.event_type = ''faction'' and e.payload ->> ''left'' = ''true'' and e.created_at > now() - interval ''12 hours'') then
   raise exception ''세력을 떠난 지 12시간이 지나야 다시 가입할 수 있습니다.'';
 end if;';
begin
  if position('12시간이 지나야' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '세력 가입 고칠 자리가 하나가 아닙니다'; end if;
  execute replace(d, a, b);
end $$;

-- 회복 완화(2026-10-28 결정)
-- ① 바깥 야영: 숙소 회복의 절반 → ⅔
do $$ declare d text := pg_get_functiondef('public.world_field_rest(text)'::regprocedure); n int;
begin
  if d like '%hp := hp * 2 / 3%' then return; end if;
  select count(*) into n from regexp_matches(d, 'hp := hp / 2;\s*mn := mn / 2;\s*sp := sp / 2;\s*er := er / 2;', 'g');
  if n <> 1 then raise exception '야영 회복 고칠 자리가 하나가 아닙니다'; end if;
  execute regexp_replace(d, 'hp := hp / 2;\s*mn := mn / 2;\s*sp := sp / 2;\s*er := er / 2;', 'hp := hp * 2 / 3; mn := mn * 2 / 3; sp := sp * 2 / 3; er := er * 2 / 3;');
end $$;

-- ② 안전지대에 머물면 10분마다 체력·정신 +5(전투불능·이동·원정 중 제외, 가득 차면 쓰지 않음). pg_cron yh-safe-regen.
create or replace function public.world_safe_regen()
returns integer language plpgsql set search_path to 'pg_catalog', 'public' as $$
declare n int;
begin
  update public.world_characters c set health = least(100, c.health + 5), mental = least(100, c.mental + 5)
    from public.world_map_regions r
   where r.is_safe_zone and r.active and r.region_name = c.location
     and (c.health < 100 or c.mental < 100) and c.health > 0 and c.downed_at is null and not coalesce(c.is_dead, false)
     and (c.travel_arrives_at is null or c.travel_arrives_at <= now())
     and not exists (select 1 from public.world_expeditions e where e.owner_id = c.owner_id and e.status = 'active');
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.world_safe_regen() from public, anon, authenticated;
do $$ begin
  if not exists (select 1 from cron.job where jobname = 'yh-safe-regen') then
    perform cron.schedule('yh-safe-regen', '*/10 * * * *', 'select public.world_safe_regen()');
  end if;
end $$;

-- ③ 본부 구조대: 소지금 30% → 15%(최소 30전, 레벨×80전까지), 하루(한국 시각) 첫 구조는 반값.
--    옮겨 가는 가까운 안전지대가 내 대세력 지배면 다시 반값·경험치 손실 없음·체력 50으로 깨어난다.
do $$
declare pat record; d text;
begin
  for pat in select * from (values
    ('xp_loss int := 0;', 'xp_loss int := 0; own boolean := false; first_today boolean := true;'),
    ('fee := least(c.gil, greatest(50, c.gil * 3 / 10));',
     'own := s.control_faction_id is not null and s.control_faction_id = c.major_faction_id;
  first_today := not exists (select 1 from public.world_events e where e.actor_id = uid and e.event_type = ''rescue'' and e.payload ->> ''self'' = ''true''
                               and e.created_at >= (date_trunc(''day'', now() at time zone ''Asia/Seoul'') at time zone ''Asia/Seoul''));
  fee := least(c.gil, least(c.level * 80, greatest(30, c.gil * 15 / 100)));
  if first_today then fee := fee / 2; end if;
  if own then fee := fee / 2; end if;'),
    ('round(public.world_xp_need(c.level) * 0.05)::int);', 'round(public.world_xp_need(c.level) * 0.05)::int); if own then xp_loss := 0; end if;'),
    ('health = 30, mental', 'health = case when own then 50 else 30 end, mental'),
    ('|| '' 체력 30''', '|| '' 체력 '' || case when own then 50 else 30 end || case when own then '' · 소속 세력 구조대(비용 반값·경험치 손실 없음)'' else '''' end || case when first_today then '' · 오늘 첫 구조 반값'' else '''' end')
  ) as t(a, b) loop
    d := pg_get_functiondef('public.world_call_rescue()'::regprocedure);
    if position(pat.b in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, pat.a, ''))) / length(pat.a) <> 1 then raise exception '구조대 고칠 자리가 하나가 아닙니다: %', left(pat.a, 60); end if;
    execute replace(d, pat.a, pat.b);
  end loop;
end $$;

-- ⑫ ─────────────────────────────────────────
-- 상위 도구: 같은 계열의 더 높은 단계 도구를 장착하면 낮은 단계 도구가 필요한 제작법도 만들 수 있다.
--   채집도 계열: 현장 채집도(1) → 강화 채집도(2) → 청강 채집도(3) → 천공 채집도(5) · 곡괭이 계열: 월철 곡괭이(1) → 영맥 곡괭이(4)
create table if not exists public.world_tool_lines (item_id text primary key references public.world_item_catalog(item_id), line text not null);
alter table public.world_tool_lines enable row level security;
revoke all on public.world_tool_lines from public, anon, authenticated;
grant select on public.world_tool_lines to authenticated;
drop policy if exists world_tool_lines_read on public.world_tool_lines;
create policy world_tool_lines_read on public.world_tool_lines for select to authenticated using (true);
insert into public.world_tool_lines(item_id, line) values
  ('field_knife', 'knife'), ('field_knife_2', 'knife'), ('t3_gather', 'knife'), ('t5_gather', 'knife'),
  ('ore_pick', 'pick'), ('t4_gather', 'pick')
on conflict (item_id) do update set line = excluded.line;

-- 장착한 도구(p_have)가 필요한 도구(p_need)를 대신할 수 있는가: 같거나, 같은 계열에서 단계가 같거나 높다
create or replace function public.world_tool_covers(p_have text, p_need text)
returns boolean language sql stable set search_path to 'pg_catalog', 'public' as $$
  select p_have = p_need or exists (
    select 1 from public.world_tool_lines a join public.world_tool_lines b on b.line = a.line
      join public.world_item_catalog ia on ia.item_id = a.item_id join public.world_item_catalog ib on ib.item_id = b.item_id
     where a.item_id = p_have and b.item_id = p_need and ia.tier >= ib.tier)
$$;
revoke all on function public.world_tool_covers(text, text) from public, anon, authenticated;
grant execute on function public.world_tool_covers(text, text) to fn_owner_18452;
grant select on public.world_tool_lines to fn_owner_18452;

do $$ declare d text := pg_get_functiondef('public.world_craft_item(text)'::regprocedure);
  a text := 'e.slot=''tool'' and e.item_id=r.required_tool;';
  b text := 'e.slot=''tool'' and public.world_tool_covers(e.item_id, r.required_tool);';
begin
  if position(b in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '제작 도구 검사 고칠 자리가 하나가 아닙니다'; end if;
  execute replace(d, a, b);
end $$;

-- 원정 전투 묘사: 승패와 주고받는 피해의 합은 지금 식(world_expedition_settle)이 정하고, 이 함수가 그 사이를 여러 합으로 풀어 쓴다.
--   내 쪽 공격(무기 갈래별 묘사·치명타·직업 기술 한 번)과 요괴의 공격(기믹 묘사·회피·막기)을 번갈아 적는다.
--   막기는 기술 「막기」 단계에 따라 확률이 오르고(6% + 단계×0.6%, 최대 35%) 그 공격의 피해를 절반으로 줄인다.
--   파티 원정: 함께 싸우는 동료 한 명마다 요괴가 하나씩 더 나온다(같은 지역 일반 요괴). 피해는 이목을 따라 나뉜다.
create or replace function public.world_exp_fight_story(p_owner uuid, p_me text, p_region text, p_foe jsonb, p_extra int, p_won boolean, p_ehp int, p_dmg int,
  p_allies jsonb, p_power float8, p_pres float8, p_base timestamptz, p_seq int, p_job text, p_wtype text, p_guard int)
returns jsonb language plpgsql volatile security definer set search_path to 'pg_catalog', 'public' as $$
declare
  foes jsonb := jsonb_build_array(p_foe); nf int; fhp int[]; a_n int; b_n int; t int; i int; seq int := p_seq; lines jsonb := '[]'::jsonb;
  dealt int; hits int[]; w float8[]; wsum float8; acc int; hi int := 0; ei int := 0; tgt int; carry int; nm text; mech text;
  who_n text; who_o uuid; pick float8; al jsonb; tot_w float8; nal int := coalesce(jsonb_array_length(p_allies), 0);
  etype text[]; parts int[]; left_d int; part int; taken int := 0; skill_at int; txt text; blk float8; told text[] := '{}'; kind_ text;
  vm text[]; va text[]; vh text[]; sk text;
begin
  if p_extra > 0 then
    foes := foes || coalesce((select jsonb_agg(jsonb_build_object('n', x.monster_name, 'mech', x.mechanic_key, 'role', x.role))
      from (select monster_name, mechanic_key, role from public.world_region_monsters where region_id = p_region and role <> 'guardian' order by random() limit p_extra) x), '[]'::jsonb);
  end if;
  nf := jsonb_array_length(foes);
  fhp := array_fill(p_ehp / nf, array[nf]); fhp[nf] := fhp[nf] + p_ehp - (p_ehp / nf) * nf;
  if nf > 1 then
    seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'fight', 'who', p_me, 'owner', p_owner,
      'text', (select string_agg(x ->> 'n', '·' order by o) from jsonb_array_elements(foes) with ordinality q(x, o) where o > 1) || '도 함께 덤벼듭니다. (요괴 ' || nf || ')');
  end if;

  -- 무기 갈래별 묘사
  vm := case p_wtype
    when 'ranged' then array['{f}에게 화살을 날렸습니다', '숨을 고르고 {f}의 눈을 노려 쏘았습니다', '거리를 벌리며 {f}에게 연달아 쏘았습니다', '{f}의 다리를 꿰뚫었습니다', '바람을 읽고 {f}의 등 뒤를 쏘았습니다']
    when 'magic' then array['영령 방울을 흔들어 {f}의 요기를 흩었습니다', '부적을 날려 {f}을(를) 태웠습니다', '주문을 외워 {f}을(를) 옭아맸습니다', '방울 소리로 {f}의 혼을 뒤흔들었습니다', '먹물로 쓴 술식이 {f}에게 달라붙었습니다']
    else array['{f}에게 칼날을 내리그었습니다', '{f}의 옆구리를 베어 냈습니다', '한 걸음 파고들어 {f}을(를) 찔렀습니다', '{f}의 공격을 흘리고 되받아쳤습니다', '자세를 낮춰 {f}의 다리를 쳐 냈습니다'] end;
  va := array['{f}에게 일격을 넣었습니다', '{f}의 빈틈을 파고들었습니다', '{f}을(를) 몰아붙였습니다', '{f}의 등을 노려 쳤습니다'];
  vh := array['{f}의 발톱에 긁혔습니다', '{f}이(가) 들이받았습니다', '{f}의 일격을 정면으로 맞았습니다', '{f}이(가) 물어뜯었습니다', '{f}이(가) 휘두른 팔에 밀려났습니다', '{f}의 요기에 살갗이 그을렸습니다'];
  sk := case p_job when 'exorcist' then '[파사검결] 부적을 두른 일격이 {f}의 요기를 갈랐습니다'
    when 'sealmaster' then '[봉인 결계] 결계를 펼쳐 {f}의 발을 묶었습니다'
    when 'medic' then '[응급 지혈] 싸우는 틈에 상처를 눌러 피를 멈췄습니다'
    when 'analyst' then '[약점 간파] {f}의 움직임에서 빈틈을 읽었습니다'
    when 'scout' then '[연속 사격] 몸을 낮추고 {f}에게 연달아 쏘았습니다'
    when 'artificer' then '[법구 발동] 허리춤의 법구가 빛을 뿜어 {f}을(를) 밀어냈습니다' else null end;

  -- 내 쪽 공격 횟수와 각 공격의 피해(합 = 요괴에게 준 피해. 이기면 요괴 체력 전부)
  a_n := least(16, case when p_won then 4 + floor(random() * 4)::int else 3 + floor(random() * 3)::int end + 2 * (nf - 1) + nal);
  dealt := case when p_won then p_ehp else greatest(1, round(p_ehp * (0.45 + random() * 0.35))::int) end;
  w := array[]::float8[]; for i in 1..a_n loop w := w || (0.6 + random()); end loop;
  wsum := (select sum(x) from unnest(w) x); hits := array[]::int[]; acc := 0;
  for i in 1..a_n loop
    if i = a_n then hits := hits || greatest(1, dealt - acc); else hits := hits || greatest(1, round(dealt * w[i] / wsum)::int); acc := acc + hits[i]; end if;
  end loop;
  -- 요괴 쪽 행동: 이기면 내 마지막 공격보다 먼저 끝나고, 지면 한두 번 더 몰아친다. 회피한 공격은 피해가 없다.
  b_n := greatest(2, case when p_won then a_n - 1 else a_n + 1 end + (nf - 1));
  if p_won then b_n := least(b_n, a_n); end if;
  etype := array[]::text[];
  for i in 1..b_n loop etype := etype || case when random() < 0.14 then 'dodge' else 'hit' end; end loop;
  if p_dmg > 0 and not ('hit' = any (etype)) then etype[1] := 'hit'; end if;
  w := array[]::float8[]; for i in 1..b_n loop w := w || case when etype[i] = 'hit' then 0.6 + random() else 0 end; end loop;
  wsum := greatest(0.0001, (select sum(x) from unnest(w) x)); parts := array[]::int[]; acc := 0;
  for i in 1..b_n loop
    if etype[i] <> 'hit' then parts := parts || 0;
    elsif i = (select max(j) from generate_subscripts(etype, 1) j where etype[j] = 'hit') then parts := parts || greatest(0, p_dmg - acc);
    else parts := parts || round(p_dmg * w[i] / wsum)::int; acc := acc + parts[i]; end if;
  end loop;
  blk := least(0.35, 0.06 + coalesce(p_guard, 0) * 0.006);
  skill_at := case when sk is not null then 2 + floor(random() * greatest(1, a_n - 2))::int else 0 end;

  for t in 1..greatest(a_n, b_n) loop
    -- 요괴의 차례
    if t <= b_n then
      ei := ei + 1;
      tgt := (select min(j) from generate_subscripts(fhp, 1) j where fhp[j] > 0);
      if tgt is null then tgt := nf; end if;
      -- 살아 있는 요괴 가운데 하나
      tgt := coalesce((select j from generate_subscripts(fhp, 1) j where fhp[j] > 0 order by random() limit 1), tgt);
      nm := foes -> (tgt - 1) ->> 'n'; mech := coalesce(foes -> (tgt - 1) ->> 'mech', '');
      if not (nm = any (told)) and random() < 0.55 then
        told := told || nm;
        txt := case mech
          when 'toxic' then '{f}이(가) 짙은 독기를 내뿜습니다' when 'spectral' then '{f}의 모습이 흐려졌다가 등 뒤에서 나타납니다'
          when 'ambush' then '{f}이(가) 그림자 속으로 몸을 숨깁니다' when 'tide' then '검은 물결이 일어 발목을 휘감습니다'
          when 'armored' then '{f}의 단단한 껍질에 공격이 미끄러집니다' when 'aerial' then '{f}이(가) 머리 위로 날아올라 덮쳐 옵니다'
          when 'swarm' then '{f}이(가) 사방에서 몰려듭니다' when 'seal_breaker' then '{f}이(가) 봉인의 틈을 비집고 요기를 터뜨립니다'
          when 'reflect' then '{f}이(가) 거울처럼 공격을 되비춥니다' when 'warded' then '{f} 주위의 금줄이 공격을 튕겨 냅니다'
          when 'boss' then '{f}의 포효에 땅이 울립니다' else '{f}이(가) 낮게 으르렁거리며 틈을 엿봅니다' end;
        seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'foe', 'who', p_me, 'owner', p_owner, 'text', replace(txt, '{f}', nm));
      end if;
      -- 이목(어그로)을 따라 맞는 사람을 고른다: 무게 = 이목^1.3
      who_n := p_me; who_o := p_owner;
      if nal > 0 then
        tot_w := (greatest(5, p_pres) ^ 1.3) + coalesce((select sum((greatest(5, (x ->> 'pres')::float8) ^ 1.3)) from jsonb_array_elements(p_allies) x), 0);
        pick := random() * tot_w - (greatest(5, p_pres) ^ 1.3);
        if pick >= 0 then
          for al in select x from jsonb_array_elements(p_allies) x loop
            who_n := al ->> 'name'; who_o := (al ->> 'owner')::uuid;
            exit when pick < (greatest(5, (al ->> 'pres')::float8) ^ 1.3);
            pick := pick - (greatest(5, (al ->> 'pres')::float8) ^ 1.3);
          end loop;
        end if;
      end if;
      part := parts[ei];
      if etype[ei] = 'dodge' or part <= 0 then
        kind_ := 'guard'; txt := (array['{f}의 공격을 몸을 틀어 피했습니다', '{f}의 일격이 허공을 갈랐습니다', '한 발 물러서 {f}의 공격을 흘려보냈습니다'])[1 + floor(random() * 3)::int];
        part := 0;
      elsif random() < blk and who_o = p_owner then
        part := greatest(1, round(part * 0.5)::int);
        kind_ := 'guard'; txt := '[막기] {f}의 공격을 받아 냈습니다 · 체력 -' || part;
      else
        kind_ := 'hurt'; txt := vh[1 + floor(random() * cardinality(vh))::int] || ' · 체력 -' || part;
      end if;
      if part > 0 then
        if who_o = p_owner then taken := taken + part; else insert into public.world_expedition_hits(owner_id, amount) values (who_o, part); end if;
      end if;
      seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', kind_, 'who', who_n, 'owner', who_o, 'text', replace(txt, '{f}', nm), 'value', part);
    end if;
    -- 내 쪽의 차례(동료는 전투력에 비례해 나선다)
    if t <= a_n then
      hi := hi + 1;
      tgt := coalesce((select min(j) from generate_subscripts(fhp, 1) j where fhp[j] > 0), nf);
      nm := foes -> (tgt - 1) ->> 'n';
      who_n := p_me; who_o := p_owner;
      if nal > 0 then
        pick := random() * (p_power + coalesce((select sum((x ->> 'power')::float8) from jsonb_array_elements(p_allies) x), 0));
        if pick >= p_power then
          pick := pick - p_power;
          for al in select x from jsonb_array_elements(p_allies) x loop
            who_n := al ->> 'name'; who_o := (al ->> 'owner')::uuid;
            exit when pick < (al ->> 'power')::float8;
            pick := pick - (al ->> 'power')::float8;
          end loop;
        end if;
      end if;
      if hi = skill_at then
        who_n := p_me; who_o := p_owner;
        seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'skill', 'who', p_me, 'owner', p_owner, 'text', replace(sk, '{f}', nm));
      end if;
      txt := case when who_o = p_owner then vm[1 + floor(random() * cardinality(vm))::int] else va[1 + floor(random() * cardinality(va))::int] end;
      if random() < 0.12 then txt := '급소를 찔렀습니다! ' || txt || ' · 치명타 ' || hits[hi] || ' 피해';
      else txt := txt || ' · ' || hits[hi] || ' 피해'; end if;
      seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'atk', 'who', who_n, 'owner', who_o, 'text', replace(txt, '{f}', nm), 'value', hits[hi]);
      -- 피해를 앞 요괴부터 깎고, 넘친 만큼은 다음 요괴로 이어진다
      carry := hits[hi];
      while carry > 0 loop
        tgt := (select min(j) from generate_subscripts(fhp, 1) j where fhp[j] > 0);
        exit when tgt is null;
        if carry >= fhp[tgt] then
          carry := carry - fhp[tgt]; fhp[tgt] := 0;
          if tgt < nf or not p_won then
            seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'fight', 'who', p_me, 'owner', p_owner, 'text', (foes -> (tgt - 1) ->> 'n') || '이(가) 쓰러졌습니다.');
          end if;
        else fhp[tgt] := fhp[tgt] - carry; carry := 0; end if;
      end loop;
    end if;
  end loop;
  if not p_won then
    seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'foe', 'who', p_me, 'owner', p_owner,
      'text', (array['요괴의 기세가 꺾이지 않습니다. 더 버티기 어렵습니다', '숨이 가빠져 더는 맞서기 어렵습니다', '상처가 깊어 거리를 벌립니다'])[1 + floor(random() * 3)::int]);
  end if;
  return jsonb_build_object('lines', lines, 'seq', seq, 'taken', taken);
end $$;
grant select on public.world_region_monsters to fn_owner_field;
grant insert on public.world_expedition_hits to fn_owner_field;
alter function public.world_exp_fight_story(uuid, text, text, jsonb, int, boolean, int, int, jsonb, float8, float8, timestamptz, int, text, text, int) owner to fn_owner_field;
revoke all on function public.world_exp_fight_story(uuid, text, text, jsonb, int, boolean, int, int, jsonb, float8, float8, timestamptz, int, text, text, int) from public, anon, authenticated;

-- world_expedition_settle에 잇기: 무기 갈래·막기 단계를 읽고, 파티 동료 한 명마다 요괴 위협 +45%(전에는 +30%, 요괴가 하나씩 더 나오는 만큼)
-- 이기면 더 나온 요괴마다 경험치와 전리품을 조금 더 얻는다. 주고받은 공격 줄은 위 함수가 쓴다.
do $$
declare d text; n int;
  rx text := 'b_n := b_n \+ nal; a_n := a_n \+ nal; my_taken := 0;.*?(\s*seq := seq \+ 1;\s*jr := jr \|\| jsonb_build_object\(''at'', base_t \+ make_interval\(secs => seq \* 2\), ''kind'', case when won then ''win'')';
begin
  d := pg_get_functiondef('public.world_expedition_settle(uuid,integer)'::regprocedure);
  if d like '%world_exp_fight_story%' then return; end if;
  select count(*) into n from regexp_matches(d, rx, 'g');
  if n <> 1 then raise exception '원정 전투 줄 고칠 자리가 하나가 아닙니다(%)', n; end if;
  d := regexp_replace(d, rx, 'my_taken := 0;
   fx := public.world_exp_fight_story(e.owner_id, me, r.region_id, jsonb_build_object(''n'', foe, ''mech'', m.mechanic_key, ''role'', m.role), nal, won, ehp, dmg, act, power, pres, base_t, seq, c.job_key, wtype, brank);
   jr := jr || (fx -> ''lines''); seq := (fx ->> ''seq'')::int; my_taken := (fx ->> ''taken'')::int;
   if won and nal > 0 then
     xp := xp + (5 + danger) * nal;
     for k in 1..nal loop
       if m.drops is not null and random() < 0.35 * loot_mul then
         select dd.k into item from jsonb_each(m.drops) dd(k, v) where exists (select 1 from public.world_item_catalog ic where ic.item_id = dd.k) order by random() limit 1;
         if item is not null then loot := public.world_inv_add(loot, item, 1); end if;
       end if;
     end loop;
   end if;\1');
  if position('pend int;' in d) = 0 then raise exception '원정 변수 자리'; end if;
  d := replace(d, 'pend int;', 'pend int; fx jsonb; wtype text; brank int;');
  if (length(d) - length(replace(d, 'pres := coalesce((public.world_combat_stats(e.owner_id) ->> ''presence'')::float8, 30);', ''))) / length('pres := coalesce((public.world_combat_stats(e.owner_id) ->> ''presence'')::float8, 30);') <> 1 then raise exception '원정 이목 줄 자리'; end if;
  d := replace(d, 'pres := coalesce((public.world_combat_stats(e.owner_id) ->> ''presence'')::float8, 30);',
    'pres := coalesce((public.world_combat_stats(e.owner_id) ->> ''presence'')::float8, 30);
 wtype := coalesce((select ic.equipment_traits ->> ''weapon_type'' from public.world_character_equipment q join public.world_item_catalog ic on ic.item_id = q.item_id where q.owner_id = e.owner_id and q.slot = ''weapon'' limit 1), ''melee'');
 brank := coalesce((c.skill_progress -> ''guarding'' ->> ''rank'')::int, 0);');
  if position('threat := threat * (1 + 0.3 * nal);' in d) = 0 or position('* (1 + 0.3 * nal));' in d) = 0 then raise exception '파티 위협 자리'; end if;
  d := replace(d, 'threat := threat * (1 + 0.3 * nal);', 'threat := threat * (1 + 0.45 * nal);');
  d := replace(d, '* (1 + 0.3 * nal));', '* (1 + 0.45 * nal));');
  execute d;
end $$;

-- ⑬ ─────────────────────────────────────────
-- 기술 단계 보상 개편(2026-10-28 결정): 계열마다 13·30단계 추가 기술, 24·43단계 둘 중 하나를 고르는 기술, 50단계 가장 강한 숙달 기술.
--   기존 9단계 기술은 그대로 두고 더한다. 단계가 높을수록 효과가 크다. 조합 기술 7개: 두 계열이 모두 18단계면 열리고, 계열마다 한 번씩만 쓰인다.
--   고른 택일 기술은 world_skill_picks.picks('계열:단계' → 'a'|'b')에 남는다(world_characters는 열마다 권한이 걸려 있어 새 열을 더하지 않는다). 처음 고르기는 무료, 바꾸기는 24단계 2,000전·43단계 5,000전.
alter table public.world_skill_catalog add column if not exists slot text not null default 'base';
alter table public.world_skill_catalog add column if not exists requires jsonb;
create table if not exists public.world_skill_picks (owner_id uuid primary key, picks jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now());
alter table public.world_skill_picks enable row level security;
revoke all on public.world_skill_picks from public, anon, authenticated;
grant select on public.world_skill_picks to authenticated;
drop policy if exists world_skill_picks_own on public.world_skill_picks;
create policy world_skill_picks_own on public.world_skill_picks for select to authenticated using (owner_id = (select auth.uid()));
grant select, insert, update on public.world_skill_picks to fn_owner_field;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot, requires)
values
  ('melee_x13', '발도', 'melee', '추가 기술 · 치명타 +2%', '{"crit_pct": 2}'::jsonb, 13, 'extra', null),
  ('melee_c24a', '일격', 'melee', '택일 기술 · 근접 피해 +5%', '{"damage_pct": 5}'::jsonb, 24, 'a', null),
  ('melee_c24b', '연타', 'melee', '택일 기술 · 근접 피해 +3% · 치명타 +2%', '{"damage_pct": 3, "crit_pct": 2}'::jsonb, 24, 'b', null),
  ('melee_x30', '강기 두르기', 'melee', '추가 기술 · 근접 피해 +4% · 받는 피해 −2%', '{"damage_pct": 4, "incoming_damage_pct": -2}'::jsonb, 30, 'extra', null),
  ('melee_c43a', '파천', 'melee', '택일 기술 · 근접 피해 +8%', '{"damage_pct": 8}'::jsonb, 43, 'a', null),
  ('melee_c43b', '유수검', 'melee', '택일 기술 · 근접 피해 +4% · 치명타 +4%', '{"damage_pct": 4, "crit_pct": 4}'::jsonb, 43, 'b', null),
  ('melee_m50', '검신', 'melee', '숙달 기술 · 근접 피해 +10% · 치명타 +5%', '{"damage_pct": 10, "crit_pct": 5}'::jsonb, 50, 'master', null),
  ('ranged_x13', '응시', 'ranged', '추가 기술 · 치명타 +2%', '{"crit_pct": 2}'::jsonb, 13, 'extra', null),
  ('ranged_c24a', '저격', 'ranged', '택일 기술 · 원거리 피해 +5%', '{"damage_pct": 5}'::jsonb, 24, 'a', null),
  ('ranged_c24b', '속사', 'ranged', '택일 기술 · 원거리 피해 +3% · 치명타 +2%', '{"damage_pct": 3, "crit_pct": 2}'::jsonb, 24, 'b', null),
  ('ranged_x30', '풍향 사격', 'ranged', '추가 기술 · 원거리 피해 +4% · 치명타 +2%', '{"damage_pct": 4, "crit_pct": 2}'::jsonb, 30, 'extra', null),
  ('ranged_c43a', '관통시', 'ranged', '택일 기술 · 원거리 피해 +8%', '{"damage_pct": 8}'::jsonb, 43, 'a', null),
  ('ranged_c43b', '연환시', 'ranged', '택일 기술 · 원거리 피해 +4% · 치명타 +4%', '{"damage_pct": 4, "crit_pct": 4}'::jsonb, 43, 'b', null),
  ('ranged_m50', '천궁', 'ranged', '숙달 기술 · 원거리 피해 +10% · 치명타 +5%', '{"damage_pct": 10, "crit_pct": 5}'::jsonb, 50, 'master', null),
  ('sealing_x13', '부적 접기', 'sealing', '추가 기술 · 술법 피해 +3%', '{"damage_pct": 3}'::jsonb, 13, 'extra', null),
  ('sealing_c24a', '폭렬부', 'sealing', '택일 기술 · 술법 피해 +5%', '{"damage_pct": 5}'::jsonb, 24, 'a', null),
  ('sealing_c24b', '정심주', 'sealing', '택일 기술 · 술법 피해 +3% · 정신 손실 −4%', '{"damage_pct": 3, "mental_loss_pct": -4}'::jsonb, 24, 'b', null),
  ('sealing_x30', '겹술식', 'sealing', '추가 기술 · 술법 피해 +4% · 침식 −4%', '{"damage_pct": 4, "erosion_pct": -4}'::jsonb, 30, 'extra', null),
  ('sealing_c43a', '천뢰부', 'sealing', '택일 기술 · 술법 피해 +8%', '{"damage_pct": 8}'::jsonb, 43, 'a', null),
  ('sealing_c43b', '청정결', 'sealing', '택일 기술 · 술법 피해 +4% · 침식 −6%', '{"damage_pct": 4, "erosion_pct": -6}'::jsonb, 43, 'b', null),
  ('sealing_m50', '태을진결', 'sealing', '숙달 기술 · 술법 피해 +10% · 침식 −8%', '{"damage_pct": 10, "erosion_pct": -8}'::jsonb, 50, 'master', null),
  ('analysis_x13', '관찰', 'analysis', '추가 기술 · 치명타 +2%', '{"crit_pct": 2}'::jsonb, 13, 'extra', null),
  ('analysis_c24a', '급소 간파', 'analysis', '택일 기술 · 치명타 +4%', '{"crit_pct": 4}'::jsonb, 24, 'a', null),
  ('analysis_c24b', '흐름 읽기', 'analysis', '택일 기술 · 주는 피해 +2% · 단서 +3%', '{"combat_damage_pct": 2, "clue_bonus_pct": 3}'::jsonb, 24, 'b', null),
  ('analysis_x30', '약점 기록', 'analysis', '추가 기술 · 치명타 +3% · 주는 피해 +2%', '{"crit_pct": 3, "combat_damage_pct": 2}'::jsonb, 30, 'extra', null),
  ('analysis_c43a', '필살 계산', 'analysis', '택일 기술 · 치명타 +6%', '{"crit_pct": 6}'::jsonb, 43, 'a', null),
  ('analysis_c43b', '전장 분석', 'analysis', '택일 기술 · 주는 피해 +4% · 단서 +3%', '{"combat_damage_pct": 4, "clue_bonus_pct": 3}'::jsonb, 43, 'b', null),
  ('analysis_m50', '만상통찰', 'analysis', '숙달 기술 · 치명타 +7% · 주는 피해 +4%', '{"crit_pct": 7, "combat_damage_pct": 4}'::jsonb, 50, 'master', null),
  ('guarding_x13', '받아넘기기', 'guarding', '추가 기술 · 받는 피해 −2%', '{"incoming_damage_pct": -2}'::jsonb, 13, 'extra', null),
  ('guarding_c24a', '철벽', 'guarding', '택일 기술 · 받는 피해 −4%', '{"incoming_damage_pct": -4}'::jsonb, 24, 'a', null),
  ('guarding_c24b', '반격 태세', 'guarding', '택일 기술 · 받는 피해 −2% · 주는 피해 +2%', '{"incoming_damage_pct": -2, "combat_damage_pct": 2}'::jsonb, 24, 'b', null),
  ('guarding_x30', '부동', 'guarding', '추가 기술 · 받는 피해 −3% · 정신 손실 −3%', '{"incoming_damage_pct": -3, "mental_loss_pct": -3}'::jsonb, 30, 'extra', null),
  ('guarding_c43a', '금강불괴', 'guarding', '택일 기술 · 받는 피해 −6%', '{"incoming_damage_pct": -6}'::jsonb, 43, 'a', null),
  ('guarding_c43b', '역류', 'guarding', '택일 기술 · 받는 피해 −3% · 주는 피해 +4%', '{"incoming_damage_pct": -3, "combat_damage_pct": 4}'::jsonb, 43, 'b', null),
  ('guarding_m50', '만장성벽', 'guarding', '숙달 기술 · 받는 피해 −8% · 정신 손실 −5%', '{"incoming_damage_pct": -8, "mental_loss_pct": -5}'::jsonb, 50, 'master', null),
  ('first_aid_x13', '지혈', 'first_aid', '추가 기술 · 회복량 +4%', '{"healing_pct": 4}'::jsonb, 13, 'extra', null),
  ('first_aid_c24a', '붕대술', 'first_aid', '택일 기술 · 회복량 +7%', '{"healing_pct": 7}'::jsonb, 24, 'a', null),
  ('first_aid_c24b', '안정 호흡', 'first_aid', '택일 기술 · 회복량 +3% · 정신 손실 −4%', '{"healing_pct": 3, "mental_loss_pct": -4}'::jsonb, 24, 'b', null),
  ('first_aid_x30', '약침', 'first_aid', '추가 기술 · 회복량 +6% · 침식 −3%', '{"healing_pct": 6, "erosion_pct": -3}'::jsonb, 30, 'extra', null),
  ('first_aid_c43a', '소생술', 'first_aid', '택일 기술 · 회복량 +10%', '{"healing_pct": 10}'::jsonb, 43, 'a', null),
  ('first_aid_c43b', '해독술', 'first_aid', '택일 기술 · 회복량 +4% · 침식 −6%', '{"healing_pct": 4, "erosion_pct": -6}'::jsonb, 43, 'b', null),
  ('first_aid_m50', '기사회생', 'first_aid', '숙달 기술 · 회복량 +14% · 받는 피해 −4%', '{"healing_pct": 14, "incoming_damage_pct": -4}'::jsonb, 50, 'master', null),
  ('foraging_x13', '눈썰미', 'foraging', '추가 기술 · 채집량 +3%', '{"gather_qty_pct": 3}'::jsonb, 13, 'extra', null),
  ('foraging_c24a', '넓게 줍기', 'foraging', '택일 기술 · 채집량 +6%', '{"gather_qty_pct": 6}'::jsonb, 24, 'a', null),
  ('foraging_c24b', '골라 줍기', 'foraging', '택일 기술 · 채집량 +2% · 희귀품 +3%', '{"gather_qty_pct": 2, "rare_loot_pct": 3}'::jsonb, 24, 'b', null),
  ('foraging_x30', '길목 기억', 'foraging', '추가 기술 · 채집량 +5% · 이동 시간 −3%', '{"gather_qty_pct": 5, "travel_time_pct": -3}'::jsonb, 30, 'extra', null),
  ('foraging_c43a', '대풍', 'foraging', '택일 기술 · 채집량 +9%', '{"gather_qty_pct": 9}'::jsonb, 43, 'a', null),
  ('foraging_c43b', '보물 감별', 'foraging', '택일 기술 · 채집량 +3% · 희귀품 +5%', '{"gather_qty_pct": 3, "rare_loot_pct": 5}'::jsonb, 43, 'b', null),
  ('foraging_m50', '산천의 은혜', 'foraging', '숙달 기술 · 채집량 +12% · 희귀품 +4%', '{"gather_qty_pct": 12, "rare_loot_pct": 4}'::jsonb, 50, 'master', null),
  ('herbalism_x13', '잎맥 살피기', 'herbalism', '추가 기술 · 채집량 +3%', '{"gather_qty_pct": 3}'::jsonb, 13, 'extra', null),
  ('herbalism_c24a', '깊이 캐기', 'herbalism', '택일 기술 · 채집량 +6%', '{"gather_qty_pct": 6}'::jsonb, 24, 'a', null),
  ('herbalism_c24b', '약효 보존', 'herbalism', '택일 기술 · 채집량 +2% · 회복량 +4%', '{"gather_qty_pct": 2, "healing_pct": 4}'::jsonb, 24, 'b', null),
  ('herbalism_x30', '약초꾼의 길', 'herbalism', '추가 기술 · 채집량 +4% · 회복량 +3%', '{"gather_qty_pct": 4, "healing_pct": 3}'::jsonb, 30, 'extra', null),
  ('herbalism_c43a', '약초 군락', 'herbalism', '택일 기술 · 채집량 +8%', '{"gather_qty_pct": 8}'::jsonb, 43, 'a', null),
  ('herbalism_c43b', '영초 감별', 'herbalism', '택일 기술 · 희귀품 +5% · 회복량 +4%', '{"rare_loot_pct": 5, "healing_pct": 4}'::jsonb, 43, 'b', null),
  ('herbalism_m50', '신농의 손', 'herbalism', '숙달 기술 · 채집량 +10% · 회복량 +8%', '{"gather_qty_pct": 10, "healing_pct": 8}'::jsonb, 50, 'master', null),
  ('mining_x13', '광맥 읽기', 'mining', '추가 기술 · 채집량 +3%', '{"gather_qty_pct": 3}'::jsonb, 13, 'extra', null),
  ('mining_c24a', '힘껏 캐기', 'mining', '택일 기술 · 채집량 +6%', '{"gather_qty_pct": 6}'::jsonb, 24, 'a', null),
  ('mining_c24b', '옥석 가리기', 'mining', '택일 기술 · 채집량 +2% · 희귀품 +3%', '{"gather_qty_pct": 2, "rare_loot_pct": 3}'::jsonb, 24, 'b', null),
  ('mining_x30', '갱도 감각', 'mining', '추가 기술 · 채집량 +5% · 받는 피해 −2%', '{"gather_qty_pct": 5, "incoming_damage_pct": -2}'::jsonb, 30, 'extra', null),
  ('mining_c43a', '노다지', 'mining', '택일 기술 · 채집량 +9%', '{"gather_qty_pct": 9}'::jsonb, 43, 'a', null),
  ('mining_c43b', '보석 눈', 'mining', '택일 기술 · 채집량 +3% · 희귀품 +5%', '{"gather_qty_pct": 3, "rare_loot_pct": 5}'::jsonb, 43, 'b', null),
  ('mining_m50', '지맥의 주인', 'mining', '숙달 기술 · 채집량 +12% · 희귀품 +4%', '{"gather_qty_pct": 12, "rare_loot_pct": 4}'::jsonb, 50, 'master', null),
  ('spirit_gathering_x13', '영기 감지', 'spirit_gathering', '추가 기술 · 채집량 +2% · 침식 −2%', '{"gather_qty_pct": 2, "erosion_pct": -2}'::jsonb, 13, 'extra', null),
  ('spirit_gathering_c24a', '영기 흡수', 'spirit_gathering', '택일 기술 · 채집량 +5%', '{"gather_qty_pct": 5}'::jsonb, 24, 'a', null),
  ('spirit_gathering_c24b', '정화 채집', 'spirit_gathering', '택일 기술 · 침식 −5%', '{"erosion_pct": -5}'::jsonb, 24, 'b', null),
  ('spirit_gathering_x30', '영맥 조율', 'spirit_gathering', '추가 기술 · 채집량 +4% · 희귀품 +2%', '{"gather_qty_pct": 4, "rare_loot_pct": 2}'::jsonb, 30, 'extra', null),
  ('spirit_gathering_c43a', '영기 폭주', 'spirit_gathering', '택일 기술 · 채집량 +8% · 희귀품 +2%', '{"gather_qty_pct": 8, "rare_loot_pct": 2}'::jsonb, 43, 'a', null),
  ('spirit_gathering_c43b', '청명심', 'spirit_gathering', '택일 기술 · 침식 −7% · 정신 손실 −3%', '{"erosion_pct": -7, "mental_loss_pct": -3}'::jsonb, 43, 'b', null),
  ('spirit_gathering_m50', '천지영기', 'spirit_gathering', '숙달 기술 · 채집량 +10% · 희귀품 +5% · 침식 −4%', '{"gather_qty_pct": 10, "rare_loot_pct": 5, "erosion_pct": -4}'::jsonb, 50, 'master', null),
  ('smithing_x13', '불꽃 담금', 'smithing', '추가 기술 · 제작 품질 +3', '{"craft_quality": 3}'::jsonb, 13, 'extra', null),
  ('smithing_c24a', '섬세한 단조', 'smithing', '택일 기술 · 제작 품질 +6', '{"craft_quality": 6}'::jsonb, 24, 'a', null),
  ('smithing_c24b', '현장 수리', 'smithing', '택일 기술 · 제작 품질 +3 · 받는 피해 −2%', '{"craft_quality": 3, "incoming_damage_pct": -2}'::jsonb, 24, 'b', null),
  ('smithing_x30', '명장의 눈', 'smithing', '추가 기술 · 제작 품질 +5', '{"craft_quality": 5}'::jsonb, 30, 'extra', null),
  ('smithing_c43a', '일품 단조', 'smithing', '택일 기술 · 제작 품질 +9', '{"craft_quality": 9}'::jsonb, 43, 'a', null),
  ('smithing_c43b', '강철 피부', 'smithing', '택일 기술 · 제작 품질 +4 · 받는 피해 −3%', '{"craft_quality": 4, "incoming_damage_pct": -3}'::jsonb, 43, 'b', null),
  ('smithing_m50', '천하명장', 'smithing', '숙달 기술 · 제작 품질 +12 · 주는 피해 +3%', '{"craft_quality": 12, "combat_damage_pct": 3}'::jsonb, 50, 'master', null),
  ('alchemy_x13', '달이기', 'alchemy', '추가 기술 · 제작 품질 +3', '{"craft_quality": 3}'::jsonb, 13, 'extra', null),
  ('alchemy_c24a', '농축', 'alchemy', '택일 기술 · 제작 품질 +6', '{"craft_quality": 6}'::jsonb, 24, 'a', null),
  ('alchemy_c24b', '약효 증폭', 'alchemy', '택일 기술 · 제작 품질 +2 · 회복량 +4%', '{"craft_quality": 2, "healing_pct": 4}'::jsonb, 24, 'b', null),
  ('alchemy_x30', '화후 조절', 'alchemy', '추가 기술 · 제작 품질 +4 · 회복량 +3%', '{"craft_quality": 4, "healing_pct": 3}'::jsonb, 30, 'extra', null),
  ('alchemy_c43a', '금단', 'alchemy', '택일 기술 · 제작 품질 +9', '{"craft_quality": 9}'::jsonb, 43, 'a', null),
  ('alchemy_c43b', '영약 조제', 'alchemy', '택일 기술 · 제작 품질 +3 · 회복량 +6%', '{"craft_quality": 3, "healing_pct": 6}'::jsonb, 43, 'b', null),
  ('alchemy_m50', '구전금단', 'alchemy', '숙달 기술 · 제작 품질 +10 · 회복량 +8%', '{"craft_quality": 10, "healing_pct": 8}'::jsonb, 50, 'master', null),
  ('wardcraft_x13', '먹 고르기', 'wardcraft', '추가 기술 · 제작 품질 +3', '{"craft_quality": 3}'::jsonb, 13, 'extra', null),
  ('wardcraft_c24a', '정교한 각인', 'wardcraft', '택일 기술 · 제작 품질 +6', '{"craft_quality": 6}'::jsonb, 24, 'a', null),
  ('wardcraft_c24b', '결계 두르기', 'wardcraft', '택일 기술 · 제작 품질 +2 · 침식 −4%', '{"craft_quality": 2, "erosion_pct": -4}'::jsonb, 24, 'b', null),
  ('wardcraft_x30', '겹결계', 'wardcraft', '추가 기술 · 제작 품질 +4 · 정신 손실 −3%', '{"craft_quality": 4, "mental_loss_pct": -3}'::jsonb, 30, 'extra', null),
  ('wardcraft_c43a', '천하 각인', 'wardcraft', '택일 기술 · 제작 품질 +9', '{"craft_quality": 9}'::jsonb, 43, 'a', null),
  ('wardcraft_c43b', '호신 결계', 'wardcraft', '택일 기술 · 제작 품질 +3 · 침식 −6%', '{"craft_quality": 3, "erosion_pct": -6}'::jsonb, 43, 'b', null),
  ('wardcraft_m50', '만법귀일', 'wardcraft', '숙달 기술 · 제작 품질 +10 · 침식 −6% · 정신 손실 −4%', '{"craft_quality": 10, "erosion_pct": -6, "mental_loss_pct": -4}'::jsonb, 50, 'master', null),
  ('tracking_x13', '흙자국 살피기', 'tracking', '추가 기술 · 단서 +3%', '{"clue_bonus_pct": 3}'::jsonb, 13, 'extra', null),
  ('tracking_c24a', '끈질긴 추적', 'tracking', '택일 기술 · 단서 +6%', '{"clue_bonus_pct": 6}'::jsonb, 24, 'a', null),
  ('tracking_c24b', '샛길', 'tracking', '택일 기술 · 단서 +2% · 이동 시간 −4%', '{"clue_bonus_pct": 2, "travel_time_pct": -4}'::jsonb, 24, 'b', null),
  ('tracking_x30', '기척 숨기기', 'tracking', '추가 기술 · 단서 +4% · 요괴 조우 −4%', '{"clue_bonus_pct": 4, "encounter_pct": -4}'::jsonb, 30, 'extra', null),
  ('tracking_c43a', '명탐', 'tracking', '택일 기술 · 단서 +9%', '{"clue_bonus_pct": 9}'::jsonb, 43, 'a', null),
  ('tracking_c43b', '바람처럼', 'tracking', '택일 기술 · 이동 시간 −6% · 요괴 조우 −4%', '{"travel_time_pct": -6, "encounter_pct": -4}'::jsonb, 43, 'b', null),
  ('tracking_m50', '만리추적', 'tracking', '숙달 기술 · 단서 +12% · 희귀품 +4% · 이동 시간 −4%', '{"clue_bonus_pct": 12, "rare_loot_pct": 4, "travel_time_pct": -4}'::jsonb, 50, 'master', null),
  ('combo_melee_smithing', '대장장이 검객', 'combo', '조합 기술(근접·단조 둘 다 18단계) · 치명타 +2% · 제작 품질 +3', '{"crit_pct": 2, "craft_quality": 3}'::jsonb, 18, 'combo', '{"melee": 18, "smithing": 18}'::jsonb),
  ('combo_ranged_tracking', '사냥꾼의 눈', 'combo', '조합 기술(원거리·추적 둘 다 18단계) · 치명타 +2% · 단서 +3%', '{"crit_pct": 2, "clue_bonus_pct": 3}'::jsonb, 18, 'combo', '{"ranged": 18, "tracking": 18}'::jsonb),
  ('combo_sealing_wardcraft', '겹봉인', 'combo', '조합 기술(봉인술·결계 각인 둘 다 18단계) · 주는 피해 +3% · 침식 −3%', '{"combat_damage_pct": 3, "erosion_pct": -3}'::jsonb, 18, 'combo', '{"sealing": 18, "wardcraft": 18}'::jsonb),
  ('combo_analysis_spirit_gathering', '영맥 판독', 'combo', '조합 기술(분석·영기 채집 둘 다 18단계) · 치명타 +2% · 희귀품 +2%', '{"crit_pct": 2, "rare_loot_pct": 2}'::jsonb, 18, 'combo', '{"analysis": 18, "spirit_gathering": 18}'::jsonb),
  ('combo_guarding_mining', '바위 몸', 'combo', '조합 기술(막기·광맥 채집 둘 다 18단계) · 받는 피해 −3% · 채집량 +3%', '{"incoming_damage_pct": -3, "gather_qty_pct": 3}'::jsonb, 18, 'combo', '{"guarding": 18, "mining": 18}'::jsonb),
  ('combo_first_aid_herbalism', '야전 약방', 'combo', '조합 기술(응급 처치·약초 채집 둘 다 18단계) · 회복량 +6%', '{"healing_pct": 6}'::jsonb, 18, 'combo', '{"first_aid": 18, "herbalism": 18}'::jsonb),
  ('combo_foraging_alchemy', '현장 조제', 'combo', '조합 기술(일반 채집·연금 둘 다 18단계) · 채집량 +3% · 제작 품질 +3', '{"gather_qty_pct": 3, "craft_quality": 3}'::jsonb, 18, 'combo', '{"foraging": 18, "alchemy": 18}'::jsonb)
on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description,
  passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot, requires = excluded.requires;

-- 이 캐릭터가 이 기술을 가졌는가: 단계에 닿았고, 택일 기술이면 고른 쪽이고, 조합 기술이면 두 계열 모두 조건 단계
create or replace function public.world_skill_has(p_prog jsonb, p_picks jsonb, p_cat text, p_unlock int, p_slot text, p_req jsonb)
returns boolean language sql immutable set search_path to 'pg_catalog' as $$
  select case
    when p_cat = 'combo' then coalesce((select bool_and(coalesce((p_prog -> r.k ->> 'rank')::int, 1) >= r.v::int) from jsonb_each_text(coalesce(p_req, '{}'::jsonb)) r(k, v)), false)
    when p_slot in ('a', 'b') then coalesce((p_prog -> p_cat ->> 'rank')::int, 1) >= p_unlock and coalesce(p_picks ->> (p_cat || ':' || p_unlock), '') = p_slot
    else coalesce((p_prog -> p_cat ->> 'rank')::int, 1) >= p_unlock end
$$;
revoke all on function public.world_skill_has(jsonb, jsonb, text, int, text, jsonb) from public, anon, authenticated;
do $$ declare r text; begin
  for r in select rolname from pg_roles where rolname like 'fn\_owner\_%' loop
    execute format('grant execute on function public.world_skill_has(jsonb, jsonb, text, int, text, jsonb) to %I', r);
  end loop;
end $$;
-- 기술 화면(world_skill_snapshot)은 부른 사람 권한으로 돈다. 값만 계산하는 함수라 조사원에게도 열어 둔다.
grant execute on function public.world_skill_has(jsonb, jsonb, text, int, text, jsonb) to authenticated;


-- 기술 효과 합(상한을 조금 넓힌다: 기술이 늘어난 만큼)
create or replace function public.world_skill_effect(p_effect_key text)
returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid; v numeric;
begin
  if p_effect_key not in ('gather_qty_pct', 'rare_loot_pct', 'clue_bonus_pct', 'healing_pct', 'incoming_damage_pct', 'mental_loss_pct', 'erosion_pct', 'travel_time_pct', 'craft_quality', 'combat_damage_pct', 'encounter_pct') then return 0; end if;
  uid := public.fn_owner_auth_uid(); if uid is null then return 0; end if;
  select coalesce(sum((sk.passive_effect ->> p_effect_key)::numeric), 0) into v
    from public.world_skill_catalog sk join public.world_characters c on c.owner_id = uid left join public.world_skill_picks pk on pk.owner_id = uid
   where sk.passive_effect ? p_effect_key and public.world_skill_has(c.skill_progress, coalesce(pk.picks, '{}'::jsonb), sk.category, sk.unlock_rank, sk.slot, sk.requires);
  -- 효과마다 상한: 한 갈래만 깊게 파도 넘치지 않게
  return case p_effect_key
    when 'gather_qty_pct' then least(v, 40) when 'rare_loot_pct' then least(v, 22) when 'clue_bonus_pct' then least(v, 28)
    when 'healing_pct' then least(v, 45) when 'craft_quality' then least(v, 40) when 'combat_damage_pct' then least(v, 15)
    when 'incoming_damage_pct' then greatest(v, -28) when 'mental_loss_pct' then greatest(v, -32)
    when 'erosion_pct' then greatest(v, -28) when 'travel_time_pct' then greatest(v, -20) when 'encounter_pct' then greatest(v, -15) else v end;
end $$;

-- 전투 능력치: 택일·조합 기술도 반영(조합 기술의 치명타 포함)
do $$ declare d text := pg_get_functiondef('public.world_combat_stats(uuid,jsonb)'::regprocedure);
  a text := 'WHERE sk.category IN (skill_cat, ''analysis'') AND coalesce((c.skill_progress -> sk.category ->> ''rank'')::int, 1) >= sk.unlock_rank;';
  b text := 'WHERE sk.category IN (skill_cat, ''analysis'', ''combo'') AND public.world_skill_has(c.skill_progress, coalesce((select pk.picks from public.world_skill_picks pk where pk.owner_id = p_owner), ''{}''::jsonb), sk.category, sk.unlock_rank, sk.slot, sk.requires);';
begin
  if position(b in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '전투 능력치 기술 조건 고칠 자리가 하나가 아닙니다'; end if;
  execute replace(d, a, b);
end $$;

-- 기술 화면: 계열별 기술(추가·택일·숙달·조합 포함), 단계 도달·고른 쪽·조합 조건
create or replace function public.world_skill_snapshot()
returns jsonb language plpgsql set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; out jsonb; pk jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 생성하세요.'; end if;
  pk := coalesce((select picks from public.world_skill_picks where owner_id = uid), '{}'::jsonb);
  select jsonb_agg(jsonb_build_object('skill_id', s.skill_id, 'skill_name', s.skill_name, 'category', s.category, 'description', s.description,
      'rank', coalesce((c.skill_progress -> s.category ->> 'rank')::int, 1), 'xp', coalesce((c.skill_progress -> s.category ->> 'xp')::int, 0),
      'unlock_rank', s.unlock_rank, 'active_skill', s.active_skill, 'passive_effect', s.passive_effect, 'slot', s.slot, 'requires', s.requires,
      'reached', case when s.category = 'combo' then public.world_skill_has(c.skill_progress, pk, s.category, s.unlock_rank, s.slot, s.requires)
                      else coalesce((c.skill_progress -> s.category ->> 'rank')::int, 1) >= s.unlock_rank end,
      'picked', case when s.slot in ('a', 'b') then coalesce(pk ->> (s.category || ':' || s.unlock_rank), '') = s.slot end,
      'req_ranks', case when s.category = 'combo' then (select jsonb_object_agg(r.k, coalesce((c.skill_progress -> r.k ->> 'rank')::int, 1)) from jsonb_each(s.requires) r(k, v)) end,
      'unlocked', public.world_skill_has(c.skill_progress, pk, s.category, s.unlock_rank, s.slot, s.requires))
    order by s.category, s.unlock_rank, case s.slot when 'base' then 0 when 'extra' then 1 when 'a' then 2 when 'b' then 3 else 4 end) into out
  from public.world_skill_catalog s;
  return coalesce(out, '[]'::jsonb);
end $$;

-- 택일 기술 고르기: 그 단계에 닿아야 하고, 처음은 무료, 바꾸면 24단계 2,000전·43단계 5,000전
create or replace function public.world_skill_choose(p_line text, p_tier int, p_pick text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; cur text; fee int := 0; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p_tier not in (24, 43) or p_pick not in ('a', 'b') then raise exception '고를 수 없는 기술입니다.'; end if;
  select skill_name into nm from public.world_skill_catalog where category = p_line and unlock_rank = p_tier and slot = p_pick;
  if nm is null then raise exception '고를 수 없는 기술입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce((c.skill_progress -> p_line ->> 'rank')::int, 1) < p_tier then raise exception '%단계에 닿아야 고를 수 있습니다.', p_tier; end if;
  cur := (select picks ->> (p_line || ':' || p_tier) from public.world_skill_picks where owner_id = uid);
  if cur = p_pick then raise exception '이미 고른 기술입니다.'; end if;
  if cur is not null then
    fee := case p_tier when 24 then 2000 else 5000 end;
    if c.gil < fee then raise exception '기술을 바꾸려면 %전이 필요합니다.', fee; end if;
  end if;
  insert into public.world_skill_picks(owner_id, picks) values (uid, jsonb_build_object(p_line || ':' || p_tier, p_pick))
  on conflict (owner_id) do update set picks = public.world_skill_picks.picks || excluded.picks, updated_at = now();
  if fee > 0 then update public.world_characters set gil = gil - fee, updated_at = now() where owner_id = uid; end if;
  return jsonb_build_object('ok', true, 'fee', fee, 'content', '「' || nm || '」을(를) 익혔습니다.' || case when fee > 0 then ' 바꾸는 값 ' || fee || '전을 냈습니다.' else '' end);
end $$;
grant execute on function public.world_seal_guard() to fn_owner_field;
alter function public.world_skill_choose(text, int, text) owner to fn_owner_field;
revoke all on function public.world_skill_choose(text, int, text) from public, anon, authenticated;
grant execute on function public.world_skill_choose(text, int, text) to authenticated;

grant fn_owner_social to postgres with inherit false, set false;
grant fn_owner_18666 to postgres with inherit false, set false;
grant fn_owner_18944 to postgres with inherit false, set false;
grant fn_owner_18989 to postgres with inherit false, set false;
grant fn_owner_field to postgres with inherit false, set false;
grant fn_owner_expedition to postgres with inherit false, set false;
grant fn_owner_18452 to postgres with inherit false, set false;
grant fn_owner_18987 to postgres with inherit false, set false;
grant fn_owner_18475 to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261029050000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
