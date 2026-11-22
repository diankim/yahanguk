import json, re, sys, glob, os, hashlib

HERE = os.path.dirname(os.path.abspath(__file__))
LINE = re.compile(r'^- (\{[^{}]*\} )?(?:S: (.*)|\[([^\]]+)\] \((?:[^()]|\([^()]*\))*\) (.*))$')


def parse(path, fix_ellipsis):
    quests = {}
    cur = scene = None
    skip = False
    for raw in open(path, encoding='utf-8'):
        ln = raw.rstrip('\n')
        m = re.match(r'^## (\S+)$', ln)
        if ln.startswith('## '):
            cur = scene = None
            skip = False
            if m and m.group(1) not in ('검사', '제안'):
                cur = m.group(1)
                quests[cur] = []
            continue
        if cur is None:
            continue
        m = re.match(r'^### (\d+) · (.*)$', ln)
        if m:
            scene = {'step': int(m.group(1)), 'title': m.group(2), 'goal': None, 'lines': []}
            quests[cur].append(scene)
            skip = False
            continue
        if ln.startswith('#### '):
            skip = True
            continue
        if skip or scene is None:
            continue
        if ln.startswith('할 일:'):
            scene['goal'] = ln[len('할 일:'):].strip()
            continue
        if not ln.startswith('- '):
            if ln.strip():
                raise SystemExit(f'{path}: {cur} {scene["step"]}: 알 수 없는 줄 {ln!r}')
            continue
        m = LINE.match(ln)
        if not m:
            raise SystemExit(f'{path}: {cur} {scene["step"]}: 줄 꼴이 틀림 {ln!r}')
        extra = json.loads(m.group(1)) if m.group(1) else {}
        if m.group(2) is not None:
            item = {'s': None, 't': m.group(2)}
        else:
            item = {'s': m.group(3), 't': m.group(4)}
        if fix_ellipsis:
            item['t'] = item['t'].replace('……', '…')
        item.update(extra)
        scene['lines'].append(item)
    return quests


def load(folder, fix_ellipsis):
    out = {}
    for f in sorted(glob.glob(os.path.join(HERE, folder, 'part_*.md'))):
        for k, v in parse(f, fix_ellipsis).items():
            if k in out:
                raise SystemExit(f'겹친 퀘스트 {k}')
            out[k] = v
    return out


def q(s):
    return "'" + s.replace("'", "''") + "'"


def dollar(s):
    tag = '$J$'
    assert tag not in s
    return tag + s + tag


def sql(data, guard):
    rows = []
    for qid, scenes in data.items():
        for sc in scenes:
            rows.append({'q': qid, 'n': sc['step'], 'title': sc['title'], 'goal': sc['goal'], 'lines': sc['lines']})
    body = json.dumps(rows, ensure_ascii=False, separators=(',', ':'))
    g = json.dumps(guard, ensure_ascii=False)
    return f"""create temp table yh_sq on commit drop as
select * from jsonb_to_recordset({dollar(body)}::jsonb) as x(q text, n int, title text, goal text, lines jsonb);
do $m$
declare bad text;
begin
  select string_agg(z.quest_id, ', ' order by z.quest_id) into bad
    from (select s.quest_id, left(md5(string_agg(s.step || coalesce(s.lines::text, '') || coalesce(s.title, '') || coalesce(s.goal, ''), '|' order by s.step)), 6) m
            from public.world_quest_steps s where s.quest_id in (select jsonb_object_keys({dollar(g)}::jsonb)) group by s.quest_id) z
   where z.m <> {dollar(g)}::jsonb ->> z.quest_id;
  if bad is not null then raise exception '배포 뒤 바뀐 퀘스트가 있어 멈춤: %', bad; end if;
  select string_agg(x.q || ':' || x.n, ', ') into bad
    from yh_sq x left join public.world_quest_steps s on s.quest_id = x.q and s.step = x.n
   where s.quest_id is null or s.title is distinct from x.title;
  if bad is not null then raise exception '장면이 맞지 않음: %', bad; end if;
  if (select count(*) from yh_sq) <> (select count(*) from public.world_quest_steps where quest_id in (select q from yh_sq)) then
    raise exception '장면 수가 맞지 않음';
  end if;
  update public.world_quest_steps s set lines = x.lines, goal = x.goal
    from yh_sq x where s.quest_id = x.q and s.step = x.n;
end $m$;
"""


TAIL = """
insert into public.world_quest_npcs(npc_key, npc_name, bio) values
('q:sn_cheongseok', '연맹 잠수꾼 청석', '수향연맹에서 가장 숨이 긴 잠수꾼. 동생 흑파와 늘 짝을 지어 잠수했다. 청파의 삼촌이다.')
on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;
update public.world_quest_npcs set bio = '수향연맹 잠수꾼 가운데 막내이자 청씨 선단의 막내 증손. 물속에서 숨을 가장 오래 참는 아이다.' where npc_key = 'q:sn_cheongpa';
update public.world_quest_npcs set npc_name = '빙하지기 한서리' where npc_key = 'q:r220_hanseol';

select public.world_quest_label_refresh();

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261125020000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
"""


if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'src':
        print(sql(load('src', False), {}).replace("raise exception '배포 뒤", "raise notice '배포 뒤"))
    else:
        guard = dict(x.split(':') for x in open(sys.argv[2]).read().split())
        print(sql(load('out', True), guard) + TAIL)
