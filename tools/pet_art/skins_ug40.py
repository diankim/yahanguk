import colorsys
import copy
import importlib.util
import os

HERE = os.path.dirname(os.path.abspath(__file__))
_s = importlib.util.spec_from_file_location('data', os.path.join(HERE, 'data.py'))
_d = importlib.util.module_from_spec(_s)
_s.loader.exec_module(_d)
BASE = {p['id']: p for p in _d.PETS}
KEEP = {'e', 'i', 'p', 'k', 'w'}
SKINS = []


def tint(hexc, hue, sat, light, spread):
    r, g, b = (int(hexc[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if s < 0.08 and (l < 0.15 or l > 0.9):
        return hexc
    nh = (hue + spread * (h - 0.5) * 0.15) % 1
    ns = min(1, max(0.12, s * sat + 0.12))
    nl = min(0.92, max(0.12, l * light))
    r, g, b = colorsys.hls_to_rgb(nh, nl, ns)
    return '#%02x%02x%02x' % (round(r * 255), round(g * 255), round(b * 255))


def recolor(form, hue, sat=1.0, light=1.0, spread=1.0, extra=None):
    f = copy.deepcopy(form)
    pal = dict(f['pal'])
    for k, v in pal.items():
        if k not in KEEP:
            pal[k] = tint(v, hue, sat, light, spread)
    pal.update(extra or {})
    f['pal'] = pal
    return f


def skin(key, pet, name, desc, hue, sat=1.0, light=1.0, spread=1.0, extra=None):
    b = BASE[pet]
    SKINS.append(dict(key=key, pet=pet, name=name, desc=desc,
                      baby=recolor(b['baby'], hue, sat, light, spread, extra), adult=recolor(b['adult'], hue, sat, light, spread, extra)))


skin('ug_rift_seahorse', 'bj_seahorse', '물목 해마',
     '뒤집힌 물목이 제 방향으로 돌던 밤, 쪽빛 물살에 섞여 올라온 아기 해마입니다. 꼬리를 말았다 풀 때마다 물빛이 한 번 일렁입니다.', 0.52, sat=1.1)
skin('ug_tide_platypus', 'platypus', '물때 부리너구리',
     '물때가 바뀌는 때를 귀신같이 아는 부리너구리입니다. 썰물이 시작되면 부리로 모래를 톡톡 두드려 알려 줍니다.', 0.46, sat=0.9)
skin('ug_stone_pillbug', 'pill_bug', '땅울림 공벌레',
     '고임터 돌판 틈에서 땅울음을 자장가 삼아 자란 공벌레입니다. 몸을 말면 이끼 낀 쐐기돌처럼 보입니다.', 0.38, sat=0.45, light=1.05)
skin('ug_neol_imugi', 'bead_imugi', '너울 구슬 이무기',
     '흩어진 너울 방울을 구슬처럼 품고 다니는 꼬마 이무기입니다. 구슬을 굴리면 안에서 파도 소리가 납니다.', 0.58, sat=1.15)
