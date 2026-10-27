# AirShowerWebApplication

空気シャワーの発達とハドロン相互作用の関係を調べるための、宇宙線物理研究者向け Web アプリケーションです。シミュレーションには COSMOS を使います。

## 開発の流れ

1. **空気シャワーシミュレーション。** COSMOS で 1 イベントを走らせ、入射条件、相互作用、観測面の粒子を HDF5 に書く。実装は [CosmosApp](CosmosApp/README_CosmosApp.md) です。
2. **シミュレーション出力の解析。** 未着手です。
3. **解析結果を表示する Web アプリケーション。** 未着手です。

## セットアップ

- GitHubからソースコードを取得
```
git clone git@github.com:hmenjo/AirShowerWebApplication.git 
```
- COSMOSXのインストール


## ディレクトリ

| パス | 内容 |
| --- | --- |
| `cosmosX/` | COSMOS Simulation Package。CosmosX Webpageからダウンロード |
| `CosmosApp/` | 空気シャワーシミュレーション |


