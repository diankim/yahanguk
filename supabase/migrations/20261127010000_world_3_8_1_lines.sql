create or replace function pg_temp.yh_line(p_q text, p_step int, p_old text, p_new text) returns void language plpgsql as $f$
declare n int;
begin
  select count(*) into n from public.world_quest_steps s, jsonb_array_elements(s.lines) e where s.quest_id = p_q and s.step = p_step and e ->> 't' = p_old;
  if n <> 1 then raise exception 'line % %: % 번 — %', p_q, p_step, n, left(p_old, 40); end if;
  update public.world_quest_steps s set lines = (
    select jsonb_agg(case when e ->> 't' = p_old then jsonb_set(e, '{t}', to_jsonb(p_new)) else e end order by o)
    from jsonb_array_elements(s.lines) with ordinality x(e, o) where p_new is not null or e ->> 't' <> p_old)
  where s.quest_id = p_q and s.step = p_step;
end $f$;

select pg_temp.yh_line('mdq_13', 8, '장날이면 장터 한쪽에 부름꾼이 명부 사본을 펴고 앉았소. 쌀 두 섬이면 아무 줄에나 도장을 찍어 줬지. 한 해에 수백 줄을. 그 이름을 실제로 불러 준 부름꾼은 하나도 없었소.',
  '봉인고에서 말한 장날 부름꾼들 말이오. 쌀값에 도장을 팔아 한 해에 수백 줄을 채우고도, 그 이름을 실제로 불러 준 적은 한 번도 없었소.');
select pg_temp.yh_line('mdq_13', 8, '그날 나는 배웠소. 부름은 하나를 살리고 하나를 죽인다는 것을. 칸을 다시 들이면 다음 장날에 부름꾼이 다시 앉소. 당신은 쌀 두 섬이 없는 고을을 본 적이 있소? 문제는 칸이 아니라 돈이오. 돈을 없앨 수 없으니 칸을 없앤 거요.',
  '그날 나는 배웠소. 부름은 하나를 살리고 하나를 죽인다는 것을. 칸을 다시 들이면 다음 장날에 부름꾼이 다시 앉소. 문제는 칸이 아니라 돈이오. 돈을 없앨 수 없으니 칸을 없앤 거요.');
select pg_temp.yh_line('mdq_16', 4, '다음 장날에 부름꾼이 다시 앉소. 장터 한쪽에 명부 사본을 펴 놓고. 쌀 두 섬이면 아무 줄 칸에나 제 이름을 적고 엄지 도장을 꾹 찍어 주지.',
  '다음 장날에 부름꾼이 다시 앉소. 봉인고에서 말한 그대로요. 쌀값에 도장을 찍고, 그 이름은 아무도 부르지 않소.');
select pg_temp.yh_line('mdq_16', 4, '부름꾼 하나가 한 해에 수백 줄에 도장을 찍소. 그 이름들을 실제로 불러 주는 일은 없소. 도장만 찍히면 거둘 수 없으니까.', null);
select pg_temp.yh_line('mdq_16', 4, '돈 있는 집 줄은 칸이 다 차오. 쌀 두 섬이 없는 고을 줄만 칸이 비지. 당신은 쌀 두 섬이 없는 고을을 본 적이 있소?',
  '돈 있는 집 줄은 칸이 다 차오. 빈 칸은 쌀 없는 고을 줄에만 남지. 봉인고에서 내가 한 물음, 아직 기억하시오?');

update public.world_patch_notes set body = body || $pn$
- [싸움] 현장 토벌·파티 토벌·그림자 토벌·귀허류 싸움에 타격 효과를 더했습니다. 무기 갈래에 따라 붓 자국이 달라지고, 맞을 때·치명타·방어·회복이 저마다 다르게 보입니다. 기기의 「동작 줄이기」를 켜면 나오지 않습니다.
- [꾸미기] 테두리 「흰 밤 테」와 낙관 「明燈」이 화면에 아무것도 그려지지 않던 것을 고쳤습니다.
- [대사] 명등기 13장·16장에서 경현이 쌀 두 섬 이야기를 같은 말로 되풀이하던 대사를 다듬었습니다.$pn$ where note_id = '3.8.0';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127010000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
