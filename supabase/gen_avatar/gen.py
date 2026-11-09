import json, pathlib

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
parts = (HERE / 'parts.json').read_text()
sql = (HERE / 'avatar.sql').read_text().replace('@PARTS@', parts.replace("'", "''"))
out = ROOT / 'supabase/migrations/20261110000000_world_1_2_0_avatar.sql'
out.write_text(sql)
print(out, len(sql))
