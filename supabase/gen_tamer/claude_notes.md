# CLAUDE.md에 옮길 규칙 (조련사 2.1.0)

CLAUDE.md는 이 작업에서 고치지 않았다. 아래를 해당 절에 옮긴다.

## §6 직업
- 직업(내부 키 / 이름)에 조련사 tamer 짝 사냥(원거리 무기, 기본 능력치 민첩7·감각8·체질5 — world_job_base). 직업 효과 world_job_effect는 0이고, 그 몫을 데리고 다니는 동무가 맡는다.
- 무기 직업 태그: 원거리 = 월궁 사수·조련사(world_weapon_jobs_of, 원거리 무기 equipment_traits.jobs에 tamer).
- 시작 장비: 대나무 단궁 · 화살 100 · 무명 철릭 · 미투리 · 동무 주먹밥 5 + 생성 화면에서 고른 첫 동무(world_create_character_v2 넷째 인자 p_pet, 목록 world_pet_partner_rules.first — 누렁 강아지·얼룩 고양이·참새·무당벌레, world_pet_start가 동무·데리고 다니는 자리를 채움). 화면 app.js #pet-pick.
- 기술 계열 taming 「조련」(world_job_line tamer → taming, 전투 계열 목록은 world_combat_lines() 한 곳 — world_skill_line_ok·world_skill_pending이 읽음, 화면 core.js COMBAT_LINES·JOB_LINE). 기본 기술 9(passive_effect damage_pct·crit_pct·pet_pct — pet_pct는 world_pet_partner_of만 더함), 추가 x13 눈짓·x30 군충몰이, 택일 24 a 물고 늘어지기 / b 몸 낮춰 · 43 a 사냥 본능 / b 끝까지 곁에, 숙달 m50 이름의 끈.
- 현장 기술 「휘파람」(world_job_skill_rules tamer: 원거리 ×1.2, 그 차례 동무 동작 반드시·동무 피해 ×2, 비무는 focus n1 ×1.3).
- 원정 기술 「동무의 코」(world_expedition_settle, 수치 world_pet_partner_rules.exp: 전투력 +10%×힘·발견 +20%×(0.5+0.5×힘)·채집 +5%·승률 +0.04×힘(물기 +0.03×힘 더)·지키기 받는 피해 −5%×힘·쪼기 비금/천상 위협 −10%×힘·홀리기 정신 손실 −10×힘).
- 협동 기술 넷 tm_fetch 물어 와(pet_strike, 공격 한 번으로 셈)·tm_guard 곁 지키기(ward)·tm_herd 몰이(expose+stagger)·tm_pack 한 몸 사냥(might + pet_x2). 조련사 협동 기술의 pct는 ×(coop_base 0.6 + coop_k 0.4×동무 힘)(world_raid_action·world_gw_resolve).
- 혼자 도전 보정 world_solo_aid tamer(시뮬 결과 표는 supabase/gen_tamer/sim_report.md).

## §3·§5 요괴 갈래
- world_monster_kinds.job_key(text)를 job_keys(text[])로 바꿨다. 판정은 `p_job = any(k.job_keys)`(world_kind_mult·world_exp_fight_story)와 world_kind_job_ok(갈래, 직업), 이름 잇기는 world_kind_jobs_label. 은형 = 월궁 사수·조련사, 군충 = 조련사. 화면은 battle view eff.jobs·도감 counter.jobs(옛 job 칸은 첫 값으로 함께 실음), gamedata kindJobs·kindMul → lore.js goodKinds(직업 소개의 「유리한 요괴」를 손으로 적지 않음)·guide.js kindJobsHtml.

## §7 꼬마 동무
- 동무 전투 짝 수치는 world_pet_partner_rules() 한 곳(힘 = 0.3 + 0.7×친밀도/300, 무리 넷 guard·bite·peck·charm의 갈래·공격 방식·배율·효과 확률, 휘파람·승리 친밀도·돌보기 배수·협동 기술 세기·원정 수치·첫 동무) → gamedata petPartner → 도움말(guide.js petPartnerHtml)·생성 화면.
- 데리고 다니는 동무(world_pet_profile)만 싸운다. world_pet_partner_of(uid)가 조련사일 때만 {id·이름·무리·style·pow·pct·mul·p·procs}를 주고, world_combat_stats.pet·world_raid_stats.pet(+ hp_atk = 공격력×(1+mul÷(1+치명타/200)) — 귀허·결전·봉연 보스 체력과 봉연 합류 체력 증가가 이것을 씀)·world_field_battle_view.pet가 같은 값을 싣는다.
- 동무 공격은 공격하는 차례에만(사용자 결정 6). 현장 world_battle_action(공격 마디 끝 — 피해·효과 pierce/broken/weak, 지키기는 pfx.pet_ward로 다음 공격 피해 감소, 홀리기는 기운 모으기 끊기에 두 배), 보스는 world_cb_pet_strike(stats, fx, bfx, 나, 휘파람) 한 곳(world_raid_action·world_gw_resolve). 새 전투도 이것을 쓴다. 동무는 탄·영력을 안 쓰고 노려지지 않으며 치명타가 없다.
- 이긴 토벌마다 그 동무 친밀도 +1(하루 10, world_pets.win_day·win_n — 캐릭터 행을 고치지 않음).
- 돌보기 친밀도는 world_pet_care_gain(uid, 행동, 오늘 횟수, 먹이, 좋아하는 별미) 한 곳(조련사 ×1.5 올림·손님 2). world_pet_act(p_owner null, …)이 데리고 다니는 동무 돌보기(모든 직업, 사용자 결정 7 — 하루 횟수는 그 동무 행으로 함께 셈, 배탈 없음). 화면 housing.js openPets 「데리고 다니는 동무」 칸 「돌보기」 → openCarry.
- 꼬마 족제비 little_ferret는 진품(빛나는 알), 조련사 둘째 퀘스트 jq2_tamer 보상(world_pet_sources quest:jq2_tamer).

## §10 퀘스트
- 조련사 직업 퀘스트 jq_tamer(Lv3 본부 객사)·jq2_tamer(Lv18 옛 의금부 옥사)·jq3_tamer(Lv32 잿빛 갈대숲, 받기 반요촌) 원본은 supabase/gen_tamer/script.md, 생성기 gen_tamer/quests.py(gen_side110/gen.py의 겹침 검사·보상 공식을 그대로 가져다 씀, 할 일은 대본의 `…` 칸을 그대로 읽음). 새 인물 q:dh_gomsil 조련사 곰실·q:sx_duseok 옥사의 영 두석·q:sx_galdae 반요 갈대지기. 설정은 gen_side110/canon.md 「동무가 따르는 까닭」.

## §15 내 모습
- 조련사 기본 옷 top:tamer 털깃 사냥 저고리·bottom:tamer 각반 바지와 미투리(tools/avatar_art/tops_art.py·data.py JOB_DEFAULT → parts.json·avatar.js, 물품 of_top_tamer·of_bottom_tamer, world_outfit_rules pool).

## 생성기
- supabase/gen_tamer/gen.py가 a_*.sql~l_*.sql·m_quests.sql(quests.py)·parts.json의 world_avatar_parts를 이어 migrations/20261116020000_world_2_1_0_tamer.sql을 만든다. 함수 고치기는 pg_temp.yh_fix(함수, [옛 조각, 새 조각, …]) — 조각마다 정확히 한 번 나와야 한다. 새 도우미 실행 권한은 pg_temp.yh_share(모든 fn_owner·service_role), 주인 바꾸기는 pg_temp.yh_own(public 만들기 권한을 그 동안만).
