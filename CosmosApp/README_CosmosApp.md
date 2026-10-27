# CosmosApp

COSMOS で空気シャワーを 1 イベントだけシミュレーションし、その結果を HDF5 1 ファイルに書きます。記録するのは入射条件、ハドロン相互作用と崩壊、各観測面に到達した粒子です。電磁相互作用はシャワーの中では追跡しますが、相互作用データセットにはしません。

フォーマット名はルートの属性 `format` に入り、現在は `cosmos-airshower-v2` です。

## ディレクトリ

作業ディレクトリは `CosmosApp/src` です。

| ファイル | 役割 |
| --- | --- |
| `chook.f` | COSMOS のユーザーフック。相互作用と観測面通過を HDF5 書き出しへ渡す。 |
| `chook_hdf5.f90` | HDF5 のグループ、データセット、属性を書く。 |
| `CMakeLists.txt` | `cosmosLinuxGfort` のビルド。HDF5 と COSMOS ライブラリをリンクする。 |
| `param` | 入射高度、天頂角、相互作用モデル、観測面、イベント数。 |
| `primary` | 入射粒子。現在の例は陽子、運動エネルギー 100 GeV/n。 |

実行ファイル `cosmosLinuxGfort` は `src` に生成されます。HDF5 は、環境変数 `COSMOS_H5OUT` がなければ `src/output/event_<イベント番号>.h5` に書かれます。

## ビルドと実行

COSMOS が環境変数を展開するバッファは 64 文字です。`LIBLOFT` と `COSMOSTOP` はこの長さに収めてください。このリポジトリの実パスは 64 文字を超えるので、短いシンボリックリンクを使います。

```bash
ln -sfn /path/to/AirShowerWebApplication/cosmosX /tmp/cx
export SHOWERMCTOP=/tmp/cx
export COSMOSTOP=/tmp/cx/Cosmos
export LIBLOFT=/tmp/cx/LibLoft

cmake -S CosmosApp/src -B CosmosApp/build
cmake --build CosmosApp/build

cd CosmosApp/src
./cosmosLinuxGfort < param
```

`param` の `DestEventNo = 1 1` により、1 回の実行は 1 イベントです。したがって 1 実行が 1 ファイルになります。`InitRN` の第 2 成分が負なので、実行のたびに乱数が変わり、別のシャワーになります。

別のパスに書きたいときは `COSMOS_H5OUT` にファイルパスを指定します。

## 何が 1 件の相互作用になるか

`chookNEPInt` が呼ばれ、過程名が `coll` または `decay` のときだけ記録します。通し番号は 1 から始まり、一次粒子の最初の相互作用が `Int_1` です。制動放射、対生成、ノックオン、光生成、原子核によるミューオン相互作用は番号を進めてもデータセットにもしません。

電磁カスケードの粒子は、最後に経験した `coll` または `decay` の祖先を親として持ちます。

## ファイルの中身

ファイルには 3 つのグループがあります。

```text
/
  format = "cosmos-airshower-v2"
  conditions/
  interactions/
    Int_1
    Int_2
    ...
  observation/
    Obs_1
    Obs_2
    ...
```

粒子種類は PDG コードです。エネルギーは全エネルギー（静止質量を含む、COSMOS の `p(4)`）で、単位は GeV です。運動量も GeV（`c = 1`）です。長さは m、天頂角は度です。

整数と実数の属性は、要素数 1 の配列として書かれます。文字列属性はスカラーです。HDF5 Table が付ける `CLASS`、`TITLE`、`VERSION`、`FIELD_*` は表形式のための属性で、物理量ではありません。

データセットは gzip レベル 6 で圧縮します。相互作用のチャンクは 256 行、観測面のチャンクは 8192 行です。生成粒子が 0 の相互作用や、粒子が来なかった観測面も、属性を残すために空のデータセットとして作ります。

### `conditions`

属性だけを持ち、行はありません。値はそのイベントの入射粒子です。

| 属性 | 意味 |
| --- | --- |
| `event_number` | イベント番号。ファイル名の番号と一致する。 |
| `pdg` | 入射粒子の PDG コード。 |
| `energy_gev` | 全エネルギー。 |
| `px_gev`, `py_gev`, `pz_gev` | 3 次元運動量。地球座標。 |
| `zenith_deg` | 天頂角。`coszenith` から計算する。 |
| `interaction_model` | `param` の `IntModel`。末尾の空白とナムリストの `/` は除く。 |
| `height_m` | 入射高度。 |
| `units` | 単位の説明。 |

天頂角は運動量の `pz` からは作りません。地球座標の z は鉛直とは限りません。

### `interactions/Int_<id>`

1 つの `coll` または `decay` が 1 つのデータセットです。`<id>` はゼロ埋めなしの整数です。1 行が生成粒子 1 個です。

行の列は次のとおりです。

| 列 | 型 | 意味 |
| --- | --- | --- |
| `sec_id` | int32 | その相互作用の中の生成粒子番号。1 始まりで、`Pwork` の順。 |
| `pdg` | int32 | 生成粒子の PDG コード。 |
| `energy_gev` | float64 | 全エネルギー。 |
| `px_gev`, `py_gev`, `pz_gev` | float64 | 生成時の運動量。地球座標。 |
| `xlab` | float64 | `E_secondary / E_projectile`。分母は入射粒子の全エネルギー。0 のときは 0。 |
| `pt_gev` | float64 | 入射粒子の進行方向に垂直な運動量の大きさ。 |

相互作用そのものの量は属性です。

| 属性 | 意味 |
| --- | --- |
| `int_id` | データセット名と同じ相互作用番号。 |
| `process` | `coll` または `decay`。 |
| `height_m` | 相互作用高度。 |
| `x_m`, `y_m`, `z_m` | 相互作用位置。地球中心を原点とする COSMOS の地球座標。 |
| `projectile_pdg` | 入射粒子の PDG コード。 |
| `projectile_energy_gev` | 入射粒子の全エネルギー。 |
| `projectile_px_gev`, `projectile_py_gev`, `projectile_pz_gev` | 入射粒子の運動量。地球座標。 |
| `target_a`, `target_z` | 標的核の質量数と原子番号。 |
| `target_pdg` | 標的核の PDG イオンコード `10LZZZAAAI`。`1000000000 + Z*10000 + A*10`。 |
| `n_secondaries` | 生成粒子数。行数と一致する。 |
| `n_coll` | 一次粒子からこの相互作用まで、この相互作用を含めた衝突回数。 |
| `n_decay` | 一次粒子からこの相互作用まで、この相互作用を含めた崩壊回数。 |
| `parent_int_id` | この入射粒子を作った相互作用の番号。一次粒子なら 0。 |
| `parent_sec_id` | その相互作用の中の生成粒子番号。一次粒子なら 0。 |
| `units` | 単位の説明。 |

崩壊では標的がないので、`target_a`、`target_z`、`target_pdg` は 0 です。

`n_coll` と `n_decay` は世代を 1 本の番号にまとめたものではありません。一次衝突は `n_coll = 1`、`n_decay = 0` です。その生成粒子が崩壊すると、崩壊側は `n_coll = 1`、`n_decay = 1` になります。

`param` の `Freec = F` では、最初の相互作用は入射高度で起きます。現在の設定では `Int_1` の `height_m` は 20000 です。

### `observation/Obs_<面番号>`

観測面 1 つが 1 つのデータセットです。面番号は COSMOS の観測サイト番号で、1 始まりです。1 行が、その面を横切った粒子 1 個です。`chookObs` の `id = 2` だけを記録します。

| 列 | 型 | 意味 |
| --- | --- | --- |
| `pdg` | int32 | 粒子の PDG コード。 |
| `energy_gev` | float64 | 検出時の全エネルギー。 |
| `px_gev`, `py_gev`, `pz_gev` | float64 | 検出時の運動量。検出器座標。 |
| `x_m`, `y_m` | float64 | 検出位置。検出器座標。 |
| `parent_int_id` | int32 | この粒子の最後の `coll` または `decay`。 |
| `parent_sec_id` | int32 | その相互作用での生成粒子番号。 |

属性は `height_m`（面の高度）、`plane_id`（面番号）、`units` です。面の高度は行には繰り返さず、属性にだけ置きます。

観測面が水平（`ObsPlane = 1`）のとき、COSMOS は位置と方向を検出器座標へ変換します。運動量の成分は、運動量の大きさにその方向余弦を掛けて、位置と同じ座標系に揃えています。相互作用側の運動量と位置は地球座標のままです。

## 一次粒子まで遡る

観測粒子の `parent_int_id` と `parent_sec_id` は、`interactions/Int_<parent_int_id>` の `sec_id` 行を指します。そのデータセットの属性 `parent_int_id` と `parent_sec_id` が、さらに一つ前の入射粒子です。`parent_int_id` が 0 になるまで繰り返すと一次粒子です。

```python
import h5py

def ancestors(path, plane, row):
    with h5py.File(path) as f:
        chain = []
        pid = int(f["observation"][plane][row]["parent_int_id"])
        sid = int(f["observation"][plane][row]["parent_sec_id"])
        while pid != 0:
            node = f["interactions"][f"Int_{pid}"]
            chain.append((pid, sid, int(node[sid - 1]["pdg"])))
            pid = int(node.attrs["parent_int_id"])
            sid = int(node.attrs["parent_sec_id"])
        return chain
```

電磁カスケードの粒子も、同じ手順で最後の `coll` または `decay` の行に着きます。その行が、カスケードの元になった生成粒子です。

## 現在の `param` が出力に与えるもの

これはフォーマットではなく、同梱の `param` の設定です。

- 入射は `primary` の陽子、運動エネルギー 100 GeV/n。ファイルに書くエネルギーは全エネルギーなので、約 100.9 GeV になります。
- 天頂角の余弦は 0.6 から 1.0 の間で抽選します。方位角は 0 です。
- 入射高度は 20000 m です。
- 相互作用モデルは、しきい値つきで `"phits" 2.0 "dpmjet3" 10 "sibyll"` です。
- `DepthList` が負なので高度リストが使われます。観測面は 6000, 5000, 4000, 3000, 2000, 1000, 0 m の 7 面で、データセットは `Obs_1` から `Obs_7` です。
- `Generate = em` なので電磁成分も追跡します。HDF5 に出る相互作用は `coll` と `decay` だけです。
- `KEminObs` は 100 keV です。これより低い粒子は観測面の行に現れません。
- `ThinSampling = F` なので、重み付きの間引きはありません。
