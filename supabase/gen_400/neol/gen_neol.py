import os

HERE = os.path.dirname(os.path.abspath(__file__))
PARTS = ['a_rules.sql', 'b_engine.sql', 'c_patch.sql', 'd_flow.sql', 'e_rewards.sql', 'f_miss.sql']
NS = 'q:hw_nopsae'
QID = 'hws_rift_neol'
QUEST = dict(id=QID, cat='조사·파도너울성', title='흩어 보내는 사람들', region='pd_city', L=51, after=['hwq_5'], sort=1790,
             summary='높새가 뒤집힌 물목에 고인 물그림자를 흩어 보내며, 이 땅에서는 뭉친 것을 쓰러뜨리지 않고 흩어 보낸다는 것을 보여 준다.',
             items={'neol_drop': 2})


def n(t):
    return {'s': None, 't': t}


def s(t):
    return {'s': NS, 't': t}


STEPS = [
    dict(title='파도너울성 널다리에서 높새를 만난다', need={'at': ['pd_city']}, lines=[
        n('파도너울성 널다리 위로 저녁 물비린내가 밀려왔다. 높새가 처마 끝에 걸터앉아 젖은 날개를 털고 있었다.'),
        n('높새는 나를 보자 날개를 접고 널다리로 훌쩍 뛰어내렸다. 발목에 감은 붕대에 아직 물이 배어 있었다.'),
        s('마침 잘 왔어. 뒤집힌 물목 언저리에 또 그게 섰대. 물빛에 섞여 있다가 뒤에서 덮치는 그림자 말이야.'),
        n('높새가 허리춤의 부적 꾸러미를 풀어 한 장을 내게 내밀었다. 종이 끝이 짠물에 젖어 동그랗게 말려 있었다.'),
        s('본토에서는 요괴를 만나면 쓰러뜨린다며? 여기선 그런 걸 쓰러뜨린다고 하지 않아. 흩어 보낸다고 해.'),
        n('나는 무엇이 다르냐고 물었다. 높새는 잠깐 입술을 깨물더니 널다리 아래 고인 물웅덩이를 가리켰다.'),
        s('저 웅덩이처럼 요기가 흐르지 못하고 고이면 덩이가 돼. 덩이에는 이름도 바탕도 없어. 그러니 죽일 것도 없고, 풀어서 다시 흐르게 하면 그만이야.'),
        s('뒤집힌 물목에 가서 물그림자 셋만 흩어 줘. 나는 위에서 물길을 볼게. 흩어진 요기가 어디로 가는지 봐야 보고서에 제대로 적을 수 있거든.'),
    ]),
    dict(title='뒤집힌 물목에서 틈 언저리 물그림자를 흩어 보낸다', need={'at': ['pd_rift'], 'tasks': [{'t': 'win', 'm': ['hw_rift_3'], 'r': ['pd_rift'], 'n': 3}]}, lines=[
        n('마지막 물그림자가 쏴아 소리를 내며 무너졌다. 검은 물이 바닥에 흩어지더니 갈라진 바위 틈으로 졸졸 스며들었다.'),
        n('높새가 머리 위에서 크게 한 바퀴 돌고 내려앉았다. 날개깃 끝에서 짠물이 후두둑 떨어졌다.'),
        s('봤어? 쓰러진 게 아니라 흘러간 거야. 저 물은 이제 물목으로 돌아가서 다시 바다가 돼.'),
        n('높새는 무릎을 꿇고 손바닥으로 젖은 바위를 쓸었다. 손끝에 묻은 물이 한쪽으로 쪼르르 흘러내렸다.'),
        s('그런데 이상해. 요즘은 고이는 게 너무 잦아. 틈 둘레에 이것보다 훨씬 큰 것이 가끔 선다는 말도 들었어.'),
        n('나는 얼마나 크냐고 물었다. 높새가 고개를 들어 물목 너머 먼바다를 오래 바라보았다.'),
        s('뱃사람들은 「엉긴 너울」이라고 불러. 파도가 고인 채로 굳은 것처럼 생겼대. 그건 혼자서는 못 흩어. 여럿이 함께 들어야 해.'),
        s('흩어진 물이 어디로 갔는지 물목을 돌며 흔적을 더 찾아 줘. 물이 고이는 자리를 알면 큰 것이 설 곳도 짐작할 수 있어.'),
    ]),
    dict(title='뒤집힌 물목을 탐색해 물이 되돌아 고이는 자리를 찾는다', need={'at': ['pd_rift'], 'tasks': [{'t': 'clue', 'r': ['pd_rift'], 'n': 3}]}, lines=[
        n('바위 틈마다 물이 빠져나간 줄무늬가 남아 있었다. 줄무늬는 모두 바다 쪽으로 기울어 있었고, 한 곳만 거꾸로 물목 안쪽을 향했다.'),
        n('높새는 내가 적어 온 쪽지를 받아 들고 날개를 반쯤 펼친 채 한참 들여다보았다. 바닷바람에 쪽지 귀퉁이가 파르르 떨렸다.'),
        s('이 한 곳이 문제야. 물이 빠져나가지 못하고 되돌아와 고이는 자리. 이런 데서 너울이 일어서.'),
        s('너울이 서면 뱃사람들이 소리쳐 알릴 거야. 그땐 혼자 막아서지 마. 무게는 나눠 지고, 마른 사람은 적셔 주고, 굳은 심은 여럿이 같이 쳐야 풀려.'),
        n('높새는 쪽지를 접어 품에 넣고 나를 똑바로 보았다. 붕대 감은 발목이 젖은 바위 위에서 살짝 비틀렸다.'),
        s('나도 혼자 다 하려다 몇 번이나 물에 빠졌거든. 그러니까 너울이 서면 그때는 같이 가자.'),
        n('높새가 짧게 웃고 날개를 털었다. 흩어진 물방울이 노을빛을 받아 반짝이며 바다 쪽으로 날아갔다.'),
    ]),
]


def emit(J, TA, known, RID, fresh, errors, xp_need):
    out = [open(os.path.join(HERE, f), encoding='utf-8').read() for f in PARTS]
    q = QUEST
    fresh('quest_ids', [q['id']], '퀘스트 id')
    task_steps = [i + 1 for i, st in enumerate(STEPS) if st['need'].get('tasks') or st['need'].get('give')]
    per = round(0.4 * xp_need(q['L']) * 0.25) // max(1, len(task_steps))
    srows = []
    for i, st in enumerate(STEPS):
        step = i + 1
        rw = {'xp': per} if step in task_steps else {}
        if step == len(STEPS):
            rw['gil'] = 5 + 4 * q['L']
            rw['items'] = q['items']
        for t in st['need'].get('tasks', []):
            for rg in t.get('r', []):
                if rg not in RID: errors.append(f'너울 퀘스트 지역 없음: {rg}')
        srows.append(dict(quest_id=q['id'], step=step, title=st['title'], goal=st['title'], need=st['need'], lines=st['lines'], reward=rw))
    if q['region'] not in RID: errors.append(f"너울 퀘스트 지역 없음: {q['region']}")
    qrow = dict(quest_id=q['id'], cat=q['cat'], title=q['title'], summary=q['summary'], region_id=q['region'], min_level=q['L'], after=q['after'], sort=q['sort'], epilogue=[])
    out.append(f"""insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, sort, epilogue, active)
select x.quest_id, 'side', x.cat, x.title, x.summary, x.region_id, x.min_level, {TA('after')}, x.sort, x.epilogue, true
  from jsonb_to_recordset({J([qrow])}) as x(quest_id text, cat text, title text, summary text, region_id text, min_level int, after jsonb, sort int, epilogue jsonb)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  after = excluded.after, sort = excluded.sort, epilogue = excluded.epilogue, active = true;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward)
select x.quest_id, x.step, x.title, x.goal, x.need, x.lines, x.reward
  from jsonb_to_recordset({J(srows)}) as x(quest_id text, step int, title text, goal text, need jsonb, lines jsonb, reward jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;""")
    return '\n'.join(out)
