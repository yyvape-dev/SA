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

## 2026-11-12 追加組込み
- dash: DJT4NN3R, https://freesound.org/people/DJT4NN3R/sounds/449993/ (CC0)。公開試聴MP3 https://cdn.freesound.org/previews/449/449993_3217484-lq.mp3 を使用。原本WAVではない。最大エネルギー近傍0.28秒を切出し、40ms/18%・80ms/7%の短いエコーを追加。最終0.36秒。
- skill: qubodup, https://freesound.org/people/qubodup/sounds/442774/ (CC0)。max92105/jrpg の content/audio/effects/PlaceholderSkillMend.wav（同作品で短縮・モノラル変換された版）を取得。スキルが実際に開始したときだけ一度再生。
- town: Hot Swing / Kevin MacLeod (incompetech.com), ISRC USUAN1100202。配布元から取得。CC BY 4.0 https://creativecommons.org/licenses/by/4.0/ 。OGGへ形式変換。著作者表示を配信ページにも掲載。
- dungeon: Slick Street Swing / MFP【Marron Fields Production】、Track1、https://opentracks.com/en/bgm/detail/23316 。配布元より取得。利用条件 https://opentracks.com/en/help/articles/license/ と制作者条件に従いゲームBGMとして使用。形式変換した音源はmusic.pck内に格納し、音源単体配布は行わない。AI学習に使わない。
- BGMは同じエリアでは再開しない。裏町・ダンジョンで切替、全曲をリピート。シームレスな継ぎ目の聴覚確認は未実施。会話中-28dB、通常-20dB。
- ダッシュとスキル音は原本と同一品質ではなく上記取得版。主観的な音色・エコー・音量の適合は実機試聴待ち。ダンジョン曲は暫定採用、ビバップ感不足は既知。
