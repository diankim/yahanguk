update public.world_patch_notes set created_at = created_at + case note_id when '2.1.0' then interval '1 second' else interval '2 seconds' end
 where note_id in ('2.1.0', '2.2.0') and created_at = (select created_at from public.world_patch_notes where note_id = '2.0.0');
