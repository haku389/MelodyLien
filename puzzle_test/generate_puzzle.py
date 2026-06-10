#!/usr/bin/env python3
"""
MelodyLien パズル生成スクリプト
設計書 §14 に基づいて実装

使い方:
    python3 generate_puzzle.py [--owned 1,3,5,7,9]

引数:
    --owned   所持済みピースのID一覧（カンマ区切り）。省略時はランダム12枚。
    --input   入力サムネイル画像パス（デフォルト: input/thumbnail.jpg）
"""

import argparse
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

# ── 設定 ──────────────────────────────────────────────────────────────────

COLS          = 6
ROWS          = 4
PIECE_COUNT   = COLS * ROWS          # 24
PIECE_W       = 200                  # 1ピース幅  (1200 / 6)
PIECE_H       = 168                  # 1ピース高さ (672 / 4)
CANVAS_W      = PIECE_W * COLS       # 1200
CANVAS_H      = PIECE_H * ROWS       # 672

# 未所持ピースの色（濃い紫グレー）
LOCKED_COLORS = ["#2F2A45", "#3A3455", "#4B4568"]

# 境界ハイライト色（選択可能なピース）
HIGHLIGHT_COLOR = (143, 109, 244, 160)   # primary color + alpha

# ── ディレクトリ ─────────────────────────────────────────────────────────

BASE   = Path(__file__).parent
INPUT  = BASE / "input"
OUTPUT = BASE / "output"
DIR_LOCKED    = OUTPUT / "locked"
DIR_THUMBNAIL = OUTPUT / "thumbnail"
DIR_PREVIEW   = OUTPUT / "preview"

for d in [DIR_LOCKED, DIR_THUMBNAIL, DIR_PREVIEW]:
    d.mkdir(parents=True, exist_ok=True)

# ── ヘルパー ─────────────────────────────────────────────────────────────

def piece_id(row: int, col: int) -> int:
    """左上から右下に1始まりのID"""
    return row * COLS + col + 1

def piece_rect(row: int, col: int) -> tuple:
    """(left, top, right, bottom)"""
    left = col * PIECE_W
    top  = row * PIECE_H
    return (left, top, left + PIECE_W, top + PIECE_H)

def piece_filename(n: int) -> str:
    return f"piece_{n:02d}.png"

# ── マスク生成（角丸矩形 + 隣接境界に凹凸タブ） ─────────────────────────

TAB_RADIUS   = 18   # タブの半径
TAB_DEPTH    = 22   # タブの突出量
CORNER_R     = 0    # 外周の角丸（外周には付けない）
INNER_MARGIN = 0    # ピース間のギャップ（1pxはアプリ側で管理）

def make_piece_mask(row: int, col: int, size: tuple | None = None) -> Image.Image:
    """
    指定のピース位置に対応する RGBA マスク画像を生成する。
    外周はストレート、内側の境界にタブ（凸凹）をつける。
    隣接ピース同士で凸凹が噛み合う設計。
    """
    w = PIECE_W if size is None else size[0]
    h = PIECE_H if size is None else size[1]

    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)

    # ベース矩形（塗りつぶし）
    draw.rectangle([0, 0, w - 1, h - 1], fill=255)

    # --- タブの方向を決める ---
    # 上辺: 一番上の行は平坦、それ以外は上の行との境界
    # 下辺: 一番下の行は平坦、それ以外は下の行との境界
    # 左辺: 一番左は平坦、それ以外
    # 右辺: 一番右は平坦、それ以外

    # タブが「凸（+）」か「凹（-）」かを決める seed
    # 同じピースIDで常に同じ向きを返すよう固定パターンを使う
    def tab_direction(r, c, side):
        """(row, col, side) から凸 or 凹を決める"""
        seed = r * 100 + c * 10 + {"top": 1, "bottom": 2, "left": 3, "right": 4}[side]
        return 1 if (seed % 2 == 0) else -1  # 1=凸, -1=凹

    cx, cy = w // 2, h // 2   # ピース中心

    # 上辺タブ（rowが0以外）
    if row > 0:
        d = tab_direction(row - 1, col, "bottom")  # 上のピースの下辺と噛み合う
        _draw_tab(mask, draw, "top", cx, 0, TAB_RADIUS, TAB_DEPTH, d, w, h)

    # 下辺タブ（最終行以外）
    if row < ROWS - 1:
        d = tab_direction(row, col, "bottom")
        _draw_tab(mask, draw, "bottom", cx, h, TAB_RADIUS, TAB_DEPTH, d, w, h)

    # 左辺タブ（colが0以外）
    if col > 0:
        d = tab_direction(row, col - 1, "right")  # 左のピースの右辺と噛み合う
        _draw_tab(mask, draw, "left", 0, cy, TAB_RADIUS, TAB_DEPTH, d, w, h)

    # 右辺タブ（最終列以外）
    if col < COLS - 1:
        d = tab_direction(row, col, "right")
        _draw_tab(mask, draw, "right", w, cy, TAB_RADIUS, TAB_DEPTH, d, w, h)

    # 軽くぼかしてエッジを滑らかに
    mask = mask.filter(ImageFilter.SMOOTH)
    return mask

def _draw_tab(mask, draw, side, cx, cy, radius, depth, direction, w, h):
    """
    タブ（凸凹）を描く。
    direction: 1=凸（ピース外側に膨らむ）, -1=凹（ピース内側に食い込む）
    """
    r  = radius
    d  = depth * direction

    if side == "top":
        # 上辺: cy=0, cx=ピース水平中心
        bx, by = cx, 0
        if direction == 1:     # 上に飛び出す（マスクに追加）
            draw.ellipse([bx - r, by - d - r, bx + r, by - d + r], fill=255)
        else:                  # 上に食い込む（マスクから削除）
            draw.ellipse([bx - r, by - r, bx + r, by + r], fill=0)

    elif side == "bottom":
        bx, by = cx, h
        if direction == 1:
            draw.ellipse([bx - r, by + d - r, bx + r, by + d + r], fill=255)
        else:
            draw.ellipse([bx - r, by - r, bx + r, by + r], fill=0)

    elif side == "left":
        bx, by = 0, cy
        if direction == 1:
            draw.ellipse([bx - d - r, by - r, bx - d + r, by + r], fill=255)
        else:
            draw.ellipse([bx - r, by - r, bx + r, by + r], fill=0)

    elif side == "right":
        bx, by = w, cy
        if direction == 1:
            draw.ellipse([bx + d - r, by - r, bx + d + r, by + r], fill=255)
        else:
            draw.ellipse([bx - r, by - r, bx + r, by + r], fill=0)

# ── ロック（未所持）ピース生成 ─────────────────────────────────────────

def generate_locked_pieces():
    """黒い未所持ピース24枚を生成して output/locked/ に保存"""
    print("🔒 未所持ピース生成中...")
    colors = [int(c, 16) for c in [
        LOCKED_COLORS[0][1:3], LOCKED_COLORS[0][3:5], LOCKED_COLORS[0][5:7]
    ]]
    base_color = tuple(colors)  # (47, 42, 69)

    for row in range(ROWS):
        for col in range(COLS):
            n = piece_id(row, col)

            # ベース画像（グラデーション風）
            img = Image.new("RGBA", (PIECE_W, PIECE_H), (*base_color, 255))
            draw = ImageDraw.Draw(img)

            # 少し明るいハイライトを左上に
            for px in range(PIECE_W):
                for py in range(PIECE_H):
                    ratio = (px + py) / (PIECE_W + PIECE_H)
                    r = int(base_color[0] + (75 - base_color[0]) * (1 - ratio) * 0.4)
                    g = int(base_color[1] + (69 - base_color[1]) * (1 - ratio) * 0.4)
                    b = int(base_color[2] + (104 - base_color[2]) * (1 - ratio) * 0.4)
                    img.putpixel((px, py), (r, g, b, 255))

            # ピース番号を薄く表示（デバッグ用）
            draw.text((PIECE_W // 2 - 8, PIECE_H // 2 - 6), f"{n:02d}",
                      fill=(255, 255, 255, 60))

            # マスク適用
            mask = make_piece_mask(row, col)
            img.putalpha(mask)

            out_path = DIR_LOCKED / piece_filename(n)
            img.save(out_path, "PNG")

    print(f"  → {PIECE_COUNT}枚生成完了: {DIR_LOCKED}")

# ── サムネイルピース生成 ───────────────────────────────────────────────

def generate_thumbnail_pieces(image_path: Path):
    """サムネイルを24枚に切り出して output/thumbnail/ に保存"""
    print(f"🖼  サムネイルピース生成中: {image_path}")

    src = Image.open(image_path).convert("RGBA")
    # 1200×672 にリサイズ
    src = src.resize((CANVAS_W, CANVAS_H), Image.LANCZOS)

    for row in range(ROWS):
        for col in range(COLS):
            n    = piece_id(row, col)
            rect = piece_rect(row, col)

            # 該当エリアを切り出し
            piece_img = src.crop(rect)

            # マスク適用
            mask = make_piece_mask(row, col)
            piece_img.putalpha(mask)

            out_path = DIR_THUMBNAIL / piece_filename(n)
            piece_img.save(out_path, "PNG")

    print(f"  → {PIECE_COUNT}枚生成完了: {DIR_THUMBNAIL}")

# ── プレビュー画像生成 ─────────────────────────────────────────────────

def create_previews(owned_ids: set):
    """
    3種類のプレビュー画像を生成
    - puzzle_preview.png  : サムネイルピース全枚
    - locked_preview.png  : 未所持ピース全枚
    - mixed_preview.png   : owned_ids に応じて混在表示
    """
    print("🔍 プレビュー画像生成中...")

    # キャンバスサイズ（2px ギャップ）
    gap = 2
    canvas_w = CANVAS_W + gap * (COLS - 1)
    canvas_h = CANVAS_H + gap * (ROWS - 1)

    def make_canvas(title):
        bg = Image.new("RGBA", (canvas_w, canvas_h), (248, 241, 255, 255))
        return bg

    def place_piece(canvas, piece_img, row, col):
        x = col * (PIECE_W + gap)
        y = row * (PIECE_H + gap)
        canvas.paste(piece_img, (x, y), piece_img)

    # puzzle_preview（全サムネイルピース）
    cv_puzzle = make_canvas("puzzle")
    # locked_preview（全未所持ピース）
    cv_locked = make_canvas("locked")
    # mixed_preview（所持済みはサムネイル、未所持は黒）
    cv_mixed  = make_canvas("mixed")

    for row in range(ROWS):
        for col in range(COLS):
            n = piece_id(row, col)

            thumb_img  = Image.open(DIR_THUMBNAIL / piece_filename(n)).convert("RGBA")
            locked_img = Image.open(DIR_LOCKED    / piece_filename(n)).convert("RGBA")

            place_piece(cv_puzzle, thumb_img,  row, col)
            place_piece(cv_locked, locked_img, row, col)

            # mixed: 所持済みはサムネイル、それ以外は黒
            if n in owned_ids:
                place_piece(cv_mixed, thumb_img,  row, col)
            else:
                # 取得可能な未所持ピースにハイライトを重ねる
                highlight = locked_img.copy()
                overlay   = Image.new("RGBA", (PIECE_W, PIECE_H), HIGHLIGHT_COLOR)
                mask_img  = make_piece_mask(row, col)
                overlay.putalpha(mask_img)
                highlight = Image.alpha_composite(highlight, overlay)
                place_piece(cv_mixed, highlight, row, col)

    cv_puzzle.save(DIR_PREVIEW / "puzzle_preview.png")
    cv_locked.save(DIR_PREVIEW / "locked_preview.png")
    cv_mixed.save( DIR_PREVIEW / "mixed_preview.png")

    print(f"  → preview 3枚生成完了: {DIR_PREVIEW}")

# ── メイン ────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="MelodyLien パズル生成ツール")
    parser.add_argument("--owned",
                        help="所持済みピースIDのカンマ区切りリスト (例: 1,3,5,7)",
                        default=None)
    parser.add_argument("--input",
                        help="入力サムネイル画像パス",
                        default=str(INPUT / "thumbnail.jpg"))
    args = parser.parse_args()

    image_path = Path(args.input)

    # 所持ピースID
    if args.owned:
        owned_ids = {int(x) for x in args.owned.split(",") if x.strip()}
    else:
        # 省略時はランダムに12枚を所持済みとして扱う
        owned_ids = set(random.sample(range(1, PIECE_COUNT + 1), 12))
        print(f"🎲 ランダム所持ピース: {sorted(owned_ids)}")

    print(f"\n📐 キャンバス: {CANVAS_W}×{CANVAS_H}px  /  ピース: {PIECE_W}×{PIECE_H}px  /  {COLS}×{ROWS}={PIECE_COUNT}枚\n")

    # ① 未所持ピース生成（常時）
    generate_locked_pieces()

    # ② サムネイルピース生成（入力画像が必要）
    if not image_path.exists():
        print(f"\n⚠️  入力画像が見つかりません: {image_path}")
        print("   thumbnail.jpg を input/ フォルダに置いてから再実行してください。")
        print("   locked/ ピースのみ生成しました。")
    else:
        generate_thumbnail_pieces(image_path)
        # ③ プレビュー画像生成
        create_previews(owned_ids)

    print("\n✅ 完了")
    print(f"   output/locked/      — 未所持ピース {PIECE_COUNT}枚")
    if image_path.exists():
        print(f"   output/thumbnail/   — サムネイルピース {PIECE_COUNT}枚")
        print(f"   output/preview/     — プレビュー画像 3枚")
        print(f"\n   所持済み ({len(owned_ids)}枚): {sorted(owned_ids)}")

if __name__ == "__main__":
    main()
