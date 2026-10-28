-- 저녁 묶음 패치(2026-10-29): 한 번에 실행하는 파일이다.
--   ① 가방 가득 참 메시지를 화면과 같은 기준으로(장착 장비 제외) · 제작은 완성품 넣을 자리를 먼저 확인
--   ② 숫자 붙은 장소 이름 정리
--   ③ 창고: 어디서나 보기(넣고 꺼내기는 안전지대만) · 안전지대에서 제작하면 창고 재료도 쓴다
--   ④ 쓰러지면 전체 채팅에 구조 알림 · ⑤ 패치노트 표 · ⑥ 다시 시작하는 귀속 물품 2종(모두에게 하나씩) · ⑦ 물품 얻는 곳
--   ⑩ 조사 바로잡기(원정 일지 시간대·구조용 물품) · 부적 정화가 중독·심신 동요·사념 침식도 푼다
--   ⑪ 대세력 떠나기·옮기기(12시간) · 회복 완화(야영 ⅔·안전지대 자연 회복·구조대 비용)
--   ⑫ 상위 도구로 하위 도구 제작법 · 원정 전투 여러 합 묘사(막기·회피·치명타·직업 기술·요괴 기믹) · 파티 원정은 동료마다 요괴 하나 더
--   ⑬ 기술 단계 보상 개편(13·30 추가 · 24·43 택일 · 50 숙달 · 조합 7)
--   ⑰ 소속 효과(전투·생활·탐사·이동·경제)
--   ⑯ 전체 채팅 하루 50회 · 칭호 묶음(3칸 + 칭호로 최대 6칸) · 레벨 차 피해 보정(토벌·원정, 레벨마다 3%, 최대 30%) · 닳은 장비 알림
--   ⑮ 운영진 칭호(운영진만, 효과 없음)
--   ⑭ 요괴 13갈래(무기·직업 상성)·기믹 39(토벌 예고·원정 자동 대처) · 요괴 도감·채집 도감·도감 칭호 20 (⑫보다 먼저 실행: 원정 묘사가 ⑭의 표를 쓴다)
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
grant fn_owner_19141 to postgres with inherit true, set true;
grant fn_owner_18878 to postgres with inherit true, set true;

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

-- ⑭ ─────────────────────────────────────────
-- 요괴 갈래 13가지: 갈래마다 든 무기(근접·원거리·술법) 상성과 유리한 직업(+20%)이 있고, 갈래마다 기믹 3개(Lv1·Lv10·Lv20부터)를 쓴다.
--   현장 토벌: 기믹은 다음 행동으로 미리 드러난다(이름과 낌새만, 대처 안내는 하지 않는다). 방어는 어느 기믹이든 피해를 줄인다.
--   원정: 두 번째 합에 기믹을 한 번 쓰고, 캐릭터가 기술 단계·레벨 차·능력치로 저절로 대처한다(10~75%, 상성 무기·직업이면 +25%p).
-- 요괴 도감: 만나면 기본 정보, 쓰러뜨리면 상성·기믹 파훼법·전리품이 열린다. 채집 도감: 현장에서 채집한 재료. 도감 칭호 20개.
create table if not exists public.world_monster_kinds (
  kind_key text primary key, kind_name text not null, melee numeric not null default 1, ranged numeric not null default 1, magic numeric not null default 1,
  job_key text, description text not null, sort int not null default 0);
alter table public.world_monster_kinds enable row level security;
revoke all on public.world_monster_kinds from public, anon, authenticated;
insert into public.world_monster_kinds(kind_key, kind_name, melee, ranged, magic, job_key, description, sort) values
  ('bird', '비금', 0.6, 1.35, 1.0, 'scout', '하늘을 나는 요괴. 높이 솟았다가 내리꽂는다.', 1),
  ('shell', '갑각', 0.85, 0.7, 1.25, 'artificer', '단단한 껍질과 비늘을 두른 요괴.', 2),
  ('ghost', '영귀', 0.6, 0.8, 1.4, 'exorcist', '형체가 흐릿한 혼백과 원령.', 3),
  ('venom', '독충', 0.9, 1.15, 1.0, 'medic', '독을 품은 벌레·뱀·두꺼비.', 4),
  ('wood', '목령', 1.25, 0.9, 1.1, 'artificer', '나무와 덩굴에 깃든 요괴.', 5),
  ('shadow', '은형', 1.1, 0.9, 1.0, 'scout', '그림자와 어둠에 숨었다가 덮치는 요괴.', 6),
  ('water', '수귀', 1.0, 0.9, 1.15, 'medic', '물에 사는 귀신과 요괴.', 7),
  ('swarm', '군충', 1.25, 0.9, 1.1, null, '떼를 지어 몰려드는 요괴.', 8),
  ('ward', '금주', 1.1, 1.0, 0.8, 'sealmaster', '금줄과 결계를 두르는 요괴.', 9),
  ('mirror', '경요', 1.0, 1.15, 0.7, 'analyst', '거울과 빛을 다루는 요괴.', 10),
  ('breaker', '파봉', 1.1, 1.0, 0.85, 'exorcist', '봉인을 깨뜨려 요기를 퍼뜨리는 요괴.', 11),
  ('sky', '천상', 1.15, 0.85, 1.0, 'analyst', '별과 벼락의 힘을 쓰는 요괴.', 12),
  ('giant', '거괴', 1.0, 1.0, 1.0, 'sealmaster', '거대한 몸집으로 땅을 울리는 우두머리.', 13)
on conflict (kind_key) do update set kind_name = excluded.kind_name, melee = excluded.melee, ranged = excluded.ranged, magic = excluded.magic,
  job_key = excluded.job_key, description = excluded.description, sort = excluded.sort;

alter table public.world_region_monsters add column if not exists kind text references public.world_monster_kinds(kind_key);
update public.world_region_monsters set kind = case
  when monster_name in ('천문식자', '별자리 포식자', '유성 파편귀', '벼락 산령', '뇌각 산군') then 'sky'
  when monster_name in ('죽성객', '혈엽수인', '목인귀', '덩굴 손') then 'wood'
  when monster_name = '비묻은 도깨비불' then 'ghost'
  else case mechanic_key when 'aerial' then 'bird' when 'armored' then 'shell' when 'spectral' then 'ghost' when 'toxic' then 'venom'
    when 'ambush' then 'shadow' when 'tide' then 'water' when 'swarm' then 'swarm' when 'warded' then 'ward' when 'reflect' then 'mirror'
    when 'seal_breaker' then 'breaker' else 'giant' end end
where kind is null;

-- 기믹: gtype big(큰 한 방) · charge(한 턴 모았다가 터뜨림) · status(상태이상) · drain(흡수) · heal(회복) · shield(결계) · evade(허상)
--   · thorns(가시) · grapple(붙잡기) · mirror(거울막) · summon(무리 부르기). power = 공격 배율, power2 = 회복·결계 비율
create table if not exists public.world_monster_gimmicks (
  gimmick_key text primary key, kind_key text not null references public.world_monster_kinds(kind_key), tier int not null check (tier between 1 and 3),
  name text not null, tell text not null, gtype text not null, power numeric not null default 1, power2 numeric not null default 0,
  status text, chance numeric not null default 0, mental int not null default 0, erosion int not null default 0);
alter table public.world_monster_gimmicks enable row level security;
revoke all on public.world_monster_gimmicks from public, anon, authenticated;
insert into public.world_monster_gimmicks(gimmick_key, kind_key, tier, name, tell, gtype, power, power2, status, chance, mental, erosion) values
  ('bird_dive', 'bird', 1, '내리꽂기', '날개를 접고 머리 위로 솟구친다.', 'big', 1.4, 0, null, 0, 0, 0),
  ('bird_gale', 'bird', 2, '날개 돌풍', '날개를 크게 펼쳐 바람을 모은다.', 'status', 0.9, 0, 'disoriented', 0.4, 3, 0),
  ('bird_sky', 'bird', 3, '천공 강하', '구름 위로 사라져 날갯소리만 들린다.', 'charge', 2.4, 0, null, 0, 0, 0),
  ('shell_curl', 'shell', 1, '몸 말기', '껍질 속으로 몸을 웅크린다.', 'shield', 0.5, 0.08, null, 0, 0, 0),
  ('shell_harden', 'shell', 2, '껍질 가시', '껍질의 가시가 곤두선다.', 'thorns', 0.8, 0, null, 0, 0, 0),
  ('shell_thorn', 'shell', 3, '갑각 돌진', '껍질을 굳히고 몸을 낮춘다.', 'charge', 2.3, 0, null, 0, 0, 0),
  ('ghost_wail', 'ghost', 1, '흐느낌', '희미한 흐느낌이 들려온다.', 'status', 0.6, 0, 'shaken', 0.25, 4, 0),
  ('ghost_possess', 'ghost', 2, '빙의', '형체가 흐려지며 몸 안으로 스며들려 한다.', 'grapple', 1.0, 0, null, 0, 6, 2),
  ('ghost_soul', 'ghost', 3, '혼 빼기', '차가운 손을 가슴께로 뻗는다.', 'drain', 1.6, 0.6, null, 0, 8, 3),
  ('venom_sting', 'venom', 1, '독침', '꼬리 끝의 독침을 치켜든다.', 'status', 0.8, 0, 'poisoned', 0.35, 0, 0),
  ('venom_mist', 'venom', 2, '독무', '주둥이에서 탁한 안개가 샌다.', 'status', 0.7, 0, 'poisoned', 0.6, 2, 0),
  ('venom_stack', 'venom', 3, '맹독 주입', '독낭이 부풀어 오른다.', 'charge', 2.0, 0, 'poisoned', 0.8, 0, 0),
  ('wood_vine', 'wood', 1, '덩굴 채찍', '덩굴이 채찍처럼 휘어진다.', 'big', 1.3, 0, null, 0, 0, 0),
  ('wood_root', 'wood', 2, '뿌리 옭아매기', '발밑의 흙이 들썩인다.', 'grapple', 0.9, 0, null, 0, 2, 0),
  ('wood_regen', 'wood', 3, '수액 재생', '몸통의 상처에서 수액이 흘러내린다.', 'heal', 0.4, 0.10, null, 0, 0, 0),
  ('shadow_ambush', 'shadow', 1, '그림자 찌르기', '그림자가 발치로 스며든다.', 'big', 1.5, 0, null, 0, 0, 0),
  ('shadow_hide', 'shadow', 2, '그림자 숨기', '몸이 어둠에 녹아든다.', 'evade', 0.6, 0, null, 0, 2, 0),
  ('shadow_clone', 'shadow', 3, '그림자 분신', '그림자가 둘, 셋으로 갈라진다.', 'evade', 1.8, 0, 'bleeding', 0.3, 0, 0),
  ('water_splash', 'water', 1, '물 끼얹기', '물을 한 아름 끌어 올린다.', 'status', 0.7, 0, 'cold', 0.25, 0, 0),
  ('water_pull', 'water', 2, '물밑 끌어당기기', '발목에 차가운 손이 감긴다.', 'grapple', 1.1, 0, null, 0, 3, 0),
  ('water_chill', 'water', 3, '심해 냉기', '주위의 물이 얼어붙듯 차가워진다.', 'charge', 2.2, 0, 'cold', 0.7, 0, 0),
  ('swarm_bite', 'swarm', 1, '떼 물기', '무리가 한꺼번에 이빨을 드러낸다.', 'big', 1.3, 0, null, 0, 0, 0),
  ('swarm_call', 'swarm', 2, '무리 부르기', '날카로운 울음으로 무리를 부른다.', 'summon', 0.5, 0.12, null, 0, 0, 0),
  ('swarm_wave', 'swarm', 3, '떼의 파도', '흩어졌던 무리가 한 덩어리로 뭉친다.', 'charge', 2.4, 0, 'bleeding', 0.4, 0, 0),
  ('ward_rope', 'ward', 1, '금줄 휘감기', '금줄이 뱀처럼 꿈틀거린다.', 'grapple', 0.8, 0, null, 0, 0, 0),
  ('ward_absorb', 'ward', 2, '결계 흡수', '주위의 요기를 결계로 빨아들인다.', 'shield', 0.4, 0.15, null, 0, 0, 0),
  ('ward_curse', 'ward', 3, '저주 금줄', '금줄에 핏빛 글자가 떠오른다.', 'status', 1.4, 0, 'erosion_whisper', 0.6, 4, 5),
  ('mirror_glint', 'mirror', 1, '거울 번쩍임', '거울면이 빛을 모은다.', 'status', 0.6, 0, 'disoriented', 0.3, 0, 0),
  ('mirror_wall', 'mirror', 2, '거울막', '앞에 얇은 거울막이 선다.', 'mirror', 0.5, 0, null, 0, 0, 0),
  ('mirror_clone', 'mirror', 3, '거울 분신', '거울 속 모습이 하나둘 걸어 나온다.', 'evade', 1.9, 0, null, 0, 3, 0),
  ('breaker_crack', 'breaker', 1, '봉인 금 긋기', '손톱으로 허공에 금을 긋는다.', 'big', 1.3, 0, null, 0, 0, 2),
  ('breaker_burst', 'breaker', 2, '요기 분출', '금 간 틈에서 검은 기운이 샌다.', 'status', 1.2, 0, 'erosion_whisper', 0.35, 0, 4),
  ('breaker_unseal', 'breaker', 3, '대봉인 해방', '봉인문이 삐걱이며 열리기 시작한다.', 'charge', 2.6, 0, null, 0, 5, 8),
  ('sky_starlight', 'sky', 1, '별빛 가르기', '별빛이 칼날처럼 모인다.', 'big', 1.4, 0, null, 0, 0, 0),
  ('sky_bolt', 'sky', 2, '낙뢰', '머리 위로 먹구름이 모인다.', 'charge', 2.0, 0, 'burned', 0.4, 0, 0),
  ('sky_nebula', 'sky', 3, '성운 장막', '별가루가 몸을 감싼다.', 'shield', 0.6, 0.2, null, 0, 0, 0),
  ('giant_roar', 'giant', 1, '포효', '가슴을 크게 부풀린다.', 'status', 0.8, 0, 'shaken', 0.4, 5, 0),
  ('giant_charge', 'giant', 2, '땅 울리기 돌진', '땅을 박차며 몸을 낮춘다.', 'charge', 2.2, 0, null, 0, 0, 0),
  ('giant_blast', 'giant', 3, '파멸의 일격', '온몸의 요기가 한 팔로 모인다.', 'charge', 3.0, 0, null, 0, 0, 4)
on conflict (gimmick_key) do update set kind_key = excluded.kind_key, tier = excluded.tier, name = excluded.name, tell = excluded.tell, gtype = excluded.gtype,
  power = excluded.power, power2 = excluded.power2, status = excluded.status, chance = excluded.chance, mental = excluded.mental, erosion = excluded.erosion;

-- 레벨 → 기믹 단계(Lv1~9: 1 · Lv10~19: 2 · Lv20~: 3)
create or replace function public.world_monster_tier(p_level int) returns int language sql immutable set search_path to 'pg_catalog' as $$
  select case when coalesce(p_level, 1) >= 20 then 3 when coalesce(p_level, 1) >= 10 then 2 else 1 end
$$;
-- 원정에서 기믹에 대처하는 기술·능력치
create or replace function public.world_gimmick_counter(p_gtype text) returns text[] language sql immutable set search_path to 'pg_catalog' as $$
  select case p_gtype when 'big' then array['guarding', 'agility'] when 'charge' then array['guarding', 'vitality']
    when 'status' then array['first_aid', 'willpower'] when 'drain' then array['sealing', 'willpower'] when 'grapple' then array['sealing', 'willpower']
    when 'evade' then array['tracking', 'perception'] when 'thorns' then array['tracking', 'perception'] else array['analysis', 'perception'] end
$$;
-- 갈래 상성: 든 무기 갈래 배율 × 유리한 직업이면 1.2
create or replace function public.world_kind_mult(p_kind text, p_style text, p_job text) returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select case p_style when 'ranged' then k.ranged when 'magic' then k.magic else k.melee end * case when k.job_key = p_job then 1.2 else 1 end
    from public.world_monster_kinds k where k.kind_key = p_kind), 1)
$$;
alter function public.world_kind_mult(text, text, text) owner to fn_owner_field;

-- 다음 행동 고르기: 단계에 따라 기믹을 쓰고(1단계 12%·2단계 22%·3단계 30%, 정예·우두머리 +6%p), 아니면 지금까지의 행동
create or replace function public.world_battle_intent_k(p_kind text, p_level int, p_mech text, p_ratio numeric, p_rank text)
returns text language plpgsql volatile security definer set search_path to 'pg_catalog', 'public' as $$
declare t int := public.world_monster_tier(p_level); k text;
  pr float8 := (case t when 1 then 0.12 when 2 then 0.22 else 0.30 end) + (case when coalesce(p_rank, 'normal') <> 'normal' then 0.06 else 0 end);
begin
  if p_kind is not null and random() < pr then
    select gimmick_key into k from public.world_monster_gimmicks where kind_key = p_kind and tier <= t order by -ln(greatest(random(), 1e-9)) / tier limit 1;
    if k is not null then return 'g:' || k; end if;
  end if;
  return public.world_battle_intent(p_mech, p_ratio, p_rank);
end $$;
alter function public.world_battle_intent_k(text, int, text, numeric, text) owner to fn_owner_field;

-- 요괴 도감
create table if not exists public.world_monster_codex (
  owner_id uuid not null, monster_id text not null references public.world_region_monsters(monster_id) on delete cascade,
  seen int not null default 1, defeated int not null default 0, first_seen timestamptz not null default now(), first_defeat timestamptz,
  primary key (owner_id, monster_id));
alter table public.world_monster_codex enable row level security;
revoke all on public.world_monster_codex from public, anon, authenticated;
create or replace function public.world_codex_mark(p_owner uuid, p_monster text, p_seen int, p_def int)
returns void language sql volatile security definer set search_path to 'pg_catalog', 'public' as $$
  insert into public.world_monster_codex as x (owner_id, monster_id, seen, defeated, first_defeat)
  select p_owner, p_monster, greatest(1, p_seen), p_def, case when p_def > 0 then now() end
   where p_owner is not null and exists (select 1 from public.world_region_monsters m where m.monster_id = p_monster)
  on conflict (owner_id, monster_id) do update set seen = x.seen + p_seen, defeated = x.defeated + p_def,
    first_defeat = coalesce(x.first_defeat, case when p_def > 0 then now() end)
$$;
alter function public.world_codex_mark(uuid, text, int, int) owner to fn_owner_field;
-- 토벌 기록(어느 전투 함수든)으로 도감을 채운다. 만난 것은 전투를 열 때 world_battle_open이 적는다.
create or replace function public.world_codex_on_event() returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  if new.actor_id is not null and new.payload ? 'monster_id' then
    perform public.world_codex_mark(new.actor_id, new.payload ->> 'monster_id', 0,
      case when new.event_type = 'combat' and coalesce(new.payload ->> 'defeated', 'true') <> 'false' then 1 else 0 end);
  end if;
  return null;
end $$;
alter function public.world_codex_on_event() owner to fn_owner_field;
drop trigger if exists trg_world_codex_on_event on public.world_events;
create trigger trg_world_codex_on_event after insert on public.world_events for each row
  when (new.event_type in ('combat', 'battle_lost', 'battle_fled')) execute function public.world_codex_on_event();
-- 지금까지의 기록으로 채우기
insert into public.world_monster_codex(owner_id, monster_id, seen, defeated, first_seen, first_defeat)
select e.actor_id, e.payload ->> 'monster_id', count(*),
  count(*) filter (where e.event_type = 'combat' and coalesce(e.payload ->> 'defeated', 'true') <> 'false'), min(e.created_at),
  min(e.created_at) filter (where e.event_type = 'combat' and coalesce(e.payload ->> 'defeated', 'true') <> 'false')
  from public.world_events e join public.world_region_monsters m on m.monster_id = e.payload ->> 'monster_id'
 where e.event_type in ('combat', 'battle_lost', 'battle_fled') and e.actor_id is not null
 group by 1, 2
on conflict (owner_id, monster_id) do nothing;

-- 표·함수 권한: 전투·원정 함수 주인 역할들이 읽는다(화면에는 도감 함수로만 내보낸다)
do $$ declare r record; begin
  for r in select rolname from pg_roles where rolname like 'fn\_owner\_%' loop
    execute format('grant select on public.world_monster_kinds, public.world_monster_gimmicks, public.world_monster_codex to %I', r.rolname);
    execute format('grant execute on function public.world_kind_mult(text, text, text), public.world_battle_intent_k(text, int, text, numeric, text), public.world_codex_mark(uuid, text, int, int), public.world_monster_tier(int), public.world_gimmick_counter(text) to %I', r.rolname);
  end loop;
end $$;
grant insert, update on public.world_monster_codex to fn_owner_field;
revoke all on function public.world_kind_mult(text, text, text) from public, anon, authenticated;
revoke all on function public.world_battle_intent_k(text, int, text, numeric, text) from public, anon, authenticated;
revoke all on function public.world_codex_mark(uuid, text, int, int) from public, anon, authenticated;
revoke all on function public.world_codex_on_event() from public, anon, authenticated;
revoke all on function public.world_monster_tier(int) from public, anon, authenticated;
revoke all on function public.world_gimmick_counter(text) from public, anon, authenticated;

-- 전투 열기: 첫 행동도 기믹을 쓸 수 있고, 만난 요괴를 도감에 적는다
do $$ declare d text := pg_get_functiondef('public.world_battle_open(uuid,text,uuid,integer,integer)'::regprocedure);
  a text := 'public.world_battle_intent(m.mechanic_key, 1, rk)'; b text := 'public.world_battle_intent_k(m.kind, lv, m.mechanic_key, 1, rk)';
  a2 text := '  RETURN jsonb_build_object(''monster_id'', m.monster_id, ''name'', m.monster_name, ''rank'', rk, ''level'', lv);';
begin
  if position(b in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 or (length(d) - length(replace(d, a2, ''))) / length(a2) <> 1 then raise exception '전투 열기 고칠 자리'; end if;
  d := replace(d, a, b);
  d := replace(d, a2, '  PERFORM public.world_codex_mark(p_owner, m.monster_id, 1, 0);' || chr(10) || a2);
  execute d;
end $$;

-- 토벌 전투: 갈래 상성(무기·직업)과 기믹
do $$
declare d text := pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure); n int;
  procedure_ text;
begin
  if position('world_kind_mult' in d) > 0 then return; end if;
  -- 바꿀 자리가 정확히 한 번씩 있는지 먼저 본다
  for procedure_ in select unnest(array[
    'attacked boolean := false; wear jsonb; rare numeric;',
    'IF act = ''flee'' THEN' || chr(10) || '    IF random() * 100 < least(90,',
    '    mul := 0.85 + random() * 0.3;',
    '    dmg := greatest(1, round(base * mul - mdef * 0.8));',
    ' 피해를 입었다.''); END IF;',
    '  IF a.current_hp <= 0 THEN' || chr(10) || '    ended := ''victory'';' || chr(10) || '  ELSIF fled THEN',
    'WHEN ''breach'' THEN 0.7 ELSE 0 END;',
    'CASE WHEN v_intent IN (''heavy'', ''dive'', ''pounce'', ''unleash'') THEN 0.25 ELSE 0.35 END',
    'eva * (CASE WHEN v_intent IN (''heavy'', ''pounce'', ''unleash'') THEN 0.6 ELSE 1 END)',
    'WHEN ''breach'' THEN ''의 봉인 깨기'' ELSE ''의 공격'' END',
    'IF guarding AND v_intent IN (''heavy'', ''dive'', ''pounce'', ''unleash'') AND style = ''melee'' THEN',
    'IF v_intent IN (''heavy'', ''pounce'') AND NOT guarding AND random() < 0.2 THEN statuses := array_append(statuses, ''bleeding''); END IF;',
    'mdmg := round(mdmg * (1 + inc / 100.0) * (1 - adr / 100.0));']) loop
    if (length(d) - length(replace(d, procedure_, ''))) / length(procedure_) <> 1 then raise exception '토벌 전투 고칠 자리가 하나가 아닙니다: %', procedure_; end if;
  end loop;
  if (length(d) - length(replace(d, 'public.world_battle_intent(m.mechanic_key, a.current_hp::numeric / a.max_hp, a.rank)', ''))) / length('public.world_battle_intent(m.mechanic_key, a.current_hp::numeric / a.max_hp, a.rank)') <> 2 then raise exception '다음 행동 자리'; end if;
  select count(*) into n from regexp_matches(d, 'mul := mul \* CASE coalesce\(m\.mechanic_key, ''''\).*?ELSE 1 END;', 'g');
  if n <> 1 then raise exception '무기 상성 자리(%)', n; end if;

  d := replace(d, 'attacked boolean := false; wear jsonb; rare numeric;',
    'attacked boolean := false; wear jsonb; rare numeric; g public.world_monster_gimmicks%rowtype; gburst boolean := false; keen boolean := false; mheal int := 0; thorn int := 0;');
  d := replace(d, 'IF act = ''flee'' THEN' || chr(10) || '    IF random() * 100 < least(90,',
    'IF act = ''flee'' THEN' || chr(10) || '    IF coalesce((v_pfx ->> ''bound'')::int, 0) > 0 THEN' || chr(10)
    || '      lines := lines || jsonb_build_array(''붙잡혀 있어 달아날 수 없다.'');' || chr(10) || '    ELSIF random() * 100 < least(90,');
  d := replace(d, '    mul := 0.85 + random() * 0.3;',
    '    keen := coalesce((v_pfx ->> ''focus'')::int, 0) > 0 OR coalesce((v_fx ->> ''marked'')::int, 0) > 0;' || chr(10) || '    mul := 0.85 + random() * 0.3;');
  d := regexp_replace(d, 'mul := mul \* CASE coalesce\(m\.mechanic_key, ''''\).*?ELSE 1 END;', 'mul := mul * public.world_kind_mult(m.kind, style, c.job_key);');
  d := replace(d, '    dmg := greatest(1, round(base * mul - mdef * 0.8));',
    '    dmg := greatest(1, round(base * mul - mdef * 0.8));' || chr(10)
    || '    IF coalesce((v_fx ->> ''evade'')::int, 0) > 0 AND NOT keen AND random() < 0.5 THEN dmg := 0; lines := lines || jsonb_build_array(''허상을 쳤다. 공격이 빗나갔다.''); END IF;');
  d := replace(d, ' 피해를 입었다.''); END IF;',
    ' 피해를 입었다.''); END IF;' || chr(10)
    || '    IF coalesce((v_fx ->> ''thorns'')::int, 0) > 0 AND style = ''melee'' AND dmg > 0 THEN thorn := greatest(1, round(dmg * 0.3)); hp := greatest(0, hp - thorn); lines := lines || jsonb_build_array(''가시에 찔려 '' || thorn || '' 피해를 입었다.''); END IF;');
  d := replace(d, '  IF a.current_hp <= 0 THEN' || chr(10) || '    ended := ''victory'';' || chr(10) || '  ELSIF fled THEN',
    '  v_pfx := v_pfx - ''bound''; v_fx := v_fx - ''evade'' - ''thorns'';' || chr(10) || '  IF a.current_hp <= 0 THEN' || chr(10) || '    ended := ''victory'';' || chr(10) || '  ELSIF fled THEN');
  d := replace(d, 'WHEN ''breach'' THEN 0.7 ELSE 0 END;', 'WHEN ''breach'' THEN 0.7 ELSE 0 END;
      IF v_intent LIKE ''g%:%'' THEN
        SELECT * INTO g FROM public.world_monster_gimmicks WHERE gimmick_key = split_part(v_intent, '':'', 2);
        gburst := v_intent LIKE ''g!:%'';
        IF g.gimmick_key IS NULL THEN hit := a.atk * (0.9 + random() * 0.2);
        ELSIF g.gtype = ''charge'' AND NOT gburst THEN
          hit := 0;
          IF dmg >= a.max_hp * 0.15 THEN lines := lines || jsonb_build_array(m.monster_name || ''의 기세가 흐트러져 「'' || g.name || ''」이(가) 끊겼다.'');
          ELSE next_intent := ''g!:'' || g.gimmick_key; lines := lines || jsonb_build_array(m.monster_name || '': '' || g.tell); END IF;
        ELSE
          hit := a.atk * (0.9 + random() * 0.2) * g.power;
          IF g.gtype = ''heal'' THEN
            mheal := round(a.max_hp * g.power2 * CASE WHEN act = ''skill'' THEN 0.5 ELSE 1 END); a.current_hp := least(a.max_hp, a.current_hp + mheal);
            lines := lines || jsonb_build_array(m.monster_name || ''의 「'' || g.name || ''」: 체력 '' || mheal || '' 회복'' || CASE WHEN act = ''skill'' THEN '' (기술로 절반을 끊음)'' ELSE '''' END);
          ELSIF g.gtype = ''summon'' THEN
            a.current_hp := least(a.max_hp, a.current_hp + round(a.max_hp * g.power2)); v_fx := v_fx || jsonb_build_object(''swarm'', 1);
            lines := lines || jsonb_build_array(m.monster_name || ''의 「'' || g.name || ''」: 무리가 몰려든다.'');
          ELSIF g.gtype = ''shield'' THEN
            v_fx := v_fx || jsonb_build_object(''barrier'', coalesce((v_fx ->> ''barrier'')::int, 0) + round(a.max_hp * g.power2));
            lines := lines || jsonb_build_array(m.monster_name || ''의 「'' || g.name || ''」: 결계가 둘러졌다.'');
          ELSIF g.gtype = ''evade'' THEN v_fx := v_fx || jsonb_build_object(''evade'', 1);
          ELSIF g.gtype = ''thorns'' THEN v_fx := v_fx || jsonb_build_object(''thorns'', 1);
          ELSIF g.gtype = ''mirror'' THEN v_fx := v_fx || jsonb_build_object(''mirror'', 1);
          END IF;
        END IF;
      END IF;');
  d := replace(d, 'CASE WHEN v_intent IN (''heavy'', ''dive'', ''pounce'', ''unleash'') THEN 0.25 ELSE 0.35 END',
    'CASE WHEN v_intent IN (''heavy'', ''dive'', ''pounce'', ''unleash'') OR gburst OR g.gtype IS NOT DISTINCT FROM ''big'' THEN 0.25 ELSE 0.35 END');
  d := replace(d, 'eva * (CASE WHEN v_intent IN (''heavy'', ''pounce'', ''unleash'') THEN 0.6 ELSE 1 END)',
    'eva * (CASE WHEN v_intent IN (''heavy'', ''pounce'', ''unleash'') OR gburst THEN 0.6 ELSE 1 END)');
  d := replace(d, 'WHEN ''breach'' THEN ''의 봉인 깨기'' ELSE ''의 공격'' END',
    'WHEN ''breach'' THEN ''의 봉인 깨기'' ELSE CASE WHEN g.gimmick_key IS NOT NULL THEN ''의 「'' || g.name || ''」'' ELSE ''의 공격'' END END');
  d := replace(d, 'IF guarding AND v_intent IN (''heavy'', ''dive'', ''pounce'', ''unleash'') AND style = ''melee'' THEN',
    'IF guarding AND (v_intent IN (''heavy'', ''dive'', ''pounce'', ''unleash'') OR gburst OR g.gtype IS NOT DISTINCT FROM ''big'') AND style = ''melee'' THEN');
  d := replace(d, 'IF v_intent IN (''heavy'', ''pounce'') AND NOT guarding AND random() < 0.2 THEN statuses := array_append(statuses, ''bleeding''); END IF;',
    'IF v_intent IN (''heavy'', ''pounce'') AND NOT guarding AND random() < 0.2 THEN statuses := array_append(statuses, ''bleeding''); END IF;
          IF g.gimmick_key IS NOT NULL THEN
            IF g.status IS NOT NULL AND random() < g.chance * (CASE WHEN guarding THEN 0.5 ELSE 1 END) THEN statuses := array_append(statuses, g.status); END IF;
            IF g.mental > 0 THEN mn := greatest(0, mn - greatest(0, round(g.mental * (CASE WHEN guarding THEN 0.5 ELSE 1 END) * (1 + public.world_status_effect_total(''mental_loss_pct'') / 100.0))::int)); END IF;
            IF g.erosion > 0 THEN er := least(100, er + greatest(1, round(g.erosion * (1 + public.world_status_effect_total(''erosion_pct'') / 100.0))::int)); END IF;
            IF g.gtype = ''drain'' THEN mheal := round(mdmg * g.power2); a.current_hp := least(a.max_hp, a.current_hp + mheal); lines := lines || jsonb_build_array(m.monster_name || ''이(가) 기운을 빨아 체력 '' || mheal || '' 회복''); END IF;
            IF g.gtype = ''grapple'' THEN v_pfx := v_pfx || jsonb_build_object(''bound'', 1); lines := lines || jsonb_build_array(''붙잡혔다. 다음 턴에는 달아날 수 없다.''); END IF;
          END IF;');
  d := replace(d, 'public.world_battle_intent(m.mechanic_key, a.current_hp::numeric / a.max_hp, a.rank)',
    'public.world_battle_intent_k(m.kind, a.mlevel, m.mechanic_key, a.current_hp::numeric / a.max_hp, a.rank)');
  -- 레벨 차 보정: 요괴보다 레벨이 높으면 받는 피해가 레벨마다 3% 줄고(최대 30%), 낮으면 3%씩 늘어난다(최대 30%)
  d := replace(d, 'mdmg := round(mdmg * (1 + inc / 100.0) * (1 - adr / 100.0));',
    'mdmg := round(mdmg * (1 + inc / 100.0) * (1 - adr / 100.0) * greatest(0.7, least(1.3, 1 - 0.03 * (c.level - a.mlevel))));');
  execute d;
end $$;

-- 전투 화면 정보: 갈래 이름·설명, 기믹은 이름과 낌새만. 상성 배율은 그 요괴를 쓰러뜨려 도감에 적은 뒤에만 보인다.
create or replace function public.world_field_battle_view(p_owner uuid)
returns jsonb language sql stable set search_path to 'pg_catalog', 'public' as $$
  SELECT CASE WHEN a.owner_id IS NULL OR a.defeated OR coalesce(a.fled, false) OR a.mlevel IS NULL THEN NULL ELSE jsonb_build_object(
    'monster_id', m.monster_id, 'name', m.monster_name, 'type', m.monster_type, 'mechanic', m.mechanic_key, 'role', m.role,
    'description', m.description, 'rank', a.rank, 'level', a.mlevel, 'hp', a.current_hp, 'max_hp', a.max_hp, 'atk', a.atk,
    'intent', a.intent, 'turn', a.turn_count, 'fx', a.fx, 'pfx', a.pfx, 'log', a.log,
    'next_action_at', a.last_action_at + interval '1 second',
    'kind', m.kind, 'kind_name', k.kind_name, 'kind_desc', k.description,
    'gimmick', CASE WHEN g.gimmick_key IS NOT NULL THEN jsonb_build_object('name', g.name, 'tell', g.tell, 'burst', a.intent LIKE 'g!:%', 'tier', g.tier) END,
    'known', coalesce(x.defeated, 0) > 0,
    'eff', CASE WHEN coalesce(x.defeated, 0) > 0 THEN jsonb_build_object('melee', k.melee, 'ranged', k.ranged, 'magic', k.magic, 'job', k.job_key) END) END
  FROM (SELECT p_owner AS o) q
  LEFT JOIN public.world_active_encounters a ON a.owner_id = q.o
  LEFT JOIN public.world_region_monsters m ON m.monster_id = a.monster_id
  LEFT JOIN public.world_monster_kinds k ON k.kind_key = m.kind
  LEFT JOIN public.world_monster_gimmicks g ON a.intent LIKE 'g%:%' AND g.gimmick_key = split_part(a.intent, ':', 2)
  LEFT JOIN public.world_monster_codex x ON x.owner_id = q.o AND x.monster_id = m.monster_id
$$;

-- 기믹 파훼법 글(도감에서 쓰러뜨린 요괴에만 보인다)
create or replace function public.world_gimmick_tip(p_key text) returns text language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case g.gtype
      when 'big' then '큰 한 방입니다. 방어하면 4분의 1만 받고, 근접 무기로 막으면 받아칩니다.'
      when 'charge' then '한 턴 동안 기를 모았다가 다음 턴에 터뜨립니다. 모으는 턴에 체력의 15% 넘게 깎거나 봉인술로 묶으면 끊기고, 못 끊었으면 방어하세요(4분의 1).'
      when 'status' then '상태이상을 노리는 공격입니다.'
      when 'drain' then '때린 만큼 체력을 되찾습니다. 방어하면 덜 맞고 덜 빼앗깁니다.'
      when 'heal' then '체력을 크게 되찾습니다. 그 턴에 직업 기술을 쓰면 회복을 절반으로 끊습니다.'
      when 'shield' then '피해를 삼키는 결계를 칩니다. 술법은 결계를 두 배로 깎고, 폭렬 부적은 결계를 무시합니다.'
      when 'evade' then '다음 공격이 절반 확률로 빗나갑니다. 방어나 물품으로 한 턴 흘려보내면 사라지고, 표식·약점 간파가 있으면 빗나가지 않습니다.'
      when 'thorns' then '다음 근접 공격 피해의 30%를 되돌려 받습니다. 원거리·술법으로 치거나 한 턴 방어로 넘기세요.'
      when 'grapple' then '붙잡히면 다음 턴에 달아날 수 없습니다. 방어하면 덜 맞습니다.'
      when 'mirror' then '다음 술법 피해의 절반을 되돌립니다. 술법이 아닌 공격이나 방어로 넘기세요.'
      when 'summon' then '무리를 불러 체력을 조금 되찾고 다음 공격이 강해집니다. 빨리 몰아쳐 정리하세요.'
      else '' end
    || case when g.status is not null then ' 맞으면 「' || coalesce(sc.status_name, g.status) || '」이(가) 붙을 수 있고, 방어하면 그 확률이 절반입니다.' else '' end
    || case when g.mental > 0 or g.erosion > 0 then ' 맞으면 ' || concat_ws(' · ', case when g.mental > 0 then '정신 -' || g.mental end, case when g.erosion > 0 then '침식 +' || g.erosion end) || '.' else '' end
    || case when g.tier >= 2 then ' 원정에서는 '
         || case (public.world_gimmick_counter(g.gtype))[1] when 'guarding' then '막기' when 'first_aid' then '응급 처치' when 'sealing' then '봉인술' when 'tracking' then '추적' else '분석' end
         || ' 기술과 ' || case (public.world_gimmick_counter(g.gtype))[2] when 'agility' then '민첩' when 'vitality' then '체질' when 'willpower' then '의지' else '감각' end
         || '이(가) 높을수록 저절로 잘 대처하고, ' || case when greatest(k.melee, k.ranged, k.magic) <= 1 then '' when k.ranged >= greatest(k.melee, k.magic) then '원거리 무기' when k.magic >= k.melee then '술법 무기' else '근접 무기' end
         || case when greatest(k.melee, k.ranged, k.magic) > 1 and k.job_key is not null then '나 ' else '' end
         || coalesce(case k.job_key when 'exorcist' then '퇴마관' when 'sealmaster' then '봉인술사' when 'scout' then '현장 조사원' when 'analyst' then '기록 분석관' when 'medic' then '의무관' when 'artificer' then '법구 제작사' end, '')
         || '(이)면 더 잘 대처합니다.'
       else ' 원정에서는 따로 대처하지 않아도 되는 가벼운 기믹입니다.' end
  from public.world_monster_gimmicks g join public.world_monster_kinds k on k.kind_key = g.kind_key
  left join public.world_status_catalog sc on sc.status_key = g.status where g.gimmick_key = p_key
$$;
alter function public.world_gimmick_tip(text) owner to fn_owner_field;
revoke all on function public.world_gimmick_tip(text) from public, anon, authenticated;

-- 도감 칭호 판정: {"codex":"kind","kind":k,"n":N} 그 갈래에서 쓰러뜨린 요괴 수 · {"codex":"all"} 쓰러뜨린 요괴 수
--   · {"codex":"kinds"} 하나라도 쓰러뜨린 갈래 수 · {"codex":"gather"} 채집 도감에 오른 재료 수
create or replace function public.world_codex_rule_count(p_owner uuid, p_rule jsonb) returns int language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case p_rule ->> 'codex'
    when 'kind' then (select count(*) from public.world_monster_codex x join public.world_region_monsters m using (monster_id) where x.owner_id = p_owner and x.defeated > 0 and m.kind = p_rule ->> 'kind')
    when 'all' then (select count(*) from public.world_monster_codex x where x.owner_id = p_owner and x.defeated > 0)
    when 'kinds' then (select count(distinct m.kind) from public.world_monster_codex x join public.world_region_monsters m using (monster_id) where x.owner_id = p_owner and x.defeated > 0)
    when 'gather' then (select count(distinct e.payload ->> 'item_id') from public.world_events e
      where e.actor_id = p_owner and e.event_type = 'gather' and e.payload ->> 'item_id' in (select unnest(s.loot_items) from public.world_gathering_spots s where s.active))
    else 0 end::int
$$;
alter function public.world_codex_rule_count(uuid, jsonb) owner to fn_owner_field;
revoke all on function public.world_codex_rule_count(uuid, jsonb) from public, anon, authenticated;

do $$ declare d text;
  a text := 'ELSIF p_rule ? ''survey_full'' THEN';
  b text := 'elsif p_rule ? ''survey_full'' then';
  c text := '    IF (r ? ''nodes'' OR r ? ''spots'')';
begin
  d := pg_get_functiondef('public.world_title_rule_ok(uuid,jsonb)'::regprocedure);
  if position('world_codex_rule_count' in d) = 0 then
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '칭호 판정 자리'; end if;
    execute replace(d, a, 'ELSIF p_rule ? ''codex'' THEN' || chr(10) || '    RETURN public.world_codex_rule_count(p_owner, p_rule) >= n;' || chr(10) || '  ' || a);
  end if;
  d := pg_get_functiondef('public.world_title_rule_progress(uuid,jsonb)'::regprocedure);
  if position('world_codex_rule_count' in d) = 0 then
    if (length(d) - length(replace(d, b, ''))) / length(b) <> 1 then raise exception '칭호 진행 자리'; end if;
    execute replace(d, b, 'elsif p_rule ? ''codex'' then' || chr(10) || '    v := public.world_codex_rule_count(p_owner, p_rule);' || chr(10) || '  ' || b);
  end if;
  d := pg_get_functiondef('public.world_title_award_check(uuid,text)'::regprocedure);
  if position('''codex''' in d) = 0 then
    if (length(d) - length(replace(d, c, ''))) / length(c) <> 1 then raise exception '칭호 판정 시점 자리'; end if;
    execute replace(d, c, '    IF r ? ''codex'' AND p_event_type IS NOT NULL AND NOT (CASE WHEN r ->> ''codex'' = ''gather'' THEN p_event_type = ''gather'' ELSE p_event_type IN (''combat'', ''expedition_end'') END) THEN CONTINUE; END IF;' || chr(10) || c);
  end if;
end $$;

insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
  ('codex_bird', '매사냥꾼', 'eye', '하늘을 나는 요괴의 날갯짓을 읽는다.', '비금 요괴 6종 토벌', '{"ranged_pct":3,"evasion_pct":1}', true, false, '{"codex":"kind","kind":"bird","n":6}', 123, '도감', 2),
  ('codex_shell', '껍질 깨는 자', 'eye', '아무리 단단한 껍질도 틈은 있다.', '갑각 요괴 6종 토벌', '{"magic_pct":3,"defense":1}', true, false, '{"codex":"kind","kind":"shell","n":6}', 124, '도감', 2),
  ('codex_ghost', '원혼 달래는 자', 'eye', '흐느끼는 혼백을 여럿 보냈다.', '영귀 요괴 6종 토벌', '{"magic_pct":3,"mental_loss_pct":-3}', true, false, '{"codex":"kind","kind":"ghost","n":6}', 125, '도감', 2),
  ('codex_venom', '독벌레 잡이', 'eye', '독침이 어디서 올지 안다.', '독충 요괴 5종 토벌', '{"ranged_pct":3,"healing_pct":2}', true, false, '{"codex":"kind","kind":"venom","n":5}', 126, '도감', 2),
  ('codex_wood', '나무꾼 퇴마사', 'eye', '덩굴과 뿌리를 베어 길을 낸다.', '목령 요괴 3종 토벌', '{"melee_pct":3,"gather_qty_pct":2}', true, false, '{"codex":"kind","kind":"wood","n":3}', 127, '도감', 2),
  ('codex_shadow', '그림자 사냥꾼', 'eye', '어둠 속 숨은 몸을 찾아낸다.', '은형 요괴 6종 토벌', '{"melee_pct":3,"crit_pct":1}', true, false, '{"codex":"kind","kind":"shadow","n":6}', 128, '도감', 2),
  ('codex_water', '물귀신 건지는 자', 'eye', '물밑에서 뻗는 손을 뿌리친다.', '수귀 요괴 6종 토벌', '{"magic_pct":3,"fish_bite_pct":3}', true, false, '{"codex":"kind","kind":"water","n":6}', 129, '도감', 2),
  ('codex_swarm', '떼 쫓는 자', 'eye', '몰려드는 무리를 흩어 놓는다.', '군충 요괴 5종 토벌', '{"melee_pct":3,"defense":1}', true, false, '{"codex":"kind","kind":"swarm","n":5}', 130, '도감', 2),
  ('codex_ward', '금줄 끊는 자', 'eye', '휘감는 금줄도 끊어 낸다.', '금주 요괴 3종 토벌', '{"melee_pct":3,"erosion_pct":-3}', true, false, '{"codex":"kind","kind":"ward","n":3}', 131, '도감', 2),
  ('codex_mirror', '거울 깨는 자', 'eye', '거울 속 허상에 속지 않는다.', '경요 요괴 3종 토벌', '{"ranged_pct":3,"crit_pct":1}', true, false, '{"codex":"kind","kind":"mirror","n":3}', 132, '도감', 2),
  ('codex_breaker', '봉인 지킴이', 'eye', '깨지려는 봉인을 몇 번이나 지켜 냈다.', '파봉 요괴 4종 토벌', '{"erosion_pct":-6,"melee_pct":2}', true, false, '{"codex":"kind","kind":"breaker","n":4}', 133, '도감', 3),
  ('codex_sky', '하늘을 벤 자', 'eye', '별과 벼락을 다루는 요괴를 꺾었다.', '천상 요괴 3종 토벌', '{"crit_pct":2,"combat_damage_pct":2}', true, false, '{"codex":"kind","kind":"sky","n":3}', 134, '도감', 3),
  ('codex_giant', '거괴 토벌자', 'eye', '땅을 울리는 거대한 요괴를 쓰러뜨렸다.', '거괴 요괴 2종 토벌', '{"incoming_damage_pct":-3,"combat_damage_pct":2}', true, false, '{"codex":"kind","kind":"giant","n":2}', 135, '도감', 3),
  ('codex_20', '요괴 도감 기록관', 'scroll', '요괴 도감의 첫 권을 채웠다.', '요괴 20종 토벌', '{"combat_damage_pct":2,"rare_loot_pct":1}', true, false, '{"codex":"all","n":20}', 136, '도감', 2),
  ('codex_50', '백귀 사냥꾼', 'scroll', '쉰 가지 요괴의 약점을 안다.', '요괴 50종 토벌', '{"combat_damage_pct":3,"crit_pct":1}', true, false, '{"codex":"all","n":50}', 137, '도감', 3),
  ('codex_kinds', '백귀야행 기록관', 'scroll', '열세 갈래 요괴를 모두 기록했다.', '13갈래 요괴를 하나씩 토벌', '{"combat_damage_pct":4,"rare_loot_pct":3,"incoming_damage_pct":-2}', true, false, '{"codex":"kinds","n":13}', 138, '도감', 4),
  ('codex_100', '만귀보', 'scroll', '세상의 요괴를 빠짐없이 적은 책의 주인.', '숨겨진 조건', '{"combat_damage_pct":6,"crit_pct":3,"rare_loot_pct":3}', true, true, '{"codex":"all","n":100}', 139, '도감', 5),
  ('codex_gather_10', '채집 도감 첫 장', 'leaf', '거둔 재료를 하나씩 적어 나간다.', '재료 10가지 채집', '{"gather_qty_pct":2}', true, false, '{"codex":"gather","n":10}', 140, '도감', 1),
  ('codex_gather_20', '채집 도감 반권', 'leaf', '어디서 무엇이 나는지 훤하다.', '재료 20가지 채집', '{"gather_qty_pct":3,"rare_loot_pct":1}', true, false, '{"codex":"gather","n":20}', 141, '도감', 2),
  ('codex_gather_all', '채집 도감 완성', 'leaf', '세상의 채집 재료를 모두 거두었다.', '채집 도감 32가지 모두 채집', '{"gather_qty_pct":6,"rare_loot_pct":3,"craft_quality":2}', true, false, '{"codex":"gather","n":32}', 142, '도감', 4)
on conflict (title_key) do update set title_name = excluded.title_name, icon = excluded.icon, description = excluded.description, condition_text = excluded.condition_text,
  bonus = excluded.bonus, active = excluded.active, hidden = excluded.hidden, rule = excluded.rule, sort = excluded.sort, category = excluded.category, grade = excluded.grade;

-- 요괴 도감 화면: 만난 요괴는 기본 정보, 쓰러뜨린 요괴는 상성·기믹 파훼법·전리품. 만나지 못한 요괴는 갈래와 사는 곳만.
create or replace function public.world_monster_codex_snapshot()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object(
    'kinds', (select jsonb_agg(jsonb_build_object('key', k.kind_key, 'name', k.kind_name, 'desc', k.description,
        'total', (select count(*) from public.world_region_monsters m where m.kind = k.kind_key),
        'seen', (select count(*) from public.world_monster_codex x join public.world_region_monsters m using (monster_id) where x.owner_id = uid and m.kind = k.kind_key),
        'defeated', (select count(*) from public.world_monster_codex x join public.world_region_monsters m using (monster_id) where x.owner_id = uid and m.kind = k.kind_key and x.defeated > 0))
      order by k.sort) from public.world_monster_kinds k),
    'monsters', (select jsonb_agg(case when x.owner_id is null then
        jsonb_build_object('id', m.monster_id, 'kind', m.kind, 'known', false, 'region', r.region_name, 'region_id', m.region_id, 'level', m.min_level, 'role', m.role)
      else jsonb_build_object('id', m.monster_id, 'kind', m.kind, 'known', true, 'name', m.monster_name, 'region', r.region_name, 'region_id', m.region_id,
        'level', m.min_level, 'max_level', m.max_level, 'role', m.role, 'desc', m.description, 'seen', x.seen, 'defeated', x.defeated,
        'counter', case when x.defeated > 0 then jsonb_build_object('melee', k.melee, 'ranged', k.ranged, 'magic', k.magic, 'job', k.job_key, 'habit', m.mechanic_description,
          'gimmicks', (select jsonb_agg(jsonb_build_object('name', g.name, 'tier', g.tier, 'from', case g.tier when 1 then 1 when 2 then 10 else 20 end, 'tell', g.tell, 'tip', public.world_gimmick_tip(g.gimmick_key)) order by g.tier)
            from public.world_monster_gimmicks g where g.kind_key = m.kind),
          'drops', (select jsonb_agg(jsonb_build_object('id', dd.key, 'name', ic.item_name)) from jsonb_each(coalesce(m.drops, '{}'::jsonb)) dd join public.world_item_catalog ic on ic.item_id = dd.key)) end) end
      order by k.sort, m.min_level, m.monster_name)
      from public.world_region_monsters m join public.world_map_regions r on r.region_id = m.region_id join public.world_monster_kinds k on k.kind_key = m.kind
      left join public.world_monster_codex x on x.owner_id = uid and x.monster_id = m.monster_id),
    'titles', (select jsonb_agg(jsonb_build_object('name', case when tc.hidden and ct.title_key is null then '숨겨진 칭호' else tc.title_name end,
        'condition', case when tc.hidden and ct.title_key is null then '숨겨진 조건' else tc.condition_text end, 'earned', ct.title_key is not null,
        'progress', case when ct.title_key is null and not tc.hidden then public.world_codex_rule_count(uid, tc.rule) end, 'need', case when not tc.hidden then (tc.rule ->> 'n')::int end) order by tc.sort)
      from public.world_title_catalog tc left join public.world_character_titles ct on ct.owner_id = uid and ct.title_key = tc.title_key
      where tc.active and tc.category = '도감' and tc.rule ->> 'codex' <> 'gather'));
end $$;
alter function public.world_monster_codex_snapshot() owner to fn_owner_field;
revoke all on function public.world_monster_codex_snapshot() from public, anon, authenticated;
grant execute on function public.world_monster_codex_snapshot() to authenticated;

-- 채집 도감: 채집터에서 나는 재료(지금 32가지). 거둔 것은 이름·설명·나는 곳·거둔 횟수, 아직은 분류와 레벨만.
create or replace function public.world_gather_codex_snapshot()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object(
    'items', (with it as (
        select x as item_id, min(s.category) as cat, min(s.min_level) as lv,
          (select jsonb_agg(z.n order by z.l) from (select distinct r2.region_name as n, coalesce(r2.min_level, 1) as l from public.world_gathering_spots s2
             join public.world_exploration_nodes n2 on n2.node_id = s2.node_id join public.world_map_regions r2 on r2.region_id = n2.region_id
            where s2.active and x = any (s2.loot_items) order by 2 limit 6) z) as regions
          from public.world_gathering_spots s, unnest(s.loot_items) x where s.active group by x),
      got as (select e.payload ->> 'item_id' as item_id, count(*) as n, sum(coalesce((e.payload ->> 'qty')::int, 1)) as q
          from public.world_events e where e.actor_id = uid and e.event_type = 'gather' and e.payload ? 'item_id' group by 1)
      select jsonb_agg(case when g.item_id is null then jsonb_build_object('known', false, 'cat', it.cat, 'level', it.lv)
          else jsonb_build_object('known', true, 'id', it.item_id, 'name', coalesce(ic.item_name, it.item_id), 'desc', ic.description, 'cat', it.cat, 'level', it.lv,
            'regions', it.regions, 'count', g.n, 'qty', g.q) end order by it.cat, it.lv, it.item_id)
        from it left join got g on g.item_id = it.item_id left join public.world_item_catalog ic on ic.item_id = it.item_id),
    'titles', (select jsonb_agg(jsonb_build_object('name', tc.title_name, 'condition', tc.condition_text, 'earned', ct.title_key is not null,
        'progress', public.world_codex_rule_count(uid, tc.rule), 'need', (tc.rule ->> 'n')::int) order by tc.sort)
      from public.world_title_catalog tc left join public.world_character_titles ct on ct.owner_id = uid and ct.title_key = tc.title_key
      where tc.active and tc.rule ->> 'codex' = 'gather'));
end $$;
alter function public.world_gather_codex_snapshot() owner to fn_owner_field;
revoke all on function public.world_gather_codex_snapshot() from public, anon, authenticated;
grant execute on function public.world_gather_codex_snapshot() to authenticated;
grant select on public.world_gathering_spots, public.world_exploration_nodes, public.world_map_regions, public.world_item_catalog, public.world_events,
  public.world_title_catalog, public.world_character_titles, public.world_status_catalog to fn_owner_field;
grant execute on function public.world_gimmick_tip(text), public.world_codex_rule_count(uuid, jsonb) to fn_owner_field;

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
  p_allies jsonb, p_power float8, p_pres float8, p_base timestamptz, p_seq int, p_job text, p_wtype text, p_guard int, p_ctx jsonb default '{}'::jsonb)
returns jsonb language plpgsql volatile security definer set search_path to 'pg_catalog', 'public' as $$
declare
  foes jsonb := jsonb_build_array(p_foe); nf int; fhp int[]; a_n int; b_n int; t int; i int; seq int := p_seq; lines jsonb := '[]'::jsonb;
  dealt int; hits int[]; w float8[]; wsum float8; acc int; hi int := 0; ei int := 0; tgt int; carry int; nm text; mech text;
  who_n text; who_o uuid; pick float8; al jsonb; tot_w float8; nal int := coalesce(jsonb_array_length(p_allies), 0);
  etype text[]; parts int[]; left_d int; part int; taken int := 0; skill_at int; txt text; blk float8; told text[] := '{}'; kind_ text;
  vm text[]; va text[]; vh text[]; sk text;
  g public.world_monster_gimmicks%rowtype; mlv int := coalesce((p_ctx ->> 'mlv')::int, 1); gt int; gch float8; cn text[]; gx int; gml int := 0; ger int := 0;
  gbest text; gjob text;
begin
  if p_extra > 0 then
    foes := foes || coalesce((select jsonb_agg(jsonb_build_object('n', x.monster_name, 'mech', x.mechanic_key, 'role', x.role, 'id', x.monster_id, 'kind', x.kind))
      from (select monster_name, mechanic_key, role, monster_id, kind from public.world_region_monsters where region_id = p_region and role <> 'guardian' order by random() limit p_extra) x), '[]'::jsonb);
  end if;
  nf := jsonb_array_length(foes);
  -- 요괴 도감: 만난 요괴(이기면 쓰러뜨린 요괴)로 적는다
  perform public.world_codex_mark(p_owner, x ->> 'id', 1, case when p_won then 1 else 0 end) from jsonb_array_elements(foes) x where x ? 'id';
  gt := public.world_monster_tier(mlv);
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
    -- 요괴 기믹(Lv10부터): 두 번째 합에 한 번. 기술 단계·레벨 차·능력치로 대처하고, 상성 무기나 직업이면 더 잘 대처한다
    if t = 2 and gt >= 2 and p_foe ? 'kind' then
      select * into g from public.world_monster_gimmicks where kind_key = p_foe ->> 'kind' and tier between 2 and gt order by random() limit 1;
      if g.gimmick_key is not null and random() < (case gt when 2 then 0.55 else 0.75 end) then
        cn := public.world_gimmick_counter(g.gtype);
        gch := 35 + (coalesce((p_ctx -> 'sp' -> cn[1] ->> 'rank')::int, 1) - case g.tier when 2 then 15 else 30 end) * 1.5
          + (coalesce((p_ctx ->> 'lv')::int, 1) - mlv) * 2 + coalesce((p_ctx -> 'st' ->> cn[2])::int, 0) * 0.3;
        gch := greatest(10, least(75, gch));
        select case when greatest(k.melee, k.ranged, k.magic) <= 1 then null when k.ranged >= greatest(k.melee, k.magic) then 'ranged' when k.magic >= k.melee then 'magic' else 'melee' end, k.job_key
          into gbest, gjob from public.world_monster_kinds k where k.kind_key = g.kind_key;
        if p_wtype = gbest or p_job = gjob then gch := gch + 25; end if;
        nm := p_foe ->> 'n';
        seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'foe', 'who', p_me, 'owner', p_owner, 'text', nm || ' · 「' || g.name || '」 ' || g.tell);
        if random() * 100 < gch then
          txt := case g.gtype when 'big' then '[막기] 「' || g.name || '」을(를) 받아 흘렸습니다'
            when 'charge' then '[끊기] 기를 모으는 틈을 파고들어 「' || g.name || '」을(를) 끊었습니다'
            when 'status' then '[버티기] 「' || g.name || '」을(를) 견뎌 냈습니다'
            when 'drain' then '[떨치기] 「' || g.name || '」을(를) 떨쳐 냈습니다' when 'grapple' then '[떨치기] 「' || g.name || '」을(를) 뿌리쳤습니다'
            when 'evade' then '[추적] 「' || g.name || '」 속 진짜 몸을 찾아냈습니다' when 'thorns' then '[추적] 가시가 없는 틈을 골라 쳤습니다'
            else '[간파] 「' || g.name || '」의 흐름을 읽어 냈습니다' end;
          seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'guard', 'who', p_me, 'owner', p_owner, 'text', txt, 'value', 0);
        else
          gx := greatest(1, round((2 + mlv * 0.25) * greatest(1, g.power))::int);
          taken := taken + gx; gml := gml + g.mental; ger := ger + g.erosion;
          txt := case g.gtype when 'big' then '「' || g.name || '」에 정통으로 맞았습니다' when 'charge' then '「' || g.name || '」이(가) 터졌습니다'
            when 'status' then '「' || g.name || '」에 휩쓸렸습니다' when 'drain' then '「' || g.name || '」에 기운을 빼앗겼습니다'
            when 'grapple' then '「' || g.name || '」에 붙잡혔습니다' when 'evade' then '「' || g.name || '」에 속아 헛손질했습니다'
            when 'thorns' then '가시에 손을 베였습니다' else '「' || g.name || '」 때문에 공격이 무뎌졌습니다' end
            || ' · 체력 -' || gx || case when g.mental > 0 then ' · 정신 -' || g.mental else '' end || case when g.erosion > 0 then ' · 침식 +' || g.erosion else '' end;
          seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'hurt', 'who', p_me, 'owner', p_owner, 'text', txt, 'value', gx);
        end if;
      end if;
    end if;
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
  return jsonb_build_object('lines', lines, 'seq', seq, 'taken', taken, 'mn', gml, 'er', ger);
end $$;
grant select on public.world_region_monsters to fn_owner_field;
grant insert on public.world_expedition_hits to fn_owner_field;
-- 원정 기믹·도감에 쓰는 표와 함수는 ⑭에서 만든다(함수 안에서만 부르므로 실행 순서는 상관없다)
alter function public.world_exp_fight_story(uuid, text, text, jsonb, int, boolean, int, int, jsonb, float8, float8, timestamptz, int, text, text, int, jsonb) owner to fn_owner_field;
revoke all on function public.world_exp_fight_story(uuid, text, text, jsonb, int, boolean, int, int, jsonb, float8, float8, timestamptz, int, text, text, int, jsonb) from public, anon, authenticated;

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
   fx := public.world_exp_fight_story(e.owner_id, me, r.region_id, jsonb_build_object(''n'', foe, ''mech'', m.mechanic_key, ''role'', m.role, ''id'', m.monster_id, ''kind'', m.kind), nal, won, ehp, dmg, act, power, pres, base_t, seq, c.job_key, wtype, brank,
     jsonb_build_object(''lv'', c.level, ''mlv'', n.min_level + 1, ''sp'', c.skill_progress, ''st'', jsonb_build_object(''agility'', c.agility, ''vitality'', c.vitality, ''willpower'', c.willpower, ''perception'', c.perception)));
   jr := jr || (fx -> ''lines''); seq := (fx ->> ''seq'')::int; my_taken := (fx ->> ''taken'')::int;
   mn := mn - coalesce((fx ->> ''mn'')::int, 0); er := er + coalesce((fx ->> ''er'')::int, 0);
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
  -- 요괴 갈래 상성(⑭ world_kind_mult): 든 무기·직업이 유리하면 위협이 줄고 불리하면 는다(현장보다 완만하게 0.6제곱)
  if (length(d) - length(replace(d, 'spirit_mech := coalesce(m.mechanic_key, '''') in (''spectral'', ''warded'', ''seal_breaker'');', ''))) / length('spirit_mech := coalesce(m.mechanic_key, '''') in (''spectral'', ''warded'', ''seal_breaker'');') <> 1 then raise exception '원정 상성 자리'; end if;
  d := replace(d, 'spirit_mech := coalesce(m.mechanic_key, '''') in (''spectral'', ''warded'', ''seal_breaker'');',
    'spirit_mech := coalesce(m.mechanic_key, '''') in (''spectral'', ''warded'', ''seal_breaker'');
        threat := threat / power(public.world_kind_mult(m.kind, wtype, c.job_key)::float8, 0.6);');
  d := replace(d, '* (1 + 0.3 * nal));', '* (1 + 0.45 * nal));');
  -- 레벨 차 보정(현장 토벌과 같은 식): 원정지 요괴 수준(원정지 최소 레벨 + 1)보다 높으면 받는 피해가 줄어든다
  if (length(d) - length(replace(d, 'dmg := round(dmg * greatest(0.3, 1 + g_inc / 100.0)', ''))) / length('dmg := round(dmg * greatest(0.3, 1 + g_inc / 100.0)') <> 1 then raise exception '원정 레벨 차 자리'; end if;
  d := replace(d, 'dmg := round(dmg * greatest(0.3, 1 + g_inc / 100.0)', 'dmg := round(dmg * greatest(0.7, least(1.3, 1 - 0.03 * (c.level - n.min_level - 1))) * greatest(0.3, 1 + g_inc / 100.0)');
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

-- 현장 화면: 지역 답사도에 따라 정보를 차례로 연다(서버가 가린다). 이미 만난 요괴는 답사도와 상관없이 보인다.
--   출몰 요괴: 갈래만 → 30% 일반 요괴 이름·레벨 → 70% 우두머리 · 얻는 것(lore): 30% 채집 재료 → 70% 요괴 전리품 → 100% 희귀품
do $$ declare d text := pg_get_functiondef('public.world_field_snapshot()'::regprocedure); n int;
  rx text := '''monsters'', \(SELECT coalesce\(jsonb_agg\(jsonb_build_object\(''name'', m\.monster_name.*?FROM public\.world_region_monsters m WHERE m\.region_id = r\.region_id\),';
begin
  if position('''lore''' in d) > 0 then return; end if;
  select count(*) into n from regexp_matches(d, rx, 'g');
  if n <> 1 then raise exception '현장 요괴 목록 고칠 자리(%)', n; end if;
  d := regexp_replace(d, rx, $R$'monsters', (SELECT coalesce(jsonb_agg(CASE WHEN x.owner_id IS NOT NULL OR sv.p >= (CASE WHEN m.role = 'guardian' THEN 70 ELSE 30 END)
        THEN jsonb_build_object('name', m.monster_name, 'type', m.monster_type, 'mechanic', m.mechanic_key, 'kind', m.kind, 'kind_name', k.kind_name, 'role', m.role,
          'min_level', m.min_level, 'max_level', m.max_level, 'revealed', true)
        ELSE jsonb_build_object('name', '???', 'kind_name', k.kind_name, 'role', m.role, 'revealed', false, 'need', CASE WHEN m.role = 'guardian' THEN 70 ELSE 30 END) END
        ORDER BY m.role DESC, m.min_level), '[]'::jsonb)
      FROM public.world_region_monsters m LEFT JOIN public.world_monster_kinds k ON k.kind_key = m.kind
      LEFT JOIN public.world_monster_codex x ON x.owner_id = uid AND x.monster_id = m.monster_id
      CROSS JOIN (SELECT coalesce((public.world_field_survey(uid, r.region_id) ->> 'pct')::int, 0) AS p) sv
      WHERE m.region_id = r.region_id),
    'lore', (SELECT jsonb_build_object('pct', sv.p,
        'gather', CASE WHEN sv.p >= 30 THEN (SELECT coalesce(jsonb_agg(DISTINCT li), '[]'::jsonb) FROM public.world_gathering_spots gs JOIN public.world_exploration_nodes gn ON gn.node_id = gs.node_id, unnest(gs.loot_items) li WHERE gn.region_id = r.region_id AND gs.active) END,
        'drops', CASE WHEN sv.p >= 70 THEN (SELECT coalesce(jsonb_agg(DISTINCT dd.key), '[]'::jsonb) FROM public.world_region_monsters dm, jsonb_each(coalesce(dm.drops, '{}'::jsonb)) dd WHERE dm.region_id = r.region_id) END,
        'rare', CASE WHEN sv.p >= 100 THEN (SELECT coalesce(jsonb_agg(si), '[]'::jsonb) FROM public.world_region_profiles rp, unnest(rp.signature_items) si WHERE rp.region_id = r.region_id AND si NOT IN ('courier_token', 'spirit_compass')) END)
      FROM (SELECT coalesce((public.world_field_survey(uid, r.region_id) ->> 'pct')::int, 0) AS p) sv),$R$);
  execute d;
end $$;
grant select on public.world_region_profiles to fn_owner_field;
-- 닳은 장비 알림: 내구도가 4분의 1 아래인 장착 장비(부서진 것 포함)를 현장 화면에 알린다
do $$ declare d text := pg_get_functiondef('public.world_field_snapshot()'::regprocedure);
  a text := '''weapon'', coalesce(weapon,';
  b text := '''gear_warn'', (SELECT coalesce(jsonb_agg(jsonb_build_object(''slot'', ge.slot, ''name'', gi.item_name, ''dur'', gd.durability, ''max'', public.world_item_max_durability(ge.item_id))), ''[]''::jsonb)
      FROM public.world_character_equipment ge JOIN public.world_item_catalog gi ON gi.item_id = ge.item_id
      JOIN public.world_item_durability gd ON gd.owner_id = ge.owner_id AND gd.item_id = ge.item_id
      WHERE ge.owner_id = uid AND gd.durability * 4 < public.world_item_max_durability(ge.item_id)),
    ''weapon'', coalesce(weapon,';
begin
  if position('''gear_warn''' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '현장 장비 알림 자리'; end if;
  execute replace(d, a, b);
end $$;
grant select on public.world_item_durability to fn_owner_field;

-- ⑮ ─────────────────────────────────────────
-- 운영진 칭호: 운영진(world_staff)만 가진다. 능력치 효과는 없고, 다른 조사원의 칭호 목록에는 나오지 않는다(분류 '운영').
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
  ('gm_staff', '야행국 운영진', 'shield', '야행국을 돌보는 운영진입니다.', '운영진만 가집니다', '{}', true, true, null, 200, '운영', 5)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text,
  bonus = excluded.bonus, active = excluded.active, hidden = excluded.hidden, rule = excluded.rule, sort = excluded.sort, category = excluded.category, grade = excluded.grade;
insert into public.world_character_titles(owner_id, title_key)
select s.owner_id, 'gm_staff' from public.world_staff s join public.world_characters c on c.owner_id = s.owner_id
on conflict do nothing;
do $$ declare d text := pg_get_functiondef('public.world_title_snapshot()'::regprocedure);
  a text := '  where tc.active;'; b text := '  where tc.active and (tc.category is distinct from ''운영'' or ct.owner_id is not null);';
begin
  if position(b in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '칭호 목록 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;

-- ⑯ ─────────────────────────────────────────
-- 전체 채팅 하루 20회 → 50회
do $$ declare d text := pg_get_functiondef('public.world_chat_send(text,text,text)'::regprocedure);
  a text := 'if day_count>=20 then raise exception ''전체 채팅은 하루 20회까지 보낼 수 있어요.''; end if;';
  b text := 'if day_count>=50 then raise exception ''전체 채팅은 하루 50회까지 보낼 수 있어요.''; end if;';
begin
  if position(b in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '전체 채팅 한도 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;

-- 칭호 묶음(프리셋): 처음 3칸, 얻기 어려운데 효과가 약했던 칭호 셋(믿음직한 해결사 의뢰 50건 · 대지의 손 채집 500회 · 공방의 주인 제작 200회)을 얻을 때마다 한 칸씩(최대 6칸).
--   지금 장착한 칭호(최대 3)와 대표 칭호를 이름 붙여 저장하고, 한 번에 바꿔 낀다.
create table if not exists public.world_title_presets (
  owner_id uuid not null, slot int not null check (slot between 1 and 6), name text not null,
  titles text[] not null default '{}', display text, updated_at timestamptz not null default now(),
  primary key (owner_id, slot));
alter table public.world_title_presets enable row level security;
revoke all on public.world_title_presets from public, anon, authenticated;
grant select, insert, update, delete on public.world_title_presets to fn_owner_field;
grant update (is_equipped) on public.world_character_titles to fn_owner_field;
create or replace function public.world_title_preset_slots(p_owner uuid) returns int language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select 3 + (select count(*)::int from public.world_character_titles where owner_id = p_owner and title_key in ('commission_50', 'gather_500', 'craft_200'))
$$;
alter function public.world_title_preset_slots(uuid) owner to fn_owner_field;
revoke all on function public.world_title_preset_slots(uuid) from public, anon, authenticated;
update public.world_title_catalog set description = description || ' 칭호 묶음 한 칸이 늘어납니다.'
 where title_key in ('commission_50', 'gather_500', 'craft_200') and description not like '%칭호 묶음%';

create or replace function public.world_title_preset_save(p_slot int, p_name text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); nm text := left(btrim(coalesce(p_name, '')), 12); t text[]; disp text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_slot < 1 or p_slot > public.world_title_preset_slots(uid) then raise exception '아직 열리지 않은 묶음 칸입니다.'; end if;
  if nm = '' then nm := '묶음 ' || p_slot; end if;
  select profile ->> 'title' into disp from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select coalesce(array_agg(title_key order by earned_at, title_key), '{}') into t from public.world_character_titles where owner_id = uid and is_equipped;
  if cardinality(t) = 0 and disp is null then raise exception '장착한 칭호나 대표 칭호가 있어야 저장할 수 있습니다.'; end if;
  insert into public.world_title_presets(owner_id, slot, name, titles, display) values (uid, p_slot, nm, t, disp)
  on conflict (owner_id, slot) do update set name = excluded.name, titles = excluded.titles, display = excluded.display, updated_at = now();
  return jsonb_build_object('ok', true, 'content', '「' || nm || '」에 지금 칭호를 저장했습니다.');
end $$;

create or replace function public.world_title_preset_apply(p_slot int)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); pr public.world_title_presets%rowtype; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform 1 from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select * into pr from public.world_title_presets where owner_id = uid and slot = p_slot;
  if not found then raise exception '저장된 묶음이 없습니다.'; end if;
  update public.world_character_titles set is_equipped = (title_key = any (pr.titles[1:3])) where owner_id = uid and (is_equipped or title_key = any (pr.titles[1:3]));
  if pr.display is not null then
    select tc.title_name into nm from public.world_character_titles ct join public.world_title_catalog tc using (title_key) where ct.owner_id = uid and ct.title_key = pr.display;
  end if;
  update public.world_characters set profile = case when nm is null then coalesce(profile, '{}'::jsonb) - 'title' - 'title_name'
      else coalesce(profile, '{}'::jsonb) || jsonb_build_object('title', pr.display, 'title_name', nm) end, updated_at = now()
   where owner_id = uid;
  return jsonb_build_object('ok', true, 'content', '「' || pr.name || '」 묶음으로 바꿨습니다.');
end $$;

create or replace function public.world_title_preset_clear(p_slot int)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  delete from public.world_title_presets where owner_id = uid and slot = p_slot;
  return jsonb_build_object('ok', true, 'content', '묶음을 비웠습니다.');
end $$;
do $$ declare f text; begin
  foreach f in array array['public.world_title_preset_save(int, text)', 'public.world_title_preset_apply(int)', 'public.world_title_preset_clear(int)'] loop
    execute format('alter function %s owner to fn_owner_field', f);
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
-- 칭호 화면이 한 번에 받도록 묶음 목록을 world_title_snapshot에 싣는다
do $$ declare d text := pg_get_functiondef('public.world_title_snapshot()'::regprocedure);
  a text := '''max_equipped'', 3, ''display'', disp,';
  b text := '''max_equipped'', 3, ''display'', disp, ''preset_slots'', public.world_title_preset_slots(uid),
    ''preset_unlocks'', (select jsonb_agg(jsonb_build_object(''name'', tc.title_name, ''condition'', tc.condition_text, ''earned'', exists (select 1 from public.world_character_titles x where x.owner_id = uid and x.title_key = tc.title_key)) order by tc.sort) from public.world_title_catalog tc where tc.title_key in (''commission_50'', ''gather_500'', ''craft_200'')),
    ''presets'', (select coalesce(jsonb_agg(jsonb_build_object(''slot'', p.slot, ''name'', p.name, ''titles'', p.titles, ''display'', p.display) order by p.slot), ''[]''::jsonb) from public.world_title_presets p where p.owner_id = uid),';
begin
  if position('''presets''' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '칭호 목록 묶음 자리'; end if;
  execute replace(d, a, b);
end $$;

-- ⑰ ─────────────────────────────────────────
-- 소속 효과: 생성 때 고른 소속(faction_key)마다 전투·생활·탐사·이동·경제에 나눠 실제 효과를 준다(world_status_effect_total에 더함).
--   본부 직속 제작 품질 +4 · 회복량 +5% · 상점 판매 한도 +500전 / 현장대응국 채집량 +6% · 이동 시간 −6% · 요괴 조우 −5%
--   기록감찰국 단서 +8% · 희귀품 +3% · 주는 피해 +2% / 봉인관리국 정신 손실 −10% · 침식 −8% · 주는 피해 +3%
--   의무지원국 회복량 +10% · 받는 피해 −4% · 채집량 +3% / 외부 협력자 이동 시간 −5% · 희귀품 +2% · 상점 판매 수수료 5% → 3%
create or replace function public.world_affil_effect(p_key text) returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select case c.faction_key
    when 'headquarters' then case p_key when 'craft_quality' then 4 when 'healing_pct' then 5 end
    when 'fieldbureau' then case p_key when 'gather_qty_pct' then 6 when 'travel_time_pct' then -6 when 'encounter_pct' then -5 end
    when 'archivebureau' then case p_key when 'clue_bonus_pct' then 8 when 'rare_loot_pct' then 3 when 'combat_damage_pct' then 2 end
    when 'sealbureau' then case p_key when 'mental_loss_pct' then -10 when 'erosion_pct' then -8 when 'combat_damage_pct' then 3 end
    when 'medicalbureau' then case p_key when 'healing_pct' then 10 when 'incoming_damage_pct' then -4 when 'gather_qty_pct' then 3 end
    when 'independent' then case p_key when 'travel_time_pct' then -5 when 'rare_loot_pct' then 2 end
    end from public.world_characters c where c.owner_id = public.fn_owner_auth_uid()), 0)::numeric
$$;
alter function public.world_affil_effect(text) owner to fn_owner_field;
revoke all on function public.world_affil_effect(text) from public, anon, authenticated;
do $$ declare r text; begin
  for r in select rolname from pg_roles where rolname like 'fn\_owner\_%' loop
    execute format('grant execute on function public.world_affil_effect(text) to %I', r);
  end loop;
end $$;
grant execute on function public.world_affil_effect(text) to authenticated;
do $$ declare d text := pg_get_functiondef('public.world_status_effect_total(text)'::regprocedure);
  a text := '+ public.world_skill_effect(p_effect_key)';
begin
  if d like '%world_affil_effect%' then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception 'status_effect_total 소속 자리'; end if;
  execute replace(d, a, a || ' + public.world_affil_effect(p_effect_key)');
end $$;
create or replace function public.world_affil_cap() returns int language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case when (select faction_key from public.world_characters where owner_id = public.fn_owner_auth_uid()) = 'headquarters' then 500 else 0 end
$$;
create or replace function public.world_affil_tax() returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case when (select faction_key from public.world_characters where owner_id = public.fn_owner_auth_uid()) = 'independent' then 0.03 else 0.05 end
$$;
do $$ declare r text; begin
  for r in select rolname from pg_roles where rolname like 'fn\_owner\_%' loop
    execute format('grant execute on function public.world_affil_cap(), public.world_affil_tax() to %I', r);
  end loop;
end $$;
alter function public.world_affil_cap() owner to fn_owner_field;
alter function public.world_affil_tax() owner to fn_owner_field;
revoke all on function public.world_affil_cap() from public, anon, authenticated;
revoke all on function public.world_affil_tax() from public, anon, authenticated;
-- 경제: 본부 직속 판매 한도 +500전, 외부 협력자 판매 수수료 3%
do $$ declare d text; f text;
begin
  foreach f in array array['public.world_shop_sell_status()', 'public.world_shop_sell(text,integer)'] loop
    d := pg_get_functiondef(f::regprocedure);
    if position('world_affil_cap' in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, 'cap := 2000;', ''))) / length('cap := 2000;') <> 1 then raise exception '판매 한도 자리: %', f; end if;
    d := replace(d, 'cap := 2000;', 'cap := 2000 + public.world_affil_cap();');
    d := replace(d, 'tax := greatest(1, round(price * p_qty * 0.05)::bigint);', 'tax := greatest(1, round(price * p_qty * public.world_affil_tax())::bigint);');
    execute d;
  end loop;
end $$;

grant fn_owner_social to postgres with inherit false, set false;
grant fn_owner_18666 to postgres with inherit false, set false;
grant fn_owner_18944 to postgres with inherit false, set false;
grant fn_owner_18989 to postgres with inherit false, set false;
grant fn_owner_field to postgres with inherit false, set false;
grant fn_owner_expedition to postgres with inherit false, set false;
grant fn_owner_18452 to postgres with inherit false, set false;
grant fn_owner_18987 to postgres with inherit false, set false;
grant fn_owner_18475 to postgres with inherit false, set false;
grant fn_owner_19141 to postgres with inherit false, set false;
grant fn_owner_18878 to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261029050000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
