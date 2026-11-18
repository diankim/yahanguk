import { rpc, store, esc, fmt } from './core.js';
import { load, catItem } from './views/common.js';
import { isFurniture, myHomeCounts } from './housing/count.js';
import { baseOf } from './hq.js';

const lookOf = id => catItem(id)?.equipment_traits?.look || null;
const petOf = id => catItem(id)?.equipment_traits?.pet || null;
export const ownKind = key => {
  const k = String(key || '');
  if (k.startsWith('pet:')) return 'pet';
  if (k.startsWith('look:')) return 'look';
  if (isFurniture(k)) return 'fur';
  if (lookOf(k)) return 'look';
  if (petOf(k)) return 'pet';
  return null;
};

export const ownSlot = key => ownKind(key) ? `<small class="own-tag" data-own="${esc(key)}" hidden></small>` : '';
export const ownRow = key => ownKind(key) ? `<div data-own-row hidden><dt>보유</dt><dd data-own="${esc(key)}" data-own-nobag></dd></div>` : '';

const n = (m, id) => Number(m?.[id] || 0);
function bagOf(id) { return n(store.character?.inventory, id); }
function storeOf(id) {
  const s = store.snaps?.['world_storage_snapshotnull'];
  return (s?.items || []).reduce((a, i) => a + (i.item_id === id ? Number(i.qty) || 0 : 0), 0);
}

async function sources(keys) {
  const kinds = new Set(keys.map(ownKind));
  const [home, look, pets] = await Promise.all([
    kinds.has('fur') ? myHomeCounts(rpc).catch(() => null) : null,
    kinds.has('look') ? load('world_avatar_get', undefined, { maxAge: 600000 }).catch(() => null) : null,
    kinds.has('pet') ? load('world_pet_snapshot', undefined, { maxAge: 120000 }).catch(() => null) : null,
  ]);
  return { home, owned: new Set(look?.owned || []), mine: new Set((pets?.mine || []).map(p => p.id)) };
}

export function ownText(key, src, nobag = false) {
  const k = String(key), kind = ownKind(k), id = k.startsWith('pet:') || k.startsWith('look:') ? null : baseOf(k);
  const held = id && !nobag ? bagOf(id) + storeOf(id) : 0;
  const bag = held ? `가방·창고 ${fmt.num(held)}` : '';
  if (kind === 'fur') {
    const p = n(src.home?.placed, id), s = n(src.home?.stored, id);
    return [bag, s ? `곳간 ${fmt.num(s)}` : '', p ? `놓음 ${fmt.num(p)}` : ''].filter(Boolean).join(' · ');
  }
  if (kind === 'look') {
    const lk = k.startsWith('look:') ? k.slice(5) : lookOf(id);
    return [lk && src.owned.has(lk) ? '옷장에 있음' : '', bag].filter(Boolean).join(' · ');
  }
  if (kind === 'pet') {
    const sp = k.startsWith('pet:') ? k.slice(4) : petOf(id);
    return [sp && src.mine.has(sp) ? '이미 있는 동무' : '', bag].filter(Boolean).join(' · ');
  }
  return '';
}

export async function fillOwned(root) {
  const els = [...(root?.querySelectorAll('[data-own]') || [])];
  if (!els.length) return;
  const src = await sources(els.map(e => e.dataset.own));
  for (const e of els) {
    const row = e.closest('[data-own-row]'), t = ownText(e.dataset.own, src, 'ownNobag' in e.dataset);
    e.textContent = t ? (row ? t : `보유 · ${t}`) : '';
    (row || e).hidden = !t;
  }
}
