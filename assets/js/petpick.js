import { PETS } from './housing/petsprite.js';
import { GAMEDATA } from './gamedata.js';
export const FIRST_PETS = GAMEDATA.petPartner?.first || [];
export const petGroupOf = id => Object.values(GAMEDATA.petPartner?.groups || {}).find(g => g.kinds.includes(PETS[id]?.kind));
export const petGroupLine = g => g ? `${g.line} · ${g.fx_line}` : '';
