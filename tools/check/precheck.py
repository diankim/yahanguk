import json, pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
JS = ROOT / 'assets/js'

ACCOUNT_TABLES = {
    'world_active_sessions', 'world_blocks', 'world_bug_reports', 'world_circle_members', 'world_economy_ledger',
    'world_expedition_hits', 'world_faction_base_activity_log', 'world_faction_donations', 'world_faction_request_claims',
    'world_faction_supply_claims', 'world_friend_notes', 'world_friends', 'world_gw_members', 'world_gw_records',
    'world_gwiryeong_log', 'world_legacy_marks', 'world_letter_sends', 'world_notify_prefs', 'world_party_loot_allocations',
    'world_pfight_members', 'world_raid_members', 'world_report_rewards', 'world_shop_buy_caps', 'world_staff',
    'world_tourney_entrants', 'world_travel_history', 'world_ui_prefs', 'world_wedding_guests', 'world_whisper_reads',
}
UNMUTABLE_NOTES = {'bug_reply', 'rescued', 'yohwa', 'death', 'system', 'drawing_removed'}
ANON_OK = {'world_app_version'}
NOT_PRELOADED = {'assets/js/boot.js', 'assets/js/maintenance.js'}
SERVER_TEXT = ['쏠 것이 떨어져', '기력이 바닥나', '영력이 바닥나', '초 남음', '의 피해']

SQL = {
    'purge': """with t as (select distinct c.table_name from information_schema.columns c join information_schema.tables tb on tb.table_name = c.table_name and tb.table_schema = 'public' and tb.table_type = 'BASE TABLE'
  where c.table_schema = 'public' and c.column_name in ('owner_id', 'character_id', 'user_id') and c.table_name like 'world\\_%'),
 s as (select string_agg(prosrc, ' ') src from pg_proc where proname in ('world_character_purge', 'world_character_delete'))
select coalesce(json_agg(t.table_name order by t.table_name), '[]') from t, s where position(t.table_name in s.src) = 0""",
    'notes': """select coalesce(json_agg(distinct k), '[]') from (select (regexp_matches(prosrc, 'world_notifications[^;]*?values\\s*\\([^,]*,\\s*''([a-z_0-9]+)''', 'gi'))[1] k from pg_proc) x
where public.world_notify_group(k) is null""",
    'anon': """select coalesce(json_agg(proname order by proname), '[]') from pg_proc p join pg_namespace n on n.oid = p.pronamespace and nspname = 'public'
where prosecdef and has_function_privilege('anon', p.oid, 'execute')""",
    'callable': """select coalesce(json_agg(proname), '[]') from pg_proc p join pg_namespace n on n.oid = p.pronamespace and nspname = 'public'
where proname like 'world\\_%' and has_function_privilege('authenticated', p.oid, 'execute')""",
    'search_path': """select coalesce(json_agg(proname order by proname), '[]') from pg_proc p join pg_namespace n on n.oid = p.pronamespace and nspname = 'public'
where prosecdef and proname like 'world\\_%' and not exists (select 1 from unnest(coalesce(proconfig, '{}')) c where c like 'search_path=%')""",
}

def js_files():
    return sorted(p for p in JS.rglob('*.js') if 'gamedata' not in p.name)

def client_checks():
    out = []
    for p in js_files():
        rel = p.relative_to(ROOT).as_posix()
        src = p.read_text()
        if p.name != 'hq.js':
            for i, line in enumerate(src.split('\n'), 1):
                if re.search(r"_hq\b|'_hq'|endsWith\('_hq'\)", line):
                    out.append(('우수품', f'{rel}:{i}', '_hq를 직접 다룸 → assets/js/hq.js'))
        if p.name != 'changes.js':
            for i, line in enumerate(src.split('\n'), 1):
                if re.search(r"/[a-z_|^$]{3,}/\.test\((ev\.|e\.)?name\b", line):
                    out.append(('다시 읽기', f'{rel}:{i}', '행동 이름 정규식 → assets/js/changes.js'))
        for i, line in enumerate(src.split('\n'), 1):
            for m in re.finditer(r"(?:\$\$?|querySelector(?:All)?|closest|matches)\(`[^`]*#[\w-]*\$\{([^}]*)\}", line):
                if not m.group(1).startswith('CSS.escape('):
                    out.append(('선택자', f'{rel}:{i}', '# 선택자에 값을 그대로 넣음 → CSS.escape(값)'))
        for t in SERVER_TEXT:
            for i, line in enumerate(src.split('\n'), 1):
                if t in line and re.search(r"/[^/\n<>]*" + re.escape(t) + r"[^/\n<>]*/[gimsuy]*\s*(\.test|\.exec|,)|\.(includes|startsWith|indexOf)\(['`][^'`]*" + re.escape(t), line):
                    out.append(('서버 문구', f'{rel}:{i}', f'서버 문구 「{t}」를 읽음 → 응답 표시값으로'))
    html = (ROOT / 'index.html').read_text()
    for p in js_files():
        rel = p.relative_to(ROOT).as_posix()
        if rel not in NOT_PRELOADED and f'href="{rel}"' not in html:
            out.append(('미리 불러오기', rel, 'index.html modulepreload에 없음'))
    return out

def rpc_names():
    names = set()
    for p in js_files():
        names |= set(re.findall(r"(?:rpc|act|load|snap)\('(world_[a-z0-9_]+)'", p.read_text()))
    return names

def db_checks(run):
    out = []
    for t in json.loads(run(SQL['purge'])):
        if t not in ACCOUNT_TABLES:
            out.append(('캐릭터 정리', t, 'world_character_purge에 없고 계정 몫 목록(ACCOUNT_TABLES)에도 없음'))
    for k in json.loads(run(SQL['notes'])):
        if k not in UNMUTABLE_NOTES:
            out.append(('알림 갈래', k, 'world_notify_group 갈래 없음(끌 수 없게 둘 것이면 UNMUTABLE_NOTES에)'))
    for f in json.loads(run(SQL['anon'])):
        if f not in ANON_OK:
            out.append(('권한', f, '로그인 없이 부를 수 있는 security definer'))
    callable_ = set(json.loads(run(SQL['callable'])))
    for f in sorted(rpc_names() - callable_):
        out.append(('권한', f, '화면이 부르는데 authenticated 실행 권한 없음(또는 함수 없음)'))
    for f in json.loads(run(SQL['search_path'])):
        out.append(('권한', f, 'security definer인데 search_path 고정 없음'))
    return out

def main():
    args = sys.argv[1:]
    if args and args[0] == '--sql':
        for k, v in SQL.items():
            if k != 'callable':
                print(f'-- {k}\n{v};\n')
        names = ','.join(f"'{n}'" for n in sorted(rpc_names()))
        print(f"-- rpc\nselect coalesce(json_agg(x order by x), '[]') from unnest(array[{names}]) x where not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace and nspname = 'public' where p.proname = x and has_function_privilege('authenticated', p.oid, 'execute'));")
        return
    dsn = next((a.split('=', 1)[1] for a in args if a.startswith('--dsn=')), None)
    found = client_checks()
    if dsn:
        run = lambda q: subprocess.run(['psql', *dsn.split(), '-At', '-c', q], check=True, capture_output=True, text=True).stdout.strip() or '[]'
        found += db_checks(run)
    for kind, where, why in found:
        print(f'[{kind}] {where} — {why}')
    print(f'{len(found)}건' + ('' if dsn else ' (DB 점검은 --dsn=… 를 주면 함께 봄)'))
    sys.exit(1 if found else 0)

if __name__ == '__main__':
    main()
