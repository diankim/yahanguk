import hashlib, re, subprocess, sys, pathlib

BASE = '-h /var/tmp/yhpg -p 5433 -U postgres -d yh_w'
NEXT = '-h /var/tmp/yhpg -p 5433 -U postgres -d yh_t4'
HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parents[1] / 'supabase/migrations/20261106080000_world_1_0_4n_contrib.sql'

PROD_MD5 = {
    'world_raid_hit': '642952b8e44ad682afbb8691923efd49',
    'world_gw_hit': 'a53515d64cc374f579072ca78aa9ff09',
    'world_raid_snapshot_core': 'ebd1f846114d790a1751e68f74cf7c12',
    'world_gw_snapshot': '0b0a9702b02833fcda96b125409cf8da',
    'world_pfight_snapshot': '51539331bebd6a5a89303224e9563f42',
    'world_raid_begin_fight': 'ecb5e9edac3febbcd8f53ac6a429f976',
    'world_raid_join': 'f9cba5c67d30baed8064d34602604f73',
    'world_raid_settle': '1c936e49d6606c966f7098c863785061',
    'world_raid_boss_base': '402331494a0830740340807c58cccf59',
    'world_raid_charge_need': '62a80b2300467efc5913883766084a43',
}

EDITS = {
    'world_raid_hit': [
        ("  st := m.stats;\n", "  st := m.stats;\n  if rk = 'world' then p_raw := p_raw * least((public.world_shadow_rules() ->> 'pow_hi')::numeric, greatest((public.world_shadow_rules() ->> 'pow_lo')::numeric, coalesce((st ->> 'attack')::numeric, 7.5 * m.level) / greatest(1, 7.5 * m.level))); end if;\n"),
        ("  perform public.world_raid_credit(p_raid, who, d, case when (r ->> 'taunt')::boolean then 'guard' else 'taken' end);\n",
         "  perform public.world_raid_credit(p_raid, who, d, case when (r ->> 'taunt')::boolean then 'guard' else 'taken' end);\n  if p_kind = 'single' and not coalesce((r ->> 'taunt')::boolean, false) then perform public.world_raid_credit(p_raid, who, d, 'hit1'); end if;\n"),
    ],
    'world_raid_boss_base': [
        ("if p_kind is distinct from 'final' then return 4 + 0.7 * (coalesce(p_lv, 1) + 3); end if;",
         "if p_kind is distinct from 'final' then return (4 + 0.7 * (coalesce(p_lv, 1) + 3)) * (public.world_shadow_rules() ->> 'dmg_mul')::numeric; end if;"),
    ],
    'world_raid_charge_need': [
        ("return greatest(500, round(s * 3))::int;", "return greatest(500, round(s * (public.world_shadow_rules() ->> 'charge_mul')::numeric))::int;"),
    ],
    'world_gw_hit': [
        ("  perform public.world_gw_credit(p_fight, p_uid, (r ->> 'd')::numeric, case when (r ->> 'taunt')::boolean then 'guard' else 'taken' end);\n",
         "  perform public.world_gw_credit(p_fight, p_uid, (r ->> 'd')::numeric, case when (r ->> 'taunt')::boolean then 'guard' else 'taken' end);\n  if not p_aoe and not coalesce((r ->> 'taunt')::boolean, false) then perform public.world_gw_credit(p_fight, p_uid, (r ->> 'd')::numeric, 'hit1'); end if;\n"),
    ],
    'world_raid_snapshot_core': [
        ("reveal_region boolean; reveal_c boolean;", "reveal_region boolean; reveal_c boolean; sh jsonb;"),
        ("  ck := public.world_raid_k(rid);\n  select coalesce(sum(public.world_raid_score(rd.kind, level, credits, stats, contrib, ck)), 0) into tot from public.world_raid_members where raid_id = rid;",
         "  sh := case when rd.status not in ('won', 'failed') then public.world_raid_shares(rid) end;\n  select coalesce(sum(contrib), 0) into tot from public.world_raid_members where raid_id = rid;"),
        ("'share', case when tot > 0 then round(public.world_raid_score(rd.kind, x.level, x.credits, x.stats, x.contrib, ck) / tot * 100, 1) else 0 end",
         "'share', case when sh is not null then coalesce((sh ->> x.owner_id::text)::numeric, 0) when tot > 0 then round(x.contrib / tot * 100, 1) else 0 end"),
    ],
    'world_gw_snapshot': [
        ("fid uuid := p_fight; why text; inv_f uuid; last_f uuid;", "fid uuid := p_fight; why text; inv_f uuid; last_f uuid; gsh jsonb;"),
        ("  select * into me from public.world_gw_members where fight_id = fid and owner_id = uid;\n  return jsonb_build_object('fight',",
         "  select * into me from public.world_gw_members where fight_id = fid and owner_id = uid;\n  gsh := public.world_gw_shares(fid);\n  return jsonb_build_object('fight',"),
        ("coalesce((public.world_gw_shares(m.fight_id) ->> m.owner_id::text)::numeric, 0)", "coalesce((gsh ->> m.owner_id::text)::numeric, 0)"),
    ],
    'world_pfight_snapshot': [
        ("me public.world_pfight_members%rowtype;", "me public.world_pfight_members%rowtype; psh jsonb;"),
        ("  select * into me from public.world_pfight_members where fight_id = p_fight and owner_id = uid;\n  return jsonb_build_object(",
         "  select * into me from public.world_pfight_members where fight_id = p_fight and owner_id = uid;\n  psh := public.world_pfight_shares(p_fight);\n  return jsonb_build_object("),
        ("coalesce((public.world_pfight_shares(p_fight) ->> pm.owner_id::text)::numeric, 0)", "coalesce((psh ->> pm.owner_id::text)::numeric, 0)"),
    ],
    'world_raid_begin_fight': [
        ("greatest(2500, round(s * 110))", "greatest((public.world_shadow_rules() ->> 'hp_min')::numeric, round(s * (public.world_shadow_rules() ->> 'hp_mul')::numeric))"),
    ],
    'world_raid_join': [
        ("::numeric, 0) * 110 * greatest(0.25,", "::numeric, 0) * (public.world_shadow_rules() ->> 'hp_mul')::numeric * greatest(0.25,"),
    ],
    'world_raid_settle': [
        ("top uuid; revenge boolean; nxt timestamptz; reg text;", "top uuid; revenge boolean; nxt timestamptz; reg text; sr jsonb := public.world_shadow_rules(); t0 timestamptz; stay numeric; lvm numeric;"),
        ("  perform public.world_raid_recontrib(p_raid);\n", "  perform public.world_raid_recontrib(p_raid);\n  t0 := coalesce(rd.signup_until, rd.created_at);\n"),
        ("    share := case when tot > 0 then m.contrib / tot else 0 end;\n",
         "    share := case when tot > 0 then m.contrib / tot else 0 end;\n    stay := least(1, greatest(0, extract(epoch from now() - greatest(m.joined_at, t0))) / greatest(1, extract(epoch from now() - t0)) / (sr ->> 'stay_full')::numeric);\n    lvm := least(1, m.clv / (sr ->> 'gil_lv')::numeric);\n"),
        ("rw_gil := least(1800, round(300 + 1700 * share));", "rw_gil := round(least(1800, 300 * stay + 1700 * share) * lvm);"),
        ("least(0.35, 0.10 + 0.6 * share)", "least(0.35, 0.10 * stay + 0.6 * share)"),
        ("rw_gil := round(80 + 300 * share); xp := round(public.world_xp_need(m.clv) * 0.03);", "rw_gil := round((80 * stay + 300 * share) * lvm); xp := round(public.world_xp_need(m.clv) * 0.03 * stay);"),
        ("case when xp > 0 then ' · 경험치 ' || xp else '' end", "case when xp > 0 then ' · 경험치 ' || round(xp * public.world_xp_damp_pct(m.owner_id, m.clv) / 100.0) else '' end"),
    ],
}

def q(dsn, sql):
    return subprocess.run(['psql', *dsn.split(), '-At', '-c', sql], check=True, capture_output=True, text=True).stdout

def strip_comments(src):
    return '\n'.join(l for l in src.split('\n') if not re.match(r'^\s*--', l))

def src_of(dsn, fn):
    oid = q(dsn, f"select oid from pg_proc where proname = '{fn}' and pronamespace = 'public'::regnamespace").strip()
    if '\n' in oid or not oid:
        sys.exit(f'{fn}: expected one function, got {oid!r}')
    return oid, q(dsn, f"select prosrc from pg_proc where oid = {oid}")[:-1]

def md5(s):
    return hashlib.md5(s.encode()).hexdigest()

parts = []
for fn, edits in EDITS.items():
    _, base = src_of(BASE, fn)
    if md5(base) != PROD_MD5[fn] and md5(strip_comments(base)) != PROD_MD5[fn]:
        sys.exit(f'{fn}: replica source differs from production')
    oid, src = src_of(NEXT, fn)
    src = strip_comments(src)
    d = q(NEXT, f"select pg_get_functiondef({oid})")[:-1]
    head = d.split('AS $function$', 1)[0]
    for a, b in edits:
        if src.count(a) != 1:
            sys.exit(f'{fn}: {src.count(a)} matches for {a[:70]!r}')
        src = src.replace(a, b)
    parts.append(f"{head}AS $function${src}$function$;\n")

OUT.write_text('lock table public.world_characters in access exclusive mode;\n\n' + (HERE / 'pre.sql').read_text() + '\n' + '\n'.join(parts) + '\n' + (HERE / 'post.sql').read_text() + '\n' + (HERE / 'notice.sql').read_text())
print(OUT)
