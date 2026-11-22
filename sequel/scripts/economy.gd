extends RefCounted
## お金と回復（2026-11-16 ②、specs/money_recovery.md）。検討表「お金と回復」「ドロップ」の案と、ユーザーの決定。
## 「仮」と書いたものは Claude が決めた数値。

const POT_S_HEAL := 0.30      # 回復薬（小）：体力の 30%
const POT_L_HEAL := 0.70      # 回復薬（大）：70%
const POT_S_PRICE := 40
const POT_L_PRICE := 120
const POT_S_MAX := 5
const POT_L_MAX := 2
const POT_CD := 3.0           # 使った後、使えない秒数
const POT_DROP := 0.03        # 雑魚が回復薬（小）を落とす割合（拾うのはおまけ）
const ROOM_HEAL := 0.10       # 部屋を片付けた時に戻る体力
const REVIVE_BASE := 100      # その場で立ち直る：100G×テーマの倍率、1 周で 1 回
const REVIVE_INV := 2.0       # 立ち直った後の当たらない秒数（仮）
const COIN_MAGNET := 1.4      # 硬貨がラナへ寄ってくる距離（m、仮）
const COIN_BOSS_N := 6        # ボスの硬貨の数（額を分ける、仮）

## 立ち直りの値段：100G×テーマの倍率。cfg＝Themes.cfg() の結果（theme_mul＝テーマの xp：1/1.5/2.2/3）
static func revive_cost(cfg: Dictionary) -> int:
	return int(round(REVIVE_BASE * float(cfg.get("theme_mul", 1.0))))
