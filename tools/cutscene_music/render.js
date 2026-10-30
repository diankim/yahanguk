// 사용: 저장소 뿌리에서 python3 -m http.server 8765 --bind 127.0.0.1 을 띄운 뒤
//   node tools/cutscene_music/render.js [rollback|morning]  → assets/audio/cutscene.mp3 · cutscene_morning.mp3 (ffmpeg 필요)
// 찍힌 시각(resolve·outro·loopStart·loopEnd)을 assets/js/cutscene.js의 MUSIC에 옮긴다.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
(async () => {
  const kinds = process.argv[2] ? [process.argv[2]] : ['rollback', 'morning'];
  const b = await chromium.launch();
  for (const kind of kinds) {
    const p = await b.newPage();
    await p.goto('http://127.0.0.1:8765/maintenance.html', { waitUntil: 'domcontentloaded' }).catch(() => {});
    await p.addScriptTag({ url: 'http://127.0.0.1:8765/tools/cutscene_music/compose.js' });
    const r = await p.evaluate(k => window.composeCutscene(k, 32000), kind);
    await p.close();
    const tmp = path.join(require('os').tmpdir(), `cutscene_${kind}.wav`);
    fs.writeFileSync(tmp, Buffer.from(r.wav, 'base64'));
    const out = path.join(__dirname, '../../assets/audio', kind === 'morning' ? 'cutscene_morning.mp3' : 'cutscene.mp3');
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', tmp, '-b:a', '112k', out]);
    delete r.wav; console.log(kind, JSON.stringify({ ...r, bytes: fs.statSync(out).size }));
  }
  await b.close();
})();
