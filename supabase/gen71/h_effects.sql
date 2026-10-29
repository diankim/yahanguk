
-- ─────────────────────────────────────────────────────────────
-- H. 이름만 있고 쓰이지 않던 상태 효과 두 가지를 실제로 반영
--   training_xp_pct(기술 경험): 충분한 휴식 +15·집중 +10·영감 +15 / 기력 저하 −15·소화 불량 −8·한기 침입 −10 → 행동으로 쌓는 기술 경험에
--   agility_pct(민첩): 근맥 손상 −15 → 전투 능력치를 셀 때 민첩에(원거리 공격·회피·달아나기·이목)
--   상태 칸만 보는 가벼운 합(world_status_effect_total처럼 장비·칭호·날씨를 다 돌지 않는다)
-- ─────────────────────────────────────────────────────────────
create or replace function public.world_status_self(p_owner uuid, p_key text) returns numeric
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce(sum((cat.effects ->> p_key)::numeric * coalesce(cs.potency, 1)), 0)
    from public.world_character_statuses cs join public.world_status_catalog cat using (status_key)
   where cs.owner_id = p_owner and cs.expires_at > now() and (cat.effects ->> p_key) ~ '^-?[0-9]+(\.[0-9]+)?$'
$$;
alter function public.world_status_self(uuid, text) owner to fn_owner_field;
do $$ begin
  set role fn_owner_field;
  revoke all on function public.world_status_self(uuid, text) from public, anon, authenticated;
  reset role;
end $$;

select pg_temp.yh_patch('public.world_event_char_apply()', 'public.world_skill_add(c.skill_progress, sk, sk_xp, ',
  'public.world_skill_add(c.skill_progress, sk, round(sk_xp * greatest(0.5, 1 + public.world_status_self(c.owner_id, ''training_xp_pct'') / 100.0))::int, ');
select pg_temp.yh_patch('public.world_combat_stats(uuid,jsonb)', 's_agi := c.agility + coalesce((p_delta ->> ''agility'')::int, 0);',
  's_agi := c.agility + coalesce((p_delta ->> ''agility'')::int, 0); s_agi := greatest(1, round(s_agi * (1 + public.world_status_self(p_owner, ''agility_pct'') / 100.0))::int);');
