import hashlib, re, subprocess, sys, pathlib

DSN = sys.argv[1] if len(sys.argv) > 1 else '-h /var/tmp/yhpg -p 5433 -U postgres -d yh_w'
OUT = pathlib.Path(__file__).resolve().parents[2] / 'supabase/migrations/20261106070000_world_1_0_4n_marks.sql'

PROD_MD5 = {
    'world_battle_action': 'ef6a61848c981ac87749df2b693c6648',
    'world_guard_action_context': '8a2ad1e099e77d111cffb9d6ee00725a',
    'world_pfight_resolve': 'f60dcf8f994209867aba7400cb0690df',
    'world_pfight_snapshot': '51539331bebd6a5a89303224e9563f42',
    'world_raid_snapshot_core': 'ebd1f846114d790a1751e68f74cf7c12',
    'world_raid_action': 'baf07fe08b8aa81e8f46746f64c4a59b',
    'world_raid_hit': '642952b8e44ad682afbb8691923efd49',
    'world_character_purge': '5fa1b522c4b5861506867ee2ad07bfe9',
}

EDITS = {
    'world_battle_action': [
        ("turn int; v_fx jsonb;", "turn int; v_weak text; v_fx jsonb;"),
        ("ELSE base := base * 0.5; lines := lines || jsonb_build_array('쏠 것이 떨어져", "ELSE base := base * 0.5; v_weak := 'ammo'; lines := lines || jsonb_build_array('쏠 것이 떨어져"),
        ("ELSE base := base * 0.5; lines := lines || jsonb_build_array('영력이 바닥나", "ELSE base := base * 0.5; v_weak := 'mp'; lines := lines || jsonb_build_array('영력이 바닥나"),
        ("ELSE base := base * 0.5; lines := lines || jsonb_build_array('기력이 바닥나", "ELSE base := base * 0.5; v_weak := 'sp'; lines := lines || jsonb_build_array('기력이 바닥나"),
        ("'crit', crit, 'health', hp, 'battle',", "'crit', crit, 'weak', v_weak, 'health', hp, 'battle',"),
    ],
    'world_guard_action_context': [
        ("away boolean; passenger uuid; idling boolean;", "away boolean; passenger uuid; idling boolean; cd_s text;"),
        ("      RAISE EXCEPTION '%', format('이동을 취소한 뒤 3분 동안은 다시 출발할 수 없습니다(%s초 남음).',\n        ceil(extract(epoch FROM (SELECT max(h.cancelled_at) FROM public.world_travel_history h WHERE h.owner_id = new.actor_id) + interval '3 minutes' - now())));",
         "      cd_s := ceil(extract(epoch FROM (SELECT max(h.cancelled_at) FROM public.world_travel_history h WHERE h.owner_id = new.actor_id) + interval '3 minutes' - now()))::text;\n      RAISE EXCEPTION USING MESSAGE = format('이동을 취소한 뒤 3분 동안은 다시 출발할 수 없습니다(%s초 남음).', cd_s), HINT = 'cd:' || cd_s;"),
    ],
    'world_pfight_resolve': [
        ("update public.world_pfight_members pm set dmg = pm.dmg + greatest(0, before - f.hp),",
         "update public.world_pfight_members pm set weak = r ->> 'weak', dmg = pm.dmg + greatest(0, before - f.hp),"),
    ],
    'world_pfight_snapshot': [
        ("'dmg', pm.dmg, 'taken', pm.taken, 'heal', pm.heal, 'share'", "'dmg', pm.dmg, 'taken', pm.taken, 'heal', pm.heal, 'weak', pm.weak, 'share'"),
    ],
    'world_raid_snapshot_core': [
        ("jsonb_build_object('id', l.id, 'at', l.at, 'kind', l.kind, 'text', l.text)", "jsonb_build_object('id', l.id, 'at', l.at, 'kind', l.kind, 'text', l.text, 'who', l.who, 'n', l.n)"),
    ],
    'world_raid_action': [
        ("world_raid_say(p_raid, case when crit then 'crit' else 'atk' end, mb.name || ' — ' || dmg || '의 피해' || case when crit then '(치명타)' else '' end || '.')",
         "world_raid_say_n(p_raid, case when crit then 'crit' else 'atk' end, mb.name || ' — ' || dmg || '의 피해' || case when crit then '(치명타)' else '' end || '.', mb.name, dmg)"),
    ],
    'world_raid_hit': [
        ("world_raid_say(p_raid, 'fall', nm || ' — ' || d || '의 피해를 입고", "world_raid_say_n(p_raid, 'fall', nm || ' — ' || d || '의 피해를 입고"),
        ("' 쉰 뒤 행동하면 돌아옴).');", "' 쉰 뒤 행동하면 돌아옴).', nm, d);"),
        ("world_raid_say(p_raid, 'hit', nm || ' — ' || d || '의 피해' || '.')", "world_raid_say_n(p_raid, 'hit', nm || ' — ' || d || '의 피해' || '.', nm, d)"),
    ],
    'world_character_purge': [
        ("  delete from public.world_pets where owner_id = p_uid;\n",
         "  delete from public.world_pets where owner_id = p_uid;\n  delete from public.world_xp_damp where owner_id = p_uid;\n  delete from public.world_yohwa_log where owner_id = p_uid;\n  delete from public.world_user_commissions where owner_id = p_uid and status = 'open';\n"),
    ],
}

def q(sql):
    return subprocess.run(['psql', *DSN.split(), '-At', '-c', sql], check=True, capture_output=True, text=True).stdout

def strip_comments(src):
    return '\n'.join(l for l in src.split('\n') if not re.match(r'^\s*--', l))

parts = []
for fn, edits in EDITS.items():
    oid = q(f"select oid from pg_proc where proname = '{fn}' and pronamespace = 'public'::regnamespace").strip()
    if '\n' in oid or not oid:
        sys.exit(f'{fn}: expected one function, got {oid!r}')
    src = q(f"select prosrc from pg_proc where oid = {oid}")[:-1]
    if hashlib.md5(src.encode()).hexdigest() != PROD_MD5[fn]:
        src = strip_comments(src)
        if hashlib.md5(src.encode()).hexdigest() != PROD_MD5[fn]:
            sys.exit(f'{fn}: replica source differs from production')
    d = q(f"select pg_get_functiondef({oid})")[:-1]
    head, body_and_tail = d.split('AS $function$', 1)
    body = src
    for a, b in edits:
        if body.count(a) != 1:
            sys.exit(f'{fn}: {body.count(a)} matches for {a[:60]!r}')
        body = body.replace(a, b)
    parts.append(f"{head}AS $function${body}$function$;\n")

print(OUT)
pre = open(pathlib.Path(__file__).with_name('pre.sql')).read()
post = open(pathlib.Path(__file__).with_name('post.sql')).read()
OUT.write_text(pre + '\n'.join(parts) + post)
