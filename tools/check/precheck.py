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
    'world_events', 'world_chat_messages', 'world_party_messages', 'world_circles', 'world_circle_invites',
    'world_gwiryeong_plants', 'world_case_state', 'world_party_loot_pool',
}
UNUSED_OK = {'pet_token'}
HQ_OK_JS = {'QS_DEFAULT'}
HQ_OK_FN = {'world_case_combine_regional'}
BASE_KEYED = re.compile(r"\.output\s*===\s*([\w$.]+)|ingredients\??\.?\[([\w$.]+)\]|lore\.items\??\.?\[([\w$.]+)\]|l\.items\??\.?\[([\w$.]+)\]")
HQ_HELPERS = re.compile(r'\b(withHq|haveOf|hqCount|bothOf|hqOf|baseOf|pairOf)\(')
UNMUTABLE_NOTES = {'bug_reply', 'bug_report', 'rescued', 'yohwa', 'death', 'system', 'drawing_removed', 'guide'}
ANON_OK = {'world_app_version'}
NOT_PRELOADED = {'assets/js/boot.js', 'assets/js/maintenance.js'}
SERVER_TEXT = ['쏠 것이 떨어져', '기력이 바닥나', '영력이 바닥나', '초 남음', '의 피해']

SQL = {
    'purge': """with t as (select distinct c.table_name from information_schema.columns c join information_schema.tables tb on tb.table_name = c.table_name and tb.table_schema = 'public' and tb.table_type = 'BASE TABLE'
  where c.table_schema = 'public' and c.column_name in ('owner_id', 'character_id', 'user_id') and c.table_name like 'world\\_%'
  union select distinct r.relname from pg_constraint k join pg_class r on r.oid = k.conrelid join pg_namespace n on n.oid = r.relnamespace
  where k.contype = 'f' and n.nspname = 'public' and r.relkind = 'r' and r.relname like 'world\\_%' and k.confrelid = 'auth.users'::regclass),
 s as (select string_agg(prosrc, ' ') src from pg_proc where proname in ('world_character_purge', 'world_character_delete'))
select coalesce(json_agg(t.table_name order by t.table_name), '[]') from t, s where position(t.table_name in s.src) = 0""",
    'notes': """select coalesce(json_agg(distinct k), '[]') from (select (regexp_matches(prosrc, 'world_notifications[^;]*?values\\s*\\([^,]*,\\s*''([a-z_0-9]+)''', 'gi'))[1] k from pg_proc
  union all select (regexp_matches(prosrc, 'world_notifications\\s*\\([^)]*\\)\\s*select\\s+[^,]+?,\\s*''([a-z_0-9]+)''', 'gi'))[1] from pg_proc) x
where public.world_notify_group(k) is null""",
    'anon': """select coalesce(json_agg(proname order by proname), '[]') from pg_proc p join pg_namespace n on n.oid = p.pronamespace and nspname = 'public'
where prosecdef and has_function_privilege('anon', p.oid, 'execute')""",
    'callable': """select coalesce(json_agg(proname), '[]') from pg_proc p join pg_namespace n on n.oid = p.pronamespace and nspname = 'public'
where proname like 'world\\_%' and has_function_privilege('authenticated', p.oid, 'execute')""",
    'unused': """select coalesce(json_agg(i.item_id order by i.item_id), '[]') from public.world_item_catalog i
where (i.category = 'material' or exists (select 1 from public.world_fish_species f where f.fish_id = i.item_id)) and i.base_item_id is null
  and not exists (select 1 from public.world_crafting_recipes r where r.ingredients ? i.item_id)""",
    'tool_gaps': """select coalesce(json_agg(line order by line), '[]') from (select l.line, min(c.tier) lo, max(c.tier) hi, count(distinct c.tier) n
  from public.world_tool_lines l join public.world_item_catalog c on c.item_id = l.item_id group by l.line) x where n < hi - lo + 1""",
    'my_fight': """select coalesce(to_json(pg_get_functiondef('public.world_my_fight(uuid)'::regprocedure)), '\"\"')""",
    'bait': """select coalesce(json_agg(t order by t), '[]') from (select t from public.world_fish_species s, unnest(s.bait_for) t group by t having count(*) < 3) x""",
    'hq_ids': """select coalesce(json_agg(distinct base_item_id), '[]') from public.world_item_catalog where base_item_id is not null""",
    'hq_read': """with hq as (select distinct base_item_id b from public.world_item_catalog where base_item_id is not null)
select coalesce(json_agg(json_build_array(proname, ids) order by proname), '[]') from (select p.proname, string_agg(distinct hq.b, ',') ids from pg_proc p join pg_namespace n on n.oid = p.pronamespace and nspname = 'public'
  join hq on p.prosrc ~ ('(->>|->|\\?)\\s*''' || hq.b || '''')
  where p.proname like 'world\\_%' and p.prosrc not like '%world_item_base%' and p.prosrc not like '%\\_hq%' group by p.proname) x""",
    'search_path': """select coalesce(json_agg(proname order by proname), '[]') from pg_proc p join pg_namespace n on n.oid = p.pronamespace and nspname = 'public'
where prosecdef and proname like 'world\\_%' and not exists (select 1 from unnest(coalesce(proconfig, '{}')) c where c like 'search_path=%')""",
}

def js_files():
    return sorted(p for p in JS.rglob('*.js') if 'gamedata' not in p.name)

def fight_kinds():
    src = (JS / 'rules.js').read_text()
    body = re.search(r"FIGHT_KINDS = \{(.*?)\n\};", src, re.S)
    return dict(re.findall(r"(\w+): \{ route: '([\w-]+)'", body.group(1))) if body else {}

def client_checks():
    out = []
    routes = set(fight_kinds().values())
    for p in sorted((JS / 'views').glob('*.js')):
        if p.name != 'fightui.js' and re.search(r'\bsettleFight\b', p.read_text()) and p.stem not in routes:
            out.append(('싸움 돌아가기', p.relative_to(ROOT).as_posix(), '싸움 화면인데 rules.js FIGHT_KINDS·world_my_fight에 없음 → 화면을 벗어나면 돌아올 길이 없음'))
    for p in js_files():
        rel = p.relative_to(ROOT).as_posix()
        src = p.read_text()
        if p.name != 'hq.js':
            for i, line in enumerate(src.split('\n'), 1):
                if re.search(r"_hq\b|'_hq'|endsWith\('_hq'\)", line):
                    out.append(('우수품', f'{rel}:{i}', '_hq를 직접 다룸 → assets/js/hq.js'))
        for i, line in enumerate(src.split('\n'), 1):
            for m in BASE_KEYED.finditer(line):
                v = next(g for g in m.groups() if g)
                if v != 'bid' and 'baseOf(' not in line:
                    out.append(('우수품', f'{rel}:{i}', f'제작법·내력은 보통 물품 id로 적혀 있음 → {v}를 baseOf로'))
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
    my = json.loads(run(SQL['my_fight']))
    for k in fight_kinds():
        if f"'kind', '{k}'" not in my:
            out.append(('싸움 돌아가기', k, 'rules.js FIGHT_KINDS에 있는데 world_my_fight가 이 싸움을 돌려주지 않음'))
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
    for i in json.loads(run(SQL['unused'])):
        if i not in UNUSED_OK:
            out.append(('제작 소모처', i, '재료·어종인데 어느 제작법에도 안 쓰임'))
    for l in json.loads(run(SQL['tool_gaps'])):
        out.append(('도구 사슬', l, 'world_tool_lines 단계가 중간에 빠짐'))
    for t in json.loads(run(SQL['bait'])):
        out.append(('명어 미끼', t, '미끼가 되는 물고기가 셋보다 적음'))
    for f, ids in json.loads(run(SQL['hq_read'])):
        if f not in HQ_OK_FN:
            out.append(('우수품', f, f'가방에서 {ids}을(를) 이름으로 읽는데 우수품 처리(world_item_base·_hq)가 없음'))
    hq = set(json.loads(run(SQL['hq_ids'])))
    for p in js_files():
        rel = p.relative_to(ROOT).as_posix()
        text = p.read_text()
        for i, line in enumerate(text.splitlines(), 1):
            for m in re.finditer(r"\[([^\[\]]*)\]", line):
                ids = re.findall(r"'([a-z][a-z0-9_]*)'", m.group(1))
                if sum(1 for x in ids if x in hq) < 2:
                    continue
                name = re.search(r'(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*$', line[:m.start()])
                if name and name.group(1) in HQ_OK_JS:
                    continue
                used = re.search(rf'\b{re.escape(name.group(1))}\b', '\n'.join(l for l in text.splitlines() if HQ_HELPERS.search(l))) if name else HQ_HELPERS.search(line)
                if not used:
                    out.append(('우수품', f'{rel}:{i}', '우수품이 있는 물품 목록인데 hq.js(withHq·haveOf·hqCount·baseOf …)를 거치지 않음'))
    for f in json.loads(run(SQL['search_path'])):
        out.append(('권한', f, 'security definer인데 search_path 고정 없음'))
    return out

ESLINT = 'eslint@8.57.0'

def undefined_names():
    files = [p.relative_to(ROOT).as_posix() for p in js_files()]
    cmd = ['npx', '--yes', ESLINT, '--no-eslintrc', '--env', 'browser,es2022', '--parser-options=sourceType:module',
           '--parser-options=ecmaVersion:2022', '--rule', '{"no-undef":"error","no-dupe-keys":"error","no-const-assign":"error"}', '-f', 'json', *files]
    try:
        r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=600)
        res = json.loads(r.stdout or '[]')
    except Exception as e:
        return [('이름 검사', 'eslint', f'돌리지 못함({e.__class__.__name__}) — 배포 전에 반드시 돌릴 것')]
    out = []
    for f in res:
        rel = pathlib.Path(f['filePath']).resolve().relative_to(ROOT).as_posix()
        for m in f['messages']:
            out.append(('이름 검사', f"{rel}:{m.get('line')}", m.get('message', '')))
    return out

def import_names():
    out = []
    exp_re = re.compile(r'export\s+(?:async\s+)?(?:function\*?|const|let|var|class)\s+([A-Za-z_$][\w$]*)')
    cache = {}
    def exports(path):
        if path not in cache:
            src = path.read_text() if path.exists() else ''
            names = set(exp_re.findall(src))
            for line in re.findall(r'^export\s+(?:const|let|var)\s+[^\n]*', src, re.M):
                names.update(re.findall(r'(?:^export\s+(?:const|let|var)\s+|,\s*)([A-Za-z_$][\w$]*)\s*=(?!=)', line))
            for grp in re.findall(r'export\s*\{([^}]*)\}', src):
                for part in grp.split(','):
                    part = part.strip()
                    if part:
                        names.add(part.split(' as ')[-1].strip())
            if re.search(r'export\s+default', src):
                names.add('default')
            cache[path] = names
        return cache[path]
    for p in js_files():
        src = p.read_text()
        for m in re.finditer(r"import\s*\{([^}]*)\}\s*from\s*'(\.[^']+)'", src):
            target = (p.parent / m.group(2)).resolve()
            have = exports(target)
            for part in m.group(1).split(','):
                name = part.strip().split(' as ')[0].strip()
                if name and name not in have:
                    line = src[:m.start()].count('\n') + 1
                    out.append(('가져오기', f'{p.relative_to(ROOT).as_posix()}:{line}', f'{name}은(는) {m.group(2)}에 없음'))
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
    found = client_checks() + import_names() + undefined_names()
    if dsn:
        run = lambda q: subprocess.run(['psql', *dsn.split(), '-At', '-c', q], check=True, capture_output=True, text=True).stdout.strip() or '[]'
        found += db_checks(run)
    for kind, where, why in found:
        print(f'[{kind}] {where} — {why}')
    print(f'{len(found)}건' + ('' if dsn else ' (DB 점검은 --dsn=… 를 주면 함께 봄)'))
    sys.exit(1 if found else 0)

if __name__ == '__main__':
    main()
