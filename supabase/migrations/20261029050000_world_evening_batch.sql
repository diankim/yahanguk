-- 저녁 묶음 패치(2026-10-29): 한 번에 실행하는 파일이다.
--   ① 가방 가득 참 메시지를 화면과 같은 기준으로(장착 장비 제외) · 제작은 완성품 넣을 자리를 먼저 확인
--   ② 숫자 붙은 장소 이름 정리
--   ③ 창고: 어디서나 보기(넣고 꺼내기는 안전지대만) · 안전지대에서 제작하면 창고 재료도 쓴다
-- @@ROLES_ON@@

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
  note_id text primary key check (note_id ~ '^[0-9-]{4,12}$'),
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
  select w || case when w is not null and ascii(right(w, 1)) between 44032 and 55203 and (ascii(right(w, 1)) - 44032) % 28 = 0 then b else a end
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

do $$ declare d text := pg_get_functiondef('public.world_status_effect_total(text)'::regprocedure);
  a text := '+ public.world_skill_effect(p_effect_key)';
begin
  if d like '%world_social_effect%' then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception 'status_effect_total anchor'; end if;
  execute replace(d, a, a || ' + public.world_social_effect(p_effect_key)');
end $$;

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
  select region_id, f, pts, top, t1 from agg
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
        'influence', (select coalesce(round(sum(points)), 0) from public.world_region_influence i where i.faction_id = f.faction_id)) order by f.faction_name), '[]') from public.world_major_factions f where f.active),
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
