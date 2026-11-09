create or replace function public.world_pet_care_gain(p_uid uuid, p_act text, p_n integer, p_item text, p_likes text)
 returns integer language plpgsql stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare base int; tm boolean := exists (select 1 from public.world_characters c where c.owner_id = p_uid and c.job_key = 'tamer'); r jsonb := public.world_pet_partner_rules();
begin
  base := case p_act
    when 'pat' then case when p_n <= 5 then 2 else 0 end
    when 'play' then case when p_n <= 3 then 3 else 0 end
    when 'feed' then case when p_item = p_likes then 12 when p_item = 'pet_food' then 4 else 6 end
    when 'guest' then 1 else 0 end;
  if not tm or base = 0 then return base; end if;
  if p_act = 'guest' then return (r ->> 'guest_tamer')::int; end if;
  return ceil(base * (r ->> 'care_mul')::numeric)::int;
end $function$;
select pg_temp.yh_share('public.world_pet_care_gain(uuid, text, integer, text, text)');

select pg_temp.yh_fix('world_pet_act', array[
$q$c public.world_characters%rowtype; have int; was_adult boolean;$q$,
$q$c public.world_characters%rowtype; have int; was_adult boolean; carry boolean := false;$q$,

$q$  select * into h from public.world_housing where owner_id = p_owner;
  if not found or h.pet_id is null then raise exception '이 별채에는 동무가 없습니다.'; end if;
  if h.pet_out then raise exception '동무가 주인과 함께 나가 있습니다.'; end if;
  why := public.world_housing_can_view(uid, p_owner, h.gate);
  if why is not null then raise exception '%', why; end if;$q$,
$q$  if p_owner is null then
    select f.pet_id into h.pet_id from public.world_pet_profile f where f.owner_id = uid;
    if h.pet_id is null then raise exception '데리고 다니는 동무가 없습니다.'; end if;
    p_owner := uid; carry := true;
  else
    select * into h from public.world_housing where owner_id = p_owner;
    if not found or h.pet_id is null then raise exception '이 별채에는 동무가 없습니다.'; end if;
    if h.pet_out then raise exception '동무가 주인과 함께 나가 있습니다.'; end if;
    why := public.world_housing_can_view(uid, p_owner, h.gate);
    if why is not null then raise exception '%', why; end if;
  end if;$q$,

$q$gain := case when pt.pat_n <= 5 then 2 else 0 end;$q$,
$q$gain := public.world_pet_care_gain(uid, 'pat', pt.pat_n, null, null);$q$,

$q$gain := case when pt.play_n <= 3 then 3 else 0 end;$q$,
$q$gain := public.world_pet_care_gain(uid, 'play', pt.play_n, null, null);$q$,

$q$gain := case when p_item = sp.likes then 12 when p_item = 'pet_food' then 4 else 6 end;$q$,
$q$gain := public.world_pet_care_gain(uid, 'feed', pt.feed_n, p_item, sp.likes);$q$,

$q$    gain := 1; react := case$q$,
$q$    gain := public.world_pet_care_gain(uid, 'guest', 1, null, null); react := case$q$,

$q$  if p_act <> 'feed' and coalesce($q$,
$q$  if p_act <> 'feed' and not carry and coalesce($q$
]);
