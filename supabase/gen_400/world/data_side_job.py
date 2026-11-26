import hashlib
import os
import re
import data_quests as Q

BS, GEO = Q.BS, Q.GEO
nd, tv, cl, wi, ga = Q.nd, Q.tv, Q.cl, Q.wi, Q.ga
L = 52
TITLE_CAT = '도해록'
JOB_TAG = {'호위': 'artificer', '월궁': 'scout', '퇴마': 'exorcist', '의무': 'medic', '봉인': 'sealmaster', '암영': 'analyst',
           '조련': 'tamer', '혈기': 'bloodknight', '여명': 'spearman', '진법': 'formation'}
JOB_NAME = {'artificer': '호위 무사', 'scout': '월궁 사수', 'exorcist': '퇴마관', 'medic': '의무관', 'sealmaster': '봉인술사', 'analyst': '암영 검객',
            'tamer': '조련사', 'bloodknight': '혈기사', 'spearman': '여명 창객', 'formation': '진법가'}

NPC = {
    '퇴마사 잉걸': '불씨들녘의 퇴마사. 김 오르는 비탈의 화산 유리 덩이에서 깨어난 화생으로, 손등과 뺨에 검은 유리 결이 돋았다. 말수가 적고 낮은 하오체를 쓰며, 생각에 잠기면 엄지로 손등 유리를 문지른다.',
    '쇠 장인 다듬': '화덕골에서 물결무늬 칼을 가장 잘 벼리던 늙은 쇠 장인. 팔뚝에 붉은 비늘이 돋은 태생 요괴로, 작업장을 닫고 비탈로 올라간 뒤 이름이 흐려졌다.',
    '옛 제자 재돌': '다듬의 옛 제자. 작업장이 닫히던 해에 화덕골로 내려가 숯 짐꾼이 된 사람 청년이다. 스승을 두고 떠난 것을 부끄러워한다.',
}

TITLES = {
    'artificer': ('hws_job_artificer', '망치를 받아 낸 방패'),
    'scout': ('hws_job_scout', '손목만 겨눈 사수'),
    'exorcist': ('hws_job_exorcist', '부르는 길을 배운 퇴마관'),
    'medic': ('hws_job_medic', '금 간 형상을 짚은 의원'),
    'sealmaster': ('hws_job_sealmaster', '풀어 줄 때를 아는 봉인술사'),
    'analyst': ('hws_job_analyst', '칼등으로 친 검객'),
    'tamer': ('hws_job_tamer', '숯내를 따라간 조련사'),
    'bloodknight': ('hws_job_bloodknight', '대신 맞아 준 혈기사'),
    'spearman': ('hws_job_spearman', '창 자루를 내준 창객'),
    'formation': ('hws_job_formation', '김 솟는 자리를 셈한 진법가'),
}

QUEST = dict(id='hws_job_twopaths', cat='직업·화덕골', title='두 갈래의 길', region=BS, after=['hwq_7'],
             summary='불씨들녘의 퇴마사 잉걸은 이름을 잃고 폭주한 이를 쓰러뜨린 뒤 이름을 불러 돌아오게 한다. 김 오르는 비탈에서 망치를 휘두르는 늙은 장인 다듬을 함께 구한다.',
             items={'volcanic_glass': 2, 'cold_ember_filings': 2}, steps=[
    ('화덕골 골목에서 퇴마사 잉걸을 만난다', nd(BS), """
해가 화산 너머로 기울자 화덕골 골목마다 화덕 연기가 낮게 깔렸다. 처마 밑 화산 유리 액막이가 노을빛을 받아 붉게 번득였다.
닫힌 작업장 앞 돌계단에 사내 하나가 앉아 놋쇠 그릇에 약초를 달이고 있었다. 손등과 뺨에는 검은 유리 결이 비늘처럼 돋아 있었다.
사내의 왼팔에 감은 무명 천에는 피가 배어 나왔다. 내 발소리에 사내가 그릇 뚜껑을 덮었다. 엄지로 손등 유리를 한 번 문지르고 나서야 나를 올려다보았다.
퇴마사 잉걸: 바깥누리에서 온 조사원이시오? 구름성 높새가 기별을 보냈소. 파도너울성에서 폭주한 이들을 다치지 않게 붙들어 주었다고.
나는 그의 팔에 감긴 천을 보며 어디서 다쳤는지 물었다.
잉걸이 피 밴 천을 내려다보고 쓴웃음을 지었다.
퇴마사 잉걸: 비탈에서 망치에 맞았소. 나는 이 들녘의 퇴마사 잉걸이오. 김 오르는 비탈에서 결 잃은 쇠 장인들이 화로마다 망치를 휘두르고 있소. 그 사람들을 붙들어 이름을 찾아 주는 게 내 일이오.
잉걸이 그릇을 계단 옆으로 밀어 두었다. 약초 끓는 냄새에 쇳내가 섞여 코끝이 매웠다.
퇴마사 잉걸: 그 가운데 다듬이라는 어르신이 계시오. 화덕골에서 물결무늬 칼을 가장 잘 벼리던 장인이오. 작업장을 닫고 혼자 비탈로 올라가시더니 이름이 흐려졌소.
잉걸이 고개를 들어 나를 똑바로 보았다.
퇴마사 잉걸: 바깥누리에서는 이런 이를 어떻게 하오? 높새 말로는 그쪽 방식이 우리와 다르다던데.
[호위] 나는 앞에 서서 휘두르는 것을 받아 내고 뒤에 선 사람들을 지킨다고 했다.
[호위] 퇴마사 잉걸: 그럼 망치는 조사원이 받아 주시오. 나는 그 틈에 어르신의 손을 잡겠소.
[월궁] 나는 멀리서 활을 쏘아 무기를 쥔 손부터 떨어뜨린다고 했다.
[월궁] 퇴마사 잉걸: 손목을 맞힌다라. 어르신의 손은 칼을 벼리던 손이오. 뼈는 비켜서 쏘아 주시오.
[퇴마] 나는 본토 퇴마관은 요괴가 된 이의 옛 이름을 불러 보내 준다고 했다.
[퇴마] 잉걸이 엄지를 손등에서 떼고 한동안 말이 없었다.
[퇴마] 퇴마사 잉걸: 보낸다고 했소? 우리는 이름을 불러서 돌아오게 하오. 그쪽은 떠나보낼 때 이름을 부르는구려. 이번에는 우리 쪽 방식으로 함께 해 봅시다.
[의무] 나는 싸움이 끝난 뒤 다친 이를 살리는 것이 내 일이라고 했다.
[의무] 퇴마사 잉걸: 마침 잘됐소. 이름이 흐려지면 형상에도 금이 가오. 붙든 뒤에 어르신의 몸을 살펴 주시오.
[봉인] 나는 부적과 사슬로 움직이지 못하게 묶어 둔다고 했다.
[봉인] 퇴마사 잉걸: 묶는 건 좋소. 다만 이름을 부를 때는 풀어야 하오. 묶인 채로는 제 발로 돌아오지 못하니까.
[암영] 나는 단도로 급소를 찔러 단숨에 쓰러뜨린다고 했다.
[암영] 퇴마사 잉걸: 급소는 안 되오. 쓰러뜨리되 다시 일어날 수 있게 해 주시오. 어르신은 망치를 손목에 끈으로 묶어 두셨소. 그 끈을 끊어 주는 건 어떻소?
[조련] 나는 동무와 함께 다니며 동무의 코로 먼저 찾아낸다고 했다.
[조련] 퇴마사 잉걸: 동무가 있소? 장인마다 몸에 밴 숯내가 다르오. 어르신은 소나무 숯만 쓰셨으니 그 냄새를 맡게 해 주시오.
[혈기] 나는 제 피로 갑주를 둘러 맞으면서 버틴다고 했다.
[혈기] 퇴마사 잉걸: 맞으면서 버틴다라. 그 망치는 쇠를 펴던 망치요. 너무 오래 맞지는 마시오.
[여명] 나는 긴 창으로 요괴보다 먼저 닿아 거리를 둔다고 했다.
[여명] 퇴마사 잉걸: 한 자루 거리라. 망치는 팔 길이만큼만 닿으니 그게 낫겠소. 창끝 대신 자루 쪽으로 밀어 주시오.
[진법] 나는 산가지로 다칠 자리를 미리 셈해 막아 둔다고 했다.
[진법] 퇴마사 잉걸: 다칠 자리를 미리 안다니 부럽구려. 내 팔도 그렇게 막았으면 좋았을 것을.
잉걸이 무릎을 짚고 일어섰다. 붕대 감은 팔이 계단 난간에 스치자 그가 이를 악물었다.
퇴마사 잉걸: 붙들기 전에 어르신이 어디서 지내시는지부터 알아야 하오. 붙든 뒤에 데려갈 자리가 있어야 이름도 돌아올 데가 있소. 비탈에 올라 어르신이 남긴 흔적을 찾아 주시오. 나는 이 약을 마저 달이고 뒤따라가겠소.
- 할 일: 김 오르는 비탈에 도착 · 김 오르는 비탈에서 탐색해 실마리 5
"""),
    ('김 오르는 비탈에서 다듬이 남긴 흔적을 찾는다', nd(GEO, tv(GEO), cl(GEO, 5)), """
김 오르는 비탈은 발밑 바위가 신발 바닥까지 뜨거웠다. 반쯤 식은 돌 화로 곁에 짚을 깔아 만든 잠자리가 있었다. 짚 위에 덮인 앞치마에는 물결무늬 세 줄이 불에 그을린 채 수놓여 있었다.
화로 옆 바위에는 망치 자국이 줄지어 패어 있었다. 세 번 깊게 내리치고 한 번 가볍게 두드린 자국이 바위 끝까지 되풀이되었다.
짚더미 밑에서는 반쯤 벼린 칼 한 자루가 나왔다. 칼등에는 서툰 글씨로 「재돌」이라고 새겨져 있었다.
비탈 아래에서 거친 숨소리가 들려 나는 고개를 돌렸다. 잉걸이 붕대 감은 팔을 가슴에 붙이고 성한 손으로 바위를 짚어 가며 올라왔다.
퇴마사 잉걸: 찾았구려. 그 앞치마가 다듬 어르신의 것이오. 물결 세 줄은 어르신이 칼마다 새기던 표식이오.
나는 바위의 망치 자국과 칼을 잉걸에게 보였다. 잉걸은 칼등의 글자를 엄지로 쓸다가 손을 멈췄다.
퇴마사 잉걸: 재돌은 어르신의 제자였소. 작업장이 닫히던 해에 화덕골로 내려가 숯 짐꾼이 되었지. 어르신은 제자 몫의 칼을 끝내 다 벼리지 못하신 거요.
잉걸이 바위 앞에 쪼그려 앉아 패인 자국을 손가락으로 하나씩 짚었다.
퇴마사 잉걸: 이 자국은 어르신이 쇠를 두드리던 박자요. 셋은 세게, 하나는 가볍게. 이름은 잊어도 손은 아직 그 박자를 기억하는구려.
그때 비탈 위쪽에서 쾅, 쾅, 쾅 하고 쇠 부딪는 소리가 울렸다. 흰 김 사이로 망치를 든 그림자 여럿이 식은 화로를 하나씩 내리치며 내려오고 있었다.
잉걸이 칼을 앞치마로 싸서 내 품에 밀어 넣었다. 손등의 유리 결이 화로 불빛을 받아 번득였다.
퇴마사 잉걸: 저 가운데 어르신이 계시오. 물결 앞치마를 두른 분은 손을 다치게 하지 마시오. 나머지 장인들도 다 누군가의 식구요. 쓰러뜨리면 내가 하나씩 이름을 묻겠소.
[호위] 나는 방패를 들고 잉걸보다 한 걸음 앞에 섰다.
[호위] 퇴마사 잉걸: 그렇지. 망치가 내려오면 받아 내시오. 나는 뒤에서 이름을 부르겠소.
[월궁] 나는 김이 덜 솟는 바위 위로 올라가 시위를 당겼다.
[월궁] 퇴마사 잉걸: 거기서 손목을 노리시오. 망치만 떨어지면 내가 달려가겠소.
[퇴마] 나는 버릇처럼 방울을 꺼내 들었다. 잉걸의 눈길이 방울에 머물자 흔들려던 손이 멈췄다.
[퇴마] 퇴마사 잉걸: 방울은 흔들어도 좋소. 다만 이번에는 보내는 소리 말고, 멈추라는 소리로 울려 주시오.
[의무] 나는 약낭을 허리에 단단히 매고, 다친 이를 끌어다 눕힐 바위 그늘을 눈여겨 두었다.
[의무] 퇴마사 잉걸: 쓰러진 이는 그리로 옮기시오. 형상에 금이 간 이부터 봐 주시오.
[봉인] 나는 부적 다섯 장을 손가락 사이에 끼워 들었다.
[봉인] 퇴마사 잉걸: 쓰러뜨린 이는 묶어 두시오. 풀 때는 내가 말하겠소.
[암영] 나는 단도를 거꾸로 쥐어 칼등이 바깥으로 오게 했다.
[암영] 퇴마사 잉걸: 칼등으로 치겠다는 거요? 고맙소. 망치 끈도 잊지 마시오.
[조련] 나는 동무에게 다듬의 앞치마 냄새를 맡게 했다. 동무가 코를 킁킁대더니 비탈 위쪽을 향해 귀를 쫑긋 세웠다.
[조련] 퇴마사 잉걸: 저쪽이오? 그럼 어르신은 맨 나중에 붙듭시다. 다른 장인들부터 떼어 내야 하오.
[혈기] 나는 손바닥을 베어 흘린 피로 갑주를 둘렀다. 붉은 막이 몸을 감싸자 나는 앞으로 나섰다.
[혈기] 퇴마사 잉걸: 피 냄새가 짙구려. 장인들이 놀라 더 사나워질지 모르니 맨 앞에서만 막아 주시오.
[여명] 나는 창을 낮게 겨누고 장인들과 한 자루 거리를 쟀다.
[여명] 퇴마사 잉걸: 그 거리를 지키시오. 망치가 창 자루에 걸리면 내가 손을 잡겠소.
[진법] 나는 산가지를 뿌려 망치가 떨어질 자리를 셈했다.
[진법] 퇴마사 잉걸: 그 셈을 나도 보게 해 주시오. 어르신이 어디로 휘두를지 알면 붙들기 쉽소.
- 할 일: 김 오르는 비탈에서 결 잃은 쇠 장인 진압 5
"""),
    ('김 오르는 비탈에서 결 잃은 쇠 장인들을 진압한다', nd(GEO, wi(5, GEO, ['hw_geo_4'])), """
마지막 망치가 바위에 떨어지며 쨍 소리를 냈다. 장인들은 저마다 식은 화로 곁에 털썩 주저앉아 빈손을 내려다보았다.
잉걸은 장인들 사이를 오가며 한 사람씩 얼굴을 들여다보고 이름을 물었다. 둘은 더듬더듬 제 이름을 댔고, 하나는 고개만 저었다.
물결 앞치마를 두른 늙은 장인은 망치를 놓고도 손바닥으로 바위를 두드리고 있었다. 셋은 세게, 하나는 가볍게 두드리는 박자였다. 팔뚝의 붉은 비늘은 녹슨 쇠처럼 빛을 잃었다.
잉걸이 장인 앞에 무릎을 꿇고 두드리는 손을 두 손으로 감쌌다.
퇴마사 잉걸: 다듬 어르신. 나요, 잉걸이오. 어르신이 이 비탈에서 주워다 이름을 붙여 준 유리 덩이 말이오.
잉걸의 입가에서 금빛 실 한 가닥이 가늘게 뻗어 나와 다듬의 가슴께에 닿았다. 다듬이 고개를 들었지만 눈빛은 금세 다시 흐려졌다. 실도 김에 흔들리며 끊어질 듯 가늘어졌다.
잉걸이 엄지로 손등 유리를 세게 문질렀다. 낮은 목소리가 갈라졌다.
퇴마사 잉걸: 한 가닥으로는 모자라오. 나는 어르신이 거둬 준 몸이지만, 곁에서 지낸 해는 몇 해 안 되오. 어르신을 가장 오래 불러 온 사람은 재돌이오.
나는 품에 든 칼을 꺼내 보이며 재돌을 이리로 데려와야 하느냐고 물었다.
퇴마사 잉걸: 재돌은 이 비탈에 오지 않소. 스승을 두고 내려간 게 부끄러워서. 그러니 우리가 어르신을 화덕골 작업장으로 모셔 갑시다. 제 작업장에 앉으면 어르신도 제가 누군지 떠올리기 쉬울 거요.
잉걸이 다듬의 손을 놓지 않은 채 비탈 위쪽의 검게 반짝이는 바위를 턱으로 가리켰다.
퇴마사 잉걸: 어르신은 칼을 다 벼리면 꼭 화산 유리에 날을 그어 보셨소. 유리가 맑게 우는 소리로 결이 섰는지 들었지. 저 바위에서 유리를 캐다 재돌에게 넘겨 주시오. 재돌의 손으로 스승의 칼을 마저 그어 보게 하고 싶소.
잉걸이 다듬을 부축해 일으키며 나를 돌아보았다.
[호위] 퇴마사 잉걸: 내려가는 길에 덜 진정된 장인이 남아 있을지 모르오. 조사원이 앞장서 주시오.
[월궁] 퇴마사 잉걸: 내려가는 길에 불나방이 덤비면 멀리서 떨궈 주시오. 어르신은 놀라면 다시 망치를 찾소.
[퇴마] 퇴마사 잉걸: 가는 동안 어르신 곁에서 방울을 낮게 울려 주시오. 보내는 소리 말고, 곁에 있다는 소리로.
[의무] 퇴마사 잉걸: 어르신 팔뚝의 비늘이 갈라졌소. 가는 동안 약을 발라 주시오. 형상이 버텨야 이름도 버티오.
[봉인] 퇴마사 잉걸: 묶은 끈은 화덕골 문턱에서 풀어 주시오. 제 작업장에는 제 발로 들어가야 하오.
[암영] 퇴마사 잉걸: 끊어 낸 망치 끈은 버리지 말고 챙겨 주시오. 어르신의 손때가 묻은 끈이오.
[조련] 퇴마사 잉걸: 동무가 어르신 곁에 붙어 걸어 주면 좋겠소. 어르신은 짐승을 좋아해서 작업장 앞에 늘 들개 밥그릇을 두었소.
[혈기] 퇴마사 잉걸: 조사원의 상처부터 싸매시오. 피 냄새를 풍기며 골목에 들어가면 아이들이 놀라오.
[여명] 퇴마사 잉걸: 창 자루를 어르신께 쥐여 주시오. 지팡이 삼아 짚게 말이오. 망치를 쥐던 손은 무언가를 쥐고 있어야 덜 헤매오.
[진법] 퇴마사 잉걸: 내려가는 길에 김이 솟을 자리를 셈해 주시오. 어르신이 발을 데지 않게.
- 할 일: 김 오르는 비탈에서 화산 유리 6 모으기 · 화덕골에 도착 · 화산 유리 6 넘기기
"""),
    ('화덕골 작업장에서 재돌과 함께 다듬의 이름을 부른다', nd(BS, ga(GEO, 6, ['volcanic_glass']), tv(BS), give={'volcanic_glass': 6}), """
잉걸이 닫힌 작업장 문을 열자 묵은 재가 풀썩 일었다. 다듬은 문턱을 넘자마자 식은 화덕 앞으로 걸어가 모루 곁에 쪼그려 앉았다.
골목 끝에서 숯 자루를 지게에 진 청년이 걸음을 멈췄다. 지게가 기우뚱하며 자루 하나가 흙바닥에 굴렀다. 청년은 다듬을 알아보고 얼굴이 하얗게 질렸다.
옛 제자 재돌: 스, 스승님? 잉걸 형, 스승님이 왜 여기 계세요?
잉걸이 재돌에게 다가가 미끄러지는 지게 끈을 붙잡아 주었다.
퇴마사 잉걸: 비탈에서 모셔 왔다. 이름을 많이 잃으셨어. 네가 불러 드려라.
재돌이 지게 끈을 쥔 채 뒷걸음질을 쳤다.
옛 제자 재돌: 제가요? 저는 스승님을 두고 내려온 놈이에요. 저를 보시면 더 싫어하실 거예요.
나는 품에서 반쯤 벼린 칼을 꺼내 재돌에게 내밀었다. 칼등의 글자가 노을빛 아래 드러났다.
재돌이 칼을 받아 들고 글자를 오래 내려다보았다. 굵은 손가락이 칼등을 따라가다 제 이름 끝 글자에서 바들바들 떨렸다.
옛 제자 재돌: 제 칼이네요. 스승님, 이걸 여태 벼리고 계셨어요?
재돌이 지게를 벗어 문간에 내려놓았다. 자루를 풀자 소나무 숯 냄새가 작업장 안에 번졌다.
재돌은 숯을 한 아름 안아다 화덕에 넣었다. 잉걸이 풀무를 밟자 식었던 화덕 바닥에 붉은 불이 피어올랐다.
나는 비탈에서 캐 온 화산 유리를 재돌의 손에 건넸다. 재돌은 유리를 모루 옆에 내려놓고 다듬 곁에 무릎을 꿇었다.
옛 제자 재돌: 스승님, 다듬 스승님. 저 재돌이에요. 숯은 소나무 것만 쓰라고 하셨잖아요. 저는 짐꾼 노릇을 하면서도 소나무 숯만 날랐어요.
재돌의 목소리를 따라 금빛 실이 뻗어 다듬에게 닿았다. 잉걸이 끊어진 가닥을 잇듯 다듬의 이름을 한 번 더 불렀다.
실 두 가닥이 다듬의 가슴께에서 얽혔다. 다듬의 손은 여전히 허공을 셋, 하나 두드릴 뿐이었다.
나는 비탈 바위에 패어 있던 망치 자국을 떠올렸다. 달군 칼을 모루에 올리고, 곁에 놓인 작은 망치를 집어 들었다.
세 번은 세게, 한 번은 가볍게 내리치자 땅, 땅, 땅, 똑 하는 쇳소리가 작업장 안을 울렸다.
다듬의 손이 허공에서 멈췄다. 늙은 장인은 내 손에서 망치를 천천히 받아 갔다.
다듬은 그 박자로 칼을 마저 두드려 폈다. 망치질이 거듭될수록 팔뚝의 비늘에 붉은 빛이 조금씩 돌아왔다.
다듬이 다 벼린 칼날을 화산 유리 위로 길게 그었다. 유리가 맑게 우는 소리가 작업장을 가득 채웠다. 다듬은 그 소리에 귀를 기울이다 눈을 끔벅였다.
쇠 장인 다듬: 결이 섰구나. 재돌아, 숯이 모자라다. 소나무 숯 더 가져와라.
재돌은 대답 대신 소매로 눈가를 훔쳤다. 숯 자루를 통째로 끌어다 화덕 곁에 부리는 손이 바빴다.
다듬이 고개를 돌려 잉걸을 오래 바라보았다. 미간에 주름이 잡혔다.
쇠 장인 다듬: 거기 유리 덩이처럼 생긴 놈은 누구냐.
잉걸이 손등을 문지르던 엄지를 멈췄다. 낮은 목소리가 떨렸다.
퇴마사 잉걸: 잉걸이오. 어르신이 비탈에서 주워다 지어 주신 이름이오.
다듬은 잉걸의 얼굴을 한참 들여다보았다. 갈라진 입술 끝이 조금 올라갔다.
쇠 장인 다듬: 잉걸이라. 그래, 불씨 같은 놈이라 그렇게 불렀지.
작업장 굴뚝으로 화덕 연기가 다시 피어올랐다. 이웃 장인 몇이 무슨 일인가 싶어 문간에 모여들었다.
잉걸이 문간에 기대어 나를 돌아보았다.
퇴마사 잉걸: 바깥누리에서는 이름을 불러 보내 준다고 했고, 여기서는 불러서 돌아오게 하오. 같은 이름을 부르는데 길이 두 갈래인 셈이오. 오늘은 조사원이 우리 쪽 길을 함께 걸어 주었구려.
[호위] 퇴마사 잉걸: 망치를 다 받아 내 준 덕에 어르신의 손이 성하오. 저 손이 다시 칼을 벼리는 건 조사원 덕이오.
[월궁] 퇴마사 잉걸: 손목뼈를 하나도 건드리지 않았더군. 그런 활 솜씨는 이 들녘에도 드무오.
[퇴마] 퇴마사 잉걸: 이제 조사원은 보내는 길도, 돌아오게 하는 길도 아는 퇴마관이오. 어느 길로 갈지는 그때그때 그 사람을 보고 정하시오.
[의무] 퇴마사 잉걸: 비늘에 발라 준 약이 잘 들었소. 형상이 버텨 준 덕에 이름이 돌아올 자리가 남아 있었소.
[봉인] 퇴마사 잉걸: 문턱에서 끈을 풀어 준 게 좋았소. 어르신이 제 발로 작업장에 들어가시는 걸 보았소?
[암영] 퇴마사 잉걸: 그 망치 끈은 재돌에게 주시오. 새 망치에 감으면 스승의 손때가 이어질 거요.
[조련] 퇴마사 잉걸: 동무가 끝까지 어르신 곁에 붙어 걸어 주었소. 내일부터는 작업장 앞에 들개 밥그릇이 다시 나올 거요.
[혈기] 퇴마사 잉걸: 조사원이 대신 맞아 준 덕에 장인들 가운데 크게 다친 이가 없소. 그 손바닥 상처는 꼭 싸매시오.
[여명] 퇴마사 잉걸: 창 자루를 짚으신 덕에 어르신이 비탈에서 한 번도 넘어지지 않았소. 고맙소.
[진법] 퇴마사 잉걸: 조사원의 셈 덕에 아무도 김에 데지 않았소. 다음에는 내 팔이 다칠 자리도 미리 셈해 주시오.
재돌이 칼을 두 손에 받쳐 들고 내 앞으로 왔다. 손등에 묻은 숯 검댕이 눈물 자국과 뒤섞여 있었다.
옛 제자 재돌: {이름} 님, 이거 받아 주세요. 스승님이 칼을 그어 보신 유리하고, 비탈 화로에서 긁어 온 쇳가루예요. 제가 드릴 수 있는 게 이것뿐이에요.
재돌이 꾸러미를 내 손에 쥐여 주고 작업장 안으로 뛰어 들어갔다. 다듬의 망치 소리가 셋, 하나, 다시 셋, 하나로 골목까지 울려 퍼졌다.
"""),
])

TAG_RE = re.compile(r'^\[(' + '|'.join(JOB_TAG) + r')\] (.*)$')


def npc_key(name):
    return 'q:hws_' + hashlib.md5(name.encode()).hexdigest()[:6]


def lines_of(text):
    out, task = [], None
    for raw in text.strip().splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith('- 할 일:'):
            task = line[7:].strip()
            continue
        job = None
        m = TAG_RE.match(line)
        if m:
            job, line = JOB_TAG[m.group(1)], m.group(2)
        d = {'s': None, 't': line}
        if ': ' in line:
            sp, t = line.split(': ', 1)
            if sp in NPC:
                d = {'s': npc_key(sp), 't': t}
        if job:
            d['job'] = job
        out.append(d)
    return out, task


def check(errors):
    q = QUEST
    st = q['steps']
    for k, (goal, need, text) in enumerate(st):
        lines, task = lines_of(text)
        where = f"직업 보조 {q['id']} 장면 {k + 1}"
        if k + 1 < len(st) and not task:
            errors.append(f'{where}: 할 일 줄 없음')
        if k + 1 == len(st) and task:
            errors.append(f'{where}: 마지막 장면에 할 일 줄')
        if k > 0 and not need.get('tasks') and not need.get('give'):
            errors.append(f'{where}: need에 할 일이 없음')
        jobs = [x['job'] for x in lines if 'job' in x]
        if jobs:
            cnt = {j: jobs.count(j) for j in JOB_TAG.values()}
            if 0 in cnt.values():
                errors.append(f'{where}: 직업 갈래 줄이 빠진 직업 {cnt}')
        for ln in lines:
            t = ln['t']
            if ln['s'] is None and t[:3] in ('그런데', '그러나', '그러자', '그리고', '하지만'):
                errors.append(f'{where}: 서술 첫머리 접속사 — {t[:20]}')
            if any(x in t for x in ('형님', '누님', '오빠', '언니', '라는 것이었다', '라고 일러', '라고 일렀다', '침을 묻')):
                errors.append(f'{where}: 금지 표현 — {t[:20]}')
            if ln['s'] is None and t.startswith('나는') and ('"' in t or '“' in t):
                errors.append(f'{where}: 주인공 직접 대사 — {t[:20]}')
            if ': ' in t and ln['s'] is None and t.split(': ', 1)[0] in ('잉걸', '다듬', '재돌'):
                errors.append(f'{where}: 화자 이름 모름 — {t[:20]}')


def emit(fresh, errors, J, TA, known, RID, xp_need):
    check(errors)
    q = QUEST
    fresh('npcs', list(NPC), '인물')
    fresh('quest_ids', [q['id']], '퀘스트 id')
    fresh('titles', [n for _, n in TITLES.values()], '칭호')
    fresh('title_keys', [k for k, _ in TITLES.values()], '칭호 키')
    for k in q['items']:
        if k not in known: errors.append(f"직업 보조 물품 없음: {k}")
    steps = q['steps']
    tot = round(0.4 * xp_need(L) * 0.25)
    task_steps = [i + 1 for i, (_, need, _) in enumerate(steps) if need.get('tasks') or need.get('give')]
    per = tot // max(1, len(task_steps))
    srows = []
    for i, (goal, need, text) in enumerate(steps):
        n = i + 1
        lines, _ = lines_of(text)
        rw = {'xp': per} if n in task_steps else {}
        if n == len(steps):
            rw['gil'] = 5 + 4 * L
            rw['items'] = q['items']
            rw['title_job'] = {j: k for j, (k, _) in TITLES.items()}
        for t in need.get('tasks', []):
            for k in t.get('items', []):
                if k not in known: errors.append(f"직업 보조 할 일 물품 없음: {k}")
            for rg in t.get('r', []):
                if rg not in RID: errors.append(f"직업 보조 지역 없음: {rg}")
        for k in need.get('give', {}):
            if k not in known: errors.append(f"직업 보조 넘길 물품 없음: {k}")
        srows.append(dict(quest_id=q['id'], step=n, title=goal, goal=goal, need=need, lines=lines, reward=rw))
    qrow = [dict(quest_id=q['id'], cat=q['cat'], title=q['title'], summary=q['summary'], region_id=q['region'], min_level=L, after=q['after'], sort=1699, epilogue=[])]
    trows = [dict(title_key=k, title_name=nm, cond=f"{JOB_NAME[j]}{'으로' if JOB_NAME[j][-1] in '관객' else '로'} 「{q['title']}」을 마친다", n=i) for i, (j, (k, nm)) in enumerate(TITLES.items())]
    out = [f"""insert into public.world_quest_npcs(npc_key, npc_name, bio) select x.npc_key, x.npc_name, x.bio
  from jsonb_to_recordset({J([dict(npc_key=npc_key(n), npc_name=n, bio=b) for n, b in NPC.items()])}) as x(npc_key text, npc_name text, bio text)
on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;""",
           f"""insert into public.world_title_catalog(title_key, title_name, description, condition_text, bonus, hidden, rule, sort, category, grade)
select x.title_key, x.title_name, x.cond || '.', x.cond, '{{}}'::jsonb, false, null, 3390 + x.n, '{TITLE_CAT}', 3
  from jsonb_to_recordset({J(trows)}) as x(title_key text, title_name text, cond text, n int)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus,
  hidden = excluded.hidden, rule = excluded.rule, category = excluded.category, grade = excluded.grade;""",
           f"""insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, sort, epilogue, active)
select x.quest_id, 'side', x.cat, x.title, x.summary, x.region_id, x.min_level, {TA('after')}, x.sort, x.epilogue, true
  from jsonb_to_recordset({J(qrow)}) as x(quest_id text, cat text, title text, summary text, region_id text, min_level int, after jsonb, sort int, epilogue jsonb)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  after = excluded.after, sort = excluded.sort, epilogue = excluded.epilogue, active = excluded.active;""",
           f"""insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward)
select x.quest_id, x.step, x.title, x.goal, x.need, x.lines, x.reward
  from jsonb_to_recordset({J(srows)}) as x(quest_id text, step int, title text, goal text, need jsonb, lines jsonb, reward jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;""",
           open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'h_quest_title_job.sql'), encoding='utf-8').read().strip()]
    return '\n'.join(out)
