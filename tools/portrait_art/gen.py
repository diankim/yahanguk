import os, re, json, sys
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(ROOT, 'tools', 'portrait_art', 'src')
IMG = os.path.join(ROOT, 'assets', 'img', 'portrait')
BIOS = os.path.join(ROOT, 'supabase', 'gen_portrait', 'bios.md')
OUT_JS = os.path.join(ROOT, 'assets', 'js', 'housing', 'portraits.js')
OUT_BOOK = os.path.join(ROOT, 'assets', 'js', 'portrait_book.js')
OUT_SQL = os.path.join(ROOT, 'supabase', 'gen_portrait', 'items.sql')

CAST = [
    ('hanseol', '감찰관 한설', 'mq_red_seal'),
    ('mogaram', '기록관 모가람', 'mq_red_seal'),
    ('yeonseohui', '서기관 연서희', 'mq_red_seal'),
    ('nodeul', '뱃사공 노들 영감', 'mq_drowned_ledger'),
    ('danbi', '주홍 무녀 단비', 'mq_red_moon_oath'),
    ('yeounbi', '호송대장 여운비', 'mq_red_moon_oath'),
    ('sawol', '무녀 사월', 'mq_red_moon_oath'),
    ('seokjinak', '맹주 석진악', 'mq_frost_seal'),
    ('baekmu', '말뚝지기 백무', 'mq_frost_seal'),
    ('wolhwa', '교주 월화', 'mq_eclipse_gate'),
    ('jinsorang', '도방 진소랑', 'mq_sunken_lantern'),
    ('gaon', '늙은 거북 가온', 'mq_sunken_lantern'),
    ('jangmuhyeon', '노장 장무현', 'mq_ash_sea'),
    ('galmae', '정찰대장 갈매', 'mq_ash_sea'),
    ('dohwa', '등대지기 도화', 'mq_ash_sea'),
    ('baekunseo', '도제조 백운서', 'mq_lamp_shadow'),
    ('yundohan', '출납관 윤도한', 'mq_nine_gates'),
    ('hahujeong', '태사령 하후정', 'mq_nine_gates'),
    ('guseul', '장부지기 구슬', 'mq_nameless_bell'),
    ('samagyeom', '대호법 사마겸', 'mq_eclipse_gate'),
    ('maehyang', '장부 행수 매향', 'mdq_4'),
    ('cheongpa', '잠수꾼 청파', 'mdq_4'),
    ('seoiyeon', '수석 관측관 서이연', 'mq_nine_gates'),
    ('seoharam', '관측관 서하람', 'mdq_4'),
    ('mumyeong', '회주 무명', 'mq_frost_seal'),
    ('soi', '무녀 소이', 'mq_frost_seal'),
    ('kangducheol', '교관 강두철', 'mq_red_seal'),
    ('munsu', '서리 문수', 'mdq_1'),
    ('munseojin', '기밀 사관 문서진', 'mq_nine_gates'),
    ('yeoul', '길잡이 여울', 'gq_1'),
    ('mukho', '촌장 묵호', 'gq_1'),
    ('dani', '단이', 'gq_1'),
    ('hisu', '서리 희수', 'mkq_1'),
    ('daon', '다온', 'mkq_1'),
    ('wolha', '이름 거둠꾼 월하', 'mkq_1'),
    ('seoyul', '서율', 'mkq_5'),
    ('seoha', '서하', 'mkq_5'),
    ('hyegak', '수좌 혜각', 'mdq_7'),
    ('yeoseotjjae', '채무 추적자 여섯째', 'mdq_8'),
    ('gwakduchil', '곽두칠', 'mdq_15'),
    ('gyeonghyeon', '정리관 경현', 'mdq_17'),
]
W, H = 24, 32
ILL_W, ILL_H = 768, 1024
COLORS = 48
ALPHA = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_'
FRAME = {'w': 1.75, 'h': 38, 'paper': [.125, 3]}
ITEM_DESC = '별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.'


def bbox(im):
    px = im.convert('RGB'); w, h = px.size; bg = px.getpixel((5, 5))
    small = px.resize((w // 4, h // 4), Image.NEAREST); L = small.load(); sw, sh = small.size
    xs, ys = [], []
    for y in range(sh):
        for x in range(sw):
            if sum(abs(a - b) for a, b in zip(L[x, y], bg)) > 40: xs.append(x); ys.append(y)
    return min(xs) * 4, min(ys) * 4, max(xs) * 4 + 4, max(ys) * 4 + 4


def crop34_content(im):
    im = im.convert('RGB'); bg = im.getpixel((5, 5))
    x0, y0, x1, y1 = bbox(im); hh = y1 - y0; top = max(0, y0 - int(hh * 0.03)); hh = y1 - top; ww = int(hh * 0.75); cx = (x0 + x1) // 2; l = cx - ww // 2
    c = Image.new('RGB', (ww, hh), bg); c.paste(im.crop((max(0, l), top, min(im.width, l + ww), y1)), (max(0, -l), 0)); return c


def crop34_full(im):
    im = im.convert('RGB'); w, h = im.size
    if abs(w * 4 - h * 3) <= 4: return im
    if w * 4 > h * 3:
        nw = h * 3 // 4; l = (w - nw) // 2; return im.crop((l, 0, l + nw, h))
    nh = w * 4 // 3; return im.crop((0, 0, w, nh))


def bios():
    out = {}; cur = None
    for line in open(BIOS, encoding='utf-8'):
        m = re.match(r'^## (.+?) — (.+?)\s*$', line)
        if m: cur = m.group(1); out[cur] = {'title': m.group(2), 'bio': ''}; continue
        if line.startswith('#'): cur = None; continue
        if cur and line.strip(): out[cur]['bio'] = (out[cur]['bio'] + ' ' + line.strip()).strip()
    return out


def main():
    errors = []
    B = bios()
    os.makedirs(IMG, exist_ok=True)
    js, book, rows, cast = [], [], [], []
    keys = set()
    for k, name, q in CAST:
        if k in keys: errors.append(f'{k} 겹침')
        keys.add(k)
        if name not in B: errors.append(f'{name} 소개 없음'); continue
        for part in ('dot', 'ill'):
            if not os.path.exists(os.path.join(SRC, f'{k}_{part}.webp')): errors.append(f'{k}_{part}.webp 없음')
        if errors: continue
        dot = crop34_content(Image.open(os.path.join(SRC, f'{k}_dot.webp'))).resize((W, H), Image.BOX)
        q8 = dot.quantize(COLORS, method=Image.MEDIANCUT)
        pal = q8.getpalette()[:COLORS * 3]
        idx = list(q8.getdata())
        used = sorted(set(idx))
        remap = {u: i for i, u in enumerate(used)}
        pal_hex = ['%02x%02x%02x' % tuple(pal[u * 3:u * 3 + 3]) for u in used]
        px = ''.join(ALPHA[remap[i]] for i in idx)
        js.append(f"  {k}: {{ n: {json.dumps(name, ensure_ascii=False)}, p: '{'.'.join(pal_hex)}', x: '{px}' }},")
        ill = crop34_full(Image.open(os.path.join(SRC, f'{k}_ill.webp'))).resize((ILL_W, ILL_H), Image.LANCZOS)
        ill.save(os.path.join(IMG, f'{k}.webp'), quality=82, method=6)
        b = B[name]
        book.append(f"  {k}: {{ n: {json.dumps(name, ensure_ascii=False)}, t: {json.dumps(b['title'], ensure_ascii=False)}, b: {json.dumps(b['bio'], ensure_ascii=False)} }},")
        traits = {'hk': f'portrait_{k}', 'kind': 'wall', 'wall': 'deco', 'ww': FRAME['w'], 'wh': FRAME['h'], 'cat': '초상', 'grade': 4, 'portrait': k}
        T = lambda s: "'" + s.replace("'", "''") + "'"
        rows.append(f"({T('hf_portrait_' + k)}, {T('초상 · ' + name)}, 'furniture', 4, {T('별채 가구 · 초상. ' + name + '의 초상. ' + ITEM_DESC)}, false, false, 0, 1, {T(json.dumps(traits, ensure_ascii=False))}::jsonb)")
        cast.append({'k': k, 'q': q})
    if errors:
        print('\n'.join(errors)); sys.exit(1)
    open(OUT_JS, 'w', encoding='utf-8').write(
        "export const PORTRAIT_FRAME = " + json.dumps(FRAME) + ";\n"
        "export const PORTRAITS = {\n" + '\n'.join(js) + "\n};\n"
        "const ALPHA = '" + ALPHA + "';\n"
        "const cache = {};\n"
        "export function portraitPic(k) {\n"
        "  if (cache[k]) return cache[k];\n"
        "  const d = PORTRAITS[k]; if (!d) return null;\n"
        "  const pal = d.p.split('.').map(h => '#' + h);\n"
        "  return cache[k] = { w: " + str(W) + ", h: " + str(H) + ", rgb: [...d.x].map(c => pal[ALPHA.indexOf(c)]) };\n"
        "}\n")
    open(OUT_BOOK, 'w', encoding='utf-8').write("export const PORTRAIT_BOOK = {\n" + '\n'.join(book) + "\n};\nexport const portraitImg = k => `assets/img/portrait/${k}.webp`;\n")
    rules = {'item': 'hf_portrait_', 'cast': cast}
    open(OUT_SQL, 'w', encoding='utf-8').write(
        "insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, equipment_traits) values\n"
        + ',\n'.join(rows) +
        "\non conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,\n"
        "  stackable = excluded.stackable, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size, equipment_traits = excluded.equipment_traits;\n\n"
        "create or replace function public.world_portrait_rules() returns jsonb language sql immutable set search_path = pg_catalog, public as $f$ select "
        + "'" + json.dumps(rules, ensure_ascii=False).replace("'", "''") + "'::jsonb $f$;\n")
    print(len(cast), 'portraits', sum(os.path.getsize(os.path.join(IMG, f'{c["k"]}.webp')) for c in cast) // 1024, 'KB illust', os.path.getsize(OUT_JS) // 1024, 'KB dots')


main()
