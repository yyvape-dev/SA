// 領地ゲームを、実際の画面ごと36週まで自動で押し進め、止まる所・エラーを探す（通しプレイの前の確認）
// 使い方: node terrain/tools/playthrough.js [出力フォルダ=/tmp/pt] [戦い方=auto]   ※静的サーバー（localhost:8123）が要る。10〜20分。Bash は run_in_background で
// 毎週：簡単な AI（建てる・兵・会話・配置）で行動点を使い →「週を終える」。出てくる画面（章の会話・朝の報告・襲撃の決断・任せた戦闘・一騎打ちの選出と勝負・結果）は、見えているボタンを順に押す。
// 出力：log.txt（週ごとの状態・ページのエラー）、止まったら stuck_*.png、章の始まりごとに ch*.png
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const out = process.argv[2] || '/tmp/pt'; fs.mkdirSync(out, { recursive: true });
const base = process.env.PT_URL || 'http://localhost:8123/terrain/';
const logF = path.join(out, 'log.txt'); fs.writeFileSync(logF, ''); const log = (...a) => { const s = a.join(' '); console.log(s); fs.appendFileSync(logF, s + '\n'); };
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 540, height: 960 } });
  const errs = []; p.on('pageerror', e => { errs.push(e.message); log('PAGEERROR', e.message); });
  p.on('console', m => { if (m.type() === 'error' && !/Failed to load resource/.test(m.text())) { errs.push(m.text()); log('CONSOLE', m.text()); } });
  p.on('dialog', d => d.accept());
  await p.goto(base + '?v=' + Date.now(), { waitUntil: 'load' });
  await p.waitForFunction(() => window.__t && window.__t.status && window.__t.status.ok, null, { timeout: 180000 });
  await p.evaluate(() => { window.__ptAI = () => { const T = window.__t, GM = T.GM, s = T.G(); if (!s || s.raid || s.over) return;
      const open = Object.keys(GM.PLOT_AREA).filter(id => GM.PLOT_AREA[id] === 'home' || s.open.includes(GM.PLOT_AREA[id]));
      const want = ['farm', 'smithy', 'tavern', 'farm', 'wall', 'farm', 'drill', 'tavern', 'wall', 'shrine', 'barracks', 'banner', 'war', 'farm', 'wall']; let g = 10;
      while (s.ap > 0 && g--) { const r = GM.nextRaid(s), lack = r ? r.E - GM.D(s) - GM.darkD(s, r) : -99, wk = r ? r.w - s.week : 99;
        if (s.morale < 35 && GM.canCastle(s, 'feast')) { GM.doCastle(s, 'feast'); continue; }
        const bt = Object.keys(s.plots).find(id => GM.canRepair(s, id)); if (bt) { GM.repair(s, bt); continue; }
        if (wk <= 1 && lack - (s.merc || 0) > -4 && GM.canCastle(s, 'merc')) { GM.doCastle(s, 'merc'); continue; }
        if (wk <= 2 && lack > -2 && GM.canCastle(s, 'troops')) { GM.doCastle(s, 'troops'); continue; }
        const cnt = {}; let done = false; for (const f of want) { cnt[f] = (cnt[f] || 0) + 1; if (!GM.facOpen(s, f) || GM.facCount(s, f) >= cnt[f]) continue; const id = open.find(id => !s.plots[id] && GM.canBuild(s, f, id)); if (id && GM.build(s, id, f)) { done = true; break; } } if (done) continue;
        const up = Object.keys(s.plots).find(id => GM.canUpgrade(s, id)); if (up && GM.upgrade(s, up)) continue;
        const k = Object.keys(GM.ALLY).find(k => GM.canTalk(s, k)); if (k && GM.talk(s, k)) continue;
        if (s.sup > 25 && GM.canCastle(s, 'invest')) { GM.doCastle(s, 'invest'); continue; }
        break; }
      for (const k of Object.keys(GM.ALLY)) { if (!GM.joined(s, k) || s.assign[k]) continue; const id = Object.keys(s.plots).find(id => GM.canAssign(s, k, id) && !GM.allyAt(s, id)); if (id) GM.assign(s, k, id); }
      T.commit(); };
    window.__ptStep = () => { const vis = e => { if (!e) return false; const r = e.getBoundingClientRect(), cs = getComputedStyle(e); return r.width > 0 && r.height > 0 && cs.display !== 'none' && cs.visibility !== 'hidden' && +cs.opacity > 0.05; };
      const order = ['.skip', '#dsel .go', '#duel .res.on', '#duel .sk', '#abt .fr .bd', '#abt .sk', '#rdec .go', '.big'];
      for (const sel of order) { const e = [...document.querySelectorAll(sel)].find(vis); if (e) { (sel === '#abt .fr .bd' ? e.parentElement : e).click(); return sel; } }
      const s = window.__t.G(); if (s.over) return 'over';
      const wk = document.querySelector('[data-wk]'); if (wk && vis(wk)) { if (!s.raid) window.__ptAI(); wk.click(); return 'week'; }
      return 'wait'; }; });
  let last = '', same = 0, steps = 0, lastCh = 0;
  while (steps++ < 4000) {
    const act = await p.evaluate(() => window.__ptStep());
    const st = await p.evaluate(() => { const s = window.__t.G(); return { w: s.week, raid: !!s.raid, over: s.over, why: s.why, sup: s.sup, mor: s.morale, hp: s.hp, tr: s.troops, D: Math.round(window.__t.GM.D(s)) }; });
    if (act === 'week') log(`週${st.w} 物資${st.sup} 民心${st.mor} 兵${st.tr} 耐久${st.hp} 防衛${st.D}${st.raid ? ' ［襲撃］' : ''}`);
    const ch = Math.ceil(st.w / 6); if (ch !== lastCh) { lastCh = ch; await p.screenshot({ path: path.join(out, `ch${ch}.png`) }); }
    if (st.over) { log('終了', st.over, st.why, '週', st.w); await p.screenshot({ path: path.join(out, 'end.png') }); break; }
    const key = `${st.w}|${st.raid}|${act}`; same = key === last ? same + 1 : 0; last = key;
    if (same === 80) { log('止まっている？', key); await p.screenshot({ path: path.join(out, `stuck_${st.w}.png`) }); }
    if (same > 160) { log('進まないので終了', key); break; }
    await p.waitForTimeout(act === 'wait' ? 500 : 250);
  }
  log('エラー件数', errs.length); await b.close();
})();
