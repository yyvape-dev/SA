// 36週のバランスを、ルール（game.js）だけで何千回も回して表にする（Skill sa-balance-sim）
// 使い方: cd terrain && node tools/balance_sim.mjs [回数=300] [出力.md]
// 建て方（作戦）×戦い方（任せる／自分で戦う：勝つ確率を仮定）ごとに、勝率・負けた週と理由・章ごとの物資・民心・防衛力と敵の規模の差・被害の段階を出す。
import fs from 'fs';
import * as GM from '../game.js';
const layout = JSON.parse(fs.readFileSync(new URL('../data/layout.json', import.meta.url)));
for (const p of layout.plots) GM.PLOT_AREA[p.id] = p.area;
const N = +(process.argv[2] || 300), OUT = process.argv[3] || '';
function seeded(seed) { let s = seed >>> 0; return () => { s = (s + 0x6D2B79F5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
const openPlots = s => layout.plots.filter(p => p.area === 'home' || s.open.includes(p.area)).map(p => p.id);
const STRAT = { // 建てる順の好み（毎回、できるものの中から先頭を選ぶ）
  econ:  ['farm', 'farm', 'tavern', 'farm', 'smithy', 'farm', 'tavern', 'wall', 'drill', 'war', 'shrine', 'barracks', 'banner', 'farm', 'farm'],
  def:   ['wall', 'smithy', 'farm', 'wall', 'farm', 'tavern', 'wall', 'barracks', 'drill', 'shrine', 'wall', 'war', 'banner', 'wall', 'farm'],
  bal:   ['farm', 'smithy', 'tavern', 'farm', 'wall', 'farm', 'drill', 'tavern', 'wall', 'shrine', 'barracks', 'banner', 'war', 'farm', 'wall'],
  fit:   ['farm', 'smithy', 'tavern', 'farm', 'wall', 'farm', 'drill', 'tavern', 'wall', 'shrine', 'barracks', 'banner', 'war', 'farm', 'wall'], // bal と同じ順で、場所は適地を優先
};
function plotFor(s, fac, strat) { const ids = openPlots(s).filter(id => !s.plots[id] && GM.canBuild(s, fac, id)); if (!ids.length) return null;
  if (strat === 'fit') { const f = ids.find(id => GM.fitOf(fac, id)); if (f) return f; } return ids[0]; }
function weekAI(s, strat, R) {
  let guard = 12;
  while (s.ap > 0 && !s.raid && !s.over && guard--) {
    const r = GM.nextRaid(s), wk = r ? r.w - s.week : 99, lack = r ? r.E - GM.D(s) - GM.darkD(s, r) : -99;
    if (s.morale < 35 && GM.canCastle(s, 'feast')) { GM.doCastle(s, 'feast'); continue; }
    const burnt = Object.keys(s.plots).find(id => GM.canRepair(s, id)); if (burnt) { GM.repair(s, burnt); continue; }
    if (r && r.dark && GM.holyD(s) < 0 && GM.facOpen(s, 'shrine')) { const id = plotFor(s, 'shrine', strat); if (id && GM.build(s, id, 'shrine')) continue; }
    if (wk <= 1 && lack + (s.merc || 0) > -2 && lack > 2 && GM.canCastle(s, 'merc')) { GM.doCastle(s, 'merc'); continue; } /* 足りない直前は傭兵 */
    if (wk <= 2 && lack > -2) { if (GM.canCastle(s, 'troops')) { GM.doCastle(s, 'troops'); continue; } const id = plotFor(s, 'wall', strat); if (id && GM.build(s, id, 'wall')) continue; }
    let done = false;
    const cnt = {}; for (const f of STRAT[strat]) { cnt[f] = (cnt[f] || 0) + 1; if (!GM.facOpen(s, f) || GM.facCount(s, f) >= cnt[f]) continue; /* 一覧に書いた数まで（farm が2回なら2つ） */ const id = plotFor(s, f, strat); if (id && GM.build(s, id, f)) { done = true; break; } }
    if (done) continue;
    const up = Object.keys(s.plots).filter(id => GM.canUpgrade(s, id)).sort((a, b) => GM.FAC[s.plots[a].fac].up - GM.FAC[s.plots[b].fac].up)[0]; if (up && GM.upgrade(s, up)) continue;
    const k = Object.keys(GM.ALLY).find(k => GM.canTalk(s, k)); if (k && GM.talk(s, k)) continue;
    if (GM.canCastle(s, 'troops') && s.sup > 8) { GM.doCastle(s, 'troops'); continue; }
    if (s.sup > 25 && GM.canCastle(s, 'invest')) { GM.doCastle(s, 'invest'); continue; }
    if (s.sup < 3 && s.morale > 65) { GM.doCastle(s, 'levy'); continue; }
    break;
  }
  for (const k of Object.keys(GM.ALLY)) { if (!GM.joined(s, k) || s.assign[k]) continue; const id = Object.keys(s.plots).find(id => GM.canAssign(s, k, id) && !GM.allyAt(s, id) && GM.AFFINITY[s.plots[id].fac].includes(k)) || Object.keys(s.plots).find(id => GM.canAssign(s, k, id) && !GM.allyAt(s, id)); if (id) GM.assign(s, k, id); }
}
function run(strat, mode, pHand, seed) {
  const R = seeded(seed), orig = Math.random; Math.random = R;
  const s = GM.newState(layout.areas); GM.startChapter(s, 1); const ch = [], raids = [];
  try {
    while (!s.over) {
      weekAI(s, strat, R); GM.endWeek(s);
      if (s.raid) { const rw = s.raid; GM.setRanka(s, true); if (GM.duelDue(s)) { const cs = GM.champions(s); if (cs.length) { const best = cs.sort((a, b) => GM.duelP(s, b) - GM.duelP(s, a)); GM.duel(s, GM.pairOK(s) && best.length > 1 ? best.slice(0, 2) : best[0], R); } }
        const margin = GM.raidD(s) - rw.E, tier = GM.autoTier(s, rw.E);
        const big = rw.gen || rw.boss, forced = mode === 'hand' ? R() < (big ? pHand - .15 : pHand) : undefined;
        GM.resolve(s, mode, R, forced); raids.push({ w: rw.w, E: rw.E, margin, tier, gen: !!rw.gen }); }
      if ((s.week - 1) % GM.CH_LEN === 0 && !ch[GM.chapterOf(s.week - 1) - 1] && s.week > 1) ch[GM.chapterOf(s.week - 1) - 1] = { sup: s.sup, mor: s.morale, D: GM.D(s), troops: s.troops, fac: Object.keys(s.plots).length };
    }
  } finally { Math.random = orig; }
  return { win: s.over === 'win', week: s.week, why: s.why, ch, raids };
}
const MODES = [['auto', 0, '任せる'], ['hand', .8, '自分で（勝率8割）'], ['hand', .6, '自分で（勝率6割）']];
const rows = [], chT = {}, raidT = {};
for (const st of Object.keys(STRAT)) for (const [mode, p, mn] of MODES) {
  const res = []; for (let i = 0; i < N; i++) res.push(run(st, mode, p, 1000 + i));
  const wins = res.filter(r => r.win).length, lose = res.filter(r => !r.win), why = {}; lose.forEach(r => { const k = `${r.why}（第${GM.chapterOf(r.week)}章）`; why[k] = (why[k] || 0) + 1; });
  rows.push(`| ${st} | ${mn} | ${(wins / N * 100).toFixed(0)}% | ${lose.length ? (lose.reduce((a, r) => a + r.week, 0) / lose.length).toFixed(1) : '-'} | ${Object.entries(why).sort((a, b) => b[1] - a[1]).slice(0, 3).map(([k, v]) => `${k}×${v}`).join('、') || '-'} |`);
  const key = `${st}／${mn}`; chT[key] = [1, 2, 3, 4, 5].map(c => { const xs = res.map(r => r.ch[c - 1]).filter(Boolean); if (!xs.length) return '-'; const av = f => (xs.reduce((a, x) => a + x[f], 0) / xs.length).toFixed(0); return `${av('sup')}/${av('mor')}/${av('D')}/${av('troops')}（${xs.length}）`; });
  raidT[key] = GM.SCHED.map(r => { const xs = res.flatMap(x => x.raids.filter(q => q.w === r.w)); if (!xs.length) return '-'; return `${(xs.reduce((a, q) => a + q.margin, 0) / xs.length).toFixed(0)}`; });
}
let md = `# 36週のバランス（${N}回ずつ、${new Date().toISOString().slice(0, 10)}）\n\n## 勝率\n| 建て方 | 戦い方 | 勝率 | 負けた週の平均 | 負けた理由（多い順） |\n|---|---|---|---|---|\n${rows.join('\n')}\n`;
md += `\n## 章の終わり（物資/民心/防衛力/兵（その章まで残った回数））\n| 作戦／戦い方 | 1 | 2 | 3 | 4 | 5 |\n|---|---|---|---|---|---|\n${Object.entries(chT).map(([k, v]) => `| ${k} | ${v.join(' | ')} |`).join('\n')}\n`;
md += `\n## 襲撃ごとの「防衛力−敵の規模」の平均（+4以上で任せても被害なし）\n| 作戦／戦い方 | ${GM.SCHED.map(r => `${r.w}週${r.gen ? '★' : ''}(${r.E})`).join(' | ')} |\n|---|${GM.SCHED.map(() => '---').join('|')}|\n${Object.entries(raidT).map(([k, v]) => `| ${k} | ${v.join(' | ')} |`).join('\n')}\n`;
if (OUT) fs.writeFileSync(OUT, md); console.log(md);
