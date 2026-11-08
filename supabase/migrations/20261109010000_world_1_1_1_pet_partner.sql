CREATE OR REPLACE FUNCTION public.world_pet_act(p_owner uuid, p_act text, p_item text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); h public.world_housing%rowtype; pt public.world_pets%rowtype; sp public.world_pet_species%rowtype; why text;
  today date := public.world_housing_today(); gain int := 0; react text := 'heart'; c public.world_characters%rowtype; have int; was_adult boolean; g public.world_pet_guest%rowtype; nm text; vn text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_act not in ('pat', 'play', 'feed') then raise exception '알 수 없는 놀이입니다.'; end if;
  select * into h from public.world_housing where owner_id = p_owner;
  if not found or h.pet_id is null then raise exception '이 별채에는 동무가 없습니다.'; end if;
  if h.pet_out then raise exception '동무가 주인과 함께 나가 있습니다.'; end if;
  why := public.world_housing_can_view(uid, p_owner, h.gate);
  if why is not null then raise exception '%', why; end if;
  select * into pt from public.world_pets where owner_id = p_owner and pet_id = h.pet_id for update;
  select * into sp from public.world_pet_species where pet_id = h.pet_id;
  nm := coalesce(pt.nickname, sp.pet_name); was_adult := pt.affinity >= 100;
  if uid = p_owner or public.world_housing_married(uid, p_owner) then
    if p_act = 'pat' then
      if pt.pat_day is distinct from today then pt.pat_n := 0; end if;
      pt.pat_n := pt.pat_n + 1; pt.pat_day := today; gain := case when pt.pat_n <= 5 then 2 else 0 end;
    elsif p_act = 'play' then
      if pt.play_day is distinct from today then pt.play_n := 0; end if;
      pt.play_n := pt.play_n + 1; pt.play_day := today; gain := case when pt.play_n <= 3 then 3 else 0 end; react := 'note';
    else
      if p_item is null or (p_item <> 'pet_food' and p_item not like 'treat\_%') then raise exception '동무 먹이를 골라 주세요.'; end if;
      if pt.feed_day is distinct from today then pt.feed_n := 0; end if;
      if pt.feed_n >= 3 then raise exception '%은(는) 오늘 배가 불러 더 먹지 않습니다.', nm; end if;
      select * into c from public.world_characters where owner_id = uid for update;
      have := coalesce((c.inventory ->> p_item)::int, 0);
      if have < 1 then raise exception '가방에 그 먹이가 없습니다.'; end if;
      update public.world_characters set inventory = case when have - 1 <= 0 then inventory - p_item else jsonb_set(inventory, array[p_item], to_jsonb(have - 1)) end, updated_at = now() where owner_id = uid;
      pt.feed_n := pt.feed_n + 1; pt.feed_day := today;
      gain := case when p_item = sp.likes then 12 when p_item = 'pet_food' then 4 else 6 end; react := case when p_item = sp.likes then 'star' else 'bowl' end;
    end if;
  else
    if p_act = 'feed' then raise exception '먹이는 주인만 줄 수 있습니다.'; end if;
    insert into public.world_pet_guest(owner_id, visitor_id, day) values (p_owner, uid, today) on conflict do nothing;
    select * into g from public.world_pet_guest where owner_id = p_owner and visitor_id = uid and day = today for update;
    if (p_act = 'pat' and g.pat) or (p_act = 'play' and g.play) then raise exception '오늘은 이미 %. 내일 또 와 주세요.', case when p_act = 'pat' then '쓰다듬어 주었습니다' else '놀아 주었습니다' end; end if;
    update public.world_pet_guest set pat = pat or p_act = 'pat', play = play or p_act = 'play' where owner_id = p_owner and visitor_id = uid and day = today;
    gain := 1; react := case when p_act = 'play' then 'note' else 'heart' end;
    if not g.pat and not g.play then
      select character_name into vn from public.world_characters where owner_id = uid;
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (p_owner, 'pet_play', '별채의 동무', vn || '님이 ' || case when p_act = 'pat' then public.world_josa(nm, '을', '를') || ' 쓰다듬어 주었습니다.' else public.world_josa(nm, '과', '와') || ' 놀아 주었습니다.' end, jsonb_build_object('visitor', uid));
    end if;
  end if;
  if p_act <> 'feed' and coalesce((public.world_pet_mess_of(p_owner, h.pet_id) ->> 'sick')::boolean, false) then gain := 0; react := 'sick'; end if;
  pt.affinity := least(300, pt.affinity + gain);
  update public.world_pets set affinity = pt.affinity, pat_day = pt.pat_day, pat_n = pt.pat_n, play_day = pt.play_day, play_n = pt.play_n, feed_day = pt.feed_day, feed_n = pt.feed_n
   where owner_id = p_owner and pet_id = h.pet_id;
  if not was_adult and pt.affinity >= 100 then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_owner, 'pet_new', '꼬마 동무가 자랐습니다', public.world_josa(nm, '이', '가') || ' 훌쩍 자랐습니다.', jsonb_build_object('pet_id', h.pet_id));
    perform public.world_title_award_check(p_owner, 'home');
  end if;
  return jsonb_build_object('ok', true, 'affinity', pt.affinity, 'gain', gain, 'adult', public.world_pet_look_adult(pt.affinity, pt.baby_look), 'grown', pt.affinity >= 100, 'grew', not was_adult and pt.affinity >= 100, 'react', react,
    'counts', case when uid = p_owner or public.world_housing_married(uid, p_owner) then jsonb_build_object('pat', pt.pat_n, 'play', pt.play_n, 'feed', pt.feed_n) end);
end $function$;

update public.world_patch_notes set body = body || E'\n- 혼례를 올린 정인은 서로의 별채 꼬마 동무를 주인처럼 돌볼 수 있습니다(쓰다듬기·놀기·먹이, 하루 횟수는 주인과 함께 씁니다).\n- 별채 곳간 창을 PC는 곳간·가방 두 칸으로, 휴대폰은 탭으로 나눠 가구가 많아도 덜 길게 보이게 했습니다.\n- 창고 꺼내기 목록도 가방처럼 「칸대로 나눠 보기」로 볼 수 있습니다.\n- 도움말 전투 항목에 치명타율(60%)·회피율(40%)·달아날 확률(95%) 상한을 적었습니다.'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109010000' where key = 'db_version';
