import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art
import gen

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'supabase', 'gen_part2', 'ports', 'lantern_harbor.html')

data = {
    'shapes': [{'key': k, 'name': n, 'spr': gen.outline(gen.rows(src))} for k, n, src in gen.SHAPES],
    'colors': [{'key': k, 'name': v['name'], 'pal': {c: v[c] for c in 'amlhrR'}} for k, v in art.COLORS.items()],
    'fixed': art.FIXED,
}
tpl = open(os.path.join(HERE, 'harbor.tpl.html'), encoding='utf-8').read()
html = tpl.replace('/*DATA*/', 'const LD = ' + json.dumps(data, ensure_ascii=False, separators=(',', ':')) + ';')
open(OUT, 'w', encoding='utf-8').write(html)
print(os.path.normpath(OUT))
