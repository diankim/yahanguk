alter table public.world_characters drop constraint world_characters_job_key_check;
alter table public.world_characters add constraint world_characters_job_key_check
  check (job_key = any (array['exorcist', 'scout', 'medic', 'sealmaster', 'analyst', 'artificer', 'tamer', 'bloodknight', 'spearman', 'formation']));

select pg_temp.yh_fix('world_job_base', array[$q$
    when 'analyst'    then$q$, $q$
    when 'bloodknight' then '{"strength":9,"agility":3,"vitality":8,"perception":3,"willpower":4,"spirit_affinity":3}'
    when 'spearman'   then '{"strength":8,"agility":7,"vitality":5,"perception":4,"willpower":3,"spirit_affinity":3}'
    when 'formation'  then '{"strength":3,"agility":3,"vitality":3,"perception":5,"willpower":7,"spirit_affinity":9}'
    when 'analyst'    then$q$]);

select pg_temp.yh_fix('world_job_effect', array[$q$
      when 'tamer'      then 0$q$, $q$
      when 'tamer'      then 0
      when 'bloodknight' then case p_key when 'incoming_damage_pct' then -6 else 0 end
      when 'spearman'   then 0
      when 'formation'  then case p_key when 'shield_pct' then 15 when 'healing_pct' then -10 when 'mental_loss_pct' then -5 else 0 end$q$]);

select pg_temp.yh_fix('world_job_label', array[$q$ when 'tamer' then '조련사' end$q$, $q$ when 'tamer' then '조련사' when 'bloodknight' then '혈기사' when 'spearman' then '여명 창객' when 'formation' then '진법가' end$q$]);
select pg_temp.yh_fix('world_job_name', array[$q$ when 'tamer' then '조련사' else$q$, $q$ when 'tamer' then '조련사' when 'bloodknight' then '혈기사' when 'spearman' then '여명 창객' when 'formation' then '진법가' else$q$]);

create or replace function public.world_job_line(p_job text)
 returns text language sql immutable
as $function$
  select case p_job when 'artificer' then 'melee' when 'scout' then 'ranged' when 'sealmaster' then 'sealing'
    when 'exorcist' then 'exorcism' when 'analyst' then 'dagger' when 'medic' then 'medicine' when 'tamer' then 'taming'
    when 'bloodknight' then 'bloodcraft' when 'spearman' then 'spear' when 'formation' then 'formation' end
$function$;

create or replace function public.world_combat_lines()
 returns text[] language sql immutable
as $function$
  select array['melee', 'ranged', 'sealing', 'dagger', 'exorcism', 'medicine', 'taming', 'bloodcraft', 'spear', 'formation']
$function$;

select pg_temp.yh_fix('world_job_skill_rules', array[$q$ 'line', '{me}의 「휘파람」: 동무가 함께 달려들었다.'))$q$, $q$ 'line', '{me}의 「휘파람」: 동무가 함께 달려들었다.'),
    'bloodknight', jsonb_build_object('name', '피 갑주', 'desc', '체력 15를 깎아 세 턴 동안 보호막 20을 두르고 그 차례에 베어 듭니다(보호막 세기 덤 적용). 그 안에 다 깨지면 깎은 체력의 절반을 돌려받습니다.', 'duel', jsonb_build_object('kind', 'heal', 'heal', 0.2), 'line', '{me}의 「피 갑주」: 제 피로 갑주를 둘러 기세 {n}을(를) 버텼다.'),
    'spearman', jsonb_build_object('name', '관통 찌르기', 'desc', '근접 ×1.4로 찌르고 상대 방어의 절반을 무시합니다.', 'duel', jsonb_build_object('kind', 'pierce', 'n', 1, 'mul', 1.4), 'line', '{me}의 「관통 찌르기」: 창끝이 갑주 틈을 꿰었다.'),
    'formation', jsonb_build_object('name', '산가지 진', 'desc', '산가지를 날리며(술법 ×0.7) 진을 쳐 세 턴 동안 받는 피해가 25% 줄고, 진이 걷힐 때 체력 10을 되찾습니다.', 'duel', jsonb_build_object('kind', 'heal', 'heal', 0.18), 'line', '{me}의 「산가지 진」: 다칠 자리를 미리 막아 기세 {n}을(를) 지켰다.'))$q$]);

select pg_temp.yh_fix('world_solo_aid(text)', array[$q$
    when 'analyst'    then$q$, $q$
    when 'bloodknight' then '{"solo_dmg": -52, "solo_guard": -27, "final_dmg": -2}'
    when 'spearman'   then '{"solo_dmg": -25, "solo_guard": -36, "final_dmg": 34}'
    when 'formation'  then '{"solo_dmg": -30, "solo_guard": -55, "final_dmg": 18}'
    when 'analyst'    then$q$]);

do $$
declare d text;
begin
  d := pg_get_functiondef('public.world_boss_rules()'::regprocedure);
  d := regexp_replace(d, '"tamer": \{"solo_dmg": (-?[0-9.]+), "solo_guard": (-?[0-9.]+)\}',
    '"tamer": {"solo_dmg": \1, "solo_guard": \2}, "bloodknight": {"solo_dmg": \1, "solo_guard": \2}, "spearman": {"solo_dmg": \1, "solo_guard": \2}, "formation": {"solo_dmg": \1, "solo_guard": \2}', 'g');
  execute d;
end $$;

create or replace function public.world_weapon_jobs_of(p_type text)
 returns jsonb language sql immutable
as $function$
  select case coalesce(p_type, 'melee') when 'ranged' then '["scout","tamer"]'::jsonb when 'magic' then '["exorcist","sealmaster","medic","formation"]'::jsonb
    else '["artificer","analyst","bloodknight","spearman"]'::jsonb end
$function$;

update public.world_monster_kinds set job_keys = job_keys || array['bloodknight'] where kind_key in ('giant', 'shell') and not 'bloodknight' = any (job_keys);
update public.world_monster_kinds set job_keys = job_keys || array['spearman'] where kind_key in ('bird', 'sky') and not 'spearman' = any (job_keys);
update public.world_monster_kinds set job_keys = job_keys || array['formation'] where kind_key in ('ward', 'water') and not 'formation' = any (job_keys);

select pg_temp.yh_fix('world_create_character_v2', array[
  $q$    else                   '{"weapon":"w_melee1_keen"$q$, $q$    when 'bloodknight' then '{"weapon":"w_melee1_heavy","armor":"a1_iron","amulet":"m1_ward","tool":"field_knife"}'
    when 'spearman'   then '{"weapon":"w_spear1_b","armor":"padded_coat","shoes":"s1_road","tool":"field_knife"}'
    when 'formation'  then '{"weapon":"w_magic1_keen","armor":"a1_robe","amulet":"m1_purify","tool":"field_knife"}'
    else                   '{"weapon":"w_melee1_keen"$q$,
  $q$    when 'analyst'    then '{"tonic":2}'$q$, $q$    when 'analyst'    then '{"tonic":2}'
    when 'bloodknight' then '{"tonic":2}'
    when 'spearman'   then '{"tonic":2}'
    when 'formation'  then '{"ward_talisman":2,"seal_paper":2}'$q$]);

create or replace function public.world_presence_rules() returns jsonb language sql immutable as $$
  select jsonb_build_object('cap', jsonb_build_object('artificer', 300, 'bloodknight', 300, 'sealmaster', 220), 'cap_other', 160)
$$;
grant execute on function public.world_presence_rules() to authenticated;
create or replace function public.world_presence_cap(p_job text) returns integer language sql immutable as $$
  select coalesce((public.world_presence_rules() -> 'cap' ->> p_job)::int, (public.world_presence_rules() ->> 'cap_other')::int)
$$;
select pg_temp.yh_share('public.world_presence_cap(text)');

select pg_temp.yh_fix('world_combat_stats', array[
  $q$WHEN c.job_key = 'analyst' AND style = 'melee' THEN 1.18 ELSE 1 END;$q$,
  $q$WHEN c.job_key = 'analyst' AND style = 'melee' THEN 1.18 WHEN c.job_key = 'bloodknight' THEN 0.95 WHEN c.job_key = 'spearman' AND style = 'melee' THEN 1.06 ELSE 1 END;$q$,
  $q$WHEN c.job_key = 'artificer' THEN 80 WHEN c.job_key = 'sealmaster' THEN 60$q$,
  $q$WHEN c.job_key = 'artificer' THEN 80 WHEN c.job_key = 'bloodknight' THEN 70 WHEN c.job_key = 'sealmaster' THEN 60$q$,
  $q$  pres := greatest(5, least(300, (1 + coalesce($q$, $q$  pres := greatest(5, least(public.world_presence_cap(c.job_key), (1 + coalesce($q$]);

select pg_temp.yh_fix('world_expedition_complete', array[$q$ when 'tamer' then '동무의 코' end;$q$, $q$ when 'tamer' then '동무의 코' when 'bloodknight' then '베어 버티기' when 'spearman' then '새벽 돌파' when 'formation' then '길흉 셈' end;$q$]);
select pg_temp.yh_fix('world_expedition_progress', array[$q$ when 'tamer' then '동무의 코' end);$q$, $q$ when 'tamer' then '동무의 코' when 'bloodknight' then '베어 버티기' when 'spearman' then '새벽 돌파' when 'formation' then '길흉 셈' end);$q$]);

select pg_temp.yh_fix('world_expedition_walk_lines', array[$q$
    else array['주변을 살피며 천천히 나아갑니다.'] end;$q$, $q$
    when 'bloodknight' then array['도끼날에 묻은 피를 닦으며 묵묵히 앞장섭니다.', '상처를 동여매고 다시 걸음을 재촉합니다.', '무거운 갑주를 고쳐 메고 숨을 고릅니다.']
    when 'spearman' then array['긴 창끝으로 앞길의 풀숲을 먼저 헤칩니다.', '창 자루를 어깨에 걸고 새벽빛 쪽을 바라봅니다.', '창끝이 닿는 거리를 가늠하며 발을 옮깁니다.']
    when 'formation' then array['나경을 꺼내 방위를 읽고 길을 고릅니다.', '산가지를 몇 개 놓아 오늘 길의 길흉을 셈합니다.', '땅 기운이 흐린 자리를 피해 돌아갑니다.']
    else array['주변을 살피며 천천히 나아갑니다.'] end;$q$]);

select pg_temp.yh_fix('world_exp_fight_story', array[$q$
    when 'tamer' then '[짝 사냥] 동무가 {f}에게 달려든 틈에 화살을 박아 넣었습니다' else null end;$q$, $q$
    when 'tamer' then '[짝 사냥] 동무가 {f}에게 달려든 틈에 화살을 박아 넣었습니다'
    when 'bloodknight' then '[베어 버티기] {f}의 공격을 몸으로 받으며 도끼로 베어 넘겼습니다'
    when 'spearman' then '[새벽 돌파] {f}이(가) 다가오기 전에 창끝이 먼저 닿았습니다'
    when 'formation' then '[길흉 셈] 미리 셈해 둔 자리로 비켜서며 {f}의 공격을 흘렸습니다' else null end;$q$]);

select pg_temp.yh_fix('world_expedition_duo_lines', array[$q$
    'tamer', jsonb_build_array($q$, $q$
    'bloodknight', jsonb_build_array('%a이(가) 다친 %b의 팔을 제 붕대로 단단히 동여매 줍니다.', '%a이(가) 무거운 짐을 대신 지고 %b에게 앞서 가라고 턱짓합니다.', '%a이(가) 도끼를 갈다가 %b의 무기 날도 봐 줍니다.'),
    'spearman', jsonb_build_array('%a이(가) 창끝으로 %b의 발 앞 풀숲을 먼저 헤쳐 줍니다.', '%a이(가) 새벽빛이 드는 쪽을 가리키며 %b에게 길을 일러 줍니다.', '%a이(가) %b에게 창 자루 잡는 법을 장난스레 가르쳐 줍니다.'),
    'formation', jsonb_build_array('%a이(가) 나경을 보며 %b에게 오늘 피할 방위를 일러 줍니다.', '%a이(가) %b의 발치에 산가지를 놓아 쉴 자리를 골라 줍니다.', '%a이(가) %b의 걸음 수를 셈해 쉬어 갈 때를 알려 줍니다.'),
    'tamer', jsonb_build_array($q$]);
