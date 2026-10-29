-- 6.1.1: 직업·소속 퀘스트 12개 · 직업/소속별 대사 · 소속 보급 편지 · 물품 내력 · 지역 첫 방문 글 · 요괴 목격담 · 숨김 칭호 유래 · 탈것 내리기
-- 6.1.0 화면 배포와 함께 돌린다. 끝에서 숨겨 둔 6.1.0 패치노트를 되살리고 서버 보스 예약을 다시 켠다.

-- 고치는 함수의 주인 역할을 postgres가 쓸 수 있게(6.0.0과 같은 방식)
do $$ declare o text; begin
  for o in select distinct pg_get_userbyid(proowner) from pg_proc where oid in ('public.world_quest_board()'::regprocedure, 'public.world_quest_journal()'::regprocedure,
             'public.world_quest_report(text)'::regprocedure, 'public.world_quest_scene(text,integer)'::regprocedure, 'public.world_claim_faction_supply()'::regprocedure) loop
    if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  end loop;
end $$;

-- ① 직업·소속 전용 퀘스트: world_quests에 조건 열(캐릭터 표가 아니라 퀘스트 표)
alter table public.world_quests add column if not exists job_key text, add column if not exists faction_key text;

do $$ declare d text; a text; b text; f text;
begin
  -- 퀘스트 칸·일지 목록은 조건이 맞는 퀘스트만 센다
  foreach f in array array['public.world_quest_board()', 'public.world_quest_journal()'] loop
    d := pg_get_functiondef(f::regprocedure);
    a := 'where x.active order by';
    b := 'where x.active and (x.job_key is null or x.job_key = c.job_key) and (x.faction_key is null or x.faction_key = c.faction_key) order by';
    if position('x.job_key is null' in d) = 0 then
      if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '고칠 자리 없음: %', f; end if;
      execute replace(d, a, b);
    end if;
  end loop;
  -- 보고도 조건을 확인한다
  d := pg_get_functiondef('public.world_quest_report(text)'::regprocedure);
  a := 'if public.world_quest_done(uid, p_quest) then raise exception ''이미 마친 퀘스트입니다.''; end if;';
  b := a || ' if (q.job_key is not null and q.job_key <> c.job_key) or (q.faction_key is not null and q.faction_key <> c.faction_key) then raise exception ''다른 직업·소속의 퀘스트입니다.''; end if;';
  if position('다른 직업·소속의 퀘스트' in d) = 0 then
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '고칠 자리 없음: 보고 조건'; end if;
    execute replace(d, a, b);
  end if;
end $$;

-- ② 대사 줄에 job·affil이 있으면 그 직업·소속에게만 보인다
create or replace function public.world_quest_lines_for(p_lines jsonb, p_job text, p_affil text)
returns jsonb language sql immutable set search_path to 'pg_catalog' as $$
  select coalesce(jsonb_agg(x order by o), '[]'::jsonb) from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) with ordinality t(x, o)
   where (not x ? 'job' or x ->> 'job' = p_job) and (not x ? 'affil' or x ->> 'affil' = p_affil)
$$;
alter function public.world_quest_lines_for(jsonb, text, text) owner to fn_owner_field;
revoke all on function public.world_quest_lines_for(jsonb, text, text) from public, anon, authenticated;

do $$ declare d text; a text; b text;
begin
  d := pg_get_functiondef('public.world_quest_report(text)'::regprocedure);
  a := '''lines'', s.lines,'; b := '''lines'', public.world_quest_lines_for(s.lines, c.job_key, c.faction_key),';
  if position('world_quest_lines_for' in d) = 0 then
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '고칠 자리 없음: 보고 대사'; end if;
    execute replace(d, a, b);
  end if;
  d := pg_get_functiondef('public.world_quest_scene(text,integer)'::regprocedure);
  if position('world_quest_lines_for' in d) = 0 then
    a := '''lines'', s.lines,'; b := '''lines'', public.world_quest_lines_for(s.lines, c.job_key, c.faction_key),';
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '고칠 자리 없음: 장면 대사'; end if;
    d := replace(d, a, b);
    a := '''lines'', ln,'; b := '''lines'', public.world_quest_lines_for(ln, c.job_key, c.faction_key),';
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '고칠 자리 없음: 결말 대사'; end if;
    execute replace(d, a, b);
  end if;
end $$;

update public.world_quest_steps s set lines = (
    select jsonb_agg(v order by o) from (
      select v, o::numeric o from jsonb_array_elements(s.lines) with ordinality t(v, o)
      union all select v, 2 + o / 100.0 from jsonb_array_elements($J$[{"s": "q:m_yeon", "t": "호위대에서 왔군요. 칼 든 사람이 붙어 주면 서고 사람들이 덜 떨어요. 앞은 맡길게요.", "job": "artificer"}, {"s": "q:m_yeon", "t": "현장 조사원이군요. 발이 빠르다고 들었어요. 오늘은 그 눈이 제일 필요해요.", "job": "scout"}, {"s": "q:m_yeon", "t": "퇴마관이군요. 방울 소리를 들으니 든든하네요. 사당 쪽 일이 생기면 먼저 부를게요.", "job": "exorcist"}, {"s": "q:m_yeon", "t": "의무관이군요. 솔직히 반가워요. 지난달엔 돌아오지 못한 사람이 둘이었거든요.", "job": "medic"}, {"s": "q:m_yeon", "t": "봉인술사군요. 이번 일엔 봉인 장부가 얽혀 있어요. 당신 눈으로 봐 주면 좋겠어요.", "job": "sealmaster"}, {"s": "q:m_yeon", "t": "백공에서 왔군요. 물건을 읽는 눈이 있다고요. 금고 자물쇠부터 한번 봐 줘요.", "job": "analyst"}, {"s": "q:m_yeon", "t": "본부 직속이면 장부 보는 법은 알겠네요. 출납관이 반가워하겠어요.", "affil": "headquarters"}, {"s": "q:m_yeon", "t": "현장대응국에서 넘어왔다고요? 들녘 순찰조가 아쉬워하겠네요.", "affil": "fieldbureau"}, {"s": "q:m_yeon", "t": "기록감찰국이라… 빈 쪽을 처음 찾은 게 그쪽 사람이었죠. 잘 왔어요.", "affil": "archivebureau"}, {"s": "q:m_yeon", "t": "봉인관리국 사람이면 인장이 얼마나 무서운 물건인지 알 거예요.", "affil": "sealbureau"}, {"s": "q:m_yeon", "t": "의무지원국이면 객사 의원 쪽이죠? 다치면 제일 먼저 그리로 가요.", "affil": "medicalbureau"}, {"s": "q:m_yeon", "t": "외부 협력자라… 명부에 이름만 있으면 돼요. 여기선 누구나 같은 밤을 걸어요.", "affil": "independent"}]$J$::jsonb) with ordinality e(v, o)) z)
 where s.quest_id = 'mq_red_seal' and s.step = 1 and position('"job"' in s.lines::text) = 0;

insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ($T$jq_artificer$T$, 'side', $T$직업·호위 무사$T$, $T$마지막 파수의 칼$T$, $T$서문 수비대의 마지막 생존자가 호위 무사에게 앞에 서는 법을 다시 묻는다.$T$, $T$west_gate$T$, 3, '{}', null, 900, '[]'::jsonb, true, $T$artificer$T$, null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  sort = excluded.sort, active = true, job_key = excluded.job_key, faction_key = excluded.faction_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_artificer$T$, 1, $T$절뚝이는 노병$T$, $T$서문 폐성벽의 노병 탁대근을 만난다$T$, $J${"at": ["west_gate"]}$J$::jsonb, $J$[{"s": null, "t": "무너진 성벽 위, 한쪽 다리를 저는 노인이 녹슨 창을 짚고 서 있다."}, {"s": "q:dh_daegeun", "t": "호위대 칼이로군. 그 칼집 매듭, 우리 때 것과 똑같아."}, {"s": "q:dh_daegeun", "t": "서문이 무너진 밤, 부적쟁이 셋을 등 뒤에 두고 버텼지. 둘을 잃었네."}, {"s": "q:dh_daegeun", "t": "자네가 앞에 서는 사람이라면 저 창귀들부터 보여 주게. 맞으면서 버티는 법을."}, {"s": "me", "t": "보고 계십시오."}]$J$::jsonb, $J${}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_artificer$T$, 2, $T$앞에 서는 법$T$, $T$녹슨 창귀를 3마리 쓰러뜨린다$T$, $J${"at": ["west_gate"], "tasks": [{"t": "win", "m": ["x_west_gate_2"], "n": 3}]}$J$::jsonb, $J$[{"s": "q:dh_daegeun", "t": "물러서지 않았군. 그런데 너무 오래 맞았어."}, {"s": "q:dh_daegeun", "t": "호위는 버티는 게 아니라 버티게 하는 걸세. 뒤에 선 사람이 붓을 다 그을 때까지."}, {"s": "q:dh_daegeun", "t": "성문 파수망령이 아직 성벽을 도네. 그놈은 나 대신 끝을 봐 주게."}]$J$::jsonb, $J${"xp": 81}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_artificer$T$, 3, $T$파수 교대$T$, $T$성문 파수망령을 쓰러뜨리고, 수리 도구를 만들어 노병에게 건넨다$T$, $J${"at": ["west_gate"], "tasks": [{"t": "win", "m": ["m_west"], "n": 1}, {"t": "craft", "items": ["repair_kit"], "n": 1}], "give": {"repair_kit": 1}}$J$::jsonb, $J$[{"s": null, "t": "망령이 흩어진 자리에 녹슨 수비대 패찰 하나가 떨어진다."}, {"s": "q:dh_daegeun", "t": "그 녀석, 내 동기였네. 이제야 교대를 했군."}, {"s": "q:dh_daegeun", "t": "수리 도구는 내 창에 쓰지. 칼이든 창이든 손보는 놈이 오래 살아."}, {"s": "q:dh_daegeun", "t": "호위대에 가거든 탁대근이 칼을 넘겼다고 하게. 다들 알아들을 걸세."}]$J$::jsonb, $J${"xp": 81, "gil": 17, "items": {"tonic": 2}}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ($T$jq_scout$T$, 'side', $T$직업·현장 조사원$T$, $T$빈 과녁의 주인$T$, $T$활터를 맡은 위소라가 과녁을 갉는 쥐떼와 돌아오지 않은 순찰의 흔적을 쫓게 한다.$T$, $T$hq_training$T$, 3, '{}', null, 901, '[]'::jsonb, true, $T$scout$T$, null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  sort = excluded.sort, active = true, job_key = excluded.job_key, faction_key = excluded.faction_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_scout$T$, 1, $T$말 없는 궁수$T$, $T$연무장 활터의 궁수 위소라를 만난다$T$, $J${"at": ["hq_training"]}$J$::jsonb, $J$[{"s": null, "t": "활터 끝, 과녁마다 작은 이빨 자국이 나 있다."}, {"s": "q:dh_sora", "t": "조사원이죠. 활 잡는 법은 봤어요."}, {"s": "q:dh_sora", "t": "과녁을 쥐떼가 갉아요. 화살도 모자라고요."}, {"s": "q:dh_sora", "t": "화살 두 묶음 깎아 와요. 그리고 쥐떼를 쏘세요. 과녁 대신."}, {"s": "me", "t": "알겠습니다."}]$J$::jsonb, $J${}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_scout$T$, 2, $T$과녁 대신$T$, $T$화살을 2번 만들고 과녁 쥐떼를 3번 쓰러뜨린다$T$, $J${"at": ["hq_training"], "tasks": [{"t": "craft", "items": ["ammo_arrow"], "n": 2}, {"t": "win", "m": ["x_hq_training_1"], "n": 3}]}$J$::jsonb, $J$[{"s": "q:dh_sora", "t": "명중. 서두르지 않았네요."}, {"s": "q:dh_sora", "t": "쥐떼가 어디서 오는지 알아요? 들녘 버려진 초소에서요. 지난 순찰조가 거기서 돌아오지 않았어요."}, {"s": "q:dh_sora", "t": "흔적을 읽어 와요. 조사원은 발로 쓰는 사람이니까."}]$J$::jsonb, $J${"xp": 81}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_scout$T$, 3, $T$돌아오지 않은 순찰$T$, $T$잿빛 들녘을 3번 탐색해 순찰조의 흔적을 찾는다$T$, $J${"at": ["hq_training"], "tasks": [{"t": "search", "r": ["field_outskirts"], "n": 3}]}$J$::jsonb, $J$[{"s": null, "t": "들녘에서 찾은 것은 부러진 화살 세 대와 진흙에 찍힌 발자국이었다."}, {"s": "q:dh_sora", "t": "…세 대 다 쐈네요. 한 대도 안 남기고."}, {"s": "q:dh_sora", "t": "끝까지 쏘고 갔으면 됐어요. 그게 우리 일이에요."}, {"s": "q:dh_sora", "t": "이 화살들은 과녁 옆에 꽂아 둘게요. 당신 것은 여기 꽂히지 않게, 잘 피해요."}]$J$::jsonb, $J${"xp": 81, "gil": 17, "items": {"ammo_arrow": 60}}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ($T$jq_exorcist$T$, 'side', $T$직업·퇴마관$T$, $T$방울을 돌려주는 밤$T$, $T$폐쇄 사당의 어린 무녀 혼백이 잃어버린 방울 소리를 찾아 달라고 한다.$T$, $T$shrine_ruins$T$, 3, '{}', null, 902, '[]'::jsonb, true, $T$exorcist$T$, null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  sort = excluded.sort, active = true, job_key = excluded.job_key, faction_key = excluded.faction_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_exorcist$T$, 1, $T$방울 소리를 그리는 아이$T$, $T$폐쇄 사당의 혼백 가을을 만난다$T$, $J${"at": ["shrine_ruins"]}$J$::jsonb, $J$[{"s": null, "t": "꺼진 촛대 사이로 작은 혼백 하나가 퇴마관의 방울을 빤히 본다."}, {"s": "q:dh_gaeul", "t": "그거… 방울이죠? 한 번만 흔들어 줄래요?"}, {"s": null, "t": "방울이 울리자 혼백의 윤곽이 잠깐 또렷해진다."}, {"s": "q:dh_gaeul", "t": "제 방울은 무녀귀가 삼켰어요. 도깨비불들이 그 앞을 지켜요."}, {"s": "q:dh_gaeul", "t": "퇴마관님은 이름을 부를 수 있잖아요. 걔들 이름을 불러 줘요."}]$J$::jsonb, $J${}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_exorcist$T$, 2, $T$불의 이름$T$, $T$촛농 도깨비불을 3번 쓰러뜨린다$T$, $J${"at": ["shrine_ruins"], "tasks": [{"t": "win", "m": ["x_shrine_ruins_1"], "n": 3}]}$J$::jsonb, $J$[{"s": "q:dh_gaeul", "t": "불들이 흩어졌어요. 이제 무녀귀만 남았어요."}, {"s": "q:dh_gaeul", "t": "무녀귀도 원래는 저처럼 방울을 흔들던 언니였대요. 너무 오래 혼자였대요."}, {"s": "me", "t": "그 언니의 이름도 불러 주겠습니다."}]$J$::jsonb, $J${"xp": 81}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_exorcist$T$, 3, $T$다시 맨 방울$T$, $T$방울먹는 무녀귀를 쓰러뜨리고, 사당에서 부적실을 2번 거둬 방울을 다시 맨다$T$, $J${"at": ["shrine_ruins"], "tasks": [{"t": "win", "m": ["m_shrine_2"], "n": 1}, {"t": "gather", "items": ["talisman_thread"], "r": ["shrine_ruins"], "n": 2}], "give": {"talisman_thread": 2}}$J$::jsonb, $J$[{"s": null, "t": "무녀귀가 무너진 자리에서 녹슨 방울 하나가 굴러 나온다."}, {"s": "q:dh_gaeul", "t": "제 방울이에요! 끈이 다 삭았네…."}, {"s": "me", "t": "부적실로 다시 매어 드리겠습니다."}, {"s": null, "t": "새로 맨 방울이 울린다. 사당 안 촛대 몇 개에 불이 붙는다."}, {"s": "q:dh_gaeul", "t": "이제 저 혼자 흔들 수 있어요. 고마워요, 퇴마관님. 무서운 밤엔 이 소리를 떠올려요."}]$J$::jsonb, $J${"xp": 81, "gil": 17, "items": {"ward_talisman": 2, "spirit_tea": 2}}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ($T$jq_medic$T$, 'side', $T$직업·의무관$T$, $T$외상 장부의 약값$T$, $T$백등 야시장 약방 할멈이 돌아오지 못한 순찰대원들 몫의 약을 함께 지어 달라고 한다.$T$, $T$lantern_market$T$, 3, '{}', null, 903, '[]'::jsonb, true, $T$medic$T$, null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  sort = excluded.sort, active = true, job_key = excluded.job_key, faction_key = excluded.faction_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_medic$T$, 1, $T$줄 그은 이름들$T$, $T$백등 야시장의 약방 할멈 고분을 만난다$T$, $J${"at": ["lantern_market"]}$J$::jsonb, $J$[{"s": null, "t": "약방 문턱에 외상 장부가 펼쳐져 있다. 이름 옆마다 붓으로 그은 줄이 많다."}, {"s": "q:dh_gopun", "t": "의무관이지? 손 보면 알아. 약 냄새가 배었어."}, {"s": "q:dh_gopun", "t": "이건 외상 장부야. 줄 그은 건 못 받은 게 아니라 못 돌아온 사람들이지."}, {"s": "q:dh_gopun", "t": "남은 사람들 약은 내가 지어야 하는데, 이 늙은 손으론 모자라. 좀 거들어."}]$J$::jsonb, $J${}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_medic$T$, 2, $T$들녘 약초$T$, $T$잿빛 들녘에서 야령초를 4번, 약제 바탕을 2번 거둬 온다$T$, $J${"at": ["lantern_market"], "tasks": [{"t": "gather", "items": ["herb"], "r": ["field_outskirts"], "n": 4}, {"t": "gather", "items": ["medicine_base"], "r": ["field_outskirts"], "n": 2}], "give": {"herb": 4}}$J$::jsonb, $J$[{"s": "q:dh_gopun", "t": "잎이 고르네. 독초 하나 안 섞였어."}, {"s": "q:dh_gopun", "t": "청심환 둘만 지어 와. 의무관이면 처방은 알 거고."}]$J$::jsonb, $J${"xp": 81}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_medic$T$, 3, $T$바른 쓴맛$T$, $T$청심환을 2번 만들어 할멈에게 건넨다$T$, $J${"at": ["lantern_market"], "tasks": [{"t": "craft", "items": ["tonic"], "n": 2}], "give": {"tonic": 2}}$J$::jsonb, $J$[{"s": null, "t": "할멈이 청심환 하나를 깨물어 맛을 본다."}, {"s": "q:dh_gopun", "t": "쓴맛이 바르게 들었어. 됐다."}, {"s": "q:dh_gopun", "t": "장부에 줄 하나 덜 긋게 됐네. 이건 자네 몫이야. 외상 아니고."}]$J$::jsonb, $J${"xp": 81, "gil": 17, "items": {"tonic": 2, "herbal_extract": 1}}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ($T$jq_sealmaster$T$, 'side', $T$직업·봉인술사$T$, $T$봉인 부적 출납부$T$, $T$출납관 윤도한이 비어 버린 봉인 부적 출납을 봉인술사에게 맞춰 달라고 한다.$T$, $T$hq_yard$T$, 3, '{}', null, 904, '[]'::jsonb, true, $T$sealmaster$T$, null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  sort = excluded.sort, active = true, job_key = excluded.job_key, faction_key = excluded.faction_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_sealmaster$T$, 1, $T$빈 칸$T$, $T$정청의 출납관 윤도한을 만난다$T$, $J${"at": ["hq_yard"]}$J$::jsonb, $J$[{"s": "q:m_yun", "t": "봉인술사시군요. 마침 잘 오셨습니다."}, {"s": "q:m_yun", "t": "봉인 부적 열두 장이 장부에서 사라진 건 들으셨지요. 창고에도 남은 게 얼마 없습니다."}, {"s": "q:m_yun", "t": "폐쇄 사당에 황지가 아직 남아 있을 겁니다. 금줄식귀가 지키고 있지만요."}, {"s": "me", "t": "황지를 거두고 부적을 다시 접겠습니다."}]$J$::jsonb, $J${}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_sealmaster$T$, 2, $T$거꾸로 묶인 금줄$T$, $T$폐쇄 사당에서 황지를 3번 거두고 금줄식귀를 2번 쓰러뜨린다$T$, $J${"at": ["hq_yard"], "tasks": [{"t": "gather", "items": ["seal_paper"], "r": ["shrine_ruins"], "n": 3}, {"t": "win", "m": ["m_shrine_1"], "n": 2}]}$J$::jsonb, $J$[{"s": "q:m_yun", "t": "금줄식귀를 두 번이나요. 대단하십니다."}, {"s": "q:m_yun", "t": "그 금줄, 묶은 방향이 거꾸로였지요? …아닙니다. 장부만 보다 보니 별게 다 눈에 띕니다."}, {"s": "q:m_yun", "t": "정화 부적 두 장만 접어 주시면 출납을 맞출 수 있습니다."}]$J$::jsonb, $J${"xp": 81}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_sealmaster$T$, 3, $T$맞춘 칸$T$, $T$정화 부적을 2번 만들어 출납관에게 건넨다$T$, $J${"at": ["hq_yard"], "tasks": [{"t": "craft", "items": ["ward_talisman"], "n": 2}], "give": {"ward_talisman": 2}}$J$::jsonb, $J$[{"s": null, "t": "윤도한이 부적을 받아 장부에 한 줄을 적는다. 글씨가 이상하리만치 반듯하다."}, {"s": "q:m_yun", "t": "이것으로 칸이 맞습니다. 고맙습니다."}, {"s": "q:m_yun", "t": "봉인은 묶는 쪽보다 푸는 쪽이 쉽습니다. 그러니 묶는 분들이 귀하지요."}]$J$::jsonb, $J${"xp": 81, "gil": 17, "items": {"seal_paper": 3, "ward_talisman": 1}}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ($T$jq_analyst$T$, 'side', $T$직업·백공 기술관$T$, $T$이름 붙은 등$T$, $T$야시장의 등을 모두 만든 마일수가 백공 기술관에게 새 등의 뼈대를 맡긴다.$T$, $T$lantern_market$T$, 3, '{}', null, 905, '[]'::jsonb, true, $T$analyst$T$, null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  sort = excluded.sort, active = true, job_key = excluded.job_key, faction_key = excluded.faction_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_analyst$T$, 1, $T$등롱 가게$T$, $T$백등 야시장의 등롱 장인 마일수를 만난다$T$, $J${"at": ["lantern_market"]}$J$::jsonb, $J$[{"s": null, "t": "등롱 가게 천장에 이름표를 단 등이 빼곡하다."}, {"s": "q:dh_ilsu", "t": "백공에서 왔다고? 손 좀 보여 줘 봐. …굳은살 자리가 좋군."}, {"s": "q:dh_ilsu", "t": "새로 들어온 조사원마다 등을 하나씩 다는 게 우리 시장 풍습이야. 네 등은 네가 만들어."}, {"s": "q:dh_ilsu", "t": "백지교 정제 황지랑 연무장 목재부터 가져와."}]$J$::jsonb, $J${}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_analyst$T$, 2, $T$황지와 목재$T$, $T$백지교에서 정제 황지를 3번, 연무장에서 목재를 3번 거둔다$T$, $J${"at": ["lantern_market"], "tasks": [{"t": "gather", "items": ["fine_paper"], "r": ["paper_bridge"], "n": 3}, {"t": "gather", "items": ["wood"], "r": ["hq_training"], "n": 3}], "give": {"fine_paper": 2, "wood": 2}}$J$::jsonb, $J$[{"s": "q:dh_ilsu", "t": "황지 결이 곱네. 목재도 마른 걸로 골랐고."}, {"s": "q:dh_ilsu", "t": "뼈대는 쇠로 잡는다. 월철 주괴 둘을 녹여 와. 그리고 수리 도구 하나. 등은 해마다 손봐야 하거든."}]$J$::jsonb, $J${"xp": 81}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$jq_analyst$T$, 3, $T$불 켜진 등$T$, $T$월철 주괴를 2번, 수리 도구를 1번 만들어 주괴를 건넨다$T$, $J${"at": ["lantern_market"], "tasks": [{"t": "craft", "items": ["iron_ingot"], "n": 2}, {"t": "craft", "items": ["repair_kit"], "n": 1}], "give": {"iron_ingot": 2}}$J$::jsonb, $J$[{"s": null, "t": "마일수가 뼈대에 황지를 바르고, 마지막으로 붓을 건넨다."}, {"s": "q:dh_ilsu", "t": "이름은 네가 써. 등에 이름을 쓰면, 그 사람이 돌아올 길을 등이 기억한대."}, {"s": null, "t": "등에 불이 들어온다. 수백 개의 등 사이에 하나가 더 늘었다."}, {"s": "q:dh_ilsu", "t": "앞으로 시장에 오면 네 등부터 찾아. 꺼져 있으면 내가 다시 켜 줄 테니."}]$J$::jsonb, $J${"xp": 81, "gil": 17, "items": {"repair_kit": 2}}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ($T$aq_headquarters$T$, 'side', $T$소속·본부 직속$T$, $T$서리의 하루$T$, $T$정청 서리 문수가 본부 직속 조사원에게 하루치 잔심부름을 몽땅 맡긴다.$T$, $T$hq_yard$T$, 4, '{}', null, 906, '[]'::jsonb, true, null, $T$headquarters$T$)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  sort = excluded.sort, active = true, job_key = excluded.job_key, faction_key = excluded.faction_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_headquarters$T$, 1, $T$뛰어다니는 서리$T$, $T$정청 서리 문수를 만난다$T$, $J${"at": ["hq_yard"]}$J$::jsonb, $J$[{"s": null, "t": "정청 마당을 서리 하나가 서류 뭉치를 안고 뛰어다닌다."}, {"s": "q:dh_munsu", "t": "본부 직속이세요? 살았다! 저 혼자 오늘 일을 다 못 해요."}, {"s": "q:dh_munsu", "t": "구름나루에 보급 장부를 전해 주세요. 오는 길에 건량도 좀요. 숙직 들어가는 분들 몫이에요."}]$J$::jsonb, $J${}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_headquarters$T$, 2, $T$나루의 장부$T$, $T$구름나루에 가서 주모 달래에게 보급 장부를 전한다$T$, $J${"at": ["river_ferry"], "tasks": [{"t": "travel", "r": ["river_ferry"], "n": 1}]}$J$::jsonb, $J$[{"s": null, "t": "나루 주모가 장부를 받아 들고 한 장씩 넘겨 본다."}, {"s": "q:sn_dalrae", "t": "정청 장부네. 문수 그 애가 또 남한테 맡겼구먼."}, {"s": "q:sn_dalrae", "t": "건량 쌀 거면 나루 쌀 좀 가져가. 정청 쌀보다 낫다니까."}]$J$::jsonb, $J${"xp": 118}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_headquarters$T$, 3, $T$숙직 도시락$T$, $T$노정 건량을 3번 만들어 문수에게 건넨다$T$, $J${"at": ["hq_yard"], "tasks": [{"t": "craft", "items": ["travel_ration"], "n": 3}], "give": {"travel_ration": 3}}$J$::jsonb, $J$[{"s": "q:dh_munsu", "t": "건량이다! 그것도 셋이나!"}, {"s": "q:dh_munsu", "t": "본부 직속은 이런 일이 제일 많아요. 칼 쓸 일보다 장부 쓸 일이요. 그래도 이게 다 돌아가게 하는 거래요."}, {"s": "q:dh_munsu", "t": "다음에 또 부탁… 아니, 다음엔 제가 할게요. 아마도요."}]$J$::jsonb, $J${"xp": 118, "gil": 21, "items": {"travel_ration": 2, "tonic": 1}}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ($T$aq_fieldbureau$T$, 'side', $T$소속·현장대응국$T$, $T$귀죽림 순찰로$T$, $T$동생을 숲에서 잃은 나무꾼이 현장대응국에 끊긴 순찰로를 다시 내 달라고 한다.$T$, $T$ghost_bamboo$T$, 4, '{}', null, 907, '[]'::jsonb, true, null, $T$fieldbureau$T$)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  sort = excluded.sort, active = true, job_key = excluded.job_key, faction_key = excluded.faction_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_fieldbureau$T$, 1, $T$끊긴 길$T$, $T$귀죽림의 나무꾼 하청운을 만난다$T$, $J${"at": ["ghost_bamboo"]}$J$::jsonb, $J$[{"s": null, "t": "대숲이 바람도 없이 운다. 도끼를 멘 젊은이가 길 표식을 다시 묶고 있다."}, {"s": "q:dh_cheongun", "t": "현장대응국 분이시죠. 순찰로가 끊긴 지 석 달이에요."}, {"s": "q:dh_cheongun", "t": "동생이 그 길에서 사라졌어요. 길이라도 다시 나 있으면… 돌아올 수 있잖아요."}]$J$::jsonb, $J${}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_fieldbureau$T$, 2, $T$뽑힌 표식$T$, $T$귀죽림을 2번 탐색하고 대나무 원숭이를 3번 쓰러뜨린다$T$, $J${"at": ["ghost_bamboo"], "tasks": [{"t": "search", "r": ["ghost_bamboo"], "n": 2}, {"t": "win", "m": ["g_ghost_bamboo"], "n": 3}]}$J$::jsonb, $J$[{"s": "q:dh_cheongun", "t": "원숭이 놈들이 표식을 다 뽑아 갔었군요."}, {"s": "q:dh_cheongun", "t": "길을 다시 묶으려면 약제 바탕이랑 영맥 수피가 필요해요. 표식에 바르면 요괴가 안 건드려요."}]$J$::jsonb, $J${"xp": 118}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_fieldbureau$T$, 3, $T$다시 난 길$T$, $T$귀죽림에서 약제 바탕과 영맥 수피를 2번씩 거둬 수피를 건넨다$T$, $J${"at": ["ghost_bamboo"], "tasks": [{"t": "gather", "items": ["medicine_base"], "r": ["ghost_bamboo"], "n": 2}, {"t": "gather", "items": ["spirit_bark"], "r": ["ghost_bamboo"], "n": 2}], "give": {"spirit_bark": 2}}$J$::jsonb, $J$[{"s": null, "t": "새 표식이 대숲 깊은 곳까지 이어진다. 바람이 지나가자 대나무가 조금 덜 운다."}, {"s": "q:dh_cheongun", "t": "길이 났어요. 동생이 어디 있든, 이 길로 오면 돼요."}, {"s": "q:dh_cheongun", "t": "현장대응국이 낸 길은 오래간다던데, 정말이네요."}]$J$::jsonb, $J${"xp": 118, "gil": 21, "items": {"travel_ration": 2, "ward_talisman": 1}}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ($T$aq_archivebureau$T$, 'side', $T$소속·기록감찰국$T$, $T$젖은 쪽의 먹$T$, $T$장서각 기록관이 기록감찰국 조사원에게 빈 쪽 앞장에 번진 먹을 감식하게 한다.$T$, $T$hq_archive$T$, 4, '{}', null, 908, '[]'::jsonb, true, null, $T$archivebureau$T$)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  sort = excluded.sort, active = true, job_key = excluded.job_key, faction_key = excluded.faction_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_archivebureau$T$, 1, $T$번진 자국$T$, $T$장서각 지하서고의 기록관 모가람을 만난다$T$, $J${"at": ["hq_archive"]}$J$::jsonb, $J$[{"s": "night_office:mo", "t": "기록감찰국이군. 반갑네. 그 빈 쪽을 처음 본 게 자네 국 사람이었지."}, {"s": "night_office:mo", "t": "빈 쪽 바로 앞장에 먹이 번진 자국이 있네. 같은 먹인지 맞춰 봐야 해."}, {"s": "night_office:mo", "t": "서고 벼루에서 먹돌을 모아 오게. 책벌레들이 갉아먹기 전에."}]$J$::jsonb, $J${}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_archivebureau$T$, 2, $T$먹돌과 책벌레$T$, $T$장서각에서 먹돌을 2번 거두고 책벌레 요괴를 2번 쓰러뜨린다$T$, $J${"at": ["hq_archive"], "tasks": [{"t": "gather", "items": ["inkstone"], "r": ["hq_archive"], "n": 2}, {"t": "win", "m": ["g_hq_archive"], "n": 2}]}$J$::jsonb, $J$[{"s": "night_office:mo", "t": "먹돌이 좋군. 이걸 갈면 비교할 수 있어."}, {"s": "night_office:mo", "t": "그런데 탈명 죽간이 또 깨어났다네. 남의 이름을 먹는 놈이지. 기록 지키는 사람이 그걸 두고 볼 순 없지."}]$J$::jsonb, $J${"xp": 118}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_archivebureau$T$, 3, $T$정정$T$, $T$탈명 죽간을 쓰러뜨리고 서고를 2번 탐색한다$T$, $J${"at": ["hq_archive"], "tasks": [{"t": "win", "m": ["m_archive"], "n": 1}, {"t": "search", "r": ["hq_archive"], "n": 2}]}$J$::jsonb, $J$[{"s": null, "t": "죽간이 흩어지자 서고 바닥에 이름 몇 개가 다시 새겨진다."}, {"s": "night_office:mo", "t": "이름이 돌아왔군. 기록감찰국은 이런 걸 정정이라고 부르지."}, {"s": "night_office:mo", "t": "먹은… 같은 먹이었네. 정청 출납부에서 쓰는 먹이야. 이건 아직 아무에게도 말하지 말게."}]$J$::jsonb, $J${"xp": 118, "gil": 21, "items": {"fine_paper": 3, "spirit_tea": 1}}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ($T$aq_sealbureau$T$, 'side', $T$소속·봉인관리국$T$, $T$닫힌 줄 모르는 수문$T$, $T$수문이 닫힌 줄 모르는 노인 곁에서, 봉인관리국 조사원이 수문 밑 봉인을 다시 센다.$T$, $T$old_canal$T$, 4, '{}', null, 909, '[]'::jsonb, true, null, $T$sealbureau$T$)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  sort = excluded.sort, active = true, job_key = excluded.job_key, faction_key = excluded.faction_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_sealbureau$T$, 1, $T$돌지 않는 손잡이$T$, $T$구룡 폐수로의 수문지기 염수칠을 만난다$T$, $J${"at": ["old_canal"]}$J$::jsonb, $J$[{"s": null, "t": "녹슨 수문 옆, 노인이 오늘도 손잡이를 돌린다. 수문은 꿈쩍도 않는다."}, {"s": "q:dh_suchil", "t": "물 들어온다! 수문 열어야 해!"}, {"s": null, "t": "수문 아래 물빛이 이상하게 검다. 봉인 장부에 적힌 표식이 기둥에 반쯤 지워져 있다."}, {"s": "me", "t": "봉인관리국입니다. 수문 밑부터 살펴보겠습니다."}]$J$::jsonb, $J${}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_sealbureau$T$, 2, $T$밑에서 두드리는 것$T$, $T$구룡 폐수로를 2번 탐색하고 그림자 뱃사공을 2번 쓰러뜨린다$T$, $J${"at": ["old_canal"], "tasks": [{"t": "search", "r": ["old_canal"], "n": 2}, {"t": "win", "m": ["x_old_canal_2"], "n": 2}]}$J$::jsonb, $J$[{"s": "q:dh_suchil", "t": "그 뱃사공들, 밤마다 수문을 두드렸어."}, {"s": "q:dh_suchil", "t": "아냐, 두드린 건 밑에서야. 밑에서."}, {"s": null, "t": "기둥 아래, 수문아귀가 봉인 표식을 갉아먹은 자리가 보인다."}]$J$::jsonb, $J${"xp": 118}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_sealbureau$T$, 3, $T$다시 센 봉인$T$, $T$수문아귀를 쓰러뜨리고 정화 부적을 만들어 기둥에 붙인다$T$, $J${"at": ["old_canal"], "tasks": [{"t": "win", "m": ["m_04"], "n": 1}, {"t": "craft", "items": ["ward_talisman"], "n": 1}], "give": {"ward_talisman": 1}}$J$::jsonb, $J$[{"s": null, "t": "새 부적을 기둥에 붙이자 검은 물빛이 조금씩 맑아진다."}, {"s": "q:dh_suchil", "t": "…물이 안 들어오네. 수문이 닫혔나?"}, {"s": "me", "t": "네. 잘 닫혀 있습니다."}, {"s": "q:dh_suchil", "t": "그럼 됐어. 이제 좀 자도 되겠군."}]$J$::jsonb, $J${"xp": 118, "gil": 21, "items": {"ward_talisman": 2, "spirit_tea": 1}}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ($T$aq_medicalbureau$T$, 'side', $T$소속·의무지원국$T$, $T$담 밖의 약초밭$T$, $T$봉인된 연화원 담 밖에서 사는 약초꾼이 의무지원국에 옛 약초밭을 되살릴 손을 빌린다.$T$, $T$sealed_garden$T$, 4, '{}', null, 910, '[]'::jsonb, true, null, $T$medicalbureau$T$)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  sort = excluded.sort, active = true, job_key = excluded.job_key, faction_key = excluded.faction_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_medicalbureau$T$, 1, $T$담 너머$T$, $T$폐쇄된 연화원의 약초꾼 남선화를 만난다$T$, $J${"at": ["sealed_garden"]}$J$::jsonb, $J$[{"s": null, "t": "연화원 담장 아래, 여인이 담 너머를 보며 호미질을 한다."}, {"s": "q:dh_seonhwa", "t": "의무지원국에서 오셨어요? 객사 의원에 약초를 대던 게 저였어요. 연화원이 닫히기 전까지는요."}, {"s": "q:dh_seonhwa", "t": "담 밖에 밭을 새로 일구는 중인데, 덩굴 손들이 자꾸 넘어와요."}]$J$::jsonb, $J${}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_medicalbureau$T$, 2, $T$덩굴 걷기$T$, $T$덩굴 손을 3번 쓰러뜨리고 연화원을 2번 탐색한다$T$, $J${"at": ["sealed_garden"], "tasks": [{"t": "win", "m": ["g_sealed_garden"], "n": 3}, {"t": "search", "r": ["sealed_garden"], "n": 2}]}$J$::jsonb, $J$[{"s": "q:dh_seonhwa", "t": "덩굴이 물러났어요. 이제 씨를 심을 수 있겠어요."}, {"s": "q:dh_seonhwa", "t": "약제 바탕이랑 수피 좀 모아 주세요. 흙에 섞으면 연화원 흙 맛이 나요."}]$J$::jsonb, $J${"xp": 118}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_medicalbureau$T$, 3, $T$첫 싹$T$, $T$연화원에서 약제 바탕과 영맥 수피를 2번씩 거둬 약제 바탕을 건넨다$T$, $J${"at": ["sealed_garden"], "tasks": [{"t": "gather", "items": ["medicine_base"], "r": ["sealed_garden"], "n": 2}, {"t": "gather", "items": ["spirit_bark"], "r": ["sealed_garden"], "n": 2}], "give": {"medicine_base": 2}}$J$::jsonb, $J$[{"s": null, "t": "새로 일군 밭고랑에 첫 싹이 올라온다."}, {"s": "q:dh_seonhwa", "t": "봄이면 객사 의원에 다시 약초를 댈 수 있어요."}, {"s": "q:dh_seonhwa", "t": "다친 분들한테 전해 줘요. 연화원 약초가 돌아온다고."}]$J$::jsonb, $J${"xp": 118, "gil": 21, "items": {"tonic": 2, "spirit_tea": 2}}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ($T$aq_independent$T$, 'side', $T$소속·외부 협력자$T$, $T$명부 밖의 손님$T$, $T$구름나루 주모가 외부 협력자에게 셈은 맞는데 손이 찬 손님들의 물길을 따라가 보게 한다.$T$, $T$river_ferry$T$, 4, '{}', null, 911, '[]'::jsonb, true, null, $T$independent$T$)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  sort = excluded.sort, active = true, job_key = excluded.job_key, faction_key = excluded.faction_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_independent$T$, 1, $T$젖은 엽전$T$, $T$구름나루의 주모 달래를 만난다$T$, $J${"at": ["river_ferry"]}$J$::jsonb, $J$[{"s": null, "t": "주막 평상에 빈 술잔과 젖은 엽전이 놓여 있다."}, {"s": "q:sn_dalrae", "t": "외부 협력자구먼. 명부엔 있고 부서는 없는 사람. 나랑 비슷하네."}, {"s": "q:sn_dalrae", "t": "요즘 밤마다 젖은 엽전을 내고 가는 손님들이 있어. 셈은 맞는데 손이 차."}, {"s": "q:sn_dalrae", "t": "나루 물에서 뭐가 올라오는지 낚아 봐. 주모 눈엔 물고기 비린내가 제일 정직하거든."}]$J$::jsonb, $J${}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_independent$T$, 2, $T$녹물 든 비늘$T$, $T$구름나루에서 물고기를 3번 낚아 올린다$T$, $J${"at": ["river_ferry"], "tasks": [{"t": "fish", "r": ["river_ferry"], "n": 3}]}$J$::jsonb, $J$[{"s": "q:sn_dalrae", "t": "평범한 고기네. …아니, 이 비늘 봐. 녹물이 들었어."}, {"s": "q:sn_dalrae", "t": "구룡 폐수로 쪽 물이야. 거기 수문이 막혔다던데, 물은 새나 봐."}, {"s": "q:sn_dalrae", "t": "손님들 상에 낼 생선 좀 손질해 줘. 들어가는 길에 물어볼 게 있어."}]$J$::jsonb, $J${"xp": 118}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ($T$aq_independent$T$, 3, $T$장부를 옮기는 일$T$, $T$손질한 생선을 2번 만들어 주모에게 건넨다$T$, $J${"at": ["river_ferry"], "tasks": [{"t": "craft", "items": ["fish_fillet"], "n": 2}], "give": {"fish_fillet": 2}}$J$::jsonb, $J$[{"s": null, "t": "주모가 생선 접시를 들고 들어가더니, 한참 뒤 젖은 엽전 한 줌을 들고 나온다."}, {"s": "q:sn_dalrae", "t": "물어봤지. 다들 장부를 옮기는 일을 한대. 누구 장부냐고 물으니 웃더라."}, {"s": "q:sn_dalrae", "t": "외부 협력자는 이런 얘길 정청보다 먼저 듣는 사람이야. 잘 갖고 있어. 쓸 데가 올 거야."}]$J$::jsonb, $J${"xp": 118, "gil": 21, "items": {"travel_ration": 2}}$J$::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;

create table if not exists public.world_item_lore (item_id text primary key, lore text not null);
create table if not exists public.world_region_lore (region_id text primary key, lines jsonb not null);
create table if not exists public.world_region_visits (owner_id uuid not null, region_id text not null, visited_at timestamptz not null default now(), primary key (owner_id, region_id));
create table if not exists public.world_kind_witness (kind_key text not null, need int not null, speaker text, line text not null, primary key (kind_key, need));
create table if not exists public.world_title_lore (title_key text primary key, lines jsonb not null);
create table if not exists public.world_affil_letters (faction_key text not null, seq int not null, min_chapters int not null default 0, sender text not null, lines jsonb not null, primary key (faction_key, seq));
alter table public.world_item_lore enable row level security;
alter table public.world_region_lore enable row level security;
alter table public.world_region_visits enable row level security;
alter table public.world_kind_witness enable row level security;
alter table public.world_title_lore enable row level security;
alter table public.world_affil_letters enable row level security;
revoke all on public.world_item_lore, public.world_region_lore, public.world_region_visits, public.world_kind_witness, public.world_title_lore, public.world_affil_letters from anon, authenticated;
grant select on public.world_item_lore, public.world_region_lore, public.world_kind_witness, public.world_title_lore, public.world_affil_letters to fn_owner_field;
grant select, insert on public.world_region_visits to fn_owner_field;

insert into public.world_item_lore values ($T$iron_sword$T$, $T$연무장 대장간에서 호위대에 들면 처음 받는 칼. 칼집 매듭은 서문 수비대 때부터 같다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$a1_iron$T$, $T$쇠미늘을 엮은 갑옷. 호위대는 첫 미늘 하나에 제 이름을 새긴다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$h1_guard$T$, $T$무명 두건. 밤길에서 머리를 감싸 땀과 피가 눈에 들지 않게 한다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$m1_ward$T$, $T$붉은 주사로 그린 호신부. 정청 사당에서 새 조사원마다 하나씩 그려 준다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$w_ranged1_keen$T$, $T$연무장 활터의 궁수들이 쓰는 활. 시위를 당기면 매가 눈을 뜬다고 해서 붙은 이름.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$a1_light$T$, $T$무명으로 지은 철릭. 가볍고 소리가 나지 않아 조사원이 즐겨 입는다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$s1_swift$T$, $T$삼을 꼬아 만든 미투리. 들녘 순찰조는 한 달에 세 켤레를 닳린다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$spirit_bell$T$, $T$혼백의 귀를 여는 방울. 퇴마관은 처음 받은 방울을 평생 바꾸지 않는다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$a1_robe$T$, $T$삼베 도포. 사당 일과 약방 일을 하는 사람들이 같은 천을 입는다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$m1_spell$T$, $T$부적을 넣어 다니는 무명 주머니. 안쪽에 첫 스승의 이름을 적어 둔다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$w_magic1_silent$T$, $T$먹으로 그림을 그린 부채. 의무관은 이것으로 열을 식히고 독기를 흩는다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$m1_purify$T$, $T$쑥을 채운 향낭. 객사 의원에서 다친 사람 머리맡에 걸어 둔다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$w_magic1_heavy$T$, $T$무쇠로 부은 금강령. 봉인술사가 흔들면 요괴의 발이 무거워진다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$padded_coat$T$, $T$솜을 누빈 전포. 백공과 봉인술사가 겨울 현장에서 입는다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$h1_calm$T$, $T$선비들이 쓰던 유건. 봉인관리국에서는 마음을 다잡는 표시로 쓴다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$w_melee1_keen$T$, $T$날을 세운 단도. 백공은 이 칼로 싸우기보다 재료를 다듬는다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$n1_plenty$T$, $T$술을 단 노리개. 백공들은 거둔 것이 넉넉하라는 뜻으로 단다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$s1_road$T$, $T$짚신. 먼 길을 가는 사람은 한 켤레를 더 등에 멘다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$field_knife$T$, $T$현장 채집도. 야행국 조사원이라면 누구나 허리에 찬다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$ore_pick$T$, $T$월철 곡괭이. 서문 성벽을 허물던 곡괭이를 다시 벼린 것이라는 말이 있다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$fishing_rod$T$, $T$대나무 낚싯대. 귀죽림 대나무는 울어서 물고기가 잘 문다고 한다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$ammo_arrow$T$, $T$연무장에서 깎는 화살. 궁수 위소라는 깃 다는 솜씨만 보고 사람을 안다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$ward_talisman$T$, $T$정화 부적. 침식을 씻어 내는 가장 흔하고 가장 귀한 부적.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$seal_paper$T$, $T$부적을 쓰는 누런 황지. 백지교 아래 물로 떠야 결이 곱다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$tonic$T$, $T$청심환. 백등 야시장 약방 할멈의 처방이 정청 의원 처방보다 낫다는 말이 돈다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$herb$T$, $T$야령초. 밤에만 잎을 펴는 풀. 잿빛 들녘 둑길 아래에 많다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$travel_ration$T$, $T$노정 건량. 객사 찬모는 빈 꾸러미를 들고 돌아오는 것이 품삯이라고 한다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$spirit_tea$T$, $T$영초 차. 순찰 의원 연옥이가 한 주전자씩 달여 숙직자에게 돌린다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$repair_kit$T$, $T$장비 수리 도구. 서문 노병은 손보는 놈이 오래 산다고 말한다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$reset_identity$T$, $T$환골탈태 서첩. 정청 서기관이 배속 변경을 허락할 때 쓰는 서류철.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$reset_stats$T$, $T$세심단. 몸에 밴 버릇을 씻어 내는 환약. 맛은 아무도 좋다고 하지 않는다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$gwiryeong_cho$T$, $T$귀령초. 요기에 물든 자를 사람으로 되돌린다는 풀. 깊은 곳에서만 드물게 핀다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$bronze_charm$T$, $T$청동 호신패. 정청 무구를 손보던 장인들이 처음 만든 호신패.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$jade_bronze_charm$T$, $T$비취를 박은 청동패. 장인 몇 사람만 이음매를 맞출 줄 안다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$spirit_compass$T$, $T$영맥 나침반. 바늘이 북이 아니라 요기가 짙은 쪽을 가리킨다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$moon_blade$T$, $T$월식도. 달이 먹히는 밤에 벼려야 날이 선다는 칼.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$wayfarer_pack$T$, $T$행상인 짐틀. 수향 상단이 쓰던 것을 백공이 고쳐 만들었다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$sealing_ink$T$, $T$봉인 먹. 봉인술사는 이 먹으로 쓴 글자만 믿는다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$fine_paper$T$, $T$정제 황지. 장서각 기록은 모두 이 종이에 남는다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$medicine_base$T$, $T$약제 바탕. 어떤 약이든 여기서 시작한다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$talisman_thread$T$, $T$부적실. 끊어진 방울 끈을 다시 맬 때도 쓴다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$rune_plate$T$, $T$각인판. 결계 각인을 새기는 얇은 판. 봉인관리국 창고에 늘 모자란다.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_item_lore values ($T$steel_ingot$T$, $T$강철 주괴. 회산 관문 대장장이가 말보다 망치가 빠른 이유.$T$) on conflict (item_id) do update set lore = excluded.lore;
insert into public.world_region_lore values ($T$hq_yard$T$, $J$[{"s": null, "t": "야행국 본부 정청. 해가 지면 불이 켜지는 관청입니다. 낮에는 문이 닫혀 있고, 밤에는 등잔 기름 냄새와 장부 넘기는 소리가 마당까지 흘러나옵니다."}, {"s": null, "t": "정청 금고는 백 년 동안 한 번도 털린 적이 없었습니다. 지난 초하루까지는요."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$hq_dorm$T$, $J$[{"s": null, "t": "본부 객사. 숙직을 마친 조사원들이 신발을 벗어 두는 곳입니다. 객사지기 노철은 손님 얼굴은 잊어도 신발은 기억한다고 합니다."}, {"s": null, "t": "부엌에서는 찬모 복례가 삼십 년째 같은 국을 끓입니다. 돌아온 사람은 국을 먹고, 돌아오지 못한 사람의 그릇은 하룻밤 엎어 둡니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$lantern_market$T$, $J$[{"s": null, "t": "백등 야시장. 등 하나마다 이름이 붙어 있습니다. 등롱 장인 마일수가 새 조사원마다 하나씩 단다는 등입니다."}, {"s": null, "t": "해가 지면 장이 서고, 닭이 울면 등이 하나씩 꺼집니다. 꺼지지 않는 등의 주인은 아직 길 위에 있다고들 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$hq_training$T$, $J$[{"s": null, "t": "연무장과 팔괘진. 호위대와 조사원이 칼과 활을 익히는 곳입니다. 과녁마다 수백 개의 화살 자국이 겹쳐 있습니다."}, {"s": null, "t": "팔괘진 바닥의 돌은 밤마다 조금씩 자리를 바꿉니다. 처음 온 사람은 길을 잃고, 익숙한 사람은 그걸로 날씨를 맞힙니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$field_outskirts$T$, $J$[{"s": null, "t": "잿빛 들녘. 정청에서 가장 가까운 바깥입니다. 곡식은 잘 자라는데, 해마다 이삭 몇 단이 밤사이 사라집니다."}, {"s": null, "t": "들녘 끝에는 이름 없는 봉분들이 있습니다. 농부들은 첫 쌀을 거기 먼저 놓습니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$shrine_ruins$T$, $J$[{"s": null, "t": "폐쇄 사당. 봉인식을 치르던 곳입니다. 금줄은 아직 매여 있지만, 묶인 방향을 아는 사람은 이제 많지 않습니다."}, {"s": null, "t": "촛대는 꺼져 있는데 가끔 방울 소리가 들립니다. 어린 무녀 하나가 이곳을 떠나지 못한다는 이야기가 있습니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$hq_archive$T$, $J$[{"s": null, "t": "장서각 지하서고. 야행국의 모든 기록이 잠든 곳입니다. 계단을 내려갈수록 먹 냄새가 짙어집니다."}, {"s": null, "t": "서고의 죽간 가운데에는 남의 이름을 먹는 것이 있습니다. 그래서 기록관들은 책을 펼치기 전에 자기 이름을 한 번 부릅니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$sealed_garden$T$, $J$[{"s": null, "t": "폐쇄된 연화원. 한때 정청 의원에 약초를 대던 정원입니다. 지금은 봉인된 담장 너머로 덩굴만 넘어옵니다."}, {"s": null, "t": "담 밖에서 호미질하는 여인이 있습니다. 담 안의 흙 냄새를 아직 기억한다고 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$old_canal$T$, $J$[{"s": null, "t": "구룡 폐수로. 아홉 마리 용이 물을 나르던 수로였다고 합니다. 지금은 녹슨 수문 하나와 그 수문을 지키는 노인만 남았습니다."}, {"s": null, "t": "물은 고였는데 어디론가 샙니다. 붉은 녹이 섞인 물로 먹을 갈면 푸르스름하게 번진다고들 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$paper_bridge$T$, $J$[{"s": null, "t": "백지교. 종이처럼 하얀 돌다리입니다. 난간에 앉아 종이학을 접는 아이가 있습니다."}, {"s": null, "t": "다리 아래 물에는 접다 만 종이학들이 떠내려갑니다. 끝까지 접힌 학만 날아오른다는 말이 있습니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$west_gate$T$, $J$[{"s": null, "t": "서문 폐성벽. 무너진 밤 뒤로 아무도 다시 쌓지 않은 성벽입니다. 수비대의 마지막 생존자가 아직 매일 성벽에 오릅니다."}, {"s": null, "t": "녹슨 창귀들은 원래 수비대의 갑옷이었다고 합니다. 주인을 잃고도 성벽을 지키는 버릇은 남았습니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$river_ferry$T$, $J$[{"s": null, "t": "구름나루. 수향연맹의 배가 드나드는 나루이자 안전지대입니다. 주막 평상에서는 온갖 물길의 소문이 오갑니다."}, {"s": null, "t": "물안개가 짙은 날에는 건너편이 구름처럼 보여 이런 이름이 붙었습니다. 나루 사람들은 배삯보다 신용을 먼저 셉니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$ghost_bamboo$T$, $J$[{"s": null, "t": "귀죽림. 바람이 없어도 대나무가 우는 숲입니다. 순찰로가 끊긴 뒤로는 나무꾼만 드나듭니다."}, {"s": null, "t": "대숲은 베는 사람의 이름을 기억한다고 합니다. 그래서 이곳 나무꾼들은 도끼를 들기 전에 자기 이름을 밝힙니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$bone_market$T$, $J$[{"s": null, "t": "백골 장터. 적월 교령의 안전지대입니다. 뼈와 부적, 기억까지 값을 매겨 사고팝니다."}, {"s": null, "t": "뼈 감정사는 뼈 한 조각으로 주인의 나이를 맞힙니다. 틀린 적은 없다는데, 맞혔는지 확인한 사람도 없습니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$salt_village$T$, $J$[{"s": null, "t": "염등촌. 소금밭 위에 등을 켜고 일하는 마을입니다. 소금이 하얗게 빛나는 밤에는 등이 필요 없습니다."}, {"s": null, "t": "염전 한가운데에 소금각시가 산다는 소문이 있습니다. 소금을 너무 많이 긁는 사람의 발목을 잡는다고 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$ember_village$T$, $J$[{"s": null, "t": "잔불촌. 남명 망국의 유민들이 사는 마을이자 안전지대입니다. 공동 부엌의 불씨는 나라가 망한 날부터 한 번도 꺼진 적이 없습니다."}, {"s": null, "t": "마을 사람들은 불씨를 나눠 주는 것을 인사로 삼습니다. 받은 불을 꺼뜨리지 않는 것이 예의입니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$sunken_district$T$, $J$[{"s": null, "t": "침수된 구시가지. 물이 빠지기를 기다리는 동네입니다. 지붕 위로 다니는 소년이 물길을 손바닥처럼 압니다."}, {"s": null, "t": "옛 관아의 아전은 아직 장부를 말리고 있습니다. 물에 잠긴 기록도 기록이라고 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$red_plain$T$, $J$[{"s": null, "t": "적사 황무지. 붉은 모래가 끝없이 이어지는 적월 교령의 땅입니다. 모래가 조용하면 그 밑에 무언가 있다는 뜻입니다."}, {"s": null, "t": "길잡이들은 모래 소리로 날씨를 맞힙니다. 붉은 달이 뜨는 밤에는 아무도 길을 잡지 않습니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$ash_mountain$T$, $J$[{"s": null, "t": "회산 관문. 잿빛 산등성이를 지키는 북령맹의 관문입니다. 대장장이의 망치 소리가 산을 울립니다."}, {"s": null, "t": "관문 위의 깃발은 바람이 아니라 맹약의 무게로 펄럭인다고 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$lotus_marsh$T$, $J$[{"s": null, "t": "천엽 연화늪. 천 장의 연잎이 수면을 덮은 수향의 늪입니다. 연밥을 따는 사람들은 물속을 보지 않습니다."}, {"s": null, "t": "밤이면 연등이 물 위를 떠다닙니다. 요즘은 그 등이 하나둘 물속으로 가라앉는다고 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$glass_canyon$T$, $J$[{"s": null, "t": "유리협곡. 바람이 모래를 녹여 유리 절벽을 만든 곳입니다. 절벽마다 사람의 얼굴이 비칩니다."}, {"s": null, "t": "유리장이들은 협곡의 바람 소리를 들으며 유리를 굽습니다. 비친 얼굴이 먼저 웃으면 절대 따라 웃지 말라고 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$mirror_pavilion$T$, $J$[{"s": null, "t": "수경루. 물시계와 거울로 지은 누각입니다. 늙은 화공이 머물며 물에 비친 것을 그리지 않으려 애씁니다."}, {"s": null, "t": "요즘 물시계가 거꾸로 흐릅니다. 누각 사람들은 시간을 묻지 않습니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$hidden_bazaar$T$, $J$[{"s": null, "t": "십삼문 암시장. 흑련회의 안전지대입니다. 열세 개의 문 가운데 열두 개만 열려 있습니다."}, {"s": null, "t": "여기서는 이름과 기억도 값이 됩니다. 계약은 지키는 편이 싸다는 것이 이곳의 첫째 규칙입니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$iron_monastery$T$, $J$[{"s": null, "t": "철벽 고찰. 북령맹의 산문이자 안전지대입니다. 바위에 박힌 절이라 바람이 들지 않습니다."}, {"s": null, "t": "깃발지기는 바람의 방향으로 손님을 맞습니다. 북쪽에서 온 손님에게는 차를 두 잔 내줍니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$ash_coast$T$, $J$[{"s": null, "t": "재의 해안. 남명 망국의 마지막 날, 바다가 재로 굳었다는 해안입니다. 파도 대신 잿가루가 밀려옵니다."}, {"s": null, "t": "마지막 어부가 아직 그물을 손봅니다. 무엇을 잡느냐고 물으면 대답하지 않습니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$jade_pass$T$, $J$[{"s": null, "t": "옥문 협로. 절벽에 박은 쇠말뚝으로 이어진 잔도입니다. 말뚝지기가 예순 해째 말뚝을 셉니다."}, {"s": null, "t": "청등을 든 호송귀가 밤마다 잔도를 지나갑니다. 길을 비켜 주면 아무 일도 없다고 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$burial_steps$T$, $J$[{"s": null, "t": "만인장. 계단처럼 층을 이룬 거대한 묘역입니다. 비석이 밤마다 운다는 소문이 있습니다."}, {"s": null, "t": "상여꾼은 서른 해째 같은 상엿소리를 낮게 흥얼거립니다. 비석을 닦는 아이는 누구의 아이인지 아무도 모릅니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$black_sand_temple$T$, $J$[{"s": null, "t": "흑사단 폐단. 적월교가 버린 제단입니다. 검은 모래 위에 바쳐진 명부가 아직 남아 있습니다."}, {"s": null, "t": "순찰 교도들은 밤마다 귀를 막습니다. 버려진 제단에서 아직 기도 소리가 들리기 때문입니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$frost_valley$T$, $J$[{"s": null, "t": "빙혼곡. 북령맹이 지켜 온 얼음 인장이 잠든 골짜기입니다. 얼음 속에 무언가의 그림자가 비칩니다."}, {"s": null, "t": "인장 파수는 종소리를 들은 뒤로 말을 아낍니다. 그 종은 이 골짜기에 있던 것이 아니었습니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$red_forest$T$, $J$[{"s": null, "t": "혈엽림. 사철 붉은 단풍이 지는 남명의 숲입니다. 붉은 잎 뒤에 붉은 것이 숨어 있습니다."}, {"s": null, "t": "약초꾼들은 이 숲에서만 나는 약초를 찾아 깊이 들어갑니다. 자기 사정은 늘 남의 이야기처럼 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$crimson_mine$T$, $J$[{"s": null, "t": "주혈 광산. 붉은 주사를 캐던 광산입니다. 큰 붕괴 뒤로 갱도 깊은 곳에서 곡괭이 소리가 들립니다."}, {"s": null, "t": "살아남은 광부 반장은 그날 이야기를 꺼내지 않습니다. 갱도 원령들도 그날에서 멈춰 있습니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$sky_lake$T$, $J$[{"s": null, "t": "천경호. 하늘이 그대로 비치는 호수입니다. 하늘이 물에 비칠 때만 줄을 던지는 노인이 있습니다."}, {"s": null, "t": "맑은 날에는 물과 하늘의 경계가 사라집니다. 그런 날에는 배를 띄우지 말라고 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$sunken_palace$T$, $J$[{"s": null, "t": "용잠 수궁. 물 밑에 잠든 궁궐입니다. 천 년 동안 문을 지킨 늙은 거북이 말을 합니다."}, {"s": null, "t": "깊은 곳에서 누군가 이름을 부르는 노래가 들린다고 합니다. 자기 이름이 들리면 대답하지 말아야 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$nine_lighthouse$T$, $J$[{"s": null, "t": "구등대 군도. 아홉 등대가 선 섬들입니다. 마지막 등대지기가 홀로 불을 지킵니다."}, {"s": null, "t": "등대를 끄라는 명령이 내려진 적이 있다고 합니다. 그 명령이 어디서 왔는지는 아무도 말하지 않습니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$forgotten_city$T$, $J$[{"s": null, "t": "무명 고도. 이름을 잃은 옛 도읍입니다. 망국의 사관이 사라진 이름을 받아 적습니다."}, {"s": null, "t": "석상 수문병들은 아직 문을 지킵니다. 지킬 이름이 없어도 문은 문이라고 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$red_moon_fort$T$, $J$[{"s": null, "t": "적월교 월식성. 붉은 달을 섬기는 교단의 성채입니다. 달이 먹히는 밤이 이어지고 있습니다."}, {"s": null, "t": "성의 거울에는 문 하나가 비친다고 합니다. 그 문은 성 안에 없습니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$thunder_peak$T$, $J$[{"s": null, "t": "뇌명봉. 벼락이 그치지 않는 북령의 봉우리입니다. 벼락 맞은 자리를 쫓는 수집꾼이 있습니다."}, {"s": null, "t": "척후들은 바위처럼 말이 없습니다. 이 산에서는 말소리가 벼락을 부른다고 믿기 때문입니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$under_root$T$, $J$[{"s": null, "t": "지맥의 뿌리. 땅의 혈관이 드러난 흑련회의 지하 갱도입니다. 영핵이 흙 속에서 맥박처럼 빛납니다."}, {"s": null, "t": "수맥 지기는 물소리만 듣고 길을 찾습니다. 이곳에서 길을 잃은 사람은 물소리를 따라 나온다고 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$white_tower$T$, $J$[{"s": null, "t": "백옥 천문탑. 천명원이 별을 기록하는 탑입니다. 맨 아래층의 노인은 마흔 해 동안 자지 않고 별을 적었습니다."}, {"s": null, "t": "별이 꺼지는 순서가 적힌 두루마리가 있다고 합니다. 요괴는 그 순서대로 내려온다고 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$black_tide_rift$T$, $J$[{"s": null, "t": "흑조 균열. 검은 물결이 갈라진 틈으로 쏟아지는 곳입니다. 끝에서 늙은 낚시꾼이 줄을 드리웁니다."}, {"s": null, "t": "균열 바닥에는 큰 것이 삽니다. 낚싯줄을 끊는 건 늘 그것이라고 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$star_observatory$T$, $J$[{"s": null, "t": "무극 관성대. 천명원의 관측대이자 안전지대입니다. 하늘 전체가 한눈에 들어옵니다."}, {"s": null, "t": "관상감의 젊은 수직은 옛 태사령의 이야기를 외워 두었습니다. 별을 읽는 일은 결국 사람을 읽는 일이라고 합니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_region_lore values ($T$sealed_abyss$T$, $J$[{"s": null, "t": "구중 봉연. 아홉 겹으로 봉인된 마지막 문이 있는 곳입니다. 사슬 소리로 밤을 세는 파수꾼이 남아 있습니다."}, {"s": null, "t": "여기까지 온 사람은 많지 않습니다. 붉은 인장을 품고 먼저 내려간 자가 있다는 소문만이 먼저 와 있습니다."}]$J$::jsonb) on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_kind_witness values ($T$bird$T$, 1, $T$q:dh_sora$T$, $T$날짐승은 내리꽂기 직전에 날개를 접어요. 그때 쏘면 돼요.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$bird$T$, 10, $T$q:rn_dalgu$T$, $T$까마귀 떼는 셈을 해. 하나 잡으면 셋이 덤비지. 나보다 셈이 밝다니까.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$shell$T$, 1, $T$q:rn_cheolbu$T$, $T$껍질은 두드려 깨는 게 아냐. 이음매를 찾아.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$shell$T$, 10, $T$q:dh_daegeun$T$, $T$녹슨 창귀 껍데기도 원래는 우리 수비대 갑옷이었네.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$ghost$T$, 1, $T$q:dh_gaeul$T$, $T$혼백은 이름을 불러 주면 잠깐 멈춰요. 저도 그랬어요.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$ghost$T$, 10, $T$q:bl_hwagang$T$, $T$상엿소리를 낮게 하면 원령이 따라 흥얼거리지. 그때가 보낼 때야.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$venom$T$, 1, $T$q:dh_yunpal$T$, $T$독은 해독보다 피하는 게 싸다네. 내 말 믿어.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$venom$T$, 10, $T$q:sn_hwaok$T$, $T$단풍 독거미는 붉은 잎 뒤에 숨어요. 붉은 게 다 단풍은 아니에요.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$wood$T$, 1, $T$q:dh_gwak$T$, $T$도깨비도 품삯을 아는 놈들이오. 셈을 치르면 덜 덤비지.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$wood$T$, 10, $T$q:dh_cheongun$T$, $T$대숲은 베는 사람 이름을 기억해요. 그래서 함부로 못 베요.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$shadow$T$, 1, $T$q:rn_sapyeong$T$, $T$모래가 조용하면 그 밑에 뭐가 있는 거야.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$shadow$T$, 10, $T$q:dh_gaetong$T$, $T$그림자 뱃사공은 불빛을 싫어해요. 대야에 촛불 하나만 띄워도 안 와요.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$water$T$, 1, $T$q:dh_suchil$T$, $T$물은 밑에서 두드려. 밑에서.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$water$T$, 10, $T$q:m_gaon$T$, $T$물에 빠진 이름은 천 년이 지나도 젖어 있단다.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$swarm$T$, 1, $T$q:dh_bokrye$T$, $T$쥐떼는 부엌 냄새를 먼저 맡아. 건량은 단단히 싸.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$swarm$T$, 10, $T$q:bl_banseok$T$, $T$갱도 지네는 영핵 냄새를 따라와. 흙냄새로 덮으면 길을 잃지.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$ward$T$, 1, $T$q:m_yun$T$, $T$금줄은 묶는 방향이 있습니다. 거꾸로 묶으면… 아닙니다.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$ward$T$, 10, $T$q:rn_seolbaek$T$, $T$결계를 두른 놈은 종소리에 약하다. 그 종은 이제 없지만.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$mirror$T$, 1, $T$q:rn_haerang$T$, $T$거울 요괴는 자기를 비춰 보면 멈춰요. 동생이 그렇게 말했어요.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$mirror$T$, 10, $T$q:sn_eungyeol$T$, $T$물거울에 비친 건 그리지 마. 그림 속으로 들어와.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$breaker$T$, 1, $T$q:m_sawol$T$, $T$봉인을 깨는 것들은 교령의 냄새가 나요. 서약한 자의 냄새.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$breaker$T$, 10, $T$q:bl_jaeum$T$, $T$사슬 소리가 멎으면 뭔가 풀린 거다. 그때 세어라.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$sky$T$, 1, $T$q:rn_beongae$T$, $T$벼락은 같은 데 두 번 안 떨어진다고? 난 세 번 맞았어.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$sky$T$, 10, $T$q:bl_galhyeon$T$, $T$별이 꺼지는 순서를 적어 두게. 요괴는 그 순서로 내려오네.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$giant$T$, 1, $T$q:rn_gangpa$T$, $T$큰 놈은 발부터. 땅이 울리면 이미 늦다.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_kind_witness values ($T$giant$T$, 10, $T$q:bl_eodu$T$, $T$균열 바닥에 큰 게 산다. 낚싯줄을 끊는 건 늘 그놈이지.$T$) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;
insert into public.world_title_lore values ($T$night_owl$T$, $J$[{"s": "q:dh_cheol", "t": "삼경에 나가서 동트기 전에 들어오는 신발이 있지. 그 신발 주인이 자네였군."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$night_hunter$T$, $J$[{"s": "q:dh_daegeun", "t": "삼경의 요괴는 낮보다 사납네. 그 시간에 칼을 쓰는 사람은 수비대에도 몇 없었어."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$dawn_gatherer$T$, $J$[{"s": "q:dh_yeonok", "t": "새벽 이슬 맞은 약초가 제일 잘 들어요. 그 시간에 캐 오는 분이 있다고 들었어요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$noon_crafter$T$, $J$[{"s": "q:dh_ilsu", "t": "한낮에 만드는 놈은 그림자가 짧아서 손이 정직해. 그런 손은 오래 가."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$dusk_seeker$T$, $J$[{"s": "q:m_yeon", "t": "땅거미 질 때 단서가 제일 잘 보여요. 그림자가 길어지면 숨은 것도 드러나거든요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$wanderer_night$T$, $J$[{"s": "q:dh_ilsu", "t": "삼경에 길 떠나는 사람 등은 잘 안 꺼져. 네 등이 그래."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$blood_mist_blade$T$, $J$[{"s": null, "t": "혈무 속에서 칼을 쓴 사람의 이야기는 정청 장부에 붉은 먹으로 적힌다."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$fog_walker$T$, $J$[{"s": "q:sn_eungyeol", "t": "안개 너머를 걷는 사람은 안개를 그리지 않지. 그 너머를 그리지."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$rain_herbalist$T$, $J$[{"s": "q:dh_seonhwa", "t": "비 오는 날 캔 약초는 뿌리가 깊어요. 그날 젖은 손이 제일 귀해요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$snow_marcher$T$, $J$[{"s": "q:rn_gangpa", "t": "설한에 걷는 사람은 발자국을 남기지 않는다. 눈이 덮어 주니까."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$wind_archer$T$, $J$[{"s": "q:dh_sora", "t": "삭풍 속에서 맞혔다고요? 바람을 읽은 거예요. 활이 아니라."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$clear_sky$T$, $J$[{"s": "q:rn_yunga", "t": "하늘이 맑은 날 길을 나서는 사람은 운을 아는 사람이지."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$one_hit$T$, $J$[{"s": "q:dh_daegeun", "t": "한 번에 끝내는 칼은 그 앞에서 열 번을 참은 칼이네."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$long_fight$T$, $J$[{"s": "q:rn_cheolbu", "t": "열다섯 합을 버틴 쇠는 다시 두드릴 필요가 없지."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$coward$T$, $J$[{"s": "q:rn_sapyeong", "t": "도망치는 것도 길잡이 일이야. 살아서 길을 아는 놈이 다음 길을 잡거든."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$fallen$T$, $J$[{"s": "q:dh_yeonok", "t": "세 번 쓰러지고 세 번 일어났다고요? 다음엔 제 바구니를 먼저 찾아요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$fallen_10$T$, $J$[{"s": "q:dh_bokrye", "t": "열 번 엎었던 그릇을 열 번 다시 바로 놨지. 젊은이 그릇 말이야."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$revived$T$, $J$[{"s": "q:bl_jaeum", "t": "저승 문턱의 사슬 소리를 들었겠지. 그 소리를 아는 사람은 많지 않다."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$mourner$T$, $J$[{"s": "q:bl_hwagang", "t": "남의 넋을 기리는 사람의 상여는 내가 멜 거네. 아주 나중에."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$mourner_20$T$, $J$[{"s": "q:bl_yeonok", "t": "비석이 스무 개나 덜 울어요. 언니가 닦아 준 거죠?"}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$rich$T$, $J$[{"s": "q:sn_dalrae", "t": "전대가 무거우면 배가 가라앉아. 반은 나루에 맡기고 가."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$tycoon$T$, $J$[{"s": "q:m_yun", "t": "그 정도 금액이면 출납부에 따로 칸을 만들어야겠습니다."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$pauper$T$, $J$[{"s": "q:dh_gopun", "t": "빈털터리라고? 외상 장부에 이름 올려 줄게. 줄은 안 그을 거야."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$eroded$T$, $J$[{"s": "q:m_sawol", "t": "그 눈빛, 교령에서 많이 봤어요. 아직 돌아올 수 있어요. 늦기 전에요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$cleansed$T$, $J$[{"s": "q:dh_gaeul", "t": "부적 냄새가 나요. 아주 맑은 냄새요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$tonic_lover$T$, $J$[{"s": "q:dh_gopun", "t": "청심환을 그렇게 먹고도 속이 멀쩡해? 내 처방이 좋긴 좋지."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$hoarder$T$, $J$[{"s": "q:rn_dalgu", "t": "짐이 그렇게 많으면 호위가 필요하겠는데. 값은 셈해서 줘."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$title_collector$T$, $J$[{"s": "q:m_yeon", "t": "정청 명부에 당신 이름 옆 칸이 모자라기 시작했어요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$title_master$T$, $J$[{"s": "q:bl_yeohwi", "t": "이름이 이렇게 많은 사람은 고도에서도 드물었소. 하나도 잊히지 않게 적어 두겠소."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$strong$T$, $J$[{"s": "q:rn_cheolbu", "t": "그 팔이면 망치를 맡겨도 되겠어."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$swift$T$, $J$[{"s": "q:dh_gaetong", "t": "저보다 빨라요! 대야 없이도요!"}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$tough$T$, $J$[{"s": "q:dh_daegeun", "t": "철골이라… 수비대에 그런 놈이 하나만 더 있었어도."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$keen$T$, $J$[{"s": "q:bl_galhyeon", "t": "천리안이라. 나와 같이 별을 세 보겠나."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$iron_will$T$, $J$[{"s": "q:rn_seolbaek", "t": "종소리를 듣고도 버틸 사람이다."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$spirit_vessel$T$, $J$[{"s": "q:m_sawol", "t": "그릇이 크면 담기는 것도 많아요. 좋은 것만 담기를."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$hazard_survivor$T$, $J$[{"s": "q:rn_sapyeong", "t": "함정을 열다섯 번 밟고 살았다? 길잡이 해도 되겠어."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$omen_reader$T$, $J$[{"s": "q:bl_unhae", "t": "징조를 읽는 사람은 태사령의 이야기에도 나오오."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$quiet_night$T$, $J$[{"s": null, "t": "아무것도 찾지 못한 밤이 서른 번. 그 밤들도 장부에는 빠짐없이 적혀 있다."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$rest_lover$T$, $J$[{"s": "q:dh_bokrye", "t": "쉴 줄 아는 사람이 오래 가. 국 한 그릇 더 먹고 가."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$expedition_vet$T$, $J$[{"s": "q:dh_cheol", "t": "원정 다녀온 신발은 금방 알아보지. 자네 신발은 이제 눈 감고도 알겠네."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$supply_regular$T$, $J$[{"s": "q:dh_munsu", "t": "보급 장부에 이름이 제일 많은 분이에요! 덕분에 제 일이 줄었어요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$mission_runner$T$, $J$[{"s": "q:m_yeon", "t": "부서에서 당신 이름을 먼저 부르기 시작했어요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$repairman$T$, $J$[{"s": "q:rn_cheolbu", "t": "스무 번 고친 장비는 새것보다 낫지. 손이 기억하거든."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$armored_breaker$T$, $J$[{"s": "q:rn_cheolbu", "t": "껍질 깨는 법을 알았구먼. 이음매를 봤지?"}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$sky_hunter$T$, $J$[{"s": "q:dh_sora", "t": "하늘을 나는 것들을 스무 번. 날개 접는 순간을 아는 거예요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$ghost_exorcist$T$, $J$[{"s": "q:dh_gaeul", "t": "혼백들이 퇴마관님 이야기를 해요. 무섭지 않대요. 이름을 불러 줬대요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$elite_50$T$, $J$[{"s": "q:rn_takmu", "t": "…정예 쉰. 대호법께 보고할 일이군."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$guardian_25$T$, $J$[{"s": "q:rn_gangpa", "t": "큰 놈 스물다섯. 발부터 쳤겠지."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$night_guardian$T$, $J$[{"s": "q:dh_daegeun", "t": "삼경에 우두머리를 베다니. 그 밤엔 성벽도 조용했겠군."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$legend$T$, $J$[{"s": "q:m_yeon", "t": "처음 정청에 왔던 날 기억나요? 장부 빈 쪽 앞에서 머뭇거리던 사람이, 이제 야행의 전설이래요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$fish_codex_master$T$, $J$[{"s": "q:rn_yunga", "t": "물 밑의 이름을 모두 적었다고? 하늘이 물에 비칠 때 한 번 같이 줄을 던지세."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$dragon_koi$T$, $J$[{"s": "q:m_gaon", "t": "용잠의 비늘을 가졌구나. 천 년 만에 보는 손이로다."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$spar_upset$T$, $J$[{"s": "q:rn_cheolbu", "t": "아래가 위를 쳤다고? 쇠도 가끔 그래. 담금질이 잘되면."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$spar_lose30$T$, $J$[{"s": "q:dh_daegeun", "t": "서른 번 진 사람은 서른한 번째에 이기네. 내가 그랬어."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$yohwa_first$T$, $J$[{"s": "q:m_sawol", "t": "요기가 스며들었군요. 무서워하지 마요. 처음엔 다들 그래요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$yohwa_half$T$, $J$[{"s": "q:rn_eunsil", "t": "반쯤 요괴가 된 사람에게도 탕약은 들어. 교리보다 탕약을 믿게."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$yohwa_seal$T$, $J$[{"s": "q:bl_jaeum", "t": "봉인 속에서 하루를 잤다지. 사슬 소리가 자장가 같았을 거다."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$yohwa_master$T$, $J$[{"s": "q:m_sawol", "t": "요기를 세 번 이겨 낸 사람은 교령에도 없어요. 당신은 이제 그 기운을 부릴 수 있어요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$codex_100$T$, $J$[{"s": "q:bl_yeohwi", "t": "백 가지 요괴의 이름을 적은 책이라. 고도의 서고에 한 권 두고 싶소."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$raid_low$T$, $J$[{"s": "q:bl_jaeum", "t": "작은 불씨가 봉연의 그림자를 쳤다. 그 불이 꺼지지 않기를."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$raid_fallen$T$, $J$[{"s": "q:dh_yeonok", "t": "일곱 번 물러나서 일곱 번 돌아갔다고요? 제 바구니가 바빴겠네요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_title_lore values ($T$final_solo$T$, $J$[{"s": "q:m_yeon", "t": "혼자서 봉주를 물리쳤다고요. …돌아와 줘서 고마워요. 그게 제일 중요해요."}]$J$::jsonb) on conflict (title_key) do update set lines = excluded.lines;
insert into public.world_affil_letters values ($T$headquarters$T$, 1, 0, $T$본부 직속 출납실$T$, $J$[{"s": null, "t": "이번 보급은 정청 창고에서 바로 꺼낸 것입니다. 청심환은 유통기한이 지나기 전에 드십시오."}, {"s": null, "t": "장부 빈 쪽 일은 아직 조사 중입니다. 출납실 사람들도 잠을 줄였습니다. — 출납실"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$headquarters$T$, 2, 0, $T$본부 직속 출납실$T$, $J$[{"s": null, "t": "보급 수령 확인했습니다. 서명이 삐뚤어졌으니 다음엔 똑바로 써 주십시오."}, {"s": null, "t": "서리 문수가 또 남에게 심부름을 맡기거든 출납실로 알려 주십시오. — 출납실"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$headquarters$T$, 3, 3, $T$본부 직속 출납실$T$, $J$[{"s": null, "t": "적월교 서약 인장이 장부에서 나온 뒤로 창고 열쇠를 바꿨습니다."}, {"s": null, "t": "새 열쇠는 출납관과 서기관만 가집니다. 보급은 늘 같은 자리에 두겠습니다. — 출납실"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$headquarters$T$, 4, 7, $T$본부 직속 출납실$T$, $J$[{"s": null, "t": "등대 쪽 일로 본부가 시끄럽습니다. 명령서 한 장이 어디서 나왔는지 다들 묻습니다."}, {"s": null, "t": "보급만큼은 늘 같은 시간에 나갑니다. 그게 우리가 할 수 있는 일입니다. — 출납실"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$fieldbureau$T$, 1, 0, $T$현장대응국 순찰조$T$, $J$[{"s": null, "t": "들녘 둑길에 쥐떼가 늘었다. 약초 캘 때 발밑 조심."}, {"s": null, "t": "이번 보급의 부적은 순찰조가 쓰다 남긴 것이 아니다. 새것이다. 진짜로. — 순찰조"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$fieldbureau$T$, 2, 0, $T$현장대응국 순찰조$T$, $J$[{"s": null, "t": "귀죽림 순찰로를 다시 낸다는 이야기가 있다. 손이 비면 나무꾼 하청운을 찾아가라."}, {"s": null, "t": "길은 내는 사람이 아니라 다니는 사람이 지킨다. — 순찰조"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$fieldbureau$T$, 3, 3, $T$현장대응국 호송반$T$, $J$[{"s": null, "t": "변경 호송이 늘었다. 회산 관문 쪽은 북령맹이 길을 막지 않는다. 적사 황무지는 해가 지면 건너지 말 것."}, {"s": null, "t": "건량은 넉넉히. 모래 위에서는 아무도 밥을 나눠 주지 않는다. — 호송반"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$fieldbureau$T$, 4, 7, $T$현장대응국 호송반$T$, $J$[{"s": null, "t": "남명 해안까지 길이 이어졌다. 재의 해안에서는 발자국이 남지 않으니 표식을 꼭 남길 것."}, {"s": null, "t": "돌아오는 길도 길이다. — 호송반"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$archivebureau$T$, 1, 0, $T$기록감찰국 서고$T$, $J$[{"s": null, "t": "보급에 황지를 넉넉히 넣었네. 단서를 찾으면 그 자리에서 적게. 기억은 먹보다 먼저 번지네."}, {"s": null, "t": "— 서고에서, 모가람"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$archivebureau$T$, 2, 0, $T$기록감찰국 서고$T$, $J$[{"s": null, "t": "탈명 죽간이 또 기지개를 켠다는 소문이 있네. 서고에 내려오거든 자네 이름부터 부르게."}, {"s": null, "t": "— 서고에서, 모가람"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$archivebureau$T$, 3, 3, $T$기록감찰국 서고$T$, $J$[{"s": null, "t": "장부에 찍힌 붉은 달 인장은 진짜였네. 서약을 맺은 자들의 명부도 어딘가 있겠지."}, {"s": null, "t": "찾거든 베끼지 말고 그대로 가져오게. 베낀 기록은 기록이 아니야. — 모가람"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$archivebureau$T$, 4, 7, $T$기록감찰국 서고$T$, $J$[{"s": null, "t": "등대를 끄라는 명령서의 먹을 맞춰 보았네. 정청 먹이었어."}, {"s": null, "t": "이 편지는 읽고 나서 태우게. — 모가람"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$sealbureau$T$, 1, 0, $T$봉인관리국 당직실$T$, $J$[{"s": null, "t": "이번 보급의 정화 부적은 당직 봉인사가 직접 접었습니다. 침식이 서른을 넘거든 미루지 말고 쓰십시오."}, {"s": null, "t": "봉인 장부는 오늘도 맞지 않습니다. — 당직실"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$sealbureau$T$, 2, 0, $T$봉인관리국 당직실$T$, $J$[{"s": null, "t": "폐쇄 사당 금줄의 방향을 다시 확인했습니다. 몇 군데가 거꾸로 묶여 있었습니다."}, {"s": null, "t": "누가 그랬는지는 아직 모릅니다. 알게 되면 가장 먼저 알리겠습니다. — 당직실"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$sealbureau$T$, 3, 3, $T$봉인관리국 당직실$T$, $J$[{"s": null, "t": "북령의 얼음 인장에 금이 갔다는 전갈이 왔습니다. 빙혼곡으로 가는 분들은 정신을 단단히 붙드십시오."}, {"s": null, "t": "봉인은 한 곳이 풀리면 이웃이 따라 풀립니다. — 당직실"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$sealbureau$T$, 4, 7, $T$봉인관리국 당직실$T$, $J$[{"s": null, "t": "구중 봉연의 사슬 소리가 정청까지 들립니다. 봉연 파수꾼이 보낸 소리일지도 모릅니다."}, {"s": null, "t": "마지막 문 앞에서는 봉인 장부를 믿으십시오. 사람보다 오래 버팁니다. — 당직실"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$medicalbureau$T$, 1, 0, $T$의무지원국 객사 의원$T$, $J$[{"s": null, "t": "보급의 약초는 담 밖 새 약초밭에서 온 것이에요. 남선화 님이 고르셨어요."}, {"s": null, "t": "다치면 참지 말고 바로 오세요. 의원 침상은 늘 비워 둬요. — 객사 의원"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$medicalbureau$T$, 2, 0, $T$의무지원국 객사 의원$T$, $J$[{"s": null, "t": "구조대가 지난밤 셋을 데려왔어요. 다 살았어요."}, {"s": null, "t": "오늘 받은 청심환은 남에게 주지 말고 꼭 본인이 드세요. — 객사 의원"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$medicalbureau$T$, 3, 3, $T$의무지원국 객사 의원$T$, $J$[{"s": null, "t": "요화에 걸린 분이 처음으로 들어왔어요. 귀령초를 구할 수 있으면 의원에 알려 주세요."}, {"s": null, "t": "요기는 몸보다 마음에 먼저 듭니다. 혼자 다니지 마세요. — 객사 의원"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$medicalbureau$T$, 4, 7, $T$의무지원국 객사 의원$T$, $J$[{"s": null, "t": "깊은 곳으로 갈수록 돌아오는 길이 길어져요. 회생 부적을 한 장은 꼭 품으세요."}, {"s": null, "t": "당신 이름 옆에는 날짜만 적고 싶어요. 돌아온 날짜요. — 객사 의원"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$independent$T$, 1, 0, $T$구름나루 주막$T$, $J$[{"s": null, "t": "정청에서 보급이 왔더라. 외부 협력자 몫은 늘 조금 적어. 대신 내가 엽전 하나 얹었어."}, {"s": null, "t": "— 나루 주모 달래"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$independent$T$, 2, 0, $T$구름나루 주막$T$, $J$[{"s": null, "t": "요즘 젖은 엽전 내는 손님이 늘었어. 셈은 맞는데 손이 차. 눈여겨봐 둬."}, {"s": null, "t": "— 달래"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$independent$T$, 3, 3, $T$구름나루 주막$T$, $J$[{"s": null, "t": "수향 상단이 붉은 인장 찍힌 짐을 실었다는 소문이 돌아. 연맹은 모른다고 하지만."}, {"s": null, "t": "외부 협력자는 소문을 먼저 듣는 사람이야. — 달래"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;
insert into public.world_affil_letters values ($T$independent$T$, 4, 7, $T$구름나루 주막$T$, $J$[{"s": null, "t": "나루 배들이 등대 쪽으로 안 가려고 해. 불이 꺼진 바다는 배도 무서워하거든."}, {"s": null, "t": "어디에도 매이지 않은 사람이 제일 멀리 가. 몸조심해. — 달래"}]$J$::jsonb) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;

-- ⑤ 읽기 함수: 물품 내력·요괴 목격담(한 번에, 접속 동안 화면이 기억) · 지역 첫 방문 · 다녀간 지역 글 · 숨김 칭호 유래
create or replace function public.world_lore_bundle()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object(
    'items', (select coalesce(jsonb_object_agg(item_id, lore), '{}'::jsonb) from public.world_item_lore),
    'witness', (select coalesce(jsonb_object_agg(kind_key, arr), '{}'::jsonb) from (
       select w.kind_key, jsonb_agg(jsonb_build_object('need', w.need, 'name', coalesce(public.world_quest_cast(array[w.speaker], '') -> w.speaker ->> 'name', ''), 't', w.line) order by w.need) arr
         from public.world_kind_witness w group by w.kind_key) z));
end $function$;

create or replace function public.world_region_intro(p_region text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; l jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  select * into r from public.world_map_regions where region_id = p_region and region_name = c.location;
  if not found or c.travel_destination is not null then return null; end if;
  select lines into l from public.world_region_lore where region_id = p_region;
  if l is null then return null; end if;
  insert into public.world_region_visits(owner_id, region_id) values (uid, p_region) on conflict do nothing;
  if not found then return null; end if;
  return jsonb_build_object('region_id', p_region, 'title', r.region_name, 'lines', l);
end $function$;

create or replace function public.world_region_lore_seen()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('region_id', v.region_id, 'region_name', m.region_name, 'territory', m.territory_name, 'visited_at', v.visited_at, 'lines', l.lines) order by v.visited_at), '[]'::jsonb)
            from public.world_region_visits v join public.world_region_lore l on l.region_id = v.region_id join public.world_map_regions m on m.region_id = v.region_id
           where v.owner_id = uid);
end $function$;

create or replace function public.world_title_story(p_title text)
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); l jsonb; spk text[]; nm text; me text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if not exists (select 1 from public.world_character_titles where owner_id = uid and title_key = p_title) then raise exception '얻은 칭호만 유래를 볼 수 있습니다.'; end if;
  select lines into l from public.world_title_lore where title_key = p_title;
  if l is null then return null; end if;
  select title_name into nm from public.world_title_catalog where title_key = p_title;
  select character_name into me from public.world_characters where owner_id = uid;
  select array_agg(distinct x ->> 's') into spk from jsonb_array_elements(l) x where x ->> 's' is not null;
  return jsonb_build_object('title', '「' || nm || '」의 유래', 'lines', l, 'cast', public.world_quest_cast(spk, me));
end $function$;

-- 소속 보급 편지: 마친 장 수까지 열린 편지 가운데 날마다 하나
create or replace function public.world_affil_letter(p_uid uuid, p_faction text)
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $function$
  select jsonb_build_object('title', l.sender || '에서 온 편지', 'lines', l.lines)
    from public.world_affil_letters l
   where l.faction_key = p_faction
     and l.min_chapters <= (select count(*) from public.world_quests q where q.kind = 'main' and q.active and public.world_quest_done(p_uid, q.quest_id))
   order by md5(l.seq::text || p_uid::text || current_date::text) limit 1
$function$;

do $$ declare d text := pg_get_functiondef('public.world_claim_faction_supply()'::regprocedure);
  a text := 'return jsonb_build_object(''content'',''소속 보급을 수령했습니다: ''';
  b text := 'return jsonb_build_object(''letter'',public.world_affil_letter(uid,c.faction_key),''content'',''소속 보급을 수령했습니다: ''';
begin
  if position('world_affil_letter' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '고칠 자리 없음: 소속 보급 편지'; end if;
  execute replace(d, a, b);
end $$;

-- ⑥ 탈것 내리기: 탈것 없이 걸어 다닌다(속도 ×1, 운임 없음 — world_travel_route가 탈것이 없으면 그렇게 계산). 언제든 다시 탈 수 있다
create or replace function public.world_mount_unequip()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 등록하세요.'; end if;
  if c.is_dead or c.health <= 0 or c.downed_at is not null then raise exception '현재 상태에서는 탈것을 바꿀 수 없습니다.'; end if;
  if c.travel_destination is not null then raise exception '이동 중에는 탈것에서 내릴 수 없습니다. 도착한 뒤에 내리세요.'; end if;
  if c.mount_id is null then raise exception '이미 걸어 다니고 있습니다.'; end if;
  update public.world_characters set mount_id = null, updated_at = now() where owner_id = uid;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload) values (uid, c.character_name, 'mount', '탈것에서 내림', jsonb_build_object('mount_id', null, 'from', c.mount_id));
  return jsonb_build_object('content', '탈것에서 내렸습니다. 이제 걸어서 다닙니다(운임 없음).', 'mount_id', null);
end $function$;

-- 탈것 내리기(주인 fn_owner_field)가 캐릭터의 탈것 열만 고칠 수 있게(열 하나만, 화면 권한은 그대로)
grant update (mount_id) on public.world_characters to fn_owner_field;

do $$ declare f text; begin
  foreach f in array array['public.world_lore_bundle()', 'public.world_region_intro(text)', 'public.world_region_lore_seen()', 'public.world_title_story(text)', 'public.world_affil_letter(uuid,text)', 'public.world_mount_unequip()'] loop
    execute format('alter function %s owner to fn_owner_field', f);
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['public.world_lore_bundle()', 'public.world_region_intro(text)', 'public.world_region_lore_seen()', 'public.world_title_story(text)', 'public.world_mount_unequip()'] loop
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  -- 보급 함수 주인이 편지 함수를 부른다
  execute format('grant execute on function public.world_affil_letter(uuid,text) to %I', (select pg_get_userbyid(proowner) from pg_proc where oid = 'public.world_claim_faction_supply()'::regprocedure));
end $$;

-- ⑦ 6.1.0 숨김 풀기: 보관해 둔 6.1.0 패치노트를 되살리고, 서버 보스 예약을 다시 켠다(아무도 모이지 않은 예고 회차는 지우고 새로 잡는다)
do $$ begin
  if to_regclass('yh_deploy.hold_patch_note') is not null then
    execute 'insert into public.world_patch_notes select * from yh_deploy.hold_patch_note on conflict (note_id) do nothing';
  end if;
end $$;
delete from public.world_raids r where r.kind = 'world' and r.status = 'announced' and not exists (select 1 from public.world_raid_members m where m.raid_id = r.raid_id);
select public.world_raid_schedule_next() where not exists (select 1 from public.world_raids where kind = 'world' and status in ('announced', 'signup', 'fight'));
select cron.alter_job(jobid, active := true) from cron.job where jobname = 'yh-raid';

update public.world_patch_notes set body = body || E'\n### 6.1.1\n- **직업·소속 퀘스트 12개**: 직업마다 하나(호위 무사 「마지막 파수의 칼」·현장 조사원 「빈 과녁의 주인」·퇴마관 「방울을 돌려주는 밤」·의무관 「외상 장부의 약값」·봉인술사 「봉인 부적 출납부」·백공 기술관 「이름 붙은 등」), 소속마다 하나(본부 직속 「서리의 하루」·현장대응국 「귀죽림 순찰로」·기록감찰국 「젖은 쪽의 먹」·봉인관리국 「닫힌 줄 모르는 수문」·의무지원국 「담 밖의 약초밭」·외부 협력자 「명부 밖의 손님」). 이야기 속 인물들이 맡기고, 내 직업·소속에게만 보입니다(Lv3·4).\n- **1장 첫 장면**에서 연서희가 직업과 소속에 따라 다르게 맞아 줍니다(일지에서 다시 보기로도 보입니다).\n- **소속 보급 편지**: 하루 소속 보급을 받으면 부서에서 짧은 편지가 함께 옵니다. 이야기를 진행할수록 내용이 달라집니다.\n- **지역 첫 방문 글**: 지역에 처음 들어가면 그곳의 내력을 짧게 보여 주고, 일지 › 기록 › 지역에 남깁니다.\n- **물품 내력**: 시작 장비와 주요 물품 정보 창에 한 줄 내력이 붙습니다.\n- **요괴 목격담**: 요괴 도감에서 갈래를 고르면, 그 갈래를 1·10마리 쓰러뜨릴 때마다 이야기 속 인물의 한마디가 열립니다.\n- **숨김 칭호 유래**: 얻은 숨김 칭호 카드의 「유래」를 누르면 그 칭호를 두고 인물들이 하는 말을 보여 줍니다.\n- **환골탈태 장면**: 서첩을 쓰면 정청 서기관이 배속 변경을 처리하는 짧은 장면이 나옵니다.\n- **탈것에서 내리기**: 지도 › 탈것에서 탈것을 내려 걸어 다닐 수 있습니다(속도 ×1, 노정패 운임 없음). 언제든 다시 탈 수 있습니다.\n'
 where note_id = '6.1.0' and position('### 6.1.1' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261031010000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

