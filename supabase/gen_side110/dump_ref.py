import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
DSN = next((a.split('=', 1)[1] for a in sys.argv[1:] if a.startswith('--dsn=')), 'host=/var/tmp/yhpg port=5433 user=postgres dbname=yh')
OUT = next((a.split('=', 1)[1] for a in sys.argv[1:] if a.startswith('--out=')), os.path.join(HERE, 'ref.json'))

SQL = r"""select json_build_object(
 'npcs', (select json_object_agg(npc_name, npc_key) from public.world_quest_npcs where npc_key not like 'q:sx\_%'),
 'items', (select json_object_agg(item_name, item_id) from (select distinct on (item_name) item_name, item_id from public.world_item_catalog order by item_name, item_id) x),
 'spots', (select json_object_agg(region_id, items) from (select n.region_id, json_agg(distinct i order by i) items
            from public.world_gathering_spots sp join public.world_exploration_nodes n on n.node_id = sp.node_id, unnest(sp.loot_items) i
           where sp.active group by n.region_id) x),
 'fishing', (select json_agg(distinct region_id order by region_id) from public.world_fish_grounds),
 'recipes', (select json_object_agg(output_item, json_build_array(recipe_id, minimum_level, craft_field)) from (select distinct on (output_item) * from public.world_crafting_recipes order by output_item, minimum_level, recipe_id) x),
 'regions', (select json_object_agg(region_name, json_build_array(region_id, min_level, is_safe_zone)) from public.world_map_regions where active),
 'monsters', (select json_object_agg(monster_name, l) from (select monster_name, json_agg(json_build_array(monster_id, region_id, min_level, role) order by min_level, monster_id) l from public.world_region_monsters group by monster_name) x),
 'quests', (select json_object_agg(quest_id, json_build_array(title, min_level, sort)) from public.world_quests))"""

out = subprocess.run(['psql', DSN, '-At', '-c', SQL], check=True, capture_output=True, text=True).stdout
ref = json.loads(out)
json.dump(ref, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=0, sort_keys=True)
print(OUT, {k: len(v) for k, v in ref.items()})
