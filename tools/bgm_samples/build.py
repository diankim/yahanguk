# 악기 조각 묶기: gleitz/midi-js-soundfonts(FluidR3 GM, CC BY 3.0)의 악기 .js에서 음 몇 개를 꺼내
# 3.2초 칸으로 이어 붙여 assets/audio/<이름>.mp3(32kHz·모노·56kbps)로 만든다. sound.js INS의 notes와 같은 순서여야 한다.
# 사용: python3 tools/bgm_samples/build.py <soundfont .js> <출력 이름> <MIDI 음 번호들(쉼표)>
#   예) python3 tools/bgm_samples/build.py sf/acoustic_grand_piano.js piano 33,37,41,45,49,53,57,61,65,69,73,77,81,85
import base64, os, re, subprocess, sys, tempfile
src, name, notes = sys.argv[1], sys.argv[2], [int(x) for x in sys.argv[3].split(',')]
NAMES = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B']
txt = open(src).read()
tmp = tempfile.mkdtemp()
parts = []
for i, m in enumerate(notes):
    key = NAMES[m % 12] + str(m // 12 - 1)
    mt = re.search(r'"' + key + r'":\s*"data:audio/(\w+);base64,([^"]+)"', txt)
    if not mt: sys.exit('no note ' + key)
    raw = os.path.join(tmp, f'{i}.{mt.group(1)}'); open(raw, 'wb').write(base64.b64decode(mt.group(2)))
    wav = os.path.join(tmp, f'{i}.wav')
    # 3.2초로 자르고(모자라면 무음으로 채움) 끝 0.25초는 잦아들게
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', raw, '-ac', '1', '-ar', '32000', '-af', 'apad=whole_dur=3.2,atrim=0:3.2,afade=t=out:st=2.95:d=0.25', wav], check=True)
    parts.append(wav)
lst = os.path.join(tmp, 'list.txt'); open(lst, 'w').write(''.join(f"file '{p}'\n" for p in parts))
out = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'audio', name + '.mp3')
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', lst, '-ac', '1', '-ar', '32000', '-b:a', '56k', out], check=True)
print(out, os.path.getsize(out))
