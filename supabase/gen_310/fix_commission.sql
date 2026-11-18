select pg_temp.yh_fix('world_commission_board', array[
  E'  END IF;\n  RETURN jsonb_build_object(''day'', today',
  E'    UPDATE public.world_commissions m SET progress = least(m.need, coalesce((
      SELECT CASE m.kind
        WHEN ''hunt'' THEN count(*) FILTER (WHERE e.event_type = ''combat'' AND coalesce((e.payload ->> ''defeated'')::boolean, false))
                          + coalesce(sum(CASE WHEN e.event_type = ''expedition_end'' AND jsonb_typeof(e.payload -> ''wins'') = ''number'' THEN greatest(0, (e.payload ->> ''wins'')::int) END), 0)
        WHEN ''gather'' THEN count(*) FILTER (WHERE e.event_type = ''gather'')
        WHEN ''search'' THEN count(*) FILTER (WHERE e.event_type = ''explore'' AND e.payload ->> ''kind'' = ''field_search'')
        ELSE 0 END
      FROM public.world_events e
      WHERE e.actor_id = uid AND e.event_type IN (''combat'', ''expedition_end'', ''gather'', ''explore'')
        AND e.created_at >= (today::timestamp AT TIME ZONE ''Asia/Seoul'')
        AND (m.kind <> ''hunt'' OR m.target_region IS NULL OR m.target_region = e.payload ->> ''region_id'')), 0))
    WHERE m.owner_id = uid AND m.day = today AND m.kind IN (''hunt'', ''gather'', ''search'') AND m.claimed_at IS NULL;
  END IF;
  RETURN jsonb_build_object(''day'', today'
]);
