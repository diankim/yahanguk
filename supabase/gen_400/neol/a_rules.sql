alter table public.world_raids add column if not exists boss_key text not null default 'shadow';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'world_raids_boss_key_check') then
    alter table public.world_raids add constraint world_raids_boss_key_check check (boss_key in ('shadow', 'neol'));
  end if;
end $$;
alter table public.world_raid_locks add column if not exists kind text not null default 'lock';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'world_raid_locks_kind_check') then
    alter table public.world_raid_locks add constraint world_raid_locks_kind_check check (kind in ('lock', 'flow', 'dry'));
  end if;
end $$;

create or replace function public.world_neol_rules()
 returns jsonb language sql immutable set search_path to 'pg_catalog'
as $f$ select '{
  "name": "엉긴 너울", "short": "너울", "news": "너울 소식",
  "gil_cap": 1800,
  "from": "12:00", "to": "23:00",
  "regions": ["pd_shore", "pd_offsea", "pd_rift", "bs_geo", "jb_ebony", "jb_ferry", "nm_snow", "dm_field", "dm_bamboo", "ho_outer", "ho_coast"],
  "min_open": 3, "active_days": 2, "gap_h": 36, "jitter_h": 12,
  "mk2": {
    "counter_mul": 2,
    "miss": {"pierce": 0.5, "regrow": 1, "regrow_none": 2},
    "weight": {"every": 12, "every3": 10, "off": 4, "delay": 6, "window": 6, "mul": 4, "solo": 1.5, "tank_n": 2, "hold": 0.5, "team": 3},
    "dry": {"from_phase": 2, "pick": 3, "dmg": 3, "line": 90, "beats": 8, "stiff": 15, "stiff_cap": 2},
    "core": {"from_phase": 3, "every": 20, "off": 9, "secs": 8, "mul": 4, "min": 3600, "hits": 3, "regrow": 3, "relock": 1.3, "open_s": 12, "open_pct": 20, "boost": 0.1},
    "tide": {"every": 9, "off": 2, "tell": 4, "gap": 2, "first": 0.8, "ebb": 1.5}
  },
  "drop": {"item": "neol_drop", "win_min": 2, "win_k": 12, "win_max": 6, "fail_min": 1, "fail_share": 0.1},
  "gear": {"items": ["raid2_norigae", "raid2_amulet", "raid2_mask"], "p": 0.04, "p_share": 0.08},
  "result": {
    "win": {"name": "흐름이 돌아옴", "here": {"gather_qty_pct": 10, "rare_loot_pct": 3}, "near": {"gather_qty_pct": 5}},
    "fail": {"name": "마름", "here": {"gather_qty_pct": -25, "incoming_damage_pct": 10, "healing_pct": -10, "encounter_pct": 10}, "near": {"healing_pct": -5, "encounter_pct": 5}}
  }
}'::jsonb $f$;

create or replace function public.world_raid_boss_key_rules(p_key text)
 returns jsonb language sql immutable set search_path to 'pg_catalog', 'public'
as $f$ select case when p_key = 'neol' then (public.world_shadow_rules() - 'name' - 'mk2' - 'from' - 'to') || public.world_neol_rules() else public.world_shadow_rules() end $f$;

create or replace function public.world_raid_boss_rules(p_raid uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  return public.world_raid_boss_key_rules((select r.boss_key from public.world_raids r where r.raid_id = p_raid));
end $f$;

create or replace function public.world_raid_news(p_key text)
 returns text language sql immutable set search_path to 'pg_catalog', 'public'
as $f$ select case when p_key = 'neol' then public.world_neol_rules() ->> 'news' else '그림자 소식' end $f$;

create or replace function public.world_raid_chat_k(p_key text, p_text text)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare who uuid := coalesce((select owner_id from public.world_staff order by owner_id limit 1), (select owner_id from public.world_characters order by owner_id limit 1));
begin
  if who is null then return; end if;
  insert into public.world_chat_messages(channel_type, sender_id, sender_name, content) values ('global', who, public.world_raid_news(p_key), p_text);
end $f$;

create or replace function public.world_raid_evening_k(p_base timestamptz, p_key text)
 returns timestamptz language plpgsql security definer set search_path to ''
as $f$
declare d date := (p_base at time zone 'Asia/Seoul')::date; s timestamptz; e timestamptz; f timestamptz;
  r jsonb := public.world_raid_boss_key_rules(p_key);
begin
  loop
    s := (d + (r ->> 'from')::time) at time zone 'Asia/Seoul'; e := (d + (r ->> 'to')::time) at time zone 'Asia/Seoul';
    if p_base <= e then f := greatest(s, p_base); return f + random() * (e - f); end if;
    d := d + 1;
  end loop;
end $f$;

select pg_temp.yh_fix('world_sys_chat_names', array['"그림자 소식",', '"그림자 소식","너울 소식",']);

select pg_temp.yh_share('public.world_neol_rules()');
select pg_temp.yh_share('public.world_raid_boss_key_rules(text)');
select pg_temp.yh_share('public.world_raid_boss_rules(uuid)');
select pg_temp.yh_share('public.world_raid_news(text)');
select pg_temp.yh_share('public.world_raid_chat_k(text, text)');
select pg_temp.yh_share('public.world_raid_evening_k(timestamptz, text)');
