# StreetMelody パズル生成ツール

設計書 `StreetMelody_パズル生成仕組み設計書.md` §14 に基づいたローカル検証ツール。

## 必要なもの

```sh
pip3 install Pillow
```

## 使い方

### 1. サムネイル画像を配置

```sh
puzzle_test/input/thumbnail.jpg
```

任意の画像でOK（自動で1200×672にリサイズされる）。

### 2. スクリプトを実行

```sh
# input/thumbnail.jpg を使ってランダム12枚を所持済みとして生成
cd puzzle_test
python3 generate_puzzle.py

# 所持済みピースIDを指定する場合
python3 generate_puzzle.py --owned 1,2,3,7,8,9,13,14,15

# 別の画像を使う場合
python3 generate_puzzle.py --input /path/to/image.jpg
```

### 3. 出力先

```
output/
  locked/
    piece_01.png ～ piece_24.png   # 未所持ピース（濃い紫グレー）
  thumbnail/
    piece_01.png ～ piece_24.png   # サムネイルから切り出したピース
  preview/
    puzzle_preview.png             # サムネイルピース全枚確認
    locked_preview.png             # 未所持ピース全枚確認
    mixed_preview.png              # 所持/未所持の混在確認
```

## ピースID設計

```
piece_01 piece_02 piece_03 piece_04 piece_05 piece_06
piece_07 piece_08 piece_09 piece_10 piece_11 piece_12
piece_13 piece_14 piece_15 piece_16 piece_17 piece_18
piece_19 piece_20 piece_21 piece_22 piece_23 piece_24
```

左上から右下に向かって1〜24のIDを振る。

## 仕様

| 項目 | 値 |
|---|---|
| キャンバスサイズ | 1200 × 672 px |
| 列数 | 6 |
| 行数 | 4 |
| ピース総数 | 24 |
| 1ピースサイズ | 200 × 168 px |
| アスペクト比 | 16:9 |
| 未所持ピース色 | #2F2A45（濃い紫グレー） |
