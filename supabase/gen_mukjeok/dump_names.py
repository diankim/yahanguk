import argparse
import json
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
SQL = """select json_build_object(
 'regions', (select json_agg(region_name) from world_map_regions),
 'region_ids', (select json_agg(region_id) from world_map_regions),
 'nodes', (select json_agg(distinct node_name) from world_exploration_nodes),
 'spots', (select json_agg(distinct spot_name) from world_gathering_spots),
 'monsters', (select json_agg(distinct monster_name) from world_region_monsters),
 'monster_ids', (select json_agg(monster_id) from world_region_monsters),
 'items', (select json_agg(distinct item_name) from world_item_catalog),
 'item_ids', (select json_agg(item_id) from world_item_catalog),
 'grounds', (select json_agg(distinct ground_name) from world_expedition_grounds),
 'fish_grounds', (select json_agg(distinct ground_name) from world_fish_grounds),
 'sites', (select json_agg(distinct site_name) from world_region_sites),
 'recipes', (select json_agg(recipe_id) from world_crafting_recipes),
 'statuses', (select json_agg(status_key) from world_status_catalog),
 'status_names', (select json_agg(status_name) from world_status_catalog),
 'titles', (select json_agg(title_name) from world_title_catalog),
 'title_keys', (select json_agg(title_key) from world_title_catalog),
 'cosmetics', (select json_agg(cosmetic_name) from world_cosmetic_catalog),
 'npcs', (select json_agg(npc_name) from world_quest_npcs))"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dsn', default='-h /var/tmp/yhpg -p 5499 -U postgres -d mk_base')
    a = ap.parse_args()
    cmd = ['psql', '-X', '-At', '-v', 'ON_ERROR_STOP=1'] + (a.dsn.split() if not a.dsn.startswith('postgres') else [a.dsn]) + ['-c', SQL]
    out = subprocess.check_output(cmd, text=True).strip().splitlines()[-1]
    d = {k: sorted(set(v or [])) for k, v in json.loads(out).items()}
    os.makedirs(os.path.join(HERE, 'ref'), exist_ok=True)
    with open(os.path.join(HERE, 'ref', 'existing_names.json'), 'w') as f:
        json.dump(d, f, ensure_ascii=False, indent=0)
    print({k: len(v) for k, v in d.items()})


if __name__ == '__main__':
    main()
