# プロローグ受領原画（2026-11-14）

ユーザー提供の8枚を無加工・元寸法のJPEGで保存。実装はCodex側の次工程。
人物・机・照明器の白背景は不透明（アルファなし）。透過済みとは扱わない。
.gdignore は原画の自動インポート・既存Web書き出しへの混入を防ぐためのもの。
ゲーム用素材は別の配置先へ加工・保存し、この原画を保持する。

| ファイル | 用途 | 受領ファイル |
|---|---|---|
| sera_book.jpeg | セラ・帳簿 | EE0C6C59-34F3-4068-B690-732C943A6518.jpeg |
| imperial_envoy.jpeg | 帝国使節 | AF3AB6B2-E6F9-4626-8A05-26934961676D.jpeg |
| desk.jpeg | 机・書類 | 82839C59-975B-4D99-8733-961428C7E089.jpeg |
| audience_room.jpeg | 謁見室 | B82450F5-9F4A-4717-8098-742DE319EEEA.jpeg |
| portable_lamp.jpeg | 携帯照明器 | 229AFC5D-76D7-4DB2-B1F3-76AC97E2EB49.jpeg |
| office.jpeg | 執務室 | 31D17313-B3A8-401E-91B3-3AFBF50231F2.jpeg |
| mina_bread.jpeg | ミナ・パン | 03CF744C-CDBB-4510-9334-EEFA37E10BC9.jpeg |
| guest_room.jpeg | 客室 | D0C23001-9D6B-49E9-8794-969AB05DB939.jpeg |

## Codexでの組み込み
- 作業ブランチ feat/sa2-prologue-20261114、対象 sequel/。main・公開中の本編は変更しない。
- CLAUDE.md、sequel/HANDOFF.md、sequel/docs/sa2_prologue_progress_20261114.md、docs/superpowers/specs/2026-11-14-sa2-prologue-design.md を読む。
- 利用可能なツール・関連スキルを確認し、本文と必要参照を実読する。tool-routing・quality-gate、切り抜き/透過検証時はasset-qa、Godot検証時はsa2-godot-check等の該当手順を探す。必要な手順や実行環境が利用できなければ、不足と未検証範囲を報告し、推測で代替しない。
- 原画を再生成せず、既存の仮背景・ミナ・セラ・使節・机・照明器と差し替える。人物の白い衣装を消さないよう、白背景の切り抜きは外周連結領域と輪郭を確認する。
- 背景3枚は1536×864、机1536×1024、照明器1254×1254、ミナ672×1536、セラ702×1536、使節1024×1536。寸法不足を拡大生成済みと表現しない。
- 既存ラナ・リリィ、台本、進行と保存を維持。足元と縮尺、机との前後関係、会話窓、照明器への寄りを実画面で確認する。
- 加工画像の寸法・アルファと既存テストを確認し、Godot実描画1280×720/1560×720を確認。指定4.7.2・Web・iPhoneの実施可否は個別に報告する。
