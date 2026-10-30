// 사용: 저장소 뿌리에서 python3 -m http.server 8765 --bind 127.0.0.1 을 띄운 뒤
//   node tools/cutscene_music/render.js  → assets/audio/cutscene.mp3 (ffmpeg 필요)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
(async () => {
  const b = await chromium.launch({ args: ['--autoplay-policy=no-user-gesture-required'] });
  const p = await b.newPage();
  await p.goto('http://127.0.0.1:8765/maintenance.html', { waitUntil: 'domcontentloaded' }).catch(() => {});
  await p.addScriptTag({ url: 'http://127.0.0.1:8765/tools/cutscene_music/compose.js' });
  const r = await p.evaluate(() => window.composeCutscene(32000));
  await b.close();
  const tmp = path.join(require('os').tmpdir(), 'cutscene.wav');
  fs.writeFileSync(tmp, Buffer.from(r.wav, 'base64'));
  const out = path.join(__dirname, '../../assets/audio/cutscene.mp3');
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', tmp, '-b:a', '112k', out]);
  console.log(JSON.stringify({ outro: r.outro, resolve: r.resolve, end: r.end, dur: r.dur, bytes: fs.statSync(out).size }));
})();
