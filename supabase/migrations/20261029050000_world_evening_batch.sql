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
