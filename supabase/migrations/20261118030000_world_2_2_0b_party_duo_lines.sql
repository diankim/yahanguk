create or replace function public.world_expedition_duo_lines(p_a uuid, p_b uuid) returns jsonb
language plpgsql stable set search_path = '' as $f$
declare ea public.world_expeditions%rowtype; eb public.world_expeditions%rowtype; na text; nb text; ja text; jb text; x text; y text; jx text; ox uuid;
  total int; done int; i int; h bigint; lines jsonb := '[]'::jsonb; k text; t timestamptz; ph text; pool text[]; s text; used text[] := '{}'; j int; c int; n int;
  p_start text[] := array['%a이(가) %b에게 「오늘도 잘 부탁해.」 하고 주먹을 내밉니다. %b이(가) 웃으며 주먹을 맞댑니다.',
    '%a과(와) %b이(가) 길머리에서 짐을 한 번 더 맞춰 보고 나란히 걸음을 뗍니다.',
    '%b이(가) 「길은 내가 볼 테니 뒤는 맡길게.」 하고 말하자 %a이(가) 고개를 끄덕입니다.',
    '%a이(가) 지도를 펼쳐 %b에게 오늘 갈 길을 손가락으로 짚어 보입니다.'];
  p_end text[] := array['%a이(가) 「돌아가면 따뜻한 국밥부터 먹자.」 하고 말하자 %b이(가) 배를 문지르며 웃습니다.',
    '%a과(와) %b이(가) 무사히 돌아가는 길에 오늘 있었던 일을 하나씩 꼽아 봅니다.',
    '%b이(가) 「덕분에 살았어.」 하고 말하자 %a이(가) 「나야말로.」 하고 어깨를 툭 칩니다.',
    '%a이(가) 지친 %b의 짐 한 꾸러미를 말없이 받아 듭니다.'];
  p_all text[] := array['%a이(가) %b에게 물주머니를 건넵니다.', '%a이(가) 앞서 걷고 %b이(가) 뒤를 살핍니다.', '%a이(가) %b의 짐끈을 고쳐 매 줍니다.',
    '%a이(가) 수상한 기척을 손짓으로 %b에게 알립니다.', '%b이(가) 찾은 흔적을 %a이(가) 지도에 옮겨 적습니다.', '%a이(가) 발을 헛디딘 %b을(를) 붙잡아 줍니다.',
    '%a과(와) %b이(가) 바위 그늘에서 잠깐 숨을 고릅니다.', '%a이(가) 마른 육포를 반으로 갈라 %b에게 나눠 줍니다.',
    '%a이(가) 「괜찮아?」 하고 묻자 %b이(가) 엄지를 들어 보입니다.',
    '%b이(가) 콧노래를 흥얼거리자 %a이(가) 어느새 따라 부릅니다.',
    '%a이(가) 길가에 핀 꽃 한 송이를 꺾어 %b의 짐 끈에 꽂아 줍니다.',
    '%a과(와) %b이(가) 갈림길에서 잠깐 티격태격하다가 결국 %b이(가) 고른 길로 갑니다.',
    '%a이(가) 「아까 그 요괴, 꽤 무서웠지?」 하고 묻자 %b이(가) 「너만큼은 아니었어.」 하고 받아칩니다.',
    '%b이(가) 신발에 든 돌을 터는 동안 %a이(가) 곁에서 망을 봅니다.',
    '%a이(가) 어릴 적 이야기를 꺼내자 %b이(가) 걸음을 늦추고 귀를 기울입니다.',
    '%a이(가) %b의 소매에 붙은 도깨비풀을 하나씩 떼어 줍니다.',
    '%b이(가) 「잠깐만.」 하고 멈추자 %a이(가) 군말 없이 함께 기다립니다.',
    '%a이(가) 주머니에서 꺼낸 엿을 %b의 입에 쏙 넣어 줍니다.',
    '%a과(와) %b이(가) 누가 더 멀리 돌을 던지나 내기를 하다가 둘 다 웃음을 터뜨립니다.',
    '%b이(가) 젖은 수건을 짜서 %a의 이마에 얹어 줍니다.',
    '%a이(가) 「다음엔 내가 앞장설게.」 하고 말하자 %b이(가) 「그래, 믿을게.」 하고 답합니다.',
    '%a이(가) 지친 기색인 %b에게 걸음을 맞춰 천천히 걷습니다.',
    '%a과(와) %b이(가) 등을 맞대고 앉아 사방을 살핍니다.',
    '%b이(가) 길에서 주운 예쁜 조약돌을 %a에게 자랑합니다.'];
  p_night text[] := array['%a과(와) %b이(가) 모닥불 곁에 나란히 앉아 번갈아 불침번을 섭니다.',
    '%a이(가) 별을 가리키며 %b에게 별자리 이름을 하나씩 일러 줍니다.',
    '%b이(가) 꾸벅꾸벅 졸자 %a이(가) 제 겉옷을 벗어 덮어 줍니다.',
    '%a이(가) 어둠 속에서 %b의 등롱 심지를 돋워 줍니다.'];
  p_dawn text[] := array['%a이(가) 먼저 일어나 %b의 몫까지 아침 죽을 끓입니다.',
    '%a과(와) %b이(가) 해 뜨는 쪽을 잠깐 함께 바라보다 다시 길을 나섭니다.',
    '%b이(가) 이슬에 젖은 %a의 신을 불 곁에 세워 말려 줍니다.'];
  p_dusk text[] := array['%a이(가) 「해 지기 전에 쉴 곳을 찾자.」 하고 말하자 %b이(가) 걸음을 재촉합니다.',
    '%a과(와) %b이(가) 노을 진 하늘 아래 오늘 번 것을 셈해 봅니다.',
    '%b이(가) 땔감을 모으는 동안 %a이(가) 잠자리를 고릅니다.'];
  p_job jsonb := jsonb_build_object(
    'artificer', jsonb_build_array('%a이(가) 방패를 들어 %b의 앞을 가려 줍니다. 「내 뒤에 있어.」', '%a이(가) 무거운 짐을 대신 지고 %b에게 가벼운 쪽을 넘깁니다.', '%a이(가) 쓰러진 나무를 치워 %b이(가) 지날 길을 엽니다.'),
    'scout', jsonb_build_array('%a이(가) 높은 바위에 올라 멀리 살핀 뒤 %b에게 안전하다고 손짓합니다.', '%a이(가) 화살촉을 갈며 %b에게 「위험하면 소리만 질러.」 하고 이릅니다.', '%a이(가) 바람결을 읽고 %b에게 돌아갈 길을 일러 줍니다.'),
    'exorcist', jsonb_build_array('%a이(가) 방울을 흔들어 %b의 어깨에 붙은 잔기운을 털어 줍니다.', '%a이(가) 쉬는 자리 둘레에 부적을 꽂아 %b이(가) 편히 눈을 붙이게 합니다.', '%a이(가) 짧은 진언을 외며 %b의 앞길을 맑힙니다.'),
    'medic', jsonb_build_array('%a이(가) %b의 긁힌 팔을 살펴 약초를 찧어 발라 줍니다.', '%a이(가) %b의 맥을 짚어 보고 「조금 쉬었다 가자.」 하고 말합니다.', '%a이(가) 쓴 탕약을 내밀자 %b이(가) 얼굴을 찡그리면서도 다 마십니다.'),
    'sealmaster', jsonb_build_array('%a이(가) 갈림길마다 작은 봉인 표식을 남겨 %b이(가) 길을 잃지 않게 합니다.', '%a이(가) 금강령을 울려 %b 곁에 얕은 결계를 칩니다.', '%a이(가) 수상한 비석을 봉인 끈으로 묶고 %b에게 가까이 가지 말라고 이릅니다.'),
    'analyst', jsonb_build_array('%a이(가) 그림자에 몸을 숨긴 채 앞서 가며 %b에게 따라오라고 손짓합니다.', '%a이(가) 단도를 갈다가 %b의 칼날도 받아 함께 손질해 줍니다.', '%a이(가) 발소리를 죽이는 법을 %b에게 속삭이듯 일러 줍니다.'),
    'tamer', jsonb_build_array('%a의 동무가 %b의 발치에 몸을 비비며 따라 걷습니다.', '%a이(가) 동무에게 휘파람을 불어 %b이(가) 떨어뜨린 물건을 물어 오게 합니다.', '%a이(가) %b에게 동무를 쓰다듬어 보라고 권합니다. 동무가 꼬리를 흔듭니다.'));
begin
  select * into ea from public.world_expeditions where expedition_id = least(p_a, p_b);
  select * into eb from public.world_expeditions where expedition_id = greatest(p_a, p_b);
  if ea.expedition_id is null or eb.expedition_id is null then return lines; end if;
  select character_name, job_key into na, ja from public.world_characters where owner_id = ea.owner_id;
  select character_name, job_key into nb, jb from public.world_characters where owner_id = eb.owner_id;
  k := least(p_a::text, p_b::text) || greatest(p_a::text, p_b::text);
  total := case ea.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end;
  done := greatest(0, least(total, floor(total * extract(epoch from least(now(), ea.ends_at) - ea.started_at) / extract(epoch from ea.ends_at - ea.started_at))::int));
  if ea.state ->> 'ended' in ('downed', 'exhausted') then done := least(done, ea.settled_rounds); end if;
  if eb.state ->> 'ended' in ('downed', 'exhausted') then done := least(done, eb.settled_rounds); end if;
  for i in 1..done loop
    h := abs(hashtext(k || '~duo2~' || i)::bigint);
    if (h / 7) % 2 = 0 then x := na; y := nb; jx := ja; ox := ea.owner_id; else x := nb; y := na; jx := jb; ox := eb.owner_id; end if;
    t := ea.started_at + (ea.ends_at - ea.started_at) * (i - 0.6) / total;
    if i = 1 then pool := p_start;
    elsif i = total then pool := p_end;
    elsif h % 4 = 0 then continue;
    else
      ph := public.world_time_phase(t);
      if (h / 3) % 10 < 3 and p_job ? jx then
        select array_agg(v) into pool from jsonb_array_elements_text(p_job -> jx) v;
      elsif (h / 3) % 10 < 5 and ph in ('night', 'dawn', 'dusk') then
        pool := case ph when 'night' then p_night when 'dawn' then p_dawn else p_dusk end;
      else pool := p_all;
      end if;
    end if;
    c := cardinality(pool); j := (h / 31) % c;
    n := 0; while n < c - 1 and pool[1 + (j + n) % c] = any(used) loop n := n + 1; end loop;
    s := pool[1 + (j + n) % c];
    if s = any(used) and i > 1 and i < total then
      c := cardinality(p_all); j := (h / 31) % c;
      n := 0; while n < c - 1 and p_all[1 + (j + n) % c] = any(used) loop n := n + 1; end loop;
      s := p_all[1 + (j + n) % c];
    end if;
    used := used || s;
    s := replace(replace(s, '%a', x), '%b', y);
    lines := lines || jsonb_build_object('at', t, 'kind', 'walk', 'who', x, 'owner', ox, 'text', s);
    if i > 1 and i < total and (h / 131) % 4 = 0 then
      c := cardinality(p_all); j := (h / 977) % c;
      n := 0; while n < c - 1 and p_all[1 + (j + n) % c] = any(used) loop n := n + 1; end loop;
      s := p_all[1 + (j + n) % c]; used := used || s;
      s := replace(replace(s, '%a', y), '%b', x);
      lines := lines || jsonb_build_object('at', t + (ea.ends_at - ea.started_at) * 0.3 / total, 'kind', 'walk', 'who', y,
        'owner', case when ox = ea.owner_id then eb.owner_id else ea.owner_id end, 'text', s);
    end if;
  end loop;
  return lines;
end $f$;

update public.world_patch_notes set body = rtrim(body, E'\n') || E'\n\n## 파티 원정 일지\n- 파티 원정으로 함께 떠난 동료끼리 서로 챙기고 말을 주고받는 줄이 훨씬 자주, 여러 가지로 나옵니다. 떠날 때·돌아올 때 한마디, 밤·새벽·해 질 녘에 어울리는 줄, 직업마다 다른 챙김이 섞입니다.\n'
 where note_id = '2.2.0' and body not like '%## 파티 원정 일지%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118030000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
