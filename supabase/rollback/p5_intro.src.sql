-- 롤백 뒤 주 이야기 1장 첫 장면(mq_red_seal 1 「빈 칸 난 장부」)에 장야를 가볍게 짚는 대사를 넣는다.
-- 조사원이 해가 뜨지 않던 밤을 꿈처럼 떠올리고, 연서희는 모른다는 듯 넘긴다(손끝의 붉은 인주만 남김).
-- 롤백 SQL과 함께 점검 중에 돌린다. 이미 들어 있으면 다시 넣지 않는다.
update public.world_quest_steps s
   set lines = (
     select jsonb_agg(x order by ord) from (
       select e as x, (i * 10)::numeric as ord from jsonb_array_elements(s.lines) with ordinality t(e, i)
       union all
       select v, (pos * 10 - 5 + k * 0.1)::numeric
         from (select min(i) pos from jsonb_array_elements(s.lines) with ordinality t(e, i) where e ->> 't' like '인사는 짧게 할게요.%') p,
              jsonb_array_elements($j$[
                {"s": null, "t": "나는 오는 길에 이상한 꿈을 꿨다고 말했다. 해가 뜨지 않는 밤이었고, 등불이 하나씩 꺼지다가 마지막엔 정청 등불 하나만 남았다고."},
                {"s": null, "t": "연서희가 붓을 멈춘다. 잠깐, 아주 잠깐 당신을 바라본다."},
                {"s": "q:m_yeon", "t": "해가 뜨지 않는 밤이요? …글쎄요. 어젯밤은 별일 없이 조용했어요. 정청에 처음 오는 사람들은 다들 그런 꿈을 꾼다더라고요."},
                {"s": null, "t": "서가 뒤에서 누군가 중얼거린다. 「간밤에 정청 등불 하나가 새벽까지 꺼지지 않았다더군. 누가 밤새 장부를 붙들고 있었는지.」"},
                {"s": null, "t": "연서희의 손끝에 붉은 인주가 희미하게 묻어 있다. 그녀는 아무렇지 않게 소매로 그것을 덮는다."},
                {"s": "q:m_yeon", "t": "꿈 얘기는 나중에 해요. 이름이 장부에 남아 있으면, 아침은 다시 와요."}
              ]$j$::jsonb) with ordinality n(v, k)
     ) z)
 where s.quest_id = 'mq_red_seal' and s.step = 1
   and not exists (select 1 from jsonb_array_elements(s.lines) e where e ->> 't' like '해가 뜨지 않는 밤이요?%');
