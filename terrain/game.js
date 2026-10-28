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
  { w: 3, E: 13, name: '野盗の襲撃', dir: 'river' }, { w: 5, E: 18, name: '謀反軍の偵察隊', dir: 'pass' }, { w: 7, E: 24, name: '謀反軍の先遣隊', dir: 'river' },
  { w: 9, E: 31, name: '将軍の副官の軍', dir: 'pass' }, { w: 11, E: 38, name: '謀反軍の本隊', dir: 'river' }, { w: 12, E: 46, name: '将軍の侵攻', boss: true, dir: 'pass' },
];
const CAP_TROOPS = 16;
// 戦場（敵が来る方角）。前線＝街の外で迎え撃つ場所
export const FRONT = { pass: { n: '山道の峠', from: '北西の山道' }, river: { n: '川の渡し場', from: '西の川' } };
// 仲間。join=仲間になる条件（開拓した区域）。絆は0〜3。効果は絆2と絆3で増える（base5 の式をもとに、戦闘の補正を足した）
export const ALLY = {
  mina:  { n: 'ミナ',   r: '捕縛役', join: null,   lv: ['', '', '自分で戦う成功率+12%・戦闘の拘束+0.4秒', '自分で戦う成功率+さらに8%・拘束+さらに0.4秒'] },
  garou: { n: 'ガロウ', r: '火力役', join: 'east', lv: ['', '', '防衛力+4・戦闘のダメージ+15%', '防衛力+7・ダメージ+30%'] },
  sera:  { n: 'セラ',   r: '内政役', join: 'lake', lv: ['', '', '畑の産出+1ずつ・戦闘の最大HP+20', '炊き出しの民心+15・最大HP+40'] },
  ranka: { n: 'ランカ', r: '火力役・将軍', join: 'forest', lv: ['', '', '出撃時の効果がさらに強くなる（防衛力+4・ダメージ+10%）', '出撃時の効果がさらに強くなる（防衛力+8・ダメージ+20%）'] },
};
// 施設への配置：仲間1人につき施設1つ。完成・発展後の施設だけ。得意な施設なら効果+基本値ぶん、そうでなければ半分（切り上げ）
export const AFFINITY = { farm: ['sera'], tavern: ['sera', 'garou', 'ranka'], smithy: ['garou', 'mina', 'ranka'] };
export function assignBonus(fac, k) { const e = Object.values(FAC[fac].eff)[0]; if (k === 'ranka' && fac !== 'farm') return e * 2; return AFFINITY[fac].includes(k) ? e : Math.ceil(e / 2); } // ランカは酒場（民心）か鍛冶場（防衛）で2倍
export const allyAt = (s, id) => Object.keys(s.assign || {}).find(k => s.assign[k] === id) || null;
export function canAssign(s, k, id) { const p = s.plots[id]; return joined(s, k) && !!p && p.stage >= 2 && !s.over && !s.raid && s.assign[k] !== id; }
export function assign(s, k, id) { if (!canAssign(s, k, id)) return false; const other = allyAt(s, id); if (other) delete s.assign[other]; s.assign[k] = id; s.log.push(`${ALLY[k].n}を${FAC[s.plots[id].fac].n}に配置した`); return true; }
export function unassign(s, k) { if (!s.assign[k]) return false; delete s.assign[k]; return true; }
function cleanAssign(s) { for (const k of Object.keys(s.assign || {})) { const p = s.plots[s.assign[k]]; if (!p || p.stage < 2) delete s.assign[k]; } }
export const joined = (s, k) => !ALLY[k].join || s.open.includes(ALLY[k].join);
const bond = (s, k) => (s.bond && s.bond[k]) || 0;
export const canTalk = (s, k) => joined(s, k) && !(k === 'ranka' && s.rankaAway) && bond(s, k) < 3 && !s.over && !s.raid && s.ap >= 1;
export function talk(s, k) { if (!canTalk(s, k)) return false; s.ap -= 1; s.bond[k] = bond(s, k) + 1; s.log.push(`${ALLY[k].n}と過ごした（絆${s.bond[k]}）`); return true; }
// ランカの出撃：最強の戦力。出た次の戦闘は休み（2回続けて出られない）
export const rankaReady = s => joined(s, 'ranka') && !s.rankaRest && !s.rankaAway;
export const rankaD = s => 10 + (bond(s, 'ranka') >= 3 ? 8 : bond(s, 'ranka') >= 2 ? 4 : 0);
export const rankaDmg = s => .4 + (bond(s, 'ranka') >= 3 ? .2 : bond(s, 'ranka') >= 2 ? .1 : 0);
export const raidD = s => D(s) + (s.raid && s.raid.ranka ? rankaD(s) : 0);
export function setRanka(s, on) { if (s.raid) s.raid.ranka = !!on && rankaReady(s); }
export function battleMods(s) { // アクション戦闘へ渡す補正
  const m = bond(s, 'mina'), g = bond(s, 'garou'), r = bond(s, 'sera'), k = bond(s, 'ranka');
  const rk = s.raid && s.raid.ranka; return { dmg: 1 + (g >= 3 ? .3 : g >= 2 ? .15 : 0) + (rk ? rankaDmg(s) : 0), bind: m >= 3 ? .8 : m >= 2 ? .4 : 0, hp: (r >= 3 ? 40 : r >= 2 ? 20 : 0) + (rk ? 30 : 0) };
}
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const mult = st => (st === 2 ? 1 : st === 3 ? 2 : 0);

export function newState(areaDefs) {
  return { week: 1, ap: 3, sup: 10, morale: 60, troops: 4, hp: 3, plots: {}, open: [], bond: { mina: 0, garou: 0, sera: 0, ranka: 0 }, assign: {}, battle: null, scouted: {}, tired: false, over: null, why: '', raid: null, log: [], areaDefs: areaDefs.map(a => ({ id: a.id, name: a.name, cost: a.cost, income: a.income })) };
}

// ---------- 指標（全部ここから計算） ----------
const DIM = [1, .7, .5, .35, .25]; // 鍛冶場は2つ目から効きが落ちる（大きい順に並べて掛ける）。積むだけでは勝てないように
function effSum(s, key) {
  const vals = [];
  for (const [id, p] of Object.entries(s.plots)) { const f = FAC[p.fac]; if (!f || !f.eff[key] || p.burnt) continue;
    let v = (f.eff[key] + (key === 'sup' && bond(s, 'sera') >= 2 ? 1 : 0)) * mult(p.stage);
    const k = allyAt(s, id); if (k && p.stage >= 2 && !(k === 'ranka' && s.rankaAway)) v += assignBonus(p.fac, k); vals.push(v); }
  if (key !== 'def') return vals.reduce((t, v) => t + v, 0); // 物資・民心は足し算のまま
  vals.sort((a, b) => b - a); return Math.round(vals.reduce((t, v, i) => t + v * (DIM[i] ?? .2), 0));
}
export const D = s => s.troops * 1.5 + effSum(s, 'def') + 2 + (bond(s, 'garou') >= 3 ? 7 : bond(s, 'garou') >= 2 ? 4 : 0); // ランカ（将軍）は兵を強くする                       // 防衛力
export const landInc = s => s.areaDefs.filter(a => s.open.includes(a.id)).reduce((t, a) => t + a.income, 0);
export const income = s => 4 + effSum(s, 'sup') + landInc(s) - Math.floor(s.troops / 2); // 毎週の物資
export const moraleD = s => -2 + effSum(s, 'mor');                                   // 毎週の民心
export const apOf = m => (m < 30 ? 2 : m >= 80 ? 4 : 3);
export const nextRaid = s => SCHED.find(r => r.w >= s.week);
export const handP = (s, E) => clamp(.45 + clamp((raidD(s) - E) / 40, -.2, .2) + (bond(s, 'mina') >= 2 ? .12 : 0) + (bond(s, 'mina') >= 3 ? .08 : 0), .12, .92); // 確率で解決するときの成功率
// アクション戦闘で耐える波の数（敵の規模から）
export const wavesOf = E => clamp(Math.round(E / 7), 2, 7);

// ---------- 行動 ----------
const spend = (s, c) => { s.ap -= 1; s.sup -= c; };
export function canBuild(s, fac) { return !s.over && !s.raid && s.ap >= 1 && s.sup >= FAC[fac].cost; }
export function build(s, id, fac) { if (!canBuild(s, fac) || s.plots[id]) return false; spend(s, FAC[fac].cost); s.plots[id] = { fac, stage: 1 }; s.log.push(`${FAC[fac].n}の建築を始めた`); return true; }
export function canUpgrade(s, id) { const p = s.plots[id]; return !!p && p.stage === 2 && !p.burnt && !s.over && !s.raid && s.ap >= 1 && s.sup >= FAC[p.fac].up; }
export function upgrade(s, id) { if (!canUpgrade(s, id)) return false; const p = s.plots[id]; spend(s, FAC[p.fac].up); p.stage = 3; s.log.push(`${FAC[p.fac].n}を発展させた`); return true; }
export function demolish(s, id) { if (!s.plots[id] || s.raid || s.over) return false; s.log.push(`${FAC[s.plots[id].fac].n}を取り壊した`); delete s.plots[id]; cleanAssign(s); return true; }
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
export function raidView(s) { const r = nextRaid(s); if (!r) return null; return { ...r, front: FRONT[r.dir], known: !!s.scouted[r.w], lo: r.E - 3, hi: r.E + 3, inWeeks: r.w - s.week }; }

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
  if (r) s.raid = { kind: 'raid', E: r.E, name: r.name, boss: !!r.boss, w: r.w, dir: r.dir }; else afterWeek(s);
  return msg;
}
function afterWeek(s) {
  checkLose(s); if (s.over) return;
  s.week++; if (s.week > WEEKS) { s.over = 'win'; s.why = `${WEEKS}週を生き延びた`; return; }
  s.ap = Math.max(1, apOf(s.morale) - (s.tired ? 1 : 0)); s.tired = false;
  // ランカは、たまにその週の街にいない（4分の1。2週続けてはいない）。配置の効果も出撃もなし
  s.rankaAway = joined(s, 'ranka') && !s.rankaAway && Math.random() < .25;
  if (s.rankaAway) s.log.push('ランカは今週、街にいない');
}
function checkLose(s) { if (s.over) return; if (s.hp <= 0) { s.over = 'lose'; s.why = '城が落とされた'; } else if (s.morale <= 0) { s.over = 'lose'; s.why = '民心が尽き、反乱が起きた'; } }
// 前線を破られると、敵が街に入り込み、施設が焼かれる（効果なし。修理すると戻る）
function burn(s, n, rnd) { const ids = Object.keys(s.plots).filter(id => s.plots[id].stage >= 2 && !s.plots[id].burnt); const out = [];
  for (let i = 0; i < n && ids.length; i++) { const id = ids.splice(Math.floor(rnd() * ids.length), 1)[0]; s.plots[id].burnt = true; out.push(FAC[s.plots[id].fac].n); }
  return out.length ? `／${out.join('・')}が焼かれた` : ''; }
export const REPAIR = 2;
export const canRepair = (s, id) => !!s.plots[id] && s.plots[id].burnt && !s.over && !s.raid && s.ap >= 1 && s.sup >= REPAIR;
export function repair(s, id) { if (!canRepair(s, id)) return false; s.ap -= 1; s.sup -= REPAIR; delete s.plots[id].burnt; s.log.push(`${FAC[s.plots[id].fac].n}を修理した`); return true; }
export function resolve(s, mode, rnd = Math.random, forced) { // forced: アクション戦闘の結果（true/false）。なければ確率で解決
  const R = s.raid; if (!R) return ''; const E = R.E, m = raidD(s) - E * (0.9 + rnd() * 0.2) + (R.duel === true ? 7 : R.duel === false ? -7 : 0); // 一騎打ちの勝敗で、結果が約1段動く
  if (joined(s, 'ranka')) s.rankaRest = !!R.ranka; // 出たら次は休み、休んだら次は出られる
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
  else if (tier === 2) { s.sup -= 5; s.morale -= 12; s.troops -= 1; t += '中被害 物資-5 民心-12 兵力-1' + burn(s, 1, rnd); }
  else { s.hp -= 1; s.morale -= 15; s.troops -= 2; s.sup -= 5; t += '大被害 城の耐久-1 民心-15 兵力-2 物資-5' + burn(s, 2, rnd); }
  s.sup = Math.max(0, s.sup); s.troops = Math.max(0, s.troops); s.morale = clamp(s.morale, 0, 100);
  s.log.push(t);
  if (R.kind === 'raid') afterWeek(s); else checkLose(s);
  return t;
}
// 結果の見込み（任せた場合の被害の段階）
export function autoTier(s, E) { const m = raidD(s) - E; return m >= 4 ? '被害なし' : m >= 0 ? '小被害' : m >= -4 ? '中被害' : '大被害'; }

// ---------- 吹き出しのせりふ（立ち絵と一緒に出す）。相手は女王ラナ（ミナ・ガロウ＝姫、セラ＝姫さま、ランカ＝お嬢） ----------
export const LINES = {
  mina: { idle: ['姫、ちゃんと寝てる？ ……べ、別に心配してるわけじゃ、なくもないけど。', 'あの夜、姫の手を引いて走ったこと、今でも夢に見るよ。……大丈夫、もう離さないから。', '敵をまとめて縛るのは任せて。昔取った杵柄ってやつ。……盗賊の頃の話は、なしね。'],
    farm: ['畑の見張りも、わたしの仕事。カラスは縛れないけど……追い払うくらいはできるよ。'], tavern: ['酒場って噂が集まるんだ。姫に悪いこと言うやつがいたら、すぐ分かるよ。'], smithy: ['捕縛網の目、もっと細かくしてもらってる。これで誰も逃がさない。姫の邪魔は、させない。'],
    b3: ['……ほんとはね、国なんて取り戻せなくてもいいんだ。姫と二人で生きていけるなら。――でも、姫がそう望むなら、わたしはどこまでもついてく。'] },
  garou: { idle: ['ガハハ！ 姫、今日も城は無事ですぜ。この斧がある限りな。', '傭兵の頃は金のために振ってた斧ですがね……今は姫のために振ってまさぁ。', '細けえ策はミナとセラに任せた。俺は姫の前に立つだけよ。ガハハ！'],
    farm: ['畑ですかい？ ガハハ、鍬も斧も似たようなもんでさぁ。'], tavern: ['酒場は俺の庭みてえなもんで。兵どもの愚痴も、ちゃんと聞いときますぜ、姫。'], smithy: ['いい鉄だ。これなら姫の兵、誰一人死なせやしねえ。'],
    b3: ['姫。昔の俺は、誰の旗の下でも戦った。……だが最後の旗は、姫のもんだと決めてますぜ。'] },
  sera: { idle: ['物資の帳簿、今週も合いました。姫さまのおかげです。', '民の顔が明るい国は、強い国です。', '急がず、でも止まらず。国づくりはそういうものです。'],
    farm: ['今年の麦は良く実りそうです。冬の蓄えも心配いりません。'], tavern: ['酒場の笑い声は、民心の物差しです。'], smithy: ['鍛冶の帳簿は、鉄より重いんです……。'],
    b3: ['姫さまの国を、もう一度。そのためなら、私は何年でも数字を数えます。'] },
  ranka: { idle: ['お嬢、戦の話？ 任せといてよ。わたしが出れば、だいたい片付くじゃん？', '謀反の将軍たち？ 一回ちゃんと負けたほうがいいよね、あの人たち。', '数で来られても、束ねちゃえば一緒じゃん？ お嬢もそう思うよね。'],
    farm: ['畑仕事かぁ……わたし向きじゃないよね？ ま、お嬢が言うならやるけどさ。'], tavern: ['酒場はいいよね〜。兵のみんなと飲んでると、士気って勝手に上がるんだよ。'], smithy: ['刃はちゃんと研いどいてよ？ お嬢の兵、一人も無駄にしたくないじゃん。'],
    rest: ['さすがに連戦はキツいって。次は休ませてよね、お嬢。'],
    b3: ['お嬢の旗の下なら、わたし何回でも立てるよ。……あ、今の照れるから忘れて。'] },
};
export function lineOf(s, k, rnd = Math.random) {
  const L = LINES[k], at = s.assign && s.assign[k], fac = at && s.plots[at] ? s.plots[at].fac : null;
  if (k === 'ranka' && s.rankaRest && L.rest) return L.rest[0];
  const pool = [...L.idle, ...(fac ? L[fac] : []), ...(fac ? L[fac] : []), ...(bond(s, k) >= 3 ? L.b3 : [])];
  return pool[Math.floor(rnd() * pool.length)];
}

// ---------- 週末の報告：変更点と注意点 ----------
// 報告役（内政役）：仲間に入ると、羊皮紙の代わりに吹き出しで報告する
export const ADVISOR = { key: 'sera', join: 'lake' }; // 内政役のセラが、湖畔で仲間になると報告役になる
export const advisorOf = s => (ADVISOR.key && (!ADVISOR.join || s.open.includes(ADVISOR.join)) ? ADVISOR.key : (s.advisorTest || null));
export function snap(s) { return { week: s.week, sup: s.sup, morale: s.morale, troops: s.troops, hp: s.hp, plots: JSON.parse(JSON.stringify(s.plots)), logN: s.log.length }; }
export function weekReport(prev, s) {
  const ch = [], wr = [], d = (a, b) => (b - a >= 0 ? '+' : '') + (b - a);
  ch.push(`物資 ${prev.sup} → ${s.sup}（${d(prev.sup, s.sup)}）`);
  ch.push(`民心 ${Math.round(prev.morale)} → ${Math.round(s.morale)}（${d(Math.round(prev.morale), Math.round(s.morale))}）`);
  if (prev.troops !== s.troops) ch.push(`兵 ${prev.troops} → ${s.troops}`);
  if (prev.hp !== s.hp) ch.push(`城の耐久 ${prev.hp} → ${s.hp}`);
  const done = Object.entries(s.plots).filter(([id, p]) => prev.plots[id] && prev.plots[id].stage === 1 && p.stage === 2).map(([id, p]) => FAC[p.fac].n);
  if (done.length) ch.push(`完成：${done.join('・')}`);
  for (const t of s.log.slice(prev.logN)) if (/襲撃|偵察隊|先遣隊|副官|本隊|侵攻/.test(t) && /：/.test(t)) ch.push(t);
  // 注意点
  const r = nextRaid(s);
  if (r) { const lack = r.E - D(s), wk = r.w - s.week; if (lack > -4) wr.push(`${wk ? wk + '週後' : '今週末'}に${r.name}（規模${s.scouted[r.w] ? r.E : '約' + r.E}）。防衛力${Math.round(D(s))}では${lack > 0 ? '足りない' : 'ぎりぎり'}。`); else if (wk <= 1) wr.push(`${wk ? '来週末' : '今週末'}に${r.name}。防衛力は足りている。`); }
  if (income(s) < 0) wr.push(`毎週の物資が${income(s)}。兵の維持費が重い。`);
  if (s.morale < 35) wr.push(`民心${Math.round(s.morale)}。30を切ると行動点が2に減る。`);
  else if (moraleD(s) < 0 && s.morale < 55) wr.push(`民心が毎週${moraleD(s)}ずつ下がっている。酒場か炊き出しを。`);
  const bt = Object.values(s.plots).filter(p => p.burnt).length; if (bt) wr.push(`焼かれた施設が${bt}つ。修理するまで効果がない。`);
  { const r2 = nextRaid(s); if (r2 && r2.w - s.week <= 2) wr.push(`敵の陣が${FRONT[r2.dir].from}に見える（${r2.w - s.week ? r2.w - s.week + '週後' : '今週末'}）。`); }
  if (s.rankaAway) wr.push('ランカは今週、街にいない。配置の効果も出撃もなし。');
  const idle = Object.keys(ALLY).filter(k => joined(s, k) && !(s.assign || {})[k]);
  if (idle.length && Object.values(s.plots).some(p => p.stage >= 2)) wr.push(`${idle.map(k => ALLY[k].n).join('・')}が施設に配置されていない。`);
  const a = s.areaDefs.find(a => !s.open.includes(a.id)); if (a && s.sup >= a.cost + 2) wr.push(`物資が貯まっている。${a.name}を開拓できる（物資${a.cost}）。`);
  return { title: `第${prev.week}週の報告`, changes: ch, warns: wr };
}

// ---------- 一騎打ち（接戦のとき、将軍同士が戦う） ----------
export const DUEL_POW = { ranka: 14, garou: 11, mina: 9, sera: 6 };
export const duelDue = s => !!s.raid && (s.raid.boss || s.raid.E >= 30 || Math.abs(raidD(s) - s.raid.E) <= 4); // 副官と将軍は必ず一騎打ちに出てくる
export const champions = s => Object.keys(ALLY).filter(k => joined(s, k) && !(k === 'ranka' && (s.rankaAway || !s.raid.ranka)));
export const foeGeneral = s => ({ n: s.raid.boss ? '謀反の将軍' : s.raid.E >= 30 ? '将軍の副官' : '敵の隊長', pow: s.raid.E / 3 + (s.raid.boss ? 6 : s.raid.E >= 30 ? 2 : 0) });
export const duelPow = (s, k) => DUEL_POW[k] + bond(s, k) * 1.5;
export const duelP = (s, k) => clamp(.5 + (duelPow(s, k) - foeGeneral(s).pow) / 16, .1, .9);
export function duel(s, k, rnd = Math.random) { const win = rnd() < duelP(s, k); s.raid.duel = win; s.raid.champ = k; s.log.push(`一騎打ち：${ALLY[k].n}が${win ? '勝った' : '敗れた'}`); return win; }
