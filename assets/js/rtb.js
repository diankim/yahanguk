import { db } from './core.js';

const groups = {};

function open(topic, event, fn) {
  const slot = { ch: null, dead: false };
  const join = () => {
    if (slot.dead) return;
    try {
      const ch = db.channel(topic, { config: { private: true } }).on('broadcast', { event }, m => { try { fn(m?.payload || {}); } catch {} });
      slot.ch = ch;
      ch.subscribe(status => {
        if (slot.ch !== ch || slot.dead) return;
        if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
          try { db.removeChannel(ch); } catch {}
          slot.ch = null;
          setTimeout(join, 20000);
        }
      });
    } catch {}
  };
  join();
  return () => { slot.dead = true; if (slot.ch) { try { db.removeChannel(slot.ch); } catch {} slot.ch = null; } };
}

export function bgroup(key, topics, event, fn) {
  const g = groups[key] || (groups[key] = new Map());
  const want = new Set((topics || []).filter(Boolean));
  for (const [t, close] of g) if (!want.has(t)) { close(); g.delete(t); }
  for (const t of want) if (!g.has(t)) g.set(t, open(t, event, fn));
}

export const bclear = key => bgroup(key, [], '', () => {});
