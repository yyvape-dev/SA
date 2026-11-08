# SA2 T1.5 — JSON会話データ／Control UI 実装・運用仕様

対象：Godot 4.4.1、`godot-viewport-test/`。2026-11-08。
正本実装ブランチ：`feat/sa2-t1-5-dialogue-data-20261108`。T1 の完了済みブランチを起点に派生。**main/SA1には未統合**。

## 過去の問題と解決

旧 `scripts/sa2_dialogue_playable.gd` は台詞 `LINES` 3行をGDScript内に直接保持し、文章変更にコード改変を要した。T1.5では会話内容を `dialogues/ja/<event_id>.json` に移し、GDScriptはイベント選択・JSON検証・会話UI制御のみ行う。

長文の創作AIによる幻覚そのものをコードで防止することはできないが、**会話原稿とプログラムを別ファイル／別責務に分け、検証失敗時に表示・実装を止める**ことで改変事故の範囲を小さくする。

## Godotノード構成

```
sa2_dialogue_playable.tscn (Node3D)
├── greybox_city.tscn（既存・変更なし）
├── Conversation NPC（T1仮3D）
└── CanvasLayer
    ├── 探索の操作説明（仮Label）
    └── ui/sa2_dialogue_panel.tscn（Control／再利用可能）
        └── Panel (PanelContainer)
            └── Padding (MarginContainer)
                └── Layout (VBoxContainer)
                    ├── Speaker (Label)
                    ├── Content (HBoxContainer)
                    │   ├── Portrait (TextureRect・通常は非表示)
                    │   └── Body (RichTextLabel)
                    └── Advance (Button)
```

- `scripts/sa2_dialogue_database.gd`：JSON読み込みと検証。パス文字列／schema_version／event ID／linesの構造／空台詞／一行上限600文字／重複line_id／portrait_idを検証し、無効データは空Dictionaryとして返す。IDにスラッシュ・ドット等を許さず、イベント名を使ったパストラバーサルを防ぐ。未存在ファイルも会話を開始しない。
- `scripts/sa2_dialogue_panel.gd`：独立した `Control`。文字送りは `RichTextLabel.visible_characters` （28 Unicode codepoint/秒）。表示途中の最初の入力は全文表示、完成後の次の入力で次行、最終行の次で閉じる。ボタン／Space・Enter／画面タップ（マウス・タッチ）対応。 `dialogue_closed` と `line_changed` シグナルで外部シーンと疎結合。
- `scripts/sa2_dialogue_playable.gd`：NPC接近判定、イベントID指定、移動ロック、進行状態・再開・撮影専用操作のみ。**物語上の会話文を記述しない**。
- `scripts/sa2_flow_state.gd`：T1状態管理を保持し、`dialogue_line_index` を追加。セーブ時に保存し、旧version 1のセーブ（同フィールド欠落）はindex=0として読み戻す。行ごとの進捗を保存。現在のFlowStateは代表2景 `C1-06`／`C2-09` 用の戦闘アダプタ契約であり、全章のイベントエンジンではない。

## JSON形式（制作・翻訳担当が編集する唯一の本文）

`godot-viewport-test/dialogues/ja/C1-06.json` はT1検証用の台詞。制作者専用本番台本ではない。

```json
{
  "schema_version": 1,
  "id": "C1-06",
  "lines": [
    {
      "line_id": "c1-06-001",
      "speaker_id": "guide",
      "speaker": "案内係",
      "text": "こちらは演習区画です。\n準備ができたら、先へ進んでください。",
      "portrait_id": ""
    }
  ]
}
```

**新しい台詞を追加／修正する時はJSONだけを編集し、UIやGDScriptは書き換えない。** 章やイベントごとにJSONファイルを分ける。各行の`line_id`は、既存セーブと将来の台本差分を追うため原則変更しない。台詞が長ければ1行の`text`に詰め込まず複数のlinesへ分割。新規イベントJSONは安全な英数字・ハイフン・アンダースコアのIDで作ればローダー変更不要。ただし新しいNPC・シナリオ発火条件と戦闘種別の設定は別途イベント制御が必要で、現在のT1 FlowStateが自動対応するわけではない。

`portrait_id`はオプション。空なら顔画像は表示しない。設定時は`res://assets/dialogue/<portrait_id>.png`を参照し、存在する画像だけ表示する。**本番会話の立ち絵制作は必須ではない**。原則は3D背景中の2D人物を映しつつ字幕を出す。将来の顔アップはT5演出レビューで必要性を判断する。

## 編集・動作検証

1. JSONを編集し、文字コードはUTF-8。GDScriptの`LINES`等に文章を複製しない。
2. Godotで開くシーン：`res://sa2_dialogue_playable.tscn`。
3. 基盤テスト：`godot --headless --path godot-viewport-test --script res://tests/sa2_t1_flow_test.gd`。
4. T1.5テスト：`godot --headless --path godot-viewport-test --script res://tests/sa2_t1_5_dialogue_test.gd`。
5. 実画面／動画：GitHub Actions `.github/workflows/sa2-t1-flow-tests.yml` のGodot Movie Maker撮影。自動移動・会話開始・文字送り・セーブ・会話終了・移動再開を記録する。単なるPNGスライドショーは実操作動画ではない。
6. **受入条件**：JSON以外に台詞がない、JSON誤記時に会話開始しない、構文／状態／連続操作テスト通過、動画目視で文字化け・重なりなし、既存T1の37チェックがPASS、GitHub保存後の再取得が一致。

### 運用上の注意・未検証

- Android/iOS/Windows等への**エクスポート版は未検証**。公式Godot 4.4ドキュメントは、`FileAccess`で読むJSON等の非リソースをパッケージへ含めるにはエクスポート設定の *non-resource export filter*（例 `*.json`）または個別ファイルの「Keep File」が必要と説明する。エクスポートプリセット作成時に必ず設定し、端末でロードを再試験する。
- 日本語フォントは試験CIにNoto CJKをインストールして `SystemFont` 参照。配布ビルドで同じフォントが存在する保証はない。製品フォントの同梱・ライセンス・各端末での描画はT5/T7で検証。フォントを勝手にGitHubにコミットしない。
- `RichTextLabel.visible_characters` はUnicodeコードポイント単位。複合絵文字の見た目上の1文字は必ずしも1カウントではない。
- 本実装はテキストの構造分離と基本表示。台本のシーン分岐、選択肢、全章横断の人物／翻訳データ、音声同期、縦画面対応は設計・実装済みと扱わない。

## 変更安全ルール（GPT／Codex／別担当AI向け）

- 最初にこの文書と `claude/sa2_vertical_slice_implementation_plan_20261108.md`（storyブランチ）・対象コードを実際に読み、利用可能スキル本文を参照。
- 会話の追加依頼だけなら `dialogues/ja/*.json` のみを編集。JSONの ID、line_id、話者、セリフ、任意顔画像IDをスキーマ検証。台本・正史と混同しない。
- T1.5ソースへ機能追加する際は既存T1の37項目とT1.5テスト、実画面・連続動画を再実行。失敗時はPASS報告禁止。
- `main`、SA1、既存検証ブランチ、承認済み台本は触らない。T1.5専用ブランチだけ変更し、差分・コミット・再取得を記録。
- 制作者専用・ネタバレ台本の本文をユーザー向け応答に表示しない。
