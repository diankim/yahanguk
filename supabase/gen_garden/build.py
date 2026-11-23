import os
H = os.path.dirname(os.path.abspath(__file__))
M = os.path.join(H, '..', 'migrations', '20261127000000_world_3_8_1.sql')
s = open(M).read()
a = s.index('create or replace function public.world_garden_rules()')
b = s.index('\nupdate public.world_patch_notes')
s = s[:a] + open(os.path.join(H, 'engine.sql')).read() + '\n' + open(os.path.join(H, '..', 'gen_bondemote', 'lines.sql')).read() + s[b:]
open(M, 'w').write(s)
print('ok')
