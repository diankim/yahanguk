PAL = {
    'k': '#1a120e', 'w': '#f6f1e6', 'c': '#ddd3bd', 's': '#a49a86', 'U': '#5f86b8', 'u': '#3b5f8a',
    'L': '#e06048', 'r': '#b4342a', 'R': '#741d18', 'D': '#4a120f', 'y': '#e8c34a', 'Y': '#f6e7a6', 'Z': '#a8822e',
    'm': '#94603c', 'M': '#c99668', 'b': '#5e3a22', 'o': '#e08a3a', 'n': '#d8b078', 'd': '#3f2c1e',
    'g': '#2f6b2a', 'G': '#4f9a3a', 'l': '#8fcf5a', 'i': '#e9a2b6', 'I': '#c86a88', 'B': '#a07040',
    'h': '#c84a2a', 'H': '#8a2a1a', 'e': '#5a4636', 'x': '#3a2a1e', 'X': '#4f3a28',
    'v': '#cfc8bd', 'q': '#f4d27a', 'Q': '#fff2b8', 'p': '#e8b0a0',
}

DISH = {
'meat': """
..mMoMm..
.MbmMbMm.
wmbMobMbs
wwccccccs
.wUUUUUs.
.wccccss.
..sssss..
""",
'fish': """
..mmmm..m
.okobobmm
.nnnnnnnm
wwwwwwwws
.ccccccs.
""",
'namul': """
.GG..mm..
GlGgmMmw.
gGgbmbwvw
wgccccccs
.wccccss.
..sssss..
""",
'rice': """
...www...
..wwwvv..
.YwwwwvZ.
YYyyyyyZZ
.YyyyyyZ.
.yyyyyZZ.
..ZZZZZ..
""",
'tteok': """
..iwwl...
.iIwvlG..
.iIwvlGG.
BMMMMMMMm
BBBBBBmmm
.BmmmmmX.
..XXXXX..
""",
'soup': """
.YyyyyyZ.
YhoohhhHZ
YhHohoHHZ
.YyyyyZZ.
.yyyyyZZ.
..ZZZZZ..
""",
}

STEAM = ["..v..", ".v..v", ".v.v.", "..v.."]
STEAMY = {'meat', 'rice', 'soup'}

NAMES = {'meat': '고기 요리', 'fish': '생선 구이', 'namul': '나물 접시', 'rice': '밥 그릇', 'tteok': '떡 접시', 'soup': '국 그릇'}

KINDS = {
    'meat': {'name': '고기상', 'tag': 'h', 'tag2': 'H',
             'dishes': ['meat', 'meat', 'soup', 'meat', 'rice', 'meat', 'meat', 'namul', 'meat', 'tteok', 'rice', 'meat']},
    'soban': {'name': '소반', 'tag': 'G', 'tag2': 'g',
              'dishes': ['namul', 'rice', 'soup', 'namul', 'tteok', 'rice', 'rice', 'namul', 'meat', 'rice', 'fish', 'namul']},
    'sea': {'name': '바다상', 'tag': 'U', 'tag2': 'u',
            'dishes': ['fish', 'soup', 'fish', 'rice', 'fish', 'namul', 'fish', 'meat', 'fish', 'tteok', 'rice', 'fish']},
}
