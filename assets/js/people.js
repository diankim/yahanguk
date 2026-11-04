import { store, esc, emblem } from './core.js';
import { FRAMES, frameTier } from './cosmetics.js';

export function face(id, profile, size = 28, initial = '') {
  if (!profile) return `<i class="av pface" style="--fn:${size}" aria-hidden="true">${esc([...String(initial || '?')][0] || '?')}</i>`;
  const fr = profile.frame && FRAMES[profile.frame];
  if (fr) { const n = Math.round(size * 34 / 28); return `<i class="av face pface mini fr t-${frameTier(profile.frame)}" style="--fn:${n}" aria-hidden="true"><span class="mini-in">${emblem(id, profile, 72)}</span></i>`; }
  return `<i class="av face pface" style="--fn:${size}" aria-hidden="true">${emblem(id, { ...profile, frame: null }, size)}</i>`;
}

const NKEY = () => `yh-friend-notes:${store.character?.owner_id || ''}`;
let notes = null;
function all() {
  if (notes && notes.k === NKEY()) return notes.m;
  let m = {}; try { m = JSON.parse(localStorage.getItem(NKEY()) || '{}') || {}; } catch {}
  notes = { k: NKEY(), m }; return m;
}
function save() { try { localStorage.setItem(NKEY(), JSON.stringify(all())); } catch {} }
export const noteOf = id => all()[id] || null;
export function setNote(id, nick, memo) { const m = all(); if (nick || memo) m[id] = { nick: nick || '', memo: memo || '' }; else delete m[id]; save(); }
export function syncNotes(friends) {
  const m = {}; for (const f of friends || []) if (f.nick || f.memo) m[f.owner_id] = { nick: f.nick || '', memo: f.memo || '' };
  notes = { k: NKEY(), m }; save();
}
export const nickTag = id => { const n = noteOf(id)?.nick; return n ? `<em class="f-nick" title="내가 붙인 별명 · 나만 보입니다">${esc(n)}</em>` : ''; };
