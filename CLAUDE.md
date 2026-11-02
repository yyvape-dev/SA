# SA（月夜の回廊・領地ゲーム）

- 返答はすべて日本語。
- 最初に読む：`claude/03_handoff_addendum.md`（新しい引き継ぎ）→ 必要なら `claude/03_concept_handoff.md`（コンセプトと 2026-10-31 10:30 までの引き継ぎ）。
- ストーリーの資料は GitHub が全て（2026-11-01 のユーザー決定。`claude/story_plan.md` と新しい引き継ぎを参照）。旧 `10_story_secret.md` の存在や非公開ルールを前提にしない。
- シナリオを執筆・改稿・レビューするときは、[ゲームシナリオ制作・改稿の教科書](claude/scenario_handbook/README.md)を読み、原則編・実践編・SAへの適用メモを参照する。教材例・改善案は未採用であり、確定設定と区別する。
- 作業を終えたら `claude/03_handoff_addendum.md` の先頭に追記して push（main へ直接）。
- 一騎打ちの確認は Skill `sa-duel-check`。アクション戦闘のエフェクトの確認は Skill `sa-battle-fx-check`。ラナのコマを足す・差し替えるときは Skill `sa-sprite-atlas`。
- 作業を報告するときは、必ず実機で試す URL をセットで送る（GitHub Pages：https://yyvape-dev.github.io/SA/ 。push 後に Pages の反映〈actions の pages build〉が success か確かめてから）。よく使う URL：アクション戦闘 `index.html?battle=1&waves=3&boss=1&al=mina`（`&px=0` で従来の描画）、仲間の連携をすぐ何度も試す `index.html?battle=1&waves=3&boss=1&cotest=1&al=ranka`（al＝ranka・lily・mina・garou・sera）、敵将を章の将軍に `&gen=g1〜g6`、一騎打ち `terrain/index.html?duel=1〜6`（5＝2人で挑む、6＝ラナとランカ）。
