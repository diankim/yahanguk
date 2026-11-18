HUBS = [
    ('night', 'f:night_office', 'lantern_market'),
    ('red', 'f:red_moon_cult', 'bone_market'),
    ('lotus', 'f:black_lotus', 'hidden_bazaar'),
    ('north', 'f:north_league', 'iron_monastery'),
    ('river', 'f:river_alliance', 'river_ferry'),
    ('south', 'f:southern_remnant', 'ember_village'),
    ('mandate', 'f:mandate_court', 'star_observatory'),
    ('gw', 'c:gwiheo', 'banyo_village'),
    ('mk', 'c:mukjeok', 'mukchang_ferry'),
    ('dd', 'c:deungdo', 'deungdo_landing'),
]

META, OPEN = {}, {}
for key, pj, reg in HUBS:
    for n in range(1, 6):
        q = f'ep_{key}_{n}'
        META[q] = (50, reg, '뒷이야기', ['mdq_17'] + ([f'ep_{key}_{n - 1}'] if n > 1 else []))
        OPEN[q] = {'project': pj, 'stage': n}

X = {
    'ep_x_doorkeeper': ('sealed_abyss', ['mq_nine_gates', 'mdq_17']),
    'ep_x_clerk': ('hq_yard', ['mq_nine_gates', 'mdq_17']),
    'ep_x_lighthouse': ('nine_lighthouse', ['mq_nine_gates', 'mdq_17']),
    'ep_x_sawol': ('red_plain', ['mq_nine_gates', 'mde_danbi_2']),
    'ep_x_mukho': ('banyo_village', ['gq_5', 'mdq_17']),
    'ep_x_yeoul': ('ash_reeds', ['gq_5', 'mdq_17']),
    'ep_x_hongmae': ('mukchang_ferry', ['mkq_5', 'mdq_17']),
    'ep_x_seoha': ('mukchang_ferry', ['mke_daon_3', 'mdq_17']),
    'ep_x_solnae': ('frost_pine_pass', ['mde_hanseol']),
    'ep_x_pine': ('dark_yamen', ['mdq_17']),
}
META['ep_night_2'] = (50, 'hq_dorm', '뒷이야기', META['ep_night_2'][3])
for q, (reg, after) in X.items():
    META[q] = (50, reg, '뒷이야기', after)

NPCS = {
    'q:sx_ep_notdan': ('놋쇠장이 놋단', '백골 장터 놋쇠장이 아낙. 쇳물 국자를 어깨에 메고 다니고, 튄 불똥을 맨손으로 털어 낸다.'),
    'q:sx_ep_trainee': ('연무청 수련생', '정통파 연무청의 어린 수련생. 묻기를 좋아한다.'),
    'q:sx_ep_follower': ('적월 교도', '옛 교법을 고집하는 적월교 교도.'),
    'q:sx_ep_marketwife': ('장터 아낙', '백골 장터에서 육포를 파는 수다스러운 아낙.'),
    'q:sx_ep_kkeutsun': ('버선 가게 끝순', '십삼문에서 마흔 해 버선 가게를 한 흑련 회원. 흑련에서는 「골무」로 불렸다.'),
    'q:sx_ep_gaprye': ('심지 장수 갑례', '등잔골 뒷골목에서 등잔 심지를 꼬는 노파. 열 해 동안 「심지 할멈」으로만 불렸다.'),
    'q:sx_ep_sosik': ('흑련 소식꾼', '등잔골 어귀 좌판에서 소문을 사고파는 젊은 흑련 소식꾼.'),
    'q:sx_ep_daepae': ('흑련 목수 대패', '대팻밥을 뒤집어쓰고 다니는 흑련 목수. 나무를 집으면 코부터 갖다 댄다.'),
    'q:sx_ep_bongsu': ('행자 봉수', '철벽 고찰 막내 행자. 바람에 볼이 텄고 지고는 못 산다.'),
    'q:sx_ep_eokbo': ('썰매꾼 억보', '북령맹 호송대 썰매꾼. 긴장하면 말을 더듬고 썰매 줄 매듭을 풀었다 맨다.'),
    'q:sx_ep_jjanmul': ('소금 장수 짠물댁', '십삼문 밀수 부두 소금 장수. 셈 끝에 늘 「밑지는 장사」를 붙인다.'),
}
NEW_SPEAK = {
    '놋단': 'q:sx_ep_notdan', '수련생': 'q:sx_ep_trainee', '교도': 'q:sx_ep_follower', '장터 아낙': 'q:sx_ep_marketwife',
    '끝순': 'q:sx_ep_kkeutsun', '심지 장수': 'q:sx_ep_gaprye', '소식꾼': 'q:sx_ep_sosik', '대패': 'q:sx_ep_daepae',
    '봉수': 'q:sx_ep_bongsu', '억보': 'q:sx_ep_eokbo', '짠물댁': 'q:sx_ep_jjanmul',
    '강두철': 'night_office:kang', '문서진': 'mandate_court:mun', '마일수': 'q:dh_ilsu', '고분': 'q:dh_gopun',
    '복례': 'q:sn_bokrye', '쇠불': 'q:sn_soebul', '달래': 'q:sn_dalrae', '옥분': 'q:sn_okbun',
    '운해': 'q:bl_unhae', '묵호': 'q:g_mukho', '여울': 'q:g_yeoul', '단이': 'q:g_dani',
    '상쇠': 'q:sx_sangsoe', '마루': 'q:sx_maru', '솔래': 'q:sx_sollae', '풀무': 'q:sx_pulmu',
    '홍매댁': 'q:ug_hongmae', '차랑': 'q:ug_charang', '묵창댁': 'q:sx_mk_jumak', '덕배': 'q:sx_mk_gukbap', '노을': 'q:sx_mk_sagong',
    '도화': 'q:m_dohwa', '사월': 'q:m_sawol',
}

NAME_OK = {('장터', '장수'), ('끝순', '끝예'), ('갑례', '갑술'), ('대패', '대살'), ('대패', '대복'), ('봉수', '봉순'), ('봉수', '봉구'), ('억보', '억쇠')}
