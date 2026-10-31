#!/usr/bin/env python3
"""롤백(1.0.0) SQL 한 파일 만들기 — python3 supabase/rollback/build.py → supabase/rollback/rollback_1_0_0.sql

순서(점검 중, 11/2 00:00 world_rollback_close가 문을 닫은 뒤):
  p1 레거시 명단(지금 캐릭터가 있는 계정)  → p2 캐릭터·지난 세계 비우기 → p3 세력 판도·장야·예약 작업
  → p4 레거시 세트·지급 트리거 → p5 1장 첫 장면 대사 → p6 꼬마 동무 1.0.0 → p7 패치노트 → p8 다시 열 준비·확인·db_version
*.src.sql은 supabase/pending·wt-pets에서 옮겨 온 원본이고, 여기서 「grant fn_owner_field to postgres …」 줄은 뺀다
(운영 postgres는 이미 fn_owner_field로 행동할 수 있고, 끝의 inherit false가 그 권한을 꺼 이후 패치를 막는다).
"""
import pathlib, re

D = pathlib.Path(__file__).parent
PARTS = ['p1_legacy_mark.src.sql', 'p2_wipe.sql', 'p3_world.sql', 'p4_legacy_grant.src.sql',
         'p5_intro.src.sql', 'p6_pets.src.sql', 'p7_notes.sql', 'p8_reopen.sql']
GRANT = re.compile(r'^grant fn_owner_field to postgres with .*;\s*$', re.M)

out = ['-- 서버 롤백 · 1.0.0 「두 번째 밤」 (build.py가 만든 파일, 고치려면 조각을 고치고 다시 만든다)\n',
       '-- 미리 돌려 보기: do $$ begin execute (…이 파일…); raise exception \'ROLLBACK_TEST ok\'; end $$; 또는 begin; + 파일 + rollback;\n',
       'set local check_function_bodies = off;\n',
       'lock table public.world_characters in access exclusive mode;\n\n']
for p in PARTS:
    s = (D / p).read_text(encoding='utf-8').replace('\r\n', '\n')
    s = GRANT.sub('', s)
    out.append(f'\n-- ════════ {p} ════════\n{s.rstrip()}\n')
out.append('\nset local check_function_bodies = on;\n')
(D / 'rollback_1_0_0.sql').write_text(''.join(out), encoding='utf-8')
print('rollback_1_0_0.sql', sum(len(x) for x in out), 'chars')
