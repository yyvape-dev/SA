# 採用音の追加組込み
対象: test/sa2-t6-lily-touch-controls-20261111、Godot 4.7.2。mainは変更しない。
ダッシュ（高音風切り+短いエコー）、スキル発動音、裏町Hot Swing、ダンジョンSlick Street Swing Track1を追加。
出典・取得版・利用条件は assets/audio/SOURCES.md。
通常ゲームmain.gdからBGMのエリア切替を行う。街の同一フロア移動では曲を再開しない。
ラナはスキル開始時と回避開始時、手動リリィはforce_skillとdodge開始時に発音。ジャストガードが成立した場合はダッシュ音を鳴らさない。
会話パネルの開閉でBGMを減音/復帰。配信ページの段階起動は維持。
音楽リピートは有効。継ぎ目、音色、音量の主観判断とiPhone実機結果は未検証。
