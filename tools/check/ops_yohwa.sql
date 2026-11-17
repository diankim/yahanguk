select 'yohwa' k, coalesce(s.potency::text, '?') stage, count(*) n, to_char(min(s.applied_at) at time zone 'Asia/Seoul', 'MM-DD HH24:MI') since,
  count(*) filter (where s.metadata ? 'frenzy_at') frenzy, count(*) filter (where s.metadata ? 'down_epoch') down
from public.world_character_statuses s where s.status_key = 'yohwa' group by s.potency
union all select 'seal', null, count(*), to_char(max(expires_at) at time zone 'Asia/Seoul', 'MM-DD HH24:MI'), null, null
from public.world_character_statuses where status_key = 'yohwa_seal' and (expires_at is null or expires_at > now())
union all select 'erosion>=80', null, count(*), null, null, null from public.world_characters where erosion >= 80
union all select 'plants_live', null, count(*), string_agg(to_char(expires_at at time zone 'Asia/Seoul', 'MM-DD HH24:MI'), ','), count(*) filter (where holder in (select owner_id from public.world_character_statuses where status_key = 'yohwa')), null
from public.world_gwiryeong_plants where ended is null
union all select 'plants_ended', ended, count(*), to_char(max(ended_at) at time zone 'Asia/Seoul', 'MM-DD HH24:MI'), null, null from public.world_gwiryeong_plants where ended is not null group by ended
union all select 'found_window', string_agg(distinct source, ','), count(*), to_char(max(got_at) at time zone 'Asia/Seoul', 'MM-DD HH24:MI'), null, null
from public.world_gwiryeong_log where got_at > now() - make_interval(days => coalesce((public.world_gwiryeong_rules() ->> 'window_days')::int, 3))
union all select 'yohwa_log_7d', kind, count(*), to_char(max(at) at time zone 'Asia/Seoul', 'MM-DD HH24:MI'), null, null from public.world_yohwa_log where at > now() - interval '7 days' group by kind;
