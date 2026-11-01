-- 7.7.4 — 피해 기록판(사용자 요청 2026-11-01): 합동 토벌·파티 토벌·귀허의 주인에서 파티원마다 준 피해·받은 피해·회복을 수치와 게이지로.
-- 준 피해·회복은 합동 토벌(world_raid_members.dmg·heal)·귀허(world_gw_members.dmg·heal)가 이미 센다. 받은 피해만 더한다.
-- 파티 토벌(world_pfight_members)은 아무것도 세지 않았으므로 세 가지를 모두 더한다:
--   준 피해 = 그 사람 차례 앞뒤 요괴 체력 차, 받은 피해·회복 = 그 사람 차례 앞뒤 체력 차(한 차례에 행동 하나라 회복품과 반격이 겹치면 차이만 남는다).
-- 캐릭터 행을 더 고치지 않는다(참가자 표만).
alter table public.world_raid_members add column if not exists taken int not null default 0;
alter table public.world_gw_members add column if not exists taken int not null default 0;
alter table public.world_pfight_members add column if not exists dmg int not null default 0,
  add column if not exists taken int not null default 0,
  add column if not exists heal int not null default 0;

do $p$
declare r record; d text; n int; own text;
begin
  for r in
    select * from (values
      -- 합동 토벌: 맞은 사람(대신 막은 사람이면 그 사람)의 받은 피해
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure,
$A$    update public.world_raid_members set fx = f - 'bound', out_until = now() + interval '60 seconds', falls = falls + 1 where raid_id = p_raid and owner_id = who;$A$,
$B$    update public.world_raid_members set taken = taken + d::int, fx = f - 'bound', out_until = now() + interval '60 seconds', falls = falls + 1 where raid_id = p_raid and owner_id = who;$B$),
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure,
$A$    update public.world_raid_members set fx = f where raid_id = p_raid and owner_id = who;
    perform public.world_raid_say(p_raid, 'hit',$A$,
$B$    update public.world_raid_members set taken = taken + d::int, fx = f where raid_id = p_raid and owner_id = who;
    perform public.world_raid_say(p_raid, 'hit',$B$),
      ('public.world_raid_snapshot_core(uuid)'::regprocedure,
$A$'dmg', x.dmg, 'heal', x.heal,$A$,
$B$'dmg', x.dmg, 'heal', x.heal, 'taken', x.taken,$B$),
      -- 귀허의 주인
      ('public.world_gw_hurt(uuid,uuid,integer,integer,text)'::regprocedure,
$A$update public.world_gw_members set hp = 0, out_rounds = $A$,
$B$update public.world_gw_members set taken = taken + d, hp = 0, out_rounds = $B$),
      ('public.world_gw_hurt(uuid,uuid,integer,integer,text)'::regprocedure,
$A$update public.world_gw_members set hp = m.hp - d where$A$,
$B$update public.world_gw_members set hp = m.hp - d, taken = taken + d where$B$),
      ('public.world_gw_snapshot(uuid)'::regprocedure,
$A$'dmg', m.dmg, 'heal', m.heal, 'falls', m.falls,$A$,
$B$'dmg', m.dmg, 'heal', m.heal, 'taken', m.taken, 'falls', m.falls,$B$),
      -- 파티 토벌: 차례 앞 체력을 잠깐 적어 두고, 차례 뒤 차이로 센다
      ('public.world_pfight_resolve(uuid)'::regprocedure,
$A$auto := mm.action is null; act := coalesce(mm.action, 'guard'); before := f.hp;$A$,
$B$auto := mm.action is null; act := coalesce(mm.action, 'guard'); before := f.hp;
      perform set_config('yh.pf_hb', coalesce((select health from public.world_characters where owner_id = mm.owner_id), 0)::text, true);$B$),
      ('public.world_pfight_resolve(uuid)'::regprocedure,
$A$if before > f.hp then f.round_dmg := f.round_dmg + (before - f.hp); end if;$A$,
$B$if before > f.hp then f.round_dmg := f.round_dmg + (before - f.hp); end if;
          update public.world_pfight_members pm set dmg = pm.dmg + greatest(0, before - f.hp),
              taken = pm.taken + greatest(0, coalesce(nullif(current_setting('yh.pf_hb', true), '')::int, c.health) - c.health),
              heal = pm.heal + greatest(0, c.health - coalesce(nullif(current_setting('yh.pf_hb', true), '')::int, c.health))
            from public.world_characters c where c.owner_id = mm.owner_id and pm.fight_id = p_fight and pm.owner_id = mm.owner_id;$B$),
      ('public.world_pfight_snapshot(uuid)'::regprocedure,
$A$'health', c.health, 'mental', c.mental, 'sp', c.spiritual_power, 'job', c.job_key)$A$,
$B$'health', c.health, 'mental', c.mental, 'sp', c.spiritual_power, 'job', c.job_key, 'dmg', pm.dmg, 'taken', pm.taken, 'heal', pm.heal)$B$)
    ) x(fn, a, b)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.7.4 meter anchor in % (% of 1): %', r.fn, n, left(r.a, 70); end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
  end loop;
end $p$;

update public.world_app_meta set value = '20261104202300' where key = 'db_version';
