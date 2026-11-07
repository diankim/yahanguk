import json, re, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
REF = json.load(open(os.path.join(HERE, 'ref.json')))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'migrations', '20261108040000_world_1_1_0_side_quests.sql')

def xp_need(L): return REF['xp_need'][L]
RULES = REF['reward_rules']['side']

ISLAND = {'banyo_village', 'ash_reeds', 'inverted_shrine', 'moonless_market', 'gwiheo_core'}
JOBS = {'호위 무사': 'artificer', '월궁 사수': 'scout', '퇴마관': 'exorcist', '의무관': 'medic', '봉인술사': 'sealmaster', '암영 검객': 'analyst'}

META = {
    '얼음 속 편지': ('sq110_ice_letter', 12, 'frost_valley', '채집', '해마다 얼음을 깨는 할미가 스무 해 전 남편의 편지 상자를 찾는다'),
    '노래하는 곡괭이': ('sq110_singing_pick', 13, 'crimson_mine', '채집', '밤마다 연장 창고의 곡괭이가 노래를 부른다'),
    '거꾸로 가는 물시계': ('sq110_backward_clock', 14, 'water_clock', '제작', '하루에 한 번 물시계가 거꾸로 돈다'),
    '벼락 맞은 대추나무': ('sq110_struck_jujube', 16, 'thunder_peak', '채집', '벼락 맞은 나무로 도장을 파겠다는 노인의 주문 백 개'),
    '별똥 줍는 아이': ('sq110_star_child', 17, 'comet_crater', '채집', '어머니 생일 선물을 찾아 낙하지까지 온 아이'),
    '칼 쓴 옥귀의 상소': ('sq110_cangue_ghost', 19, 'old_prison', '전투', '칼을 쓴 채 죽은 죄수가 밤마다 상소문을 읊는다'),
    '잠꾸러기 천문관': ('sq110_sleepy_astronomer', 20, 'white_tower', '제작', '별을 세다 꼭 아흔아홉에서 잠드는 천문관'),
    '뿌리 아래 사는 사람들': ('sq110_root_folk', 21, 'under_root', '전투', '이름을 맡긴 광부 가족에게 지맥포식자가 다가온다'),
    '붉은 제단의 가짜 신탁': ('sq110_false_oracle', 22, 'crimson_altar', '전투', '신탁을 꾸며 공물을 거두던 사제 앞에 진짜 원령이 나타난다'),
    '소금 갈매기 혼례': ('sq110_gull_wedding', 24, 'tide_gate', '채집', '갑문 꼭대기 갈매기 둥지 때문에 갑문이 안 닫힌다'),
    '밀물 도르래': ('sq110_tide_pulley', 24, 'tide_gate', '제작', '은퇴하는 갑문 목수와 그 자리를 이을 손녀'),
    '관성대 요리 겨루기': ('sq110_star_cookoff', 25, 'star_observatory', '제작', '별빛구이 원조를 두고 다투는 두 관측관'),
    '울음 새는 거울': ('sq110_weeping_mirror', 26, 'seal_vault', '전투', '밤마다 다른 봉인관의 얼굴로 우는 압수물 거울'),
    '검은 물결 위의 등': ('sq110_black_tide_lamps', 28, 'black_tide_rift', '제작', '균열에서 돌아오지 않은 어부들을 위해 등을 띄운다'),
    '흑룡 어보탕': ('sq110_dragon_soup', 28, 'black_tide_rift', '제작', '이 탕을 먹고 죽는 게 소원이라는 미식가'),
    '봉연 앞 마지막 보급소': ('sq110_last_depot', 29, 'black_tide_rift', '채집', '봉연으로 가는 조사원들을 몰래 먹이던 노인의 보급소'),
    '갈대가 부르는 이름': ('sq110_reed_name', 31, 'ash_reeds', '전투', '이름을 반쯤 잃은 이의 남은 이름을 갈대가 부른다'),
    '반요촌 첫 장날': ('sq110_first_market', 31, 'banyo_village', '제작', '반요들이 처음으로 장을 연다'),
    '실 잣는 반요 아이': ('sq110_spinning_child', 32, 'ash_reeds', '채집', '갈대 영사로 실을 잣는 반요 아이'),
    '거꾸로 매달린 동자': ('sq110_hanging_boys', 33, 'inverted_shrine', '전투', '처마에 거꾸로 매달린 동자들이 바로 세워 달라고 한다'),
    '거꾸로 피우는 향': ('sq110_inverted_incense', 34, 'inverted_shrine', '채집', '거꾸로 피운 향 연기가 잃은 것을 찾아 준다'),
    '이름 잃은 사공의 탈': ('sq110_ferryman_mask', 35, 'ash_reeds', '제작', '얼굴을 잃은 사공에게 탈을 지어 준다'),
    '기억 저울 장수': ('sq110_memory_scale', 36, 'moonless_market', '전투', '남의 기억을 싸게 사들이던 장수'),
    '달을 판 상주': ('sq110_moon_mourner', 37, 'moonless_market', '채집', '장례 비용을 치르려고 달을 판 상주'),
    '전당포 거미의 장부': ('sq110_pawn_spider', 37, 'moonless_market', '제작', '맡은 물건을 돌려주기 싫은 전당포 거미'),
    '귀허 진주 낚싯대': ('sq110_pearl_rod', 38, 'gwiheo_core', '제작', '마지막으로 귀허에 줄을 드리우고 싶은 노인'),
    '돌아오는 파도': ('sq110_returning_wave', 39, 'gwiheo_core', '전투', '귀허에서는 떠난 것이 파도가 되어 돌아온다'),
}
CHAIN = {
    '아버지의 등짐': ('cq110_pack_1', 14, 'nine_lighthouse', '외상 장부를 멘 등짐장수 오누이가 꺼진 등대를 찾아온다', ['mq_frost_seal']),
    '옥에 갇힌 외상값': ('cq110_pack_2', 19, 'old_prison', '외상을 진 사람이 옥사에서 옥귀가 되어 있다', ['cq110_pack_1']),
    '받지 말 것': ('cq110_pack_3', 24, 'tide_gate', '장부 한 줄에 아버지 글씨로 「받지 말 것」', ['cq110_pack_2']),
    '아버지가 마지막으로 판 것': ('cq110_pack_4', 29, 'black_tide_rift', '아버지의 마지막 흔적이 균열로 이어진다', ['cq110_pack_3']),
    '이름을 사러 온 손님': ('cq110_pack_5', 33, 'ash_reeds', '반요촌에 이름을 잃어 가는 등짐장수가 있다', ['cq110_pack_4', 'mq_nine_gates']),
    '뚝딱이 어디 갔나': ('cq110_bat_1', 6, 'red_plain', '꼬마 도깨비 방울이 할아버지의 방망이를 잃어버렸다', ['mq_drowned_ledger']),
    '물에 비친 방망이': ('cq110_bat_2', 9, 'mirror_pavilion', '수경루 물거울에 방망이가 비친다', ['cq110_bat_1']),
    '방망이 든 사슴': ('cq110_bat_3', 12, 'red_forest', '혈엽림 사슴귀가 방망이를 물고 달아났다', ['cq110_bat_2']),
    '벼락 맞은 금 나와라': ('cq110_bat_4', 16, 'thunder_peak', '뇌명봉에 금이 비처럼 쏟아졌다는 소문', ['cq110_bat_3']),
    '마지막 뚝딱': ('cq110_bat_5', 20, 'white_tower', '방망이로 빌 수 있는 소원은 하나뿐이다', ['cq110_bat_4']),
    '그림 속 광부': ('cq110_paint_1', 23, 'under_root', '떠돌이 화공의 초상 속 광부가 밤마다 그림 밖을 내다본다', ['mq_eclipse_gate']),
    '압수된 초상': ('cq110_paint_2', 26, 'seal_vault', '봉인고에 압수된 초상들이 서로를 부른다', ['cq110_paint_1']),
    '물에 젖지 않는 그림': ('cq110_paint_3', 30, 'sealed_abyss', '봉연 물속에서도 젖지 않는 그림 한 장', ['cq110_paint_2']),
    '거꾸로 그린 얼굴': ('cq110_paint_4', 34, 'inverted_shrine', '사당에 거꾸로 걸린 화공의 자화상', ['cq110_paint_3', 'mq_nine_gates']),
    '값을 매길 수 없는 그림': ('cq110_paint_5', 38, 'moonless_market', '저잣거리에 화공의 마지막 그림이 매물로 나왔다', ['cq110_paint_4']),
}
SEQUEL = {
    '내일 하려던 부탁': ('sq110_s_cheolbu', 19, 'comet_crater', '전투', '열두 해 미뤄 둔 대장장이 철부의 부탁', ['sq_ash_mountain_2']),
    '돌아보지 않은 이름': ('sq110_s_maenggu', 21, 'under_root', '전투', '막장에서 돌아보지 않았던 부름이 더 깊은 갱에서 다시 들린다', ['sq_crimson_mine_2']),
    '이름을 찾은 사환': ('sq110_s_sahwan', 22, 'crimson_altar', '전투', '흑사단 이름들이 팔려 간 장부를 쫓는다', ['sq_black_sand_temple_2']),
    '돌아온 배': ('sq110_s_suchil', 24, 'tide_gate', '낚시', '수문지기가 기다리던 배가 만조에 떠밀려 온다', ['sq_old_canal_1']),
    '흰 달의 제자': ('sq110_s_eunsil', 25, 'crimson_altar', '제작', '흰 달로 약을 달이는 노파가 제자를 찾는다', ['sq_red_moon_fort_2']),
    '막내가 이끄는 호송대': ('sq110_s_chorong', 27, 'seal_vault', '전투', '막내 초롱이 처음으로 호송대장이 되었다', ['sq_jade_pass_2']),
    '동생의 거울': ('sq110_s_yunpal', 28, 'seal_vault', '전투', '못 살린 동생의 얼굴이 압수 거울에 비친다', ['sq_ghost_bamboo_2']),
    '대답한 등대': ('sq110_s_byeolsun', 28, 'black_tide_rift', '제작', '그날 대답하듯 깜빡인 다른 등대', ['sq_nine_lighthouse_1']),
    '빚 갚는 배': ('sq110_s_chaeun', 31, 'black_tide_rift', '낚시', '흑련회가 정말 빚을 받으러 왔다', ['sq_black_tide_rift_2']),
    '도망친 끝': ('sq110_s_somae', 32, 'ash_reeds', '전투', '적월교를 떠난 순례자가 도망친 끝', ['rq_crimson_altar']),
    '명부의 나머지 줄': ('sq110_s_yeohwi', 33, 'inverted_shrine', '조사', '망국 사관이 남긴 줄의 나머지가 사당에 거꾸로 적혀 있다', ['sq_forgotten_city_1']),
    '빌려준 얼굴': ('sq110_s_haerang', 36, 'moonless_market', '전투', '거울 속 또 하나의 얼굴이 저잣거리에서 팔리고 있다', ['sq_glass_canyon_2']),
    '지팡이에 새긴 이름': ('sq110_s_sapyeong', 37, 'moonless_market', '채집', '순례자들의 지팡이가 좌판에 묶음으로 나왔다', ['sq_red_plain_1']),
    '아들을 낚는 줄': ('sq110_s_eodu', 38, 'gwiheo_core', '낚시', '떠난 것이 돌아오는 바다에 늙은 낚시꾼이 마지막 줄을 드리운다', ['sq_black_tide_rift_1']),
}
SEQUEL.update({
    '대호법이 외운 이름': ('sq110_f_redmoon', 23, 'crimson_altar', '세력', '대호법이 외운 이름 하나가 제단에서 지워지려 한다', ['sq_red_moon_fort_1']),
    '맡긴 이름의 이자': ('sq110_f_lotus', 22, 'under_root', '세력', '흑련회 장부에 맡긴 이름에도 이자가 붙는다', ['sq_under_root_1']),
    '얼음 맹세를 잇는 사람': ('sq110_f_north', 18, 'thunder_peak', '세력', '북령 맹약을 처음 맺은 이들의 마지막 하나', ['sq_frost_valley_2']),
    '뱃길 장부의 빈칸': ('sq110_f_river', 25, 'tide_gate', '세력', '수향 뱃길 장부에 일부러 비워 둔 칸', ['sq_sunken_palace_1']),
    '바다로 옮긴 불씨': ('sq110_f_south', 20, 'nine_lighthouse', '세력', '고개의 봉화 불씨를 남명의 바다로 옮긴다', ['rq_ember_pass']),
    '예언하지 않은 날': ('sq110_f_mandate', 26, 'star_observatory', '세력', '천명원이 예언하지 않기로 한 단 하루', ['rq_comet_crater']),
    '서고 맨 끝 칸': ('sq110_f_office', 31, 'seal_vault', '세력', '서리 문수가 서고 맨 끝 칸의 목록을 본다', ['sq_hq_yard_1', 'mq_lamp_shadow']),
    '먹을 사는 사람': ('sq110_e_ink', 37, 'moonless_market', '외전', '먹귀가 붙든 기억을 사들이는 흑련회 거둠꾼', ['mq_nine_gates']),
    '지워지는 문패': ('sq110_e_doorplate', 39, 'ash_reeds', '외전', '문패 글자가 지워지는 나루에서 떠밀려 온 반요', ['mq_nine_gates']),
    '봉연 물길의 표식': ('sq110_e_mark', 30, 'sealed_abyss', '외전', '봉연 물길로 떠내려온 옛 조사원의 표식', ['mq_lamp_shadow']),
    '천 번째 학': ('sq110_s_bomi', 20, 'cloud_corridor', '채집', '다 접은 천 마리 학이 날아간 곳', ['sq_paper_bridge_1']),
    '숲이 배운 노래': ('sq110_s_cheongun', 21, 'red_forest', '전투', '누이의 노래를 혈엽림에서 다시 듣는다', ['sq_ghost_bamboo_1']),
    '삼십 년 계약의 끝': ('sq110_s_yeonsu', 20, 'lotus_marsh', '전투', '연근식귀와 맺은 삼십 년 계약의 마지막 해', ['sq_lotus_marsh_2']),
    '수좌가 되던 날': ('sq110_s_doyun', 22, 'iron_monastery', '조사', '목탁 치던 행자가 수좌가 되는 시험', ['sq_iron_monastery_1']),
    '술값으로 갚겠다던 빚': ('sq110_s_dalgu', 21, 'comet_crater', '채집', '술값으로 갚겠다던 빚을 진짜로 갚으러 왔다', ['sq_bone_market_2']),
    '칼 대신 바구니': ('sq110_s_yeonok', 22, 'white_tower', '전투', '바구니를 든 순찰 의원이 순찰대를 이끈다', ['sq_field_outskirts_2']),
    '섬까지 온 등잔 장수': ('sq110_s_soetdae', 35, 'inverted_shrine', '제작', '덤을 주던 등잔 장수가 귀허도까지 건너왔다', ['rq_lamp_alley', 'mq_nine_gates']),
})
SEQUEL.update({
    '월식 아래 남은 사람들': ('sq110_f_redmoon2', 29, 'crimson_altar', '세력', '월식이 지나간 뒤 제단터에 남은 사람들', ['sq110_f_redmoon']),
    '회주의 장부': ('sq110_f_lotus2', 28, 'under_root', '세력', '흑련회 회주가 따로 지키는 장부', ['sq110_f_lotus']),
    '맹약지의 겨울잠': ('sq110_f_north2', 24, 'thunder_peak', '세력', '맹세를 이은 뒤 맞는 북령의 첫겨울', ['sq110_f_north']),
    '빈칸에 이름을 쓰는 날': ('sq110_f_river2', 30, 'tide_gate', '세력', '뱃길 장부의 빈칸에 이름을 적는 날', ['sq110_f_river']),
    '망국의 마지막 백성': ('sq110_f_south2', 29, 'black_tide_rift', '세력', '남명이 무너진 뒤에도 남아 있는 백성들', ['sq110_f_south']),
    '예언을 깨뜨린 별': ('sq110_f_mandate2', 32, 'white_tower', '세력', '천명원의 예언을 처음 깨뜨린 별', ['sq110_f_mandate']),
    '거두지 않은 이름': ('sq110_f_office2', 35, 'seal_vault', '세력', '정청이 끝내 거두지 않은 이름 하나', ['sq110_f_office']),
})
META.update({
    '물수제비 할아범': ('sq111_skipping_stone', 13, 'sky_lake', '낚시', '천경호에서 물수제비로 물고기를 잡는다고 우기는 할아범'),
    '등대지기의 저녁상': ('sq111_keeper_supper', 18, 'nine_lighthouse', '낚시', '혼자 남은 등대지기가 손님상을 차리고 싶어 한다'),
    '뿌리 약초꾼의 마지막 약': ('sq111_root_herbalist', 22, 'under_root', '채집', '눈이 먼 약초꾼이 마지막으로 지을 약의 재료'),
    '제단에 바칠 떡': ('sq111_altar_cake', 23, 'crimson_altar', '제작', '어린 교도가 처음 맡은 공물 떡을 망쳤다'),
    '만조에 낚는 편지': ('sq111_tide_letter', 23, 'tide_gate', '낚시', '만조 때마다 병에 든 편지가 갑문으로 떠밀려 온다'),
    '갑문 아래 조개 무덤': ('sq111_clam_grave', 25, 'tide_gate', '채집', '갑문 아래 조개들이 사람 소리로 운다'),
    '관성대 망원경 닦개': ('sq111_lens_cloth', 26, 'star_observatory', '제작', '망원경 알을 닦다 별을 지워 버렸다는 견습 관측관'),
    '봉인고 먼지 털이': ('sq111_vault_dust', 27, 'seal_vault', '채집', '봉인고 대청소 날, 먼지마다 요기가 붙어 있다'),
    '균열 끝의 은갈치': ('sq111_rift_cutlass', 28, 'black_tide_rift', '낚시', '어부들의 몫을 가로채던 선주의 그물에 걸린 것'),
    '반요촌 대장간의 첫 쇠': ('sq111_first_iron', 30, 'banyo_village', '제작', '반요촌에 처음 대장간을 연 반요 대장장이'),
    '봉연 물밑 낚시꾼': ('sq111_abyss_angler', 30, 'sealed_abyss', '낚시', '봉연 물가에 앉아 사람 아닌 것을 낚는 낚시꾼'),
    '사슬 매듭 풀기': ('sq111_chain_knot', 31, 'sealed_abyss', '제작', '봉연의 사슬에 묶인 채 굳은 매듭을 풀어 달라는 목소리'),
    '봉연 이끼 따기': ('sq111_abyss_moss', 31, 'sealed_abyss', '채집', '봉연 벽 이끼로 약을 짓는 늙은 봉인관'),
    '반요촌 아이들의 첫 물고기': ('sq111_first_fish', 31, 'ash_reeds', '낚시', '물고기를 한 번도 잡아 본 적 없는 반요 아이들'),
    '갈대숲 사냥꾼의 빚': ('sq111_hunter_debt', 32, 'ash_reeds', '전투', '갈대숲에서 사라진 사냥꾼이 남긴 빚 문서'),
    '갈대숲 혼례 상': ('sq111_reed_wedding', 32, 'ash_reeds', '제작', '반요촌에서 처음 올리는 혼례의 잔칫상'),
    '거꾸로 짠 이불': ('sq111_inverted_quilt', 33, 'inverted_shrine', '제작', '거꾸로 매달린 동자들이 덮을 이불'),
    '사당 지붕 기와': ('sq111_shrine_tiles', 33, 'inverted_shrine', '채집', '거꾸로 선 사당의 기와가 하늘로 떨어진다'),
    '흑조 균열 만선 잔치': ('sq111_full_catch', 33, 'black_tide_rift', '낚시', '열 해 만에 만선을 꿈꾸는 늙은 어부들'),
    '사당 종지기 원혼': ('sq111_bell_ringer', 34, 'inverted_shrine', '전투', '종을 거꾸로 쳐서 마을을 망친 종지기의 원혼'),
    '사당의 마지막 신도': ('sq111_last_believer', 35, 'inverted_shrine', '전투', '아무도 오지 않는 사당을 홀로 지키는 신도'),
    '저잣거리 향신료 도둑': ('sq111_spice_thief', 35, 'moonless_market', '채집', '향을 훔쳐 먹는 꼬마 요괴들'),
    '갈대숲 물귀신 낚기': ('sq111_reed_drowned', 35, 'ash_reeds', '낚시', '갈대숲 물웅덩이에서 사람을 끌어당기는 것'),
    '저잣거리 소매치기 그림자': ('sq111_shadow_pickpocket', 36, 'moonless_market', '전투', '사람의 그림자를 훔쳐 파는 소매치기'),
    '달 없는 밤의 등롱 장인': ('sq111_lantern_maker', 36, 'moonless_market', '제작', '달이 없는 저잣거리에 달 대신 걸 등롱'),
    '봉연 끝의 낚시 대회': ('sq111_abyss_contest', 36, 'sealed_abyss', '낚시', '봉인관들이 몰래 여는 낚시 대회'),
    '망각 수정 캐는 노인': ('sq111_crystal_miner', 37, 'moonless_market', '채집', '잊고 싶은 것이 있어 망각 수정을 캐는 노인'),
    '귀허 문턱의 파수꾼': ('sq111_threshold_guard', 38, 'gwiheo_core', '전투', '귀허 문턱을 혼자 지켜 온 옛 조사원의 넋'),
    '귀허 갯벌의 진주조개': ('sq111_pearl_clams', 38, 'gwiheo_core', '채집', '귀허 갯벌의 조개는 잊힌 이름을 품는다'),
    '귀허로 띄우는 배': ('sq111_paper_boat', 39, 'gwiheo_core', '제작', '돌아오지 못한 이들에게 띄우는 배'),
    '귀허의 마지막 낚시꾼': ('sq111_last_angler', 39, 'gwiheo_core', '낚시', '귀허에서 무엇을 낚는지 아무도 모르는 낚시꾼'),
})
CHAIN_NAME = {'cq110_pack': '아버지의 등짐', 'cq110_bat': '도깨비 방망이 분실 사건', 'cq110_paint': '무명 화공의 그림'}
JOB_META = {}
for jn, jk in JOBS.items():
    JOB_META[(jn, 18)] = f'jq2_{jk}'
    JOB_META[(jn, 32)] = f'jq3_{jk}'

ITEMS = REF['items']; MONS = REF['monsters']; REGIONS = REF['regions']; RECIPES = REF['recipes']; SPOTS = REF['spots']; FISH = set(REF['fishing'])
NPC_OLD = dict(REF['npcs'])
SX_SEEN = {}
for _k, _n in json.load(open(os.path.join(HERE, '..', 'gen744', 'data', 'speakers.json'), encoding='utf-8')).items():
    if not _k.startswith('q:'): NPC_OLD.setdefault(_n, _k)
REGION_NAMES = sorted(REGIONS, key=len, reverse=True)
ITEM_NAME = {v: k for k, v in ITEMS.items()}
MON_NAME = {m[0]: k for k, v in MONS.items() for m in v}
REGION_NAME = {v[0]: k for k, v in REGIONS.items()}
errors = []

def item_id(name):
    name = name.strip()
    if name in ITEMS: return ITEMS[name]
    errors.append(f'물품 이름 모름: {name}'); return name

def region_of(text):
    for n in REGION_NAMES:
        if n in text: return REGIONS[n][0]
    return None

def mon_id(name, regions):
    name = name.strip()
    c = MONS.get(name)
    if not c:
        errors.append(f'요괴 이름 모름: {name}'); return name, None
    for mid, rg, lv, role in c:
        if rg in regions: return mid, role
    return c[0][0], c[0][3]

def split_tasks(s):
    return [p.strip() for p in re.split(r'\s*[·,]\s*|\s+그리고\s+', s) if p.strip()]

def parse_task(p, ctx_regions, qid):
    r = region_of(p)
    regs = [r] if r else ctx_regions
    body = p
    for n in REGION_NAMES:
        body = body.replace(n + '에서', '').replace(n + ' 곁에서', '').replace(n, '')
    body = re.sub(r'\(.*?\)', '', body).strip()
    m = re.match(r'^(?:.*\s)?탐색\s*(\d+)\s*회?$', body)
    if m: return ('task', {'t': 'search', 'r': regs[:1], 'n': int(m.group(1))})
    m = re.match(r'^(?:.*\s)?낚시\s*(\d+)\s*회?$', body)
    if m:
        rr = regs[:1]
        if rr and rr[0] not in FISH: errors.append(f'{qid}: 낚시터 없는 곳 {rr[0]}')
        return ('task', {'t': 'fish', 'r': rr, 'n': int(m.group(1))})
    m = re.match(r'^(.+?)\s*(\d+)\s*(?:개|마리|줌|덩이|그릇|벌)?\s*(모으기|처치|만들기|넘기기|캐기|쫓기)$', body)
    if not m:
        errors.append(f'{qid}: 할 일을 못 읽음 — {p}'); return None
    name, n, verb = m.group(1).strip(), int(m.group(2)), m.group(3)
    if (name not in ITEMS and verb not in ('처치', '쫓기')) or (name not in MONS and verb in ('처치', '쫓기')):
        full = re.sub(r'\s*\d+\s*(?:개|마리|줌|덩이|그릇|벌)?\s*(모으기|처치|만들기|넘기기|캐기|쫓기)$', '', re.sub(r'^.*?에서\s+', '', p)).strip()
        if full in ITEMS or full in MONS: name = full
    if verb in ('모으기', '캐기'):
        iid = item_id(name)
        rr = regs[:1]
        if rr and iid not in SPOTS.get(rr[0], []): errors.append(f'{qid}: {rr[0]} 채집터에 {name} 없음')
        return ('task', {'t': 'gather', 'items': [iid], 'r': rr, 'n': n})
    if verb in ('처치', '쫓기'):
        mid, role = mon_id(name, regs)
        t = {'t': 'win', 'm': [mid], 'n': n}
        return ('task', t)
    if verb == '만들기':
        iid = item_id(name)
        if iid not in RECIPES: errors.append(f'{qid}: 제작법 없음 {name}')
        return ('task', {'t': 'craft', 'items': [iid], 'n': n})
    if verb == '넘기기':
        return ('give', (item_id(name), n))

def parse_files(paths):
    quests = []; cur = None; scene = None
    for path in paths:
        for raw in open(path, encoding='utf-8'):
            line = raw.rstrip('\n')
            h = re.match(r'^###\s+(.+)$', line)
            if h and not line.startswith('####'):
                head = h.group(1)
                t = re.search(r'「(.+?)」', head)
                if not t: cur = None; continue
                title = t.group(1)
                job = next((j for j in JOBS if head.startswith(j)), None)
                lv = re.search(r'Lv\s*(\d+)', head)
                if job:
                    L = int(lv.group(1)); qid = JOB_META.get((job, L))
                    if not qid: errors.append(f'직업 퀘스트 레벨 모름: {head}'); cur = None; continue
                    parts = [x.strip() for x in head.split('·')]
                    reg = region_of(head.split('」', 1)[1]) or None
                    cur = dict(id=qid, title=title, L=L, region=reg, cat=f'직업·{job}', job=JOBS[job], summary='', npcs={}, scenes=[])
                elif title in CHAIN:
                    qid, L, reg, summ, aft = CHAIN[title]
                    cur = dict(id=qid, title=title, L=L, region=reg, cat='연계·' + CHAIN_NAME[qid[:-2]], job=None, summary=summ, npcs={}, scenes=[], after=aft)
                elif title in SEQUEL:
                    qid, L, reg, cat, summ, aft = SEQUEL[title]
                    cur = dict(id=qid, title=title, L=L, region=reg, cat=f"{cat}·{REGION_NAME.get(reg, reg)}", job=None, summary=summ, npcs={}, scenes=[], after=aft)
                elif title in META:
                    qid, L, reg, cat, summ = META[title]
                    cur = dict(id=qid, title=title, L=L, region=reg, cat=f"{cat}·{REGION_NAME.get(reg, reg)}", job=None, summary=summ, npcs={}, scenes=[])
                else:
                    cur = None; continue
                if any(q['id'] == cur['id'] for q in quests): errors.append(f'퀘스트 겹침: {title}')
                quests.append(cur); scene = None; continue
            if cur is None: continue
            if line.startswith('인물:'):
                for key, name, bio in re.findall(r'`(sx_[a-z0-9_]+)`\s*([^(·`]+?)\s*\(([^)]*)\)', line):
                    cur['npcs'][name.strip()] = ('q:' + key, bio.strip())
                    SX_SEEN[name.strip()] = ('q:' + key, bio.strip())
                for name, v in SX_SEEN.items():
                    if name in line and name not in cur['npcs']: cur['npcs'][name] = v
                for name in NPC_OLD:
                    if name in line and name not in cur['npcs']: cur['npcs'][name] = (NPC_OLD[name], None)
                continue
            s = re.match(r'^####\s+장면\s*(\d+)\s*·\s*(.+?)\s*\((받기|보고)\s*:\s*(.+?)\)\s*$', line)
            if s:
                scene = dict(title=s.group(2).strip(), place=region_of(s.group(4)) or cur['region'], lines=[], todo=None)
                if not region_of(s.group(4)): errors.append(f"{cur['id']}: 장면 곳 모름 — {s.group(4)}")
                cur['scenes'].append(scene); continue
            if scene is None: continue
            l = re.match(r'^-\s+([^:]+?):\s*(.+)$', line)
            if not l: continue
            who, text = l.group(1).strip(), l.group(2).strip()
            if who == '할 일': scene['todo'] = text; continue
            if who == '서술': scene['lines'].append({'s': None, 't': text}); continue
            key = None
            for name, (k, _) in cur['npcs'].items():
                if who == name or name.endswith(who) or who in name.split(): key = k; break
            if not key: errors.append(f"{cur['id']}: 말하는 이 모름 — {who}")
            scene['lines'].append({'s': key, 't': text})
    return quests


def goal_text(tasks, give):
    out = []
    for t in tasks:
        if t['t'] == 'gather': out.append(f"{ITEM_NAME.get(t['items'][0], t['items'][0])}을(를) 모은다")
        elif t['t'] == 'win': out.append(f"{MON_NAME.get(t['m'][0], t['m'][0])}을(를) 물리친다")
        elif t['t'] == 'craft': out.append(f"{ITEM_NAME.get(t['items'][0], t['items'][0])}을(를) 만든다")
        elif t['t'] == 'search': out.append(f"{REGION_NAME.get(t['r'][0], t['r'][0])}을(를) 살핀다")
        elif t['t'] == 'fish': out.append(f"{REGION_NAME.get(t['r'][0], t['r'][0])}에서 낚시를 한다")
    for k in give: out.append(f"{ITEM_NAME.get(k, k)}을(를) 넘긴다")
    return ', '.join(out)

def T(s): return 'null' if s is None else "'" + str(s).replace("'", "''") + "'"
def J(o): return T(json.dumps(o, ensure_ascii=False)) + '::jsonb'

def reward_items(L): return dict(next(it for top, it in RULES['items'] if L <= top))

def build(quests):
    out = []; w = out.append
    w("lock table public.world_characters in access exclusive mode;")
    npcs = {}
    for q in quests:
        for name, (k, bio) in q['npcs'].items():
            if k.startswith('q:sx_'):
                if name in NPC_OLD: errors.append(f'{q["id"]}: 기존 인물과 이름 겹침 {name}')
                if k in npcs and npcs[k][0] != name: errors.append(f'인물 키 겹침 {k}')
                npcs[k] = (name, bio or name)
    seen_names = {}
    for k, (name, bio) in npcs.items():
        short = name
        if short in seen_names and seen_names[short] != k: errors.append(f'인물 이름 겹침: {name} ({k}, {seen_names[short]})')
        seen_names[short] = k
    for k, (name, bio) in sorted(npcs.items()):
        w(f"insert into public.world_quest_npcs(npc_key, npc_name, bio) values ({T(k)}, {T(name)}, {T(bio)}) on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;")
    for i, q in enumerate(sorted(quests, key=lambda x: (x['L'], x['id']))):
        sc = q['scenes']
        if len(sc) < 2: errors.append(f"{q['id']}: 장면이 둘보다 적음"); continue
        steps = []
        for k, s in enumerate(sc):
            need = {'at': [s['place']]}
            goal = s['title']
            if k > 0:
                todo = sc[k - 1]['todo']
                if not todo: errors.append(f"{q['id']}: 장면 {k} 끝에 할 일이 없음")
                else:
                    tasks, give = [], {}
                    ctx = [sc[k - 1]['place'], s['place'], q['region']]
                    for p in split_tasks(todo):
                        r = parse_task(p, [x for x in ctx if x], q['id'])
                        if not r: continue
                        if r[0] == 'task': tasks.append(r[1])
                        else: give[r[1][0]] = give.get(r[1][0], 0) + r[1][1]
                    for t in tasks:
                        if t['t'] == 'craft':
                            for iid in t['items']:
                                if iid not in give: give[iid] = t['n']
                    if tasks: need['tasks'] = tasks
                    if give: need['give'] = give
                    goal = goal_text(tasks, give)
                    for t in tasks:
                        if t['t'] in ('search', 'fish', 'gather') and t.get('r') and t['r'][0] in ISLAND and q['L'] < 30: errors.append(f"{q['id']}: 섬 할 일인데 레벨 낮음")
            elif sc[-1]['todo']:
                pass
            steps.append([s['title'], goal, need, s['lines']])
        if sc[-1]['todo']: errors.append(f"{q['id']}: 마지막 장면에 할 일이 있음")
        L = q['L']; tot = round(RULES['xp'] * xp_need(L))
        task_steps = [k for k, st in enumerate(steps) if st[2].get('tasks') or st[2].get('give')]
        per = tot // max(1, len(task_steps))
        after = list(q.get('after', []))
        if q['job']:
            after = [f"jq_{q['job']}"] if L < 30 else [f"jq2_{q['job']}"]
        if (q['region'] in ISLAND or L >= 31) and 'mq_nine_gates' not in after: after.append('mq_nine_gates')
        if not q['summary']: q['summary'] = q['title']
        w(f"""insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ({T(q['id'])}, 'side', {T(q['cat'])}, {T(q['title'])}, {T(q['summary'])}, {T(q['region'])}, {L}, {T('{' + ','.join(after) + '}')}::text[], null, {1100 + i}, '[]'::jsonb, true, {T(q['job'])}, null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;""")
        w(f"delete from public.world_quest_steps where quest_id = {T(q['id'])} and step > {len(steps)};")
        for k, (title, goal, need, ls) in enumerate(steps):
            rw = {}
            if k in task_steps: rw['xp'] = per
            if k == len(steps) - 1:
                rw['gil'] = RULES['gil'][0] + RULES['gil'][1] * L; rw['items'] = reward_items(L)
            w(f"""insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ({T(q['id'])}, {k + 1}, {T(title)}, {T(goal)}, {J(need)}, {J(ls)}, {J(rw)})
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;""")
    w('select public.world_quest_label_refresh();')
    w("update public.world_app_meta set value = '20261108040000' where key = 'db_version';")
    return '\n'.join(out) + '\n'

if __name__ == '__main__':
    files = [os.path.join(HERE, f) for f in ('plan.md', 'script_a.md', 'script_b.md', 'script_c.md', 'script_d.md', 'script_e.md', 'script_f.md', 'script_g.md', 'script_h.md', 'script_i.md', 'script_j.md', 'script_k.md', 'script_l.md', 'script_m.md', 'script_n.md', 'script_o.md') if os.path.exists(os.path.join(HERE, f))]
    qs = parse_files(files)
    sql = build(qs)
    missing = [t for t in list(META) + list(CHAIN) + list(SEQUEL) if t not in {q['title'] for q in qs}]
    if missing: print('대본 없음:', ', '.join(missing))
    if errors:
        print('\n'.join(errors)); sys.exit(1)
    open(OUT, 'w', encoding='utf-8').write(sql)
    print(f'퀘스트 {len(qs)} · 인물 · {OUT}')
