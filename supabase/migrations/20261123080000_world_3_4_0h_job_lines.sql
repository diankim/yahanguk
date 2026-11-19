do $j$
declare r record; n int;
begin
  for r in select * from (values
    ('cq110_bat_2', 2, '/암영=조사원 단도로 다 베어 버려!', '/암영=조사원 단도로 다 베어 버려!/혈기=조사원 도끼로 다 찍어 버려!/여명=조사원 창으로 다 쓸어 버려!/진법=조사원 진을 쳐서 갈대를 막아 버려!'),
    ('ep_north_2', 2, '/조련=화살과 동무가', '/조련=화살과 동무가/혈기=도끼가/여명=창끝이/진법=산가지 진이'),
    ('mdq_3', 2, '/조련=화살과 동무가', '/조련=화살과 동무가/혈기=도끼가/여명=창끝이/진법=산가지 진이'),
    ('mdq_4', 5, '/조련=활대를', '/조련=활대를/혈기=도끼 자루를/여명=창대를/진법=산가지 통을'),
    ('mdq_13', 3, '/퇴마=부적을 날려 그것을 태웠다', '/퇴마=부적을 날려 그것을 태웠다/혈기=도끼로 그것을 찍어 넘겼다/여명=창으로 그것의 가슴을 꿰뚫었다/진법=산가지를 흩뿌려 그것을 진 안에 가두었다'),
    ('mdq_16', 5, '/암영=단도를 거꾸로 쥐었다', '/암영=단도를 거꾸로 쥐었다/혈기=도끼 자루를 고쳐 쥐었다/여명=창을 곧추세웠다/진법=산가지를 손가락 사이에 끼웠다'),
    ('mdq_5', 6, '/조련=휘파람을 불어 동무를 앞세우고 청파를 노리던 것에 화살을 박았다', '/조련=휘파람을 불어 동무를 앞세우고 청파를 노리던 것에 화살을 박았다/혈기=도끼를 휘둘러 청파에게 덤비던 것을 찍어 넘겼다/여명=창을 내질러 청파를 노리던 것의 가슴을 꿰뚫었다/진법=산가지를 흩뿌려 청파 둘레에 진을 치고 덤비던 것을 막아 냈다'),
    ('mdq_6', 7, '/조련=동무를 불 앞에 세우고 처마 밑으로 기어드는 것들에 화살을 날렸다', '/조련=동무를 불 앞에 세우고 처마 밑으로 기어드는 것들에 화살을 날렸다/혈기=불 앞을 막아서며 기어드는 것들을 도끼로 찍어 넘겼다/여명=창을 길게 내질러 처마 밑으로 기어드는 것들을 하나씩 꿰었다/진법=산가지로 처마 둘레에 진을 쳐 그것들이 넘어오지 못하게 했다'),
    ('mkq_1', 2, '/의무=침이나 약으로 다스려지는', '/의무=침이나 약으로 다스려지는/조련=화살이나 동무 이빨에 쓰러지는/혈기=도끼에 찍히는/여명=창끝에 꿰뚫리는/진법=진에 갇히는/*=무기로 쓰러지는'),
    ('rg_galmae_3', 1, '/조련=활을', '/조련=활을/혈기=도끼를/여명=창을/진법=산가지를'),
    ('rg_galmae_5', 2, '/조련=활을', '/조련=활을/혈기=도끼를/여명=창을/진법=산가지를'),
    ('sq110_cangue_ghost', 3, '/암영=나는 숨을 죽이고 그림자 쪽으로 한 걸음 미끄러져 들어갔다.', '/암영=나는 숨을 죽이고 그림자 쪽으로 한 걸음 미끄러져 들어갔다./조련=나는 동무를 옥귀 곁에 앉히고 화살을 메겼다./혈기=나는 옥귀 앞을 막아서며 도끼를 고쳐 잡았다./여명=나는 창끝을 낮추고 옥귀 앞으로 한 걸음 나섰다./진법=나는 산가지를 바닥에 흩어 옥귀 둘레에 진을 쳤다./*=나는 옥귀 앞을 막아서며 무기를 고쳐 잡았다.'),
    ('sq110_f_redmoon', 3, '/암영=단도가 경문의 이음매를 끊자', '/암영=단도가 경문의 이음매를 끊자/조련=동무가 경문 한 줄을 물어뜯어 흩자/혈기=도끼가 경문을 내리찍어 흩어 버리자/여명=창끝이 경문 한 줄을 꿰어 끊자/진법=산가지 진에 경문이 걸려 멈추자/*=경문이 한 줄씩 흩어지자'),
    ('sq110_returning_wave', 2, '/암영=발소리 죽여 걷는 것까지 그대로인걸.', '/암영=발소리 죽여 걷는 것까지 그대로인걸./조련=동무 부르는 휘파람까지 그대로인걸./혈기=도끼를 메고 다니는 것까지 그대로인걸./여명=창을 끌고 다니는 버릇까지 그대로인걸./진법=산가지 세는 손 버릇까지 그대로인걸.'),
    ('sq110_s_yunpal', 2, '/암영=그림자 속으로 몸을 숨겨도 거울 속에는 내 모습이 그대로 남아 있었다', '/암영=그림자 속으로 몸을 숨겨도 거울 속에는 내 모습이 그대로 남아 있었다/조련=동무를 부르자 거울 속 동무가 반대쪽을 돌아보았다/혈기=도끼를 들자 거울 속에도 똑같은 도끼가 들렸다/여명=창을 겨누자 거울 속에서도 창끝이 나를 겨누었다/진법=산가지를 펼치자 거울 속 산가지가 거꾸로 놓였다/*=무기를 들자 거울 속에서도 똑같은 손이 움직였다'),
    ('sq110_weeping_mirror', 2, '/암영=그림자로 숨어도 거울 속엔 그대 그림자가 남을 것이오', '/암영=그림자로 숨어도 거울 속엔 그대 그림자가 남을 것이오/조련=동무를 앞세우면 거울 속 동무가 먼저 덤벼들 것이오/혈기=도끼를 휘두르면 그 도끼가 그대로 되돌아올 것이오/여명=창을 내지르면 거울 속 창이 먼저 닿을 것이오/진법=진을 치면 거울이 그 진을 뒤집어 칠 것이오/*=무엇을 하든 거울이 그대로 따라 할 것이오'),
    ('sq111_threshold_guard', 3, '/암영=자네 칼이면 저것의 틈을 찾겠지.', '/암영=자네 칼이면 저것의 틈을 찾겠지./조련=자네 동무 코면 저것이 오는 길을 먼저 맡겠지./혈기=자네처럼 피로 버티는 이가 서 있으면 저것도 함부로 못 넘을 걸세./여명=자네 창이면 저것이 문턱에 닿기 전에 꿰어 버리겠지./진법=자네 진이면 저것이 문턱 자리를 찾지 못하겠지.')
  ) v(qid, st, old, new) loop
    if exists (select 1 from public.world_quest_steps where quest_id = r.qid and step = r.st and position(r.new in lines::text) > 0) then continue; end if;
    update public.world_quest_steps set lines = replace(lines::text, r.old, r.new)::jsonb
     where quest_id = r.qid and step = r.st and position(r.old in lines::text) > 0;
    get diagnostics n = row_count;
    if n <> 1 then raise exception '직업 대사 자리를 못 찾음: % %', r.qid, r.st; end if;
  end loop;
end $j$;

do $r$
declare v record; i int;
begin
  for v in select * from (values
    ('bloodknight', '혈기사군요. 제 피로 버틴다고 들었어요. 앞에 서 주면 서고 사람들이 숨을 돌릴 거예요.'),
    ('spearman', '여명 창객이군요. 새벽마다 먼저 나선다면서요. 길을 터 줄 사람이 필요했어요.'),
    ('formation', '진법가군요. 산가지로 자리를 셈한다고요. 서고 안이 미로 같으니 그 셈이 쓸모 있을 거예요.')
  ) x(job, t) loop
    if exists (select 1 from public.world_quest_steps s, jsonb_array_elements(s.lines) e where s.quest_id = 'mq_red_seal' and s.step = 1 and e ->> 'job' = v.job) then continue; end if;
    select o - 1 into i from public.world_quest_steps s, jsonb_array_elements(s.lines) with ordinality x(e, o)
     where s.quest_id = 'mq_red_seal' and s.step = 1 and e ->> 'job' = 'tamer';
    if i is null then raise exception '연서희 직업 대사 자리를 못 찾음'; end if;
    update public.world_quest_steps set lines = jsonb_insert(lines, array[i::text], jsonb_build_object('s', 'q:m_yeon', 't', v.t, 'job', v.job), true)
     where quest_id = 'mq_red_seal' and step = 1;
  end loop;
end $r$;

create or replace function pg_temp.yh_setjson(p_fn regprocedure, p_j jsonb) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); body text := (select prosrc from pg_proc where oid = p_fn);
begin
  if position(body in src) = 0 then raise exception 'yh_setjson %: 본문을 못 찾음', p_fn; end if;
  execute replace(src, body, ' select ' || quote_literal(p_j::text) || '::jsonb ');
end $f$;

do $o$
begin
  if (public.world_outfit_rules() -> 'src')::text like '%극의 장부 교환%' then
    perform pg_temp.yh_setjson('public.world_outfit_rules()'::regprocedure, jsonb_set(public.world_outfit_rules(), '{src}',
      (select jsonb_object_agg(k, replace(replace(replace(v, '극의 장부 교환 · 극 귀허', '무용담 교환 · 무용담 · 귀허의 주인'), '극의 장부 교환 · 극 명부', '무용담 교환 · 무용담 · 먹그림자'), '극의 장부 교환 · 극 장부', '무용담 교환 · 무용담 · 값귀'))
         from jsonb_each_text(public.world_outfit_rules() -> 'src') e(k, v))));
  end if;
end $o$;

create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  if position(p_new in d) > 0 then return; end if;
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  execute replace(d, p_old, p_new);
end $$;

select pg_temp.yh_patch(f, $q$w.job_key = 'medic' and w.act ->> 't' is not null$q$, $q$(rb -> 'fade') ? w.job_key and w.act ->> 't' is not null$q$)
  from unnest(array['public.world_by_mech(uuid,integer,boolean,boolean,uuid[])', 'public.world_ug_by_mech(uuid,integer,boolean,boolean,uuid[])']) f;
select pg_temp.yh_patch(f, $q$-(rb -> 'fade' ->> 'medic')::int$q$, $q$-(rb -> 'fade' ->> w.job_key)::int$q$)
  from unnest(array['public.world_by_mech(uuid,integer,boolean,boolean,uuid[])', 'public.world_ug_by_mech(uuid,integer,boolean,boolean,uuid[])']) f;
do $b$
begin
  if not (public.world_boss_rules() -> 'baekya' -> 'board' -> 'fade') ? 'formation' then
    perform pg_temp.yh_setjson('public.world_boss_rules()'::regprocedure, jsonb_set(public.world_boss_rules(), '{baekya,board,fade,formation}', to_jsonb((public.world_boss_rules() -> 'baekya' -> 'board' -> 'fade' ->> 'medic')::int)));
  end if;
end $b$;

do $c$
begin
  if (public.world_contrib_rules() ->> 'heal')::numeric <> 0.05 then
    perform pg_temp.yh_setjson('public.world_contrib_rules()'::regprocedure, public.world_contrib_rules() || '{"heal": 0.05, "guard_mul": {"formation": 1.6}}'::jsonb);
  end if;
end $c$;

do $c$
begin
  if (public.world_contrib_rules() ->> 'heal')::numeric <> 0.05 or not public.world_contrib_rules() ? 'job_mul' then
    perform pg_temp.yh_setjson('public.world_contrib_rules()'::regprocedure, public.world_contrib_rules() || '{"heal": 0.05, "guard_mul": {"formation": 1.6},
      "job_mul": {"medic": 0.98, "scout": 0.88, "tamer": 0.76, "analyst": 1.25, "exorcist": 1.15, "spearman": 1.08, "artificer": 0.98, "formation": 0.86, "sealmaster": 1.35, "bloodknight": 1.0}}'::jsonb);
  end if;
end $c$;

select pg_temp.yh_patch('public.world_contrib_shares(jsonb)', $q$    select x ->> 'id' id,$q$,
  $q$    select x ->> 'id' id, coalesce(x ->> 'job', (select c.job_key from public.world_characters c where c.owner_id::text = x ->> 'id')) job,$q$);
select pg_temp.yh_patch('public.world_contrib_shares(jsonb)', $q$  select coalesce(jsonb_object_agg(s.id, case when z.tot > 0 then round(s.v / z.tot * 100, 1) else 0 end), '{}'::jsonb) into res
    from s, (select sum(v) tot from s) z;$q$,
  $q$  select coalesce(jsonb_object_agg(s.id, case when z.tot > 0 then round(s.v / z.tot * 100, 1) else 0 end), '{}'::jsonb) into res
    from (select s.id, s.v * coalesce((r -> 'job_mul' ->> e.job)::numeric, 1) v from s join e using (id)) s,
         (select sum(s.v * coalesce((r -> 'job_mul' ->> e.job)::numeric, 1)) tot from s join e using (id)) z;$q$);

update public.world_patch_notes set body = body || $N$- 새 세 직업(혈기사·여명 창객·진법가)으로 읽을 때 퀘스트 대사의 직업마다 다른 줄이 다른 직업 줄이나 빈 줄로 나오던 것을 맞췄습니다.
- 백야 판에서 진법가의 협동 기술도 의무관처럼 동료의 「바램」을 덜어 줍니다.
- 함께 싸운 기여도에서 치유 몫의 무게를 줄이고 진법가가 막아 준 피해 배수를 낮춰, 직업마다 기여도가 고르게 나오도록 맞췄습니다.
- 함께 싸운 기여도를 다시 맞췄습니다. 치유 몫의 무게를 줄이고, 직업마다 역할이 달라 생기는 차이를 고르게 해 같은 몫을 해낸 사람이 직업과 상관없이 비슷한 기여도를 받습니다.
- 도움말을 지금 규칙에 맞게 고쳤습니다(새 세 직업·8단계 장비·낚시터와 명어·묵적 봉쇄령과 등도 옛터가 열리는 때 등).
$N$
 where note_id = '3.0.0' and position('새 세 직업(혈기사·여명 창객·진법가)으로 읽을 때' in body) = 0;

update public.world_app_meta set value = '20261123080000' where key = 'db_version';
