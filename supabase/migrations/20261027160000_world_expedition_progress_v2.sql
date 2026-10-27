-- 원정 진행 기록 2: 수색 회차 사이사이에 걸음·지형·기척·날씨·태세·직업에 맞는 기록이 시간에 따라 쌓인다.
-- - 30분 원정은 약 1분 15초마다, 8시간 원정은 10분마다 한 줄씩 늘어난다(원정 하나에 최대 약 48줄 + 수색 회차).
-- - 줄은 원정 번호와 시각으로 정해지므로 새로고침하거나 다른 기기에서 봐도 같다.
-- - 승패와 전리품은 여전히 귀환할 때 공개한다(진행 중에는 기척·흔적·분위기만 적는다).
-- 읽기 전용 함수라 바로 적용해도 된다.

create or replace function public.world_expedition_progress() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); e public.world_expeditions%rowtype; r public.world_map_regions%rowtype; c public.world_characters%rowtype;
  total int; done int; i int; t timestamptz; ph text; wk text; pph text; pwk text; lines jsonb := '[]'::jsonb; nm text; mons text[]; h0 int; h1 int;
  rations int; eaten int := 0; pool text[]; line text; party jsonb; pid uuid;
  span_s float8; beat_s float8; beats int; b int; bt timestamptz; grp text; cat int; h bigint; prev text := ''; mon text; next_beat timestamptz; next_round timestamptz;
  p_gen text[]; p_reg text[]; p_stance text[]; p_job text[]; p_env text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into e from public.world_expeditions where owner_id = uid and status = 'active';
  if not found then return jsonb_build_object('active', false); end if;
  select * into c from public.world_characters where owner_id = uid;
  select * into r from public.world_map_regions where region_id = e.region_id;
  select node_name into nm from public.world_exploration_nodes where node_id = e.node_id;
  total := case e.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end;
  span_s := extract(epoch from e.ends_at - e.started_at);
  done := greatest(0, least(total, floor(total * extract(epoch from least(now(), e.ends_at) - e.started_at) / span_s)::int));
  mons := array(select monster_name from public.world_region_monsters where region_id = e.region_id order by monster_name);
  rations := coalesce((e.supplies ->> 'travel_ration')::int, 0);
  lines := lines || jsonb_build_object('at', e.started_at, 'kind', 'start', 'text', coalesce(nm, '원정지') || '(으)로 들어섰습니다. 태세: '
    || case e.stance when 'cautious' then '신중' when 'bold' then '강행' else '균형' end || ' · 예정 수색 ' || total || '회');

  /* ── 수색 회차·시간대·날씨·건량 ── */
  pph := public.world_time_phase(e.started_at); pwk := public.world_weather_key(r.territory_id, e.started_at);
  pool := array['%s번째 수색을 마치고 다음 갈래로 나아갑니다.', '%s번째 수색을 마쳤습니다. 지나온 길을 지도에 옮겨 적습니다.', '%s번째 구역을 훑고 표식을 남겨 둡니다.',
    '%s번째 수색. 짐을 고쳐 메고 더 안쪽으로 향합니다.'];
  for i in 1..done loop
    t := e.started_at + (e.ends_at - e.started_at) * i / total;
    ph := public.world_time_phase(t); wk := public.world_weather_key(r.territory_id, t);
    if ph is distinct from pph then
      lines := lines || jsonb_build_object('at', t, 'kind', 'env', 'text', '시간이 흘러 ' || case ph when 'dawn' then '해돋이' when 'noon' then '한낮' when 'dusk' then '땅거미' else '삼경' end || '이 되었습니다.');
    end if;
    if wk is distinct from pwk then
      lines := lines || jsonb_build_object('at', t, 'kind', 'env', 'text', '날씨가 ' || case wk when 'clear' then '청명' when 'cloudy' then '담운' when 'rain' then '장우'
        when 'fog' then '농무' when 'wind' then '삭풍' when 'snow' then '설한' when 'bloodmist' then '혈무' else wk end || '(으)로 바뀌었습니다.');
    end if;
    pph := ph; pwk := wk;
    h0 := floor(e.minutes * (i - 1) / total / 60.0)::int; h1 := floor(e.minutes * i / total / 60.0)::int;
    if h1 > h0 then
      if eaten < rations then eaten := eaten + 1; lines := lines || jsonb_build_object('at', t, 'kind', 'supply', 'text', '노정 건량을 하나 꺼내 먹었습니다. (남은 건량 ' || (rations - eaten) || ')');
      else lines := lines || jsonb_build_object('at', t, 'kind', 'warn', 'text', '건량이 떨어져 허기진 채로 걷습니다.'); end if;
    end if;
    line := replace(pool[1 + abs(hashtext(e.expedition_id::text || ':' || i)::bigint) % cardinality(pool)], '%s', i::text);
    lines := lines || jsonb_build_object('at', t, 'kind', 'round', 'round', i, 'text', line);
  end loop;

  /* ── 사이사이의 걸음: 지역·일반·태세·직업·날씨/시간대 ── */
  grp := case
    when r.region_type in ('lake', 'coast', 'swamp', 'river_port', 'islands', 'underwater_ruins', 'bridge') then 'water'
    when r.region_type in ('ruined_temple', 'sealed_shrine', 'monastery', 'burial_ground', 'haunted_garden', 'pavilion') then 'shrine'
    when r.region_type in ('mountain_pass', 'mountain_peak', 'canyon', 'ice_valley', 'frontier_gate') then 'mountain'
    when r.region_type in ('underground', 'mine', 'abyss', 'rift', 'lost_city', 'ruins', 'archive', 'underworld_market') then 'deep'
    when r.region_type in ('observatory', 'celestial_tower') then 'sky'
    else 'wild' end;
  p_reg := case grp
    when 'water' then array['물안개가 발목까지 차올라 걸음을 조심스럽게 옮깁니다.', '물가의 갈대가 바람도 없이 한쪽으로 눕습니다.', '젖은 돌 위로 %m의 발자국이 이어져 있습니다.',
      '수면 아래에서 무언가 반짝였다가 사라집니다.', '떠내려온 나무판에 오래된 글씨가 새겨져 있습니다.', '물살 소리에 섞여 낮은 노랫소리가 들리는 듯합니다.',
      '썩은 말뚝에 묶인 빈 배 한 척이 삐걱거립니다.', '진흙에 빠진 신을 빼내느라 한참 애를 씁니다.', '물비린내 속에 비린 요기가 섞여 있습니다.', '수초 사이로 길이 하나 보여 그쪽으로 건너갑니다.']
    when 'shrine' then array['무너진 석등 아래에 아직 마르지 않은 향 자국이 있습니다.', '처마 끝 풍경이 혼자 울립니다.', '깨진 현판의 글자를 손끝으로 더듬어 읽어 봅니다.',
      '불단 뒤에서 %m의 그림자가 스쳐 지나갑니다.', '바닥에 흩어진 부적 조각을 주워 살펴봅니다.', '누군가 놓고 간 제물이 아직 상하지 않았습니다.',
      '돌계단 하나하나에 오래된 이름이 새겨져 있습니다.', '향 냄새가 짙어지는 쪽으로 천천히 다가갑니다.', '쓰러진 비석을 일으켜 세우고 잠시 묵념합니다.', '종루 위에서 누군가 내려다보는 기척이 듭니다.']
    when 'mountain' then array['가파른 비탈을 밧줄에 의지해 오릅니다.', '돌이 굴러떨어지는 소리에 바위 뒤로 몸을 숨깁니다.', '능선 너머로 %m의 울음이 메아리칩니다.',
      '바위틈에서 찬 바람이 새어 나옵니다.', '발아래 구름이 흘러가는 것을 내려다봅니다.', '오래된 돌무더기 이정표를 따라 방향을 잡습니다.',
      '미끄러운 얼음길에서 한 걸음씩 디딜 곳을 고릅니다.', '절벽에 새겨진 수호 문양이 희미하게 빛납니다.', '숨이 가빠 잠시 바위에 기대어 쉽니다.', '골짜기 아래로 길이 갈라집니다. 왼쪽 길을 택합니다.']
    when 'deep' then array['횃불이 흔들리며 벽의 긁힌 자국을 비춥니다.', '천장에서 떨어지는 물방울 소리만 이어집니다.', '좁은 통로를 몸을 옆으로 틀어 지나갑니다.',
      '어둠 저편에서 %m의 숨소리가 들립니다.', '무너진 서가 사이로 젖은 종이 냄새가 납니다.', '바닥에 그려진 오래된 진법을 밟지 않게 돌아갑니다.',
      '갱도 벽에 박힌 광석이 횃불에 반짝입니다.', '갈림길마다 분필로 표시를 남깁니다.', '발소리가 메아리쳐 몇 걸음 뒤에 따라오는 것 같습니다.', '깊은 곳에서 차가운 바람이 거꾸로 불어옵니다.']
    when 'sky' then array['별자리 판이 저절로 조금씩 돌아갑니다.', '높은 난간 너머로 밤하늘이 손에 닿을 듯합니다.', '관측 기록 한 장이 바람에 날려 와 발밑에 떨어집니다.',
      '하늘 위로 %m의 날개 그림자가 지나갑니다.', '청동 혼천의가 낮게 웅웅 울립니다.', '계단이 끝없이 이어지는 듯해 층수를 세며 오릅니다.',
      '흩어진 성진사가 발밑에서 반짝입니다.', '탑 꼭대기에서 별빛이 한 줄기 내려와 길을 비춥니다.']
    else array['수풀을 헤치며 짐승길을 따라 걷습니다.', '쓰러진 나무 아래에서 잠시 숨을 고릅니다.', '바람결에 %m의 기척이 스칩니다.',
      '풀숲에 버려진 낡은 등롱을 발견합니다.', '나뭇가지에 묶인 붉은 천 조각이 바람에 날립니다.', '%m이(가) 남긴 흔적을 따라 걸음을 옮깁니다.',
      '멀리서 낯선 소리가 들려 걸음을 늦춥니다.', '약초 냄새가 나는 쪽을 기억해 둡니다.', '오래된 표식을 발견하고 기록해 둡니다.', '잡초가 웃자란 옛길이 숲 안쪽으로 이어집니다.'] end;
  p_gen := array['잠시 멈춰 지도를 고쳐 그립니다.', '물을 긷고 짐을 다시 꾸립니다.', '신발 끈을 고쳐 묶고 다시 걷습니다.', '가방 속 보급품을 하나하나 세어 봅니다.',
    '발밑의 흙빛이 바뀌었습니다. 다른 구역으로 들어선 듯합니다.', '지나온 길을 돌아보며 표식이 남았는지 확인합니다.', '목이 말라 물을 한 모금 마십니다.',
    '잠깐 귀를 기울입니다. 주변이 너무 조용합니다.', '무기를 한 번 더 점검합니다.', '야행국에 보낼 짧은 보고를 적어 둡니다.', '바람 방향을 확인하고 냄새가 실려 오지 않는 쪽으로 돕니다.',
    '앉을 만한 돌을 찾아 잠시 다리를 쉽니다.'];
  p_stance := case e.stance
    when 'cautious' then array['기척이 나는 쪽을 피해 먼 길로 돌아갑니다.', '몸을 낮추고 소리를 죽여 지나갑니다.', '위험해 보이는 곳은 표시만 하고 지나칩니다.', '쉴 곳을 미리 봐 두고 천천히 나아갑니다.']
    when 'bold' then array['%m의 흔적을 일부러 따라 더 깊이 들어갑니다.', '거친 덤불을 칼로 베어 길을 냅니다.', '쉬지 않고 걸음을 재촉합니다.', '기척이 짙은 쪽으로 방향을 틉니다.']
    else array['갈림길에서 잠시 고민하다 넓은 길을 택합니다.', '경계를 늦추지 않고 일정한 걸음으로 나아갑니다.', '싸울 곳과 물러날 곳을 눈여겨봅니다.', '숨을 고르며 주변을 한 바퀴 둘러봅니다.'] end;
  p_job := case c.job_key
    when 'exorcist' then array['부적 한 장을 손에 쥐고 요기의 흐름을 읽습니다.', '나쁜 기운이 고인 곳에 정화 부적을 붙여 둡니다.', '방울을 한 번 흔들어 주변 혼백을 달랩니다.']
    when 'scout' then array['꺾인 풀잎으로 무엇이 언제 지나갔는지 가늠합니다.', '높은 곳에 올라 지형을 살핍니다.', '바닥의 발자국 크기를 재어 기록합니다.']
    when 'medic' then array['길가의 약초를 몇 줄기 꺾어 챙깁니다.', '작은 상처를 소독하고 붕대를 고쳐 맵니다.', '쓸 만한 약초가 자라는 곳을 지도에 표시합니다.']
    when 'sealmaster' then array['쉴 자리 둘레에 작은 결계를 그려 둡니다.', '봉인 먹으로 갈림길 바위에 표식을 남깁니다.', '결계가 흐트러진 자리를 찾아 손으로 짚어 봅니다.']
    when 'analyst' then array['지금까지 본 요괴의 습성을 수첩에 정리합니다.', '흔적의 순서를 맞춰 보며 동선을 추론합니다.', '모순되는 단서 하나에 밑줄을 그어 둡니다.']
    when 'artificer' then array['쓸 만한 부품을 주워 주머니에 넣습니다.', '헐거워진 장비의 매듭을 고쳐 조입니다.', '이상한 광택의 금속 조각을 살펴봅니다.']
    else array['주변을 살피며 천천히 나아갑니다.'] end;

  beat_s := greatest(75, span_s / 48.0);
  beats := floor(extract(epoch from least(now(), e.ends_at) - e.started_at) / beat_s)::int;
  for b in 1..beats loop
    bt := e.started_at + make_interval(secs => b * beat_s);
    if bt >= e.ends_at then exit; end if;
    h := abs(hashtext(e.expedition_id::text || '~' || b)::bigint);
    cat := h % 20;
    mon := coalesce(mons[1 + (h / 7) % greatest(1, cardinality(mons))], '요괴');
    if cat < 9 then line := p_reg[1 + (h / 20) % cardinality(p_reg)];
    elsif cat < 14 then line := p_gen[1 + (h / 20) % cardinality(p_gen)];
    elsif cat < 16 then line := p_stance[1 + (h / 20) % cardinality(p_stance)];
    elsif cat < 18 then line := p_job[1 + (h / 20) % cardinality(p_job)];
    else
      ph := public.world_time_phase(bt); wk := public.world_weather_key(r.territory_id, bt);
      p_env := case wk when 'rain' then array['빗줄기가 굵어져 처마 같은 바위 밑으로 잠시 피합니다.', '빗물에 흔적이 씻겨 내려가 길을 다시 찾습니다.']
        when 'fog' then array['안개가 짙어 한 걸음 앞도 잘 보이지 않습니다.', '안개 속에서 누군가 이름을 부르는 듯합니다.']
        when 'snow' then array['눈이 발목까지 쌓여 걸음이 무거워집니다.', '눈 위에 찍힌 낯선 발자국을 따라가 봅니다.']
        when 'wind' then array['삭풍이 옷깃을 파고들어 몸을 웅크립니다.', '바람에 실려 온 재가 눈을 따갑게 합니다.']
        when 'bloodmist' then array['붉은 안개가 피부에 닿아 따끔거립니다.', '혈무 속에서 요기가 한층 짙어집니다.']
        when 'cloudy' then array['구름이 낮게 깔려 사방이 어둑합니다.', '흐린 하늘 아래 바람이 눅눅합니다.']
        else array['맑은 하늘 덕에 먼 곳까지 내다보입니다.', '햇볕이 따뜻해 잠시 걸음이 가볍습니다.'] end
        || case ph when 'night' then array['달빛에 기대어 발밑을 더듬습니다.', '삼경의 정적 속에 풀벌레 소리마저 멎었습니다.']
        when 'dawn' then array['동이 트며 이슬이 반짝입니다.', '새벽 새 우는 소리에 긴장이 조금 풀립니다.']
        when 'dusk' then array['노을이 지며 그림자가 길어집니다.', '땅거미가 내려 등불을 켭니다.']
        else array['한낮의 열기에 땀이 흐릅니다.', '그늘을 골라 걸으며 숨을 돌립니다.'] end;
      line := p_env[1 + (h / 20) % cardinality(p_env)];
    end if;
    line := replace(replace(line, '%m', mon), '%p', coalesce(nm, '원정지'));
    if line = prev then line := p_gen[1 + (h / 3) % cardinality(p_gen)]; end if;
    prev := line;
    lines := lines || jsonb_build_object('at', bt, 'kind', 'walk', 'text', line);
  end loop;

  if now() >= e.ends_at then lines := lines || jsonb_build_object('at', e.ends_at, 'kind', 'end', 'text', '원정을 마치고 돌아왔습니다. 결과를 받으세요.'); end if;
  -- 시각 순서로 다시 정렬(같은 시각이면 들어온 순서)
  lines := (select coalesce(jsonb_agg(x order by (x ->> 'at')::timestamptz, n), '[]'::jsonb) from jsonb_array_elements(lines) with ordinality as a(x, n));

  next_round := case when done < total then e.started_at + (e.ends_at - e.started_at) * (done + 1) / total end;
  next_beat := e.started_at + make_interval(secs => (beats + 1) * beat_s);
  if next_beat >= e.ends_at then next_beat := null; end if;

  -- 같은 파티원의 원정
  select party_id into pid from public.world_party_members where owner_id = uid;
  party := coalesce((select jsonb_agg(jsonb_build_object('name', pc.character_name, 'place', pn.node_name, 'region', pr.region_name, 'same_region', x.region_id = e.region_id,
      'rounds_done', greatest(0, least(xt.tot, floor(xt.tot * extract(epoch from least(now(), x.ends_at) - x.started_at) / (x.minutes * 60.0))::int)), 'total_rounds', xt.tot,
      'ends_at', x.ends_at) order by pc.character_name)
    from public.world_party_members pm join public.world_expeditions x on x.owner_id = pm.owner_id and x.status = 'active'
    join public.world_characters pc on pc.owner_id = pm.owner_id left join public.world_exploration_nodes pn on pn.node_id = x.node_id
    left join public.world_map_regions pr on pr.region_id = x.region_id
    cross join lateral (select case x.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end as tot) xt
    where pid is not null and pm.party_id = pid and pm.owner_id <> uid), '[]'::jsonb);
  return jsonb_build_object('active', true, 'place', nm, 'region', r.region_name, 'stance', e.stance, 'rounds_done', done, 'total_rounds', total,
    'started_at', e.started_at, 'ends_at', e.ends_at,
    'next_at', case when next_round is null then next_beat when next_beat is null then next_round else least(next_round, next_beat) end,
    'next_round_at', next_round,
    'lines', lines, 'party', party,
    'job_skill', case c.job_key when 'exorcist' then '파사 부적' when 'scout' then '흔적 추적' when 'medic' then '야전 처치'
      when 'sealmaster' then '결계 야영' when 'analyst' then '약점 간파' when 'artificer' then '현장 가공' end);
end $$;
