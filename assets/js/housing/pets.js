// 꼬마 동무(7.x 별채 펫) 도트 자료. 그림은 오른쪽을 보고, 화면이 뒤집어 왼쪽을 그린다(drawSprite flip).
// 프레임: idle 가만히 · blink 눈 감기 · step 걷기(idle과 번갈아) · sleep 자기(폭은 같고 키는 낮을 수 있음).
// pal: 글자 → '#rrggbb'(k는 테두리 #1a120e), '.'은 빈칸. 화면이 render.js P()로 바꿔 쓴다.
// 등급 grade 1 범품 · 2 양품 · 3 진품 · 4 명품 · 5 신품, kind는 요괴 13갈래, likes는 좋아하는 별미.
// 자동 생성: tools/pet_art/gen.py(안쪽 그림 + 자동 테두리). 직접 고쳐도 된다.

export const PETS = {
  nureong_puppy: {
    name: "누렁 강아지",
    grade: 1,
    kind: "ward",
    desc: "마을 어귀마다 한 마리씩은 있는 누런 강아지입니다. 낯선 기척이 나면 제일 먼저 짖어 알려 줍니다.",
    likes: "treat_meat",
    baby: {
      pal: { a: "#dba54a", b: "#a8722a", c: "#f5e2b0", n: "#3a2418", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["......kkkkk...", "....kkaaaaakk.", "...kbaaaaaaabk", ".k.kbaieaieabk", "kbkkbbeeaeebbk", "kbkkkpacncapk.", ".kbaaaaacccak.", ".kaaaaaaaaaaak", ".kaaaaaaaaaaak", ".kaakakkkakaak", "..kk.k...k.kk."],
      blink: ["......kkkkk...", "....kkaaaaakk.", "...kbaaaaaaabk", ".k.kbaaaaaaabk", "kbkkbbkkakkbbk", "kbkkkpacncapk.", ".kbaaaaacccak.", ".kaaaaaaaaaaak", ".kaaaaaaaaaaak", ".kaakakkkakaak", "..kk.k...k.kk."],
      step: ["......kkkkk...", "....kkaaaaakk.", "...kbaaaaaaabk", ".k.kbaieaieabk", "kbkkbbeeaeebbk", "kbkkkpacncapk.", ".kbaaaaacccak.", ".kaaaaaaaaaaak", ".kaaaaaaaaaaak", "..kaakakaakak.", "...kk.k.kk.k.."],
      sleep: ["......kkkkk...", "....kkaaaaakk.", "...kbaaaaaaabk", ".kkkbakkakkabk", "kbaabpacncapbk", ".kaaaaaaaaaaak", ".kaaaaaaaaaak.", "..kkkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#dba54a", b: "#a8722a", c: "#f5e2b0", n: "#3a2418", d: "#c0392b", y: "#f2c94c", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: [".........kkkkk...", ".......kkaaaaakk.", "......kbaaaaaaabk", "......kbaieaieabk", ".k....kbbeeaeebbk", "kbk....kpacncapk.", ".kbk....kacccak..", ".kbkkkkkdddydddk.", ".kaaaaaaaacccaak.", ".kabbaaaaaaaaaak.", ".kaakaakkkkaakaak", ".kaakaak..kaakaak", "..kk.kk....kk.kk."],
      blink: [".........kkkkk...", ".......kkaaaaakk.", "......kbaaaaaaabk", "......kbaaaaaaabk", ".k....kbbkkakkbbk", "kbk....kpacncapk.", ".kbk....kacccak..", ".kbkkkkkdddydddk.", ".kaaaaaaaacccaak.", ".kabbaaaaaaaaaak.", ".kaakaakkkkaakaak", ".kaakaak..kaakaak", "..kk.kk....kk.kk."],
      step: [".........kkkkk...", ".......kkaaaaakk.", "......kbaaaaaaabk", "......kbaieaieabk", ".k....kbbeeaeebbk", "kbk....kpacncapk.", ".kbk....kacccak..", ".kbkkkkkdddydddk.", ".kaaaaaaaacccaak.", ".kabbaaaaaaaaaak.", ".kaakkaakkaakaak.", "kaak..kaakaakkaak", ".kk....kk.kk..kk."],
      sleep: [".........kkkkk...", ".......kkaaaaakk.", "......kbaaaaaaabk", ".kkkkkkbakkakkabk", "kbaaaaabpacncapbk", ".kaaaaaaadddydddk", "kaabbaaaaaaaaaaak", ".kaaaaaaaaaaaaak.", "..kkkkkkkkkkkkk.."]
    }
  },
  spotted_cat: {
    name: "얼룩 고양이",
    grade: 1,
    kind: "shadow",
    desc: "세 빛깔 얼룩이 박힌 고양이입니다. 볕 드는 자리를 귀신같이 찾아내 낮잠을 잡니다.",
    likes: "treat_fish",
    baby: {
      pal: { a: "#f6f1e6", o: "#e8964a", d: "#4a3f3a", n: "#e07a86", e: "#2a1a14", i: "#8a7a74", p: "#f3a0a0", k: "#1a120e" },
      idle: ["......k...k...", ".....kok.kak..", "....koookaaak.", ".k..kooaaaaak.", "kdk.kaieaieak.", "kdk.kaeeaeeak.", ".kdkkpaanaapk.", ".kdaaaoooaaak.", ".kaaaaooaaaak.", ".kaakakkakaak.", "..kk.k..k.kk.."],
      blink: ["......k...k...", ".....kok.kak..", "....koookaaak.", ".k..kooaaaaak.", "kdk.kaaaaaaak.", "kdk.kakkakkak.", ".kdkkpaanaapk.", ".kdaaaoooaaak.", ".kaaaaooaaaak.", ".kaakakkakaak.", "..kk.k..k.kk.."],
      step: ["......k...k...", ".....kok.kak..", "....koookaaak.", ".k..kooaaaaak.", "kdk.kaieaieak.", "kdk.kaeeaeeak.", ".kdkkpaanaapk.", ".kdaaaoooaaak.", ".kaaaaooaaaak.", "..kaakakakaak.", "...kk.k.k.kk.."],
      sleep: [".......k...k..", "......kok.kak.", ".....koookaaak", "..kkkkooaaaaak", ".kaaaaakkakkak", "kaooaapaanaapk", "kaddddddddaak.", ".kkkkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#f6f1e6", o: "#e8964a", d: "#4a3f3a", n: "#e07a86", e: "#2a1a14", i: "#8a7a74", p: "#f3a0a0", k: "#1a120e" },
      idle: [".........k...k...", "........kok.kak..", ".......koookaaak.", "..k....kooaaaaak.", ".kdk...kaieaieak.", "kdk....kaeeaeeak.", "kdk....kpaanaapk.", ".kdkkkkkkaaaaak..", "..kdaaaaaaaaaaak.", "..kaooooaaaddaak.", "..kaaooaaaaaaaak.", "..kaakaakkkaakak.", "..kaakaak.kaakak.", "...kk.kk...kk.k.."],
      blink: [".........k...k...", "........kok.kak..", ".......koookaaak.", "..k....kooaaaaak.", ".kdk...kaaaaaaak.", "kdk....kakkakkak.", "kdk....kpaanaapk.", ".kdkkkkkkaaaaak..", "..kdaaaaaaaaaaak.", "..kaooooaaaddaak.", "..kaaooaaaaaaaak.", "..kaakaakkkaakak.", "..kaakaak.kaakak.", "...kk.kk...kk.k.."],
      step: [".........k...k...", "........kok.kak..", ".......koookaaak.", "..k....kooaaaaak.", ".kdk...kaieaieak.", "kdk....kaeeaeeak.", "kdk....kpaanaapk.", ".kdkkkkkkaaaaak..", "..kdaaaaaaaaaaak.", "..kaooooaaaddaak.", "..kaaooaaaaaaaak.", "...kaakaakkaakak.", "..kaak.kaakakkak.", "...kk...kk.k..k.."],
      sleep: ["..........k...k..", ".........kok.kak.", "........koookaaak", "..kkkkkkkooaaaaak", ".kaaaaaaaakkakkak", "kaaoooaaapaanaapk", "kaaooaaaaaddaaaak", ".kddddddddddddkk.", "..kkkkkkkkkkkk..."]
    }
  },
  magpie: {
    name: "까치",
    grade: 1,
    kind: "bird",
    desc: "반가운 손님이 온다고 먼저 울어 주는 새입니다. 반짝이는 것을 보면 꼭 한 번 쪼아 봅니다.",
    likes: "treat_meat",
    baby: {
      pal: { a: "#34364a", b: "#2f4f96", w: "#f4f2ec", n: "#4a4a58", h: "#6a6c88", e: "#0c0806", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: [".......kkk....", "......kaaak...", ".....kaaaaak..", "....kaaaaieak.", ".kk.kaaaaeennk", "kbbkkbaaaapak.", ".kbbbbbbwwwwk.", "..kbbbbbwwwwk.", "...kkbbwwwwk..", ".....knknkk...", "......k.k....."],
      blink: [".......kkk....", "......kaaak...", ".....kaaaaak..", "....kaaaaaaak.", ".kk.kaaaahhnnk", "kbbkkbaaaapak.", ".kbbbbbbwwwwk.", "..kbbbbbwwwwk.", "...kkbbwwwwk..", ".....knknkk...", "......k.k....."],
      step: [".......kkk....", "......kaaak...", ".....kaaaaak..", "....kaaaaieak.", ".kk.kaaaaeennk", "kbbkkbaaaapak.", ".kbbbbbbwwwwk.", "..kbbbbbwwwwk.", "...kbbbwwwwk..", "....kkknnkk...", ".......kk....."],
      sleep: ["........kkk...", ".......kaaak..", "......kaaaaak.", ".kk..kaaahhank", "kbbkkbaaaapak.", ".kbbbbbbwwwwk.", "..kbbbbwwwwwk.", "...kkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#34364a", b: "#2f4f96", w: "#f4f2ec", n: "#4a4a58", h: "#6a6c88", e: "#0c0806", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["..........kkk....", ".........kaaak...", "........kaaaaak..", "........kaaaieak.", "........kaaaeennk", ".......kaaaaapkk.", ".kk..kkbwwbbawwk.", "kbbkkbbbwwbbbwwwk", ".kbbbbbbbbbbwwwk.", "..kkbbbbbbbwwwk..", "....kkkkbbwwwk...", "........knkknk...", ".......knnknnk...", "........kk.kk...."],
      blink: ["..........kkk....", ".........kaaak...", "........kaaaaak..", "........kaaaaaak.", "........kaaahhnnk", ".......kaaaaapkk.", ".kk..kkbwwbbawwk.", "kbbkkbbbwwbbbwwwk", ".kbbbbbbbbbbwwwk.", "..kkbbbbbbbwwwk..", "....kkkkbbwwwk...", "........knkknk...", ".......knnknnk...", "........kk.kk...."],
      step: ["..........kkk....", ".........kaaak...", "........kaaaaak..", "........kaaaieak.", "........kaaaeennk", ".......kaaaaapkk.", ".kk..kkbwwbbawwk.", "kbbkkbbbwwbbbwwwk", ".kbbbbbbbbbbwwwk.", "..kkbbbbbbbwwwk..", "....kkkkbbwwwk...", "........kknnk....", "........knnknk...", ".........kk.k...."],
      sleep: ["..........kkk....", ".........kaaak...", "........kaaaaakk.", "........kaaahhank", ".......kaaaaapkk.", ".kk..kkbwwbbawwk.", "kbbkkbbbwwbbbwwwk", ".kbbbbbbbbbbwwwk.", "..kkbbbbbbbwwwk..", "....kkkkkkkkkk..."]
    }
  },
  sparrow: {
    name: "참새",
    grade: 1,
    kind: "bird",
    desc: "처마 밑에서 짹짹거리며 낟알을 줍는 작은 새입니다. 겁이 많아 쓰다듬으면 몸을 동그랗게 부풀립니다.",
    likes: "treat_rice",
    baby: {
      pal: { a: "#8a5634", b: "#c08a5a", d: "#3a2a22", c: "#f2ead8", n: "#4a3a30", y: "#d09a6a", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: [".......kkkk...", "......kaaaak..", ".....kaaaaaak.", "....kaaacieck.", ".kk.kaaaceecnk", "kbbkaaaaccpdk.", ".kbdbdbbcccck.", "..kbbdbbcccck.", "...kkbbcccck..", ".....kykykk...", "......k.k....."],
      blink: [".......kkkk...", "......kaaaak..", ".....kaaaaaak.", "....kaaacccck.", ".kk.kaaacddcnk", "kbbkaaaaccpdk.", ".kbdbdbbcccck.", "..kbbdbbcccck.", "...kkbbcccck..", ".....kykykk...", "......k.k....."],
      step: [".......kkkk...", "......kaaaak..", ".....kaaaaaak.", "....kaaacieck.", ".kk.kaaaceecnk", "kbbkaaaaccpdk.", ".kbdbdbbcccck.", "..kbbdbbcccck.", "...kkbbcccck..", ".....kkyykk...", ".......kk....."],
      sleep: [".......kkkk...", "......kaaaak..", ".....kaaaaaak.", ".kk.kaaacddcnk", "kbbkaaaaccpdk.", ".kbdbdbbcccck.", "..kbbbbcccck..", "...kkkkkkkk..."]
    },
    adult: {
      pal: { a: "#8a5634", b: "#c08a5a", d: "#3a2a22", c: "#f2ead8", n: "#4a3a30", y: "#d09a6a", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["..........kkkk...", ".........kaaaak..", "........kaaaaaak.", ".......kaaacieck.", ".......kaaaceecnk", ".kk...kaaaaaccpdk", "kbbkkkbdbdbbcccck", ".kbbbbbdbdbbcccck", "..kkbbdbdbbbccck.", "....kkbbbbbccck..", "......kkykkykk...", "......kyykyyk....", ".......kk.kk....."],
      blink: ["..........kkkk...", ".........kaaaak..", "........kaaaaaak.", ".......kaaacccck.", ".......kaaacddcnk", ".kk...kaaaaaccpdk", "kbbkkkbdbdbbcccck", ".kbbbbbdbdbbcccck", "..kkbbdbdbbbccck.", "....kkbbbbbccck..", "......kkykkykk...", "......kyykyyk....", ".......kk.kk....."],
      step: ["..........kkkk...", ".........kaaaak..", "........kaaaaaak.", ".......kaaacieck.", ".......kaaaceecnk", ".kk...kaaaaaccpdk", "kbbkkkbdbdbbcccck", ".kbbbbbdbdbbcccck", "..kkbbdbdbbbccck.", "....kkbbbbbccck..", "......kkkyykkk...", ".......kyykyk....", "........kk.k....."],
      sleep: ["..........kkkk...", ".........kaaaak..", "........kaaaaaak.", ".......kaaacddck.", ".......kaaaccccnk", ".kk...kaaaaaccpdk", "kbbkkkbdbdbbcccck", ".kbbbbbdbdbbcccck", "..kkbbbbbbbbccck.", "....kkkkkkkkkkk.."]
    }
  },
  squirrel: {
    name: "다람쥐",
    grade: 1,
    kind: "wood",
    desc: "볼주머니가 터지도록 먹이를 모아 두는 다람쥐입니다. 숨겨 둔 곳은 금세 잊어버립니다.",
    likes: "treat_honey",
    baby: {
      pal: { a: "#c0753a", b: "#7a4420", c: "#f2dcb0", f: "#d88a48", t: "#f0b070", n: "#5a3020", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["..kkk..k...k..", ".ktttkkakkkak.", "ktffftkaaaaak.", "ktfbffaieaieak", "ktfbfkaeeaeeak", ".ktfbfcpanapck", "..ktfaaacccck.", "...ktfabaccck.", "....kaaaaccck.", "....kaakakaak.", ".....kk.k.kk.."],
      blink: ["..kkk..k...k..", ".ktttkkakkkak.", "ktffftkaaaaak.", "ktfbffaaaaaaak", "ktfbfkakkakkak", ".ktfbfcpanapck", "..ktfaaacccck.", "...ktfabaccck.", "....kaaaaccck.", "....kaakakaak.", ".....kk.k.kk.."],
      step: ["..kkk..k...k..", ".ktttkkakkkak.", "ktffftkaaaaak.", "ktfbffaieaieak", "ktfbfkaeeaeeak", ".ktfbfcpanapck", "..ktfaaacccck.", "...ktfabaccck.", "....kaaaaccck.", ".....kaakaak..", "......kk.kk..."],
      sleep: ["..kkk..k...k..", ".ktttkkakkkak.", "ktffftkaaaaak.", "ktfbffakkakkak", "ktfbffcpanapck", "ktffffaacccck.", ".ktttttaaaaak.", "..kkkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#c0753a", b: "#7a4420", c: "#f2dcb0", f: "#d88a48", t: "#f0b070", n: "#5a3020", o: "#b8783a", q: "#6a4020", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["..kkk............", ".ktttk....k...k..", "ktffftk..kakkkak.", "ktfbfftk.kaaaaak.", "ktfbbfftkaieaieak", "ktfbffftkaeeaeeak", ".ktfbfftkcpanapck", "..ktfbftkaacccaak", "...ktfaabaaqqcak.", "....kaaabaaaoock.", "....kaabaaacccck.", ".....kaaaaaccck..", "....kaaakkkkaak..", ".....kkk....kk..."],
      blink: ["..kkk............", ".ktttk....k...k..", "ktffftk..kakkkak.", "ktfbfftk.kaaaaak.", "ktfbbfftkaaaaaaak", "ktfbffftkakkakkak", ".ktfbfftkcpanapck", "..ktfbftkaacccaak", "...ktfaabaaqqcak.", "....kaaabaaaoock.", "....kaabaaacccck.", ".....kaaaaaccck..", "....kaaakkkkaak..", ".....kkk....kk..."],
      step: ["..kkk............", ".ktttk....k...k..", "ktffftk..kakkkak.", "ktfbfftk.kaaaaak.", "ktfbbfftkaieaieak", "ktfbffftkaeeaeeak", ".ktfbfftkcpanapck", "..ktfbftkaacccaak", "...ktfaabaaqqcak.", "....kaaabaaaoock.", "....kaabaaacccck.", ".....kaaaaaccck..", ".....kaaakkaak...", "......kkk..kk...."],
      sleep: ["..kkk............", ".ktttk....k...k..", "ktffftk..kakkkak.", "ktfbfftk.kaaaaak.", "ktfbbfftkakkakkak", "ktfbfffaacpanapck", ".ktffffaaabaaaaak", "..ktttttaaaaaaak.", "...kkkkkkkkkkkk.."]
    }
  },
  white_rabbit: {
    name: "흰 토끼",
    grade: 1,
    kind: "wood",
    desc: "눈처럼 하얀 털에 빨간 눈을 가진 토끼입니다. 기분이 좋으면 제자리에서 폴짝 뜁니다.",
    likes: "treat_herb",
    baby: {
      pal: { a: "#f8f5ef", c: "#ddd4c8", p: "#f2a2b2", n: "#e07a8a", e: "#8e2232", i: "#d27482", k: "#1a120e" },
      idle: ["......kk.kk...", ".....kaakaak..", ".....kpakpak..", ".....kpakpak..", "....kaaaaaaak.", "....kaieaieak.", "..kkkaeeaeeak.", ".kcckpaanaapk.", "kccaaaaaaaaak.", ".kcaaaaaaaaak.", ".kaaakkkakaak.", "..kkk...k.kk.."],
      blink: ["......kk.kk...", ".....kaakaak..", ".....kpakpak..", ".....kpakpak..", "....kaaaaaaak.", "....kaaaaaaak.", "..kkkakkakkak.", ".kcckpaanaapk.", "kccaaaaaaaaak.", ".kcaaaaaaaaak.", ".kaaakkkakaak.", "..kkk...k.kk.."],
      step: ["......kk.kk...", ".....kaakaak..", ".....kpakpak..", ".....kpakpak..", "....kaaaaaaak.", "....kaieaieak.", "..kkkaeeaeeak.", ".kcckpaanaapk.", "kccaaaaaaaaak.", ".kkcaaaaaaaak.", "kaaakkkkkaak..", ".kkk.....kk..."],
      sleep: ["...kkkk.......", "..kaaaakkkkk..", "...kappaaaaak.", "..kkkakkakkak.", ".kcckpaanaapk.", "kccaaaaaaaaaak", ".kcaaaaaaaaak.", "..kkkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#f8f5ef", c: "#ddd4c8", p: "#f2a2b2", n: "#e07a8a", e: "#8e2232", i: "#d27482", k: "#1a120e" },
      idle: ["........kk..kk..", ".......kaakkaak.", ".......kpakpak..", ".......kpakpak..", ".......kpakpak..", "......kaaaaaaak.", "......kaieaieak.", "..kk..kaeeaeeak.", ".kcckkkpaanaapk.", "kcccaaaaaaaaak..", ".kcaaaaaaaaaaak.", "..kaaaaaaaaaaak.", ".kaaaakkkkaakak.", "..kkkk....kk.k.."],
      blink: ["........kk..kk..", ".......kaakkaak.", ".......kpakpak..", ".......kpakpak..", ".......kpakpak..", "......kaaaaaaak.", "......kaaaaaaak.", "..kk..kakkakkak.", ".kcckkkpaanaapk.", "kcccaaaaaaaaak..", ".kcaaaaaaaaaaak.", "..kaaaaaaaaaaak.", ".kaaaakkkkaakak.", "..kkkk....kk.k.."],
      step: ["........kk..kk..", ".......kaakkaak.", ".......kpakpak..", ".......kpakpak..", ".......kpakpak..", "......kaaaaaaak.", "......kaieaieak.", "..kk..kaeeaeeak.", ".kcckkkpaanaapk.", "kcccaaaaaaaaak..", ".kcaaaaaaaaaaak.", ".kkcaaaaaaaaak..", "kaaaakkkkkkaak..", ".kkkk......kk..."],
      sleep: ["....kkkkk.......", "...kaaaaakkkkk..", "....kapppaaaaak.", "..kk.kkakkakkak.", ".kcckkkpaanaapk.", "kcccaaaaaaaaaaak", ".kcaaaaaaaaaaak.", "..kaaaaaaaaaaak.", "...kkkkkkkkkkk.."]
    }
  },
  baby_turtle: {
    name: "새끼 거북",
    grade: 1,
    kind: "shell",
    desc: "등딱지가 손바닥만 한 거북입니다. 느릿느릿 걷다가도 먹이 소리에는 고개를 번쩍 듭니다.",
    likes: "treat_herb",
    baby: {
      pal: { s: "#4e8a3e", h: "#7ab858", r: "#365e2c", a: "#b6d27a", c: "#e8dca0", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["....kkkk......", "...krrrrk.kk..", "..krshhsrkaak.", ".krshsshsraaak", ".krhsshhsraiek", "krccccccccaeek", ".kaccccccaapk.", ".kaakaakaakk..", "..kk.kk.kk...."],
      blink: ["....kkkk......", "...krrrrk.kk..", "..krshhsrkaak.", ".krshsshsraaak", ".krhsshhsraaak", "krccccccccakk.", ".kaccccccaapk.", ".kaakaakaakk..", "..kk.kk.kk...."],
      step: ["....kkkk......", "...krrrrk.kk..", "..krshhsrkaak.", ".krshsshsraaak", ".krhsshhsraiek", "krccccccccaeek", ".kaccccccaapk.", "..kaakaakaak..", "...kk.kk.kk..."],
      sleep: ["....kkkk......", "...krrrrk.....", "..krshhsrk....", ".krshsshsrkk..", ".krhsshhsraak.", "krccccccccakk.", ".kcccccccccck.", "..kkkkkkkkkk.."]
    },
    adult: {
      pal: { s: "#4e8a3e", h: "#7ab858", r: "#365e2c", a: "#b6d27a", c: "#e8dca0", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: [".....kkkkkk.......", "....krrrrrrk......", "...krshhshhrk.kk..", "..krshsshsshrkaak.", ".krhhsshhsshhraak.", ".krshhsshhsshraiek", "krccccccccccccaeek", ".kacccccccccaaapk.", ".kaaakaakkkaakak..", "..kaakaak.kaakak..", "...kk.kk...kk.k..."],
      blink: [".....kkkkkk.......", "....krrrrrrk......", "...krshhshhrk.kk..", "..krshsshsshrkaak.", ".krhhsshhsshhraak.", ".krshhsshhsshraaak", "krccccccccccccakk.", ".kacccccccccaaapk.", ".kaaakaakkkaakak..", "..kaakaak.kaakak..", "...kk.kk...kk.k..."],
      step: [".....kkkkkk.......", "....krrrrrrk......", "...krshhshhrk.kk..", "..krshsshsshrkaak.", ".krhhsshhsshhraak.", ".krshhsshhsshraiek", "krccccccccccccaeek", ".kacccccccccaaapk.", "..kaakkaakaakkak..", ".kaakkaak.kaakak..", "..kk..kk...kk.k..."],
      sleep: [".....kkkkkk.......", "....krrrrrrk......", "...krshhshhrk.....", "..krshsshsshrk....", ".krhhsshhsshhrkk..", ".krshhsshhsshraak.", "krcccccccccccakk..", ".kcccccccccccccck.", "..kkkkkkkkkkkkkk.."]
    }
  },
  goldfish: {
    name: "금붕어",
    grade: 1,
    kind: "water",
    desc: "동그란 어항 속에서 사는 금붕어입니다. 손가락을 대면 졸졸 따라 헤엄칩니다.",
    likes: "treat_rice",
    baby: {
      pal: { g: "#bfe3ee", q: "#e6f6fa", w: "#6ab4d4", d: "#4a90b8", o: "#f07030", f: "#ffb060", b: "#eaf8ff", s: "#d8c090", l: "#4a9a50", e: "#2a1a14", i: "#ffffff", k: "#1a120e" },
      idle: ["...kkkkkkkk...", "..kggggggggk..", "..kgqqqqqqgk..", ".kgwwwwwwwbgk.", "kgwwwwwwwwwwgk", "kgwwfwooiwwwgk", "kgwffoooeowwgk", "kgwwfwooowwwgk", "kgdwlwwwwwwdgk", ".kgsllsssssgk.", "..kggggggggk..", "...kkkkkkkk..."],
      blink: ["...kkkkkkkk...", "..kggggggggk..", "..kgqqqqqqgk..", ".kgwwwwwwwbgk.", "kgwwwwwwwwwwgk", "kgwwfwooowwwgk", "kgwffoookowwgk", "kgwwfwooowwwgk", "kgdwlwwwwwwdgk", ".kgsllsssssgk.", "..kggggggggk..", "...kkkkkkkk..."],
      step: ["...kkkkkkkk...", "..kggggggggk..", "..kgqqqqqqbk..", ".kgwwwwwwwwgk.", "kgwwwwwwwwbwgk", "kgwwwfwooiwwgk", "kgwwffoooeowgk", "kgwwwfwooowwgk", "kgdwlwwwwwwdgk", ".kgsllsssssgk.", "..kggggggggk..", "...kkkkkkkk..."],
      sleep: ["...kkkkkkkk...", "..kggggggggk..", "..kgqqqqqqgk..", ".kgwwwwwwwwgk.", "kgwwwwwwwwwwgk", "kgwwwwwwwwwwgk", "kgwwfwoooowwgk", "kgwffoooookwgk", "kgdwlfwooowdgk", ".kgsllsssssgk.", "..kggggggggk..", "...kkkkkkkk..."]
    },
    adult: {
      pal: { g: "#bfe3ee", q: "#e6f6fa", w: "#6ab4d4", d: "#4a90b8", o: "#f07030", r: "#d84a20", f: "#ffb060", b: "#eaf8ff", s: "#d8c090", l: "#4a9a50", m: "#2e7a3a", e: "#2a1a14", i: "#ffffff", k: "#1a120e" },
      idle: ["....kkkkkkkkk....", "...kgggggggggk...", "...kgqqqqqqqgk...", "..kgwwwwwwwwbgk..", ".kgwwwwwwwwwwwgk.", "kgwwwwwwwwwwwbwgk", "kgwffwwwoooiwwwgk", "kgwfffwoorooewwgk", "kgwwffooororowwgk", "kgwfffwoooooowwgk", "kgwffwwwwfwwwwwgk", "kgdlwwwwwwwwwwdgk", "kgdlmwwwwwwwwldgk", ".kgsllsssssslsgk.", "..kgggggggggggk..", "...kkkkkkkkkkk..."],
      blink: ["....kkkkkkkkk....", "...kgggggggggk...", "...kgqqqqqqqgk...", "..kgwwwwwwwwbgk..", ".kgwwwwwwwwwwwgk.", "kgwwwwwwwwwwwbwgk", "kgwffwwwoooowwwgk", "kgwfffwoorokkwwgk", "kgwwffooororowwgk", "kgwfffwoooooowwgk", "kgwffwwwwfwwwwwgk", "kgdlwwwwwwwwwwdgk", "kgdlmwwwwwwwwldgk", ".kgsllsssssslsgk.", "..kgggggggggggk..", "...kkkkkkkkkkk..."],
      step: ["....kkkkkkkkk....", "...kgggggggggk...", "...kgqqqqqqqgbk..", "..kgwwwwwwwwwgk..", ".kgwwwwwwwwwbwgk.", "kgwwwwwwwwwwwwwgk", "kgwwffwwwoooiwwgk", "kgwwfffwoorooewgk", "kgwwwffooororowgk", "kgwwfffwoooooowgk", "kgwwwffwwwfwwwwgk", "kgdlwwwwwwwwwwdgk", "kgdlmwwwwwwwwldgk", ".kgsllsssssslsgk.", "..kgggggggggggk..", "...kkkkkkkkkkk..."],
      sleep: ["....kkkkkkkkk....", "...kgggggggggk...", "...kgqqqqqqqgk...", "..kgwwwwwwwwwgk..", ".kgwwwwwwwwwwwgk.", "kgwwwwwwwwwwwwwgk", "kgwwwwwwwwwwwwwgk", "kgwwwwwwwwwwwwwgk", "kgwffwwwoooowwwgk", "kgwfffwoorooowwgk", "kgwwffooorookwwgk", "kgdfffwoooooowdgk", "kgdlmwwwwfwwwldgk", ".kgsllsssssslsgk.", "..kgggggggggggk..", "...kkkkkkkkkkk..."]
    }
  },
  ink_cat: {
    name: "먹물 고양이",
    grade: 3,
    kind: "shadow",
    desc: "벼루 먹물을 뒤집어쓴 듯 새까만 고양이입니다. 밤이 되면 노란 눈만 동그랗게 떠 있습니다.",
    likes: "treat_fish",
    baby: {
      pal: { a: "#2c2a3a", h: "#45425a", i: "#f4f0e6", e: "#f2c94c", p: "#e79aa8", k: "#1a120e" },
      idle: ["......k...k...", ".....kak.kak..", "....kapakapak.", ".k..kahaaahak.", "kak.kaieaieak.", "kak.kaaeaaeak.", ".kakkaaapaaak.", ".kahhaaaaaaak.", ".kaaaaaaaaaak.", ".kaakakkakaak.", "..kk.k..k.kk.."],
      blink: ["......k...k...", ".....kak.kak..", "....kapakapak.", ".k..kahaaahak.", "kak.kaaaaaaak.", "kak.kahhahhak.", ".kakkaaapaaak.", ".kahhaaaaaaak.", ".kaaaaaaaaaak.", ".kaakakkakaak.", "..kk.k..k.kk.."],
      step: ["......k...k...", ".....kak.kak..", "....kapakapak.", ".k..kahaaahak.", "kak.kaieaieak.", "kak.kaaeaaeak.", ".kakkaaapaaak.", ".kahhaaaaaaak.", ".kaaaaaaaaaak.", "..kaakakakaak.", "...kk.k.k.kk.."],
      sleep: [".......k...k..", "......kak.kak.", ".....kapakapak", "..kkkkahaaahak", ".kaaaaahhahhak", "kahhaaaaapaaak", "kaaaaaaaaaaak.", ".kkkkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#2c2a3a", h: "#45425a", i: "#f4f0e6", e: "#f2c94c", p: "#e79aa8", y: "#f0d070", r: "#c0392b", k: "#1a120e" },
      idle: [".........k...k...", "........kak.kak..", ".......kapakapak.", "..k....kahaaahak.", ".kak...kaieaieak.", "kak....kaaeaaeak.", "kak....kaaapaaak.", ".kakkkkkkrryrrk..", "..kahhhaaaaaaaak.", "..kaaahhaaaaaaak.", "..kaaaaaaaaaaaak.", "..kaakaakkkaakak.", "..kaakaak.kaakak.", "...kk.kk...kk.k.."],
      blink: [".........k...k...", "........kak.kak..", ".......kapakapak.", "..k....kahaaahak.", ".kak...kaaaaaaak.", "kak....kahhahhak.", "kak....kaaapaaak.", ".kakkkkkkrryrrk..", "..kahhhaaaaaaaak.", "..kaaahhaaaaaaak.", "..kaaaaaaaaaaaak.", "..kaakaakkkaakak.", "..kaakaak.kaakak.", "...kk.kk...kk.k.."],
      step: [".........k...k...", "........kak.kak..", ".......kapakapak.", "..k....kahaaahak.", ".kak...kaieaieak.", "kak....kaaeaaeak.", "kak....kaaapaaak.", ".kakkkkkkrryrrk..", "..kahhhaaaaaaaak.", "..kaaahhaaaaaaak.", "..kaaaaaaaaaaaak.", "...kaakaakkaakak.", "..kaak.kaakakkak.", "...kk...kk.k..k.."],
      sleep: ["..........k...k..", ".........kak.kak.", "........kapakapak", "..kkkkkkkahaaahak", ".kaaaaaaaahhahhak", "kahhhaaaaaaapaaak", "kaaahhaaaarryrrak", ".kaaaaaaaaaaaaak.", "..kkkkkkkkkkkkk.."]
    }
  },
  baby_crow: {
    name: "아기 까마귀",
    grade: 2,
    kind: "bird",
    desc: "깃털이 아직 보송한 까마귀 새끼입니다. 은혜를 잊지 않아 가끔 작은 조약돌을 물어 옵니다.",
    likes: "treat_rice",
    baby: {
      pal: { a: "#363a52", h: "#5a6290", n: "#5a5a68", e: "#0c0806", i: "#ffffff", p: "#c89aa8", k: "#1a120e" },
      idle: ["........k.k...", ".......kakak..", "......kaaaak..", ".....kaaaaaak.", "....kaaaaieak.", ".kk.kaaaaeennk", "kaakkahhaaapk.", ".kaahhhhaaaak.", "..kahhhaaaaak.", "...kkaaaaaak..", ".....knknkk...", "......k.k....."],
      blink: ["........k.k...", ".......kakak..", "......kaaaak..", ".....kaaaaaak.", "....kaaaaaaak.", ".kk.kaaaahhnnk", "kaakkahhaaapk.", ".kaahhhhaaaak.", "..kahhhaaaaak.", "...kkaaaaaak..", ".....knknkk...", "......k.k....."],
      step: ["........k.k...", ".......kakak..", "......kaaaak..", ".....kaaaaaak.", "....kaaaaieak.", ".kk.kaaaaeennk", "kaakkahhaaapk.", ".kaahhhhaaaak.", "..kahhhaaaaak.", "...kkaaaaaak..", ".....kknnkk...", ".......kk....."],
      sleep: ["........k.k...", ".......kakak..", "......kaaaak..", ".....kaaaaaak.", ".kk.kaaahhaank", "kaakkahhaaapk.", ".kaahhhhaaaak.", "..kaaaaaaaak..", "...kkkkkkkk..."]
    },
    adult: {
      pal: { a: "#363a52", h: "#5a6290", n: "#5a5a68", e: "#0c0806", i: "#ffffff", p: "#c89aa8", k: "#1a120e" },
      idle: ["..........kkk....", ".........kaaak...", "........kaaaaak..", ".......kaaaaieak.", ".......kaaaaeennk", "......kaaaaaapkk.", ".kk..kkahhhaaaak.", "kaakkaahhhhaaaak.", ".kaaaahhhhhaaaak.", "..kkaaahhhaaaak..", "....kkkkaaaaak...", "........knkknk...", ".......knnknnk...", "........kk.kk...."],
      blink: ["..........kkk....", ".........kaaak...", "........kaaaaak..", ".......kaaaaaaak.", ".......kaaaahhnnk", "......kaaaaaapkk.", ".kk..kkahhhaaaak.", "kaakkaahhhhaaaak.", ".kaaaahhhhhaaaak.", "..kkaaahhhaaaak..", "....kkkkaaaaak...", "........knkknk...", ".......knnknnk...", "........kk.kk...."],
      step: ["..........kkk....", ".........kaaak...", "........kaaaaak..", ".......kaaaaieak.", ".......kaaaaeennk", "......kaaaaaapkk.", ".kk..kkahhhaaaak.", "kaakkaahhhhaaaak.", ".kaaaahhhhhaaaak.", "..kkaaahhhaaaak..", "....kkkkaaaaak...", "........kknnk....", "........knnknk...", ".........kk.k...."],
      sleep: ["..........kkk....", ".........kaaak...", "........kaaaaakk.", ".......kaaaahhank", "......kaaaaaapkk.", ".kk..kkahhhaaaak.", "kaakkaahhhhaaaak.", ".kaaaahhhhhaaaak.", "..kkaaaaaaaaaak..", "....kkkkkkkkkk..."]
    }
  },
  dokkaebi_fire: {
    name: "도깨비불",
    grade: 2,
    kind: "ghost",
    desc: "밤길 무덤가를 떠도는 푸른 불씨가 정을 붙였습니다. 메밀묵 냄새만 나면 불꽃이 두 배로 커집니다.",
    likes: "treat_rice",
    baby: {
      pal: { f: "#3fc6e0", c: "#9cecff", w: "#e8fdff", e: "#123048", i: "#6a9ac0", p: "#ff9ab8", s: "#9af0ff", k: "#1a120e" },
      idle: ["...k..........", "..kfk....k.s..", "..kffk..kfk...", "...kffkkffk...", "...kfffffffk..", "..kffccccccfk.", ".kffcwwwwwwcfk", ".kfcwiewiewcfk", ".kfcweeweewcfk", ".kfcpwwwwpcfk.", "..kfcccccccfk.", "...kfffffffk..", "....kkkkkkk..."],
      blink: ["...k..........", "..kfk....k.s..", "..kffk..kfk...", "...kffkkffk...", "...kfffffffk..", "..kffccccccfk.", ".kffcwwwwwwcfk", ".kfcwwwwwwwcfk", ".kfcwkkwkkwcfk", ".kfcpwwwwpcfk.", "..kfcccccccfk.", "...kfffffffk..", "....kkkkkkk..."],
      step: ["..k...........", ".kfkk...k..s..", "..kffk.kfk....", "..kfffkffkk...", "...kfffffffk..", "..kffccccccfk.", ".kffcwwwwwwcfk", ".kfcwiewiewcfk", ".kfcweeweewcfk", ".kfcpwwwwpcfk.", "..kfcccccccfk.", ".s.kfffffffk..", "....kkkkkkk..."],
      sleep: ["....k.........", "...kfk..k.....", "...kffkkfkk...", "..kffffffffk..", ".kffcccccccfk.", ".kfcwkkwkkwcfk", ".kfcpwwwwpcfk.", "..kffcccccfk..", "...kkfffffk...", ".....kkkkk...."]
    },
    adult: {
      pal: { f: "#3fc6e0", c: "#9cecff", w: "#e8fdff", d: "#2a7fb8", e: "#123048", i: "#6a9ac0", p: "#ff9ab8", s: "#9af0ff", k: "#1a120e" },
      idle: ["..k..............", ".kfk......k......", "..kfk....kfk.....", ".kffk...kffk..s..", "..kffkkkfffk.....", "..kdfffffffdkk...", "..kffcccccccffk..", ".kffcwwwwwwwcfk..", ".kfcwwwwwwwwwcfk.", ".kfcwwiewwiewcfk.", ".kfcwweewweewcfk.", ".kfcwpwwwwwpwcfk.", ".skfcwwwwwwwcfk..", "..kffcccccccffk..", "...kkfffffffkk...", ".....kkkkkkk....."],
      blink: ["..k..............", ".kfk......k......", "..kfk....kfk.....", ".kffk...kffk..s..", "..kffkkkfffk.....", "..kdfffffffdkk...", "..kffcccccccffk..", ".kffcwwwwwwwcfk..", ".kfcwwwwwwwwwcfk.", ".kfcwwwwwwwwwcfk.", ".kfcwwkkwwkkwcfk.", ".kfcwpwwwwwpwcfk.", ".skfcwwwwwwwcfk..", "..kffcccccccffk..", "...kkfffffffkk...", ".....kkkkkkk....."],
      step: [".k...............", "kfk.......k......", ".kfk.....kfk.....", ".kffkk..kffk.....", "..kfffkkffkk.s...", "..kdffffffffkk...", "..kffcccccccffk..", ".kffcwwwwwwwcfk..", ".kfcwwwwwwwwwcfk.", ".kfcwwiewwiewcfk.", ".kfcwweewweewcfk.", ".kfcwpwwwwwpwcfk.", "..kfcwwwwwwwcfks.", "..kffcccccccffk..", "...kkfffffffkk...", ".....kkkkkkk....."],
      sleep: ["....k............", "...kfk...k.......", "...kffk.kfk......", "...kkffkffkkk....", "..kdffffffffdk...", "..kffcccccccffk..", ".kffcwwwwwwwcfk..", ".kfcwwkkwwkkwcfk.", ".kfcwpwwwwwpwcfk.", "..kffcccccccffk..", "...kkfffffffkk...", ".....kkkkkkk....."]
    }
  },
  little_raccoon: {
    name: "꼬마 너구리",
    grade: 2,
    kind: "shadow",
    desc: "눈가에 검은 탈을 쓴 듯한 꼬마 너구리입니다. 머리에 나뭇잎을 얹고 둔갑하는 흉내를 냅니다.",
    likes: "treat_fish",
    baby: {
      pal: { a: "#9a8468", b: "#4e4034", c: "#f0e8d8", t: "#6a5a48", n: "#2a1a14", e: "#120c08", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: [".....kk...kk..", "....kbbkkkbbk.", "....kacaaacak.", "....kbieciebk.", ".kk.kbeeceebk.", "kttkkpccnccpk.", "ktbtaaacccckk.", ".kttaaaaaaaaak", "..kaaaaaaaaak.", "..kbbkbkkbkbbk", "...kk.k..k.kk."],
      blink: [".....kk...kk..", "....kbbkkkbbk.", "....kacaaacak.", "....kbaacaabk.", ".kk.kbcccccbk.", "kttkkpccnccpk.", "ktbtaaacccckk.", ".kttaaaaaaaaak", "..kaaaaaaaaak.", "..kbbkbkkbkbbk", "...kk.k..k.kk."],
      step: [".....kk...kk..", "....kbbkkkbbk.", "....kacaaacak.", "....kbieciebk.", ".kk.kbeeceebk.", "kttkkpccnccpk.", "ktbtaaacccckk.", ".kttaaaaaaaaak", "..kaaaaaaaaak.", "..kbkbbkkbbkbk", "...k.kk..kk.k."],
      sleep: [".....kk...kk..", "....kbbkkkbbk.", ".kk.kacaaacak.", "kttkkbccaccbk.", "ktbtkpccnccpk.", "ktbtaaaaaaaaak", ".kttaaaaaaaak.", "..kkkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#9a8468", b: "#4e4034", c: "#f0e8d8", t: "#6a5a48", n: "#2a1a14", l: "#5aa040", m: "#3a7a2a", e: "#120c08", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["..........kk.....", "........kkllkkk..", ".......kbbmlkbbk.", ".......kacaaacak.", ".......kbieciebk.", ".kk....kbeeceebk.", "kttk...kpccnccpk.", "ktbtkkkkkaccakk..", "kttbtaaaaaaccaak.", ".ktbtaaaaaaaaaak.", "..kttaaaaaaaaaak.", "...kbbkbbkkkbbkbk", "...kbbkbbk.kbbkbk", "....kk.kk...kk.k."],
      blink: ["..........kk.....", "........kkllkkk..", ".......kbbmlkbbk.", ".......kacaaacak.", ".......kbaacaabk.", ".kk....kbcccccbk.", "kttk...kpccnccpk.", "ktbtkkkkkaccakk..", "kttbtaaaaaaccaak.", ".ktbtaaaaaaaaaak.", "..kttaaaaaaaaaak.", "...kbbkbbkkkbbkbk", "...kbbkbbk.kbbkbk", "....kk.kk...kk.k."],
      step: ["..........kk.....", "........kkllkkk..", ".......kbbmlkbbk.", ".......kacaaacak.", ".......kbieciebk.", ".kk....kbeeceebk.", "kttk...kpccnccpk.", "ktbtkkkkkaccakk..", "kttbtaaaaaaccaak.", ".ktbtaaaaaaaaaak.", "..kttaaaaaaaaaak.", "...kkbbkbbkkbbkbk", "...kbbk.kbbkbkkbk", "....kk...kk.k..k."],
      sleep: ["..........kk.....", "........kkllkkk..", ".......kbbmlkbbk.", ".kk....kacaaacak.", "kttk...kbccaccbk.", "ktbtkkkkpccnccpk.", "kttbtaaaaaacccaak", ".ktbtaaaaaaaaaak.", "..ktttaaaaaaaak..", "...kkkkkkkkkkk..."]
    }
  },
  baby_crane: {
    name: "아기 학",
    grade: 2,
    kind: "sky",
    desc: "정수리에 붉은 점이 돋기 시작한 아기 학입니다. 다리가 길어 걸을 때마다 휘청거립니다.",
    likes: "treat_fish",
    baby: {
      pal: { w: "#f6f4ee", g: "#d4d0c8", a: "#2c2c36", r: "#d8323a", n: "#c8a860", l: "#4a4a52", e: "#2a1a14", i: "#7a7a80", p: "#f3a0a0", k: "#1a120e" },
      idle: [".......kkkk...", "......kwrrwk..", ".....kwwwiewk.", ".....kwwweewnk", ".kk.kkwwwwpwk.", "kaakggwwwwwk..", ".kaaggggwwwwk.", "..kaggggwwwwk.", "...kkgggwwkk..", ".....klklk....", "....kllkllk...", ".....kk.kk...."],
      blink: [".......kkkk...", "......kwrrwk..", ".....kwwwwwwk.", ".....kwwwkkwnk", ".kk.kkwwwwpwk.", "kaakggwwwwwk..", ".kaaggggwwwwk.", "..kaggggwwwwk.", "...kkgggwwkk..", ".....klklk....", "....kllkllk...", ".....kk.kk...."],
      step: [".......kkkk...", "......kwrrwk..", ".....kwwwiewk.", ".....kwwweewnk", ".kk.kkwwwwpwk.", "kaakggwwwwwk..", ".kaaggggwwwwk.", "..kaggggwwwwk.", "...kkgggwwkk..", ".....klkklkk..", "....kllk.kllk.", ".....kk...kk.."],
      sleep: [".......kkkk...", "......kwrrwk..", ".....kwwwwwwk.", ".kk.kkwwkkwwnk", "kaakggwwwwpwk.", ".kaaggggwwwwk.", "..kaggggwwwwk.", "...kgggggggk..", "....kkkkkkk..."]
    },
    adult: {
      pal: { w: "#f6f4ee", a: "#2c2c36", r: "#d8323a", n: "#c8a860", l: "#4a4a52", e: "#2a1a14", i: "#7a7a80", k: "#1a120e" },
      idle: ["..........kk.....", ".........krrkk...", "........kwwwwwkk.", "........kwwiewnnk", "........kaweewkk.", ".........kaaak...", "...kk..kkaawk....", "..kaakkwwwwwwk...", ".kaaaawwwwwwwwk..", "kaaaaawwwwwwwwk..", ".kaaaaawwwwwwk...", "..kkaaawwwwwk....", "....kkkklkklk....", ".......klkklk....", "......kllkllk....", ".......kk.kk....."],
      blink: ["..........kk.....", ".........krrkk...", "........kwwwwwkk.", "........kwwwwwnnk", "........kawkkwkk.", ".........kaaak...", "...kk..kkaawk....", "..kaakkwwwwwwk...", ".kaaaawwwwwwwwk..", "kaaaaawwwwwwwwk..", ".kaaaaawwwwwwk...", "..kkaaawwwwwk....", "....kkkklkklk....", ".......klkklk....", "......kllkllk....", ".......kk.kk....."],
      step: ["..........kk.....", ".........krrkk...", "........kwwwwwkk.", "........kwwiewnnk", "........kaweewkk.", ".........kaaak...", "...kk..kkaawk....", "..kaakkwwwwwwk...", ".kaaaawwwwwwwwk..", "kaaaaawwwwwwwwk..", ".kaaaaawwwwwwk...", "..kkaaawwwwwk....", "....kkkklkklk....", ".......klkllk....", "......kllkkk.....", ".......kk........"],
      sleep: ["..........kk.....", ".........krrkk...", "........kwwwwwkk.", "........kwwkkwnnk", "........kawwwwkk.", "...kk..kkaaakk...", "..kaakkwwwawwk...", ".kaaaawwwwwwwwk..", "kaaaaawwwwwwwwk..", ".kaaaaawwwwwwwk..", "..kkaaawwwwwwk...", "....kkkkkkkkk...."]
    }
  },
  baby_otter: {
    name: "새끼 수달",
    grade: 2,
    kind: "water",
    desc: "물가 바위에서 뒹굴기를 좋아하는 새끼 수달입니다. 마음에 드는 조약돌은 꼭 품에 안고 잡니다.",
    likes: "treat_fish",
    baby: {
      pal: { a: "#7a5236", b: "#553620", c: "#e4ccaa", n: "#2a1a14", g: "#c8dce8", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: [".......k...k..", "......kakkkak.", ".....kaaaaaaak", ".....kaieaieak", ".....kaeeaeeak", "..kkkkpccnccpk", ".kbbaaaacccck.", "kbbbaaaaaaaak.", ".kbkaaaaaaak..", "..kkaakakkaak.", "....kk.k..kk.."],
      blink: [".......k...k..", "......kakkkak.", ".....kaaaaaaak", ".....kaaaaaaak", ".....kakkakkak", "..kkkkpccnccpk", ".kbbaaaacccck.", "kbbbaaaaaaaak.", ".kbkaaaaaaak..", "..kkaakakkaak.", "....kk.k..kk.."],
      step: [".......k...k..", "......kakkkak.", ".....kaaaaaaak", ".....kaieaieak", ".....kaeeaeeak", "..kkkkpccnccpk", ".kbbaaaacccck.", "kbbbaaaaaaaak.", ".kbkaaaaaaak..", "..k.kaakakaak.", ".....kk.k.kk.."],
      sleep: [".......k...k..", "......kakkkak.", ".....kaaaaaaak", "..kkkkakkakkak", ".kbbaapccnccpk", "kbbbaaaacggcak", ".kbbaaaaaaaak.", "..kkkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#7a5236", b: "#553620", c: "#e4ccaa", n: "#2a1a14", g: "#c8dce8", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["..........k...k...", ".........kakkkak..", "........kaaaaaaak.", "........kaieaieak.", "........kaeeaeeak.", "........kpccnccpk.", ".k...kkkaaccccak..", "kbk.kaaaaaaccccck.", "kbbkaaaaaaaaaccck.", ".kbbbaaaaaaaaaakk.", "..kkaakaakkkaakaak", "....kk.kk...kk.kk."],
      blink: ["..........k...k...", ".........kakkkak..", "........kaaaaaaak.", "........kaaaaaaak.", "........kakkakkak.", "........kpccnccpk.", ".k...kkkaaccccak..", "kbk.kaaaaaaccccck.", "kbbkaaaaaaaaaccck.", ".kbbbaaaaaaaaaakk.", "..kkaakaakkkaakaak", "....kk.kk...kk.kk."],
      step: ["..........k...k...", ".........kakkkak..", "........kaaaaaaak.", "........kaieaieak.", "........kaeeaeeak.", "........kpccnccpk.", ".k...kkkaaccccak..", "kbk.kaaaaaaccccck.", "kbbkaaaaaaaaaccck.", ".kbbbaaaaaaaaaak..", "..kkkaakaakaakaak.", ".....kk.kk.kk.kk.."],
      sleep: ["..........k...k...", ".........kakkkak..", "........kaaaaaaak.", "........kakkakkak.", ".k....kkkpccnccpk.", "kbkkkkaaaacggccck.", "kbbbbaaaaaaggccak.", ".kbbbbaaaaaaaaaak.", "..kkkkkkkkkkkkkk.."]
    }
  },
  baby_owl: {
    name: "아기 부엉이",
    grade: 2,
    kind: "bird",
    desc: "밤새 눈을 동그랗게 뜨고 집을 지켜 주는 아기 부엉이입니다. 낮에는 졸린 듯 자꾸 꾸벅입니다.",
    likes: "treat_meat",
    baby: {
      pal: { a: "#8a6440", b: "#5e4028", c: "#ecdcb8", y: "#f0b030", n: "#d89a40", f: "#d8a050", e: "#2a1a14", i: "#ffffff", k: "#1a120e" },
      idle: ["..k......k...", ".kak....kak..", ".kaakkkkaak..", "kaaaaaaaaaak.", "kcyyyccyyyck.", "kcyiecyiecck.", "kcyeeccyeeck.", "kacccnncccak.", "kaabcbcbcaak.", ".kabcbcbcak..", "..kffkkffk...", "...kk..kk...."],
      blink: ["..k......k...", ".kak....kak..", ".kaakkkkaak..", "kaaaaaaaaaak.", "kcccccccccck.", "kcccccccccck.", "kckkkckkkkck.", "kacccnncccak.", "kaabcbcbcaak.", ".kabcbcbcak..", "..kffkkffk...", "...kk..kk...."],
      step: ["..k......k...", ".kak....kak..", ".kaakkkkaak..", "kaaaaaaaaaak.", "kcyyyccyyyck.", "kcyiecyiecck.", "kcyeeccyeeck.", "kacccnncccak.", "kaabcbcbcaak.", ".kabcbcbcak..", ".kffkkkkffk..", "..kk....kk..."],
      sleep: ["..k......k...", ".kak....kak..", ".kaakkkkaak..", "kaaaaaaaaaak.", "kccccccccccck", "kckkkcckkkck.", "kacccnncccak.", "kaabcbcbcaak.", ".kabcbcbcak..", "..kkkkkkkk..."]
    },
    adult: {
      pal: { a: "#8a6440", b: "#5e4028", c: "#ecdcb8", y: "#f0b030", n: "#d89a40", f: "#d8a050", e: "#2a1a14", i: "#ffffff", k: "#1a120e" },
      idle: ["..k.........k..", ".kak.......kak.", ".kaak.....kaak.", ".kaaakkkkkaaak.", "kaaaaaaaaaaaaak", "kacyyycccyyycak", "kacyiecccyiecak", "kacyeecncyeecak", "kaaccccnccccaak", "kbaacbcbcbcaabk", "kbaabcbcbcbaabk", "kbbaacbcbcaabbk", ".kbbaaaaaaabbk.", "..kfffkkkfffk..", "...kkk...kkk..."],
      blink: ["..k.........k..", ".kak.......kak.", ".kaak.....kaak.", ".kaaakkkkkaaak.", "kaaaaaaaaaaaaak", "kacccccccccccak", "kacccccccccccak", "kackkkcnckkkcak", "kaaccccnccccaak", "kbaacbcbcbcaabk", "kbaabcbcbcbaabk", "kbbaacbcbcaabbk", ".kbbaaaaaaabbk.", "..kfffkkkfffk..", "...kkk...kkk..."],
      step: ["..k.........k..", ".kak.......kak.", ".kaak.....kaak.", ".kaaakkkkkaaak.", "kaaaaaaaaaaaaak", "kacyyycccyyycak", "kacyiecccyiecak", "kacyeecncyeecak", "kaaccccnccccaak", "kbaacbcbcbcaabk", "kbaabcbcbcbaabk", "kbbaacbcbcaabbk", ".kbbaaaaaaabbk.", ".kfffkkkkkfffk.", "..kkk.....kkk.."],
      sleep: ["..k.........k..", ".kak.......kak.", ".kaak.....kaak.", ".kaaakkkkkaaak.", "kaaaaaaaaaaaaak", "kacccccccccccak", "kackkkcccckkkak", "kaaccccnccccaak", "kbaacbcbcbcaabk", "kbaabcbcbcbaabk", "kbbaacbcbcaabbk", ".kbbaaaaaaabbk.", "..kkkkkkkkkkk.."]
    }
  },
  little_toad: {
    name: "꼬마 두꺼비",
    grade: 2,
    kind: "venom",
    desc: "우물가에 사는 통통한 두꺼비입니다. 복을 부른다는 말을 들었는지 늘 의젓하게 앉아 있습니다.",
    likes: "treat_meat",
    baby: {
      pal: { a: "#93a04c", b: "#6a7a36", c: "#e6dca0", m: "#4a5420", e: "#2a1a14", i: "#8a8a60", p: "#f3a0a0", k: "#1a120e" },
      idle: ["......kkk.kkk.", ".....kccckccck", "...kkkciekciek", "..kaaaceeaceek", ".kabaaaaaaaapk", ".kaaabaammmmak", "kaabaaaaccccak", ".kaaaaaccccck.", ".kaakakkkakaak", "..kk.k...k.kk."],
      blink: ["......kkk.kkk.", ".....kccckccck", "...kkkcaakcaak", "..kaaackkackk.", ".kabaaaaaaaapk", ".kaaabaammmmak", "kaabaaaaccccak", ".kaaaaaccccck.", ".kaakakkkakaak", "..kk.k...k.kk."],
      step: ["......kkk.kkk.", ".....kccckccck", "...kkkciekciek", "..kaaaceeaceek", ".kabaaaaaaaapk", ".kaaabaammmmak", "kaabaaaaccccak", ".kaaaaaccccck.", "kaakkkkkkakaak", ".kk......k.kk."],
      sleep: ["......kkk.kkk.", "...kkkccckccck", "..kaaackkackk.", ".kabaaaaaaaapk", ".kaaabaammmmak", "kaabaaaaccccak", "kaaaaaacccccck", ".kkkkkkkkkkkk."]
    },
    adult: {
      pal: { a: "#93a04c", b: "#6a7a36", c: "#e6dca0", m: "#4a5420", y: "#e8c040", h: "#8a6a10", g: "#c8b850", e: "#2a1a14", i: "#8a8a60", p: "#f3a0a0", k: "#1a120e" },
      idle: ["........kkk.kkk..", ".......kccckccck.", "....kkkkciekciek.", "...kaaaaceeaceek.", "..kabaagaaaaaapk.", ".kaagaaaaaammyyyk", "kaabaabaaaaamyhyk", "kabaaagacccccyyyk", ".kaaaabacccccckk.", ".kaaakkkakkkakak.", "kaaaakkaakkaakaak", ".kkkk..kk..kk.kk."],
      blink: ["........kkk.kkk..", ".......kccckccck.", "....kkkkcaakcaak.", "...kaaaackkackk..", "..kabaagaaaaaapk.", ".kaagaaaaaammyyyk", "kaabaabaaaaamyhyk", "kabaaagacccccyyyk", ".kaaaabacccccckk.", ".kaaakkkakkkakak.", "kaaaakkaakkaakaak", ".kkkk..kk..kk.kk."],
      step: ["........kkk.kkk..", ".......kccckccck.", "....kkkkciekciek.", "...kaaaaceeaceek.", "..kabaagaaaaaapk.", ".kaagaaaaaammyyyk", "kaabaabaaaaamyhyk", "kabaaagacccccyyyk", ".kaaaabacccccckk.", ".kaaakkkkkkkkkkak", "kaaaak.....kaakak", ".kkkk.......kk.k."],
      sleep: ["........kkk.kkk..", "....kkkkccckccck.", "...kaaaackkackk..", "..kabaagaaaaaapk.", ".kaagaaaaaammyyyk", "kaabaabaaaaamyhyk", "kabaaagacccccyyyk", "kaaaaabaccccccck.", ".kkkkkkkkkkkkkk.."]
    }
  },
  firefly_spirit: {
    name: "반딧불 정령",
    grade: 2,
    kind: "swarm",
    desc: "여름밤 개울가의 반딧불이 모여 생긴 작은 정령입니다. 꽁무니 불빛으로 기분을 알려 줍니다.",
    likes: "treat_honey",
    baby: {
      pal: { a: "#2e3b55", n: "#3a4a66", c: "#f2e8c8", w: "#d6eef6", g: "#c8e04a", h: "#fbffc0", s: "#f6ffa0", e: "#2a1a14", i: "#8a8070", p: "#f3a0a0", k: "#1a120e" },
      idle: ["........k...k.", "...sk..khk.khk", "..kwwk.kknknk.", ".kwwwwkccccck.", "kwwwwwciecieck", ".kwwwwceeceeck", ".kghaapcccccpk", "kghhgaakccckk.", "kghhgkknkknk..", ".kggks.k..k...", "..kk.........."],
      blink: ["........k...k.", "...sk..khk.khk", "..kwwk.kknknk.", ".kwwwwkccccck.", "kwwwwwccccccck", ".kwwwwckkckkck", ".kghaapcccccpk", "kghhgaakccckk.", "kghhgkknkknk..", ".kggks.k..k...", "..kk.........."],
      step: ["........k...k.", ".kkk...khk.khk", "kwwwk..kknknk.", "kwwwwkkccccck.", ".kwwwwciecieck", "..kwwwceeceeck", ".kghaapcccccpk", "kghhgaakccckk.", "kghhgkknkknk..", ".kggs..k..k...", "..kk.........."],
      sleep: ["........k...k.", "...kkk.khk.khk", "..kwwwkkknknk.", ".kwwwwwccccck.", "kgggwwckkckkck", "kghhggpcccccpk", ".kgggkkccckkk.", "..kkk..kkk...."]
    },
    adult: {
      pal: { a: "#2e3b55", n: "#3a4a66", c: "#f2e8c8", w: "#d6eef6", g: "#c8e04a", h: "#fbffc0", s: "#f6ffa0", e: "#2a1a14", i: "#8a8070", p: "#f3a0a0", k: "#1a120e" },
      idle: ["..........k...k..", ".....s...khk.khk.", "...kk.....knknk..", "..kwwk...kccccck.", ".kwwwwk.kccccccck", "kwwwwwwkkciecieck", ".kwwwwwwkceeceeck", "..kwwwwaapcccccpk", ".kgghhgaaaccccck.", "kghhhhhgaaknkknk.", "kghhhhhgkksk..k..", ".kghhhgk.........", "..kgggk..s.......", "...kkk..........."],
      blink: ["..........k...k..", ".....s...khk.khk.", "...kk.....knknk..", "..kwwk...kccccck.", ".kwwwwk.kccccccck", "kwwwwwwkkccccccck", ".kwwwwwwkckkckkck", "..kwwwwaapcccccpk", ".kgghhgaaaccccck.", "kghhhhhgaaknkknk.", "kghhhhhgkksk..k..", ".kghhhgk.........", "..kgggk..s.......", "...kkk..........."],
      step: ["..........k...k..", ".kk......khk.khk.", "kwwk......knknk..", "kwwwk....kccccck.", "kwwwwkk.kccccccck", ".kwwwwwkkciecieck", "..kwwwwkkceeceeck", "..kkkwwaapcccccpk", ".kgghhgaaaccccck.", "kghhhhhgaaknkknk.", "kghhhhhgkk.k..k..", ".kghhhgk..s......", ".skgggk..........", "...kkk..........."],
      sleep: ["..........k...k..", ".........khk.khk.", "...kkk....knknk..", "..kwwwkk.kccccck.", ".kwwwwwwkccccccck", ".kggwwwwwckkckkck", "kgghhhgaapcccccpk", "kghhhhhgaaccccck.", ".kghhhhgkkkkkkk..", "..kggggk.........", "...kkkk.........."]
    }
  },
  baby_gumiho: {
    name: "새끼 구미호",
    grade: 3,
    kind: "mirror",
    desc: "꼬리가 아직 셋뿐인 어린 여우입니다. 천 년을 채우면 아홉 꼬리가 된다며 날마다 꼬리를 세어 봅니다.",
    likes: "treat_meat",
    baby: {
      pal: { a: "#f8f0e0", c: "#d9bd90", o: "#f4a050", r: "#d83a4a", n: "#3a2418", e: "#5a2410", i: "#b07050", k: "#1a120e" },
      idle: ["..kk.kk........", ".kookookk...k..", ".kaakcckok.kok.", "koaakcckaakaak.", "koaakccaaaaaaak", "kccakccaieaieak", ".kccaccaeeaeeak", "..kccccraanaark", "...kaaaaaaaaak.", "...kaaaaaaaaak.", "...kookokkokook", "....kk.k..k.kk."],
      blink: ["..kk.kk........", ".kookookk...k..", ".kaakcckok.kok.", "koaakcckaakaak.", "koaakccaaaaaaak", "kccakccaaaaaaak", ".kccaccakkakkak", "..kccccraanaark", "...kaaaaaaaaak.", "...kaaaaaaaaak.", "...kookokkokook", "....kk.k..k.kk."],
      step: [".kk.kk.........", "kookook.k...k..", "kaakcckkok.kok.", "kaakcckkaakaak.", "koakccaaaaaaak.", "kcakccaaieaieak", ".kccaccaeeaeeak", "..kccccraanaark", "...kaaaaaaaaak.", "...kaaaaaaaaak.", "....kookokokok.", ".....kk.k.k.k.."],
      sleep: ["........k...k..", ".......kok.kok.", ".......kaakaak.", ".kk...kaaaaaaak", "kookkkkakkakkak", "kccaaaaraanaark", "koaccaaaaaaaaak", ".koocccccccaak.", "..kkkkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#f8f0e0", c: "#d9bd90", o: "#f4a050", q: "#e07c34", r: "#d83a4a", n: "#3a2418", e: "#5a2410", i: "#b07050", k: "#1a120e" },
      idle: [".....k.k...k...k..", "...kkqkok.kok.kok.", "..kooqqookkaakaak.", ".kqooqcakkaaaaaaak", "koqcaacakkaieaieak", "koacaacakkaeeaeeak", "kcaacacakkraanaark", "kccaackkkkkaccakk.", "kaacakaaaaaaaccak.", "kcaakaaaaaaaaaaak.", "kccckaaaaaaaaaakk.", "kaakkaakaakkkaakak", ".kk.kookook.kookok", ".....kk.kk...kk.k."],
      blink: [".....k.k...k...k..", "...kkqkok.kok.kok.", "..kooqqookkaakaak.", ".kqooqcakkaaaaaaak", "koqcaacakkaaaaaaak", "koacaacakkakkakkak", "kcaacacakkraanaark", "kccaackkkkkaccakk.", "kaacakaaaaaaaccak.", "kcaakaaaaaaaaaaak.", "kccckaaaaaaaaaakk.", "kaakkaakaakkkaakak", ".kk.kookook.kookok", ".....kk.kk...kk.k."],
      step: ["......k.k..k...k..", "..k.kkqkokkok.kok.", ".kqkooqqookaakaak.", "koqqooccokaaaaaaak", "kooccaccakaieaieak", "kqaacacaakaeeaeeak", "kccacacakkraanaark", "kaccackkkkkaccakk.", "kaaackaaaaaaaccak.", "kccckaaaaaaaaaaak.", "kaaakaaaaaaaaaakk.", ".kkk.kaakaakkaakak", "....kook.kookookok", ".....kk...kk.kk.k."],
      sleep: ["...........k...k..", "..........kok.kok.", "..kkk.....kaakaak.", ".koqok...kaaaaaaak", "koqockkkkkakkakkak", "kqockkaaaaraanaark", "koakaaaaaaaaaaaaak", "kqckaaaaaaaaaaaak.", ".kk.kkkkkkkkkkkk.."]
    }
  },
  baby_haetae: {
    name: "아기 해태",
    grade: 3,
    kind: "ward",
    desc: "옳고 그름을 가린다는 해태의 새끼입니다. 불기운을 먹고 자라서 화로 곁을 떠나지 않습니다.",
    likes: "treat_rice",
    baby: {
      pal: { a: "#e8c46a", b: "#c89a3e", m: "#3f9a8c", n: "#7cd0bc", h: "#f4ecd2", y: "#f2d050", q: "#3a2418", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["........k.....", ".....kkkhkkk..", "....kmnmhmnmk.", "...kmaaaaaaamk", "..kkmaieaieamk", ".kmkmaeeaeeamk", "kmnmkpaaqaapmk", ".kmkkmmyymmmk.", ".kmabaabaaaak.", "..kaaaaaaaaak.", "..kaakakkakaak", "...kk.k..k.kk."],
      blink: ["........k.....", ".....kkkhkkk..", "....kmnmhmnmk.", "...kmaaaaaaamk", "..kkmaaaaaaamk", ".kmkmakkakkamk", "kmnmkpaaqaapmk", ".kmkkmmyymmmk.", ".kmabaabaaaak.", "..kaaaaaaaaak.", "..kaakakkakaak", "...kk.k..k.kk."],
      step: ["........k.....", ".....kkkhkkk..", "....kmnmhmnmk.", "...kmaaaaaaamk", "..kkmaieaieamk", ".kmkmaeeaeeamk", "kmnmkpaaqaapmk", ".kmkkmmyymmmk.", ".kmabaabaaaak.", "..kaaaaaaaaak.", "...kaakakakak.", "....kk.k.k.k.."],
      sleep: ["........k.....", ".....kkkhkkk..", "....kmnmhmnmk.", "..kkmaaaaaaamk", ".kmkmakkakkamk", "kmnmkpaaqaapmk", ".kmabmmyymmmmk", ".kaaaaaaaaaaak", "..kkkkkkkkkkk."]
    },
    adult: {
      pal: { a: "#e8c46a", b: "#c89a3e", m: "#3f9a8c", n: "#7cd0bc", h: "#f4ecd2", y: "#f2d050", q: "#3a2418", c: "#f6e6b8", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["..........k......", ".......kkkhkkk...", "......kmnmhmnmk..", ".....kmnmhhhmnmk.", "....kmmaaaaaaammk", "..k.kmaaieaieaamk", ".kmkkmaaeeaeeaamk", "kmnmkmnpaaqaapnmk", "kmkmkkmmmyymmmmk.", "kmnkkmabaabaabcmk", ".kmmaabaabaabcck.", "..kabaabaabaacck.", "..kaaaaaaaaaaaak.", "..kaakaakkkaakaak", "..kbbkbbk.kbbkbbk", "...kk.kk...kk.kk."],
      blink: ["..........k......", ".......kkkhkkk...", "......kmnmhmnmk..", ".....kmnmhhhmnmk.", "....kmmaaaaaaammk", "..k.kmaaaaaaaaamk", ".kmkkmaakkakkaamk", "kmnmkmnpaaqaapnmk", "kmkmkkmmmyymmmmk.", "kmnkkmabaabaabcmk", ".kmmaabaabaabcck.", "..kabaabaabaacck.", "..kaaaaaaaaaaaak.", "..kaakaakkkaakaak", "..kbbkbbk.kbbkbbk", "...kk.kk...kk.kk."],
      step: ["..........k......", ".......kkkhkkk...", "......kmnmhmnmk..", ".....kmnmhhhmnmk.", "....kmmaaaaaaammk", "..k.kmaaieaieaamk", ".kmkkmaaeeaeeaamk", "kmnmkmnpaaqaapnmk", "kmkmkkmmmyymmmmk.", "kmnkkmabaabaabcmk", ".kmmaabaabaabcck.", "..kabaabaabaacck.", "..kaaaaaaaaaaaak.", "...kaakaakaakaak.", "...kbbkbbkbbkbbk.", "....kk.kk.kk.kk.."],
      sleep: ["..........k......", ".......kkkhkkk...", "......kmnmhmnmk..", ".....kmnmhhhmnmk.", "..k.kmmaaaaaaammk", ".kmkkmaakkakkaamk", "kmnmkmnpaaqaapnmk", "kmkmkmmmmyymmmmmk", "kmnaabaabaabaccmk", "kaaaaaaaaaaaaaak.", ".kkkkkkkkkkkkkk.."]
    }
  },
  bead_imugi: {
    name: "구슬 이무기",
    grade: 3,
    kind: "water",
    desc: "용이 되려고 여의주를 품고 사는 어린 이무기입니다. 구슬을 잃어버릴까 봐 잠도 감고 잡니다.",
    likes: "treat_honey",
    baby: {
      pal: { a: "#3a9a8a", b: "#2a6e6a", c: "#ece2b4", f: "#7ad8c0", g: "#f6f4ff", h: "#b8c8f8", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: [".......kkkkk..", "......kaaaaak.", ".....kafaaafak", ".....kaieaieak", ".....kaeeaeeak", "...kkkpacccapk", "..kbbakaccaggk", ".kbabaakaagghk", ".kaakbaaaakkk.", ".kbabkbbabk...", "..kkk.kkkk...."],
      blink: [".......kkkkk..", "......kaaaaak.", ".....kafaaafak", ".....kaaaaaaak", ".....kakkakkak", "...kkkpacccapk", "..kbbakaccaggk", ".kbabaakaagghk", ".kaakbaaaakkk.", ".kbabkbbabk...", "..kkk.kkkk...."],
      step: [".......kkkkk..", "......kaaaaak.", ".....kafaaafak", ".....kaieaieak", ".....kaeeaeeak", "..kkkkpacccapk", ".kbbakkaccaggk", "kbabaakaaagghk", ".kakkbaaaakkk.", ".kabkkbababk..", "..kk..kkkkk..."],
      sleep: [".......kkkkk..", "......kaaaaak.", ".....kafaaafak", "...kkkakkakkak", "..kbbapacccapk", ".kbabaabaagggk", "kbabkbaaaagghk", ".kababababkkk.", "..kkkkkkkk...."]
    },
    adult: {
      pal: { a: "#3a9a8a", b: "#2a6e6a", c: "#ece2b4", f: "#7ad8c0", g: "#f6f4ff", h: "#b8c8f8", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["..........k..k....", ".........kfkkfk...", "........kaaaaaak..", ".......kafaaaafak.", ".......kaieaaieak.", ".......kaeeaaeeak.", ".......kpaccccapk.", "..kk....kaccccak..", ".kbfk....kaccakkk.", ".kbak...kaacbkkggk", ".kbabkkkaaccbkgghk", "..kbaabaacccbkghhk", "..kbacccccccbkkkk.", "...kbbbbbbbbk.....", "....kkkkkkkk......"],
      blink: ["..........k..k....", ".........kfkkfk...", "........kaaaaaak..", ".......kafaaaafak.", ".......kaaaaaaaak.", ".......kakkaakkak.", ".......kpaccccapk.", "..kk....kaccccak..", ".kbfk....kaccakkk.", ".kbak...kaacbkkggk", ".kbabkkkaaccbkgghk", "..kbaabaacccbkghhk", "..kbacccccccbkkkk.", "...kbbbbbbbbk.....", "....kkkkkkkk......"],
      step: ["..........k..k....", ".........kfkkfk...", "........kaaaaaak..", ".......kafaaaafak.", ".......kaieaaieak.", ".......kaeeaaeeak.", ".......kpaccccapk.", "........kaccccak..", ".kk......kaccakkk.", "kfbkk...kaacbkkggk", ".kbabkkkaaccbkgghk", "..kbaabaacccbkghhk", "..kbacccccccbkkkk.", "...kbbbbbbbbk.....", "....kkkkkkkk......"],
      sleep: ["..........k..k....", ".........kfkkfk...", "........kaaaaaak..", ".......kafaaaafak.", "..kk...kakkaakkak.", ".kbfk..kpaccccapk.", ".kbabkkkaacccabkk.", "..kbaabaaccccbkggk", "..kbacccccccbkgghk", "...kbbbbbbbbk.khhk", "....kkkkkkkk...kk."]
    }
  },
  baby_sangun: {
    name: "아기 산군",
    grade: 3,
    kind: "breaker",
    desc: "산의 임금 범의 새끼입니다. 아직은 어흥 소리보다 하품 소리가 더 큽니다.",
    likes: "treat_meat",
    baby: {
      pal: { a: "#f0902a", d: "#2e1a10", c: "#fbf2e0", n: "#3a2418", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: [".....kk...kk..", "....kaakkkaak.", "..k.kaadadaak.", ".kdkkaieaieak.", "kak.kdeeaeedk.", "kdkkkpccnccpk.", ".kadaadaacccck", ".kaadaadaccak.", ".kaaaaaaaaaak.", ".kcckckkkckcck", "..kk.k...k.kk."],
      blink: [".....kk...kk..", "....kaakkkaak.", "..k.kaadadaak.", ".kdkkaaaaaaak.", "kak.kdkkakkdk.", "kdkkkpccnccpk.", ".kadaadaacccck", ".kaadaadaccak.", ".kaaaaaaaaaak.", ".kcckckkkckcck", "..kk.k...k.kk."],
      step: [".....kk...kk..", "....kaakkkaak.", "..k.kaadadaak.", ".kdkkaieaieak.", "kak.kdeeaeedk.", "kdkkkpccnccpk.", ".kadaadaacccck", ".kaadaadaccak.", ".kaaaaaaaaaak.", "..kcckckckcck.", "...kk.k.k.kk.."],
      sleep: [".....kk...kk..", "....kaakkkaak.", "....kaadadaak.", ".kkkkakkakkak.", "kdadkpccnccpk.", ".kadaadaadaaak", ".kaaaaaaaaaak.", "..kkkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#f0902a", d: "#2e1a10", c: "#fbf2e0", n: "#3a2418", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["..........kk...kk.", ".........kaakkkaak", "..k......kaadadaak", ".kdk.....kaieaieak", "kak......kdeeaeedk", "kdk......kpccnccpk", ".kakkkkkkkaccccak.", ".kdkaadaadaadcccak", "..kaadaadaadacccak", "..kaaadaadaadaaaak", "..kaaaaaaaaaaaaak.", "..kaakaakkkkaakaak", "..kcckcck..kcckcck", "...kk.kk....kk.kk."],
      blink: ["..........kk...kk.", ".........kaakkkaak", "..k......kaadadaak", ".kdk.....kaaaaaaak", "kak......kdkkakkdk", "kdk......kpccnccpk", ".kakkkkkkkaccccak.", ".kdkaadaadaadcccak", "..kaadaadaadacccak", "..kaaadaadaadaaaak", "..kaaaaaaaaaaaaak.", "..kaakaakkkkaakaak", "..kcckcck..kcckcck", "...kk.kk....kk.kk."],
      step: ["..........kk...kk.", ".........kaakkkaak", "..k......kaadadaak", ".kdk.....kaieaieak", "kak......kdeeaeedk", "kdk......kpccnccpk", ".kakkkkkkkaccccak.", ".kdkaadaadaadcccak", "..kaadaadaadacccak", "..kaaadaadaadaaaak", "..kaaaaaaaaaaaaak.", "...kaakaakkaakaak.", "..kcck.kcckcckkcck", "...kk...kk.kk..kk."],
      sleep: ["..........kk...kk.", ".........kaakkkaak", ".........kaadadaak", ".........kakkakkak", ".kkk.....kdaaaaadk", "kdadkkkkkkpccnccpk", ".kadaadaadaadcccak", ".kaaadaadaadaaaaak", "..kaaaaaaaaaaaaak.", "...kkkkkkkkkkkkk.."]
    }
  },
  moon_rabbit: {
    name: "달토끼",
    grade: 3,
    kind: "sky",
    desc: "달에서 떡방아를 찧다 내려왔다는 토끼입니다. 이마에 초승달 무늬가 은은하게 빛납니다.",
    likes: "treat_rice",
    baby: {
      pal: { a: "#f4f0fa", c: "#cfc6e0", p: "#f2a8bc", y: "#f2d060", n: "#b07a42", r: "#fbf8ee", g: "#7ab060", e: "#2a2a4a", i: "#8a8ab0", k: "#1a120e" },
      idle: [".....kk.kk...", "....kaakaak..", "....kpakpak..", "....kpakpak..", "...kaaayaaak.", "...kaieaieak.", "...kaeeaeeak.", "...kpaanaapk.", "..kkkcaaarrgk", ".kccaaaaaakk.", "..kkaaakaaak.", "....kkk.kkk.."],
      blink: [".....kk.kk...", "....kaakaak..", "....kpakpak..", "....kpakpak..", "...kaaayaaak.", "...kaaaaaaak.", "...kakkakkak.", "...kpaanaapk.", "..kkkcaaarrgk", ".kccaaaaaakk.", "..kkaaakaaak.", "....kkk.kkk.."],
      step: [".....kk.kk...", "....kaakaak..", "....kpakpak..", "....kpakpak..", "...kaaayaaak.", "...kaieaieak.", "...kaeeaeeak.", "...kpaanaapk.", "..kkkcaaarrgk", ".kccaaaaaakk.", "..kaaakkkaak.", "...kkk...kk.."],
      sleep: ["....kkkk.....", "...kaaaakk...", "..kapppaaak..", "...kaaayaaak.", "...kakkakkak.", "..kkpaanaapk.", ".kcccaaaarrgk", "kccaaaaaaaak.", ".kkkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#f4f0fa", c: "#cfc6e0", p: "#f2a8bc", y: "#f2d060", n: "#b07a42", e: "#2a2a4a", i: "#8a8ab0", k: "#1a120e" },
      idle: [".....kk.kk.....", "....kaakaak.kk.", "....kpakpakknnk", "....kpakpakknnk", "...kaaaayaaknk.", "...kaieaieaknk.", "...kaeeaeeaknk.", "...kpaanaapnk..", ".kk.kcaaaank...", "kcckkaaaaank...", "kccaaaaaaank...", ".kkaaaaaaknk...", "...kaakaaknk...", "..kaaakaaannk..", "...kkk.kkkkk..."],
      blink: [".....kk.kk.....", "....kaakaak.kk.", "....kpakpakknnk", "....kpakpakknnk", "...kaaaayaaknk.", "...kaaaaaaaknk.", "...kakkakkaknk.", "...kpaanaapnk..", ".kk.kcaaaank...", "kcckkaaaaank...", "kccaaaaaaank...", ".kkaaaaaaknk...", "...kaakaaknk...", "..kaaakaaannk..", "...kkk.kkkkk..."],
      step: [".....kk.kk.....", "....kaakaak....", "....kpakpak.kk.", "....kpakpakknnk", "...kaaaayaaknnk", "...kaieaieankk.", "...kaeeaeeank..", "...kpaanaapnk..", ".kk.kcaaaank...", "kcckkaaaaank...", "kccaaaaaaank...", ".kkaaaaaaknk...", "..kaakkkaank...", ".kaaak.kaannk..", "..kkk...kkkk..."],
      sleep: [".....kkkk......", "....kaaaakk....", "...kapppaaak...", "...kaaaayaak...", "...kakkakkak...", ".kkkpaanaapk...", "kcckcaaaaaak...", "kccaaaaaaaaakk.", ".kaaaaaaaaaannk", "..kkkkkkkkkkkk."]
    }
  },
  wooden_doll: {
    name: "목각 인형 정령",
    grade: 3,
    kind: "wood",
    desc: "오래된 느티나무 가지로 깎은 인형에 나무 정령이 깃들었습니다. 머리의 새싹이 기분 따라 흔들립니다.",
    likes: "treat_honey",
    baby: {
      pal: { a: "#c8945a", b: "#94643a", c: "#e2b884", l: "#6ab04a", m: "#3e7a2e", s: "#b8f4a8", e: "#3a2414", i: "#f6e6c8", p: "#e88a7a", k: "#1a120e" },
      idle: ["....kkk....", "...klmlk...", "..kacaaak..", ".kacaaaaak.", ".kaieaieak.", ".kaeeaeeak.", ".kpaabaapk.", ".skaaaaak..", ".kacccccak.", "..kbbbbbk..", "..kcckcck..", "...kk.kk..."],
      blink: ["....kkk....", "...klmlk...", "..kacaaak..", ".kacaaaaak.", ".kaaaaaaak.", ".kakkakkak.", ".kpaabaapk.", ".skaaaaak..", ".kacccccak.", "..kbbbbbk..", "..kcckcck..", "...kk.kk..."],
      step: ["...kkk.....", "..klmlkk...", "..kacaaak..", ".kacaaaaak.", ".kaieaieak.", ".kaeeaeeak.", ".kpaabaapk.", "..kaaaaaks.", ".kacccccak.", "..kbbbbbk..", ".kcckkkcck.", "..kk...kk.."],
      sleep: ["....kkk....", "...klmlk...", "..kacaaak..", ".kacaaaaak.", ".kakkakkak.", ".kpaabaapk.", "kaccccccak.", "kabbbbbbcak", ".kkkkkkkkk."]
    },
    adult: {
      pal: { a: "#c8945a", b: "#94643a", c: "#e2b884", l: "#6ab04a", m: "#3e7a2e", s: "#b8f4a8", e: "#3a2414", i: "#f6e6c8", p: "#e88a7a", k: "#1a120e" },
      idle: ["....k.kkk.k...", "...klklmlklk..", "....klmmmlk...", "....kaaaaak...", "...kacaaaaak..", "..kacaaaaaaak.", "..kaaieaieaak.", "..kaaeeaeeaak.", "..kapaabaapak.", ".s.kabbbbbak..", "...kaaaaaaak..", "..kaacccccaak.", ".kabkcbcbckbak", "..kkkbbbbbkkk.", "...kccckccck..", "....kkk.kkk..."],
      blink: ["....k.kkk.k...", "...klklmlklk..", "....klmmmlk...", "....kaaaaak...", "...kacaaaaak..", "..kacaaaaaaak.", "..kaaaaaaaaak.", "..kaakkakkaak.", "..kapaabaapak.", ".s.kabbbbbak..", "...kaaaaaaak..", "..kaacccccaak.", ".kabkcbcbckbak", "..kkkbbbbbkkk.", "...kccckccck..", "....kkk.kkk..."],
      step: ["...k.kkk.k....", "..klklmlklk...", "...kklmmmlk...", "....kaaaaak...", "...kacaaaaak..", "..kacaaaaaaak.", "..kaaieaieaak.", "..kaaeeaeeaak.", "..kapaabaapak.", "...kabbbbbaks.", "...kaaaaaaak..", "..kaacccccaak.", ".kabkcbcbckbak", "..kkkbbbbbkkk.", "..kccckkkccck.", "...kkk...kkk.."],
      sleep: ["....k.kkk.k...", "...klklmlklk..", "....klmmmlk...", "....kaaaaak...", "...kacaaaaak..", "..kacaaaaaaak.", "..kaakkakkaak.", "..kapaabaapak.", ".kaaabbbbbaak.", "kabcbcbcbcbcak", "kabbbbbbbbbbck", ".kkkkkkkkkkkk."]
    }
  },
  baby_bulgasari: {
    name: "아기 불가사리",
    grade: 4,
    kind: "giant",
    desc: "밥풀로 빚어졌다는 쇠 먹는 짐승의 새끼입니다. 바늘 같은 털이 아직 말랑해서 안아 줄 만합니다.",
    likes: "treat_rice",
    baby: {
      pal: { a: "#7c8496", b: "#596070", c: "#aab2c0", n: "#dfe5ee", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["..k.k.k.......", ".knknknk....k.", "knnnnnbkkkkkbk", "knbnbnaaaaaaak", ".knbnbaieaieak", "..kbbbaeeaeeak", ".kaaaapaacaapk", ".kaaaaaaacaak.", ".kaaaaaakcck..", ".kbbkbbkkbbk..", "..kk.kk..kk..."],
      blink: ["..k.k.k.......", ".knknknk....k.", "knnnnnbkkkkkbk", "knbnbnaaaaaaak", ".knbnbaaaaaaak", "..kbbbakkakkak", ".kaaaapaacaapk", ".kaaaaaaacaak.", ".kaaaaaakcck..", ".kbbkbbkkbbk..", "..kk.kk..kk..."],
      step: [".k.k.k........", "knknknk.....k.", "knnnnnbkkkkkbk", "knbnbnaaaaaaak", ".knbnbaieaieak", "..kbbbaeeaeeak", ".kaaaapaacaapk", ".kaaaaaaaacck.", ".kaaaaaakack..", "..kbbkbbkbbk..", "...kk.kk.kk..."],
      sleep: ["..k.k.k.......", ".knknknk....k.", "knnnnnbkkkkkbk", "knbnbnaaaaaaak", ".knbnbakkakkak", ".kabbbpaacaapk", ".kaaaaaaaacaak", ".kaaaaaaaaacck", "..kkkkkkkkkkk."]
    },
    adult: {
      pal: { a: "#7c8496", b: "#596070", c: "#aab2c0", n: "#dfe5ee", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["...k.k.k.k........", "..knknknknk....k..", ".knnnnnnnnbkkkkbk.", "knnbnbnbnbaaaaaak.", "knbnbnbnbaaaaaaaak", ".knbnbnbnaieaaieak", "..kbbbbbnaeeaaeeak", "..kaaaaaaapaccapak", "..kaaaaaaaaaccaak.", ".kaaaaaaaaaaaccak.", ".kaacaaaaaaaakcck.", ".kaacaaaaaaak.kck.", ".kaaaaaaaaaak..k..", ".kbbbkbbkkbbbk....", ".kbbbkbbkkbbbk....", "..kkk.kk..kkk....."],
      blink: ["...k.k.k.k........", "..knknknknk....k..", ".knnnnnnnnbkkkkbk.", "knnbnbnbnbaaaaaak.", "knbnbnbnbaaaaaaaak", ".knbnbnbnaaaaaaaak", "..kbbbbbnakkaakkak", "..kaaaaaaapaccapak", "..kaaaaaaaaaccaak.", ".kaaaaaaaaaaaccak.", ".kaacaaaaaaaakcck.", ".kaacaaaaaaak.kck.", ".kaaaaaaaaaak..k..", ".kbbbkbbkkbbbk....", ".kbbbkbbkkbbbk....", "..kkk.kk..kkk....."],
      step: ["..k.k.k.k.........", ".knknknknkk....k..", ".knnnnnnnnbkkkkbk.", "knnbnbnbnbaaaaaak.", "knbnbnbnbaaaaaaaak", ".knbnbnbnaieaaieak", "..kbbbbbnaeeaaeeak", "..kaaaaaaapaccapak", "..kaaaaaaaaaccaak.", ".kaaaaaaaaaaaacck.", ".kaacaaaaaaaakcck.", ".kaacaaaaaaakkck..", ".kaaaaaaaaaak.k...", "..kbbbkbbkbbbk....", "..kbbbkbbkbbbk....", "...kkk.kk.kkk....."],
      sleep: ["...k.k.k.k........", "..knknknknk....k..", ".knnnnnnnnbkkkkbk.", "knnbnbnbnbaaaaaak.", "knbnbnbnbaaaaaaaak", ".knbnbnbnakkaakkak", ".kabbbbbnaaaaaaaak", ".kaaaaaaaapaccapak", "kaacaaaaaaaaccaak.", "kaacaaaaaaaaaacck.", ".kaaaaaaaaaaaaacck", "..kkkkkkkkkkkkkkk."]
    }
  },
  samjogo_chick: {
    name: "삼족오 새끼",
    grade: 4,
    kind: "sky",
    desc: "해 속에 산다는 세 발 까마귀의 새끼입니다. 깃털 끝이 햇살처럼 금빛으로 반짝입니다.",
    likes: "treat_honey",
    baby: {
      pal: { a: "#34364c", h: "#565a80", g: "#f2c440", y: "#e8a030", e: "#f2c440", i: "#ffffff", p: "#c88aa0", k: "#1a120e" },
      idle: [".......k..k...", "......kgkkgk..", ".......kggk...", "......kaaaak..", ".....kaaaaaak.", "....kaaaaieak.", ".kk.kaaaaeeyyk", "kagkkgaaaaapk.", ".kaggggaaaaak.", "..kaahhaaaak..", "...kkykykyk...", ".....k.k.k...."],
      blink: [".......k..k...", "......kgkkgk..", ".......kggk...", "......kaaaak..", ".....kaaaaaak.", "....kaaaaaaak.", ".kk.kaaaaggyyk", "kagkkgaaaaapk.", ".kaggggaaaaak.", "..kaahhaaaak..", "...kkykykyk...", ".....k.k.k...."],
      step: [".......k..k...", "......kgkkgk..", ".......kggk...", "......kaaaak..", ".....kaaaaaak.", "....kaaaaieak.", ".kk.kaaaaeeyyk", "kagkkgaaaaapk.", ".kaggggaaaaak.", "..kaahhaaaak..", "...kykkykkyk..", "....k..k..k..."],
      sleep: [".......k..k...", "......kgkkgk..", ".......kggk...", "......kaaaak..", ".....kaaaaaak.", ".kk.kaaaagggyk", "kagkkgaaaaapk.", ".kaggggaaaaak.", "..kaaaaaaaak..", "...kkkkkkkk..."]
    },
    adult: {
      pal: { a: "#34364c", h: "#565a80", g: "#f2c440", y: "#e8a030", r: "#cf3a2c", o: "#f08a3a", e: "#f2c440", i: "#ffffff", p: "#c88aa0", k: "#1a120e" },
      idle: ["...kkkk...........", "..krrrrk....k..k..", ".krroorrk..kgkkgk.", "krroooorrk.kkggk..", "krroooorrkkaaaak..", "krroooorrkaaaaaak.", ".krroorrkaaaaaieak", "..krrrrkkaaaaaeeyk", ".kkkkkkggaaaaaapk.", "kagkkggahhaaaaak..", ".kagggaahhhaaaak..", "..kaaaaaaaaaaak...", "...kkkaaaaaaak....", "......kykykykk....", ".....kyykyykyyk...", "......kk.kk.kk...."],
      blink: ["...kkkk...........", "..krrrrk....k..k..", ".krroorrk..kgkkgk.", "krroooorrk.kkggk..", "krroooorrkkaaaak..", "krroooorrkaaaaaak.", ".krroorrkaaaaaaaak", "..krrrrkkaaaaaggyk", ".kkkkkkggaaaaaapk.", "kagkkggahhaaaaak..", ".kagggaahhhaaaak..", "..kaaaaaaaaaaak...", "...kkkaaaaaaak....", "......kykykykk....", ".....kyykyykyyk...", "......kk.kk.kk...."],
      step: ["...kkkk...........", "..krrrrk....k..k..", ".krroorrk..kgkkgk.", "krroooorrk.kkggk..", "krroooorrkkaaaak..", "krroooorrkaaaaaak.", ".krroorrkaaaaaieak", "..krrrrkkaaaaaeeyk", ".kkkkkkggaaaaaapk.", "kagkkggahhaaaaak..", ".kagggaahhhaaaak..", "..kaaaaaaaaaaak...", "...kkkaaaaaaak....", ".....kykkykkyk....", "....kyykkyykyyk...", ".....kk..kk.kk...."],
      sleep: ["...kkkk...........", "..krrrrk....k..k..", ".krroorrk..kgkkgk.", "krroooorrk.kkggk..", "krroooorrkkaaaak..", "krroooorrkaaaaaak.", ".krroorrkaaaaaaaak", "..krrrrkkaaaaaggyk", ".kkkkkkggaaaaaapk.", "kagkkggahhaaaaak..", ".kagggaahhhaaaak..", "..kaaaaaaaaaaak...", "...kaaaaaaaaaak...", "....kkkkkkkkkk...."]
    }
  },
  baby_girin: {
    name: "아기 기린",
    grade: 4,
    kind: "sky",
    desc: "사슴 몸에 외뿔과 비늘을 지닌 상서로운 기린의 새끼입니다. 풀 한 포기도 밟지 않으려 사뿐사뿐 걷습니다.",
    likes: "treat_herb",
    baby: {
      pal: { a: "#ecc462", s: "#c8983a", m: "#4aa090", h: "#f6f0d8", c: "#f8ecc4", n: "#8a5a30", f: "#5a4030", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: [".......k.k.k..", ".....kkakhkak.", "....kmaaaaaaak", "...kmmaieaieak", ".k.kmmaeeaeeak", "kmkmmkpacncapk", ".kmmasaaccckk.", ".kaasasaaaak..", "..kasasaaask..", "..kakakkakak..", "..kfkfkkfkfk..", "...k.k..k.k..."],
      blink: [".......k.k.k..", ".....kkakhkak.", "....kmaaaaaaak", "...kmmaaaaaaak", ".k.kmmakkakkak", "kmkmmkpacncapk", ".kmmasaaccckk.", ".kaasasaaaak..", "..kasasaaask..", "..kakakkakak..", "..kfkfkkfkfk..", "...k.k..k.k..."],
      step: [".......k.k.k..", ".....kkakhkak.", "....kmaaaaaaak", "...kmmaieaieak", ".k.kmmaeeaeeak", "kmkmmkpacncapk", ".kmmasaaccckk.", ".kaasasaaaak..", "..kasasaaask..", "...kakakakak..", "...kfkfkfkkfk.", "....k.k.k..k.."],
      sleep: [".......k.k.k..", ".....kkakhkak.", "....kmaaaaaaak", ".k.kmmakkakkak", "kmkmmkpacncapk", ".kmmasaacccck.", ".kaasasasaaaak", "..kffaaaaaffk.", "...kkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#ecc462", s: "#c8983a", m: "#4aa090", h: "#f6f0d8", c: "#f8ecc4", n: "#8a5a30", f: "#5a4030", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["............k.....", "..........kkhkk...", "........kkakhkak..", ".......kmaaaaaaak.", "......kmmaieaieak.", "......kmmaeeaeeak.", ".....kmmmpacncapk.", ".k....kkmmaaccak..", "kmk.kkmmmaaaccck..", "kmmkaaasasasaack..", ".kmmasasasasaaak..", "..kkasasasasaask..", "...kaakakkkkakak..", "...kakkak..kakkak.", "...kfkkfk..kfkkfk.", "....k..k....k..k.."],
      blink: ["............k.....", "..........kkhkk...", "........kkakhkak..", ".......kmaaaaaaak.", "......kmmaaaaaaak.", "......kmmakkakkak.", ".....kmmmpacncapk.", ".k....kkmmaaccak..", "kmk.kkmmmaaaccck..", "kmmkaaasasasaack..", ".kmmasasasasaaak..", "..kkasasasasaask..", "...kaakakkkkakak..", "...kakkak..kakkak.", "...kfkkfk..kfkkfk.", "....k..k....k..k.."],
      step: ["............k.....", "..........kkhkk...", "........kkakhkak..", ".......kmaaaaaaak.", "......kmmaieaieak.", "......kmmaeeaeeak.", ".....kmmmpacncapk.", ".k....kkmmaaccak..", "kmk.kkmmmaaaccck..", "kmmkaaasasasaack..", ".kmmasasasasaaak..", "..kkasasasasaask..", "...kaakakkkakak...", "..kakk.kakak.kak..", "..kfk..kfkfk.kfk..", "...k....k.k...k..."],
      sleep: ["............k.....", "..........kkhkk...", "........kkakhkak..", ".......kmaaaaaaak.", "......kmmakkakkak.", ".k...kmmmpacncapk.", "kmk.kkmmmaaacckk..", "kmmkaaasasasaacck.", ".kmmasasasasasaaak", "..kkafasasasaafak.", "....kffffffffffk..", ".....kkkkkkkkkk..."]
    }
  },
  little_cheongryong: {
    name: "꼬마 청룡",
    grade: 4,
    kind: "water",
    desc: "동쪽 하늘을 지킨다는 푸른 용의 새끼입니다. 재채기를 하면 작은 구름이 퐁 하고 나옵니다.",
    likes: "treat_fish",
    baby: {
      pal: { a: "#3a7ad8", c: "#f2e2a4", h: "#f0c850", f: "#7ad8e8", w: "#f2e2a4", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", n: "#1e3a78", k: "#1a120e" },
      idle: ["......k.k.k.k.", ".....khkhkhkhk", "......khaaahk.", ".....kaaaaaaak", "..k..kaieaieak", ".kfk.kaeeaeeak", "kafkkwpacncapk", "kaafkaaccccck.", ".kaafaaccccak.", "..kaaaaaccak..", "...kkaakkaak..", ".....kk..kk..."],
      blink: ["......k.k.k.k.", ".....khkhkhkhk", "......khaaahk.", ".....kaaaaaaak", "..k..kaaaaaaak", ".kfk.kakkakkak", "kafkkwpacncapk", "kaafkaaccccck.", ".kaafaaccccak.", "..kaaaaaccak..", "...kkaakkaak..", ".....kk..kk..."],
      step: ["......k.k.k.k.", ".....khkhkhkhk", "......khaaahk.", ".....kaaaaaaak", "..k..kaieaieak", ".kfk.kaeeaeeak", "kafkkwpacncapk", "kaafkaaccccck.", ".kaafaaccccak.", "..kaaaaaccak..", "...kaakkaak...", "....kk..kk...."],
      sleep: ["......k.k.k.k.", ".....khkhkhkhk", "......khaaahk.", "..k..kaaaaaaak", ".kfk.kakkakkak", "kafkkwpacncapk", "kaafaaacccccak", ".kaaaaaaacccck", "..kkkkkkkkkkk."]
    },
    adult: {
      pal: { a: "#3a7ad8", b: "#2a58a8", c: "#f2e2a4", h: "#f0c850", f: "#7ad8e8", w: "#f2e2a4", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", n: "#1e3a78", k: "#1a120e" },
      idle: ["..........k.k.k.k.", ".........khkhkhkhk", "..........khaaahk.", ".........kaaaaaaak", "........kfaieaieak", ".......kffaeeaeeak", ".......kffpacncapk", "...k..kffaaacccawk", "..kfkkffaaaccccwk.", ".kfafkfaaaccccck..", "kfabaffaabccccak..", "kfabkkaabbccccaak.", "kfabkkabkaaccakk..", ".kfabbakkaakkaak..", "..kbbkkkbbbkkbbbk.", "...kk...kkk..kkk.."],
      blink: ["..........k.k.k.k.", ".........khkhkhkhk", "..........khaaahk.", ".........kaaaaaaak", "........kfaaaaaaak", ".......kffakkakkak", ".......kffpacncapk", "...k..kffaaacccawk", "..kfkkffaaaccccwk.", ".kfafkfaaaccccck..", "kfabaffaabccccak..", "kfabkkaabbccccaak.", "kfabkkabkaaccakk..", ".kfabbakkaakkaak..", "..kbbkkkbbbkkbbbk.", "...kk...kkk..kkk.."],
      step: ["..........k.k.k.k.", ".........khkhkhkhk", "..........khaaahk.", ".........kaaaaaaak", "........kfaieaieak", ".......kffaeeaeeak", ".......kffpacncapk", "...k..kffaaacccawk", "..kfkkffaaaccccwk.", ".kfafkfaaaccccck..", "kfabaffaabccccak..", "kfabkkaabbccccaak.", "kfabkkabkaaccakk..", ".kfabbakaakkkaak..", "..kbbkkbbbk.kbbbk.", "...kk..kkk...kkk.."],
      sleep: ["..........k.k.k.k.", ".........khkhkhkhk", "..........khaaahk.", ".........kaaaaaaak", "........kfakkakkak", "....k..kffpacncapk", "...kfkkffaaacccawk", "..kfafkfaaaccccwk.", ".kfabaffaaacccccck", "kfabkaaabbbccccaak", ".kfabbaaaaaaaaaak.", "..kkkkkkkkkkkkkk.."]
    }
  },
  little_jangseung: {
    name: "꼬마 장승",
    grade: 4,
    kind: "ward",
    desc: "마을 어귀를 지키던 천하대장군이 아기만 하게 줄어들었습니다. 눈을 부라려도 하나도 무섭지 않습니다.",
    likes: "treat_herb",
    baby: {
      pal: { a: "#c89058", b: "#7a4a26", h: "#2a2630", g: "#4a4452", w: "#f6f0e0", e: "#2a1a14", i: "#ffffff", p: "#e8705a", k: "#1a120e" },
      idle: ["...kkkkk...", "..khhhhhk..", ".kghhhhhgk.", "khhhhhhhhhk", ".kbbbabbbk.", ".kaieaieak.", ".kaeeaeeak.", ".kpaabaapk.", ".kawkwkwak.", ".kaabbbaak.", "..kbkkkbk..", "...k...k..."],
      blink: ["...kkkkk...", "..khhhhhk..", ".kghhhhhgk.", "khhhhhhhhhk", ".kbbbabbbk.", ".kaaaaaaak.", ".kakkakkak.", ".kpaabaapk.", ".kawkwkwak.", ".kaabbbaak.", "..kbkkkbk..", "...k...k..."],
      step: ["...kkkkk...", "..khhhhhk..", ".kghhhhhgk.", "khhhhhhhhhk", ".kbbbabbbk.", ".kaieaieak.", ".kaeeaeeak.", ".kpaabaapk.", ".kawkwkwak.", ".kaabbbaak.", "..kkbkbkk..", "....k.k...."],
      sleep: ["...kkkkk...", "..khhhhhk..", ".kghhhhhgk.", "khhhhhhhhhk", ".kbbbabbbk.", ".kakkakkak.", ".kpaabaapk.", ".kabbbbbak.", ".kaabbbaak.", "kaaaabaaaak", ".kkkkkkkkk."]
    },
    adult: {
      pal: { a: "#c89058", b: "#7a4a26", h: "#2a2630", g: "#4a4452", w: "#f6f0e0", e: "#2a1a14", i: "#ffffff", p: "#e8705a", k: "#1a120e" },
      idle: ["....kkkkk....", "...khhhhhk...", ".kkghhhhhgkk.", "khhhhhhhhhhhk", ".kabbbabbbak.", ".kaaieaieaak.", ".kaaeeaeeaak.", ".kapaabaapak.", ".kaawkwkwaak.", ".kaabbbbbaak.", "..kabbbbbak..", "..kaaaaaaak..", "..kaabbbaak..", "..kaaabaaak..", "...kbkkkbk...", "....k...k...."],
      blink: ["....kkkkk....", "...khhhhhk...", ".kkghhhhhgkk.", "khhhhhhhhhhhk", ".kabbbabbbak.", ".kaaaaaaaaak.", ".kaakkakkaak.", ".kapaabaapak.", ".kaawkwkwaak.", ".kaabbbbbaak.", "..kabbbbbak..", "..kaaaaaaak..", "..kaabbbaak..", "..kaaabaaak..", "...kbkkkbk...", "....k...k...."],
      step: ["....kkkkk....", "...khhhhhk...", ".kkghhhhhgkk.", "khhhhhhhhhhhk", ".kabbbabbbak.", ".kaaieaieaak.", ".kaaeeaeeaak.", ".kapaabaapak.", ".kaawkwkwaak.", ".kaabbbbbaak.", "..kabbbbbak..", "..kaaaaaaak..", "..kaabbbaak..", "..kaaabaaak..", "...kkbkbkk...", ".....k.k....."],
      sleep: ["....kkkkk....", "...khhhhhk...", ".kkghhhhhgkk.", "khhhhhhhhhhhk", ".kabbbabbbak.", ".kaakkakkaak.", ".kapaabaapak.", ".kaabbbbbaak.", ".kaabbbbbaak.", ".kaaaaaaaaak.", "kaaabbbbbaaak", ".kkkkkkkkkkk."]
    }
  },
  baby_baektaek: {
    name: "아기 백택",
    grade: 5,
    kind: "ward",
    desc: "세상 모든 요괴의 이름을 안다는 백택의 새끼입니다. 몸 곳곳의 눈이 한꺼번에 깜빡이면 방 안이 환해집니다.",
    likes: "treat_herb",
    baby: {
      pal: { a: "#f8f6f0", c: "#d8d4e8", h: "#e8c860", m: "#b8c8f4", g: "#e4f2ff", e: "#3a3a6e", i: "#8a8ac8", p: "#f3a0a0", n: "#8a8aa8", k: "#1a120e" },
      idle: [".......k...k..", "..g...khkkkhk.", ".ggg..khaiahk.", ".....kaaaeaaak", ".....kaieaieak", ".....kaeeaeeak", "..kkkkpaanaapk", ".kmcaieaaammg.", "kmccaeeaaaamk.", ".kccaaaaaaaak.", ".kcckcckkcckck", "..kk.kk..kk.k."],
      blink: [".......k...k..", "..g...khkkkhk.", ".ggg..khaaahk.", ".....kaaaaaaak", ".....kaaaaaaak", ".....kakkkkkak", "..kkkkpaanaapk", ".kmcaaaaaammg.", "kmccakkaaaamk.", ".kccaaaaaaaak.", ".kcckcckkcckck", "..kk.kk..kk.k."],
      step: [".......k...k..", "..g...khkkkhk.", ".ggg..khaiahk.", ".....kaaaeaaak", ".....kaieaieak", ".....kaeeaeeak", "..kkkkpaanaapk", ".kmcaieaaammg.", "kmccaeeaaaamk.", ".kccaaaaaaaak.", "..kcckckcckck.", "...kk.k.kk.k.."],
      sleep: [".......k...k..", "......khkkkhk.", "......khaaahk.", ".....kaaakaaak", "..kkkkakkakkak", ".kmcaapaanaapk", "kmccakkaaammmk", ".kccaaaaaaaaak", "..kkkkkkkkkkk."]
    },
    adult: {
      pal: { a: "#f8f6f0", c: "#d8d4e8", h: "#e8c860", m: "#b8c8f4", g: "#e4f2ff", e: "#3a3a6e", i: "#8a8ac8", p: "#f3a0a0", n: "#8a8aa8", k: "#1a120e" },
      idle: ["............k...k.", ".g.........khkkkhk", "...g......khhkhhk.", "..........khaiahk.", ".........kaaaeaaak", ".........kaieaieak", ".........kaeeaeeak", ".k.......kpaanaapk", "kmk.kkkkkmmmmmmkk.", "kmmkaaaaaaaaammg..", "kmkaaieaaieaammk..", "kmkaaeeaaeeaaamk..", ".kaaaaaaaaaaaaak..", ".kacaaaaaaaaacak..", ".kcckcckkkcckcck..", "..kk.kk...kk.kk..."],
      blink: ["............k...k.", ".g.........khkkkhk", "...g......khhkhhk.", "..........khaaahk.", ".........kaaaaaaak", ".........kaaaaaaak", ".........kakkkkkak", ".k.......kpaanaapk", "kmk.kkkkkmmmmmmkk.", "kmmkaaaaaaaaammg..", "kmkaaaaaaaaaammk..", "kmkaakkaakkaaamk..", ".kaaaaaaaaaaaaak..", ".kacaaaaaaaaacak..", ".kcckcckkkcckcck..", "..kk.kk...kk.kk..."],
      step: ["............k...k.", ".g.........khkkkhk", "...g......khhkhhk.", "..........khaiahk.", ".........kaaaeaaak", ".........kaieaieak", ".........kaeeaeeak", ".k.......kpaanaapk", "kmk.kkkkkmmmmmmkk.", "kmmkaaaaaaaaammg..", "kmkaaieaaieaammk..", "kmkaaeeaaeeaaamk..", ".kaaaaaaaaaaaaak..", ".kacaaaaaaaaacak..", ".kcckkkcckcckkcck.", "..kk...kk.kk..kk.."],
      sleep: ["............k...k.", "...........khkkkhk", "..........khhkhhk.", "..........khaaahk.", ".........kaaakaaak", ".k.......kakkakkak", "kmk.kkkkkkpaanaapk", "kmmkaaaaaaaammmmk.", "kmkaakkaakkaammk..", "kmkaaaaaaaaaaamk..", ".kaaaaaaaaaaaaaak.", "..kkkkkkkkkkkkkk.."]
    }
  },
  gwiheo_butterfly: {
    name: "귀허 나비",
    grade: 5,
    kind: "ghost",
    desc: "귀허의 검푸른 바다 위를 날던 나비가 길을 잃고 따라왔습니다. 날갯짓마다 물빛 가루가 흩날립니다.",
    likes: "treat_honey",
    baby: {
      pal: { d: "#1a2a5a", b: "#2a5aa0", t: "#3ac0c8", g: "#c8f8ff", s: "#9fe8ff", a: "#20203a", c: "#d8d4f0", e: "#20203a", i: "#8a88b0", p: "#f3a0a0", k: "#1a120e" },
      idle: ["..kkk...k...k.", ".kdddk.kak.kak", "kdbbbdk.kakak.", "kdbtgbdkcccck.", "kdbttbdcieciek", ".kdbbbdceeceek", "..kddddapcccpk", ".kdbtbdaakkkk.", ".kdbgbdkak.s..", "..kdddk.k.....", "...kkk........"],
      blink: ["..kkk...k...k.", ".kdddk.kak.kak", "kdbbbdk.kakak.", "kdbtgbdkcccck.", "kdbttbdcccccck", ".kdbbbdckkckk.", "..kddddapcccpk", ".kdbtbdaakkkk.", ".kdbgbdkak.s..", "..kdddk.k.....", "...kkk........"],
      step: ["..kk....k...k.", ".kddk..kak.kak", "kdbbdk..kakak.", "kdbtgdkkcccck.", "kdbttdkcieciek", "kdbbtdkceeceek", ".kddddkapcccpk", "..kdbdaakkkkk.", "..kdgdkkak....", "...kdk..k..s..", "....k........."],
      sleep: ["...kkk........", "..kdddk.......", ".kdbbbdkk..k..", ".kdbtbdkakkak.", ".kdbgtdkkaak..", ".kdbttbdcccck.", "..kdbbdckkckk.", "..kddddacccpk.", "...kkkkkkkkk.."]
    },
    adult: {
      pal: { d: "#1a2a5a", b: "#2a5aa0", t: "#3ac0c8", g: "#c8f8ff", s: "#9fe8ff", a: "#20203a", c: "#d8d4f0", e: "#20203a", i: "#8a88b0", p: "#f3a0a0", k: "#1a120e" },
      idle: ["..kkkk......k...k.", ".kddddkk...kak.kak", "kdbbbbddk...kakak.", "kdbttgbbdk.kcccck.", "kdbtgttbbdkcieciek", "kdbbttbbbdkceeceek", ".kdbbbbbbdaapcccpk", "..kdddddddaakkkkk.", "..kdbbtbbdak......", ".kdbtgtbdkak......", ".kdbbtbdk.k..s....", "..kdbbdk..........", "...kddk....s......", "....kk............"],
      blink: ["..kkkk......k...k.", ".kddddkk...kak.kak", "kdbbbbddk...kakak.", "kdbttgbbdk.kcccck.", "kdbtgttbbdkcccccck", "kdbbttbbbdkckkckk.", ".kdbbbbbbdaapcccpk", "..kdddddddaakkkkk.", "..kdbbtbbdak......", ".kdbtgtbdkak......", ".kdbbtbdk.k..s....", "..kdbbdk..........", "...kddk....s......", "....kk............"],
      step: ["..kkk.......k...k.", ".kdddk.....kak.kak", "kdbbbdk.....kakak.", "kdbtgbdk...kcccck.", "kdbttgbdk.kcieciek", "kdbbttbdkkkceeceek", ".kdbbbbdddaapcccpk", "..kddddddaakkkkkk.", "...kdbtbdak.......", "..kdbtgbdkak......", "..kdbbbdk.k.......", "...kdbdk....s.....", "....kdk...........", ".....k............"],
      sleep: ["....kk............", "...kddk...........", "..kdbbdk..........", "..kdbtbdk...k...k.", "..kdbgtbdk.kak.kak", "..kdbttbdk..kakak.", "..kdbbbbdk.kcccck.", "...kdbbbbdkckkckk.", "...kddddddkacccpk.", "....kkkkkkaakkkk..", "..........kk......"]
    }
  },
  cheese_cat: {
    name: "누렁 줄고양이",
    grade: 1,
    kind: "shadow",
    desc: "노란 털에 주황 줄무늬가 진 고양이입니다. 장터 사람들은 「호박이」라고 부릅니다. 밥그릇 소리만 나면 어디서든 달려옵니다.",
    likes: "treat_fish",
    baby: {
      pal: { a: "#f0a24e", o: "#c96f28", c: "#fbf1df", n: "#e07a86", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["......k...k...", ".....kak.kak..", "....kaaakaaak.", ".k..kaoaoaoak.", "kok.kaieaieak.", "kok.kaeeaeeak.", ".kokkpacncapk.", ".kaaoaoacccck.", ".kaoaoaacccck.", ".kaakakkckcck.", "..kk.k..k.kk.."],
      blink: ["......k...k...", ".....kak.kak..", "....kaaakaaak.", ".k..kaoaoaoak.", "kok.kaaaaaaak.", "kok.kakkakkak.", ".kokkpacncapk.", ".kaaoaoacccck.", ".kaoaoaacccck.", ".kaakakkckcck.", "..kk.k..k.kk.."],
      step: ["......k...k...", ".....kak.kak..", "....kaaakaaak.", ".k..kaoaoaoak.", "kok.kaieaieak.", "kok.kaeeaeeak.", ".kokkpacncapk.", ".kaaoaoacccck.", ".kaoaoaacccck.", "..kaakakckcck.", "...kk.k.k.kk.."],
      sleep: [".......k...k..", "......kak.kak.", ".....kaaakaaak", "..kkkkaoaoaoak", ".kaaaaakkakkak", "kaoaoapacncapk", "kaccccccccaak.", ".kkkkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#f0a24e", o: "#c96f28", c: "#fbf1df", n: "#e07a86", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: [".........k...k...", "........kak.kak..", ".......kaaakaaak.", "..k....kaoaoaoak.", ".kok...kaieaieak.", "kok....kaeeaeeak.", "kok....kpacncapk.", ".kokkkkkkacccak..", "..koaaaaaaccccck.", "..kaoaoaoaccccak.", "..kaaoaoaaaaaaak.", "..kaakaakkkcckck.", "..kaakaak.kcckck.", "...kk.kk...kk.k.."],
      blink: [".........k...k...", "........kak.kak..", ".......kaaakaaak.", "..k....kaoaoaoak.", ".kok...kaaaaaaak.", "kok....kakkakkak.", "kok....kpacncapk.", ".kokkkkkkacccak..", "..koaaaaaaccccck.", "..kaoaoaoaccccak.", "..kaaoaoaaaaaaak.", "..kaakaakkkcckck.", "..kaakaak.kcckck.", "...kk.kk...kk.k.."],
      step: [".........k...k...", "........kak.kak..", ".......kaaakaaak.", "..k....kaoaoaoak.", ".kok...kaieaieak.", "kok....kaeeaeeak.", "kok....kpacncapk.", ".kokkkkkkacccak..", "..koaaaaaaccccck.", "..kaoaoaoaccccak.", "..kaaoaoaaaaaaak.", "...kaakaakkcckck.", "..kaak.kaakckkck.", "...kk...kk.k..k.."],
      sleep: ["..........k...k..", ".........kak.kak.", "........kaaakaaak", "..kkkkkkkaoaoaoak", ".kaaaaaaaakkakkak", "kaaoaoaoapacncapk", "kaaaoaoaaacccaaak", ".kooooooooooookk.", "..kkkkkkkkkkkk..."]
    }
  },
  gray_longhair: {
    name: "잿빛 장모 고양이",
    grade: 1,
    kind: "shadow",
    desc: "잿빛 털이 솜뭉치처럼 부푼 고양이입니다. 앞머리에 눈이 반쯤 가려도 밥그릇만큼은 용케 찾아갑니다.",
    likes: "treat_fish",
    baby: {
      pal: { a: "#cfd2d8", s: "#9ea2ad", w: "#eef0f4", p: "#eaa6a6", e: "#3a3440", n: "#e58f98", k: "#1a120e" },
      idle: ["...........k..k...", "..........kakkak..", "........kkapaapak.", "......kkaaaaaaaak.", ".....kaaaaaaaaaaak", "....kaaasasasasaak", "...kaaaaseasaseaak", ".kkaaaaaaaaanaaaak", "kskaaawaaaaaaaaak.", "kssaaaaaaaaaaaaak.", "ksssaaaaaaaaaaak..", "kssskaaaaaaaaaak..", ".kskkasaasaasak...", "..k..kkkkkkkkk...."],
      blink: ["...........k..k...", "..........kakkak..", "........kkapaapak.", "......kkaaaaaaaak.", ".....kaaaaaaaaaaak", "....kaaasasasasaak", "...kaaaassasassaak", ".kkaaaaaaaaanaaaak", "kskaaawaaaaaaaaak.", "kssaaaaaaaaaaaaak.", "ksssaaaaaaaaaaak..", "kssskaaaaaaaaaak..", ".kskkasaasaasak...", "..k..kkkkkkkkk...."],
      step: ["...........k..k...", "..........kakkak..", "........kkapaapak.", "......kkaaaaaaaak.", ".....kaaaaaaaaaaak", "....kaaasasasasaak", "...kaaaaseasaseaak", ".kkaaaaaaaaanaaaak", "kskaaawaaaaaaaaak.", "kssaaaaaaaaaaaaak.", "ksssaaaaaaaaaaak..", "kssskaaaaaaaaaak..", ".kskkaasaasaasak..", "..k..kkkkkkkkkk..."],
      sleep: ["...........k..k...", "..........kakkak..", ".......kkkapaapak.", ".....kkaaaaaaaaak.", ".kk.kaaasasasasaak", "ksskaaaaskkaskkaak", "ksssaaaaaaaanaaak.", ".kssaaaaaaaaaaak..", "..kkkasaasaasak...", ".....kkkkkkkkk...."]
    },
    adult: {
      pal: { a: "#cfd2d8", s: "#9ea2ad", w: "#eef0f4", p: "#eaa6a6", e: "#3a3440", n: "#e58f98", k: "#1a120e" },
      idle: ["...............k...k....", "..............kak.kak...", "............kkapakapak..", "..........kkaaaaaaaaaak.", ".........kaaaaaaaaaaaaak", "........kaaasasasasasaak", ".......kaaaasasasasasaak", "......kaaaaaaseasaseaaak", ".....kaaaaaaaaaaanaaaaak", ".k..kaaaaaawaaaaaaaaaak.", "kskkaaawaaaaaaaaaaaaaak.", "ksssaaaaaaaaaaaaaaaaaak.", "kssssaaaaaaaaaaaaaaaak..", "ksssssaaaaaaaaaaaaaaak..", ".ksskkkasaaasaaasaakk...", "..kk...kkkkkkkkkkkk....."],
      blink: ["...............k...k....", "..............kak.kak...", "............kkapakapak..", "..........kkaaaaaaaaaak.", ".........kaaaaaaaaaaaaak", "........kaaasasasasasaak", ".......kaaaasasasasasaak", "......kaaaaaassasassaaak", ".....kaaaaaaaaaaanaaaaak", ".k..kaaaaaawaaaaaaaaaak.", "kskkaaawaaaaaaaaaaaaaak.", "ksssaaaaaaaaaaaaaaaaaak.", "kssssaaaaaaaaaaaaaaaak..", "ksssssaaaaaaaaaaaaaaak..", ".ksskkkasaaasaaasaakk...", "..kk...kkkkkkkkkkkk....."],
      step: ["...............k...k....", "..............kak.kak...", "............kkapakapak..", "..........kkaaaaaaaaaak.", ".........kaaaaaaaaaaaaak", "........kaaasasasasasaak", ".......kaaaasasasasasaak", "......kaaaaaaseasaseaaak", ".....kaaaaaaaaaaanaaaaak", ".k..kaaaaaawaaaaaaaaaak.", "kskkaaawaaaaaaaaaaaaaak.", "ksssaaaaaaaaaaaaaaaaaak.", "kssssaaaaaaaaaaaaaaaak..", "ksssssaaaaaaaaaaaaaaak..", ".ksskkkaasaaasaaasakk...", "..kk...kkkkkkkkkkkk....."],
      sleep: ["...............k...k....", "..............kak.kak...", ".........kkkkkapakapak..", ".......kkaaaaaaaaaaaaak.", ".kk..kkaaaaasasasasasaak", "ksskkaaaaaaaskkaaskkaaak", "kssskaaaaaaaaaaaanaaaaak", "kssssaaaaaaaaaaaaaaaaak.", ".ksssaaaaaaaaaaaaaaaak..", "..ksskkasaaasaaasaakk...", "...kk..kkkkkkkkkkkk....."]
    }
  },
  tuxedo_cat: {
    name: "까치 고양이",
    grade: 1,
    kind: "shadow",
    desc: "까치처럼 검은 등에 흰 앞섶을 받쳐 입은 고양이입니다. 늘 차려입은 얼굴로 손님을 맞습니다.",
    likes: "treat_fish",
    baby: {
      pal: { a: "#4a4553", c: "#f6f3ec", n: "#e48a96", e: "#c9b23a", i: "#fff4b0", p: "#d98a96", k: "#1a120e" },
      idle: ["......k...k...", ".....kak.kak..", "....kaaakaaak.", ".k..kaaaaaaak.", "kak.kaieaieak.", "kak.kaeeaeeak.", ".kakkpacncapk.", ".kaaaaaacccck.", ".kaaaaaacccck.", ".kcckckkckcck.", "..kk.k..k.kk.."],
      blink: ["......k...k...", ".....kak.kak..", "....kaaakaaak.", ".k..kaaaaaaak.", "kak.kaaaaaaak.", "kak.kakkakkak.", ".kakkpacncapk.", ".kaaaaaacccck.", ".kaaaaaacccck.", ".kcckckkckcck.", "..kk.k..k.kk.."],
      step: ["......k...k...", ".....kak.kak..", "....kaaakaaak.", ".k..kaaaaaaak.", "kak.kaieaieak.", "kak.kaeeaeeak.", ".kakkpacncapk.", ".kaaaaaacccck.", ".kaaaaaacccck.", "..kcckckckcck.", "...kk.k.k.kk.."],
      sleep: [".......k...k..", "......kak.kak.", ".....kaaakaaak", "..kkkkaaaaaaak", ".kaaaaakkakkak", "kaaaaapacncapk", "kaccccccccaak.", ".kkkkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#4a4553", c: "#f6f3ec", n: "#e48a96", e: "#c9b23a", i: "#fff4b0", p: "#d98a96", k: "#1a120e" },
      idle: [".........k...k...", "........kak.kak..", ".......kaaakaaak.", "..k....kaaaaaaak.", ".kak...kaieaieak.", "kak....kaeeaeeak.", "kak....kpacncapk.", ".kakkkkkkacccak..", "..kaaaaaaaccccck.", "..kaaaaaaaccccak.", "..kaaaaaaaaaaaak.", "..kaakaakkkaakak.", "..kcckcck.kcckck.", "...kk.kk...kk.k.."],
      blink: [".........k...k...", "........kak.kak..", ".......kaaakaaak.", "..k....kaaaaaaak.", ".kak...kaaaaaaak.", "kak....kakkakkak.", "kak....kpacncapk.", ".kakkkkkkacccak..", "..kaaaaaaaccccck.", "..kaaaaaaaccccak.", "..kaaaaaaaaaaaak.", "..kaakaakkkaakak.", "..kcckcck.kcckck.", "...kk.kk...kk.k.."],
      step: [".........k...k...", "........kak.kak..", ".......kaaakaaak.", "..k....kaaaaaaak.", ".kak...kaieaieak.", "kak....kaeeaeeak.", "kak....kpacncapk.", ".kakkkkkkacccak..", "..kaaaaaaaccccck.", "..kaaaaaaaccccak.", "..kaaaaaaaaaaaak.", "...kaakaakkaakak.", "..kcck.kcckckkck.", "...kk...kk.k..k.."],
      sleep: ["..........k...k..", ".........kak.kak.", "........kaaakaaak", "..kkkkkkkaaaaaaak", ".kaaaaaaaakkakkak", "kaaaaaaaapacncapk", "kaaaaaaaaacccaaak", ".kcccccaaaaccckk.", "..kkkkkkkkkkkk..."]
    }
  },
  ddonggae: {
    name: "똥개",
    grade: 1,
    kind: "ward",
    desc: "주둥이·귀·발이 까무잡잡한 동네 개입니다. 어디서 얹었는지 늘 머리에 똥 한 덩이를 이고 다닙니다. 본인은 모자인 줄 알고 아주 뿌듯해합니다.",
    likes: "treat_meat",
    baby: {
      pal: { a: "#ead6ab", b: "#4a3222", g: "#d8b47c", m: "#5c3f2a", c: "#fbf3e2", n: "#1a0f0a", q: "#4e2c12", r: "#7e4a20", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["........k.....", ".......kqk....", "......kqrqk...", ".....kqqrqqk..", "....kkaaaaakk.", "...kbaaaaaaabk", ".k.kbaieaieabk", "kbkkbbeeaeebbk", "kbkkkpamnmapk.", ".kbaaaaacccak.", ".kaggaaaaaaaak", ".kaaaaggaaaaak", ".kmmkmkkkmkmmk", "..kk.k...k.kk."],
      blink: ["........k.....", ".......kqk....", "......kqrqk...", ".....kqqrqqk..", "....kkaaaaakk.", "...kbaaaaaaabk", ".k.kbaaaaaaabk", "kbkkbbkkakkbbk", "kbkkkpamnmapk.", ".kbaaaaacccak.", ".kaggaaaaaaaak", ".kaaaaggaaaaak", ".kmmkmkkkmkmmk", "..kk.k...k.kk."],
      step: ["........k.....", ".......kqk....", "......kqrqk...", ".....kqqrqqk..", "....kkaaaaakk.", "...kbaaaaaaabk", ".k.kbaieaieabk", "kbkkbbeeaeebbk", "kbkkkpamnmapk.", ".kbaaaaacccak.", ".kaggaaaaaaaak", ".kaaaaggaaaaak", "..kmmkmkmmkmk.", "...kk.k.kk.k.."],
      sleep: ["........k.....", ".......kqk....", "......kqrqk...", ".....kqqrqqk..", "....kkaaaaakk.", "...kbaaaaaaabk", ".kkkbakkakkabk", "kbaabpamnmapbk", ".kaggaaaaaaaak", ".kaaaaaggaaak.", "..kkkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#ead6ab", b: "#4a3222", g: "#d8b47c", m: "#5c3f2a", c: "#fbf3e2", n: "#1a0f0a", q: "#4e2c12", r: "#7e4a20", d: "#c0392b", e: "#2a1a14", i: "#ffffff", p: "#f3a0a0", k: "#1a120e" },
      idle: ["...........k.....", "..........kqk....", ".........kqrqk...", "........kqqrqqk..", ".......kkaaaaakk.", "......kbaaaaaaabk", "......kbaieaieabk", ".k....kbbeeaeebbk", "kbk....kpamnmapk.", ".kbk....kacccak..", ".kbkkkkkdddddddk.", ".kaaaaaaaacccaak.", ".kaggaaaaggaaaak.", ".kaakaakkkkaakaak", ".kmmkmmk..kmmkmmk", "..kk.kk....kk.kk."],
      blink: ["...........k.....", "..........kqk....", ".........kqrqk...", "........kqqrqqk..", ".......kkaaaaakk.", "......kbaaaaaaabk", "......kbaaaaaaabk", ".k....kbbkkakkbbk", "kbk....kpamnmapk.", ".kbk....kacccak..", ".kbkkkkkdddddddk.", ".kaaaaaaaacccaak.", ".kaggaaaaggaaaak.", ".kaakaakkkkaakaak", ".kmmkmmk..kmmkmmk", "..kk.kk....kk.kk."],
      step: ["...........k.....", "..........kqk....", ".........kqrqk...", "........kqqrqqk..", ".......kkaaaaakk.", "......kbaaaaaaabk", "......kbaieaieabk", ".k....kbbeeaeebbk", "kbk....kpamnmapk.", ".kbk....kacccak..", ".kbkkkkkdddddddk.", ".kaaaaaaaacccaak.", ".kaggaaaaggaaaak.", ".kaakkaakkaakaak.", "kmmk..kmmkmmkkmmk", ".kk....kk.kk..kk."],
      sleep: ["...........k.....", "..........kqk....", ".........kqrqk...", "........kqqrqqk..", ".......kkaaaaakk.", "......kbaaaaaaabk", ".kkkkkkbakkakkabk", "kbaaaaabpamnmapbk", ".kaaaaaaadddddddk", "kaaggaaaaggaaaaak", ".kaaaaaaaaaaaaak.", "..kkkkkkkkkkkkk.."]
    }
  },
  platypus: {
    name: "부리너구리",
    grade: 2,
    kind: "water",
    desc: "오리 부리에 너구리 몸, 납작한 꼬리를 단 먼 바다 건너의 동무입니다. 뱃사람들이 구등대 군도에서 데려왔다고 합니다. 물가에서는 누구보다 날쌥니다.",
    likes: "treat_fish",
    baby: {
      pal: { a: "#8a5a36", t: "#5c3a22", b: "#3e3b38", w: "#4a3a30", e: "#2a1a14", i: "#ffffff", k: "#1a120e" },
      idle: [".....kkkkk....", "....kaaaaak...", "...kaaaaaaakk.", ".kkkaaieaabbbk", "kttkaaeeaabbbk", "kttaaaaaaabbk.", "kttaaaaaaaak..", ".kaaaaaaaaak..", "..kwwkkkkwwk..", "...kk....kk..."],
      blink: [".....kkkkk....", "....kaaaaak...", "...kaaaaaaakk.", ".kkkaaaaaabbbk", "kttkaakkaabbbk", "kttaaaaaaabbk.", "kttaaaaaaaak..", ".kaaaaaaaaak..", "..kwwkkkkwwk..", "...kk....kk..."],
      step: [".....kkkkk....", "....kaaaaak...", "...kaaaaaaakk.", ".kkkaaieaabbbk", "kttkaaeeaabbbk", "kttaaaaaaabbk.", "kttaaaaaaaak..", ".kaaaaaaaaak..", "..kkwwkkwwk...", "....kk..kk...."],
      sleep: [".....kkkkk....", "....kaaaaakkk.", ".kkkaakkaabbbk", "kttaaaaaaabbbk", "kttaaaaaaaakk.", ".kaaaaaaaaak..", "..kkkkkkkkk..."]
    },
    adult: {
      pal: { a: "#8a5a36", t: "#5c3a22", b: "#3e3b38", w: "#4a3a30", e: "#2a1a14", i: "#ffffff", k: "#1a120e" },
      idle: ["........kkkkk.....", "......kkaaaaak....", ".....kaaaaaaaakkk.", ".kkk.kaaaieaaabbbk", "ktttkkaaaeeaaabbbk", "ktttaaaaaaaaaabbk.", "ktttaaaaaaaaaaak..", ".kttaaaaaaaaaaak..", "..kaaaaaaaaaaakk..", "..kwwkwwkkkwwkwwk.", "...kk.kk...kk.kk.."],
      blink: ["........kkkkk.....", "......kkaaaaak....", ".....kaaaaaaaakkk.", ".kkk.kaaaaaaaabbbk", "ktttkkaaakkaaabbbk", "ktttaaaaaaaaaabbk.", "ktttaaaaaaaaaaak..", ".kttaaaaaaaaaaak..", "..kaaaaaaaaaaakk..", "..kwwkwwkkkwwkwwk.", "...kk.kk...kk.kk.."],
      step: ["........kkkkk.....", "......kkaaaaak....", ".....kaaaaaaaakkk.", ".kkk.kaaaieaaabbbk", "ktttkkaaaeeaaabbbk", "ktttaaaaaaaaaabbk.", "ktttaaaaaaaaaaak..", ".kttaaaaaaaaaaak..", "..kaaaaaaaaaaak...", "...kwwkwwkwwkwwk..", "....kk.kk.kk.kk..."],
      sleep: ["........kkkkk.....", "......kkaaaaakkkk.", ".kkkkkaaakkaaabbbk", "ktttaaaaaaaaaabbbk", "ktttaaaaaaaaaaabk.", ".kaaaaaaaaaaaaak..", "..kkkkkkkkkkkkk..."]
    }
  },
  hare: {
    name: "산토끼",
    grade: 1,
    kind: "wood",
    desc: "산기슭에서 내려온 갈색 토끼입니다. 귀 끝이 까맣고, 놀라면 한달음에 언덕 너머까지 뛰어갑니다.",
    likes: "treat_herb",
    baby: {
      pal: { a: "#a37a50", x: "#3a2a1e", c: "#efe4cf", p: "#d9a08a", n: "#6a4030", e: "#2a1a14", i: "#ffffff", k: "#1a120e" },
      idle: ["......kk.kk...", ".....kxxkxxk..", ".....kpakpak..", ".....kpakpak..", "....kaaaaaaak.", "....kaieaieak.", "..kkkaeeaeeak.", ".kcckpaanaapk.", "kccaaaaaaaaak.", ".kcaaaaaaaaak.", ".kaaakkkakaak.", "..kkk...k.kk.."],
      blink: ["......kk.kk...", ".....kxxkxxk..", ".....kpakpak..", ".....kpakpak..", "....kaaaaaaak.", "....kaaaaaaak.", "..kkkakkakkak.", ".kcckpaanaapk.", "kccaaaaaaaaak.", ".kcaaaaaaaaak.", ".kaaakkkakaak.", "..kkk...k.kk.."],
      step: ["......kk.kk...", ".....kxxkxxk..", ".....kpakpak..", ".....kpakpak..", "....kaaaaaaak.", "....kaieaieak.", "..kkkaeeaeeak.", ".kcckpaanaapk.", "kccaaaaaaaaak.", ".kkcaaaaaaaak.", "kaaakkkkkaak..", ".kkk.....kk..."],
      sleep: ["...kkkk.......", "..kxaaakkkkk..", "...kappaaaaak.", "..kkkakkakkak.", ".kcckpaanaapk.", "kccaaaaaaaaaak", ".kcaaaaaaaaak.", "..kkkkkkkkkk.."]
    },
    adult: {
      pal: { a: "#a37a50", x: "#3a2a1e", c: "#efe4cf", p: "#d9a08a", n: "#6a4030", e: "#2a1a14", i: "#ffffff", k: "#1a120e" },
      idle: ["........kk..kk..", ".......kxxkkxxk.", ".......kpakpak..", ".......kpakpak..", ".......kpakpak..", "......kaaaaaaak.", "......kaieaieak.", "..kk..kaeeaeeak.", ".kcckkkpaanaapk.", "kcccaaaaaaaaak..", ".kcaaaaaaaaaaak.", "..kaaaaaaaaaaak.", ".kaaaakkkkaakak.", "..kkkk....kk.k.."],
      blink: ["........kk..kk..", ".......kxxkkxxk.", ".......kpakpak..", ".......kpakpak..", ".......kpakpak..", "......kaaaaaaak.", "......kaaaaaaak.", "..kk..kakkakkak.", ".kcckkkpaanaapk.", "kcccaaaaaaaaak..", ".kcaaaaaaaaaaak.", "..kaaaaaaaaaaak.", ".kaaaakkkkaakak.", "..kkkk....kk.k.."],
      step: ["........kk..kk..", ".......kxxkkxxk.", ".......kpakpak..", ".......kpakpak..", ".......kpakpak..", "......kaaaaaaak.", "......kaieaieak.", "..kk..kaeeaeeak.", ".kcckkkpaanaapk.", "kcccaaaaaaaaak..", ".kcaaaaaaaaaaak.", ".kkcaaaaaaaaak..", "kaaaakkkkkkaak..", ".kkkk......kk..."],
      sleep: ["....kkkkk.......", "...kxaaaakkkkk..", "....kapppaaaaak.", "..kk.kkakkakkak.", ".kcckkkpaanaapk.", "kcccaaaaaaaaaaak", ".kcaaaaaaaaaaak.", "..kaaaaaaaaaaak.", "...kkkkkkkkkkk.."]
    }
  }
};

export const EFFECTS = {
  heart: {
    pal: { r: "#e2475a", w: "#ff9aa6", k: "#1a120e" },
    rows: [".kk.kk.", "krwkrrk", "krrrrrk", ".krrrk.", "..krk..", "...k..."]
  },
  zz: {
    pal: { z: "#cfe3f2" },
    rows: ["zzzz", "..z.", ".z..", "zzzz"]
  },
  bowl: {
    pal: { w: "#f4f0e6", n: "#8a5a32", m: "#b07a46", f: "#e9c46a", k: "#1a120e" },
    rows: [".fwfwf.", "kkkkkkk", "knmmmnk", ".knnnk.", "..kkk.."]
  },
  star: {
    pal: { g: "#f0d070", w: "#fff6c8" },
    rows: ["..g..", ".gwg.", "ggwgg", ".gwg.", "..g.."]
  },
  note: {
    pal: { n: "#cfe3f2" },
    rows: ["..nnn", "..n.n", "..n..", "nnn..", "nnn.."]
  }
};
