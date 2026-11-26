export const TR_MOTIFS = {
  hull: 'M-8-4h16M-8 0h16M-8 4h16M-3-4v4M3 0v4M-6-6a1 1 0 102 0 1 1 0 10-2 0M4 6a1 1 0 102 0 1 1 0 10-2 0M0-8v4M-2.5-6.5a2.5 2.5 0 015 0',
  tide: 'M-8 1c2-2 4-2 6 0s4 2 6 0 4-2 6 0M-8 5c2-2 4-2 6 0s4 2 6 0 4-2 6 0M4-8a4 4 0 100 7 3 3 0 010-7z',
};
export const TR_FRAMES = { fr_hull: ['legend', 'hull'], fr_hanul: ['legend', 'tide'] };
export const TR_PATTERNS = {
  pt_sealane: '<path d="M0 5h20M0 15h20" opacity=".45"/><path d="M3 12l4-5 5 3 5-6" stroke-dasharray="1.6 1.8"/><circle cx="3" cy="12" r="1"/><circle cx="12" cy="10" r="1"/><circle cx="17" cy="4" r="1"/><path d="M7 18h5l-1 1.4H8zM9.4 18v-3.6l2.4 2.4H9.4"/>',
};
export const TR_SEALS = { sl_bak: '舶', sl_hanul: '潮' };
export const TR_SEAL_TIER = { sl_bak: 'legend', sl_hanul: 'legend' };
