# SA（月夜の回廊・領地ゲーム）

- 返答はすべて日本語。
- 最初に読む：`claude/03_handoff_addendum.md`（新しい引き継ぎ）→ 必要なら `claude/03_concept_handoff.md`（コンセプトと 2026-10-31 10:30 までの引き継ぎ）。
- 筋の資料 `10_story_secret.md` は claude.ai のプロジェクト側にだけある。公開リポジトリなので置かない。ストーリーの中身はユーザーに明かさない。
- 作業を終えたら `claude/03_handoff_addendum.md` の先頭に追記して push（main へ直接）。
- 一騎打ちの確認は Skill `sa-duel-check`。アクション戦闘のエフェクトの確認は Skill `sa-battle-fx-check`。ラナのコマを足す・差し替えるときは Skill `sa-sprite-atlas`。
- 作業を報告するときは、必ず実機で試す URL をセットで送る（GitHub Pages：https://yyvape-dev.github.io/SA/ 。push 後に Pages の反映〈actions の pages build〉が success か確かめてから）。よく使う URL：アクション戦闘 `index.html?battle=1&waves=3&boss=1&al=mina`（`&px=0` で従来の描画）、一騎打ち `terrain/index.html?duel=1〜6`（5＝2人で挑む、6＝ラナとランカ）。
