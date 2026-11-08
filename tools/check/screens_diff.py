import json, pathlib, sys
from PIL import Image, ImageChops

a, b = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
out = pathlib.Path(sys.argv[3]) if len(sys.argv) > 3 else b / 'diff'
out.mkdir(parents=True, exist_ok=True)
rows = []
for fa in sorted(a.glob('*.png')):
    fb = b / fa.name
    if not fb.exists():
        rows.append((fa.name, '수정 후 없음', None))
        continue
    ia, ib = Image.open(fa).convert('RGB'), Image.open(fb).convert('RGB')
    w, h = max(ia.width, ib.width), max(ia.height, ib.height)
    pa, pb = Image.new('RGB', (w, h), 'white'), Image.new('RGB', (w, h), 'white')
    pa.paste(ia); pb.paste(ib)
    d = ImageChops.difference(pa, pb).convert('L').point(lambda v: 255 if v > 24 else 0)
    ratio = sum(d.histogram()[255:]) / (w * h)
    side = Image.new('RGB', (w * 3 + 20, h), '#888')
    side.paste(pa, (0, 0)); side.paste(pb, (w + 10, 0)); side.paste(Image.merge('RGB', (d, Image.new('L', d.size), Image.new('L', d.size))), (2 * w + 20, 0))
    side.save(out / fa.name)
    rows.append((fa.name, f'{ia.width}x{ia.height} → {ib.width}x{ib.height}', round(ratio * 100, 2)))
for f in sorted(b.glob('*.png')):
    if not (a / f.name).exists():
        rows.append((f.name, '수정 전 없음', None))
for name, size, pct in rows:
    print(f'{name}\t{size}\t' + ('' if pct is None else f'바뀐 화소 {pct}%'))
(out / 'diff.json').write_text(json.dumps(rows, ensure_ascii=False, indent=1))
