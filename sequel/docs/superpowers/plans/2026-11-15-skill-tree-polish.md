# SA2 skill tree clarity Implementation Plan

> For agentic workers: use superpowers:executing-plans. User asked for continuous execution in this session.

**Goal:** 既存ツリーの技・派生・強化結果・操作理由を読んで判断できるようにする。
**Architecture:** progress/skill_tree は変更せず、表示モデルと描画を分離。dungeon_hud のツリー部分だけ委譲する。
**Tech Stack:** Godot 4.7.2 / GDScript / 既存Noto日本語サブセット。
**Spec:** DESIGN.md、既存 sequel/specs/skill_tree.md。

## Global Constraints
- ソース基点46d2741。mainへ本編をマージしない。
- 採用済み画像を再利用し、戦闘・成長・セーブ・パーティのルールを維持。
- 必殺派生・新しい技・長押し・フリック・4枠目は追加しない。

## Review Focus
- 選択だけでSPを消費しない。
- Lv2→3で派生解放、Lv5/SP0で押せない理由が出る。
- 派生の説明と待ち時間が実テーブルに一致する。
- 振り直しは選択キャラのみ、確認2回、返却数の一致。
- 844×390で説明と操作が重ならず、日本語欠字がない。

## Task 1: 説明モデルと選択操作
- [x] 既存の実装に対し、行のタッチでSPを消費しないことをテストして失敗を確認。
- [x] skill_tree_presenter.gd に詳細、実テーブルの現在/次レベルCD・消費、返却SPを実装。
- [x] dungeon_hud.gd に選択状態と独立した強化/派生適用操作を追加。
- [x] モデルと操作テストを通す。旧セーブ移行/保存復元は既存progressを直接確認。

## Task 2: ツリー描画と日本語
- [x] skill_tree_art.gd に共通矩形、四行ツリー、説明、状態別アクションを実装。
- [x] 戦闘用の採用済みアイコンと顔を再利用。フォント不足字を既存ツールで追加。
- [x] 844×390/1280×720、3人、SP0/Lv3/最大/未実装必殺/振り直しを撮影。
- [x] 既存HUD/遠征盤テストを回帰確認。検証結果・未確認を仕様/HANDOFFへ記録しソースpush。
