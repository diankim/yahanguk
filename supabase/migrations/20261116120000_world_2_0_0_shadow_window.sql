lock table public.world_characters in access exclusive mode;

create or replace function public.world_shadow_rules()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'pg_catalog'
AS $function$
  select '{"hp_mul": 350, "hp_min": 9000, "dmg_mul": 1.4, "pow_lo": 0.75, "pow_hi": 1.5, "charge_mul": 5, "stay_full": 0.5, "gil_lv": 20, "from": "12:00", "to": "23:00"}'::jsonb
$function$;

create or replace function public.world_raid_evening(p_base timestamp with time zone)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d date := (p_base at time zone 'Asia/Seoul')::date; s timestamptz; e timestamptz; f timestamptz;
  r jsonb := public.world_shadow_rules();
begin
  loop
    s := (d + (r ->> 'from')::time) at time zone 'Asia/Seoul'; e := (d + (r ->> 'to')::time) at time zone 'Asia/Seoul';
    if p_base <= e then f := greatest(s, p_base); return f + random() * (e - f); end if;
    d := d + 1;
  end loop;
end $function$;

do $c$ begin
  if not exists (select 1 from public.world_patch_notes where note_id = '2.0.0') then
    raise exception '2.0.0 패치노트가 없습니다';
  end if;
end $c$;
update public.world_patch_notes set body = body || $N$

### 봉연의 그림자
- 나타나는 때를 한국 시각 정오~밤 11시 사이로 넓혔습니다(지금까지 오후 4시~9시 30분). 늦게 나타나면 토벌이 자정 무렵까지 이어질 수 있습니다.
$N$ where note_id = '2.0.0';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261116120000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
