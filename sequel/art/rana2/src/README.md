# 新ラナ 素材（2026-11-06 チャットで判定済み）
置き場所：sequel/art/rana2/src/ にこのまま置く。手順はプロジェクトの claude/chat_handoff.md「ラナの差し替え」。
全動画 1104×832・24fps・3秒（atkHold_spin のみ5秒）。マゼンタ背景、右向き。
- stance_battle / stance_normal：戦闘立ち絵・通常立ち絵（941×1672）
- walk / run_dodge：歩き・走り（回避は走りを流用、残像はコード）
- atkA_thrust（小）/ atkB_downslash（中）/ atkC_flurry（大、髪が緑に色ずれ→色相補正、金の軌跡）/ atkHold_spin（長押し、金の輪）
- spare_spinkick / spare_combo：予備。スキル用の在庫として同じく連番化する（spinkick の赤い輪は敵色）
- hit：被弾（途中で左向きに振り返る→要判定）/ down：倒れて起き上がる（土煙あり、起き上がりの途中にコマ飛び）
全部を video-to-sprite-pipeline で連番化し、元絵と同じ大きさで並べた比較画像を出す。焼き込みの光は、まず抜いて試し、汚ければコードで描き直す。
