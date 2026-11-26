import { rpc, act, esc, icon, guard, ask, $, $$, fmt, openModal, store, effectText } from './core.js';
import { HFEAST } from './rules.js';
import { helpQ } from './tips.js';
import { feastTableSvg, bowlSvg } from './feastart.js';
import { foldOpen, catItem } from './views/common.js';
import { openItemPick } from './views/itempick.js';

const mobile = () => window.matchMedia('(max-width: 640px)').matches;
const until = (t, txt = '') => `<b data-hf-left="${new Date(t).getTime()}">${esc(fmt.remain(new Date(t) - Date.now()))}</b>${txt}`;

export async function openHarborFeast(port = null) {
  const m = openModal({ title: '나눔 잔칫상', wide: true, body: '<div class="hf-box"><p class="muted">상을 살피는 중…</p></div>' });
  const box = $('.hf-box', m);
  const st = { v: null, fresh: 0, port, at: 0 };
  const read = async () => {
    try { st.v = await rpc('world_hfeast_view', { p_port: st.port }); st.at = Date.now(); } catch (e) { box.innerHTML = `<p class="bad">${esc(e.message)}</p>`; return; }
    draw();
  };
  function draw() {
    if (!box.isConnected || !st.v) return;
    const keep = box.closest('.modal-body')?.scrollTop || 0;
    box.innerHTML = viewHtml(st.v, st.fresh);
    const mb = box.closest('.modal-body'); if (mb) mb.scrollTop = keep;
    st.fresh = 0;
    bind();
  }
  function bind() {
    const v = st.v;
    const giveB = $('[data-hf-give]', box);
    if (giveB) giveB.onclick = () => pick(giveB);
    const eatB = $('[data-hf-eat]', box);
    if (eatB) eatB.onclick = () => guard(eatB, async () => {
      try { const r = await act('world_hfeast_eat'); st.v = r; draw(); return r; } catch (e) { read(); throw e; }
    });
    function pick(btn) {
      const rows = (v.dishes || []).map(d => { const it = catItem(d.id) || {};
        return { id: d.id, name: d.name, have: d.n, max: d.n, cat: 'consumable', rarity: it.rarity || 'common', tier: it.tier || 0, desc: it.description || '', sub: `${HFEAST.kindName(d.kind)}에 드는 요리` }; });
      openItemPick({ title: '상에 올릴 요리', rows, empty: '가방에 올릴 수 있는 요리가 없습니다.', note: `<p class="muted small">${esc(HFEAST.dishNote)}</p>`,
        onDone: async id => {
          const r0 = rows.find(x => x.id === id); if (!r0) return;
          if (!(await ask(HFEAST.giveAsk(r0.name, v.table?.n || 0, v.table?.need || HFEAST.need), { title: '요리 올리기', ok: '올리기' }))) return;
          guard(btn, async () => {
            try { const r = await act('world_hfeast_give', { p_item: id }); st.fresh = r.table?.n || 0; st.v = r; draw(); return r; } catch (e) { read(); throw e; }
          });
        } });
    }
  }
  const tick = setInterval(() => {
    if (!box.isConnected) { clearInterval(tick); return; }
    const now = Date.now(); let due = false;
    $$('[data-hf-left]', box).forEach(s => { const t = Number(s.dataset.hfLeft); if (t > now) s.textContent = fmt.remain(t - now); else { s.textContent = '지금'; due = true; } });
    if (due && now - st.at > 3000) read();
  }, 1000);
  await read();
  return m;
}

function headHtml(v) {
  const t = v.table || {};
  return `<div class="hf-head">
    <div class="hf-where">${icon('pin', 15)}${v.port ? `<b>${esc(v.port_name)} 잔칫상</b>${v.here ? '' : '<small class="muted">· 멀리서 보는 중</small>'}` : '<b class="muted">항구가 아님</b>'}${helpQ(HFEAST.help, '나눔 잔칫상')}</div>
    ${v.port ? `<div class="hf-stats">
      <span class="chip" title="이번 상을 차리는 칸 시간">이번 상 ${esc(HFEAST.kst(v.slot_at))}~${esc(HFEAST.kst(v.slot_end).replace('한국 시각 ', ''))}</span>
      <span class="chip${t.status === 'open' ? ' ok' : ''}">${t.status === 'open' ? `${esc(t.kind_name || '')} 차려짐` : `${t.n || 0}/${t.need || HFEAST.need}그릇`}</span>
      <span class="chip" title="한 사람이 한 상에 올릴 수 있는 그릇">내 그릇 ${v.mine || 0}/${HFEAST.per_person}</span>
    </div>` : ''}</div>`;
}

function card(key, title, ico, sub, body, def) {
  const open = mobile() ? foldOpen(`hf-${key}-m`, def) : true;
  return `<details class="hf-card" data-fold="${mobile() ? `hf-${key}-m` : `hf-${key}`}" ${open ? 'open' : ''}><summary><h3>${icon(ico, 16)} ${esc(title)}</h3>${sub ? `<small class="muted">${sub}</small>` : ''}</summary>${body}</details>`;
}

function tableCard(v, fresh) {
  const t = v.table || {}, bowls = t.bowls || [], need = t.need || HFEAST.need, open = t.status === 'open';
  const guess = open ? t.kind : HFEAST.guess(bowls);
  const plates = bowls.length ? `<ol class="hf-plates">${bowls.map(b => `<li class="${b.me ? 'me' : ''}${b.n === fresh ? ' new' : ''}">${bowlSvg(b.kind, 18)}<b>${esc(b.name)}</b><small>${esc(b.item_name)}${b.hq ? ' (우수)' : ''}</small></li>`).join('')}</ol>`
    : '<p class="muted small">아직 오른 그릇이 없습니다. 첫 그릇을 올려 보세요.</p>';
  const plateBox = bowls.length && mobile() ? `<details class="hf-sub" data-fold="hf-plates-m" ${foldOpen('hf-plates-m', false) ? 'open' : ''}><summary>올린 이름표 ${bowls.length}</summary>${plates}</details>` : plates;
  const line = open
    ? `<p class="hf-line ok">${icon('spark', 14)} ${esc(`${need}그릇이 다 차 ${t.kind_name || HFEAST.kindName(t.kind)}이(가) 차려졌습니다.`)}</p>`
    : `<p class="hf-line">${guess ? `지금대로라면 <b>${esc(HFEAST.kindName(guess))}</b> · ` : ''}${need - (t.n || 0)}그릇 더 오르면 열립니다 · 칸이 끝나기까지 ${until(v.slot_end)}</p><p class="muted small">${esc(HFEAST.vanish)}</p>`;
  const art = feastTableSvg(bowls, { need, kind: guess, open, fresh, size: 340, label: `잔칫상 ${t.n || 0}/${need}그릇` });
  return card('table', '이번 상', 'bowl', `${t.n || 0}/${need}`, `<div class="hf-scene${open ? ' open' : ''}">${art}</div>
    <div class="hf-meter" role="progressbar" aria-valuemin="0" aria-valuemax="${need}" aria-valuenow="${t.n || 0}"><i style="width:${Math.min(100, Math.round((t.n || 0) / need * 100))}%"></i></div>
    ${line}${plateBox}`, true);
}

function giveCard(v) {
  const t = v.table || {}, down = !!store.character?.downed_at, n = (v.dishes || []).length;
  if (t.status === 'open') return card('give', '요리 올리기', 'plus', '', `<p class="muted small">이번 상은 차려졌습니다. 다음 상은 ${esc(HFEAST.kst(v.slot_end))}부터 올릴 수 있습니다.</p>`, false);
  const off = !v.here || down || (v.mine_left || 0) <= 0 || !n;
  const why = !v.here ? HFEAST.away : down ? HFEAST.down : (v.mine_left || 0) <= 0 ? `이 상에는 ${HFEAST.per_person}그릇을 모두 올렸습니다.` : !n ? '가방에 올릴 수 있는 요리가 없습니다.' : '';
  return card('give', '요리 올리기', 'plus', `남은 내 그릇 ${v.mine_left ?? HFEAST.per_person}`, `
    <p class="muted small">한 그릇씩 올립니다. 이 상에 내가 올릴 수 있는 그릇은 ${v.mine_left ?? HFEAST.per_person}그릇 남았습니다${v.here ? ` · 가방의 요리 ${n}가지` : ''}.</p>
    <div class="btn-row"><button type="button" class="btn primary" data-hf-give data-here="잔칫상에 요리 올리기" ${off ? 'disabled' : ''}>${icon('bowl', 16)}<span>요리 올리기</span></button></div>
    ${why ? `<p class="hint">${esc(why)}</p>` : ''}`, !!v.here);
}

function eatCard(v) {
  const e = v.eat, down = !!store.character?.downed_at;
  if (!e) return card('eat', '상에서 먹기', 'heart', '', `<p class="muted small">지금 이 항구에 열린 상이 없습니다. 상이 다 차 열리면 ${HFEAST.eat_h}시간 동안 와서 먹을 수 있습니다.</p>`, false);
  const body = e.ate
    ? `<p class="hf-line ok">${icon('check', 14)} 이 상에서 먹었습니다 · 「${esc(e.buff)}」</p>`
    : `<p class="hf-line"><b>${esc(e.kind_name)}</b> · 「${esc(e.buff)}」 · ${esc(HFEAST.kst(e.until))}까지 (${until(e.until, ' 남음')})</p>
       <div class="btn-row"><button type="button" class="btn primary" data-hf-eat data-here="잔칫상에서 먹기" ${!v.here || down || e.full ? 'disabled' : ''}>${icon('bowl', 16)}<span>상에서 먹기</span></button></div>
       ${!v.here ? `<p class="hint">${esc(HFEAST.away)}</p>` : down ? `<p class="hint warn">${esc(HFEAST.down)}</p>` : e.full ? `<p class="hint warn">${esc(HFEAST.full(v.cap || HFEAST.cap))}</p>` : ''}`;
  return card('eat', '상에서 먹기', 'heart', e.ate ? '먹음' : `${esc(HFEAST.kst(e.until).replace('한국 시각 ', ''))}까지`, body, true);
}

function kindsCard() {
  const rows = (HFEAST.order || Object.keys(HFEAST.kinds || {})).map(k => { const x = HFEAST.kinds?.[k] || {};
    return `<li>${bowlSvg(k, 30)}<div><b>${esc(x.name || '')}</b> · 「${esc(x.buff || '')}」 <small class="muted">${HFEAST.buff_h}시간</small><p class="muted small">${esc(x.desc || '')}${k === HFEAST.tie ? ' · 갈래 수가 같으면 이 상' : ''}</p><p class="hf-fx">${effectText(x.effects).map(t => `<span class="chip ok">${esc(t)}</span>`).join('')}</p></div></li>`; }).join('');
  return card('kinds', '상 종류와 기운', 'spark', '', `<ul class="hf-kinds">${rows}</ul>`, false);
}

function viewHtml(v, fresh) {
  if (!v.port) return `${headHtml(v)}<p class="notice-line">${icon('pin', 14)} ${esc(HFEAST.away)} <span class="muted small">항구: ${esc(HFEAST.portNames())}</span></p><div class="hf-cols">${kindsCard()}</div>`;
  return `${headHtml(v)}
    ${v.here ? '' : `<p class="notice-line">${icon('pin', 14)} ${esc(HFEAST.away)}</p>`}
    <div class="hf-cols"><div class="hf-col">${tableCard(v, fresh)}</div><div class="hf-col">${eatCard(v)}${giveCard(v)}${kindsCard()}</div></div>
    <p class="muted small hf-next">다음 상은 ${esc(HFEAST.kst(v.slot_end))}부터 차립니다.</p>`;
}
