update public.world_patch_notes set body =
  regexp_replace(body, E'(### 고친 것\\n(?:- [^\\n]*\\n)+)\\n(### 창고\\n(?:- 창고[^\\n]*\\n|- 전으로[^\\n]*\\n|- 직업 전투[^\\n]*\\n|- 지역 완전[^\\n]*\\n|- 연담[^\\n]*\\n)+)((?:- [^\\n]*\\n)*)$', E'\\2\\n\\1\\3')
 where note_id = '3.0.0' and body ~ E'### 고친 것\\n(?:- [^\\n]*\\n)+\\n### 창고\\n';
