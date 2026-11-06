export const HQ = '_hq';
export const isHq = id => String(id || '').endsWith(HQ);
export const baseOf = id => String(id || '').replace(/_hq$/, '');
export const hqOf = id => `${baseOf(id)}${HQ}`;
export const pairOf = id => isHq(id) ? baseOf(id) : hqOf(id);
export const hqCount = (inv, id) => Number(inv?.[baseOf(id)] || 0) + Number(inv?.[hqOf(id)] || 0);
export const withHq = (ids, inv) => (ids || []).flatMap(k => inv && Number(inv[hqOf(k)] || 0) > 0 ? [k, hqOf(k)] : [k]);
export const bothOf = ids => (ids || []).flatMap(k => [baseOf(k), hqOf(k)]);
export const haveOf = (ids, inv) => bothOf(ids).filter(k => Number(inv?.[k] || 0) > 0);
