# 採用SE / 2026-11-12
CC0。音色の採否はユーザー確認済み。実装側で音質を聴覚評価したとの主張はしない。

| 用途 | 原作者 / 採用元 | 取得先 |
|---|---|---|
| 通常命中 | CogFireStudios / https://freesound.org/people/CogFireStudios/sounds/547041/ | 0xMartin/Duke-s-Gambit: duke-s-gambit/assets/sounds/hit.mp3（同ゲームで変換・短縮された版、0.575秒） |
| 強打・リリィの打撃 | CogFireStudios / https://freesound.org/people/CogFireStudios/sounds/547042/ | cinegemadar/testris: assets/audio/547042__cogfirestudios__hit-impact-sword-3.wav |
| ガード | loudernoises / https://freesound.org/people/loudernoises/sounds/334169/ | tagniam/Turn: sounds/attack2.wav |
| 剣振り | qubodup / https://freesound.org/people/qubodup/sounds/59992/ | ShaleGame/ShaleGame: Assets/Sounds/59992__qubodup__swosh-sword-swing.ogg |

全て48kHz/モノラル/16bit PCMに変換。音程・速度は変更しない。
.wav.datはWAVバイトをそのまま保持し、Godotでload_from_buffer。export_presetsのinclude_filterで配信に含める。
ガード原音guard_dryは保存。guardは40ms/80ms/130ms、音量24%/12%/6%のディレイを加え、ピークを抑制。原音0.517秒→0.667秒。
発音は攻撃の実判定時。ラナ斬撃は命中に関わらずswing、命中があった場合だけhit/heavyを一度。複数敵同時命中で重ねない。リリィは剣振り音を使わず打撃音。ジャストガード成功時のみguard。
8ボイスの固定プール、音声はヒットストップ中も継続。開始ページの順次起動は変更しない。
