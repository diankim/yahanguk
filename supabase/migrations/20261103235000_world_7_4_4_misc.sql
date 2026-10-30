-- 7.4.4 ① 조사 숙련 계열 이름 「추적」 → 「탐사」(사용자 요청, 탐색·답사·원정과 이어지게). 키 tracking과 기술 이름(잔향 추적·만리추적 등)은 그대로.
-- 7.4.4 ② 별채 가구·별미 제작법 50개의 분야가 한글(「목공」「봉인 공예」 등)로 들어가 있어 분야 거르기·같은 분야 품질 +12·기술 경험(봉인 공예→결계 각인)·
--          요리 숙련(말린 생선포)이 붙지 않던 것을 영문 키로 고친다(원본 gen72/gen.py·pets_data.py도 고침).

update public.world_crafting_recipes set craft_field = case craft_field
    when '단조' then 'smithing' when '목공' then 'carpentry' when '법구 공예' then 'artifice' when '봉인 공예' then 'sealing'
    when '직조' then 'weaving' when '가죽 공예' then 'leatherwork' when '연금' then 'alchemy' when '요리' then 'cooking' end
  where craft_field in ('단조', '목공', '법구 공예', '봉인 공예', '직조', '가죽 공예', '연금', '요리');

create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $f$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
  execute replace(d, p_old, p_new);
end $f$;
select pg_temp.yh_patch('public.world_gimmick_tip(text)', 'when ''tracking'' then ''추적''', 'when ''tracking'' then ''탐사''');
select pg_temp.yh_patch('public.world_exp_fight_story(uuid,text,text,jsonb,integer,boolean,integer,integer,jsonb,double precision,double precision,timestamp with time zone,integer,text,text,integer,jsonb)',
  '''[추적] 「''', '''[탐사] 「''');
update public.world_skill_catalog set description = replace(description, '원거리·추적', '원거리·탐사') where description like '%원거리·추적%';

update public.world_patch_notes set body = body || $N$
## 7.4.4
- **퀘스트 대사 다듬기**: 주 이야기·보조 퀘스트·외전·세력 퀘스트에서 앞뒤가 맞지 않거나 어색한 대사를 고쳤습니다. 다음에 할 일(어디서·무엇을·왜)은 앞 장면 끝에서 인물이 게임 속 이름 그대로 맡기고, 일을 마치고 돌아오면 방금 한 일로 이야기가 이어집니다. 할 일 조건과 보상은 그대로입니다.
- **「이름」 이야기 다듬기**: 이름을 잃는다·맡긴다·지워진다·되찾는다는 말이 장마다 조금씩 다르게 쓰이던 것을 하나로 맞추고, 처음 나오는 장면에서 인물이 그 뜻을 짧게 풀어 줍니다(명줄, 영과 요괴, 무명, 반요 등).
- 객사 별채 퀘스트의 살림꾼 이름을 **순덕**으로 바꿨습니다(백지교의 보미와 이름이 같았습니다).
- 회산 관문·주혈 광산 보조 퀘스트에서 제련품인 강철 주괴를 「채집」하던 할 일을 그 지역 광맥에서 나는 **월철 광석·생 월철**로 바꿨습니다(수량 같음). 이미 그 장면에 있는 분은 새 재료로 채우면 됩니다.
- 세력을 떠났다가 다시 들어오면, 다시 가입하는 장면 끝에서 등급 2 할 일을 맡겨 줍니다.
- **조사 기술 이름 「추적」 → 「탐사」**: 탐색·답사·원정에서 오르는 기술이라 이름을 맞췄습니다. 쌓은 경험과 익힌 기술은 그대로입니다.
- **붉은 안개**: 가로로 흐르며 아주 느리게 짙어졌다 옅어집니다. 기기의 「동작 줄이기」와 상관없이 흐르고, 날씨 창에서 끌 수 있습니다.
- **별채 가구 제작법 분야 오류**: 가구·벽지·바닥재·말린 생선포 제작법 50개가 분야 거르기에 잡히지 않고, 같은 분야 품질 보너스와 맞는 기술 경험이 붙지 않던 것을 고쳤습니다(봉인 공예 가구는 결계 각인, 말린 생선포는 요리 숙련).
$N$ where note_id = '7.4.0' and position('## 7.4.4' in body) = 0;

update public.world_app_meta set value = '20261103235000' where key = 'db_version';
