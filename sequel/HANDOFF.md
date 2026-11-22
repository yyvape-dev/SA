# SA2（続編・融合都市、Godot 4.7.2）引き継ぎ

> **便ごとの記録は [docs/handoff_log.md](docs/handoff_log.md) に書く。HANDOFF.md には2行の要約とリンクだけ。**（Codex・GPT・Claude 共通。batch ごとの詳細もログへ）
> この文書は80行以内。中身は「現在地／正本の場所／次／未決／決まり」だけ。

## 現在地（2026-11-22）
- **ブランチを main に1本化した**（2026-11-22 ユーザー決定）。main に、ランカ（feat/sa2-ranka-20261112）、スキルツリー・ダンジョン16・敵の行動（idle/rush/shot/charge）・お金と回復・装備・クリア後の商人（claude/skill-tree-implementation-fsvlcl）、Codex の育成UI・戦闘HUD・選択画面（codex/* 3本、上のブランチ経由）、プロローグの試し場面と原画8枚（feat/sa2-prologue-20261114、`sa2_prologue_preview.tscn`）が入った。取り込み前の main はブランチ `backup/main-20261122`（手元にはタグも）。ブランチは消していない。
- 敵は全部 1つの `battle.gd`・`enemy.gd` で動く（第1弾9体の数値も `foe_stats.gd` に統合）。第1弾9体の絵も半分の解像度に（2026-11-22 ユーザー決定。`tools/halve_foes.py`）。
- 本編の Web 版：https://yyvape-dev.github.io/SA/sequel/web/ （統合後の main を書き出し）。テスト部屋：https://yyvape-dev.github.io/SA/previews/sa2-rooms/?mode=foes （`?mode=ranka`・`rana`・`lily`）。
- 直近の便（2行要約）：
  - 2026-11-22 統合：ブランチの表・衝突の扱い・テスト結果・pck の比較 → [handoff_log.md](docs/handoff_log.md) の先頭。
  - 2026-11-22 統合の続き：9体を半分・プロローグ取り込み・ブランチの決まりを採用 → [handoff_log.md](docs/handoff_log.md) の先頭。
  - 2026-11-20 敵 第1弾9体 → [docs/sa2_foes_handoff_20261120.md](docs/sa2_foes_handoff_20261120.md)。

## 正本の場所
- 仕様：`specs/`（ダンジョン `dungeon_themes.md`、戦闘の打ち手 `combat_tactics.md`、お金と回復 `money_recovery.md`、装備 `gear.md`、スキルツリー `skill_tree.md`）。
- 敵：数値 `scripts/foe_stats.gd`、背 `enemy.gd` の `HEIGHT`、絵の作り方と各ツールの役目 [docs/sa2_foes_handoff_20261120.md](docs/sa2_foes_handoff_20261120.md) の「敵の仕組みの統合と正本」。
- 仲間：ランカ [docs/sa2_ranka_handoff_20261112.md](docs/sa2_ranka_handoff_20261112.md)、T6・T7 [docs/sa2_t6_handoff_20261110.md](docs/sa2_t6_handoff_20261110.md)・[docs/sa2_t7_handoff_20261111.md](docs/sa2_t7_handoff_20261111.md)。
- プロローグ：[docs/sa2_prologue_work_discussion_handoff_20261114.md](docs/sa2_prologue_work_discussion_handoff_20261114.md)（台本・確定事項）、[docs/sa2_prologue_art_integration_20261114.md](docs/sa2_prologue_art_integration_20261114.md)（原画）。
- 背景素材（GPT 制作の便）：[docs/sa2_dungeon_art_handoff_20261114.md](docs/sa2_dungeon_art_handoff_20261114.md)、保存先 `art/incoming/dungeon_20261114/`。
- 書き出し：`tools/export_web.py`（本体＋地区 pck）。手順は Skill `sa2-godot-check`。敵の追加は Skill `sa2-enemy-add`。
- 過去の経緯・数値・はまりどころ：[docs/handoff_log.md](docs/handoff_log.md)（2026-11-22 までの HANDOFF の全文を文字を変えずに移した）。

## 次（候補）
1. 実機（iPhone）で統合版を触る：ダンジョン・装備・商人・ランカ同行で、熱・メモリ・落ちないか。
2. 敵 第1弾9体をダンジョンの出現に入れる（テーマの割り当て・ボス。雑魚2＋ボス1）。
3. 戦闘バランス：T4 の難しさ、1周の時間、ボスのブレイク（BREAK_K は Claude の仮）。
4. 回り込みのボタンの絵、装備と素材のアイコンの絵の発注。
5. ダンジョンの名前（札は番号 1-1〜4-4 だけ）。
6. プロローグの中身の議論（Work）→ 合意した変更の実装。Web の試し版を置くなら `previews/sa2-prologue/`（絵は地区 pck `pr1`）。

## 未決（ユーザー判定待ち）
- 第1弾9体：焼き込みの軌跡（ランサー攻撃2 以外）、テーマの割り当て・ボス、背の高さ。
- 必殺派生の中身、つなぎの猶予・背中の秒数・浮きの強さ・ランクの点。
- 古いブランチ（11-04〜11-14 の試作）を残すか片付けるか（今は触らない）。

## 決まり
- push は main へ直接。報告には実機の URL を添える。Pages の pages build が success か確かめてから。
- 絵は縮めない・崩さない（処理した絵は元絵と同じ大きさで並べて比べてから入れる）。色：青＝味方、赤＝敵、金＝物資・決着。技名・体数の文字は出さない（数字は出す）。
- 素材・敵・キャラを足す前に、上限（iPhone の熱・メモリ、絵の解像度と枚数、1画面の敵の数）を数字で確かめる。敵の絵は地区 pck に分け、本体を太らせない。
- 画面の文字の大きさを毎フレーム変えない（拡大で出す。2026-11-16 iPhone で落ちた件）。
- 書き出しの前に、同じ書き出し先へ他のエージェントが push していないか確かめる（`git log origin/main -5 -- <パス>`）。上書きしない。pck の大きさを前回と比べて報告する。
- 撮影・自動の確認は `--fixed-fps 60`、乱数の種を固定、セーブをまっさらに。
- 古いセーブの SP：D1〜D3 もクリア済みにした分の初回クリア +2×6 を渡す（7→19）。今の動きのまま（2026-11-22 ユーザー決定）。
- **ブランチの使い方（2026-11-22 ユーザー採用）**：
  - 作業ブランチは `<種類>/<内容>-<日付>`（例 `feat/sa2-xxx-20261123`）。main から切る。
  - main に入れる時期：作業の区切り（テスト全部 PASS＋撮影＋ユーザーの判定）ごとに、遅くとも3日以内。ブランチの上にブランチを重ねない（今回の割れの原因）。
  - 長くかかる作業は、毎日 main を取り込む（`git merge origin/main`）。衝突はその日のうちに直す。
  - プレビューの置き場所：`previews/<名前>/`（名前＝作業ブランチの内容の部分）。`sequel/web/` は main の本編だけ。他人の `previews/<名前>/` には書かない。
  - main に入れたら、そのブランチのプレビューは消すか「済」と HANDOFF の便の記録に書く。
