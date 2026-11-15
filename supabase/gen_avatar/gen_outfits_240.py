import pathlib

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
parts = (HERE / 'parts.json').read_text()
sql = (HERE / 'outfits_240.sql').read_text().replace('@PARTS@', parts.replace("'", "''"))
out = ROOT / 'supabase/migrations/20261118180000_world_2_4_0_outfits.sql'
out.write_text(sql)
print(out, len(sql))
