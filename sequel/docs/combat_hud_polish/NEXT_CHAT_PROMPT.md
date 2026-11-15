GitHub yyvape-dev/SA の sequel/（SA2、Godot 4.7.2・Web）の作業を引き継いでください。次の依頼内容はこのプロンプトの末尾に追記します。まず現状を確認し、完了済み部分を作り直さず進めてください。

■ 土台
- ソースのブランチ: codex/combat-hud-polish-20261115。実装2f1feb4、公開確認を含む引き継ぎ857dd27。その後のドキュメント更新も含め、このブランチの最新を取得する。
- mainには本編のソースは未マージ。mainからソース作業を始めない。このソースブランチから新しい作業ブランチを切る。
- 最初の土台claude/skill-tree-implementation-fsvlcl以降、ダンジョン選択UIと戦闘HUDの変更を積み重ねてある。

■ 最初に読む
1. sequel/HANDOFF.md の先頭2節（戦闘HUD・魔導式遠征盤）
2. sequel/docs/combat_hud_polish/README.md と comparison.png、evidence/web_skill_cd.png
3. sequel/specs/skill_ui.md と sequel/specs/dungeon_select_ui.md
4. sequel/docs/expedition_apparatus_result.md
5. 対象コード: sequel/scripts/combat_hud_art.gd、combat_hud_model.gd、combat_hud_materials.gd、touch_ui.gd、dungeon_hud.gd
絵の変更時はworld_concept.md・dungeon_themes.mdと採用済み本番素材を実際に見る。

■ 現在できていること
- 門→地図→難易度→仲間→読み込みの選択UIを、採用済みの真鍮・革・暗いガラスの魔導式遠征盤として実装済み。
- 戦闘中の体力・必殺・仲間・ボスのゲージ、ラナ/リリィ/ランカ各3技＋必殺、通常攻撃・回避のアイコンを同じ世界観で実装済み。
- 青HP、紫の必殺蓄積、実際の消費量に応じた区切りと金の使用可能回数、赤ボス。手動操作キャラの実体力/育成後の消費量を表示。
- 素材24WebP・約2.95MiB。原画・同寸比較・切り出し記録はsequel/art/ui_source/combat_hud/。原画は.gdignoreでpck除外。再検査: sequel/で python3 tools/package_combat_ui.py --check --compare。
- 通常スキルの明るさは操作状態とCDを表す。対象・距離の最終判定は既存のuse_skill/use_ultに委ねる。

■ 守ること
- 新しい絵は採用済み本番素材を参照する。人物の顔は既存素材を使い、勝手に描き替えない。
- 画面の文字は数字だけ。青＝味方、赤＝敵、金＝決定/使用可能。戦闘の必殺蓄積は紫。
- 絵の比率を崩さない。加工物は元と同じ大きさで並べて確認する。不要な画像生成をしない。
- 既存タッチ位置/判定、戦闘・成長・パーティのルールを外見変更のついでに変えない。
- open_menu／choose_theme(i)->bool／choose(i)->bool／toggle_ally／go／menu_back／party_cap、menu_stage名、main.gdのset_party・bench・party_flowを維持。絵の位置を変えたらmenu_rects()も一致させる。
- 長押し・フリック・4枠目・新しい技は未実装で、追加依頼はまだない。

■ 検証済みと未確認を分ける
- モデル/手動キャラ結合/配置、既存の選択画面テストはPASS。
- ネイティブ実戦でスキル/CD開始/必殺の実消費、3人の描画を確認。
- DUNGEON_TEST=1: 鍵3つが正しく6run完走。終了時ObjectDB2件の解放警告が残る（原因未特定）。
- 同一ビルドのローカルChromium844×390で地図→入場→戦闘→スキルタッチ/CD表示、pageerror/ScriptErrorなし。
- 公開URLは今回のpck取得・地図/T2難易度・pageerror0まで確認。公開環境での戦闘再撮影は未実施。
- iPhone実機の表示・入力遅延・速度は未確認。ソフトウェアChromiumの結果を実機性能と扱わない。
- 地図の推奨レベルは「入場制限なし」とユーザー決定済み。ただし実数値は未決。4/10/18/26はモック用の仮値で、本番RECOMMENDEDは0＝非表示。勝手に確定しない。
- 地図は門＋T1〜T4のみ、将来の仲間枠2つはユーザー了承済み。

■ 書き出し・保存
- 公式Godot 4.7.2を使う。export_web.pyのWEB_OUT=../previews/sa2-dungeon。
- 最新mainを確認し、mainへはpreviews/sa2-dungeon/だけをpush。本編sequel/web/やソースをmainへマージしない。既に公開されている追加地区パックを消さない。force pushしない。
- 現公開main d4e78be、Web版20261115130227-2f1feb4-g4.7.2。後続更新がある可能性があるので最新を確認する。
- URL: https://yyvape-dev.github.io/SA/previews/sa2-dungeon/?town=back&at=gate&unlock=1
- 完了時はHANDOFFと対象仕様に結果・証拠・未確認を追記し、ソースもpushする。実際に行っていない検証を完了扱いしない。

■ 今回の追加依頼
（ここに、次に直したいこと・追加したいことを記入）
