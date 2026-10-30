// 사용: 저장소 뿌리에서 python3 -m http.server 8765 --bind 127.0.0.1 을 띄운 뒤 node tools/bgm_preview/render.js <출력 폴더>
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const OUT = process.argv[2] || 'bgm_out';
const LIST = (process.argv[3] || 'capital,east,north,south,frontier,underworld,heavenward,abyss,gwiheo').split(',');
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const b = await chromium.launch(), info = {};
  for (const t of LIST) for (const battle of [false, true]) {
    const p = await b.newPage();
    await p.goto('http://127.0.0.1:8765/maintenance.html', { waitUntil: 'domcontentloaded' }).catch(() => {});
    await p.addScriptTag({ url: 'http://127.0.0.1:8765/tools/bgm_preview/harness.js' });
    const r = await p.evaluate(([t, bt]) => window.renderRegion(t, bt, bt ? 40 : 95), [t, battle]);
    await p.close();
    const name = `${t}${battle ? '_battle' : ''}`, wav = path.join(OUT, name + '.wav');
    fs.writeFileSync(wav, Buffer.from(r.wav, 'base64'));
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', wav, '-b:a', '80k', path.join(OUT, name + '.mp3')]); fs.unlinkSync(wav);
    delete r.wav; info[name] = r; console.log(name, JSON.stringify(r));
  }
  fs.writeFileSync(path.join(OUT, 'info.json'), JSON.stringify(info, null, 1));
  await b.close();
})();
