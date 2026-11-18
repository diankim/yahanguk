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
for q, (reg, after) in X.items():
    META[q] = (50, reg, '뒷이야기', after)

NPCS = {}
NEW_SPEAK = {}
