import { $, $$, esc, icon, fmt, act, rpc, ask, guard, openModal, bar, nameOf, empty } from '../core.js';
import { REALM_BOND as RB } from '../rules.js';
import { load, chip, panel, rarRow } from './common.js';
import { helpQ } from '../tips.js';
import { pickRows, openItemPick, bundleChips } from './itempick.js';
import { openItemInfo } from './item.js';

const num = RB.num;
const TABS = [['reqs', '의뢰판', 'flag'], ['donate', '특산 기부', 'coin'], ['vault', '비고', 'chest'], ['perks', '혜택', 'spark'], ['story', '이야기', 'scroll']];
let tab = 'reqs';
let picks = {};
let picksRealm = null;

const ladder = st => `<ol class="rank-ladder rb-ladder" title="${esc(RB.ladderTip())}">${(RB.stages || []).map(s => `<li class="${s.n < st ? 'past' : s.n === st ? 'now' : ''}"><b>${s.n}</b><span>${esc(s.name)}</span></li>`).join('')}</ol>`;
const ptsBar = c => {
  const nx = c.next, from = RB.stageNeed(c.stage), to = nx ? nx.need : from;
  return nx ? `<div class="rb-bar">${bar(Math.max(0, c.pts - from), Math.max(1, to - from), 'gold')}<small class="muted">인연도 ${num(c.pts)} / ${num(to)}${c.pts >= to ? ' · 문턱 넘음' : ` · ${num(to - c.pts)} 남음`}</small></div>`
    : `<div class="rb-bar">${bar(1, 1, 'gold')}<small class="muted">인연도 ${num(c.pts)} · 가장 높은 단계</small></div>`;
};
const dayChips = c => `${chip(`오늘 ${num(c.today)}/${num(c.today_cap)}`, c.today >= c.today_cap ? 'ok' : '')}${chip(`모든 권역 ${num(c.all_today)}/${num(c.all_cap)}`, c.all_today >= c.all_cap ? 'ok' : '')}${chip(`인연 표 ${fmt.num(c.tokens)}`, 'accent')}`;
const nextHtml = c => {
  const x = c.next; if (!x) return `<p class="small ok">${icon('check', 13)} ${esc(RB.nextLine(null))}</p>`;
  const st = RB.storyState(x), ok = x.quest_done || x.quest_active || !x.quest_why;
  return `<p class="small rb-next">${esc(RB.nextLine(x))}${x.quest_at ? ` <span class="muted">· 받는 곳 ${esc(x.quest_at)}</span>` : ''}</p>
    <p class="small ${x.quest_done ? 'ok' : ok ? 'accent' : 'muted'} rb-why">${icon(x.quest_done ? 'check' : ok ? 'scroll' : 'knot', 12)} ${esc(st)}</p>`;
};

function cardHtml(c, here) {
  if (!c.opened) return `<article class="rb-card off"><header><b>${esc(c.name)}</b></header><small class="muted">${esc(RB.unopened)}</small></article>`;
  const atHub = here?.realm === c.realm && here?.hub;
  return `<article class="rb-card" data-rb-open="${esc(c.realm)}" tabindex="0" role="button" aria-label="${esc(c.name)} 권역 인연 열기">
    <header><b>${esc(c.name)}</b><span class="chip accent">${c.stage} ${esc(c.stage_name)}</span>${atHub ? chip('여기', 'ok') : ''}</header>
    ${ladder(c.stage)}${ptsBar(c)}
    <div class="chips">${dayChips(c)}</div>
    ${nextHtml(c)}
    <small class="muted rb-foot">${icon('pin', 12)}<span>${esc(c.hub_name || '')} 안전지대 · 누르면 의뢰판·기부·비고</span></small></article>`;
}

export async function realmTab(body) {
  const d = await load('world_realm_bond_list', undefined, { maxAge: 60000 });
  const list = d?.realms || [], any = list.some(c => c.opened);
  body.innerHTML = panel('권역 인연', `<p class="desc">${esc(RB.intro)}</p>
    ${any ? '' : `<p class="hint">${icon('pin', 14)} ${esc(RB.none)}</p>`}
    <div class="rb-grid">${list.map(c => cardHtml(c, d?.here)).join('')}</div>`, { ico: 'hand', extra: helpQ(RB.help(), '권역 인연 안내') });
  $$('[data-rb-open]', body).forEach(b => {
    b.onclick = () => openRealmBond(b.dataset.rbOpen);
    b.onkeydown = e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openRealmBond(b.dataset.rbOpen); } };
  });
}

const taskRows = r => [...(r.tasks || []).map(t => `<li class="${t.have >= t.n ? 'done' : ''}">${icon(t.have >= t.n ? 'check' : 'chevron', 13)}<span>${esc(t.label)}</span><small>${fmt.num(t.have)}/${fmt.num(t.n)}${esc(t.unit || '')}</small></li>`),
  ...(r.give || []).map(g => `<li class="${g.have >= g.n ? 'done' : ''}">${icon(g.have >= g.n ? 'check' : 'chevron', 13)}<span>「<button type="button" class="linkish" data-rb-info="${esc(g.item_id)}">${esc(g.name)}</button>」 넘기기</span><small>${fmt.num(Math.min(g.have, g.n))}/${fmt.num(g.n)}개</small></li>`)].join('');

function reqsHtml(v) {
  const full = v.room <= 0, can = v.at_hub && !full;
  return `<p class="muted small">${esc(RB.reqNote())}</p>
    ${full ? `<p class="hint good">${icon('check', 14)} ${esc(RB.capFull)}</p>` : ''}
    <ul class="fq-reqs rb-reqs">${(v.board || []).map(r => `<li class="${r.claimed ? 'owned' : ''}"><div><b>${esc(r.title)}</b><ul class="fq-tasks">${taskRows(r)}</ul><small class="muted">인연도·인연 표 +${num(r.reward)}${(r.give || []).length ? ' · 넘길 물품은 보고할 때 가방에서 빠집니다' : ''}</small></div>
      ${r.claimed ? chip('받음', 'ok') : `<button class="btn small ${r.ready && can ? 'primary' : ''}" data-here="권역 의뢰 보고" data-rb-req="${esc(r.key)}" ${r.ready && can ? '' : 'disabled'}>${r.ready ? '보고' : '진행 중'}</button>`}</li>`).join('')}</ul>`;
}

function donateHtml(v) {
  const sp = v.specials || [], has = sp.some(s => s.have > 0), full = v.room <= 0, can = v.at_hub && !full;
  return `<p class="muted small">${esc(RB.donateNote())}</p>
    <div class="chips">${chip(`오늘 더 쌓을 수 있는 몫 ${num(v.room)}`, full ? 'ok' : '')}</div>
    <ul class="rb-specials">${sp.map(s => `<li class="${rarRow(s.item_id)}"><button type="button" class="linkish" data-rb-info="${esc(s.item_id)}">${esc(s.name)}</button><small class="muted">시세 ${fmt.num(s.price)}전 · 가방 ${fmt.num(s.have)}</small></li>`).join('')}</ul>
    ${full ? `<p class="hint good">${icon('check', 14)} ${esc(RB.capFull)}</p>` : !has ? `<p class="muted small">넘길 수 있는 특산 재료가 가방에 없습니다. ${esc(v.name)} 권역에서 채집하거나 토벌해 모으세요.</p>` : `
    <div class="chips rb-picked">${bundleChips(picks, 'data-rb-rm')}</div>
    <div class="btn-row"><button class="btn small" type="button" id="rb-pick" data-here="권역 기부" ${can ? '' : 'disabled'}>${icon('bag', 15)}<span>가방에서 고르기</span></button>
      <button class="btn primary" type="button" id="rb-donate" data-here="권역 기부" disabled>${icon('coin', 16)}<span>기부하기</span></button></div>
    <p class="small" id="rb-don-sum"></p>`}`;
}

function vaultHtml(v) {
  const items = v.vault || [];
  return `<div class="chips">${chip(`인연 표 ${fmt.num(v.tokens)}`, 'accent')}${chip(`${v.stage}단계 「${v.stage_name}」`)}</div>
    ${items.length ? `<ul class="fq-vault rb-vault">${items.map(x => {
      const off = !v.at_hub || !x.open || v.tokens < x.price;
      return `<li class="${x.kind === 'item' ? rarRow(x.id) : ''} ${x.open ? '' : 'locked'} ${x.owned ? 'owned' : ''}"><div>
        <b>${x.kind === 'item' ? `<button type="button" class="linkish" data-rb-info="${esc(x.id)}">${esc(x.name)}</button>` : esc(x.name)} ${chip(RB.kinds[x.kind] || '')}</b>
        <small class="muted">인연 표 ${fmt.num(x.price)}${x.open ? '' : ` · ${x.stage}단계 「${esc(RB.stageName(x.stage))}」부터`}</small></div>
        ${x.owned ? chip('가짐', 'ok') : `<button class="btn small ${off ? '' : 'primary'}" data-here="권역 비고 교환" data-rb-buy="${esc(x.id)}" ${off ? 'disabled' : ''}>${!x.open ? icon('knot', 13) + '<span>잠김</span>' : v.tokens < x.price ? '표 모자람' : '받기'}</button>`}</li>`; }).join('')}</ul>` : empty('아직 준비된 비고 품목이 없습니다.')}
    <p class="muted small">${esc(RB.vaultNote)}</p>`;
}

const perksHtml = v => `<table class="guide-table rb-perks"><thead><tr><th>단계</th><th>그 권역 안에서</th></tr></thead><tbody>
  ${(v.perks || []).map(p => `<tr class="${p.on ? 'on' : ''}"><td>${p.stage} ${esc(RB.stageName(p.stage))}</td><td>${esc(p.text)}${p.on ? ` <span class="chip ok">${icon('check', 11)}받는 중</span>` : ''}</td></tr>`).join('')}</tbody></table>
  <p class="muted small">혜택은 그 권역 안에서만 붙고, 휴식 회복은 그 권역 안전지대에서만 붙습니다.</p>`;

const storyHtml = v => `<p class="muted small">${esc(RB.storyNote)}</p>
  <ol class="rb-story">${(v.story || []).map(s => { const open = s.done || s.active || !s.why;
    return `<li class="${s.done ? 'done' : s.active ? 'now' : open ? 'open' : 'locked'}"><header><span class="chip">${s.stage}단계 「${esc(RB.stageName(s.stage))}」</span><b>${esc(s.title)}</b></header>
      <small class="rb-why ${s.done ? 'ok' : open ? 'accent' : 'muted'}">${icon(s.done ? 'check' : open ? 'scroll' : 'knot', 12)} ${esc(RB.storyState(s))}</small>
      ${open && s.summary ? `<p class="small muted">${esc(s.summary)}</p>` : ''}</li>`; }).join('')}</ol>`;

function bodyHtml(v) {
  const sec = { reqs: reqsHtml, donate: donateHtml, vault: vaultHtml, perks: perksHtml, story: storyHtml }[tab] || reqsHtml;
  return `<div class="rb">
    <div class="rb-head"><div class="rb-title"><span class="chip accent">${v.stage} ${esc(v.stage_name)}</span>${v.at_hub ? chip('안전지대에 있음', 'ok') : ''}</div>
      ${ladder(v.stage)}${ptsBar(v)}<div class="chips">${dayChips(v)}</div>${nextHtml(v)}</div>
    ${v.at_hub ? '' : `<p class="hint">${icon('pin', 14)} ${esc(RB.away(v.hub_name || v.name))}</p>`}
    <div class="segmented with-ico rb-tabs" role="tablist" style="--n:${TABS.length}">${TABS.map(([k, l, ic]) => `<button role="tab" type="button" data-rb-tab="${k}" class="${k === tab ? 'on' : ''}" aria-selected="${k === tab}" title="${esc(l)}">${icon(ic, 16)}<span>${esc(l)}</span></button>`).join('')}</div>
    <div class="rb-sec">${sec(v)}</div></div>`;
}

function donate(m, v) {
  const box = $('.rb-sec', m); if (!box || tab !== 'donate') return;
  const sp = (v.specials || []).filter(s => s.have > 0), rate = v.donate_gil || RB.gain?.donate_gil || 50;
  for (const id of Object.keys(picks)) { const s = sp.find(x => x.item_id === id); if (!s) delete picks[id]; else picks[id] = Math.min(picks[id], s.have); }
  const rows = pickRows(sp.map(s => ({ id: s.item_id, name: s.name, have: s.have, max: s.have, sub: `시세 ${fmt.num(s.price)}전` })), []);
  const calc = sel => {
    let val = 0, n = 0, top = 0;
    for (const [id, q] of (sel instanceof Map ? sel : new Map(Object.entries(sel)))) { const s = sp.find(x => x.item_id === id); if (s && q > 0) { val += s.price * q; n += q; top = Math.max(top, s.price); } }
    const amt = val / rate;
    return { val, n, amt, gain: Math.min(amt, v.room), over: amt - top / rate >= v.room };
  };
  const sumText = (c, lead = true) => c.n ? `${lead ? `${fmt.num(c.n)}개 · ` : ''}시세 ${fmt.num(c.val)}전 → 인연도 <b>+${num(c.gain)}</b>${c.over ? ` <span class="warn">(오늘 더 쌓을 수 있는 몫 ${num(v.room)}을 크게 넘습니다 — 수량을 줄이세요)</span>` : c.amt > v.room ? ` <span class="muted">(넘는 몫은 쌓이지 않음)</span>` : ''}` : '';
  const c = calc(picks), sum = $('#rb-don-sum', box), btn = $('#rb-donate', box);
  if (sum) sum.innerHTML = sumText(c);
  if (btn) btn.disabled = !c.n || c.over || !v.at_hub;
  $('#rb-pick', box)?.addEventListener('click', () => openItemPick({ title: `${v.name}에 넘길 특산 재료`, rows, many: true, picked: picks, okText: '이대로 담기',
    sumText: sel => { const x = calc(sel); return x.n ? ` · ${sumText(x, false)}` : ''; }, onDone: p => { picks = p; draw(m, v); } }));
  $$('[data-rb-rm]', box).forEach(b => b.onclick = e => { e.preventDefault(); delete picks[b.getAttribute('data-rb-rm')]; draw(m, v); });
  if (btn) btn.onclick = async () => {
    const chosen = Object.entries(picks).filter(([, q]) => q > 0);
    if (!chosen.length) return;
    const nm = id => sp.find(s => s.item_id === id)?.name || nameOf(id);
    if (!(await ask(`${chosen.map(([id, q]) => `${nm(id)} ×${q}`).join(', ')}을(를) ${v.name}에 기부할까요? 넘긴 물품은 돌려받지 못합니다.`, { title: '권역 기부', ok: '기부' }))) return;
    const r = await guard(btn, () => act('world_realm_bond_donate', { p_items: Object.fromEntries(chosen) }));
    if (r?.ok) { picks = {}; await reload(m, v.realm); }
  };
}

function draw(m, v) {
  const host = $('.rb-host', m); if (!host) return;
  if (picksRealm !== v.realm) { picks = {}; picksRealm = v.realm; }
  m._v = v;
  host.innerHTML = bodyHtml(v);
  $$('[data-rb-tab]', host).forEach(b => b.onclick = () => { tab = b.dataset.rbTab; try { sessionStorage.setItem('yh-rb-tab', tab); } catch {} draw(m, v); });
  $$('[data-rb-info]', host).forEach(b => b.onclick = () => openItemInfo(b.dataset.rbInfo));
  $$('[data-rb-req]', host).forEach(b => b.onclick = async () => {
    const r = await guard(b, () => act('world_realm_bond_claim', { p_req: b.dataset.rbReq, p_realm: v.realm }));
    if (r?.ok) await reload(m, v.realm);
  });
  $$('[data-rb-buy]', host).forEach(b => b.onclick = async () => {
    const x = (v.vault || []).find(y => y.id === b.dataset.rbBuy); if (!x) return;
    if (!(await ask(`${x.name}을(를) 인연 표 ${fmt.num(x.price)}(으)로 받을까요?`, { title: `${v.name} 비고`, ok: '받기' }))) return;
    const r = await guard(b, () => act('world_realm_bond_buy', { p_key: x.id }));
    if (r?.ok) await reload(m, v.realm);
  });
  donate(m, v);
}

async function reload(m, realm) {
  const v = await rpc('world_realm_bond_view', { p_realm: realm });
  const t = $('.modal-head h2, .modal-title', m);
  if (!v?.realm) { const host = $('.rb-host', m); if (host) host.innerHTML = `<p class="hint">${icon('pin', 14)} ${esc(RB.none)}</p>`; return; }
  if (t) t.textContent = `권역 인연 · ${v.name}`;
  if (!v.opened) { const host = $('.rb-host', m); if (host) host.innerHTML = `<p class="hint">${icon('pin', 14)} ${esc(v.name)} — ${esc(RB.unopened)}. 그 권역 안전지대에 처음 닿으면 인연이 시작됩니다.</p>`; return; }
  draw(m, v);
}

export async function openRealmBond(realm = null) {
  try { tab = sessionStorage.getItem('yh-rb-tab') || tab; } catch {}
  if (!TABS.some(x => x[0] === tab)) tab = 'reqs';
  const m = openModal({ title: '권역 인연', wide: true, body: '<div class="rb-host"><div class="loading"><span class="spinner"></span>불러오는 중…</div></div>' });
  try { await reload(m, realm); }
  catch (e) { const host = $('.rb-host', m); if (host) host.innerHTML = `<p class="hint warn">${esc(e.message || '불러오지 못했습니다.')}</p>`; }
  return m;
}

export const realmTile = r => { const k = RB.realmOfHub(r); return k ? ['realm', 'hand', '인연', `${RB.realmName(k)} · ${RB.tile}`] : null; };
