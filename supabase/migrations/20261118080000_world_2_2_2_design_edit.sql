create or replace function pg_temp.yh_fix2(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); n int;
begin
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'yh_fix2 %: 조각이 % 번 있음', p_fn, n; end if;
  execute replace(src, p_old, p_new);
end $f$;

create or replace function public.world_design_clean(p_slot text, p_base text, p_title text, p_pal text, p_px text, p_deco text)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
declare r jsonb := public.world_outfit_rules() -> 'design'; m jsonb; pal text; px text; deco text := ''; t text;
begin
  if p_slot in ('face', 'hair') then
    m := public.world_avatar_parts() -> p_slot;
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
  elsif p_slot in ('top', 'bottom') then
    m := public.world_avatar_parts() -> 'masks' -> (p_slot || ':' || coalesce(p_base, ''));
    if m is null then raise exception '도안 바탕으로 고를 수 없는 옷입니다.'; end if;
    pal := lower(replace(coalesce(p_pal, ''), '#', ''));
    if pal !~ '^([0-9a-f]{6}){1,8}$' or length(pal) / 6 > (r ->> 'colors')::int then raise exception '색이 올바르지 않습니다.'; end if;
    px := coalesce(p_px, '');
    if char_length(px) <> (m ->> 'n')::int or px !~ '^[0-7.]+$' then raise exception '도안 칸이 올바르지 않습니다.'; end if;
    if px !~ '[0-7]' then raise exception '한 칸 이상 칠해 주세요.'; end if;
    if exists (select 1 from regexp_matches(px, '[0-7]', 'g') x where x[1]::int >= length(pal) / 6) then raise exception '고르지 않은 색으로 칠한 칸이 있습니다.'; end if;
    deco := lower(replace(coalesce(p_deco, ''), '#', ''));
    if char_length(deco) <> 6 * (m ->> 'deco')::int or deco !~ '^([0-9a-f]{6}|[.]{6})*$' then raise exception '장식 색이 올바르지 않습니다.'; end if;
    t := btrim(regexp_replace(coalesce(p_title, ''), '[[:cntrl:]]+', ' ', 'g'));
    if char_length(t) > (r ->> 'title_max')::int then raise exception '도안 이름은 %자까지 쓸 수 있습니다.', r ->> 'title_max'; end if;
  else
    raise exception '도안을 그릴 곳을 고르세요.';
  end if;
  return jsonb_build_object('pal', pal, 'px', px, 'deco', deco, 't', t);
end $f$;
revoke all on function public.world_design_clean(text, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.world_design_clean(text, text, text, text, text, text) to fn_owner_field;

select pg_temp.yh_fix2('public.world_outfit_design_save(text,text,text,text,text,text)'::regprocedure,
  $o$    m := parts -> p_slot;
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
$o$,
  $n$    o := public.world_design_clean(p_slot, p_slot, p_title, p_pal, p_px, '');
    pal := o ->> 'pal'; px := o ->> 'px'; t := o ->> 't';
$n$);
select pg_temp.yh_fix2('public.world_outfit_design_save(text,text,text,text,text,text)'::regprocedure,
  $o$  pal := lower(replace(coalesce(p_pal, ''), '#', ''));
  if pal !~ '^([0-9a-f]{6}){1,8}$' or length(pal) / 6 > (r ->> 'colors')::int then raise exception '색이 올바르지 않습니다.'; end if;
  px := coalesce(p_px, '');
  if char_length(px) <> (m ->> 'n')::int or px !~ '^[0-7.]+$' then raise exception '도안 칸이 올바르지 않습니다.'; end if;
  if px !~ '[0-7]' then raise exception '한 칸 이상 칠해 주세요.'; end if;
  if exists (select 1 from regexp_matches(px, '[0-7]', 'g') x where x[1]::int >= length(pal) / 6) then raise exception '고르지 않은 색으로 칠한 칸이 있습니다.'; end if;
  deco := lower(replace(coalesce(p_deco, ''), '#', ''));
  if char_length(deco) <> 6 * (m ->> 'deco')::int or deco !~ '^([0-9a-f]{6}|[.]{6})*$' then raise exception '장식 색이 올바르지 않습니다.'; end if;
  t := btrim(regexp_replace(coalesce(p_title, ''), '[[:cntrl:]]+', ' ', 'g'));
  if char_length(t) > (r ->> 'title_max')::int then raise exception '도안 이름은 %자까지 쓸 수 있습니다.', r ->> 'title_max'; end if;
$o$,
  $n$  o := public.world_design_clean(p_slot, p_base, p_title, p_pal, p_px, p_deco);
  pal := o ->> 'pal'; px := o ->> 'px'; deco := o ->> 'deco'; t := o ->> 't';
$n$);

create or replace function public.world_outfit_design_edit(p_id bigint, p_title text, p_pal text, p_px text, p_deco text default '')
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); d public.world_outfit_designs%rowtype; o jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  perform pg_advisory_xact_lock(hashtextextended('outfit:' || uid::text, 0));
  select * into d from public.world_outfit_designs x where x.id = p_id and x.owner_id = uid and x.deleted_at is null and x.removed_at is null for update;
  if not found then raise exception '도안을 찾을 수 없습니다.'; end if;
  if d.origin is not null then raise exception '받은 도안은 고칠 수 없습니다.'; end if;
  o := public.world_design_clean(d.slot, d.base, coalesce(p_title, d.title), p_pal, p_px, coalesce(p_deco, ''));
  update public.world_outfit_designs set title = o ->> 't', pal = o ->> 'pal', px = o ->> 'px', deco = case when d.slot in ('top', 'bottom') then o ->> 'deco' else deco end where id = d.id;
  return public.world_outfit_design_list() || jsonb_build_object('saved', d.id, 'content', case d.slot when 'face' then '눈·입 도안을 고쳤습니다.' when 'hair' then '머리 도안을 고쳤습니다.'
    else '옷 도안을 고쳤습니다.' || case when d.woven_at is not null then ' 이미 지은 옷도 고친 모습으로 바뀝니다.' else '' end end);
end $f$;
revoke all on function public.world_outfit_design_edit(bigint, text, text, text, text) from public, anon;
grant execute on function public.world_outfit_design_edit(bigint, text, text, text, text) to authenticated;

update public.world_patch_notes set body = rtrim(body, E'\n') || E'\n- 내가 그린 도안(옷·눈·입·머리)을 다시 열어 고칠 수 있습니다. 고쳐도 하루 새 도안 수에 들지 않고, 머리 그리기 도안도 쓰지 않습니다. 이미 지은 옷은 고친 모습으로 바뀌고, 친구에게 보낸 사본은 그대로입니다. 「내 모습」의 눈·입·머리 칸에서도 고치기·지우기를 할 수 있습니다.\n'
 where note_id = '2.2.0' and body like '%## 2.2.2%' and body not like '%다시 열어 고칠 수%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118080000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
