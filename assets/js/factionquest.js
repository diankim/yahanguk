// 대세력 퀘스트·등급·의뢰판·비고·수련장·인물(캐릭터 › 세력). 진행과 판정은 서버(world_faction_*)가 하고, 여기서는 그리고 부른다.
// 대화는 게임 안 팝업에서 한 줄씩 넘겨 보인다(지문은 기울임, 대사는 인물 이름표).
import { act, esc, icon, guard, $, $$, fmt, openModal, openLayer, closeModal, ask } from './core.js';
import { panel, chip, invalidate } from './views/common.js';
import { factionColor } from './geo.js';
import { replayLog } from './replay.js';
import { logRow } from './spar.js';

// 등급 효과(서버 world_faction_rank_effect와 같은 값, 2~5등급)
const RANK_PERK = {
  night_office: r => `단서 발견 +${(r - 1) * 2}%`, red_moon_cult: r => `주는 피해 +${r - 1}%`, black_lotus: r => `희귀품 +${r - 1}%`,
  north_league: r => `받는 피해 −${r - 1}%`, river_alliance: r => `이동 시간 −${(r - 1) * 2}%`, southern_remnant: r => `채집량 +${(r - 1) * 2}%`,
  mandate_court: r => `예언 · 요괴 조우 −${(r - 1) * 2}% · 날씨·시간대 불이익 −${(r - 1) * 10}%`,
};

// 대화 팝업: lines [{s: 인물 키 | null, t}] · cast {키: {name}}
export function playDialogue(r, fid) {
  const lines = r?.lines || [];
  if (!lines.length) return;
  const hue = factionColor(fid);
  let i = 0;
  const m = openModal({ title: r.title || '세력', body: `<div class="dlg-box" tabindex="0" role="button" aria-label="다음 줄">
      <div class="dlg-plate" style="--fc:${hue}"></div><p class="dlg-text"></p>
      <div class="dlg-foot"><small class="dlg-count"></small><small class="muted">누르면 다음 줄</small></div></div>
      <div class="dlg-end" hidden>${r.rank_name ? `<p class="hint good">${icon('flag', 14)} 지금 등급 · <b>${esc(r.rank_name)}</b></p>` : ''}${r.reward ? `<p class="hint">${icon('bag', 14)} 받은 것 · ${esc(r.reward)}</p>` : ''}<button class="btn primary" data-dlg-close>닫기</button></div>` });
  const box = $('.dlg-box', m), plate = $('.dlg-plate', m), text = $('.dlg-text', m), cnt = $('.dlg-count', m), end = $('.dlg-end', m);
  const show = () => {
    const l = lines[i], who = l.s ? (r.cast?.[l.s]?.name || '') : '';
    plate.textContent = who; plate.hidden = !who;
    text.textContent = l.t; text.classList.toggle('narr', !l.s);
    cnt.textContent = `${i + 1} / ${lines.length}`;
    if (i === lines.length - 1) end.hidden = false;
  };
  const next = () => { if (i < lines.length - 1) { i++; show(); } };
  box.onclick = next;
  box.onkeydown = e => { if (e.key === 'Enter' || e.key === ' ' || e.key === 'ArrowRight') { e.preventDefault(); next(); } };
  $('[data-dlg-close]', m).onclick = () => closeModal();
  show(); box.focus();
}

const taskRows = tasks => (tasks || []).map(t => `<li class="${t.cur >= t.n ? 'done' : ''}">${icon(t.cur >= t.n ? 'check' : 'chevron', 13)}<span>${esc(t.label)}</span><small>${fmt.num(t.cur)}/${fmt.num(t.n)}</small></li>`).join('');

export function factionPanels(s, c) {
  const fid = s.faction_id, rk = s.rank || 1, ranks = s.ranks || [], q = s.quest;
  const ladder = `<ol class="rank-ladder" style="--fc:${factionColor(fid)}">${ranks.map((n, i) => `<li class="${i + 1 < rk ? 'past' : i + 1 === rk ? 'now' : ''}"><b>${i + 1}</b><span>${esc(n)}</span></li>`).join('')}</ol>`;
  const perk = RANK_PERK[fid];
  const questHtml = s.rejoin_pending
    ? `<div class="fq-card"><b>${icon('scroll', 14)} 돌아온 이에게</b><p class="muted small">다시 돌아온 조사원을 세력 사람들이 맞이합니다.</p><button class="btn primary" data-fq-report>대화 보기</button></div>`
    : q ? `<div class="fq-card ${q.ready ? 'ready' : ''}">
        <p class="eyebrow">${q.kind === 'join' ? `가입 퀘스트 ${q.step}/3` : `등급 퀘스트 · ${esc(ranks[q.step - 1] || '')}`}</p>
        <b>${esc(q.title)}</b><p class="small">${esc(q.goal)}</p>
        ${(q.tasks || []).length ? `<ul class="fq-tasks">${taskRows(q.tasks)}</ul>` : ''}
        ${q.locked ? `<p class="hint warn">${icon('shield', 14)} ${esc(q.locked)}</p>` : ''}
        ${!q.locked && (q.at_names || []).length && !q.here_ok ? `<p class="hint">${icon('pin', 14)} ${esc(q.at_names.join('·'))}에서 보고합니다.</p>` : ''}
        ${q.cost ? `<p class="hint">${icon('coin', 14)} ${fmt.num(q.cost)}전이 듭니다.</p>` : ''}
        <button class="btn ${q.ready ? 'primary' : ''}" data-fq-report ${q.ready ? '' : 'disabled'}>${icon('scroll', 16)}<span>${q.ready ? (q.tasks?.length ? '보고하기' : '대화하기') : '아직 할 일이 남았습니다'}</span></button>
        ${q.tasks?.length ? `<p class="muted small">할 일은 이 장면이 열린 뒤부터 셉니다.</p>` : ''}</div>`
      : `<p class="desc">${icon('check', 14)} 모든 등급 퀘스트를 마쳤습니다.</p>`;
  const reqs = s.requests || [];
  const vault = s.vault || [], hall = s.hall || {}, kp = s.keepers || {};
  const vaultOpen = s.join_done && s.at_home;
  return `
    ${panel('세력 등급', `
      ${ladder}
      <div class="chips">${chip(`평판 ${fmt.num(s.rep)}`, 'accent')}${chip(`공훈 ${fmt.num(s.merit)}`, 'ok')}${s.next ? chip(`다음 등급 · 평판 ${fmt.num(s.next.rep)} · Lv${s.next.level}`) : chip('최고 등급')}</div>
      <p class="small">${perk ? `등급 효과 · 지금 ${esc(perk(rk))}${rk < 5 ? ` (최고 등급 ${esc(perk(5))})` : ''}` : ''} · 등급이 오를수록 비고 품목이 늘어납니다.</p>
      <label class="check"><input type="checkbox" id="fq-show" ${s.show_rank ? 'checked' : ''} ${s.join_done ? '' : 'disabled'}><span>프로필·조사원 카드에 세력 등급 보이기</span></label>
      <h3 class="sub-h">${s.join_done ? '등급 퀘스트' : '가입 퀘스트'}</h3>${questHtml}
      <p class="muted small">평판은 그 세력 일로 쌓이는 누적 값(등급 기준)이고, 공훈은 의뢰판·퀘스트로 모아 비고에서 쓰는 몫입니다. 공훈을 써도 평판은 줄지 않습니다.</p>`, { ico: 'flag' })}
    ${panel('의뢰판', `<p class="muted small">매일(한국 시각 0시) 세 가지 의뢰가 바뀝니다. 오늘 한 일을 세고, 다 되면 받습니다.</p>
      <ul class="fq-reqs">${reqs.map(r => `<li><div><b>${esc(r.title)}</b><ul class="fq-tasks">${taskRows(r.tasks)}</ul><small class="muted">평판 +${r.rep} · 공훈 +${r.merit}</small></div>
        ${r.claimed ? chip('받음', 'ok') : `<button class="btn small ${r.ready ? 'primary' : ''}" data-fq-req="${esc(r.key)}" ${r.ready ? '' : 'disabled'}>${r.ready ? '받기' : '진행 중'}</button>`}</li>`).join('')}</ul>`, { ico: 'scroll' })}
    ${panel(kp.vault?.title || '비고', `${kp.vault ? `<p class="fq-keeper"><b>${esc(kp.vault.who || '')}</b> “${esc(kp.vault.line || '')}”</p>` : ''}
      ${!s.join_done ? `<p class="hint">${icon('shield', 14)} 가입 퀘스트를 마치면 열립니다.</p>` : !s.at_home ? `<p class="hint">${icon('pin', 14)} ${esc((s.home_names || []).join('·'))}에서 열 수 있습니다.</p>` : ''}
      <ul class="fq-vault">${vault.map(v => `<li class="${v.locked ? 'locked' : ''}"><div><b>${esc(v.name)}</b><small class="muted">공훈 ${fmt.num(v.price)}${v.locked ? ` · ${esc(ranks[v.rank_need - 1] || '')}부터` : ''}</small></div>
        <div class="fq-buy"><input type="number" min="1" max="99" value="1" id="fqq-${esc(v.item_id)}" aria-label="수량" ${vaultOpen && !v.locked ? '' : 'disabled'}><button class="btn small" data-fq-buy="${esc(v.item_id)}" ${vaultOpen && !v.locked ? '' : 'disabled'}>사기</button></div></li>`).join('')}</ul>
      <p class="muted small">공훈으로만 사고, 비고는 물건을 사들이지 않습니다.</p>`, { ico: 'bag' })}
    ${panel(kp.hall?.title || '수련장', `${kp.hall ? `<p class="fq-keeper"><b>${esc(kp.hall.who || '')}</b> “${esc(kp.hall.line || '')}”</p>` : ''}
      <p class="small">지금 등급(${rk}등급) 시련 · 상대 Lv${hall.foe_level ?? '-'} · 하루 한 번 · 내 전투 능력치(공격력·방어·치명타·회피)로 12합까지 겨룹니다. 이기면 공훈 +${10 * rk}, 3·5등급 시련을 처음 넘으면 세력 칭호(5등급은 세력 낙관도)를 받습니다.</p>
      <button class="btn ${hall.done_today ? '' : 'primary'}" id="fq-trial" ${s.join_done && s.at_home && !hall.done_today ? '' : 'disabled'}>${icon('sword', 16)}<span>${hall.done_today ? '오늘은 이미 치렀습니다' : !s.join_done ? '가입 퀘스트를 마치면 열립니다' : !s.at_home ? '세력 안전지대에서 열립니다' : '시련 치르기'}</span></button>`, { ico: 'sword' })}
    ${panel('세력 인물', (s.npcs || []).length ? `<ul class="fq-npcs">${s.npcs.map(n => `<li><button type="button" class="fq-npc" data-npc="${esc(n.key)}"><b>${esc(n.name)}</b>${n.quote ? `<q>${esc(n.quote)}</q>` : ''}<small>${esc(n.bio)}</small></button></li>`).join('')}</ul>
      <p class="muted small">만난 인물 ${s.npcs.length}/${s.npc_total || s.npcs.length} · 이름을 누르면 인물 기록을 펼칩니다. 퀘스트에서 처음 대화하면 여기에 남습니다.</p>` : `<p class="muted small">아직 만난 인물이 없습니다. 퀘스트에서 대화하면 인물 정보가 여기에 남습니다.</p>`, { ico: 'users' })}`;
}

export function bindFaction(body, s, redraw) {
  const done = () => { invalidate('world_faction_snapshot'); redraw?.(); };
  $$('[data-fq-report]', body).forEach(b => b.onclick = () => guard(b, async () => {
    const r = await act('world_faction_report');
    playDialogue(r, s.faction_id); done(); return null;
  }));
  $$('[data-fq-req]', body).forEach(b => b.onclick = () => guard(b, async () => { const r = await act('world_faction_request_claim', { p_req: b.dataset.fqReq }); done(); return r; }));
  $$('[data-fq-buy]', body).forEach(b => b.onclick = async () => {
    const id = b.dataset.fqBuy, qty = Math.max(1, Math.min(99, Number($(`#fqq-${id}`, body)?.value) || 1));
    const v = (s.vault || []).find(x => x.item_id === id);
    if (!(await ask(`${v?.name || id} ×${qty}을(를) 공훈 ${fmt.num((v?.price || 0) * qty)}으로 살까요?`, { title: '비고', ok: '사기' }))) return;
    guard(b, async () => { const r = await act('world_faction_vault_buy', { p_item: id, p_qty: qty }); done(); return r; });
  });
  const tr = $('#fq-trial', body);
  if (tr) tr.onclick = () => guard(tr, async () => {
    const r = await act('world_faction_trial');
    // 시련 전투를 한 줄씩 펼치고, 끝나면(또는 건너뛰면) 결과를 보인다
    const m = openModal({ title: `${s.keepers?.hall?.title || '수련장'} · ${r.tier}등급 시련`, body: `<div class="spar-result">
      <ol class="spar-log replay"></ol><button class="btn small ghost" data-skip>건너뛰기</button>
      <div class="spar-end" hidden><p class="lead ${r.won ? 'ok' : 'bad'}">${r.won ? '시련을 넘었습니다' : '시련에 졌습니다'}</p><p class="small">${esc(r.content || '')}</p></div></div>` });
    replayLog($('.spar-log', m), r.log || [], logRow, { skipBtn: $('[data-skip]', m), onDone: () => { $('.spar-end', m).hidden = false; } });
    done(); return null;
  });
  // 세력 인물 기록: 한 줄 소개 대사와 자세한 서술
  $$('[data-npc]', body).forEach(b => b.onclick = () => {
    const n = (s.npcs || []).find(x => x.key === b.dataset.npc); if (!n) return;
    const cut = n.name.lastIndexOf(' '), title = cut > 0 ? n.name.slice(0, cut) : '', who = cut > 0 ? n.name.slice(cut + 1) : n.name;
    openLayer({ title: '세력 인물', body: `<article class="npc-card" style="--fc:${factionColor(s.faction_id)}">
      <header><small>${esc(title)}</small><h3>${esc(who)}</h3></header>
      ${n.quote ? `<blockquote>“${esc(n.quote)}”</blockquote>` : ''}
      <p class="npc-bio">${esc(n.bio)}</p>
      ${n.detail ? n.detail.split(/(?<=다\.)\s+/).reduce((acc, t, i) => { const k = Math.floor(i / 2); (acc[k] = acc[k] || []).push(t); return acc; }, []).map(p => `<p>${esc(p.join(' '))}</p>`).join('') : ''}</article>` });
  });
  const sh = $('#fq-show', body);
  if (sh) sh.onchange = () => guard(sh, async () => { const r = await act('world_faction_show_rank', { p_show: sh.checked }); done(); return r; });
}
