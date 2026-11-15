import pathlib

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
parts = (HERE / 'parts.json').read_text()
sql = (HERE / 'face_hair.sql').read_text().replace('@PARTS@', parts.replace("'", "''"))
out = ROOT / 'supabase/migrations/20261118060000_world_2_2_2_face_hair.sql'
out.write_text(sql)
print(out, len(sql))
