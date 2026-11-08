import { makeRoom } from './render.js';
import { FUR, WALL, PAPER, GROUND } from './furniture.js';

let room = null;
export function furnPic(id) {
  const s = String(id || ''), k = s.slice(3);
  if (s.startsWith('hp_') && PAPER[k]) return `<span class="hs-sw fpic-sw" style="--a:${PAPER[k].c};--b:${PAPER[k].l}"></span>`;
  if (s.startsWith('hg_') && GROUND[k]) return `<span class="hs-sw fpic-sw" style="--a:${GROUND[k].a};--b:${GROUND[k].b}"></span>`;
  if (!s.startsWith('hf_') || !(FUR[k] || WALL[k])) return '';
  room ||= makeRoom(4, { FUR, WALL, PAPER, GROUND });
  return `<img class="fpic-img" src="${room.thumb(k)}" alt="">`;
}
