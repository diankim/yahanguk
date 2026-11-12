import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
CAT = '외전·묵적록'
SPEAK = {'서술': None, '희수': 'q:mk_hisu', '다온': 'q:mk_daon', '월하': 'q:mk_wolha', '먹그림자': 'q:mk_shadow', '먹귀': 'q:mk_meok',
         '서율': 'q:mk_seoyul', '서하': 'q:mk_seoha'}
NPCS = {
    'q:mk_hisu': ('정청 서리 희수', '정청 출납 서리. 묵창 나루 주민 명부의 대조를 맡았다. 평생 틀리지 않으려고 쓴 손을 가졌다.'),
    'q:mk_daon': ('다온', '묵창 나루의 열 살 남짓한 아이. 부모 없이 문패가 다 지워진 집에 산다. 공책에 이름을 적어 두면 안 잊는다고 믿는다.'),
    'q:mk_wolha': ('월하', '흑련회 이름 거둠꾼. 「월하」는 부르는 이름이고 본명은 흑련회 회원 장부에 맡겨 두었다.'),
    'q:mk_shadow': ('먹그림자', '먹으로 그린 사람의 윤곽. 주인공과 같은 말투로 제 이야기를 한다.'),
    'q:mk_meok': ('먹귀', '이름을 잃은 동안 주인공 자리에 붙는 이름표.'),
    'q:mk_seoyul': ('서율', '옛 정청 조사원. 서하의 오라버니. 기억 조각 속의 목소리.'),
    'q:mk_seoha': ('서하', '기억 조각 속의 아이.'),
}

FERRY, FIELD, FOREST, TOWER, COURT, HQ = 'mukchang_ferry', 'blank_field', 'meokbi_forest', 'myeongbu_tower', 'nine_court', 'hq_yard'

FIX = {
    (1, 2): [
        ('선창 끝에 아이 하나가 쓰러져 있었다.', '나루 끝 강둑에 아이 하나가 쓰러져 있었다.'),
        ('희수: 아이는 제가 집에 데려다주겠습니다. 그동안 나루 안쪽에 저런 것이 더 있는지 둘러봐 주세요.',
         '희수: 아이는 제가 집에 데려다주겠습니다. 그동안 나루 바깥 강둑 쪽에 저런 것이 더 있는지 둘러봐 주세요. 강둑을 따라가면 빈칸 벌판 어귀가 나옵니다.'),
    ],
    (1, 3): [
        ('나루를 도는 내내 발소리 하나가 몇 걸음 뒤에서 따라왔다.', '강둑을 따라 벌판 어귀를 돌고 나루로 돌아오는 내내, 발소리 하나가 몇 걸음 뒤에서 따라왔다.'),
        ('선창에서 쓰러져 있던 아이였다.', '강둑에 쓰러져 있던 아이였다.'),
        ('희수: 먹귀가 저 아이한테만 유독 자주 붙습니다. 그 집이 걸려요. 오늘 밤은 아이 집 근처에서 쉬어 주시겠습니까.',
         '희수: 먹귀가 저 아이한테만 유독 자주 붙습니다. 그 집이 걸려요. 오늘 밤은 주막에 묵으며 쉬어 주시겠습니까. 아이 집이 주막 바로 뒤예요.'),
    ],
    (3, 4): [
        ('희수: 서율 조사원. 서고에 그분 보고서가 몇 장 남아 있어요. 내일 보여 드릴게요.',
         '희수: 서율 조사원. 서고에 그분 보고서가 몇 장 남아 있어요. 오늘 밤 사람을 보내 정청 서고에서 가져오게 할 테니, 내일 이 주막으로 와 주세요. 거기서 보여 드릴게요.'),
    ],
    (3, 5): [
        ('희수가 가져온 보고서는 누렇게 바래 있었다.', '이튿날 주막으로 가자, 희수가 정청 서고에서 가져온 보고서를 펼쳐 놓고 있었다. 보고서는 누렇게 바래 있었다.'),
    ],
    (3, 8): [
        ('희수: 조사원. 정청에서 연락이 왔어요. 나루 사정이 나빠지고 있습니다.',
         '희수: 조사원. 정청에서 연락이 왔어요. 나루 사정이 나빠지고 있습니다. 먹귀가 빈칸 벌판에서 나루로 들어오는 길목으로 원정을 한 번 다녀와 주세요. 어디로 새어 드는지 봐야 해요.'),
    ],
    (4, 1): [
        ('희수: 조사원, 다온은 어디 있어요?', '희수: 조사원, 다온은 어디 있어요? 벌판 원정에서 돌아오는 길에 아이 집에 들러 봐 주세요. 나루 안쪽, 문패가 다 지워진 집이에요.'),
    ],
    (4, 2): [
        ('다온은 마루에 엎드려 공책을 쓰고 있었다.', '벌판 원정에서 나루로 돌아와, 문패가 다 지워진 집 앞에 섰다. 안에서 붓 소리가 났다. 다온은 마루에 엎드려 공책을 쓰고 있었다.'),
    ],
}

PLAN = {
    1: dict(id='mkq_1', L=40, region=FERRY, after=['gq_5'], items={'name_ink_charm': 2, 'erased_plate': 2},
            summary='묵창 나루의 주민 명부에서 이름이 하나둘 흐려진다. 정청 서리 희수와 함께 먹빛 강가의 나루로 간다.',
            steps=[
                ('정청 대청에서 출납 서리 희수를 만난다', {'at': [HQ]}),
                ('노정 건량 3개를 지어 묵창 나루로 간다', {'at': [FERRY], 'tasks': [{'t': 'craft', 'items': ['travel_ration'], 'n': 3}, {'t': 'travel', 'r': [FERRY], 'n': 1}]}),
                ('빈칸 벌판 어귀를 3번 탐색한 뒤 묵창 나루로 돌아온다', {'at': [FERRY], 'tasks': [{'t': 'search', 'r': [FIELD], 'n': 3}]}),
                ('묵창 나루 주막에서 쉰다', {'at': [FERRY], 'tasks': [{'t': 'rest', 'r': [FERRY], 'n': 1}]}),
                ('묵창 나루 선창에서 물고기를 1마리 낚아 주막의 희수에게 간다', {'at': [FERRY], 'tasks': [{'t': 'fish', 'r': [FERRY], 'n': 1}]}),
                ('빈칸 벌판 어귀 물가에서 묵창 갈대 먹 2개를 걷어 묵창 나루 주막으로 가져온다', {'at': [FERRY], 'tasks': [{'t': 'gather', 'items': ['mukchang_ink'], 'r': [FIELD], 'n': 2}]}),
            ]),
    2: dict(id='mkq_2', L=41, region=FIELD, after=['mkq_1'], items={'meokgwi_incense': 2, 'blank_hanji': 3},
            summary='정청이 먹귀를 가둬 두던 빈칸 벌판의 테가 터졌다. 이름을 들을 수 있는 사람은 나 하나다.',
            steps=[
                ('빈칸 벌판 어귀에서 희수를 만난다', {'at': [FIELD]}),
                ('빈칸 벌판에서 떠도는 먹귀를 8번 풀어 보낸다', {'at': [FIELD], 'tasks': [{'t': 'win', 'm': ['mk_field_1'], 'n': 8}]}),
                ('빈칸 벌판을 탐색해 먹귀가 우는 곳의 실마리를 찾는다', {'at': [FIELD], 'tasks': [{'t': 'clue', 'r': [FIELD], 'n': 1}]}),
                ('억새 그늘에 숨은 문패 뜯는 손을 5번 풀어 보낸다', {'at': [FIELD], 'tasks': [{'t': 'win', 'm': ['mk_field_3'], 'n': 5}]}),
                ('다온을 따라 빈칸 벌판의 이름 없는 사당을 찾는다', {'at': [FIELD], 'tasks': [{'t': 'search', 'r': [FIELD], 'n': 2}]}),
                ('빈칸 벌판에서 지워진 문패 조각 2개를 주워 묵창 나루로 돌아가 희수에게 손을 보인다', {'at': [FERRY], 'tasks': [{'t': 'gather', 'items': ['erased_plate'], 'r': [FIELD], 'n': 2}, {'t': 'travel', 'r': [FERRY], 'n': 1}]}),
            ]),
    3: dict(id='mkq_3', L=42, region=FERRY, after=['mkq_2'], items={'meokbi_umbrella': 2, 'meokbi_moss': 3},
            summary='남의 꿈을 꾸고, 팔에 먹 무늬가 번진다. 먹비 숲에서 옛 조사원 서율의 흔적을 찾는다.',
            steps=[
                ('묵창 나루에서 아침을 맞는다', {'at': [FERRY]}),
                ('먹비 숲에서 먹비 이끼(먹비 맞은 잎) 3개를 거둬 묵창 나루로 가져온다', {'at': [FERRY], 'tasks': [{'t': 'gather', 'items': ['meokbi_moss'], 'r': [FOREST], 'n': 3}]}),
                ('희수가 올 때까지 자율 활동을 한 번 끝까지 마친다', {'at': [FERRY], 'tasks': [{'t': 'idle', 'n': 1}]}),
                ('밤에 묵창 나루 주막의 희수에게 팔을 보이고 창밖 목소리를 알린다', {'at': [FERRY]}),
                ('주막 방에서 자율 활동 「휴식」을 끝까지 하고 이튿날 희수에게 옛 보고서를 받는다', {'at': [FERRY], 'tasks': [{'t': 'idle', 'k': 'rest', 'n': 1}]}),
                ('먹비 숲으로 가서 원정을 한 번 끝까지 다녀와 옛 조사원 숙소를 찾는다', {'at': [FOREST], 'tasks': [{'t': 'travel', 'r': [FOREST], 'n': 1}, {'t': 'expedition', 'r': [FOREST], 'n': 1}]}),
                ('숙소 앞에 몰려든 먹비 반딧불 떼를 5번 풀어 보낸다', {'at': [FOREST], 'tasks': [{'t': 'win', 'm': ['mk_forest_3'], 'n': 5}]}),
                ('묵창 나루로 돌아가 주막에서 쉰다', {'at': [FERRY], 'tasks': [{'t': 'travel', 'r': [FERRY], 'n': 1}, {'t': 'rest', 'r': [FERRY], 'n': 1}]}),
            ]),
    4: dict(id='mkq_4', L=44, region=FERRY, after=['mkq_3'], items={'name_ink_charm': 3, 'register_slip': 3},
            summary='나루에 엉킴이 번진다. 정청은 다온의 이름을 거두기로 한다. 마을 먹귀가 모인 명부 탑으로 오른다.',
            steps=[
                ('묵창 나루에서 희수를 만난다', {'at': [FERRY]}),
                ('빈칸 벌판으로 원정을 한 번 다녀오고, 묵창 나루 안쪽 다온의 집에 간다', {'at': [FERRY], 'tasks': [{'t': 'expedition', 'r': [FIELD], 'n': 1}]}),
                ('묵창 나루의 희수에게 간다', {'at': [FERRY]}),
                ('이름 먹 부적 2장을 지어 명부 탑으로 간다', {'at': [TOWER], 'tasks': [{'t': 'craft', 'items': ['name_ink_charm'], 'n': 2}, {'t': 'travel', 'r': [TOWER], 'n': 1}]}),
                ('명부 탑에서 먹귀를 10번 풀어 보낸다', {'at': [TOWER], 'tasks': [{'t': 'win', 'r': [TOWER], 'n': 10}]}),
                ('명부 탑을 3번 탐색해 꼭대기로 오른다', {'at': [TOWER], 'tasks': [{'t': 'search', 'r': [TOWER], 'n': 3}]}),
                ('탑 꼭대기의 엉킨 먹귀 무리를 세 번 풀어 보낸다', {'at': [TOWER], 'tasks': [{'t': 'win', 'm': ['mk_tower_5'], 'n': 3}]}),
                ('명부 탑 꼭대기에서 이어진다', {'at': [TOWER]}),
            ]),
    5: dict(id='mkq_5', L=45, region=COURT, after=['mkq_4'], items={'name_ink_charm': 3, 'drifting_name_thread': 3},
            summary='매듭 안쪽, 아홉 칸 명부. 먹그림자와 마주하고 돌아오는 이름을 듣는다.',
            steps=[
                ('아홉 칸 뜰에서 눈을 뜬다', {'at': [COURT]}),
                ('아홉 칸 명부에서 먹그림자와 싸운다', {'at': [COURT], 'tasks': [{'t': 'mj', 'mode': 'story', 'n': 1}]}),
                ('아홉 칸 뜰에서 이어진다', {'at': [COURT]}),
                ('아홉 칸 뜰에서 이어진다', {'at': [COURT]}),
            ]),
}


EXTRA = dict(id='mkq_x', title='다시 쓰는 명부', L=45, region=FERRY, after=['mkq_5'], items={'meokgwi_lump': 2},
    summary='희수가 일부러 틀리게 쓴 회수 명부의 줄이 닫히지 않아, 명부 탑의 먹이 아홉 칸 뜰로 새어 내려온다. 이름 없는 그림자를 깊은 명부에서 보낸다.',
    steps=[
        ('묵창 나루 주막에서 희수를 만난다', {'at': [FERRY]}, '틀린 획', [
            ('서술', '아홉 칸 뜰에서 깨어난 지 이레가 지났다. 손등의 먹 자국은 아직 옅게 남아 있었다.'),
            ('서술', '묵창 나루 주막에 들어서자 희수가 마루에 장부 두 권을 나란히 펼쳐 놓고 있었다. 한 권은 정청 명부였고, 다른 한 권은 회수 명부였다.'),
            ('서술', '희수는 나를 보더니 회수 명부의 한 줄을 손가락으로 짚었다. 마지막 획이 엇나간 내 이름이었다.'),
            ('희수', '그날 탑 아래에서 제가 일부러 틀리게 쓴 줄입니다. 틀린 기록은 무효가 되니까요. 그래서 조사원은 거둬지지 않았습니다.'),
            ('서술', '희수는 잠깐 말을 멈추고 장부 가장자리를 손끝으로 눌렀다.'),
            ('희수', '그런데 무효가 된 줄은 닫히지도 않습니다. 회수가 끝나지 않은 채로 열려 있어요. 아홉 칸 뜰의 봉인진도 이 줄에 묶여 반쯤 열린 채입니다.'),
            ('서술', '마루 끝에서 공책에 무언가를 적던 다온이 고개를 들었다.'),
            ('다온', '열려 있으면 어떻게 돼요, 서리님?'),
            ('서술', '희수는 다온 쪽으로 몸을 돌려 대답했다.'),
            ('희수', '탑에 쌓인 먹이 새어 내려와. 밤마다 뜰에 고이고.'),
            ('서술', '희수가 다시 나를 보았다.'),
            ('희수', '이 줄을 바르게 고쳐 쓰려면 봉인진이 깨끗해야 합니다. 먼저 먹이 어디서 새는지 봐야겠어요. 명부 탑을 두 번쯤 살펴봐 주세요. 저는 고쳐 쓸 먹을 갈아 두겠습니다.'),
            ('서술', '나는 명부 탑에 다녀오겠다고 했다.'),
        ]),
        ('명부 탑을 2번 탐색해 먹이 새는 곳을 찾는다', {'at': [TOWER], 'tasks': [{'t': 'search', 'r': [TOWER], 'n': 2}]}, '이름이 붙지 않은 먹', [
            ('서술', '명부 탑의 원부 서고는 조용했다. 칸마다 꽂힌 원부의 등에서 먹이 한 방울씩 맺혀 떨어지고 있었다.'),
            ('서술', '떨어진 먹은 바닥 틈을 따라 한 줄기로 모여 계단 아래로 흘러갔다. 줄기가 향하는 곳은 아홉 칸 뜰이었다.'),
            ('서술', '계단참에 누군가 쭈그려 앉아 그 줄기를 들여다보고 있었다. 월하였다. 그는 손가락에 먹을 찍어 비벼 보더니 혀를 찼다.'),
            ('월하', '조사원도 왔네요. 이거 팔아 보려고 왔는데 글렀어요. 이름이 하나도 안 붙어 있거든.'),
            ('서술', '월하는 먹 묻은 손가락을 소맷자락에 문질러 닦았다.'),
            ('월하', '정청이 오래 거둔 이름들에서 빠져나온 찌꺼기예요. 누구 것인지 모르니 살 사람도 없고, 불러 줄 이름도 없죠. 서율 기억 부스러기도 좀 섞여 있을 거고.'),
            ('서술', '나는 계단 아래를 내려다보았다. 뜰 바닥에 고인 먹이 천천히 일어서고 있었다. 붓을 쥔 손과 기울어진 고개가 보였다. 매듭 안쪽에서 마주했던 모습이었다.'),
            ('서술', '그러나 그 얼굴 어디에도 서율은 없었다.'),
            ('서술', '월하가 손등 위로 굴리던 엽전을 멈추고 나를 흘끗 보았다.'),
            ('월하', '저건 서율이 아니에요. 서율이 남기고 간 버릇이지. 지우던 버릇이요. 이름이 없으니 불러서 보낼 수도 없어요. 그때보다 깊은 칸에서 힘으로 밀어내야 할 거예요.'),
            ('서술', '월하는 일어서서 무릎을 털었다.'),
            ('월하', '뜰에 내려가려면 테두리부터 묶어야 해요. 묵창 주막에서 봉인 먹줄 하나 챙기고요. 나는 여기서 먹 흐르는 거나 구경할게요. 공짜 구경은 흑련회도 안 막거든.'),
            ('서술', '나는 봉인 먹줄을 챙겨 깊은 명부에서 그림자를 보낸 뒤, 묵창 나루로 가서 희수에게 알리겠다고 했다.'),
        ]),
        ('봉인 먹줄을 챙겨 깊은 명부에서 먹그림자를 보내고 묵창 나루로 돌아간다', {'at': [FERRY], 'tasks': [{'t': 'mj', 'n': 1}]}, '다시 쓰는 명부', [
            ('서술', '깊은 명부에서 돌아오자 뜰 바닥의 먹은 말라 있었다. 탑 계단을 타고 내려오던 먹 줄기도 끊겨 있었다.'),
            ('서술', '묵창 주막에서는 희수가 갈아 둔 먹에 붓을 적신 채 기다리고 있었다. 내가 마른 뜰 이야기를 하자 희수는 고개를 한 번 끄덕였다.'),
            ('희수', '흑련회 분이 먼저 다녀가셨습니다. 장사를 공쳤다고 하시더군요. 그럼 지금 고쳐 쓰겠습니다.'),
            ('서술', '희수는 회수 명부의 엇나간 줄 위에 두 줄을 곧게 그었다. 그리고 그 옆 여백에 작은 글씨로 적었다.'),
            ('서술', '「회수하지 않음. 정청 서리 희수.」'),
            ('서술', '이번에는 획 하나도 엇나가지 않았다. 희수는 붓을 내려놓고 나서야 숨을 내쉬었다.'),
            ('희수', '이제 틀린 기록이 아닙니다. 조사원은 남는 사람으로, 바르게 적혔어요.'),
            ('서술', '희수는 장부를 덮으려다 손을 멈추고 창밖의 명부 탑을 올려다보았다.'),
            ('희수', '다만 탑에 쌓인 이름이 너무 많습니다. 줄은 닫았지만, 오래 거둔 먹은 앞으로도 밤마다 조금씩 뜰로 내려올 거예요.'),
            ('서술', '희수는 머뭇거리다 말을 이었다. 문장이 짧게 끊겼다.'),
            ('희수', '염치없는 부탁이지만. 가끔. 뜰에 들러 주시겠어요?'),
            ('서술', '나는 그러겠다고 했다.'),
            ('서술', '마루 끝에서 다온이 공책 맨 뒷장을 펼쳤다. 풀어 보낸 이름들 아래 빈 줄에 붓끝을 대고 한참 고민하더니, 작은 글씨로 적었다.'),
            ('서술', '「이름 모름. 따라 함.」'),
            ('다온', '이름은 없어도 왔다 간 건 적어 둬야죠. 그래야 안 잊어버리잖아요.'),
            ('서술', '희수가 다온의 공책을 내려다보았다. 이번에는 아무것도 고치라고 하지 않았다.'),
        ]),
    ])


def parse():
    src = open(os.path.join(HERE, 'script.md'), encoding='utf-8').read()
    src = src.split('## 화면 연출 메모')[0]
    chapters, memories = {}, []
    ch = None
    scene = None
    in_memory = False
    for raw in src.splitlines():
        line = raw.rstrip()
        m = re.match(r'^# (\d)장 「(.+?)」', line)
        if m:
            ch = int(m.group(1)); chapters[ch] = dict(title=m.group(2), scenes=[]); scene = None; in_memory = False; continue
        if line.startswith('# 결말'):
            ch = 'end'; chapters['end'] = dict(title='결말', scenes=[dict(no=1, title='결말', lines=[], task=None)]); scene = chapters['end']['scenes'][0]; in_memory = False; continue
        if line.startswith('#### '):
            in_memory = True; continue
        m = re.match(r'^### 장면 (\d+) · (.+?) \(', line)
        if m and ch:
            in_memory = False
            scene = dict(no=int(m.group(1)), title=m.group(2), lines=[], task=None); chapters[ch]['scenes'].append(scene); continue
        if in_memory:
            if line.strip():
                memories.append(line.strip())
            continue
        m = re.match(r'^- (서술|희수|다온|월하|먹그림자|먹귀|서율|서하): (.+)$', line)
        if m and scene is not None:
            scene['lines'].append((m.group(1), m.group(2)))
            continue
        m = re.match(r'^- 할 일: (.+)$', line)
        if m and scene is not None:
            scene['task'] = m.group(1)
    return chapters, memories


def build():
    chapters, memories = parse()
    quests, steps = [], []
    for c in range(1, 6):
        P = PLAN[c]
        sc = chapters[c]['scenes']
        if len(sc) != len(P['steps']):
            raise SystemExit(f'{c}장 장면 수가 다름: 대본 {len(sc)} · 계획 {len(P["steps"])}')
        quests.append(dict(id=P['id'], title=chapters[c]['title'], L=P['L'], region=P['region'], after=P['after'], summary=P['summary'], items=P['items']))
        for k, s in enumerate(sc):
            lines = list(s['lines'])
            for old, new in FIX.get((c, s['no']), []):
                os_, ot = old.split(': ', 1) if ': ' in old and old.split(': ', 1)[0] in SPEAK else ('서술', old)
                ns_, nt = new.split(': ', 1) if ': ' in new and new.split(': ', 1)[0] in SPEAK else ('서술', new)
                idx = [i for i, (sp, t) in enumerate(lines) if sp == os_ and old.split(': ', 1)[-1] in t] if os_ != '서술' else [i for i, (sp, t) in enumerate(lines) if sp == '서술' and old in t]
                if len(idx) != 1:
                    raise SystemExit(f'고칠 줄을 못 찾음 {c}장 {s["no"]}: {old}')
                i = idx[0]
                sp, t = lines[i]
                lines[i] = (sp, t.replace(ot, nt) if os_ == '서술' else nt)
            goal, need = P['steps'][k]
            steps.append(dict(quest=P['id'], step=k + 1, title=s['title'], goal=goal, need=need,
                              lines=[{'s': SPEAK[sp], 't': t} for sp, t in lines]))
    quests.append(dict(id=EXTRA['id'], title=EXTRA['title'], L=EXTRA['L'], region=EXTRA['region'], after=EXTRA['after'], summary=EXTRA['summary'], items=EXTRA['items'], side=True))
    for k, (goal, need, title, lines) in enumerate(EXTRA['steps']):
        steps.append(dict(quest=EXTRA['id'], step=k + 1, title=title, goal=goal, need=need, lines=[{'s': SPEAK[sp], 't': t} for sp, t in lines]))
    end = chapters['end']['scenes'][0]['lines']
    epi = [{'s': SPEAK[sp], 't': t} for sp, t in end]
    return quests, steps, epi, memories


def count():
    return len(PLAN)


def emit(w, J, T, bulk, TA, xp_need, errors, ref):
    quests, steps, epi, memories = build()
    with open(os.path.join(HERE, 'ref', 'mj_fight_lines.json'), 'w', encoding='utf-8') as f:
        json.dump(memories, f, ensure_ascii=False, indent=1)
    names = set(ref.get('npcs', []))
    for k, (nm, _) in NPCS.items():
        if nm in names:
            errors.append('인물 이름 겹침: ' + nm)
    w("""create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;""")
    w("select pg_temp.yh_patch('public.world_faction_task_count(uuid,jsonb,timestamp with time zone)', 'when ''craft'' then ''craft'' end', 'when ''craft'' then ''craft'' when ''rest'' then ''rest'' end');")
    w("select pg_temp.yh_patch('public.world_faction_task_label(jsonb)', 'when ''craft'' then ''제작'' else', 'when ''craft'' then ''제작'' when ''rest'' then ''쉬기'' else');")
    w("select pg_temp.yh_patch('public.world_name_rules()', '''field'', jsonb_build_object(', '''idle'', jsonb_build_object(''training'', ''자율 수련'', ''research'', ''자료 조사'', ''maintenance'', ''장비 정비'', ''rest'', ''휴식''),\n    ''field'', jsonb_build_object(');")
    w("select pg_temp.yh_patch('public.world_faction_task_label(jsonb)', 'when ''clue'' then ''탐색에서 단서 발견''', 'when ''clue'' then ''탐색해 실마리 찾기''');")
    w("select pg_temp.yh_patch('public.world_faction_task_label(jsonb)', 'string_agg(m.region_name, ''·'') || ''에서 ''', 'string_agg(m.region_name, ''·'') || case when p_task ->> ''t'' = ''travel'' then ''에 '' else ''에서 '' end');")
    w("select pg_temp.yh_patch('public.world_faction_task_label(jsonb)', 'when ''rest'' then ''쉬기'' else', 'when ''rest'' then ''쉬기'' when ''idle'' then ''자율 활동'' || coalesce(''('' || (public.world_name_rules() -> ''idle'' ->> (p_task ->> ''k'')) || '')'', '''') || '' 끝까지 마치기'' || case when p_task ? ''min'' then ''('' || (p_task ->> ''min'') || ''분 넘게)'' else '''' end else');")
    w("select pg_temp.yh_patch('public.world_faction_task_count(uuid,jsonb,timestamp with time zone)', '+ case when p_task ->> ''t'' = ''win'' and not p_task ? ''phase''', '+ case when p_task ->> ''t'' = ''idle'' then (select count(*)::int from public.world_idle_activities a where a.owner_id = p_uid and a.status = ''claimed'' and a.claimed_at >= p_since and a.claimed_at >= a.started_at + make_interval(mins => a.duration_minutes) and a.duration_minutes >= coalesce((p_task ->> ''min'')::int, 0) and (not p_task ? ''k'' or a.activity_type = p_task ->> ''k'')) else 0 end + case when p_task ->> ''t'' = ''win'' and not p_task ? ''phase''');")
    bulk('world_quest_npcs', [dict(npc_key=k, npc_name=nm, bio=bio) for k, (nm, bio) in NPCS.items()], [('npc_key', 'text'), ('npc_name', 'text'), ('bio', 'text')], 'npc_key', ['npc_name', 'bio'])
    qrows, srows = [], []
    for i, q in enumerate(quests):
        L = q['L']
        tot = round((0.4 if q.get('side') else 0.6) * xp_need(L))
        mine = [s for s in steps if s['quest'] == q['id']]
        task_steps = [s['step'] for s in mine if s['need'].get('tasks') or s['need'].get('give')]
        per = tot // max(1, len(task_steps))
        qrows.append(dict(quest_id=q['id'], cat=CAT, title=q['title'], summary=q['summary'], region_id=q['region'], min_level=L, after=q['after'], sort=1300 + i, epilogue=[]))
        for s in mine:
            rw = {}
            if s['step'] in task_steps:
                rw['xp'] = per
            last = s['step'] == len(mine)
            if last:
                rw['gil'] = (5 + 4 * L) if q.get('side') else 20 + 10 * L
                rw['items'] = q['items']
            lines = s['lines'] + (epi if last and q['id'] == 'mkq_5' else [])
            srows.append(dict(quest_id=q['id'], step=s['step'], title=s['title'], goal=s['goal'], need=s['need'], lines=lines, reward=rw))
    bulk('world_quests', qrows, [('quest_id', 'text'), ('kind', 'text'), ('cat', 'text'), ('title', 'text'), ('summary', 'text'), ('region_id', 'text'), ('min_level', 'int'), ('after', 'jsonb'),
         ('sort', 'int'), ('epilogue', 'jsonb'), ('active', 'boolean')], 'quest_id', ['cat', 'title', 'summary', 'region_id', 'min_level', 'after', 'sort', 'epilogue', 'active'],
         {'kind': "'side'", 'after': TA('after'), 'active': 'true'})
    bulk('world_quest_steps', srows, [('quest_id', 'text'), ('step', 'int'), ('title', 'text'), ('goal', 'text'), ('need', 'jsonb'), ('lines', 'jsonb'), ('reward', 'jsonb')],
         'quest_id, step', ['title', 'goal', 'need', 'lines', 'reward'])
