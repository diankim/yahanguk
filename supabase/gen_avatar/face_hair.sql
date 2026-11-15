create or replace function pg_temp.yh_fix2(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); n int;
begin
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'yh_fix2 %: 조각이 % 번 있음', p_fn, n; end if;
  execute replace(src, p_old, p_new);
end $f$;

alter table public.world_outfit_designs drop constraint world_outfit_designs_slot_check;
alter table public.world_outfit_designs add constraint world_outfit_designs_slot_check check (slot in ('top', 'bottom', 'face', 'hair'));
alter table public.world_outfit_designs drop constraint world_outfit_designs_pal_check;
alter table public.world_outfit_designs add constraint world_outfit_designs_pal_check check (pal ~ '^([0-9a-f]{6}){1,16}$');
alter table public.world_outfit_designs drop constraint world_outfit_designs_px_check;
alter table public.world_outfit_designs add constraint world_outfit_designs_px_check check (px ~ '^[0-9a-f.]+$');

create or replace function public.world_avatar_parts()
 returns jsonb language sql immutable
as $f$ select '@PARTS@'::jsonb $f$;

create or replace function public.world_outfit_rules()
 returns jsonb language sql immutable
as $f$ select '{"box_exp_pct": 2, "box_boss_pct": 1, "box": "of_bundle", "pool": ["of_top_vest", "of_top_jeoksam", "of_acc_scarf", "of_top_jeogori", "of_bottom_chima", "of_acc_norigae", "of_top_magoja", "of_acc_earring", "of_acc_glasses", "of_top_guard", "of_bottom_guard", "of_top_scout", "of_bottom_scout", "of_top_exorcist", "of_bottom_exorcist", "of_top_medic", "of_bottom_medic", "of_top_seal", "of_bottom_seal", "of_top_shadow", "of_bottom_shadow", "of_top_tamer", "of_bottom_tamer"], "tourney": "acc:foxmask", "design": {"per_day": 2, "keep": 20, "colors": 8, "title_max": 12, "weave": {"top": "r_of_jeogori", "bottom": "r_of_chima"}, "face": {"keep": 3, "colors": 8}, "hair": {"keep": 10, "colors": 16, "item": "hair_pattern"}}}'::jsonb $f$;

insert into public.world_item_catalog (item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
values ('hair_pattern', '머리 그리기 도안', 'consumable', 4,
  '비장고 깊은 곳에서 나온, 빈 머리 모양이 먹선으로만 그려진 도안. 가방에서 펼치면 머리 모양과 색을 마음대로 그려 도안첩에 담고, 내 모습에서 바로 쓸 수 있다. 한 번 그리면 사라진다.',
  true, '{}'::jsonb, 1, '{"hair_pattern": true}'::jsonb, true, 1500, 20)
on conflict (item_id) do nothing;

select pg_temp.yh_fix2('public.world_bijang_rules()'::regprocedure,
  $o$jsonb_build_object('id', 'hf_bj_map_frame', 'w', 2, 'n', 1))),$o$,
  $n$jsonb_build_object('id', 'hf_bj_map_frame', 'w', 2, 'n', 1), jsonb_build_object('id', 'hair_pattern', 'w', 4, 'n', 1))),$n$);
select pg_temp.yh_fix2('public.world_bijang_rules()'::regprocedure,
  $o$jsonb_build_object('id', 'blank_hanji', 'w', 2), jsonb_build_object('id', 'meokbi_ebony', 'w', 2), jsonb_build_object('id', 'spirit_core', 'w', 1),$o$,
  $n$jsonb_build_object('id', 'blank_hanji', 'w', 2), jsonb_build_object('id', 'meokbi_ebony', 'w', 2), jsonb_build_object('id', 'spirit_core', 'w', 1), jsonb_build_object('id', 'hair_pattern', 'w', 1),$n$);
select pg_temp.yh_fix2('public.world_bijang_rules()'::regprocedure,
  $o$jsonb_build_object('id', 'yoin_blood', 'w', 2), jsonb_build_object('id', 'gwiheo_pearl', 'w', 1), jsonb_build_object('id', 'spirit_core', 'w', 1),$o$,
  $n$jsonb_build_object('id', 'yoin_blood', 'w', 2), jsonb_build_object('id', 'gwiheo_pearl', 'w', 1), jsonb_build_object('id', 'spirit_core', 'w', 1), jsonb_build_object('id', 'hair_pattern', 'w', 2),$n$);

create or replace function public.world_avatar_design_ids(p_look jsonb)
 returns bigint[] language sql immutable
as $f$ select array_remove(array[
  case when p_look ->> 'top_d' ~ '^[0-9]{1,18}$' then (p_look ->> 'top_d')::bigint end,
  case when p_look ->> 'bottom_d' ~ '^[0-9]{1,18}$' then (p_look ->> 'bottom_d')::bigint end,
  case when p_look ->> 'face_d' ~ '^[0-9]{1,18}$' then (p_look ->> 'face_d')::bigint end,
  case when p_look ->> 'hair_d' ~ '^[0-9]{1,18}$' then (p_look ->> 'hair_d')::bigint end], null) $f$;

select pg_temp.yh_fix2('public.world_avatar_look_clean(uuid,jsonb)'::regprocedure,
  $o$    l := case when did is null then l - (k || '_d') else l || jsonb_build_object(k || '_d', did) end;
  end loop;$o$,
  $n$    l := case when did is null then l - (k || '_d') else l || jsonb_build_object(k || '_d', did) end;
  end loop;
  foreach k in array array['face', 'hair'] loop
    dv := l ->> (k || '_d');
    if dv is null then continue; end if;
    did := null;
    if dv ~ '^[0-9]{1,18}$' then
      select x.id into did from public.world_outfit_designs x
       where x.id = dv::bigint and x.owner_id = p_owner and x.slot = k and x.deleted_at is null and x.removed_at is null;
    end if;
    l := case when did is null then l - (k || '_d') else l || jsonb_build_object(k || '_d', did) end;
  end loop;
  foreach k in array array['skin_c', 'hair_c', 'eye_c'] loop
    if l ? k and coalesce(l ->> k, '') !~ '^[0-9a-f]{6}$' then l := l - k; end if;
  end loop;$n$);

select pg_temp.yh_fix2('public.world_outfit_design_map(uuid,bigint[])'::regprocedure,
  $o$   where d.id = any (p_ids) and d.woven_at is not null and d.removed_at is null$o$,
  $n$   where d.id = any (p_ids) and d.woven_at is not null and d.removed_at is null and (d.slot in ('top', 'bottom') or d.deleted_at is null)$n$);

select pg_temp.yh_fix2('public.world_avatar_get(uuid)'::regprocedure,
  $o$      from public.world_wardrobe w where w.owner_id = uid and w.look_key ~ '^(top|bottom):@[0-9]{1,18}$'), '{}'::bigint[])));$o$,
  $n$      from public.world_wardrobe w where w.owner_id = uid and w.look_key ~ '^(top|bottom):@[0-9]{1,18}$'), '{}'::bigint[])
      || coalesce((select array_agg(x.id) from public.world_outfit_designs x where x.owner_id = uid and x.slot in ('face', 'hair') and x.deleted_at is null and x.removed_at is null), '{}'::bigint[])));$n$);

select pg_temp.yh_fix2('public.world_avatar_set(jsonb,boolean)'::regprocedure,
  $o$  v := coalesce(p_look ->> 'acc', '');$o$,
  $n$  foreach k in array array['face', 'hair'] loop
    dv := p_look ->> (k || '_d');
    if dv is null or dv = '' then continue; end if;
    if dv !~ '^[0-9]{1,18}$' then raise exception '도안 번호가 올바르지 않습니다.'; end if;
    if not exists (select 1 from public.world_outfit_designs x where x.id = dv::bigint and x.owner_id = uid and x.slot = k and x.deleted_at is null and x.removed_at is null) then
      raise exception '도안첩에 있는 % 도안만 쓸 수 있습니다.', case k when 'face' then '얼굴' else '머리' end; end if;
    look := look || jsonb_build_object(k || '_d', dv::bigint);
  end loop;
  foreach k in array array['skin_c', 'hair_c', 'eye_c'] loop
    v := lower(replace(coalesce(p_look ->> k, ''), '#', ''));
    if v = '' then continue; end if;
    if v !~ '^[0-9a-f]{6}$' then raise exception '고른 색이 올바르지 않습니다.'; end if;
    look := look || jsonb_build_object(k, v);
  end loop;
  v := coalesce(p_look ->> 'acc', '');$n$);

select pg_temp.yh_fix2('public.world_outfit_design_save(text,text,text,text,text,text)'::regprocedure,
  $o$  if p_slot is null or p_slot not in ('top', 'bottom') then raise exception '도안을 그릴 옷을 고르세요.'; end if;$o$,
  $n$  if p_slot in ('face', 'hair') then
    m := parts -> p_slot;
    pal := lower(replace(coalesce(p_pal, ''), '#', ''));
    if pal !~ '^([0-9a-f]{6}){1,16}$' or length(pal) / 6 > (r -> p_slot ->> 'colors')::int then raise exception '색이 올바르지 않습니다.'; end if;
    px := coalesce(p_px, '');
    if char_length(px) <> (m ->> 'n')::int or px !~ (case p_slot when 'face' then '^[0-7.]+$' else '^[0-9a-f.]+$' end) then raise exception '도안 칸이 올바르지 않습니다.'; end if;
    if px !~ '[0-9a-f]' then raise exception '한 칸 이상 칠해 주세요.'; end if;
    if exists (select 1 from regexp_matches(px, '[0-9a-f]', 'g') x where ('x' || lpad(x[1], 8, '0'))::bit(32)::int >= length(pal) / 6) then raise exception '고르지 않은 색으로 칠한 칸이 있습니다.'; end if;
    if p_slot = 'hair' and exists (select 1 from generate_series(0, (m ->> 'bh')::int - 1) j, generate_series(0, (m ->> 'bw')::int - 1) i
        where substr(px, ((m ->> 'by')::int + j) * (m ->> 'w')::int + (m ->> 'bx')::int + i + 1, 1) <> '.') then
      raise exception '눈·입 자리는 칠할 수 없습니다.'; end if;
    t := btrim(regexp_replace(coalesce(p_title, ''), '[[:cntrl:]]+', ' ', 'g'));
    if char_length(t) > (r ->> 'title_max')::int then raise exception '도안 이름은 %자까지 쓸 수 있습니다.', r ->> 'title_max'; end if;
    if (select count(*) from public.world_outfit_designs x where x.owner_id = uid and x.slot = p_slot and x.deleted_at is null and x.removed_at is null) >= (r -> p_slot ->> 'keep')::int then
      raise exception '% 도안은 %장까지 둘 수 있습니다. 안 쓰는 도안을 지운 뒤 그려 주세요.', case p_slot when 'face' then '얼굴' else '머리' end, r -> p_slot ->> 'keep'; end if;
    if p_slot = 'hair' then
      perform 1 from public.world_characters c where c.owner_id = uid for update;
      if coalesce((select (c.inventory ->> (r -> 'hair' ->> 'item'))::int from public.world_characters c where c.owner_id = uid), 0) < 1 then
        raise exception '가방에 머리 그리기 도안이 있어야 머리를 그릴 수 있습니다.'; end if;
      update public.world_characters c set inventory = case when (c.inventory ->> (r -> 'hair' ->> 'item'))::int <= 1 then c.inventory - (r -> 'hair' ->> 'item')
        else jsonb_set(c.inventory, array[r -> 'hair' ->> 'item'], to_jsonb((c.inventory ->> (r -> 'hair' ->> 'item'))::int - 1)) end, updated_at = now() where c.owner_id = uid;
    end if;
    nid := null;
    if p_slot = 'face' then
      select x.id into nid from public.world_outfit_designs x where x.owner_id = uid and x.slot = 'face' and x.deleted_at is not null and x.removed_at is null
       order by x.deleted_at limit 1 for update;
    end if;
    if nid is not null then
      execute 'update public.world_outfit_designs set title = $1, pal = $2, px = $3, deleted_at = null, woven_at = now() where id = $4' using t, pal, px, nid;
    else
      insert into public.world_outfit_designs (owner_id, author_id, author_name, slot, base, title, pal, px, deco, woven_at)
      values (uid, uid, nm, p_slot, p_slot, t, pal, px, '', now()) returning id into nid;
    end if;
    return public.world_outfit_design_list() || jsonb_build_object('saved', nid, 'content', case p_slot when 'face' then '얼굴 도안을 담았습니다. 내 모습에서 바로 쓸 수 있습니다.' else '머리 도안을 담았습니다. 머리 그리기 도안 한 장을 썼고, 내 모습에서 바로 쓸 수 있습니다.' end);
  end if;
  if p_slot is null or p_slot not in ('top', 'bottom') then raise exception '도안을 그릴 옷을 고르세요.'; end if;$n$);
select pg_temp.yh_fix2('public.world_outfit_design_save(text,text,text,text,text,text)'::regprocedure,
  $o$x.author_id = uid and x.origin is null and x.created_at >= public.world_drawing_day_start()) >= (r ->> 'per_day')::int$o$,
  $n$x.author_id = uid and x.origin is null and x.slot in ('top', 'bottom') and x.created_at >= public.world_drawing_day_start()) >= (r ->> 'per_day')::int$n$);
select pg_temp.yh_fix2('public.world_outfit_design_save(text,text,text,text,text,text)'::regprocedure,
  $o$x.owner_id = uid and x.deleted_at is null and x.removed_at is null) >= (r ->> 'keep')::int then
    raise exception '도안첩이 가득 찼습니다(%장). 안 쓰는 도안을 지운 뒤 그려 주세요.'$o$,
  $n$x.owner_id = uid and x.slot in ('top', 'bottom') and x.deleted_at is null and x.removed_at is null) >= (r ->> 'keep')::int then
    raise exception '도안첩이 가득 찼습니다(%장). 안 쓰는 도안을 지운 뒤 그려 주세요.'$n$);

select pg_temp.yh_fix2('public.world_outfit_design_list()'::regprocedure,
  $o$      'made_today', (select count(*) from public.world_outfit_designs x where x.author_id = uid and x.origin is null and x.created_at >= day),$o$,
  $n$      'made_today', (select count(*) from public.world_outfit_designs x where x.author_id = uid and x.origin is null and x.slot in ('top', 'bottom') and x.created_at >= day),
      'faces', (select count(*) from mine where slot = 'face' and deleted_at is null),
      'hairs', (select count(*) from mine where slot = 'hair' and deleted_at is null),
      'hair_items', coalesce((select (c.inventory ->> (r -> 'hair' ->> 'item'))::int from public.world_characters c where c.owner_id = uid), 0),$n$);
select pg_temp.yh_fix2('public.world_outfit_design_list()'::regprocedure,
  $o$      'kept', (select count(*) from mine where deleted_at is null),$o$,
  $n$      'kept', (select count(*) from mine where deleted_at is null and slot in ('top', 'bottom')),$n$);

create or replace function public.world_outfit_design_delete(p_id bigint)
 returns jsonb language plpgsql security definer set search_path to ''
as $f$
declare uid uuid := public.fn_owner_auth_uid(); sl text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  update public.world_outfit_designs set deleted_at = now() where id = p_id and owner_id = uid and deleted_at is null and removed_at is null returning slot into sl;
  if sl is null then raise exception '도안을 찾을 수 없습니다.'; end if;
  return public.world_outfit_design_list() || jsonb_build_object('content', case when sl in ('face', 'hair')
    then '도안을 지웠습니다. 쓰던 ' || case sl when 'face' then '얼굴' else '머리' end || '은 처음 고른 모양으로 돌아가고, 지운 도안에서 되살릴 수 있습니다.'
    else '도안을 지웠습니다. 이미 지은 옷은 그대로 입을 수 있고, 지운 도안에서 되살릴 수 있습니다.' end);
end $f$;

select pg_temp.yh_fix2('public.world_outfit_design_restore(bigint)'::regprocedure,
  $o$  if (select count(*) from public.world_outfit_designs x where x.owner_id = uid and x.deleted_at is null and x.removed_at is null) >= (r ->> 'keep')::int then$o$,
  $n$  if d.slot in ('face', 'hair') then
    if (select count(*) from public.world_outfit_designs x where x.owner_id = uid and x.slot = d.slot and x.deleted_at is null and x.removed_at is null) >= (r -> d.slot ->> 'keep')::int then
      raise exception '% 도안은 %장까지 둘 수 있습니다. 다른 도안을 지운 뒤 되살려 주세요.', case d.slot when 'face' then '얼굴' else '머리' end, r -> d.slot ->> 'keep'; end if;
  elsif (select count(*) from public.world_outfit_designs x where x.owner_id = uid and x.slot in ('top', 'bottom') and x.deleted_at is null and x.removed_at is null) >= (r ->> 'keep')::int then$n$);

select pg_temp.yh_fix2('public.world_outfit_design_give(bigint,uuid)'::regprocedure,
  $o$deco, giver_id, gift_from)$o$, $n$deco, giver_id, gift_from, woven_at)$n$);
select pg_temp.yh_fix2('public.world_outfit_design_give(bigint,uuid)'::regprocedure,
  $o$d.deco, uid, nm)$o$, $n$d.deco, uid, nm, case when d.slot = 'hair' then now() end)$n$);
select pg_temp.yh_fix2('public.world_outfit_design_give(bigint,uuid)'::regprocedure,
  $o$  if not found then raise exception '내가 그린 도안만 보낼 수 있습니다.'; end if;$o$,
  $n$  if not found then raise exception '내가 그린 도안만 보낼 수 있습니다.'; end if;
  if d.slot = 'face' then raise exception '얼굴 도안은 보낼 수 없습니다.'; end if;$n$);
select pg_temp.yh_fix2('public.world_outfit_design_give(bigint,uuid)'::regprocedure,
  $o$  if (select count(*) from public.world_outfit_designs x where x.owner_id = p_target and x.deleted_at is null and x.removed_at is null) >= (r ->> 'keep')::int then$o$,
  $n$  if (select count(*) from public.world_outfit_designs x where x.owner_id = p_target and (case when d.slot = 'hair' then x.slot = 'hair' else x.slot in ('top', 'bottom') end) and x.deleted_at is null and x.removed_at is null)
      >= (case when d.slot = 'hair' then (r -> 'hair' ->> 'keep')::int else (r ->> 'keep')::int end) then$n$);
select pg_temp.yh_fix2('public.world_outfit_design_give(bigint,uuid)'::regprocedure,
  $o$nm || '님이 옷 도안' || case when d.title <> '' then ' 「' || d.title || '」' else '' end || '을(를) 보냈습니다. 내 모습 › 내 도안에서 지어 입을 수 있습니다.'$o$,
  $n$nm || '님이 ' || case when d.slot = 'hair' then '머리' else '옷' end || ' 도안' || case when d.title <> '' then ' 「' || d.title || '」' else '' end || '을(를) 보냈습니다. '
      || case when d.slot = 'hair' then '내 모습 › 머리에서 바로 쓸 수 있습니다.' else '내 모습 › 내 도안에서 지어 입을 수 있습니다.' end$n$);

select pg_temp.yh_fix2('public.world_outfit_design_weave(bigint)'::regprocedure,
  $o$  if d.woven_at is not null then raise exception '이미 지어 옷장에 넣은 도안입니다.'; end if;$o$,
  $n$  if d.slot in ('face', 'hair') then raise exception '얼굴·머리 도안은 짓지 않고 바로 씁니다.'; end if;
  if d.woven_at is not null then raise exception '이미 지어 옷장에 넣은 도안입니다.'; end if;$n$);

select pg_temp.yh_fix2('public.world_outfit_design_report(bigint,text)'::regprocedure,
  $o$x.id::text in (public.world_avatar_look_of(x.owner_id) ->> 'top_d', public.world_avatar_look_of(x.owner_id) ->> 'bottom_d')$o$,
  $n$x.id::text in (public.world_avatar_look_of(x.owner_id) ->> 'top_d', public.world_avatar_look_of(x.owner_id) ->> 'bottom_d', public.world_avatar_look_of(x.owner_id) ->> 'face_d', public.world_avatar_look_of(x.owner_id) ->> 'hair_d')$n$);

select pg_temp.yh_fix2('public.world_outfit_design_remove(bigint,text)'::regprocedure,
  $o$'운영진이 옷 도안' || case when d.title <> '' then ' 「' || d.title || '」' else '' end || '을(를) 내렸습니다. 그 도안으로 지은 옷은 입을 수 없습니다.'$o$,
  $n$'운영진이 ' || case d.slot when 'face' then '얼굴' when 'hair' then '머리' else '옷' end || ' 도안' || case when d.title <> '' then ' 「' || d.title || '」' else '' end || '을(를) 내렸습니다. '
      || case when d.slot in ('face', 'hair') then '그 도안은 더 쓸 수 없습니다.' else '그 도안으로 지은 옷은 입을 수 없습니다.' end$n$);

update public.world_patch_notes set body = rtrim(body, E'\n') || E'\n\n## 2.2.2\n- 내 모습에서 피부·머리·눈 색을 정해진 색 말고도 직접 고를 수 있습니다.\n- 눈·입을 직접 그리는 얼굴 도안이 생겼습니다. 저장하면 바로 쓸 수 있고, 한 사람이 세 장까지 둘 수 있습니다.\n- 비장고 상자와 마지막 방에서 「머리 그리기 도안」이 나옵니다. 한 장을 쓰면 머리 모양과 색을 마음대로 그려 바로 쓸 수 있고, 빈 도안은 사고팔 수 있습니다. 그린 머리는 옷 도안처럼 친구에게 사본을 보낼 수 있습니다.\n- 옷·장신구와 머리 그리기 도안의 물품 정보 창에 미리 보기 그림이 나옵니다.\n'
 where note_id = '2.2.0' and body not like '%## 2.2.2%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118060000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
