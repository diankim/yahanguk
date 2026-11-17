import importlib.util as _iu
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
_sp = _iu.spec_from_file_location('pj_data', os.path.join(HERE, 'data.py'))
D = _iu.module_from_spec(_sp)
_sp.loader.exec_module(D)

ACTIVE = {'night_office': 11, 'red_moon_cult': 5.6, 'north_league': 4.6, 'mandate_court': 4.4, 'river_alliance': 3.4, 'black_lotus': 1.3, 'southern_remnant': 1.1}
NAMES = {'night_office': '정통파', 'red_moon_cult': '적월교', 'north_league': '북령맹', 'mandate_court': '천명원', 'river_alliance': '수향연맹', 'black_lotus': '흑련회', 'southern_remnant': '남명회'}
SERVER = 36
SHOW = float(sys.argv[1]) if len(sys.argv) > 1 else 0.6
CAP = D.PAY['day_cap']
HELP = {'night_office': {'black_lotus': 1.0, 'southern_remnant': 1.0}}


def daily(share, help_on):
    out = {f: n * SHOW * CAP * share for f, n in ACTIVE.items()}
    if help_on:
        for src, to in HELP.items():
            for dst, people in to.items():
                out[src] -= people * CAP * share
                out[dst] += people * CAP * share
    return out


def days(per_day, base):
    each = [b / per_day for b in base]
    return each, sum(each)


def faction_table(share, help_on):
    d = daily(share, help_on)
    rows = []
    for f in ACTIVE:
        each, tot = days(d[f], D.F_BASE)
        rows.append(f'| {NAMES[f]} | {ACTIVE[f]} | {d[f]:,.0f} | ' + ' | '.join(f'{x:.1f}' for x in each) + f' | {tot:.1f} |')
    return rows


def common_table(shares):
    rows = []
    for s in shares:
        per = SERVER * SHOW * CAP * s
        each, tot = days(per, D.C_BASE)
        rows.append(f'| 서버 {SERVER}명 × {SHOW:g} × {CAP:,} × {s:g} | {per:,.0f} | ' + ' | '.join(f'{x:.1f}' for x in each) + f' | {tot:.1f} |')
    return rows


if __name__ == '__main__':
    head = '| 세력 | 하루 접속 | 하루 몫 | ' + ' | '.join(f'{i + 1}단계 {b:,}' for i, b in enumerate(D.F_BASE)) + ' | 다섯 단계 합 |'
    line = '|---|---|---|' + '---|' * 6
    print(f'납품하는 사람 비율 {SHOW} · 한 사람 하루 {CAP:,}몫(모든 사업 합) · 날수는 단계마다')
    for share in (1.0, 0.5):
        for help_on in (False, True):
            hp = '정통파 참여자 중 2명이 흑련회·남명회를 1명씩 도움' if help_on else '돕기 없음'
            print(f'\n세력 사업 — 몫의 {share:.0%}를 거점 사업에 · {hp}')
            print(head)
            print(line)
            print('\n'.join(faction_table(share, help_on)))
    print('\n공동 사업 — 서버 전체 몫 중 공동에 넣는 비율별(한 땅에 모일 때)')
    print('| 가정 | 하루 몫 | ' + ' | '.join(f'{i + 1}단계 {b:,}' for i, b in enumerate(D.C_BASE)) + ' | 다섯 단계 합 |')
    print('|---|---|' + '---|' * 6)
    print('\n'.join(common_table((0.5, 0.25))))
