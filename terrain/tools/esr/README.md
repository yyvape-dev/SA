# 絵の拡大（AI、PyTorch なし）
- `esr_np.py`：Real-ESRGAN の animevideov3（x4、BSD-3-Clause）を numpy だけで動かす。透過PNGに対応（RGB とアルファを別々に拡大）。CPU 2コアで 1枚 約2秒（人物 250px 程度）。
- 重み（2.4MB）は毎回取る：`curl -sSL -o terrain/tools/esr/realesr-animevideov3.pth https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesr-animevideov3.pth`
- 使い方：`python3 terrain/tools/esr/esr_np.py <入力フォルダ> <出力フォルダ> [倍率]`（4倍で拡大してから、指定の倍率へ縮める）。
- 一騎打ちの連番に入れるのは `terrain/tools/pack_upscaled_duel.py`。
