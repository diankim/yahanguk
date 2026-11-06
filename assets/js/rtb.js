import { db } from './core.js';

const groups = {};

function open(topic, event, fn, onUp) {
  const slot = { ch: null, dead: false };
  const join = () => {
    if (slot.dead) return;
    try {
      const ch = db.channel(topic, { config: { private: true } }).on('broadcast', { event }, m => { try { fn(m?.payload || {}); } catch {} });
      slot.ch = ch;
      ch.subscribe(status => {
        if (slot.ch !== ch || slot.dead) return;
        if (status === 'SUBSCRIBED') { onUp(true); return; }
        if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT' || status === 'CLOSED') {
          onUp(false);
          try { db.removeChannel(ch); } catch {}
          slot.ch = null;
          setTimeout(join, status === 'CLOSED' ? 3000 : 20000);
        }
      });
    } catch { onUp(false); }
  };
  join();
  return () => { slot.dead = true; if (slot.ch) { const c = slot.ch; slot.ch = null; try { db.removeChannel(c); } catch {} } };
}

export function bgroup(key, topics, event, fn, onLive) {
  const g = groups[key] || (groups[key] = { subs: new Map(), up: new Set(), live: null, onLive: null });
  g.onLive = onLive || null;
  const report = () => {
    const live = g.subs.size > 0 && [...g.subs.keys()].every(t => g.up.has(t));
    if (live === g.live) return;
    g.live = live;
    try { g.onLive?.(live); } catch {}
  };
  const want = new Set((topics || []).filter(Boolean));
  for (const [t, close] of g.subs) if (!want.has(t)) { close(); g.subs.delete(t); g.up.delete(t); }
  for (const t of want) if (!g.subs.has(t)) g.subs.set(t, open(t, event, fn, up => {
    if (!g.subs.has(t)) return;
    if (up) g.up.add(t); else g.up.delete(t);
    report();
  }));
  report();
}

export const bclear = key => bgroup(key, [], '', () => {});
