update public.world_patch_notes set body = replace(body, '다른 무기(같은 단계 이하)로', '같은 단계거나 그 밑 단계의 다른 무기로') where note_id = '3.0.0' and body like '%다른 무기(같은 단계 이하)로%';
