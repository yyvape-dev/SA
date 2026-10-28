// 領地づくりのルール（状態と計算だけ。画面は持たない）。base5 の式を領地マップ向けに移したもの。
// 状態 s は保存できる素のオブジェクト。行動は「できるか can」と「実行 apply」に分け、ボタンの表示にも同じ式を使う。

export const FAC = { // 施設。stage 1=建築中（効果なし、週末に完成） 2=完成（効果×1） 3=発展後（効果×2）
  farm:   { n: '畑',     cost: 3, up: 4, eff: { sup: 2 }, d: '毎週の物資+2' },
  tavern: { n: '酒場',   cost: 4, up: 5, eff: { mor: 3 }, d: '毎週の民心+3' },
  smithy: { n: '鍛冶場', cost: 5, up: 6, eff: { def: 4 }, d: '防衛力+4' },
};
export const STAGE = ['空き地', '建築中', '完成', '発展後'];
export const WEEKS = 12;
export const SCHED = [ // 襲撃の予定（E=敵の規模）。後半ほど強く、家の街だけでは守り切れない強さにする
  { w: 3, E: 13, name: '野盗の襲撃' }, { w: 5, E: 18, name: '謀反軍の偵察隊' }, { w: 7, E: 24, name: '謀反軍の先遣隊' },
  { w: 9, E: 31, name: '将軍の副官の軍' }, { w: 11, E: 38, name: '謀反軍の本隊' }, { w: 12, E: 46, name: '将軍の侵攻', boss: true },
];
const CAP_TROOPS = 16;
// 仲間。join=仲間になる条件（開拓した区域）。絆は0〜3。効果は絆2と絆3で増える（base5 の式をもとに、戦闘の補正を足した）
export const ALLY = {
  mina:  { n: 'ミナ',   r: '捕縛役', join: null,   lv: ['', '', '自分で戦う成功率+12%・戦闘の拘束+0.4秒', '自分で戦う成功率+さらに8%・拘束+さらに0.4秒'] },
  garou: { n: 'ガロウ', r: '火力役', join: 'east', lv: ['', '', '防衛力+4・戦闘のダメージ+15%', '防衛力+7・ダメージ+30%'] },
  sera:  { n: 'セラ',   r: '内政役', join: 'lake', lv: ['', '', '畑の産出+1ずつ・戦闘の最大HP+20', '炊き出しの民心+15・最大HP+40'] },
};
export const joined = (s, k) => !ALLY[k].join || s.open.includes(ALLY[k].join);
const bond = (s, k) => (s.bond && s.bond[k]) || 0;
export const canTalk = (s, k) => joined(s, k) && bond(s, k) < 3 && !s.over && !s.raid && s.ap >= 1;
export function talk(s, k) { if (!canTalk(s, k)) return false; s.ap -= 1; s.bond[k] = bond(s, k) + 1; s.log.push(`${ALLY[k].n}と過ごした（絆${s.bond[k]}）`); return true; }
export function battleMods(s) { // アクション戦闘へ渡す補正
  const m = bond(s, 'mina'), g = bond(s, 'garou'), r = bond(s, 'sera');
  return { dmg: 1 + (g >= 3 ? .3 : g >= 2 ? .15 : 0), bind: m >= 3 ? .8 : m >= 2 ? .4 : 0, hp: r >= 3 ? 40 : r >= 2 ? 20 : 0 };
}
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const mult = st => (st === 2 ? 1 : st === 3 ? 2 : 0);

export function newState(areaDefs) {
  return { week: 1, ap: 3, sup: 10, morale: 60, troops: 4, hp: 3, plots: {}, open: [], bond: { mina: 0, garou: 0, sera: 0 }, battle: null, scouted: {}, tired: false, over: null, why: '', raid: null, log: [], areaDefs: areaDefs.map(a => ({ id: a.id, name: a.name, cost: a.cost, income: a.income })) };
}

// ---------- 指標（全部ここから計算） ----------
function effSum(s, key) { let v = 0; for (const p of Object.values(s.plots)) { const f = FAC[p.fac]; if (f && f.eff[key]) v += (f.eff[key] + (key === 'sup' && bond(s, 'sera') >= 2 ? 1 : 0)) * mult(p.stage); } return v; }
export const D = s => s.troops * 1.5 + effSum(s, 'def') + 2 + (bond(s, 'garou') >= 3 ? 7 : bond(s, 'garou') >= 2 ? 4 : 0);                       // 防衛力
export const landInc = s => s.areaDefs.filter(a => s.open.includes(a.id)).reduce((t, a) => t + a.income, 0);
export const income = s => 4 + effSum(s, 'sup') + landInc(s) - Math.floor(s.troops / 2); // 毎週の物資
export const moraleD = s => -2 + effSum(s, 'mor');                                   // 毎週の民心
export const apOf = m => (m < 30 ? 2 : m >= 80 ? 4 : 3);
export const nextRaid = s => SCHED.find(r => r.w >= s.week);
export const handP = (s, E) => clamp(.45 + clamp((D(s) - E) / 40, -.2, .2) + (bond(s, 'mina') >= 2 ? .12 : 0) + (bond(s, 'mina') >= 3 ? .08 : 0), .12, .92); // 確率で解決するときの成功率
// アクション戦闘で耐える波の数（敵の規模から）
export const wavesOf = E => clamp(Math.round(E / 7), 2, 7);

// ---------- 行動 ----------
const spend = (s, c) => { s.ap -= 1; s.sup -= c; };
export function canBuild(s, fac) { return !s.over && !s.raid && s.ap >= 1 && s.sup >= FAC[fac].cost; }
export function build(s, id, fac) { if (!canBuild(s, fac) || s.plots[id]) return false; spend(s, FAC[fac].cost); s.plots[id] = { fac, stage: 1 }; s.log.push(`${FAC[fac].n}の建築を始めた`); return true; }
export function canUpgrade(s, id) { const p = s.plots[id]; return !!p && p.stage === 2 && !s.over && !s.raid && s.ap >= 1 && s.sup >= FAC[p.fac].up; }
export function upgrade(s, id) { if (!canUpgrade(s, id)) return false; const p = s.plots[id]; spend(s, FAC[p.fac].up); p.stage = 3; s.log.push(`${FAC[p.fac].n}を発展させた`); return true; }
export function demolish(s, id) { if (!s.plots[id] || s.raid || s.over) return false; s.log.push(`${FAC[s.plots[id].fac].n}を取り壊した`); delete s.plots[id]; return true; }
export function canOpen(s, a) { return !s.open.includes(a.id) && !s.over && !s.raid && s.ap >= 1 && s.sup >= a.cost; }
export function openArea(s, a) { if (!canOpen(s, a)) return false; spend(s, a.cost); s.open.push(a.id); s.log.push(`${a.name}を開拓した`); return true; }

export const CASTLE = { // 城でできること
  troops: { t: '兵を募る', cost: 3, d: '兵力+2（物資の維持費が増える）', can: s => s.troops < CAP_TROOPS, ap: s => { s.troops = Math.min(CAP_TROOPS, s.troops + 2); } },
  levy:   { t: '徴発',     cost: 0, d: '物資+5 民心-8', can: () => true, ap: s => { s.sup += 5; s.morale = clamp(s.morale - 8, 0, 100); } },
  feast:  { t: '炊き出し', cost: 3, d: '民心+10', can: () => true, ap: s => { s.morale = clamp(s.morale + (bond(s, 'sera') >= 3 ? 15 : 10), 0, 100); } },
  scout:  { t: '偵察',     cost: 0, d: '次の襲撃の規模が確定', can: s => { const r = nextRaid(s); return !!r && !s.scouted[r.w]; }, ap: s => { s.scouted[nextRaid(s).w] = true; } },
  sortie: { t: '出撃',     cost: 0, d: '敵の前哨（規模14）を攻める。勝てば物資+8', can: s => s.troops >= 2, ap: s => { s.raid = { kind: 'sortie', E: 14, name: '敵の前哨' }; } },
};
export function canCastle(s, id) { const a = CASTLE[id]; return !s.over && !s.raid && s.ap >= 1 && s.sup >= a.cost && a.can(s); }
export function doCastle(s, id) { if (!canCastle(s, id)) return false; const a = CASTLE[id]; spend(s, a.cost); a.ap(s); s.log.push(`${a.t}を行った`); return true; }

// 偵察前の襲撃の規模は、幅で見せる（±3）
export function raidView(s) { const r = nextRaid(s); if (!r) return null; return { ...r, known: !!s.scouted[r.w], lo: r.E - 3, hi: r.E + 3, inWeeks: r.w - s.week }; }

// ---------- 週末と戦闘 ----------
export function endWeek(s) {
  if (s.over || s.raid) return null;
  const i = income(s), d = moraleD(s);
  s.sup = Math.max(0, s.sup + i); s.morale = clamp(s.morale + d, 0, 100);
  const done = [];
  for (const [id, p] of Object.entries(s.plots)) if (p.stage === 1) { p.stage = 2; done.push(FAC[p.fac].n); }
  const msg = `週末：物資${i >= 0 ? '+' : ''}${i} 民心${d >= 0 ? '+' : ''}${d}${done.length ? '／完成：' + done.join('・') : ''}`;
  s.log.push(msg);
  const r = SCHED.find(x => x.w === s.week);
  if (r) s.raid = { kind: 'raid', E: r.E, name: r.name, boss: !!r.boss, w: r.w }; else afterWeek(s);
  return msg;
}
function afterWeek(s) {
  checkLose(s); if (s.over) return;
  s.week++; if (s.week > WEEKS) { s.over = 'win'; s.why = `${WEEKS}週を生き延びた`; return; }
  s.ap = Math.max(1, apOf(s.morale) - (s.tired ? 1 : 0)); s.tired = false;
}
function checkLose(s) { if (s.over) return; if (s.hp <= 0) { s.over = 'lose'; s.why = '城が落とされた'; } else if (s.morale <= 0) { s.over = 'lose'; s.why = '民心が尽き、反乱が起きた'; } }
export function resolve(s, mode, rnd = Math.random, forced) { // forced: アクション戦闘の結果（true/false）。なければ確率で解決
  const R = s.raid; if (!R) return ''; const E = R.E, m = D(s) - E * (0.9 + rnd() * 0.2);
  const at = m >= 4 ? 0 : m >= 0 ? 1 : m >= -4 ? 2 : 3; let ok, tier, t = `${R.name}（${mode === 'auto' ? '任せた' : forced === undefined ? '自分で戦った' : '自分で戦った・' + (forced ? '勝利' : '敗北')}）：`;
  if (mode === 'auto') { tier = at; ok = tier === 0; } else { ok = forced === undefined ? rnd() < handP(s, E) : !!forced; tier = ok ? 0 : clamp(at + 1, 1, 3); if (R.kind === 'sortie') s.ap = Math.max(0, s.ap - 1); else s.tired = true; }
  s.raid = null;
  if (R.boss) { s.over = ok ? 'win' : 'lose'; s.why = ok ? '将軍の侵攻を退けた' : '将軍に城を落とされた'; s.log.push(t + (ok ? '勝利' : '敗北')); return t + (ok ? '勝利' : '敗北'); }
  if (R.kind === 'sortie') {
    if (ok) { const g = mode === 'hand' ? 10 : 8; s.sup += g; s.morale += 3; t += `勝利 物資+${g}`; }
    else if (tier === 1) { s.morale -= 5; s.sup -= 2; t += '苦戦 民心-5 物資-2'; }
    else { s.troops -= 1; s.morale -= 8; t += '敗走 兵力-1 民心-8'; }
  } else if (tier === 0) { if (mode === 'hand') { s.sup += 4; s.morale += 5; t += '完勝 物資+4 民心+5'; } else t += '被害なし'; }
  else if (tier === 1) { s.sup -= 3; s.morale -= 5; t += '小被害 物資-3 民心-5'; }
  else if (tier === 2) { s.sup -= 5; s.morale -= 12; s.troops -= 1; t += '中被害 物資-5 民心-12 兵力-1'; }
  else { s.hp -= 1; s.morale -= 15; s.troops -= 2; s.sup -= 5; t += '大被害 城の耐久-1 民心-15 兵力-2 物資-5'; }
  s.sup = Math.max(0, s.sup); s.troops = Math.max(0, s.troops); s.morale = clamp(s.morale, 0, 100);
  s.log.push(t);
  if (R.kind === 'raid') afterWeek(s); else checkLose(s);
  return t;
}
// 結果の見込み（任せた場合の被害の段階）
export function autoTier(s, E) { const m = D(s) - E; return m >= 4 ? '被害なし' : m >= 0 ? '小被害' : m >= -4 ? '中被害' : '大被害'; }
