// シナリオの状態・到達順・ページ・勝敗を確認する。node terrain/tools/scenario_check.mjs
import assert from 'node:assert/strict';
import * as EV from '../scenario-events.js';
import { SCENES, LOSE_C } from '../scenario.js';
import * as N from '../narrative.js';
import * as GM from '../game.js';
const ids = new Set(), speakers = new Set(['rana', 'mina', 'garou', 'sera', 'ranka', 'lily', 'foe', 'g1', 'g2', 'g3', 'g4', 'g5', 'g6']);
const joinedAt = { mina: 1, garou: 7, sera: 13, ranka: 19, lily: 25 };
let utterances = 0;
function check(lines, week, label) {
  assert.ok(lines.length, `${label}: empty`);
  for (const [who, text] of lines) {
    assert.ok(speakers.has(who) || who.startsWith('@'), `${label}: ${who}`);
    assert.ok(text && !text.includes('undefined'), label);
    assert.ok(!joinedAt[who] || week >= joinedAt[who], `${label}: ${who} before joining`);
    utterances++;
  }
  for (const [, text] of N.pages(lines)) {
    assert.ok(text.split('\n').length <= 2, `${label}: too many rows`);
    assert.ok(text.split('\n').every(row => [...row].length <= 18), `${label}: too long`);
  }
}
for (const option of [0, 1, null]) {
  const state = N.prepareNarrative(GM.newState([]));
  for (let week = 1; week <= 36; week++) {
    state.week = week;
    for (const event of EV.WEEK[week] || []) {
      if (option === 0) { assert.ok(!ids.has(event.id), event.id); ids.add(event.id); }
      const scene = N.materialize(event, state);
      check(scene.lines, week, event.id);
      if (event.choices) for (let index = 0; index < event.choices.length; index++) check(N.readLines(event.choices[index].reply, state), week, event.id);
      if (event.choices && option !== null) {
        assert.equal(N.recordChoice(state, event.id, option, event.choices), true);
        const saved = JSON.parse(JSON.stringify(state));
        assert.equal(N.recordChoice(saved, event.id, 1 - option, event.choices), false, 'choice replay must be idempotent');
        const resumed = N.materialize(event, saved);
        assert.equal(resumed.choices, undefined, 'reload must resume saved answer');
        assert.deepEqual(event.choices[option].reply, resumed.lines.slice(-event.choices[option].reply.length));
      }
      if (event.battle) {
        check(N.skirmishLines(event, true, state), week, event.id + ':win');
        check(N.skirmishLines(event, false, state), week, event.id + ':loss');
        assert.notDeepEqual(event.after, event.afterLose);
      }
    }
  }
  for (const tone of ['mercy', 'rigor', 'both']) check(EV.endingVoices(state, tone), 36, 'epilogue');
}
for (const [chapter, scene] of Object.entries(SCENES)) {
  for (const [kind, lines] of Object.entries(scene)) check(lines, (+chapter - 1) * 6 + 1, chapter + ':' + kind);
}
for (const [chapter, lines] of Object.entries(LOSE_C)) check(lines, +chapter * 6, 'chapter loss');
for (const [who, scenes] of Object.entries(EV.BOND)) for (const [level, lines] of Object.entries(scenes)) check(lines, joinedAt[who], who + level);
check(EV.JUDGE.lines, 36, 'judgment');
for (const c of EV.JUDGE.choices) check(c.reply, 36, 'sentence');
check(EV.FINAL_ESCAPE, 36, 'escape');
const oldSave = { week: 20, evSeen: { c1_thief: 1 }, bondSeen: { mina1: 1 } };
N.prepareNarrative(oldSave);
assert.equal(oldSave.storyLegacy, true);
assert.deepEqual(oldSave.storyChoices, {});
assert.equal(oldSave.evSeen.c1_thief, 1);
assert.equal(oldSave.bondSeen.mina1, 1);
// 防衛補正で最終勝利になった場合も、章会話が敗北にならない。
const fortress = GM.newState([]);
fortress.week = 36; fortress.troops = 100;
fortress.raid = { kind: 'raid', gen: 6, boss: true, E: 1, name: 'test' };
GM.resolve(fortress, 'hand', () => 0.5, false);
assert.equal(fortress.over, 'win');
assert.equal(fortress.chEnd.win, true);
console.log(JSON.stringify({ events: ids.size, bonds: 15, utterancesChecked: utterances, result: 'PASS' }));
