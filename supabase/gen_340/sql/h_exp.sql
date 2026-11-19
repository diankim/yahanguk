select pg_temp.yh_fix('world_expedition_settle', array[
  $q$        if c.job_key = 'analyst' and random() < 0.25 then$q$,
  $q$        if c.job_key = 'spearman' and random() < 0.3 then
          win_p := win_p + 0.1; jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[새벽 돌파] 요괴가 다가오기 전에 창끝이 먼저 닿습니다.');
        end if;
        if c.job_key = 'analyst' and random() < 0.25 then$q$,
  $q$        hp := hp - my_taken;$q$,
  $q$        if c.job_key = 'formation' and my_taken > 0 and random() < 0.3 then
          my_taken := round(my_taken * 0.7)::int; er := greatest(0, er - 1); jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[길흉 셈] 미리 셈해 둔 자리로 비켜서 피해를 덜었습니다.');
        end if;
        hp := hp - my_taken;
        if c.job_key = 'bloodknight' and my_taken > 0 and hp > 0 and random() < 0.25 then
          hp := least(100, hp + greatest(1, my_taken / 2)); jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '[베어 버티기] 베어 낸 기운으로 받은 상처의 절반을 되찾았습니다.');
        end if;$q$]);
