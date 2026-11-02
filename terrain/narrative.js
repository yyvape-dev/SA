// シナリオの状態処理。表示・資源効果を持たず、旧セーブと選択の再開を扱う。
export const VERSION = 2;
export const readLines = (value, state) => typeof value === 'function' ? value(state) : value || [];
export const choiceOf = (state, id) => state.storyChoices?.[id];
// 既存の会話窓は18字×2行。台本の明示改行を尊重し、長い行だけ折り返す。
export function pages(lines) {
  const result = [], closing = '、。，．？！：；）」』】〉》…ー';
  for (const [speaker, text] of lines) {
    const rows = [];
    for (const line of text.split('\n')) {
      const chars = [...line];
      while (chars.length > 18) {
        let n = 18;
        while (n > 1 && (closing.includes(chars[n]) || '（「『【〈《'.includes(chars[n - 1]))) n--;
        rows.push(chars.splice(0, n).join(''));
      }
      rows.push(chars.join(''));
    }
    for (let i = 0; i < rows.length; i += 2) result.push([speaker, rows.slice(i, i + 2).join('\n')]);
  }
  return result;
}
export function prepareNarrative(state) {
  state.storyChoices ||= {};
  state.skirmResults ||= {};
  state.evSeen ||= {};
  state.bondSeen ||= {};
  if (state.storyVersion !== VERSION) {
    // 旧版の既読は維持。新しい週イベントを過去に遡って流さない。
    state.storyVersion = VERSION;
    state.storyLegacy = state.week > 1;
  }
  return state;
}
export function materialize(event, state) {
  const chosen = choiceOf(state, event.id);
  const choices = (event.choices || []).map(c => ({ ...c, reply: [...readLines(c.reply, state)] }));
  const lines = [...readLines(event.lines, state)];
  if (Number.isInteger(chosen) && choices[chosen]) {
    lines.push(...choices[chosen].reply);
    return { ...event, lines, choices: undefined };
  }
  return { ...event, lines, choices: choices.length ? choices : undefined };
}
// 資源・徳の加算前に呼ぶ。リロードして同じ選択を再生しても二重に加算しない。
export function recordChoice(state, id, index, choices) {
  prepareNarrative(state);
  if (!Number.isInteger(index) || !choices[index] || Number.isInteger(state.storyChoices[id])) return false;
  state.storyChoices[id] = index;
  return true;
}
export function skirmishLines(event, won, state) {
  return readLines(won ? event.after : event.afterLose, state);
}
export function endingTone(state) {
  const v = state.virtue || {};
  const d = (v.mercy || 0) - (v.rigor || 0);
  return d >= 2 ? 'mercy' : d <= -2 ? 'rigor' : 'both';
}
