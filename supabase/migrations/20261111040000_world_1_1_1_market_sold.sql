update public.world_patch_notes set body = body || E'\n- 거래소 「팔기」 칸 아래에 판매 내역을 접어 두었습니다. 최근 7일 동안 팔린 물품·수량·받은 돈(거래세를 뗀 금액)·때를 30건까지 보입니다. 산 사람은 보이지 않습니다.\n- 일지 › 의뢰: 받거나 거둔 조사원 의뢰는 「지난 의뢰」 칸에 접혀 들어갑니다.\n- 우수품 물품 정보에도 그 물품을 만드는 제작법·들어가는 제작법·내력이 나옵니다(우수품은 같은 제작법에서 품질이 높을 때 나옵니다). 제작 재료 칸의 「창고 n」에 창고에 둔 우수품도 셉니다.'
where note_id = '1.1.0' and position('거래소 「팔기」 칸 아래에 판매 내역' in body) = 0;

update public.world_app_meta set value = '20261111040000' where key = 'db_version';
